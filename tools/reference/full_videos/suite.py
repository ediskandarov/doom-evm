#!/usr/bin/env python3
"""Pilot-gated, independently recoverable recordings; at most two owned map jobs."""
import argparse,concurrent.futures,datetime,json,subprocess,time,shutil,signal,threading
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;LOCAL=ROOT/'artifacts/local/full-videos'
ap=argparse.ArgumentParser();ap.add_argument('--maps',default='2,3,4,5,6,7,8,9');ap.add_argument('--concurrency',type=int,default=2);ap.add_argument('--pilot',type=Path,default=LOCAL/'E1M1/pilot-short-v2');ap.add_argument('--observer',type=Path,default=LOCAL/'observer-v2');a=ap.parse_args();assert 1<=a.concurrency<=2
assert subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip()=='feat/full-speedrun-videos'
for file in ['recording.json','ui-verification.json','verification.json','media.json']:
 r=json.loads((a.pilot/file).read_text());assert r.get('pass',r.get('pass_')),('Complete verified pilot required',file)
assert json.loads((a.pilot/'rollback.json').read_text())['pass']
children=set();lock=threading.Lock();halt=threading.Event();rollback_lock=threading.Lock()
def stopping(signum,frame):
 halt.set()
 with lock:
  for p in children:
   if p.poll() is None:p.terminate()
signal.signal(signal.SIGTERM,stopping);signal.signal(signal.SIGINT,stopping)
def run(command,log,stage,windows):
 started=datetime.datetime.now(datetime.timezone.utc).isoformat();timer=time.monotonic()
 with log.open('ab') as f:
  f.write(('\nCOMMAND '+json.dumps([str(x) for x in command])+'\n').encode());f.flush()
  p=subprocess.Popen([str(x) for x in command],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT)
  with lock:children.add(p)
  try:p.wait()
  finally:
   with lock:children.discard(p)
 windows.append(dict(stage=stage,command=[str(x) for x in command],startedUTC=started,endedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),elapsedSeconds=time.monotonic()-timer,returncode=p.returncode))
 assert p.returncode==0,(stage,p.returncode,str(log))
def job(m):
 out=LOCAL/f'E1M{m}/complete-short-v1';out.mkdir(parents=True,exist_ok=True);log=out/'pipeline.log';windows=[];begin=datetime.datetime.now(datetime.timezone.utc).isoformat();timer=time.monotonic()
 try:
  if halt.is_set():raise RuntimeError('Suite interrupted')
  record=out/'recording.json'
  if not record.exists() or not json.loads(record.read_text())['pass']:
   cmd=['node',HERE/'record-short.mjs','--map',str(m),'--observer',a.observer,'--output',out]
   if (out/'checkpoint.json').exists():cmd.append('--resume')
   elif m in [2,6]:cmd+=['--fork-checkpoint',LOCAL/f'E1M{m}/complete-v2']
   run(cmd,log,'EVM recording',windows)
  run(['python3',HERE/'native-frames.py','--map',str(m)],log,'native gameplay',windows)
  run(['python3',HERE/'native-short-ui.py','--map',str(m)],log,'native UI',windows)
  # rollback runner resolves the artifact specified by this recording's identity.
  with rollback_lock:run(['node',HERE/'rollback.mjs',out],log,'storage rollback',windows)
  run(['python3',HERE/'verify-ui.py',out],log,'native UI/melt verification',windows)
  if not (out/'media.json').exists():run(['python3',HERE/'encode.py',out],log,'MP4 encoding',windows)
  run(['python3',HERE/'verify.py',out],log,'final verification',windows)
  result=dict(map=m,pass_=True,recording=str(out.relative_to(ROOT)),startedUTC=begin,endedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),elapsedSeconds=time.monotonic()-timer,stages=windows)
 except Exception as e:result=dict(map=m,pass_=False,error=str(e),startedUTC=begin,endedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),elapsedSeconds=time.monotonic()-timer,stages=windows)
 (out/'pipeline.json').write_text(json.dumps(result,indent=2)+'\n');return result
maps=[int(x) for x in a.maps.split(',')];assert set(maps)<=set(range(2,10)) and len(set(maps))==len(maps)
start=datetime.datetime.now(datetime.timezone.utc).isoformat();timer=time.monotonic();results=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=a.concurrency) as pool:
 pending={};queue=maps[:]
 while queue or pending:
  while queue and len(pending)<a.concurrency and not halt.is_set():
   m=queue.pop(0);pending[pool.submit(job,m)]=m
  done=[f for f in pending if f.done()]
  for f in done:result=f.result();results.append(result);pending.pop(f);print(json.dumps(result),flush=True)
  free=shutil.disk_usage(ROOT).free
  if free<4*1024**3:stopping(None,None);raise RuntimeError('Disk reserve below4GiB; owned jobs requested to checkpoint')
  (LOCAL/'short-suite.json').write_text(json.dumps(dict(startedUTC=start,results=results,queue=queue,running=list(pending.values()),diskFreeBytes=free),indent=2)+'\n')
  if halt.is_set() and not pending:break
  time.sleep(10)
report=dict(startedUTC=start,endedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),elapsedSeconds=time.monotonic()-timer,results=results,pass_=len(results)==len(maps) and all(r['pass_'] for r in results));(LOCAL/'short-suite.json').write_text(json.dumps(report,indent=2)+'\n');assert report['pass_'],report
