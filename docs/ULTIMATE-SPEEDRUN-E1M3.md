# Ultimate DOOM E1M3: complete gameplay, blocked rendering

Authentic UV Speed by Jonathan Rimmer: [e1m3-036/e1m3-036.lmp](https://dsdarchive.com/files/demos/doom/96083/e1m3-036.zip).
Demo SHA-256: `d91a896d529672e5bbc011b7607de75308c183643ee204d722e8704e348a9f5e`. Exact classic Ultimate DOOM 1.9 IWAD MD5
`c4fe9fd920207691a9f493668e0a2083`; full SHA-256, source/compiler/ABI/resource
identity and runtime settings are bound in [result.json](../artifacts/ultimate-speedruns/E1M3/result.json).

Native C reaches a genuine exit at tic 1291. O2, O0 and
ASan/UBSan normal initial-zero-zone whole gameplay bytes agree. Alternate fresh
allocation-fill exactness: `False`.
The original stair/platform uninitialized-field allocation diagnostic remains
failed; no field is masked. The explicitly named native normal-zone domain is
audited separately in [native domains](ULTIMATE-NATIVE-DOMAINS.md).

A separate gameplay-only EVM run verifies all 1291 original
tics and 1292 whole snapshots through GA_COMPLETED.
It generates zero rendered frames and cannot establish video completeness.
Full-rate rendering independently accepts 922/1291 frames,
then rejects tic 923. 922
whole accepted frames equal all three native pixel profiles. There are
3 virtual-pointer sample uses touching
3 destinations. The common native pixel gate
passes for 59,007,997 pixels
outside virtual-derived destinations. Virtual-derived bytes remain deterministic
extensions even where they happen to equal native bytes.

The rejected sample is index 1395 beyond 1384 source
bytes, at physical zone offset 3763387. It reads byte
11 of allocated block 1634,
inside its owner-slot pointer at header offsets 8–15. Provenance is unknown.
The diagnostic replays every prefix tic and reproduces the full-rate attempt's
exact savedDigest. Its capture rollback preserves the complete saved state,
native snapshot, frame counter and zero logs. [Bounds diagnosis](ULTIMATE-RENDER-BOUNDS.md)
explains why gas or memory increases cannot supply the missing owner address.
No engine algorithms, allocator semantics, draw guards, inputs or goldens change.

Partial recording gas: 1,055,438,777,854, including gameplay
211,882,819,601 and captures (including the rejected transaction)
839,481,087,063. Separate complete-gameplay gas:
40,480,507,576; diagnostic gas: 29,706,190,408.
Costs belong to separate runs and are not interchangeable. Measured partial
replay session: 999.445428 seconds;
complete gameplay session: 30.987815 seconds.
UTC bounds and RPC timing remain in the result. All use local Anvil with Cancun,
1 GiB EVM memory, 10B transaction/block gas, unlimited request bodies and
bounded two-block history. No infrastructure cap caused this rejection.

MP4: **none**. No missing frame is reused or represented as full-rate output.
Ignored local `artifacts/local/ultimate-speedruns/E1M3/full-rate`
preserves accepted pixels, native comparison and receipts; `gameplay` preserves
full gameplay proof; `render-diagnostic` preserves the error-only reproduction.
[Evidence manifest](../artifacts/ultimate-speedruns/E1M3/evidence-manifest.json) binds these local proofs.
Commercial geometry/resources/artwork stay local. Unknown owner-slot bytes are
the unresolved rendering blocker.
