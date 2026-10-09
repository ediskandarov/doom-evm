# Phase 3 original zone allocator core

`src/doom/z_zone.sol` ports the eight core allocation/list functions in pinned
`linuxdoom-1.10/z_zone.c` at `a77dfb96cb91780ca334d0d4cfd86957558007e0`:
`Z_Init`, `Z_ClearZone`, `Z_Malloc`, `Z_Free`, `Z_FreeTags`, `Z_ChangeTag2`,
`Z_CheckHeap` and `Z_FreeMemory`. The original `Z_ChangeTag` macro is represented
by a checked function and the original-name alias. Console/file dump functions
remain host diagnostics. This checkpoint covers the allocator ledger, not full
gameplay allocation integration or arbitrary raw header/payload reads.

The shared `z_zone_types.sol` layout uses stable block IDs for C pointers and
physical offsets for the pinned LP64 backing layout: memblock 40 bytes, memzone
56 bytes, the permanent list sentinel at offset 8, first free header at offset
56. Payload sizes round to eight bytes, matching the native gameplay LP64
adaptation; upstream originally rounds to four. The allocator does not request
host memory or use an external service.

## Original behavior and representation

- Allocation scans from the original rover, backs over a preceding free block,
  preserves the original `start = base->prev` stop condition and purges encountered
  owned cache blocks. Both `base` and `rover` follow the original merge-sensitive
  assignment order. The stop condition is not replaced with an improved best-fit
  search or a sum-of-free-memory check.
- Header bytes are included in allocation size. A new free fragment is created
  only when `extra > 64`, not at equality. Smaller remainders are donated to the
  allocated block; payload offset is header offset plus 40.
- Free clears the original owner mark, tag and ID, then merges with the preceding
  and following free blocks in that order. Rover updates follow the original
  identities. Absorbed headers remain ledger tombstones; live-list traversal
  uses `next`, not array capacity or every historical header.
- `FreeTags` captures the next header before freeing. Its local iterator can
  encounter an absorbed free header, just as the original pointer loop can;
  keeping tombstone links preserves that control flow.
- Clear relinks the whole zone to one free block. Original clear does **not**
  clear owner marks, first-header tag/ID, payload bytes or old interior headers.
  Stale owner slots retain their physical payload addresses. The port deliberately
  does not invent a cache-clearing side effect.
- Owner keys identify deterministic logical pointer slots. `UINT32_MAX` means
  unowned; owned key zero is valid. Allocated/unowned blocks represent original
  user value 2, free blocks represent NULL and the sentinel represents the zone
  pointer. Actual process pointer bytes are outside this ledger's proof.
- Dynamic block buffers grow geometrically while IDs and offsets remain stable.
  Pool growth is an adapter detail, not an extra native allocation inside the
  modeled zone. The default intended backing size is 64 MiB; smaller heaps test
  fragmentation and limits.

A malloc writes `ZONEID = 0x1d4a11`; free writes zero. Those ID values are known.
Original fragment creation does not initialize `newblock->id`; the ledger marks
that field `idKnown=false`, including physical address reuse. Initial free and
sentinel IDs are unknown. Clear preserves first-header knownness. Snapshot masks
never turn an uninitialized field into a claimed portable zero or readable 17.
This conservative ledger does not infer arbitrary payload bytes left at a new
fragment header.

## Native sequence proof

```sh
python3 tools/reference/phase3_zone_allocator/reference.py --check
.toolchain/bin/forge test --match-contract ZoneTest -vv
```

The native harness compiles the actual original allocator translation unit,
with the sole allocation-body adaptation `size = (size + 7) & ~7` and read-only
known-ID observers after existing alloc/free writes and fragment creation.
Instrumentation does not change native headers or payloads. The allocation
provider supplies a declared zero-filled backing; no gameplay algorithm is
replaced by a fixture tape.

**1,624 snapshots** compare O0, O2 and full ASan/UBSan byte for byte. Input records
contain allocation/free/tag/clear/check commands; output records contain physical
links/rover, allocated sizes including slack, original owner marks, tags,
known-only IDs and free/purgeable byte totals. Small heaps 232, 233 and 240 bytes
exercise strict fragment equality and greater-than boundaries; 4 KiB, 8 KiB and
64 MiB heaps exercise the same layout. Deterministic long sequences include
cache purges, both-neighbor coalescing, stale owners across clear/reallocation,
unowned blocks, tag changes and free-tag traversal.

Five original fatal conditions are measured in each of the three native builds:
unowned cache malloc, unowned change to a purgeable tag, double free, exhausted
allocation and broken back link. C terminates via its original `I_Error`;
corresponding Solidity requests revert. Partial native state after a fatal exit
is not treated as an accepted operation or compared to transaction rollback.

`test/fixtures/phase3_zone_allocator/manifest.json` binds the original checkout,
compiler, sources, generated source, schema and golden bytes. Fixture inputs are
commands; native allocator outputs are comparison values only. The Solidity
unit runs the real core and compares every snapshot, rather than loading native
allocation outcomes as its allocator state.

Both Solidity tests pass in terminal run86053: all1,624 native snapshots and all
five fatal conditions, zero failures/skips. Aggregate fixture costs are
451,535,952 and 80,120 gas; they include setup and comparison and are not production
allocator or frame costs. The preceding run4031 passed every snapshot; its only
failure was a test expecting a parameterized error as a bare selector. The
expectation was corrected to `AllocationFailed(40)`; the core did not change.
`test/fixtures/phase3_zone_allocator/validation.json` binds the final source and
fixture hashes to this evidence. No production integration acceptance follows
from this isolated proof.

## Declared bounds and remaining integration

The API supports original nonnegative sizes and byte lengths bounded by signed
32-bit positive range, owner/tag categories representable in the frozen types,
and structurally valid heaps. Explicit guards reject malformed links, invalid
IDs/owners, oversized requests and source-invalid freeing calls. Original fatal
owner/allocation/check conditions remain failures. Native integer/pointer
representation is the pinned LP64 implementation profile, not universal ISO C.

Root-owned integration must replay actual engine allocation order and owner
namespaces and model known physical bytes before exposing a bounded read beyond
a logical resource lump. Pointer or padding bytes, uninitialized fragment IDs,
unknown payloads and stale memory are not silently fabricated. The core contains
no special handling for a particular sprite, frame, column or byte value.
The renderer's DrawBounds guard remains unchanged by this workstream.
