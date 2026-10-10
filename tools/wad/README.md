# Bring your own (free) demons

Phase 1 asset tooling pins **Freedoom 0.13.0 Phase 1**, a redistributable BSD-3-Clause IWAD. Node 24.11.0 executes the TypeScript directly through native type stripping; no npm packages are needed.

```sh
node tools/wad/download.ts artifacts/local/freedoom
node tools/wad/pack.ts artifacts/local/freedoom/freedoom1.wad artifacts/local/wad
node --test tools/wad/wad.test.ts
node tools/wad/check.ts artifacts/local/freedoom/freedoom1.wad artifacts/local/wad
```

The downloader checks the archive SHA-256 before extracting only the exact WAD and license members, then checks the WAD identity and the committed license bytes. Its ZIP reader supports stored/deflated single-disk members with bounded output. A cached archive is rechecked on every invocation. The archive checksum was obtained from the [official release CHECKSUM](https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0-CHECKSUM), retained in `test/fixtures/wad/UPSTREAM-CHECKSUM.txt`; its PGP signature was not independently authenticated. Release, HTTPS source, archive SHA-256 and WAD SHA-256 are in `freedoom.lock.json`.

`pack.ts` accepts only that pinned WAD so it cannot label arbitrary assets as Freedoom. It writes `resources.bin`, `bundle.json`, `palette.json` and `validation.json`. Packing concatenates **all 3,163 directory entries** in original order, including duplicate names, zero-length markers and unknown opaque lumps. Every original eight-byte name and every payload byte is retained. Input offsets disappear from the runtime bundle because the payloads are contiguous; original offsets remain in the selected-source snapshot. No texture assembly, geometry normalization, frame computation, or host renderer is performed.

The selected validation map defaults to E1M1. Map records are read from the frozen `schemas/wad-layouts-v1.json` disk ABI, with signed int16 indices and the original `-1` side sentinel. Node child words are unsigned, with bit 15 marking subsectors. Validators check record divisibility, all selected-map references, subsector spans, BSP references/cycles, REJECT length and BLOCKMAP signed offsets/list termination. A zero-node map is accepted only with one subsector. The parser rejects extended/Hexen layouts explicitly. Lookup matches the original `W_CheckNumForName`: uppercase and zero-pad the query, zero-pad directory bytes after the first NUL as `W_AddFile` does with `strncpy`, compare all eight lookup bytes, and take the last matching entry. Raw directory bytes remain unchanged in the package. Lowercase directory names are retained opaque, not silently renamed. The node count is at most 32,768 so the root index cannot overlap the subsector flag.

Asset validation checks PLAYPAL palette strides, all 34 required COLORMAP tables, PNAMES counts, TEXTURE1/2 definition offsets, dimensions and patch indices, all referenced patch column/post bounds and termination, flats between F_START/F_END, and selected-map texture/flat references. Original patch clipping is preserved: posts are not required to fit the declared patch height. Tall-patch reinterpretation is not added. THINGS values are parsed in their original signed domains; Phase 1 does not assert that arbitrary thing types have gameplay implementations. Unknown nonreferenced lumps stay opaque. Map and asset validation is stronger than the original unsafe loader on malformed data, without changing supported raw bytes.

Palette variant zero is the first 768 PLAYPAL bytes. Its SHA-256 and the full resource identity are copied into the existing v0 palette schema. Bundle identity is the SHA-256 of canonical compact, recursively key-sorted ASCII JSON over the manifest excluding `resourceIdentity` and `blobFile`, matching the Phase 0 Python implementation. `upstreamCommit` in bundle provenance identifies the pinned original DOOM ABI; Freedoom release identity is recorded separately in the lock and WAD hash.

The checker compares two independent in-memory pack runs and all disk outputs, validates both v0 JSON schemas strictly, compares every packed lump to the original WAD, and checks committed selected snapshots against original source bytes and offsets. The 176,053-byte snapshot contains all ten E1M1 lumps plus PLAYPAL, COLORMAP, PNAMES, one patch and one flat, alongside license and credits. Full 28 MB WADs and packages remain in ignored `artifacts/local/`. Regenerate snapshots only after an intentional reviewed source change:

```sh
node tools/wad/snapshot.ts artifacts/local/freedoom/freedoom1.wad
```

No renderer or Phase 2 code is included. The real palette may color the existing synthetic event frame without making it a DOOM frame.

Goal 4.7a adds resource selections for all nine Episode One maps without changing
the shared v0 bundle or its identity:

```sh
node tools/wad/episode-pack.ts pack artifacts/local/freedoom/freedoom1.wad artifacts/local/wad
node tools/wad/episode-pack.ts check artifacts/local/freedoom/freedoom1.wad artifacts/local/wad
python3 tools/reference/episode/reference.py --check
node --test tools/wad/wad.test.ts tools/wad/episode.test.ts
```

The [resource integration contract](../../docs/PHASE4-EPISODE-RESOURCES.md) defines
the catalog/map descriptors, shared indices, checksums, native comparisons and
focused ordinary-EVM resource verification. This is resource preparation only.
