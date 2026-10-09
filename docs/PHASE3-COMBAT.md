# Phase 3 weapons and interactions

This workstream ports complete original `p_pspr.c` and `p_inter.c` gameplay
algorithms through the frozen `GameContext` callbacks. It is a module delivery;
M2/M3 acceptance additionally requires integrated movement, AI, world state,
rendering, event transport, and full-world C comparisons.

## Source mapping

Upstream: `a77dfb96cb91780ca334d0d4cfd86957558007e0`.

| Original | Solidity | Functions |
|---|---|---|
| `p_pspr.c` | `src/doom/p_pspr.sol` | `P_SetPsprite`, `P_CalcSwing`, `P_BringUpWeapon`, `P_CheckAmmo`, `P_FireWeapon`, `P_DropWeapon`, `P_BulletSlope`, `P_GunShot`, `P_SetupPsprites`, `P_MovePsprites` |
| `p_pspr.c` | `src/doom/p_pspr.sol` | `A_WeaponReady`, `A_ReFire`, `A_CheckReload`, `A_Lower`, `A_Raise`, `A_GunFlash`, `A_Punch`, `A_Saw`, `A_FireMissile`, `A_FireBFG`, `A_FirePlasma`, `A_FirePistol`, `A_FireShotgun`, `A_FireShotgun2`, `A_FireCGun`, `A_Light0/1/2`, `A_BFGSpray`, `A_BFGsound` |
| `p_inter.c` | `src/doom/p_inter.sol` | `P_GiveAmmo`, `P_GiveWeapon`, `P_GiveBody`, `P_GiveArmor`, `P_GiveCard`, `P_GivePower`, `P_TouchSpecialThing`, `P_KillMobj`, `P_DamageMobj` |

The dispatcher uses generated `P_Info.A_*` IDs. Original `p_enemy.c` shotgun
open/load actions produce only sound; close also calls `A_ReFire`, retained in
the PSprite dispatcher. Actor dispatch must delegate `A_BFGSpray` to
`P_Pspr.A_BFGSpray`. `A_Explode` remains mapped to `p_enemy.c` and its radius
attack hook. Callback cycles use one shared context and stable actor IDs.

Important original behavior remains visible in the code:

- `wp_nochange` is **10**, and `am_noammo` is **5**; intervening enum count
  entries are real values. PSprite null pointers are `GameConst.NULL`, whereas
  requested original `S_NULL` is zero.
- PSprite state transitions execute actions immediately and continue through
  zero-tic states, including recursive state changes. Flash follows weapon
  coordinates each tic. Weapon rise/lower uses original six-unit movement.
- Empty-ammo fallback preserves original priority and strict comparisons
  (`shell > 2`, `cell > 40`), game-mode restrictions, and chainsaw fallback.
- Rockets/BFG do not auto-fire from the ready state while the attack button is
  continuously held. Refire, flashes, pellet count, RNG draws, spread, autoaim,
  melee facing, chainsaw angle correction, and BFG forty-ray spray retain
  original order.
- Pickup amounts, trainer/nightmare doubling, weapon-switch preferences,
  netgame placed weapons/keys, bonuses, backpack limits, messages, timed powers,
  armor, mirrored actor/player health, and dropped-weapon amounts are original.
- Damage performs thrust before player invulnerability checks, then exit-sector
  protection, armor absorption, player/actor damage, pain RNG, and retargeting.
  Death preserves count/frags, corpse flags/height, gib-state selection, tic
  randomization, and monster-specific drops.

## Native evidence

```sh
python3 tools/reference/phase3_combat/reference.py --check
python3 tools/reference/phase3_combat/weapons.py --check
.toolchain/bin/forge test --match-contract 'PInterTest|PPsprTest' -vv
```

Verified module checkpoint: **24 Forge tests passed** (15 interaction tests and
9 weapon tests), with no differential mismatches. The isolated compile command
used while the other gameplay workstreams were still being written was:

```sh
.toolchain/bin/forge test --match-contract 'PPsprTest|PInterTest' \
  --skip p_map.t.sol --skip p_maputl.t.sol --skip p_enemy.sol -vv
```

