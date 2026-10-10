# Real Freedoom E1M1 demo replay experiment

Independent experiment; not Phase 4 Episode One integration.

## Scope and ownership

- Owner: this goal's primary agent; existing worktree `/Users/eduard/sandbox/doom-evm-speedrun`, branch `feat/phase4-speedrun-e1m1`.
- Baseline: `0141708e9772c40a4b43f6fc631e0364fa0eb1a4`. Existing untracked `.toolchain` symlink is preserved and used read-only.
- Measured start: 2026-10-10 14:56:09 UTC. Usage attribution will be recorded only when available.
- Own only new experiment files under `tools/reference/speedrun`, `src/support/Speedrun*`, `artifacts/speedrun-e1m1`, and this report. No changes to main, shared ledgers, production gameplay, accepted fixtures, or original C.
- Dependencies: specified demo download, exact pinned IWAD, pinned original C/Clang profile, existing native gameplay observer and EVM gameplay/resource adapters.
- Runtime: check and refuse occupied ports; prefer Anvil 18620; never use 8545, 18880 or browser 8088. Local downloads/builds/runtime evidence live under `artifacts/local/speedrun-e1m1`.
- Gates: inspect format and provenance; decode exact original commands; prove real native exit with recorded initial settings; only then attempt actual EVM execution and compare state; keep correctness separate from timing/gas.
- Stop condition: demonstrated E1M1 EVM exit or a reproducible, precisely identified blocker after native investigation. No episode progression, renderer optimization, AI player, or full inherited acceptance.

## Source acquisition checkpoint

The requested [speedrun record](https://www.speedrun.com/freedoom_phase_1/runs/zg677ovm) links [this original demo](https://drive.google.com/file/d/1ofW23JwBMdzYd_k3NCz0GdIV5FrlvolK/view?usp=drive_link). The page reports 7.970 seconds, DSDA-Doom v0.29.0, Freedoom 0.13.0-2, skill 1 and complevel 3. No substitute demo is authorized or used.

Downloaded original: 1,700 bytes; SHA-256 `111aec6cabcd2718f0e4fab662980bb68c1831bfc1db12a438fe7e8af2fb5782`.

The pinned repository IWAD is separately identified by `tools/wad/freedoom.lock.json`: SHA-256 `7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d`. Recording-time IWAD identity is not established by a matching release label.

The existing native gameplay harness consumes `forwardmove sidemove angleturn buttons render` rows, one original `P_Ticker` per row, and records canonical DSG1 world states. Its default is medium skill. Production `Doom.step` converts keyboard masks and also starts medium skill; it does not accept arbitrary demo commands. The existing test-only `GameplayProbe` accepts exact commands but also defaults to medium skill. Any experiment adapter must select skill before spawning and reuse original gameplay.

Implementation, native verification and EVM execution are pending at this checkpoint.
