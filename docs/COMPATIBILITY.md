# Compatibility and completeness

This is a bounded release audit of integrated revision
`1b728fe3f8307a49f71437d5af75a4935df81492`. It combines source/call-path inspection
with existing certificates. It is not a new full-engine acceptance run.
The [release report](release/READINESS.md) lists checks actually rerun.

## Game profiles

| Profile | Admitted resources | Demonstrated coverage and limits |
|---|---|---|
| Freedoom 0.13.0 Phase 1 | Pinned `freedoom1.wad`; Episode One, E1M1–E1M9 | Nine-map resource/startup proofs, standalone episode replays and production UI/gameflow integration. Full historical Phase 0–3 acceptance uses its frozen E1M1 profile. |
| Ultimate DOOM 1.9 | Exact locally supplied `DOOM.WAD`; Episode One, E1M1–E1M9 | Nine standalone accepted full presentation recordings; browser map/skill selection and bounded gameplay/exit checks. This is not an uninterrupted full-episode browser playthrough. |
| DOOM II 1.9 | Exact locally supplied `DOOM2.WAD`; MAP01–MAP32 selectable | All 32 maps pass medium-skill startup comparison. Complete recorded gameplay/render replays cover MAP01 and MAP07. This does not establish complete gameplay or pixel acceptance for all 32 maps. |

Commercial IWAD MD5 identities: Ultimate `c4fe9fd920207691a9f493668e0a2083`;
DOOM II `25e1459ca71d321525f84628f45ca8cd`. Resource and SHA-256 bindings are
checked separately by the installer. Rerelease files, arbitrary mods/PWADs,
other episodes and other IWAD versions are not admitted merely by renaming them.
[Browser handling](browser-deployment/README.md).

## Source and acceptance matrix

“Verified” below means finite evidence in the linked profile, not every possible
input or every original C branch. “Available” describes production reachability.

| Area | Current source path | Status and evidence |
|---|---|---|
| Fixed math, tables, RNG | `m_fixed.sol`, `tables.sol`, `m_random.sol` | Original numerical behavior with declared native/compiler domains; [foundation](PHASE1-REPORT.md), [all-index tables](PHASE2-TABLES.md) |
| BSP, walls, planes, sprites, weapons | `r_*.sol`, `DoomRenderer.sol` | EVM indexed rendering; eight native-exact static views and finite gameplay frame proofs; [renderer](PHASE2-REPORT.md), [gameplay](PHASE3-REPORT.md) |
| Movement, collision, weapons, damage, AI and world specials | `p_*.sol`, `DoomGame.sol` | Available and finite module/world verification; historical audit maps 238 active gameplay C definitions (231 named plus seven delegated loaders), not whole-program completeness; [function matrix](PHASE3-FEATURE-MATRIX.md) |
| Status Bar, face, HUD, palette feedback | `st_*.sol`, `hu_*.sol`, `DoomUI.sol` | Available, with original-C state/pixel/palette and production UI evidence; [Status Bar](PHASE4-STATUSBAR.md), [UI integration](PHASE4-UI-INTEGRATION.md) |
| Automap and keyboard cheats | `am_map.sol`, `m_cheat.sol`, `st_cheats.sol` | Available within admitted maps/modes; [automap](PHASE4-AUTOMAP.md), [cheats](PHASE4-CHEATS.md) |
| Keyboard and pause | `g_game.sol`, `InputProtocol.sol`, `web/input*.mjs` | Sequenced original responder/ticker input; [input acceptance](PHASE4-INPUT-RUNTIME.md). Mouse, joystick and chat frontends absent. |
| Menus and Options | `m_menu.sol`, `DoomMenu.sol` | Original-style menus, Messages, End Game and supported view sizes 10/11; map/skill selector is an EVM extension; [Options](OPTIONS-LEVEL-SELECTION.md). Smaller views, Low Detail control, mouse sensitivity, help/quit/attract-mode completeness and F11 gamma control are not claimed. |
| Death and respawn | `EpisodeRuntime.sol`, `g_game.sol` | Original single-player death/rebirth dispatch integrated; [death/save combined proof](DEATH-SAVE-LOAD-INTEGRATION.md) |
| Save/Load | `p_saveg.sol`, `DoomSave.sol`, `SaveSchema.sol` | Six-slot **Exact EVM Snapshot**, an intentional noncanonical archive/timing adaptation. Original save-file compatibility, lossy state semantics and engine migration absent; [save report](SAVE-LOAD.md), [canonical research](SAVE-LOAD-CANONICAL-DISCOVERY.md) |
| Normal/secret exits and intermission | `g_game.sol`, `wi_stuff.sol`, `EpisodeRuntime.sol` | Source-derived flow with bounded native/EVM/browser checks; [Episode integration](PHASE4-EPISODE-COMPLETION.md), [DOOM II](doom2/REPORT.md). Standalone recordings end before next-level startup; they do not prove that transition. |
| Finales | `f_finale.sol` | E1 text/art and supported DOOM II text branches. MAP30's cast sequence explicitly reverts as unsupported. Other episodes' finales absent. |
| Melt wipe | `f_wipe.sol`, `FullSpeedrunProbe.sol` | Original-C/EVM recording and component proof; **not in the production browser contract import closure**. [Recording/integration limits](FULL-VIDEO-OPTIONS-INTEGRATION.md) |
| Demo playback | `tools/reference/*speedrun*/` | Authentic recorded commands replay through EVM observation consumers. Original in-game demo loader/recording/attract loop is not a production feature. |
| Sound, music, multiplayer | Gameplay branches retain relevant semantics | Intentionally out of scope. Gameplay noise propagation and RNG order do not imply audio output or network play. |

