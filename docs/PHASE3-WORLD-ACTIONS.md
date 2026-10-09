# Phase 3 world action modules

These modules port all **33 active original functions** in `p_doors.c`,
`p_floor.c`, `p_ceilng.c`, `p_plats.c`, and `p_lights.c` at upstream
`a77dfb96cb91780ca334d0d4cfd86957558007e0`. This is a module checkpoint;
integrated M2/M3 gameplay, pixel rendering, event transport, and inherited gates
remain separate acceptance requirements.

| Original source | Solidity | Active functions |
|---|---|---|
| `p_doors.c` | `p_doors.sol` | `T_VerticalDoor`, `EV_DoLockedDoor`, `EV_DoDoor`, `EV_VerticalDoor`, `P_SpawnDoorCloseIn30`, `P_SpawnDoorRaiseIn5Mins` |
| `p_floor.c` | `p_floor.sol` | `T_MovePlane`, `T_MoveFloor`, `EV_DoFloor`, `EV_BuildStairs` |
| `p_ceilng.c` | `p_ceilng.sol` | `T_MoveCeiling`, `EV_DoCeiling`, `P_AddActiveCeiling`, `P_RemoveActiveCeiling`, `P_ActivateInStasisCeiling`, `EV_CeilingCrushStop` |
| `p_plats.c` | `p_plats.sol` | `T_PlatRaise`, `EV_DoPlat`, `P_ActivateInStasis`, `EV_StopPlat`, `P_AddActivePlat`, `P_RemoveActivePlat` |
| `p_lights.c` | `p_lights.sol` | `T_FireFlicker`, `P_SpawnFireFlicker`, `T_LightFlash`, `P_SpawnLightFlash`, `T_StrobeFlash`, `P_SpawnStrobeFlash`, `EV_StartLightStrobing`, `EV_TurnTagLightsOff`, `EV_LightTurnOn`, `T_Glow`, `P_SpawnGlowingLight` |

Original abandoned sliding-door code under `#if 0` is inactive in the pinned C
build and is not implemented. Audio-only calls remain outside EVM gameplay.
There is no assembly in these gameplay modules.

## Frozen interfaces and original behavior

All functions take the shared `GameContext memory`. Event functions use the
original typed door/floor/ceiling/platform enums and return original `int32`
success values when applicable. `StairType { build8, turbo16 }` lives in
`p_floor.sol` and is imported by the special dispatcher. Thinker callbacks take
stable payload IDs; `P_Tick.P_AddThinker` preserves original tail insertion order,
and removal remains lazy. Sector `specialdata` stores the thinker ID. Active
ceiling/platform registries store payload IDs, with `GameConst.NULL` as empty.

`P_Spec` owns original neighboring-sector/tag helpers. `EV_DoDoorTag` and
`EV_DoFloorTag` extend the interface for original boss callbacks that construct
a tag-only temporary line. They use the same original tag loop and event logic;
no real map line is invented. `raiseFloor24AndChange` requires a front sector and
rejects synthetic tag-only calls when an eligible free sector would be allocated;
empty/busy tags retain the original defined zero return. Original boss calls do
not use this type.

The source retains original details that affect determinism:

- Plane endpoints use strict `<`/`>` tests, so reaching a destination exactly
  does not return `pastdest` until the next movement call. An obstructed endpoint
  restores the old height but still returns `pastdest`; ordinary obstruction
  returns `crushed`. Upward ceilings retain movement on ordinary obstruction
  because original rollback code is compiled out.
- Door reversal, waiting, blazing speeds, 30-second close, 5-minute initial wait,
  card/skull locks, and monster/player differences use original ordering.
- Floors retain destination selection, texture-height search, completion-time
  flat/special changes, and staircase traversal. Stair height increments before
  skipping an occupied matching neighbor; the outer tag search resumes from the
  final staircase sector, as original C does.
- Crusher speed drops and recovery, platform wait/status transitions, stasis
  callbacks, and registry order are original. Ceiling registry overflow is
  silently ignored; platform overflow/missing-removal produce original fatal
  errors, represented as custom reverts.
- Fire/flash/strobe/glow timing and RNG calls are original. `EV_LightTurnOn`
  keeps its mutable brightness value across tagged sectors, preserving original
  first-nonzero surrounding brightness behavior.

## Native proofs

```sh
python3 tools/reference/phase3_world/reference.py --check
python3 tools/reference/phase3_world/planes.py --check
python3 tools/reference/phase3_world/domains.py --check
python3 tools/reference/phase3_world/undefined_floor.py --check
python3 tools/reference/phase3_world/mover_casts.py --check
.toolchain/bin/forge test --match-contract WorldActionsTest -vv
```

The current module checkpoint passes **all 28 WorldActions tests**. The combined
unfiltered gate also passes all **55 tests in four suites**, including the
separate special dispatcher, bounding-box, and persistent-state adapter tests:

```sh
.toolchain/bin/forge test \
  --match-contract 'WorldActionsTest|WorldSpecials_Test|MBBoxTest|GameStorageTest' -vv
```

