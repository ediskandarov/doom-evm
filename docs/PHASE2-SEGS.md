# Phase 2B wall rendering

`src/doom/r_segs.sol` ports original `R_StoreWallRange` and `R_RenderSegLoop` from `linuxdoom-1.10/r_segs.c` at `a77dfb96cb91780ca334d0d4cfd86957558007e0`.

The integrated tests execute actual Solidity BSP traversal and its genuine wall callback, resource reads and drawing primitives. No host visibility, projected geometry or native pixels are supplied as renderer inputs. All eight E1M1 ANG45 wall views match the corresponding original C `mode=walls` cases byte for byte over all 64,000 pixels. Every drawseg scalar and active clip/masked-column array, every final floor/ceiling clip entry, and every visplane field/top/bottom byte also match. Tests bind case name, render pass, manifest/reference pixel hashes, camera, dimensions, lighting, map and pinned resource/source identity.

Important source details retained:

- Signed absolute-value conversion for the wrapped angle difference; original `abs(INT_MIN)` inputs explicitly reject.
- Unchecked signed int32 stepping follows the pinned native `-fwrapv` profile; int16 clip/opening/masked-column stores and uint8 visplane stores narrow explicitly.
- Single-column ranges leave both original scalestep fields unchanged. Wall scratch persists between fragments.
- Texture selection uses translation indexes; pegging heights use the original sidedef texture indexes.
- Masked column scratch aliases the current drawseg before count increment. Shared screen-height/minus-one arrays preserve constant clip behavior; independent full-width snapshots replace adjusted interior C pointers.
- Original drawseg exhaustion returns at 256 entries; opening consumption counts original shorts and rejects beyond 320×64.
- Frame-memory linedef `ML_MAPPED` mutation, sky joins, silhouettes, fixed lighting and horizontal/vertical light adjustments remain original.

The production port uses no assembly. Test-only directory loads read allocated fixture words, and allocation probes only read the free-memory pointer. Unit tests etch pinned resource chunks solely for isolated execution; ordinary CREATE/resource-upload and actual-MSIZE measurements are a separate follow-up gate.

```sh
.toolchain/bin/forge test --match-contract RSegsTest -vv
```

Eight tests currently pass. Initial complete test gas, including resource/map initialization and all comparisons, ranges approximately 644–875 million under the existing 1-billion gas limit. These numbers are not isolated rendering costs or actual touched-memory measurements. Synthetic branch fixtures and separate ordinary-EVM cost/actual-memory evidence are being completed before this module's final report. This wall gate does not claim full planes/sprites rendering or Phase 2 completion.
