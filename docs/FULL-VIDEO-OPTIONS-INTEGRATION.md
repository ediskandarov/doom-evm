# Full Video and Options integration

Designated Single Writer to Main checkpoint, 2026-10-11. Clean synchronized
baseline `411e6049f9e2ad496d45264facbb6fdafc3dbfa7`. Both feature worktrees were
clean at their requested final commits. Main was fetched and synchronized using
fast-forward only. No feature commits were already integrated or unrelated
commits included. Other worktrees and runtimes were not modified.

## History and implementation

Normal `--no-ff` merges preserve all thirteen source commits:

| Feature | Original commits, oldest first | Integration merge |
| --- | --- | --- |
| Full Video | bd2d479, 75441d8, c763e58, 94a8e39, b4a4dcd, 5ec0069, f35e08a, dabe805, **486e896633e0f6726ae842a03429e258ded45843** | ec32f9eb91d416f73ed53f78bbcd16fadf50d97c |
| Options | c4412ad, fbd2c97, 400684a, **184ea6624e6ea37a18f1d265ece66a172e6be609** | fb62949c829ca10f9e11ecd28096291d12ad4d3a |

Integration verification/tools and combined browser packages are committed at
`8351c8df91e44ec0292b3b0aa5e32fee26749cee`.

Order: Full Video, then Options. Full Video descends from `59522a5`; Options
descends directly from the latest baseline. There were no Git conflicts.
All122 Full Video files and36 non-release Options files retain exact feature
content. The four browser release/pin files were regenerated from the combined
compilation. Existing Frame/input APIs, resource identities, installation manager,
game switching, memory defaults and guarded pointer semantics are preserved.

No integration-specific production rendering change was necessary. The Options
UIState addition defaults to messages-on for the existing recorder. Its production
adapters bind the authoritative menu preferences, apply pending size refreshes
without a gameplay tic, synchronize `setUIFullscreen(bool)`, and preserve original
Status Bar redraw history. The recorder still deliberately captures view10.
Production menus remain EVM-rendered for all three games.

Combined builds use unchanged solc0.8.37, viaIR/optimizer200/Cancun,10B gas and
1GiB interpreter budget. Doom runtime895,029 bytes; Doom2 runtime876,852 bytes.
Regenerated browser selectors and immutable offsets match the Options handoff;
release bytecode/source bindings identify this combined compilation separately.

## Fresh verification on combined sources

| Gate | Executed result |
| --- | --- |
| Affected production/recorder roots | Compile passed;295.932s |
| Focused Forge | **52 passed**:34 Options/menu/HUD/input/lifecycle,14 wipe/finale/gameflow,4 WI storage/Frame/rollback |
| Focused Node | **72 passed**, input/menu/deployment/profile/recovery |
| Native startup |21 finite map/skill cases,63 original-C executions across O0/O2/ASan+UBSan |
| Native Status Bar resize |36 original ST steps; Freedoom41 changed background pixels, Ultimate/DOOM II37 each |
| Real three-game Chrome/Anvil |**23 checks,210 exact receipt/Frame/palette/Canvas checkpoints,15 native-matching map/skill selections,15 full-storage rollback proofs** |
| Sampled real-EVM recorder/composition |287 frames;**279 native-equal complete indexed framebuffers and palettes**,634 exact canonical gameplay observations |
| Corrected borrowed-UI E1M2 |First84 authentic commands,85 exact snapshots;45 frames including44 native-equal frames; tic84 final pixel(290,106)=8 |
| Standalone presentation rollback |8 combined probes plus1 E1M2 probe; failed transactions have no logs and unchanged complete storage roots |

Chrome installs Freedoom/Ultimate/DOOM II using the existing browser File API and
ordinary resource/game CREATE transactions. It verifies New Game, actual player
movement, direct representative maps, original skills and Nightmare confirmation/
cancel, DOOM II MAP32, Messages Off/On, Options persistence, no-render refresh,
screen clamps, original viewport APIs, Escape/Resume and End Game/title restart.
All three contracts remain isolated across switching/reload; detection reuses
installations without resource redeployment. Solidity defaults are2 before the
actual explicit profile3 initialization. Fresh Node checks preserve interrupted
installation, uncertain-receipt recovery and same-chain-ID reset rejection.
The browser's92,160 native Status Bar pixel comparisons retain the accepted
41/37 redraw behavior instead of assuming cached bars are history-independent.

The real-EVM presentation run deploys the unchanged merged FullSpeedrunProbe and
a separately generated verification-only composition consumer. Both replay the
authentic E1M1 prefix to its genuine316-tic exit, checking every one of317 complete
canonical snapshots. Gameplay displays are sampled at1,20 and316. The composition
also opens Options, changes10→11, resumes the native-exact fullscreen framebuffer,
reopens Options, changes11→10, resumes the restored native-exact bar, then completes
the authentic input prefix, melts and accelerates original WI through button edges.
Menu packets, displays, wipes and UI clocks preserve saved gameplay exactly.
Eight menu-overlay frames are transport-tested without being labeled whole-frame
native-exact; original menu drawing is separately covered by native-bound Forge
fixtures and the actual three-game browser gate.

Original G_DoCompleted supplies kills3/29, items2/38, secrets0/3, time316tics and
par1050tics to both Intermissions. No statistics are calculated by a recording
overlay. The fifteen post-exit integration commands are a separate UI appendix;
they neither modify original tapes nor count as gameplay tics. No G_WorldDone or
subsequent level startup is claimed by these standalone sequences.

