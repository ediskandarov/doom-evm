# Ultimate DOOM E1M6: complete gameplay, blocked rendering

Authentic UV Speed by ShadowCaco33: [e1m6-0136.lmp](https://dsdarchive.com/files/demos/doom/108200/e1m6-0136.zip).
Demo SHA-256: `fa51135c2bee9b4c82c1b0390c6e29755b347237c981b911cef044e4b01e1ea6`. Exact classic Ultimate DOOM 1.9 IWAD MD5
`c4fe9fd920207691a9f493668e0a2083`; full SHA-256, source/compiler/ABI/resource
identity and runtime settings are bound in [result.json](../artifacts/ultimate-speedruns/E1M6/result.json).

Native C reaches a genuine exit at tic 3385. O2, O0 and
ASan/UBSan normal initial-zero-zone whole gameplay bytes agree. Alternate fresh
allocation-fill exactness: `True`.

A separate gameplay-only EVM run verifies all 3385 original
tics and 3386 whole snapshots through GA_COMPLETED.
It generates zero rendered frames and cannot establish video completeness.
Full-rate rendering independently accepts 1735/3385 frames,
then rejects tic 1736. 1735
whole accepted frames equal all three native pixel profiles. There are
1 virtual-pointer sample uses touching
1 destinations. The common native pixel gate
passes for 111,039,999 pixels
outside virtual-derived destinations. Virtual-derived bytes remain deterministic
extensions even where they happen to equal native bytes.

The rejected sample is index 565 beyond 552 source
bytes, at physical zone offset 824125. It reads byte
13 of allocated block 999,
inside its owner-slot pointer at header offsets 8–15. Provenance is unknown.
The diagnostic replays every prefix tic and reproduces the full-rate attempt's
exact savedDigest. Its capture rollback preserves the complete saved state,
native snapshot, frame counter and zero logs. [Bounds diagnosis](ULTIMATE-RENDER-BOUNDS.md)
explains why gas or memory increases cannot supply the missing owner address.
No engine algorithms, allocator semantics, draw guards, inputs or goldens change.

Partial recording gas: 2,256,471,884,011, including gameplay
488,730,313,112 and captures (including the rejected transaction)
1,763,413,663,429. Separate complete-gameplay gas:
134,775,446,906; diagnostic gas: 64,016,500,702.
Costs belong to separate runs and are not interchangeable. Measured partial
replay session: 2056.902436 seconds;
complete gameplay session: 104.601883 seconds.
UTC bounds and RPC timing remain in the result. All use local Anvil with Cancun,
1 GiB EVM memory, 10B transaction/block gas, unlimited request bodies and
bounded two-block history. No infrastructure cap caused this rejection.

MP4: **none**. No missing frame is reused or represented as full-rate output.
Ignored local `artifacts/local/ultimate-speedruns/E1M6/full-rate`
preserves accepted pixels, native comparison and receipts; `gameplay` preserves
full gameplay proof; `render-diagnostic` preserves the error-only reproduction.
[Evidence manifest](../artifacts/ultimate-speedruns/E1M6/evidence-manifest.json) binds these local proofs.
Commercial geometry/resources/artwork stay local. Unknown owner-slot bytes are
the unresolved rendering blocker.
