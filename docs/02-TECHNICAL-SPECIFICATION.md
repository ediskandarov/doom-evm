# DOOM on EVM — Technical Specification

> **Version:** 0.1, architecture baseline dated 2026-10-09. This is a **design specification**, not a claim that the described code has already been implemented or tested.
>
> Related documents: [decision history](01-IDEA-AND-DECISIONS.md) · [implementation and agents](03-IMPLEMENTATION-PLAN.md).

## 0. TL;DR for Codex

We are porting **the original DOOM (`id-Software/DOOM`, `linuxdoom-1.10`)** to Solidity/Yul, to run on **local Anvil**. The origin of every function must remain recognizable (`r_bsp.c` → `r_bsp.sol`, `R_RenderBSPNode` → `R_RenderBSPNode`). The contract maintains game state, executes game ticks, software-renders a framebuffer, and emits a `Frame` event. The browser reads logs and displays **already-rendered pixels**; it does not compute the scene. Relaxed EVM resource limits are allowed, but custom DOOM-specific opcodes or precompiles are not. M1 targets a frame from a Doom-compatible WAD level using a genuine renderer (BSP/segs/planes), not a raycaster clone. We verify the port against a pinned C reference.

## 1. Scope and boundaries

### In scope

- Single-player DOOM world simulation and software renderer executed in the EVM.
- A source-faithful port of the relevant modules, with matching file organization and function names.
- Local Anvil, Foundry tests, TypeScript resource tooling, and a minimal browser frontend.
- WAD loading/preprocessing without outsourcing any per-frame rendering algorithm to a non-EVM component.
- Indexed 8-bit framebuffer; EVM event logs as the primary transport.
- Native C reference harness, golden snapshots, and reproducible comparisons.

### Out of scope for M1

- Mainnet or L2 deployment, economic gas efficiency, and public-chain deployment security.
- Sound, multiplayer, network sync, demo playback, saves/loads, menus, and original network code.
- Production-grade UI, a React architecture, or achieving 35 FPS.
- Generating view-dependent game geometry outside the EVM as a substitute for the original renderer.

### What counts as genuine EVM execution

**Allowed outside the EVM:** reading WAD files; unpacking lumps; normalizing their serialization; composing static patch textures/flats into a resource bundle; generating reference fixtures; converting palette indexes to RGBA for browser Canvas display; sending input; and receiving events.

**Must happen inside the EVM:** determining frame-specific geometry visibility, BSP traversal, clipping, projection, texture-coordinate selection, lighting/palette-index selection, writing the framebuffer, executing the game tick, and updating the game world. Any WAD precomputation that encroaches on rendering (for example, computing a visible wall list **for a particular player viewpoint**) is prohibited.

## 2. Pinned upstream dependencies

