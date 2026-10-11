#!/usr/bin/env python3
"""Bind the inherited279-frame Freedoom virtual-profile regression to receipts."""
import gzip,hashlib,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'tools/reference/speedrun'))
from verify_video import states,dynamic,FRAME_TOPIC
sha=lambda b:hashlib.sha256(b).hexdigest()
b=ROOT/'artifacts/local/ultimate-speedruns/freedoom-regression';rdir=b/'full-rate'
load=lambda p:json.loads(p.read_text());r=load(rdir/'evm.json');old=load(ROOT/'artifacts/virtual-pointer/virtual-profile-manifest.json');native=load(b/'native-result.json')
assert r['pass'] and r['ownedRuntimeStopped'] and r['memoryProfile']=='virtual' and r['sampleEvery']==1
assert r['executedTics']==r['verifiedTics']==len(r['frames'])==279
assert [(f['tic'],f['indexed8Sha256']) for f in r['frames']]==[(f['tic'],f['indexed8Sha256']) for f in old['frames']]
assert states(gzip.decompress((rdir/'evm.states.bin.gz').read_bytes()))==states(gzip.decompress((b/'native-states.delta.bin.gz').read_bytes()),True)
assert sha((b/'source-download').read_bytes())==r['demoSha256']==native['demoSha256']
for f,h in r['sourceHashes'].items():assert sha((ROOT/f).read_bytes())==h
receipts=json.loads(gzip.decompress((rdir/'evm.capture-receipts.json.gz').read_bytes()));assert len(receipts)==279
for tx,f in zip(receipts,r['frames']):
 assert tx['status']=='0x1' and tx['transactionHash']==f['transactionHash']
 frame=next(log for log in tx['logs'] if log['topics'][0]==FRAME_TOPIC)
 assert int(frame['topics'][2],16)==f['tic'] and int(frame['topics'][1],16)==int(f['frameId'])
 pixels=dynamic(bytes.fromhex(frame['data'][2:]),64);assert pixels==(rdir/f['file']).read_bytes() and sha(pixels)==f['indexed8Sha256']
 assert f['savedStateUnchanged']
proof=dict(pass_=True,gameplayTics=279,snapshots=280,frames=279,allPreviouslyAcceptedFrameHashesIdentical=True,tic52VirtualLinkFrameIdentical=True,originalSample=old['samples'],demoSHA256=r['demoSha256'],IWADSHA256=native['wadSha256'],sourceHashes=r['sourceHashes'],gas=r['totalReplayGas']+r['totalCaptureGas'],reportSHA256=sha((rdir/'evm.json').read_bytes()),captureReceiptsSHA256=sha((rdir/'evm.capture-receipts.json.gz').read_bytes()),acceptedManifestSHA256=sha((ROOT/'artifacts/virtual-pointer/virtual-profile-manifest.json').read_bytes()),verifierSHA256=sha(Path(__file__).read_bytes()),limits='Original accepted virtual sample remains virtual; equality of all279 prior frame hashes is regression evidence, not universal native pixel equivalence. No accepted video or fixture changed.')
(ROOT/'artifacts/ultimate-speedruns/owner-pointer/freedoom-regression.json').write_text(json.dumps(proof,indent=2)+'\n');print('PASS279 preserved Freedoom frame hashes,280 whole gameplay snapshots and mined frame receipts')
