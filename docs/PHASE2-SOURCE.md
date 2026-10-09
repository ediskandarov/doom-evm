# Authenticated resource deployment

The ordinary EVM verification in `tools/reference/phase2_source/verify.mjs`
deploys the complete pinned resource bundle and exercises the production
`WadResources` constructor through `WadResourcesProbe`. It does not replace
authentication, set contract code, or use Foundry cheatcodes.

Run from the repository root after preparing the pinned local WAD bundle:

```sh
node tools/reference/phase2_source/verify.mjs --output artifacts/local/phase2-source.json
```

The script starts its own Anvil on port 18563 (`--port` overrides this), refuses
an existing RPC server, and terminates its child in `finally`. It uses the
project's Cancun profile with relaxed code/block limits, a 1 GB memory limit,
and a 1 billion gas transaction ceiling. These are project deployment settings,
not a claim of compatibility with public Ethereum block limits.

## Source and authentication

The committed evidence is
`tools/reference/phase2_source/ordinary-evm.json`. Its source hashes identify
the exact implementation measured, including all compiler input dependencies,
the probe, verifier, instrumentation utility, and Foundry configuration. This
run used Anvil 1.8.5 and the production base from commit `d8b3f40`.

Before deployment, verification checks the bundle schema, pinned resource
identity, canonical manifest hash, raw blob hash, contiguous lump offsets,
and exact packed directory fixture. It also runs
`tools/wad/check-source-identity.mjs` to independently check the constructor's
commitments against the pinned inputs.

The 28,741,889 resource bytes are uploaded through 1,755 ordinary `ResourceStore`
CREATE transactions. Every resulting runtime is compared byte for byte with
`STOP || payload`, including the final short chunk. The authenticated base
checks dimensions, directory SHA-256, each runtime length, and SHA-256 of the
ordered sequence of full runtime SHA-256 digests before storing resources.
The constructor reuses one bounded chunk scratch buffer rather than loading
the entire blob into memory.

| Commitment | SHA-256 |
| --- | --- |
| Raw resource blob | `0a07ab5de33592142c3427d29e8f2eaf25d0e4fa21e03ac9c9b0fb5d77531d16` |
| Packed directory | `4acf70e1a550810a0682365afb4a717b8258082e18962f898554eac4dbd1d012` |
| Ordered full-runtime digests | `62a3aec2214b5b7776713b87435b010d6f6300929e3b169d0b6e7e03de01fb6a` |

After ordinary probe deployment, the script checks all five resource identity
fields and an independently reconstructed metadata digest binding blob length,
chunk/lump counts, every stored directory descriptor, and every ordered stored
chunk address. Reads from the beginning, across a 16 KiB boundary, from the
final chunk, and an empty read at the blob end match the pinned bytes exactly.

## Measured costs

| Operation | Transaction gas |
| --- | ---: |
| All 1,755 chunk deployments, cumulative | 6,271,928,016 |
| Authenticated probe deployment | 140,469,519 |
| Full metadata reconstruction and digest | 25,475,024 |
| 16-byte read crossing a chunk boundary, including stored view copy | 11,757,411 |

The upload and exact runtime verification took 53.1 seconds, including client,
RPC, mining, and validation time. The cumulative upload gas is distributed
across 1,755 transactions. The constructor cost includes storage and runtime
deployment as well as authentication; it is not an isolated hashing cost.

Copying the complete stored `ResourceView` costs 11,726,594 gas in this probe.
The subsequent cross-boundary read costs 7,262 gas; ordinary 32-byte reads cost
3,946 gas, and the empty read costs 587 gas. This supports creating one resource
view per render invocation and reusing it for all resource operations.

## Literal memory measurements

The normal probe is also deployed as a separate instrumented copy using the
existing source-map-checked utility in `phase2_data/instrument.mjs`. Only four
GAS instructions attributed to the probe's `memorySize` helper become MSIZE;
instruction size, stack effect, gas cost, and bytecode layout remain unchanged.
The report records the source spans, program counters, and both runtime hashes.
Constructor logic and the production base are unchanged. Constructor gas,
read operation gas, output digests, and complete read transaction gas agree
between normal and instrumented deployments.

For each nonempty read, literal EVM MSIZE is 416 bytes at entry, 462,080 after
the stored view copy, 462,144 after the range read, and 462,208 after hashing.
For the empty read, the final two values are 462,112 and 462,144. These values
are actual EVM memory sizes at these boundaries, not Solidity free pointers.
ABI return encoding follows the last marker, so they are not asserted to be
whole-call peaks. Constructor memory was not instrumented. A separately
deployed calibration program writes at byte offset 0x123 and returns literal
MSIZE 320, agreeing with an independent stack-only trace decoder.

## Mined rejection evidence

Each adversarial case first checks the precise constructor revert selector
through an ordinary creation `eth_call`, then submits a genuine CREATE
transaction. All three receipts have status 0, no logs, and no runtime code at
the attempted deployment address.

| Changed input | Rejection | Transaction gas |
| --- | --- | ---: |
| One packed directory byte | `DirectoryIdentity()` | 3,448,120 |
| One final payload byte in a newly deployed real chunk | `ChunkIdentity()` | 23,756,367 |
| Missing chunk addresses | `ResourceDimensions()` | 1,837,420 |

The report retains every successful chunk transaction, runtime digest, and
length, both authenticated probe deployments, read transactions, and failed
deployment transactions. All addresses and transaction hashes refer to this
isolated local Anvil run, which the script shuts down after verification.
