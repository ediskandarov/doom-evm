# Phase 1 — foundation checkpoint 👹

**Status: complete and verified, 2026-10-09. Phase 2 has not started.**

All **13 Phase 1 gates** passed, including all **12 Phase 0 gates**, **33 Foundry tests**, **51 WAD tests**, **12 reference infrastructure tests**, palette/transport tests and three malformed resource-identity regressions. Every recorded executable/fixture source hash was rechecked against the final worktree. [Final gate summary](../artifacts/phase1/verification/summary.json) · [nested Phase 0 evidence](../artifacts/phase1/verification/phase0/summary.json).

## Scope and evidence

| Requirement | Implementation and proving gate |
|---|---|
| Shared contracts before parallel work | `82f0707` freezes numeric/table APIs, vector schemas, original little-endian WAD layouts and ownership; three separate worktrees follow that freeze. `PHASE1-INTERFACES.md` records the approved undefined-C extension. |
| F1-A — original fixed math | `m_fixed.sol` preserves FixedMul/FixedDiv/FixedDiv2. Original C runs produce 3,276 rows: 3,164 successful values, 76 I_Error outcomes and 36 explicitly undefined cases. Foundry checks every defined result/error; separate tests cover the deterministic extensions. |
| F1-B — tables | All 16,385 original C words compiled and compared byte-for-byte with generated source; all 24,577 Solidity lookups including cosine alias hashed and compared. Both native exporters agree. Original SlopeDiv preserves unsigned 32-bit wrapping. |
| F1-C — real resource pipeline | Freedoom 0.13.0 archive checksum pin, complete raw-lump preservation, deterministic repeated packing, selected E1M1 records/resources validated, malformed-input regressions, source snapshots, license and real palette. |
| F1-D — mock Frame to Canvas | Original synthetic path retained; real PLAYPAL variant0 added with strict resource identity and SHA validation. Full 64,000 event pixels and 256,000 Canvas RGBA bytes compared; WS, receipt fallback, backfill and ordering remain covered. |
| F1-E — original C oracle | Mechanically extracted original functions with exact source hashes/line spans, pinned native compiler and shims, O0/O2/UBSan comparisons; 581 synthetic geometry and 772 real E1M1 BSP/subsector vectors; real camera configuration and validated pixel-diff/record tooling. |
| Preserve Phase 0 | Unchanged `scripts/verify-phase0.py` included as a mandatory gate, running every original gate against the integrated sources. |
| Resource placement recommendation | Ordinary CREATE uploads actual WAD slices into storage and STOP-prefixed code; every sample read checked byte-for-byte and measured through transactions. No renderer adapter or frame-access estimate. |

Reproduce everything from the README prerequisites:

```sh
python3 scripts/verify-phase1.py
```

The command downloads/checks the pinned permitted WAD, regenerates the package, rebuilds/checks the native oracle and tables, runs schemas and tests, executes the entire Phase 0 suite, and checks actual Anvil resource transactions and Chrome Canvas pixels. Fresh evidence is under `artifacts/local/phase1-verification/`. The retained final snapshot is [artifacts/phase1](../artifacts/phase1/); log paths are relocated and trailing whitespace trimmed, explicitly noted in each summary. Full WAD/archive/package files stay in ignored `artifacts/local/`; compact selected-lump snapshots and original license/credits are committed.

## Fidelity decisions

`FixedDiv2` in the C oracle retains the active original double expression. The Solidity integer implementation has a domain proof: binary64 rounding cannot cross an integer or int32 range boundary for int32 inputs followed by exact power-of-two scaling. It compares the exact rational range **before** truncation, preserving the asymmetric inclusive negative/exclusive positive bounds. See [proof and module notes](../tools/tables/NUMERICS.md).

`abs(INT_MIN)` and NaN-to-int conversions are undefined in C. They remain excluded from equality claims. The port uses widened mathematical magnitudes for the former and a custom error for direct zero division, including 0/0. Original native observations and sanitizer diagnostics are retained separately. Original defined FixedDiv(0,0) still saturates to MAXINT. Signed right shift and narrowing follow the measured pinned compiler profile.

The oracle compiles original `tables.c` and extracts exact bodies from `m_fixed.c` and `r_main.c`. Its minimal host structs, I_Error interception and BSP trace adapter are explicit hashed shims. Map input conversion multiplies signed coordinates by 65536 instead of invoking a negative left shift. No geometry algorithm has been reimplemented in the oracle. No Solidity geometry/BSP renderer is part of Phase 1.

