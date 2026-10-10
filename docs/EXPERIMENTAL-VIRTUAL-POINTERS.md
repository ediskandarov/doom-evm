# Experimental deterministic virtual pointer profile

Started 2026-10-10 18:05:46 UTC. Owner: the implementing agent in
`/Users/eduard/sandbox/doom-evm-virtual-memory`, branch
`experiment/virtual-pointer-memory`. Clean baseline:
`1e7033c149ddab6641be3116af3974d5ed585183`. The completed tic 52 diagnostic
branch is preserved as a merge dependency; main is never modified or pushed.

Scope: a separate explicit experimental z_zone pointer-byte source, component
proofs against pinned original C, historical rejection regressions, exact
gameplay/sampled-frame checks, and every-tic E1M1 rendering/video if supported.
Owned implementation paths: `src/doom/z_zone_types.sol`,
`src/doom/z_zone_backing.sol`, a new `src/doom/z_zone_virtual.sol`, test-only
`src/support/SpeedrunVideoProbe.sol`, goal-specific tests/tools/evidence and this
report. The new persisted profile bit is a shared interface change for integrator
review; no production initializer or external production ABI will select it.

Dependencies: original DOOM commit
`a77dfb96cb91780ca334d0d4cfd86957558007e0`, unchanged verified E1M1 tape,
authenticated Freedoom 0.13.0 resources, diagnostic allocator chronology,
solc 0.8.37/viaIR/optimizer 200/Cancun and unchanged execution budgets.
Isolated Anvil ports 18710–18719; refuse occupied ports, track and stop only
instances started by this goal. Local artifacts: `artifacts/local/virtual-pointer`.

Verification gates: focused allocator/backing/profile Forge tests, independently
measured native pointer representation/address arithmetic, real disabled-profile
tic52 rejection/rollback, enabled tic52 attempt and unresolved-read diagnosis if
needed, 280 exact gameplay worlds, 56 original sampled frame hashes, every-tic
capture through original exit if supported, byte/provenance manifest and MP4
verification. No complete historical acceptance suite. Stop after verified
implementation and recoverable committed handoff; no later goal or integration.

## Address model and eligibility

The intended fixed virtual base is `0x0000001000000000` (2^36). A supported
current zone block pointer is this base plus its header offset, including the
blocklist sentinel at offset8. Representation is eight-byte little-endian LP64,
align8, untagged unsigned addresses strictly below2^48. The entire nonempty
zone must fit that domain. Zero represents NULL and2 is the original unowned
allocation marker. Neither is obtained by adding the zone base.

Original `z_zone.c` and `z_zone.h` contain header `user`, `next`, `prev`, zone
`rover`, and global `mainzone` pointers. `next`/`prev` always target current
same-zone headers/sentinel. `rover` targets a current header; `mainzone` and the
sentinel's `user` target the zone base. Free header `user` is NULL; allocated
unowned header `user` is the integer-to-pointer marker2. Other `user` values
target caller-provided owner slots: they may be external globals/stack or
zone-resident arrays. The owner namespace does not record those addresses, so
they remain unsupported, even when a particular native owner happened to be
inside the zone. Caller owner-slot payload pointers, local allocator pointers,
arbitrary payload pointers and function/tagged/authenticated representations
are outside this byte source.

Current header fields are recoverable from topology and allocation status because
Init/Clear writes links/user, split writes fragment links/user, allocate writes
user, and free/coalesce updates the surviving links/user. Retired records only
retain conservative overwrite history: their apparent logical links are not a
stale-byte journal and cannot justify reconstruction. Validate current membership,
reciprocity, alignment, contiguous nonoverlapping geometry and sentinel identity
before reconstructing any experimental bytes. Existing provenance0–3 retain
their meanings; new provenance4 denotes a deterministic extension. Previously
known bytes take precedence. Unknowns remain unknown.

No fixed-address native mapping is planned. Independently controlled *offsets*
inside safely allocated native buffers will demonstrate actual base+offset
representations; the virtual representation will be checked by integer arithmetic
and little-endian serialization. Virtual pixels are deterministic extensions,
even if a value happens to equal one native process. Strict, ordinary deterministic
and Episode initialization semantics remain unchanged.

## Precise configuration and source mapping

The only production-library configuration is the new persisted
`ZoneState.experimentalVirtualPointers` boolean, default false from `Z_Init`.
No function in `Doom` enables it. The isolated test/video adapter selects
`initializeProfile(3)`; its default `initialize()` still selects1. The CLI requires
`--memory-profile virtual`. This selection combines initial-zone zero=true,
bounded pointer high bytes=true and experimental virtual pointers=true.
The experimental bit can be used independently by component callers; it never
sets either existing bit. `Z_ClearZone` preserves the policy bits and rebuilds
the current ring without turning historical bodies into known bytes.

