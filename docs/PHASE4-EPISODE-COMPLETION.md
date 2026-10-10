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
210 exact E1M1 player observations and 14 native full UI Frames, actual pickup at
tic64, shooting, God/Automap/IDDT and E1M1–E1M3 renders.

Integration remains incomplete: E1M4 load/render reverts with DrawBounds.
Attempts1–3 preserve the sandbox failure and exact failed EVM gates. A separate
error-only diagnostic build is being used to identify the rejecting physical
read; it does not change or weaken production bounds or native fixtures.
No completed-episode or browser acceptance is claimed at this checkpoint.
