#!/usr/bin/env python3
"""Reject EVM mismatches in the common native domain outside virtual-source pixels."""
import argparse,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
ap=argparse.ArgumentParser();ap.add_argument('base',type=Path);a=ap.parse_args();base=a.base.resolve();recording=base/'full-rate'
load=lambda p:json.loads(p.read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
r=load(recording/'evm.json');nr=load(base/'native-full/native-frames.json')
frames={f['tic']:f for f in nr['frames']};profiles={p['name']:p for p in nr['profiles']};assert set(profiles)=={'O2','O0','sanitize'}
assert all(len(p['captures'])>=r['executedTics'] and all(c['preRenderWorldExact'] for c in p['captures']) for p in profiles.values())
byprofile={name:{c['tic']:c for c in p['captures']} for name,p in profiles.items()};rows=[];common=unsupported=virtual=0
for f in r['frames']:
 tic=f['tic'];evm=(recording/f['file']).read_bytes();original=(base/'native-full'/frames[tic]['file']).read_bytes();assert len(evm)==len(original)==64000
 native=[original]
 for name in ['O0','sanitize']:
  entry=byprofile[name][tic]
  native.append(original if entry['sha256']==hashlib.sha256(original).hexdigest() else (base/'native-full'/f'{name}-frame-{tic:06d}.indexed8').read_bytes())
 for name,pixels in zip(['O2','O0','sanitize'],native):assert hashlib.sha256(pixels).hexdigest()==byprofile[name][tic]['sha256']
 touched={s['y']*320+s['x'] for s in f['virtualSamples']};checked=unknown=0
 for i,(x,y,z,e) in enumerate(zip(*native,evm)):
  if x==y==z and i not in touched:
   assert e==x, f'Genuine supported-pixel divergence tic{tic} offset{i}: native{x} EVM{e}'
   checked+=1
  elif i not in touched:unknown+=1
 common+=checked;unsupported+=unknown;virtual+=len(touched)
 rows.append(dict(tic=tic,commonNativePixelsChecked=checked,nativeAllocationDependentPixels=unknown,virtualTouchedDestinations=len(touched)))
result=dict(verifierSha256=sha(Path(__file__)),pass_=True,recordingComplete=bool(r['pass']),frames=len(rows),commonNativePixelsChecked=common,nativeAllocationDependentPixels=unsupported,virtualTouchedDestinations=virtual,allCommonNativePixelsOutsideVirtualSourcesExact=True,wholeFrameCommonNativeExact=sum(x['commonNativePixelsChecked']==64000 for x in rows),limits='Virtual destinations count any provenance4 draw use, including overwritten samples; they are not a claim that all final values survive. Allocation-dependent native pixels are outside universal comparison. Every EVM pixel remains receipt-authenticated.',rows=rows,sourceReportSha256=sha(recording/'evm.json'),nativeReportSha256=sha(base/'native-full/native-frames.json'))
(recording/'pixel-domain.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='rows'}))