| Existing selection | Initial-zone zero | Existing pointer high bytes | Experimental addresses |
|---|---|---|---|
| Strict | false | false | false |
| Ordinary deterministic | true | false | false |
| Episode | true | true | false |
| Explicit video profile3 | true | true | true |

`z_zone_virtual.sol` is a representation adapter for source-written allocator
fields; the same-named original allocator remains in `z_zone.sol`. No original
algorithm, allocation ordering or pointer store is moved into this adapter.

| Pinned original source | Written values and representation | Reconstruction boundary |
|---|---|---|
| `z_zone.h:57–66`, memblock `user,next,prev` | LP64 offsets8,24,32; width8 | Current header fields only |
| `z_zone.c:43–59`, memzone `blocklist,rover` | Sentinel at8; rover at48 | Sentinel identity participates in links; rover membership is validated, but rover bytes are not exposed by the tail reader |
| `z_zone.c:64–115`, Init/Clear | Zone/sentinel links, first-free links and NULL user; sentinel user=zone | These writes establish every initial current pointer field |
| `z_zone.c:122–171`, Free | user=NULL; surviving previous/next links and rover | Current surviving fields are supported; merged-away fields are historical and unknown |
| `z_zone.c:183–288`, Malloc | Fragment links/NULL, allocated user=owner or2, neighbor prev and rover | All current links are written; unowned2 is supported; owner-slot addresses are unsupported |
| `z_zone.c:98`, global `mainzone` | Pointer returned by I_ZoneBase | Model base is a separate explicit address space, not this process address |
| `z_zone.c:271`, caller `*user` | Allocated payload address, header+40 | Store location/coverage is absent from the ledger; no body reconstruction is added |

The native measurement and generated layout constants agree on memblock40,
memzone56, pointer8 and alignment8. Fixed base plus any valid aligned offset
cannot overflow uint64 or the declared below2^48 domain. The positive base,
contiguous current blocks and sentinel offset8 make current pointer identities
injective and distinct from NULL and marker2. Source membership, reciprocal
links, header size/alignment, allocated ZONEID, complete zone coverage, no adjacent
free blocks and current rover membership are checked once per requested tail.
Following the validated links then supplies current header identities to the
byte serializer. Invalid topology suppresses new category4 facts; existing
provenance behavior is preserved.

Original malloc/ASLR, historical Linux ILP32, arbitrary external addresses,
tagged/authenticated pointers, stale headers, mutable bodies and broader
allocation histories are not emulated. Owner-slot IDs are logical identities,
including IDs whose actual native slot might reside in a zone array. They do
not provide its address. The experiment is not a full virtual byte heap.

## Native reference experiment

`tools/reference/virtual_pointer/reference.py` builds a test-only inclusion of
pinned original `z_zone.c`, retaining its existing declared align8 adaptation.
O0, O2 and ASan+UBSan each run with four controlled zone placement offsets
(0,8,256,4096) inside safely allocated calloc buffers. No mmap/fixed-address
mapping, native allocator assumption or compiler flag change is used.

The 12 successful processes yield 1,044 observations through Init, allocation,
free, coalescing, reuse and Clear. Each raw stored pointer matches its measured
eight-byte little-endian representation. Every next/prev/rover target is a current
same-zone identity; each virtual serialized value equals the fixed base plus
that target offset across all runs. Both global owner slots and an owner slot
within the zone are observed and explicitly remain unsupported in the Solidity
reader. Build commands, compiler/target, source/executable hashes, raw observations
and measured times are recorded in `native-pointer/reference.json`.

This proves pointer arithmetic/representation with actual native placements
under the declared profile. It does not place native memory at 2^36. No native
pixel equality claim follows from this experiment alone.

## Tic 52 and every-tic rendering

Before implementation, all three original policies reproduce the historical
`DrawBounds()` selector `0x5b9a48fe` in real failed transactions at tic52.
Baseline strict/ordinary/Episode gas is 636,189,255 / 641,502,398 / 641,505,832.
The final implementation with its experimental bit disabled reproduces the same
failure at 636,205,116 / 641,517,503 / 641,520,627 gas. Every failure retains an exact
native gameplay world, unchanged complete saved-state digest, unchanged frame
counter and no logs. These are supported-profile rejections, not gas exhaustion.

The explicit experimental profile renders tic52 successfully at 715,970,158 gas.
An independently built observation-only clone records this actual sampled byte:

