# Goal 4.11 — Production UI integration

## Scope and ownership

Baseline: `b833ff844aeccc644a9174b63e8229f1dd40d567`. Owner: this Goal 4.11
session, exclusively in `feat/phase4-ui-integration` at
`/Users/eduard/sandbox/doom-evm-ui-integration`. Measured start:
`2026-10-10 11:18:39 UTC`. Main and other worktrees are outside ownership.
No merge or push to main is authorized.

Connect accepted `ST_*`, `HU_*` and `V_*` to persistent production gameplay,
render original 320×168 world plus 32-pixel status bar, preserve the accepted
320×200 world-only path, and deliver complete EVM pixels through `Frame`.
No cheats, automap, maps, gameflow, progression, intermission or memory
architecture work is included. Stop after this goal's verification and handoff.

Dependencies: accepted Status Bar (4.2), HUD (4.3), Video (4.1), existing
`DoomGame` gameplay/renderer state, authenticated pinned Freedoom resource bundle,
original C at `a77dfb96cb91780ca334d0d4cfd86957558007e0`, pinned solc/viaIR/Cancun
and the existing 10 billion gas execution budget.

## Interface boundary

Keep existing startup, commands and `Frame` ABI intact. UI startup is explicit;
UI fullscreen switches between original view sizes 10 and 11. UI tickers follow
the gameplay ticker, including no-render transactions. Retain module histories
in a separate consumer context, reattaching authenticated immutable graphics
for draws instead of persisting duplicate patch bytes. Palette selection and
gamma run in accepted `ST_*`; a frame-bound companion palette event supports
receipt, WebSocket and historical browser presentation. Browser code only
expands indexes to RGBA.

## Verification gates

1. Build affected production/test roots with pinned settings; formatting/diff checks.
2. Focused UI/video tests, actual gameplay producers, storage/mode/rollback tests.
3. Original-C UI/gameplay comparisons with separate goal-specific evidence;
   affected gameplay/renderer dependency tests and selected inherited cases.
4. Ordinary CREATE and real gameplay transactions on a newly owned, unoccupied
   Anvil port (planned 18711; never 18579, 18880 or 8088).
5. Actual production Frame receipts/WebSocket delivery and Chrome Canvas readback,
   including palette effects, HUD timing and fullscreen preservation.

The complete inherited Phase 0–3 suite remains deferred to final Phase 4
acceptance. Existing assertions, fixtures and certificates are preserved.

## Progress

| Checkpoint | Implementation | Integration | Verification | Next |
|---|---|---|---|---|
| Baseline inspection | Not started | Existing modules merged | Clean requested baseline; original pin confirmed | Wire consumer state and frame presentation |
| Runtime implementation `0b65825` | Implemented | Connected in feature worktree | Source-bound production artifact; consumer storage vectors pass | Execute native/EVM/browser boundary |
| Verification `4980269` | Implemented | Production UI and browser presentation connected | 159 Forge tests, 50 Node tests; native/EVM/Chrome exact for declared cases | Handoff to designated integrator |

Goal 4.11 is verified within the scope below. Implementation and runtime
integration are complete in this feature branch. Main integration remains the
designated integrator's task; this goal does not merge or push main. No later
Phase 4 goal has started.

## Delivered behavior and original-source mapping

`Doom.initializeGameUI(false)` starts the original single-player Status Bar and
HUD. World view size 10 gives 320×168 pixels, and the original status drawing
supplies rows 168–199. `initializeGameUI(true)` uses size 11, hides status widgets,
and retains messages/palette effects. Driver-only `setUIFullscreen(bool)` changes
the next view and requests the original refresh without consuming a tic, input
sequence or Frame. Existing `initializeGame`/`initializeGameStrict` and pre-start
static rendering retain the accepted world-only profile.

| Original dispatch/consumer boundary | Production connection |
|---|---|
| `g_game.c:G_Ticker`, level dispatch `P_Ticker → ST_Ticker → HU_Ticker` | Existing `DoomGame.tick`, then `DoomUI.tick`; the same persistent console player and both original RNG streams |
| `ST_Init`, `ST_Start`, `HU_Init`, `HU_Start` | `DoomUI.initialize` loads authenticated original WAD patches and starts the accepted modules |
| `d_main.c:D_Display`, `HU_Erase → ST_Drawer → R_RenderPlayerView → HU_Drawer` | `DoomUI.erase`, `drawStatus`, existing `DoomGame.render`, then `drawHUD` |
| Original view sizes 10/11 | Existing `R_ExecuteSetViewSize`; a restricted overload adds viewport selection while the old overload still passes11 |
| Original widget and face globals/statics | Persistent `UIState.status`, including old health/weapons, priority, attack timer, facecount, pain cache, keyboxes and widget draw history |
| Original pending `Player.message` and HUD 140-tic timeout | Existing gameplay producers and `HU_Ticker`; retains all 81 NUL/stale backing bytes and erase/update history across rendered and no-render transactions |
| `ST_doPaletteStuff`, original gamma lookup / `I_SetPalette` presentation boundary | Accepted EVM module computes768 RGB8 bytes; `FramePalette` binds them to the matching `frameId`/`inputSeq` before the unchanged `Frame` |

