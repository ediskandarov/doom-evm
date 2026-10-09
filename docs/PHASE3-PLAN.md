# Phase 3 implementation and acceptance ledger

Phase 2's accepted static renderer and all inherited gates remain the baseline.
The Phase 3 goal begins at `2026-10-09T14:10:28Z`; local usage collection uses
that explicit boundary. Earlier abandoned input scaffolding was removed and
does not count as accepted Phase 3 implementation.

## Recovery checkpoint


Current verification recovery: first inherited run at `367783e` correctly stopped
at the unchanged format gate, before compilation/tests. Five files were formatted
in `5a11e39`; all non-brace tokens remain identical, full build passes (70 files,
497.56 seconds), and all **403 tests / 40 suites pass with zero failures/skips**,
fuzz seed 0x44. [Format evidence](../artifacts/phase3/format-checkpoint.json).
Compiled engine bytecode changed beyond metadata, despite unchanged compiler
settings. Do not relabel prior kernel/production/browser/memory receipts current;
Fresh production 84848 passes all 129 tics, six native Frames and thirteen
whole-storage rollback guards. Checkpoint `f0bce73` [fresh production evidence](../tools/reference/gameplay/production-final-evidence.json)
records current init 1,621,885,757 gas and runtime 503,731 bytes; old receipts
remain historical. [Native reconciliation](../tools/reference/gameplay/production-native-reconciliation.json)
proves every original data file/Frame unchanged. Full kernel 60930 is terminal PASS: nine scenarios / 2,355 tics / 31 exact
frames / nine exact final stored snapshots, all 1,755 runtimes verified.
Checkpoint `3242865` [fresh kernel evidence](../tools/reference/gameplay/final-kernel-evidence.json); Chrome 5132 is terminal PASS and committed `45d0f62`: all six native indexed
Frames, 84 exported field comparisons and Canvas RGBA bytes exact; actual
keyboard lifecycle/blur/deduplication/receipt fallback verified.
[Current Chrome evidence](../tools/transport/evidence/gameplay-browser-final.json).
Current clone memory checkpoint `3ad701b` is verified: all-render six tics
and six production-cadence tics (five no-render) pass all three-deployment
storage/field/native-frame and paired-clone gas comparisons. Measured boundaries
remain init 19,665,056B / no-render 8,749,760–8,753,856B / live render
11,918,816–11,956,800B. [Fresh memory evidence](../tools/reference/gameplay/production-final-memory-evidence.json).
A concurrent unlocked-sender attempt timed out waiting for a receipt after tic2;
no pending hash/nonce was retained, so shared-sender conflict is suspected only.
Empty pool/equal latest-pending nonce were observed; sequential replay passed.
No gas-exhaustion/revert evidence. All old reports remain historical.
Final audit refresh and frozen inherited/native gates remain. Current replay checkpoint
`0015986` verifies two complete independent ordinary deployments: all 130 × 14
rows, seven Frames, commands/cadence/sequences, startup/constructor/receipt gas
and thirteen rejection selectors/gas/whole-storage rollback assertions equal.
[Fresh replay evidence](../tools/reference/gameplay/production-final-reproducibility-evidence.json). No current bytecode-identity claim. Current native header checkpoint `c672568` passes all four retained tests inside
the 403-test full run; all 54 compiled source keccak bindings checked.
[Fresh header evidence](../tools/reference/phase3_zone_setup/final-validation.json).
Atomic fixture gas remains 1,624,686,931, distinct from production gas.
The 388-function audit snapshot needs refresh after the new evidence checkpoint.

Inherited compile headroom checkpoint `bcbe46a`: the 497.56-second dependency build
justifies forced-build timeout 1,200 seconds and enclosing Phase 0/1 wrappers
1,800/3,600 seconds. Runner self-test passes; exact diff validation proves every
command/assertion/compiler/gas setting and other individual timeout unchanged.

The first Phase 3 native batch passed 27 commands through projectile-world proof,
then stopped at a stale production-oracle manifest. Fresh separate production
and browser oracles pass four native profiles. All data files/commands/states/
Frames match their retained versions exactly; only production profile label and
generator source hash differ. Original oracles/reports remain unchanged. Final
full native regression will use the fresh oracle paths; no required gate removed.

