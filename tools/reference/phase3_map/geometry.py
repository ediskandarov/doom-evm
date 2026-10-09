#!/usr/bin/env python3
"""Original mechanically extracted geometry functions; emits binary proof vectors."""
import argparse, importlib.util, json, pathlib, random, re, struct, subprocess, tempfile
HERE=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('original_reference',HERE.parent/'reference.py')
ref=importlib.util.module_from_spec(spec);spec.loader.exec_module(ref)

def extract(file,name):
    source=(ref.SOURCE/file).read_text()
    m=re.search(r'\n(?:fixed_t|int|void|angle_t|subsector_t\*)\s+'+name+r'\s*\([^;{}]*\)\s*\{',source);assert m,name
    start=m.start()+1;end=m.end();depth=1
    while depth:
        depth+=(source[end]=='{')-(source[end]=='}');end+=1
    body=source[start:end]
    return body,dict(file=file,function=name,startLine=source[:start].count('\n')+1,endLine=source[:end].count('\n')+1,sha256=ref.sha(body.encode()))

def rows():
    rng=random.Random(0xD003)
    out=[]
    for a in [0,1,-1,65535,65536,-65536,100*65536,-100*65536]:
        for b in [0,1,-1,65536,-65536]:out.append((0,[a,b]))
    for i in range(600):
        coord=lambda:rng.randint(-4096*65536,4096*65536)
        dx=coord();dy=coord()
        if i%5==0:dx=0
        if i%5==1:dy=0
        x=coord();y=coord();vx=coord();vy=coord()
        out.append((0,[dx,dy]));out.append((1,[x,y,vx,vy,dx,dy]));out.append((3,[x,y,vx,vy,dx,dy]));out.append((5,[x,y,vx,vy,dx,dy]))
        # Actual slopetype, box edge contacts included, not an invented orientation.
        slope=0 if dy==0 else 1 if dx==0 else 2 if (dx<0)==(dy<0) else 3
        left=x-16*65536;right=x+16*65536;bottom=y-16*65536;top=y+16*65536
        out.append((2,[top,bottom,left,right,vx,vy,dx,dy,slope]))
        a=[coord() for _ in range(8)];out.append((4,a));out.append((6,a))
    for dx,dy in [(0,65536),(65536,0),(-65536,0),(0,-65536),(65536,65536)]:
        for x,y in [(0,0),(65536,0),(0,65536),(-65536,-65536)]:
            out.append((1,[x,y,0,0,dx,dy]));out.append((3,[x,y,0,0,dx,dy]));out.append((5,[x,y,0,0,dx,dy]))
    for ff,fc,bf,bc in [(0,128,0,128),(24,128,0,64),(0,64,24,128),(0,0,0,128),(-64,128,-32,256)]:
        for two in [0,1]:out.append((7,[ff*65536,fc*65536,bf*65536,bc*65536,two]))
    return out

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');a=parser.parse_args()
    assert ref.invoke(['git','-C',str(ref.SOURCE),'rev-parse','HEAD']).strip()==ref.UPSTREAM
    assert not ref.invoke(['git','-C',str(ref.SOURCE),'diff','--name-only'])
    version=ref.invoke(['clang','--version']).splitlines();assert version[0]==ref.VERSION and version[1]=='Target: '+ref.TARGET
    functions=[];records=[]
    selected={'p_maputl.c':['P_AproxDistance','P_PointOnLineSide','P_BoxOnLineSide','P_PointOnDivlineSide','P_MakeDivline','P_InterceptVector','P_LineOpening'],'p_sight.c':['P_DivlineSide','P_InterceptVector2'],'m_fixed.c':['FixedMul','FixedDiv','FixedDiv2']}
    for file,names in selected.items():
        for name in names:
            body,record=extract(file,name);functions.append(body);records.append(record)
    prefix='#include <stdio.h>\n#include <stdint.h>\n#include <stdlib.h>\n#include "m_bbox.h"\n#include "doomdef.h"\n#include "p_local.h"\nfixed_t opentop,openbottom,openrange,lowfloor;\nvoid I_Error(char *format,...) { (void)format; exit(2); }\n'
    generated=prefix+'\n'.join(functions)+'\n'+(HERE/'geometry_driver.c').read_text()
    cases=rows();commands=''.join(str(op)+' '+str(len(args))+' '+' '.join(map(str,args))+'\n' for op,args in cases)
    results=[];profiles=[]
    with tempfile.TemporaryDirectory(prefix='doom-phase3-map-') as td:
        td=pathlib.Path(td);(td/'oracle.c').write_text(generated)
        (td/'values.h').write_text('#include <limits.h>\n#define MAXINT INT_MAX\n#define MININT INT_MIN\n')
        for profile,opt,sanitize in [('O0','-O0',False),('O2','-O2',False),('sanitized','-O2',True)]:
            flags=[opt if f=='-O2' else f for f in ref.FLAGS]
            if sanitize:flags+=['-fsanitize=address,undefined','-fno-sanitize-recover=all']
            ref.invoke(['clang',*flags,'-I'+str(td),'-I'+str(ref.SOURCE),str(td/'oracle.c'),'-o',str(td/profile)])
            raw=subprocess.run([str(td/profile)],input=commands.encode(),capture_output=True,check=True).stdout
            results.append(raw);profiles.append(dict(name=profile,flags=flags,outputSha256=ref.sha(raw)))
    assert all(r==results[0] for r in results), 'Original compiler profiles diverged'
    raw=results[0];assert len(raw)==sum(4*(1+(4 if op==7 else 1)) for op,_ in cases)
    output=bytearray(struct.pack('>I',len(cases)));p=0
    for op,args in cases:
        no=struct.unpack_from('>I',raw,p)[0];p+=4;expected=raw[p:p+no*4];p+=no*4
        output.extend(bytes([op,len(args),no,0]));output.extend(struct.pack('>'+str(len(args))+'i',*args));output.extend(expected)
    manifest=dict(upstream=ref.UPSTREAM,compiler=ref.VERSION,target=ref.TARGET,cases=len(cases),extractions=records,sourceHashes={file:ref.sha((ref.SOURCE/file).read_bytes()) for file in selected},harnessHashes={file:ref.sha((HERE/file).read_bytes()) for file in ['geometry.py','geometry_driver.c']},generatedSha256=ref.sha(generated.encode()),profiles=profiles,vectorSha256=ref.sha(output),scope='Original geometry and line opening; no rewritten C oracle; int32 wrapping profile; abs(INT_MIN) excluded')
    dest=ref.ROOT/'test/fixtures/phase3_map';files={'geometry.bin':bytes(output),'geometry-manifest.json':(json.dumps(manifest,indent=2)+'\n').encode()}
    for name,value in files.items():
        if a.check:assert (dest/name).read_bytes()==value,name
        else:(dest/name).write_bytes(value)
    print(f'PASS original collision geometry: {len(cases)} cases, exact O0/O2/ASan/UBSan')
if __name__=='__main__':
    try:main()
    except subprocess.CalledProcessError as error:
        print(error.stderr.decode() if isinstance(error.stderr,bytes) else error.stderr)
        raise
