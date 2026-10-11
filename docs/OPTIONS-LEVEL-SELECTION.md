# Options and SELECT LEVEL feature goal

## Scope and baseline

Started 2026-10-11 15:15:28 UTC. Owner: Options feature agent, branch
`feat/options-menu`, isolated pre-created worktree
`/Users/eduard/sandbox/doom-evm-options`. Fetch confirmed latest `origin/main`
and clean feature HEAD are `411e6049f9e2ad496d45264facbb6fdafc3dbfa7`.
No main writes, merges, pushes, or other worktree/runtime changes are authorized.

Own original menu implementation, focused menu tests/oracles, goal-specific
verification and report. Required adapter edits will be delivered as feature
branch integration proposals for the integrator's shared-interface review;
Frame, input/resource protocols and authentication stay frozen. No Save/Load,
death/rebirth, recording tools, palette rewrite, memory-default/provenance or
relaxed-rendering implementation. Reserve isolated verification ports 19281
(Anvil) and 19282 (HTTP); refuse occupied ports. Workloads run sequentially.

Stop after functional supported Options, all three authenticated map/skill
flows, focused native/Forge/Node and real Chrome/Anvil checks, Gitmoji commits,
clean feature worktree and exact handoff. No historical full acceptance run.

## Initial source audit

Pinned original: `a77dfb96cb91780ca334d0d4cfd86957558007e0`.
`m_menu.c` defines End Game, Messages, Detail, Screen Size, Mouse Sensitivity,
Sound Volume, spacer rows and their sliders. Original Escape closes menus;
Backspace follows prevMenu. Confirmation accepts space/n/y/Escape, and closes
menus even on cancel. Nightmare starts only on `y`.

| Original option | Integrated baseline | Implementation boundary |
|---|---|---|
| End Game | Missing menu/action | Original confirmation and title return |
| Messages | Original generation/HU rules implemented but setting unconnected | Wire persistent setting and original forced MSGON/MSGOFF |
| Detail | Low-level low-detail primitives exist; production hard-codes high | Pinned Linux `M_ChangeDetail` itself prints low detail unavailable and returns before R_SetViewSize; document renderer integration gap, no fake toggle |
| Screen Size | Runtime has authentic blocks 10/11; no menu | Expose these supported original sizes/thermometer positions (7/8); blocks 3–9 require original border/background and HUD erase integration |
| Mouse Sensitivity | Intentionally unsupported keyboard-only input | Omit control; no mouse subsystem |
| Sound Volume/music | Project exclusion | Omit audio controls |
| Gamma (F11, outside Options) | Existing ST palette gamma path | Preserve; do not rewrite |

Existing SELECT LEVEL already opens original skills after one map choice.
Commercial menu paginates eight maps per 320x200 screen. NEW GAME preserves
E1 episode choice / commercial direct skill choice. Production evidence still
needs checking, including all five skills and existing-game replacement.

## Verification gates

- Compare source-extracted original Options graphics, responder/settings and
  confirmation behavior under O0/O2/sanitized native profiles; preserve old goldens.
- Focused menu/HUD/input/gameflow Forge tests; Node transport/install regressions.
- Ordinary authenticated CREATE and sequenced production transactions, profile3:
  E1M1/MAP01 all skills, non-first maps, MAP32, Nightmare/cancel/back, restart
  replacement, original NEW GAME, actual spawn totals/RNG/inventory, setting
  persistence and mined storage-root rollback.
- Owned real Chrome/Anvil with actual browser installation, profile switching,
  DOM keys and exact receipt Frame→palette→Canvas comparison; no HTML menus.
- Bind source/ABI/resource/compiler identities, actual counts, limits, evidence
  hashes and measured times. Record only demonstrated coverage.

## Implementation and fidelity boundaries

Production MAIN now has NEW GAME, SELECT LEVEL and OPTIONS. SELECT LEVEL remains
one map list followed by existing NewDef and existing five patch-based skill
rows. No extra SELECT MAP screen or duplicate skill definitions were added.
`Doom` authenticates Freedoom/Ultimate resource profiles; `Doom2` authenticates
DOOM II resources and initializes the commercial menu. DOOM I lists only E1M1–9;
DOOM II lists MAP01–32 with eight-row pages and continuous wrapping arrows.
Main hotkeys are n/s/o. Original Enter, arrows, letter cycling, Escape (close all
menus), Backspace (previous menu) and Nightmare y/n/space/Escape behavior persist.
Skill Backspace returns to the remembered selected map. Map Backspace returns
to MAIN. The original Episode-One/DOOM-II NEW GAME branches remain intact.

