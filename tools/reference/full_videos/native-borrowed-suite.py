#!/usr/bin/env python3
"""Separate native profile references; preserve legacy goldens and EVM recordings."""
import argparse,concurrent.futures,datetime,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;LOCAL=ROOT/'artifacts/local/full-videos'
ap=argparse.ArgumentParser();ap.add_argument('--maps',default='1,3,4,5,6,7,8,9');ap.add_argument('--concurrency',type=int,default=2);ap.add_argument('--display-history',action='store_true');a=ap.parse_args();assert 1<=a.concurrency<=2
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def job(m):
 out=LOCAL/f'E1M{m}';out.mkdir(exist_ok=True);started=datetime.datetime.now(datetime.timezone.utc).isoformat();timer=time.monotonic();stages=[]
 with (out/'native-borrowed-suite.log').open('ab') as log:
  for name in ['native-frames.py','native-short-ui.py']:
   cmd=['python3',str(HERE/name),'--map',str(m),'--borrow-all-ui',*(['--display-history'] if a.display_history else [])];began=time.monotonic();p=subprocess.run(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT);stages.append(dict(command=cmd,returncode=p.returncode,elapsedSeconds=time.monotonic()-began));assert p.returncode==0,(m,name)
 g=out/('native-display-history' if a.display_history else 'native-borrowed-ui');u=out/('native-display-short-ui' if a.display_history else 'native-borrowed-short-ui');target=out/('pilot-short-v2' if m==1 else 'complete-short-v1');target.mkdir(exist_ok=True)
 for old in ['verification.json','ui-verification.json']:
  p=target/old;q=target/old.replace('.json','-legacy-native.json')
  if p.exists() and not q.exists():q.write_bytes(p.read_bytes())
 selection=dict(displayHistory=a.display_history,profile='LP64 initialized64MiB zone; all ST/HU/WI borrowed immutable UI resources including ST_lib; temporary per-gameplay render; original source gameplay/WI/finale/melt'+('; original differential ST/HU display history and independent native prior screens' if a.display_history else ''),gameplayDirectory=str(g.relative_to(ROOT)),presentationDirectory=str(u.relative_to(ROOT)),gameplayManifestSHA256=sha(g/'gameplay.json'),presentationManifestSHA256=sha(u/'manifest.json'),reason='Separate native reference matches declared borrowed UI resources and display cadence. EVM frame/source/provenance unchanged.',originalNativeReferencesPreserved=True)
 (target/'native-profile.json').write_text(json.dumps(selection,indent=2)+'\n');result=dict(map=m,startedUTC=started,endedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),elapsedSeconds=time.monotonic()-timer,stages=stages,selection=selection,pass_=True);(out/'native-borrowed-preparation.json').write_text(json.dumps(result,indent=2)+'\n');return result
maps=[int(x) for x in a.maps.split(',')];assert len(set(maps))==len(maps) and set(maps)<=set(range(1,10));results=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=a.concurrency) as pool:
 for r in pool.map(job,maps):results.append(r);print(json.dumps(dict(map=r['map'],pass_=r['pass_'],elapsedSeconds=r['elapsedSeconds'])),flush=True)
(LOCAL/('native-display-suite.json' if a.display_history else 'native-borrowed-suite.json')).write_text(json.dumps(dict(results=results,pass_=all(r['pass_'] for r in results)),indent=2)+'\n')
