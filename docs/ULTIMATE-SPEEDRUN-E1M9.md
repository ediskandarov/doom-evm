# Ultimate DOOM E1M9 full-rate recording

Completed ShadowCaco33's authentic UV Speed [e1m9-0045.lmp](https://dsdarchive.com/files/demos/doom/108203/e1m9-0045.zip).
Demo SHA-256: `ae640d1a17919e24983afd9d191d75502f0f745b89a52fff808ee41a2761bfb1`.
Classic Ultimate DOOM 1.9 IWAD MD5: `c4fe9fd920207691a9f493668e0a2083`.
[Result](../artifacts/ultimate-speedruns/E1M9/result.json) binds full IWAD,
resource, compiler, source and ABI identity.

Every original gameplay tic replays inside EVM: 1,598 tics and 1,599 whole
native/EVM snapshots agree, with a genuine normal exit at tic 1,598. Native
O2/O0/ASan-UBSan and alternate fresh-allocation-fill gameplay profiles agree.
Every gameplay frame renders in EVM and has an authenticated mined receipt.
A separately preserved complete gameplay-only run also passes; it claims zero
rendered frames and is independent of video acceptance.

All 1,598 frames equal normal O2/O0 native bytes; 1,597 whole frames also equal
the sanitized native profile. Frame 897 uses two validated experimental
virtual previous-link pointer samples: byte `0x2d` from address
`0x00000010002de868`, producing pixel 2 at (187–188,189). Both survive in the
framebuffer; the sanitized host-placement bytes differ there. The remaining
102,271,998 pixels match the common native domain. These two pixels remain
virtual-derived even though normal O2/O0 happen to agree. [Every virtual sample](../artifacts/ultimate-speedruns/E1M9/virtual-samples.json)
is preserved. No universal pixel-perfect equivalence is claimed.

Verified recording gas: 1,421,620,264,871, including gameplay 279,605,994,052
and capture 1,138,232,267,404. Measured replay session: 1,358.969906583 seconds;
capture RPC time: 1,114.062375307001 seconds. UTC bounds:
2026-10-10T21:29:03.414Z through 2026-10-10T21:52:04.761Z. Local Anvil uses
Cancun, 1 GiB EVM memory, 10B transaction/block gas, unlimited RPC request bodies
and two-block history retention. No memory/gas infrastructure increase is needed.

MP4: `artifacts/local/ultimate-speedruns/E1M9/full-rate/speedrun-e1m9.mp4`;
1,598 frames at 35 FPS, 45.65714285714286 seconds, 1280×800, 4:3 display aspect.
The initial MP4's 1000-unit movie edit list rounded its duration to 45.657000
seconds while its 35000-unit media track contained all 1,598 frames. That strict
media gate stayed failed. The wrapper now pins both clocks to 35000, preserving
exact tic timing; the original failed file, container diagnosis and logs remain
local. No EVM tic, frame or duration assertion changes. Independent complete
receipt/world/source/provenance/palette/PNG/MP4 and supported-pixel gates pass,
and the final contact sheet was visually inspected. H.264 is lossy; indexed8
and PNG preserve source pixels.

[Evidence manifest](../artifacts/ultimate-speedruns/E1M9/evidence-manifest.json)
binds local proofs. Rendering observes a temporary memory copy, not persistent
renderer history or production browser/UI acceptance. Commercial resources,
geometry, artwork and videos remain local. No unresolved failure, push or main
merge. The initial zero-tic localhost sandbox transport failure is separately
preserved under `attempt-rpc-sandbox-denied`; its retry used an authorized owned
localhost runtime.