`M_Options`, `M_ChangeMessages`, `M_SizeDisplay`, `M_EndGame`,
`M_EndGameResponse`, `M_DrawOptions` and `M_DrawThermo` map corresponding original
functions. End/Message/Size row coordinates are unchanged: OptionsDef x=60,
y=37, line height16; title108,15; message value180,53; size thermometer60,101.
The original nine-slot thermometer uses original dot positions7/8. Arrow-left
stops at7 (blocks10); arrow-right/Enter stops at8 (blocks11). The inactive Detail,
Mouse, spacers below Screen Size, and Sound rows are omitted from production;
arrow navigation skips the absent Detail row. The separate non-extended graphics
oracle retains the complete original high-detail/mouse5 layout for comparison,
including all nine size positions; it is not a functional production setting.

Messages persist outside game state through new games and per-level HUD restart.
`UIState.hideMessages` is the inverse of original showMessages; its zero default
preserves existing non-menu callers. Original HU_Ticker receives the setting;
original pickup, cheat and door message generation stays unchanged. Toggling
queues original `Messages ON/OFF` and the original force-display HUD flag. The
inherited production menu pauses all gameplay/UI tickers, so this notice reaches
the HUD on resume. Original message expiration, protected notices and retained
pending Player.message follow the existing original HU implementation.

Screen Size changes the EVM `R_ExecuteSetViewSize` path through the existing
blocks10/11 renderer and `ST_Drawer` fullscreen argument. It never resizes CSS.
A display refresh applies the request without G_Ticker, leveltime, movement or
RNG advancement. No-render requests retain the display refresh until a later
rendered Frame. Status Bar is refreshed when shrinking; full-screen rendering
replaces its screen region when enlarging. No renderer algorithms were changed.

End Game accepts only original y confirmation, preserves cancel/unknown-key
rules and the Options lastOn. Confirm disables the active game, clears action,
sets the bounded title gamestate and restores the existing base palette path;
subsequent title input opens the control panel. Original D_StartTitle's demo
carousel is not implemented: this adapter displays authenticated TITLEPIC only.
Dormant storage is not serialized or deleted; gameplay APIs reject it while
`gameStarted=false`. Subsequent start uses fresh original G_InitNew/setup state.
Direct level selection during play continues through G_DeferedInitNew → original
G_Ticker, not an exit. Original inventory reset, difficulty mutation, startup RNG,
and map skill filters remain engine-owned. No Intermission is requested.

### Unsupported original options

- **Smaller screen sizes (blocks3–9):** R_Main calculates dimensions already, but
  DoomGame.render rejects these blocks. R_Draw lacks original R_FillBackScreen
  and R_DrawViewBorder. Supporting them requires original FLOOR7_2/GRNROCK
  background tiling, eight BRDR_* bevel patches, screen1 → screen0 border copies,
  HUD erase with real viewwindowx/y/back buffer, pause positioning, authentic
  status composition and native/EVM pixel verification for all dimensions.
- **Detail:** pinned Linux m_menu.c M_ChangeDetail (1131–1147) toggles its variable,
  prints `low detail mode n.a.` and returns before commented R_SetViewSize. The
  port has original low column/span primitives and detailshift branches, but
  production DoomGame.render always passes detail0. A separate renderer feature
  must thread detail through view setup, projection, walls/planes/sprites/psprites,
  fuzz/translation quirks and persistence, then prove defined original pixels
  against direct renderer oracle profiles. This goal exposes no fake Detail toggle.
- **Mouse Sensitivity:** production/browser input is keyboard packets only; original
  mouse events and deltas are absent. No mouse control or subsystem was added.
- **Sound/Music:** excluded project-wide; omit Sound Volume and volume controls.
  No audio implementation or audio-related RNG/gameplay changes were added.
- **Gamma:** ST_Stuff already contains original gamma tables and palette expansion;
  damage/bonus/radiation palette paths and FramePalette are preserved. Original
  F11 dispatch is not connected in this keyboard menu profile. No alternate
  palette implementation or new gamma control was introduced.

