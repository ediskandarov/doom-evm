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

## EVM result and metrics

**Passed actual EVM execution.** [`SpeedrunProbe`](../src/support/SpeedrunProbe.sol) is a new test-only host that calls existing authenticated `EpisodeStartup.initialize` for E1M1 skill0, then existing `DoomGame.tick` with the verbatim original four-byte commands. Original Solidity libraries own all gameplay and exit logic. Native states are used only for off-chain comparison. No production source, ABI, budgets, fixture or renderer changed.

Fresh Anvil 1.8.5, Cancun, isolated port18620, ordinary CREATE: all 1,755 STOP-prefixed resource runtimes were read back exactly. The probe runtime was verified against compiled bytes with its immutable driver bound to the actual deployment sender. Solc0.8.37 `f401782d`, viaIR, optimizer200 and the existing 10B transaction budget were retained; focused compilation took 41.62 seconds. The runtime allows the existing local large-code and 1GiB-memory profile; this is not a public-chain deployment claim.

All 280 receipt observations match complete native DSG1 states byte for byte. A final `snapshot()` read of persisted storage also matches. EVM `gameaction=6`, normal exit, `leveltime=279`, no cheats. **No native/EVM divergence was observed.** Final state SHA-256: `db14ca0dff152ef1a209131cba0235a9c94b55ae1aae6ed3f09211af597d3499`. The actual EVM and native full state streams have the same hash quoted above. The comparison covers the observer's full logical world: player/inventory/psprites, RNG, thinker order, actors/AI, sectors, lines, sides, block links, special thinkers and resource translations; it does not compare every raw zone/pointer byte or produce Frame proofs.

| Measurement | Actual result |
|---|---:|
| Reported speedrun time | 7.970 seconds |
| Replayed in-game time | 279/35 = 7.971428571 seconds |
| Native initial O2 whole process | 0.615221 seconds |
| Native final recheck O2 whole process | 0.554704 seconds |
| EVM gameplay replay wall time | 11.948577 seconds |
| EVM gameplay transaction RPC/receipt time sum | 11.926680 seconds |
| Executed gameplay tics / transactions | 279 / 56 (five tics per batch; final batch four) |
| Gameplay transaction gas | 21,203,677,822 |
| Average gameplay gas per tic | 75,998,845.240 |
| Authenticated EVM startup | 2,110,363,636 gas; 0.556434 seconds |
| Resources plus probe deployment | 6,493,412,272 gas; 48.921564 seconds; 1,756 transactions |
| Entire successful deployment/startup/replay | 29,807,453,730 gas; 1,813 transactions |

Performance is separate from correctness. Native times include startup, full per-tic/zone observations and file IO; EVM replay excludes deployment/startup and includes RPC, mining, full world events, batching, storage and comparisons. These differently instrumented timings are not an engine speedup ratio or production transaction cost. No tic is rendered. Detailed per-transaction hashes/gas/times and compiler/source/ABI/resource identities are in [`evm-result.json`](../artifacts/speedrun-e1m1/evm-result.json); full mined receipts are preserved separately.

Selected checkpoints below match in both engines. Coordinates are original signed 16.16 words; angles are unsigned 32-bit values.

| Tic | x | y | angle | Health | P_Random index | Thinkers |
|---:|---:|---:|---:|---:|---:|---:|
| 0 | -27262976 | 16777216 | 0 | 100 | 53 | 219 |
| 35 | 6749498 | 17125327 | 570425344 | 100 | 58 | 220 |
| 70 | 50882980 | 23324746 | 1442840576 | 102 | 76 | 218 |
| 140 | 38823234 | 65752270 | 2164260864 | 102 | 129 | 216 |
| 210 | 11195467 | 98582884 | 2952790016 | 98 | 236 | 216 |
| 279 | -24087204 | 85082286 | 2231369728 | 98 | 143 | 215 |

Final player: z=-8388608, health98, armor2/type1, shotgun selected, clip89/shell16/cell0/missile0, kills0/items5/secrets0, real exit switch used. Expanded final player state and initial settings are in [`native-result.json`](../artifacts/speedrun-e1m1/native-result.json).

## Reproduction and evidence

Run from this feature worktree with the pinned toolchain. The original demo is committed with its source/hash; the full IWAD remains an ignored local download. To acquire resources anew:

