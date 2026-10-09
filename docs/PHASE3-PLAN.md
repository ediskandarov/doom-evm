# Phase 3 implementation and acceptance ledger

Phase 2's accepted static renderer and all inherited gates remain the baseline.
The Phase 3 goal begins at `2026-10-09T14:10:28Z`; local usage collection uses
that explicit boundary. Earlier abandoned input scaffolding was removed and
does not count as accepted Phase 3 implementation.

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
| Input commands | Whole original `G_BuildTiccmd` keyboard-profile comparison, held input/repeat/sequence tests | In progress |
| M2 real-level movement | Per-tic original C vs Solidity positions, momentum, BAM angle, view height and RNG on E1M1 | Pending |
| M2 collision | Blocking actors/walls, sliding, steps/dropoffs and height constraints; original traversal/intercept order | Pending |
| M2 use | Real-level use traces, edge handling, door/switch changes persisted across transactions | Pending |
| M2 reproducible frames | Same command stream twice, exact indexed8 native frame comparison at selected tics, real Frame events | Pending |
| Live thinkers | Append/remove/stasis and same-tic spawn order, native actor/state and RNG traces | Pending |
| Weapons/shooting | All nine original weapon definitions/actions covered; ammo, refire, hitscan, projectiles and psprite traces | Pending |
| Monster AI | Real state actions, sight/noise, chase/attack and RNG; feature matrix for all original actor families | Pending |
| Damage/lifecycle | Armor/powers, pain/death, drops, missiles, radius damage, pickup and removal traces | Pending |
| Doors/interactions | Doors, floors, ceilings, platforms, switches, lights, teleport and sector damage; per-special coverage | Pending |
| Gameplay rendering | Runtime sector/side/actor/psprite state reaches renderer; exact native frames | Pending |
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