Last implementation checkpoint: `5a11e39`, verified Forge formatting;
atomic production gameplay/startup implementation is `60cd6f7`;
original map allocation and native-zone interface integration is `1578f06`;
renderer/cache/backing checkpoint is `9c4ba50`; actor/mover lazy free is `ab316f8`;
verified source-derived renderer allocator startup is `d9ca352`;
zone core is `2392f4a`.
Last full kernel checkpoint: `53b5cd3`, atomic nine scenarios / 2,355 tics /
31 exact frames / nine final stored snapshots; all 63 consumed hashes checked.
[Bounded evidence](../tools/reference/gameplay/atomic-kernel-evidence.json).
Last native observation checkpoint: `01417ad`, rocket-world/blast observations;
`4d06c03` supplies the generic physical-byte/column proof;
`ba53a4b` supplies exact map/setup heap boundaries;
`5ffd10a` supplies the original zone lifecycle/layout evidence;
`7fc2cab` remains the exact post-render state extension.
Last audit checkpoint: `6749dcd`, 388 original definitions, 238 active core
gameplay definitions, 22 monster/boss families and explicit per-special/domain
limits. Generator/check pass; nested reports and current/hash-at-run drift are
disclosed. No new runtime acceptance claim. `6172458` updates root port/runtime
documentation to current atomic gameplay and configurable budgets.
Last ABI checkpoint: `1e6227d`, generated native sizeof/offsetof constants;
`python3 tools/zone/generate-layout.py --check` and standalone Forge build pass.
Last browser component checkpoint: `982782f`, atomic startup and configurable
transaction budgets. All 44 isolated tests pass, retaining the earlier 38 cases
and adding six atomic/configuration regressions. Historical staged support is
explicitly capability-gated; nativeZone alone uses one initializeGame call.
[Component evidence](../tools/transport/evidence/gameplay-atomic-input.json).
Actual Chrome checkpoint `a88f285` separately commits the executed runner and
[all-six-frame evidence](../tools/transport/evidence/gameplay-browser-atomic.json):
84 exported field comparisons, all 384,000 native indexed pixels and all Canvas
RGBA bytes exact, actual keyboard lifecycle, blur, deduplication and receipt fallback.
Seven original browser source bindings checked; budget dependencies separately
bound at integration. The 44-test component proof remains distinct.
Production adapter and its atomic/header/keyboard evidence are committed in
`60cd6f7`; atomic probe is committed in `53b5cd3`; real-browser is committed in `a88f285`; memory/reproducibility are committed in `c5a3069`.
[Memory](../tools/reference/gameplay/production-memory-evidence.json) and
[independent replay](../tools/reference/gameplay/production-reproducibility-evidence.json)
retain literal clone limits and complete replay scope separately. All current
source/report bindings and seven isolated measurement tests pass. **Phase 3 is
active; M2 and M3 are unaccepted.** Committed production `Doom.sol` now exposes verified atomic gameplay and keeps
accepted Phase 2 static rendering before startup.
The committed atomic public test-probe verifies nine scenarios, 2,355 tics and 31 frames.
The committed production adapter verifies 129 keyboard tics and six frames. Real
Chrome gameplay now passes all six frames; final inherited acceptance is pending.
Do not infer engine acceptance from completed module ports or finite passing streams.

`Implemented` means source exists; `integrated` means the stated consumer really
uses it; `verified` names the actual scope of executed evidence. Native-only or
mock-neighbor module proof does not imply whole-engine verification.

## Implementation and verification progress

