# Goal 4.12 — Production Cheats and Automap

## Scope, baseline and ownership

Baseline: `9f7d09120a1a250fe38f85b4f4bcba6cc78b5117`. Branch:
`feat/phase4-input-runtime`; owner: this session, exclusively in
`/private/tmp/doom-evm-input-runtime`. Measured start: `2026-10-10 12:29:26 UTC`.
The worktree and branch were created from the requested baseline and were clean.
The baseline AGENTS.md was read; it retains the independent worktree/runtime,
source-fidelity, focused verification and Gitmoji requirements.

Connect merged ST_Cheats and AM_Map to production gameplay, persistent raw
keyboard events and the completed Goal 4.11 UI/Frame pipeline. Browser code
transports original key events; Solidity recognizes cheats, updates gameplay,
projects the live automap world and generates all indexed pixels. Preserve
legacy world-only and Status Bar/HUD APIs and evidence. IDCLEV recognition and
its deferred skill/episode/map request persist; Episode Runtime will own action
consumption and synchronous loading. No Episode resource, Intermission, main,
merge or push work is authorized. Stop after verified feature commits and handoff.

Owned surfaces: production Doom/DoomGame/DoomUI and directly related keyboard
adapters, dedicated tests/oracles/runners/evidence and this progress document.
Original C, accepted fixtures/goldens, compiler/viaIR/Cancun, budgets, resource
schemas and the frozen Frame ABI remain pinned. Main and other worktrees are
outside ownership. Do not use ports 18579, 18880 or 8088; runners must refuse
occupied ports and clean up only their own processes.

## Reconciliation with completed Goal 4.11

The previous discovery remains applicable: ordered HU -> combined ST/cheats ->
AM -> native held-key routing; one persistent parser path; original ST -> AM ->
HU tick order; AM uses the existing framebuffer instead of world rendering.
Goal 4.11 finalized separate UIState storage, view-size 10/11 overloads,
borrowed patch/font attachment, FramePalette and browser receipt/WS palette
association. Extend these existing functions rather than recreate them.

Two assumptions are now explicit: UI tickers are dispatched by DoomUI after
DoomGame.tick (not production GameflowHooks), and gameflow/multi-map loading is
outside this goal. Therefore preserve IDCLEV's GA_NEWGAME request and its exact
selection without introducing G_Ticker action dispatch or a substitute loader.
AM_Map owns IDDT cheatPos/cheating; production never calls the standalone
ST_Cheats.AM_CheckCheat or consumes its duplicate reveal state.

## Verification gates and stop condition

1. Build affected roots with pinned settings; focused changed-module and consumed
   cheat/automap/UI/video/player/input tests, formatting and source/ABI checks.
2. Original C comparisons for combined event routing, cheats, AM state/pixels,
   authoritative live projection and existing Status Bar/HUD composition.
3. Ordinary CREATE/resource authentication and targeted EVM transactions,
   persistent split prefixes/parameters, input consumption, no-render tics,
   Frame/palette identity and complete-storage rollback on failed commands.
4. Real browser raw input -> EVM Cheats/Automap -> Canvas readback, receipt/WS
   association, aliases/repeat/release, and blur/stop handling.
5. Commit implementation and separate evidence/report with Gitmoji; record exact
   SHAs, changed files, reproducible commands, measured counts/costs and Episode
   Runtime hook. Leave a clean recoverable feature branch. Full inherited
   Phase 0–3 and final Phase 4 acceptance are deferred.

## Progress

| Checkpoint | Implementation | Integration | Verification | Next |
|---|---|---|---|---|
| Baseline and UI reconciliation | Not started | Goal 4.11 accepted | Clean requested baseline; instructions and UI handoff read | Implement ordered event adapter and live AM projection |
| Production runtime | Complete | Feature worktree only | Final pinned production build, native/EVM/Chrome and focused gates pass | Commit verified implementation and proof |
| Implementation `1cfd318` | Committed | Feature branch only | Source-bound final proof and preserved UI profile pass | Commit proof/tools/report handoff |

Measured timings, available usage attribution, failed gates, source/resource
identity and evidence hashes will be recorded at verified checkpoints. Missing
measurements will not be estimated.

## Delivered production behavior

`initializeGameInput(bool fullscreen)` starts the accepted single-player retail
E1M1 medium-skill game, Status Bar/HUD and fresh persistent input/AM globals.
It opts into `stepEvents(bytes,uint32)` / `stepEventsAndRender(bytes,uint32)`.
Each packet contains at most64 ordered `[type,key]` byte pairs (keydown0, keyup1).
Empty packets tick held keys. Driver and inputSeq authorization remain atomic.
Existing world-only/UI initializers and bitmap command profiles remain available;
raw mode rejects conflicting bitmap commands. Frame and FramePalette are unchanged.

