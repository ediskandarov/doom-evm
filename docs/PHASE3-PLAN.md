# Phase 3 implementation and acceptance ledger

**M2 and M3 passed the original acceptance gates.** Engineering acceptance was
recorded at `2026-10-09T21:13:08Z` in [the checked certificate](../artifacts/phase3/acceptance.json).
This is playable original-source single-player medium retail E1M1 inside local
ordinary EVM execution. Full original DOOM, arbitrary maps/modes and complete
per-branch/per-species world coverage are not claimed; see the explicit
[feature/domain matrix](PHASE3-FEATURE-MATRIX.md).

## Recovery checkpoint

Functional production adapter/startup: `60cd6f7`; atomic public test-probe:
`53b5cd3`; final engine formatting: `5a11e39`. The complete engineering source
freeze was `9279bf9`; engine sources/settings have not changed since that run.
All tested source hashes and final build provenance are in the certificate.
Shared game-state interfaces were frozen in `d793fd1`/`0960141` before gameplay
workstreams; native allocation schema extensions are `ab316f8`.

Final verification checkpoints:

- `2810c8b`: complete frozen inherited/native regressions. All 24 Phase 2 commands
  plus documentation, all 12 Phase 0/13 Phase 1 gates,403 Foundry tests (40 suites,
  zero failures/skips, fuzz0x44),33 Phase 3 native/local commands,53 Node and20
  collector tests PASS. HEAD/source/pristine original-submodule guards PASS.
- `3242865`: all nine kernel scenarios /2,355 original logical tics /31 exact
  64,000-byte frames /nine exact final stored snapshots. GameplayProbe artifact
  remains identical after inherited builds; all 1,755 ordinary resource runtimes
  verified. Includes150 projectile tics/seven frames/blast/kill/lazy removal.
- `a4f53b5`: final renderer-emitted production artifact, actual ordinary CREATE,
  atomic startup,129 keyboard tics /130×14 fields /six live native Frames plus
  static pre-start Frame /thirteen whole-storage rollback guards PASS.
- `949e594`: second fresh independent complete production stream; every field,
  command/sequence/cadence,seven Frame records, constructor/init/receipt gas and
  thirteen rejection selector/gas/rollback records equal.
- `ce7f0de`: actual Chrome all-six-native-indexed/receipt/Canvas-RGBA frames and84
  exported field comparisons PASS; Start/Resume/DOM keyboard, blur stop,
  deduplication and controlled receipt fallback verified.
- `c672568`: all four native startup/header/owner/actor/light/map-slot tests PASS
  inside full403-test run; all 54 compiled source keccak bindings checked.
- `ffb147e`: final production artifact vs two ordinary source-map marker clones,
  six all-render tics and six production-cadence tics (five no-render) PASS for
  every storage/field/native Frame and paired-clone gas comparison. Rebuilding
  the isolated clone leaves production artifact identical.

`Implemented` means source exists; `integrated` means actual consumers use it;
`verified` always states the executed scope. Native/module proofs using controlled
neighbors do not imply arbitrary integrated-world branch coverage.

## Implementation and verification status