| Workstream | Implementation | Integration | Verification and commit |
|---|---|---|---|
| Shared player/actor/thinker/world interfaces and heap | Base, persistence and native allocation extensions complete | All gameplay modules use stable IDs; native payload blocks now allocated/freed by heap/ticker, storage/resource aliases verified | `d793fd1`, `0960141`, `ab316f8`: all nine original payload sizes/tags, no embedded-thinker double allocation, lazy physical reuse with stable actor IDs; 21 focused tests pass. [Allocation checkpoint](../artifacts/phase3/zone-heap-checkpoint.json). Map/backing/production integration verified in `60cd6f7`/`53b5cd3`; final inherited gates pending. |
| Original state/action, actor, weapon tables and RNG | Complete | Imported by gameplay modules | Every field of 967 states/137 actor types/9 weapons and both RNG streams matches native; O0/O2/sanitizers. `f1081fd`. [Foundation checkpoint](../artifacts/phase3/foundation-checkpoint.json). |
| Keyboard commands and browser sampler | Complete declared keyboard profile; atomic startup and configurable budgets committed | Helper/decoder and serialized lifecycle verified; actual atomic production 129 tics and Chrome six frames separately executed, pending evidence commits | `0a7d839`: 41,007 original-C cases, 14 Forge tests, five browser tests. `a67f435`: 29 isolated lifecycle tests. `9d1b567`: 37 tests retain all prior cases and verify optional prepare/init, Stop and reload. [Staged evidence](../tools/transport/evidence/gameplay-staged-input.json). `982782f`: 44 isolated tests pass; [atomic component evidence](../tools/transport/evidence/gameplay-atomic-input.json). Actual six-frame Chrome gate passes at the atomic source snapshot; its separate checkpoint remains. |
| Original-C full gameplay/frame oracle | Complete original eight plus projectile reference scenario | Used by nine-scenario EVM comparison; native-only proof remains separate | 2,205 original tics and 24 live frames match O0/O2/ASan and alternate allocation fill. `6af2ec2`. [Native checkpoint](../artifacts/phase3/native-reference-checkpoint.json). |
| Collision, traversal and sight | All 40 active original functions implemented | Real hooks/spatial links integrated in nine atomic native/EVM probe scenarios; isolated tests additionally cover declared branches | 4,310 geometry cases and 71 scenarios match C; three Forge tests pass. `be86b4b`; fresh call-local traversal amendment `659ee64` passes unchanged goldens and full public-probe code generation. [Collision report](PHASE3-COLLISION.md). |
| Weapons, pickups and damage | Complete original p_pspr/p_inter functions | Real PSprite/actions/attacks integrated in probe; isolated proof uses explicit neighboring doubles for broader branch coverage | 72 weapon scenarios/11,520 tics and 6,025 interaction cases; 24 Forge tests pass. `e7d58a8`. [Combat report](PHASE3-COMBAT.md). |
| Live thinkers/ticker | All six active original functions implemented | Original ticker drives real world and stored state in all nine atomic probe scenarios | Eight original scheduling snapshots, same-tic spawn/stasis/lazy removal/pause order; TickTest passes. `ba901c2`. [Tick report](PHASE3-TICK.md). |
| Monster AI/actions | All 64 active original definitions implemented | Real sight/chase/attack actions integrated in probe; isolated species/action proof retains explicit doubles | 1,137 native cases and 64 Forge tests pass. `b2bb3b1`. [AI matrix](PHASE3-AI.md). |
| Player movement, actor lifecycle and G_Game lifecycle | All 24 active definitions complete | Original spatial helpers/hooks integrated in full probe; atomic production 129-tic proof and independent complete replay include allocator integration | 784 native cases across O0/O2/ASan/allocation-fill profiles; 24 Forge tests pass, including corrected positive aged-respawn case. `38a4d0e`. [Lifecycle report](PHASE3-LIFECYCLE.md), [validation](../test/fixtures/phase3_lifecycle/validation.json). |
| Doors, floors, ceilings, platforms and lights | All 33 active functions complete and committed | Paired with P_Spec in module tests and full probe; native real-level door use/obstruction persists exactly | `fdadcb5`: 359 native scenarios/79,021 snapshots, 2,160 plane cases and measured LP64 mover casts; all 28 Forge tests pass. [World report](PHASE3-WORLD-ACTIONS.md), [validation](../test/fixtures/phase3_world/validation.json). Undefined domains remain explicit. |
| Sector specials, switches, teleport and animations | All 23 active functions complete and committed | Real world dispatch tested on controlled maps and eight full probe scenarios; per-special branch scope remains explicit | `fdadcb5`: 416 helper cases plus 1,007 dispatch scenarios/4,048 paired snapshots; all 25 Forge tests pass. [Specials report](PHASE3-WORLD-SPECIALS.md), [validation](../test/fixtures/phase3_specials/validation.json). |
| Original bounding-box helpers | Both functions complete and committed | Committed startup uses exact original else-if ordering | `bc74405`: 521 streams/8,299 points match O0/O2/full sanitizers; MBBoxTest passes. [Validation](../test/fixtures/phase3_bbox/validation.json). Full probe startup matches native in all eight scenarios (`b1c2735`). |
| Gameplay persistence layout | Approved extensions implemented and committed | Real memory/storage/memory copy tested on synthetic nonempty actor/thinker/door state | `9bcc6af`: [storage checkpoint](../artifacts/phase3/storage-checkpoint.json). GameStorageTest passes (9,959,477 test gas), including map/resource/scratch aliases, renderer caches and framebuffer. Eight full-level final DSG1 snapshots match native (`b1c2735`); full-schema synthetic proof is separate from this observed subset. Actual atomic initialization 1,621,868,997 gas; bounded clone memory and production costs in `c5a3069`. |
| P_Setup gameplay startup | Implemented and committed | Real BLOCKMAP/REJECT, sector grouping and THINGS order connected to gameplay; ordinary authenticated EVM startup and persisted tic/frame scenarios match native | `b1c2735`: all eight startups, 2,205 persisted logical tics, 24 frames and eight final snapshots exact. Physical map/header/owner startup verified in `1578f06` and atomic `60cd6f7`. Integrator owns `src/doom/p_setup.sol`. Existing disk loader reused with explicit attribution. |
| DoomGame state/action/render adapter | Implemented and committed | All gameplay hooks and renderer projection written; committed atomic production caller and nine-scenario probe | Type-checks in module batch; full public probe graph compiles; all eight startup states, 2,205 full logical tics, 24 exact 64,000-byte frames and eight final post-render stored snapshots pass. `b1c2735`: [comparison](../tools/reference/gameplay/COMPARISON.md), [validation](../test/fixtures/gameplay_evm/validation.json). Integrator owns `src/evm/DoomGame.sol`. |
| Production Doom adapter and browser gameplay | Atomic adapter committed `60cd6f7`; client component `982782f` | Original startup, keyboard/tic/render/storage and authenticated resources integrated; 129-tic atomic production and six-frame Chrome execute successfully | `a67f435`: [browser checkpoint](../artifacts/phase3/browser-input-checkpoint.json). Browser 29 isolated tests pass; no real gameplay browser claim. Production draft compile and 129 keyboard tics/14 state fields/six exact frames/13 rejection-storage rollback checks pass. Static real Chrome/WS/receipt/Canvas gate passes after config-only repair. Historical DrawBounds is resolved. Atomic production evidence [129 tics / six frames / 13 full-storage rollbacks](../tools/reference/gameplay/production-atomic-evidence.json), one init at 1,621,868,997 gas; [four header/setup tests](../tools/reference/phase3_zone_setup/atomic-validation.json). Real Chrome [six-frame checkpoint](../tools/transport/evidence/gameplay-browser-atomic.json) is `a88f285`; final inherited gates remain. |
| Full native/EVM gameplay comparison | Atomic probe and runner committed `53b5cd3` | Ordinary deployment, all 1,755 authenticated resource runtimes checked; real original hooks and stored state | Native post-render extension `7fc2cab` resolves the observer boundary without engine changes. Full corrected run passes all 2,205 tics/24 frames/eight exact final post-render stored snapshots; `b1c2735`: [retained evidence](../test/fixtures/gameplay_evm/evidence.json) and all 55 historical consumed hashes verified. New atomic [evidence](../tools/reference/gameplay/atomic-kernel-evidence.json): nine scenarios / 2,355 tics / 31 frames / nine stored states exact; all 63 consumed hashes freshly checked. |
| Native allocation/backing-memory adapter | Zone types/core committed; source-driven startup replay component verified and committed | Core, heap/ticker, map, semantic caches and known backing are component-integrated and committed; full atomic production/kernel/browser proof committed; inherited gates pending | `2392f4a`: 1,624 exact snapshots, 15 fatal probes, two Forge tests. `5ffd10a`: nine native contexts/four profiles, 83,054 events, 84 snapshots and 63,975 sprite-adjacency checks; all prior native outputs unchanged. [Lifecycle validation](../test/fixtures/phase3_zone_lifecycle/validation.json). `d9ca352`: 6,498 startup calls/4,913 headers/4,126 owners and three Forge tests; [startup validation](../test/fixtures/phase3_zone_startup/validation.json). No runtime allocation tape, clamp, invented padding or guard removal. |
| Resource initializer integration amendment | Complete and committed | Complete public test-probe graph compiles | `abfb38c`: all 20 inherited RData tests pass, including all native lookup/sprite/map/composite fields. [Checkpoint](../artifacts/phase3/resource-init-checkpoint.json). Final inherited gate remains pending. |
| Original feature/function audit | 388 original definitions with spans/body hashes/mappings; 22-family matrix and explicit unsupported domains | Audit-time source snapshot; refresh on final freeze | `6749dcd`: [feature matrix](PHASE3-FEATURE-MATRIX.md), [JSON inventory](../artifacts/phase3/feature-matrix.json). Evidence scope and unsupported/undefined domains explicit; no new runtime acceptance claim. |
| Usage telemetry | Complete collector; active collection | Local Codex logs only, no engine dependency or services | 20 collector tests pass; historical Phase 0–2 totals remain stable. Phase 3 boundary `d47dd86`. Latest snapshots are ignored `artifacts/local/codex-usage/`. |

