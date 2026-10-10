# Ultimate DOOM E1M4 full-rate recording

Completed authentic UV Speed demo by izzybell from
[the original DSDA archive](https://dsdarchive.com/files/demos/doom/113314/e1m4-0021.zip). Demo SHA-256:
`1f5427b2776aa7deb83716350eb6d252e4953895aa338c239bf62eeac5d67fdf`. Classic IWAD MD5
`c4fe9fd920207691a9f493668e0a2083`; full SHA-256/resource identity is bound in
[result.json](../artifacts/ultimate-speedruns/E1M4/result.json).

All768 native/EVM snapshots agree; all767 gameplay frames render inside EVM.
All767 indexed8 frames equal independent O2/O0/sanitized original-C captures.
No virtual-pointer sample is used in this finite tape. Gameplay also agrees
across the independent0xa5 allocation-fill diagnostic. A genuine normal exit
occurs at tic767. This is finite profile equality, not universal equivalence.

Verified total gas:672,360,227,071; gameplay:
132,711,462,124; captures:535,793,653,910. Exact UTC bounds,
RPC/session durations, compiler/source/ABI/resource identity and startup costs
are in the result. Local Anvil uses Cancun,1GiB memory,10B gas, unlimited RPC
request bodies and two-block history retention; accepted mined receipts are
preserved separately. Compiler/viaIR/optimizer, engine algorithms and provenance
guards are unchanged. Superseded chain dumps are cleaned after head verification.

MP4:`artifacts/local/ultimate-speedruns/E1M4/full-rate/speedrun-e1m4.mp4`;767 frames at35fps,21.914286 seconds.
Independent verification covers receipts, world bytes, source hashes, source
pixels, provenance, palette/PNG expansion and MP4 timing/rate/count/aspect/hash.
Indexed8/PNG preserve source pixels; H.264 is lossy. Rendering observes a memory
copy without persistent renderer history or production UI acceptance.

[Evidence manifest](../artifacts/ultimate-speedruns/E1M4/evidence-manifest.json)
binds local proofs. Commercial WAD/geometry/frame payloads and MP4 stay ignored
locally. No unresolved failure, main merge or push.
