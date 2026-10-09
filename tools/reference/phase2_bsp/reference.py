#!/usr/bin/env python3
"""Original r_bsp clipping oracle and exact full-render trace bindings."""
import argparse,importlib.util,json,pathlib,random,re,struct,tempfile
HERE=pathlib.Path(__file__).resolve().parent
ROOT=HERE.parents[2]
FIX=ROOT/'test/fixtures/phase2_bsp'
spec=importlib.util.spec_from_file_location('p1',HERE.parent/'reference.py');ref=importlib.util.module_from_spec(spec);spec.loader.exec_module(ref)
def extract(name):
 text=(ref.SOURCE/'r_bsp.c').read_text();m=re.search(r'\nvoid\s+'+name+r'\s*\(',text);assert m,name
 start=m.start()+1;end=text.index('{',m.end())+1;depth=1
 while depth:
  if text[end]=='{':depth+=1
  elif text[end]=='}':depth-=1
  end+=1
 body=text[start:end]
 return body,{'file':'r_bsp.c','function':name,'startLine':text[:start].count('\n')+1,'endLine':text[:end].count('\n')+1,'sha256':ref.sha(body.encode())}
def commands():
 rng=random.Random(0x42535032);rows=[]
 def add(op,a,b=0):rows.append([op,a,b])
 for width in [1,2,32,160,320]:
  add('clear',width);add('pass',0,width-1);add('solid',0,width-1);add('pass',0,width-1);add('solid',0,width-1)
 for scenario in range(30):
  add('clear',320)
  for first,last in [(20,40),(80,100),(140,160),(200,220)]:add('solid',first,last)
  for first,last in [(0,19),(41,79),(101,139),(161,199),(221,319),(0,319),(40,80),(20,20),(319,319)]:add('pass',first,last)
  for _ in range(20):
   first=rng.randrange(320);last=rng.randrange(first,320);add('solid' if rng.randrange(2) else 'pass',first,last)
 return rows

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args()
 assert ref.invoke(['git','-C',str(ref.SOURCE),'rev-parse','HEAD']).strip()==ref.UPSTREAM
 ref.invoke(['git','-C',str(ref.SOURCE),'diff','--exit-code','HEAD','--','r_bsp.c'])
 version=ref.invoke(['clang','--version']).splitlines();assert version[:2]==[ref.VERSION,'Target: '+ref.TARGET]
 units=[];records=[]
 for fn in ['R_ClipSolidWallSegment','R_ClipPassWallSegment','R_ClearClipSegs']:
  body,record=extract(fn);units.append(body);records.append(record)
 source='#include "compat.h"\n'+'\n'.join(units)+'\n#include "driver.c"\n'
 commands_=commands();stdin=''.join(' '.join(map(str,r))+'\n' for r in commands_)
 with tempfile.TemporaryDirectory(prefix='doom-bsp-oracle-') as tmp:
  d=pathlib.Path(tmp);(d/'oracle.c').write_text(source);runs={}
  for opt in ['O0','O2','sanitize']:
   flags=[('-O0' if opt=='O0' and f=='-O2' else f) for f in ref.FLAGS if f!='-fwrapv']
   if opt=='sanitize':flags+=['-fsanitize=address,undefined','-fno-sanitize-recover=all']
   ref.invoke(['clang',*flags,'-I'+str(HERE),str(d/'oracle.c'),'-o',str(d/opt)])
   runs[opt]=ref.invoke([str(d/opt)],input=stdin)
  assert runs['O0']==runs['O2']==runs['sanitize']
 lines=runs['O2'].splitlines();assert len(lines)==len(commands_)
 clip=[];binary=bytearray()
 for cmd,line in zip(commands_,lines):
  left,right=line.split('|');parts=left.split();assert parts[0]==cmd[0];ranges=list(map(int,parts[1:]));state=list(map(int,right.split()));assert len(ranges)%2==0 and len(state)==1+2*state[0]
  clip.append({'operation':cmd[0],'inputs':cmd[1:],'wallRanges':ranges,'solidRanges':state[1:]})
  binary+=struct.pack('>BiiBB',['clear','solid','pass'].index(cmd[0]),*cmd[1:],len(ranges)//2,state[0])+b''.join(struct.pack('>i',x) for x in ranges+state[1:])
 manifest=json.loads((ROOT/'test/fixtures/renderer/manifest.json').read_text());tracefiles={};cases=[]
 assert manifest['upstreamCommit']==ref.UPSTREAM
 names=['R_RenderBSPNode','R_Subsector','R_ClipSolidWallSegment','R_ClipPassWallSegment','R_StoreWallRange']
 for angle in range(8):
  name=f'full-angle{angle}';case=next(c for c in manifest['cases'] if c['name']==name)
  assert case['mode']=='full' and case['angle']==angle*0x20000000
  text=(ROOT/f'test/fixtures/renderer/{name}/trace.txt').read_bytes();assert ref.sha(text)==case['traceSha256']==manifest['files'][name+'/trace.txt']
  blob=bytearray()
  for line in text.decode().splitlines():
   fn,a,b=line.split();assert fn in names;blob+=struct.pack('>Bii',names.index(fn),int(a),int(b))
  tracefiles[f'{name}.bin']=bytes(blob);cases.append({'name':name,'mode':'full','angle':case['angle'],'traceSha256':case['traceSha256'],'packedSha256':ref.sha(blob),'events':len(blob)//9})
 meta={'upstreamCommit':ref.UPSTREAM,'compiler':ref.VERSION,'target':ref.TARGET,'sourceSha256':ref.sha((ref.SOURCE/'r_bsp.c').read_bytes()),'extractions':records,'generatedSourceSha256':ref.sha(source.encode()),'harnessSha256':{n:ref.sha((HERE/n).read_bytes()) for n in ['reference.py','compat.h','driver.c']},'clipRows':len(clip),'clipProfiles':'O0/O2 and ASan/UBSan without fwrapv identical','rendererManifestSha256':ref.sha((ROOT/'test/fixtures/renderer/manifest.json').read_bytes()),'cases':cases}
 outputs={'clip.bin':bytes(binary),'clip.json':(json.dumps(clip,indent=2)+'\n').encode(),'manifest.json':(json.dumps(meta,indent=2)+'\n').encode(),**tracefiles}
 for name,data in outputs.items():
  p=FIX/name
  if args.check:assert p.read_bytes()==data,'Fixture drift '+name
  else:p.write_bytes(data)
 print(json.dumps({'clipRows':len(clip),'fullNativeTraceCases':len(cases),'mode':'check' if args.check else 'generate'}))
if __name__=='__main__':main()
