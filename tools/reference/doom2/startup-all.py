#!/usr/bin/env python3
"""Bounded all-map startup only; no 32-map gameplay/speedrun acceptance."""
import argparse,hashlib,importlib.util,json,os,struct,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('zone',ROOT/'tools/reference/phase3_zone_lifecycle/reference.py');zone=importlib.util.module_from_spec(spec);spec.loader.exec_module(zone)
base=ROOT/'artifacts/local/doom2/startup-all';base.mkdir(exist_ok=True);commands=base/'empty-commands.txt';commands.write_text('')
wad=Path.home()/'Downloads/doom-steam/base/doom2/DOOM2.WAD';assert sha(wad.read_bytes())=='10d67824b11025ddd9198e8cfc87ca335ee6e2d3e63af4180fa9b8a471893255'
cases=[];files={};started=time.time()
for map_ in range(1,33):
 name=f'MAP{map_:02d}-skill2';baseline=None
 for profile in ['O2','O0','sanitize']:
  dest=base/name/profile;dest.mkdir(parents=True,exist_ok=True);binary=ROOT/f'artifacts/local/doom2/native-build-{profile}/speedrun';cmd=[str(binary),str(wad),str(dest),str(commands),str(map_),'2','0']
  r=subprocess.run(cmd,capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'});(dest/'stdout.log').write_bytes(r.stdout);(dest/'stderr.log').write_bytes(r.stderr);assert r.returncode==0 and not r.stderr,(name,profile,r.stderr.decode())
  states=(dest/'states.bin').read_bytes();n=struct.unpack_from('>I',states)[0];assert len(states)==n+4
  data={k:(dest/k).read_bytes() for k in ['collision.bin','flow.bin','difficulty.bin']};data['world.bin']=states[4:]
  stages=[json.loads(x) for x in (dest/'zone-stages.jsonl').read_bytes().splitlines()];events=[json.loads(x) for x in (dest/'zone-events.jsonl').read_bytes().splitlines()];stage=next(x for x in stages if x['stage']=='after_P_Setup');data['zone.bin']=zone.startup_outputs(events,stage)['startup-headers.bin']
  if baseline is None:baseline=data
  else:assert data==baseline,(name,profile)
 for filename,payload in baseline.items():(base/name/filename).write_bytes(payload);files[name+'/'+filename]=sha(payload)
 cases.append(dict(name=name,map=map_,skill=2,nomonsters=False,summary=json.loads((dest/'summary.json').read_text()),files={n:dict(bytes=len(b),sha256=sha(b)) for n,b in baseline.items()}));print('PASS native startup',name,flush=True)
manifest=dict(status='O0/O2/ASan+UBSan exact',resourceIdentity=json.loads((ROOT/'artifacts/doom2/resource-pin.json').read_text())['resourceIdentity'],cases=cases,files=files,startUnix=started,endUnix=time.time(),scope='32 commercial map startup observations only; no gameplay ticks, renderer or map completion claim')
(base/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');(ROOT/'artifacts/doom2/startup-all-native.json').write_text(json.dumps(manifest,indent=2)+'\n')
