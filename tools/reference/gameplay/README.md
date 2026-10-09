# Original C gameplay oracle

Run `python3 tools/reference/gameplay/verify.py --check` to reproduce committed fixtures. Omit `--check` to intentionally regenerate them. No upstream file is edited. This is independent native evidence, not Solidity M2/M3 acceptance.

The build compiles the actual original renderer and all gameplay translation units (`p_user`, `p_tick`, `p_mobj`, `p_map`, `p_maputl`, `p_sight`, `p_pspr`, `p_inter`, `p_enemy`, and every sector/switch/teleport module), with original `info.c` action pointers, `d_items.c`, `m_random.c`, and `z_zone.c`. Full original `P_SetupLevel` loads BLOCKMAP, REJECT, collision sector line lists, things, and special thinkers. The former static renderer's action stubs, geometry-only setup and stationary camera are not used.

The pinned original checkout, compiler/target and numerical flags remain those in `tools/reference/reference.py`. Every original header/unit is hashed. The adaptation manifest records the existing renderer LP64 patches, additional `P_GroupLines` pointer-array sizing, original zone allocation alignment from four to eight bytes for LP64 pointer-bearing blocks, mechanically extracted original `G_PlayerReborn`/exit functions, and observation hooks. Host `I_ZoneBase` allocates a fixed 64 MiB zone; original zone tags, purging, block reuse, owner clearing and lazy thinker removal remain active. `P_RunThinkers`' next-pointer read after `Z_Free` remains inside the actual zone allocation, as in the original engine.

All scenarios run at O0, O2, O2 ASan/UBSan, and O2 ASan/UBSan with every newly allocated payload filled `0xa5`. Profile output must agree byte-for-byte, including complete logical world states and all 64,000 pixels of each selected live frame. Sanitizer leak checking is disabled because the engine owns its zone until process exit. Original source compiler warnings are retained in build logs; the original questionable expressions are not silently corrected. These are pinned implementation-profile goldens, not universal ISO C definedness claims.

## Input and host profile

Commands are text rows `forwardmove sidemove angleturn buttons render`, representing one original `ticcmd_t` and one original `P_Ticker`. `render=1` captures `R_RenderPlayerView` after that tic. `gametic` increments once outside `P_Ticker`, matching the original outer game loop. Commands are observation/test inputs; they do not contain geometry or rendering results. Browser key conversion is separately verified against `G_BuildTiccmd`.

The host is medium-skill single-player E1M1, retail DOOM, with no menus, networking, save/load, demo, sound or wall-clock scheduling. `G_Ticker`'s menu/intermission/network/demo layers are bypassed; the original gameplay ticker runs directly. Normal command scenarios do not request special save/pause buttons. Player psprites are rendered by the real original masked pass; there is no status bar/HUD. UI/haptic/platform callbacks are no-ops. Original exit actions set `gameaction` but intermission/map transitions are not simulated. The omitted audio/HUD routines normally consume cosmetic `M_Random`; its index remains zero in this declared profile. Gameplay `P_Random` remains a separate original stream, including spawn-time draws. Gameplay noise propagation remains the original `P_NoiseAlert`, independently of audio output.

Ordinary scenarios use untouched original E1M1 spawning. Arena scenarios explicitly add one original possessed actor 64 units east of the real player start, validate with original `P_CheckPosition`, target the player and enter the original see-state. Damage gives green armor 100; death starts both player health fields at 3. These are controlled initial conditions on real geometry, not claims of a natural unmodified playthrough. The `door-use` scenario sets the original `nomonsters` flag before setup to prove an unobstructed full open/wait/close cycle. `door-obstructed` retains all original monsters and proves the original closing-door reversal. Both use original `P_TeleportMove` to `(832,576)`, facing south at real line 55, then sends held use. Scenario `setup.json` records this provenance.

## Observation format

`ticks.bin` contains fixed big-endian signed 32-bit player summaries, including the initial state. `manifest.json.playerTraceFields` is the exact column order; angles are uint32 bit patterns represented as signed words. `verify.py.player_records` decodes the same bytes for inspection. The redundant expanded JSON traces are not committed.

Every tic also produces a pointer/padding-free DSG1 logical world record. `observe.h` specifies field order: player fields and psprites; original thinker list order; actor coordinates/momentum/states/health/AI/target/tracer and sector/block links; typed special thinkers; mutable sectors/lines/sides; block heads; buttons; active platforms/ceilings; resource translation arrays; logical respawn queue; both random indices. Thinker IDs are monotonically assigned by a read-only hook at original `P_AddThinker`. Address reuse resolves to the newest observed thinker identity. Zero is NULL; -1 is the thinker sentinel. Original states and map objects use original table/array indices.

Original special objects intentionally leave some unused fields uninitialized. Logical observation records `INT32_MIN` for inactive platform count/oldstatus, door topcountdown, ceiling olddirection and floor texture/newspecial. Their actual bytes are read only when the original algorithm can use the field (waiting/stasis or relevant floor type). No original field is initialized or modified to make the oracle pass. Alternate allocation fill found and verified this distinction.

`states.delta.bin.gz` retains every exact canonical world record in a compact reversible format. After gzip decompression, each record is a big-endian byte length followed by XOR with the preceding reconstructed record, zero-extended or truncated to the current length. `verify.py.delta_decode` reconstructs the original length-prefixed stream; each encoded stream is round-trip checked. `state-hashes.json` binds every tic to its full reconstructed record SHA-256. No state hashes alone are used to claim EVM equivalence.

`diagnostics.bin` separately records length-prefixed original transient collision globals: tic, shared validcount, tmthing ID, flags/coordinates/bbox, floatok, contacted floor/ceiling/dropoff, ceilingline, spechit order, line/shoot targets, shoot height/damage/range/aim and sight slopes. Renderer traversals also change validcount, so these diagnostics are excluded from the logical-world digest. `events.json` counts original function entries, including gameplay action routines. Entry counts support coverage investigation; state changes and pixels provide stronger behavior evidence.

## Acceptance evidence and remaining scope

The native cases provide reproducible movement/collision/lift/pickup traces, firing/psprites/RNG, controlled monster chasing/attacks/pain/death, armor damage, player death, and a real held-use door cycle. Native output is a reference to compare against Solidity, never an EVM simulation input. The integrator must verify the same initial conditions and input sequences through EVM transactions, persistent state and emitted Frame bytes, with all existing Phase 0/1/2 gates retained. Source-level feature coverage must explicitly distinguish implemented versus exercised weapons, monster species/actions, keys/pickups, doors/lifts/floors, teleporters/crushers, death/exit behavior and omitted UI/gameflow. These initial scenarios do not by themselves exercise every original action or establish M2/M3 completion.

## Exact post-render state boundary

The original snapshots above precede selected rendering. R_RenderPlayerView
sets original ML_MAPPED line flags, so a final persisted EVM snapshot must be
compared to original state after the selected render. A separate observation-only
`post_render_host.c` wrapper calls the actual renderer and then the same DSG1
observer. It changes no engine state or original source.

`python3 tools/reference/gameplay/post_render.py --check` reproduces all 24
selected post-render states across O0/O2/ASan and alternate allocation fill, and
checks that every original pre-state, diagnostic, event, summary and frame byte
remains unchanged. [Post-render fixtures](../../../test/fixtures/gameplay_post/manifest.json)
retain exact compressed records; the [checkpoint](../../../artifacts/phase3/post-render-reference-checkpoint.json)
binds the scope. The runner compares final persisted state against these exact
post-states, with no masked fields. Native observation evidence does not imply
EVM acceptance until the corresponding comparison run passes.