The executed mixed module batch was:

```sh
.toolchain/bin/forge test --match-path 'test/unit/{p_map,p_maputl,p_tick,GameHeap,g_game,p_info,m_random}.t.sol' --skip p_enemy.t.sol -vv
```

It passed 22 tests in seven suites. Combat and AI have separate recorded passing
commands. This is **not** a fresh complete inherited-gate run.

Subsequent verified runs: 52 tests in the lifecycle/world batch (lifecycle 24),
then all 55 tests in `WorldActionsTest|WorldSpecials_Test|MBBoxTest|GameStorageTest`
(28/25/1/1). The strengthened nonempty `GameStorageTest` passed separately.
These are module and synthetic-storage evidence, not production acceptance.

Reproducible checkpoint commands (terminal results recorded in linked validation files):

```sh
.toolchain/bin/forge test --match-contract 'PUserLifecycleTest|PMobjLifecycleTest|GGameLifecycleTest|WorldActionsTest|WorldSpecials_Test' -vv
.toolchain/bin/forge test --match-contract 'WorldActionsTest|WorldSpecials_Test|MBBoxTest|GameStorageTest' -vv
.toolchain/bin/forge test --match-contract GameStorageTest -vv
python3 tools/reference/phase3_bbox/reference.py --check
python3 tools/reference/phase3_world/reference.py --check
python3 tools/reference/phase3_world/planes.py --check
python3 tools/reference/phase3_world/domains.py --check
python3 tools/reference/phase3_world/undefined_floor.py --check
python3 tools/reference/phase3_world/mover_casts.py --check
python3 tools/reference/phase3_specials/reference.py --check
python3 tools/reference/phase3_specials/dispatch.py --check
python3 tools/reference/phase3_specials/generate_dispatch.py --check
```

