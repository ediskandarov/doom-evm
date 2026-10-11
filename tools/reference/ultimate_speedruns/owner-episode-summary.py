#!/usr/bin/env python3
"""Final gate: all nine complete recordings and all five immutable regressions."""
import hashlib,json,shutil,subprocess
from pathlib import Path
from datetime import datetime
from fractions import Fraction
ROOT=Path(__file__).resolve().parents[3];LOCAL=ROOT/'artifacts/local/ultimate-speedruns';OUT=ROOT/'artifacts/ultimate-speedruns/owner-pointer'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text())
telemetry=LOCAL/'owner-host-telemetry.jsonl';host=[json.loads(s) for s in telemetry.read_text().splitlines()]
rows=[];extra=[]
for m in range(1,10):
 base=LOCAL/f'E1M{m}'
 if m==8:base=base/'alternatives/sedlo-046'
 local=base/'owner-v1/full-rate';safe=ROOT/'artifacts/ultimate-speedruns'/base.relative_to(LOCAL)/'owner-v1'
 r=load(safe/'result.json');evm=load(local/'evm.json');v=load(local/'verification.json');pixel=load(local/'pixel-domain.json')
 assert r['EVMGameplay']['allSnapshotsExact'] and r['EVMGameplay']['exit']['reached'] and v['evidenceVerified'] and v['recordingComplete'] and v['mediaVerified'] and evm['pass'] and evm['ownedRuntimeStopped']
 assert r['frames']['rendered']==r['EVMGameplay']['tics']==r['nativeReplay']['tics']==len(evm['frames'])
 assert pixel['allCommonNativePixelsOutsideVirtualSourcesExact'] and pixel['sourceReportSha256']==sha(local/'evm.json')
 for f in load(safe/'evidence-manifest.json')['files']:assert sha(ROOT/f['path'])==f['SHA256'],f['path']+' evidence drift'
 assert sha(ROOT/r['media']['MP4'])==r['media']['SHA256']
 clock=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_packets','-show_streams','-show_entries','packet=pts,duration:stream=time_base','-of','json',str(ROOT/r['media']['MP4'])]))
 unit=Fraction(clock['streams'][0]['time_base']);packets=clock['packets'];count=r['frames']['rendered']
 assert len(packets)==count and sorted(Fraction(p['pts'])*unit for p in packets)==[Fraction(t,35) for t in range(count)]
 assert all(Fraction(p['duration'])*unit==Fraction(1,35) for p in packets)
 mediaClock=dict(packets=count,timeBase=str(unit),allPresentationTimesExact=True,allPacketDurationsOneTic=True,FPS=35)
 args=r['runtime']['serverArgs'];assert args[args.index('--gas-limit')+1]=='10000000000' and args[args.index('--memory-limit')+1]=='1073741824', 'Record actual infrastructure changes before final summary'
 assert args[args.index('--hardfork')+1]=='cancun' and args[args.index('--host')+1]=='127.0.0.1' and '--no-request-size-limit' in args
 partialPreserved=None
 if m in [3,5,6,8]:
  prior=load(base/'full-rate/frame-manifest.json');current=load(local/'frame-manifest.json')
  assert [(f['tic'],f['indexed8Sha256']) for f in prior['frames']]==[(f['tic'],f['indexed8Sha256']) for f in current['frames'][:len(prior['frames'])]]
  partialPreserved=dict(frames=len(prior['frames']),allFrameHashesUnchanged=True,priorManifestSHA256=sha(base/'full-rate/frame-manifest.json'))
 preserved=None
 if m in [1,2,4,7,9]:
  reg=load(local/'accepted-regression.json');assert reg['pass_'] and reg['frames']==r['frames']['rendered']
  old=load(base/'full-rate/frame-manifest.json');new=load(local/'frame-manifest.json')
  assert [(f['tic'],f['indexed8Sha256']) for f in old['frames']]==[(f['tic'],f['indexed8Sha256']) for f in new['frames']]
  oldMP4=base/'full-rate'/old['media']['mp4'];assert sha(oldMP4)==old['media']['mp4Sha256']
  target=safe/'accepted-regression.json'
  if target.exists():assert target.read_bytes()==(local/'accepted-regression.json').read_bytes()
  else:shutil.copyfile(local/'accepted-regression.json',target)
  extra.append(dict(path=str(target.relative_to(ROOT)),SHA256=sha(target)))
  preserved=dict(frames=reg['frames'],allFrameHashesAndPriorVirtualProvenanceUnchanged=True,oldMP4SHA256=sha(oldMP4),newMP4SHA256=r['media']['SHA256'],MP4BytesIdentical=sha(oldMP4)==r['media']['SHA256'],pixelChanges=0)
 started=datetime.fromisoformat(evm['startedUTC']);ended=datetime.fromisoformat(evm['endedUTC']);samples=[h for h in host if started<=datetime.fromisoformat(h['UTC'])<=ended]
 peaks={}
 for kind in ['node','anvil']:
  values=[p['rssKiB'] for h in samples for p in h['processes'] if '--port '+str(evm['port'])+' ' in p['ownedCommand'] and (p['ownedCommand'].startswith('node ') if kind=='node' else '/bin/anvil ' in p['ownedCommand'])]
  peaks[kind+'SampledPeakRSSKiB']=max(values) if values else None
  peaks[kind+'RSSSamples']=len(values)
 row=dict(map=f'E1M{m}',report=str((safe/'result.json').relative_to(ROOT)),reportSHA256=sha(safe/'result.json'),demo=r['demo'],IWAD=r['IWAD'],tics=r['EVMGameplay']['tics'],snapshots=r['EVMGameplay']['observations'],frames=r['frames']['rendered'],supportedPixels=r['supportedPixelDomain'],virtualProvenance=r['ownerPointerProvenance'],gas=r['gas'],runtime=r['runtime'],resourceUsage=dict(**peaks,sampleIntervalSeconds=30,minimumSampledDiskFreeBytes=min(h['disk']['free'] for h in samples) if samples else None,limits='Sampled RSS maxima, not unobserved execution peaks; absolute-path Node matching repaired at 2026-10-11T06:01:41Z. Missing earlier Node RSS not estimated; shared host swap/RAM recorded in telemetry'),media=r['media'],mediaClock=mediaClock,acceptedRegression=preserved,partialPrefixRegression=partialPreserved,unresolvedFailure=None)
 rows.append(row)
