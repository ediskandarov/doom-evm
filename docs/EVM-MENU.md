# Original DOOM menu in EVM

Goal start: 2026-10-10 17:43:17 UTC. Baseline: `1e7033c`, clean
`feat/evm-menu`, owned worktree `/Users/eduard/sandbox/doom-evm-menu`.
Only this feature worktree is writable for this goal. No main merge or push.

Scope: port relevant `m_menu.c` drawing, keyboard responder and skull state;
authenticate every graphic through the existing WAD view; wire New Game and
explicit E1M1–E1M9 direct selection to Episode Runtime; replace the HTML launcher
in the default menu profile. Unsupported Save/Load/Options/Help/Quit, audio,
mouse/joystick, network/demo and other episodes stay out of scope. Legacy APIs
and explicit browser test profiles remain available.

Dependencies: pinned original C at `a77dfb96cb91780ca334d0d4cfd86957558007e0`,
existing V_Video, HU font, raw input, EpisodeStartup/EpisodeRuntime, immutable
WAD identity and unchanged Frame/FramePalette protocol. Authorized production
integration edits are confined to this feature branch; the integrator owns
eventual reconciliation of shared adapters and browser changes into main.
No shared ABI, compiler, hardfork, budget or resource schema change is planned.

Memory policy: retain the existing borrowed immutable UI graphics boundary.
Menu resources do not create virtual gameplay-zone allocations. Native menu
proofs must identify this adapted profile, as required by the RESTRICT audit;
they establish bounded drawing/responder equivalence, not whole-process native
allocation equivalence. Gameplay startup retains the existing Episode policy.
Unknown physical backing stays unknown; no allocator/provenance relaxation.

Verification gates: native O0/O2/sanitized menu checkpoints, focused Forge
renderer/responder/storage tests, real ordinary Anvil startup/input/rollback
transactions, all nine direct selections, fresh inventory/no Intermission,
Escape/resume and paused redraws, legacy production smoke, Node browser tests,
and actual Chrome Canvas readback. Dedicated planned Anvil port 18781; refuse
occupied ports and never use 18880/8088 or another owner's runtime.

Checkpoint commits: A renderer, B input/state, C New Game/Select Level,
D browser integration/proofs. Preserve failed attempts separately. Stop when
the requested menu is implemented, focused gates pass, evidence and source
mapping are recorded, and the feature branch is clean with a recoverable handoff.
Full historical/final Phase 4 acceptance belongs to the integrator.

Checkpoint B: five focused Forge tests pass, including 28 original responder
events compared field-by-field (13 fields) after external storage round-trips.
Arrow wrapping, left/right consumption, Enter, Escape, Backspace, remembered
selections, duplicate skill hotkeys, Nightmare cancellation/acceptance and skull
timing match the native trace. Extended E1M9 navigation and menu packet isolation
pass. Compilation 151.96s; test suite 467ms. Checkpoint A commit `2406f71`.

Production input isolation is an explicit packet-boundary adaptation: the
complete packet is validated first; a packet containing menu-owned input never
reaches G_Responder/ST cheats. Keyups and unknown active-menu keys are isolated
even where original M_Responder returns false. Held gameplay keys are cleared
on menu ownership transitions to avoid stuck movement after Resume. This does
not change the standalone original responder's return values.

## Progress

Checkpoint A implementation: `src/doom/m_menu.sol` ports original menu drawing,
text widths/writing, skull ticker and startup globals. Ten new original-C
checkpoints (nine full screens and one responder trace) reproduce under O0/O2
and ASan/UBSan. Both focused Forge tests pass: all nine native screens match
64,000 indexes each; all nine extended screen cursor positions are distinct and
in bounds. Compile took 152.52s, tests 468ms. A checkpoint: 2026-10-10
17:53 UTC. Production integration and acceptance remain pending. Available goal-tool usage attribution
will be recorded without estimating missing data.

## Original and modified presentation

Original drawing comparison profile (`extended=false`) retains the complete
retail MainDef and EpiDef graphics, NewDef skill graphics, both skulls and the
Nightmare confirmation. Source function spans/hashes and native compiler,
executable and harness identities are in `test/fixtures/evm_menu/manifest.json`.

