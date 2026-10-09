# Phase 2 interface freeze

Frozen before Batch 2A implementation, 2026-10-09. Baseline: Phase 1 `cd6836f`.
Upstream `a77dfb96cb91780ca334d0d4cfd86957558007e0`; the existing pinned Freedoom resource identities, native compiler profile, numeric contracts and Frame v0 remain authoritative.

## Scope and completion gates

Phase 2 includes **all** implementation-plan section 5: Batch 2A geometry/data/draw, Batch 2B BSP/segs and a C-compared wall frame, Batch 2C planes/sprites/orchestration, and the full static M1 event-to-browser gate. Passing 2A alone does not complete Phase 2. Gameplay remains Phase 3. Every integration gate requires native source comparisons, bounds/edge tests and real EVM gas/memory measurements. Phase 0 and Phase 1 runners remain required, without weakening their assertions.

## Numeric and map ABI

`r_defs.sol` freezes `Vertex`, existing `Sector`, `Node`, `Side`, `Line`, `Seg`, `Subsector`, `MapThing`, `MapData`. Coordinates are original signed 16.16 int32. Runtime references are uint32 indexes, with `0xffffffff` NULL. Raw BSP children remain uint16 with bit `0x8000`. Bounding boxes are `[top,bottom,left,right]`, nested node boxes `[child][coordinate]`. Disk values are decoded explicitly little-endian. Loader operations equivalent to p_setup.c must retain that attribution; rendering helpers belong to their defining original C files.

## Geometry API (`library R_Main`)

Internal pure functions:

- `R_PointOnSide(int32 x,int32 y,Node memory node) returns (uint32)`.
- `R_PointOnSegSide(int32 x,int32 y,Seg memory seg,MapData memory map) returns (uint32)`.
- `R_PointToAngle(RenderState memory rs,int32 x,int32 y) returns (uint32)`.
- `R_PointToAngle2(RenderState memory rs,int32 x1,int32 y1,int32 x2,int32 y2) returns (uint32)`; preserve mutation of viewx/viewy.
- `R_PointToDist(RenderState memory rs,int32 x,int32 y) returns (int32)`.
- `R_PointInSubsector(int32 x,int32 y,MapData memory map) returns (uint32)`; reject invalid children/cycles rather than hang.
- `R_ScaleFromGlobalAngle(RenderState memory rs,uint32 visangle,uint32 rw_normalangle,int32 rw_distance) returns (int32)`.
- `R_InitTextureMapping(RenderState memory rs)` and `R_InitLightTables(RenderState memory rs)`.
- `R_SetupFrame(RenderState memory rs,int32 x,int32 y,int32 z,uint32 angle,int32 extralight,int32 fixedcolormap)` replaces player/global indirection, no simulation. `fixedcolormap=-1` means NULL.
- `R_ExecuteSetViewSize(RenderState memory rs,uint32 blocks,uint32 detail)` implements original supported sizes and setup arrays; call original-mapped buffer setup in r_draw once integrated. Until then a private adapter with identical offsets is allowed and must be removed at integration.

Original uint32 angle wraps are explicit. Signed-overflow/shift extensions must be distinguished from defined-C equivalence and audited against the native profile. No regenerated floating trig.

Reviewed amendment: retain setup side effects `pspritescale`, `pspriteiscale`, `screenheightarray`, `scalelightfixed`, `framecount`, `validcount`, `sscount` in RenderState. Integration initializes original `validcount=1` before first setup; counters use explicit uint32 wrapping as a deterministic extension beyond the signed C overflow domain.

## Render state / drawing API

`r_state.sol` adds only Batch 2A fields to the existing context. `width,height` are logical view dimensions; `scaledviewwidth` includes detail doubling. The physical screen/framebuffer is always 320x200 for M1. `R_InitBuffer` sets offsets into that physical framebuffer; `center*` and projection match r_main. Existing Phase 0 tests can continue to use small standalone context byte buffers.

`DrawColumn`/`DrawSpan` replace original dc_*/ds_* globals; all calls take memory references. `sourceOffset` replaces an interior byte pointer. Colormaps contain 256 byte indexes; all source/destination addresses are checked. The draw APIs are `R_DrawColumn`, `R_DrawColumnLow`, `R_DrawTranslatedColumn` `(RenderState,DrawColumn)`; `R_DrawFuzzColumn(RenderState,DrawColumn,bytes colormaps)`; `R_DrawSpan`, `R_DrawSpanLow` `(RenderState,DrawSpan)`; `R_InitBuffer(RenderState,uint32 width,uint32 height)`; `R_InitTranslationTables() returns(bytes)`; `R_VideoErase(RenderState,bytes backscreen,uint32 ofs,uint32 count)`. Library name `R_Draw`; internal pure. Preserve original low-detail quirks and side effects, with explicit safety rejection where original would overrun. Fuzz position is per-state. Border/UI helpers beyond the full-screen static view can be documented separately; no fake substitute output.