### Integration interfaces and other owners

The feature branch proposes shared adapter edits for integrator review: both
Doom contracts handle Options requests identically, UIState adds one inverse
message-visibility flag, and EpisodeRuntime uses that flag in HU_Ticker. MenuState
adds Options menu history and persistent settings plus transient request flags.
Keep original Frame/input/resource ABIs and memory defaults; interactive
installations still explicitly request profile3, with original virtual-pointer
provenance unchanged. New read-only `optionsStatus()` returns messages,
screenblocks and active-game flag; `spawnStatus()` returns original kills/items/
secrets totals, actor count and gameplay RNG. Existing `menuStatus()` remains
nine words, so existing browser transport needs no UI or protocol change.

Save/Load owner: production has no connected Save/Load actions or serialization.
The legacy non-extended drawing surface still retains M_LOADG/M_SAVEG patches.
Extend main item dispatch/hotkeys and menu history with dedicated save/load
screens; return using M_SetupNextMenu and preserve menu-first packet ownership.
Snapshot/restore authoritative map/skill/world and required HUD/runtime state;
original global Options settings remain session preferences. Do not reinterpret
SELECT LEVEL as restoring a save. Merge UIState/MenuState layout changes through
the integrator before combining serializers; browser menuStatus is unchanged.

Death/Respawn owner: authoritative gameskill/gamemap and existing reborn/load
lifecycle are unchanged. Recording/visual owners: no Status Bar, Intermission,
Melt Wipe, original gameplay, renderer modules, resource schemas or recording
tools were edited. Menu resize redraw uses existing EpisodeRuntime.draw with
no gameplay tick. Browser releases must be repackaged after integration so pins
bind the merged sources; older installation journals remain keyed by their old
artifact hash and are neither erased nor reconfigured by this feature.


## Verified checkpoints (integration pending)

Baseline production audit reuses the source-bound real Chrome/Anvil evidence in
`artifacts/phase4/three-game-browser-main/chrome.json` (20 Canvas checkpoints,
pass, ended 2026-10-11 12:00:23.862 UTC; SHA256
`7a82ae4a9cd20283006410dadc96cd350a81ad682b1c68d800b9809c2110208b`) and
`artifacts/phase4/virtual-menu-main/menu-evm.json` plus
`artifacts/doom2/menu-evm.json`. These demonstrate integrated original NEW GAME,
SELECT LEVEL → existing skills and authenticated production behavior before
this feature. Options absence was confirmed against the deployed-artifact source
and exhaustive menu dispatch, rather than inferred from a missing browser panel.

- Production roots built with solc0.8.37, viaIR, optimizer200 and Cancun unchanged;
  final production compile measured 251.05 seconds. Build logs are retained in
  `artifacts/local/options/production-build-final.log`.
- `python3 tools/reference/options/reference.py`: 146 native checkpoints across
  O0/O2/ASan+UBSan; 144 original complete Options frames, End Game frame and
  29-event/11-field supported Options responder trace. Forge verifies every
  indexed byte through SHA256; compact expected frame hashes avoid redundant
  fixture artwork. Earlier original menu fixtures remain byte-identical.
- `python3 tools/reference/options/startup-native.py`: 21 map/skill cases across
  O0/O2/ASan+UBSan (63 executions); original G_InitNew, P_SetupLevel and one idle
  P_Ticker. This includes every first-map skill and E1M2/E1M9 or MAP07/MAP32.
  Original spawn totals, RNG, inventory and pointer-free records agree. Measured
  elapsed time45.62 seconds; full manifests and local outputs are preserved.
- `python3 tools/reference/options/focused.py`: 34 tests / eight suites pass,
  zero failed/skipped; measured108.06 seconds including compile. Covers new
  Options, old menu, commercial menu, HUD messages, input and gameflow lifecycle.
- `node --test web/menu-input.test.mjs web/input-runtime.test.mjs
  web/input-loop.test.mjs web/input-app.test.mjs web/install.test.mjs
  web/input.test.mjs web/doom2-profile.test.mjs web/browser-profiles.test.mjs`:
  72 pass, zero failed/skipped.

### Original-C first-map spawn observations

Skills here are original zero-based engine skills0–4, in original menu order.

