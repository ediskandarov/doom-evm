#!/usr/bin/env python3
"""Build original gameplay and renderer, recording every host adaptation."""
import argparse, importlib.util, json, pathlib, re, subprocess, sys
HERE=pathlib.Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent))
import reference as ref
spec=importlib.util.spec_from_file_location('renderer_builder',HERE.parent/'renderer/build.py')
renderer=importlib.util.module_from_spec(spec); spec.loader.exec_module(renderer)
PUNITS=['p_ceilng.c','p_doors.c','p_enemy.c','p_floor.c','p_inter.c','p_lights.c','p_map.c','p_maputl.c','p_mobj.c','p_plats.c','p_pspr.c','p_setup.c','p_sight.c','p_spec.c','p_switch.c','p_telept.c','p_tick.c','p_user.c','m_random.c','d_items.c','z_zone.c']

def extract(filename,name):
    text=(ref.SOURCE/filename).read_text()
    match=re.search(r'\n(?:void|boolean)\s+'+name+r'\s*\([^;{}]*\)\s*\{',text); assert match,name
    start=match.start()+1; opening=match.end()-1; end=opening+1; depth=1
    while depth:
        if text[end]=='{': depth+=1
        elif text[end]=='}': depth-=1
        end+=1
    body=text[start:end]
    return body,dict(file=filename,function=name,startLine=text[:start].count('\n')+1,endLine=text[:end].count('\n')+1,sha256=ref.sha(body.encode()))

