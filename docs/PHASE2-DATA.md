# Phase 2A resource access

Source: `id-Software/DOOM` commit `a77dfb96cb91780ca334d0d4cfd86957558007e0`. This delivery implements resource access and the static map loader. The complete Phase 2 renderer and ordinary-deployment Anvil acceptance gate remain integration work.

## Mapping and fidelity

| Port | Original |
| --- | --- |
| `R_Data.R_InitData`, texture disk decoding | `r_data.c`: `R_InitTextures`, `R_InitFlats`, `R_InitSpriteLumps`, `R_InitColormaps` |
| `R_GenerateLookup`, `R_GenerateComposite`, `R_DrawColumnInCache`, `R_GetColumn` | Same named `r_data.c` functions |
| `R_CheckTextureNumForName`, `R_TextureNumForName`, `R_FlatNumForName` | Same named `r_data.c` functions |
| `W_CheckNumForName`, `W_GetNumForName`, `W_CacheLumpNum` | `w_wad.c`, with immutable code chunks replacing file/cache backing |
| `R_LoadMap` | `p_setup.c`: `P_LoadVertexes/Sectors/SideDefs/LineDefs/Segs/Subsectors/Nodes`; `P_GroupLines` subsector-sector binding; raw `mapthing_t` decoding |
| `ResourceStore`, `read`, `R_GetFlat`, `R_InitDataLazy`, local name indexes | EVM adapters, with no independent C renderer claim |

The original linear name lookup precedence is preserved by collision-resolved temporary hash indexes: last WAD match, first texture match. WAD directory names have the original `strncpy(...,8)` NUL-padding semantics; only the query is uppercased. Texture comparisons fold both strings and stop at NUL. `'-'` maps to texture zero. No generic lowercasing of WAD directory names occurs.

Texture column details retained:

- Width mask is the largest power of two **at most** the texture width, minus one; column input wraps as unsigned bits, including negative columns.
- Lookup patch counts wrap as original unsigned bytes, lump indexes narrow to signed short, and offsets narrow to unsigned short.
- A direct column points into the patch at original column offset plus three, ignoring `originy`, just like C. `lump > 0` is the original branch condition, including its unusual lump-zero behavior.
- An empty final patch column can contain just the `0xff` terminator. Its virtual pixel pointer can be two bytes past the lump. The returned `ColumnView.offset` preserves this; masked drawing inspects the retained prefix at `offset-3`. No out-of-bounds byte is read by returning the view, and drawing bounds remain enforced.
- Composite posts use absolute `topdelta`, original post order, overlap overwrites and vertical clipping. In particular, negative `originy` reduces count and sets position to zero **without advancing source**. This apparent clipping bug is preserved and covered by 660 native vectors.
- Composite memory is not invented as zero-filled original output. A coverage buffer tracks every written byte; requesting a texture with uninitialized composite holes reverts `UndefinedComposite`. Native dual allocation fills prove **all 338 composite textures** in pinned Freedoom are fully defined.

Map disk coordinates and offsets are signed little-endian shorts multiplied by 65536, matching the pinned native result of C's signed left shifts. Vertex, linedef, sidedef and sector indexes retain original signed-short semantics and reject invalid negative indexes; `-1` sidedefs become `0xffffffff` NULL. Raw node children retain all 16 bits. `subsector_t.numlines` and `firstline`, like the disk fields, are signed short in the pinned headers. The adapter rejects negative values; native boundary fixtures explicitly include 32767, 32768 and 65535. An earlier unsigned compatibility shim was corrected after header review; normal E1M1 values did not expose it. Node count 32768 is supported. Subsector sector comes from the first seg's sidedef. Flags, slope type, angles, line bounding boxes and front/back sector bindings match the C transcript.

The frozen sector subset omits simulation fields and sector line lists. `MapThing[]` contains raw decoded things; gameplay filtering/spawning is a separate renderer/actor integration task. BLOCKMAP/REJECT gameplay state, resource animation changes and `R_PrecacheLevel` actor traversal are not implemented here. No camera-dependent resources or visibility are prepared by the host.

## EVM placement and measured optimization

The existing Phase 1 bundle offsets address 1,755 STOP-prefixed immutable code chunks, at most 16,384 data bytes each. `read` bounds-checks the complete requested interval, every chunk index and code range, then uses exact-range `EXTCODECOPY`. It never copies the entire 28,741,889-byte bundle into frame memory.

Initial straightforward eager initialization measured 894,291,835 gas and a 10,044,000-byte allocator end before native assertions. That evidence justified exact local name indexes, approved lazy lookup initialization, and a per-frame patch/flat cache. Eager `R_InitData` remains available for full static validation. `R_InitDataLazy` decodes identical texture definitions, flat/sprite metadata and colormaps but defers each original lookup until access. It changes the timing of malformed texture rejection; eagerly validate resources before deployment readiness. Frames must not mutate the immutable definitions or source view after initialization.

Measurements in [`measurements.json`](../test/fixtures/phase2_data/measurements.json) come from actual EVM `gasleft()` deltas in Foundry. They are function costs, not complete transaction gas. `allocatorEnd` is `mload(0x40)`, an allocation high-water bound, **not** an `MSIZE`/trace claim. The integration gate measures actual Anvil transactions and memory expansion separately.

