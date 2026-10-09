# Porting map

Baseline: `original/DOOM/linuxdoom-1.10`, upstream `a77dfb96cb91780ca334d0d4cfd86957558007e0`. Phase 1 ports original fixed math and table operations, adds the original C oracle and packages permitted WAD resources. Renderer and gameplay functions remain unimplemented.

| Upstream source | Solidity destination | Status and deliberate adaptation |
|---|---|---|
| `doomtype.h`, numeric declarations in `m_fixed.h` / `tables.h` | `src/doom/doomtype.sol` | Header scaffold: primitive int32/uint32 conventions, constants and explicit null sentinel. Arithmetic is implemented in m_fixed.sol and tested against original C vectors. |
| `doomstat.h` | `src/doom/doomstat.sol` | Persistent storage context scaffold; only uint64 gametic, wider than original C counter. No game logic. |
| `r_defs.h` | `src/doom/r_defs.sol` | Minimal Vertex/Sector header subsets; explicit widths/index IDs; not complete map structures. Original copyright notice retained. |
| `r_state.h`, view globals from `r_main.c` | `src/doom/r_state.sol` | Minimal RenderState memory context; globals grouped, framebuffer bytes added. Clip/plane/sprite fields deferred to renderer gate. |
| `m_fixed.c` | `src/doom/m_fixed.sol` | FixedMul, FixedDiv, FixedDiv2 ported. Signed narrowing/shift match pinned Clang. Exact rational implementation proven equivalent to defined binary64 results. abs(INT_MIN) widened magnitude and direct 0/0 error are documented extensions. |
| `tables.c`, `tables.h`; cosine alias in `r_main.c` | `src/doom/tables.sol` | Exact original constants, finesine/finecosine/finetangent/tantoangle lookup API and SlopeDiv. Generated chunks, explicit bounds, aligned memory-safe read; all indices/native hashes verified. |
| `r_main.c`, `r_data.c`, `r_draw.c` | Corresponding `src/doom/r_*.sol` | Not started. |
| `r_bsp.c`, `r_segs.c`, `r_plane.c`, `r_things.c`, `r_sky.c` | Corresponding `src/doom/r_*.sol` | Not started. No replacement raycaster. |
| `p_*.c`, other gameplay modules | Corresponding `src/doom/p_*.sol` etc. | Not started; M2/M3. |
| No C counterpart | `src/evm/Doom.sol` | Abstract integration boundary only; no fake production renderer. |
| No C counterpart | `src/support/ResourcePlacement.sol` | Static WAD upload/read comparison: storage bytes versus immutable STOP-prefixed code. Ordinary CREATE, bounded memory-safe EXTCODECOPY. Experiment, not r_data adapter. |
| No C counterpart | `src/evm/FrameProtocol.sol`, `ResourceTypes.sol` | EVM transport/resource identity adapters. |
| Shape reference `r_segs.c:R_StoreWallRange` | `src/support/StackPressure.sol` | Synthetic experiment only. Named shape function/stub dependencies, intentionally not `r_segs.sol`; see stack report for every class of deviation. |
| No C counterpart | `src/support/FrameFixture.sol` | Synthetic EVM pixel generator; not an engine port. |

Core implementation modules will keep original function names and their defining C file. Each later module must identify the pinned source, mapped functions, numeric/algorithmic differences, assembly proofs (if any), C comparison command and evidence. Shared header extensions and ABI changes go through the integrator. Source fidelity takes priority over a single runtime contract.

## Progress

| Milestone | Status | Evidence | Divergences | Blockers |
|---|---|---|---|---|
| Phase 0 scaffold | passed | Build + context tests; frozen Solidity and JSON boundaries | Minimal headers, not full engine layouts | None |
| Event smoke | passed | `tools/transport/evidence/`, FrameEvent tests, browser readback | Synthetic palette/frame; no WAD | None |
| Stack-pressure spike | passed | `artifacts/phase0/stack-*` | Stubbed geometry/textures, toy arithmetic | None for spike; real renderer untested |
| C fixed math | passed | Original C fixtures, Foundry comparisons, rational proof in `tools/tables/NUMERICS.md` | Undefined C domains handled explicitly; no equivalence claim for extensions | None |
| WAD data in EVM (foundation sample) | passed | Real Freedoom package, byte-checked CREATE upload/read experiments | Sample slices only; complete engine resource adapter remains Phase 2 | None for Phase 1 |
| BSP walls render | not started | — | — | Renderer dependency chain |
| M1 full static frame | not started | — | — | Renderer dependency chain |
| M2 movement | not started | — | — | M1 |
| M3 basic gameplay | not started | — | — | M2 |

Defined numeric results and full table contents are compared to original C. No pixel equivalence, DOOM FPS, original-level rendering, or priority claim follows. Source and resource license provenance remain separate. Small permitted Freedoom snapshots are bundled with their BSD license; the full WAD remains a checksum-verified local download.

## Phase 1 non-Solidity mapping

- `tools/reference/reference.py` compiles original `tables.c` and mechanically extracts FixedMul/FixedDiv/FixedDiv2 and R_PointOnSide/R_PointToAngle/R_PointToAngle2/R_PointInSubsector. Source spans, hashes, compiler semantics and host shims are retained in fixtures; none of those geometry functions has been ported to Solidity yet.
- `tools/wad/wad.ts` decodes the on-disk structures from doomdata.h and validates p_setup/r_data resource relationships. It preserves lump bytes; pointer conversion and runtime texture/geometry adapters await Phase 2. All directories, signed indices, BSP flags, patch posts and variable resource offsets have explicit bounds. Lookup reproduces W_AddFile strncpy padding plus W_CheckNumForName last-match behavior.
- Browser changes only validate resource/palette identity and expand RGB colors for existing mock Frame pixels. The frame ABI and abstract Doom adapter remain unchanged.

See [Phase 1 report](docs/PHASE1-REPORT.md) for complete evidence, scope and remaining renderer work.
