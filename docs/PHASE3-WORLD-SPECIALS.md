# Phase 3 world special dispatch, animation, switches and teleport

All **23 active original functions** in `p_spec.c` (18), `p_switch.c` (4) and `p_telept.c` (1) are implemented and verified for the declared isolated native profiles, pinned at `a77dfb96cb91780ca334d0d4cfd86957558007e0`. This document does not establish M2/M3 acceptance or complete original DOOM coverage.

| Module | Original function coverage |
|---|---|
| `p_spec.sol` | `P_InitPicAnims`; `getSide`, `getSector`, `twoSided`, `getNextSector`; all seven original surrounding-height/tag/light helpers; `P_CrossSpecialLine`, `P_ShootSpecialLine`, `P_PlayerInSpecialSector`, `P_UpdateSpecials`, `EV_DoDonut`, `P_SpawnSpecials` |
| `p_switch.sol` | `P_InitSwitchList`, `P_StartButton`, `P_ChangeSwitchTexture`, `P_UseSpecialLine` |
| `p_telept.sol` | `EV_Teleport` |

`P_FindSectorFromTag` is an explicit adapter for original boss-action synthetic linedefs: the original helpers read only the linedef's tag. It shares the original linear ascending-sector search with `P_FindSectorFromLineTag`. No fake real-map line is created. `getSide`/`getSector` use sector-relative line ordinals; `getNextSector` uses a global linedef ID. `twoSided` returns original `flags & 4`, rather than a normalized boolean.

## Native proofs and branch matrix

```sh
python3 tools/reference/phase3_specials/generate_dispatch.py --check
python3 tools/reference/phase3_specials/reference.py --check
python3 tools/reference/phase3_specials/dispatch.py --check
.toolchain/bin/forge test --match-path test/unit/WorldSpecials.t.sol -vv
```

The dispatch generator mechanically adapts original main-switch case bodies and verifies them directly against the tested Solidity, normalizing whitespace and formatter-added single-call braces. Duplicate generated snippets are not needed. `dispatch-matrix.json` records **72 cross**, **63 use** and **3 shoot** special numbers and original body hashes. Guards are separately source reviewed: excluded projectile types, monster-only activation, manual secret-door restriction, front-side use, the original otherwise inactive special124 backside permission, and monster-only teleport behavior. The use handler retains original `true` results for unsupported front-side player specials; crossing and shooting retain no-op defaults.

The first native proof mechanically extracts **18 unchanged original functions**, plus the original 22 animation and 40 switch definitions. Its **416 cases** cover neighboring sector helpers and signed sentinels, the original first20 eligible higher-floor limit, switch texture ordering, repeat buttons, animation and switch initialization, missing animation starts, timer/scroll/button updates, hazard/power/RNG/secret/exit behavior and teleport marker ordering. The synthetic resource names are well formed logical fixtures, not a host gameplay implementation or real WAD substitute. Damage, fog spawning and teleport movement are explicit recorded higher-module mocks; the original functions' call arguments/order and resulting selected state are compared.

The second proof drives all original numeric special switch branches into the **actual complete original** door/floor/ceiling/plat/light units and original thinker list functions. It has **1,007 scenarios and 4,048 paired snapshots**, including player/monster/projectile guards, both crossing/use sides, missing/present keycards, direct donut creation and every sector-spawn special0..17. The native world state includes ordered typed thinkers, payloads, registries, sector mutations, callback count/hash and RNG. A second snapshot captures switch textures, buttons, scrolling, secrets and exit state. Unknown specials and the otherwise inactive124 use path are included. This dispatch profile contains no teleport markers; successful teleport sequencing is covered by the first proof, while actual collision/fog mechanics remain whole-engine integration requirements.

Both proofs are byte-exact across **O0, O2 and full ASan/UBSan**, with pristine checkout/compiler checks and source/extraction/harness hashes. Dispatch uses the shared synthetic world fixture and original five world translation units; the only geometry callback is the declared obstruction profile. Native raw snapshots are compressed for diagnosis and never used as EVM gameplay inputs. Golden hashes are computed from C observations, never EVM output.

