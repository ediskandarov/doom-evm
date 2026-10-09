#!/usr/bin/env python3
"""Mechanically extracted original r_plane/r_draw oracle, never a rewritten renderer."""
import argparse,importlib.util,json,pathlib,struct,subprocess,tempfile
HERE=pathlib.Path(__file__).resolve().parent;ROOT=HERE.parents[2];FIX=ROOT/'test/fixtures/phase2_planes'
spec=importlib.util.spec_from_file_location('geometry',HERE.parent/'phase2_geometry/reference.py');geom=importlib.util.module_from_spec(spec);spec.loader.exec_module(geom);ref=geom.p1

def rows():
 out=[]
 def row(*v):out.append(list(v))
 for detail in [0,1]:
  for angle in [0,0x40000000,0xffffffff]:
   for height,fixed in [(0,-1),(65536,-1),(100*65536,-1),(2147483647,-1),(65536,0),(65536,32)]:row(0,height,3,1,6,fixed,angle,detail,0,0)
  for height,distance,clear in [(65536,123456,0),(0,123456,1),(0,-65536,1),(65536,-65536,0)]:row(0,height,2,0,7,-1,0,detail,distance,clear)
  for t1,b1,t2,b2 in [(255,0,1,5),(1,5,255,0),(1,5,2,4),(2,4,1,5),(1,3,4,6),(4,6,1,3),(255,77,255,88),(0,7,0,7),(0,7,255,7)]:row(1,7,t1,b1,t2,-1,0,detail,b2,0)
  for sky in [0,1]:
   for light,extra in [(-32,-10),(0,0),(128,1),(320,99)]:
    for fixed in [-1,32]:row(2,4*65536,sky,light,extra,fixed,0xffffffff,detail,0,0)
 row(3,0,0,0,0,-1,0,0,0,0)
 return out

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args()
 assert ref.invoke(['git','-C',str(ref.SOURCE),'rev-parse','HEAD']).strip()==ref.UPSTREAM
 ref.invoke(['git','-C',str(ref.SOURCE),'diff','--exit-code','HEAD','--','r_plane.c','r_draw.c','m_fixed.c','tables.c'])
 assert ref.invoke(['clang','--version']).splitlines()[:2]==[ref.VERSION,'Target: '+ref.TARGET]
 units=[];records=[];shims=[]
 functions=[('m_fixed.c',n,'fixed_t') for n in ['FixedMul','FixedDiv','FixedDiv2']]+[('r_draw.c',n,'void') for n in ['R_DrawColumn','R_DrawColumnLow','R_DrawSpan','R_DrawSpanLow']]+[('r_plane.c',n,t) for n,t in [('R_InitPlanes','void'),('R_MapPlane','void'),('R_ClearPlanes','void'),('R_FindPlane','visplane_t*'),('R_CheckPlane','visplane_t*'),('R_MakeSpans','void'),('R_DrawPlanes','void')]]
 for file,fn,typ in functions:
  body,record=geom.extract(file,fn,typ);records.append(record)
  if fn=='R_DrawPlanes':
   for field in ['top','bottom']:
    before='pl->'+field+'[';after='((byte*)pl+offsetof(visplane_t,'+field+'))[';count=body.count(before);assert count== (5 if field=='top' else 3),(field,count)
    body=body.replace(before,after);shims.append({'before':before,'after':after,'count':count,'reason':'Original enclosing-object sentinel pad addresses; avoid array-subobject bounds UB.'})
  units.append(body)
 source='#include "compat.h"\n'+'\n'.join(units)+'\n#include "driver.c"\n'
 vectors=rows();outputs=[]
 with tempfile.TemporaryDirectory(prefix='doom-plane-oracle-') as tmp:
  d=pathlib.Path(tmp);(d/'oracle.c').write_text(source)
  for profile in ['O0','O2','sanitize']:
   flags=[('-O0' if profile=='O0' and f=='-O2' else f) for f in ref.FLAGS]
   if profile=='sanitize':flags+=['-fsanitize=address,undefined','-fno-sanitize-recover=all']
   ref.invoke(['clang',*flags,'-I'+str(HERE),'-I'+str(ref.SOURCE),str(d/'oracle.c'),str(ref.SOURCE/'tables.c'),'-o',str(d/profile)])
   run=[subprocess.check_output([str(d/profile),*map(str,r)]) for r in vectors]
   if outputs:assert outputs==run,profile
   else:outputs=run
 data=b''.join(geom.packed(r)+bytes.fromhex(ref.sha(o)) for r,o in zip(vectors,outputs))
 native=json.loads((ROOT/'test/fixtures/renderer/manifest.json').read_text());cases=[]
 for n in range(8):
  name=f'full-angle{n}';case=next(c for c in native['cases'] if c['name']==name);assert case['mode']=='full' and case['angle']==n*0x20000000
  frame=(ROOT/f'test/fixtures/renderer/{name}/plane-pixels.bin').read_bytes();sha=ref.sha(frame);assert sha==native['files'][name+'/plane-pixels.bin']
  cases.append(dict(case,planePixelsSha256=sha))
 meta={'upstreamCommit':ref.UPSTREAM,'compiler':ref.VERSION,'target':ref.TARGET,'profiles':['O0 -fwrapv','O2 -fwrapv','O2 ASan/UBSan -fwrapv'],'extractions':records,'shims':shims,'sourceSha256':{n:ref.sha((ref.SOURCE/n).read_bytes()) for n in ['r_plane.c','r_draw.c','m_fixed.c','tables.c']},'generatedSourceSha256':ref.sha(source.encode()),'harnessSha256':{n:ref.sha((HERE/n).read_bytes()) for n in ['reference.py','compat.h','driver.c']},'vectorCount':len(vectors),'vectorsSha256':ref.sha(data),'rendererManifestSha256':ref.sha((ROOT/'test/fixtures/renderer/manifest.json').read_bytes()),'resourceIdentity':native['resourceIdentity'],'cases':cases}
 files={'vectors.bin':data,'vectors.json':(json.dumps([dict(inputs=r,stateSha256=ref.sha(o),stateBytes=len(o)) for r,o in zip(vectors,outputs)],indent=2)+'\n').encode(),'manifest.json':(json.dumps(meta,indent=2)+'\n').encode()}
 for name,blob in files.items():
  path=FIX/name
  if args.check:assert path.read_bytes()==blob,'Fixture drift '+name
  else:path.write_bytes(blob)
 print(json.dumps({'nativeVectors':len(vectors),'planeSnapshots':len(cases),'mode':'check' if args.check else 'generate'}))
if __name__=='__main__':main()
