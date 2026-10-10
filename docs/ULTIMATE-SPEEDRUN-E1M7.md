# Ultimate DOOM E1M7 full-rate recording

Completed mhrz's authentic UV Speed [e1m7-113.lmp](https://dsdarchive.com/files/demos/doom/56602/e1m7-113.zip), SHA-256
`182931b0afdcace7dffe66c74bdcd546e6e110eed95a725ce79dc7dd4ce5041e`.
Classic Ultimate DOOM 1.9 IWAD MD5 is `c4fe9fd920207691a9f493668e0a2083`;
full SHA-256/resources are bound in [result.json](../artifacts/ultimate-speedruns/E1M7/result.json).

All 2,573 whole native/EVM gameplay observations agree across 2,572 original
tics, ending in genuine GA_COMPLETED. Native gameplay agrees in O2, O0,
ASan/UBSan and the alternate fresh-allocation-fill diagnostic. Every gameplay
frame renders inside EVM; none is reused or supplied by native C.

All 2,572 indexed8 frames equal the normal O2 and O0 captures. The sanitized
native capture differs at three pixels in frame 2,384, where the renderer reads
an allocator link pointer. Those three EVM pixels use validated experimental
virtual-pointer provenance: byte `0x38` from virtual previous-block address
`0x000000100038a0b8`, producing pixel 60 at (193–195,169). All three survive in
the framebuffer. The remaining 164,607,997 pixels match all three native
profiles. Thus 2,571 whole frames are common-native exact; frame 2,384 contains
three deterministic virtual-derived pixels. This is finite domain evidence,
not universal native pixel equality. [Virtual samples](../artifacts/ultimate-speedruns/E1M7/virtual-samples.json)
record every use, source/header/target identity and destination.

Verified recording gas is 2,926,248,654,012: gameplay 597,674,311,641 and
captures 2,324,543,070,568, with deployment/startup separately bound. Measured
replay session is 2,698.299389542 seconds and capture RPC time is
2,196.601761294 seconds. UTC: 2026-10-10T20:31:21.101Z through
2026-10-10T21:16:42.491Z. Anvil uses localhost, Cancun, 1 GiB EVM memory,
10B transaction/block gas, unlimited request bodies, and two-block retention.
No MemoryOOG or gas cap occurs. The runner calls UltimateStartup/DoomGame.load
directly once; it does not use the previously duplicated menu initialization
path. Integrated menu/startup fixes are already present in the baseline.

MP4: `artifacts/local/ultimate-speedruns/E1M7/full-rate/speedrun-e1m7.mp4`;
2,572 frames at 35 FPS, 73.48571428571428 seconds, 1280×800 with 4:3 display
aspect. Independent receipt/world/source/provenance/palette/PNG/MP4 verification
passes, and the contact sheet was visually inspected. Indexed8 and PNG preserve
pixels; H.264 is lossy. Rendering observes a temporary memory copy, not
continuously persisted renderer history or production UI acceptance.

[Evidence manifest](../artifacts/ultimate-speedruns/E1M7/evidence-manifest.json)
binds ignored local proof payloads. Commercial resources/artwork/worlds/video
remain local. No unresolved failure, push or main merge.