| Workstream | Implemented / integrated | Verified evidence |
|---|---|---|
| Interfaces, stable IDs, heap and storage | Complete; real persistent actors/thinkers/world/resources/zone aliases | Shared freeze,21 allocation/schema tests; full403-test regression, nine final native stored snapshots and independent public replay |
| State/actor/weapon tables and RNG | Complete; actual dispatch consumes original tables | Every field of 967 states,137 actor/effect/item definitions,nine weapons and both RNG streams; foundation proof f1081fd plus frozen regressions |
| Keyboard and client lifecycle | Complete; original held mapping, serialized atomic startup and transactions | Original 41,007 commands, module/Node regressions,129-tic public path and actual Chrome |
| Collision/traversal/sight | Complete; real hooks/BLOCKMAP/REJECT/spatial lists |4,310 geometry cases,71 scenarios and nine exact whole-world streams; explicit domains |
| Weapons, damage, pickups | Complete; real actions/hitscan/projectiles/psprites |72 weapon scenarios/11,520 tics,6,025 interaction cases; full pistol/combat/damage/death/rocket and public firing |
| Thinkers, movement and lifecycle | Complete; original ordered ticker, spatial links, stable IDs and lazy physical free | Scheduling/lifecycle native modules, all current Foundry tests, nine real-world streams |
| Monster AI | All 64 active functions integrated into original dispatch/hooks |1,137 controlled native cases; actual whole-world sight/chase/attack/RNG;22-family source/action matrix. Per-species integrated entry attribution remains uninstrumented |
| World movers/specials | All 33 mover/light and 23 special/switch/teleport functions integrated |359 world scenarios/79,021 snapshots/2,160 plane cases;416 helper and1,007 dispatch scenarios/4,048 snapshots; original special-number matrix;375-tic real door and obstruction streams |
| Original startup/allocator/cache/backing | Complete; one atomic resource+level call, source-driven allocations and known-byte drawing | Native four-profile lifecycle/header/owner proofs, all setup assertions, full kernel/public/browser. No runtime allocation tape, clamp, invented pointers/padding or removed guards |
| Production gameplay/render/transport | Complete; driver/sequence/input validation, step/stepAndRender, storage, one Frame per rendered success | Final-artifact public/repeat/Chrome evidence above; accepted pre-start static renderer and all inherited gates preserved |
| Source/feature/domain audit | Complete 388-definition mapping,238 active core definitions (231 named,7 delegated),22 families | Original spans/body hashes, current tested bindings, per-special and unsupported-domain declarations; checked acceptance record |
| Local usage collector | Complete and separate from engine; sessions/models/agents/phases, cumulative deduplication, JSON/CSV |20 tests; historical Phase0/1/2 totals stable; explicit Phase3 engineering closure and aggregate-only snapshot, no transcript/service ingestion |

## Execution policy and actual measurements

Default local budget is **10,000,000,000 gas**, shared by
`execution-budget.json`, Anvil/explicit transactions/harnesses/gates.
`DOOM_GAS_LIMIT` overrides it; child environments normalize `FOUNDRY_GAS_LIMIT`.
Source `scripts/env.sh` for direct Forge policy propagation. Budget is independent
of economic efficiency. Production performs original renderer resource preparation
and level/player startup in **one initializeGame transaction**; no staged public
API or native-algorithm split remains. Compiler stays solc 0.8.37/viaIR/optimizer 200/
Cancun; code policy and 1 GiB memory setting are unchanged.

| Current actual ordinary transaction | Gas |
|---|---:|
| Atomic initializeGame |1,621,885,757|
| No-render tic |309,171,400–312,238,893|
| Selected live Frame tic |719,455,170–781,684,253|

Literal measured clone engine-boundary high-water: init19,665,056B;
static8,841,664B; no-render8,749,760–8,753,856B;
liveFrames11,918,816–11,956,800B. These exclude later observer encoding/separate
call frames and are **not exact untouched-production peaks**.

The final renderer helper's three-root build emits 502,443-byte Doom runtime.
Full-project build emits 503,731 bytes from identical consumed sources/settings;
both complete gameplay streams are retained. Final acceptance binds the former
artifact and its exact command/hashes. Never substitute artifact or receipt
identity merely because source/settings match.

## Historical evidence and resolved failures

All earlier records keep their original hashes/scopes/gas; none was relabeled.

- `b1c2735` / `7fc2cab`: original eight-scenario2,205-tic/24-frame baseline and
  independent post-render observer fix. No engine pixel/logic change.
- Historical public adapter before physical allocator: init740,635,413 gas.
  Historical staged 1B run: prepare577,921,129/init960,335,676 gas;129 tics,
  six frames and17 rejections. Superseded staging is not current acceptance.
