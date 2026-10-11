#!/usr/bin/env python3
"""Summarize existing periodic host observations; no additional runtime instrumentation."""
import hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];p=ROOT/'artifacts/local/full-videos/host.jsonl'
rows=[json.loads(line) for line in p.read_text().splitlines()];anvil=[];recorder=[];swap=[]
for row in rows:
 for line in row['processes']['stdout'].splitlines():
  match=re.match(r'\s*(\d+)\s+(\d+)\s+(.+)',line)
  if not match:continue
  pid,rss,command=match.groups();sample=dict(timeUTC=row['timeUTC'],pid=int(pid),RSSBytes=int(rss)*1024)
  if re.search(r'anvil --host 127\.0\.0\.1 --port (1894[1-9]|18959)\b',command):anvil.append(sample)
  elif re.search(r'node .*full_videos/record(?:-short(?:-finale)?)?\.mjs\b',command):recorder.append(sample)
 match=re.search(r'used = ([0-9.]+)M',row['swap']['stdout'])
 if match:swap.append(float(match[1]))
def maximum(samples):return max(samples,key=lambda x:x['RSSBytes']) if samples else None
report=dict(samples=len(rows),startedUTC=rows[0]['timeUTC'],endedUTC=rows[-1]['timeUTC'],hostLog=str(p.relative_to(ROOT)),hostLogSHA256=hashlib.sha256(p.read_bytes()).hexdigest(),minimumObservedDiskFreeBytes=min(x['diskFreeBytes'] for x in rows),maximumObservedOwnedAnvilRSS=maximum(anvil),maximumObservedRecorderRSS=maximum(recorder),maximumObservedSystemSwapUsedMiB=max(swap) if swap else None,samplingIntervalSeconds=30,scope='Observed samples across the goal, including pilots/diagnostics/native verification. RSS is per observed owned process, not combined simultaneous memory. System swap includes other users of the host and is not attributed exclusively to EVM. Sampling maxima are not guaranteed process peaks. No CPU-time estimate or EVM behavior instrumentation.')
(ROOT/'artifacts/full-videos/host-summary.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