No `ST_*`, `HU_*`, `V_*`, gameplay algorithm or shared `GameState` layout was
changed. The new adapter only dispatches modules, attaches borrowed graphics,
selects supported views and retains consumer globals. Source, ABI, compiler,
budget, resource and evidence identities are bound in the
[verification certificate](../artifacts/phase4/ui/verification.json).

Mutable UI history and text remain in contract storage. Authenticated patch/font
bytes are borrowed afresh for drawing and detached before storage. The supported
single-player screen4 background is reconstituted with the original `V_DrawPatch`
from immutable `STBAR`; original differential widget restores then use it. Both
views have `viewwindowx=0`, so original `HU_Erase` changes history without border
copies. Existing framebuffer, wall/plane caches, fuzz state and native-zone
ownership remain under the existing gameplay adapter.

The native UI oracle compiles the original ST/HU/video translation units with
the accepted actual gameplay and renderer. Its declared platform boundary
borrows immutable UI lumps into host buffers and owns screen4 outside the
existing gameplay zone, matching the production consumer boundary. This avoids
changing the accepted renderer backing profile; it is **not** new evidence of
whole-process original-zone allocation equivalence. Native build adaptations,
source hashes, flags and the upstream pin are preserved in
[native-build.json](../artifacts/phase4/ui/native-build.json). No original C or
accepted native golden was edited.

## Verification and evidence

- Affected production/test-root build: pinned solc 0.8.37, optimizer 200, viaIR,
  Cancun; successful compile reported 89.49 seconds. Existing compiler warnings
  remain visible. Formatting and `git diff --check` pass.
- Focused Forge gate: **159 passed, 0 failed, 0 skipped**, including video,
  Status Bar, HUD, actual pickup/locked-door message producers, player/interactions,
  all weapons/psprites, storage, renderer view setup/drawing/planes/sprites/pass
  order. Eleven Status Bar tests also run through the inherited consumer-test
  base. New consumer tests compare **276 original-C snapshots** across separate
  storage calls: 22 inventory, 168 firing/release, 86 damage/direction/pain snapshots.
  This includes every weapon/key, armor, backpack, skull/card priority, original
  stale-key behavior, refresh and original face quirks. See
  [focused log](../artifacts/phase4/ui/focused.log).
- Node gate: **50 passed, 0 failed, 0 skipped**; explicit UI startup/fullscreen,
  existing input/DOM/transport/budget checks, palette receipt association,
  malformed/duplicate palettes, stale async delivery, invalidation and runtime
  cleanup. See [Node log](../artifacts/phase4/ui/node.log).
- New original-C oracle: **210 tics, 13 UI Frames**, O0/O2/ASan+UBSan and alternate
  allocation fill agree exactly. Accepted Status Bar oracle also reproduces
  **1,299 steps/11 sequences**, and HUD oracle **209 cases/575 snapshots**.
  [Native manifest](../artifacts/phase4/ui/native.json) binds all generated outputs.
- Real Anvil: all 1,755 resource contracts and production Doom deployed with
  ordinary CREATE, all runtime/resource bytes rechecked. **210 transactions**
  match 45 exported native scalar fields, all 81 message backing bytes, and mode
  selection after each tic, including 197 no-render tics. All13 UI Frames match
  **64,000 native indexes and768 native gamma/palette bytes**. A pre-start static
  Frame also matches. Six driver/startup/sequence/invalid-input rejections preserve
  the complete account storage root. Mode changes before tics 70/101 preserve
  sequence/Frame counters. See [production evidence](../artifacts/phase4/ui/production.json).
- Actual Chrome155: a fresh production instance repeats all 210 tics; 12 rendered
  tics use real Start/Resume keyboard handling, pickup tic 64 uses receipt fallback,
  and intervening no-render commands use ordinary transactions. All13 Canvas
  images match 256,000 native-palette RGBA bytes, with WebSocket/receipt dedup and
  blur cancellation. The natural pickup produces health 101 and message
  `Picked up a health bonus.` at tic 64/counter 140; tic 203 remains visible with
  counter 1, and tic 204 expires. Bonus palette 10 and both viewport switches match.
  See [browser proof](../artifacts/phase4/ui/browser.json),
  [pickup Canvas](../artifacts/phase4/ui/canvas-tic64.png),
  [fullscreen Canvas](../artifacts/phase4/ui/canvas-tic70.png), and
  [expiry Canvas](../artifacts/phase4/ui/canvas-tic204.png).
