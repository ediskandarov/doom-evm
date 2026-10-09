# Porting map

Baseline: `original/DOOM/linuxdoom-1.10`, upstream `a77dfb96cb91780ca334d0d4cfd86957558007e0`. Phase 0 establishes interfaces and experiments only. **No original C function has been ported.**

| Upstream source | Solidity destination | Status and deliberate adaptation |
|---|---|---|
| `doomtype.h`, numeric declarations in `m_fixed.h` / `tables.h` | `src/doom/doomtype.sol` | Header scaffold: primitive int32/uint32 conventions, constants and explicit null sentinel. Arithmetic awaits C vectors. |
| `doomstat.h` | `src/doom/doomstat.sol` | Persistent storage context scaffold; only uint64 gametic, wider than original C counter. No game logic. |
| `r_defs.h` | `src/doom/r_defs.sol` | Minimal Vertex/Sector header subsets; explicit widths/index IDs; not complete map structures. Original copyright notice retained. |
| `r_state.h`, view globals from `r_main.c` | `src/doom/r_state.sol` | Minimal RenderState memory context; globals grouped, framebuffer bytes added. Clip/plane/sprite fields deferred to renderer gate. |
| `m_fixed.c` | `src/doom/m_fixed.sol` | Not started; file intentionally absent. |
| `tables.c` | `src/doom/tables.sol` | Not started; file intentionally absent. |
| `r_main.c`, `r_data.c`, `r_draw.c` | Corresponding `src/doom/r_*.sol` | Not started. |
| `r_bsp.c`, `r_segs.c`, `r_plane.c`, `r_things.c`, `r_sky.c` | Corresponding `src/doom/r_*.sol` | Not started. No replacement raycaster. |
| `p_*.c`, other gameplay modules | Corresponding `src/doom/p_*.sol` etc. | Not started; M2/M3. |
| No C counterpart | `src/evm/Doom.sol` | Abstract integration boundary only; no fake production renderer. |
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
| C fixed math | not started | — | — | Requires Phase 1 C oracle |
| WAD data in EVM | not started | — | — | Real per-lump layouts and storage benchmarks pending |
| BSP walls render | not started | — | — | Renderer dependency chain |
| M1 full static frame | not started | — | — | Renderer dependency chain |
| M2 movement | not started | — | — | M1 |
| M3 basic gameplay | not started | — | — | M2 |

No C/pixel equivalence, DOOM FPS, original-level rendering, or priority claim follows from these experiments. Source and resource license provenance remain separate. No WAD is bundled.