| Property | Result |
|---|---|
| Source | BON1D0, owner1552, block4496, header12785384, logical length238 |
| Draw | x301,y155; sourceOffset138; original fraction−8 masks to127; sample265 |
| Physical address offset | 12785689 |
| Current neighboring header | block4497, BON2A0/owner1553, header12785664 |
| Sampled field | relative25: byte1 of `next`, field offset24 |
| Current target header offset | 12786048 (`0x00c31980`) |
| General model | `0x0000001000000000 + 0x00c31980 = 0x0000001000c31980` |
| Serialized pointer | `80 19 c3 00 10 00 00 00` |
| Sample and drawn/final pixel | byte25 (`0x19`), palette index73 |
| Provenance | 4: experimental virtual pointer; value survives to final framebuffer |

No value in the implementation names a lump, map, pixel or tic. The virtual base
was selected before replay; no native address-placement assumption is inferred
from the coincident normal native result.

Both ordinary and observer experimental replays successfully capture 279 mined
EVM Frames, one per original gameplay tic, reach original exit line407 and
`GA_COMPLETED` at tic279, and match all 280 preserved native/EVM gameplay snapshots.
All279 ordinary and observer indexed frame hashes agree. The observer reports
exactly one category4 sample, the field above. No other sampled virtual bytes or
rejected reads occur in this tape. Unobserved/unsupported memory remains unknown.

Fresh independent native O0, O2 and ASan+UBSan runs produce 279 post-tic captures
per profile (837 captures), with exact initial/target pre-render worlds. Normal
O0/O2 frame hashes match all 279 experimental EVM frames. Sanitized native matches
278 complete frames; only tic52 differs, by exactly this one pixel (105 vs73).
The native sample hook independently verifies actual native base+targetOffset
produces its byte25 for normal builds and byte97 for the sanitized build. Thus
the other 63,999 pixels of tic52 match all three observed profiles. The virtual
pixel stays a **deterministic extension** even though it equals the normal native
captures. These finite comparisons do not establish universal native equivalence.

The ordinary deterministic profile independently reproduces all 56 established
sampled frame hashes and all 280 gameplay worlds with this implementation.
Earlier speedrun artifacts, native goldens, original C, fixtures, input bytes,
WAD resources, renderer arithmetic, allocator ordering and bounds checks are
unchanged. The observation clone is generated only under ignored local artifacts;
it adds sample records after the unchanged guard and has no production activation.

The full-rate MP4 contains 279 distinct scene captures at 35 Hz, duration
7.971429 s, nearest-neighbor 1280×800, sample aspect 5:6 and display aspect 4:3.
Receipt pixels, authenticated palette expansion, PNG hashes, media hash and
ffprobe frame/pacing metadata pass the existing video verifier. The contact sheet
was visually inspected. Local media is
`artifacts/local/virtual-pointer/full-rate/speedrun-e1m1.mp4`.

These are full-rate scene captures at game pacing, not real-time EVM execution.
The preserved video adapter renders from a temporary memory copy at each tic;
render-side allocations/cache mutations do not enter saved gameplay. Native
captures independently replay each no-render prefix then render once, matching
that scope. This is not a claim about a production persistent-render stream,
every Episode map, UI/browser acceptance or a full historical release gate.

## Reproduction commands

Run from this feature worktree. Use fresh goal-local output paths when preserving
a previous checkpoint. The three disabled-profile invocations deliberately exit
nonzero after recording their failed transaction and rollback evidence.

