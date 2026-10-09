#!/usr/bin/env python3
"""Deterministically add test-only trace writes to exact production BSP source."""
import argparse,hashlib,json,pathlib,re,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[3]
FIX=ROOT/'test/fixtures/phase2_bsp'
HELPER='''
    // TEST ONLY. BSP does not otherwise access framebuffer/fuzzpos. Never render with this copy.
    function _trace(RenderContext memory ctx,uint8 op,int32 a,int32 b) private pure {
        uint256 p=ctx.rs.fuzzpos;
        require(p+9<=30000 && ctx.rs.framebuffer.length>=30000,"trace capacity");
        ctx.rs.framebuffer[p]=bytes1(op);
        for(uint256 j;j<4;++j){ctx.rs.framebuffer[p+1+j]=bytes1(uint8(uint32(a)>>(24-j*8)));ctx.rs.framebuffer[p+5+j]=bytes1(uint8(uint32(b)>>(24-j*8)));}
        ctx.rs.fuzzpos=uint32(p+9);
    }
'''
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args()
 path=ROOT/'src/doom/r_bsp.sol';source=path.read_text();text=source;records=[]
 hooks=[('_enter',0,'bspnum','0'),('R_Subsector',1,'int32(num)','0'),('R_ClipSolidWallSegment',2,'first','last'),('R_ClipPassWallSegment',3,'first','last'),('_storeWall',4,'first','last')]
 for fn,op,a,b in hooks:
  matches=list(re.finditer(r'\bfunction '+fn+r'\s*\(',text));assert len(matches)==1,(fn,len(matches))
  start=text.index('{',matches[0].end());hook=f'\n        _trace(ctx,{op},{a},{b});'
  text=text[:start+1]+hook+text[start+1:];records.append({'function':fn,'operation':op,'statement':hook.strip()})
 assert text.count('library R_BSP {')==1;text=text.replace('library R_BSP {','library InstrumentedR_BSP {')
 text=text.replace('from "./','from "../../../src/doom/')
 text=text[:text.rindex('}')]+HELPER+text[text.rindex('}'):]
 text='// GENERATED TEST INSTRUMENTATION. DO NOT IMPORT INTO PRODUCTION.\n'+text
 p=subprocess.run([str(ROOT/'.toolchain/bin/forge'),'fmt','--raw','-'],input=text,text=True,capture_output=True,check=True);out=p.stdout.encode()
 manifest={'productionSource':'src/doom/r_bsp.sol','productionSha256':hashlib.sha256(source.encode()).hexdigest(),'generatorSha256':hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),'generatedSha256':hashlib.sha256(out).hexdigest(),'hooks':records,'onlyOtherChanges':['library name','relative import paths','private observation writer'],'testStorage':'framebuffer bytes0..29999 and fuzzpos; unused by production BSP; callbacks use disjoint bytes30000+ and framecount/validcount'}
 for name,data in {'InstrumentedR_BSP.sol':out,'instrumentation.json':(json.dumps(manifest,indent=2)+'\n').encode()}.items():
  if args.check:assert (FIX/name).read_bytes()==data,'Stale instrumentation '+name
  else:(FIX/name).write_bytes(data)
 print('PASS deterministic production-derived BSP trace instrumentation' if args.check else 'Generated production-derived BSP trace instrumentation')
if __name__=='__main__':main()
