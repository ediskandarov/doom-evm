# Interactive E1M1 blood-sprite DrawBounds investigation

This is a post-Phase-3 correction. The frozen Phase 3 certificate and earlier
measurements remain historical evidence for their exact sources and scope.
Phase 4 telemetry and the planned memory audit are unchanged.

## Exact failure and preserved state

The reported transaction is
`0xfb434064c3b69ab521010869b0906ca7e8dd4340ad95d4e5f2fd91176f3e3030`,
block `0xe09`, contract `0x631cc89bab95812b5fbdfd65a039a103210105b5` on
local Anvil `http://127.0.0.1:18579`. It calls `stepAndRender(0,445)`.
Four attempts at the same command reverted with `0x5b9a48fe`, each using
659,898,736 gas from a 10,000,000,000 gas allowance. This is a bounds rejection,
not gas exhaustion, a compilation stack limit or an EVM memory-limit error.

Read-only capture recovered transaction/receipt, contract runtime, accessed
prestate, immutable resource code, all 444 successful held-key inputs and the
four failed attempts. The live runtime exactly matched the local accepted
502,443-byte artifact after binding the driver immutable. The contract storage
root was checked before and after capture. No reset, mine, transaction, code
replacement, storage injection or policy change was sent to that live node.
A full `anvil_dumpState` request closed its connection; targeted prestate and
resource captures succeeded instead. The live process remained reachable.
Large private state/trace captures stay under ignored
`artifacts/local/drawbounds-crash/`, not in Git.

Error-only bytecode instrumentation on a separate diagnostic clone redirected
individual bounds branches to labelled memory captures. The exact branch was
ordinary `R_DrawColumn`'s physical-tail knownness check in `r_draw.sol`, baseline
PC 416446 (line 57). Bounds checks in production were not patched or relaxed.

| Captured input | Value |
|---|---:|
| Resource | `BLUDA0`, authenticated lump 1546 |
| Logical source length | 324 bytes |
| Masked post offset / source offset | 202 / 205 |
| x / yl / yh / centery | 123 / 178 / 198 / 100 |
| dc_iscale / post-adjusted dc_texturemid | 9472 / -738855 |
| spryscale / sprtopscreen | 453406 / 10305097 |
| Initial frac | -39 |
| Original masked sample | `(-39 >> 16) & 127 = 127` |
| Absolute source index / tail index | 332 / 8 |
| Source zone block offset / size | 12783792 / 368 |
| Successor offset / size / owner | 12784160 / 240 / lump 1547 (`BLUDB0`) |
| Tail knownness at index 8 | unknown, marker 0 |

The source allocation rounds 324 bytes to 328, followed by a 40-byte LP64
allocator header. Index 332 addresses the successor header at byte 4. Its size
occupies bytes 0–3; its user pointer starts at byte 8. Bytes 4–7 are ABI padding.
The draw is a blood effect from combat, not the monster animation, weapon
sprite or a wall texture/composite read.

## Native evidence and behavioral deviation

Pinned original `R_DrawMaskedColumn` and `R_DrawColumn` produce exactly the
captured arithmetic. Original `I_ZoneBase` uses `malloc`; `Z_Init`, `Z_Malloc`,
`Z_Free`, and tag changes write header fields individually and do not initialize
this padding. Therefore the accessed byte has no value defined by the original
source. It is inside the allocated zone, though beyond the logical lump.
ASan not reporting an allocation overrun does not establish initializedness.

`tools/reference/drawbounds_blood/reference.py` compiles the actual unchanged
draw bodies and allocator with the already accepted LP64 align8 adaptation.
Under controlled initial heap patterns 0, 85 and 165, original allocation leaves
this padding unchanged, and the original first pixel changes with that pattern.
O0, O2 and ASan/UBSan agree within each profile. These patterns demonstrate
initial-state dependence; they are not observations of the original process's
uninitialized `malloc` contents and are not universal native pixel goldens.

