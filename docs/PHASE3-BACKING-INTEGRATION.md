# Verified renderer backing integration checkpoint

The renderer now mirrors semantic original cache calls and can read a physical
tail byte only when its value is explicitly known from the allocation ledger or
an authenticated cached resource. Existing bounds checks remain. This is a
component checkpoint; full production startup, tic/frame, transport and browser
acceptance are separate.

The [native backing checkpoint](PHASE3-BACKING.md) proves 80 controlled cases,
10,240 value/knownness positions and 18 unchanged original column draws across
O0/O2/ASan/UBSan. Its native-only files remain unchanged. This integration adds
six Solidity tests for every native case/pixel, cache hits/reallocation, quiet
composite reconstruction versus actual purge, stale-tail clearing, a zero-memory-
allocation ordinary fast path and rejection of pointers/padding/slack/free IDs/
out-of-zone bytes and invalid knownness masks.

## Source behavior

`W_ZoneCache` owns semantic cache bookkeeping. Original raw columns and sprites
use `PU_CACHE`; flats use `PU_STATIC` while drawn and return to `PU_CACHE`;
composites allocate `PU_STATIC` before patch cache calls and become `PU_CACHE`
after construction. Lump owners are lump IDs and composite owners are
`numlumps + textureID`. Existing live composites reconstruct ephemeral bytes
without a second native allocation or patch retag; purged owners trigger genuine
regeneration even if an ephemeral byte array remains. Deferred lookup decoding
and immutable per-transaction parsing remain outside native allocation chronology.

`Z_ZoneBacking` follows source-block/successor links only when the ordinary
sample127 could cross the logical resource end. It materializes only requested
bytes and marks known integer fields using generated native layout offsets.
Authored pointers/padding, allocation slack, free/unmodeled body bytes and zone
exhaustion remain unknown. Authenticated adjacent cached lump body ranges are
bounded by live ownership and logical length. The current window intentionally
rejects arbitrary translated indices beyond its known range; negative absolute
resource indices remain rejected. No asset, frame, pixel or sample-value exception
exists.

Every engine `dc.source` assignment resets/binds the tail. `ColumnView` retains
its two-field pointer adapter; `currentColumnZoneBlock` identifies the raw/
composite source, and sprites select their explicit cached lump block. The
original patch-cache-length `SpriteBounds` check remains. The masked-post helper
becomes `view` only to read immutable adjacent backing when necessary; its post,
clip, fraction and draw ordering are unchanged. Its one pure test caller was
adapted to `view` with all original malformed-post assertions retained.

Full-hook-graph code generation required two call-local working structs:
`MapLineWork` in the original line loader and `TailWork` in the new backing
reader. They hold working aliases/offsets/cursors, preserve reads/writes/math/
iteration order and are never stored in the game or supplied by a host. Compiler
settings, memory/gas ceilings and assertion sets did not change.

## Executed verification

```sh
.toolchain/bin/forge test \
  --match-contract 'RDataTest|PZoneSetupTest|ZoneBackingTest|RDrawTest|RThingsTest|RSegsTest|RPlaneTest' -vv
.toolchain/bin/forge test --match-path test/unit/r_plane.t.sol -vv
```

Terminal run6162 compiled 77 files with solc0.8.37 in 183.82 seconds and executed
97 passing tests plus one separately owned full-setup fixture `MemoryOOG` failure.
The owned suites all passed: RData20, RDraw11, RThings15, RSegs43 and ZoneBacking6.
The contract regex missed the actual `RPlanesTest` name; the explicit plane path
was therefore run in47902, with all16 passing tests and zero failures/skips.
**All111 owned tests pass**, rather than treating the earlier regex as plane
coverage. The largest owned data test uses884,648,036 aggregate fixture gas;
backing-case/pixel comparison uses36,289,003. The measured draw primitives and
lazy-tail fast path allocate no memory during their checked interval. These are
fixture/component measurements, not production per-frame gas estimates.

Setup's two geometry/header tests passed in6162. Its full real-spawn setup
fixture failed at999,978,936 gas with `MemoryOOG`, without a native mismatch.
The reference agent identified duplicate resource parsing in its fixture and
changed only that scaffolding to the actual single-parse initializer. Terminal
run73296 then passed all three PZoneSetup tests, including full real-spawn
normalized headers/owner marks (921,597,231 gas) and both geometry gates
(841,226,923/756,455,921 gas). All assertions and limits remained unchanged.
That is complete setup allocation/header evidence; whole game state, frames
and public production/browser acceptance remain separate.

Earlier80103/80877/31289 compilation attempts stopped before assertions at the
line-loader liveness site. Run12089 then stopped at the new backing-reader stack
site. These were code-generation failures, not native mismatches. A preliminary
focused-test ternary literal type error was also corrected before codegen; it
was test syntax and did not alter engine behavior or assertions.

`artifacts/phase3/renderer-backing-checkpoint.json` binds the verified component
source/test/native dependencies and precise command scopes. Final public
Doom/GameplayProbe code generation, original physical cache chronology through
production ticking/rendering, recovered six-tic browser/canvas proof, whole native state/
frame comparisons and inherited final gates remain required.
