#!/usr/bin/env python3
"""Run maps independently, retaining failures and resuming only frozen identities."""
import argparse,datetime,json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];TOOLS=ROOT/'tools/reference/ultimate_speedruns'
ap=argparse.ArgumentParser();ap.add_argument('--maps',default=','.join(f'E1M{i}' for i in range(1,10)));ap.add_argument('--port',type=int,default=18641);ap.add_argument('--stage',choices=['native','evm','verify','all'],default='all');ap.add_argument('--resume',action='store_true');ap.add_argument('--plan',action='store_true');ap.add_argument('--artifacts',type=Path,default=ROOT/'artifacts/local/ultimate-speedruns');a=ap.parse_args()
assert a.port>1024 and a.port<65536 and a.port not in [8545,18880,8088]
root=a.artifacts.resolve();assert root.is_relative_to(ROOT/'artifacts/local')
load=lambda p:json.loads(p.read_text())
def command(*parts):
 argv=[str(p) for p in parts];print(' '.join(argv),flush=True)
 if not a.plan:subprocess.run(argv,cwd=ROOT,check=True)
def tool(name,*parts):command('python3' if name.endswith('.py') else 'node',TOOLS/name,*parts)
failures=[]
for map_ in a.maps.split(','):
 assert map_ in [f'E1M{i}' for i in range(1,10)]
 base=root/map_
 if map_=='E1M8':base=base/'alternatives/sedlo-046'
 try:
  assert (base/'source-download').exists() and (base/'source.json').exists(),'Missing authenticated input; acquire/stage original demo first'
  if a.stage in ['native','all'] and not (base/'native-result.json').exists():tool('native.py',base)
  if not a.plan:assert (base/'native-result.json').exists(),'Run native stage first'
  if a.stage=='native':
   if not a.plan and not load(base/'native-result.json')['allProfilesExact']:tool('native-domain.mjs',base)
   continue
  normal=(base/'native-result.json').exists() and not load(base/'native-result.json')['allProfilesExact']
  if normal and not (base/'native-domain.json').exists():tool('native-domain.mjs',base)
  recording=base/'full-rate';report=recording/'evm.json'
  if a.stage in ['evm','all'] and (not report.exists() or a.resume):
   if report.exists():
    prior=load(report);assert not prior['pass'],'Completed recording already exists'
    assert not prior.get('renderFailure'),'Bounds failure requires separate diagnosis, not blind resume'
    if not a.plan:
     archive=recording/('attempt-'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'));archive.mkdir()
     for p in recording.iterdir():
      if p.is_file():os.link(p,archive/p.name)
     (archive/'frames').symlink_to('../frames',target_is_directory=True)
     (archive/'RECOVERY.txt').write_text('Frozen-source recovery evidence. Frame paths share the parent deterministic frame directory; checkpoint entries resolve by sibling filename after relocation.\n')
   tool('evm-native-domain.mjs' if normal else 'evm.mjs','--artifacts',base,'--output-prefix',recording/'evm','--port',a.port,*(['--resume'] if a.resume else []))
  if a.stage=='evm':continue
  if not a.plan:assert report.exists(),'Run EVM stage first'
  if not (base/'native-full/native-frames.json').exists():
   cache=root/'E1M1/native-full'
   if (cache/'build-O2/episode-startup').exists():tool('native-frames-cached.py','--source',base,'--output',base/'native-full','--build-cache',cache)
   else:tool('native-frames.py','--source',base,'--output',base/'native-full')
  complete=load(report)['pass'] if report.exists() else a.plan
  if complete and (a.plan or 'media' not in load(recording/'frame-manifest.json')):tool('encode.py',recording)
  tool('verify-native-domain.py' if normal else 'verify.py',base,recording,'--native-frames',base/'native-full')
  tool('pixel-domain.py',base)
 except (AssertionError,subprocess.CalledProcessError,OSError) as e:
  failures.append(dict(map=map_,error=str(e)));print(f'{map_}: preserved failure: {e}',file=sys.stderr,flush=True)
if not a.plan:
 (root/'suite-last-run.json').write_text(json.dumps(dict(UTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),stage=a.stage,maps=a.maps,failures=failures),indent=2)+'\n')
if failures:sys.exit(1)
