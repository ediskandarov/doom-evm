# Renderer cache chronology and physical backing

The completed checkpoint is native-only; the renderer integration described below
is a source draft with Solidity and production verification pending.

The integration aims to preserve original source sampling when a column addresses a known
physical byte beyond its logical WAD lump. It does not remove drawing bounds
checks or claim arbitrary native pointer/padding/payload portability. It uses the
separately verified original zone allocator ledger; disabled tracking keeps the
Phase 2 resource and drawing behavior.

## Cache calls follow original engine semantics

`W_ZoneCache.cacheLump` implements original `w_wad.c:W_CacheLumpNum`: allocate a
missing lump with its original tag and owner slot, or change the existing block's
tag. Lump owners are lump IDs; texture composite owners are
`numlumps + textureID`. Logical owner zero is valid. Zero-sized/disabled zone
returns block zero without a modeled native allocation.

The renderer mirrors actual original calls:

- `R_GetColumn` caches raw patch columns with `PU_CACHE` and records their block
  identity. Composite misses allocate with `PU_STATIC` before visiting patch
  caches, then change the composite to `PU_CACHE` after construction.
- `R_DrawVisSprite` caches the sprite lump with `PU_CACHE`. Its post draws retain
  the explicit block identity; the original malformed cache-length guard remains.
- Normal planes cache their translated flat with `PU_STATIC`, draw spans and
  release it to `PU_CACHE`, matching the original protected drawing interval.
- Ephemeral lookup/resource decoding during an EVM transaction is not another
  original native cache call. `R_GenerateLookup` remains quiet because native
  startup already performed it. A composite with a live native owner can rebuild
  ephemeral immutable bytes without allocating again or retagging its patches.
  If its native owner was purged, `R_GetColumn` regenerates it even when an
  ephemeral byte array is still present.

Original sources: `w_wad.c:476–500`, `r_data.c:R_GenerateComposite/R_GetColumn`,
`r_things.c:R_DrawVisSprite`, `r_plane.c:R_DrawPlanes`. The native lifecycle
[observations](../tools/reference/phase3_zone_lifecycle/README.md) separately bind
actual startup, setup, gameplay and render chronology. Operation tapes, headers
and pixels are comparison evidence and are not runtime inputs.

## Bounded physical-byte materialization

`Z_ZoneBacking` starts at the source allocation's physical payload address plus
logical resource length, then follows its live successor links. It does not scan
all heap records. A draw source assignment first clears the previous tail and
knownness mask. Materialization occurs only when `sourceOffset + 127` can exceed
the logical data. Normal columns therefore allocate no tail buffer and perform
no heap walk.

The current window comes from original ordinary-column `& 127` sampling. Each
returned byte has a separate knownness marker; only marker one is readable:

| Physical domain | Policy |
|---|---|
| Written block size integer | Known, little-endian original int32 |
| Written block tag integer | Known; initial first-free tag remains unknown |
| ID written by allocation/free | Known; uninitialized fragment IDs remain unknown |
| Authenticated cached resource payload | Known only within its logical length and a live matching owner |
| User/next/prev pointers and padding | Unknown |
| Alignment or donated slack | Unknown |
| Free payload and unmodeled object/composite body | Unknown |
| Beyond the zone allocation | Unknown |

Layout offsets come from the generated original C layout module, rather than a
specific sprite or pixel. Clear preserves written first-header fields as the
original allocator does. There is no asset name, special frame, magic sample
byte or pixel correction in the backing code.

`R_DrawColumn` retains its destination, colormap, translation and negative-index
checks. A sample inside logical data takes the original direct path. A sample
beyond it must fit both explicit tail arrays and have marker one; otherwise
`DrawBounds` remains the result. The default empty tails preserve every inherited
negative case. Arbitrary translated-column indices outside this conservative
window, negative absolute resource indices, pointers and unknown bytes remain
rejected; no broader raw-memory claim is made.

## Focused native proof

```sh
python3 tools/reference/phase3_zone_backing/reference.py --check
```

The harness executes the actual pinned `z_zone.c`, its established LP64 align8
adaptation and the unchanged original `R_DrawColumn` body. Eighty cases combine
16 payload lengths with allocated cached, allocated unowned, freed, fresh-free
fragment and donated-slack successors. They compare 128 backing value/knownness
positions per case across O0, O2 and full ASan/UBSan. Only known bytes are read
and exported; unknown output zeros are comparison placeholders, not native-zero
claims. Allocation/header/pointer bytes are never fixture inputs to the port.

Eighteen cases also run original `R_DrawColumn` with `frac=-1`, preserving its
ordinary masked sample127, at a source-derived successor ID address. The native
result supplies the expected mapped byte; the port must obtain it through the
allocator and known-byte path. This is generic integer-header sampling, without
naming the browser's failing asset or hardcoding its pixel.

`test/fixtures/phase3_zone_backing/manifest.json` binds original source/header,
allocator observer, drawing extraction, compiler and fixture hashes. The focused
Solidity tests compare every native backing byte/mask and selected column result,
reject pointer/padding/slack/free-fragment/out-of-zone reads, retain malformed
knownness-mask failures and check the no-allocation fast path. Cache lifecycle
tests cover cache hits, owner clearing/reallocation and composite reconstruction
versus actual purge/regeneration.

Solidity verification is pending the next coordinated compiler slot. An earlier
whole-setup code-generation gate stopped at stack depth before any assertions;
that is a compilation issue, not native equivalence evidence or an algorithm
mismatch. Existing startup proofs remain frozen separately. Final production
allocation chronology, whole state/frame comparisons, browser six-tic acceptance
and all inherited renderer gates are still required.
