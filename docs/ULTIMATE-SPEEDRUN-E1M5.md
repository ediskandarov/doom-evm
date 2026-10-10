# Ultimate DOOM E1M5: complete gameplay, blocked rendering

Authentic UV Speed by trioct: [e1m5-100.lmp](https://dsdarchive.com/files/demos/doom/51000/e1m5-100.zip).
Demo SHA-256: `4a3ffd0a1f92ac2980e9c3b5aafde01a6ec2fb4eaca0fdde61ab85d51e1ea48e`. Exact classic Ultimate DOOM 1.9 IWAD MD5
`c4fe9fd920207691a9f493668e0a2083`; full SHA-256, source/compiler/ABI/resource
identity and runtime settings are bound in [result.json](../artifacts/ultimate-speedruns/E1M5/result.json).

Native C reaches a genuine exit at tic 2110. O2, O0 and
ASan/UBSan normal initial-zero-zone whole gameplay bytes agree. Alternate fresh
allocation-fill exactness: `False`.
The original stair/platform uninitialized-field allocation diagnostic remains
failed; no field is masked. The explicitly named native normal-zone domain is
audited separately in [native domains](ULTIMATE-NATIVE-DOMAINS.md).

A separate gameplay-only EVM run verifies all 2110 original
tics and 2111 whole snapshots through GA_COMPLETED.
It generates zero rendered frames and cannot establish video completeness.
Full-rate rendering independently accepts 1063/2110 frames,
then rejects tic 1064. 1062
whole accepted frames equal all three native pixel profiles. There are
1 virtual-pointer sample uses touching
1 destinations. The common native pixel gate
passes for 68,031,999 pixels
outside virtual-derived destinations. Virtual-derived bytes remain deterministic
extensions even where they happen to equal native bytes.

The rejected sample is index 224 beyond 216 source
bytes, at physical zone offset 3009056. It reads byte
8 of allocated block 1254,
inside its owner-slot pointer at header offsets 8–15. Provenance is unknown.
The diagnostic replays every prefix tic and reproduces the full-rate attempt's
exact savedDigest. Its capture rollback preserves the complete saved state,
native snapshot, frame counter and zero logs. [Bounds diagnosis](ULTIMATE-RENDER-BOUNDS.md)
explains why gas or memory increases cannot supply the missing owner address.
No engine algorithms, allocator semantics, draw guards, inputs or goldens change.

Partial recording gas: 1,021,199,600,919, including gameplay
204,126,796,547 and captures (including the rejected transaction)
813,152,240,983. Separate complete-gameplay gas:
54,947,882,777; diagnostic gas: 26,950,697,342.
Costs belong to separate runs and are not interchangeable. Measured partial
replay session: 1002.872093 seconds;
complete gameplay session: 44.173173 seconds.
UTC bounds and RPC timing remain in the result. All use local Anvil with Cancun,
1 GiB EVM memory, 10B transaction/block gas, unlimited request bodies and
bounded two-block history. No infrastructure cap caused this rejection.

MP4: **none**. No missing frame is reused or represented as full-rate output.
Ignored local `artifacts/local/ultimate-speedruns/E1M5/full-rate`
preserves accepted pixels, native comparison and receipts; `gameplay` preserves
full gameplay proof; `render-diagnostic` preserves the error-only reproduction.
[Evidence manifest](../artifacts/ultimate-speedruns/E1M5/evidence-manifest.json) binds these local proofs.
Commercial geometry/resources/artwork stay local. Unknown owner-slot bytes are
the unresolved rendering blocker.