The native bbox/world/special commands were freshly rerun after hash validation,
all passing before their commits. Their committed binary fixtures are deliberate
reproducible conformance evidence; build products and local console logs are ignored.

## Remaining work and current constraints

Historical integrated probe evidence (`b1c2735`) covers all eight original E1M1
startups, 2,205 complete logical tic states, 24 exact 64,000-byte frames and eight
final post-render persisted snapshots. The PRE/POST-render ML_MAPPED observer
failure was resolved by the independent native extension `7fc2cab`; it required
no engine change. Production draft evidence separately covers 129 keyboard tics,
14 exported fields, six frames and 13 rejected calls with full storage-root rollback.
The static real Chrome transport/Canvas gate also passes. These historical scopes remain preserved. Current atomic production/kernel/browser
and repeat evidence below includes allocator integration; M2/M3 still need the
frozen inherited gate and final acceptance review.

Historical resolved engine blocker: real gameplay Chrome passed four frames and 14
fields, then tic five (mask 128, sequence 7) reverts with DrawBounds at
538,537,735 gas. Failed transaction:
`0xd28123618d70997eb485b1f4bce9126b6567a8ec064ab6542506f550e4caa677`.
That old instance remains inputSeq 6 / gametic 4. Report:
`artifacts/local/phase3-gameplay-browser.json`. Four native profiles reproduce
frac −1 sampling PLAYW0 offset 1148 of a 1128-byte lump: next LP64 zone-header ID
offset 20, written ZONEID low byte 17, mapped to palette index 139. This is a
logical asset overread inside the larger zone allocation, not proven ISO C UB.
Cause evidence: `artifacts/local/draw-diagnostic/conclusion.json`.
The new source-derived backing adapter resolves this without changing sampling:
Chrome 72876 now matches all six native frames and Canvas bytes. Final gates and
repeated streams, rather than this resolved revert, are the remaining blockers.

Verified recovery checkpoints:

- `2392f4a`: original allocator core, 1,624 snapshots / 15 fatal probes / two Forge tests.
- `5ffd10a`: complete native lifecycle and actual LP64 sizeof/offsetof, nine contexts
  × four profiles; 83,054 events / 84 snapshots / 63,975 adjacency checks.
  All prior native outputs unchanged. Peak live bytes 13,901,664 of 67,108,864;
  zero purges in these finite runs. Native tapes are comparison evidence only.
- `d9ca352`: EVM startup derives all 6,498 allocation/cache calls from authenticated
  metadata and original parsed definitions. All 4,913 headers and 4,126 owner marks
  match native. Three Forge tests pass under unchanged limits. Normal replay stage
  costs 344,974,734 test gas; fixture-inclusive normal test costs 808,761,041.
  These are component measurements, not integrated production estimates.
- `ab316f8`: native zone/payload/map/backing schema and typed heap/ticker wiring;
  all nine original sizes/tags, lazy physical free/reuse, stable IDs and storage
  aliases verified. Eight shared/startup tests and 13 inherited primitive/heap
  tests pass. [Bounded evidence](../artifacts/phase3/zone-heap-checkpoint.json).
  Tail fields are interface-only here; drawing still has its original strict guard.
- `9d1b567`: capability-gated staged browser startup; 37 isolated Node tests pass,
  including all prior 29 tests and eight preparation/Stop/reload cases. Both stages
  require confirmation without a Frame or input sequence change. Root reran the
  command and validated all 11 source bindings. This is component proof only.

