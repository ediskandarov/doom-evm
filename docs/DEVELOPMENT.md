# Development and verification

Use the [getting-started setup](GETTING-STARTED.md) and run commands from the
repository root. `source scripts/env.sh` selects project-local tools. The pinned
policy is Foundry 1.8.5, solc 0.8.37, optimizer 200, viaIR and Cancun. Node is
24.11.0. Python tooling is mostly standard library; media work additionally needs
Pillow, FFmpeg and FFprobe. Native comparisons pin Apple Clang 17.0.0
(`clang-1700.0.13.5`), target `arm64-apple-darwin24.6.0`.
[Exact flags and profiles](../TOOLCHAIN.md).

## Build the browser contracts

Players need no build. Developers can compile the production roots into a private
cache/output pair:

```sh
source scripts/env.sh
forge build src/evm/Doom.sol src/evm/Doom2.sol src/evm/ResourceStore.sol \
  --offline --no-lint --skip test script \
  --out artifacts/local/release-build/out \
  --cache-path artifacts/local/release-build/cache
```

Imports still compile; `--match-path` alone is not a compilation filter. A cold
viaIR build can take minutes. Reuse compatible artifacts by copying **both**
`out/` and `cache/` into your private build directory and letting Forge validate
source/dependency hashes. Do not share a writable cache with another worktree or
change compiler settings to avoid a rebuild.

The existing combined packaging entry point is:

```sh
node tools/wad/download.ts artifacts/local/freedoom
python3 tools/reference/death_respawn/package.py artifacts/local/release-build
```

Despite its historical directory name, this wrapper packages **both** current
production adapters. It applies the existing asynchronous `cast keccak` stdin
adaptation to the two profile packagers, checks compiler metadata/source hashes,
and stages the authenticated Freedoom payload. It does not deploy. The original
packagers remain for historical reproduction. Review every generated release
diff, including pins, before committing. Never package commercial IWADs.

## Focused tests

Prepare resources before tests that consume them:

```sh
node tools/wad/download.ts artifacts/local/freedoom
cp artifacts/local/freedoom/freedoom1.wad web/install-assets/freedoom1.wad
node tools/wad/episode-pack.ts pack artifacts/local/freedoom/freedoom1.wad artifacts/local/wad
python3 tools/reference/episode/reference.py --check
node --test web/*.test.mjs tools/wad/*.test.ts tools/execution-budget.test.mjs
python3 -m unittest discover -s test/tooling -p 'test_*.py' -v
node tools/wad/check-source-identity.mjs
python3 scripts/check-toolchain.py
```

The episode native step creates the ignored files consumed by `episode.test.ts`
and checks them against the committed manifest. `--check` is essential: accepted
fixtures should not be regenerated just to make tests pass. The suite includes
independent original-C resource comparisons for nine maps, browser input,
installation/recovery, resource authentication and budget handling.

For a Solidity change, select the relevant existing tests and imported dependencies
under the [risk-based policy](04-IMPLEMENTATION-PLAN-EXTRA.md#5-verification-cadence-and-checkpoint-policy).
The production build above is not a substitute for behavioral tests. Consult the
owning module report for native comparisons and isolated Forge commands; do not
automatically run every historical phase for a documentation edit.

## Real browser deployment

The current three-game runner uses the actual webpage, local IWAD File API,
ordinary transactions and all 64,000 Canvas pixels. Supply your own commercial
files. It refuses occupied ports and stops its owned Anvil/Chrome:

```sh
node tools/browser-deployment/three-game-check.mjs \
  --port 19671 --http-port 19672 \
  --output-prefix artifacts/local/browser-reproduction/run \
  --ultimate-wad "$HOME/Downloads/doom-steam/base/DOOM.WAD" \
  --doom2-wad "$HOME/Downloads/doom2-steam/base/DOOM2.WAD"
```

Set `CHROME_BIN` to an installed Chrome executable if needed. Use free ports;
18880/8088 are reserved for the playground. Keep commercial screenshots,
transactions, IWADs and extracted resources under ignored `artifacts/local/`.
The older `tools/browser-deployment/check.mjs` has historical unavailable-profile
assertions and is not the current three-game acceptance entry point.

This proves installation, profile selection, bounded gameplay and EVM-to-Canvas
delivery. It is not a full episode playthrough or a universal native pixel proof.
[Three-game report](browser-deployment/THREE-GAME-INTEGRATION.md).

## Reproduce accepted evidence

Use the source revision, IWAD identity, compiler, native memory profile and output
paths bound by the chosen certificate. Historical commands can write fixtures or
published reports by default: read their CLI first and use a fresh worktree/output
directory. A current-source rerun is a new checkpoint, not replacement evidence.

| Evidence | Authoritative reproduction entry |
|---|---|
| Phase 0–3 full inheritance | [Toolchain/run descriptions](../TOOLCHAIN.md), `scripts/verify-phase0.py`, `verify-phase1.py`, `verify-phase2.py`; the last grew to include Phase 3 gates |
| Original-C numerical/source checks | [Native reference tools](../tools/reference/README.md), [renderer](../tools/reference/renderer/README.md), [gameplay](../tools/reference/gameplay/README.md) |
| Freedoom episode speedruns | [Episode tools](../tools/reference/episode_speedruns/README.md) |
| Ultimate and virtual-owner comparisons | [Ultimate tools](../tools/reference/ultimate_speedruns/README.md), [owner episode](ULTIMATE-OWNER-EPISODE.md) |
| Nine complete presentation recordings | [Full-video tools](../tools/reference/full_videos/README.md), [accepted metrics](../artifacts/full-videos/EPISODE-SUMMARY.md) |
| DOOM II startup/MAP01/MAP07 | [DOOM II report and commands](doom2/REPORT.md) |
| Options and composition | [Combined tools](../tools/reference/full_options/README.md) |
| Death/Exact Snapshot integration | [Combined tools](../tools/reference/death_save/README.md) |

Read-only receipt/hash/media verifiers can audit retained recordings without
re-executing gameplay. The complete 18,175-frame EVM recording suite was not
rerun for this release preparation. Large local evidence must be supplied by its
owner; committed manifests do not reconstruct missing commercial pixels or MP4s.

Preserve failures alongside successes. Keep distinctions between canonical
gameplay-state comparison, full native framebuffer comparison, supported-pixel
comparison, EVM receipt provenance and Canvas presentation. The [compatibility
guide](COMPATIBILITY.md) explains those limits.

## Contributing

For the release-preparation preservation/link check, use a fresh report path:

```sh
python3 tools/release/check.py \
  --compiled artifacts/local/release-build \
  --output artifacts/local/release-check/new-report.json
```

This audit is tied to the recorded release baseline: it protects historical blobs,
checks local documentation links and current anchors, the upstream pin, packaged
source/artifact identities and compiler settings. It deliberately rejects changes
outside the release's five existing-file edits; it is not a general future CI
policy. `--compiled` is optional when only auditing a checkout. External links
and whole-engine behavior are outside this check.

Follow [AGENTS.md](../AGENTS.md) for isolated worktree/runtime ownership, integration
and Gitmoji commits. Follow [PORTING.md](../PORTING.md) for source-faithful names,
control flow, arithmetic and RNG order. Shared interface changes need integrator
coordination. Tests, source bindings, failed diagnostics, licenses and historical
reports are part of the project's reproducibility surface, not cleanup debris.