1. `original/DOOM`: Git submodule or vendored snapshot of `https://github.com/id-Software/DOOM`; **pin an exact commit SHA** and record it in `UPSTREAM.md`.
2. `linuxdoom-1.10`: the primary source-mapping baseline. **Do not silently mix in** Chocolate Doom or Crispy Doom implementations.
3. Reference implementation: (a) small native builds of selected original C functions; (b) if needed, Chocolate Doom at a **specific commit**; (c) an identified reference WAD with SHA-256.
4. For a publicly reproducible asset set, use [Freedoom Phase 1](https://github.com/freedoom/freedoom). Its `E1M1` is **Freedoom's own map**, not the original id Software level.
5. Do not commit or redistribute the proprietary `DOOM.WAD` or package its commercial assets into test artifacts. Users may supply a locally held compatible WAD if they have the right to use it.

### License and attribution

The official DOOM source repository uses GPL-2.0 (see the [upstream repository](https://github.com/id-Software/DOOM)); some old C headers retain historical licensing language. Preserve upstream copyright notices and the full license text; license the port and derivative components compatibly, and check SPDX identifiers on new files. WAD asset licenses are independent of the engine license. Review the exact distribution strategy before release.

## 3. Proposed repository layout

```text
doom-evm/
├── original/
│   └── DOOM/                        # pinned upstream id-Software repo
├── src/
│   ├── doom/
│   │   ├── doomtype.sol             # C header adaptation: explicit types
│   │   ├── doomdef.sol
│   │   ├── doomstat.sol
│   │   ├── m_fixed.sol
│   │   ├── tables.sol
│   │   ├── r_defs.sol
│   │   ├── r_state.sol
│   │   ├── r_main.sol
│   │   ├── r_bsp.sol
│   │   ├── r_segs.sol
│   │   ├── r_plane.sol
│   │   ├── r_draw.sol
│   │   ├── r_things.sol
│   │   ├── r_data.sol
│   │   ├── r_sky.sol
│   │   ├── p_tick.sol               # added in later milestones
│   │   └── ...
│   ├── evm/
│   │   ├── Doom.sol                 # thin adapter: session, step, event
│   │   ├── ResourceStore.sol        # only if measurements justify it
│   │   └── FrameProtocol.sol        # optional protocol definition
│   └── support/
│       └── ...                      # genuinely EVM-specific adapters
├── test/
│   ├── unit/
│   │   ├── m_fixed.t.sol
│   │   ├── tables.t.sol
│   │   └── ...
│   ├── integration/
│   │   ├── FrameEvent.t.sol
│   │   └── RenderGolden.t.sol
│   └── fixtures/                    # small, redistributable fixtures only
├── tools/
│   ├── wad/                         # TS WAD reader + deterministic packer
│   └── reference/                   # C harness, reference capture, diffs
├── web/                              # input + log subscription + canvas
├── scripts/                          # setup, deployment, reproducibility
├── docs/                              # these three documents, PORTING.md
├── UPSTREAM.md
├── PORTING.md
├── foundry.toml
└── LICENSE
```

**Naming convention:** map `.c → .sol` and `.h → .sol` at the **module** level. If incompatible names/types require a dedicated `*.types.sol` module, include an explicit `@source` reference and record the mapping in `PORTING.md`. Solidity libraries such as `library R_BSP` and `library R_Segs` are fine, but **preserve the original function names**, e.g., `R_RenderBSPNode`. Do not introduce a proliferation of attractive-looking services that no longer map to the C source.

### Source-component mapping

| Upstream file | Our module | Initial scope |
|---|---|---|
| `m_fixed.c`, `m_fixed.h` | `m_fixed.sol` | Fixed-point helpers; bit-level equivalence |
| `tables.c`, `tables.h` | `tables.sol` | Trigonometric lookup constants and checksum tests |
| `doomtype.h`, `doomdef.h` | `doomtype.sol`, `doomdef.sol` | Numeric definitions and constants |
| `r_defs.h`, `r_state.h` | `r_defs.sol`, `r_state.sol` | Data layout; static vs. frame state |
| `r_main.c` | `r_main.sol` | Geometry setup and `R_RenderPlayerView` |
| `r_bsp.c` | `r_bsp.sol` | BSP traversal and clipping |
| `r_segs.c` | `r_segs.sol` | Walls, textures, gradients |
| `r_plane.c` | `r_plane.sol` | Visplanes: floors and ceilings |
| `r_draw.c` | `r_draw.sol` | Pixel/column/span writes |
| `r_things.c` | `r_things.sol` | Sprites; an explicitly documented omission is allowed during early M1 work |
| `r_data.c` | `r_data.sol` | WAD texture/flat/colormap access |
| `p_tick.c`, `p_mobj.c`, `p_map.c`, etc. | Corresponding `p_*.sol` | M2/M3 game simulation |

**Important:** C modules often call functions implemented in neighboring source files. A function belongs to the file in which it is **defined**, not the file containing a forward declaration. For example, do not move `R_StoreWallRange` into `r_bsp.sol` merely because that file declares it.

## 4. Contract model and state

### Data lifetimes

| Category | Where it lives | Examples | Mutability |
|---|---|---|---|
| Static resources | Contract runtime code / storage / resource contracts | BSP nodes, vertices, linedefs, palettes, TEXTURE/PNAMES, flats | Immutable during a game session |
| Persistent world state | `storage` | Player, sectors/doors, monsters, RNG seed, tic count | Modified by `stepAndRender` |
| Frame state | `memory` | `viewx/y/z`, angle, clip arrays, drawsegs, visplanes, framebuffer | Re-created for every frame |
| Frontend state | Browser | Pressed keys, WS cursor, canvas/palette | Does not determine frame geometry |

Conceptual type definitions (**not** guaranteed to compile as-is):

```solidity
struct DoomState {
    uint64 gametic;
    // Player, thinkers, mutable sector states, RNG... introduced incrementally
}

struct RenderState {
    int32 viewx;
    int32 viewy;
    int32 viewz;
    uint32 viewangle;
    bytes framebuffer;             // width * height palette indices
    // clip buffers, visplanes, drawsegs...
}
```

- Use `DoomState storage ds` for internal game-state library calls, and `RenderState memory rs` for rendering.
- `memory` structs and dynamic arrays can be passed to internal functions by reference, but **verify the precise semantics** of assignment, copying, and each data type involved.
- Represent C pointers to WAD objects as array indexes or typed IDs with explicit bounds checks. Represent `NULL` with a dedicated sentinel/flag; never conflate valid index `0` with null.
- Game logic must not implicitly depend on fragile environmental values such as `msg.sender`, `block.timestamp`, or the external world. Inputs and tics are explicit.
- Large `storage`→`memory` copies are a potential bottleneck; measure baseline profiles before scaling them up.

### Fixed-point arithmetic and numeric semantics

In C, `fixed_t` is signed 32-bit 16.16 fixed point, and `angle_t` is unsigned 32-bit. Use `int32`, `uint32`, and `int64` intermediates (sometimes `int256` when required), while **preserving the source semantics**: signed shifts, sign extension, division toward zero, special cases, rounding and truncation.

**Critical:** Solidity 0.8+ checks arithmetic overflow by default, while signed overflow in C is formally undefined behavior. Simply using `unchecked` is **not** a universal guarantee of equivalence to optimizations made by the original C compiler. First pin the reference compiler and the concrete semantics we will compare against. For DOOM edge cases, implement deterministic wrapping where that matches the measured reference behavior. Record all differences in `PORTING.md`. Validate `FixedDiv` and `FixedDiv2` separately, including the original use of `double`.

### Functional boundaries

Do not replace hundreds of C globals with hundreds of unrelated Solidity contract globals. Context structs (`ds`, `rs`) and modules with `internal` library functions are acceptable. Do not introduce a public contract for each function without evidence that it is necessary. Place EVM-specific helpers beside the original function they support, or document the relationship explicitly.

## 5. Frame protocol v0 — primary transport

### Conceptual ABI

```solidity
// Sketch; the exact ABI is frozen in implementation-plan task A1.
contract Doom {
    event Frame(
        uint64 indexed frameId,
        uint32 indexed inputSeq,
        uint16 width,
        uint16 height,
        bytes pixels                 // width * height bytes, row-major
    );

    function stepAndRender(uint32 buttons, uint32 inputSeq) external {
        // Check authorization/sequence for a single driver.
        // Advance one or more deterministic DOOM tics.
        // Render through genuine R_* libraries.
        // ++frameId; emit Frame(frameId, inputSeq, width, height, pixels);
    }
}
```

This is a **target API**, not an already-implemented contract. For M1, a fixed-camera `renderFrame()` may emit the same `Frame` event. An auxiliary `renderView()` returning `bytes` via `eth_call` is also allowed, but it must not replace the primary event architecture.

### Payload v0

- `pixels`: exactly `width * height` bytes, **row-major**, left-to-right and top-to-bottom; offset `y * width + x`.
- Palette indexes range from `0..255`; use `bytes`, not `uint8[]`, for a more compact ABI representation.
- The contract/configuration determines `width` and `height`; the client verifies them against the actual payload length.
- Colors come from the **same WAD** (`PLAYPAL` and the selected palette variant). Distribute the palette separately, via a local asset loader, palette event, or static read; **choose one method in A1**.
- Increment `frameId` by one for each **successfully emitted** frame. `inputSeq` correlates each frame with the submitted input.
- Initially there is only one active player/driver. Do not send a new input until the preceding transaction has a receipt, unless ordering is explicitly guaranteed.
- Do not emit one event per pixel, and do not mark `bytes pixels` as `indexed` (that would expose a hash rather than the payload).
- The event is present in the receipt **after the transaction is included in a block**; a revert means **no frame and no state change**.

### Browser flow

```mermaid
sequenceDiagram
    participant UI as Browser (driver)
    participant RPC as Anvil RPC/WS
    participant EVM as DOOM EVM contract
    UI->>RPC: eth_subscribe(logs, Frame topic)
    UI->>RPC: eth_sendTransaction(stepAndRender(buttons, seq))
    RPC->>EVM: Execute tx
    EVM->>EVM: P_* game tick; R_* renderer
    EVM-->>RPC: emit Frame(id, seq, width, height, pixels)
    RPC-->>UI: receipt + log notification after mining
    UI->>UI: decode bytes + palette -> ImageData
    UI->>UI: canvas.putImageData
```

Fallback and robustness:

- Establish the WebSocket subscription **before** sending the first transaction.
- The driver's receipt **contains the same logs** and can serve as a local fallback without WS. Observers use WS plus `eth_getLogs` backfill.
- Deduplicate by `(txHash, logIndex)`; honor `frameId` ordering rather than relying on wall-clock time.
- If multiple frames are missed, displaying the newest available is acceptable. Handle disconnection/reconnection; local reorganizations are unlikely, but the API permits `removed` notifications.
- Use either `viem` or `ethers` for a minimal UI; the client library is not an architectural commitment.

### Payload size and throughput

| Resolution | Pixel payload size |
|---|---:|
| 128 × 80 | 10,240 B |
| 160 × 100 | 16,000 B |
| 320 × 200 | 64,000 B |

EVM `LOG` data costs gas; historical events consume disk/memory; large JSON-RPC payloads and WS buffers can become bottlenecks. Start with 160×100 or 320×200 and profile the **entire** chain (EVM execution / block inclusion / WS delivery / Canvas); do not confuse rendering time with transport latency.

### Contract state machine and errors

```text
UNINITIALIZED -> RESOURCES_LOADED -> READY -> RUNNING
                                      ^           |
                                      +--- reset -+
```

- `initialize` / `loadResource...` perform controlled local-session setup, split across transactions where needed.
- `stepAndRender` is allowed in READY/RUNNING; invalid input sequences or session state cause a revert.
- Any execution error or out-of-gas exception reverts **both** world state and the `Frame` event.
- Exactly one frame per successful gameplay transaction is the invariant once READY; administrative transactions without frames are permitted.

## 6. WAD resources: preprocessor/runtime boundary

### Pipeline

```text
IWAD (e.g. Freedoom Phase 1)
  -> TypeScript WAD parser (lumps + SHA-256)
  -> normalized static package (geometry, textures, flats, palette, colormaps)
  -> local deployment/upload (possibly chunks/resource code contracts)
  -> renderer reads static data from EVM
```

At minimum, M1 uses THINGS (if needed for the spawn position), LINEDEFS, SIDEDEFS, VERTEXES, SEGS, SSECTORS, NODES, SECTORS, TEXTURE/PNAMES/patches, flats, `PLAYPAL`, `COLORMAP`, and additional lumps as required. Parse the selected IWAD correctly; do not assume the list is exhaustive.

**Static asset preparation may run outside the EVM**, equivalent to resource-loading work performed by the original engine (for instance, preassembling patch textures). For every transformation, record its `resource transform`, inputs, and outputs. **Never precompute frame-specific rendering or visibility.**

Evaluate two resource-placement strategies:

1. `storage` arrays/mappings: easy to address and update, but expensive to populate or copy.
2. Runtime code of auxiliary resource contracts, read via `EXTCODECOPY` or an SSTORE2-like mechanism: potentially better for immutable blobs. Account for the separate initcode-size limit. Storage strategy must not change renderer behavior.

Choose based on `upload + sample access + frame render` benchmarks. A separate agent owns resource-loading tooling. The invariant is that runtime render data is available **within EVM execution**, not replaced by a browser-supplied precomputed frame.

## 7. Rendering pipeline

```mermaid
flowchart TD
    W[Static WAD resources] --> R[R_InitData / maps / tables]
    S[Persistent game state] --> F[R_SetupFrame]
    R --> F
    F --> C[R_ClearClipSegs/DrawSegs/Planes/Sprites]
    C --> B[R_RenderBSPNode]
    B --> G[R_StoreWallRange + R_RenderSegLoop]
    G --> D[R_DrawColumn / framebuffer]
    B --> P[R_DrawPlanes / spans]
    P --> D
    B --> M[R_DrawMasked / sprite columns]
    M --> D
    D --> E[emit Frame(bytes pixels)]
```

These are **target modules**, not a promise of a single rendering pass or an exact graph of every internal C call. Verify the actual execution order for each function against the pinned `r_main.c`. Replace original `NetUpdate()` and other platform calls with no-ops or omit them **with an explicit reason**.

**M1 supports staged fidelity:** geometry and walls first; then visplanes; then sprites and HUD. Only describe an image as a *full DOOM frame* when every element visible in the selected reference scene is actually implemented. Never hide missing features.

## 8. Solidity / Foundry / Anvil

### Initial compiler configuration

```toml
# Template; pin exact working tool versions during bootstrap.
[profile.default]
src = "src"
test = "test"
optimizer = true
optimizer_runs = 200
via_ir = true
evm_version = "cancun"
# solc_version = "<exact tested version>"
```

**Why via-IR:** the compiler may spill temporary values from the EVM stack into memory. This reduces the risk of `Stack too deep`, but does not guarantee that massive functions, recursive calls, or Yul will compile. Pin the actual solc version after the toolchain spike.

### Anvil: illustrative local configuration

```bash
# Verify supported flags with your installed `anvil --help` before using them.
anvil \
  --hardfork cancun \
  --disable-code-size-limit \
  --disable-block-gas-limit \
  --gas-limit 1000000000 \
  --memory-limit 1073741824
```

Execution is **not literally unlimited**: `eth_sendTransaction` still has a per-transaction gas budget; EVM memory expansion is costly; Anvil and JSON-RPC have technical limits and timeouts. `--disable-block-gas-limit` does not guarantee an arbitrarily large gas budget per call. EIP-3860's initcode-size limit is a **separate** issue and is not necessarily disabled by removing the runtime bytecode size restriction. Bypassing deployment with `anvil_setCode` is acceptable for a documented local experiment, but first try normal deployment and record the reason if a workaround is needed.

### Stack and Yul policy

1. The EVM stack is limited to **1024 × 256-bit words**; legacy `DUP`/`SWAP` instructions can access only limited depth. `via_ir` helps manage local variables.
2. Convert C globals to `storage`/`memory` state. Keep ordinary C locals as Solidity locals initially.
3. On `Stack too deep`: identify the conflict, reduce live ranges, move temporary locals into a function-specific `memory` scratch struct, and only then split helpers **within the same source module**. Record each `@deviation`.
4. Inline Yul is allowed for correctness, framebuffer writes, and memory layout—not cosmetic rewrites. Apply `assembly ("memory-safe")` **only when the documented conditions are satisfied**. An unsafe assembly block can inhibit stack-to-memory optimization across the contract.
5. Test the depth of recursive BSP traversal against target maps. If needed, substitute an explicit traversal stack in `memory`, with tests for traversal order.
6. Measure final bytecode size after inlining internal libraries, independent of source-file size. External EVM modules are a possible fallback; they retain file/function mapping but add `CALL` overhead.

### Numeric and pixel equivalence tests

Pin the C reference build's compiler version, flags, architecture, and selected 32-bit integer semantics. For every reference framebuffer, record WAD checksum, viewpoint, resolution/detail level, palette/colormap/light configuration, and tic count. Compare progressively: trig/fixed-point → BSP visibility → wall columns → planes/sprites → complete `pixels`.

## 9. Testing and observability

### Test pyramid

| Level | Example | Acceptance rule |
|---|---|---|
| Unit | `FixedMul`, `FixedDiv`, signs, shifts, extremes | Compare against C reference vectors; document known divergences |
| Data | WAD lumps/endianness/indexes/checksum | Fully reproducible output; reject malformed WADs explicitly |
| Component | BSP child order, clipping, texture coordinates | Event traces/fixtures agree with C |
| Render golden | One frame / several camera positions | Pixel-wise diff or an exact explanation of tolerated differences |
| Integration | Transaction receipt has one `Frame`; WS delivers identical bytes | No 3D scene computation in JavaScript |
| E2E | Key press → updated state → new frame | Repeatable frame sequence on local Anvil |

### Artifacts required from each render test

```json
{
  "wad_sha256": "...",
  "upstream_commit": "...",
  "renderer_commit": "...",
  "solc_version": "...",
  "resolution": [320, 200],
  "camera": { "x": 0, "y": 0, "z": 0, "angle": 0 },
  "gametic": 0,
  "palette_variant": 0,
  "framebuffer_sha256": "...",
  "pixel_diff_count": 0,
  "gas_used": 0,
  "exec_ms": 0,
  "receipt_ms": 0,
  "event_delivery_ms": 0
}
```

Zeros in this template are **placeholders**, not measured results. Only commit reference images if the resource license permits redistribution. On divergence, retain error maps and lists of mismatched pixel coordinates. Never claim bit-perfect equivalence without a comparison.

### Recommended measurements

- Bytecode size, deployment method/limits, WAD bundle size.
- Gas used for initialization/upload, ticks, rendering, and event emission.
- Render execution time and total input-to-canvas latency.
- Frame log payload size and the rate at which Anvil accumulates event data.
- Peak host memory and the number of frames/minutes before a reset becomes necessary.

## 10. Public API and test seams — contracts between agents

*All identifiers and structures below are proposals. Freeze them in A1 before agents begin writing code that must integrate across modules.*

```solidity
// src/doom/r_state.sol
struct RenderState { /* renderer state + bytes framebuffer */ }

// src/evm/Doom.sol
interface IDoom {
    event Frame(
        uint64 indexed frameId,
        uint32 indexed inputSeq,
        uint16 width,
        uint16 height,
        bytes pixels
    );

    function stepAndRender(uint32 buttons, uint32 inputSeq) external;
    function renderFrame() external;      // M1 diagnostics, optional later
}
```

**Circular imports:** type/header modules must stay minimal and independent of implementations such as `R_Main`, `R_BSP`, etc. Dependency arrows point from functions toward shared types. If needed, `R_Main` is the top-level integration point rather than a member of a circular import chain.

**Input semantics:** in M2, freeze the bitmask-to-original-`ticcmd_t` mapping in `INPUT_PROTOCOL.md`. Distinguish held keys from new presses (fire/use), define turning speed, tic count and repeat behavior. The simulation must not depend on `block.timestamp`.

## 11. Acceptance criteria / Definition of Done

### For every `*.sol` module

- [ ] Identify the exact upstream `.c/.h` and its commit SHA; list the mapped functions.
- [ ] Preserve function names and recognizable control flow, or explain the differences.
- [ ] Compile under the pinned solc version with `via_ir = true`.
- [ ] Test critical arithmetic functions against C vectors, including edge cases.
- [ ] Validate every Yul memory assumption; never add `memory-safe` casually.
- [ ] Do not introduce browser-based 3D rendering or precomputed visibility data.
- [ ] Update `PORTING.md` (status and known deviations).

### For M1 end-to-end

- [ ] Local `forge build`, `forge test`, loading a permitted WAD, deployment, and frame-producing transaction all work.
- [ ] Receipt or WS yields the **complete pixel array** computed in the EVM.
- [ ] Browser displays the array with only palette decoding, without geometry computation.
- [ ] Actual Doom BSP and segments are used; scope of planes/sprites is disclosed accurately.
- [ ] Attach comparison against the equivalent C reference scene and localize discrepancies.
- [ ] Record exact Anvil parameters and one-frame metrics in reproducible commands.

## 12. Authoritative references

- [Original `r_main.c`](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_main.c)
- [Original `r_bsp.c`](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_bsp.c)
- [Original `r_segs.c`](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_segs.c)
- [Original `m_fixed.c`](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/m_fixed.c)
- [Solidity via-IR optimizer](https://docs.soliditylang.org/en/latest/internals/optimizer.html)
- [Solidity `memory-safe` assembly](https://docs.soliditylang.org/en/latest/assembly.html#memory-safety)
- [Foundry `via_ir` and `evm_version`](https://getfoundry.sh/reference/config/solidity-compiler)
- [Anvil command-line flags](https://github.com/hbs/foundry-book/blob/master/src/reference/cli/anvil.md) — verify against the installed version
- [Ethereum JSON-RPC logs / receipts](https://ethereum.org/developers/docs/apis/json-rpc/)
- [Freedoom resources and licensing](https://github.com/freedoom/freedoom)