Player profile (`extended=true`) keeps original New Game at MainDef (97,64),
adds SELECT LEVEL at (97,80) using original HU font, and omits unsupported
launcher rows. New Game still passes through Episode One then original skill
selection. The Episode screen shows only the supported first episode.
SELECT LEVEL uses a font heading at (80,24), nine E1M1–E1M9 labels at
(80,48+i*16), and the original skull at (48,43+item*16). This is a deliberate
non-original screen and has no native pixel-equivalence claim. Skill choice
uses original NewDef patches/positions and retains Nightmare confirmation.
TITLEPIC is the initial D_PageDrawer background; during gameplay the original
menu overlays the last EVM gameplay framebuffer.

## Production checkpoint C

The feature `Doom.initializeMenu(bool)` enables raw events/Episode Mode and the
original base palette without loading or ticking a game. The first ordinary
raw-event Frame draws TITLEPIC plus the menu. Existing Frame/FramePalette ABIs
are unchanged. `menuStatus()` exposes nine authoritative inspection fields.
`renderFrame()` supports menu redraws. Legacy initializers remain separate and
cannot replace an initialized menu profile.

Menu selection invokes the existing authenticated EpisodeStartup for the first
game, or `G_DeferedInitNew -> EpisodeRuntime.tick -> G_DoNewGame/G_InitNew` for
later games. No exit/completion or WI_Start is used. Selection consumes one
original gameplay tic and its normal Frame; input after selection is discarded.
All five original skills remain selectable; Nightmare retains its confirmation.
SELECT LEVEL remembers map choice, then uses the same original skill screen.

Menu-owned packets advance only the skull ticker, input sequence and Frame ID.
They borrow the last EVM gameplay framebuffer for overlay and do not run
G_Ticker, thinkers, gameplay/UI RNG or ST/HU/AM/cheat tickers. Escape closes the
menu with a cached gameplay Frame; the next ordinary gameplay packet resumes
ticking. Explicit gameplay Pause is independent and survives opening/closing
the menu. This render-only cadence is the EVM adapter's deliberate boundary;
original P_Ticker's menu pause condition remains unchanged.

Production build passed (134.82s). The real-EVM checkpoint ran from
2026-10-10T18:01:35.576Z to 2026-10-10T18:03:00.594Z on owned Anvil18781:
59 input transactions,48 recorded Frames, all nine medium-skill map selections,
New Game, Nightmare cancel/accept, easy skill, inventory reset, no Intermission,
held-input clearing, paused redraws, Escape/Resume and seven complete-storage
rollback receipts. Original skill screen and legacy first raw-input frame match
native pixels. A legacy static render before gameplay also succeeds. Native UI
oracle reproduction:210 tics/13 Frames, O0/O2/sanitizers/allocation-fill profiles;
only its first Frame is claimed as the new production regression comparison.

Maximum measured input gas:7,813,562,258 under the unchanged10B budget. Runtime
size:969,768 bytes under the existing development code-size policy. The ordinary
CREATE JSON payload exceeds Anvil's default2MiB HTTP limit; this owned runner
uses `--no-request-size-limit`. This changes transport only. The socket-denied
and HTTP-limit attempts remain separate failures; no resource, native backing,
gas/memory/hardfork/compiler policy was relaxed. Peak EVM memory is unmeasured.
Browser acceptance and integration handoff remain pending.

## Checkpoint D implementation and source mapping

The normal production gameplay browser selects the EVM menu by default, including
configurations without a menu flag. `menuMode=false` explicitly selects inherited
diagnostic/test launcher behavior. Those existing test fixtures/runners now set
that flag; their assertions are unchanged. Static and synthetic profiles remain
available. No HTML Start Game, map chooser, restart or pause controls are created
in the normal menu profile. Initially hidden legacy markup prevents a launcher
flash during config fetch. The browser forwards raw keyboard packets, validates
Frame/Palette receipts and expands indexes to Canvas; it computes no menu actions
or menu graphics. Gas budget, transaction and Frame counters appear only in the
collapsed Debug panel. Focus/visibility handling retains the existing input loop.

`fixtureClient` retains programmatic `startGame`, `nextFrame`, `stopGame`,
`episodeControl`, keyboard, transactions and loop inspection APIs. Menu-mode
`startGame` initializes/resumes the menu transport and does not select a game.
The EVM decides map, skill and startup from keyboard input. Reload reopens the
authoritative menu over persisted gameplay.

