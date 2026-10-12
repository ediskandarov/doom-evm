# README gameplay demonstration

[`freedoom-evm.gif`](freedoom-evm.gif) is a presentation derivative of the existing
accepted Freedoom 0.13.0 E1M1 EVM recording. It is not a new engine run or native
rendering. The original MP4 remains local and unchanged.

- Original file: `artifacts/local/speedrun-e1m1-video/speedrun-e1m1.mp4` in the
  recording owner's worktree.
- Original MP4 SHA-256: `cbc0f78a4b0da044e688cb2d5186ebd59c180cf95b5f94b773df0798c851d939`.
- GIF SHA-256: `135c1f806574c4daace7ddb793b25beaa224b1488d301934a2d17852288ee480`.
- GIF size: 1,899,005 bytes; 320×240, 7 presentation frames/s, looped.
- Original scope: 279 game tics, 280 matching native/EVM gameplay worlds,
  56 sampled EVM frames, 279 encoded frames at 35 FPS, 7.971429 seconds.

The animation shows game time, not EVM wall time. Original captures were taken
every five tics with a four-tic final interval. Conversion resamples the already
encoded video; it does not add gameplay samples or establish new pixel equality.
Both the MP4 and GIF are lossy presentation derivatives. Exact authenticated
indexed bytes are bound in the original evidence.

[Recording report and author/input provenance](../SPEEDRUN-E1M1-VIDEO.md),
[recording result](../../artifacts/speedrun-e1m1-video/recording-result.json),
[verification](../../artifacts/speedrun-e1m1-video/verification.json),
[frame manifest](../../artifacts/speedrun-e1m1-video/frame-manifest.json).

Reproduce the derivative from your retained hash-matched MP4, without running EVM:

```sh
ffmpeg -nostdin -v error -i /path/to/speedrun-e1m1.mp4 \
  -filter_complex '[0:v]fps=7,scale=320:240:flags=neighbor,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=none' \
  -loop 0 /path/to/new-freedoom-evm.gif
```

Generated with the local FFmpeg recorded in the release evidence. Encoder
version differences can change the GIF hash; this is not an acceptance golden.
The Freedoom artwork is copyright © 2001–2024 Contributors to the Freedoom
project, under the [complete BSD notice](../../test/fixtures/wad/COPYING.txt).
[Contributor credits](../../test/fixtures/wad/CREDITS.txt) are preserved with the
fixtures. No commercial DOOM artwork or IWAD is included in this demonstration.
