# Phase 0 schema contracts v0

These contracts freeze serialization and provenance boundaries before ports begin. They do not implement WAD parsing, a resource uploader, a C reference harness, or DOOM rendering. Shared Solidity counterparts are `ResourceIdentity` / `LumpDescriptor` in `src/evm/ResourceTypes.sol` and `Frame` in `src/evm/FrameProtocol.sol`. Changes require integrator approval and matching fixture updates.

| Contract | Schema | Example |
| --- | --- | --- |
| Static resource manifest | `schemas/resource-bundle-v0.schema.json` | `test/fixtures/phase0/bundle.json` |
| Separate RGB palette asset | `schemas/palette-v0.schema.json` | `test/fixtures/phase0/palette.json` |
| Frame buffer descriptor | `schemas/frame-v0.schema.json` | `test/fixtures/phase0/frame.json` |
| Frame reference provenance | `schemas/reference-v0.schema.json` | `test/fixtures/phase0/reference.json` |

All JSON schemas use Draft 2020-12, reject unknown fields, and require the listed fields. `schemaVersion: 0` is explicit in each document and identity. Hashes are lowercase hexadecimal SHA-256 without `0x`; upstream commits are 40 lowercase hex characters. Solidity consumes equivalent `bytes32` values. JSON integers must be exact: consumers handling `uint64` values must use a lossless JSON parser or reject values beyond their language's exact integer range; JavaScript `Number` does not safely represent all `uint64` values.

Run the executable contract checks:

```sh
python3 scripts/check-schemas.py
.toolchain/bin/forge test --match-contract ContextsTest -vv
```

The schema checker uses Python's standard library and implements only the keywords present in these schemas. It rejects unknown validation keywords rather than silently ignoring them. When `jsonschema` is installed, it additionally runs that library's Draft 2020-12 validator. No package installation is required. JSON Schema handles field shape and primitive bounds; the Python checks enforce cross-file identity, actual file hashes, packing, palette length, and frame dimensions. The script exercises malformed descriptors with recomputed manifest hashes, ensuring bounds validation is tested separately from identity validation.

## Resource identity and binary packing

`ResourceIdentity` contains schema version, WAD SHA, bundle SHA, palette SHA and palette variant. Every example document carries the identical identity. Synthetic data must have an all-zero WAD hash, `kind: synthetic`, and an explicit label. WAD-derived data requires a nonzero WAD hash, WAD name, source license and pinned upstream commit; this is metadata, not proof that a WAD was actually parsed or licensed correctly.

`blobSha256` hashes the raw bytes of `blobFile`. `bundleSha256` binds the **manifest**, including provenance and lump descriptors, so a renamed or differently split lump changes the bundle identity even if raw bytes stay the same. It is SHA-256 of the bundle document after removing `resourceIdentity` and `blobFile`, serialized with Python's exact deterministic expression:

```python
json.dumps(manifest, sort_keys=True, separators=(',', ':'), ensure_ascii=True).encode('ascii')
```

There is no trailing newline in hashed canonical data. JSON document formatting and local payload filenames do not affect the hash. Resource identity is excluded to avoid a self-reference; palette and WAD hashes remain separate identity fields, and the WAD hash is also bound via provenance. This explicit canonical encoding is a project format, not a claim of RFC 8785 conformance. New writers must reproduce it exactly.

Lumps are packed contiguously into one normalized blob in ID order, without gaps or overlap. `id` is the zero-based array position; `uint32.max` is reserved for the null sentinel. A Solidity `LumpDescriptor[]` uses array position as the ID. Duplicate names are allowed because WADs can contain repeated names. `nameHex` is exactly eight raw bytes, preserving padding. Offsets and lengths are unsigned uint32 byte counts; `offset + length` must not exceed the blob's actual length or uint32 maximum. Empty marker lumps are allowed. Normalized packing is deliberately stricter than arbitrary raw WAD directory layouts; a future parser must validate input WAD bounds separately, then repack.

Multi-byte integers in normalized blobs are little-endian, signed quantities use two's complement, and fixed-point coordinates are signed int32 16.16. Binary angles are uint32. The tiny sample has two named lumps and four little-endian int32 values: `1`, `-2`, `65536`, `-65536`. The format does not assign production per-lump record layouts yet: the Phase 1 asset gate must freeze those layouts and document every static resource transform. No per-view geometry, visibility or lighting may be computed by the packer. Raw WAD `NF_SUBSECTOR` values must be interpreted in their original uint16 domain before converting to validated resource indexes.

## Palette and frame boundaries

A palette is a separate JSON asset with `encoding: rgb8`, 256 colors, and exactly 768 RGB bytes in `rgbHex`. The bytes must match `resourceIdentity.paletteSha256`; `paletteVariant` identifies the selected palette. This gives transport clients a locally loadable asset without requiring a palette event or renderer code in the browser. A real PLAYPAL selection must match the WAD and bundle identity.

A frame descriptor names a raw binary indexed8 buffer, its SHA and byte length, dimensions, event `frameId` and `inputSeq`. The byte length must be exactly `width * height`, in row-major order starting at the top left. IDs start at 1; the descriptor represents one frame, while monotonic sequence and reverted-transaction behavior are transport test responsibilities. The example has a 320×200 deterministic gradient (`pixel[x,y] = (x+y) mod 256`) and grayscale palette. It is an independent serialization fixture, not a golden for the event spike's varying frame pattern.

## Reference boundaries

The reference descriptor binds camera coordinates/angle, detail, colormap, extra light/fixed colormap, simulated tic, resolution, palette identity, and raw indexed8 frame SHA. `fixedColormap: -1` means normal lighting; nonnegative values identify a fixed colormap. A WAD reference also requires a map name, exact upstream commit, compiler name/version/target/flags, patch and harness hashes, and explicit integer and double semantics. Hash the empty byte string when there are no reference patches; record actual harness bytes for its hash. This prevents a framebuffer from becoming an unexplained golden. Compiler metadata itself does not prove C equivalence: native comparisons and divergence reports are Phase 1+ work.

Only `synthetic-transport` scope is accepted for synthetic provenance. Real frame scopes are `world-view` and `full-frame`; feature coverage and actual pixel comparisons remain mandatory before either is claimed as passed. Numeric and geometry vectors will have separate fixture schemas at their implementation gates. EVM measurements and renderer/compiler revision metadata belong to the run report alongside the C reference; this descriptor is not a replacement for the specification's render-test report.

## Verified primitive assumptions

`test/unit/Contexts.t.sol` verifies internal memory-reference mutation and memory assignment aliasing; storage-to-memory and memory-to-storage independence; internal persistent-state mutation; arithmetic signed right shifts versus division truncation; sign extension, explicit narrowing and widened int64 multiplication; angle wrapping; null-index separation from index zero; and the raw BSP flag. Narrowing also runs 256 fuzz cases. No `m_fixed` function is implemented here, no assembly is used, and no C comparison is claimed. C compiler overflow and original `FixedDiv2` floating behavior remain Phase 1 oracle requirements.
