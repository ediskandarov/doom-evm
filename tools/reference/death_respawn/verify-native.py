#!/usr/bin/env python3
"""Reproduce focused independent original-C goldens without modifying fixtures."""
import argparse,datetime,hashlib,json,os,struct,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
ap=argparse.ArgumentParser();ap.add_argument('--reuse-builds',action='store_true');a=ap.parse_args()
base=ROOT/'artifacts/local/death-respawn';base.mkdir(parents=True,exist_ok=True)
sha=lambda b:hashlib.sha256(b).hexdigest()
report={'startedUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'pass':False,'cases':{},'builds':{}}
start=time.monotonic()
for profile,opt,san in [('O0','O0',False),('O2','O2',False),('sanitize','O2',True)]:
 out=base/'native'/profile
 if not a.reuse_builds:
  cmd=[sys.executable,str(HERE/'native.py'),'--output',str(out),'--opt',opt]+(['--sanitize'] if san else [])
  run=subprocess.run(cmd,capture_output=True);(base/f'verify-build-{profile}.log').write_bytes(run.stdout+run.stderr);assert run.returncode==0,run.stderr.decode()
 manifest=json.loads((out/'death-build.json').read_text());assert manifest['deathBuilderSha256']==sha((HERE/'native.py').read_bytes()),'stale native build'
 report['builds'][profile]={'manifestSha256':sha((out/'death-build.json').read_bytes()),'binarySha256':sha((out/'death-respawn').read_bytes())}
 for case in ['environment','monster']:
  dest=base/'native-verification'/case/profile;dest.mkdir(parents=True,exist_ok=True)
  cmd=[str(out/'death-respawn'),str(ROOT/'artifacts/local/freedoom/freedoom1.wad'),str(dest),str(ROOT/f'test/fixtures/death_respawn/{case}-commands.txt'),'1','3','0']
  r=subprocess.run(cmd,capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'});(dest/'stdout.log').write_bytes(r.stdout);(dest/'stderr.log').write_bytes(r.stderr);assert r.returncode==0 and not r.stderr,(case,profile,r.stderr.decode())
  d=(dest/'states.bin').read_bytes();offset=0;states=[]
  while offset<len(d):
   n=struct.unpack_from('>I',d,offset)[0];offset+=4;states.append(d[offset:offset+n]);offset+=n
  fixture='environment-display' if case=='environment' else case
  expected=(ROOT/f'test/fixtures/death_respawn/{fixture}-hashes.bin').read_bytes();hashes=[]
  for i,state in enumerate(states[1:],1):
   hashes.append(hashlib.sha256(state).digest())
   for name in ['frame','palette']:
    p=dest/f'{name}-{i:06d}.bin';hashes.append(hashlib.sha256(p.read_bytes()).digest() if p.exists() else bytes(32))
  assert b''.join(hashes)==expected,(case,profile,'golden mismatch')
  events=[json.loads(s) for s in (dest/'zone-events.jsonl').read_text().splitlines()]
  info={'tics':len(states)-1,'completeWorldSnapshots':len(states)-1,'frames':len(list(dest.glob('frame-*.bin'))),'hashesSha256':sha(expected),'zoneOperations':len(events),'mallocs':sum(e['op']=='malloc' for e in events),'frees':sum(e['op']=='free' for e in events),'command':cmd}
  report['cases'].setdefault(case,{})[profile]=info
  print('PASS native',case,profile,info['tics'],'tics',info['frames'],'full frames',flush=True)
report.update({'pass':True},endedUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),seconds=time.monotonic()-start,scope='Independent original C O0/O2/ASan+UBSan, full pointer-free canonical world and complete indexed framebuffer/palette digests. Physical native zone traces retained; no universal pointer/unknown-byte equivalence or melt orchestration claim.')
(base/'native-verification.json').write_text(json.dumps(report,indent=2)+'\n')
