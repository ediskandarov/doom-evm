#!/usr/bin/env python3
"""Full original post-exit input tail, source-derived UI hold and transitions; independent profiles."""
import argparse,json,hashlib,subprocess,os,time,datetime
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
ap=argparse.ArgumentParser();ap.add_argument('--map',type=int,required=True);ap.add_argument('--profiles',default='O2,O0,sanitize');ap.add_argument('--borrow-all-ui',action='store_true');ap.add_argument('--display-history',action='store_true');a=ap.parse_args();m=a.map
base=ROOT/f'artifacts/local/ultimate-speedruns/E1M{m}'
if m==8:base=base/'alternatives/sedlo-046'
tape=json.loads((base/'tape.json').read_text());out=ROOT/f'artifacts/local/full-videos/E1M{m}'/('native-display-short-ui' if a.display_history else 'native-borrowed-short-ui' if a.borrow_all_ui else 'native-short-ui-v3');out.mkdir(parents=True,exist_ok=True)
commands=out/'commands.txt';n=json.loads((base/'native-result.json').read_text());prefix=tape['commands'][:n['executedTics']];recipe=[0] if m==8 else [0,1]+[0]*104+[1,0,1]+[0]*9
previousCommandBytes=commands.read_bytes() if commands.exists() else None
commands.write_text(''.join(f"{r['forwardmove']} {r['sidemove']} {r['angleturn']} {r['buttons']} 0\n" for r in prefix)+''.join(f'0 0 0 {b} 0\n' for b in recipe))
sha=lambda b:hashlib.sha256(b).hexdigest()
previous=out/'manifest.json'
if previous.exists():
 cached=json.loads(previous.read_text())
 valid=previousCommandBytes==commands.read_bytes() and cached.get('pass_') and set(cached['profiles'])==set(a.profiles.split(',')) and cached.get('displayHistory',False)==a.display_history and cached.get('nativeUIResourceProfile')==('all UI including ST_lib borrowed' if a.borrow_all_ui else 'legacy mixed UI: ST_lib uses physical zone')
 if valid:
  for profile,data in cached['profiles'].items():valid=valid and sha(Path(data['command'][0]).read_bytes())==data['binarySha256'] and Path(data['command'][3]).read_bytes()==commands.read_bytes()
  for f in cached['frames']:valid=valid and sha((out/f['file']).read_bytes())==f['sha256'] and sha((out/f['paletteFile']).read_bytes())==f['paletteSha256']
  if valid:print(json.dumps(dict(map=m,frames=len(cached['frames']),profiles=list(cached['profiles']),pass_=True,cached=True)));raise SystemExit(0)
report=dict(startedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),profiles={},frames=[],pass_=False)
for profile in a.profiles.split(','):
 dest=out/profile;dest.mkdir(exist_ok=True);binary=ROOT/f'artifacts/local/full-videos/{"native-display-short-ui-v2" if a.display_history else "native-borrowed-short-ui" if a.borrow_all_ui else "native-short-finale-v2" if m==8 else "native-short"}-{profile}/full-native';began=time.monotonic();env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0:halt_on_error=1','UBSAN_OPTIONS':'halt_on_error=1'};env.pop('DOOM_ORACLE_ALLOCATION_FILL',None);env.pop('FULL_CAPTURE_TIC',None)
 if a.display_history:
  g=ROOT/f'artifacts/local/full-videos/E1M{m}/native-display-history';manifest=json.loads((g/'gameplay.json').read_text());previous=manifest['frames'][f"{profile}-{n['executedTics']-1}"];env['FULL_PREVIOUS_SCREEN']=str(g/previous['file']);assert sha((g/previous['file']).read_bytes())==previous['sha256']
 cmd=[str(binary),str(ROOT/'artifacts/local/ultimate-doom/DOOM.WAD'),str(dest),str(commands),str(m),str(tape['header']['skill']),str(tape['header']['nomonsters'])];run=subprocess.run(cmd,capture_output=True,env=env);(dest/'stdout.log').write_bytes(run.stdout);(dest/'stderr.log').write_bytes(run.stderr);assert run.returncode==0 and not run.stderr,(profile,run.stderr.decode())
 files=sorted(dest.glob('*.indexed8'));rows=[]
 for file in files:
  seq,kind,demoTic,gameplayTic,rng,stage,count=map(int,file.stem.split('-'));pixels=file.read_bytes();pal=(dest/f'palette-{seq:06d}.bin').read_bytes();rows.append(dict(frameId=seq,kind=kind,demoTic=demoTic,gameplayTic=gameplayTic,rng=rng,stage=stage,count=count,file=str(file.relative_to(out)),sha256=sha(pixels),paletteFile=str((dest/f'palette-{seq:06d}.bin').relative_to(out)),paletteSha256=sha(pal)))
 if profile=='O2':report['frames']=rows
 else:
  assert len(rows)==len(report['frames'])
  for expected,actual in zip(report['frames'],rows):
   assert {k:v for k,v in expected.items() if k not in ['file','paletteFile']}=={k:v for k,v in actual.items() if k not in ['file','paletteFile']},(profile,actual['frameId'],'native presentation divergence')
 report['profiles'][profile]=dict(command=cmd,binarySha256=sha(binary.read_bytes()),frames=len(rows),elapsedSeconds=time.monotonic()-began)
 (out/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
if m==8:assert sum(f['kind']==4 and f['stage']==1 for f in report['frames'])==105,'Complete original finale art hold'
report['displayHistory']=a.display_history
report['nativeUIResourceProfile']='all UI including ST_lib borrowed' if a.borrow_all_ui else 'legacy mixed UI: ST_lib uses physical zone'
report.update(pass_=True,endedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat());(out/'manifest.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(dict(map=m,frames=len(report['frames']),profiles=list(report['profiles']),pass_=True)))
