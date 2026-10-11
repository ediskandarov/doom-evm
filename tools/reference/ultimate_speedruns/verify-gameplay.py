#!/usr/bin/env python3
"""Independent full-tape gameplay proof; never accepts this as rendered video."""
import argparse,gzip,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'tools/reference/speedrun'))
from verify_video import states,dynamic,sha
ap=argparse.ArgumentParser();ap.add_argument('base',type=Path);a=ap.parse_args();base=a.base.resolve();out=base/'gameplay'
load=lambda p:json.loads(p.read_text());r=load(out/'evm.json');n=load(base/'native-result.json');domain=load(base/'native-domain.json')
assert r['kind']=='real-classic-ultimate-doom-evm-gameplay-only' and r['pass'] and r['ownedRuntimeStopped'] and r['exit']['reached']
assert r['memoryProfile']=='virtual' and r['nativeDomain']==domain and domain['pass']
assert sha((base/'native-result.json').read_bytes())==domain['nativeResultSha256']
assert all(p['allStateBytesEqual'] for p in domain['profiles'] if p['name']!='sanitize-fill')
assert not r['frames'] and not r['totalCaptureGas'] and r['captureTransactionCount']==0
native=states(gzip.decompress((base/'native-states.delta.bin.gz').read_bytes()),True)
actual=states(gzip.decompress((out/'evm.states.bin.gz').read_bytes()))
assert actual==native and len(actual)==n['executedTics']+1==r['verifiedTics']+1
assert r['actualStateStreamSha256']==n['statesSha256']
demo=(base/'source-download').read_bytes();assert sha(demo)==r['demoSha256']==n['demoSha256']
assert sha(demo[13:13+n['executedTics']*4])==r['originalCommandBytesSha256']
seen=[]
for receipt in json.loads(gzip.decompress((out/'evm.replay-receipts.json.gz').read_bytes())):
 assert receipt['status']=='0x1'
 for log in receipt['logs']:
  assert log['address']==r['deployment']['address'];data=bytes.fromhex(log['data'][2:]);tic=int.from_bytes(data[:32],'big');assert dynamic(data,32)==native[tic];seen.append(tic)
assert seen==list(range(len(native)))
for suffix,key in [('capture','captureReceiptsSha256'),('replay','replayReceiptsSha256'),('deployment','deploymentReceiptsSha256')]:assert sha((out/f'evm.{suffix}-receipts.json.gz').read_bytes())==r[key]
for file,digest in r['sourceHashes'].items():assert sha((ROOT/file).read_bytes())==digest
result=dict(pass_=True,gameplayTics=r['verifiedTics'],observations=len(actual),allOriginalCommandsAndStateBytesExact=True,exit=r['exit'],renderedFrames=0,mediaAccepted=False,nativeProfile=domain['profile'],allAllocationProfilesExact=n['allProfilesExact'],reportSha256=sha((out/'evm.json').read_bytes()),verifierSha256=sha(Path(__file__).read_bytes()))
(out/'verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
