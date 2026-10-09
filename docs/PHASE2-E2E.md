# Ordinary EVM and browser renderer evidence

`tools/renderer/verify.mjs` deploys authenticated original resources and the real
`Doom` contract, compares all eight full native views through a separate probe,
and runs the existing browser gate against genuine production Frame events.
The committed report is `tools/renderer/evidence/renderer.json`; all eight
frame artifacts, an intermediate wall frame, raw production/rejection receipts,
and the actual browser screenshot are adjacent to it.

Generated images contain Freedoom artwork, copyright the Freedoom contributors,
redistributed under the [Freedoom BSD license](../test/fixtures/wad/COPYING.txt).
The source WAD identity and attribution remain in each reference artifact.

## Reproduce or run interactively

After the normal toolchain and pinned WAD preparation:

```sh
node tools/renderer/verify.mjs --output-prefix artifacts/local/renderer --port 18567
```

To leave the verified real deployment available for the browser:

```sh
node tools/renderer/verify.mjs --output-prefix artifacts/local/renderer --port 18567 --keep-alive
```

Once verification reports success, run this in a second terminal in the same
checkout and open `http://127.0.0.1:8080`:

```sh
node tools/transport/serve.mjs
```

The verifier has written the real contract configuration and pinned palette to
ignored local web files. The page reads the current input counter, so another
click submits the next valid transaction. This is the static E1M1 world view;
buttons other than zero are explicitly unsupported until gameplay is ported.
Ctrl-C in the verifier terminal terminates its owned Anvil. Without
`--keep-alive`, the node terminates automatically in `finally` after the checks.
An occupied port is rejected before spawning; existing nodes are never reused
or stopped. Compilation permits 300 seconds without changing any acceptance
assertion.

## What the evidence proves

1. All 1,755 chunks are deployed through ordinary CREATE. Every full runtime
   equals the expected `STOP || original payload`, including the short final
   chunk. Schema, canonical bundle identity, blob, packed directory, and ordered
   runtime hash commitments are verified against the pinned source.
2. Production Doom and both probe variants inherit the unchanged authenticated
   WadResources constructor. The real deployed Doom runtime equals its compiled
   artifact after substituting only the artifact-declared immutable driver
   offsets with the actual deploying account. Its driver and all identity fields
   are read back.
3. All eight probe calls execute the same DoomRenderer.initialize/render as
   production. Each case binds its manifest name and `mode=full`, camera,
   resource identity, counts, tic zero, palette, and all 64,000 pixel bytes.
   Every native pixel diff is zero. No visibility, projection, native trace, or
   framebuffer is supplied as an EVM rendering input.
4. Two separate real Doom transactions exercise stepAndRender and renderFrame.
   Each emits exactly one full Frame with sequential frame/input identifiers.
   Every WebSocket payload byte equals its receipt. Four mined rejections cover
   wrong driver, nonzero buttons, replay, and skipped input; each has status 0,
   no logs, and unchanged public counters.
5. A separate probe emits a genuine wall-only Frame, matching `walls-angle0`
   exactly. Production Doom remains full-only.
6. The existing browser checker consumes real Doom with `--existing-config` and
   the actual WAD palette. It verifies every byte of the final receipt and every palette-expanded
   pixel in the final Canvas readback, reconnect/backfill deduplication, and
   receipt fallback. The ordinary verifier also checks both browser transactions
   against the native frame. Its two
   transactions advance real Doom to frame/input four. Raw receipts are retained.

The report includes the renderer commit, all Solidity compiler input hashes,
verification dependency/schema hashes, table/info generator hashes, compiler
settings and versions, and SHA-256 of the actual Anvil/Solc/Forge/Node binaries.
Reference-v0 artifacts identify the EVM build separately from the native build.
PNG generation only palette-expands already-rendered bytes; diff PNGs mark
mismatches red and are black for these exact comparisons.

## Observed costs and timing

The full authenticated resource upload costs 6,271,928,016 gas cumulatively over
1,755 transactions. The actual Doom deployment costs 175,935,017 gas and has
165,797 runtime bytes. These measurements use the documented local Cancun
Anvil settings: relaxed code/block limits, a 1 billion gas transaction ceiling,
and a 1 GB memory limit. They are ordinary EVM execution, not a claim that this
contract fits public Ethereum deployment limits.

The first real full Frame costs 590,974,330 gas; the subsequent renderFrame
costs 590,957,053. The wall-only event costs 529,844,189. Across all eight probe
views, whole transaction gas ranges from 493,302,483 to 590,075,082.

On this local run, full-frame eth_call takes roughly 0.3–0.4 seconds and real
Frame send-to-receipt roughly 0.5 seconds. The report retains individual measured
values, rather than treating these timings as performance guarantees.
eth_call duration includes RPC/client overhead; it is not isolated interpreter
CPU time. Send-to-receipt includes execution, mining, and RPC delivery.

Browser timing is gathered by an optional checker-injected script, leaving the
application and default mock gate unchanged. It observes RPC send/receipt,
WebSocket arrival, and actual Canvas putImageData. Both browser frames reach
Canvas in roughly half a second, one through WS and one through receipt
fallback. Canvas-only timings can round to zero at the browser clock's
resolution. They are distinct from the positive input-to-Canvas durations.

## Literal EVM memory, separately qualified

Only the separate RendererProbe's source-mapped GAS marker instructions become
ordinary MSIZE instructions. The instrumenter validates source spans and exact
changed byte offsets; both instructions cost two gas and push one word, so code
layout remains unchanged. Normal and instrumented constructor gas, operation
gas, whole transaction gas, camera/counts, and all pixel bytes agree.

At angle zero, literal MSIZE boundaries are 1,088 bytes at probe entry, 462,752
following the stored resource view copy, 6,825,728 following initialization,
and 9,027,840 following the full render. Other viewpoints end between 7,294,144
and 9,027,840 bytes. These are actual EVM memory sizes in the separate probe,
not Solidity free pointers, and **not asserted to be exact production Doom
memory or whole-call peaks**. ABI return encoding occurs after the last marker.
A separate ordinary calibration contract's literal MSIZE 320 agrees with a
stack-only opcode trace decoder.

Anvil and Node RSS are sampled separately and explicitly labeled as host memory.
The short four-production-frame run does not establish a long-running memory
budget or reset interval. Production emits no telemetry logs.

The optional browser hook was checked with the unchanged default mock browser
gate and the missing-Chrome lifecycle regression; both pass. Final acceptance
also reruns inherited Phase 0/1 and all native/Forge gates on the integrated
source tree.