Table memory reads use aligned 32-byte loads within allocated chunks; the final short chunk has Solidity's allocated padding. Resource code reads write only into newly allocated output bytes. Each memory-safe assembly block states its bounds. There is no new custom precompile, EVM fork, or `anvil_setCode` dependency.

## Resource identity and placement

Pinned resource: [Freedoom 0.13.0](https://github.com/freedoom/freedoom/releases/tag/v0.13.0), `freedoom1.wad`, SHA-256 `7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d`. Archive and official checksum URL are in `tools/wad/freedoom.lock.json`. Its BSD-3-Clause resource license is separate from the engine's GPL-2.0.

Bundle identity: `d379076f21645cf7cc5acb056663d0faacc4065489a0ca99738479323c9f7a47`. PLAYPAL variant0 SHA-256: `fd895921b5d0a394612bb29852ed003d44d69f76dec31c0dc6b5d5fc7d63f7bb`.

The selected map contains 1,175 lines, 1,196 vertices, 2,057 segs, 682 subsectors, 681 nodes and 182 sectors. Resource validation covers 963 texture definitions, 1,045 referenced patches, 240 flats, 14 palettes and 34 colormaps. The packer only reorders raw lump payloads into contiguous directory order; it computes no visibility, lighting or frame-specific information. Runtime record decoding remains a Phase 2 resource-adapter task.

Measured gas with actual WAD slices ([raw transactions and read hashes](../artifacts/phase1/resource-placement.json)):

| Slice | Bytes | Storage upload | Code upload incl. reader | Storage full sample | Code full sample |
|---|---:|---:|---:|---:|---:|
| PLAYPAL palette0 | 768 | 795,575 | 423,279 | 415,090 | 26,527 |
| COLORMAP prefix | 4,096 | 3,158,133 | 1,147,551 | 2,103,347 | 29,464 |
| E1M1 NODES prefix | 16,384 | 11,852,481 | 3,797,970 | 8,338,373 | 41,770 |

Sample transactions include SHA-256 and an event; storage reads use a straightforward byte loop. Code measurements include deploying the reader and payload contracts. Every call result and transaction digest equals original package bytes. These compare the implemented strategies, not every possible storage optimization. Timings include client/RPC/mining overhead.

Decision: use immutable code blobs as the starting strategy for the future static resource adapter, with measured 16 KiB chunks as the initial size. Mutable game state stays in storage. This is supported for upload and sampled access; the actual renderer access pattern, larger uploads and end-to-end frame costs must still be measured once that renderer exists. No frame-performance claim follows from these numbers.

## Limits and next gate

The native oracle intentionally requires Apple clang 17.0.0 `clang-1700.0.13.5`, target `arm64-apple-darwin24.6.0`, and recorded flags. Other compiler/platform profiles require explicit review. Linux binaries are pinned for Foundry but a cross-platform C oracle is not yet verified. The WAD packer deliberately rejects extended map formats and only packages the checksum-pinned permitted IWAD; raw parser tests include malformed classic input.

The browser still displays a **mock-generated EVM frame**, now optionally using real WAD colors. [Canvas/receipt verification](../artifacts/phase1/wad-browser.json) and [screenshot](../artifacts/phase1/wad-browser.png) retain the actual result. No real DOOM frame, pixel-perfect renderer, gameplay or M1 completion is claimed. Pixel-diff infrastructure exists, but no original-renderer framebuffer golden exists yet.

Before Phase 2 implementation, extend the shared geometry/render-state and resource-access contracts around these tested foundations. Then sequence r_main geometry, r_data access and r_draw primitives as prescribed by the existing plan. Measure pure table-lookup memory growth and immutable resource access in those actual workloads. The real E1M1 camera/BSP fixtures are ready to serve as their native reference; full frame goldens arrive with the real renderer.

## Completion audit

Every F1 workstream in the implementation plan has an implementation, reproducible command, source-fidelity notes and passing gate above. The original toolchain/compiler settings, abstract Doom adapter, shared render context and Phase 0 verifier are unchanged. Code inspection confirms no Phase 2 Solidity module was introduced. Review regressions cover W_AddFile name padding, the 15-bit BSP root boundary, all eight magic-byte bits, untrusted manifest identities, and camera/map/upstream agreement in reference comparisons. All defined native numeric/error rows are compared; the 36 undefined cases remain disclosed.
