# Complete Ultimate DOOM speedrun presentations

Goal started 2026-10-11 09:20:02.385334 UTC (measured preflight). Owner: this session in
`/Users/eduard/sandbox/doom-evm-full-videos`, exclusively on
`feat/full-speedrun-videos`. Clean baseline:
`59522a545d1311924a28875a098892c5e27c113b`.

Scope: nine independent original-input E1 presentations, EVM Status Bar,
authoritative Intermission/finale, original-source melt, native references,
separate frame counters, 35 FPS 4:3 MP4s, provenance, gas/runtime measurements
and recoverable feature-branch handoff. Complete and verify E1M1 before the
eight other recordings. Preserve historical evidence and commercial assets
outside Git. No main changes, integration, push or Computer Use.

Owned additions: `src/doom/f_wipe.sol`, independent support consumers,
`tools/reference/full_videos/`, dedicated tests/fixtures and evidence,
this report. Existing shared ABIs, engine state, runtime, browser protocols,
acceptance runners and historical recorders remain unchanged. Any necessary
shared changes are an integrator handoff, not an edit in this feature.

Dependencies: original C at `a77dfb96cb91780ca334d0d4cfd86957558007e0`,
authenticated classic Ultimate DOOM 1.9 IWAD, original archived demo inputs,
existing source-derived ST/HU/WI/finale/Gameflow modules, explicit owner-v1
virtual address profile, pinned solc 0.8.37/viaIR/optimizer200/Cancun.
Historical acceptance: 14,475 gameplay tics/frames, 14,484 snapshots and nine
genuine exits; finite native equality and RESTRICT profile remain explicit.

Runtime ownership: new checked-free localhost ports 18941–18949; no reserved
18880/8088 use. Each recorder starts/stops only its own Anvil child. Process
and artifact checkpoints are independent per map. Initial available disk:
29 GiB as reported by `df`; exact bytes will be recorded by preflight.

Verification gates: original-C melt state/pixel/RNG/timing comparisons;
focused Forge persistence and rollback; unchanged source/input/historical
evidence hashes; independent native gameplay/UI/palette/transition references;
mined EVM frames, saved-state consistency, authoritative exit statistics;
pilot acceptance before remaining recordings; supported pixel comparisons
with every virtual destination distinguished; exact frame accounting and
MP4 timing/dimensions; measured gas/runtime/host resources. No full historical
Phase 0–4 suite. Stop only after all nine presentations and gates pass and
Gitmoji commits/handoff are complete.

## Source investigation

`d_main.c:D_Display` wipes only when `gamestate != wipegamestate` (or the
explicit forced-wipe sentinel). A deterministic 35 Hz display clock supplies
one tic per wipe step; the blocking wipe does not invoke gameplay tickers.
Original `f_wipe.c` initializes 320 random y entries, then updates only 160
two-pixel columns. Its completion notification is one step after the last
column reaches the destination. Both details must be retained.

`g_game.c:G_DoCompleted` uses genuine exit state and authoritative totals.
E1M8 bypasses WI and requests victory; E1M9 marks didsecret and returns to
zero-based next=3 (E1M4). No exit is requested by a recording host.

`G_ReadDemoTiccmd` encounters DEMOMARKER and `G_CheckDemoStatus` quits in
single-demo mode; attract-mode playback advances its demo sequence. Standalone
demo playback therefore cannot promise a full post-demo Intermission/finale.
The recording pipeline must distinguish exact tape playback from any explicit
legitimate post-exit Gameflow continuation; it must not invent extra gameplay
commands or represent continuation as original demo data. Final timing and
coverage will be documented after native/pilot verification.

## Progress

Implementation: original melt committed as `bd2d479`; eight focused tests and
178 native steps across three profiles pass. Independent presentation consumer
and recording/native/media/telemetry tools compile. Shared interfaces unchanged.
Full E1M1 pilot still pending; other eight EVM recordings have not started.

The first partial pilot proves 316/316 gameplay pixels and palettes against
O0/O2/ASan+UBSan (20,224,000 pixels), 317 canonical snapshots, authentic input
bytes, entry melt and checkpoint restore. Five separate mined rejections preserve
saved and presentation digests, snapshots, counters and logs. Its first WI frame
matches native, but exit-melt RNG differs: the adapter dropped WI_Start's ten
animation-init random calls before WI_Ticker. This gate remains failed. The
attempt is preserved at `artifacts/local/full-videos/E1M1/pilot-clock-fixed`.
The corrected v2 consumer commits the WI_Start miscellaneous RNG, and avoids
reconstructing unused gameplay state/definitions on later UI-only calls.
A new pilot must replay from startup under its own frozen source identity.

