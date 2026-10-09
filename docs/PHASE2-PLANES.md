# Phase 2 plane renderer

`src/doom/r_plane.sol` ports every `r_plane.c` function from id Software commit
`a77dfb96cb91780ca334d0d4cfd86957558007e0`: `R_InitPlanes` (empty),
`R_ClearPlanes`, `R_FindPlane`, `R_CheckPlane`, `R_MapPlane`, `R_MakeSpans`,
and `R_DrawPlanes`. The original plane-height cache, four span-transition loops,
light selection, sky mapping and drawing order remain intact. Drawing calls use
the separately verified original `R_Draw` primitives and immutable resource adapter.

The top/bottom arrays contain 322 bytes, with logical x at offset x+1.
Clear rewinds active counts and clears cached heights, preserving cached distances,
steps, span starts, and previously allocated plane slots. Find/check reset exactly
320 top bytes; bottom and both sentinel pads retain prior contents. Sky heights
and lights coalesce, sky uses untranslated texture and colormap zero, and flats
use flattranslation. Native zero-height cache hits after a clear deliberately
reuse previous distance/steps. A negative signed distance becomes an unsigned
light index before saturation, as in C.

## Evidence

The eight full-mode E1M1 cases run real code-backed WAD resource initialization,
map loading, EVM-derived player-start camera, view/light setup, original BSP,
walls, and planes. Every resulting 64,000-byte framebuffer is compared to the
native third-NetUpdate `plane-pixels.bin` snapshot, captured before sprites and
masked walls. Case name/mode/angle, source commit, format, camera, lighting and
resource identities are checked; the snapshot is bound to its manifest SHA256.
No native visibility, plane definitions or pixels are renderer inputs.

The native extension mechanically extracts original plane, fixed math and four
draw functions. Its manifest records original source hashes, extraction lines,
function hashes, generated-source hash, harness hashes, pinned compiler and target.
Only the original top/bottom sentinel accesses are adapted through the enclosing
object representation, preserving addresses while avoiding array-subobject UB.
Resource callbacks supply declared synthetic bytes and do not calculate visibility.
All 117 synthetic snapshots include logical dimensions/clips, draw globals, all 200 entries of five cache/span
arrays, active planes including sentinel bytes, and the first eight physical
framebuffer rows. Identical output is required at O0/O2 and ASan/UBSan, using the
pinned `-fwrapv` profile. This is profile equivalence, not an ISO-definedness claim.

Fixtures cover high/low detail, unsigned angle wrap, cache miss/hit, zero height,
repeated clear, fixed colormap including index32, negative-distance saturation,
empty/disjoint/expanding/contracting spans, translated flats, sky full brightness,
light saturation, sky coalescing, occupied overlap and stale bytes. All eighteen logical view sizes are checked for plane clear bounds and scales;
existing geometry fixtures separately prove their original view and lighting setup.
The construction snapshots directly cover occupied splitting, sky tuple coalescing,
and all 128 valid slots before testing the explicit overflow rejection.

Bounds tests reject invalid rows (including y==height), columns, spans, invalid
plane indexes, 129th planes, unsafe CheckPlane overflow, and abs(INT_MIN). The
original CheckPlane overflow and abs(INT_MIN) have no native defined result;
these are explicit rejection extensions. Int32 arithmetic otherwise follows the
pinned renderer's wrapping profile. Low-detail drawing intentionally retains the
original span endpoint/count behavior proven in the draw stage. Z_ChangeTag has
no observable operation in the immutable memory cache adapter.

## Reproduction

```
python3 tools/reference/phase2_planes/reference.py --check
.toolchain/bin/forge test --match-contract RPlanesTest -vv
python3 tools/reference/phase2_planes/measure.py
```

`test/fixtures/phase2_planes/costs.json` records source-bound initialization,
BSP/wall and plane gas regions and allocator free-pointer values. Those values
are allocator positions, not EVM MSIZE. Unit resource chunk placement uses `etch`
in setup; the real renderer reads normal immutable code bytes. Full native scene
orchestration and deployed-resource/Anvil measurements remain integrator-owned.

In the isolated pre-optimization snapshot using allocation-based table access, plane-only regions cost 18.37M–136.40M
gas; initialization 543.78M–543.92M, BSP/walls 75.48M–275.99M. The allocator advances
from 12.75–16.09MB before planes to 12.92–17.69MB afterward. These figures include
actual memory expansion in the measured call and are not estimates or whole-frame
sprite costs. All sixteen plane test functions pass under the unchanged 1B limit;
the largest real-frame comparison is 972.74M including comparison overhead.
