# Goal 4.7a — Episode One resources

This milestone prepares and verifies E1M1–E1M9 from the pinned redistributable
Freedoom 0.13.0 Phase 1 IWAD. It does not start gameplay, render Frames, advance
levels, or implement intermission, sound, browser upload or another episode.
The current user scope supersedes the older 4.7a startup/frame split in the extra
plan. Work is confined to `feat/phase4-multimap`; production adapters are unchanged.

## Resource integration contract

`packEpisode(parseWad(bytes))` in `tools/wad/episode.ts` accepts the existing pinned
WAD and returns the unchanged v0 blob, bundle, palette and E1M1 validation, plus a
v1 Episode One catalog. The original WAD SHA-256, canonical bundle SHA-256 and
palette identity remain exactly those accepted in Phase 1. All 3,163 original
directory entries, eight-byte names, duplicate names, empty markers, opaque lumps
and payload bytes remain in order. No resources are renumbered, assembled,
normalized, filtered or copied into separate map blobs.

`episode-pack.ts pack` writes `episode.json` and `maps/E1M1.json` through
`maps/E1M9.json` beside the existing `resources.bin`, `bundle.json`, `palette.json`
and `validation.json`. Each map file is a standalone selection descriptor bound
to the **same shared resource identity**, not an independent blob. Their names
describe resources only; no next-map or secret-exit relationships are encoded.

Each map descriptor contains:

- The map name and original marker descriptor. The marker uses original
  `W_CheckNumForName` last-match lookup semantics.
- Exactly ten map-relative lump descriptors in original order: THINGS, LINEDEFS,
  SIDEDEFS, VERTEXES, SEGS, SSECTORS, NODES, SECTORS, REJECT and BLOCKMAP.
  Their `id`, `nameHex`, packed `offset` and `length` address the shared v0 bundle;
  `originalOffset` addresses the source WAD. Each payload has a SHA-256.
- Record counts, structural/resource validation, signed BLOCKMAP origin and
  texture/patch/flat dependencies using original resource indices.
- `packageSha256`: SHA-256 of canonical compact, recursively sorted ASCII JSON
  of the descriptor excluding only `packageSha256`.

The catalog contains all nine descriptors in numeric order, the shared asset
index, bundle provenance and `chunkBytes=16384`. `catalogSha256` uses the same
canonical hashing rule, excluding only itself. The strict
`schemas/episode-resources-v1.schema.json` defines shape and field domains;
`verifyEpisode(sourceBytes, catalog, bundle, blob)` additionally regenerates and
compares everything, enforcing exact nine-map coverage, ordering, boundaries,
checksums, dependencies, provenance and source identity. Schema validation alone
does not authenticate a catalog. The disk checker also checks every individual
map file, palette and legacy validation, then proves repeated packing exact.

The shared index preserves TEXTURE1 followed by optional TEXTURE2 order and
**first texture definition precedence**. PNAMES resolves patch names by last WAD
match. A sidedef name beginning with `-` resolves to original texture index zero;
dependency lists conservatively include that index. Texture entries record the
source definition offset and ordered patch IDs. Flat indices are relative to
`F_START+1`, including internal marker positions: the namespace count is 246,
while 240 entries are actual flats. Sprite indices remain relative to
`S_START+1` (853 original patches); all sprite patches are checked. Shared palettes,
colormaps and all unused/unknown resources retain their existing IDs and bytes.
Dependencies describe direct map references, not the complete animation/switch/
gameplay precache closure. The full shared bundle preserves those other assets.

For later level-loading work, build the existing `ResourceView` from the v0
bundle and immutable chunk addresses. Select the validated map descriptor by
map name; resolve geometry by **marker-relative IDs**, never global lookup of a
repeated name such as NODES. Pass the chosen map name to the existing
`R_Data.R_LoadMap`. THINGS retain every signed disk field without spawning or
skill/type filtering. BLOCKMAP and REJECT retain their entire original bytes,
including list terminators, duplicate list offsets and extra matrix bytes.
The future collision/level initializer owns their runtime state. Record strides,
short signedness, `-1` sidedef sentinels and unsigned node children remain the
frozen `wad-layouts-v1` ABI. Existing zero-node and BSP-domain rules remain intact.

Authentication happens in resource tooling; the support EVM harness is not a
new production loader or on-chain arbitrary-WAD authenticator. Native zone
startup, thinker spawning, per-level memory reset and gameplay transition
integration are subsequent goals.

## Native and EVM verification

`tools/reference/episode/reference.py` extracts the pinned original C resource
functions, reuses the accepted Phase 2 host ABI/disk/allocator adapter, and
parameterizes its previously fixed E1M1 selection. Seven verbatim P_Load* loaders
produce every geometry runtime field for each map. Verbatim P_LoadBlockMap
produces signed words, fixed origins and dimensions. THINGS use the original
`mapthing_t` declaration and signed SHORT fields; REJECT and all ten raw lumps
are emitted from the original-name-selected resource view. No P_SetupLevel,
P_LoadThings spawning or gameplay filtering runs.

