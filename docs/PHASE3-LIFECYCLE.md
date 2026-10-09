# Phase 3 player and actor lifecycle fidelity

This checkpoint covers all five active original `p_user.c` definitions, all sixteen active `p_mobj.c` definitions, and original `G_PlayerReborn`, `G_ExitLevel`, and `G_SecretExitLevel`. It preserves the previously verified keyboard `G_BuildTiccmd` behavior. This is isolated lifecycle evidence, not M2/M3 or whole-original-DOOM acceptance.

`tools/reference/phase3_lifecycle/reference.py` compiles the complete pinned original `p_user.c` and `p_mobj.c` translation units without gameplay body edits. Original state/info tables, fixed arithmetic, angles, RNG and mechanically extracted original sector/block link helpers remain active. Three game lifecycle bodies are mechanically extracted from the pinned `g_game.c`. Every original source/header, extraction, harness and compiler profile is hash-bound in the manifest.

Neighbor collision/aim/slide/weapon/special callbacks are explicit observing test doubles. All original state callbacks are represented by observing thunks: their invocation/order and state-walker effects are checked independently of enemy/weapon algorithms. Private deterministic state slots 900–902 form a zero-tic chain and can exercise a callback that changes tics or recursively selects another state. This controlled table mutation is documented fixture setup, not an edit to original algorithms. Independent enemy, weapon, collision and whole-world native proofs cover those neighboring modules separately.

The native comparison invokes every one of the 24 covered definitions across 784 controlled cases. O0, O2, ASan/UBSan O2, and alternate `0xa5` allocation-fill outputs agree exactly under the pinned compiler and existing `-fwrapv` profile. The retained [undefined audit](../test/fixtures/phase3_lifecycle/undefined-audit.json) deliberately runs full UBSan without `-fwrapv` and records eight original negative-shift failures in turning, spawning/respawn and effects/projectiles. Signed narrowing and negative-shift behavior retain the explicit implementation-profile policy; these are not universal ISO C definedness claims. Source-undefined cases such as invalid table indices or unknown original mapthing types are not used to assert native equivalence.

All 24 lifecycle Solidity tests passed in integrator run 52538. After correcting the positive aged-item-respawn fixture, its affected test passed again in run 9411 (624,476,097 gas). Native row 783 now creates two actors and advances the full queue tail from 1 to 2. That broader run also contained an unrelated world-specials failure; these results claim only the lifecycle scope.

The snapshot preserves complete player state for all four slots, actor positions/momentum/state/RNG/targets/links/spawnpoints/lazy-removal status, sector and block heads, starts, the complete item-respawn queue, exit state and ordered boundary calls. A record includes its exact inputs and output words. Synthetic repeated unit calls increment original tic counters once per call; they do not invoke the entire `G_Ticker`/network/menu loop or refresh its command buffer. The clock is deterministic, with original 35-tic durations in respawn and gameplay tests.

## Coverage

| Family | Implemented and compared | Current proof scope |
| --- | --- | --- |
| Player movement/view | Thrust, CalcHeight, MovePlayer | Original fixed thrust, turn and ground checks, bob/cap/height/clamp behavior, airborne clamp overwrite |
| Player thinking/death | DeathThink, PlayerThink | Attacker-facing death turn, lowered viewpoint/use-to-reborn, reactiontime, preseeded onground both true/false, chainsaw forced command, held-use suppression, special buttons/sector calls, weapons, powers and colormaps |
| State/momentum | SetMobjState, ExplodeMissile, XYMovement, ZMovement, MobjThinker | Zero-tic chains and recursive callbacks, positive-only subdivision, stopspeed/friction/no-momentum, sky removal, gravity/float/skull/missile boundaries, state cycling and nightmare gates |
| Actor spawn/remove | SpawnMobj, RemoveMobj, NightmareRespawn, RespawnSpecials | Spawn without initial action, original RNG/reaction/state flags, floor/ceiling spawn, actual original block/sector linking, lazy removal, item exclusions/ring wrap, timed queue respawn, corpse replacement/fog/spawnpoint inheritance |
| WAD/player spawn | SpawnPlayer, SpawnMapThing | Reborn stats preservation, slot/translation/card behavior, deathmatch starts, difficulty/multiplayer/deathmatch/no-monsters filters, randomized initial tics and kill/item counters |
| Effects/projectiles | SpawnPuff, SpawnBlood, CheckMissileSpawn, SpawnMissile, SpawnPlayerMissile | Original draw order/negative spread, blood state thresholds, half-step collision, fuzzy targets, missile vectors and aim retry/fallback behavior |
| Game lifecycle | PlayerReborn, ExitLevel, SecretExitLevel | Full reset with preserved frags/counts, original default inventory/ammo, completed action, commercial MAP31 existence rule |

The tests isolate callers from controlled neighboring subsystems. They do not by themselves establish natural gameplay trajectories, real collision acceptance, rendering, all engine storage round trips or all combinations of original input domains. The integrator must preserve full-game shared scratch state across transactions: `P_PlayerThink` can skip `P_MovePlayer` during reactiontime while `P_CalcHeight` reads the previous `onground` value. Static renderer caches, original actor lists and mutable world state also require their independent integration gates.

No production gameplay algorithm has been replaced by a reference trace. Accepted input semantics remain intact; engine/frame acceptance requires the separate EVM versus whole-original-C state/frame comparisons and all retained Phase 0/1/2 gates.
