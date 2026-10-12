# Release cleanup inventory

Inventory baseline: `1b728fe3f8307a49f71437d5af75a4935df81492`.
All tracked paths were enumerated, executable/source duplicates hashed, imports
traced from production/browser roots, and apparent orphans checked against tests,
runners, documentation and evidence. No deletion occurred during inventory.
This is a dependency audit, not a whole-program dead-code proof.

## Repository classification

| Area at baseline | Count | Classification and consumers | Decision |
|---|---:|---|---|
| Root files | 14 | README, license/upstream/porting/toolchain/input docs, agent policy, Git attributes/ignores/submodule, Node/compiler/budget locks | Keep policy and execution pins; refresh public entry points and IWAD/media ignore rules |
| `src/doom/` | 67 | Original-source Solidity modules, header/state adapters and memory profiles; production, test and recording consumers | Keep unchanged; fidelity takes precedence over style |
| `src/evm/` | 20 | Production adapters, persistence, input/Frame/resource protocols; includes standalone ResourceStore deployment | Keep unchanged |
| `src/support/` | 29 | Native/EVM observation probes, historical measurements and fixtures; **UltimateStartup is also a production dependency** | Keep unchanged; directory move would change source bindings |
| `web/` | 39 | 17-module launcher import closure, legacy diagnostic app, Node tests, authenticated contract/palette/license packages | Keep browser logic/artifacts unchanged; document current launcher |
| `scripts/` | 13 | Environment, installer, budgets, schema checks, Anvil launcher and historical phase gates | Fix measured installer replacement issue; retain old gate names and wrappers |
| `tools/` | 538 | WAD/resource/table tooling, transport, native oracles, renderer, browser deployment, audits and usage telemetry | Retain independent or source-bound reproduction roles; document preferred current commands |
| `test/` | 1,391 | 86 Solidity test files and 1,305 fixture files at baseline; fixture licenses, binaries, manifests and source bindings | Preserve byte-for-byte; add separate installer tests only |
| `schemas/` | 8 | Frozen WAD, bundle, episode, table, vector, palette and Frame schemas consumed by tools/tests | Preserve |
| `docs/` | 110 | Designs, interfaces, per-module/map reports, accepted and failed engineering checkpoints, plus current deployment guide | Add a current index/guide layer; preserve historical reports in place |
| `artifacts/` (tracked) | 1,960 | Phase 0–4, browser, speedrun, full-video, memory, save/death and telemetry certificates; source fingerprints and failed diagnostics | Preserve, including large accepted archives and diagnostic logs |
| `original/DOOM` | 1 Git submodule | Original-C oracle/source extraction/licensing at pinned upstream SHA | Preserve pin and clean source |
| Ignored local data | Not counted as source | `.toolchain`, `out`, `cache`, `node_modules`, `artifacts/local`, local browser configs; user WADs, MP4s and experiments | No deletion; copy caches read-only into goal-local outputs |

Counts are the pre-cleanup tracked inventory, excluding submodule contents.
The root count includes configuration files such as `foundry.toml` and
`toolchain.lock.json`; they are not repeated in a separate infrastructure bucket.

## Consumers and entry points

| Task | Current path | Historical/independent role retained |
|---|---|---|
| Environment | `scripts/install-toolchain.py`, `env.sh`, `check-toolchain.py` | Locked compiler/runtime; atomic installer replacement does not change versions |
| WAD preparation | `tools/wad/download.ts`, `episode-pack.ts` | `pack.ts`, snapshots, independent native resource comparison and commercial packers bind other profiles |
| Production build | Explicit Doom/Doom2/ResourceStore Forge roots in [development](../DEVELOPMENT.md) | Phase verifiers and isolated probe builds measure different source closures |
| Release packaging | `tools/reference/death_respawn/package.py` calls both profile packagers | Existing async stdin adaptation avoids duplicating or replacing their authenticity checks |
| Browser launch | Local static `web/` server + dedicated Anvil; deployment in browser | `tools/transport/serve.mjs`, `web/app.mjs` and synthetic palette remain test/legacy entry points |
| Browser acceptance | `tools/browser-deployment/three-game-check.mjs` | Single-profile `check.mjs` has historical unavailable-profile assertions; keep for its checkpoint, do not advertise as current |
| Native references | `tools/reference/` families with per-profile manifests | Different compile flags, allocations, UI borrowing and render histories are independent experiments |
| EVM verification | Focused Forge tests and module-specific `evm.mjs` runners | Production and observation consumers have distinct ABI/cost/persistence evidence |
| Speedrun playback | `speedrun`, `episode_speedruns`, `ultimate_speedruns`, `doom2` | Original tapes, strict/virtual/owner profiles and native-domain exclusions must remain separable |
| Video recording | `speedrun`, `episode_speedruns`, `ultimate_speedruns`, `full_videos` | Sampled/full-rate/long/short/finale recorders implement different accepted timing and endpoints |
| Evidence audit | Certificate verifiers, source/receipt/media hashes | Generated reports are evidence, not automatically disposable build products |
| Usage accounting | `tools/usage/` | Sanitized historical experiment accounting; not required to play, but not unused evidence tooling |