The explicit local platform policy initializes the zone domain to zero before
original allocation begins. It matches the existing native gameplay host's
`calloc` backing. It is a documented deviation from unmodified native
`I_ZoneBase`, not a renderer correction or a claim of pixel-perfect equivalence
with every native process. Frames depending on initial-zone bytes are compared
only with that explicitly initialized native profile. Renderer arithmetic,
allocation order, original LP64 memory layout and physical addresses are kept.

## Initialization and provenance

`initializeGame()` selects deterministic initialization for new production games.
The driver can instead call `initializeGameStrict()` before startup to retain
source-written-only rejection. The internal `DoomGame.initializeNative` and
`Z_Init` defaults stay strict for the established diagnostic/native gates.
Initialization is chosen before allocations, not retroactively after a crash.

The physical reader exports three provenance classes through
`Z_ZoneBacking.tailWithProvenance`:

- 1: current original source-written integer headers or authenticated cached bytes.
- 2: untouched bytes of the explicitly zero-initialized initial-zone domain.
- 0: unknown, unmodeled, overwritten without retained byte evidence, or invalid.

The drawing API retains its existing readable marker and all its guards; binding
converts either supported provenance class to that marker. It never treats an
unknown byte as readable. Ordinary in-lump reads and fully source-written tails
retain their original path.

The sparse policy does not allocate a 64 MiB EVM byte array. Historical block
records and a monotonically increasing maximum requested payload extent exclude
all potentially written bodies at each header address. These extents survive
freeing, coalescing, splitting/reallocation and `Z_ClearZone`. Historical header
pointer/tag/ID regions are excluded as well. Current source-written values take
precedence. Only source-unwritten bytes outside those excluded regions can
retain initial-zero provenance. The initial zone header and out-of-zone addresses
are never seeded by this reader. Pointers remain unknown.

Requested-body ranges are conservatively treated as potentially written because
mutable object/composite bodies and obsolete cached payload contents are not
fully reconstructed. This may reject a reused byte whose original value could
be recovered by a future fuller backing model; it must never silently fill it.
Unwritten alignment slack can be initialized only if no prior written range
covered it. Clear does not reseed memory. No asset name, sprite frame, texture
coordinate or pixel value selects policy behavior.

The metadata additions fit existing packed Solidity storage words. Native C
allocation sizes/offsets stay unchanged. This is not a live-deployment migration:
the original deployment remains untouched, and enabling a policy on incomplete
historical metadata is not supported. A corrected game is rebuilt from its
captured input history on a separate node.

## Verification ledger

Implementation and verification are tracked separately. The six focused tests
pass, including the actual first blood post, strict-mode rejection, reuse and
Clear histories, a five-length allocation matrix, source/initialized/unknown
provenance, pointer rejection and out-of-zone rejection. The existing 80 native
backing cases and original allocator tests also pass unchanged.

The captured 445-command native replay passes O0, O2 and ASan/UBSan under explicit
zero-initialized backing. Full Foundry passes 409 tests (including the original seed0x44 gate), with
compiler settings unchanged. All 21 remaining Phase2 commands pass with fresh
measurement/browser evidence and source guards; format/Foundry/Foundation gates
are recorded separately rather than repeating forced builds. The 32 Phase3
native/JavaScript/telemetry regression commands pass (53 JavaScript and50
telemetry tests). The unchanged frozen feature audit correctly rejects new
source hashes; a separate compatibility audit refreshes current source bindings.
The old feature matrix and acceptance evidence remain unchanged.

Ordinary production CREATE and every one of the captured445 inputs pass against
the explicitly initialized native profile: 446 status/view observations with14
fields and445 whole64000-byte frames have zero differences. This includes the
reported blood post. A second ordinary deployment of the same artifact selects
strict startup, matches the preceding444 frames and gameplay fields, then
reproduces DrawBounds at445 with no Frame or committed gameplay change.
The nine existing whole-world scenarios also pass2355 tics,31 frames and nine
final stored-state comparisons, using their existing strict native profile.