Original tapes contain 19,221 total demo tics, including 4,746 post-exit tics;
the historical 14,475-tic gameplay prefix is only part of the tapes. E1M1 has
3,280 original tics and remains on the original StatCount wait screen at its
marker. Three independent native UI profiles produce 3,141 title/exit-wipe/WI
comparison frames with exact pixels, palette and state timing.

Publication telemetry is an additional authorized deliverable: per-map and
aggregate JSON, receipt-based gas/transaction distributions, operation categories,
frame counts, UTC/RPC/setup/throughput ratios, exact environment/source/IWAD/input
bindings, native/virtual pixel limits and failures. Unavailable subdivisions or
active-session bounds remain explicitly unavailable. No expensive instrumentation
is added solely for optional metrics.
Integration: independent feature only; production integration deferred.
Acceptance: pending all gates, beginning with E1M1.


## Verified E1M1 pilot

The corrected pilot passes: all 3,498 final EVM frames and palettes match the
independent original-C reference in the declared profile. All 316 gameplay targets,
317 canonical snapshots, 80 melt frames, 3,068 WI frames and 35 title frames pass.
The complete 3,280-tic input tape is consumed; 105 additional zero-input WI tics
hold its original ending screen. Five mined rejection checks pass; restore and
all saved/presentation digests, snapshots, counters and logs are verified.

MP4: `artifacts/local/full-videos/E1M1/pilot-v2/ultimate-e1m1-complete.mp4`,
35 FPS, 1280×960 square-pixel 4:3, 3,498 encoded frames, 99.94285714285714s,
SHA256 `6d65e321e75f3c787fc31dc758d7460b1f4cd25f27e0b193e1d7f204a82d12f4`.
Visual QA inspects title, gameplay/bar/HUD, melt and completed statistics.
Measured final recording gas: 689,031,769,853 in 4,572 successful transactions.
Recorder UTC interval: 954.584s; actual summed transaction RPC time: 858.189469293s;
render RPC throughput: 4.360271546 frames/s. These measurements exclude native
preparation, encoding and failed pilot attempts; EVM-only CPU time is unavailable.
Structured metadata is in `artifacts/full-videos/E1M1-telemetry.json` and its
per-map manifests. No virtual samples are used in this pilot.

Focused inherited dependency checks: 50 tests passed and four WI transaction
harness tests initially failed because default dynamic linking tried to read an
unavailable artifact path. Their existing historical `--no-dynamic-test-linking`
option fixes the harness; all four then pass. First failure evidence is retained.
Total focused coverage: 54 tests; no assertion/golden/shared config changed.

Read-only historical preservation passes for nine archives/input tapes, all
14,475 old indexed frames and 38 virtual uses, preflight-bound old MP4s and
manifests. Commercial files stay local. Pilot acceptance unlocks remaining
recordings. Main is unchanged.

## E1M4 tape progression discovered by native preparation

E1M4's exact original tape requests early WI acceleration, reaches G_WorldDone
at tic782, and has one further original gameplay command at tic783. That command
legitimately loads E1M5 and advances it once. The v2 standalone WI-only gate
rejects this unsupported endpoint; the failure is preserved. An independent v3
consumer now reuses original G_DoWorldDone/P_Setup and retains a separate
EVM-derived progression world after the last main-map render. Canonical E1M4
saved gameplay remains frozen at its genuine767-tic exit. No gameplay command
is invented; a later display hold republishes its EVM-generated next-level screen
without another gameplay tic. Its next-level native/EVM proof is pending.

Native progression diagnostics retain the original physical-lifetime thinker
identity journal. Solidity starts new logical pools per level. Additional
current-player/global scalar and pixel coverage must be reported independently
from any unsupported whole multi-level identity comparison; never mask an
accepted original-map snapshot field to force this extension to pass.

## Verified abbreviated presentation checkpoint

The original 3,498-frame E1M1 MP4 and all long-pilot evidence remain unchanged.
Its exported publication metadata is copied to `artifacts/full-videos/pilot-long-v2/`.
A new pilot at `artifacts/local/full-videos/E1M1/pilot-short-v2/` has **547 frames**,
**117 Intermission frames**, and **80 full melt frames** (42 entry, 38 exit).
The final statistics stay visible for exactly105 frames. All547 indexed frames
and palettes agree with independent original-C O0/O2/sanitizer profiles. All317
canonical snapshots match the preserved original gameplay; no virtual samples.
The new silent35 FPS/1280×960/4:3 MP4 is15.628571428571428 seconds, SHA256
`4a8be58e4d401e6fd628449e2b99874d359e13c213eb3153bab7e17b5566a3ae`.

