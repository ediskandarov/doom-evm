#!/usr/bin/env python3
"""Original unchanged m_bbox.c clear/add streams, including source else-if quirk."""
import argparse,json,pathlib,random,subprocess,tempfile,sys
HERE=pathlib.Path(__file__).resolve().parent;sys.path.insert(0,str(HERE.parent));import reference as ref
FIXTURES=ref.ROOT/'test/fixtures/phase3_bbox'

def cases():
 low=-(1<<31);high=(1<<31)-1
 rows=[[],[(0,0)],[(3,7),(2,6),(1,5)],[(0,0),(0,0)],[(high,low),(low,high)],[(low,low),(low,low),(high,high)],[(high,high),(high,high),(low,low)],[(i,-i)for i in range(-16,17)],[(i,i)for i in range(16,-17,-1)]]
 rng=random.Random(0x42424f58)
 for _ in range(512):rows.append([(rng.randrange(low,high+1),rng.randrange(low,high+1)) for i in range(rng.randrange(1,33))])
 return rows

def main():
 p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args();assert ref.invoke(['git','-C',str(ref.SOURCE),'rev-parse','HEAD']).strip()==ref.UPSTREAM;ref.invoke(['git','-C',str(ref.SOURCE),'diff','--exit-code','HEAD','--']);assert ref.invoke(['clang','--version']).splitlines()[:2]==[ref.VERSION,'Target: '+ref.TARGET]
 rows=cases();inputs=''.join(str(len(row))+' '+' '.join(f'{x} {y}'for x,y in row)+'\n'for row in rows);base=None
 with tempfile.TemporaryDirectory(prefix='doom-bbox-')as td:
  compatibility='#include <limits.h>\n#include "doomtype.h"\n';(pathlib.Path(td)/'values.h').write_text(compatibility)
  for name,opt,sanitize in [('O0','O0',False),('O2','O2',False),('strict','O2',True)]:
   binary=pathlib.Path(td)/name;flags=[('-'+opt if f=='-O2'else f)for f in ref.FLAGS if f!='-fwrapv']
   if sanitize:flags+=['-fsanitize=address,undefined','-fno-sanitize-recover=all']
   ref.invoke(['clang',*flags,'-I'+td,'-I'+str(ref.SOURCE),str(ref.SOURCE/'m_bbox.c'),str(HERE/'driver.c'),'-o',str(binary)])
   r=subprocess.run([str(binary)],input=inputs.encode(),capture_output=True);assert r.returncode==0 and not r.stderr,(name,r.stderr.decode())
   if base is None:base=r.stdout
   else:assert base==r.stdout,(name,'mismatch')
 metadata=dict(portabilityHeader=dict(name='values.h',text=compatibility,sha256=ref.sha(compatibility.encode()),reason='macOS lacks old values.h; original doomtype.h provides exact MININT/MAXINT constants'),upstreamCommit=ref.UPSTREAM,compiler=ref.VERSION,target=ref.TARGET,profiles=['O0 without -fwrapv','O2 without -fwrapv','O2 full ASan/UBSan without -fwrapv'],sourceFunctions=['M_ClearBox','M_AddToBox'],streams=len(rows),points=sum(map(len,rows)),sourceFiles={n:ref.sha((ref.SOURCE/n).read_bytes())for n in ['m_bbox.c','m_bbox.h','m_fixed.h','doomtype.h']},harnessFiles={n:ref.sha((HERE/n).read_bytes())for n in ['driver.c','reference.py']},vectorSha256=ref.sha(base),encoding='big-endian32: stream count then4clear bounds; each point x,y then4bounds; streams concatenate until EOF; native BOXTOP/BOTTOM/LEFT/RIGHT order',scope='All prefix bounds of point streams; original else-if firstpoint/decreasing-order behavior retained, no alternative geometric bounding algorithm')
 outputs={'vectors.bin':base,'manifest.json':(json.dumps(metadata,indent=2)+'\n').encode()}
 if a.check:
  for n,b in outputs.items():assert (FIXTURES/n).read_bytes()==b,'stale '+n
 else:
  for n,b in outputs.items():(FIXTURES/n).write_bytes(b)
 print(f'PASS original bbox: {len(rows)} streams/{sum(map(len,rows))} points, O0/O2/full ASan+UBSan strict exact')
if __name__=='__main__':main()
