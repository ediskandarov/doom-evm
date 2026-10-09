#!/usr/bin/env python3
"""Original r_draw.c oracle; no drawing algorithm is rewritten by the host."""
import argparse, importlib.util, json, pathlib, random, re, struct, subprocess, tempfile
HERE=pathlib.Path(__file__).resolve().parent
ROOT=HERE.parents[2]
spec=importlib.util.spec_from_file_location('phase1_reference',HERE.parent/'reference.py')
base=importlib.util.module_from_spec(spec); spec.loader.exec_module(base)
SOURCE=ROOT/'original/DOOM/linuxdoom-1.10/r_draw.c'
FIX=ROOT/'test/fixtures/phase2_draw'
FUNCTIONS=['R_DrawColumn','R_DrawColumnLow','R_DrawTranslatedColumn','R_DrawFuzzColumn','R_DrawSpan','R_DrawSpanLow','R_InitBuffer','R_InitTranslationTables','R_VideoErase']
def extract(text,name):
    m=re.search(r'\nvoid\s+'+name+r'\s*\(',text); assert m,name
    start=m.start()+1; p=text.index('{',m.end())+1; depth=1
    while depth:
        if text[p]=='{': depth+=1
        if text[p]=='}': depth-=1
        p+=1
    body=text[start:p]
    return body,{'function':name,'startLine':text[:start].count('\n')+1,'endLine':text[:p].count('\n')+1,'sha256':base.sha(body.encode())}
def cases():
    rows=[]; rng=random.Random(0x44524157)
    def row(op,**kw):
        d=dict(op=op,width=320,height=200,x=13,yl=0,yh=199,iscale=65536,texturemid=100*65536,offset=0,xfrac=0,yfrac=0,xstep=65536,ystep=0,reserved=0,fuzzpos=0,centery=100)
        d.update(kw); rows.append({'inputs':list(d.values()),'semantics':'defined-C'})
    for op in [0,1]:
        row(op,x=0); row(op,x=159 if op else 319,yl=199,yh=199,texturemid=-65536)
        row(op,yl=42,yh=41) # empty before any pointer dereference
        row(op,width=256,height=128,x=100,yl=0,yh=127,centery=64,offset=31)
        for _ in range(12):
            lo=rng.randrange(200); row(op,x=rng.randrange(160 if op else 320),yl=lo,yh=rng.randrange(lo,200),iscale=rng.randint(-200000,200000),texturemid=rng.randint(-10000000,10000000),offset=rng.choice([0,1,31,128,511]))
    for offset,mid,step,lo,hi in [(128,-128*65536,65536,0,199),(31,0,65536,0,0),(0,0,65536,0,199),(4096,10*65536,-65536,0,199)]:
        row(2,offset=offset,texturemid=mid,iscale=step,yl=lo,yh=hi,centery=0)
    for pos in [0,1,24,48,49]: row(3,fuzzpos=pos)
    row(3,yl=0,yh=0); row(3,yl=199,yh=199); row(3,yl=25,yh=75,fuzzpos=49)
    for op in [4,5]:
        row(op,x=0,yl=0,yh=79 if op==5 else 319,xfrac=-65536,yfrac=-65536)
        row(op,x=199,yl=159 if op==5 else 319,yh=159 if op==5 else 319)
        row(op,width=256,height=128,x=100,yl=0,yh=60,xfrac=-123456,yfrac=-65536,xstep=-31001,ystep=72001)
        for _ in range(16):
            lo=rng.randrange(80 if op==5 else 160)
            row(op,x=rng.randrange(199),yl=lo,yh=lo+rng.randrange(70 if op==5 else 150),xfrac=rng.randint(-10000000,10000000),yfrac=rng.randint(-10000000,10000000),xstep=rng.randint(-2000000,2000000),ystep=rng.randint(-2000000,2000000))
    # Defined pointer accesses despite the original low span crossing a scanline.
    row(5,x=50,yl=80,yh=159)
    for ofs,n in [(0,0),(0,64000),(31,33),(63999,1)]: row(6,yl=ofs,yh=n)
    row(7)
    for width,height in [(320,200),(320,168),(256,128),(96,48),(1,1)]: row(8,width=width,height=height)
    # Deliberate signed accumulation overflow: pinned -fwrapv extensions, excluded from UBSan defined-C claim.
    row(0,texturemid=2147483647,iscale=2147483647); rows[-1]['semantics']='pinned-fwrapv-extension'
    row(4,x=5,yl=0,yh=319,xfrac=2147483647,yfrac=-2147483648,xstep=2147483647,ystep=-2147483648); rows[-1]['semantics']='pinned-fwrapv-extension'
    return rows