The fixture harness keeps coordinates and buffers in a `WeaponCase memory`
scratch struct, and separates scenario advancement from comparison through the
existing callback type. This resolves via-IR stack pressure without modifying
weapon algorithms or reducing cases. Independent ammo categories are separate
tests to keep repeated fixture/context allocations under the configured test
gas limit. Test-harness gas includes reading and comparing fixtures and does not
measure gameplay transaction performance. Full integrated gates are still required.

The isolated interaction oracle mechanically extracts all nine complete
original `p_inter.c` functions and original `P_CheckAmmo`. It retains canonical
original `mobjinfo`, state metadata, `weaponinfo`, RNG table, and pickup strings.
**6,025 cases** compare **42 fields**: all give functions, all 36 pickup sprites,
ammo/skill/weapon ownership and network modes, player damage/armor/invulnerability,
exit sector 11, player deaths, and monster death/gib/drop cases for eight types.
Input/output bytes use explicit big-endian words. O0/O2/full ASan+UBSan output is
identical under the pinned compiler profile. This isolated fixture uses null
inflictor/source for damage; geometry/thrust and real callback effects require
the separate full-world oracle.

The weapon oracle compiles the **entire unchanged original `p_pspr.c`** against
canonical states with its actual weapon action pointers and original tables,
RNG, fixed math, and extracted angle functions. **72 scenarios × 160 tics**
compare **33 fields every tic**: every weapon, empty/100 ammo, held/pulsed attack,
hit/no-hit, strength granted at tic 70, death/drop at tic 120, and a BFG actor
spray at tic 100. Comparisons include overlay state/tics/coordinates, weapon and
ammo fields, attack/refire/light, actor facing/flags, RNG position, recorded
aim/line/missile/damage/noise calls, and original swing calculations.

Cyclic engine hooks in these isolated oracles are explicitly declared test
doubles. Interaction state hooks record transitions without action dispatch;
weapon state transitions use real PSprite actions, while map line attacks,
missile spawning, noise propagation, and spray damage are recorded sinks. Hook
counts and ordered argument hashes prove calls and RNG ordering; they do not
prove collision, missile flight, or target damage. Those effects belong to
`tools/reference/gameplay` full-world comparisons and integrated acceptance.

Manifests identify the exact compiler, upstream, source/harness/generated-source
hashes, flags, scope, and fixture hashes. Fixture regeneration is byte-stable.

## Explicit adaptations and undefined domains

- Audio, tactile feedback, and automap presentation calls have no EVM gameplay
  side effects. Sound-only actions have empty bodies/dispatcher branches for
  that reason; they do not replace gameplay actions with stubs.
- Original `swingx/swingy` globals have no consumer in original gameplay.
  `P_CalcSwing` returns both values explicitly; native comparisons cover them.
- Pointer identity becomes original table indexes or stable actor/player IDs.
  `P_SetPsprite` and hooks mutate shared memory aliases. There is no assembly.
- Original `(P_Random()-P_Random()) << n` can shift negative signed values,
  which ISO C leaves undefined. The weapon manifest records a full UBSan
  diagnostic from unchanged source. O0/O2 outputs agree on the pinned compiler;
  Solidity uses explicit wrapping multiplication. The verification sanitizer
  run disables only `shift-base` and omits `-fwrapv`; all other UBSan categories
  and AddressSanitizer remain active. This is compiler-profile equivalence for
  that original undefined construct, rather than a portable ISO-C claim.
- Arithmetic that models original 32-bit wrap uses explicit `unchecked`
  sections; ordinary fixed-point math retains existing `M_Fixed` semantics.
- Invalid ammo types reject with `InvalidAmmo`. Original `ammo == NUMAMMO`
  reaches beyond its arrays; the port rejects this undefined-C input explicitly.
  Invalid table/player/weapon/power/card indexes retain Solidity bounds checks.
  Unknown collectible sprites reject with `UnknownSpecialThing`, corresponding
  to original `I_Error`. A living non-player touch request rejects explicitly;
  original callers invoke pickup logic only for players.

No shared types, engine adapter, renderer, browser entrypoint, or external
telemetry service is changed by this workstream.
