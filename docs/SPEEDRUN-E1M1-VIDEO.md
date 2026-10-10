# EVM E1M1 speedrun video recording

## Scope checkpoint

Independent extension of the verified real demo replay at `bb16afd879d5fe818ada5a21834027c07a4b3803`; existing worktree `/Users/eduard/sandbox/doom-evm-speedrun`, branch `feat/phase4-speedrun-e1m1`. Start measured 2026-10-10 15:38:14 UTC.

Ownership: new speedrun video support contract, recording/media runners and this report only. Preserve the accepted no-render contract/runner, original tape, native snapshots, existing verification and prior report. No production contract, original C, main, shared Phase 4 ledger, other worktree or runtime change.

Dependencies: pinned native replay evidence and IWAD, authenticated resource deployment, existing `DoomGame.render` and frozen `IFrameProtocol.Frame` event, ffmpeg/ffprobe and host-only palette/PNG/nearest-neighbor conversion. Runtime prefers checked-free port 18620; reject occupied/reserved ports and stop only the owned Anvil.

Verification gates: focused affected-root build; verbatim original demo commands and all 280 native gameplay snapshots; genuine exit; actual EVM-rendered Frame receipts and pixel hashes; capture has no persisted gameplay effect, while reporting renderer effects on its temporary memory copy; authenticated palette; precise 35 Hz media timing,1280×800 raster and 4:3 presentation; visual inspection of representative frames; old offline replay proof still passes.

Stop after generating ignored MP4/contact sheet/frame manifest, verifying and committing reusable tools/docs plus small checkpoint evidence. No rendering in native C or JavaScript, no episode progression, no production API changes, no full inherited acceptance.

Initial design: an isolated video companion to the existing runner and support probe, retaining their accepted source identity. Render only a memory copy of authoritative saved state and emit standard Frame events. Preserve the existing gameplay tape and serialize every post-tic DSG1 observation. Sampling starts at one frame for each five-tic gameplay transaction, with the final four-tic interval retained. Each sampled post-tic image represents its preceding interval, held for exactly that interval's length divided by35 seconds; finer sampling approaches ordinary35 fps post-tic display. Host media conversion only expands authenticated palette indexes, repeats/scales pixels and encodes.

## Record it

From this worktree, run:

```sh
node tools/reference/speedrun/record.mjs
```

Requires the pinned repository toolchain, Node 24, Python3 with Pillow, ffmpeg with libx264, and ffprobe. The command restores missing verified input files from committed evidence, downloads/hash-checks the official Freedoom IWAD if missing, packs authenticated resources, verifies the old 280-snapshot proof, builds only affected roots, refuses an occupied Anvil port, runs actual EVM transactions, encodes media and independently verifies receipt/pixel/palette/timing evidence. It never invokes native rendering. The existing verified no-render runner and support contract remain unchanged; the video companion reuses their deployment/command/state-comparison recipe and the shared DSG1 decoder.

Generated files are ignored under `artifacts/local/speedrun-e1m1-video/`:

- `speedrun-e1m1.mp4`:1280×800 stored raster, 4:3 display aspect, 7.971429 seconds.
- `speedrun-e1m1-contact-sheet.png`:12 representative 4:3 panels with tic labels.
- `frame-manifest.json`:capture tics, indexed8/PNG/RGB hashes, mined transaction hashes, gas, render-memory effects and exact presentation durations.
- `frames/`:original EVM indexed8 bytes and palette-expanded320×200 PNGs.
- `evm.json`, compressed receipts/state streams, `palette.bin`, `video-verification.json`, `ffmpeg.log`:local execution/provenance evidence.

Options:

```sh
node tools/reference/speedrun/record.mjs --sample-every 5 --port 18620 --output-dir artifacts/local/my-speedrun-video
node tools/reference/speedrun/record.mjs --encode-only --output-dir artifacts/local/speedrun-e1m1-video
```

`--sample-every N` supports1–279 tics; the last tic 279 is always captured. Gameplay batches remain at most five tics and split at sampling boundaries; exact original command bytes/order are unchanged. The verified default captures5,10,…,275,279:56 unique EVM images. The encoder holds each image for its covered tic span at 35 fps (last interval four tics), producing279 coded frames without interpolation. At default sampling, images represent their preceding five-tic interval; this is approximately 7 Hz visual sampling in an accurately paced35 fps container. **Sampling every tic currently fails at tic 52; see the documented renderer limit below.** A render failure aborts the recording and retains failure evidence; there is no automatic frame replacement or fallback.

MP4 scaling uses `scale=1280:800:flags=neighbor,setsar=5/6`. The5:6 sample aspect makes the1280×800 raster display at 4:3. PNG source images preserve exact RGB palette expansion; contact-sheet panels independently use nearest-neighbor320×240 square-pixel presentation. H.264 encoding is lossy; indexed8 and PNG hashes preserve the exact source pixels. Palette variant 0 matches the authenticated WAD palette hash. This records the accepted fullscreen world/weapon view; it does not add status-bar/UI/palette-flash features.

## Rendering and state fidelity

[`SpeedrunVideoProbe`](../src/support/SpeedrunVideoProbe.sol) initializes the same E1M1 skill 0 engine and consumes the same original four-byte ticcmds. `capture(tic)` loads authoritative storage into a memory copy, invokes unmodified `DoomGame.render` → `DoomRenderer` → original-source Solidity renderer libraries, and emits the frozen [`Frame`](../src/evm/FrameProtocol.sol) event. Pixels come solely from mined EVM receipts, decoded with the existing [`web/protocol.mjs`](../web/protocol.mjs). Host code only expands palette indexes, repeats/nearest-neighbor scales pixels, lays out contact panels and encodes video.