| Original source/function | Feature implementation/adaptation |
|---|---|
| `m_menu.c` menu definitions, M_Init/M_Ticker | `src/doom/m_menu.sol` MenuState, original lastOn/hurtme/skull counters; supported retail subset |
| M_DrawMainMenu/M_DrawNewGame/M_DrawEpisode/M_Drawer | Same-named functions, original WAD patches/coordinates/16-pixel spacing/skull offset; modified production Main/Episode subsets and SelectDef documented above |
| M_WriteText/M_StringWidth/M_StringHeight | Original uppercasing, HU font widths, newline12 and centered four-line Nightmare prompt; the retained fixed prompt's height is four original font heights |
| M_Responder/M_StartControlPanel/M_ClearMenus/M_SetupNextMenu | Same-named keyboard branches, exact supported hotkeys/wrap/Enter/Escape/Backspace and lastOn; mouse, joystick, sliders and unsupported function keys excluded |
| M_NewGame/M_Episode/M_ChooseSkill/M_VerifyNightmare | Original Episode One/skill flow and deferred-new-game request; SELECT LEVEL reuses skill flow with explicit map1..9 |
| `d_main.c` D_ProcessEvents/D_PageDrawer/D_Display | `DoomMenu.respond` menu-first packet ownership; TITLEPIC before initial menu, saved gameplay framebuffer before overlay, original menu last |
| `g_game.c` G_DeferedInitNew/G_DoNewGame/G_InitNew | Unchanged G_Game/EpisodeStartup/EpisodeRuntime modules; no legitimate exit or Intermission used for selection |
| `v_video.c` patch drawing | Unchanged V_Video; authenticated ResourceView supplies all patch/font bytes |

The final startup adapter retains the authenticated EpisodeStartup context and
rebinds the same map/move/path/translation/native-zone aliases as DoomGame.load
before its first tick/render. The earlier store-then-reload path duplicated the
resource/context graph and failed fresh E1M7 under1GiB. This fix reduces ordinary
EVM memory allocations; it does not change the native-zone allocation chronology,
initial-byte policy, pointer-high predicate, source algorithms or resource inputs.
All nine fresh starts subsequently pass. The first E1M1 gameplay Frame remains
byte-identical to checkpoint C. Final production compilation took124.98s.

Source spans/hashes for the mechanically extracted original menu functions are
in the [native manifest](../test/fixtures/evm_menu/manifest.json). Native graphics
borrow exact immutable WAD bytes and V_Init buffers outside a gameplay zone,
matching the established UI adapter. Source-original full Main/Episode/skill
drawings and responder vectors are separate from modified production screens.
The [RESTRICT audit](PHASE4-NATIVE-MEMORY-AUDIT.md) remains applicable: successful
finite frames do not establish a universally portable native heap/pointer model.

## Reproduction and integration handoff

Prerequisites: pinned local toolchain and original source; Freedoom IWAD and full
authenticated resource bundle under ignored `artifacts/local`. Menu fixture
patch bytes carry the preserved [Freedoom license](../test/fixtures/evm_menu/COPYING.txt).
Refuse occupied ports. The menu runner starts/stops only its own Anvil18781;
Chrome gates use a temporary profile and ephemeral server port.

```sh
python3 tools/reference/phase2_data/prepare_chunks.py
python3 tools/reference/menu/reference.py --check
.toolchain/bin/forge build src/evm/Doom.sol src/evm/ResourceStore.sol --offline --no-lint
.toolchain/bin/forge test --match-path test/unit/m_menu.t.sol --skip Doom.sol --skip GameplayProbe --skip RendererProbe --skip WadResourcesProbe --skip ProductionUI.t.sol --skip DoomRenderer.t.sol --offline -vv
python3 tools/reference/menu/focused.py
python3 tools/reference/ui/reference.py --output artifacts/local/menu-legacy-native
node --test web/*.test.mjs tools/transport/protocol.test.mjs tools/transport/palette.test.mjs tools/transport/ui-palette.test.mjs tools/transport/lifecycle.test.mjs
node tools/reference/menu/evm.mjs --port 18781 --browser --output-prefix artifacts/local/menu-reproduction
python3 tools/reference/menu/checkpoint.py --check
```

For an interactive local launch with a fresh production deployment:

```sh
node tools/reference/menu/evm.mjs --play --port 18781 --http-port 18782 --output-prefix artifacts/local/menu-play
```

