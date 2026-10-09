# Phase 3 source coverage and acceptance boundaries

This audit inventories the pinned original `linuxdoom-1.10` source at
`a77dfb96cb91780ca334d0d4cfd86957558007e0` and the current Solidity ports.
**M2 and M3 remain unaccepted.** Existing module proofs establish their declared
profiles; the full production gameplay, persistence, framebuffer and browser gates
are still pending. This document does not claim a complete original DOOM port.

The machine-readable [feature matrix](../artifacts/phase3/feature-matrix.json)
contains every inventoried definition's original and port source spans, body
hashes, evidence references, unsupported profiles and remaining gates. It records
an audit-time snapshot. Refresh it after source changes and final integration;
checkpoint hashes bind their own tested revisions, not automatically every later
shared-state layout. No compiler was run for this audit and no Codex session
transcripts were read.

## Source presence and module evidence

There are **238 active definitions across the 18 core gameplay `p_*.c` units**:
226 have named ports with isolated module evidence; 12 belong to draft level setup.
The latter has five named ports and seven disk loaders delegated to
`R_Data.R_LoadMap`, with sector runtime fields completed by `P_LoadSectorRuntime`.
Delegation is an adaptation, rather than seven independent new ports or seven
unimplemented loaders. Setup still requires real-level runtime comparison.

The broader inventory has **287 definitions**: those 238, four upstream-disabled
sliding-door definitions, eight original save/archive definitions, 32 `g_game.c`
definitions and five RNG/bounding-box definitions. Four game functions are
ported: the declared keyboard `G_BuildTiccmd` profile and original
`G_PlayerReborn`, `G_ExitLevel`, `G_SecretExitLevel`. The other 28 gameflow functions
and eight save/archive functions are not ported.

