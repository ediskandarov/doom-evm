# Renderer startup allocator replay

`DoomZoneStartup` derives the original zone calls from authenticated resource
metadata, parsed texture definitions and original parsed sprite definitions.
It never takes an allocation tape or native header snapshot as runtime input.

The replay follows original `R_InitData`, `R_InitTranslationTables` and the
following `R_InitSprites`/`R_InitSpriteDefs` call. Structural allocation sizes use
the documented LP64 native profile; actual native `sizeof` exports verify them.
`lumpcache[]` itself is allocated by host `malloc`, outside the original zone.
Owner slots represent lump IDs; texture composite owners occupy the following
namespace. Original composite generation allocates nothing during this startup
span, so those owner slots remain empty. The other R_Init calls (point-to-angle,
lookup tables, planes, light tables and sky mapping) make no zone allocations.

Every original `W_CacheLumpNum` access is replayed. A cache miss allocates the
original lump length with its owner and tag. A hit invokes original
`Z_ChangeTag2`. PNAMES and TEXTURE temporary blocks are freed in original order;
lookup patch caches and all sprite-lump caches retain their original order.
Colormaps and translation tables have their original alignment headroom.

The normal entry point disables observations. `replayObserved` executes the
same private algorithm and returns a locally computed operation digest/count
for tests. Neither value influences allocations or rendering. The digest starts
at 32 zero bytes and chains SHA256 of the previous digest plus seven big-endian
32-bit words: operation, requested payload size, requested tag, owner key,
header offset, block size, rover offset after the call. Operations are 1 malloc,
2 free, 3 changeTag. Free records input header/size/owner before coalescing;
requested size/tag are zero for free, and requested size is zero for changeTag.
UINT32_MAX represents an unowned allocation. Nested allocator purge frees are
excluded from this outer-call trace; the allocator component separately proves
its internal purge/coalescing behavior.

Native whole-host lifecycle observations supply comparison-only traces and
normalized live-header snapshots. Original unset ID bytes remain explicitly
unknown; pointer and padding bytes are not invented. Final verification status
will be recorded after native and EVM component checks finish.

## Verification

The original whole-host lifecycle oracle proves this startup span under
O0, O2, ASan/UBSan and ASan/UBSan with allocation fill `0xa5`. All nine native
scenarios share identical startup records: **6,498 outer calls** (4,914 malloc,
3 free, 1,581 tag changes), **4,913 live headers** and **4,126 owner slots**.
The actual C layout exports confirm pointer/int/short/texture/patch/sprite-def/
sprite-frame sizes of 8/4/2/28/12/16/28 bytes.

```sh
python3 tools/reference/phase3_zone_startup/reference.py --check
.toolchain/bin/forge test --match-contract DoomZoneStartupTest -vv
```

All three component tests pass, with zero failures/skips. They compare the
complete source-generated operation digest, every normalized live header and
owner payload offset, the normal observation-disabled replay against the same
native headers, and actual native sizeof constants. Final four-profile native
binary gold is byte-identical to the interim O2 bytes used during the Forge run.
Only metadata was refreshed after native verification finished.

The observed and normal tests cost 953,625,319 and 808,761,041 gas respectively,
under the unchanged one-billion-gas test limit. These are fixture-inclusive
tests with resource parsing, sprite definitions and assertions; they are not
production startup measurements. The fixture etches immutable resource code
only, never the engine runtime or supplied gameplay/pixels. The measured normal test stages are:

| Test stage | Gas |
|---|---:|
| Resource-fixture parsing and sprite definition loading | 107,531,293 |
| Zone initialization | 2,053,774 |
| Normal source-backed startup replay | 344,974,734 |
| Native header/owner comparison | 354,182,132 |

These event measurements exclude event-emission overhead and include the memory
context established by preceding stages. They are test-stage observations,
not estimates for an integrated production transaction. Actual EVM memory
high-water usage was not measured. `validation.json` records hashes and scopes.

| Original function/span | Replay work |
|---|---|
| `R_InitTextures` | PNAMES and TEXTURE temporary cache/free, seven arrays, per-texture definitions/columns, patch lookup accesses and texture translation |
| `R_InitFlats` | Flat translation including the extra original slot |
| `R_InitSpriteLumps` | Three metadata arrays, every sprite lump cached in original order |
| `R_InitColormaps` | Original lump length plus 255 alignment bytes, unowned static block |
| `R_InitTranslationTables` | Original 256×3 plus 255 alignment bytes |
| `R_InitSpriteDefs` | Original LP64 sprite-def array, per-present-sprite frame arrays |
| `W_CacheLumpNum` | Allocate on miss, `Z_ChangeTag2` on every hit |

Map/thinker/gameplay allocation replay, backing payload bytes and renderer access
to neighboring headers belong to separate integration work. This component does
not promote the earlier production/browser checkpoint to allocator acceptance.
