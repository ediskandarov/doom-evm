# Porting map

Baseline: `original/DOOM/linuxdoom-1.10`, upstream `a77dfb96cb91780ca334d0d4cfd86957558007e0`. The complete static E1M1 renderer is implemented and matches all eight original-C world-view frames byte for byte. Phase 2 is accepted: ordinary deployment, Frame delivery, browser verification and every inherited regression gate pass. Gameplay remains Phase 3; see the [acceptance report](docs/PHASE2-REPORT.md).

| Upstream source | Solidity destination | Status and deliberate adaptation |
|---|---|---|
| `doomtype.h`, numeric declarations in `m_fixed.h` / `tables.h` | `src/doom/doomtype.sol` | Header scaffold: primitive int32/uint32 conventions, constants and explicit null sentinel. Arithmetic is implemented in m_fixed.sol and tested against original C vectors. |
| `doomstat.h` | `src/doom/doomstat.sol` | Persistent storage context scaffold; only uint64 gametic, wider than original C counter. No game logic. |
| `r_defs.h` | `src/doom/r_defs.sol` | Rendering-relevant vertices, sectors, nodes, sides, lines, segs, subsectors and raw things; pointers become checked indexes. |
| Renderer headers/globals | `r_state.sol`, `r_render_state.sol`, `r_sprite_state.sol` | View, draw, clip, plane, sprite and psprite contexts; [frozen interfaces](docs/PHASE2-INTERFACES.md). Paths are under `src/doom/`. |
| `m_fixed.c` | `src/doom/m_fixed.sol` | FixedMul, FixedDiv, FixedDiv2 ported. Signed narrowing/shift match pinned Clang. Exact rational implementation proven equivalent to defined binary64 results. abs(INT_MIN) widened magnitude and direct 0/0 error are documented extensions. |
| `tables.c`, `tables.h`; cosine alias in `r_main.c` | `src/doom/tables.sol` | Every original integer and SlopeDiv; generated scalar packed-word switches allocate no lookup buffers. [All-index proof and measurements](docs/PHASE2-TABLES.md). |
| `r_main.c` | `src/doom/r_main.sol` | Point/seg side, angles/distance/subsector, scale, texture/light/view setup, frame setup and R_RenderPlayerView. [Function mapping and domains](docs/PHASE2-GEOMETRY.md). Original pass order uses internal callbacks to avoid circular imports. |
| `r_data.c`, original WAD cache/name semantics | `src/doom/r_data.sol` | Texture/flat/sprite initialization, lookup/composite generation, columns and names. Lazy lookup changes timing, not validated outputs; eager validation remains. [Mapping and proof](docs/PHASE2-DATA.md). |
| `p_setup.c` map loaders and rendering part of P_GroupLines | `R_Data.R_LoadMap` | Explicitly attributed static loader adapter despite its resource-module placement; raw WAD decoding and sector associations. |
| `r_draw.c` | `src/doom/r_draw.sol` | Original column/low/translated/fuzz/span primitives, buffer setup, translations and video erase. [Native pixels and quirks](docs/PHASE2-DRAW.md). Border/background UI helpers are outside the full-screen view. |
| `r_bsp.c` | `src/doom/r_bsp.sol` | All original functions. Explicit traversal stack preserves enter/front/bbox/back order. [Eight traces and 1,120 clipping operations](docs/PHASE2-BSP.md). |
| `r_segs.c` | `src/doom/r_segs.sol` | R_StoreWallRange, R_RenderSegLoop, R_RenderMaskedSegRange. [Native wall pixels, branch/callback proofs and ordinary measurements](docs/PHASE2-SEGS.md). |
| `r_plane.c` | `src/doom/r_plane.sol` | All seven functions, including empty R_InitPlanes; original construction, caches, spans, sky and lighting. [117 native cases and eight snapshots](docs/PHASE2-PLANES.md). |
| `r_things.c` | `src/doom/r_things.sol` | All original functions: definition/rotation setup, pool, projection, collection/sort, masked posts, sprite clipping, psprites and masked pass. [Source and native proof](docs/PHASE2-SPRITES.md). |
| `info.c` static rendering fields | `src/doom/info.sol` | Mechanically exported original names, state sprite/frame pairs and mobj spawn-state/flags/dimensions. No visibility, actions or game ticks. `tools/reference/info/generate.py --check`. |
| P_LoadThings, P_SpawnMapThing/P_SpawnMobj, P_SetThingPosition rendering subset | `src/doom/p_setup_static.sol` | Declared medium-skill single-player static adapter: 209 E1M1 things, original flags/frames/placement and reverse sector insertion. No gameplay/collision/sound/actions. |
| `r_sky.c:R_InitSkyMap`, startup selection | `src/evm/DoomScene.sol` | E1M1 SKY1/F_SKY1 and original 100*FRACUNIT midpoint; camera derived from raw THINGS and EVM BSP lookup. Explicit orchestration adapter. |
| Original cross-module calls | `r_render_hooks.sol`, `src/evm/DoomRenderer.sol` | Genuine setup → clears → BSP/walls/collection → planes → masked walls/sprites/psprites; internal memory callbacks only. |
| `p_*.c`, other gameplay modules | Corresponding `src/doom/p_*.sol` etc. | Not started; M2/M3. |
| No C counterpart | `src/evm/Doom.sol` | Concrete authenticated static renderer; driver/consecutive-input checks, retained fuzz position and one indexed8 Frame event. Context setup is recreated in memory per transaction; no nonzero-button gameplay yet. |
| No C counterpart | `src/evm/WadResources.sol`, `ResourceStore.sol` | Directory and every ordered immutable runtime authenticated before storage writes. [Ordinary CREATE and corruption proofs](docs/PHASE2-SOURCE.md). |
| No C counterpart | `src/support/ResourcePlacement.sol` | Static WAD upload/read comparison: storage bytes versus immutable STOP-prefixed code. Ordinary CREATE, bounded memory-safe EXTCODECOPY. Experiment, not r_data adapter. |
| No C counterpart | `src/evm/FrameProtocol.sol`, `ResourceTypes.sol` | EVM transport/resource identity adapters. |
| Shape reference `r_segs.c:R_StoreWallRange` | `src/support/StackPressure.sol` | Synthetic experiment only. Named shape function/stub dependencies, intentionally not `r_segs.sol`; see stack report for every class of deviation. |
| No C counterpart | `src/support/FrameFixture.sol` | Synthetic EVM pixel generator; not an engine port. |

