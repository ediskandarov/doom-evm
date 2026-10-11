#!/usr/bin/env python3
"""Goal-local measured host/RSS telemetry; no process mutation or unrelated logs."""
import argparse,json,re,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
ap=argparse.ArgumentParser();ap.add_argument('--once',action='store_true');ap.add_argument('--interval',type=int,default=30);a=ap.parse_args()
out=ROOT/'artifacts/local/ultimate-speedruns/host-telemetry.jsonl';out.parent.mkdir(parents=True,exist_ok=True)
while True:
 row={'UTC':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'disk':dict(zip(['total','used','free'],shutil.disk_usage(ROOT))),'processes':[]}
 for name,command in [('memoryBytes',['sysctl','-n','hw.memsize']),('swap',['sysctl','vm.swapusage']),('vm',['vm_stat'])]:
  p=subprocess.run(command,capture_output=True,text=True);row[name]=p.stdout.strip() if p.returncode==0 else {'unavailable':p.stderr.strip()}
 p=subprocess.run(['ps','-axo','pid,ppid,rss,%cpu,etime,command'],capture_output=True,text=True)
 if p.returncode==0:
  for line in p.stdout.splitlines():
   if (re.search(r'node tools/reference/ultimate_speedruns/(?:evm(?:-native-domain|-diagnostic)?|gameplay)\.mjs', line) or str(ROOT/'.toolchain/bin/anvil') in line) and 'ps -axo' not in line:
    parts=line.split(None,5);row['processes'].append(dict(pid=int(parts[0]),ppid=int(parts[1]),rssKiB=int(parts[2]),cpuPercent=float(parts[3]),elapsed=parts[4],ownedCommand=parts[5]))
 with out.open('a') as f:f.write(json.dumps(row)+'\n')
 print(json.dumps({'UTC':row['UTC'],'diskFreeBytes':row['disk']['free'],'ownedProcesses':row['processes']}),flush=True)
 if a.once:break
 time.sleep(a.interval)