- `ba53a4b`: original native map chronology / pre-THINGS and complete setup
  boundaries, four profiles exact; original six browser frames and all world
  outputs unchanged. Geometry has 25 completed outer operations, 4,924 headers
  and 4,126 owner marks. [Native validation](../tools/reference/phase3_zone_setup/validation.json).
  Later `1578f06` and atomic `60cd6f7` verify the Solidity setup/header assertions.
- `4d06c03`: native-only backing proof, 80 cases / 10,240 byte-knownness positions
  and 18 unchanged original negative-frac column draws across O0/O2/full sanitizers.
  Source-written header/resource bytes are distinguished from unknown pointers,
  padding and slack. Generation and fresh `--check` pass. [Validation](../test/fixtures/phase3_zone_backing/validation.json).
  Later `9c4ba50` passes all 111 owned renderer/resource/backing tests.
- `01417ad`: 150 original rocket-world tics / seven selected frames and exact
  pre/post-render worlds across four profiles. Observation-only nested timeline
  confirms actual radius damage to the player (requested 25 at tic 49), alongside
  flight, explosion, kill and lazy removal. [Native validation](../tools/reference/gameplay_projectile/validation.json).
  Probe scenario six and runner `53b5cd3` pass all 150 original projectile tics, seven frames and the final stored snapshot.

- `9c4ba50`: renderer/cache/backing and call-local loader/reader integration,
  111 owned tests pass. All source/dependency bindings reviewed; public Doom and
  GameplayProbe build passes. [Checkpoint](../artifacts/phase3/renderer-backing-checkpoint.json).
- `1578f06`: original map/blockmap/reject/THINGS/grouped-line allocations and
  persisted native zone aliases. Three exact header/owner/digest/setup tests pass,
  including all 210 actors and nine lights; measured full-test gas 921,597,231 at
  the historical one-billion limit. [Validation](../tools/reference/phase3_zone_setup/evm-validation.json).

## Current gas-budget decision and recovery

The user explicitly replaced the arbitrary one-billion cap with a configurable
local budget, default **10,000,000,000 gas**, on 2026-10-09. Source fidelity takes
precedence over that historical cap. `execution-budget.json` is the shared default;
`DOOM_GAS_LIMIT` overrides it and normalized child environments also set
`FOUNDRY_GAS_LIMIT`. Five Node/Python/shell parity/configuration tests pass. Real
launcher/probes confirm the new default; all verification consumers are being
updated consistently. Compiler settings, original semantics, code/memory limits
and every correctness gate are preserved. Stack/code-generation errors and
unknown-byte drawing guards are separate from gas exhaustion.
Core policy checkpoint `bb0c375` is committed: five default/override/invalid-input/
Node/Python/Bash/Zsh parity tests pass, and a TOML comparison proves only the gas
default changed. Consumers are committed in `f2402cd` and `82fea9d`; full inherited 10B acceptance
has not run.
Legacy JS checkpoint `f2402cd` converts eight benchmark/browser consumers;
syntax/configuration checks pass and deliberate low-gas rejections remain.
[Wiring evidence](../artifacts/phase3/execution-js-checkpoint.json). Their complete
inherited runtime gates are pending.
Python/Anvil checkpoint `82fea9d` converts all five launch/probe/Phase 0–2 runners.
Fresh current-helper launcher and limit probes pass at 10B, including budget+1
cases; child environments and source inventories bind both helpers/config.
[Evidence](../artifacts/phase3/execution-python-checkpoint.json). Original gate
counts, deliberate smaller gas probes and historical reports remain intact.

Production (`60cd6f7`) and the verified pending probe now call `DoomGame.initializeNative`
for original R_Init/R_InitSprites then G_InitNew/P_Setup in **one transaction**.
Resources decode once. Public preparation APIs have been removed from production;
old staged browser support is explicitly historical capability only. The new full
atomic native-header test passes with separately retained evidence; do not promote
the historical one-billion records to this new source snapshot.

The completed historical staged production run 44500 remains separate: 129 tics,
14 fields, six exact native frames, 17 rollback rejections and all 1,755 ordinary
resource runtimes verified. Actual resource preparation 577,921,129 gas; level
initialization 960,335,676; steps 309,135,111–312,202,597; rendered steps
719,412,460–781,641,380. Reports and original measurements are preserved under
`artifacts/local/gameplay-production-zone.*`. This two-transaction architecture
is superseded and is not final atomic acceptance.

