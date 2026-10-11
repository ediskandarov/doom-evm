#!/usr/bin/env python3
"""Read-only final nine-map acceptance, source/media bindings and preservation gates."""
import datetime,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];PUB=ROOT/'artifacts/full-videos';LOCAL=ROOT/'artifacts/local/full-videos'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text())
expected=[316,798,1291,767,2110,3385,2572,1638,1598];maps=[]
for m,n in enumerate(expected,1):
 out=LOCAL/f'E1M{m}'/('pilot-short-v2' if m==1 else 'complete-short-v1');r=load(out/'recording.json')
 gates={name:load(out/(name+'.json')) for name in ['verification','ui-verification','media','rollback','state-verification','visual-qa']}
 assert r['pass'] and r['ownedRuntimeStopped'] and r['gameplayTics']==n and r['gameplayCaptures']==n and r['nativeGameplayComparisons']==n+1
 for name in ['verification','ui-verification','media']:assert gates[name]['pass_']
 for name in ['rollback','state-verification']:assert gates[name]['pass']
 assert gates['visual-qa']['visuallyReviewed'] and gates['state-verification']['noFieldsMasked']
 assert gates['state-verification']['matchingGameplaySnapshots']==n+1 and gates['state-verification']['recordingManifestSHA256']==sha(out/'recording.json')
 assert len(r['frames'])==sum(r[k] for k in ['gameplayFrames','menuFrames','wipeFrames','intermissionFrames','finaleFrames'])
 assert r['gameplayFrames']==n-1 and r['menuFrames']==35 and not r.get('nextLevelGameplayTics',0)
 assert all(t['status']=='0x1' for t in r['transactions'])
 assert sum(t['gas'] for t in r['transactions'])==r['totalGas']
 assert gates['media']['frames']==len(r['frames']) and gates['media']['allPacketClocksExact'] and sha(Path(gates['media']['path']))==gates['media']['sha256']
 assert gates['verification']['finalFrameNativePixelDifferences']==0 and gates['ui-verification']['allPixelsAndPalettesExact']
 assert gates['rollback']['ownedRuntimeStopped'] and len(gates['rollback']['checks'])==5
 assert all(c['allSavedAndPresentationFieldsUnchanged'] and c['noLogs'] for c in gates['rollback']['checks'])
 for file,digest in r['identity']['sourceHashes'].items():assert sha(ROOT/file)==digest,(m,file)
 assert r['identity']['resourceIdentity']['wadSha256']=='6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f'
 recipe=[0,1]+[0]*104+[1,0,1]+[0]*9
 if m!=8:
  assert r['intermissionFrames']==117 and r['finaleFrames']==0 and [x['buttons'] for x in r['postExitInputs']]==recipe
  endpoint=gates['rollback']['recordingEndpoint'];assert endpoint['wiState']==-1 and endpoint['remainingNoStateTics']==1 and not endpoint['worldDoneRequested']
  assert not endpoint['G_WorldDoneVerified'] and not endpoint['nextLevelStartupVerified']
 else:
  assert not r['intermissionFrames'] and r['frames'][-1]['kind']==4 and r['frames'][-1]['stage']==1
  assert sum(f['kind']==4 and f['stage']==1 for f in r['frames'])==105 and r['wipeFrames']==121
  assert all(x['buttons']==0 for x in r['postExitInputs'])
 maps.append(dict(map=m,pass_=True,recording=str(out.relative_to(ROOT)),recordingSHA256=sha(out/'recording.json'),gameplayTics=n,snapshots=n+1,frames=len(r['frames']),gas=r['totalGas'],gateHashes={k:sha(out/(k+'.json')) for k in gates}))
history=load(PUB/'historical-preservation.json');assert history['pass_'] and history['historicalIndexedFramesVerified']==14475 and len(history['originalInputs'])==9
assert sha(LOCAL/'E1M1/pilot-v2/ultimate-e1m1-complete.mp4')=='6d65e321e75f3c787fc31dc758d7460b1f4cd25f27e0b193e1d7f204a82d12f4'
focused=load(PUB/'focused/summary.json');assert focused['totalFocusedTestsVerified']==54 and focused['recheckFailures']==0
wipe=load(PUB/'wipe/verification.json');assert wipe['forgeTests']==8 and wipe['failed']==0 and wipe['nativeSteps']==178
adapter=load(PUB/'handoff-metadata-audit.json');assert sha(ROOT/'src/support/FullSpeedrunProbe.sol')==adapter['consumerSourceSHA256'] and not adapter['G_WorldDoneVerified'] and not adapter['nextLevelStartupVerified']
diagnosis=load(PUB/'diagnostics/E1M2-allocation-divergence.json');assert diagnosis['classification']==2 and diagnosis['unchangedEVMSourceAndMemoryProvenance']
for binding in diagnosis['bindings']:assert sha(ROOT/binding['file'])==binding['sha256'],binding['file']
report=dict(pass_=True,verifiedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),scope='Nine standalone EVM recordings; finite declared native gameplay/UI/wipe/finale comparisons; independent full-state receipts; status/UI/gameflow/statistics/palette/media/source/input/persistence/rollback/preservation gates. No browser integration, G_WorldDone/startup or full historical suite claim.',gameplayTics=sum(x['gameplayTics'] for x in maps),matchingGameplaySnapshots=sum(x['snapshots'] for x in maps),frames=sum(x['frames'] for x in maps),gas=sum(x['gas'] for x in maps),maps=maps,preservedLongPilotSHA256=sha(LOCAL/'E1M1/pilot-v2/ultimate-e1m1-complete.mp4'),historicalPreservationSHA256=sha(PUB/'historical-preservation.json'),focusedTestsSHA256=sha(PUB/'focused/summary.json'),wipeProofSHA256=sha(PUB/'wipe/verification.json'),handoffAdapterAuditSHA256=sha(PUB/'handoff-metadata-audit.json'))
assert report['gameplayTics']==14475 and report['matchingGameplaySnapshots']==14484
report['allocationDiagnosisSHA256']=sha(PUB/'diagnostics/E1M2-allocation-divergence.json')
(PUB/'acceptance.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='maps'}))