- `d9ca352`: source-derived renderer allocation startup6,498 calls/4,913 headers/
 4,126 owners; replay344,974,734 fixture-stage gas, not production cost.
  `1578f06` full setup fixture921,597,231 gas under historical 1B. Current atomic
  fixture1,624,686,931 gas remains separate from ordinary transaction cost.
- First atomic production:1,621,868,997 init gas and 502,589-byte runtime.
  Formatted full-project and final renderer-context init:1,621,885,757 gas.
  Distinct retained source/build/receipt identities remain explicit.
- Historical Chrome tic 5 DrawBounds at 538,537,735 gas, tx
  `0xd28123618d70997eb485b1f4bce9126b6567a8ec064ab6542506f550e4caa677`.
  Four native profiles reproduce negative-frac access to the next source-written
  zone header. Generic known physical backing resolves it; no asset/pixel special
  case or math clamp. [Retained cause](../artifacts/phase3/historical-draw-diagnosis.json).
- Map-loop/tail-reader compile liveness resolved with call-local working structs;
  compiler settings/algorithms unchanged. Old fixture MemoryOOG arose from duplicate
  test-only resource decoding and was corrected without weakening assertions.
  Stack/code-generation, memory knownness and gas exhaustion remain distinct.
- First final inherited run stopped at unchanged formatting gate. `5a11e39`
  formatting preserves every non-brace token; all403 tests pass.497.56s dependency
  build justified timeout headroom only (`bcbe46a`), not weaker correctness gates.
- Concurrent measurement receipt timeout after tic 2 has no retained pending hash/
  nonce; sender collision is suspected, not proved. Empty pool/equal nonces were
  observed, and sequential fresh replay passes. No revert/gas-exhaustion evidence.
  Forced build later cleaned the ignored clone; ENOENT preflight was resolved by
  isolated rebuild. Neither failure is falsely recorded as a passed measurement.

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

The requirement and required-evidence columns below are unchanged. Current status
is supported by the checked certificate and linked proof scopes above.

