# Phase 0: but can it emit a frame?

**Passed with a synthetic fixture; this is not a DOOM renderer or C port.**
`src/support/FrameFixture.sol` has no upstream C counterpart. Its 320×200 bytes are generated in Solidity as `(pixelOffset + inputSeq) % 256`, then emitted in one `Frame` event. The browser only expands received palette indexes into RGBA and writes Canvas `ImageData`. No scene geometry, WAD data, visibility, or engine code exists in this spike.

## Reproduce

Use the project's pinned toolchain and Node **24.11.0** (built-in `fetch` and `WebSocket`); there are no npm dependencies.

```sh
.toolchain/bin/forge test --match-contract FrameEventTest
node --test tools/transport/protocol.test.mjs
node tools/transport/benchmark.mjs
node tools/transport/browser-check.mjs
```

The benchmark starts an isolated Anvil on localhost port 18546, normally deploys the fixture, subscribes before sending transactions, runs assertions, saves `artifacts/local/transport.json`, and stops its child node. `--port 18550`, `--frames 10`, and `--output /tmp/transport.json` are available. `--frames` is bounded to 2–100. Receipt and readiness waits are bounded to 30 seconds; WS acknowledgement is bounded to 10 seconds. Memory sampling uses `ps` every 100 ms and therefore requires a Unix-like host. Local listeners/process launches may require environment permission.

The browser check starts its own Anvil on 18549 and a temporary HTTP server, runs the same transaction checks, launches installed Chrome headlessly with a fresh temporary profile, verifies every Canvas pixel against a mined receipt, captures a screenshot, and cleans up its child processes/profile. It uses Chrome DevTools Protocol directly. On another OS, set `CHROME_BIN` to a Chrome/Chromium executable; `BROWSER_ANVIL_PORT` changes its Anvil port. This is not a browser-version compatibility matrix.

For an interactive browser with a persistent node:

```sh
# Terminal 1: keep the configured project node running.
./scripts/start-anvil.sh
# Terminal 2: deploy and exercise a new fixture on that node, then serve its config.
node tools/transport/benchmark.mjs --rpc http://127.0.0.1:8545 --ws ws://127.0.0.1:8545
node tools/transport/serve.mjs
# Visit http://127.0.0.1:8080
```

The explicit `--rpc` mode assumes a disposable **local Anvil with unlocked accounts**. It deploys a new fixture and sends test transactions, but does not change or claim to verify that node's startup limits. Do not connect this test driver to a public network. `web/config.local.json` points at the new deployment and is ignored by Git. Self-managed benchmark/browser commands stop their node on completion, so their generated config is not a persistent demo session. Reloading a page reads `inputSeq()` before allowing more input; one page must act as the driver.

## Executable acceptance

| Requirement | Evidence |
|---|---|
| Exactly one successful Frame with 64,000 indexed8 bytes | Foundry checks every byte of two frames; real benchmark asserts receipt has exactly one log, correct dimensions/IDs and every byte of three frames. |
| Single driver, strictly consecutive sequence starting at 1 | Contract errors; Foundry invalid-driver/replay/gap/button tests; benchmark mines driver/replay/gap failures. |
| Transaction rollback covers state and events | Real Anvil receipts for wrong driver, replay, gap, out-of-gas, and an intentional revert **after emit** all have status 0 and zero logs; both counters remain unchanged. Foundry separately proves state rollback. |
| Subscribe before transaction, complete WS payload | Subscription acknowledgement precedes first send; all ABI data and topics from each WS notification equal its transaction receipt. |
| WS disconnection recovery | Benchmark and browser deliberately close WS for a frame, render from the receipt, resubscribe, and `eth_getLogs` backfill without duplicate display. Unexpected browser disconnect also retries subscription/backfill. |
| Deduplication and ordering | Shared `FrameInbox` uses `(txHash, logIndex)` and increasing `frameId`; unit tests cover repeats, old arrivals, gaps, and removed logs. Displaying the latest frame across gaps is permitted. Removed notifications invalidate the browser session and disable input until reload. |
| No overlapping input transactions | Browser locks the input until its receipt arrives; ambiguous send/receipt errors keep input disabled. Benchmark always awaits the preceding receipt. |
| Palette identity | Separate `web/palette.synthetic.json`, schema v0, 768 grayscale RGB bytes, SHA-256 and resource identity; browser verifies hash and configured identity before enabling input. Copied from the schema agent's synthetic bundle fixture. Zero WAD SHA denotes no WAD. |
| Real Canvas | Browser check compares all received indexed bytes to the actual receipt and hashes all 256,000 Canvas RGBA bytes against the palette-expanded receipt; screenshot is supplementary evidence. |