There are zero failures/skips. The world fixture's largest test uses 641,210,811
gas under the unchanged 1,000,000,000 test limit. Tag-light categories are
independent tests to avoid cumulative fixture allocation growth. These gas
numbers include fixture setup and comparison, and do not measure engine frames.
`test/fixtures/phase3_world/validation.json` binds this checkpoint to source,
dependency, harness, and fixture hashes. It does not establish integrated M2/M3.

The world harness compiles the **entire unchanged five original C translation
units**, original RNG, and mechanically extracted original neighborhood helpers
and thinker-list routines. Under the pinned compiler, **359 scenarios and
79,021 snapshots** are byte-identical at O0, O2, and with full AddressSanitizer
and UndefinedBehaviorSanitizer enabled. Synthetic geometry is a declared
four-sector two-sided chain; collision is an explicitly declared `P_ChangeSector`
hook with clear, always-blocked, alternating, and temporary obstruction profiles.
The proof establishes mover/thinker behavior and ordered collision callbacks;
full-world collision/damage acceptance is separate.

Coverage includes all event-created door/floor/ceiling/platform types, manual
door locks and player/monster reopening, complete long timers, ceiling/platform
stop/resume/retrigger, stair busy-neighbor traversal, floor completion changes,
ceiling registry overflow, and every lighting function with different initial
light/RNG profiles. `donutRaise` floor thinkers are configured through their
original payload semantics; original `EV_DoFloor` does not initialize this type.
The special dispatcher separately owns original `EV_DoDonut` construction.

Snapshots serialize mutable sectors/lines, RNG index, ordered change-sector
callback counts/argument hashes, original linked thinker order/status, all live
typed payload fields, active registry identities, and lock messages. Python
exports SHA-256 expectations; compressed complete native snapshots remain
available for field diagnostics. Payload tombstones after lazy removal are not
serialized as live native objects. Manifests record source, harness, extraction,
compiler/profile, generated-source, and fixture hashes.

A second exact proof runs **2,160 original `T_MovePlane` cases**, covering both
planes/directions, crush flags, obstruction patterns, zero/normal/large speeds,
equality, undershoot/overshoot, endpoint restoration, final heights, and ordered
callback arguments. The domain audit separately exercises both original fatal
platform-registry errors and the four LP64 door/platform overlap cases.

The Forge fixture adapter reuses an allocated 8 KiB snapshot buffer to avoid
long-timer memory growth. Each test-only assembly write checks its complete
32-byte store is inside that allocation; temporary length changes expose only
the initialized prefix to SHA-256. Hash expectations are copied over exact
in-bounds source/destination spans. This assembly belongs only to verification,
and does not replace world algorithms.
Known-initialization mask flags belong to that verification buffer, separately
from original `GameState` action/state fields. Test instrumentation therefore
cannot change gameplay action values or misclassify another constructor.

## Original undefined and compiler-profile domains

`original-domains.json` records direct original-source measurements rather than
assuming all allocation bytes were initialized:

- `P_SpawnDoorCloseIn30` leaves `topheight` and `topwait` untouched: a zero-filled
  allocation produces zero, while a `0xA5` allocation retains `0xA5A5A5A5`.
  These fields are normally inactive while closing, but obstruction reversal
  can make them meaningful.
- Original stair allocation leaves floor `type` and `crush` untouched. The
  same alternate fill is retained. `crush` is passed to plane/collision logic
  from the first tic, and `type` is tested on completion. They are not known
  portable C values.
- Known unset raw fields are logically masked in canonical state snapshots.
  **Execution in this isolated proof explicitly uses the zero allocator
  profile.** The port's zero-valued fresh payload is a deterministic extension
  for original uninitialized domains when those values are consumed. Masking
  raw bytes does not prove alternate-fill gameplay equivalence. Whole-world
  alternate-fill evidence and remaining ambiguities must be tracked separately.
- Generic `EV_DoFloor(donutRaise)` has no original switch initializer for its
  sector pointer. A separate full UBSan probe records the null-sector dereference
  on its first thinker tic in the zero-heap profile. The generic event rejects
  this undefined allocating call with `UninitializedFloorType`; empty/busy tagged
  sectors preserve original return zero. Actual `EV_DoDonut` constructs initialized
  `donutRaise` payloads directly, and those thinkers remain supported and compared.
- Original manual door reuse casts `specialdata` to `vldoor_t`. On pinned LP64,
  `vldoor_t.direction`, `plat_t.count`, and `ceiling_t.speed` occupy byte offset 48. The native
  probe shows count 7 becomes -1 for a player, stays 7 for a monster, and count
  -1 becomes 1 for either; the four ceiling-speed cases follow the same rule.
  The port preserves both measured integer overlaps explicitly, including these
  vanilla quirks. Floor byte offset 48 spans a 16-bit texture and padding, which
  lacks a complete proven representation in the frozen fields. A fire-flicker
  allocation is only 48 bytes, and the separate ASan probe demonstrates the
  original out-of-bounds door-direction access. Unsupported reinterpretations
  reject with `InvalidDoorThinker`; these domains are not presented as C-equivalent.

No shared production types, engine adapter, renderer, or browser entrypoint is
edited by this workstream.
