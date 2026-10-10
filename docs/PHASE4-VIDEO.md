# Goal 4.1 — Original video primitives

This goal prepares shared EVM video operations; it does not implement any status
bar, HUD, automap, intermission or palette effect. The accepted production
renderer, gameplay dispatch and Frame protocol are unchanged.

## Source mapping and interface

Pinned source: linuxdoom-1.10 at
`a77dfb96cb91780ca334d0d4cfd86957558007e0`.
All eight active `v_video.c` functions retain their original names in
`src/doom/v_video.sol`: `V_Init`, `V_MarkRect`, `V_CopyRect`, `V_DrawPatch`,
`V_DrawPatchFlipped`, `V_DrawPatchDirect`, `V_DrawBlock`, `V_GetBlock`.
`v_video_types.sol:VideoState` represents `screens[5]` and `dirtybox[4]` from
`v_video.h`. Explicit function state/byte references replace globals/pointers.
Gamma tables/usegamma belong to palette presentation in Goal 4.2; the native
oracle records the original table without using it to draw pixels.

`V_Init` allocates four 64,000-byte zeroed buffers, matching `I_AllocLow`'s
original malloc+memset. Screen 4 remains consumer supplied: original `ST_Init`
uses 10,240 bytes. Original dirtybox initialization is not invented: V_Init
leaves it alone, and tests explicitly call `M_ClearBox` where needed.
The four EVM byte arrays are separate allocations rather than one native
contiguous pointer block. Cross-screen physical pointer arithmetic is not an
API operation. Every valid screen-relative byte/stride is preserved. This is
a local memory context, not a change to the gameplay zone/memory architecture.

To compose with an existing rendered frame:

```solidity
VideoState memory video;
V_Video.V_Init(video); // Allocate scratch screens before first use.
video.screens[0] = renderState.framebuffer; // Memory alias, no pixel copy.
// Supply video.screens[4] when a future status-bar consumer needs it.
V_Video.V_DrawPatch(video, x, y, 0, originalLumpBytes);
// Existing Frame event emits the same renderState.framebuffer.
```

The resource boundary accepts original patch bytes; existing
`R_Data.W_CacheLumpNum`/immutable code readers work without a new resource
format or browser graphics. `VideoProbe` demonstrates this boundary and the
unchanged event ABI; it is verification support, not production UI dispatch or
an authenticated full-WAD deployment.

## Original behavior and explicitly bounded domains

Patches use signed little-endian width/height/left/top offsets, original
horizontal column order (reversed for flipped), absolute topdelta, post length,
source offset +3 and next post +length+4. Pixels are literal palette indexes,
including 0 and 255; only a topdelta 255 terminates a column. Transparent holes
leave the destination untouched. There is no tall-patch interpretation,
rescaling, colormap application or browser composition.

The port selects original `RANGECHECK` behavior. `V_DrawPatch` and Direct ignore
an entire out-of-box patch before dirty marking; Flipped errors. Original code
does not clip individual posts at screen edges. Positioning applies left/top
offsets before bounds checks. The screen domain remains 320x200 even when
`R_InitBuffer` selects 320x168: the bottom32 rows remain available to future
consumers. No viewport or existing renderer algorithm was changed.

CopyRect/DrawBlock mark dirty on every destination screen; DrawPatch marks
only screen0; GetBlock does not mark. Original M_AddToBox else-if and zero-size
MarkRect's two points remain visible. Rectangles copy one contiguous row at a
time using original 320-byte pitch. Defined vertical self-copy retains original
sequential effects, including downward row cascades.

Deliberate safety-domain adaptations:

- Negative rectangle dimensions and unrepresentable/invalid coordinates reject
  instead of permitting C's unsafe copies. Bounds sums are widened for checks;
  valid original int32 operations and patch-origin wrapping are retained.
- Truncated headers/column tables/posts, offsets into the header/table, missing
  sentinels, negative patch dimensions and posts beyond declared height reject
  with `MalformedPatch`. These are outside the validated well-formed WAD domain.
- Screen-relative physical accesses must fit the actual supplied allocation,
  including the smaller screen4 buffer. Unknown/invalid memory is never read,
  initialized or substituted. Normal out-of-box ignore is not a fallback for
  malformed physical backing accessed by otherwise valid patches.
- Partial same-row overlapping memcpy is undefined in original C and rejected
  with `OverlappingCopy`. Identical source/destination is a defined no-op
  extension; disjoint rows and original vertical order retain exact comparisons.
- Original fatal I_Error is represented by a revert. Normal off-screen ignore
  retains original control behavior, without stderr presentation in the EVM.

Local memory-safe Yul implements only bounded row memcpy using Cancun MCOPY.
Both source and destination ranges are checked, with no header/padding access;
partial overlapping native undefined domains reject before copying. There is
no assembly patch drawing, pointer emulation or memory-architecture redesign.

## Verification and finite scope

The native generator compiles unchanged original `v_video.c` and `m_bbox.c`
translation units with a platform declaration prelude. O0/O2/ASan+UBSan compare
58 cases, all five buffers, extracted blocks, errors and dirty boxes.
Solidity compares buffer/dirty/GetBlock digests for48 successful cases and
original rejection behavior for10 error cases. Real
Freedoom0.13.0 assets: STBAR, STTNUM0, STFST00, STCFN033, AMMNUM0, WIMAP0;
a synthetic patch covers multiple/empty posts, signed offsets and literal
0/255 pixels. Provenance and licensing are retained with small fixtures.

Native array-bounds UBSan is disabled solely for original variable-width
`patch_t.columnofs[8]` storage; ASan still checks physical accesses. Apple's
unsupported leak detection is disabled. No sanitizer claim covers malformed
native memory, signed overflow or overlapping memcpy. Those domains have
explicit Solidity rejection tests rather than invented native goldens.

Focused Foundry and native comparisons, targeted resource/event integration,
ordinary isolated Anvil receipts and an unchanged accepted world-frame case
are recorded separately in `artifacts/phase4/video-verification.json` and
`video-evm.json`. Current function/source bindings belong to
`video-source-map.json`; no historical certificate or frozen hash is rewritten.
The full inherited Phase0–3 suite and real-browser Phase4 UI acceptance are
explicitly deferred to final Phase4 acceptance. This goal changes neither
browser code nor a production visual mode, so it makes no new browser/UI claim.

Entry point for Goal4.2: use this memory API to port original `st_lib.c` widget
operations, supply screen4 as original320x32 backing, then integrate st_stuff
and face state with an explicitly selected168-row world mode. Palette transport
requires its own backward-compatible design and verification. Preserve the
legacy full-screen mode and DrawBounds compatibility profile.


The completed gate set is51 passing Foundry tests:17 focused new tests,33
existing dependency tests and one accepted full-world angle0 test. Seven
ordinary Frame receipts compare448,000 complete pixels; six native UI-patch
frames compare384,000 pixels directly with the pinned C oracle. Support render
transactions consume25,454,065–47,461,948 gas (including pattern/setup/load/Frame),
not a production-world-frame or isolated-primitives estimate.
