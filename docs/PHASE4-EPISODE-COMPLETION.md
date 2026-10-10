# Episode One functional integration

Owner: this session, `feat/phase4-episode-completion` in
`/Users/eduard/sandbox/doom-evm-episode-completion` only.
Baseline: `0141708e9772c40a4b43f6fc631e0364fa0eb1a4`, matching remote main.
Measured start: `2026-10-10T14:51:41Z`.

Authorized scope: integrate authenticated nine-map startup, original Gameflow,
raw input/Cheats/Automap, persistent ST/HU and WI; port the active original E1
finale; provide browser New Game/level selection/restart/pause controls. This
feature owns the necessary adapter/interface changes on this branch. The
designated integrator retains exclusive ownership of main. No other worktree
is modified; the existing untracked toolchain symlink is preserved.

Dependencies: pinned original C at
`a77dfb96cb91780ca334d0d4cfd86957558007e0`, accepted Freedoom resource identity,
solc 0.8.37/viaIR/optimizer200/Cancun and the existing execution budget. Borrow
local authenticated resources read-only and copy them into this worktree.

Verification gates: affected-root builds; focused native, Forge and Node
regressions; ordinary Anvil CREATE/transactions on an unoccupied isolated port
18761; real Chrome receipt/Canvas smoke checks on an ephemeral browser port.
Never use playground ports 18880/8088 or mutate EVM storage to simulate an exit.
Exercise short original input/trigger scenarios; separate controlled module
proofs from actual production input/exit evidence.

Stop condition: committed integrated application, focused passing evidence,
updated shared progress ledger and recoverable integrator handoff. No merge,
push, complete input tapes, speedruns, optimization or full historical acceptance.
Record actual timestamps and available goal counters without estimating gaps.

Implementation, integration verification and final acceptance remain distinct.
Full episode recorded playthrough and exhaustive Phase 0–4 acceptance are outside
this user-authorized goal.

## Verified component checkpoint

The opt-in Episode runtime uses the existing G_Ticker, original setup and world
hooks. A call-local serialized callback context supplies persistent UI/WI/finale
state without changing the GameState or input/Frame ABI. Mutable nightmare/fast
definitions are retained across calls. Original P_SpawnPlayer now exposes an
optional ST/HU hook; legacy contexts leave it disabled.

The E1 finale ports F_StartFinale, F_Ticker, F_TextWrite and F_Drawer's active E1
branches. Original text, FLOOR4_8 tiling, glyph placement, TEXTSPEED=3,
TEXTWAIT=250 and retail CREDIT versus HELP2 are retained. Audio, cast/other
episodes and melt wipes remain excluded. No commercial skip/next-episode logic
is installed. Borrowed UI resource lifetimes retain the accepted adaptation.

Focused checkpoint: 125 Forge tests pass, including 27 native finale state/full
pixel comparisons, 1,215 WI observations, original lifecycle/mobj/UI/raw input
and nine-map native startup dependencies. Existing browser/transport 54 tests
and four new transactional control tests pass. The unchanged Gameflow oracle
again verifies 219 cases under O0/O2/sanitizers. Production Anvil attempt2 proves
210 exact E1M1 player observations and 13 native full UI Frames, actual pickup at
tic64, shooting, God/Automap/IDDT and E1M1–E1M3 renders.

Integration remains incomplete: E1M4 load/render reverts with DrawBounds.
Attempts1–3 preserve the sandbox failure and exact failed EVM gates. A separate
error-only diagnostic build is being used to identify the rejecting physical
read; it does not change or weaken production bounds or native fixtures.
No completed-episode or browser acceptance is claimed at this checkpoint.

## Verified integration corrections

The E1M4 rejection was not a Git conflict, compiler failure or native pixel
mismatch. Error-only diagnostics preserve the exact physical samples. The source
is a 512-byte generated texture composite whose digest matches original-C
texture record76 (32x16) in the inherited resource oracle. Sample527 reads the
next header's user-pointer byte7; sample559 reads byte7 of the neighboring live
4096-byte composite payload. The existing backing reader deliberately had no
evidence for either byte class.