assert sum(r['tics'] for r in rows)==sum(r['frames'] for r in rows)==14475
assert sum(r['snapshots'] for r in rows)==14484
assert load(OUT/'freedoom-regression.json')['allPreviouslyAcceptedFrameHashesIdentical']
cleanup=LOCAL/'owner-cleanup.jsonl';removed=[f for row in cleanup.read_text().splitlines() for f in json.loads(row)['removed']]
summary=dict(pass_=True,completeMaps=9,gameplayTics=14475,snapshots=14484,EVMFrames=14475,fullRateFPS=35,allSupportedCommonNativePixelsOutsideVirtualExact=True,commonNativePixelsCompared=sum(r['supportedPixels']['commonNativePixelsChecked'] for r in rows),virtualZoneUses=sum(r['virtualProvenance']['virtualZoneUses'] for r in rows),virtualOwnerUses=sum(r['virtualProvenance']['virtualOwnerUses'] for r in rows),totalRecordingGas=sum(r['gas']['totalVerifiedRecording'] for r in rows),maps=rows,additionalEvidence=extra,telemetry=dict(path=str(telemetry.relative_to(ROOT)),SHA256=sha(telemetry),samples=len(host),minimumFreeBytes=min(h['disk']['free'] for h in host),hardwareRAMBytes=int(next(h['memoryBytes'] for h in host if isinstance(h['memoryBytes'],str)))),checkpointCleanup=dict(path=str(cleanup.relative_to(ROOT)),SHA256=sha(cleanup),removedFiles=len(removed),bytesFreed=sum(f['bytes'] for f in removed)),infrastructureLimitChanges=[],configuredInfrastructure='Inherited 10B gas, 1 GiB execution memory, localhost isolated ports, Cancun, --no-request-size-limit, prune-history 2 and transaction-block-keeper 2. No new limit increases required.',nativeVerdict='RESTRICT',RelaxedImplemented=False,limits='Finite native profile evidence. Virtual address bytes are deterministic extensions, never actual native process placement. Temporary-copy renders preserve accepted infrastructure; continuous persisted render history/production UI acceptance is outside this suite.',sourceCommit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),summaryToolSHA256=sha(Path(__file__)))
accepted=OUT/'episode-summary.json'
if accepted.exists():
 prior=load(accepted)
 # Reverification may use a later metadata/tool commit, but every recording,
 # media, resource, telemetry and regression binding must remain immutable.
 audit=lambda record:{k:v for k,v in record.items() if k not in ('sourceCommit','summaryToolSHA256')}
 assert audit(prior)==audit(summary),'accepted episode evidence drift; preserve it and create a separate attempt'
 print(json.dumps(dict(acceptedEvidencePreserved=True,completeMaps=prior['completeMaps'],EVMFrames=prior['EVMFrames'],snapshots=prior['snapshots'])))
 raise SystemExit(0)
