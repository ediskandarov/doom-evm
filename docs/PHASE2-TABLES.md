# Phase 2 scalar table access

The integrated wall-and-plane tests approached the existing billion-gas limit before sprites were included. Repeated scalar trig lookups allocated 1 KiB chunks, advancing the EVM memory watermark even though callers retained only one integer.

`tools/tables/generate.py` now emits two-level packed-word switches. The outer switch selects the original 256-word region; the inner switch selects eight original integers packed into one bytes32 stack value. A shift and mask returns the requested 32 bits. The final partial group is padded only beyond the original array length; the existing index check runs first. There are no lookup memory reads, writes, allocations, allocator rewinds, computed trigonometry or changes to the table API. The assembly operates only on stack values. Original signed/unsigned casts, cosine alias and SlopeDiv remain unchanged.

All 16,385 original C integers and the unchanged table manifest are independently checked by the generator. Existing Foundry tests compare every table entry and cosine alias, all out-of-bounds rejections, all geometry vectors and 18 complete view configurations. The full integrated suite passes **149 tests** with seed `0x44`, including every original wall pixel, intermediate state and synthetic wall case. No expected numerical fixtures were changed.

The same angle0 wall test fell from 871,290,579 to 503,847,962 gas after this accessor change. This includes setup and bytewise verification, not just rendering. Ordinary CREATE-deployed normal and MSIZE-instrumented wall probes then passed all eight native wall hashes with identical normal/instrumented operation and transaction gas. [The optimized measurement snapshot](../test/fixtures/phase2_segs/packed-table-measurements.json) binds all Solidity sources, generator, bytecode and calibration, with source-independent literal-MSIZE calibration at 320 bytes.

| View | BSP + wall gas | Actual MSIZE after walls | Whole transaction gas |
| --- | ---: | ---: | ---: |
| angle0 | 86,766,473 | 7,940,128 | 443,471,585 |
| angle1 | 75,608,869 | 7,600,704 | 432,231,436 |
| angle2 | 34,840,360 | 6,789,632 | 391,263,704 |
| angle3 | 38,836,460 | 6,847,616 | 395,274,319 |
| angle4 | 40,599,073 | 6,838,880 | 397,035,204 |
| angle5 | 38,973,419 | 6,848,192 | 395,412,176 |
| angle6 | 34,907,680 | 6,790,432 | 391,332,733 |
| angle7 | 70,239,634 | 7,514,464 | 426,841,894 |

Setup ends at 6,624,576 actual touched bytes in this probe. The earlier isolated wall snapshot remains in `measurements.json`; its different shared-state/source hashes remain explicit. Neither snapshot includes plane/sprite drawing or proves complete-frame performance. All final Phase 0/1 runners and full-renderer measurements remain required.

```sh
python3 tools/tables/generate.py
.toolchain/bin/forge test --fuzz-seed 0x44
node tools/reference/phase2_segs/benchmark.mjs --output artifacts/local/phase2-wall-packed-tables.json
```