| Measured ordinary transaction | Gas |
|---|---:|
| Historical reported failure (old unchanged runtime) | 659,898,736 |
| Corrected atomic deterministic initialization | 1,712,979,721 |
| Corrected captured tic445, successful full Frame | 1,792,487,625 |
| Corrected initialized replay frame range | 674,869,826–1,971,621,098 |
| New strict initialization | 1,713,104,122 |
| New strict tic445, expected DrawBounds | 673,665,669 |

All budgets remain10B; no compiler/memory/code limits or initialization algorithms
are changed. The new measured artifact is518359 runtime bytes (driver-template
SHA256 `2bdbf5e724432ba89ae8fd462a4c2f743527ea8f1d7c1690a0090bef94fce5eb`).
The historical502443-byte artifact and its measurements remain distinct.
Existing selective-root builds can produce another bytecode variant with the
same engine sources/settings; the two captured replay modes explicitly use the
same retained artifact.

All12 Phase0 and13 Phase1 command gates pass, including the original resource
placement/palette browser checks. One lifecycle attempt was sandbox-blocked and
was rerun with permitted loopback networking. The resource-placement gate's
unchanged120-second timeout required a separately completed455.54-second
prebuild; the actual benchmark then passed with a warm cache. Compilation remains
an independent resource/runner concern, not gas exhaustion.

The separate compatibility checkpoint and source audit bind all current engine
hashes and refresh388 function mappings. Five audit integrity tests reject
missing/failed gates, tampered current hashes and changed historical acceptance
identity. They neither modify nor relabel the original certificate, feature
matrix, reports or hashes. The final518098-byte artifact was independently
replayed for all445 tics as well (template SHA256
`e10accea72a1b160c22aca016f9965f8435975a8d7bf187fc99b618a7b2c6667`),
with identical per-tic gas and full frames to the first measured variant.

The existing129-tic public-contract gate also passes on that final artifact,
including six native live frames, a static pre-start frame and all13 complete
storage-root rollback/error checks. The unchanged actual Chrome interaction gate also passes six complete frames,
native status/view fields, Canvas pixels, receipt fallback, duplicate suppression
and blur/release behavior. Test configuration/palette changes were restored to
the original18579 deployment afterwards. This is a post-acceptance compatibility checkpoint, not a rewritten or
retrospectively refreshed Phase3 acceptance certificate.

Commands:

```sh
python3 tools/reference/drawbounds_blood/reference.py
python3 tools/reference/drawbounds_blood/replay_native.py
.toolchain/bin/forge test --fuzz-seed 0x44 -vv
node tools/reference/drawbounds_blood/replay.mjs --rpc http://127.0.0.1:18690
node tools/reference/drawbounds_blood/replay.mjs --rpc http://127.0.0.1:18690 --strict --artifact artifacts/local/drawbounds-crash/production-artifact.json
```

The production replay needs the private capture's constructor metadata and
immutable resources on an isolated node. The committed compact fixtures contain
the 445 inputs, native status/view observations and the two final native frames;
they never provide world geometry or pixels to the engine.

## Separate evidence and audit

- [Compatibility verification checkpoint](../artifacts/phase3/drawbounds-compatibility.json)
- [Current source/function audit](../artifacts/phase3/drawbounds-source-audit.json)
- [Regression command evidence](../artifacts/phase3/drawbounds-regressions.json)
- [Initialized captured replay](../artifacts/phase3/drawbounds-replay-initialized.json)
- [Strict captured replay](../artifacts/phase3/drawbounds-replay-strict.json)
- [Final artifact captured replay](../artifacts/phase3/drawbounds-replay-final-artifact.json)
- [Whole-world kernel regression](../artifacts/phase3/drawbounds-kernel.json)
- [Storage layout verification](../artifacts/phase3/drawbounds-storage-layout.json)

Refresh/check only the new bindings with `python3 tools/audit/compatibility.py`
and `python3 tools/audit/compatibility.py --check`. The original acceptance/source
audit is unchanged and deliberately does not certify newly changed sources.

- [Public transaction/authentication/rollback regression](../artifacts/phase3/drawbounds-public-production.json)
- [Actual Chrome regression](../artifacts/phase3/drawbounds-browser.json)
