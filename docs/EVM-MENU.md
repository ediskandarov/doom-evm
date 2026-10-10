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

Unsupported Save/Load/Options/Help/Quit have no player-facing rows or fake
actions. No audio, demo carousel, wipe, multiplayer or other episode support is
added by this goal.
