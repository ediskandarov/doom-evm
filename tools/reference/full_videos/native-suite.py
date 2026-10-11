#!/usr/bin/env python3
"""Bounded independent native references only; does not start EVM/video recordings."""
import concurrent.futures,subprocess,json,datetime,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;LOCAL=ROOT/'artifacts/local/full-videos'
def job(m):
 p=LOCAL/f'E1M{m}';p.mkdir(exist_ok=True);start=datetime.datetime.now(datetime.timezone.utc).isoformat();began=time.monotonic()
 with (p/'native-preparation.log').open('ab') as log:
  for name in ['native-frames.py','native-ui.py']:
   r=subprocess.run(['python3',str(HERE/name),'--map',str(m)],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
   if r.returncode:return dict(map=m,pass_=False,error=f'{name} exit{r.returncode}',startedUTC=start,endedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),elapsedSeconds=time.monotonic()-began)
 return dict(map=m,pass_=True,startedUTC=start,endedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),elapsedSeconds=time.monotonic()-began)
results=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 fs={pool.submit(job,m):m for m in range(2,10)}
 for f in concurrent.futures.as_completed(fs):
  r=f.result();results.append(r);(LOCAL/'native-suite.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(r),flush=True)
assert all(r['pass_'] for r in results)
