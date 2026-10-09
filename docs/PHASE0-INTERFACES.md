# Phase 0 interface freeze v0

Owner: integrator. These are minimal compilable boundaries, not completed engine layouts. Extensions require an explicit integrator update and corresponding fixture/schema changes before dependent work begins.

- Solidity 0.8.37, optimizer 200, via-IR, Cancun. Shared code is in `src/doom` and `src/evm`.
- `fixed_t`: primitive `int32`, signed 16.16; `angle_t`: primitive `uint32`. Widen multiplication to signed 64 bits. No arithmetic function is ported in Phase 0. Wrapping and `FixedDiv2` double semantics require pinned C comparisons in Phase 1; `unchecked` is not proof of C equivalence.
- Signed right shift is arithmetic; division truncates toward zero. Null index is `uint32.max`, never 0. Raw WAD BSP children use `0x8000` for `NF_SUBSECTOR`; validate before widening into resource indexes.
- `RenderState memory`: view coordinates/angle, dimensions, `bytes framebuffer`. Internal memory references alias; storage copies are independent. Clip/plane/sprite buffers are added at the renderer interface gate, not invented now.
- `DoomState storage`: `uint64 gametic` only. Entity/sector/RNG state is added with source mapping at later gates. No implicit environmental game inputs.
- `Frame(uint64 indexed frameId,uint32 indexed inputSeq,uint16 width,uint16 height,bytes pixels)`. Exactly width*height indexed8 bytes, row-major, top-left origin. Pixel bytes are not indexed. Frame IDs start at 1 and advance once per successful frame; reverted calls change neither state nor logs.
- Phase 0 fixture publishes a deterministic synthetic 320x200 image, explicitly not a DOOM renderer. Driver sequence starts at 1, strictly increments, and is submitted after the preceding receipt.
- Palette distribution: separate local JSON asset containing 768 RGB bytes, variant and SHA-256, bound to a resource identity. Phase 0 uses a labeled synthetic palette without a WAD. Later PLAYPAL data must match WAD/bundle identities. Browser performs palette expansion only.
- `ResourceIdentity` and `LumpDescriptor`: versioned static bundle identity and explicit lump bounds. JSON schemas define little-endian blob serialization, SHA-256 and provenance. No view-dependent resource transforms permitted. Storage/code placement is deliberately unresolved pending Phase 1 benchmarks.
- Reference fixtures distinguish `synthetic` from `wad`; synthetic fixtures cannot claim a WAD hash or C equivalence. Real goldens must identify upstream SHA, WAD SHA, compiler/build semantics, camera, palette, detail, tic and resolution.
- `Doom` remains abstract until a real renderer exists. Experiments live in `src/support`; no mock is represented as a port.