| Original module | Active definitions | Present port/evidence scope |
|---|---:|---|
| `p_maputl`, `p_map`, `p_sight` | 15 + 20 + 5 | Spatial links, BLOCKMAP, path/intercepts, movement/slide/teleport, hitscan/use/radius/sector clipping and sight; [collision proof](PHASE3-COLLISION.md) |
| `p_user`, `p_mobj` | 5 + 16 | Player/lifecycle/state/momentum/spawning/respawn and effects; [lifecycle proof](PHASE3-LIFECYCLE.md) |
| `p_pspr`, `p_inter` | 30 + 9 | All weapon/PSprite and pickup/damage/death definitions; [combat proof](PHASE3-COMBAT.md) |
| `p_enemy` | 64 | Acquisition, chase, every active action, sound flood, bosses and brain; [AI proof](PHASE3-AI.md) |
| `p_tick` | 6 | Linked scheduling and ticker, including the originally empty `P_AllocateThinker`; [tick proof](PHASE3-TICK.md) |
| `p_doors`, `p_floor`, `p_ceilng`, `p_plats`, `p_lights` | 6 + 4 + 6 + 6 + 11 | All active events and thinkers; [world-action proof](PHASE3-WORLD-ACTIONS.md) |
| `p_spec`, `p_switch`, `p_telept` | 18 + 4 + 1 | Helpers, numeric dispatch, animation, switches, sector effects, donut and teleport; [specials proof](PHASE3-WORLD-SPECIALS.md) |
| `p_setup` | 12 | Draft loaders/grouping/startup/init; [original setup](../original/DOOM/linuxdoom-1.10/p_setup.c#L584), [draft adapter](../src/doom/p_setup.sol) |
| `m_random`, `m_bbox` | 3 + 2 | Independent original RNG streams and bbox operations; `M_Random` maps to `M_RandomValue` |
| `g_game` | 32 | Four named ports; keyboard profile restrictions and missing gameflow listed below |
| `p_saveg` | 8 | Original archive/unarchive format absent; EVM persistence is a separate adapter |

Source presence and called-function coverage are not branch-completeness claims.
All active enemy functions, for example, have controlled native cases; that does
not mean every species/action has been exercised in a real persisted EVM world.
The matrix's `moduleEvidence` links to the exact scope instead of treating every
function as accepted end to end. Its `wholeEngineEvmEvidence` fields remain null.

## What the existing proofs establish

| Proof | Native coverage | EVM evidence and boundary |
|---|---|---|
| Input | 41,007 keyboard command cases | 14 Solidity tests and five browser unit tests; device/network and production transport are separate |
| Collision/sight | 4,310 geometry cases and 71 scenarios | Three tests; higher-module callbacks are explicit recorded doubles |
| Lifecycle | 784 cases / 24 definitions including three game reset/exit functions | 24 tests; recursive state and neighbor callbacks controlled; corrected positive item respawn separately rerun |
| Weapons/interactions | 72 weapon scenarios / 11,520 tics; 6,025 interaction cases | 24 tests; real PSprite actions, recorded aim/hit/missile/noise/state boundaries |
| Enemy AI | 1,137 cases / 64 definitions | 64 tests; ordered visibility/movement/spawn/damage/state doubles |
| Ticker | Eight scheduling snapshots | One test; callbacks recorded, static test nodes retained after deallocation |
| World actions | 359 scenarios / 79,021 snapshots; 2,160 plane cases; four plat and four ceiling cast cases | 28 tests; synthetic sector chain and obstruction callback; zero allocator execution profile |
| Specials | 416 helper/selected-state cases; 1,007 dispatch scenarios / 4,048 paired snapshots | 25 tests; real world action dispatch, declared synthetic geometry; successful teleport movement/fog are boundary mocks |
| Bounding boxes | 521 streams / 8,299 points | One test; every point prefix compared |
| Storage | Synthetic nonempty map/actor/thinker/door/scratch/resource/render state | One roundtrip test; complete real-level/production evidence pending |
| Complete native world | Eight E1M1 scenarios / 2,205 tics / 24 live 64,000-byte frames | Native oracle only; corresponding EVM state and frame acceptance pending |

Counts refer to the retained checkpoint records, not a new audit run. The final
world/specials/bbox/storage batch passed 55 tests in four suites; it does not
replace a full frozen regression run. Aggregate fixture costs such as
771,444,952 gas for a player-sector fixture batch include setup/serialization and
are not production per-tic/frame costs.

The [special-number matrix](../test/fixtures/phase3_specials/dispatch-matrix.json)
binds all 72 crossing, 63 use and three shoot branches to original bodies and a
mechanical checked translation. All numeric branches are exercised in declared
dispatch fixtures; actual geometric consequences still require integration.

The [whole-world oracle](../tools/reference/gameplay/README.md) runs original
`P_SetupLevel`, gameplay units, renderer and zone allocator. Ordinary idle,
movement and pistol cases use original E1M1 spawning. Combat/damage/death arena
cases add an original possessed actor at a declared valid point in real E1M1;
armor/health are controlled initial conditions. Door cases teleport to the real
line 55 and send held use; one disables monsters and the other retains them to
exercise obstruction reversal. These are bounded scenarios, not all-map or
natural-complete-playthrough coverage. O0/O2/ASan/UBSan and alternate `0xa5`
allocation-fill outputs agree for these scenarios.

Per-function `nativeEntryObservations` preserve counts from retained
`events.json` instrumentation. A null entry means no retained measurement for
that function; it does not prove nonexecution. Entry counts alone do not prove
branches, state equivalence, persistence or pixel equivalence.

## Adapter and feature boundaries

At this snapshot, [Doom.sol](../src/evm/Doom.sol) is the accepted Phase 2 static
caller and explicitly has no gameplay ticks. [DoomGame](../src/evm/DoomGame.sol)
is a draft library with shared hook routing, startup/tick and actor/PSprite render
projection. [P_Setup](../src/doom/p_setup.sol) adds runtime map/spawn state.
Reported module compilation typechecked these drafts. Full public-caller graph
compilation remains pending after a via-IR Yul stack-depth failure. Optimized IR
points to a scenario parameter retained across initialization in the test probe;
the reference agent is resolving test-only calldata lifetime. `R_Data` is restored
to committed HEAD and the startup helper trial has been removed. No production
loader refactor remains. This is a compilation issue, not an observed gameplay
mismatch. Startup and transaction equivalence remain pending. The test-only
`GameplayProbe` observer is not a production game frontend.

| Feature/profile | Current boundary |
|---|---|
| Single-player startup | Draft medium-skill retail E1M1, one player, optional adapter `nomonsters`; not arbitrary CLI initialization |
| Weapons, pickups, AI, world actions | Complete active module definitions and bounded proofs; full-world EVM combinations pending |
| Other maps, skills and modes | Algorithms and dependent branches tested in isolated contexts; arbitrary episode/WAD/map runtime acceptance absent |
| Keyboard | Original declared keyboard conversion; production authorization, sequencing and browser delivery pending |
| Mouse, joystick, chat | Zero-valued omitted device branches; no device/chat frontend |
| CLI | No original `D_DoomMain` parser, `-avg` or `-timer`; original timer-update logic is implemented and tested separately |
| Multiplayer/deathmatch | Four-player fields and original module branches retained/tested; no network consistency/checksum/game loop; startup rejects deathmatch |
| Demo record/playback | No original demo gameflow; retained ticker demo flags only preserve its conditional scheduling behavior |
| Audio/music | Presentation/device calls omitted; original gameplay noise flood and sound-choice `P_Random` draws retained |
| Menus, status bar, HUD, automap | Presentation absent; original ticker menu guard retained; world view and PSprites rendered |
| Save/load | Original `p_saveg`/game save format absent; storage roundtrip is a distinct EVM mechanism |
| Exit/intermission/finale/next map | Exit and secret flags set original completed gameaction; intermission, finale and automatic level progression absent |
| Death/reborn | DeathThink, PlayerReborn and SpawnPlayer exist; `G_DoReborn`, check-spot and level restart dispatch absent |
| Sliding doors | Original abandoned `#if 0` definitions remain disabled, excluded from active coverage |

Original source spans for missing functions are in JSON. In particular,
[`G_Ticker` (605–748)](../original/DOOM/linuxdoom-1.10/g_game.c#L605),
[`G_DoReborn` (924–967)](../original/DOOM/linuxdoom-1.10/g_game.c#L924) and
[`G_DoCompleted` (1020–1141)](../original/DOOM/linuxdoom-1.10/g_game.c#L1020)
contain absent gameflow. Calling `P_Ticker` directly does not supply those layers.

## Native C domains and explicit adaptations

The numerical contract is the pinned compiler/target and recorded flags,
including `-fwrapv`, signed narrowing and arithmetic-shift behavior. Original
negative signed shifts have independent strict-UB diagnostics; this is not a
universal ISO C definedness claim. Ordered RNG expressions are deliberately
preserved rather than silently using Solidity evaluation order.

Original zone allocation becomes stable IDs, capacity buffers and tombstones;
linked thinker/sector/block traversal and same-tic tail execution retain original
order. Native whole-world verification uses original zone free/reuse with
recorded LP64 alignment and sector-pointer-array sizing adaptations. Tick unit
fixtures retain node bytes after recorded free and do not establish reuse.

The [allocation-domain audit](../test/fixtures/phase3_world/original-domains.json)
records uninitialized close-timer door `topheight/topwait` and stair `type/crush`.
World module execution explicitly uses zero-filled allocation. Canonical masks
exclude unknown raw fields but cannot prove equivalent execution under arbitrary
heap contents when those fields are consumed. Fresh Solidity zero values are a
deterministic extension in those domains. Selected whole-world alternate-fill
agreement is stronger evidence for those scenarios, not all stair/timer cases.

The [mover-cast probe](../test/fixtures/phase3_world/mover-casts.json) binds original
manual-door reuse to pinned LP64 byte offset 48: `door.direction`, `plat.count`
and `ceiling.speed`. Both measured integer overlaps are preserved. Floor texture
and padding lack a complete proven representation; fire-flicker reinterpretation
is an original out-of-bounds read. Unsupported cases reject explicitly. Generic
`EV_DoFloor(donutRaise)` originally uses an uninitialized sector pointer;
that domain is rejected, while actual `EV_DoDonut` construction is supported.

Geometry guards reject original undefined or malformed domains: `abs(INT_MIN)`,
more than eight crossed specials or 128 intercepts, malformed BLOCKMAP,
invalid/cyclic BSP, short REJECT, null donut topology and more than 64 scrollers.
The original 64-step path traversal bound is retained. Next-highest-floor's first
20 eligible entries are an original warning/break limit, not a rejected overflow.

Original fatal limits become reverts: exhausted 16 buttons, exhausted/missing
30 platform registry, missing required resources and unknown collectibles.
The 30-ceiling registry's original silent registration failure remains silent.
Invalid table/player/ammo/weapon indices, undefined AI direction/player/brain
states, zero division inputs and unsupported reinterpretations are explicit
boundaries. These guards do not count as successful original gameplay cases.

Complete generated data covers 967 states, 137 actor/effect/item definitions,
nine weapons and 74 actions. These counts do not imply 137 monster species or
integrated execution of every table entry.

## Remaining acceptance work

The JSON lists pending gates individually so the integrator can attach final
artifacts without converting unit proofs into whole-engine claims:

1. Compare complete real E1M1 native/EVM startup, actors/world links, RNG,
   BLOCKMAP/REJECT, sector lists and spawned specials.
2. Run actual keyboard conversion and sequenced movement/turn/strafe/use through
   persisted EVM state, compare logical tic records and repeat deterministic
   streams; compare every selected 64,000-byte framebuffer.
3. Compare integrated weapon/monster/damage/pickup/door/switch/lift behavior,
   original thinker/RNG ordering and stored world/render scratch and aliases.
4. Wire and verify the production game caller, authenticated resources,
   authorization/input sequence, exact Frame events, WebSocket/receipt paths
   and browser Canvas.
5. Rerun all inherited Phase 0/1/2 gates and all Phase 3 regressions on the final
   frozen source. Measure actual production tic/frame gas and memory.
6. Keep article claims bounded by this feature/domain matrix and local usage
   telemetry, preserving missing historical measurements and phase/model/agent
   boundaries. No external telemetry service is required.
