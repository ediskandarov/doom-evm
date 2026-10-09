# Original native zone lifecycle observations

This directory observes the actual original `z_zone.c` allocator and its real renderer,
WAD-cache, setup and gameplay callers. It supplies comparison evidence for a separately
implemented source-backed physical model. None of its operation streams, observed
headers, or pixel outputs are runtime engine inputs.

The completed run checks nine contexts: the six-tic all-render browser stream and all
existing eight E1M1 native scenarios. O0, O2, ASan+UBSan, and ASan+UBSan with allocation
fill `0xa5` produce byte-identical normalized observations. Every retained original
pre-render world snapshot, tick trace, diagnostic, event count, summary and frame is
unchanged. This is 2,211 gameplay tics and 30 selected frames, with allocator observations
at startup, setup, scenario configuration, selected renders and exit.

## Observation adaptations

`reference.py` first invokes the unchanged existing gameplay builder, inheriting its
pinned original source hashes, compiler profile, and explicit LP64 adaptations. It then
modifies only temporary translation-unit copies:

- Calls to Z_Malloc, Z_Free, Z_FreeTags and Z_ChangeTag use observer wrappers that invoke
  the original routines. The original Z_ChangeTag macro's preliminary ZONEID check is
  explicitly retained before calling the original Z_ChangeTag2.
- The two internal Z_Free calls in original Z_Malloc and Z_FreeTags go through the same
  observer so purge/coalescing chronology is visible; they are marked as nested calls.
- Original new-fragment creation and free's ID write update observer-only knownness masks.
  They never write any original zone field or payload byte.
- An unchanged host copy gains calls to ZoneStage after Z_Init, R_Init, R_InitSprites,
  P_SetupLevel, explicit scenario setup, selected R_RenderPlayerView and final exit.

The observer's masks and I/O live outside the original zone. All engine state, cache
ownership mutation, free/reuse/tag/purge decisions and drawing remain original C.
`adaptedSourceSha256` entries bind the temporary source adaptations. Caller names/files
and line numbers identify the adapted original translation unit; line numbers can include
previously documented inherited observation insertions.

## Data and normalized pointers

Fixtures are in `test/fixtures/phase3_zone_lifecycle`. Per-case JSONL gzip files record:

- Completed allocations, frees and tag changes, plus FreeTags begin/end. Events contain
  monotonic sequence, original gametic, stage phase, caller/file/line, requested size/tag,
  logical owner key, returned or pre-free header offset/size and final rover. Allocations
  include full new-header metadata; frees include the merged survivor's header metadata.
- Full live-list snapshots with byte length, rover, cap links, counters, every block and
  owner-mark payload offset. Allocated live bytes include block headers and alignment;
  peak is the maximum live sum, not a process RSS or backing allocation size measurement.
- Every currently cached sprite's own header/payload and immediate successor header at
  each stage. This checks the whole sprite cohort, rather than a single failing lump.

Zone pointers become byte offsets from mainzone: the sentinel is offset 8, the initial
free block offset 56, and each block header is 40 bytes under the pinned LP64 profile.
Unowned allocations and absent owner marks use −1. WAD owners are lump IDs; texture
composite owners are numlumps + texture ID. Raw host/code addresses and pointer bytes
are never represented as portable source bytes.

Initial free-block tag/ID are not written by original Z_Init. A new fragment's tag is
written zero but its ID is untouched. Therefore `idKnown=false` and `id=null` describe
new fragments even if their backing bytes contain zero or stale data. Allocation writes
ZONEID and Free writes zero; merged blocks retain the survivor's write-knownness.
The observer never reads or claims an unknown raw free-header ID as portable.

## Startup comparison binaries

The after_R_InitSprites prefix is identical across all nine contexts/profiles. It contains
6,498 completed outer operations and 4,913 live-list blocks with 4,126 owner slots
(3,163 lumps + 963 texture composites).

`startup-operations.bin` is BE32 operation count followed by seven BE32 words per completed
outer call: op (Malloc=1, Free=2, ChangeTag=3), requested size (Malloc only), requested tag
(Malloc/ChangeTag), owner key, header offset, block size, rover after operation. Free's
header/size/owner are captured before the original free; its rover is captured afterward.
Nested purge Free calls and FreeTags boundary events are omitted from this compact prefix
but retained in the complete JSON event stream.

`startup-summary.bin` is BE32 count + 32-byte rolling SHA256, starting with 32 zero bytes
and hashing prior digest + each 28-byte record. `startup-headers.bin` contains BE32
byteLength/rover/capPrev/capNext/freeMemory/blockCount, then nine words per block:
offset/size/allocated/owner/tag-if-allocated-else-zero/idKnown/id-if-known-else-zero/prev/next,
then ownerCount and owner payload offsets. −1 is encoded `0xffffffff`. FreeMemory uses
original Z_FreeMemory's rule: free blocks plus blocks with tag >= PU_PURGELEVEL.
These binaries are comparison-only goldens, never allocation recipes supplied to replay.

## Layout and coverage results

`layout.py` compiles actual original headers and mechanically extracts unchanged private
texture/texpatch/memzone typedefs. `layout.json` exports sizeof/alignment/offsetof for
allocator, map, mobj, all eight special-action payloads, sprite and texture definitions.
Primitive widths are pointer8/int4/short2, allocation alignment8, mobj224, sector128,
texture28/texpatch12, spritedef16/spriteframe28. All field offsets and source/extraction
hashes are retained; values are not inferred from a Solidity representation.

The complete trace has 83,054 events, 84 snapshots and 63,975 sprite adjacency checks.
All 853 cached sprite blocks have allocated known-ZONEID successors throughout the
observed stages. Maximum live size is 13,901,664 bytes of the 67,108,864-byte zone;
no cache purge occurs in these nine finite runs. This does not establish an invariant for
arbitrary levels, memory sizes, gameplay duration, cache pressure or future scenarios.
Pointer/padding/body portability and uninitialized bytes require their own source-derived
rules; adjacency alone does not define them. Existing PLAYW0 diagnostics retain the exact
logical overread cause and native next-header ID sample independently.

## Commands actually executed

```sh
python3 tools/reference/phase3_zone_lifecycle/layout.py
python3 tools/reference/phase3_zone_lifecycle/reference.py --quick  # O2 interim only
python3 tools/reference/phase3_zone_lifecycle/reference.py          # final four-profile generation
```

The final generation run is 38145. It executed all four profiles and checked every retained
original output; it was not a `--check` reproduction command. Reproduction uses the same
command with `--check`. No Forge compiler, production edit, external service, raw Codex
session log, or runtime allocation/pixel tape is involved in this native evidence work.
