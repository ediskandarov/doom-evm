# Original resource oracle and ordinary EVM benchmark

The native oracle, Foundry comparisons and ownership mapping are documented in [PHASE2-DATA.md](../../../docs/PHASE2-DATA.md). The ordinary-deployment benchmark below closes the resource placement/memory measurement gap left by test-only `vm.etch` fixtures. It does not claim a complete renderer frame.

```sh
python3 tools/reference/phase2_data/reference.py --check
python3 tools/reference/phase2_data/prepare_chunks.py
.toolchain/bin/forge test --match-contract RDataTest -vv
node --test tools/reference/phase2_data/instrument.test.mjs
node tools/reference/phase2_data/benchmark.mjs
```

The benchmark requires the hash-pinned Phase 1 bundle at `artifacts/local/wad`. It creates an isolated Anvil on localhost port 18561 (`--port` overrides), runs ordinary `eth_sendTransaction` CREATE for all **1,755** real resource chunks, fetches every runtime with `eth_getCode`, and checks exact STOP-plus-payload bytes. Bundle schema, canonical bundle identity, snapshot identity, contiguous directory bounds and original blob hash are verified before starting. No `etch`, `setCode` or custom interpreter opcodes are used. The server is stopped at the end. The default report is `artifacts/local/phase2-resource-access.json`; `--output` selects another path.

The retained [ordinary-evm.json](ordinary-evm.json) is an isolated benchmark snapshot bound to its recorded source and runtime hashes. Later shared renderer fields can change layout/cost; rerun against the final integrated tree rather than treating these numbers as timeless. The snapshot precedes the shared colormap-cache amendment. Compiling the probe with the pinned viaIR optimizer can take approximately 90 seconds on this host.

## Actual interpreter memory

Solc's viaIR optimizer disallows inline `MSIZE`. A dedicated `memorySize()` helper in `ResourceAccessProbe` contains a marked `GAS`. `instrumentGasMarkers` in [instrument.mjs](instrument.mjs) walks decoded opcodes and the compiler source map, selecting only GAS instructions attributed to that helper. It replaces those single-byte opcodes with **ordinary EVM MSIZE** in a separately deployed measurement probe. No production renderer is patched. The optimizer cloned this marker to 13 locations in the retained build; all PCs, exact source spans, source text and original/instrumented bytecode hashes are retained.

GAS and MSIZE each cost two gas and push one stack item. The creation/runtime lengths, jump destinations, PUSH payloads and every other byte are unchanged. The source-map selection fails closed if no marker is found or the runtime embedding is ambiguous. A negative test proves an unrelated GAS and a GAS-valued PUSH immediate are untouched.

For each operation, the script verifies:

1. Original and instrumented deployed runtimes equal their expected bytecode exactly.
2. Output resource digests agree between probes and with independently checked bundle/native data.
3. Every recorded operation gas delta agrees between probes.
4. Entire ordinary transaction receipt gas agrees between probes.
5. Returned MSIZE values are multiples of 32.

A separately deployed 14-byte calibration runtime expands memory with MSTORE8 at offset `0x123`, reads literal MSIZE and returns **320**. An independent stack-only trace decoder obtains the same result. The decoder is exported alongside the patcher for bounded calibration; it rejects nested interpreter frames rather than silently mixing their memories. This telemetry approach avoids multi-million-step traces for eager initialization.

To reuse the patcher, import `instrumentGasMarkers(artifact, sourceText, helperName)` and ordinarily deploy the returned creation bytes. The artifact must contain compiler deployed source maps and the source-file ID. Always retain the returned report and independently check output/gas equality for the measured calls. The helper must only collect telemetry: its changing return value must not control rendering, indexing, memory allocation or output digests.

## Retained results

All resource uploads together consumed **6,271,928,016 gas** across 1,755 independent transactions; this is cumulative setup cost, not one transaction. The normal probe's storage directory/address setup and deployment consumed **127,079,646 gas**. It stores the original resource directory and addresses; memory is reconstructed per measured call.

| Operation | Whole ordinary transaction gas | Operation gas | Actual MSIZE after operation |
| --- | ---: | ---: | ---: |
| 16-byte read crossing a chunk boundary | 11,834,639 | 7,030 | 462,656 |
| Lazy initialization | 62,126,041 | 50,213,639 | 2,332,768 |
| Eager initialization | 538,507,831 | 526,329,500 | 10,312,224 |
| Lazy initialization + map load | 187,895,511 | 125,836,623 for map | 6,163,680 |
| First direct column / cached next column | 62,708,262 combined | 486,182 / 1,476 | 2,359,488 / 2,359,552 |
| First flat / cached same flat | 62,127,363 combined | 42,598 / 405 | 2,336,896 / 2,336,896 |

Whole transaction gas includes roughly 11.8 million gas to reconstruct the memory ResourceView from storage, initialization where applicable, checksums and ABI results. The cross-boundary copy itself costs only 7,030 gas. “First” means uncached in this memory frame; initialization can already warm code accounts. A cached column reuses its patch bytes and allocates a new 64-byte ColumnView. A cached flat reuses its allocation with zero memory expansion.

Memory values are actual interpreter MSIZE at explicit boundaries, not the free-memory pointer. The report also records a final marker after digest generation; ABI return encoding may occur after that marker, so it is not labeled a whole-call peak. The full renderer must be measured in its own call context.