The first correction is an explicit **Episode-only address-domain adaptation**:
`canonicalPointerHighBytes` is false for all accepted legacy/strict initializers.
Episode startup selects native LP64 addresses below2^48. Only bytes6/7 of CURRENT
header user/next/prev fields become zero with provenance3. The native proof runs
unchanged original allocator/draw bodies under O0/O2/ASan+UBSan, guards every
tested address below2^48, and reproduces sample527. This conditional proof is not
whole-process address equivalence. No lower pointer bytes, obsolete headers,
mutable bodies or freed payloads become known. Initial-zero provenance remains2;
the production draw marker converts supported provenance to1 as before. This
new Episode domain must be reviewed explicitly by the integrator.

The second correction reads CURRENT source-written composite bytes through the
existing R_GenerateComposite algorithm, rebuilding ephemeral bytes with native
cache effects disabled. All963 original-C composite records remain exact in the
20 inherited RData tests. A dedicated neighbor-tail test proves allocator, tag,
owner and rover state unchanged and freed-composite bytes still unknown. No C
source, accepted golden, allocator ordering or R_Draw bound was altered.

The extended gate passes **175 Forge tests**, including backing/initialization/
draw and both new reader checks. Later InputProtocol's packet lifetime correction
passes **73 affected input, enemy-action and lifecycle tests**, including original
A_BossDeath. These runs overlap; their counts must not be added as unique coverage.
The nine maps load and render in ordinary Anvil within the existing10B budget.

An E1M9 16-event IDCLEV packet exhausted that budget while repeatedly projecting
the same AM world. Original responders borrow the same world throughout an event
batch; no world tic/map load or AM-observed position change occurs between events.
The adapter now borrows one projection per packet. No gameplay, responder order,
compiler, EVM memory limit or execution budget changed.

A later long proof run lost its owned Anvil RPC during E1M9 traversal after normal
and secret-entry transitions passed. Its termination cause was not captured;
host memory/external termination remain hypotheses. Partial Frames and the real
WI Canvas proof are preserved. The runner now records signal exits, checkpoints
evidence during execution and bounds off-chain Anvil history to64 states. Current
state, transactions, receipts and logs remain ordinary EVM/RPC outputs. This is
runner retention, not a game-memory or gas-semantics change.

## Final functional verification and handoff

Implementation commits: `827c95d` (runtime/WI/finale/controls), `54b696d`
(verified backing domain and live composites), `e216de0` (packet borrowing),
`4be57da6b67668b8d16260e009249279fb75a418` (browser, runners and lifecycle tests).
Only this feature branch was committed. No branch was merged or pushed and no
main/other worktree or external runtime was modified.

| Required behavior | Demonstrated evidence |
|---|---|
| E1M1 movement, shooting, pickup, ST/HU | 210 real production input tics,14 player fields each,13 native full UI Frames exact; pickup at64 and HUD expiry retained |
| Nine-map initialization/rendering | All E1M1–E1M9 load/render through original G_DoNewGame/P_SetupLevel in mined transactions;16 inherited startup tests compare nine native worlds and affected profiles |
| Cheats/Automap/IDCLEV | God, original AM/IDDT, deferred IDCLEV12 consumed without WI; native keys clear at load; invalid IDCLEV21 rolls back all storage |
| Pause/restart/death/rebirth | Production pause freezes leveltime and resume advances once; restart reloads; original P_DamageMobj -> dead-use -> next-tic reload tested without injected storage |
| Genuine exits and carryover | Original P_UseLines special11 produces E1M1 WI -> E1M2; special51 produces E1M3 -> E1M9; special11 returns E1M9 -> E1M4; inventory retained |
| Original E1M8 ending | Original movement crosses the authenticated special52 linedef, G_DoCompleted bypasses WI and F_StartFinale enters GS_FINALE; initial native pixels exact;27 native/EVM text/art timing snapshots exact in Forge |
| Browser delivery and controls | WI plus finale/world/AM Frames, matching EVM palette and all256,000 Canvas RGBA bytes; fresh launcher New Game, level selection, Restart and Pause/Resume through real Chrome DOM handlers |
| Existing production modes | Separate ordinary deployments verify static and world-only native pixels, UI native pixels and raw keyboard mode |
| Persistence/rollback | Separate input transactions and WI continuation; seven contract-storage-root rollbacks in the routing run; original storage/module rollback tests retained |

