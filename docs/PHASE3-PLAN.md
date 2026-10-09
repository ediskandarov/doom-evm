# Phase 3 implementation and acceptance ledger

Phase 2's accepted static renderer and all inherited gates remain the baseline.
The Phase 3 goal begins at `2026-10-09T14:10:28Z`; local usage collection uses
that explicit boundary. Earlier abandoned input scaffolding was removed and
does not count as accepted Phase 3 implementation.

## Recovery checkpoint

Last reviewed checkpoint: `b2bb3b1`, original monster-action module. **Phase 3 is
active; M2 and M3 are unaccepted.** The production `Doom.sol` still exposes the
accepted Phase 2 static renderer. Gameplay modules have substantial isolated
proofs, but they are not yet connected to production transactions, storage or
browser controls. Do not infer engine acceptance from completed module ports.

`Implemented` means source exists; `integrated` means the stated consumer really
uses it; `verified` names the actual scope of executed evidence. Native-only or
mock-neighbor module proof does not imply whole-engine verification.

## Implementation and verification progress

| Workstream | Implementation | Integration | Verification and commit |
|---|---|---|---|
| Shared player/actor/thinker/world interfaces and heap | Base complete; approved persistence extensions are currently uncommitted | Used by all gameplay module proofs; production storage copy pending | Compiles; actor/thinker aliases survive pool growth. `d793fd1`; tag-only boss callbacks `0960141`. [Interface checkpoint](../artifacts/phase3/interface-freeze.json). |
| Original state/action, actor, weapon tables and RNG | Complete | Imported by gameplay modules | Every field of 967 states/137 actor types/9 weapons and both RNG streams matches native; O0/O2/sanitizers. `f1081fd`. [Foundation checkpoint](../artifacts/phase3/foundation-checkpoint.json). |
| Keyboard commands and browser sampler | Complete declared keyboard profile | Standalone helper and decoder tested; production browser/engine connection pending | 41,007 original-C cases, 14 Forge tests, five browser tests. `0a7d839`. [Input checkpoint](../artifacts/phase3/input-checkpoint.json). |
| Original-C full gameplay/frame oracle | Complete eight reference scenarios | Ready as EVM comparison oracle; no EVM conformance claim | 2,205 original tics and 24 live frames match O0/O2/ASan and alternate allocation fill. `6af2ec2`. [Native checkpoint](../artifacts/phase3/native-reference-checkpoint.json). |
| Collision, traversal and sight | All 40 active original functions implemented | Internal hooks and spatial links exercised with declared unit neighbors; actual gameplay integration pending | 4,310 geometry cases and 71 scenarios match C; three Forge tests pass. `be86b4b`. [Collision report](PHASE3-COLLISION.md). |
| Weapons, pickups and damage | Complete original p_pspr/p_inter functions | Real PSprite action transitions tested; line attacks/missiles/neighbor effects mocked in isolated proof | 72 weapon scenarios/11,520 tics and 6,025 interaction cases; 24 Forge tests pass. `e7d58a8`. [Combat report](PHASE3-COMBAT.md). |
| Live thinkers/ticker | All six active original functions implemented | List/ticker callbacks exercised; actual world and storage pending | Eight original scheduling snapshots, same-tic spawn/stasis/lazy removal/pause order; TickTest passes. `ba901c2`. [Tick report](PHASE3-TICK.md). |
| Monster AI/actions | All 64 active original definitions implemented | Ordered neighboring calls tested with explicit doubles; real EVM species/world effects pending | 1,137 native cases and 64 Forge tests pass. `b2bb3b1`. [AI matrix](PHASE3-AI.md). |
| Player movement, actor lifecycle and G_Game lifecycle | Source written; uncommitted | Original spatial helpers and frozen hooks wired in module tests | Native oracle reports 772 cases; Solidity verification requested, not yet accepted. Owned by `/root/p3_reference_audit`; [working report](PHASE3-LIFECYCLE.md). |
| Doors, floors, ceilings, platforms and lights | All five original source modules written; uncommitted | Paired with P_Spec helper APIs; engine dispatcher draft exists | Native 357 scenarios/78,699 snapshots; Solidity tests prepared but pending. `/root/p3_input` owns verification. Original uninitialized-field and manual-door/plat reinterpretation domains under audit. |
| Sector specials, switches, teleport and animations | All 23 active functions written; uncommitted | World-module dispatch written; persistent translations agreed | Native 416 helper cases; whole special-dispatch proof and Solidity verification pending. `/root/p3_interface_audit` owns verification. |
| P_Setup gameplay startup | Draft implemented; uncommitted | Real BLOCKMAP/REJECT, sector grouping and THINGS order connected to gameplay; not exercised yet | Pending startup/native state proof. Integrator owns `src/doom/p_setup.sol`. Existing disk loader reused with explicit attribution. |
| DoomGame state/action/render adapter | Draft implemented; uncommitted | All gameplay hooks and renderer projection written; no production caller yet | Pending compile, whole-tic comparison, persistent state round trips and pixel proof. Integrator owns `src/evm/DoomGame.sol`. |
| Production Doom adapter and browser gameplay | Pending | Existing static engine remains baseline | Pending driver/sequence/tic/storage/frame/Canvas gates. |
| Usage telemetry | Complete collector; active collection | Local Codex logs only, no engine dependency or services | 20 collector tests pass; historical Phase 0–2 totals remain stable. Phase 3 boundary `d47dd86`. Latest snapshots are ignored `artifacts/local/codex-usage/`. |