Ownership: root owns shared budget loaders/default/Foundry/shell setup, atomic
Doom/DoomGame/probe and final gates; reference agent owns Python Anvil/probe/gate
consumer updates and the new atomic header test; interface agent owns legacy JS
benchmark/browser consumers; input agent owns browser/config budgets and atomic
production/MSIZE tooling. Atomic 35080 passes all four setup tests at 10B; the new
test uses 1,624,686,931 fixture-inclusive gas. Public code generation passes.
Production 93227 verifies one initialization at **1,621,868,997 actual gas** and
129 tics / 14 fields / six frames / 13 whole-storage rollback rejections. Chrome
72876 verifies all six native/receipt/Canvas frames, including old failing tic five.
Kernel 19797 verifies **nine scenarios / 2,355 tics / 31 frames / nine final stored
states**, including rocket blast damage/removal. These source-bound workstreams
are committed as production `60cd6f7`, kernel `53b5cd3` and Chrome `a88f285`; M2/M3 remain unaccepted.

MSIZE clone 41920 and cadence 74863 pass paired-clone gas and three-way storage/
field/native-pixel checks. Measured clone boundaries: atomic init 19,665,056 bytes;
steps 8,749,760–8,753,856; frames 11,918,816–11,956,800. These are literal clone
high-water values, not exact untouched-production peaks. Independent repeat 10416 also passes the complete 129-tic stream: 130 × 14
fields, command/sequence/cadence, seven Frame hashes and gas (static plus six live),
constructor/initialization gas, thirteen rejection errors/gas/storage rollback and
source/runtime identities equal. The optional palette writer changed only the
runner hash; both historical tool hashes remain explicit. Refreshed audit review,
separate integration commits and frozen inherited gates remain. No active compiler. Formatted-build runtime rechecks are in progress.

Next dependency order:

1. Atomic production interface/startup and header evidence are committed in
   `60cd6f7`; 58 atomic/header and 63 repeat-production source bindings were
   freshly checked, and targeted formatting plus runner syntax checks pass.
2. Nine-scenario kernel `53b5cd3`, real Chrome `a88f285` and memory/replay
   `c5a3069` checkpoints are committed. Historical measurements/tool hashes are
   preserved. Continue separate checkpoints for audit and final gates.
3. Refreshed source/function/domain audit is committed `6749dcd`; root reviewed
   function mapping and feature limits. Preserve unknown-byte guards, original algorithms and unsupported-domain declarations. Archive obsolete local
   diagnostic tooling outside normal source inventory rather than claiming it works.
4. Freeze all sources and run complete Phase 0/1/2 inherited gates, all Phase 3
   regression tests and format/source checks. No edits or commits during that run.
5. Refresh bounded usage JSON/CSV and assess every unchanged acceptance criterion.

No external blocker. Previous agents completed their work; no live agents are
reported. Root owns integration and final acceptance. Production/probe/browser/memory proof tooling is committed; refreshed audit and
final frozen inherited gates remain.
Anvil port 18579 is retained; the atomic browser deployment completed six tics.
The historical failed instance and one-billion measurements remain historical.

Compiler failures 80103/80877/31289 (map-loop liveness) and 12089 (tail-reader
liveness) were resolved by call-local MapLineWork/TailWork, without changing
compiler settings or original ordering. The earlier fixture MemoryOOG was resolved
by removing duplicate test-only resource decoding. These are separate from gas
exhaustion. Atomic setup 35080 now passes all four tests, preserving all prior
header/owner/actor/light assertions; full atomic fixture costs 1,624,686,931 gas.

At each verified integration checkpoint, update and commit this ledger with exact
implementation/integration/verification scope, evidence and code hashes, remaining
work and blockers. Acceptance criteria below are preserved; no unsupported pass
claim is implied by any partial or component result.

## Shared state and work order

The integrator reviews and freezes compilable gameplay types before parallel
movement, thinker, weapon, AI or world-action ports. Reference and input tooling
can proceed independently before this freeze. See `PHASE3-INTERFACES.md` for the
approved schema and ordering invariants. Existing renderer headers stay stable;
the render adapter projects authoritative gameplay actors, sectors and player
psprites into the existing renderer context.

1. Freeze full player/actor/thinker/world contexts and cross-module hooks.
2. Export complete original state/action, actor and weapon tables; port both RNG
   streams. Prove every table field against the original native data.
3. Port `p_maputl`, `p_map`, `p_sight`, actor lifecycle and player movement with
   ordered BLOCKMAP/REJECT access and original fixed-point semantics.
4. Integrate the live thinker list, storage round trips and keyboard commands.
5. In parallel after the freeze, port weapons, monster actions and sector
   specials using agreed callbacks; then integrate real state-action dispatch.
6. Connect gameplay state to full rendering and browser sequential transactions.
7. Run native state/frame comparisons, production EVM scenarios, browser frame
   readback, inherited gates and source-fidelity/feature-coverage audits.

Native fixtures compile the pinned original gameplay translation units and
actual action pointers. A movement-only stand-in or a simulated monster stub
cannot prove M3. Host adaptations and undefined C domains must be listed with
source spans and reproducibility evidence.

