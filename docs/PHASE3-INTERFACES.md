# Phase 3 shared gameplay interfaces

Approved by the integrator, 2026-10-09. The shared schema compiles with pinned Solidity 0.8.37; complete native table and RNG comparisons pass, and actor/thinker aliases survive geometric pool growth in the dedicated integration tests. This freezes module boundaries; it does not establish M2 or M3 acceptance. The source is pristine `original/DOOM/linuxdoom-1.10`, commit `a77dfb96cb91780ca334d0d4cfd86957558007e0`. The schemas are in `src/doom/p_game_state.sol`; existing renderer schemas remain compatible with Phase 2.

## Numeric and identity rules

Original `fixed_t` and C `int` values use `int32`; angles and runtime actor flags use `uint32`. Arithmetic must retain the existing pinned C profile, including signed arithmetic shifts and explicit wrapping where the original/native profile wraps. Enum order follows the original headers. The original table `long` fields are narrowed to their observed, representable signed 32-bit values; a generated native table comparison proves that domain before use. `MobjInfo` retains all 23 original signed integer fields; `StateDef` and `WeaponInfo` retain complete gameplay tables.

Pointers become stable `uint32` indices. `GameConst.NULL == 0xffffffff` is the null pointer for actors, players, state pointers, sector actions and spatial links. `S_NULL == 0` is an original state number and is **not** the null state pointer. Thinker slot zero is the sentinel `thinkercap`, and is never null. New arrays/records require explicit null initialization: Solidity's default zero is a valid object or sentinel ID. Live actor and thinker arrays never compact or reorder. Tombstones preserve identity after lazy removal; reuse is deferred until there is an explicit proof that it preserves reference semantics.

`Player` maps `d_player.h player_t`, `Mobj` maps `p_mobj.h mobj_t`, and `Thinker` maps `d_think.h thinker_t`. The derived `mobj->info` pointer is `definitions.mobjinfo[actor.mobjType]`; other pointer links are represented directly. Message text is local game state and not telemetry. `PlayerPSprite` contains simulation state/tics/sx/sy; render sprite/frame values are derived from the current `StateDef`.

Actor/thinker/typed payload arrays are capacity buffers. `mobjCount`, `thinkerCount`, `doorCount`, `floorCount`, `ceilingCount`, `platCount`, `fireFlickerCount`, `lightFlashCount`, `strobeCount` and `glowCount` bound the allocated ID range; array length is capacity, not population. Thinker count includes sentinel index zero. `P_Heap` owns reservation/append: append assigns `ID=count++`, doubling capacity when needed and preserving existing identity and links. Removal does not decrease the counts. Never traverse unused capacity as live actors. Heap growth must preserve aliases retained by a caller across nested spawn callbacks, with a dedicated integration test.

## Ownership and memory aliases

`GameState.map` is the persistent authoritative world: sector heights/pictures/light, side textures/offsets and line flags/specials can mutate. `GameSector` contains sector fields absent from renderer `Sector`: special/tag, adjacency, sound traversal, blockbox, sector actor head and special thinker reference. Line validcounts and specialdata remain parallel arrays, indexed by original linedef number.

The integrator loads one `GameState` into memory and sets `GameContext.map = GameContext.state.map`. Both references must alias the same memory world throughout the tic. Modules mutate that shared memory context, and the transaction copies final state to storage. Renderer resources and internal hooks are transient and never stored in `GameState`. The renderer receives the final mutable map and an exact projection of gameplay actor/psprite state. It must not derive camera movement, collisions or gameplay on the host.

`MapScratch` and `PathScratch` replace original globals, and remain shared through nested original calls. This includes collision results consumed by `P_TryMove`/monster floating movement, sight and attack slopes, path intercepts, slide lines, damage-radius globals, player onground, weapon bulletslope and sound flood target. A module must not clear another module's original globals merely to simplify its interface.

`P_LineOpening` publishes `opentop`, `openbottom`, `openrange` and `lowfloor` into `MapScratch`. Collision/trace/sound routines consume those exact shared results.

Approved source-audit extension: `MapScratch.usething` retains the original use-traversal actor independently of `shootthing`, and `sightcounts[2]` preserves the original sight counters. `GameState.skyflatnum/skytexture` retains level-start sky selection for original missile/hitscan sky checks and rendering. These fields prevent unrelated original globals from being aliased together.

`BlockMap.lump` retains the original signed 16-bit BLOCKMAP words, including offsets and original list ordering. Block offsets begin at original word four. Dimensions/origin and block actor heads are separate fields. REJECT is the original bit matrix. Do not reconstruct either from a host collision model.

## Internal call boundaries

Every `GameHooks` callback is an internal `view` function receiving the same `GameContext memory`; `view` permits lazy immutable WAD reads without allowing contract storage mutations. It follows the renderer's existing internal hook approach. The integrator supplies all hooks before use. Function pointers are never persisted, exposed as an ABI, delegated to an external service or supplied by the browser.

`P_BlockLinesIterator` and `P_BlockThingsIterator` accept `function(GameContext memory,uint32) internal view returns (bool)` callbacks. `P_PathTraverse`/`P_TraverseIntercepts` accept `function(GameContext memory,Intercept memory) internal view returns (bool)`. Their callers supply the original PIT/PTR routines directly; `P_MapUtl` does not import the higher-level collision or AI modules. Callback false stops traversal immediately.