(OUT/'episode-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
lines=['# Ultimate DOOM Episode One owner-profile acceptance','',f"Nine authentic complete 35 FPS recordings: **14,475 EVM gameplay tics and frames**, **14,484 exact whole snapshots**. Every map reaches its original native/EVM exit. All five prior recordings remain preserved; all 6,051 prior indexed8 frame hashes and virtual provenance records are unchanged. Original Freedoom 279 frames and 280 snapshots also pass regression.",'','The general owner-slot solution adds a separate authenticated `lumpcache[]` virtual address domain with LP64 stride 8 and current owner validation. Native O0/O2/sanitizer draws and allocator lifetime experiments justify identities/layout, not absolute placement. Native compatibility remains **RESTRICT**. Relaxed Rendering was not implemented.','', '| Map | Demo | Tics / frames | Native O2 whole frames equal | Virtual zone / owner uses | MP4 |','| --- | --- | ---: | ---: | ---: | --- |']
for row in rows:
 r=load(ROOT/row['report']);m=row['map'];lines.append(f"| [{m}](ULTIMATE-{m}-OWNER-V1.md) | {r['demo']['author']} / {r['demo']['originalName']} | {row['tics']} | {r['frames']['O2Equal']} | {row['virtualProvenance']['virtualZoneUses']} / {row['virtualProvenance']['virtualOwnerUses']} | `{row['media']['MP4']}` |")
lines+=['',f"{summary['commonNativePixelsCompared']:,} common-native pixels outside all virtual draw destinations agree exactly. Virtual draw uses: {summary['virtualZoneUses']} zone, {summary['virtualOwnerUses']} external owner. Whole-frame equality is a measured finite comparison; a virtual sample remains virtual even when equal or overwritten. Per-map provenance records give exact source/header/byte/destination/final-value survival.",'',f"Total verified recording gas: {summary['totalRecordingGas']:,}. Each map report preserves startup/deployment/replay/capture gas, exact compiler/source/runtime identities, transaction and resource hashes, start/end and RPC durations, local limits, native profile and media proof. Sampled host RSS, swap and disk usage are hash-bound in the [episode manifest](../artifacts/ultimate-speedruns/owner-pointer/episode-summary.json). Checkpoint cleanup freed {sum(f['bytes'] for f in removed):,} bytes from {len(removed)} superseded files; newest validated recovery state and final receipts remain. No new infrastructure limit increase was required.",'','The five previous MP4s were not overwritten. Their new regression recordings have zero indexed-pixel/provenance changes. The summary records both media hashes and whether encoded bytes are identical. New owner pixels on formerly blocked frames have no prior accepted EVM counterpart; their native comparison and virtual category are explicit in each report.','', 'Implementation: `14a997a`; reusable suite: `761f873`; native proof: `6d3f366`; Freedoom regression: `33364f0`. Focused 44-test verification passed, including restored worktree-local pinned test chunks; no full historical acceptance rerun. [Source investigation](ULTIMATE-OWNER-POINTERS.md) and [frozen evidence](../artifacts/ultimate-speedruns/owner-pointer/episode-summary.json) preserve the architecture, commands, limits and compatibility boundaries.','', 'No unresolved recording failure remains. Earlier failed/partial attempts, incompatible faster E1M8 evidence, all source archives and accepted artifacts remain preserved. No commercial IWAD/artwork/video is committed, no main integration or push occurred.']
(ROOT/'docs/ULTIMATE-OWNER-EPISODE.md').write_text('\n'.join(lines)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k in ['completeMaps','gameplayTics','snapshots','EVMFrames','commonNativePixelsCompared','virtualZoneUses','virtualOwnerUses','totalRecordingGas']}))
