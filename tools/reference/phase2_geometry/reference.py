#!/usr/bin/env python3
"""Phase 2 geometry native oracle. All algorithms are mechanically extracted original C."""
import argparse, hashlib, importlib.util, json, pathlib, random, re, struct, subprocess, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[3]
HERE=pathlib.Path(__file__).resolve().parent
FIX=ROOT/'test/fixtures/phase2_geometry'
spec=importlib.util.spec_from_file_location('phase1',HERE.parent/'reference.py'); p1=importlib.util.module_from_spec(spec);spec.loader.exec_module(p1)
def extract(file,name,result):
    text=(p1.SOURCE/file).read_text()
    match=re.search(r'\n'+re.escape(result)+r'\s+'+name+r'\s*\(',text)
    assert match,name
    start=match.start()+1;end=text.index('{',match.end())+1;depth=1
    while depth:
        if text[end]=='{':depth+=1
        elif text[end]=='}':depth-=1
        end+=1
    body=text[start:end]
    return body,{'file':file,'function':name,'startLine':text[:start].count('\n')+1,'endLine':text[:end].count('\n')+1,'sha256':p1.sha(body.encode())}
def packed(values):return b''.join(struct.pack('>I',v&0xffffffff) for v in values)
def build(directory):
    # The original harness pins compiler, target, source tree and numeric semantics.
    meta,original=p1.build(directory)
    units=[]; records=[]
    for file,name,result in [('m_fixed.c','FixedMul','fixed_t'),('m_fixed.c','FixedDiv','fixed_t'),('m_fixed.c','FixedDiv2','fixed_t'),('r_main.c','R_PointOnSegSide','int'),('r_main.c','R_PointToDist','fixed_t'),('r_main.c','R_ScaleFromGlobalAngle','fixed_t'),('r_main.c','R_InitTextureMapping','void'),('r_main.c','R_InitLightTables','void'),('r_draw.c','R_InitBuffer','void'),('r_main.c','R_ExecuteSetViewSize','void'),('r_main.c','R_SetupFrame','void')]:
        body,record=extract(file,name,result);units.append(body);records.append(record)
    generated='#include "compat.h"\n'+'\n'.join(units)+'\n#include "driver.c"\n'
    cfile=directory/'geometry.c';cfile.write_text(generated)
    for name,flags in [('geomO0',[f.replace('-O2','-O0') for f in p1.FLAGS]),('geomO2',p1.FLAGS),('geomSan',[f for f in p1.FLAGS if f!='-fwrapv']+['-fsanitize=undefined,float-cast-overflow','-fno-sanitize-recover=all']),('geomViewSan',[f for f in p1.FLAGS if f!='-fwrapv']+['-fsanitize=undefined,float-cast-overflow','-fno-sanitize=shift-base','-fno-sanitize-recover=all'])]:
        p1.invoke(['clang',*flags,'-I'+str(HERE),'-I'+str(p1.SOURCE),str(cfile),str(p1.SOURCE/'tables.c'),'-o',str(directory/name)])
    return {'upstreamCommit':p1.UPSTREAM,'build':meta,'sources':{f:p1.sha((p1.SOURCE/f).read_bytes()) for f in ['r_main.c','r_draw.c','m_fixed.c','tables.c']},'extractions':records,'generatedSourceSha256':p1.sha(generated.encode()),'harnessSha256':{f:p1.sha((HERE/f).read_bytes()) for f in ['reference.py','driver.c','compat.h']}}
def run(binary,rows):
    cmds=''.join(r['function']+' '+' '.join(map(str,r['inputs']))+'\n' for r in rows)
    lines=p1.invoke([str(binary)],input=cmds).splitlines();assert len(lines)==len(rows)
    return [dict(r,outputs=[int(x) for x in line.split()]) for r,line in zip(rows,lines)]
def rows():
    rng=random.Random(0x47454f32);out=[]
    def row(fn,values):out.append({'function':fn,'inputs':list(values)})
    for x,y in [(1,0),(0,1),(65536,65536),(-65536,0),(0,-65536),(2147483647,1),(1,-2147483647)]:row('dist',[0,0,x,y])
    for _ in range(300):
        v=[rng.randint(-1000*65536,1000*65536) for _ in range(4)]
        if v[:2]!=v[2:]:row('dist',v)
    for dx,dy in [(0,65536),(0,-65536),(65536,0),(-65536,0),(65536,65536),(-65536,65536)]:
        for x,y in [(0,0),(1,1),(-1,-1),(65536,0),(0,-65536)]:row('seg',[x,y,0,0,dx,dy])
    for _ in range(300):row('seg',[rng.randint(-1000*65536,1000*65536) for _ in range(6)])
    for detail in [0,1]:
        for delta in [-0x20000000,-1,0,1,0x20000000]:
            for distance in [0,1,65536,128*65536,2147483647]:row('scale',[0,160*65536>>detail,detail,delta&0xffffffff,0,distance])
    for _ in range(300):
        angle=rng.randrange(2**32);vis=(angle+rng.randint(-0x20000000,0x20000000))&0xffffffff;normal=(vis+rng.randint(-0x3fffffff,0x3fffffff))&0xffffffff;detail=rng.randrange(2)
        row('scale',[angle,(160>>detail)*65536,detail,vis,normal,rng.randint(1,2147483647)])
    for angle in [0,1,0x1fffffff,0x20000000,0x40000000,0x80000000,0xc0000000,0xffffffff]:
        for fixed in [0,1,31,32,33]:row('setup',[-27262976,16777216,2686976,angle,2,fixed,0])
    return out

