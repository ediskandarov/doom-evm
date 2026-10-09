#!/usr/bin/env python3
"""Build original renderer translation units with explicit LP64/platform adaptations."""
import argparse, hashlib, json, pathlib, re, shutil, subprocess, sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
import reference as ref
ROOT=ref.ROOT
HERE=pathlib.Path(__file__).resolve().parent
UNITS=['r_main.c','r_bsp.c','r_segs.c','r_plane.c','r_things.c','r_draw.c','r_data.c','r_sky.c','tables.c','m_fixed.c','m_bbox.c','w_wad.c','doomstat.c','info.c']

def build(out,opt='O2',sanitize=False,strict=False):
    out.mkdir(parents=True,exist_ok=True)
    assert ref.invoke(['git','-C',str(ref.SOURCE),'rev-parse','HEAD']).strip()==ref.UPSTREAM
    ref.invoke(['git','-C',str(ref.SOURCE),'diff','--exit-code','HEAD','--'])
    version=ref.invoke(['clang','--version']).splitlines()
    assert version[:2]==[ref.VERSION,'Target: '+ref.TARGET]
    records=[]; hashes={}
    (out/'values.h').write_text('#include <limits.h>\n#include "doomtype.h"\n')
    for source in sorted(ref.SOURCE.glob('*.h')):
        shutil.copyfile(source,out/source.name); hashes[source.name]=ref.sha(source.read_bytes())
    def change(name,text,before,after,reason):
        assert text.count(before)==1,(name,before,text.count(before))
        records.append(dict(file=name,before=before,after=after,reason=reason))
        return text.replace(before,after)
    for name in UNITS:
        text=(ref.SOURCE/name).read_text(); hashes[name]=ref.sha(text.encode())
        if name=='w_wad.c': text=change(name,text,'#include <malloc.h>','#include <stdlib.h>','macOS malloc declarations')
        if name=='r_data.c':
            text=change(name,text,'} maptexture_t;','} __attribute__((packed)) maptexture_t;','WAD texture records can start at two-byte offsets; packed disk access removes host alignment UB')
            text=change(name,text,'void\t\t**columndirectory;','int32_t\t\tcolumndirectory;','obsolete on-disk field is 32 bits, not a host pointer')
            for variable in ['textures','texturecolumnlump','texturecolumnofs','texturecomposite']:
                before=variable+' = Z_Malloc (numtextures*4, PU_STATIC, 0);'
                text=change(name,text,before,variable+' = Z_Malloc (numtextures*sizeof(*'+variable+'), PU_STATIC, 0);','LP64 host pointer array allocation')
            text=change(name,text,'((int)colormaps + 255)&~0xff','((uintptr_t)colormaps + 255)&~(uintptr_t)0xff','preserve 256-byte alignment on LP64')
        if name=='r_draw.c': text=change(name,text,'( (int)translationtables + 255 )& ~255','( (uintptr_t)translationtables + 255 )& ~(uintptr_t)255','preserve 256-byte alignment on LP64')
        if name=='r_plane.c':
            for field in ['top','bottom']:
                before='pl->'+field+'['; after='((byte*)pl+offsetof(visplane_t,'+field+'))['
                count=text.count(before); assert count
                records.append(dict(file=name,before=before,after=after,count=count,reason='Access original visplane sentinel pad bytes through the enclosing object representation, avoiding array-subobject bounds UB without changing any address'))
                text=text.replace(before,after)
        if name=='r_bsp.c':
            for fn,args in [('R_RenderBSPNode','bspnum'),('R_Subsector','num'),('R_ClipSolidWallSegment','first,last'),('R_ClipPassWallSegment','first,last')]:
                match=re.search(r'\nvoid\s+'+fn+r'\s*\(',text); assert match,fn
                opening=text.index('{',match.end())
                hook='\n    OracleTrace("'+fn+'",'+args+(',0' if ',' not in args else '')+');\n'
                text=text[:opening+1]+hook+text[opening+1:]
                records.append(dict(file=name,traceEntry=fn,hook=hook))
        if name=='r_segs.c':
            match=re.search(r'\nvoid\s+R_StoreWallRange\s*\(',text); assert match
            opening=text.index('{',match.end()); hook='\n    OracleTrace("R_StoreWallRange",start,stop);\n'
            text=text[:opening+1]+hook+text[opening+1:]; records.append(dict(file=name,traceEntry='R_StoreWallRange',hook=hook))
        (out/name).write_text(text)
    # Keep original map loader functions; exclude game setup, sound, spawning and collision setup.
    setup=(ref.SOURCE/'p_setup.c').read_text(); hashes['p_setup.c']=ref.sha(setup.encode())
    prefix=setup[:setup.index('//\n// P_LoadVertexes')]
    funcs=[]
    for fn in ['P_LoadVertexes','P_LoadSectors','P_LoadSideDefs','P_LoadLineDefs','P_LoadSubsectors','P_LoadNodes','P_LoadSegs']:
        match=re.search(r'\nvoid\s+'+fn+r'\s*\(',setup); assert match,fn
        start=match.start()+1; opening=setup.index('{',match.end()); end=opening+1; depth=1
        while depth:
            if setup[end]=='{': depth+=1
            elif setup[end]=='}': depth-=1
            end+=1
        body=setup[start:end]; funcs.append(body)
        records.append(dict(extraction=dict(file='p_setup.c',function=fn,startLine=setup[:start].count('\n')+1,endLine=setup[:end].count('\n')+1,sha256=ref.sha(body.encode()))))
    (out/'map_loader.c').write_text(prefix+'\n'+'\n'.join(funcs)+'\n')
    # Action pointers are static info.c data, never called by a static renderer.
    actions=re.findall(r'void\s+(A_\w+)\s*\(\s*\);',(ref.SOURCE/'info.c').read_text())
    (out/'actions.c').write_text('#include "i_system.h"\n'+'\n'.join('void '+name+'(void) { I_Error("Unexpected gameplay action '+name+'"); }' for name in actions)+'\n')
    flags=[('-'+opt if f=='-O2' else f) for f in ref.FLAGS]
    flags+=['-DNORMALUNIX','-include','stdint.h','-include','stddef.h','-include','stdlib.h','-include','string.h','-include','strings.h','-include','alloca.h','-include',str(HERE/'trace.h'),'-Wno-incompatible-pointer-types','-Wno-implicit-function-declaration','-Wno-pointer-to-int-cast','-Wno-int-to-pointer-cast']
    if strict: flags.remove('-fwrapv')
    if sanitize: flags+=['-fsanitize=address,undefined','-fno-sanitize-recover=all']
    cmd=['clang',*flags,'-I'+str(out),*[str(out/name) for name in UNITS],str(out/'map_loader.c'),str(out/'actions.c'),str(HERE/'host.c'),'-Wl,-dead_strip','-o',str(out/'renderer')]
    result=subprocess.run(cmd,text=True,capture_output=True)
    (out/'build.log').write_text(result.stdout+result.stderr)
    if result.returncode: print(result.stderr); raise SystemExit(result.returncode)
    manifest=dict(upstreamCommit=ref.UPSTREAM,compiler=ref.VERSION,target=ref.TARGET,flags=[f.replace(str(HERE),'<HARNESS>') for f in flags],sources=hashes,adaptations=records,hostSha256=ref.sha((HERE/'host.c').read_bytes()),builderSha256=ref.sha(pathlib.Path(__file__).read_bytes()),traceHeaderSha256=ref.sha((HERE/'trace.h').read_bytes()),valuesHeaderSha256=ref.sha((out/'values.h').read_bytes()))
    (out/'build-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return out/'renderer'

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--output',type=pathlib.Path,default=ROOT/'artifacts/local/native-renderer'); parser.add_argument('--opt',choices=['O0','O2'],default='O2'); parser.add_argument('--sanitize',action='store_true'); parser.add_argument('--strict',action='store_true'); args=parser.parse_args()
    print(build(args.output,args.opt,args.sanitize,args.strict))
