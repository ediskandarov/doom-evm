# Phase 3 enemy AI and original action routines

`src/doom/p_enemy.sol` maps all 64 active definitions in pinned `linuxdoom-1.10/p_enemy.c` (`a77dfb96cb91780ca334d0d4cfd86957558007e0`). The original names and module ownership remain visible. The 51 original actor state actions use original generated `P_Info` action IDs; `A_PainShootSkull` is a parameterized helper, and the three original shotgun PSprite callbacks have their original source ownership here. The game adapter must route the appropriate actor/PSprite callbacks through the shared hooks.

This is implementation and isolated conformance evidence. It does not establish M2/M3 acceptance or claim a complete original DOOM port.

## Shared-state behavior

Actor/player/sector identities use frozen `p_game_state.sol`; actors and all other thinker kinds share the original linked-list update order. Source loops examine active mobj thinkers, rather than iterating pool capacity or tombstones. RNG draws use the original `P_Random` stream; spread expressions explicitly consume their two draws in the pinned native order. Disabled sound-device calls omit audio output, while sound-selection draws in `A_Look`/`A_Scream` and active-sound tests in `A_Chase` retain their original RNG effects. Gameplay sound flood is original sector propagation, including closed openings, one sound-block crossing, and shorter alternate paths.

Original reciprocal movement/visibility/collision/damage/state/spawn calls go through internal `GameHooks`. Boss and Keen actions pass the only initialized original junk-linedef field, its tag, through `bossDoFloor`/`bossDoDoor`; exits call `exitLevel`. Arch-vile search replaces private C globals with a local `VileSearch` memory alias. Its bx-then-by block order, per-block bnext order and first successful corpse early stop remain the original `P_BlockThingsIterator` control flow. These scratch fields are not externally observable original world state.

Adapters reject source-undefined inputs such as invalid movement direction, all player slots disabled during player search, more than 32 brain targets, absent brain targets, zero brain-cube vertical speed/state duration, and zero target mass. Defined original domains retain wrapping int32/uint32 arithmetic, fixed multiplication, signed division and binary angles under the pinned native compiler profile.

Original quirks remain explicit: diagonal chase speed 47000; reverse `spechit` traversal and postfix decrement to -1; lost-soul count checks `>20` (allowing the 21st); temporary corpse height scaling before collision tests; `A_VileTarget` initially passes target.x for both coordinates; `A_BruisAttack` does not add an absent original face-target call; brain explosion z is raw `128 + random*2*FRACUNIT`; and brain-spit easy alternation is persistent state.

## Native proof

`python3 tools/reference/phase3_enemy/reference.py --check` compiles the entire original `p_enemy.c` unchanged, original info/state tables and RNG, plus mechanically extracted original angle/distance/line-opening helpers. It verifies the pinned upstream/clean checkout/compiler and hashes every source/header, extraction and harness file. The native profiles are O0, O2, and O2 ASan/UBSan with the existing `-fwrapv` implementation profile. Original negative signed shifts retain the pinned-profile policy; this is not a universal ISO C definedness claim.

Neighbor subsystems are explicit observing test doubles: controlled sight/collision returns, deterministic spawn/missile results, damage, state selection and ordered call recording. They isolate what original enemy routines compute, consume and request; they do not replace integrated-world C reference evidence. `test/unit/p_enemy.t.sol` constructs the same controlled contexts and compares actor state, RNG progression, sector sound state, brain state, and exact ordered neighbor calls against native binary records. These doubles do not implement enemy algorithms.

The native fixture has 1,137 cases and invokes every one of the 64 original definitions. It varies RNG starts, visibility/movement rejection, target distance/direction/shadow/death/nullability, reaction/threshold state, no-direction, held attack state, corpse-fit failure, extra live bosses, lost-soul overflow, tracer tic cadence, difficulty and boss map/episode rules. Per-record inputs and full outputs are preserved in `test/fixtures/phase3_enemy/vectors.bin`; the manifest lists exact operations and schema.

## Coverage matrix

| Original family | Implemented definitions/actions | Current evidence | Remaining integrated evidence |
| --- | --- | --- | --- |
| Sound and acquisition | RecursiveSound, NoiseAlert, melee/missile range, LookForPlayers, Look | Controlled openings/blocking, visibility, distance and player search; whole E1M1 native scenarios also alert monsters | Alternate shortest sound paths and all species missile probability branches require expanded targeted contexts |
| Movement/chase | Move, TryWalk, NewChaseDir, Chase, FaceTarget | Controlled rejection/direction/random draws and callbacks; real E1M1 movement/monster chasing native traces | Expanded floating-species vertical movement and exact angle-turn branches |
| Hitscan/refire | PosAttack, SPosAttack, CPosAttack, CPosRefire, SpidRefire | Ordered aim/pellet/damage parameters, spread RNG, visibility/refire behavior; whole native pistol/zombie combat | All hitscan species through EVM world transactions |
| Melee/projectiles | Bspi, Troop, Sarg, Head, Cyber, Bruis, SkelMissile/Whoosh/Fist, Tracer, SkullAttack | All actions called across controlled target conditions; projectile motion/reaim and smoke/RNG observed | All species/projectile collision interactions through EVM world transactions |
| Arch-vile | PIT_VileCheck, VileChase/Start/Target/Attack, StartFire/FireCrackle/Fire | Controlled corpse-fit/resurrection and fire coordinates/targets/damage/radius calls | Integrated resurrection with original world block/sector links and moving targets |
| Mancubus/lost souls | FatRaise/Attack1/2/3, PainShootSkull/Attack/Die | Reaim/spread/call order, three soul launches and original overflow limit | Integrated multi-projectile collision and exact 20-versus-21 boundary |
| Death/boss effects | Scream/XScream/Pain/Fall/Explode, BossDeath, KeenDie, Hoof/Metal/BabyMetal, PlayerScream | Flags, sound-choice RNG, radius calls, surviving-player and duplicate-boss conditions; all supported boss/episode dispatch rules | EVM sector transitions on boss maps and full sound-choice species variation |
| Brain/cubes | BrainAwake/Pain/Scream/Explode/Die/Spit, SpawnSound/Fly | Target scanning, easy alternation, explosion placement, spawn distribution/calls, reaction countdown and telefrag request | Expanded multiple-target rotation, all spawn-distribution thresholds and integrated spawn/telefrag world effects |
| Shotgun PSprite ownership | OpenShotgun2/LoadShotgun2/CloseShotgun2 | Sound-only callbacks and original ReFire delegation; weapon workstream has full original PSprite proof | Adapter routing and integrated super-shotgun runtime profile |

The independent `tools/reference/gameplay/` oracle covers real E1M1 gameplay and live original frames. Its eight scenarios establish native ordinary movement/collision/lift/pickup and controlled combat/damage/death/door behavior. EVM gameplay state/frame comparisons and retained Phase 0/1/2 gates remain the integrator's acceptance work.
