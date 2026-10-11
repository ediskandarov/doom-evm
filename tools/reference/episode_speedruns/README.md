# Independent Episode One recordings

Source the pinned toolchain before running commands. All generated binaries,
WADs, frame pixels, chain checkpoints and MP4s belong to this worktree's ignored
`artifacts/local`. No production engine source, original C or resource schema is
modified. Each map has its own source/native/full-rate directories. Never share
an output directory between running processes; the coordinator refuses its own
occupied lock and completed recordings. The EVM runner rejects occupied ports
and reserved 8545/18880/8088, starts one child Anvil and stops only that child.

```sh
source scripts/env.sh
node tools/wad/download.ts artifacts/local/freedoom
node tools/wad/pack.ts artifacts/local/freedoom/freedoom1.wad artifacts/local/wad
node tools/wad/episode-pack.ts pack artifacts/local/freedoom/freedoom1.wad artifacts/local/wad
node tools/wad/check.ts artifacts/local/freedoom/freedoom1.wad artifacts/local/wad
python3 tools/reference/episode_speedruns/native.py artifacts/local/episode-speedruns/E1M2
python3 tools/reference/episode_speedruns/observer.py
forge build artifacts/local/episode-speedruns/observer/src/support/EpisodeSpeedrunProbe.sol src/evm/ResourceStore.sol --out artifacts/local/episode-speedruns/observer/out --cache-path artifacts/local/episode-speedruns/observer/cache
python3 tools/reference/episode_speedruns/record.py E1M2 --port 18640
```

Before native replay, place the unchanged downloaded demo at `source-download`
and its provenance at `source.json` in that map's directory. Required source
fields include `map`, `demoSha256`, author and original URL. The native tool
refuses a different hash and unsupported formats/settings. It uses the preserved
original command reader and native gameplay builder. Classic version109/110
single-player short-tic demos, skills0–4, maps1–9 and the explicit no-monsters flag
are supported. Respawn, fast, deathmatch, multiplayer, long-tic and extended
commands are rejected. Do not infer compatible gameplay from the header alone.

For E1M2, committed tape/provenance and native evidence are under
`artifacts/episode-speedruns/E1M2`; copy the `.lmp` to the local `source-download`
filename and the source metadata to `source.json`. Preserve original demo footer
and notes even if their port labels disagree.

The opt-in experimental virtual profile and provenance logger reuse the existing
`virtual_pointer/observer.py` transformations in a goal-owned generated clone.
Every original draw guard and allocator body is retained. `EpisodeSpeedrunProbe`
adds map/skill selection to the accepted video probe; gameplay remains entirely
in Solidity. Rendering observes a temporary copy; renderer history is not
persisted into gameplay. This is observational full-rate capture, not production
UI/Frame integration acceptance.

Checkpoint/resume:

```sh
python3 tools/reference/episode_speedruns/record.py E1M2 --resume --port 18640
python3 tools/reference/episode_speedruns/record.py E1M2 --encode-only
```

Every250 completed tics (configurable), the runner saves its own Anvil chain dump
and all prior mined receipts, then atomically replaces the checkpoint pointer.
The default reduces disk use for large storage dumps; reserve sufficient disk
space for each map. A SIGINT/SIGTERM requests a checkpoint at the next complete
frame. The low-level runner also supports `--stop-after-tic N` for deliberate
resume checks. An incomplete checkpoint stop exits nonzero and never emits a
complete MP4. Last safe checkpoints survive later render/replay failures.

Resume refuses source/ABI/input/resource/budget drift, verifies checkpoint hash
and earlier frame hashes, loads only into a newly owned node, reads back every
resource runtime, rechecks the probe runtime/driver, reconstructs every retained
native/EVM receipt observation, and checks saved state and frame counter before
continuing. The Anvil RPC request-body limit is disabled to transfer its own
large chain dumps; its execution memory limit remains1GiB and gas10B. No native
state is loaded into EVM. Earlier receipts remain the historical transaction
proof when the restored node does not retain historical blocks.

Independent native pixel captures use a fresh original-C no-render prefix plus
one render per target tic, matching the probe chronology:

```sh
python3 tools/reference/episode_speedruns/native-frames.py --source artifacts/local/episode-speedruns/E1M2 --output artifacts/local/episode-speedruns/E1M2/native-full
python3 tools/reference/episode_speedruns/verify.py artifacts/local/episode-speedruns/E1M2 artifacts/local/episode-speedruns/E1M2/full-rate --native-frames artifacts/local/episode-speedruns/E1M2/native-full
```

Equality is reported per declared O2/O0/sanitized capture profile. Every actual
provenance4 use and destination is retained separately, including samples later
overwritten. A virtual-derived pixel is still a deterministic extension even
when its value equals a native capture. No universal pointer/pixel equivalence
is inferred. The encoder reuses the accepted host-only palette expansion,
nearest-neighbor scaling and H.264 encoding with exactly one image per tic at35Hz.

`proton-download.ts` is an optional direct public-share downloader using official
Proton Drive SDK0.22.2, crypto2.2.0 and esbuild. It uses public-link SRP and verified
download APIs, no account or browser. Install into an ignored local directory
with `--ignore-scripts`, copy the source there for dependency resolution, then
bundle with `--bundle --platform=node --format=esm --external:openpgp
--alias:openpgp/lightweight=openpgp`. Invoke with the public URL and local output
path. Keep session tokens and signed storage URLs out of committed logs; preserve
only demo identity, archive hash and public source URL.