The E1M8 verification fixture initializes authentic resources/map8 inside EVM,
enters original F_StartFinale, samples text at original counts10/100/1000/1570,
then verifies the original forced art melt and CREDIT art/palette. Every original
UI ticker executes; unrendered intermediate text clocks add no gameplay tic.
This is a representative finale fixture, **not a fresh genuine E1M8 speedrun exit**.
Source-agent genuine E1M8 completion remains inherited evidence.

Fresh gameplay/UI/finale comparisons use O0/O2/ASan+UBSan references with consistent
borrowed immutable UI assets including STTMINUS and matching sampled differential
display history. Entry melts use original C at O2 with independently native-rendered
endpoints; the focused wipe tests also retain the original three-profile state,
column/RNG, pixel and completion-delay fixtures. Full comparisons require zero
indexed-byte and palette differences; no native bytes are injected into EVM.

Dedicated ports19371/19372 (Chrome/site/Anvil),19373 (combined presentation) and
19374 (E1M2) were checked free. Only owned children are stopped. Reserved
18880/8088 and other agents' environments remain untouched. Full receipts,
commercial pixels, screenshots and native binaries are ignored local artifacts;
[published verification](../artifacts/phase4/full-options-main/integration.json)
retains metadata, hashes, commands and declared coverage.

## Native-reference investigations and preservation

The source Full Video diagnosis is preserved verbatim: mixed native UI allocated
STTMINUS as128 requested/168 physical bytes at malloc ordinal2126. The consistent
borrowed-UI reference excludes that zone allocation, matching EVM chronology.
At E1M2 tic84 the divergent sampled byte was byte0 of the neighboring **free-block
size**,96 versus8. It was original-written integer provenance1, not an unsupported
pointer byte. All mixed-profile failures, corrected references, observer patches,
failed recordings and historical goldens remain available unchanged. The new
focused E1M2 test independently matches all64,000 pixels and palette bytes across
the three declared native profiles without an EVM pixel or memory patch.

This integration's first bar-only composition checkpoint passed. A fuller view11
comparison then failed at Options resume/tic20:52,543 differing pixels, first at
(0,0). The new native comparison host had called original M_SizeDisplay /
R_SetViewSize but omitted original D_Display's R_ExecuteSetViewSize. Native
rendering therefore retained view10. Correcting that host call produces exactly
the already-mined EVM fullscreen SHA256
`827af4df5a5edd69946a2fdff300c606a3ed6d457e8f9d826b6094c24633ef41`.
The subsequent complete combined gate passes. Original C, EVM pixels and accepted
goldens were not changed. The failed raw report/log/reference directory and first
successful checkpoint are preserved separately; published failure metadata avoids
embedding raw commercial framebuffer bytes. Earlier generator/import/type errors
are also retained as verification-helper failures, not engine regressions.

## Inherited recording evidence and limits

The source agent's accepted totals remain **18,175 video frames**,14,484 matching
native/EVM gameplay snapshots,18,173 finite native-equal frames, nine genuine exits,
35FPS/4:3 presentation,18,947,598,824,099 gas and39,472 successful transactions.
These are inherited results; this integration did not regenerate nine MP4s or
rerender18,175 frames. The two virtual-derived whole-frame exceptions remain
exceptions. There are25 direct virtual samples in11 frames, even when values happen
to match native; no universal native pointer/pixel equivalence is claimed. All nine
final indexed framebuffers have zero native differences in the declared profile.

All27 bound historical MP4s remain at their original absolute locations with
unchanged SHA256/size/mtime. The nine final presentations are in the source
worktree's `artifacts/local/full-videos/E1M1/pilot-short-v2/` and
`E1M2`–`E1M9/complete-short-v1/`. Exact links and media hashes remain in
[EPISODE-SUMMARY.md](../artifacts/full-videos/EPISODE-SUMMARY.md).
No commercial IWAD, extracted commercial asset, raw commercial frame or MP4 was
committed; no recording was deleted, overwritten or re-encoded.

Native fidelity remains **RESTRICT** to the declared borrowed-UI/LP64/initial-zone
and display-history profiles. Preserve E1M3/E1M5 initial-zero-zone limitations,
adversarial-fill failures, mixed-profile failures and the documented virtual
exceptions. Strict, deterministic, Episode and experimental memory policies,
pointer provenance and unknown-byte rejection remain unchanged. Profile3 stays
explicit; Solidity defaults remain2. No Relaxed Rendering.

Standalone recordings end at Entering or E1M8 art. G_WorldDone and following startup
remain unverified by these recordings. Production browser melt orchestration is
not added by this source integration. Smaller bordered views3–9, Low Detail,
Mouse Sensitivity and F11 Gamma remain unsupported; Save/Load, Death/Respawn,
palette-effects/visual-gap work, audio/music and multiplayer remain separate.
DOOM II MAP30 text is supported; the unported cast boundary still rejects.
Complete inherited Phase0–4 acceptance and all full speedrun reruns are deferred.

Original source handoffs are preserved:
[Full Video](ULTIMATE-FULL-VIDEOS.md), [Options](OPTIONS-LEVEL-SELECTION.md),
[Options API handoff](../artifacts/options-level-selection/api-compatibility/handoff.json),
[source allocation diagnosis](../artifacts/full-videos/diagnostics/E1M2-allocation-divergence.json).

Measured publication checkpoint:2026-10-11 17:15:47UTC; goal-service410,594
aggregate tokens /2,460 elapsed seconds. Missing per-model/cost attribution is
unavailable and not estimated. Final commit/push and completion usage follow.