| Game | Monster totals by skill | Item totals by skill | Gameplay RNG after first idle tic |
|---|---|---|---|
| Freedoom | 17 / 17 / 29 / 46 / 46 | 53 / 53 / 49 / 48 / 48 | 54 / 54 / 61 / 97 / 97 |
| Ultimate DOOM | 4 / 4 / 6 / 29 / 29 | 37 / 37 / 37 / 38 / 38 | 141 / 141 / 144 / 193 / 193 |
| DOOM II | 9 / 9 / 19 / 27 / 27 | 9 / 9 / 9 / 9 / 9 | 53 / 53 / 73 / 89 / 89 |

Easy skills0/1 share mapthing filter flags; UV/Nightmare3/4 share hard flags.
Nightmare's original fast/respawn behavior is distinct through existing engine
G_InitNew logic; matching spawn totals is expected. No new skill definitions were
introduced. These observations do not claim exhaustive nightmare gameplay.

The first browser attempt's strict “restored bar equals prior cached bar” gate
failed and remains preserved at `artifacts/local/options/browser.json`. Native
investigation (`python3 tools/reference/options/status-resize.py`) then ran the
unchanged original ST_Drawer/ST_lib sequence: ordinary initial draw, god-mode
tick/differential draw, full-screen refresh, status-bar refresh. Original C itself
changes41 background pixels for Freedoom and37 for each commercial IWAD on the
forced refresh, with unchanged player state. This follows original old-icon
restores and widget/background draw order. O0/O2/ASan+UBSan agree. The browser
gate now compares both prior and restored regions directly against their exact
original-C expected10,240 bytes, instead of assuming a history-independent bar.
No Status Bar code, golden or original-C body was changed. The failed first gate
is not relabeled a pass.


The original C resize oracle borrows each authenticated IWAD's actual status-bar
assets through the existing original host boundary; it runs36 ST steps (three
games × four history steps × three compiler profiles). Native force-refresh
background differences are an original rendering quirk, not a new menu effect.
Expected raw commercial patches/status pixels remain in ignored local artifacts.
The final browser report uses a separate `browser-final` prefix, preserving all
first-attempt screenshots, logs and the failed assertion report.

## Cross-agent overlap audit — 2026-10-11 15:53:34 UTC

Read-only inspection of both worktrees included uncommitted and committed
changes. No other worktree, branch, runtime or recording process was modified.

| Shared boundary changed here | Exact proposed change | Video/Save integration concern |
|---|---|---|
| src/evm/Doom.sol and Doom2.sol | Menu initialization, _newEpisodeContext preference binding, _stepMenu Options requests/redraw/title transition; additive optionsStatus/spawnStatus | Reconcile menu/title/resize draws with future display/wipe orchestration; preserve atomic input sequence and one normal Frame |
| src/evm/DoomUI.sol | UIState.hideMessages plus two HU_Ticker argument changes | Recompile recording/snapshot adapters using UIState; zero preserves messages-on recordings; no drawStatus implementation change |
| src/evm/EpisodeRuntime.sol | hudTicker passes !a.ui.hideMessages | Preserve video-owned draw/pass ordering, WI/finale and displayedGamestate histories |
| src/doom/m_menu.sol and src/evm/DoomMenu.sol | Options menu/history/settings/requests; active game flag and End Game packet stop | Save/Load main dispatch must retain n/s/o entries, correct previous menus and menu-first ownership |
| web/install-assets/Doom.json, web/install-pins.mjs, web/doom2-assets/Doom.json, web/doom2-pins.mjs | Generated source-bound release artifacts | Integrator regenerates once against merged sources; do not merge stale binaries/pins by choosing one agent's version |

Video branch `feat/full-speedrun-videos` was at94a8e39. Its committed code changes
include original `src/doom/f_wipe.sol`, `src/support/FullSpeedrunProbe.sol` and
`test/unit/f_wipe.t.sol`; its uncommitted work includes FullSpeedrunProbe and
`tools/reference/full_videos/*` native/profile/recording/verification tools and
its own reports/evidence. There is no direct changed-file intersection in the
observed feature diffs, but FullSpeedrunProbe calls shared DoomUI.drawStatus,
DoomUI.drawHUD, DoomUI.erase and DoomGame.render(c,10). The shared UIState type and
production redraw entry points therefore need integrator review even without a
textual merge conflict.