`Doom.sol` has 81 files in its static import closure; `Doom2.sol` has 80.
Release source pins also include standalone ResourceStore (82/81 source entries).
The launcher imports 17 JavaScript modules. `web/app.mjs` is retained by the
explicit diagnostic configuration path in `web/index.html` and legacy tests.
ResourceStore has no production import because it is separately deployed.

## Cleanup decisions and exact removals

**Deleted files: none. Moved files: none.** No demonstrably unreachable scaffold
was found whose removal would preserve the documented reproduction surface.
No gameplay, renderer, allocator, pointer, ABI, compiler, fixture or golden changed.

- Replace obsolete Phase-3-first README instructions with one current player
  path; move detail into linked current documents, leaving checkpoint reports intact.
- Consolidate *documented* build/package/browser/test entry points in
  [Development](../DEVELOPMENT.md). Existing independent implementations remain.
- Replace in-place toolchain executable writes with atomic file replacement.
  The real reinstall initially terminated Forge with SIGKILL; exact downloaded
  bytes matched the existing binaries, and a subsequent invocation worked. The
  suspected macOS code-signature cache issue motivates preserving the old inode;
  the fix's inode/checksum behavior is directly tested without claiming an OS
  diagnosis was proven.
- Replace the narrow `web/install-assets/*.wad` ignore with case-insensitive
  repository-wide IWAD/MP4 patterns. This affects untracked future additions;
  it does not remove any user files or change existing tracked evidence.
- Reuse the hash-matched accepted Freedoom MP4 to produce a small README GIF.
  No gameplay is rerendered and no commercial artwork is committed.

## Duplicate and obsolete-looking candidates retained

| Candidate | Evidence of use / reason to retain |
|---|---|
| `FrameFixture.sol`, `StackPressure.sol`, `ResourcePlacement.sol` | Phase 0–1 experiments, tests and measured reports; intentionally synthetic, not production dead code |
| `doomtype.sol` | Header adaptation consumed by `test/unit/Contexts.t.sol` and the porting map |
| `p_setup_static.sol`, `DoomScene.sol` | Imported by the live DoomRenderer path and renderer tests; not superseded solely by gameplay startup |
| `f_wipe.sol`, `FullSpeedrunProbe.sol` | Recording acceptance and native wipe tests; not production browser code, but actively evidenced |
| Identical `doom2/encode.py` / `ultimate_speedruns/encode.py` | Distinct recorded profile entry points; dynamically adapt the historical encoder and bind hashes/paths |
| Identical `doom2/pixel-domain.py` / `ultimate_speedruns/pixel-domain.py` | Independent profile reproduction; emitted proof includes verifier SHA-256 |
| Identical `episode_speedruns/verify.py` / `ultimate_speedruns/verify.py` | Certificate/source/receipt validators used by profile runners; consolidating would change historical verifier identity |
| Identical `artifacts/phase4/*/run-command.py` and two `run.py` copies | Captured execution records at integration checkpoints, not current shared tooling |
| Full-video long pilot, failed short pilot, diagnostic patches | Allocation/display-history diagnosis and failed-gate provenance; not failed work to erase |
| `artifacts/virtual-pointer/evidence.tar.gz` (~35 MB) | Accepted memory experiment evidence; size alone does not authorize removal |
| Browser packaged bytecode (~7.3 MB across two adapters) | Required for build-free installation; independently authenticated against source and compiler metadata |

## Remaining maintenance debt / proposed follow-ups

These are proposals, not release-goal engine work:

1. Keep historical tools pinned; a future measured change could extract shared
   packaging/encoding logic with byte-identical output checks and compatibility
   entry points. Avoid rewriting hash-bound wrappers merely to modernize style.
2. `src/support/UltimateStartup.sol` and the combined packager's death-respawn
   directory are misleading names. Documented now; moving them requires an
   explicit source/artifact binding migration.
3. Historical verifier defaults sometimes write committed fixture/report paths.
   Fresh outputs/worktrees and `--check` are essential; a separate review could
   make future defaults safer without mutating accepted tools.
4. Full final Phase 0–4 acceptance, production-browser melt, canonical save
   semantics, remaining original controls and broad DOOM II gameplay coverage
   are not completed by this cleanup. See [the fidelity audit](../COMPATIBILITY.md).
5. Native reproduction is macOS-profile-specific. Linux binaries in the lock are
   not evidence of Linux acceptance; Windows is not a documented/tested target.
6. Historical absolute paths and private commercial evidence remain intentionally
   bound to original runs. No source cleanup can manufacture missing local media.

AGENTS.md remains accurate and unchanged: its ownership, cache, risk-based gates
and fidelity requirements are still applicable. The shared Phase 4 ledger is
left for the designated integrator.
