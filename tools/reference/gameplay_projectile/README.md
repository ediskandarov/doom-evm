# Bounded original rocket-world scenario

The host includes the frozen gameplay host unchanged. It wraps the actual original P_SetupLevel once, then applies a controlled setup through original objects and functions: spawn one possessed enemy 64 map units east of the actual E1M1 player; check its position; set ANG180, target the player and enter its original see state. The player faces east with blue armor200, missile weapon owned/ready, no pending change, six missiles and original P_SetupPsprites. Ordinary argv avoids the original host's other scenario branches.

Inputs are 35 idle tics, 80 held-fire tics, then 35 idle tics. All 150 original ticks run original collision, missile, AI, weapon, damage, death and thinker removal functions in actual E1M1 geometry. Selected original frames are tics1 (weapon rising),35 (raised),44 (live rocket),49 (explosion),65 (first rocket removed),115 and150. The full DSG1 snapshot precedes each selected render; a separate exact snapshot immediately follows it. Original ML_MAPPED and renderer state effects are retained.

O0, O2, ASan+UBSan and ASan+UBSan with allocation fill0xa5 agree on all exported tick/state/diagnostic/frame/event/post-render bytes. Additional observation-only function-entry counters expose actual P_SpawnPlayerMissile, P_ExplodeMissile, P_RadiusAttack and P_KillMobj. A separate pointer-free argument timeline observes both boundaries of actual P_RadiusAttack and each P_DamageMobj entry. Its nesting distinguishes radius-traversal damage from direct missile or monster damage, retaining original target/source identities, requested damage, actor types and health before the call. Canonical thinker observations show rocket flight, explosion states, deferred removal and the enemy kill. Some later missile spawns immediately collide and need not persist to the next snapshot; the entry counters retain those actual calls.

This fixture is comparison-only evidence for a bounded native scenario. It supplies neither runtime gameplay decisions nor pixels. It does not by itself certify EVM or production acceptance. Original source adaptations and compiler profile are inherited unchanged from the frozen gameplay oracle; the manifest separately binds the new wrapper and observation hooks.

Generate: `python3 tools/reference/gameplay_projectile/reference.py`

Reproduce: `python3 tools/reference/gameplay_projectile/reference.py --check`

`states.delta.bin.gz` uses the frozen gameplay XOR encoding. `post-render.bin.gz` contains repeated BE32 gametic/length plus exact DSG1 payload. The named actor evidence is derived programmatically from those pointer-free canonical snapshots.