No edits here touch ST_Stuff, ST_Lib, DoomGame.render, R_* renderer modules,
WI/finale/wipe modules, the shared statusbar native host/reference or the video
agent's recording and native profile files. View borders remain unsupported for
blocks3–9; adding their implementation is an explicit dependency on coordinated
renderer/background/HUD erase changes, not an independent rewrite in this goal.

**Keep the findings separate:** the video E1M2 discrepancy was an inconsistent
native STTMINUS allocation profile; its EVM frames were already correct. This
goal's41/37-pixel differences are reproduced by unchanged original ST_Drawer /
ST_Lib redraw history with all UI resources borrowed consistently (including
STTMINUS); they are not automatically EVM defects. The local size-refresh oracle
uses the existing comparison-only statusbar host, whose W_CacheLumpName routes
all ST resources to immutable loaded buffers. It changes neither a shared native
profile nor a production renderer. Native evidence correction is separate from
production corrections; prior failed evidence and goldens remain preserved.

### Required integration order and focused post-merge checks

1. Integrator refreshes main, inspects both exact handoffs and freezes shared
   UIState/MenuState layouts and production display/Frame responsibilities.
   Preserve video-owned wipe/WI/finale and native-profile corrections as their
   original feature commits and evidence. Preserve this goal's supported-size
   bounds and Menu/Options settings without modifying original draw algorithms.
2. Reconcile Options request/redraw hooks in both Doom adapters and HU setting
   binding; rebuild recording/snapshot consumers against the agreed UIState.
   A size change is a display refresh, not a level exit or gamestate transition.
   A confirmed End Game is a title transition; future Melt ownership must handle
   its source-faithful display integration without making Options a wipe owner.
3. Regenerate source-bound browser artifacts/pins against the merged HEAD.
   Run the focused34-test Options gate and72 Node input/install regressions,
   original Options native graphics/state checks and original size-refresh
   comparison. Retain their finite profile boundaries.
4. Run actual three-game menu startup/Options/Chrome regression against the new
   merged artifacts, including profile3, all skills, MAP32, same-sequence rollback,
   paused/no-render resizing and native refreshed status regions. Run video-owner
   focused wipe/WI/finale and full-frame comparisons, especially corrected E1M2
   STTMINUS profile and inherited full-screen/status-bar recording checkpoints.
   Run save/restore and death/rebirth owner checks against agreed layouts if those
   commits are integrated. This is targeted post-merge coverage, not a request to
   run historical complete Phase0–4 acceptance.

## Verified core handoff checkpoint and API compatibility follow-up

Core implementation/native/browser evidence is committed at
`c4412ad` (Options, tests, original C observations, coordination report) and
`fbd2c97` (source-bound browser release artifacts). The core three-game browser
run ended2026-10-11 15:55:05.345 UTC: 252 exact Canvas frames,27 production
map/skill selections,15 mined storage-root rollbacks, all three game installations
and profile switching. Every first-map skill and representative later-map
startup matched original C spawn totals, health, inventory and gameplay RNG.
The original NEW GAME, Nightmare/cancel/Back/Escape, Messages visibility,
no-render resize, original status refresh and End Game/title restart gates pass.
This is an isolated feature checkpoint, not main integration or historical final
acceptance. Its committed certificates remain preserved in
`artifacts/options-level-selection/`.

Inspection then found that the inherited `setUIFullscreen(bool)` API would change
UIState.fullscreen while leaving the new menu thermometer value stale; the next
menu packet would overwrite that API choice. The follow-up adds only a
menuMode-guarded synchronization of MenuState.screenSize in each existing setter,
after its unchanged driver/UI guards. It removes an unreachable preference
binding from the legacy initializer. No rendering function or original native
profile changes. Both APIs/ABI signatures remain unchanged.

This additional shared adapter dependency must be reconciled by the integrator
in **Doom.setUIFullscreen and Doom2.setUIFullscreen**, alongside _stepMenu, so
there is one authoritative EVM setting across both entry points. Focused final
browser verification also calls each existing setter in both directions, checks
the Options value before rendering, frozen gameplay, no setter Frame/sequence
consumption and native-exact restored status pixels. Its separate evidence lives
in `artifacts/options-level-selection/api-compatibility/`; it does not overwrite
the verified core certificate or the first failed redraw-assumption evidence.


## Final verification and recoverable handoff

