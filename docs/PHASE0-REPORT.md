# Phase 0 — assembling the chainsaw

Status: **passed**, 2026-10-09. All 12 integration gates passed, including 19 Foundry tests, 3 Node tests, schema mutation checks, real Anvil transactions and full Canvas readback. Phase 1 has not started.

Retained evidence: [verification summary](../artifacts/phase0/verification/summary.json), [Foundry test output](../artifacts/phase0/verification/foundry-tests.log), [browser result](../artifacts/phase0/verification/browser.json), [screenshot](../artifacts/phase0/verification/browser.png), [runtime limits](../artifacts/phase0/runtime-limits.json). All executable source hashes were rechecked before finalizing this report. No Phase 0 blockers remain.

The scope is a reproducible workbench and two measured risk experiments. It does not include original C math ports, WAD parsing, actual scene rendering, gameplay, or an M1 claim.

| Phase 0 requirement | Concrete deliverable and executable proof |
|---|---|
| F0-01 repository/upstream | `original/DOOM` Git submodule at `a77dfb96cb91780ca334d0d4cfd86957558007e0`; `UPSTREAM.md`, root GPL license; `scripts/check-toolchain.py` verifies SHA |
| F0-02 pinned Foundry/Anvil/Solidity | `toolchain.lock.json`, checksum installer, exact pragma, `foundry.toml`; version check, forced build and Foundry tests |
| Working relaxed local Anvil | `scripts/start-anvil.sh`, `--check`, real deployment/gas/memory probes with control nodes; `TOOLCHAIN.md` records measured CLI correction |
| F0-03 shared interfaces | Importable DoomType, RenderState, DoomState, Vertex/Sector subsets, ResourceIdentity/LumpDescriptor, Frame ABI, abstract Doom adapter; frozen docs and versioned schemas |
| Executable technical assumptions | 7 context tests cover aliasing/copy semantics, widths, shifts, division, sentinel and angle wrapping; schema validator checks four fixtures and 37 malformed cases |
| F0-04 64 KB event | FrameFixture produces all bytes in EVM; Foundry and mined receipts prove single frame and rollback; Node proves WS=receipt, ordering, deduplication and fallback; Chrome readback checks every RGBA byte |
| F0-05 stack pressure | `R_StoreWallRange`-shaped support spike, direct solc pipeline comparison, 9 branch/recurrence tests; via-IR succeeds while legacy reproduces stack-too-deep |
| F0-06 traceability/reporting | `PORTING.md`, frozen fixture/provenance format, experiment reports, retained run artifacts and full verifier |
| Parallel ownership/review | Three isolated worktrees/branches: stack, schemas/context, transport. Integrator owned shared core/toolchain; reviewed and cherry-picked bounded commits. Cross-review found and fixed browser failure cleanup. |
| Stay within Phase 0 | Core implementation files like `m_fixed.sol`, `r_bsp.sol`, `r_segs.sol` intentionally absent. Support experiments are labeled synthetic; no C oracle or WAD equivalence claims. |

## Reproduce all gates

After the README setup:

```sh
python3 scripts/verify-phase0.py
```

This includes a fresh forced build; deterministic Foundry fuzz seed `0x44`; schema/transport tests; both compiler pipelines; an actual launcher smoke test; control and relaxed Anvil probes; real frame transactions; and headless Chrome. A missing-browser regression verifies cleanup rather than leaving a test node/profile behind. Fresh outputs live in ignored `artifacts/local/`; the final retained run goes in `artifacts/phase0/verification/`. Summary source SHA-256 hashes tie executable evidence to reviewed code even before its final commit. Do not treat stale screenshots or a previous green report as proof after code changes.

## Decisions justified by experiments

- Keep via-IR + optimizer 200 + Cancun. The representative stack-heavy source fails in the legacy pipeline and compiles via IR without assembly or local scratch refactoring. Its runtime is 4,170 bytes; this does not prove a full renderer fits or deep recursion is safe.
- Keep one uncompressed 320×200 indexed8 Frame event. The complete 64,000 bytes survived WS, receipt fallback and Canvas decoding. The first recorded frame costs 11,622,237 gas, subsequent recorded frames 11,605,137; this includes a toy byte loop and cannot estimate Doom rendering costs.
- Keep ordinary deployment. Both 25,000- and 50,000-byte synthetic runtimes deployed with relaxed Anvil limits, including 50,014-byte initcode; control configurations fail. No `anvil_setCode` workaround was needed.
- Correct the illustrative Anvil command for the pinned version: disabling block limits conflicts with the `--gas-limit` flag. Use post-start RPC to set 1e9, then verify a newly mined header. Retain explicit per-transaction budgets; relaxed admission is not evidence of successful mining above that budget.
- Keep static resource placement undecided. Only bundle identity/packing/provenance boundaries are frozen; real WAD parsing, detailed per-lump records, storage versus code access, and upload/read benchmarks belong to Phase 1. No precomputed visibility or external scene rendering was introduced.

Latency and RSS/heap sampling are recorded in the transport report. Client timings include RPC, execution and mining; isolated engine execution time is not measured because there is no engine yet. Sampled memory is not a proven maximum or long-session capacity estimate.

## Next tasks, prepared but not started

The Phase 1 workstreams from the implementation plan remain applicable. With four available concurrent slots, the integrator can schedule at most three agents at a time.

| Workstream | Owned files | Input / acceptance |
|---|---|---|
| A — Numeric | `src/doom/m_fixed.sol`, `test/unit/m_fixed.t.sol` | Frozen numeric widths; genuine original-C vectors, including FixedDiv2 behavior and documented compiler semantics |
| B — Tables | `src/doom/tables.sol`, `test/unit/tables.t.sol` | Integrator must freeze lookup interface first; original table checksums and rounding/index vectors |
| C — Assets | `tools/wad/**`, `test/fixtures/wad/**` | Frozen bundle identity; freeze per-lump record layouts before implementation; Freedoom SHA/license, malformed input tests, upload/read measurements |
| D — Transport refinement | `web/**`, `tools/transport/**`, fixture tests | Existing synthetic v0 pipeline; integrate actual resource palette and later adapter only at explicit gates; no `Doom.sol` ownership |
| E — C reference | `tools/reference/**`, `test/fixtures/reference/**` | Pinned original SHA; freeze native compiler flags/semantics and vector formats; reproducible numeric/BSP vectors, then real scene goldens |

Table/numeric-vector schemas are deliberately not a claim of completed Phase 1 interfaces. Finish their narrow gate before dependent agents start. All changes to shared engine structs and the adapter remain integrator-owned. Core renderer or gameplay work is outside this Phase 0 completion.