```sh
python3 tools/reference/speedrun/verify_evidence.py
node tools/wad/pack.ts artifacts/local/speedrun-e1m1/freedoom1.wad artifacts/local/speedrun-e1m1/wad
python3 tools/reference/virtual_pointer/reference.py
python3 tools/reference/speedrun/native-frames.py --output artifacts/local/virtual-pointer/native-frames
python3 tools/reference/virtual_pointer/speedrun_native.py
.toolchain/bin/forge build src/support/SpeedrunVideoProbe.sol src/evm/ResourceStore.sol --out artifacts/local/virtual-pointer/out --cache-path artifacts/local/virtual-pointer/cache
node tools/reference/speedrun/evm-video.mjs --port 18713 --memory-profile virtual --sample-every 1 --artifact artifacts/local/virtual-pointer/out/SpeedrunVideoProbe.sol/SpeedrunVideoProbe.json --output-prefix artifacts/local/virtual-pointer/full-rate/evm
python3 tools/reference/virtual_pointer/observer.py
.toolchain/bin/forge build artifacts/local/virtual-pointer/observer/src/support/SpeedrunVideoProbe.sol --out artifacts/local/virtual-pointer/observer/out --cache-path artifacts/local/virtual-pointer/observer/cache
node tools/reference/speedrun/evm-video.mjs --port 18714 --memory-profile virtual --sample-every 1 --provenance-observer --artifact artifacts/local/virtual-pointer/observer/out/SpeedrunVideoProbe.sol/SpeedrunVideoProbe.json --output-prefix artifacts/local/virtual-pointer/observer-full-rate/evm
node tools/reference/speedrun/evm-video.mjs --port 18715 --memory-profile legacy --sample-every 5 --artifact artifacts/local/virtual-pointer/out/SpeedrunVideoProbe.sol/SpeedrunVideoProbe.json --output-prefix artifacts/local/virtual-pointer/legacy-sampled/evm
node tools/reference/speedrun/evm-video.mjs --port 18716 --memory-profile strict --capture-tics 52 --artifact artifacts/local/virtual-pointer/out/SpeedrunVideoProbe.sol/SpeedrunVideoProbe.json --output-prefix artifacts/local/virtual-pointer/disabled-strict/evm
node tools/reference/speedrun/evm-video.mjs --port 18717 --memory-profile legacy --capture-tics 52 --artifact artifacts/local/virtual-pointer/out/SpeedrunVideoProbe.sol/SpeedrunVideoProbe.json --output-prefix artifacts/local/virtual-pointer/disabled-legacy/evm
node tools/reference/speedrun/evm-video.mjs --port 18718 --memory-profile episode --capture-tics 52 --artifact artifacts/local/virtual-pointer/out/SpeedrunVideoProbe.sol/SpeedrunVideoProbe.json --output-prefix artifacts/local/virtual-pointer/disabled-episode/evm
python3 tools/reference/speedrun/encode_video.py artifacts/local/virtual-pointer/full-rate
python3 tools/reference/speedrun/verify_video.py artifacts/local/virtual-pointer/full-rate
python3 tools/reference/speedrun/encode_video.py artifacts/local/virtual-pointer/legacy-sampled
python3 tools/reference/speedrun/verify_video.py artifacts/local/virtual-pointer/legacy-sampled
.toolchain/bin/forge test --match-path test/unit/VirtualPointers.t.sol
.toolchain/bin/forge test --match-path 'test/unit/{z_zone_backing,z_zone_initialization,z_zone,DoomZoneStartup,p_zone_setup,CompositeBacking,PointerHighBytes,SpeedrunTic52Backing}.t.sol'
.toolchain/bin/forge test --match-path 'test/integration/Episode*.t.sol'
python3 tools/reference/virtual_pointer/verify.py
python3 tools/reference/virtual_pointer/checkpoint.py
```

Resource preparation additionally needs the retained demo as `source-download`,
`tape.json`, `native-result.json` and `native-states.delta.bin.gz` copied from
`artifacts/speedrun-e1m1` into `artifacts/local/speedrun-e1m1`; the authenticated
WAD is supplied locally. For component Forge resource fixtures, place the packed
`resources.bin` in `artifacts/local/wad` and run
`python3 tools/reference/phase2_data/prepare_chunks.py`. The 1,755 generated
chunks are test dependencies, not changed accepted fixtures.

The baseline rejections already bind to the preserved merge dependency
`c8392e9`; rerunning them requires that exact revision in an independently owned
checkout. The verifier validates their executed sources through Git and the
final executions against current source hashes. `verify.py` checks actual
ordinary/observer/disabled Frame receipts, gameplay worlds, pointer samples,
native captures, source identities and regression logs; the existing video
verifier independently verifies the ordinary full-rate media.

## Verification and measurements

Engine/replay verification completed 2026-10-10 18:28:14 UTC, 1,348 s after the
measured start. Diagnostic ABI compatibility and the final evidence recheck
completed 2026-10-10 18:36:19 UTC, 1,833 s after that start. Subsequent evidence
packaging/commit time is separate. Implementation and
focused verification are complete; main integration/acceptance is not performed.

All 52 focused Forge tests pass: 8 new virtual pointer tests (including 256 fuzz
cases), 26 existing memory/allocator/composite/initialization/rejection tests and
18 Episode startup/lifecycle tests. The new cases cover disabled selection,
pointer representation, sentinel links and rover, NULL/marker2, unsupported
owners, unchanged existing provenance, retired/free/Clear history, invalid
geometry/identity/lifetime and storage persistence plus DrawBounds rollback.
The existing tests retain every accepted assertion and fixture. No complete
historical Phase 0–4 acceptance was run.