## Resource access API

`r_data_types.sol` freezes `ResourceView`, `TexPatch`, `Texture`, `RenderResources`, `ColumnView`. Resource bytes live in ordinary deployed STOP-prefixed runtime code chunks of 16384 bytes (last chunk may be shorter). Offsets address the original Phase 1 contiguous bundle, not a new camera-dependent format. `ColumnView.data[offset]` replaces a returned pointer, keeping post prefix available for masked drawing. No visibility data is supplied by the host.

`library R_Data` APIs (internal view unless pure is possible):

- `read(ResourceView,uint32 offset,uint32 length) returns(bytes)` and `W_CacheLumpNum(ResourceView,uint32 lump) returns(bytes)` perform bounded copies across chunks.
- `W_CheckNumForName(ResourceView,bytes8 name) returns(int32)` and `W_GetNumForName(ResourceView,bytes8 name) returns(uint32)` preserve last-match WAD lookup semantics.
- `R_InitData(ResourceView) returns(RenderResources)` performs original static texture/flat/sprite/colormap initialization.
- `R_GetColumn(RenderResources,uint32 texture,int32 column) returns(ColumnView)` preserves width-mask and direct-patch/composite branch behavior.
- `R_CheckTextureNumForName(RenderResources,bytes8) returns(int32)`, `R_TextureNumForName(RenderResources,bytes8) returns(uint32)`, `R_FlatNumForName(RenderResources,bytes8) returns(uint32)`.
- `R_GetFlat(RenderResources,uint32 flat) returns(bytes)` is an EVM convenience equivalent to W_CacheLumpNum(firstflat+flat).
- `R_LoadMap(RenderResources,bytes8 mapname) returns(MapData)` is an explicitly attributed p_setup static-loader adapter, not original r_data renderer logic.

Original `R_GenerateLookup`, `R_GenerateComposite`, `R_DrawColumnInCache` remain traceable in r_data. Undefined/uninitialized composite holes must be identified rather than mislabeled faithful output. Immutable blob deployment support belongs in `src/evm/ResourceStore.sol`.

Measured amendment: eager original-style initialization consumed 894,291,835 gas and advanced the allocator to 10,044,000 bytes on the pinned full WAD. Retain eager `R_InitData` for verification; add `R_InitDataLazy(ResourceView) returns(RenderResources)` which defers each original `R_GenerateLookup` until first column use. This changes initialization timing, not column values; malformed textures must still be caught by eager deployment validation. Add `bytes[] lumpcache` to RenderResources to preserve original W_CacheLumpNum reuse within a frame. Exact-name indexes may accelerate lookups only while preserving name normalization, first/last match and collision resolution. Eager/lazy/native equality and fresh cost measurements are required before accepting the optimization.

## Ownership and integration

Integrator owns shared structs, interfaces, schemas, foundry config, Doom glue, deployment/full-renderer oracle and all cross-module integration. Three isolated worktrees own:

1. Geometry: `src/doom/r_main.sol`, `test/unit/r_main.t.sol`, `tools/reference/phase2_geometry/**`, `test/fixtures/phase2_geometry/**`, `docs/PHASE2-GEOMETRY.md`.
2. Resources: `src/doom/r_data.sol`, `src/evm/ResourceStore.sol`, `test/unit/r_data.t.sol`, `tools/reference/phase2_data/**`, `test/fixtures/phase2_data/**`, `docs/PHASE2-DATA.md`.
3. Drawing: `src/doom/r_draw.sol`, `test/unit/r_draw.t.sol`, `tools/reference/phase2_draw/**`, `test/fixtures/phase2_draw/**`, `docs/PHASE2-DRAW.md`.

Native extensions import/reuse the existing reference harness and mechanically extract original functions; they may not rewrite the oracle algorithms. Existing Phase 1 fixtures/harness remain unchanged. Each delivery supplies exact upstream/source hashes, native and Forge commands, domain/deviation audit, memory-safe assembly proofs, gas and memory probes. No edits to shared types without an integrator-reviewed amendment. Later BSP/segs and plane/sprite contexts are frozen at their prerequisite integration gates, before those agents begin.

Reviewed test harness amendment: Foundry may read `test/fixtures` and `artifacts/local/wad`. Large pinned resource fixtures may use `vm.etch` in isolated unit tests only, with separate CREATE tests. Deployment and end-to-end gates must upload real code contracts using ordinary transactions, without `setCode`/`etch`.

## Batch 2B freeze: BSP, walls and visplane construction

`r_render_state.sol` freezes `ClipRange`, `DrawSeg`, `Visplane`, `WallState`, `RenderContext`. Batch 2A structs and APIs remain stable. The integrator owns this file. Context references map/resource/view state without copying their dynamic contents. All wall coordinate calculations and source comparisons use original int32/uint32 narrowing and explicit wrap where required. `rw_angle1` stores the original signed-int global's angle bits as uint32; conversions at original signed-use sites must be explicit.

