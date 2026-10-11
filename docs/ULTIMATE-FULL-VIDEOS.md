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