The [porting map](../PORTING.md) identifies C modules, functions, host adapters
and per-module evidence. Original `linuxdoom-1.10` is pinned at
`a77dfb96cb91780ca334d0d4cfd86957558007e0`; original C and goldens are unchanged.
No engine algorithms were modernized during release preparation.

## Memory profiles

| Policy | Meaning | Fidelity boundary |
|---|---|---|
| 0 | Strict known backing | Unknown/unproven bytes reject; no assumed initial zone bytes |
| 1 | Deterministic initialized zone | Explicit initial-byte assumption; not arbitrary native heap contents |
| 2 | Initialized zone plus bounded pointer-high bytes | Historical Episode/default policy; only the declared native address-domain assumptions |
| 3 | Experimental virtual zone and authenticated lumpcache owner-slot pointers | Explicit browser selection for all three games; deterministic addresses differ from real native process addresses |

The default Solidity policy remains 2; the browser explicitly requests 3 through
the appropriate game initializer. No policy turns unknown memory into arbitrary
fallback pixels. Bounds, topology, owner identity and unknown-byte guards remain.
Strict/other policies remain useful diagnostic profiles and are not removed.

[`z_zone_virtual.sol`](../src/doom/z_zone_virtual.sol) models validated current
zone links and proven lumpcache owner slots in distinct deterministic address
domains. Other pointer fields, native padding and unproven memory are outside
that proof. A virtual-derived pixel can numerically match a native pixel while
still lacking universal native address equivalence. Likewise, a source-written
integer byte is not automatically independent of allocation history.

Native claims are restricted to recorded LP64 layout, compiler flags, initialized
memory, UI-resource borrowing and renderer/display-history profiles. The pinned
C itself has implementation-dependent and undefined domains; agreement under
O0/O2/sanitizers does not erase them. See the [native memory audit](PHASE4-NATIVE-MEMORY-AUDIT.md),
[virtual-pointer experiment](EXPERIMENTAL-VIRTUAL-POINTERS.md) and
[owner-slot proof](ULTIMATE-OWNER-POINTERS.md).

## What the recording numbers establish

The accepted Ultimate E1 suite contains **14,475 gameplay tics**, **14,484 exact
canonical gameplay snapshots**, and **18,175 EVM-generated presentation frames**.
Of those frames, **18,173 complete indexed framebuffers match the declared native
profile**. Two contain declared virtual-derived destinations; 25 direct virtual
samples occur in 11 frames, including samples whose resulting values match.
All nine final framebuffers match. [Certificate](../artifacts/full-videos/acceptance.json),
[native scope and metrics](ULTIMATE-FULL-VIDEOS.md).

The media is encoded at 35 FPS, totaling 519.285714 seconds. Measured processing
totals 18,795.220818 seconds across maps; rendering RPCs yield 1.094161 emitted
frames per summed RPC second. These sums include transport/mining/polling,
are not exclusive EVM CPU time, and are not a concurrent wall-clock benchmark.
Recorded gas totals **18,947,598,824,099**, including the observation workload.
Those historical costs are not a current-browser performance promise.

Receipt-authenticated EVM pixels, Canvas equality, canonical gameplay-state
equality and native-exact framebuffers are distinct checks. A passed Canvas
comparison establishes faithful display of EVM output, not native renderer
equivalence. See [verification and reproduction](DEVELOPMENT.md).
