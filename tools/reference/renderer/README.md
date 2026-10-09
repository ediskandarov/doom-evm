# Original C renderer reference

```sh
python3 tools/reference/renderer/verify.py --check
```

Omit `--check` to regenerate the committed reference fixtures intentionally. This invokes the **actual original renderer translation units**, including r_bsp, r_segs, r_plane, r_things, r_draw, r_main and r_data, with the existing pinned C compiler profile and original tables/fixed math. It compares all 64,000 pixels, BSP/clipping/wall-call traces and scene counts across O0, O2, ASan/UBSan O2, and a separate 0xa5 allocation-fill run. Sixteen fixtures cover eight ANG45 headings at the E1M1 player start, both wall-only and complete world-view passes. These are native reference images, not evidence of EVM rendering.

The static scene includes every medium-skill, single-player WAD thing at its original spawn state's sprite/frame and flags, with floor/ceiling spawn height and sector-linked insertion order. It invokes no state action, game tick, thinker or input. The camera uses the Phase 1 stationary player-start policy. It has no player weapon overlay or HUD. The complete **world view** contains floors, ceilings, sky, walls, masked textures and world sprites; wall-only references deliberately omit the final plane/masked passes. Original C computes visibility for every reference image; none of its traces may be fed to the EVM as rendering inputs.

## Explicit host adaptations

`build.py` verifies the original checkout SHA and absence of modifications, copies the original sources/headers into a temporary build, and emits a hashed adaptation manifest. No upstream file is edited.

- LP64 pointer arrays allocate `sizeof(pointer)` instead of the original hard-coded four bytes. Two aligned byte-buffer casts use uintptr_t. The obsolete TEXTURE disk `columndirectory` field remains 32 bits, and that disk struct is packed because WAD texture offsets need not be four-byte aligned.
- macOS provides allocator declarations through stdlib.h and a small values.h compatibility header. All added declarations/headers are recorded or hashed.
- Original visplanes deliberately place sentinel pad bytes next to top/bottom arrays, then index beyond those array subobjects. The native adapter accesses these **same bytes at the same addresses** through the enclosing object's byte representation. This removes array-subobject bounds UB without changing the original plane algorithm or struct layout. Solidity must allocate explicit, valid sentinel slots.
- `R_InitSpriteDefs` expects a NULL-terminated list while original info.c's sprnames lacks an allocated terminator. The host passes a copy with one explicit terminating NULL, retaining every original sprite name.
- The host allocator implements allocation ownership and tags without a purging zone allocator. Alternate payload fills verify that these selected frames do not depend on freshly allocated zeroes. The original WAD I/O/cache functions are compiled, and free clears the original cache owner pointer.
- Original p_setup map loaders are mechanically extracted. The host supplies the first, rendering-relevant subsector-sector association loop from P_GroupLines. Remaining sound/collision grouping is outside this static renderer. Static thing initialization is an explicitly identified host adapter to original mobjinfo/states; action-pointer targets fail loudly if unexpectedly called.
- NetUpdate and platform I/O notifications are no-ops. Any unexpected border draw or simulation fails. Full-screen camera-only rendering does not use those paths.
- Trace entry hooks observe original BSP traversal, subsectors, solid/pass clipping and wall ranges. Their text is recorded in the build manifest; hooks do not modify renderer state.

## Undefined behavior audit

The whole original renderer is **not** portable defined-C code. Removing `-fwrapv` from the sanitizer profile fails first on an original negative left shift in R_InitSpriteLumps; `undefined-audit.json` retains that diagnostic. The golden claim is numerical equivalence to the explicitly pinned implementation profile, supported by O0/O2 and sanitizers with that profile, not universal ISO C behavior. Foundation fixtures with stricter defined-domain coverage retain their existing independent assertions. Signed wrapping, negative shifts and original resource-layout quirks must remain visible in the port's divergence report.

Freedoom-derived pixel fixtures use the resource license in `test/fixtures/wad/COPYING.txt`; code is GPL-2.0-only with id Software attribution retained in copied original units. `manifest.json` binds every reference file to the upstream SHA and the pinned WAD/bundle/palette identity. Existing strict reference-v0 validation checks all metadata.