Rendering really changes its temporary context: for example, at tic 5 `validcount` changes 7→8 and mapped lines 0→63; the rendered DSG1 digest differs. `CaptureProof` reports pre/post memory digests, counters and renderer gas. The adapter never assigns that memory context back to saved gameplay. A separate storage snapshot after every capture must still equal the original native state. This intentionally avoids coupling observation to simulation; render caches/fuzz history/automap discovery from a capture are not persisted. It is an observational recording, not acceptance of production `stepAndRender` or a continuously persisted renderer history.

The successful default-cadence run retains all 280 exact startup/post-tic native/EVM DSG1 snapshots, original input hash, genuine normal exit at line 407/tic 279, and a final exact persisted-state check. No gameplay divergence or fixture change is hidden. The prior `verify_evidence.py` check still passes unchanged. `verify_video.py` additionally reconstructs all gameplay receipt states, decodes every actual Frame receipt, compares indexed8 bytes and native checkpoint digests, independently expands all PNG palette bytes, verifies source hashes and checks MP4 duration/frame count/dimensions/aspect with ffprobe.

## Full-rate renderer failure

An attempted `--sample-every 1` produced51 real EVM frames and matched native gameplay through tic 52, then its tic 52 render transaction reverted. A second isolated run with `--sample-every 52` reproduced the same first render failure without any preceding capture. Actual revert data is `0x5b9a48fe`, matching `DrawBounds()` in [`r_draw.sol`](../src/doom/r_draw.sol). Failed capture gas was641,531,003, below the unchanged 10B budget; this was a custom bounds error, not gas exhaustion. The source uses this error for several column/span/source-tail/destination bounds checks; the exact guard/source byte is not established by the returned selector. No unsupported-memory assumption or renderer modification was introduced to force a pass.

Both failed runs retained exactly matching native world-state prefixes through tic 52 and stopped their own Anvil. Their full receipts/reports remain ignored under `full35/` and `tic 52-diagnostic/`. The five-tic cadence reaches the real exit and captures every requested frame successfully. Full 35 Hz rendering needs a separate renderer-domain investigation; it is not claimed successful here.

## Verified final recording

The exact documented default command completed successfully on fresh isolated Anvil 18620. Final execution ran 2026-10-10 15:53:15.249→15:54:54.984 UTC. The owned node stopped after receipt/state export. Solc 0.8.37 `f401782d`, viaIR, optimizer200, Cancun and the unchanged 10B budget were retained; initial focused compilation took 47.51 seconds. ffmpeg 9.0.1, Pillow 12.1.1 and Node 24.11.0 were used. A second successful 56-frame capture matched every indexed8 frame hash from the first run.

| Measurement | Actual final result |
|---|---:|
| Gameplay tics / native-equivalent world observations | 279 / 280 |
| Unique EVM-rendered frames / Frame transactions | 56 / 56 |
| Gameplay transactions | 56 |
| Capture transaction wall time sum | 31.211948 seconds |
| Gameplay plus capture replay wall time | 44.601648 seconds |
| Capture transactions gas, including context load/proofs/events | 40,039,679,375 |
| Renderer-only `gasleft` deltas within captures | 22,712,735,752 |
| Gameplay transactions gas | 21,207,385,329 |
| Deployment/startup/replay/capture total gas | 69,867,162,335 |
| Total successful transactions including deployment/startup | 1,869 |
| MP4 coded frames / rate / duration | 279 / 35 fps / 7.971429 seconds |
| Encoding wall time | 0.505922 seconds |
| MP4 size | 2,360,559 bytes |

Wall times include local RPC/mining/receipt handling; capture transaction gas also includes loading/observations/events and is not renderer-only gas or production transaction cost. Deployment and startup are outside the44.6-second replay measurement. No native rendering performance is measured in this goal.

MP4 SHA-256:`cbc0f78a4b0da044e688cb2d5186ebd59c180cf95b5f94b773df0798c851d939`. Contact sheet SHA-256:`24cff2c8e736512a13e336871543616595dd72e329c200744a90b4640c8677d8`. The contact sheet and final decoded MP4 frame were visually inspected; the route, weapons, doors and final green exit switch are visible. Source PNGs exactly match authenticated palette expansion of mined EVM pixels. The media stay ignored locally; compact committed [`recording-result.json`](../artifacts/speedrun-e1m1-video/recording-result.json), [`frame-manifest.json`](../artifacts/speedrun-e1m1-video/frame-manifest.json), [`verification.json`](../artifacts/speedrun-e1m1-video/verification.json) and [`render-failures.json`](../artifacts/speedrun-e1m1-video/render-failures.json) bind success and the preserved finer-cadence failure.

Verification passed: affected-root compile/formatting, Python/Node syntax, old 280-world receipt proof unchanged, new 280-world exact EVM replay,56 actual Frame receipts with unchanged saved gameplay, independent PNG palette comparison, MP4 duration279/35 and 35 fps/count/dimensions/aspect, repeat indexed8 hashes, ignored-output check, documentation links and whitespace. No complete inherited acceptance was run, no original/native fixture assertion was changed, and no production source was modified.

Scope checkpoint:`6e876b6`. Final implementation is a Gitmoji checkpoint on this same feature branch; `git rev-parse HEAD` identifies the exact handoff SHA. Owned files are the new video support contract, four recording/encoding/verification tools, this report and compact video evidence. The original speedrun checkpoint and its files remain intact. No main changes, merges or pushes. The pre-existing untracked `.toolchain` symlink remains; generated media and full receipt dumps remain ignored. Stop after this recording handoff; the separate full-rate bounds investigation is outstanding.

Measured verification end: 2026-10-10 15:58:19 UTC. Goal-service attribution at this checkpoint: 108,558 tokens and 1,205 elapsed seconds; per-stage token/cost attribution is unavailable.
