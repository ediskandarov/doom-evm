# Original P_Setup allocation boundaries

This observation-only harness links the original native translation units through the frozen zone-lifecycle harness. It adds one stage observation after the original P_GroupLines completes. No arithmetic, allocation decision, input, or rendering behavior is replaced.

The original browser six-command stream supplies the baseline. All original frames, tick/world snapshots, diagnostics, events and summaries remain byte-identical. O0, O2, ASan+UBSan, and ASan+UBSan with allocation fill 0xa5 agree on the new observations.

The geometry boundary precedes the temporary THINGS cache and actor/special spawns. Its 25 completed outer allocation operations include BLOCKMAP cache, pointer-sized blocklinks, seven map arrays with their temporary cache/free calls, REJECT cache and the sector-line pointer buffer. FreeTags boundary events are retained in the compressed event evidence; the compact digest excludes that outer boundary operation. The full setup boundary also includes the actual 210 original actors and nine original light thinkers.

`geometry-operations.bin` contains a BE32 count followed by seven BE32 words per operation: operation, requested size, tag, logical owner, header offset, block size, and rover offset after the call. The rolling digest starts with 32 zero bytes and hashes the previous digest plus each 28-byte record. `geometry-summary.bin` stores count and digest.

`*-headers.bin` contain the agreed normalized zone headers and owner slots from the lifecycle/startup proof. Pointer bytes, unknown IDs in fresh free fragments, and unrelated body bytes are not claimed portable. JSON observations are deterministically gzip-compressed.

These fixtures are comparison-only evidence. Runtime Solidity derives allocation order and sizes from original source and authenticated parsed resources, never this operation tape. This checkpoint alone makes no claim of full EVM setup or browser acceptance.

Generation: `python3 tools/reference/phase3_zone_setup/reference.py`

Reproduction: `python3 tools/reference/phase3_zone_setup/reference.py --check`

The executed generation session 47812 passed all four profiles. The manifest binds the source adapters, original source/compiler profile, and all exported fixture hashes.
