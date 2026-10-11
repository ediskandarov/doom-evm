# Continuation: deterministic owner-slot addressing

The existing goal remains open, targeting nine complete Episode One recordings.
Continuation baseline: `8ee6d1f2c403dfb9e7c2aa2016116a578d4724e9`, existing
`feat/ultimate-episode-speedruns` worktree. Prior reports, five accepted MP4s,
partial attempts, resources, compiled observers and manifests remain preserved.
No new branch/worktree, main integration/push or Computer Use is authorized.

Owned scope now includes the explicitly requested experimental pointer adapter
and its backing dispatch, isolated observation/verification tools, focused
native/Forge proofs and new recording directories. No shared state/type or
production ABI change is planned. Existing policy bits and allocator/draw
algorithms remain unchanged. Native sources and fixtures remain immutable.

Source inspection distinguishes two owner objects: `lumpcache[]` is allocated
by host `malloc` in W_InitMultipleFiles; `texturecomposite[]` is zone-allocated
in R_InitTextures under the existing LP64 pointer-array-size adaptation.
`memblock_t.user` stores the **address of an owner slot**, not the allocated
payload value written into that slot. Z_Free clears the stored payload and
writes NULL to the freed header. Cache hits retag the same allocation; purges
clear the slot; recaching the same lump uses the same slot address while its
payload/header may change.

Design selected before new rendering: retain zone base `0x0000001000000000`;
reserve a disjoint authenticated-lumpcache slot region at
`0x0000002000000000`, with LP64 stride eight and little-endian representation.
Address is region base plus eight times original lump index. This defines a
virtual object identity, **not native malloc placement**. Category 5 will label
supported virtual owner-slot bytes, separate from existing category 4 zone
links. Existing categories 0–3 take precedence. The region is aligned, disjoint
from the full allowed zone range, and below2^48 for all supported counts.

Admission requires the explicit experimental bit, validated current topology,
an authenticated resource/lump-cache catalog of matching length, in-range lump
identity, and an active ownerBlocks entry referencing the sampled allocated
header. NULL, unowned2 and internal links retain their existing representations.
Retired headers, stale owner marks, texture-composite/other/global/stack owner
slots and unmodeled external pointers remain unknown unless independently
proved and modeled. No map/tic/pixel-specific address exists in the adapter.

Gates: actual original-C sample identity/layout proof in O0/O2/ASan-UBSan for
all four failures; allocator lifecycle slot clearing/reuse proof; focused policy,
identity, lifetime, persistence/rollback tests; existing Freedoom E1M1 virtual
link regressions; nine real tapes with strict whole gameplay snapshots;
per-frame native-supported pixel and virtual provenance proof; five accepted
recording hash regressions; complete35FPS media in separate attempts. Native
compatibility verdict remains RESTRICT. New virtual bytes never establish
universal native pixel equality. Continue investigating any additional unknown
byte without a speculative fallback. Record actual resource/limit changes and
retain restorable checkpoints; only owned localhost runtimes may be modified.

## Native investigation milestone

All 12 actual original-C draws (O0, O2, ASan/UBSan) confirm category A:
external `&lumpcache[index]`, stride8, little-endian LP64. Each capture reproduces
its original pre-render DSG1 state and the saved EVM diagnostic physical/header
geometry. Sanitizer output is empty. Slot identity/relative offsets remain
stable; absolute malloc/ASLR addresses and their lower bytes vary. The pointer
stored in each slot equals header+40; the header's user field equals the slot's
address and is outside the zone. These are two distinct pointers.

| Map | Tic | Draw destination | Source | Neighbor owner | Header offset | user byte |
| --- | ---: | --- | --- | --- | ---: | ---: |
| E1M3 | 923 | 99,112 | SPOSB1,1474 | SPOSB2B8,1475 | 3763376 | 3 |
| E1M5 | 1064 | 34,150 | BLUDC0,1094 | BAL2A0,1095 | 3009048 | 0 |
| E1M6 | 1736 | 4,137 | STEP04,1928 | STEP03,1927 | 824112 | 5 |
| E1M8 Sedlo | 263 | 182,192 | STEP04,1928 | STEP03,1927 | 824112 | 5 |

[Actual draw proof](../artifacts/ultimate-speedruns/owner-pointer/native-samples.json)
records each source/header size, source offset, physical sample, tag/id,
next/prev/rover, slot identity, observed pointer bytes, executable/source hashes
and commands. Original C is copied for observation, never edited in the pinned
submodule. Observation hooks do not change sample arithmetic or allocate zone
memory. The first setup attempt had stale pre-move include paths; the first
hook attempt observed a preceding ordinary payload draw. Both local attempts
remain preserved. The final hook observes header-user samples only.

[Lifecycle proof](../artifacts/ultimate-speedruns/owner-pointer/native-lifecycle.json)
contains six executions across the three builds. Original Z_Free and tag/scan
purging clear the owner value; cache retag preserves header and slot; recache
can move the block while retaining the slot identity. A test allocation request
first reached original scan exhaustion; the successful chronology retains a
distinct start block and proves purging without changing allocator semantics.
Z_ClearZone does not clear stale owner slots: admission therefore depends on
CURRENT ring membership, allocation and the reciprocal ownerBlocks identity,
never historical records alone.

The solution is general for authenticated WAD cache owner slots and small:
a disjoint base+index*stride mapping, active-header validation, backing dispatch,
and provenance5 observation/verification. No persistent state/type/ABI change,
heap emulation, sampled-pixel table, or additional native bytes are needed.
Texture-composite owners are category B zone-resident slots; their array block
identity is not currently retained and they remain unsupported. Identifiable
globals (C), transient/external objects (E) likewise remain unknown. Existing
NULL and unowned2 sentinel representations (D) remain supported. Relaxed
Rendering is deliberately deferred under the latest user instruction.
