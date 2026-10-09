# Phase 3 implementation and acceptance ledger

Phase 2's accepted static renderer and all inherited gates remain the baseline.
The Phase 3 goal begins at `2026-10-09T14:10:28Z`; local usage collection uses
that explicit boundary. Earlier abandoned input scaffolding was removed and
does not count as accepted Phase 3 implementation.

## Recovery checkpoint

Last implementation checkpoint: `b1c2735`, full original gameplay kernel integration.
Last native observation checkpoint: `7fc2cab`, exact post-render state extension.
Last audit checkpoint: `6302955`, original definition/feature inventory.
All completed module/kernel proofs below are committed. Production adapter and real gameplay browser tooling remain pending their separate checkpoint commits. **Phase 3 is
active; M2 and M3 are unaccepted.** Committed production `Doom.sol` remains the
accepted Phase 2 static renderer; its working-tree gameplay adapter is a draft.
Gameplay modules have substantial isolated proofs and the full public test-probe
graph now compiles, but production transactions and real browser gameplay remain
unverified. Do not infer engine acceptance from completed module ports.

`Implemented` means source exists; `integrated` means the stated consumer really
uses it; `verified` names the actual scope of executed evidence. Native-only or
mock-neighbor module proof does not imply whole-engine verification.

## Implementation and verification progress

