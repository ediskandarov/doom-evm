# Ultimate DOOM E1M1 full-rate recording

Completed on the integrated experimental profile. Original DSDA UV Speed demo:
[aconfusedhuman, `e1m1-903.lmp`](https://dsdarchive.com/files/demos/doom/54454/e1m1-903.zip),
recorded with DSDA-Doom0.18.0 complevel3. The preserved tape and SHA-256 are in
[source.json](../artifacts/ultimate-speedruns/E1M1/source.json).
Classic Ultimate DOOM1.9 IWAD MD5 `c4fe9fd920207691a9f493668e0a2083`, SHA-256
`6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f`.
Commercial resource/world/frame payloads and media remain ignored locally.

The original command reader exactly agrees with the decoded tape. Original-C
O2, O0, ASan/UBSan and fresh0xa5 allocation-fill gameplay all agree on317 DSG1
observations and genuine normal exit at tic316, line326. The stock Linux DOOM
version110 loader rejects the109 header; the preserved original command reader
and gameplay functions are tested directly without changing that version check.

Actual EVM execution matches all317 complete native world snapshots and renders
all316 post-tic frames. Independent fresh-prefix O2/O0/sanitized original-C
renders match every64,000-byte framebuffer. No virtual-pointer sample was used
in this finite tape. This is finite profile equality, not universal pixel or
allocation equivalence. Captures render a temporary copy and do not persist
renderer history into gameplay; no production UI acceptance is claimed.

Verified recording gas:252,404,150,437 total;43,713,010,620 gameplay and
205,058,695,425 captures. Capture RPC wall-time sum234.127623 seconds; successful
gameplay RPC sum and startup/deployment details are in
[result.json](../artifacts/ultimate-speedruns/E1M1/result.json). The final replay
session took277.736904 seconds. UTC bounds include checkpoint/recovery gaps;
these differently instrumented measurements are not a native/EVM speed ratio.
The interrupted pre-disk-stop attempt retains its log and frame files but lacks
complete receipts beyond its last checkpoint; its unmeasured total gas is not
estimated or included in the verified recording total.

Anvil: localhost18641, Cancun,1GiB execution memory,10B transaction/block gas;
RPC request body limit disabled; history/transaction retention2 blocks, with all
accepted mined receipts preserved separately. Solc0.8.37, viaIR and optimizer200
remain unchanged. Streamed binary chain checkpoints and file-based restore
passed the deliberate tic10 stop and post-disk recovery. Superseded chain dumps
were removed only after verifying retained checkpoint hashes; proof receipts,
original demos and failure evidence remain preserved.

Local MP4: `artifacts/local/ultimate-speedruns/E1M1/full-rate/speedrun-e1m1.mp4`,
316 frames at35fps,9.028571 seconds,1280×800 stored raster and4:3 display.
Independent verification checks actual Frame receipts, state bytes, source hashes,
provenance records, PNG palette expansion, MP4 frame count/rate/duration/aspect
and media hashes. H.264 is lossy; indexed8/PNG hashes preserve source pixels.
The representative contact sheet was visually inspected.

[Evidence manifest](../artifacts/ultimate-speedruns/E1M1/evidence-manifest.json)
binds the local receipt/state/media reports by hash. All commercial geometry,
framebuffer pixels, artwork and WAD payloads remain local; committed evidence is
metadata/hashes plus the original public input tape. No main merge or push.