After the genuine exit: release0, Attack1,104 releases, Attack1, release0, Attack1,
nine releases. Every command is passed through original WI_checkForAccelerate
and WI_Ticker inside EVM. The recipe finishes on the original Entering/NoState
screen with cnt=1. The original timer is untouched. No WI-internal melt is invented.
These118 commands are a separate explicit input appendix; the full authentic tape
file and hash remain unchanged, but its post-exit trailer is not executed by this
abbreviated profile. E1M8 instead runs original finale text timing, forced art melt,
and105 readable art frames with zero appended buttons. E1M9 keeps the actual
didsecret/next=E1M4 state. No next-level gameplay is added.

The first short attempt rendered547 correct frames but its next, final handoff
transaction reverted: the minimal presentation context lacks player/episode
metadata required by G_WorldDone. The failure and receipt are retained separately
in `pilot-short-v1`; no failed gate is relabeled. The corrected supported recording
ends one tic before that unsupported boundary. A legitimate later next-map load
needs adapter work; this feature does not claim that transition or inject another
gameplay tick. The earlier native E1M4 multi-level investigation remains archived
locally and is superseded for the final short presentations.

Final logical-recording gas is324,602,338,892 across1,621 successful transactions,
a reduction of364,429,430,961 gas and2,951 frames from the long pilot. Summed measured
transaction RPC time falls from858.189469293s to348.194527918s. The new pilot reuses
its actual mined genuine-exit checkpoint: deployed bytecode, every resource chunk,
all saved frame hashes, canonical state and frame counter are read back unchanged.
It never replaces contract code or writes host-computed state. Inherited receipt
gas/time is included once in the logical recording total; new-session elapsed
wall time is reported separately. Full inherited-prefix wall bounds are unavailable
and are not estimated. Structured old/new measurements and lineage are in
`artifacts/full-videos/pilot-short-v2/comparison.json`. Storage rollback passes all
five rejection cases. This verified short pilot gates the remaining eight maps.

## Recorder endpoint and metadata correction