| Workstream | Implementation | Integration | Verification and commit |
|---|---|---|---|
| Shared player/actor/thinker/world interfaces and heap | Base and approved persistence extensions complete | Used by all gameplay module proofs; synthetic storage copy verified; full-level production copy pending | Compiles; actor/thinker aliases survive pool growth. `d793fd1`; tag-only boss callbacks `0960141`. [Interface checkpoint](../artifacts/phase3/interface-freeze.json). |
| Original state/action, actor, weapon tables and RNG | Complete | Imported by gameplay modules | Every field of 967 states/137 actor types/9 weapons and both RNG streams matches native; O0/O2/sanitizers. `f1081fd`. [Foundation checkpoint](../artifacts/phase3/foundation-checkpoint.json). |
| Keyboard commands and browser sampler | Complete declared keyboard profile | Standalone helper/decoder and serialized browser lifecycle tested; real production browser connection pending | 41,007 original-C cases, 14 Forge tests, five browser tests. `0a7d839`; browser lifecycle `a67f435` adds a 29-test isolated gate. [Input checkpoint](../artifacts/phase3/input-checkpoint.json). |
| Original-C full gameplay/frame oracle | Complete eight reference scenarios | Ready as EVM comparison oracle; no EVM conformance claim | 2,205 original tics and 24 live frames match O0/O2/ASan and alternate allocation fill. `6af2ec2`. [Native checkpoint](../artifacts/phase3/native-reference-checkpoint.json). |
| Collision, traversal and sight | All 40 active original functions implemented | Internal hooks and spatial links exercised with declared unit neighbors; actual gameplay integration pending | 4,310 geometry cases and 71 scenarios match C; three Forge tests pass. `be86b4b`; fresh call-local traversal amendment `659ee64` passes unchanged goldens and full public-probe code generation. [Collision report](PHASE3-COLLISION.md). |
| Weapons, pickups and damage | Complete original p_pspr/p_inter functions | Real PSprite action transitions tested; line attacks/missiles/neighbor effects mocked in isolated proof | 72 weapon scenarios/11,520 tics and 6,025 interaction cases; 24 Forge tests pass. `e7d58a8`. [Combat report](PHASE3-COMBAT.md). |
| Live thinkers/ticker | All six active original functions implemented | List/ticker callbacks exercised; actual world and storage pending | Eight original scheduling snapshots, same-tic spawn/stasis/lazy removal/pause order; TickTest passes. `ba901c2`. [Tick report](PHASE3-TICK.md). |
| Monster AI/actions | All 64 active original definitions implemented | Ordered neighboring calls tested with explicit doubles; real EVM species/world effects pending | 1,137 native cases and 64 Forge tests pass. `b2bb3b1`. [AI matrix](PHASE3-AI.md). |
| Player movement, actor lifecycle and G_Game lifecycle | All 24 active definitions complete | Original spatial helpers and frozen hooks wired in module tests; production pending | 784 native cases across O0/O2/ASan/allocation-fill profiles; 24 Forge tests pass, including corrected positive aged-respawn case. `38a4d0e`. [Lifecycle report](PHASE3-LIFECYCLE.md), [validation](../test/fixtures/phase3_lifecycle/validation.json). |
| Doors, floors, ceilings, platforms and lights | All 33 active functions complete and committed | Paired with P_Spec APIs in module tests; production pending | `fdadcb5`: 359 native scenarios/79,021 snapshots, 2,160 plane cases and measured LP64 mover casts; all 28 Forge tests pass. [World report](PHASE3-WORLD-ACTIONS.md), [validation](../test/fixtures/phase3_world/validation.json). Undefined domains remain explicit. |
| Sector specials, switches, teleport and animations | All 23 active functions complete and committed | Real world-module dispatch tested on controlled maps; production pending | `fdadcb5`: 416 helper cases plus 1,007 dispatch scenarios/4,048 paired snapshots; all 25 Forge tests pass. [Specials report](PHASE3-WORLD-SPECIALS.md), [validation](../test/fixtures/phase3_specials/validation.json). |
| Original bounding-box helpers | Both functions complete and committed | Startup draft uses exact original else-if ordering | `bc74405`: 521 streams/8,299 points match O0/O2/full sanitizers; MBBoxTest passes. [Validation](../test/fixtures/phase3_bbox/validation.json). Full startup pending. |
| Gameplay persistence layout | Approved extensions implemented and committed | Real memory/storage/memory copy tested on synthetic nonempty actor/thinker/door state | `9bcc6af`: [storage checkpoint](../artifacts/phase3/storage-checkpoint.json). GameStorageTest passes (9,959,477 test gas), including map/resource/scratch aliases, renderer caches and framebuffer. Authenticated full-level round trip and production cost remain pending. |
| P_Setup gameplay startup | Implemented and committed | Real BLOCKMAP/REJECT, sector grouping and THINGS order connected to gameplay; ordinary authenticated EVM startup matches the original 102,468-byte DSG1 state; persisted tic/frame run underway | Startup logical-state proof passes through the test probe; 70 persisted idle tics and three native frames verified; full scenario set underway. Integrator owns `src/doom/p_setup.sol`. Existing disk loader reused with explicit attribution. |
| DoomGame state/action/render adapter | Implemented and committed | All gameplay hooks and renderer projection written; compiled draft production caller and test probe | Type-checks in module batch; full public probe graph compiles; all eight startup states, 2,205 full logical tics, 24 exact 64,000-byte frames and eight final post-render stored snapshots pass. `b1c2735`: [comparison](../tools/reference/gameplay/COMPARISON.md), [validation](../test/fixtures/gameplay_evm/validation.json). Integrator owns `src/evm/DoomGame.sol`. |
| Production Doom adapter and browser gameplay | Draft adapter implements startup and sequenced command/tic/frame paths; browser loop committed with isolated proof | Production artifact compiles; actual production keyboard/EVM/browser integration pending | `a67f435`: [browser checkpoint](../artifacts/phase3/browser-input-checkpoint.json). Browser 29 isolated tests pass; no real gameplay browser claim. Production compile and 129 keyboard tics/14 state fields/six exact frames/13 rejection-storage rollback checks pass. Static real Chrome/WS/receipt/Canvas gate passes after config-only repair. Gameplay Chrome passes four exact frames/14 fields then hits DrawBounds on tic five; diagnosis and final inherited gates pending. |
| Full native/EVM gameplay comparison | Test-only public probe and runner implemented and committed | Ordinary deployment, all 1,755 authenticated resource runtimes checked; real original hooks and stored state | Idle 70 and movement 275 per-tic DSG1 states plus three full native frames each pass. Movement final persistence comparison exposed PRE/POST-render ML_MAPPED observer mismatch; exact native post-render observer is being added. Full corrected run passes all 2,205 tics/24 frames/eight exact final post-render stored snapshots; `b1c2735`: [retained evidence](../test/fixtures/gameplay_evm/evidence.json) and all 55 consumed source hashes verified. |
| Resource initializer integration amendment | Complete and committed | Complete public test-probe graph compiles | `abfb38c`: all 20 inherited RData tests pass, including all native lookup/sprite/map/composite fields. [Checkpoint](../artifacts/phase3/resource-init-checkpoint.json). Final inherited gate remains pending. |
| Original feature/function audit | 287 original definitions inventoried with spans/body hashes and port mappings | Audit-time source snapshot; refresh on final freeze | `6302955`: [feature matrix](PHASE3-FEATURE-MATRIX.md), [JSON inventory](../artifacts/phase3/feature-matrix.json). Evidence scope and unsupported/undefined domains explicit; no new runtime acceptance claim. |
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