The transport parser intentionally implements only the frozen Frame ABI and fixture call. Its constants were generated using pinned `cast sig-event` / `cast sig`. A general Ethereum client library can replace it when the real adapter API expands; no architecture depends on this small ABI implementation. Reorganizations are surfaced as a session error, not silently displayed as valid frames. This local demo is a single-driver transport experiment, not a production chain observer.

## Recorded run

Measured on 2026-10-09, macOS, Anvil 1.8.5, Solidity 0.8.37 (`f401782d`), via-IR + optimizer 200 + Cancun; Node 24.11.0. Raw evidence: [transaction report](../tools/transport/evidence/transport.json), [browser report](../tools/transport/evidence/browser.json), [Canvas screenshot](../tools/transport/evidence/browser.png). Host timings are observations, not performance targets.

| Frame | Pixel bytes / ABI data bytes | Gas used | Send → receipt observed | Send → WS observed |
|---|---:|---:|---:|---:|
| 1 | 64,000 / 64,128 | 11,622,237 | 28.20 ms | 21.02 ms |
| 2 | 64,000 / 64,128 | 11,605,137 | 25.03 ms | 20.32 ms |
| 3 | 64,000 / 64,128 | 11,605,137 | 25.06 ms | 19.39 ms |

Deployment used 257,429 gas; runtime bytecode was 947 bytes. The frame-1 pixel SHA-256 was `f268e8234ce8f3af96819db5e09a5f129bf0240a0aac37c76bbe42cf4fa4061c`. Successful transactions each requested 1,000,000,000 gas; the mined block's configured gas limit was independently read as 1,000,000,000. Gas includes the deliberately simple per-byte fixture loop and event; it does **not** estimate future DOOM rendering gas.

The process sampling observed Node RSS 146,604,032 bytes, heap used 28,412,104 bytes, external allocation 4,215,327 bytes, and Anvil RSS 31,735,808 bytes (six samples, 100 ms interval). These are sampled peaks of a short process including transport/decode/assertion work, not precise maximum EVM memory or a long-session capacity study. An external-node run records Anvil RSS as unavailable.

Send-response, receipt and WS timestamps come from one monotonic client clock. They include RPC overhead, EVM execution and mining; this test **does not isolate EVM execution time**. Receipt polling adds up to its 20 ms interval. The report includes separate send-response time rather than calling it execution time.

The Chrome 155.0.8059.40 run backfilled existing frames 1–4, displayed newly submitted frame 5 over WS, then frame 6 through receipt fallback with WS closed. Backfill after reconnect was deduplicated (7 duplicates). Every final Canvas pixel matched the mined frame; RGBA SHA-256: `f5ee5ccace341c6eb24fceaf247eba8e46f1a722f2980bcfa2016154c8759fab`.

## Configuration decision

Keep indexed8, one uncompressed event per frame, via-IR and Cancun. This 64 KB payload passed end to end; there is no evidence here requiring chunking, a lower resolution, or a different transport. Frame timing and memory must be measured again with the actual renderer and longer sessions.

Anvil 1.8.5 rejects using `--disable-block-gas-limit` and `--gas-limit` together. The working launch is:

```sh
.toolchain/bin/anvil --host 127.0.0.1 --port 18546 --hardfork cancun \
  --disable-code-size-limit --disable-block-gas-limit --memory-limit 1073741824
```

After readiness, call `anvil_setBlockGasLimit` with `0x3b9aca00` and verify the block header. The benchmark records this post-launch RPC alongside its exact arguments. Transactions still pass an explicit gas budget; this is a relaxed local EVM, not unlimited execution. No custom opcode, precompile, `anvil_setCode`, off-chain synthetic framebuffer injection, or substitute engine is used.