The Entering endpoint is an explicit recording choice, not an engine limitation.
The minimal recorder context omitted `playeringame[0]`, `gameepisode`, and
`gamemap`, required by G_Game.singlePlayer/episodeOne checks in G_WorldDone.
It also omitted semantic `secretExit` and player `didsecret` metadata. The small
FullSpeedrunProbe-only fix copies original profile flags and map/episode/player
selection from saved authoritative gameplay, and takes didsecret from authoritative
G_DoCompleted/WI wbs (which includes E1M9's completion effect). No original WI
algorithm/timer, production state type, ABI or gameplay code changes.

Production Doom._restoreEpisode -> DoomGame.load retains the complete state;
EpisodeRuntime.intermissionTicker calls G_WorldDone on that same context. The
identified omission belongs only to the recorder. This is a source-path audit,
not fresh production/browser transition acceptance. The affected observation
consumer compiles successfully under the pinned compiler/settings. Current
recordings retain their frozen pre-fix source/bytecode closure and explicitly stop
before this branch; the feature delivers the small corrected adapter separately.
No G_WorldDone execution or subsequent level startup is claimed verified.

Endpoint validation reads actual persisted WI state=-1,cnt=1,sp_state=10 and
worldDoneRequested=false from the restored final checkpoint without advancing it.
Native original C consumes identical gameplay/presentation commands and ends on
the same Entering frame. All normal final-recording transactions succeed; rejected
rollback probes are isolated diagnostics. The failed short attempt remains failed
and preserved. See `artifacts/full-videos/handoff-metadata-audit.json`.

## Native reference allocation diagnosis: E1M2 tic84

Classification2: native reference adapter/profile difference. The legacy native
builder borrowed ST/HU/WI graphics but omitted original ST_lib's STTMINUS load.
The first divergent allocation is malloc ordinal2126: after the player mobj,
ST_initData -> STlib_init -> W_CacheLumpName caches lump732 STTMINUS (128 bytes,
168 with LP64 align8/header). EVM's declared borrowed UI profile excludes this
physical-zone cache allocation. The extra168 bytes shift later heap geometry.
Neither the renderer nor memory provenance is changed.

For coordinate290,106,STEP5 texture75,column31,world draw operation458 agrees.
Source offset496,masked index16,composite index512,step93235,midpoint-1002024 and
frac1049146 agree. Composite SHA256
`65890b87232d4d67b33f1d25ba3f56b54bddaf371946b9e1eb75af5d66969204` and
COLORMAP11 SHA256 `82130e1472cf9e189d76c8991625df5ee6dd146863c7213530a237b4018cc379`
agree. The first divergent sampled value is byte0 of the next free-block size:
native legacy61513056 ->96 ->COLORMAP103, EVM61513224 ->8 ->COLORMAP8.
Both512-byte composites use552-byte allocations. Their headers start at5595256
(native mixed UI) and5595088(EVM). The sampled next headers start at5595808
and5595640. Both are free,tag0,unowned. Full40-byte headers, creation/block
identities and provenance masks are recorded in the diagnosis JSON; native
pointers/shared ZONEID are distinguished from EVM logical block indices.
Unknown bytes remain provenance0; sample512 is original-written integer provenance1.

A separate consistent borrowed-UI native profile redirects ST_lib cache calls
through the same existing authenticated UI resource provider. All2397 native
malloc requests,returned offsets and sizes then match EVM; the same pixel reads8
and all1029 existing E1M2 indexed frames/palettes match O0/O2/sanitizer references.
No EVM frame/source/byte/provenance was patched or rerendered. The old mixed
references and13 differing pixels in11 frames are preserved. Evidence:
`artifacts/full-videos/diagnostics/E1M2-allocation-divergence.json`; reproducible
observer patches/instructions are under `tools/reference/full_videos/diagnostics/`.

## Native Status Bar display history

E1M3's next reference mismatch is5 pixels in weapon widgets at the genuine-exit
frame,not a gameplay/allocator difference. The fresh-prefix reference forced a
full ST_Drawer refresh; original differential widget updates can retain different
background pixels at overlapping weapon icons. A separate display-history native
profile calls unchanged original ST/HU drawing functions for each prefix tic,
uses refresh only at initial entry, and starts each target world render with the
previous independently generated native framebuffer. Temporary world rendering
and canonical snapshots retain the accepted chronology; no native pixels enter EVM.
Old full-refresh references remain separate. E1M3's232 UI/melt frames then match
exactly; gameplay1290/1291 whole frames match,with4 explicitly virtual-derived
uses in the remaining gameplay frame. Final frame differences0; finite total
native-equal count1521/1522. Existing MP4/EVM frame hashes are unchanged.

The final native reference profile now declares both consistent borrowed UI
resources and original differential display history. A strict comparison still
requires all common-native pixels outside explicitly virtual draw destinations
to match; no assertion or golden is weakened.

## Independent full snapshot receipt audit

A separate read-only verifier now decodes every startup/advance Observation
from retained successful receipts and compares its full DSG1 bytes with the
preserved authoritative native state tape. It validates receipt SHA256,
transaction hash,status,contract address,event signature,and original tic;
no fields are masked. The first six recordings independently confirm8,673
snapshots. Final nine-map counts will be recorded after the remaining recordings
finish. This does not rerun gameplay or add EVM telemetry instrumentation.

## Final verified nine-map checkpoint

Acceptance passed 2026-10-11T16:22:14.706472+00:00. All nine complete
MP4s, native gameplay/UI/finale/melt comparisons, authoritative statistics,
original inputs, independent full snapshot receipt comparisons, persistence/
rollback and historical preservation gates pass. All owned recording runtimes
and the goal monitor are stopped. Integration/push/main/browser deployment are
outside this handoff and were not performed.

| Map | Gameplay tics | Encoded frames | Video seconds | Gas | Successful transactions | Finite native-equal frames |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| E1M1 | 316 | 547 | 15.628571 | 324,602,338,892 | 1,621 | 547 |
| E1M2 | 798 | 1029 | 29.400000 | 917,395,666,205 | 2,585 | 1029 |
| E1M3 | 1291 | 1522 | 43.485714 | 1,728,806,988,621 | 3,571 | 1521 |
| E1M4 | 767 | 1003 | 28.657143 | 811,950,237,036 | 2,528 | 1003 |
| E1M5 | 2110 | 2346 | 67.028571 | 2,635,722,517,898 | 5,214 | 2345 |
| E1M6 | 3385 | 3619 | 103.400000 | 5,459,324,203,074 | 7,762 | 3619 |
| E1M7 | 2572 | 2808 | 80.228571 | 3,305,344,543,682 | 6,138 | 2808 |
| E1M8 | 1638 | 3467 | 99.057143 | 2,068,482,084,762 | 5,863 | 3467 |
| E1M9 | 1598 | 1834 | 52.400000 | 1,695,970,243,929 | 4,190 | 1834 |

Totals: 14,475 gameplay tics, 14,484 independently verified
full canonical snapshots, 18,175 encoded frames, 519.285714 video seconds,
18,947,598,824,099 gas and 39,472 successful transactions.
All final-recording mined transactions succeed. 18,173 finite indexed frames equal
native; two remaining frames contain declared virtual-derived destinations.
25 direct virtual samples occur in 11 frames, including numerically matching
values; no universal native pointer equality is claimed. All nine final indexed
framebuffers have zero native differences. The historical 14,475 saved frames,
38 historical virtual uses, nine original tapes/archives and MP4s remain intact.

Measured receipt processing sums to 18795.220818s across maps, with
1.094161 emitted frames per summed rendering-RPC second.
This includes transport/mining/polling and is not exclusive EVM CPU time.
The aggregate processing/video ratio is 36.194373. Known active recorder
wall windows sum to 19089.645s for E1M2–E1M9; E1M1 inherited-prefix
wall bounds are unavailable. These work sums are not concurrent episode elapsed
time. Internal world/Status Bar/HUD gas subdivisions are unavailable. No
completed expensive EVM recording was rerun for optional telemetry.

Final metadata manifests, gas distributions, operation categories, attempts and
environment bindings: [episode summary](../artifacts/full-videos/EPISODE-SUMMARY.md),
[structured telemetry](../artifacts/full-videos/episode-telemetry.json),
[acceptance](../artifacts/full-videos/acceptance.json). Commercial pixels, IWADs,
MP4s, full receipts and state checkpoints stay under ignored artifacts/local.
[Reproduction instructions](../tools/reference/full_videos/README.md) include
profile flags, isolated ports, bounded concurrency and exact source bindings.

E1M1–E1M7/E1M9 end explicitly on original Entering/NoState(cnt1); this is a
recording endpoint. The frozen recorder's older 'handoff unsupported' label is
preserved as historical metadata and clarified in published manifests. The
small authoritative metadata adapter correction is separately compiled/source
audited; neither G_WorldDone execution nor subsequent level startup is claimed
verified. E1M8 preserves its original text timing, full forced art melt and105
regular CREDIT art frames. E1M9's verified didsecret/next metadata selects E1M4.

Focused verification remains54 original/new UI and storage tests, including
8 new melt tests, plus178 original-C melt steps across7 cases and O0/O2/sanitizer
profiles, all recorded in separate evidence. Initial dynamic-link harness
failures remain retained; their four focused tests pass with the existing
no-dynamic-test-linking option. Native allocation/display-history diagnostics
and the failed short pilot remain separate. The full historical Phase0–4 suite
was not rerun.

## Verified feature handoff

Publication/verification commit: `dabe805cc45f809e7c944a13cdd4d0c632e1b1e2`.
Implementation and reference commits:

- `f35e08a5d0339c99f9b9bb31942976bc21f42f02 📝 Bind allocation diagnosis to preserved reference proof`
- `5ec0069a54880069d011c7dd64f246383cdd89bb 🔬 Align native UI allocation and display references`
- `b4a4dcd2d231e0e68491623c2b02dd57a8ce0116 🐛 Restore authoritative metadata for intermission handoff`

Exact changed paths relative to the clean goal baseline are listed in
[changed-files.txt](../artifacts/full-videos/changed-files.txt). Ownership remains
the new F_Wipe library/support consumer/tests, full_videos tools and dedicated
metadata/reports. No shared production ABI, state types, browser protocol or
historical recorder is modified. The integration agent may adopt the source
library and small consumer metadata fix after separately checking production
interfaces; this feature does not perform that integration.

Reproducible verification commands from the assigned worktree:

```sh
python3 -m py_compile tools/reference/full_videos/*.py
node --check tools/reference/full_videos/verify-states.mjs
node --check tools/reference/full_videos/record-short-finale.mjs
node --check tools/reference/full_videos/pixel-trace.mjs
python3 tools/reference/full_videos/acceptance.py
```

The acceptance command rechecks the nine retained proof bindings, source hashes,
media SHA256, recorded frame/gas totals, final endpoints, five rollback checks
per map, historical preservation, long-pilot hash, focused tests and diagnostic
evidence. It refreshes the acceptance timestamp; it does not execute EVM.
Use the README for full native/receipt/media proof reproduction and new recordings.

Available goal-manager token/time attribution is captured as a measured
checkpoint in usage-attribution.json, separately from EVM gas/RPC/host telemetry.
No model monetary cost or missing CPU/wall attribution is estimated. Source
metadata handoff execution, next-level startup and browser/production acceptance
remain unverified; they are not required to complete these standalone endpoints.
All original C, original input/archive/frame evidence, historical MP4s and failed
attempts remain preserved. No merge or push was performed.
