#!/usr/bin/env python3
"""Stop only this goal's exact browser-final command and its spawned process tree."""
import json,os,signal,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
rows=subprocess.check_output(['ps','-axo','pid=,ppid=,command='],text=True).splitlines();processes={}
for row in rows:
 parts=row.strip().split(None,2)
 if len(parts)==3:processes[int(parts[0])]=(int(parts[1]),parts[2])
expected='node tools/reference/doom2/browser.mjs --port 19073 --http-port 19072 --output-prefix artifacts/local/doom2/browser-final/real'
parents=[pid for pid,(ppid,cmd) in processes.items() if cmd==expected];assert len(parents)<=1,parents
owned=set(parents)
while True:
 children={pid for pid,(ppid,cmd) in processes.items() if ppid in owned};before=len(owned);owned|=children
 if len(owned)==before:break
for pid in sorted(owned-set(parents),reverse=True)+parents:
 try:os.kill(pid,signal.SIGTERM)
 except ProcessLookupError:pass
record=dict(exactCommand=expected,measuredUTC=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),processes=[dict(pid=pid,ppid=processes[pid][0],command=processes[pid][1]) for pid in sorted(owned)],reason='Inherited lifecycle test left diagnostic config in shared source tree; isolated staging copied it and bypassed launcher. Stop only the owned final-browser attempt before correcting staging.')
(ROOT/'artifacts/local/doom2/browser-final/cleanup.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(dict(stoppedOwnedProcesses=len(owned),parents=parents)))
