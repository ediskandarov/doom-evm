#!/usr/bin/env python3
"""Summarize actual captured host measurements and hash-bound cleanup audit."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];base=ROOT/'artifacts/local/ultimate-speedruns'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
tele=base/'host-telemetry.jsonl';clean=base/'checkpoint-cleanup.jsonl'
rows=[json.loads(x) for x in tele.read_text().splitlines()];assert rows
reclaim=next((i for i in range(1,len(rows)) if rows[i-1]['disk']['free']<5*1024**3 and rows[i]['disk']['free']>10*1024**3),None)
post=rows[reclaim:] if reclaim is not None else rows
node=[p['rssKiB'] for r in post for p in r['processes'] if p['ownedCommand'].startswith('node ')]
anvil=[p['rssKiB'] for r in post for p in r['processes'] if '.toolchain/bin/anvil' in p['ownedCommand'] and p['ownedCommand'].startswith('/')]
removed=[r for line in clean.read_text().splitlines() for r in json.loads(line)['removed']]
result=dict(measuredUTC=[rows[0]['UTC'],rows[-1]['UTC']],samples=len(rows),physicalMemoryBytes=int(rows[-1]['memoryBytes']) if str(rows[-1]['memoryBytes']).isdigit() else None,initialSwap=rows[0]['swap'],finalSwap=rows[-1]['swap'],beforeDiskPauseMinFreeBytes=min(r['disk']['free'] for r in rows[:reclaim]) if reclaim is not None else None,firstPostReclaimMeasurementUTC=post[0]['UTC'],firstPostReclaimDiskFreeBytes=post[0]['disk']['free'],minimumPostReclaimDiskFreeBytes=min(r['disk']['free'] for r in post),finalDiskFreeBytes=rows[-1]['disk']['free'],maximumCapturedOwnedNodeRSSKiB=max(node) if node else None,maximumCapturedOwnedAnvilRSSKiB=max(anvil) if anvil else None,cleanup=dict(removedFiles=len(removed),measuredBytesFreed=sum(r['bytes'] for r in removed)),logs=[dict(path=str(p.relative_to(ROOT)),bytes=p.stat().st_size,SHA256=sha(p)) for p in [tele,clean]],limitations='Captured process RSS samples only, not universal execution high-water memory. Native workers and independent verifier RSS are not fully sampled. Infrastructure changes/configuration are in runtime-notes.json and each map result. No inferred gas-to-memory conversion, unmeasured resource/time estimate, or episode-specific API cost/token attribution.')
(ROOT/'artifacts/ultimate-speedruns/host-summary.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