The API compatibility compile measured250.52 seconds; compiler0.8.37,
viaIR/optimizer200/Cancun and default10-billion gas budget are unchanged. Final
real Chrome/Anvil run: `2026-10-11T16:09:57.450Z` → `2026-10-11T16:20:17.372Z`. It passes258 exact
receipt Frame/palette → Canvas checkpoints,27 actual new-game map/skill selections,
15 mined all-storage-root rollback proofs and6 original full-screen API calls
with zero logs/sequence consumption. All three installed games switch/reopen
without affecting other game state. Original-C spawn counts, first-tic RNG,
health, inventory and requested map/skill agree. Nightmare confirmation/cancel,
Back/Escape, original NEW GAME, existing-game replacement with no Intermission,
Messages Off/On, reopening/persistence, screen clamps, no-render display refresh,
End Game and fresh title startup pass. Native status comparison covers92,160
indexed pixels (three10,240-byte regions per game), including API restoration.
Maximum successful final Frame gas: 4,767,591,509;
no peak EVM MSIZE or guaranteed FPS claim. Both owned browser and Anvil, the
owned HTTP server and temporary Chrome profile were stopped/closed by cleanup.

Reproduction from this feature worktree, sequentially:

```sh
python3 tools/reference/options/reference.py --check
python3 tools/reference/options/startup-native.py
python3 tools/reference/options/status-resize.py
python3 tools/reference/options/focused.py
.toolchain/bin/forge build src/evm/Doom.sol src/evm/Doom2.sol src/evm/ResourceStore.sol --offline --no-lint
node tools/browser-deployment/package.mjs
node tools/reference/doom2/package.mjs .
node --test web/menu-input.test.mjs web/input-runtime.test.mjs web/input-loop.test.mjs web/input-app.test.mjs web/install.test.mjs web/input.test.mjs web/doom2-profile.test.mjs web/browser-profiles.test.mjs
node tools/reference/options/browser.mjs --output-prefix artifacts/local/options/browser-api-final --ultimate-wad artifacts/local/options/DOOM.WAD --doom2-wad artifacts/local/options/DOOM2.WAD
python3 tools/reference/options/certificate.py --check
git diff --check
```

Native/production resource packs are worktree-local copies of already authenticated
installed inputs. Reproduction requires the exact pinned Freedoom/Ultimate/DOOM II
IWADs and ignored local full resource packs; no commercial IWAD, raw commercial
UI/frame payload or video is committed. Final source/ABI/resource and evidence
hashes are bound in
`artifacts/options-level-selection/api-compatibility/verification.json` with
actual source-bound browser, native startup/status and focused reports alongside.
Core checkpoint certificates under `artifacts/options-level-selection/` remain
bound to the prior verified checkpoint `fbd2c97`, not relabeled as final sources.
The failed first redraw assumption remains local and hash-bound in final evidence.
Previous accepted source, oracle fixtures, certificates and other-owner worktrees
are preserved.

Implementation and feature verification are complete. Main integration and
post-merge video/save/respawn regressions remain the integrator's responsibility,
in the integration order above. Source proposals change6 implementation files:
m_menu, DoomMenu, Doom, Doom2, DoomUI and EpisodeRuntime; existing Frame/input/WAD
ABIs, memory policy defaults and renderer/gameplay algorithms are unchanged.
New read-only inspection APIs are optionsStatus/spawnStatus; setUIFullscreen and
menuStatus keep their existing signatures. Browser artifacts/pins require merged
source regeneration. No Save/Load serialization, alternate respawn, wipe,
recording tool, border implementation, audio or relaxed renderer was introduced.

Branch: `feat/options-menu`. Local Gitmoji commits preserve core implementation,
release packaging and the small API compatibility follow-up separately. Stop
here after final commit and clean status; do not merge, push main, or begin another
goal. No branch has been pushed by this workstream.


Available usage attribution is recorded without estimates in
`artifacts/options-level-selection/api-compatibility/usage-checkpoint.json`:
get_goal's measured pre-final-commit checkpoint reported347,666 aggregate tokens
and4,045 elapsed seconds. No token budget was requested. Per-model/cache billing
and dollar attribution were not supplied; none is estimated. Goal start was
2026-10-11 15:15:28 UTC; runtime verification end times above are measured,
with commit/handoff completion recorded by Git/final goal status separately.
