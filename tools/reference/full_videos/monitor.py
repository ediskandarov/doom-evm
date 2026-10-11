#!/usr/bin/env python3
"""Sample host resource measurements; never signal processes or manage external environments."""
import datetime,json,subprocess,shutil,time,re,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];stop=ROOT/'artifacts/local/full-videos/monitor.stop';out=ROOT/'artifacts/local/full-videos/host.jsonl'
while not stop.exists():
 row=dict(timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),monitorPid=os.getpid(),diskFreeBytes=shutil.disk_usage(ROOT).free)
 for key,cmd in [('vmStat',['vm_stat']),('swap',['sysctl','vm.swapusage']),('processes',['ps','-axo','pid=,rss=,command='])]:
  p=subprocess.run(cmd,capture_output=True,text=True);data=p.stdout
  if key=='processes':data='\n'.join(line for line in data.splitlines() if str(ROOT) in line or 'tools/reference/full_videos/' in line or 'anvil --host 127.0.0.1 --port 1894' in line)
  row[key]=dict(returncode=p.returncode,stdout=data,stderr=p.stderr)
 with out.open('a') as f:f.write(json.dumps(row)+'\n')
 time.sleep(30)
