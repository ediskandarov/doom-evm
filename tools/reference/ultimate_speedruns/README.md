# Ultimate DOOM Episode One experimental speedrun suite

Use the isolated feature worktree. Read AGENTS.md. Never use occupied ports,
reserved ports 18880/8088, another owner's runtime, or another worktree's
artifacts. Source `scripts/env.sh` before Node/Forge/Anvil commands. Pin original
DOOM submodule at a77dfb96cb91780ca334d0d4cfd86957558007e0. Keep `.toolchain`
linked to the existing pinned toolchain; do not rebuild or alter it.

The authenticated commercial IWAD must be supplied locally, not downloaded
from a redistribution site. This suite requires MD5
c4fe9fd920207691a9f493668e0a2083 and SHA-256
6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f.
The rerelease is incompatible. Freedoom's pinned profile, shared resource
adapters and tools remain separate and unchanged.

## Prepare local resources and affected roots

```sh
git submodule update --init original/DOOM
source scripts/env.sh
mkdir -p artifacts/local/ultimate-doom
cp ~/Downloads/doom-steam/base/DOOM.WAD artifacts/local/ultimate-doom/DOOM.WAD
node tools/reference/ultimate_speedruns/pack.ts
python3 tools/reference/ultimate_speedruns/adapters.py
python3 tools/reference/ultimate_speedruns/observer.py
forge build artifacts/local/ultimate-speedruns/observer/src/support/UltimateSpeedrunProbe.sol src/evm/ResourceStore.sol --out artifacts/local/ultimate-speedruns/observer/out --cache-path artifacts/local/ultimate-speedruns/observer/cache
```

The packer verifies both IWAD hashes and all nine map resource schemas. Generated
commercial blobs/directories/palettes, clone sources, native world geometry and
artwork stay in ignored `artifacts/local`; adapters authenticate only identity,
counts and hashes. The observer changes telemetry only and retains provenance
checks, draw guards and allocator algorithms. It builds with pinned solc
0.8.37, viaIR, optimizer and Cancun. No production ABI is changed.

Run `python3 tools/reference/ultimate_speedruns/stage-inputs.py` to authenticate
and stage all committed archives and alternate tapes without overwriting existing
inputs or derived metadata. For arbitrary new inputs, stage original demo
archive/source metadata under a per-map local
directory, extract its single original `.lmp` verbatim as `source-download`, and
copy `source.json`. Reject archives containing WADs. `native.py DIRECTORY`
extracts commands, compiles the pinned original command decoder and missing
native references in this worktree, and checks the exact IWAD/native exits.
For new acquisition, save the public DSDA Episode 1 IL index to
`artifacts/local/ultimate-speedruns/dsda-index.html`, then run `acquire.py`.
It preserves original ZIP/demo/author notes/URL/SHA and selects single-player,
non-TAS UV Speed DSDA-Doom complevel3 inputs. Archives are real tapes, never
video reconstruction or invented controls. Review acquisition metadata before
changing selected inputs. E1M8 uses the preserved verified Sedlo 046 alternate.

## Independent recording and verification

```sh
python3 tools/reference/ultimate_speedruns/monitor.py
# In a separate shell with the pinned environment sourced:
python3 tools/reference/ultimate_speedruns/suite.py --maps E1M1,E1M2 --port 18641
python3 tools/reference/ultimate_speedruns/suite.py --maps E1M1 --stage verify
```

The coordinator handles maps sequentially and continues after a failed map.
Use `--plan` to inspect commands and `--stage native|evm|verify|all` to isolate
work. Existing completed recordings are reverified without replaying them.
Native all-allocation-profile failure remains failed. Only the independently
hash-bound `native-domain.mjs` gate may establish the finite normal-zone
profile; it does not mask an EVM field or force a mismatching tape to pass.
E1M3/E1M5 normal tapes use that explicit profile. An unclassified audit failure
blocks the map. For arbitrary new inputs, stage separate directories/attempts,
not over an accepted demo or completed recording.

Every successful capture is one original gameplay tic and one mined EVM Frame.
Rendering operates on a temporary memory copy; every saved whole gameplay state
is compared before/after. Native snapshots are comparison-only inputs. Native
pixel captures run original C from fresh processes for O2/O0/ASan-UBSan, with
complete pre-render world comparison. `verify.py` (or the explicitly named
`verify-native-domain.py`) checks state/receipt/frame/palette/media hashes.
`pixel-domain.py` rejects every common-native pixel mismatch outside recorded
virtual-pointer destinations; it verifies each native profile's actual bytes.
It does not confer universal pixel equality. `checkpoint-result.py MAP`
requires complete media and supported-domain gates before exporting small
metadata; use `--base` for a separately staged alternate.

Full videos use the original indexed8 frames and authenticated palette,
35 FPS, one frame per tic, nearest scaling and 4:3 display aspect. PNG/indexed8
are exact; H.264 is lossy. No MP4 is produced as a complete recording after a
missing/rejected frame. Production browser/UI or persistent renderer history
acceptance is outside this observational test adapter's claim.

## Resume, infrastructure and disk

`evm.mjs --resume` restores the latest chain and independently checks frozen
source/compiler/ABI/resources/input/budget identity, resource runtime bytes,
native observations, stored snapshot and frame counter before proceeding.
Checkpoints stream chain hex and receipts to compressed files; they avoid
Node's string-size ceiling. State restore uses an owned Anvil's `--load-state`
file and removes the temporary restore JSON after load. SIGTERM/SIGINT requests
a safe checkpoint at the next completed tic. `--stop-after-tic N` is an explicit
partial checkpoint, not a full recording. The coordinator's `--resume` retains
prior root files using hardlinks before replaying an interrupted attempt, and
refuses a blind retry of a documented renderer bounds failure.

