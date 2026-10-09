# Phase 3 acceptance report

**M2 movement and M3 basic gameplay passed.** The original DOOM gameplay
functions execute inside the ordinary local EVM against authenticated Freedoom
E1M1 resources. The browser submits keyboard input and displays indexed pixels
from Frame events; it performs no movement, visibility or scene rendering.

The [acceptance certificate](../artifacts/phase3/acceptance.json) checks all fifteen
unchanged requirements, tested source hashes and final production build identity.
The [progress ledger](PHASE3-PLAN.md) records implementation/integration/checkpoint
commits, history and recovery commands. The [feature matrix](PHASE3-FEATURE-MATRIX.md)
separates implemented functions, controlled module coverage, observed world
streams and unsupported profiles.

## Executed acceptance evidence

| Proof | Executed result |
|---|---|
| [Whole kernel](../tools/reference/gameplay/final-kernel-evidence.json) | Nine real E1M1 scenarios, 2,355 original logical tics, 31 exact 64,000-byte frames and nine exact final stored snapshots. Ordinary deployment and all 1,755 resource runtimes byte-checked. |
| [Public production](../tools/reference/gameplay/production-release-evidence.json) | One atomic initialization; 129 physical keyboard packets; 130 rows × 14 exported fields; six live native frames plus static pre-start Frame; thirteen rejection checks with whole-storage rollback. |
| [Independent replay](../tools/reference/gameplay/production-release-reproducibility-evidence.json) | Two fresh ordinary contracts agree on every field, command, sequence, rendering cadence, seven Frame hashes, receipt/init/constructor gas and all thirteen guard records. |
| [Actual Chrome](../tools/transport/evidence/gameplay-browser-release.json) | Six native indexed frames and Canvas RGBA buffers exact; 84 field comparisons; actual Start/Resume and DOM keyboard for five commands, controlled receipt fallback for the sixth; blur and deduplication verified. |
| [Original startup](../tools/reference/phase3_zone_setup/final-validation.json) | All native normalized allocation headers/owners, actors/lights and nine map slots exact; four tests within the complete Foundry run; 54 compiler source bindings checked. |
| [Memory](../tools/reference/gameplay/production-release-memory-evidence.json) | Six all-render tics and six production-cadence tics on three ordinary deployments: production and two marker clones. Storage, exported fields, native frames and paired-clone gas agree. |
| [Frozen regressions](../artifacts/phase3/final-verification.json) | All 24 Phase 2 commands plus documentation, all 12 Phase 0 and 13 Phase 1 gates, 403 Foundry tests in 40 suites, and all 33 Phase 3 native/local commands pass. No skipped/failed Foundry tests; fuzz seed 0x44. Source/HEAD/pristine-submodule guards pass at 9279bf9. |

The kernel scenarios cover idle, movement, pistol, combat, armor/damage, death,
real door use, obstructed door reversal and rocket flight/blast/kill/removal.
Original collision, all nine weapon actions, all 64 enemy functions, thinkers,
pickups, movers, lights, switches, teleport and numeric-special dispatch have
additional controlled native module proofs. Their broader branch coverage does
not imply every branch or species ran in the finite integrated E1M1 streams.

## Local execution and measurements

The default local budget is **10 billion gas**, configurable in
`execution-budget.json` or through `DOOM_GAS_LIMIT`. All Anvil, transaction,
harness and verification consumers share it. Direct Forge commands use their
native `FOUNDRY_GAS_LIMIT`; `source scripts/env.sh` propagates the shared policy.
There is no economic gas-efficiency target.

Original resource preparation and level/player startup run in one
`initializeGame()` transaction. No public preparation stage remains, and no
original startup algorithm is split to satisfy the historical one-billion cap.
Solc 0.8.37, viaIR, optimizer 200, Cancun and the existing code/memory policies
remain unchanged. The inherited build timeout was increased to accommodate a
measured 497.56-second dependency build; every correctness command/assertion
remains intact.

| Actual ordinary production operation | Gas |
|---|---:|
| Atomic initialization | 1,621,885,757 |
| No-render tic | 309,171,400–312,238,893 |
| Selected rendered tic | 719,455,170–781,684,253 |

These are executed transaction receipts, including storage and optional
render/event work. Probe serialization gas is separate. Historical 1B/staged
and earlier atomic measurements remain preserved with their original hashes.

| Measured clone engine boundary | Bytes |
|---|---:|
| Initialization | 19,665,056 |
| Static frame | 8,841,664 |
| No-render tic | 8,749,760–8,753,856 |
| Live frame | 11,918,816–11,956,800 |

These literal MSIZE readings exclude later observer encoding and separate call
frames. Clone code generation can change memory reuse, so an exact untouched
production peak is **unmeasured**.

The final inherited renderer command builds three explicit roots and emits a
502,443-byte production runtime. A full-project build produces a different
503,731-byte artifact from identical consumed sources/settings. Both full
production profiles are verified and retained. Current acceptance binds the
renderer-emitted artifact, its exact build command and hashes; gas/artifact
identities are never conflated. The isolated measurement-clone build leaves
that production artifact unchanged.

## Run and reproduce

After the inherited verifier has prepared the pinned WAD/resources:

```sh
source scripts/env.sh
python3 scripts/verify-phase2.py
python3 tools/reference/gameplay/production.py --output artifacts/local/gameplay-production-native-final
python3 tools/reference/gameplay/production.py --profile browser --output artifacts/local/gameplay-browser-native-final
node tools/reference/gameplay/production.mjs --native-zone \
  --native artifacts/local/gameplay-production-native-final \
  --output-prefix artifacts/local/gameplay-production-new --keep-node
node tools/transport/serve.mjs
```

The production runner exports a fresh browser config and palette beside its
report. Use those explicit files with the browser gate:

```sh
node tools/transport/gameplay-browser-check.mjs \
  --config artifacts/local/gameplay-production-new.config.json \
  --palette artifacts/local/gameplay-production-new.palette.json
```

For interactive use, copy the exported config/palette to
`web/config.local.json` and `web/palette.local.json`, open the local frontend,
and click Start. The sampler serializes transactions. Original 35 tics/s define
simulation time; no realtime FPS target is claimed. Stop/blur releases input.
Keep shared unlocked-sender writers sequential.

## Scope and measurement limits

The accepted profile is one player, medium skill, retail E1M1 and full-screen
world view/psprites. Full outer gameflow/automatic level progression, complete
death restart, menus/HUD/automap, sound-device output, demo/save format,
multiplayer and arbitrary maps/modes remain explicit omissions. All active core
gameplay functions are mapped; this is not complete original DOOM acceptance.

Source adaptations preserve explicit pinned numeric/LP64 domains, stable logical
IDs and a source-driven native allocation mirror. Only known source-written
physical backing bytes can be sampled beyond a logical lump; unknown pointers,
padding, slack or payloads reject. No asset/frame exception, invented padding,
clamp or native runtime allocation tape is used.

Compiler stack pressure, fixture memory exhaustion, unknown-byte rejection,
receipt timeout and gas exhaustion are recorded separately. A concurrent
measurement lost a receipt without retaining its pending hash/nonce; exact
cause is unproven. The sequential replay passed. A later missing ignored clone
artifact stopped at preflight and was rebuilt separately. Neither is recorded
as a passed failed attempt.

[Usage exports](CODEX-USAGE.md) remain local aggregate telemetry, separate from
the engine. The Phase 3 engineering closure is an explicit acceptance marker,
not an inferred goal counter. Unflushed response usage and later publication
bookkeeping can remain outside that window; missing counts are never estimated.