The executed mixed module batch was:

```sh
.toolchain/bin/forge test --match-path 'test/unit/{p_map,p_maputl,p_tick,GameHeap,g_game,p_info,m_random}.t.sol' --skip p_enemy.t.sol -vv
```

It passed 22 tests in seven suites. Combat and AI have separate recorded passing
commands. This is **not** a fresh complete inherited-gate run.

## Remaining work and current constraints

1. Verify and incrementally commit lifecycle and world workstreams; preserve their
   original callback ordering, special-number coverage and undefined-domain audit.
2. Compile and verify the new persistence interfaces. Original scratch globals,
   translation arrays, renderer wall/plane caches, fuzz/frame counters and screens[0]
   must survive transactions. Check aliases through a real storage round trip.
3. Validate original E1M1 startup and wire production tick/render/driver/sequence
   operations; connect browser keyboard state without host movement or rendering.
4. Compare identical native/EVM input streams, with matching render cadence,
   canonical world state and exact 64,000-byte selected frames. Cover real movement,
   blocking/sliding, pickup, firing, monster damage/death, doors and obstruction.
5. Measure production gas/memory and limits, verify transport/Canvas, audit the
   feature matrix, then run every inherited gate against frozen final sources.

There is no external blocker. The current dependencies are pending module tests,
startup/storage integration and whole-engine comparisons. Previous test-only
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
| M2 real-level movement | Per-tic original C vs Solidity positions, momentum, BAM angle, view height and RNG on E1M1 | Pending |
| M2 collision | Blocking actors/walls, sliding, steps/dropoffs and height constraints; original traversal/intercept order | Module evidence verified; real E1M1 EVM traces pending |
| M2 use | Real-level use traces, edge handling, door/switch changes persisted across transactions | Pending |
| M2 reproducible frames | Same command stream twice, exact indexed8 native frame comparison at selected tics, real Frame events | Pending |
| Live thinkers | Append/remove/stasis and same-tic spawn order, native actor/state and RNG traces | Scheduling module verified; full-world/storage traces pending |
| Weapons/shooting | All nine original weapon definitions/actions covered; ammo, refire, hitscan, projectiles and psprite traces | Module evidence verified; real projectile/damage/frame effects pending |
| Monster AI | Real state actions, sight/noise, chase/attack and RNG; feature matrix for all original actor families | Module evidence/matrix verified; EVM world effects pending |
| Damage/lifecycle | Armor/powers, pain/death, drops, missiles, radius damage, pickup and removal traces | Interaction module verified; lifecycle tests and integration pending |
| Doors/interactions | Doors, floors, ceilings, platforms, switches, lights, teleport and sector damage; per-special coverage | Implemented; native unit evidence partly available; EVM proof pending |
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