- `library R_BSP`: `R_ClearClipSegs(ctx)`, `R_ClearDrawSegs(ctx)`; `R_RenderBSPNode(ctx,int32 bspnum,storeWall,addSprites)`, `R_Subsector(ctx,uint32 num,storeWall,addSprites)`, `R_AddLine(ctx,uint32 seg,storeWall)`, `R_ClipSolidWallSegment(ctx,int32 first,int32 last,storeWall)`, `R_ClipPassWallSegment(ctx,int32 first,int32 last,storeWall)`, `R_CheckBBox(ctx,int32[4] bbox) returns(bool)`. Here `storeWall` is `function(RenderContext memory,int32,int32) internal view`; `addSprites` is `function(RenderContext memory,uint32) internal view`. These memory callbacks replace original cross-module function references and prevent circular imports. The BSP trace test can supply observation-only callbacks; the integrated wall gate must wire the genuine R_Segs callback. Invalid BSP graphs must reject rather than loop.
- `library R_Segs`: `R_StoreWallRange(ctx,int32 start,int32 stop)` and `R_RenderSegLoop(ctx)` internal view; later masked range integration remains in this same module. Original drawseg exhaustion (256) returns without drawing. Clip arrays use logical x indexes; adjusted C pointers become full-width arrays (empty means NULL), never negative memory pointers. An int16 original store must narrow explicitly even though the transport uses int32 slots. Preserve MAXSHORT masked-column sentinel32767 and silhouette constants1/2.
- `library R_Plane` construction prerequisite (integrator-owned until 2C): `R_ClearPlanes(ctx)`, `R_FindPlane(ctx,int32 height,uint32 picnum,int16 lightlevel) returns(uint32)`, `R_CheckPlane(ctx,uint32 plane,int32 start,int32 stop) returns(uint32)`. Logical x=-1..320 maps to bytes index x+1; top initialized0xff, bottom initialized0. No access outside allocated objects. Plane NULL uses0xffffffff, original MAXVISPLANES128 enforced explicitly. Wall code populates real floor/ceiling marks; wall-only output skips drawing those planes.
- `ctx.wall` is original r_segs scratch state. `ctx.curline/frontsector/backsector` retain BSP globals as map indexes. `ctx.dc/ds` are shared drawing globals. `sectorValidcount` supplies original sector visitation without mutating static map resources. `skyflatnum/skytexture/skytexturemid` are initialized from the WAD, with original SKY1 and100*FRACUNIT for E1M1.

The full native renderer supplies sixteen reference cases, all SHA-bound in `test/fixtures/renderer/manifest.json`. **Every integration comparison must bind its case name and manifest mode, plus hash and metadata**: generic reference-v0 intentionally has no wall/full render-pass field, so metadata alone cannot distinguish these two passes. The final M1 gate requires `mode=full`; a passing `walls` case is only the intermediate 2B gate. No native traces, projections or pixels may be supplied as renderer inputs.

Ownership for this batch: geometry agent takes `src/doom/r_bsp.sol`, `test/unit/r_bsp.t.sol`, `tools/reference/phase2_bsp/**`, `test/fixtures/phase2_bsp/**`, `docs/PHASE2-BSP.md`; drawing agent takes `src/doom/r_segs.sol`, `test/unit/r_segs.t.sol`, `tools/reference/phase2_segs/**`, `test/fixtures/phase2_segs/**`, `docs/PHASE2-SEGS.md` after the BSP trace prerequisite passes. Integrator supplies shared context and visplane construction; full planes/sprite work starts after a verified wall-only frame.

Batch 2B review amendments (before BSP/segs implementation):

- Resource initialization retains original identity `texturetranslation`/`flattranslation` arrays (only defined entries, omitting unused uninitialized extra slots). Wall column selection uses translated texture indexes, while pegging heights use the original sidedef texture indexes. Static Phase 2 does not advance texture animation.
- `ctx.negonearray` is shared all-minus-one clipping storage. The construction-stage clear currently initializes it; the final sprite initialization may reuse it without per-seg copies.
- `R_RenderSegLoop` aliases masked-column scratch through `ctx.drawsegs[ctx.drawsegCount].maskedtexturecol` before count increment. Preserve wall scratch between fragments. A single-column range leaves original scalestep fields unchanged. Keep int16 narrowing on clip/opening/masked-column stores and uint8 narrowing on plane top/bottom writes.
- Preserve `ctx.map.lines[linedef].flags |= ML_MAPPED` in frame memory. Static deployed resources remain immutable; persistent automap state is outside Phase 2.
- Original `abs(rw_normalangle-rw_angle1)` converts wrapped uint32 bits to signed int32 before absolute value; reject INT_MIN as outside the defined original domain. Do not implement unsigned absolute value. Fixed lighting uses `rs.scalelightfixed`/fixedcolormap when active, otherwise the clamped row from scalelight.
