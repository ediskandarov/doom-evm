#!/usr/bin/env python3
"""Aggregate only independently verified selected map outcomes and local proofs."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];root=ROOT/'artifacts/ultimate-speedruns';rows=[];proofs=[]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for i in range(1,10):
 map_=f'E1M{i}';base=root/map_
 if i==8:base=base/'alternatives/sedlo-046'
 r=json.loads((base/'result.json').read_text());manifest=json.loads((base/'evidence-manifest.json').read_text());assert r['map']==map_ and r['EVMGameplay']['allSnapshotsExact']
 for item in manifest['files']:
  p=ROOT/item['path'];assert p.exists() and p.stat().st_size==item['bytes'] and sha(p)==item['SHA256'],item['path']
 complete=r.get('unresolvedFailure') is None
 pixel=r.get('supportedPixelDomain') or r['frames'].get('supportedPixelDomain')
 if pixel is None:
  local=ROOT/'artifacts/local/ultimate-speedruns'/map_/'full-rate/pixel-domain.json';pixel=json.loads(local.read_text());assert pixel['pass_']
  proofs.append(dict(path=str(local.relative_to(ROOT)),bytes=local.stat().st_size,SHA256=sha(local)))
 assert pixel['pass_'] and pixel['frames']==r['frames']['rendered']
 rows.append(dict(map=map_,status='complete35fps' if complete else 'rendering-blocked',demo=r['demo'],nativeTics=r['nativeReplay']['tics'],nativeAllAllocationProfilesExact=r['nativeReplay']['allAllocationProfilesExact'],EVMGameplayTics=r['EVMGameplay']['tics'],exactGameplayObservations=r['EVMGameplay']['observations'],EVMFrames=r['frames']['rendered'],allThreeNativeWholeFramesEqual=r['frames']['allDeclaredNativeProfilesEqual'],commonNativePixelsOutsideVirtualSources=pixel['commonNativePixelsChecked'],virtualSampleUses=r['frames']['virtualSampleUses'],virtualTouchedDestinations=r['frames']['virtualDerivedDestinations'],mainRecordingGas=r['gas']['totalVerifiedRecording'] if complete else r['gas']['partialRecording'],separateCompleteGameplayGas=0 if complete else r['gas']['completeSeparateGameplay'],MP4=r['media']['MP4'] if complete else None,rejectedTic=None if complete else r['frames']['firstRejectedTic'],result=str((base/'result.json').relative_to(ROOT)),evidence=str((base/'evidence-manifest.json').relative_to(ROOT))))
 proofs.append(dict(path=str((base/'evidence-manifest.json').relative_to(ROOT)),bytes=(base/'evidence-manifest.json').stat().st_size,SHA256=sha(base/'evidence-manifest.json')))
assert all(r['EVMGameplayTics']==r['nativeTics'] for r in rows)
summary=dict(profile='classic-ultimate-doom-1.9',memoryProfile='integrated-experimental-virtual-pointer',IWAD=dict(MD5='c4fe9fd920207691a9f493668e0a2083',SHA256='6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f'),maps=rows,totals=dict(fullRateRecordings=sum(r['status']=='complete35fps' for r in rows),renderingBlockedMaps=sum(r['status']=='rendering-blocked' for r in rows),nativeAndEVMGameplayTics=sum(r['nativeTics'] for r in rows),exactGameplayObservations=sum(r['exactGameplayObservations'] for r in rows),renderedFrames=sum(r['EVMFrames'] for r in rows),completeRecordingFrames=sum(r['EVMFrames'] for r in rows if r['status']=='complete35fps'),commonNativePixelsOutsideVirtualSources=sum(r['commonNativePixelsOutsideVirtualSources'] for r in rows),virtualSampleUses=sum(r['virtualSampleUses'] for r in rows),virtualTouchedDestinations=sum(r['virtualTouchedDestinations'] for r in rows),selectedRecordingAttemptGas=sum(r['mainRecordingGas'] for r in rows),separateBlockedMapGameplayGas=sum(r['separateCompleteGameplayGas'] for r in rows)),proofs=proofs,limits='Finite native profiles only. Allocation-fill gates stay failed for E1M3/E1M5; strict whole DSG1 matches named normal C profile. Virtual-derived destinations are a deterministic extension. Accepted partial frames are not complete recordings. Gas totals cover selected recording proofs and listed separate gameplay runs, excluding diagnostic/extra failed attempts and unmeasured interrupted work. MP4s are lossy presentation; raw indexed8 is receipt-authenticated. No universal native pixel, production browser/UI or continuously persisted renderer-history claim.')
(root/'episode-summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary['totals']))