def run(binary,rows):
    p=subprocess.run([str(binary)],input=(''.join(' '.join(map(str,r['inputs']))+'\n' for r in rows)).encode(),capture_output=True,check=True)
    output=p.stdout; offset=0; results=[]
    for row in rows:
        a=row['inputs']; n=64000+32+4*(a[1]+a[2]); data=output[offset:offset+n]; assert len(data)==n
        pixels=data[:64000]; state=list(struct.unpack('<8i',data[64000:64032])); arrays=data[64032:]
        results.append(dict(row,pixelsSha256=base.sha(pixels),state=state,lookupSha256=base.sha(arrays)))
        offset+=n
    assert offset==len(output)
    return results

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--check',action='store_true'); args=ap.parse_args()
    assert base.invoke(['git','-C',str(SOURCE.parent),'rev-parse','HEAD']).strip()==base.UPSTREAM
    version=base.invoke(['clang','--version']).splitlines(); assert version[0]==base.VERSION and version[1]=='Target: '+base.TARGET
    assert base.sha(SOURCE.read_bytes())=='b19edd950d3d56d2d1d6168677d6345c190f081baa8269bfac3d2f3920a36a96','original r_draw.c modified'
    text=SOURCE.read_text(); units=[]; records=[]
    for name in FUNCTIONS:
        body,record=extract(text,name); records.append(record)
        if name=='R_InitTranslationTables':
            old='( (int)translationtables + 255 )& ~255'; new='( (uintptr_t)translationtables + 255 )& ~(uintptr_t)255'
            assert body.count(old)==1; body=body.replace(old,new)
        units.append(body)
    fuzz=re.search(r'int\s+fuzzoffset\[FUZZTABLE\]\s*=\s*\{.*?\};',text,re.S).group()
    generated='#include "compat.h"\n'+fuzz+'\n'+'\n'.join(units)+'\n#include "driver.c"\n'
    rows=cases()
    with tempfile.TemporaryDirectory(prefix='doom-draw-') as tmp:
        tmp=pathlib.Path(tmp); cfile=tmp/'draw.c'; cfile.write_text(generated)
        for opt in ['O0','O2','sanitize']:
            flags=[('-O0' if opt=='O0' and f=='-O2' else f) for f in base.FLAGS]
            if opt=='sanitize': flags=[f for f in flags if f!='-fwrapv']+['-fsanitize=undefined,address','-fno-sanitize-recover=all']
            base.invoke(['clang',*flags,'-I'+str(HERE),str(cfile),'-o',str(tmp/opt)])
        result=run(tmp/'O2',rows); assert result==run(tmp/'O0',rows)
        defined=[r for r in rows if r['semantics']=='defined-C']
        assert [r for r in result if r['semantics']=='defined-C']==run(tmp/'sanitize',defined)
    packed=b''
    for r in result: packed+=struct.pack('>16i',*r['inputs'])+bytes.fromhex(r['pixelsSha256'])+struct.pack('>8i',*r['state'])+bytes.fromhex(r['lookupSha256'])
    doc={'upstreamCommit':base.UPSTREAM,'sourceSha256':base.sha(SOURCE.read_bytes()),'compiler':base.VERSION,'target':base.TARGET,'flags':base.FLAGS,'extractions':records,'generatedSourceSha256':base.sha(generated.encode()),'harnessSha256':base.sha(pathlib.Path(__file__).read_bytes()),'hostHashes':{n:base.sha((HERE/n).read_bytes()) for n in ['compat.h','driver.c']},'hostAdaptation':'Only translation allocation pointer alignment changes int cast/mask to uintptr_t for 64-bit host; loop body unchanged. Resource buffers are deterministic synthetic byte patterns, not replacement drawing routines.','vectors':result,'O0O2':'identical','definedUBSanASan':'clean'}
    source='// SPDX-License-Identifier: GPL-2.0-only\npragma solidity 0.8.37;\n// Generated by original r_draw.c native oracle. 160-byte records.\nlibrary DrawVectors { function data() internal pure returns(bytes memory) { return hex"'+packed.hex()+'"; } }\n'
    source=base.invoke([str(ROOT/'.toolchain/bin/forge'),'fmt','--root',str(ROOT),'--raw','-'],input=source)
    for name,content in {'vectors.json':json.dumps(doc,indent=2)+'\n','DrawVectors.sol':source}.items():
        path=FIX/name
        if args.check: assert path.read_text()==content,'drift '+str(path)
        else:path.write_text(content)
    print(json.dumps({'cases':len(rows),'defined':len(defined),'extension':len(rows)-len(defined),'O0O2':'identical','UBSanASan':'clean on defined cases'}))
if __name__=='__main__': main()
