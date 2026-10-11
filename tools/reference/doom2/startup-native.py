#!/usr/bin/env python3
"""Extract comparison-only commercial startup observations from native replay runs."""
import gzip,hashlib,importlib.util,json,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
spec=importlib.util.spec_from_file_location('zone',ROOT/'tools/reference/phase3_zone_lifecycle/reference.py');zone=importlib.util.module_from_spec(spec);spec.loader.exec_module(zone)
sha=lambda b:hashlib.sha256(b).hexdigest()
out=ROOT/'artifacts/local/doom2/startup';out.mkdir(exist_ok=True)
pin=json.loads((ROOT/'artifacts/doom2/resource-pin.json').read_text());cases=[];files={}
for map_ in [1,7]:
 base=ROOT/f'artifacts/local/doom2/MAP{map_:02d}';result=json.loads((base/'native-result.json').read_text());assert result['exitReached'] and result['allProfilesExact']
 name=f'MAP{map_:02d}-skill3';baseline=None
 for profile in ['O2','O0','sanitize','sanitize-fill']:
  native=base/f'native-{profile}';states=gzip.decompress((native/'states.bin.gz').read_bytes());n=struct.unpack_from('>I',states)[0]
  data={k:(native/k).read_bytes() for k in ['collision.bin','flow.bin','difficulty.bin']};data['world.bin']=states[4:4+n]
  stages=[json.loads(x) for x in (native/'zone-stages.jsonl').read_bytes().splitlines()];events=[json.loads(x) for x in (native/'zone-events.jsonl').read_bytes().splitlines()]
  stage=next(x for x in stages if x['stage']=='after_P_Setup');data['zone.bin']=zone.startup_outputs(events,stage)['startup-headers.bin']
  if baseline is None:baseline=data
  else:assert data==baseline,(name,profile)
 for filename,payload in baseline.items():
  p=out/name/filename;p.parent.mkdir(exist_ok=True);p.write_bytes(payload);files[name+'/'+filename]=sha(payload)
 cases.append(dict(name=name,map=map_,skill=3,nomonsters=False,summary=json.loads((base/'native-O2/summary.json').read_text()),files={n:dict(bytes=len(b),sha256=sha(b)) for n,b in baseline.items()}))
manifest=dict(status='O0/O2/ASan+UBSan exact',resourceIdentity=pin['resourceIdentity'],cases=cases,files=files,scope='Original G_InitNew/G_DoLoadLevel/P_SetupLevel commercial startup; comparison-only native bytes')
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');(ROOT/'artifacts/doom2/startup-native.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(dict(pass_=True,cases=len(cases))))