1. Verify original E1M1 startup and the complete adapter; module checkpoints are
   committed. World movers and special dispatch share imports and a test fixture
   base, so their verified integration is atomic in `fdadcb5`. Lifecycle, interfaces
   and bbox remain separate commits; unverified startup/adapter code is excluded.
2. Verify authenticated full-level persistence. Original scratch globals,
   translation arrays, renderer wall/plane caches, fuzz/frame counters and screens[0]
   must survive transactions. Check aliases through a real storage round trip.
3. Validate original E1M1 startup and wire production tick/render/driver/sequence
   operations; connect browser keyboard state without host movement or rendering.
4. Compare identical native/EVM input streams, with matching render cadence,
   canonical world state and exact 64,000-byte selected frames. Cover real movement,
   blocking/sliding, pickup, firing, monster damage/death, doors and obstruction.
5. Measure production gas/memory and limits, verify transport/Canvas, audit the
   feature matrix, then run every inherited gate against frozen final sources.

There is no external blocker. The current blocker is an actual production DrawBounds revert in the new
six-tic all-render Chrome profile; the native profile passes four compiler/fill
profiles. Commands 1–4 match all frame bytes and 14 player/status fields. Tic 5
(mask 128, sequence 7) reverts at 538,537,735 gas, so this is not the gas cap.
Failed transaction: `0xd28123618d70997eb485b1f4bce9126b6567a8ec064ab6542506f550e4caa677`;
selector `0x5b9a48fe` is DrawBounds(). Contract storage remains at inputSeq 6 /
gametic 4. Report: `artifacts/local/phase3-gameplay-browser.json`. The reference
agent owns a test-only diagnostic source clone, the interface agent reviews
original drawing/clipping logic, and root owns any production fix. No guards or
compiler limits will be weakened to pass the profile. The production adapter
stays uncommitted. Further dependencies are repeated streams, actual memory
measurements, final source audit and frozen inherited gates. The full probe compiles after a test-only immutable
scenario reread, a verified resource patch field-assignment amendment (20 RData tests pass,
`abfb38c`), and committed call-local traversal work. No compiler settings or limits
changed. The loopback Anvil sandbox retry was approved. Startup matches original C
byte-for-byte after ordinary deployment and exact verification of all 1,755
resource runtimes. The subsequent idle run verifies 70 full logical tic states, three selected
64,000-byte frames and final stored snapshot exactly. Reset gas is 761,217,276;
five-tic test batches use 251,505,408–680,980,862 gas, including observation costs.
This proves only the idle probe profile; all eight scenarios are now executing. The ignored report is `artifacts/local/gameplay-evm.json`
(startup-only), plus `artifacts/local/gameplay-idle.json` and its compressed
state stream. Both have `completeNativeScenarioSet=false`. The first all-scenario run additionally
passed movement 275 full states/three frames, then stopped at a final observer
boundary error: the native final snapshot is before rendering while stored EVM
state is after rendering (line 543 ML_MAPPED). No engine correction is indicated.
A separate exact C post-render observer will replace that invalid comparison;
this failure is retained, not masked or counted as a passed final snapshot.

