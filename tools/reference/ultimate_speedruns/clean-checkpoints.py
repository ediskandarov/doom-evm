#!/usr/bin/env python3
"""Remove only superseded goal-owned Anvil chain dumps after validating the head."""
import argparse,gzip,hashlib,json,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
ap=argparse.ArgumentParser();ap.add_argument('roots',nargs='+',type=Path);a=ap.parse_args();removed=[]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for root in a.roots:
 root=root.resolve();assert '/artifacts/local/' in str(root)
 for pointer in root.rglob('evm.checkpoint.json'):
  c=json.loads(pointer.read_text());keep={pointer.resolve()}
  if c['schemaVersion']==2:
   assert sha(Path(c['chain']['file']))==c['chain']['sha256'];keep.add(Path(c['chain']['file']).resolve())
   for item in c['receipts'].values():assert sha(Path(item['file']))==item['sha256'];keep.add(Path(item['file']).resolve())
  else:
   assert sha(Path(c['payload']))==c['payloadSha256'];keep.add(Path(c['payload']).resolve())
  for p in pointer.parent.glob('evm.checkpoint-*'):
   if p.resolve() in keep or p.name.endswith('.tmp'):continue
   assert p.is_file() and not p.is_symlink()
   if not any(p.name.endswith(suffix) for suffix in ['.chain.gz','.bin.gz','.deployment.json.gz','.replay.json.gz','.capture.json.gz']):continue
   size=p.stat().st_size;digest=sha(p);p.unlink();removed.append(dict(file=str(p),bytes=size,sha256=digest,reason='Superseded Anvil dump or duplicate checkpoint receipts; latest pointer, state and receipts verified and retained; final proof receipts unaffected'))
log=ROOT/'artifacts/local/ultimate-speedruns/checkpoint-cleanup.jsonl';log.parent.mkdir(parents=True,exist_ok=True)
with log.open('a') as f:f.write(json.dumps(dict(UTC=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),removed=removed))+'\n')
print(json.dumps(dict(removed=len(removed),bytesFreed=sum(r['bytes'] for r in removed))))