| Measurement | Actual result |
|---|---|
| Full-rate ordinary capture gas,279 Frames | 229,340,110,045 |
| Maximum single ordinary Frame transaction gas | 1,457,578,770 |
| Full-rate replay gas (279 single-tic advances) | 92,322,385,240 |
| Replay elapsed after startup/deployment | 261.711 s |
| Sum of ordinary capture transaction times | 195.654 s |
| MP4 encoding time | 1.015 s |
| Independent three-profile native capture run | 129.492 s |
| Safe native pointer experiment | 1.162 s |
| Baseline/final probe solc durations | 60.54 /61.47 s |
| Observer solc duration | 62.20 s |
| New virtual tests solc duration | 379.84 s |
| Existing memory regression solc duration | 425.71 s |
| Episode regression solc duration | 460.90 s |

Measurements include test observations, storage, local RPC/mining and concurrent
local workloads; these are not production performance measurements. Full-rate
replay advances one tic per transaction, unlike the five-tic sampled replay,
so total replay gas is not directly comparable. Pinned solc 0.8.37, viaIR,
optimizer 200, Cancun, Anvil 1.8.5,10 billion gas and 1 GiB configured execution
memory limit remain unchanged. Peak memory was not measured. Every goal-owned
runtime on 18710–18718 is stopped; reserved 18880/8088 and external runtimes were
not used. The evidence identifies actual ABI, deployed runtime and authenticated
resource bytes, receipts, source hashes, limits and every capture.

Available usage attribution is the goal tool's aggregate thread snapshot, saved
with the evidence. Its cumulative token count includes repeated/cached context;
no unique-token estimate, dollar cost, approval-wait duration or unmeasured peak
memory is inferred. The only working thread is the implementing root agent;
no delegated agents were spawned.

## Committed handoff and remaining boundaries

Implementation/test/tool commit:
`573be4fbbf31958ebbe39802346f76c0de41821d`
(`✨ Add opt-in deterministic virtual pointer profile`). Diagnostic compatibility
commit: `4a6ef7d9af3f34b138c3250a14a40c8f3e240385`
(`🐛 Preserve diagnostic decoding across virtual profile layouts`). The preserved
diagnostic dependency is `001240b7b9f9dc794260dd75711ef1029b264357`, merged into
this feature branch by `c8392e9c165cceab9041d4efd6acd85d33658879`.

Changed implementation paths: `src/doom/z_zone_virtual.sol`,
`src/doom/z_zone_backing.sol`, `src/doom/z_zone_types.sol`,
`src/support/SpeedrunVideoProbe.sol`, `test/unit/VirtualPointers.t.sol`,
`tools/reference/speedrun/evm-video.mjs`,
`tools/reference/speedrun/decode-diagnostic.py` and
`tools/reference/virtual_pointer/`. Goal report/evidence paths are this document
and `artifacts/virtual-pointer/`. The main worktree, shared Phase4 ledger, original C, accepted
test/fixture/resource bytes and other worktrees remain untouched.

Shared interface requirement for integration: the extra persisted profile bit is
packed into the existing ZoneState scalar storage word, but adds one word to its
internal ABI tuple/`abi.encode` representation. Diagnostic decoding recognizes
both old and new layouts; actual preserved errors and independently encoded
false/true extended tuples produce the same allocation/sample identities.
The Frame/browser protocol, WAD schema, external production Doom initializer
signatures and execution budgets are unchanged. Review the fixed-base policy
and new provenance4 before integration; selecting a production entry point is
outside this goal. No production initializer currently activates the profile.

[`checkpoint.json`](../artifacts/virtual-pointer/checkpoint.json) records exact
source/ABI/runtime/resource identities, commands/results, measurements, raw
report/receipt hashes, media hashes and the compact evidence archive identity.
[`evidence.tar.gz`](../artifacts/virtual-pointer/evidence.tar.gz) preserves mined
receipts, reports, native observations/build manifests, logs, executed observer
sources and compilation artifacts. The committed
[`virtual-profile-manifest.json`](../artifacts/virtual-pointer/virtual-profile-manifest.json)
classifies all279 frames and records the actual virtual sample. Full raw native
captures, EVM indexed frames, RGB previews and MP4 remain in the goal-local
artifact directory; no inherited checkpoint was overwritten.

There are no unresolved sampled reads on this tape. Unsupported external/owner
addresses, retired pointer bytes, arbitrary payload pointers and other execution
profiles still require additional evidence/representation; they remain unknown
here. No new heap architecture, map/tic-specific fix, production activation,
full release acceptance, main merge or push is claimed. Stop at this verified
feature handoff. The integrator may reconcile it into the Phase4 ledger later.