- Preserved high-risk inherited production gate: **129 tics, six gameplay Frames,
  one static Frame, 13 full-storage rollback checks** pass using the unchanged
  accepted runner on an independent node. See
  [legacy evidence](../artifacts/phase4/ui/legacy.json).

Initial combined attempts reached all 210 native-matching production tics but
failed the browser harness (first a missing runner, then selecting the companion
palette as the Frame). They remain failed local checkpoints under
`artifacts/local/ui/production-before-browser.json` and `production-final.json`.
The corrected combined `production-complete` run passes. Local networking
initially failed under the sandbox; authorized reruns passed. No acceptance
assertion or golden was weakened to resolve these failures.

Reproducible commands are in the [verification README](../tools/reference/ui/README.md).
The preserved legacy gate used:

```sh
python3 tools/reference/gameplay/production.py --output artifacts/local/ui/legacy-native
node tools/reference/gameplay/production.mjs --port 18712 --native artifacts/local/ui/legacy-native --output-prefix artifacts/local/ui/legacy --no-web-palette-write
python3 tools/reference/statusbar/reference.py --check
python3 tools/reference/hud/reference.py --check
```

The certificate checker validates identities/recorded results; it does not
replace executing these gates. Full inherited Phase 0–3/final Phase 4 acceptance
remains deferred, as authorized.

## Measurements and limits

The successful combined runtime gate ran from
`2026-10-10T11:45:40.675Z` to `2026-10-10T11:47:57.598Z`; its Chrome gate took
46.414 seconds. The focused Forge gate, including compilation, took 251.615
seconds. Source-bound production runtime is 592,441 bytes under the existing
local code-size policy.

| Operation | Measured gas |
|---|---:|
| UI startup | 2,928,643,720 |
| Rendered UI tic, including storage and events | 1,025,760,389–1,378,285,802 |
| No-render UI tic, including storage | 325,568,136–328,534,796 |

Rendered UI transactions took 849.246–1,168.268 ms on this local node. These are
measured transaction latency samples, not a real-time 35 Hz claim. The unchanged
10,000,000,000 gas budget accommodates every measured operation. Peak EVM memory
was not measured here; no new MSIZE or memory-architecture claim is made.

Report checkpoint: `2026-10-10 11:55:51 UTC`. Available goal-tool attribution at
that checkpoint reports 248,576 tokens used and 2,232 elapsed seconds. These are
the tool's aggregate counters; no missing approval-wait, dollar-cost or other
usage attribution is estimated. Final handoff timing follows the documentation
commit in the session completion record.

The ordinary route exercises natural health-bonus pickup, fire/ammo, viewport
changes and message timing. Armor/keys/every weapon/damage/death-face domains
have controlled consumer or inherited module proofs; this is not an honest
whole-episode or every-pickup playthrough. Whole-world canonical records are not
compared by the production ABI gate. This goal uses default original gamma 0,
`showMessages=true`, and single-player message producers. Chat, raw HUD responder
input, cheats, automap and level/gameflow lifecycle remain later integration
work; their implementations were not added here.

## Handoff and integration requirements

- Implementation commit:
  **`0b65825bd589b9f824ef08172cb780c5b928ab9b`**.
- Evidence/tools commit: **`49802693238a51fb24de4e5f206980530809a28b`**;
  the report's final documentation commit
  completes the handoff. All commits use Gitmoji and preserve baseline history.
- Owned changed files: `src/evm/{Doom,DoomGame,DoomUI}.sol`,
  `web/{app,input-loop,ui-palette}.mjs`, `web/input-loop.test.mjs`,
  `test/integration/ProductionUI.t.sol`, `tools/transport/ui-{palette.test,browser-check}.mjs`,
  `tools/reference/ui/*`, `artifacts/phase4/ui/*`, and this report.
- The designated integrator should review shared adapter interfaces and reconcile
  this handoff into `docs/PHASE4-PLAN.md`. Future lifecycle consumers must retain
  original Status Bar statics when restarting; this goal adds no restart path.
- For UI clients set `productionUI:true`, `gameplay:true`, and optionally
  `uiFullscreen:true` in local browser config. Start uses `initializeGameUI(bool)`;
  legacy config/startup remains world-only. UI Frame consumers must select Frame
  by topic and associate the companion `FramePalette` by address, transaction,
  block, frameId and inputSeq. Historical palette receipts are independently
  usable; slow older lookups cannot overwrite newer Canvas frames.
- No compiler, budget, WAD schema, `Frame` ABI or gameplay-state layout change is
  required. New deployments are required for the added UI consumer storage/API;
  no storage upgrade of an existing deployment is claimed.
- Verification owned Anvil ports 18711/18712 plus temporary Chrome/server/profile
  instances, all stopped by their owning runners. Ports 18579/18880/8088 and other
  runtimes were not used. No other worktree was modified. No branch was merged
  or pushed to main.

No blocker remains for the declared Goal 4.11 scope. Later feature lifecycle
integration and complete final Phase 4 acceptance remain separate dependencies.