The separate native post-render extension (`7fc2cab`) verifies all 24 new records
across four profiles and every existing pre-state/diagnostic/event/summary/frame
byte unchanged. Its executed run was generation; `--check` is documented as
reproduction, not an executed claim. The corrected complete EVM run now passes
all eight startups/2,205 tics/24 frames/eight exact final stored states. Production
keyboard verification separately passes 129 tics, 14 exported fields, six exact
frames and 13 rejections with complete storage-root rollback. Neither closes
M2/M3 before real gameplay browser, repeated streams, limits and frozen inherited gates.

The kernel and its observer/runner/evidence are committed atomically in `b1c2735`.
The production adapter remains a separate uncommitted verified workstream until
its retained production evidence is reviewed. Real static Chrome transport now
passes against the production candidate, including exact original pixels and
all Canvas bytes. The earlier missing config metadata was repaired without
changing engine state or code; real gameplay Chrome verification is next. The reference agent now owns a
test-only public gameplay probe/canonical serializer and native/EVM runner; the input
agent owns browser wiring; the interface agent owns the feature/fidelity matrix.
No completed module ports are being restarted. Previous test-only
via-IR stack pressure and one-billion-gas batching failures were resolved with
scratch contexts and smaller test bands without dropping cases or changing engine
algorithms/resource limits. Compiler runs are serialized across agents.

At each verified integration checkpoint, update this ledger with implementation,
integration and verification scope, evidence, code commit hashes, remaining work
and current blockers; commit the ledger separately. Keep acceptance criteria below
unchanged and require their actual evidence before marking them passed.

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
| Input commands | Whole original `G_BuildTiccmd` keyboard-profile comparison, held input/repeat/sequence tests | Module evidence verified; production integration pending |
| M2 real-level movement | Per-tic original C vs Solidity positions, momentum, BAM angle, view height and RNG on E1M1 | 275 movement probe tics/full states exact; production keyboard path and full gate pending |
| M2 collision | Blocking actors/walls, sliding, steps/dropoffs and height constraints; original traversal/intercept order | Module evidence verified; real E1M1 EVM traces pending |
| M2 use | Real-level use traces, edge handling, door/switch changes persisted across transactions | Pending |
| M2 reproducible frames | Same command stream twice, exact indexed8 native frame comparison at selected tics, real Frame events | Pending |
| Live thinkers | Append/remove/stasis and same-tic spawn order, native actor/state and RNG traces | Scheduling module verified; full-world/storage traces pending |
| Weapons/shooting | All nine original weapon definitions/actions covered; ammo, refire, hitscan, projectiles and psprite traces | Module evidence verified; real projectile/damage/frame effects pending |
| Monster AI | Real state actions, sight/noise, chase/attack and RNG; feature matrix for all original actor families | Module evidence/matrix verified; EVM world effects pending |
| Damage/lifecycle | Armor/powers, pain/death, drops, missiles, radius damage, pickup and removal traces | Interaction and lifecycle modules verified; integrated traces pending |
| Doors/interactions | Doors, floors, ceilings, platforms, switches, lights, teleport and sector damage; per-special coverage | Native and EVM module/dispatch proofs verified; real-level persistence pending |
| Gameplay rendering | Runtime sector/side/actor/psprite state reaches renderer; exact native frames | Adapter draft written; comparison pending |
| Production transport | Authenticated resources, authorized driver, consecutive input sequence, WS/receipt/Canvas pixel readback | Pending |
| Inherited gates | Phase 0, Phase 1 and complete Phase 2 verification commands against the frozen final source | Pending final run |
| Fidelity and limits | Original function mapping, adaptation/undefined-domain audit, full feature coverage and measured gas/memory | Pending |
| Usage | Local JSON/CSV collection with phases/models/agents and missing-data diagnostics | Active |

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
