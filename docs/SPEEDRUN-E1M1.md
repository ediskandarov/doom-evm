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

## Native verification checkpoint

The original file is a version-109 short-tic recording: 13-byte header, 370 four-byte commands, marker `0x80` at offset 1493, then a PWAD footer with `FEATURES`, `PORTNAME` and `CMDLINE`. Each row stores signed forward/side bytes, an unsigned angle byte shifted left eight bits and narrowed to signed int16, and a buttons byte. Timing is one row per 35 Hz tic. Every decoded row agrees with the mechanically extracted original `G_ReadDemoTiccmd`; no video reconstruction or keyboard approximation is used.

The footer confirms DSDA-Doom 0.29.0 and `-complevel 3`. Its checksum `68712648751c1048b2cd9aa95a725bfb` verifies as MD5 of the demo through its marker plus its 16 feature bytes. Tagged [DSDA demo source](https://github.com/kraflab/dsda-doom/blob/v0.29.0/prboom2/src/dsda/demo.c) and [footer source](https://github.com/kraflab/dsda-doom/blob/v0.29.0/prboom2/src/dsda/exdemo.c) establish that this is a demo/features checksum, not an IWAD hash. The features are Menu and Extended HUD. There are no long-tic or extended gameplay commands in this file.

The stock pinned Linux DOOM `G_DoPlayDemo` rejects VERSION109 because its `VERSION` is 110. The command reader uses the compatible four-byte layout, and original gameplay replays successfully through the existing harness without changing that version check. DSDA's footer selects Ultimate Doom compatibility; the original native retail profile is explicitly used. Neither the version byte alone nor the `0.13.0-2` label establishes engine or WAD equivalence. Recording-time IWAD identity remains unknown; successful replay on our independently hash-verified pinned IWAD is demonstrated. No DSDA state trace is available for an all-state DSDA comparison.

Original `G_InitNew` and `G_DoLoadLevel` select skill0 (`-skill 1`), retail E1M1, player0 only, original cleared RNG, monsters enabled, no respawn/fast/deathmatch, real player start and inventory. Original `P_Ticker` executes the exact commands. Generated observation-only host code stops after `ga_completed`; a generated `p_switch.c` observation records the real case11 line index. Original C and accepted native fixtures are untouched.

**Native result:** genuine normal exit at line407, tic279, `leveltime=279`, `gameaction=6`, `secretexit=0`. All 280 complete DSG1 states (startup plus 279 tics), player summaries and diagnostics agree across O0, O2, ASan/UBSan, and ASan/UBSan with fresh allocation payloads filled `0xa5`. The remaining 91 commands are preserved in the complete tape and are beyond the level exit; progression/intermission is outside this experiment. Initial native O2 process time: 0.615221 seconds, including startup and observation IO, excluding compilation.

Full state stream: 28,562,808 bytes; SHA-256 `82ea9cd129ba41274de70fe4b2e829d9e5c47ac3f18c5b6f9456183a7d339010`. Evidence and input tapes are in [`artifacts/speedrun-e1m1`](../artifacts/speedrun-e1m1/).