## Required acceptance evidence

| Requirement | Required evidence | Current state |
|---|---|---|
| Input commands | Whole original `G_BuildTiccmd` keyboard-profile comparison, held input/repeat/sequence tests | Whole keyboard module, 44 browser component tests and repeated 129-tic production path verified; actual atomic Chrome six-frame evidence committed. Frozen regression run pending. |
| M2 real-level movement | Per-tic original C vs Solidity positions, momentum, BAM angle, view height and RNG on E1M1 | 275 movement whole-world tics plus all 129 production keyboard tics match C, including forward/back/strafe/turn; independent replay exact. Final frozen gates pending. |
| M2 collision | Blocking actors/walls, sliding, steps/dropoffs and height constraints; original traversal/intercept order | Original collision/traversal module scope and nine atomic whole-world traces exact; documented geometry/undefined domains. Final frozen gates pending. |
| M2 use | Real-level use traces, edge handling, door/switch changes persisted across transactions | 375-tic door-use and 375-tic obstruction state/frame/persistence proofs exact; original held/release edge behavior in keyboard module and production. Final frozen gates pending. |
| M2 reproducible frames | Same command stream twice, exact indexed8 native frame comparison at selected tics, real Frame events | 31 native/kernel frames and nine final stored snapshots exact; two fresh 129-tic production streams match all fields, seven Frame hashes, cadence/gas and thirteen guards. Final frozen gates pending. |
| Live thinkers | Append/remove/stasis and same-tic spawn order, native actor/state and RNG traces | Original scheduling module and nine atomic stored traces exact; native physical lazy-free integration verified. Final frozen gates pending. |
| Weapons/shooting | All nine original weapon definitions/actions covered; ammo, refire, hitscan, projectiles and psprite traces | All nine definitions/actions controlled module proof; integrated pistol, combat and rocket-world flight/blast/kill/removal, production firing exact. Broader branches remain explicitly module-scoped; final gates pending. |
| Monster AI | Real state actions, sight/noise, chase/attack and RNG; feature matrix for all original actor families | All 64 active actions controlled module proof; integrated sight/chase/attack/RNG exact. 22-family source/action coverage matrix records uninstrumented integrated species attribution. Final gates pending. |
| Damage/lifecycle | Armor/powers, pain/death, drops, missiles, radius damage, pickup and removal traces | Combat 175 / damage 350 / death 350 / projectile 150 whole-world tics exact, armor/blast/kill/lazy removal and allocator integration verified. Final gates pending. |
| Doors/interactions | Doors, floors, ceilings, platforms, switches, lights, teleport and sector damage; per-special coverage | All world/special module scopes retained, explicit numeric-special matrix; door 375 / obstruction 375 whole-world persistence exact. Broader per-special branches remain module-scoped. Final gates pending. |
| Gameplay rendering | Runtime sector/side/actor/psprite state reaches renderer; exact native frames | 31 exact native/kernel frames, six production live frames and six real Chrome indexed/Canvas frames; historical DrawBounds resolved through original known physical backing. Final gates pending. |
| Production transport | Authenticated resources, authorized driver, consecutive input sequence, WS/receipt/Canvas pixel readback | All 1,755 ordinary authenticated resource runtimes, driver/sequence/rollback and actual Chrome WS/receipt fallback/Canvas verified. Final gates pending. |
| Inherited gates | Phase 0, Phase 1 and complete Phase 2 verification commands against the frozen final source | Pending final frozen complete Phase 0/1/2 run, including every Phase 3 Foundry test. |
| Fidelity and limits | Original function mapping, adaptation/undefined-domain audit, full feature coverage and measured gas/memory | 388-function mapping, 22-family/per-special/unsupported-domain audit committed 6749dcd; configurable 10B, actual gas and bounded clone memory committed c5a3069. Historical drift explicit; frozen regression proof pending. |
| Usage | Local JSON/CSV collection with phases/models/agents and missing-data diagnostics | Collector complete, phase/model/agent boundaries preserved; final JSON/CSV snapshot and missing-data diagnostics refresh pending. |

M2 and M3 remain unaccepted until these proofs cover the actual integrated
engine. Unit tests alone do not establish playable EVM gameplay. Multiplayer,
sound-device output, menus and intermission UI require explicit feature-matrix
status rather than an implied claim of complete original DOOM.

## Ownership

The integrator owns shared headers/hooks, `Doom.sol`, the gameplay/render/storage
adapter, acceptance runner and final audit. Agents receive non-overlapping
source/test/native-harness paths after the freeze. Shared interface changes
require a concrete integrator review before consumers are changed. No source
edits occur during the final frozen verification run.