Open the printed URL. The menu loads automatically. Arrows navigate, Enter
selects, Escape closes/reopens, Backspace returns to the previous screen, and
original letter hotkeys remain supported. Select Level supports digits1..9.
During gameplay all accepted original/raw and additional browser bindings remain
available. Ctrl-C stops only that launcher's owned Anvil/server. No reserved
18880/8088 or speedrun-owned process/files are used.

Integration interfaces: additive initializeMenu(bool), menuMode(), menuStatus();
existing Frame/FramePalette/raw-event and gameplay APIs unchanged. Deploy fresh
bytecode; no storage upgrade is claimed. The main integrator must reconcile the
feature's Doom/browser adapter edits and shared Phase4 ledger. No main merge,
main push, published-history rewrite or automatic later goal is part of this task.
Checkpoint commits: A `2406f71`, B `fd90725`, C `7ef2412`; the final D tip is given
in the clean-tree handoff. Full inherited Phase0–3/final Phase4 acceptance remains
the integrator's separate release gate.

## Final feature verification

Accepted EVM run: **2026-10-10T18:19:29.428Z–18:21:28.476Z**. All1,755
ordinary resource CREATE runtimes match exact authenticated bytes; production
Doom runtime/source identities are checked. **79 input transactions,60 recorded
Frames, nine retained-runtime selections and nine fresh first-game selections**
pass. All five skills, fresh inventory, no Intermission, menu pause/isolation,
Escape/Resume and independent explicit Pause pass. Eight mined rejection receipts
prove complete storage-root rollback and no logs, including an underfunded fresh
E1M7 startup followed by success with the same sequence. The failed historical
MemoryOOG run is preserved separately and remains failed.

Final runtime: **848,394 bytes**, SHA256
`c8066d3b4674294af01f515a1df285c0a85849cf1f9c3675dc2e87f4ecd0e401`.
Maximum measured input gas: **7,813,461,627**. Fresh E1M7 startup/tick/Frame uses
7,123,880,330 gas and succeeds under the unchanged1GiB interpreter limit.
These are local finite measurements; peak MSIZE/memory and FPS are not measured.

Chrome155 accepted run: **18:21:16.476Z–18:21:28.406Z**,16 Canvas checkpoints,
each matching every indexed byte, EVM palette and all256,000 expanded RGBA bytes.
Actual DOM keydown/keyup and held-key input navigate Select Level, launch E1M9,
reopen/close the menu, resume gameplay, start original New Game E1M1, verify
receipt fallback/backfill dedup and reload persisted state. No visible HTML
launcher is present; Debug remains collapsed. Canvas screenshots were inspected.
The earlier reload harness race is separate failed evidence; the final checker
waits for the new document and its initialized menu client.

Five menu Forge tests (nine original pixel screens,28 responder events/13 fields,
storage round-trips and extension/isolation) and27 focused inherited input,
video and Episode lifecycle tests pass. The66 browser/transport Node tests pass,
including existing launcher assertions under explicit legacy profiles. No
assertion, existing engine fixture/golden, original C, allocator, shared
Frame ABI, toolchain or execution budget was weakened or changed.

Evidence: [accepted EVM receipts](../artifacts/phase4/menu/accepted.json),
[Canvas proof](../artifacts/phase4/menu/accepted-browser.json),
[focused Forge result](../artifacts/phase4/menu/inherited-focused.json),
[Node result](../artifacts/phase4/menu/node.json),
[preserved attempts](../artifacts/phase4/menu/attempts.json), and
[source/evidence certificate](../artifacts/phase4/menu/verification.json).
The certificate checker validates hashes and protected source identity; it does
not rerun or replace the execution gates.

Measured report checkpoint/end: **2026-10-10 18:21:43 UTC**. Available goal-tool
attribution at this checkpoint:549,002 aggregate tokens and2,306 elapsed seconds.
Missing monetary/approval/subtask breakdowns are not estimated. Final Git commit,
certificate checking and clean-tree bookkeeping follow this checkpoint.

No implementation blocker remains for the declared menu domain. Integration into
main and frozen final Phase4 acceptance remain pending with the main integrator.
All owned verification runtimes are stopped; reserved/speedrun environments and
other worktrees were preserved. The feature stops at its clean committed handoff.

Unsupported Save/Load/Options/Help/Quit have no player-facing rows or fake
actions. No audio, demo carousel, wipe, multiplayer or other episode support is
added by this goal.
