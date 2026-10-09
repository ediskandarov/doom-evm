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

## Ownership and integration

Integrator owns shared structs, interfaces, schemas, foundry config, Doom glue, deployment/full-renderer oracle and all cross-module integration. Three isolated worktrees own:

1. Geometry: `src/doom/r_main.sol`, `test/unit/r_main.t.sol`, `tools/reference/phase2_geometry/**`, `test/fixtures/phase2_geometry/**`, `docs/PHASE2-GEOMETRY.md`.
2. Resources: `src/doom/r_data.sol`, `src/evm/ResourceStore.sol`, `test/unit/r_data.t.sol`, `tools/reference/phase2_data/**`, `test/fixtures/phase2_data/**`, `docs/PHASE2-DATA.md`.
3. Drawing: `src/doom/r_draw.sol`, `test/unit/r_draw.t.sol`, `tools/reference/phase2_draw/**`, `test/fixtures/phase2_draw/**`, `docs/PHASE2-DRAW.md`.

Native extensions import/reuse the existing reference harness and mechanically extract original functions; they may not rewrite the oracle algorithms. Existing Phase 1 fixtures/harness remain unchanged. Each delivery supplies exact upstream/source hashes, native and Forge commands, domain/deviation audit, memory-safe assembly proofs, gas and memory probes. No edits to shared types without an integrator-reviewed amendment. Later BSP/segs and plane/sprite contexts are frozen at their prerequisite integration gates, before those agents begin.