| Hook | Arguments after context | Result / original call |
|---|---|---|
| `tryMove`, `checkPosition`, `teleportMove` | actor, x, y | bool; `P_TryMove`, `P_CheckPosition`, `P_TeleportMove` |
| `slideMove` | actor | `P_SlideMove` |
| `checkSight` | actor1, actor2 | bool; `P_CheckSight` |
| `aimLineAttack` | actor, angle, distance | int32 slope; `P_AimLineAttack` |
| `lineAttack` | actor, angle, distance, slope, damage | `P_LineAttack` |
| `radiusAttack` | spot, source, damage | `P_RadiusAttack` |
| `useLines`, `changeSector` | player / sector, crunch | `P_UseLines`; bool `P_ChangeSector` |
| `spawnMobj` | x, y, z, type | actor ID; `P_SpawnMobj` |
| `removeMobj`, `setMobjState` | actor / actor, state | `P_RemoveMobj`; bool `P_SetMobjState` |
| `spawnPuff`, `spawnBlood` | x,y,z / x,y,z,damage | original effect spawning |
| `spawnMissile`, `spawnPlayerMissile` | source,dest,type / source,type | actor ID / void, matching original |
| `damageMobj`, `touchSpecialThing` | target,inflictor,source,damage / special,toucher | original immediate interactions |
| `actionMobj`, `actionPSprite` | action ID,actor / action ID,player,psprite slot | table action dispatch |
| `playerThink`, `movePsprites`, `setupPsprites`, `dropWeapon` | player slot | matching original calls |
| `respawnSpecials` | none | `P_RespawnSpecials` |
| `crossSpecialLine` | linedef,oldside,actor | `P_CrossSpecialLine` |
| `useSpecialLine`, `shootSpecialLine` | actor,linedef,side / actor,linedef | bool / void, matching original |
| `playerSpecialSector` | player slot | `P_PlayerInSpecialSector` |
| `updateSpecials`, `spawnSpecials` | none | matching original calls |
| `noiseAlert` | target,emitter | `P_NoiseAlert` |
| `thinkerDispatch` | thinker ID | kind/payload dispatch |

Action IDs are generated from first action declaration order in `info.c`, plus one; zero means no callback. The generated definitions include all original state fields and weapon/mobj records. Unsupported action IDs must fail explicitly; silently skipping an action cannot establish source fidelity.

Approved AI extension: `bossDoFloor(context,tag,FloorType)`, `bossDoDoor(context,tag,DoorType)` and `exitLevel(context)` retain the original boss/Keen actions. Original boss calls create a synthetic linedef with only its tag initialized, so these hooks carry the tag directly rather than inventing a real map-line index. The world adapter must execute the matching original sector action and return its success flag.

Door/floor/ceiling/plat/light data uses typed payload arrays with thinker IDs. `specialdata` identifies the thinker, from which kind/payload determine its concrete type. Active ceiling/plat registries contain payload indices, not thinker IDs; they retain the original 30-slot first-free search order. Buttons retain 16 slots and paired switches retain original order. Sliding doors inside original `#if 0` are outside the active source profile.

## Deterministic scheduling and side effects

The original order is normative:

1. `P_Ticker`: player slots ascending, live thinker list, `P_UpdateSpecials`, `P_RespawnSpecials`, increment leveltime. Simulated time is 35 tics per second and never derives from `block.timestamp`.
2. `P_AddThinker` appends at the live tail. Thinkers created by earlier thinkers may execute later in the same tic. Snapshotting the initial list length changes original behavior.
3. `P_RemoveThinker` marks removal. Actual thinker unlink occurs on its next visitation. Null callback stasis is distinct from removal. `P_RemoveMobj` unlinks sector/block position immediately, before delayed thinker removal.
4. Spatial links insert at the sector and block heads. Collision visits block things before block lines, with bx outer/by inner loops. BLOCKMAP list order and first-hit abort behavior must survive.
5. `P_TryMove` processes crossed specials in reverse `spechit` encounter order. Intercept minimum selection uses strict `<`, preserving discovery order on ties.
6. `P_Random` increments `prndindex` before lookup. `M_Random` has a separate index. Spawning consumes original RNG calls, including `lastlook` and positive spawn-state tic randomization.
7. `P_SpawnMobj` copies the spawn state without calling its action. `P_SetMobjState` invokes actions immediately and traverses zero-tic states.

Startup follows `P_SetupLevel`: initialize thinker cap; load BLOCKMAP/map/REJECT; group sector lines in original order; spawn THINGS in lump order; spawn specials. Player rebirth preserves stats, initializes inventory, and starts `usedown`/`attackdown` true. Original spawn filtering, skill selection and ambush flags must be preserved.

## Fidelity and validation obligations

Keep original 24-unit step/dropoff checks, MAXMOVE30, VIEWHEIGHT41, radius16, gravity65536, friction0xe800 and stop0x1000. Preserve the original airborne `P_CalcHeight` branch's later assignment overwriting its earlier ceiling clamp. Input use/fire remains held; gameplay owns edge state. Browser input mapping is separately specified in `INPUT_PROTOCOL.md`.

Original fixed buffers include eight crossed specials, 128 intercepts, 32 animations, 64 scrolling lines, 32 brain targets and 128 item respawn entries. Any out-of-profile buffer overflow must be documented and explicitly rejected; silent truncation cannot be compared as equivalent original behavior. Exact limits and supported domain require native fixtures.

The integrator reviewed schema naming, callback argument order, the memory-to-storage boundary, action IDs, null conventions and heap aliases before parallel source ports. Each agent owns its source/tests and must coordinate shared interface changes. Concrete engine storage round trips remain a later acceptance gate; interface approval does not claim that they are already implemented.

M2 requires native-comparable movement/collision/camera traces through a real level for forward/back/strafe/turn/use and reproducible EVM frame sequences. M3 adds weapons/shooting, monster AI, damage, doors and interactions. Acceptance requires whole-tic native state traces, frame hashes, storage persistence, transport/browser behavior, gas/memory measurements, a feature-coverage matrix and preserved existing gates. The interface freeze is not gameplay acceptance evidence.
