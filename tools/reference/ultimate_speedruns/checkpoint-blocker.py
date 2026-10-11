#!/usr/bin/env python3
"""Publish only hash-bound metadata for a proven unsupported rendering domain."""
import argparse,gzip,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
ap=argparse.ArgumentParser();ap.add_argument('base',type=Path);a=ap.parse_args();base=a.base.resolve()
assert base.is_relative_to(ROOT/'artifacts/local/ultimate-speedruns')
load=lambda p:json.loads(p.read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
r=load(base/'full-rate/evm.json');v=load(base/'full-rate/verification.json');pixel=load(base/'full-rate/pixel-domain.json');g=load(base/'gameplay/evm.json');gv=load(base/'gameplay/verification.json');n=load(base/'native-result.json');s=load(base/'source.json');d=load(base/'render-diagnostic/evm.json');decoded=load(base/'render-diagnostic/decoded.json')
assert not r['pass'] and v['evidenceVerified'] and not v['recordingComplete'] and pixel['pass_']
assert pixel['sourceReportSha256']==sha(base/'full-rate/evm.json') and pixel['frames']==len(r['frames'])
assert g['pass'] and gv['pass_'] and gv['reportSha256']==sha(base/'gameplay/evm.json') and g['verifiedTics']==n['executedTics']
assert d['verifiedTics']==r['verifiedTics'] and d['renderFailure']['rollback']['savedDigest']==r['renderFailure']['rollback']['savedDigest']
assert decoded['known']==('00'*32) and decoded['sampleBlock']['allocated'] and 8<=decoded['sampleBlock']['relative']<14
assert decoded['sampleBlock']['owner']!=0xffffffff
for report in [r,g,d]:
 assert report['memoryProfile']=='virtual' and report['ownedRuntimeStopped']
 for file,digest in report['sourceHashes'].items():assert sha(ROOT/file)==digest
captures=json.loads(gzip.decompress((base/'full-rate/evm.capture-receipts.json.gz').read_bytes()));failed=[c for c in captures if c['status']=='0x0'];assert len(failed)==1 and failed[0]['logs']==[]
assert failed[0]['transactionHash']==r['renderFailure']['transactionHash'] and int(failed[0]['gasUsed'],16)==r['renderFailure']['gas']
assert all(r['renderFailure']['rollback'][k] for k in ['allSavedFieldsUnchanged','nativeWorldExact','frameCounterUnchanged','noLogs'])
comparisons=v['nativePixelComparisons'];out=ROOT/'artifacts/ultimate-speedruns'/base.relative_to(ROOT/'artifacts/local/ultimate-speedruns');out.mkdir(parents=True,exist_ok=True)
result=dict(map=r['map'],status='rendering-blocked-supported-gameplay-complete',demo=dict(author=s['author'],originalName=s['originalName'],URL=s['downloadUrl'],SHA256=s['demoSha256']),IWAD=dict(MD5='c4fe9fd920207691a9f493668e0a2083',SHA256=n['wadSha256']),nativeReplay=dict(tics=n['executedTics'],statesSHA256=n['statesSha256'],allAllocationProfilesExact=n['allProfilesExact'],referenceProfile=g['nativeProfile']),EVMGameplay=dict(tics=g['verifiedTics'],observations=gv['observations'],allSnapshotsExact=True,exit=g['exit'],separateGameplayOnlyRun=True),frames=dict(rendered=len(r['frames']),required=n['executedTics'],firstRejectedTic=r['renderFailure']['tic'],O2Equal=sum(c['O2Equal'] for c in comparisons),allDeclaredNativeProfilesEqual=sum(len(c['equalProfiles'])==3 for c in comparisons),virtualSampleUses=v['virtualSampleUses'],virtualDerivedDestinations=v['virtualDerivedDestinations'],supportedPixelDomain={k:v for k,v in pixel.items() if k!='rows'}),gas=dict(partialRecording=r['totalGasIncludingStartupAndDeployment'],partialGameplay=r['totalReplayGas'],captureIncludingRejectedTransaction=r['totalCaptureGas'],completeSeparateGameplay=g['totalGasIncludingStartupAndDeployment'],diagnostic=d['totalGasIncludingStartupAndDeployment']),runtime=dict(partialRecording=dict(startedUTC=r['startedUTC'],endedUTC=r['endedUTC'],partialReplaySeconds=r.get('partialReplayElapsedMs',0)/1000,replayRPCSeconds=r['replayTransactionElapsedMs']/1000,captureRPCSeconds=r['captureTransactionElapsedMs']/1000,serverArgs=r['serverArgs']),completeGameplay=dict(startedUTC=g['startedUTC'],endedUTC=g['endedUTC'],replaySeconds=g['replayElapsedMs']/1000,serverArgs=g['serverArgs'])),MP4=None,unresolvedFailure=dict(kind='unknown-owner-slot-pointer-byte',diagnostic=decoded,sameSavedDigestAsFullRateFailure=True,rollback=r['renderFailure']['rollback'],originalFailure=r['renderFailure']),limitations='Full gameplay acceptance is independent of partial rendering. No full MP4 exists; no missing frame is reused. Named native initial-zero-zone profile only where alternate allocation diagnostic fails. Owner-slot addresses remain unknown; allocator, draw guards, inputs, goldens and engine algorithms unchanged.',sourceHashes=r['sourceHashes'],compiler=r['compiler'],abiSHA256=r['abiSha256'],resourceIdentity=r['resourceIdentity'],recordedSourceCommit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip())
(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');(out/'decoded-diagnostic.json').write_text(json.dumps(decoded,indent=2)+'\n');(out/'virtual-samples.json').write_bytes((base/'full-rate/virtual-samples.json').read_bytes())
paths=[base/'source.json',base/'native-result.json',base/'native-domain.json',base/'native-full/native-frames.json']
for directory in ['full-rate','gameplay','render-diagnostic']:
 paths += [p for p in (base/directory).iterdir() if p.is_file() and (p.suffix=='.json' or p.name.endswith('-receipts.json.gz')) and 'checkpoint' not in p.name]
paths += [out/'result.json',out/'decoded-diagnostic.json',out/'virtual-samples.json']
manifest=dict(map=r['map'],UTC=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),commercialPayloadsLocalOnly=True,files=[dict(path=str(p.relative_to(ROOT)),bytes=p.stat().st_size,SHA256=sha(p)) for p in paths])
(out/'evidence-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps({k:result[k] for k in ['map','status','EVMGameplay','frames']})[:1500])