EVM checks use corresponding shared schemas and recorded boundary mocks for the first proof. The actual-dispatch checks reuse `WorldFixtureBase`'s canonical world serializer. Fixture-only initialization masks are explicit `WorldWords` metadata, separate from actual GameState gameaction/gamestate. The special14 regression identified and corrected a serializer mask collision; the production door constructor was already equivalent to C and did not change.

All **25 WorldSpecials tests pass**, including all416 selected-state cases and all1,007 dispatch cases/4,048 paired world/overlay snapshots. The integrator's final command was:

```sh
.toolchain/bin/forge test --match-contract 'WorldActionsTest|WorldSpecials_Test|MBBoxTest|GameStorageTest' -vv
```

Terminal session93349 exited zero with **55 passing tests, zero failures, four suites**, including all28 world-action tests. The largest WorldSpecials test used 771,444,952 gas for its full player-sector fixture batch; that is aggregate test/setup/serialization cost, not a production per-tic/frame measurement. `test/fixtures/phase3_specials/validation.json` records commands, source/function coverage, fixture/dependency hashes and the integrator-reported terminal evidence. No raw console-log archive is claimed.

Passing these fixtures proves the declared module profiles and does not replace real-level, persisted-state and framebuffer acceptance.

## Preserved behavior and integration requirements

- All 22 animation definitions and 40 paired switch definitions retain original order and names. Original retail mode selects episode1 switches; only registered selects episode2 and commercial selects episode3.
- Animation frame calculation keeps the absolute `i` term: `basepic + ((leveltime / speed + i) % numpics)`. It is not normalized to `i - basepic`.
- Texture and flat translations are persistent `GameState` arrays. `P_InitPicAnims` aliases the original initialized resource arrays; the adapter must restore those exact aliases before every tic and render, then persist mutated mappings. `P_UpdateSpecials` executes before the original ticker increments leveltime.
- One-shot switches clear their line special before looking up/changing texture. Matching scans pairs in original order, checking top, then middle, then bottom for each pair. Repeat button registration is first-free and does not replace an already pressed button on the same line.
- Button expiration restores the original texture and clears the full original record. Null pointer fields use the frozen `0xffffffff` adapter representation.
- Neighbor traversal retains sector line order and original initial sentinels: highest floor starts at -500 units, highest ceiling at zero and lowest ceiling at INT_MAX. Next-highest-floor stops at the first20 eligible heights, matching the original warning/break behavior.
- Donut creation preserves the original `(!flags & ML_TWOSIDED)` expression's always-false result, then uses the original backsector rather than substituting a geometrically improved neighbor. Ring and hole thinkers append in original order.
- Hazard checks preserve short-circuit RNG calls: protected super slime/strobe performs its random check even on non-damage tics. Secret sectors clear once. Exit-super-damage clears godmode before damage and checks current health after the callback.
- Teleport rejects missiles and backside1, searches tagged sectors ascending and live active mobj thinkers in list order, stops immediately if the first selected destination fails, adjusts floor/view height, spawns source/destination fog in order, sets player reactiontime18, then resets angle/momentum.
- `G_ExitLevel`/`G_SecretExitLevel` update original gameaction/secret state. Intermission/finale/next-map UI is not implemented by these modules and requires an explicit feature-matrix entry.

## Declared domains and omissions

The local single-player CLI profile supplies no `-avg` or `-timer` arguments; `P_SpawnSpecials` consequently resets levelTimer false. Original `P_UpdateSpecials` timer behavior remains implemented and has native fixtures. Original disabled sliding-door functions remain disabled.

The shared native mover fixture declares a **zero allocator profile**. Original timed-door and stair routines leave some fields uninitialized; the fixture observes zero bytes and records this limitation. These tests do not establish portable ISO-C semantics for arbitrary fresh allocation contents. Whole-world acceptance must use the original zone allocator and audit which initialized fields affect the selected gameplay scenarios.

Malformed donut topology that would dereference NULL, more than64 scrolling lines, invalid animation cycles, missing required switch textures and exhausted16 button slots fail explicitly. These are original error/undefined domains, not additional rules applied to valid source inputs. Audio presentation calls are no-ops; weapon/monster sound propagation remains the gameplay `P_NoiseAlert` path.

Remaining acceptance work: full real-level initialization and storage persistence, integration with actual collision/damage/actor lifecycle, deterministic input/tic traces, frame sequences, transport/browser validation and all existing gates.
