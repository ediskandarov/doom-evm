# Phase 3 collision, traversal and sight port

The three matching Solidity modules implement all **40 active original functions** in `p_map.c` (20), `p_maputl.c` (15) and `p_sight.c` (5), pinned at `a77dfb96cb91780ca334d0d4cfd86957558007e0`. This is module-level work; whole Phase 3/M2/M3 acceptance is separate.

## Source mapping

| Module | Original functions, all retained under the same names |
|---|---|
| `p_maputl.sol`: geometry | `P_AproxDistance`, `P_PointOnLineSide`, `P_BoxOnLineSide`, `P_PointOnDivlineSide`, `P_MakeDivline`, `P_InterceptVector`, `P_LineOpening` |
| `p_maputl.sol`: spatial and traversal | `P_UnsetThingPosition`, `P_SetThingPosition`, `P_BlockLinesIterator`, `P_BlockThingsIterator`, `PIT_AddLineIntercepts`, `PIT_AddThingIntercepts`, `P_TraverseIntercepts`, `P_PathTraverse` |
| `p_map.sol`: collision | `PIT_StompThing`, `P_TeleportMove`, `PIT_CheckLine`, `PIT_CheckThing`, `P_CheckPosition`, `P_TryMove`, `P_ThingHeightClip` |
| `p_map.sol`: slide | `P_HitSlideLine`, `PTR_SlideTraverse`, `P_SlideMove` |
| `p_map.sol`: use and shooting | `PTR_AimTraverse`, `PTR_ShootTraverse`, `P_AimLineAttack`, `P_LineAttack`, `PTR_UseTraverse`, `P_UseLines` |
| `p_map.sol`: damage and sector movement | `PIT_RadiusAttack`, `P_RadiusAttack`, `PIT_ChangeSector`, `P_ChangeSector` |
| `p_sight.sol` | `P_DivlineSide`, `P_InterceptVector2`, `P_CrossSubsector`, `P_CrossBSPNode`, `P_CheckSight` |

Disabled upstream float interception and `#if 0` intercept filtering remain disabled. Helpers `setCheck` and `stairstep` extract repeated original straight-line blocks without changing their ordering. Geometry uses the existing original fixed-point and table ports. Cross-module gameplay effects execute through the frozen internal hooks. Native audio calls remain presentation no-ops; weapon noise propagation is implemented separately by the original gameplay `P_NoiseAlert` path.

## Native proof

```sh
python3 tools/reference/phase3_map/geometry.py --check
python3 tools/reference/phase3_map/scenarios.py --check
.toolchain/bin/forge test --match-path 'test/unit/p_map*.t.sol' -vv
```

The geometry generator mechanically extracts 12 unchanged original functions from `p_maputl.c`, `p_sight.c` and `m_fixed.c`. It emits **4,310 cases** covering approximate distance, four side/box variants, original sight-side behavior, both interception functions and line opening including stale globals on a one-sided line. The standalone C driver provides arguments and records original outputs. There is no rewritten C arithmetic oracle.

The scenario generator compiles the **complete unchanged original** `p_map.c`, `p_maputl.c`, `p_sight.c`, `m_fixed.c`, `m_random.c` and `tables.c` translation units. Original renderer point/angle/subsector functions are mechanically extracted for their shared numerical dependencies. Its **71 synthetic map scenarios** cover collision and stepping, no clipping, missile origin/species rules, skull strikes, solid/non-solid pickups, reverse special-line crossings, telefragging, wall sliding, aiming, blood/puff hits, sky walls, use, radius damage, sector crushing, spatial unlink/relink, off-map and NOSECTOR/NOBLOCKMAP behavior, sorted and equal-fraction intercept order, earlyout and original traversal bounds. Two controlled reentrant callbacks change original shared globals: a damage callback replaces `tmthing` during a skull strike, and a shoot-special callback changes `attackrange` before line-slope calculation. The port re-reads those original globals at the same points as C.

