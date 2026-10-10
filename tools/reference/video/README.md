# Goal 4.1 native video oracle

Run from the repository root:

```sh
python3 tools/reference/video/reference.py
python3 tools/reference/video/reference.py --check
```

The generator compiles the pinned `original/DOOM/linuxdoom-1.10/v_video.c`
and `m_bbox.c` translation units directly, without editing or extracting their
algorithms. The compatibility prelude replaces platform/header dependencies
with the original scalar, patch and post layouts. All builds enable original
`RANGECHECK`. O0, O2, and ASan+UBSan must produce identical complete screen
buffers, dirty boxes, errors, extracted blocks, and original gamma table.
`native.json` records source hashes, original function spans, compiler identity,
profile flags and complete-output digests.

The original `patch_t.columnofs[8]` declaration implements variable-width WAD
storage. Array-bounds UBSan alone is disabled for that legacy extension;
physical accesses remain covered by ASan and the remaining UBSan checks.
Apple's runtime does not support leak detection, so the sanitizer profile
disables it and makes no leak-safety claim. Same-row overlapping `memcpy`,
negative copy dimensions, overflowing signed arithmetic and malformed posts
that access invalid physical memory are excluded from C equivalence claims.
The Solidity tests cover its explicit rejection of those unsafe inputs.

The fixture setup verifies that `V_Init` allocates four contiguous 320x200
buffers and does not assign screen 4. The host's `calloc` is equivalent to
original `I_AllocLow`'s malloc followed by zeroing. For drawing tests, every
screen is then filled with a reproducible indexed8 pattern. Screen 4 is a
caller-owned 320x32 status-bar backing. The fixture explicitly calls
`M_ClearBox`; original `V_Init` does not initialize `dirtybox`.

`reference.py` reads the local immutable resource bundle programmatically.
It validates the resource SHA256, extracts six authentic Freedoom patches,
and records their IDs, source offsets and individual SHA256 values. Their
BSD license is copied alongside the fixtures. The synthetic seventh patch
has transparent gaps, an empty column, multiple posts, signed offsets and
literal index values 0 and 255. No UI module or browser drawing is involved.

The 58 cases exercise the eight original video entry points, normal and
flipped real patches, direct drawing, signed positioning, whole-patch
rangecheck rejection, nonzero-screen dirty marking differences, a 320x32
backing buffer, zero-sized rectangles and defined sequential vertical copies.
Normal out-of-bounds patches are ignored exactly as original rangechecked C;
flipped patches and rectangular operations use original `I_Error` behavior.
There is no invented edge clipping or scaled drawing.

## Binary fixture format

`test/fixtures/phase4_video/cases.bin` consists of 58 independent 260-byte
rows. `cases.json` gives each row's descriptive name and all decoded fields.

Each row contains 13 signed big-endian int32 inputs, then four signed
big-endian int32 dirty-box values, then six 32-byte SHA256 values:

```text
op,x,y,scrn,width,height,destx,desty,destscrn,patchId,seed,screen4Height,expectedError
dirtybox: top,bottom,left,right
SHA256: screen0,screen1,screen2,screen3,screen4,getBlock
```

Operations are numbered 0–7: `V_Init`, `V_MarkRect`, `V_CopyRect`,
`V_DrawPatch`, `V_DrawPatchFlipped`, `V_DrawPatchDirect`, `V_DrawBlock`,
`V_GetBlock`. Patches 0–6 are `STBAR`, `STTNUM0`, `STFST00`, `STCFN033`,
`AMMNUM0`, `WIMAP0`, and the synthetic patch. `patchId=-1` means unused.
`expectedError=1` means the native `I_Error` path was taken; screen and dirty
values then describe the unmodified pre-operation state.

All cases begin with fresh buffers. Screen byte `i` of screen `s` is:

```text
(i*13 + floor(i/320)*7 + s*41 + seed) & 255
```

DrawBlock source byte `i` is `(i*17 + seed + 3) & 255`.
`getBlock` hashes the empty byte array except for successful GetBlock cases.
Screens 0–3 always hash 64000 bytes; screen 4 hashes `320*screen4Height`.
`gamma.bin` records the original table independently; gamma/palette changes
are outside this drawing goal's scope.