| Original boundary | Production connection |
|---|---|
| G_Responder supported level/keyboard branches | InputProtocol: F12 spy branch, HUD first, combined status/cheats, AM, then unconsumed native keys |
| ST_Responder cheat portion / m_cheat | Existing ST_Cheats and M_Cheat; all16 sequences persist, including raw parameter bytes; slot15 remains unused by production |
| AM_Responder IDDT | AM_Map alone owns AutomapState.cheatPos/cheating; no second recognizer or mirrored reveal state |
| Original held keys / G_BuildTiccmd | Persistent256-bit native key set; existing original builder; browser WASD/E aliases project in EVM after responder consumption |
| G_Ticker level order | Existing P_Ticker, then ST_Ticker -> AM_Ticker -> HU_Ticker; no-render and paused UI tics retain module histories |
| D_Display supported views | HU_Erase -> AM if active -> ST -> world if inactive -> HU -> original pause patch; existing full-frame emitter |
| Original AM borrowed globals | Live ordered vertices/linedefs/current heights and flags, player actors/powers/block origins, sector/snext thing traversal |
| AM lifecycle cross-calls | Immediate combined-ST notification handling, selected-player messages, marker load/unload counters and Stop->Start ordering |

Implemented cheat effects use the same authoritative player/actor/world as
gameplay and Status Bar. HUD consumes Player.message through its unchanged
ticker, retaining original NUL/stale backing bytes. Parser cursors and mutable
sequences survive transactions and AM/UI lifecycle. No timing window, case
folding inside recognition, mismatch retry, difficulty/health/pause filter or
new inventory behavior was introduced. IDDQD, IDFA/IDKFA, both noclip codes,
IDBEHOLD and its variants, IDCHOPPERS, IDMYPOS, IDCLEV and IDDT reuse the merged
implementations; IDMUS remains excluded.

Automap writes only its original upper168 rows into the existing framebuffer;
status/HUD supply the remaining composition. It draws original follow/pan/zoom,
overview, grid, marker and IDDT stages. Renderer-owned ML_MAPPED flags persist.
Active AM skips world rendering and its discovery/fuzz/frame-cache mutations.
Fullscreen still displays the status bar in AM and the original map title.

Original AM_Stop emits `[keydown,1,AM_MSGEXITED]`. This is intentionally passed
to ST cheats too; it can complete pending raw parameter capture. The adapter
does not repair the original initializer. Message assignments are copied only
when AM actually assigns them, so old strings are not replayed after HUD clear.
Markers and other UI assets borrow authenticated WAD bytes per call, following
Goal4.11's declared consumer boundary. Mutable histories persist, patch/font
bytes do not. No new whole-process zone-allocation equivalence is claimed.

Browser code translates original unshifted US printable/special key numbers,
preserves repeats and order, buffers during receipt waits, and forwards packets.
It performs no cheat matching, gameplay, geometry or indexed pixel generation.
Stop/blur clears physical holds and settles releases through serialized
no-render packets, preventing stuck movement/pan/zoom. Failed mutations are not
automatically retried; uncertain submissions retain the existing reconciliation
lock. Canvas only expands authenticated EVM indexes using EVM-selected palettes.

## Verification and evidence

The [certificate](../artifacts/phase4/input-runtime/verification.json) binds
source/ABI/compiler/resource identities and all exported evidence. The
[reproduction commands](../tools/reference/input-runtime/README.md) execute
the gates; the certificate checker checks recorded bindings only.

- Focused Forge: **220 passed,0 failed,0 skipped**,25 suites, fixed fuzz seed
  `0x412`; includes seven new adapter tests plus consumed cheats/AM/ST/HU/video,
  player/interactions/command/storage and affected renderer cases. Native AM
  and video bounds fuzzing retain256 runs. Existing assertions and fixtures
  remain unchanged. [Log](../artifacts/phase4/input-runtime/focused.log).
- Node: **56 passed,0 failed,0 skipped**, including raw ABI, printable keys,
  repeats, in-flight queue retention, alias releases, pause/blur, failure/unknown
  outcome handling, legacy UI/DOM/input, palette and transport cleanup.
  [Log](../artifacts/phase4/input-runtime/node.log).
- Original C: **51 tics,35 complete Frames**, identical under O0/O2/ASan+UBSan
  and alternate allocation fill. Verbatim G_Responder/G_BuildTiccmd/deferred
  request functions execute with original AM/ST/HU/cheat/gameplay/renderer.
  Only the declared music/platform/display boundaries are adapted; original
  C and inherited goldens are unmodified. The additional punctuation case
  proves that an intervening semicolon resets a partial cheat.
  [Manifest](../artifacts/phase4/input-runtime/native.json),
  [source spans and adaptations](../artifacts/phase4/input-runtime/native-build.json).
- Ordinary EVM: **51 native-matching transactions**,16 no-render tics,35
  complete gameplay Frames plus one accepted static Frame. Each tic compares
  74 scalar fields,15 ST cursors/mutable sequences, all81 HUD bytes,20 mark
  coordinates and every ordered linedef flag. All gameplay Frames match
  64,000 original indexes and768 gamma/palette bytes. Ten mined rejection
  checks preserve the entire contract storage root, inputSeq and logs, including
  an invalid event after earlier cheat recognition. All1,755 resource runtimes
  and production Doom use ordinary CREATE and exact source/resource identities.
  [Receipts](../artifacts/phase4/input-runtime/production.json).