| Requirement | Required evidence | Current state |
|---|---|---|
| Input commands | Whole original `G_BuildTiccmd` keyboard-profile comparison, held input/repeat/sequence tests | **Verified** — Whole original keyboard profile, held/repeat/sequence and actual browser command delivery. |
| M2 real-level movement | Per-tic original C vs Solidity positions, momentum, BAM angle, view height and RNG on E1M1 | **Verified** — 275 movement whole-world tics plus complete129 keyboard tics; original positions/momentum/BAM/view/RNG and fresh independent replay. |
| M2 collision | Blocking actors/walls, sliding, steps/dropoffs and height constraints; original traversal/intercept order | **Verified** — All original collision/traversal module fixtures and nine integrated E1M1 traces; blocking/sliding/steps/height/order domains remain explicit. |
| M2 use | Real-level use traces, edge handling, door/switch changes persisted across transactions | **Verified** — 375-tic door-use and375-tic obstruction persistence plus keyboard held/release edge and transport. |
| M2 reproducible frames | Same command stream twice, exact indexed8 native frame comparison at selected tics, real Frame events | **Verified** — 31 exact native kernel frames; two independent complete129-tic production streams with identical seven Frame records/commands/gas. |
| Live thinkers | Append/remove/stasis and same-tic spawn order, native actor/state and RNG traces | **Verified** — Original scheduling/lazy-free module scope and nine whole-world persistent traces with source-derived physical allocator. |
| Weapons/shooting | All nine original weapon definitions/actions covered; ammo, refire, hitscan, projectiles and psprite traces | **Verified** — All nine weapon definitions/actions controlled module proof; integrated pistol/combat/rocket flight/blast/kill/removal and real production firing. |
| Monster AI | Real state actions, sight/noise, chase/attack and RNG; feature matrix for all original actor families | **Verified** — All 64 actions controlled original-C proof, integrated sight/chase/attack/RNG; explicit22-family state/action matrix. Integrated per-species attribution is uninstrumented. |
| Damage/lifecycle | Armor/powers, pain/death, drops, missiles, radius damage, pickup and removal traces | **Verified** — Combat175/damage350/death350/projectile150 world traces and controlled armor/powers/pickup/missile/drop/removal branches. |
| Doors/interactions | Doors, floors, ceilings, platforms, switches, lights, teleport and sector damage; per-special coverage | **Verified** — All-world/special controlled module scopes and explicit numeric-special matrix; full real door/obstruction stored world traces. |
| Gameplay rendering | Runtime sector/side/actor/psprite state reaches renderer; exact native frames | **Verified** — Runtime world/actor/psprite state rendered inside ordinary EVM, exact native indexed8 and Canvas comparisons. Generic known physical backing resolves historical overread. |
| Production transport | Authenticated resources, authorized driver, consecutive input sequence, WS/receipt/Canvas pixel readback | **Verified** — All1755 ordinary authenticated runtimes, driver/consecutive sequence/input guards, whole-storage rollback, actual WS/receipt fallback/Canvas. |
| Inherited gates | Phase 0, Phase 1 and complete Phase 2 verification commands against the frozen final source | **Verified** — All 24 Phase 2 commands plus documentation, all 12 Phase 0/13 Phase 1 gates,403 Foundry tests,33 Phase 3 native/local commands. |
| Fidelity and limits | Original function mapping, adaptation/undefined-domain audit, full feature coverage and measured gas/memory | **Verified** — 388-definition source mapping,22-family/per-special/unsupported-domain audit, actual configurable10B gas and literal clone boundary memory. Compiler settings preserved. |
| Usage | Local JSON/CSV collection with phases/models/agents and missing-data diagnostics | **Verified** — Local collector20 tests, historic Phase0/1 recovery and phase/model/session/agent aggregates; no transcripts/services. Snapshot excludes unflushed response and late publication bookkeeping. |

M2/M3 acceptance applies to the actual integrated engine within its documented
profile, with preserved inherited gates. No complete original DOOM/playthrough,
arbitrary-map, multiplayer, sound-device, menu/intermission or all-branch claim.

## Remaining work and blockers

Engineering implementation/integration/verification is complete; no blockers or
active agents/compiler/verification jobs. The shared local Anvil18579 is retained
for interactive gameplay. Aggregate-only usage snapshot and explicit engineering closure are committed
separately in `a711398`; historical Phase 0/1/2 totals remain stable. Final acceptance/report/audit publication is committed in `e30f522` and
published to origin/main. No engineering or publication blockers remain. Do not restart
completed ports. A future phase must retain every existing correctness gate and
add its own explicit usage boundary.

## Ownership

The integrator owns shared interfaces, adapter, integration, gate runner and
acceptance. Non-overlapping gameplay workstreams used frozen interfaces. Original
submodule remains pristine at a77dfb96cb91780ca334d0d4cfd86957558007e0.

## Publication checkpoint

`e30f522` publishes the checked M2/M3 certificate, report, current source audit,
port mapping and project instructions. `a711398` publishes aggregate-only usage
JSON/CSV and explicit engineering closure. Repository push is verified against
origin/main; final documentation handoff records the ready local browser config.
All requested implementation, integration, verification and telemetry work is
complete. Engine sources remain identical to the frozen accepted hashes.

## Final goal accounting

Goal completion is recorded at2026-10-09T21:31:33Z after clean2696ff7 publication.
Separate tool accounting:6,818,723 tokens /26,155 seconds, never summed with
response usage. The actual goal closure and earlier engineering-acceptance
marker are both preserved in tools/usage/phases.json. Completion JSON/CSV are
separate from the preserved engineering snapshot; all20 collector tests pass.
No engine, compiler setting, correctness gate or acceptance scope changed.