def build(out,opt='O2',sanitize=False,strict=False):
    renderer.build(out,opt,sanitize,strict)
    manifest=json.loads((out/'build-manifest.json').read_text())
    manifest['scope']='Actual original gameplay translation units plus original software renderer; host packet input and observation only'
    for name in PUNITS:
        text=(ref.SOURCE/name).read_text(); manifest['sources'][name]=ref.sha(text.encode())
        if name=='z_zone.c':
            before='size = (size + 3) & ~3;';after='size = (size + 7) & ~7;'
            assert text.count(before)==1;text=text.replace(before,after)
            manifest['adaptations'].append(dict(file=name,before=before,after=after,reason='LP64 zone blocks require eight-byte pointer alignment; original zone allocation/reuse/free/tag algorithms retained'))
            before='return (void *) ((byte *)base + sizeof(memblock_t));'
            after='OracleAllocation((byte *)base + sizeof(memblock_t), size-sizeof(memblock_t));\n    '+before
            assert text.count(before)==1;text=text.replace(before,after)
            manifest['adaptations'].append(dict(file=name,hook='OracleAllocation',reason='Alternate allocation fill observes whether selected defined logical states depend on fresh payload bytes'))
        if name=='p_tick.c':
            for fn,hook in [('P_AddThinker','OracleAddThinker'),('P_RemoveThinker','OracleRemoveThinker')]:
                match=re.search(r'\nvoid\s+'+fn+r'\s*\([^;{}]*\)\s*\{',text); assert match
                pos=match.end(); text=text[:pos]+'\n    '+hook+'(thinker);\n'+text[pos:]
                manifest['adaptations'].append(dict(file=name,traceEntry=fn,hook=hook,reason='Observe stable thinker identity; no original state mutation'))
        if name=='p_setup.c':
            before='linebuffer = Z_Malloc (total*4, PU_LEVEL, 0);'; after='linebuffer = Z_Malloc (total*sizeof(*linebuffer), PU_LEVEL, 0);'
            assert text.count(before)==1; text=text.replace(before,after)
            manifest['adaptations'].append(dict(file=name,before=before,after=after,reason='LP64 sector line pointer array allocation'))
        watch={'P_TryMove','P_CheckPosition','P_SlideMove','P_UseLines','P_DamageMobj','EV_DoDoor','EV_VerticalDoor','P_TouchSpecialThing','P_NoiseAlert','P_CheckSight','P_SpawnMobj','P_RemoveMobj','P_SetMobjState'}
        for match in reversed(list(re.finditer(r'\n(?:void|boolean|int|mobj_t\*|fixed_t)\s+([A-Za-z_]\w*)\s*\([^;{}]*\)\s*\{',text))):
            fn=match.group(1)
            if fn.startswith('A_') or fn in watch:
                pos=match.end();text=text[:pos]+'\n    OracleEvent("'+fn+'");\n'+text[pos:]
                manifest['adaptations'].append(dict(file=name,traceEntry=fn,hook='OracleEvent',reason='Count original function entries without modifying original state'))
        (out/name).write_text(text)
    funcs=[]
    for fn in ['G_PlayerReborn','G_ExitLevel','G_SecretExitLevel']:
        body,record=extract('g_game.c',fn); funcs.append(body)
        manifest['adaptations'].append(dict(extraction=record))
    manifest['sources']['g_game.c']=ref.sha((ref.SOURCE/'g_game.c').read_bytes())
    (out/'game_functions.c').write_text('#include "doomstat.h"\n#include "g_game.h"\n#include "p_local.h"\n#include "w_wad.h"\nextern boolean secretexit;\n'+'\n'.join(funcs)+'\n')
    # No static-renderer actions.c or extracted map_loader.c: actual p_* definitions own both.
    flags=[('-'+opt if f=='-O2' else f) for f in ref.FLAGS]
    flags+=['-fsigned-char','-DNORMALUNIX','-include','stdint.h','-include','stddef.h','-include','stdlib.h','-include','string.h','-include','strings.h','-include','alloca.h','-include',str(HERE.parent/'renderer/trace.h'),'-Wno-incompatible-pointer-types','-Wno-implicit-function-declaration','-Wno-pointer-to-int-cast','-Wno-int-to-pointer-cast']
    if strict: flags.remove('-fwrapv')
    if sanitize: flags+=['-fsanitize=address,undefined','-fno-sanitize-recover=all']
    (out/'gameplay-observe.h').write_text('void OracleAddThinker(void *);\nvoid OracleRemoveThinker(void *);\nvoid OracleEvent(const char *);\nvoid OracleAllocation(void *,int);\n')
    flags+=['-include',str(out/'gameplay-observe.h')]
    units=renderer.UNITS+PUNITS
    cmd=['clang',*flags,'-I'+str(out),*[str(out/name) for name in units],str(out/'game_functions.c'),str(HERE/'host.c'),'-Wl,-dead_strip','-o',str(out/'gameplay')]
    result=subprocess.run(cmd,text=True,capture_output=True)
    (out/'gameplay-build.log').write_text(result.stdout+result.stderr)
    if result.returncode: print(result.stderr); raise SystemExit(result.returncode)
    manifest.update(flags=[f.replace(str(HERE.parent),'<HARNESS>') for f in flags],hostSha256=ref.sha((HERE/'host.c').read_bytes()),builderSha256=ref.sha(pathlib.Path(__file__).read_bytes()),observationSha256=ref.sha((HERE/'observe.h').read_bytes()),diagnosticsSha256=ref.sha((HERE/'diagnostics.h').read_bytes()),rendererBuilderSha256=ref.sha((HERE.parent/'renderer/build.py').read_bytes()))
    manifest['adaptations'].append(dict(hostZone='Original z_zone.c owns allocations, frees, purges, reuse and tags. Host I_ZoneBase provides one fixed 64 MiB region. Original P_RunThinkers next read after Z_Free remains within the original zone payload.'))
    (out/'gameplay-build-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return out/'gameplay'

if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('--output',type=pathlib.Path,default=ref.ROOT/'artifacts/local/native-gameplay'); p.add_argument('--opt',choices=['O0','O2'],default='O2'); p.add_argument('--sanitize',action='store_true'); p.add_argument('--strict',action='store_true'); a=p.parse_args(); print(build(a.output,a.opt,a.sanitize,a.strict))
