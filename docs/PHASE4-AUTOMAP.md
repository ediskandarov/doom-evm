# Goal 4.5 — original DOOM automap

The port lives in `src/doom/am_map.sol` and `am_map_types.sol`. It follows
`original/DOOM/linuxdoom-1.10/am_map.c` and `am_map.h` at upstream
`a77dfb96cb91780ca334d0d4cfd86957558007e0`. Geometry transformation, clipping,
Bresenham rasterization, vector glyphs, rotation, state updates and patch drawing
all execute inside Solidity/Yul. JavaScript only transports inputs and checks
returned bytes. The map is north-up: original rotation applies to arrows and
thing triangles, not the map window.

This branch owns only new automap source, verification support, tests, fixtures
and evidence. Existing engine, video, renderer, Status Bar, HUD, Gameflow,
production adapters, compiler configuration, Frame ABI and Phase 0–3 evidence
are unchanged. Production adapter hookup remains integration-owned. No merge
into main or later Phase 4 goal is part of this handoff.

## Integration contract

Import `AM_Map`, `AutomapState`, `AMWorld` and the existing `VideoState`.

1. Call `AM_Init` once on a fresh state, then persist the complete state between
   calls. It initializes original process defaults (`followplayer=1`,
   `stopped=true`, initial scale .2, last episode/map -1). `AM_Start` detects
   episode/map changes and calls `AM_LevelInit`; same-level reopen retains
   scale, grid, follow, cheat and marks just as the original does.
2. Supply a fresh **live** `AMWorld` view for responder, ticker and drawer.
   Coordinates and floor/ceiling heights are signed 16.16 `int32`; angles are
   original unsigned 32-bit BAM. Vertices retain original order. Walls are
   linedefs in original index order, not BSP segs. Supply both sector heights
   and explicit `back=false` for a null backsector.
3. Copy linedef flags, including the current renderer's `ML_MAPPED=256` bit,
   without clearing them. Discovery remains owned by the existing renderer.
   `ML_DONTDRAW=128`, `ML_SECRET=32`, teleport special 39, sector differences,
   cheat level and `pw_allmap` control visibility/color in the port.
4. Supply all four player slots, `ingame`, invisibility power and console slot.
   On start, the original fallback picks the first active player if the console
   slot is inactive. `world.allmap` is the selected player's current allmap
   power. `netgame`, `deathmatch` and `singledemo` retain original player-display
   and cheat restrictions. Populate things in sector index / `snext` order;
   do not sort, deduplicate or filter the original thing lists. Block origins
   are the level's original `bmaporgx/y`, in 16.16 units.
5. Call `AM_Responder(s,world,eventType,data1)` with original events: keydown 0,
   keyup 1, other event types pass through. Use its boolean consumption result
   in the existing responder ordering. Call `AM_Ticker` once per game tic.
   Arrow pan is accepted only with follow disabled; releases return false.
   Follow rounding and follow-before-zoom-before-pan ordering are preserved.
6. Set `video.screens[0]` to the existing renderer's 64,000-byte framebuffer
   reference. Call `AM_Drawer` when active in place of the world drawer. It
   clears/renders only rows 0–167 and calls original `V_MarkRect`; rows 168–199
   remain available for status-bar composition. Other screen buffers are
   untouched. HUD/status composition and Frame emission remain caller-owned.
   The existing 320×200 Frame event and indexed palette stay unchanged.
7. Supply `bytes[10]` containing original `AMMNUM0` through `AMMNUM9` patches.
   `AM_drawMarks` uses the original hard-coded 5×6 admission test followed by
   the existing `V_DrawPatch`, including actual patch offsets, transparency,
   dirty marks and RANGECHECK policy. Load these resources via the existing
   resource reader when entering, hold through active use, and release/tag
   them when stopping. `loads/unloads` count these lifecycle requests, one
   request per complete set, rather than dereferencing C cache pointers.
8. Synchronize `s.message` with the selected player's message slot. Responder
   assignments are the original follow/grid/mark/clear English strings. Copy
   updates to that player's HUD message slot, and propagate consumer clearing
   back to `s.message`. The library does not call HUD or Status Bar.
9. `s.notification` exposes the last original status-bar event as
   `[type,data1,data2]`; process changes together with lifecycle requests.
   Enter is `[ev_keyup,0x616d6500,0]`. The original **AM_Stop initializer is
   `{0,ev_keyup,AM_MSGEXITED}`**, yielding `[ev_keydown,1,0x616d7800]`; the port
   preserves this quirk. Integration must deliberately handle this original
   event layout when connecting Status Bar rather than silently modifying the
   automap oracle. `viewactive` changes on Tab responder paths; direct
   `AM_Start/AM_Stop` do not change it. Direct stop also leaves big-state intact.

All library functions operate on caller-owned memory. The production adapter
must load and save this state through its existing persistence model; these
files introduce no storage slots in the production engine. Messages and last
notifications are state, not a queue; inspect changes after each responder call.
Load/unload counters distinguish repeated/reentrant start/stop calls, including
same-event Stop→Start sequences. Invalid empty geometry, missing active players,
invalid console indices or insufficient framebuffer backing are rejected instead
of reproducing undefined C pointer accesses. Valid original geometry is not
normalized or clamped beyond original window/zoom clamping.

