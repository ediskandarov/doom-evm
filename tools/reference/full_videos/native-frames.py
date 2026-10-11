#!/usr/bin/env python3
"""Fresh original-C prefix per gameplay tic; persistent UI ticker, temporary renderer.

Store all native O2 pixels; retain O0/sanitizer divergences rather than masking
native pointer bytes. Observe canonical pre-render snapshots with only the
separately tracked miscellaneous presentation RNG normalized to the baseline.
"""
import argparse,hashlib,json,gzip,sys,subprocess,tempfile,os,time,datetime
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
sys.path.insert(0,str(HERE.parent/'speedrun'));from verify_video import states
sha=lambda b:hashlib.sha256(b).hexdigest()
ap=argparse.ArgumentParser();ap.add_argument('--map',type=int,default=1);ap.add_argument('--profiles',default='O2,O0,sanitize');ap.add_argument('--tics',default='all');a=ap.parse_args()
base=ROOT/f'artifacts/local/ultimate-speedruns/E1M{a.map}'
if a.map==8:base=base/'alternatives/sedlo-046'
info=json.loads((base/'native-result.json').read_text());tape=json.loads((base/'tape.json').read_text());ref=states(gzip.decompress((base/'native-states.delta.bin.gz').read_bytes()),True)
out=ROOT/f'artifacts/local/full-videos/E1M{a.map}/native';out.mkdir(parents=True,exist_ok=True)
tics=list(range(1,info['executedTics']+1)) if a.tics=='all' else list(map(int,a.tics.split(',')))
path=out/'gameplay.json';report=json.loads(path.read_text()) if path.exists() else dict(startedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),frames={},profiles={},pass_=False)
for name in a.profiles.split(','):
 build=ROOT/f'artifacts/local/full-videos/native-{name}'
 if not (build/'full-native').exists():subprocess.run(['python3',HERE/'native-build.py','--output',build,'--opt','O0' if name=='O0' else 'O2',*(['--sanitize'] if name=='sanitize' else [])],check=True)
 report['profiles'][name]=dict(binarySha256=sha((build/'full-native').read_bytes()),manifestSha256=sha((build/'full-manifest.json').read_bytes()))
 for tic in tics:
  key=f'{name}-{tic}'
  if key in report['frames']:continue
  began=time.monotonic()
  with tempfile.TemporaryDirectory(dir=out) as tmp:
   tmp=Path(tmp);commands=tmp/'commands.txt';commands.write_text(''.join(f"{r['forwardmove']} {r['sidemove']} {r['angleturn']} {r['buttons']} 0\n" for r in tape['commands'][:tic]))
   env={**os.environ,'FULL_CAPTURE_TIC':str(tic),'ASAN_OPTIONS':'detect_leaks=0:halt_on_error=1','UBSAN_OPTIONS':'halt_on_error=1'};env.pop('DOOM_ORACLE_ALLOCATION_FILL',None)
   cmd=[build/'full-native',ROOT/'artifacts/local/ultimate-doom/DOOM.WAD',tmp,commands,str(a.map),str(tape['header']['skill']),str(tape['header']['nomonsters'])]
   run=subprocess.run(cmd,capture_output=True,env=env);assert run.returncode==0 and not run.stderr,(name,tic,run.stderr.decode())
   worlds=states((tmp/'states.bin').read_bytes(),False);assert len(worlds)==2 and worlds[0]==ref[0] and worlds[1]==ref[tic],(name,tic,'canonical state mismatch')
   pixels=(tmp/f'gameplay-{tic:06d}.indexed8').read_bytes();pal=(tmp/f'gameplay-{tic:06d}.palette').read_bytes();assert len(pixels)==64000 and len(pal)==768
   file=f'gameplay-{tic:06d}.indexed8';paletteFile=f'gameplay-{tic:06d}.palette'
   if name=='O2':(out/file).write_bytes(pixels);(out/paletteFile).write_bytes(pal)
   else:
    expected=(out/file).read_bytes();assert pal==(out/paletteFile).read_bytes(),(name,tic,'palette mismatch')
    if pixels!=expected:
     file=f'{name}-'+file;(out/file).write_bytes(pixels)
   report['frames'][key]=dict(tic=tic,profile=name,sha256=sha(pixels),file=file,paletteFile=paletteFile,paletteSha256=sha(pal),wholeGameplayExact=True,elapsedSeconds=time.monotonic()-began,stdoutSha256=sha(run.stdout))
  path.write_text(json.dumps(report,indent=2)+'\n')
  if tic%25==0 or tic==tics[-1]:print(f'PASS E1M{a.map} native {name} {tic}',flush=True)
report.update(pass_=all(f'{name}-{tic}' in report['frames'] for name in a.profiles.split(',') for tic in tics),endedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat());path.write_text(json.dumps(report,indent=2)+'\n')
