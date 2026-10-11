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