| Operation | Measured gas | Allocator end |
| --- | ---: | ---: |
| Full eager init, after exact name index | ~540 million | 10,678,208 bytes |
| Lazy init | ~52.6 million | 2,698,112 bytes |
| Static E1M1 load after lazy init | ~131.5 million incremental | 6,529,088 bytes total |
| First direct-column access, including lookup/patch allocation | ~521,400 | ~2.72 MB total |
| Same patch cached column | ~1,600 | same patch allocation reused |
| First flat access | ~47,100 | 4 KiB plus header allocated |
| Same flat cached | ~405 | allocation reused |

“First” means first allocation of that lump in the frame; source code accounts can already be warm from initialization. Composite memcpy initially cost up to ~51 million gas for a representative 36 KiB texture. Bounds-proven Cancun `MCOPY` plus complete-word coverage operations reduced representative composites to approximately 0.15–6.2 million gas while retaining all 338 native hashes. No assembly replaces geometry or decoding with a host-computed answer.

## Native evidence and commands

The extension imports the existing Phase 1 reference profile and extractor conventions. It mechanically extracts **20 original functions**, retaining exact body hashes and upstream source hashes in [`manifest.json`](../test/fixtures/phase2_data/manifest.json). It adds no changes to the Phase 1 harness or fixtures.

- 963 complete lookup directories, width/height/mask/composite-size records are hashed from native output and compared in EVM.
- All 338 composite textures are byte-identical via SHA-256; native allocations initialized separately to `0xa5` and `0x5a` identify unwritten bytes.
- 2,889 `R_GetColumn` calls (negative one, zero, width for every texture) compare native branch/lump and returned offset, including transparent final columns.
- All 853 sprite width/offset/topoffset records and flat marker semantics match native. Pinned Freedoom's 246 marker-interval flat slots include six zero-size internal markers; 240 actual flat images remain unchanged.
- Every represented E1M1 runtime map field is compared against a 244,476-byte native transcript: 1,196 vertices, 182 sectors, 1,829 sides, 1,175 lines, 2,057 segs, 682 subsectors and 681 nodes.
- 660 original cache clipping cases compare every output byte. Synthetic tests cover name precedence/NUL padding, rejected holes, cross-chunk copies, empty reads, missing/short chunks and overflow bounds. Ordinary CREATE is exercised with a real 16 KiB chunk and a second short chunk.

Run from repository root after the Phase 1 pinned resource package exists:

```sh
python3 tools/reference/phase2_data/reference.py --check
python3 tools/reference/phase2_data/prepare_chunks.py
.toolchain/bin/forge test --match-contract RDataTest -vv
python3 tools/reference/phase2_data/measure.py
```

`prepare_chunks.py` verifies the original blob hash and writes ignored test-only code-image files under `artifacts/local/wad/phase2-chunks`. Foundry's full-WAD tests use `vm.etch` to avoid 1,755 CREATEs in every test; this is explicitly **not** the deployment gate. Full deployment remains ordinary CREATE on Anvil. Derived binary fixtures contain original output checksums and a small static map transcript, not proprietary game data.

Native profile: Apple clang 17.0.0 `(clang-1700.0.13.5)`, `arm64-apple-darwin24.6.0`, existing `-O2 -fwrapv -fno-strict-aliasing -ffp-contract=off -fno-fast-math`. O0/O2 and UBSan results match. Original map/sprite negative signed shifts are C undefined behavior, retained only as pinned-profile extensions; that mixed run disables shift sanitization explicitly. A separate clipping-only run enables all UBSan checks and removes `-fwrapv`, with identical bytes. No undefined behavior is claimed as defined-C equivalence.

Host adaptation is documented rather than hidden: disk structures retain original 16/32-bit layouts; runtime pointers are native 64-bit. The `R_InitTextures` disk/allocator host adapter is not an extracted oracle; the actual lookup/composition/name/P_Load bodies are extracted verbatim. `Z_Free` is a no-op for shared immutable input bytes, and `Z_Malloc` uses ordinary host allocation with explicit fill. The full renderer oracle independently exercises original initialization during integration.

## Assembly bounds

- `ResourceStore` returns exactly the allocated `bytes` payload holding STOP plus data, without its header.
- `read` writes `count` bytes into `out[copied:copied+count]` after bounds checks prove the interval lies inside the allocation and source code.
- `R_DrawColumnInCache` checks complete source post bounds, clipped count, cache destination and coverage destination before `MCOPY`. Coverage stores use 32-byte words only when the entire word fits, then byte stores for the tail. No header, padding or neighboring object is modified.
- Coverage verification reads full words only when their complete 32-byte range is inside the coverage allocation; the remainder uses Solidity byte indexing.
- Test-only binary hash and name loads read inside prechecked fixtures; measurement reads the free-memory pointer. No production scratch-space aliasing or free-pointer rewinding occurs.

## Phase 3 integration amendment

Compiling the complete gameplay hook graph exposed a via-IR stack limit in the
three-field TexPatch constructor. The loader now assigns originx, originy and
patch through the existing array-element memory alias, in the same original
order. Decoding, lookup, bounds and resource read order are unchanged. Fresh
RDataTest verification passes all 20 tests, including every native lookup/sprite
field, map field, composite and signed-subsector boundary. The
[amendment checkpoint](../artifacts/phase3/resource-init-checkpoint.json) binds the
current source. Final integrated Phase 0/1/2 gates remain required separately.
