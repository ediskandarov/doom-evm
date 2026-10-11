#!/usr/bin/env python3
"""Human-readable publication summary derived from the verified telemetry JSON."""
import json,hashlib,collections
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];out=ROOT/'artifacts/full-videos';r=json.loads((out/'episode-telemetry.json').read_text());maps=r['maps'];assert len(maps)==9 and all(x['recordingComplete'] and x['evidenceVerified'] for x in maps)
rows=[]
for x in sorted(maps,key=lambda x:x['map']):
 g=x['gameplay'];v=x['video'];e=x['evm'];t=x['execution'];f=x['fidelity']
 rows.append(f"| {x['map']} | {g['tics']} | {g['durationSeconds']:.3f} | {v['totalEncodedFrames']} | {v['durationSeconds']:.3f} | {e['totalGas']:,} | {e['successfulTransactions']:,} | {t['renderedFramesPerRPCSecond']:.3f} | {f['nativeExactAllPresentationFrames']} | {f['framesWithDirectVirtualSamples']} / {f['directVirtualSampleUses']} |")
agg=r['aggregate']
text=f'''# Nine complete Ultimate DOOM Episode One presentations

All nine original speedruns reach their genuine exits. All gameplay, original
Status Bar/HUD, Intermission/finale and source-derived screen melt pixels are
computed inside EVM. Output is silent 35 FPS H.264, 1280×960, square-pixel 4:3.
Original palette decoding/scaling/encoding are the only host pixel operations.
Commercial WAD/frames/media and full receipts remain local; hashes, provenance,
structured telemetry and reproduction tools are retained in Git.

Aggregate final recording gas: **{agg['gas']:,}** across
**{agg['successfulTransactions']:,} successful mined transactions**.
Gameplay: **{agg['gameplayTics']:,} tics** and
**{agg['matchingGameplaySnapshots']:,} matching canonical snapshots**.
Final encoded EVM frames: **{agg['encodedFrames']:,}**.
Video duration summed across all nine files: **{agg['videoDurationSeconds']:.6f}s**.
Finite native-equal indexed frames: **{agg['nativeExactAllPresentationFrames']:,}**.
Direct experimental virtual-address sample uses: **{agg['directVirtualSamples']}**.
These totals exclude failed attempts and separate diagnostic/rollback transactions.

| Map | Gameplay tics | Gameplay seconds | Video frames | Video seconds | Gas | Successful tx | Render RPC FPS | Finite native-equal frames | Virtual frames / uses |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
'''+ '\n'.join(rows)+'''

Each map's JSON contains original tape identity, genuine authoritative kill/item/
secret/time/par statistics, mutually exclusive frame counters, overlapping Status
Bar coverage, gas min/mean/median/max, actual operation-category receipts,
maximum transaction gas, measured failures, UTC bounds, setup/render/RPC timing,
throughput and computation/video ratios, finite native comparison coverage,
virtual provenance and final-frame differences, Anvil configuration, frozen source/
ABI/IWAD/input hashes, media paths and verification bindings.

Render RPC FPS divides actual emitted frames by the measured transaction intervals
that emit them. Those intervals include localhost transport, mining and polling;
they are not EVM-only CPU time or realtime network performance. UTC elapsed
windows include resumed downtime where applicable. Exact recorded session
windows and matching inherited-prefix session bounds are summed when available;
full inherited-prefix wall bounds remain unavailable for the checkpoint-forked
E1M1 pilot. Its measured receipt RPC time is retained without a wall-time estimate. End-to-end per-map pipeline
stage timings are reported separately. Concurrent per-map durations must not be
summed and relabeled episode wall time. No missing cost or timing is estimated.
Summed measured transaction RPC processing: **'''+f"{agg['summedRPCSeconds']:,.6f}"+''' seconds**.
Summed processing/video-duration ratio: **'''+f"{agg['summedRPCToTotalVideoDurationRatio']:.6f}"+''' times**.
This is measured transaction work summed across maps, not concurrent episode wall time.
World rendering, Status Bar and HUD execute in one capture transaction and have
no separately measured gas attribution. Gameplay advance also includes ST/HU
tickers and observations. Pure eth_call gas/CPU subdivisions are unavailable. Optional subdivision remains unavailable.

The deterministic display clock uses one tic per original blocking wipe step;
no gameplay or input command advances during the wipe. Authentic tape files are
preserved; final recordings consume their exact gameplay prefixes and separate
authorized post-exit input appendices. Original WI button-edge acceleration
reveals the final statistics, holds 105 frames, then briefly draws original
Entering/NoState(cnt1). The endpoint is a recording choice; no next level loads.
E1M8 uses zero-input original finale timing and 105 final art frames.
E1M8 bypasses Intermission and includes the original forced finale-art melt.
E1M9 marks didsecret and points to E1M4. No next-map gameplay is fabricated.

Native references use unchanged original C functions with the established
consistent borrowed immutable UI-resource/LP64/initial-zone profile, original
differential ST/HU display history and temporary gameplay render chronology.
Previous source framebuffers are independently native-generated. Old mixed
ST_lib-cache and forced-full-refresh reference failures remain preserved. Canonical gameplay snapshots keep historical miscellaneous
RNG counters; original ST/WI/wipe use a separately retained presentation RNG.
Gameplay P_Random and all original command bytes remain unchanged. Finite native
pixel equality does not make virtual zone/owner pointer bytes universal native
values. Their explicit provenance categories remain experimental and RESTRICT.
Whole gameplay-frame equality counts use the declared native O2 reference;
common native pixels outside explicit virtual destinations are checked across
O0/O2/sanitizer profiles. All UI/melt/finale references agree across those profiles.
E1M3/E1M5 use the preserved supported initial-zero-zone native domain; their
adversarial allocation-fill failures remain failures and are retained separately.
The archive's original recording IWAD identity is unavailable; these replays are
verified against the authenticated compatible classic Ultimate DOOM IWAD identified below.
H.264 is lossy; indexed8 comparisons establish pixel equality before encoding.

The original baseline recordings, saved frames, input archives and provenance
are preserved and checked read-only. Failed pilot/earlier attempts remain separate.
Production/browser integration and the full historical Phase 0–4 acceptance suite
are outside this feature verification. Reproduce using the suite README and the
per-map manifest's exact frozen source/resource/configuration bindings.
'''
def fmt(v,digits=3):return 'Unavailable' if v is None else f'{v:,.{digits}f}'
def table(columns,rows):return '\n\n| '+' | '.join(columns)+' |\n| '+' | '.join(['---']*len(columns))+' |\n'+'\n'.join('| '+' | '.join(map(str,row))+' |' for row in rows)+'\n'
text+='\n## Gameplay identities and authoritative statistics\n'
text+=table(['Map','Author / original tape','Kills / total','Items / total','Secrets / total','Time tics / whole seconds','Par seconds'],[[x['map'],str(x['gameplay']['identity']['author'])+' / '+str(x['gameplay']['identity']['originalName']),f"{x['gameplay']['statistics']['kills']} / {x['gameplay']['statistics']['totalKills']}",f"{x['gameplay']['statistics']['items']} / {x['gameplay']['statistics']['totalItems']}",f"{x['gameplay']['statistics']['secrets']} / {x['gameplay']['statistics']['totalSecrets']}",f"{x['gameplay']['statistics']['timeTics']} / {x['gameplay']['statistics']['timeSecondsInteger']}",str(x['gameplay']['statistics']['parSeconds'])+(' (catalog only; no WI)' if x['map']=='E1M8' else '')] for x in maps])
text+='\n## Frame accounting\n'
text+=table(['Map','Gameplay','Complete Status Bar coverage','Title','Menu','Melt','Intermission','Finale','Total'],[[x['map'],x['video']['gameplayFrames'],x['video']['completeStatusBarFrames'],x['video']['titleFrames'],x['video']['menuFrames'],x['video']['meltWipeFrames'],x['video']['intermissionFrames'],x['video']['finaleFrames'],x['video']['totalEncodedFrames']] for x in maps])
text+='\nStatus Bar coverage overlaps gameplay and melt; it is not added to the total.\n'
text+='\n## Measured processing time\n'
text+=table(['Map','Active recorded wall seconds','Elapsed window seconds','Transaction RPC seconds','Setup RPC seconds','Render RPC seconds','Active wall / video ratio'],[[x['map'],fmt(x['execution']['activeWallClockProcessingSeconds']),fmt(x['execution']['elapsedWindowSeconds']),fmt(x['execution']['measuredRPCTransactionSeconds']),fmt(x['execution']['deploymentSetupRPCSeconds']),fmt(x['execution']['renderTransactionSeconds']),fmt(x['execution'].get('activeProcessingToVideoDurationRatio'))] for x in maps])
text+='\n## Gas distributions\n'
text+=table(['Map','Transaction gas min / mean / median / max','Rendered-frame transaction gas min / mean / median / max'],[[x['map'],' / '.join(f"{x['evm']['gasPerSuccessfulTransaction'][k]:,.0f}" for k in ['min','avg','median','max']),' / '.join(f"{x['evm']['gasPerRenderedFrameTransaction'][k]:,.0f}" for k in ['min','avg','median','max'])] for x in maps])
text+='\nGas is consumed in actual local mined transactions. Aggregate successful transaction gas/frame distributions and operation-category totals are in episode-telemetry.json. Per-rendered-frame gas is the emitting transaction cost; allocation/setup and separate gameplay advances are accounted separately.\n'
text+='\n## Failures and recovery\n'
text+=table(['Map','Failed final mined transactions','Manual checkpoint resumes','Observed retained final-directory log errors'],[[x['map'],x['evm']['failedMinedTransactions'],x['evm']['transportFailuresAndRetries']['manualCheckpointResumeCount'],x['evm']['transportFailuresAndRetries']['observedFinalDirectoryLogErrors']] for x in maps])
text+='\nLog errors include native comparison assertions, requested recoverable stops and refusal of an occupied verification port. Their classifications and line/hash bindings are preserved in attempt-inventory.json. These do not indicate failed final gameplay transactions. Automatic transaction resubmission is disabled; receipt polling does not resubmit. Earlier failed attempts retain separate receipt gas and lineage. Their costs are not summed because checkpoints share inherited receipts; unreceipted failures have unavailable gas.\n'
text+='\n## Final MP4 paths and verification\n'
text+=''.join(f"\n- [{x['map']} MP4]({x['video']['MP4']}); SHA256 `{x['video']['MP4SHA256']}`; final indexed framebuffer differences {x['fidelity']['finalFrameNativePixelDifferences']}.\n" for x in maps)
pilot=json.loads((out/'pilot-short-v2/comparison.json').read_text())
text+='\n## Preserved long pilot versus abbreviated pilot\n'
text+=table(['Metric','Long pilot','Abbreviated pilot'],[[label,pilot['old'][key],pilot['new'][key]] for label,key in [('Total frames','totalFrames'),('Intermission frames','intermissionFrames'),('Melt frames','meltFrames'),('Gas consumed','gas'),('Successful transactions','successfulTransactions'),('Measured transaction RPC seconds','measuredTransactionRPCSeconds')]])
text+=f"\nSaved {pilot['savedFrames']:,} frames, {pilot['savedGas']:,} gas and {pilot['savedMeasuredRPCSeconds']:.6f} measured RPC seconds. The old pilot's full recorder wall time is {pilot['old']['recorderWindowSeconds']:.3f}s; the new appended-UI session is {pilot['new']['recorderWindowSeconds']:.3f}s. The new full inherited-prefix wall time is unavailable, so these two session windows are not compared as equivalent totals. Both full melts and all 317 original gameplay snapshots remain unchanged. The historical 3498-frame MP4 remains at `artifacts/local/full-videos/E1M1/pilot-v2/ultimate-e1m1-complete.mp4`.\n"
text+='\nThe original Entering endpoint was explicitly read back as WI state=-1,cnt=1,worldDoneRequested=false. A small recorder-only metadata copy fixes the later guard omission but is compiled/source-audited only. Neither G_WorldDone execution nor subsequent level startup is claimed verified. Failed short-pilot, native mixed-cache and full-refresh reference attempts remain diagnostic evidence.\n'
env=json.loads((out/'environment.json').read_text());hardware=env['hostHardware']
text+='\n## Environment and source identities\n'
text+=f"\nMeasured host: {hardware['CPU']}, {hardware['physicalMemoryBytes']:,} physical RAM bytes, {hardware['architecture']}, macOS {hardware['OS']} ({hardware['OSBuild']}). Anvil/Forge 1.8.5, solc 0.8.37+commit.f401782d, viaIR, optimizer 200, Cancun. Each owned Anvil uses 10,000,000,000 gas and 1,073,741,824 EVM memory bytes, disables the code-size and RPC request-body limits, and retains two history blocks. Per-request timeout 300s; state dump 900s; receipt polling has no separate aggregate deadline. At most two recording jobs run concurrently. Tool version output and full arguments are preserved in environment.json and per-map telemetry.\n"
text+=f"\nAuthenticated IWAD SHA256: `{env['IWADSHA256']}`; original C revision: `{env['sourceOriginalCommit']}`. The feature HEAD at execution is paired with exact generated source hashes, ABI hash, deployed runtime hash and resource bundle identity; HEAD alone does not identify an observation clone or an uncommitted recorder helper.\n"
text+=table(['Map','Recorded feature HEAD','Original input tape SHA256'],[[x['map'],x['environment']['engineCommitSHA'],x['environment']['inputTapeSHA256']] for x in maps])
text+='\nHost monitoring summary is in host-summary.json: sampled RSS/disk/swap observations are distinguished from guaranteed peaks and exclusive resource attribution. Source allocations, gameplay snapshots and commercial pixel buffers remain unchanged by telemetry collection.\n'
(out/'EPISODE-SUMMARY.md').write_text(text)
print(out/'EPISODE-SUMMARY.md')