Anvil is localhost-only; port availability is checked before launch. Each
runner terminates only its own child. Default local limits are 10B gas, 1 GiB
EVM memory, no RPC request-size cap, and two-block history/receipt retention.
All accepted proof receipts persist separately from that pruning. Authorized
local `--gas-limit` and `--memory-limit` may rise incrementally without changing
compiler or hardfork; checkpoint identity drift still fails explicitly.
Receipt/RPC deadlines are 300 seconds; streamed state dumps allow 900 seconds. Actual configuration,
UTC/RPC/session timing and costs are in each report, not estimated from video
length. Monitor host disk/RAM/swap/RSS. Avoid episode-wide unbounded concurrency.

```sh
python3 tools/reference/ultimate_speedruns/clean-checkpoints.py artifacts/local/ultimate-speedruns
```

Cleanup validates the latest compressed chain/receipt SHA before removing
state dumps and duplicate checkpoint receipts strictly older than the validated
head. It never removes a new checkpoint awaiting atomic pointer publication. It retains the latest
restore point, all final proof receipts, demo inputs, failed evidence and source
fixtures. Relocated evidence is resolved by sibling filename and SHA. Every
removal records size/SHA/reason in `checkpoint-cleanup.jsonl`. Do not delete
unknown files or clean another owner's resources/toolchain/runtime.

## Bounds failures

Use `render-diagnostic.py` and `evm-diagnostic.mjs` as described in
[the detailed bounds report](../../../docs/ULTIMATE-RENDER-BOUNDS.md). They add
error evidence, not substitute bytes. `gameplay.mjs` independently verifies
the remaining whole tape through a real exit with zero render calls;
`verify-gameplay.py` rejects any claim that it is a video.
`checkpoint-blocker.py BASE` requires full independent gameplay, verified
partial receipts/pixels, exact savedDigest reproduction and current source
hashes before exporting metadata. In the original observer, external owner-slot addresses remain unsupported.
The explicit owner-v1 extension below supports only proven authenticated WAD
cache slots. Other unknown pointers and native out-of-array intercept corruption
remain unsupported. Never loosen a
gate, invent an owner address, reuse missing frames or patch state to match.

Keep MP4s, commercial resources/geometry/frame payloads and full receipts out
of Git. Gitmoji commits contain source and small provenance/result/hash
manifests. Do not push or merge main. See per-map reports and the episode summary
for the measured outcome; successful renderer execution alone is not proof of
native-exact bytes.


## Explicit experimental owner-slot extension

Read [the source investigation](../../../docs/ULTIMATE-OWNER-POINTERS.md) before
using this profile. It extends the opt-in virtual-pointer adapter with a
separate `lumpcache[]` address domain, not arbitrary C process addresses.
Texture composite and other unproven owner slots remain unknown. Provenance 4
means zone links; provenance 5 means validated WAD cache owner-slot bytes.
Neither category establishes actual native pointer-byte equivalence.

```sh
source scripts/env.sh
python3 tools/reference/ultimate_speedruns/observer-owner.py
forge build artifacts/local/ultimate-speedruns/owner-observer/src/support/UltimateSpeedrunProbe.sol src/evm/ResourceStore.sol --out artifacts/local/ultimate-speedruns/owner-observer/out --cache-path artifacts/local/ultimate-speedruns/owner-observer/cache
python3 tools/reference/ultimate_speedruns/monitor-owner.py
# Separate shell, same pinned environment:
python3 tools/reference/ultimate_speedruns/owner-suite.py --maps 3,5,6,8,1,2,4,7,9 --concurrency 2
```

The suite chooses the already audited native gameplay domain for each tape,
uses isolated ports 18641–18649, and writes separate `owner-v1/full-rate`
directories. It preserves previous producers, five accepted recordings and
partial failure evidence. Existing successful attempts are reverified; interrupted
attempts resume from their frozen checkpoint identity. Add `--commit` only when
progressive feature-branch commits are desired. `--wait-for 3,8` can read this
owner's separately launched jobs' completed reports; it never attaches to a
runtime. At most two Episode jobs run concurrently.

Each completion independently verifies whole native snapshots, mined frame
receipts, all virtual sample identities and bytes, supported native pixels,
palette/PNG/media hashes and genuine exits. Five accepted-map regressions
require every prior indexed8 frame hash and original virtual provenance record
to remain identical. Periodic cleanup removes only validated superseded
owner-v1 checkpoint dumps/duplicate checkpoint receipts; final receipts and the
newest validated recovery state remain. The monitor records sampled host
RAM/swap/disk and owned Node/Anvil RSS. Missing measurements are not estimated.

After all nine results pass and owned jobs/monitor have stopped:

```sh
python3 tools/reference/ultimate_speedruns/owner-episode-summary.py
```

This final gate binds all nine immutable manifests and MP4s, verifies exact
35 FPS packet presentation timestamps and durations, checks the five old videos
are unchanged, compares all four preserved partial prefixes, and exports the
measured resource/cleanup summary. It also requires the separate preserved
Freedoom regression proof. [Episode acceptance](../../../docs/ULTIMATE-OWNER-EPISODE.md)
is generated only after every gate passes. Keep all commercial artifacts local.