All outputs agree under pinned Clang O0, O2 and UBSan except shift checks.
Original negative signed shifts in map/sprite/blockmap loading remain documented
native-profile extensions; this is not an ISO-C portability claim. The existing
host adapter uses 64-bit pointers and original 16/32-bit disk records, with
immutable cache input and no-op Z_Free. R_InitTextures is an explicit adapter;
name resolution, texture lookup/composite, flat/sprite init and map loader bodies
are original C. The fixture records source/extraction/compiler/harness hashes.

`episode-native.ts` independently derives all geometry runtime fields from disk
records and compares complete transcripts. It also compares signed THINGS,
every BLOCKMAP word, every raw map lump and shared texture/patch indices.
All native shared texture lookups/composites and sprite dimensions match the
accepted Phase 2 fixture, including explicitly unwritten composite bytes.

The separate `EpisodeResourcesProbe` calls existing lazy R_Data initialization
and R_LoadMap, serializes all geometry and THINGS fields, and emits four digests
per map: geometry, THINGS, signed BLOCKMAP transcript and raw REJECT.
`evm.mjs` deploys the entire original blob once through 1,755 ordinary ResourceStore
CREATE transactions and verifies every STOP-prefixed runtime byte. Nine mined
map receipts match all four native digests. An attempted E2M1 selection produces
a mined revert with no events. The runner starts/stops only its own isolated node,
refuses an occupied port, and never uses etch/setCode or changes a production adapter.

Measured full-blob deployment costs **6,271,928,016 cumulative gas**, not one
transaction. Lazy initialization costs **47,204,473 gas** in this calldata harness.
The map operation ranges from **102,778,863 gas** (E1M8) to **538,495,563 gas**
(E1M7). Whole verification receipts range from **238,852,926** to **984,718,924 gas**;
they include calldata/decoding, initialization, map loading, transcript checksums
and events. These are resource-only support costs, not production storage-backed
startup, frame or gameplay costs. The existing configurable 10B gas budget and
Solc 0.8.37/viaIR/optimizer200/Cancun settings remain unchanged.

The shared blob is **28,741,889 bytes**; all nine map payloads total
**2,190,770 bytes**. Three in-process packaging runs and per-map descriptor sizes,
chunk spans and dependency counts are retained in the packaging report. Timings
exclude file writes; RSS values are snapshots, not isolated peaks. EVM wall times
include client/RPC/mining and the preceding call, not pure execution timing.

Evidence: [native comparison](../artifacts/phase4/episode-native-comparison.json),
[packaging costs](../artifacts/phase4/episode-packaging.json),
[ordinary EVM receipts](../artifacts/phase4/episode-evm.json),
[verification and ownership](../artifacts/phase4/episode-verification.json),
and `test/fixtures/phase4_episode/{catalog,native}.json`.

## Reproduce focused checks

Use the pinned toolchain from TOOLCHAIN.md. The full WAD and binaries stay in
ignored local output; the catalog, native manifest and compact reports are tracked.

```sh
node tools/wad/download.ts artifacts/local/freedoom
node tools/wad/episode-pack.ts pack artifacts/local/freedoom/freedoom1.wad artifacts/local/wad
node tools/wad/episode-pack.ts check artifacts/local/freedoom/freedoom1.wad artifacts/local/wad
node tools/wad/check.ts artifacts/local/freedoom/freedoom1.wad artifacts/local/wad
python3 tools/reference/episode/reference.py --check
node tools/wad/episode-native.ts artifacts/local/freedoom/freedoom1.wad artifacts/local/wad/episode-native artifacts/phase4/episode-native-comparison.json
node --test tools/wad/wad.test.ts tools/wad/episode.test.ts
node tools/wad/episode-measure.ts artifacts/local/freedoom/freedoom1.wad artifacts/phase4/episode-packaging.json
.toolchain/bin/forge build src/support/EpisodeResourcesProbe.sol src/evm/ResourceStore.sol --no-lint
node tools/reference/episode/evm.mjs
python3 tools/reference/episode/checkpoint.py --check
```

Existing directly relevant R_Data checks are limited to original E1M1 fields,
shared native lookup/sprite metadata, cross-chunk ordinary reads, and name/width
rules. Their exact focused invocation is:

```sh
python3 tools/reference/phase2_data/prepare_chunks.py
.toolchain/bin/forge test --match-path test/unit/r_data.t.sol \
  --match-test 'test(NativeAllE1M1MapFields|NativeAllLookupAndSpriteMetadata|ResourceReadAcrossChunksAndOrdinaryDeploy|NamesAndWidthMaskRules)' \
  --skip Doom --skip GameplayProbe --skip RendererProbe --skip WadResourcesProbe \
  --skip StatusBarProbe --skip HudProbe --skip VideoProbe --skip EpisodeResourcesProbe -vv
```

The skips exclude unrelated build roots; all four selected tests execute.
The checkpoint consumes focused logs in `artifacts/local/episode-verification`
(`node.log`, `forge.log`, `packer.log`, `legacy-packer.log`). Redirect the matching
commands there when recreating the checkpoint. Regenerating measured reports
changes timing and receipt metadata, so regenerate the checkpoint after an
intentional evidence refresh. The complete inherited regression suite is deferred as requested. No
multi-level gameplay or episode acceptance claim is made. Stop after Goal 4.7a.