Module reports identify the pinned source, mapped functions, numeric/algorithmic differences, assembly proofs, C comparison commands and evidence. Shared header extensions and ABI changes go through the integrator. Historical isolated metrics remain bound to their original sources and must not be relabeled current full-frame costs. Measurement probes, StackPressure and FrameFixture are test support, not substitutes for production rendering.

## Progress

| Milestone | Status | Evidence | Divergences | Blockers |
|---|---|---|---|---|
| Phase 0 scaffold | passed | Build + context tests; frozen Solidity and JSON boundaries | Minimal headers, not full engine layouts | None |
| Event smoke | passed | `tools/transport/evidence/`, FrameEvent tests, browser readback | Synthetic palette/frame; no WAD | None |
| Stack-pressure spike | passed | `artifacts/phase0/stack-*` | Stubbed geometry/textures, toy arithmetic | None for spike; real renderer untested |
| C fixed math | passed | Original C fixtures, Foundry comparisons, rational proof in `tools/tables/NUMERICS.md` | Undefined C domains handled explicitly; no equivalence claim for extensions | None |
| Authenticated full WAD source | passed | [Source report](docs/PHASE2-SOURCE.md), every runtime/corruption check and actual production deployment | Immutable code/resource adapter | None |
| BSP walls render | passed | [Wall report](docs/PHASE2-SEGS.md), eight native-matching ordinary calls and wall-only Frame receipt | Intermediate wall-only scope | None |
| M1 full static frame | passed | Eight bytewise full-frame comparisons, production Frame/WS/Canvas, 196 tests and all prior gates; [report](docs/PHASE2-REPORT.md) | Static full-screen world view | None for declared static scope |
| M2 movement | not started | — | — | M1 |
| M3 basic gameplay | not started | — | — | M2 |

The full-frame target is the pinned Freedoom 0.13.0 E1M1 player start, stationary floor+41 camera clamped to ceiling−4, medium-skill single-player spawn states, tic zero, high detail and 320×200. Eight ANG45 headings match native pixels. Floors, ceilings, sky, walls, masked textures and world sprites are included. Weapon/HUD overlays are inactive in this scene; active psprite algorithms have separate original-C pixel proofs. Static equivalence is not a gameplay or FPS claim.

The native engine uses declared LP64 disk/pointer/alignment and sentinel-object adapters. O0/O2 and ASan/UBSan agree under the pinned -fwrapv profile; strict C undefined domains remain audited. Solidity retains original clipping tails, negative-origin composite behavior, stale wall steps, zero-height plane caches and low-detail drawing quirks. Bounds and undefined arithmetic domains have explicit per-module handling; original drawseg exhaustion returns and sprite exhaustion uses an overflow sink, while fixed-math extensions are documented separately. Every production memory-safe block states its bounded allocation proof; packed table extraction uses stack operations only. Dedicated measurement probes use source-mapped ordinary GAS→MSIZE replacements with equal outputs/gas; production does not patch instructions. Allocator positions are not MSIZE.

Source and resource license provenance remain separate. Permitted Freedoom fixtures carry their BSD license; the full WAD remains a checksum-verified local download.

## Phase 1 non-Solidity mapping

- `tools/reference/reference.py` retains Phase 1's original numeric/table/geometry oracle. Phase 2 extensions mechanically extract more original functions or compile original full translation units; source spans, hashes, compiler semantics and host adapters remain explicit.
- `tools/wad/wad.ts` packages original lump bytes and validates resource relationships. Runtime EVM adapters now decode and consume those bytes; no camera-specific visibility or projection is precomputed.
- Browser code validates identity, decodes Frame events and expands palette indexes to Canvas RGBA. Production visibility, projection, lighting and indexed pixel writes execute inside the EVM.

See the historical [Phase 1 report](docs/PHASE1-REPORT.md) and current [Phase 2 ledger](docs/PHASE2-REPORT.md).