- Chrome155: fresh production instance, actual Start and DOM raw events,51
  accepted tics and **35 exact Canvas Frames**. Native indexes, palettes and
  all256,000 RGBA bytes match; IDDT things uses receipt fallback and WS/backfill
  dedup, and blur cancels the next command. Scheduling is controlled for fixed
  tic boundaries; it does not inject gameplay/commands/state/pixels.
  [Proof](../artifacts/phase4/input-runtime/browser.json),
  [Automap Canvas](../artifacts/phase4/input-runtime/canvas-IDDT-things-stage.png).
- Existing UI profile: **210 native-matching tics,13 UI Frames plus one static
  Frame**, with native pickup/HUD expiry/palettes/fullscreen and complete-storage
  rejections. Reproduced original UI outputs under all four native profiles and
  replayed the existing production runner on final bytecode.
  [Regression](../artifacts/phase4/input-runtime/ui-regression.json).

Earlier attempts remain failed and separate. Initial localhost gates were
blocked by sandbox EPERM and passed after authorized execution. Native harness
bootstrap needed correct original AM implicit-int/cache declarations. New
test names/types were corrected for the pinned compiler/Forge. The initial
adapter expectation overlooked original mismatch consumption after the final
`i` of IDBEHOLDI; the test now asserts that retained cursor and supplies a
separator before IDCLEV. The first Chrome harness had a template string syntax
error, fixed in the harness. No engine assertion, accepted fixture or original
C algorithm was weakened. [Attempt records](../artifacts/phase4/input-runtime/attempts.json).

## Measurements and limits

Final production/browser gate: `2026-10-10T13:29:56.681Z` to
`2026-10-10T13:32:10.494Z`; Chrome portion47.579 seconds. Pinned final compile
reported96.14 seconds; final focused gate18.784 seconds. Production runtime:
675,417 bytes under the existing development code-size policy.

| Operation | Measured gas |
|---|---:|
| Raw/UI startup | 2,930,540,533 |
| Rendered command, including storage and events | 755,220,313–3,709,835,264 |
| No-render command, including storage | 325,858,476–1,512,137,268 |

All measured operations fit the unchanged10B budget. These are finite local
measurements, not real-time/FPS guarantees. Peak EVM memory was not measured.
Evidence checkpoint: `2026-10-10 13:36:02 UTC`; available goal-tool attribution
reported302,294 aggregate tokens and3,996 elapsed seconds. Missing cost,
approval-wait or other usage breakdowns are not estimated.

This goal does not claim whole-world/whole-episode equivalence. Full inherited
Phase0–3/final Phase4 acceptance, multiplayer/chat/menu/demo/mouse/joystick,
other OS/IME key symbols and full gameflow remain outside this checkpoint.
No Episode resource or Intermission module was modified.

## Episode Runtime and integration handoff

Implementation commit: **`1cfd318c89f1b2ea3c446f2f05290277c345565c`**.
The separate Gitmoji proof/tools/report commit completes the mergeable feature
tip; its exact SHA is supplied in the session handoff. This document's links,
formatting, source/evidence certificate and protected-file scope checks pass.
Measured report end/checkpoint: `2026-10-10 13:40:34 UTC`; commit bookkeeping and
final clean-tree verification follow that checkpoint.

IDCLEV recognition, exact requested skill/episode/map and GA_NEWGAME persist;
the current level remains loaded and continues through the declared level-only
profile. Episode Runtime must consume inputRuntime.flow through original
G_Ticker action ordering and synchronous P_SetupLevel, restore mutable difficulty
definitions, refresh map/resource/zone aliases and internal hooks, and restart
ST/HU at console-player spawn while preserving their statics. Synchronize AM
and flow active/view flags without resetting AM/cheat histories. G_DoLoadLevel
must clear inputRuntime.gamekeydown as well as flow.keys/sendpause. Never
substitute E1M1 or tick both old and full-gameflow paths. Actual warp/loading is
not implemented or accepted here.

Owned changes are only `src/evm/{Doom,DoomGame,DoomUI,InputProtocol}.sol`,
`web/{app,input,input-loop}.mjs`, `web/input-runtime.test.mjs`,
`test/integration/InputRuntime.t.sol`, `tools/reference/input-runtime/*`,
`tools/transport/input-runtime-browser-check.mjs`, dedicated evidence and this
report. The designated integrator reconciles this into the shared Phase4
ledger. New deployment/config is required for the explicit raw profile; no
storage upgrade is claimed. Use gameplay/productionUI/rawKeyboard=true and
the existing FramePalette association rules.

Owned Anvil ports18721/18722/18723, temporary Chrome servers and profiles were
stopped by their runners. Reserved18579/18880/8088 and other owners' processes
were not used. Main and other feature worktrees were not modified. Integration
and final Phase4 acceptance remain the designated integrator's responsibility.
No main merge or push is performed; stop after feature commits and clean handoff.
