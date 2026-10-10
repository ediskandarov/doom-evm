#!/usr/bin/env python3
"""Remove only superseded goal-owned Anvil chain dumps after validating the head."""
import argparse,gzip,hashlib,json,time,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
ap=argparse.ArgumentParser();ap.add_argument('roots',nargs='+',type=Path);ap.add_argument('--audit-log',type=Path,default=ROOT/'artifacts/local/ultimate-speedruns/checkpoint-cleanup.jsonl');a=ap.parse_args();removed=[]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def sibling(pointer,file,digest):
 p=pointer.parent/Path(file).name
 assert p.is_file() and not p.is_symlink() and sha(p)==digest, str(p)+' checkpoint identity mismatch'
 return p.resolve()
for root in a.roots:
 root=root.resolve();assert '/artifacts/local/' in str(root)
 for pointer in root.rglob('evm.checkpoint.json'):
  c=json.loads(pointer.read_text());keep={pointer.resolve()}
  if c['schemaVersion']==2:
   keep.add(sibling(pointer,c['chain']['file'],c['chain']['sha256']))
   for item in c['receipts'].values():keep.add(sibling(pointer,item['file'],item['sha256']))
  else:
   keep.add(sibling(pointer,c['payload'],c['payloadSha256']))
  for p in pointer.parent.glob('evm.checkpoint-*'):
   if p.resolve() in keep or p.name.endswith('.tmp'):continue
   match=re.match(r'^evm\.checkpoint-(\d+)\.',p.name)
   # A live runner can finish a new file just before atomically advancing its
   # pointer. Never remove that future checkpoint or any current-tic file.
   if not match or int(match[1])>=c['tic']:continue
   assert p.is_file() and not p.is_symlink()
   if not any(p.name.endswith(suffix) for suffix in ['.chain.gz','.bin.gz','.deployment.json.gz','.replay.json.gz','.capture.json.gz']):continue
   size=p.stat().st_size;digest=sha(p);p.unlink();removed.append(dict(file=str(p),bytes=size,sha256=digest,reason='Superseded Anvil dump or duplicate checkpoint receipts; latest pointer, state and receipts verified and retained; final proof receipts unaffected'))
log=a.audit_log;log.parent.mkdir(parents=True,exist_ok=True)
with log.open('a') as f:f.write(json.dumps(dict(UTC=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),removed=removed))+'\n')
print(json.dumps(dict(removed=len(removed),bytesFreed=sum(r['bytes'] for r in removed))))