| Input | Original behavior |
|---|---|
| Tab (9) | enter/exit automap; change viewactive |
| arrows (right ae, left ac, up ad, down af hex) | pan 4 framebuffer pixels/tic when follow is off |
| `=` / `-` | held zoom, original fixed multipliers 66846 / 64250 |
| `0` | toggle level overview, save/restore window |
| `f` / `g` | toggle follow / block-aligned grid |
| `m` / `c` | add center mark to 10-slot ring / clear marks |
| `iddt` | cycle normal→walls→walls+things→normal outside deathmatch |

Colors retain original palette indices: background 0, wall/secret 176,
teleporter 184, floor change 64, ceiling change 231, cheat two-sided 96,
unmapped allmap 99, grid 104, local player 209, crosshair 96, things 112.
Network player colors are 112/96/64/176; invisible players use 246. Special 39
precedes secret/floor/ceiling tests. The original light-update call in ticker
is commented out, so normal line colors do not pulse. The original light
helper remains available and native-tested separately.

## Verification and reproducibility

The native host mechanically removes only `#include` lines from `am_map.c`;
all original function bodies, globals, macros and vector glyphs are compiled
unchanged. Original `v_video.c`, `m_bbox.c`, `m_fixed.c`, `m_cheat.c` and
`tables.c` are separate unchanged translation units. Named-field host structs
replace unrelated engine headers. Cache/tag/Status Bar calls are observed by
host shims; `finecosine` uses the original `finesine+2048` pointer definition.
Each scenario runs in a fresh process to reset original statics.

22 scenarios produce 383 state snapshots and complete 64,000-byte frames.
O0, O2 and ASan/UBSan outputs agree exactly. The corpus includes authentic
Freedoom E1M1 linedefs/vertices/sector heights/block origin and all ten authentic
marker patches. Fixture discovery is seeded by linedef index modulo three;
it is not a capture of a played game. Both native and EVM consume identical
thing traversal order. Synthetic cases cover every wall visibility/color
branch, multiplayer/deathmatch/demo restrictions, nine BAM angles, cheat
reset/mismatch behavior, inactive input, panning, follow rounding, zoom clamps,
overview restore, reopen/new-level/direct stop, grid negative remainder, marker
ring overwrite/clear/sentinel, each clipping edge and direction, point lines,
128 deterministic random fixed-coordinate lines, and slope/light helpers.

Native comparisons assert intermediate state (66 words plus message), return
consumption, lifecycle requests, raw notifications, dirtybox and whole-frame
SHA-256 after **every action**, including actions with no drawing. Separate
Foundry assertions verify vector definitions remain immutable, inclusive
Bresenham endpoints and bottom-row protection (256 fuzz runs), renderer screen-0
aliasing, video composition and the frozen Frame ABI.

ASan/UBSan disables only signed shifts (original `FTOM` shifts negative values)
and variable-sized patch `columnofs` array-bound checks; process-lifetime fixture
allocations disable leak checking. Signed overflow remains checked in native
fixtures. Solidity explicitly narrows/uses unchecked original 32-bit arithmetic;
undefined-C arithmetic/pointers and arbitrary malformed WAD equivalence are not
claimed. Missing/malformed patches use the accepted Phase 4 video diagnostics.

Run from this worktree:

```sh
python3 tools/reference/automap/reference.py --check
forge test --match-path 'test/{unit/am_map,integration/AutomapVideo}.t.sol' \
  --skip Doom --skip GameplayProbe --skip RendererProbe --skip WadResourcesProbe -vv
forge build --contracts src/support/AutomapProbe.sol \
  --skip Doom --skip GameplayProbe --skip RendererProbe --skip WadResourcesProbe
node tools/reference/automap/evm.mjs
python3 tools/reference/automap/verify.py --check
```

The skips exclude unrelated build roots, not automap assertions. The receipt
runner refuses occupied ports, starts/stops only its own Anvil on default port
18745, deploys with ordinary CREATE, verifies every state/pixel digest, decodes
all 22 frozen Frame receipts, checks the bottom 32 rows, and mines a malformed
input revert with no logs/counter mutation. No host bitmap rendering is used.
Pinned compiler/EVM/budget remain unchanged; the dedicated probe includes
fixture decoding and original table code and uses the project's configurable
10-billion-gas development profile. Its measured gas includes test setup,
replay, hashing and events; it is not a production automap cost estimate.

Evidence is in `artifacts/phase4/automap-{verification,source-map,evm}.json` and
`test/fixtures/phase4_automap/native.json`. The source map binds all original
function spans and current Solidity files; verification checks those bindings,
fixtures, receipt compiler inputs and ownership relative to branch baseline
`9f98ed1d38e6de3f2577f5d76b07ec136fc70d52`.
The worktree began at `6d7630e`; its reflog records an external `merge main`
fast-forward at 2026-10-10 14:14:20 +0400 that brought in the completed Status
Bar integration. All automap work was still separate untracked additions. This
task did not perform that integration; final ownership checks preserve every
inherited tracked file at `9f98ed1`.
Full inherited regression and production browser acceptance are deferred to
final Phase 4, as requested. Goal 4.5 ends with verified feature-branch commits.