```sh
mkdir -p artifacts/local/speedrun-e1m1
curl --connect-timeout 10 --max-time 30 -fsSL 'https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip' -o artifacts/local/speedrun-e1m1/freedoom-0.13.0.zip
shasum -a 256 artifacts/local/speedrun-e1m1/freedoom-0.13.0.zip
unzip -p artifacts/local/speedrun-e1m1/freedoom-0.13.0.zip freedoom-0.13.0/freedoom1.wad > artifacts/local/speedrun-e1m1/freedoom1.wad
cp artifacts/speedrun-e1m1/e1m1-easy.lmp artifacts/local/speedrun-e1m1/source-download
python3 tools/reference/speedrun/replay.py
node tools/wad/pack.ts artifacts/local/speedrun-e1m1/freedoom1.wad artifacts/local/speedrun-e1m1/wad
.toolchain/bin/forge build src/support/SpeedrunProbe.sol src/evm/ResourceStore.sol
node tools/reference/speedrun/evm.mjs --port 18620 --batch 5
python3 tools/reference/speedrun/verify_evidence.py
```

Expected archive SHA-256: `3f9b264f3e3ce503b4fb7f6bdcb1f419d93c7b546f4df3e874dd878db9688f59`. The native runner refuses a non-pinned WAD or different demo. Optional original reacquisition uses the exact `downloadUrl` in [`source.json`](../artifacts/speedrun-e1m1/source.json), then checks the original SHA-256. The EVM runner refuses an occupied port; choose another free isolated port using `--port` if needed. It starts/stops only its own Anvil and records its PID. The successful run started 2026-10-10 15:23:23.263 UTC and ended 15:24:24.786 UTC; port18620 was unoccupied after cleanup.

`verify_evidence.py` independently decodes the original tape and DSDA checksum, reconstructs both exact state streams, validates all 280 mined receipt observations against native bytes, verifies receipt hashes/gas/counts and checks historical executed EVM sources at preserved commit `bb16afd879d5fe818ada5a21834027c07a4b3803`. That commit must remain an ancestor of the current checkout, and every recorded source hash must match its Git object. Committed delta streams use the existing `verify.py.delta_decode` format; raw original state streams and execution outputs remain under `artifacts/local/speedrun-e1m1`. This offline check examines preserved evidence; the preceding `evm.mjs` command performs fresh actual execution and binds the current compiled sources. It does not accept current engine changes merely because historical receipts pass.

Development attempts remain documented in [`development-attempts.json`](../artifacts/speedrun-e1m1/development-attempts.json): sandbox localhost EPERM before deployment, then a runtime-verifier mismatch at immutable address placeholders before any gameplay tic. Both were resolved and no engine expectation changed. Failed-run artifacts remain local. Adding native footer checksum/manifest metadata after the EVM run changed the inspector hash; the final four-profile native recheck confirms identical generated replay/exit observer sources, input tape and complete states. All EVM library/runner hashes still match the actual executed source; the offline verifier checks this distinction explicitly.

## Handoff and limits

This is independent experiment acceptance, not Phase4 release/integration acceptance. Production `Doom.initializeGame` still chooses medium skill and its input APIs build keyboard commands; mouse/joystick are outside that input profile. Supporting this tape in production would require selecting skill before spawn and a reviewed exact ticcmd/demo input endpoint (or appropriate original mouse-command support). Neither change is implemented here. Rendering, UI, intermission and episode progression were not exercised or modified. Recording-time IWAD bytes and all-state equivalence to DSDA remain unverified; the specified tape's successful pinned-original-C and matching EVM replay are proven.

Checkpoints: `99ba341` scope/source; `38efd8c` original tape/native exit. The final EVM checkpoint on `feat/phase4-speedrun-e1m1` contains the isolated adapter, runners and receipt/state evidence. Use `git rev-parse HEAD` for its exact SHA. No integration dependency or production change is required for this experiment; no main changes, merges or pushes occurred. The pre-existing untracked `.toolchain` symlink remains; all other deliverables are committed. Stop after E1M1.

Measured verification end: 2026-10-10 15:30:34 UTC, following the recorded 14:56:09 UTC start. Goal-service attribution at that checkpoint: 176,692 tokens and 2,065 elapsed seconds; no per-stage usage or monetary attribution is available. [`evidence-manifest.json`](../artifacts/speedrun-e1m1/evidence-manifest.json) binds the saved evidence by file size and SHA-256. Focused build, four-profile native replay/recheck, actual EVM receipts/storage comparison, offline receipt verification, Python/Node syntax, Solidity formatting, report links and whitespace checks passed. No full inherited acceptance run was performed.