Higher gameplay modules in these unit scenarios are explicit recorded mocks. Both C and Solidity receive identical fixture geometry/setup and identical mock effects. The comparison includes exact callback sequence/arguments, actor positions/momentum/health/flags/state/size, sector/block links, shared collision outputs, RNG index, validcount, intercept count and sight counters. These mocks prove the collision modules' call boundaries; they do not prove weapons, damage or AI themselves. The separate whole-world gameplay oracle executes the actual original higher modules, original zone allocator and real E1M1 map. Its traces are required for integration acceptance.

Both native generators require the pinned original checkout and compiler profile, emit source/extraction/harness hashes, and compare every binary output across **O0, O2 and ASan/UBSan**. The generated binary fixtures and manifests are tracked under `test/fixtures/phase3_map`. Generated inputs are deterministic and never come from live EVM output.

The integrator's verified command was:

```sh
.toolchain/bin/forge test --match-path 'test/unit/{p_map,p_maputl,p_tick,GameHeap,g_game,p_info,m_random}.t.sol' --skip p_enemy.t.sol -vv
```

It exited zero with **22 passing tests, zero failures, seven suites**. The collision tests compare all 4,310 geometry cases and all 71 scenario records exactly in the EVM; the original undefined `abs(INT_MIN)` domain rejection also passes. Gas was 495,270,142 for the complete scenario fixture test, 55,671,243 for the complete geometry fixture test and 941 for the undefined-domain rejection test. These are aggregate test costs including fixture setup/serialization, not production per-tic/frame measurements. Complete AI source compiled in this batch, but its ongoing tests were explicitly skipped and are not claimed verified here.

`test/fixtures/phase3_map/validation.json` records commands, reported test evidence, and current source/test/fixture/dependency hashes. The integrator reported these metrics from terminal session 72303; no raw console-log archive is claimed. Both native `--check` commands were rerun successfully after the Forge batch. Whole-engine acceptance remains pending.

## Original details preserved

- Head insertion and original next/prev sector/block links; unset does not clear the removed object's original links.
- Things before lines in collision, bx outer/by inner ordering, original signed BLOCKMAP words and duplicate-linedef suppression via global validcount.
- Crossed specials in reverse encounter order, with original final `numspechit == -1` after its post-decrement loop.
- Minimum fraction selection with strict `<`, preserving discovery order for equal intercepts.
- Original one-unit trace-start nudge on exact block boundaries and the 64-block traversal cap. The cap may leave a long ray only partly scanned; no enhanced raycast replaces it.
- Original sight horizontal shortcut checks `x == node.y`, as written in upstream. It is not corrected to `y == node.y`.
- Original shot endpoint uses `(distance >> 16) * finecosine/sine`, rather than substituting `FixedMul`.
- Original `P_RadiusAttack` expression uses `(damage + MAXRADIUS) << 16`, where MAXRADIUS is already fixed-point. The pinned 32-bit wrapping result is retained instead of silently changing the expression's units.
- Original `P_LineAttack` does not reset/set `linetarget`; aim establishes that global. Zero-damage shooting still produces its original puff/blood callbacks.
- Original P_CheckPosition can pick up items before a later collision fails. Its name does not imply a side-effect-free probe.

## Defined-domain policy

Original C `int`/fixed-point behavior follows the repository's pinned 32-bit wrap profile and signed arithmetic shifts. `abs(INT_MIN)` is outside the original defined domain and explicitly rejected. Geometry and map loading must supply valid line/sector/subsector/actor references and complete REJECT bytes.

Original buffer writes past eight crossed specials or 128 intercepts are undefined. The Solidity port rejects those overflows rather than truncating or emulating adjacent-memory corruption. Negative/out-of-range BLOCKMAP offsets/line IDs, unterminated lists, invalid BSP cycles/subsector IDs and truncated REJECT matrices likewise fail explicitly. These are domain checks, not additional gameplay rules on valid original inputs.

Stable IDs never compact and all null pointers use `0xffffffff`. The GameContext map aliases the authoritative state map. Heap growth must preserve actor aliases across nested original callbacks. Whole-world gates must establish that persisted world mutation and rendering use the state after each tic; passing these isolated fixtures alone cannot establish M2/M3.