def solidity(rows,views,synthetic,wad,nodes):
    # All existing geometry rows are transported, including every full BSP node path.
    data=b''
    fnnames=['R_PointToAngle2','R_PointOnSide','R_PointInSubsector','BSPPath','dist','seg','scale','setup']
    for scope,entries in [(0,synthetic),(1,wad),(0,rows)]:
        for row in entries:
            assert row.get('status','ok')=='ok'
            ins=row['inputs'];outs=row['outputs'];data+=bytes([fnnames.index(row['function']),scope,len(ins),len(outs)])+packed(ins+outs)
    src='// SPDX-License-Identifier: GPL-2.0-only\npragma solidity 0.8.37;\n// Generated original-C fixtures; no oracle algorithms in Solidity.\nlibrary GeometryVectors {\n'
    src+='function vectors() internal pure returns(bytes memory){return hex"'+data.hex()+'";}\n'
    src+='function nodes() internal pure returns(bytes memory){return hex"'+nodes.hex()+'";}\n'
    src+='function viewhash(uint256 i) internal pure returns(bytes32){\n'
    for i,row in enumerate(views):src+=f'if(i=={i})return hex"{row["sha256"]}";\n'
    src+='revert();}\n}\n'
    return p1.invoke([str(ROOT/'.toolchain/bin/forge'),'fmt','--root',str(ROOT),'--raw','-'],input=src).encode()

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');parser.add_argument('--wad',type=pathlib.Path,default=ROOT/'artifacts/local/freedoom/freedoom1.wad');args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='doom-phase2-geom-') as tmp:
        d=pathlib.Path(tmp);manifest=build(d)
        normal=run(d/'geomO2',rows());assert normal==run(d/'geomO0',rows());assert normal==run(d/'geomSan',rows())
        configs=[{'function':'view','inputs':[b,detail]} for b in range(3,12) for detail in range(2)]
        views=run(d/'geomO2',configs);assert views==run(d/'geomO0',configs);assert views==run(d/'geomViewSan',configs)
        audit=subprocess.run([str(d/'geomSan')],input='view 11 0\n',text=True,capture_output=True)
        assert audit.returncode and 'left shift of negative value' in audit.stderr
        undefined={'classification':'Original R_ExecuteSetViewSize shifts negative (i-viewheight/2); ISO C undefined. Equality is pinned compiler-profile evidence; port uses multiplication with identical representable results.','sanitizerDiagnostic':audit.stderr.replace(str(d),'<build>').strip(),'otherChecks':'All other sanitizer categories enabled for view setup; ordinary vectors full UBSan clean.'}
        viewhashes=[{'blocks':r['inputs'][0],'detail':r['inputs'][1],'wordCount':len(r['outputs']),'sha256':p1.sha(packed(r['outputs']))} for r in views]
        synthetic=json.loads((p1.FIXTURES/'geometry-synthetic-v1.json').read_text())['vectors'];wad=json.loads((p1.FIXTURES/'geometry-wad-v1.json').read_text())['vectors']
        assert p1.sha(args.wad.read_bytes())==json.loads((p1.FIXTURES/'geometry-wad-v1.json').read_text())['wadSha256']
        p1.wad_map(args.wad,d)
        files={'manifest.json':(json.dumps(manifest,indent=2)+'\n').encode(),'vectors.json':(json.dumps(normal,indent=2)+'\n').encode(),'view-arrays.json':(json.dumps(viewhashes,indent=2)+'\n').encode(),'undefined-audit.json':(json.dumps(undefined,indent=2)+'\n').encode(),'GeometryVectors.sol':solidity(normal,viewhashes,synthetic,wad,(d/'nodes.bin').read_bytes())}
        for name,data in files.items():
            path=FIX/name
            if args.check:assert path.read_bytes()==data,'Fixture drift '+name
            else:path.write_bytes(data)
        print(json.dumps({'extendedVectors':len(normal),'existingSyntheticVectors':len(synthetic),'existingWadVectors':len(wad),'allViewConfigurations':len(views),'native':'O0/O2 identical; full UBSan scalar; view shift-base separately audited','mode':'check' if args.check else 'generate'}))
if __name__=='__main__':main()