The focused Forge runs cover **239 unique tests**:175 in the broad affected gate,
plus64 enemy-action cases; the later73-case gate repeats nine earlier tests.
All pass with zero failures/skips. **58 Node tests** pass. Native Gameflow219
cases and the new finale27 checkpoints agree under O0/O2/sanitizers. The existing
963 texture records and80 physical-tail cases remain exact. Counts describe
finite functional/component coverage, not complete Phase0–4 acceptance.

Evidence is deliberately split. [Routing run](../artifacts/phase4/episode-completion/functional.json)
passes all required normal/secret subcases and preserves its failed first E1M8
approach. A solid green torch (original MT_MISC42, doomednum45, MF_SOLID) occupies
that approach; the player never crossed the exit. The corrected original-input
approach is verified in the passing [completion run](../artifacts/phase4/episode-completion/completion-final.json).
An intermediate completion attempt preserved a failed legacy-UI comparison:
its golden used run-forward257 but the test sent idle0. The follow-up sends the
original golden's actual command; no assertion or fixture was weakened.

[WI Chrome proof](../artifacts/phase4/episode-completion/functional-browser-intermission.json),
[finale/control Chrome proof](../artifacts/phase4/episode-completion/completion-final-browser-finale-controls.json),
[fresh browser launch](../artifacts/phase4/episode-completion/browser-fresh.json),
[launcher](../artifacts/phase4/episode-completion/launch.json),
[175-case gate](../artifacts/phase4/episode-completion/focused-final.json) and
[73-case follow-up](../artifacts/phase4/episode-completion/input-final.json)
retain actual source/resource/compiler identities, receipt hashes, timing and
full-frame digests. Failed attempts remain failed and separately preserved.
The feature's final certificate binds the roll-up and current source.

The final production runtime is **928,442 bytes**, with patched-driver SHA-256
`219e2732fabf70b9a22a7dcc3aaa538ec8fbb2d7786a68b0a9d148a375b1ed1d`.
Solc0.8.37/viaIR/optimizer200/Cancun,10B gas and1GiB per-execution memory limit
remain unchanged. This is a local Anvil deployment under the existing large-code
policy, not mainnet-size or35Hz acceptance. Peak memory was not measured.

Measured verification endpoint: `2026-10-10T16:06:15Z` after fresh Chrome launch
and owned-runtime cleanup. Start/end clock interval is4,474s. Later publication
time and available goal counters are recorded separately, without estimates.
All started Anvil/Chrome/HTTP children were stopped; reserved18880/8088 and other
owners' environments were untouched. The pre-existing toolchain symlink remains
intact and is correctly ignored. All inherited fixtures, original C, compiler,
execution-budget and Frame/resource schemas remain unchanged.

Integration requirements: fresh deployment, existing gameplay/productionUI/
rawKeyboard configuration plus`episodeMode:true`; the documented launcher sets
these. Additional public control endpoints are driver-only and share the input
sequence/Frame channel. GameContext gains ephemeral callback data/optional player
UI hook; ZoneState gains a default-false address-domain flag. Public legacy
status/input/Frame signatures remain unchanged; internal/support ABI consumers
must compile against the new types. There is no live-deployment migration.

Remaining review/limitations: explicitly review the Episode-only pointer domain
and source-written composite extension before main integration. Low pointers,
retired headers, freed/mutable bodies and arbitrary native-process backing remain
unknown. The exit proofs use declared God/noclip traversal with real original
input and exit triggers; no honest full-episode replay or baron-combat tape is
claimed. Audio, melt wipes, saves/demos/multiplayer/other episodes, gas optimization,
complete historical regression and final release acceptance remain follow-ups.
No known functional blocker remains in the demonstrated scope. Stop for the
designated integrator; do not merge/push main or begin a later goal.

Reproduce:

```sh
python3 tools/reference/episode_completion/finale.py --check
python3 tools/reference/episode_completion/pointer.py
python3 tools/reference/gameflow/reference.py --check
python3 tools/reference/episode_completion/focused.py
python3 tools/reference/episode_completion/focused.py --input-only
node --test web/*.test.mjs tools/transport/protocol.test.mjs tools/transport/ui-palette.test.mjs
node tools/reference/episode_completion/evm.mjs --browser --output-prefix artifacts/local/episode-functional
```

The default functional runner now uses the corrected E1M8 approach and legacy UI
command. `--finale-only --browser` reproduces the targeted completion gate. Use
the README launcher for interactive play; tests require the authenticated local
WAD/chunks and pinned toolchain, as the inherited dependency gates do.
