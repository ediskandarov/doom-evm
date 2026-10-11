# Focused E1M2 allocation diagnosis

Read `artifacts/full-videos/diagnostics/E1M2-allocation-divergence.json`.
The first divergence is native malloc ordinal2126: ST_lib caches STTMINUS
(128 requested bytes,168 with LP64 header/alignment) inside the physical zone.
The intended borrowed-UI reference adapter omitted this one library. EVM is
unchanged. A separate `--borrow-all-ui` native profile removes the unintended
physical allocation and matches all2397 malloc requests/result offsets/sizes.

The target is E1M2 gameplay tic84,coordinate290,106,world draw call458:
STEP5 texture75,column31,composite512 bytes,source offset496,masked index16,
composite index512,frac1049146,step93235,midpoint-1002024,COLORMAP11.
Composite and COLORMAP hashes agree. Native legacy source byte96 and EVM8 are
both byte0 of the next free-block size. Corrected native also reads8. Full header
bytes, known/provenance masks, block/creation identities and commands are retained.
Native C has physical pointers and a shared ZONEID marker, not EVM block indices.
Unknown header bytes remain unknown; virtual pointer bytes remain experimental.

Reproduce observations without modifying production or golden files:

1. Generate an independent observation clone with `prepare.py` into a new folder.
   Apply `evm-pixel-journal.patch` with `patch -p1 -d CLONE < PATCH`, then compile
   its FullSpeedrunProbe and ResourceStore with the pinned root config.
2. Build a fresh native-O2 reference with `native-build.py`; apply
   `native-pixel-journal.patch` in that output folder and compile its preserved
   manifest command with the output paths changed to this new folder.
3. Run native with FULL_CAPTURE_TIC=84 and three output variables:
   TRACE_COMPOSITE,TRACE_COLORMAP,TRACE_HEADER. Each names a local output file.
   Replay the original first84 E1M2 commands. The trace includes the target,
   zone stages before/after drawing and all original allocator operations.
4. For the consistent borrowed profile, prepend W_CacheLumpName/UIWCacheName
   and W_CacheLumpNum/UIWCacheNum macros to the generated st_lib.c only.
   Repeat into another output folder; never overwrite the legacy case.
5. `pixel-trace.mjs` uses the retained generated observer-pixel-trace artifact
   and an owned startup checkpoint at port18959. It deploys a fresh diagnostic
   consumer using authenticated checkpoint resource chunks, initializes E1M2
   and replays its original first84 commands. Its generated source patch records
   allocator events without changing geometry, provenance or sampling arithmetic.
   The source/constants are diagnostic only; it is not a production recorder.

The repository retains actual local trace directories/binary/source hashes.
Original mixed-profile references, the failing13 pixels in11 frames and existing
MP4/frame hashes remain preserved. Diagnostic gas/time is excluded from final
recording telemetry. All1029 existing E1M2 frames/palettes match the independently
corrected native reference under O0/O2/sanitizer; no EVM rerender was required.
