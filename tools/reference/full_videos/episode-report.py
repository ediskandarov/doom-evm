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
windows include resumed downtime where applicable. End-to-end per-map pipeline
stage timings are reported separately. Concurrent per-map durations must not be
summed and relabeled episode wall time. No missing cost or timing is estimated.
World rendering, Status Bar and HUD execute in one capture transaction and have
no separately measured gas attribution. Optional subdivision remains unavailable.

The deterministic display clock uses one tic per original blocking wipe step;
no gameplay or demo command advances during the wipe. Entire authentic input tapes
are consumed, including their post-exit commands. Native single-demo mode would
quit at DEMOMARKER; an explicit additional zero-input UI continuation holds
statistics/next-map presentation or completes original E1 finale text/CREDIT.
E1M8 bypasses Intermission and includes the original forced finale-art melt.
E1M9 marks didsecret and points to E1M4. No next-map gameplay is fabricated.

Native references use unchanged original C functions with the established
borrowed immutable UI-resource/LP64/initial-zone profile and temporary gameplay
render chronology. Canonical gameplay snapshots keep historical miscellaneous
RNG counters; original ST/WI/wipe use a separately retained presentation RNG.
Gameplay P_Random and all original command bytes remain unchanged. Finite native
pixel equality does not make virtual zone/owner pointer bytes universal native
values. Their explicit provenance categories remain experimental and RESTRICT.
H.264 is lossy; indexed8 comparisons establish pixel equality before encoding.

The original baseline recordings, saved frames, input archives and provenance
are preserved and checked read-only. Failed pilot/earlier attempts remain separate.
Production/browser integration and the full historical Phase 0–4 acceptance suite
are outside this feature verification. Reproduce using the suite README and the
per-map manifest's exact frozen source/resource/configuration bindings.
'''
(out/'EPISODE-SUMMARY.md').write_text(text)
print(out/'EPISODE-SUMMARY.md')
