# Ultimate DOOM E1M8: complete gameplay, blocked rendering

Authentic UV Speed by Sedlo: [e1m8-046.lmp](https://dsdarchive.com/files/demos/doom/30217/e1m8-046.zip).
Demo SHA-256: `a47622d63d3b797280842c86b858cf80a7d85b7b1df03882db08f5f16fb261ef`. Exact classic Ultimate DOOM 1.9 IWAD MD5
`c4fe9fd920207691a9f493668e0a2083`; full SHA-256, source/compiler/ABI/resource
identity and runtime settings are bound in [result.json](../artifacts/ultimate-speedruns/E1M8/alternatives/sedlo-046/result.json).

Native C reaches a genuine exit at tic 1638. O2, O0 and
ASan/UBSan normal initial-zero-zone whole gameplay bytes agree. Alternate fresh
allocation-fill exactness: `True`.

A separate gameplay-only EVM run verifies all 1638 original
tics and 1639 whole snapshots through GA_COMPLETED.
It generates zero rendered frames and cannot establish video completeness.
Full-rate rendering independently accepts 262/1638 frames,
then rejects tic 263. 262
whole accepted frames equal all three native pixel profiles. There are
0 virtual-pointer sample uses touching
0 destinations. The common native pixel gate
passes for 16,768,000 pixels
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

Partial recording gas: 186,743,099,068, including gameplay
35,302,920,232 and captures (including the rejected transaction)
147,837,824,119. Separate complete-gameplay gas:
26,990,631,866; diagnostic gas: 7,314,986,949.
Costs belong to separate runs and are not interchangeable. Measured partial
replay session: 189.288506 seconds;
complete gameplay session: 22.451598 seconds.
UTC bounds and RPC timing remain in the result. All use local Anvil with Cancun,
1 GiB EVM memory, 10B transaction/block gas, unlimited request bodies and
bounded two-block history. No infrastructure cap caused this rejection.

MP4: **none**. No missing frame is reused or represented as full-rate output.
Ignored local `artifacts/local/ultimate-speedruns/E1M8/alternatives/sedlo-046/full-rate`
preserves accepted pixels, native comparison and receipts; `gameplay` preserves
full gameplay proof; `render-diagnostic` preserves the error-only reproduction.
[Evidence manifest](../artifacts/ultimate-speedruns/E1M8/alternatives/sedlo-046/evidence-manifest.json) binds these local proofs.
Commercial geometry/resources/artwork stay local. Unknown owner-slot bytes are
the unresolved rendering blocker.

The original faster Zero-Master tape is also retained. Its pinned native C
playback overflows `intercepts[128]` at tic 159; an error-only guard confirms the
first out-of-array write before undefined behavior. [Fast-demo failure](../artifacts/ultimate-speedruns/E1M8/fast-demo-failure.json)
records that incompatibility. Sedlo's DOOM 1.9 alternate passes all four native
gameplay profiles and exits normally; its rendering fails for the independent
owner-pointer reason above. No overflow memory was reconstructed.
