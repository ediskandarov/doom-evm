# README gameplay demonstration

[`ultimate-e1m1.gif`](ultimate-e1m1.gif) shows Ultimate DOOM E1M1 (Hangar),
using a gameplay excerpt from the owner's specified, already verified recording:

```text
/Users/eduard/sandbox/doom-evm-full-videos/artifacts/local/full-videos/E1M1/pilot-v2/ultimate-e1m1-complete.mp4
```

The original MP4 is local, gitignored and unchanged. Its SHA-256 matches the
[committed recording manifest](../../artifacts/full-videos/pilot-long-v2/E1M1/manifest.json)
and [passed checks](../../artifacts/full-videos/pilot-long-v2/E1M1/checks.json).
The archive calls this the **long pilot**: 3,498 frames at 35 FPS, 99.942857
seconds, 1280×960 with square pixels and a 4:3 display aspect ratio. It is distinct
from both the earlier 279-frame experiment and the abbreviated E1M1 recording
used in the nine-map aggregate metrics. [Recording report](../ULTIMATE-FULL-VIDEOS.md#verified-e1m1-pilot).

## Excerpt and presentation

- Source interval: **00:02.200–00:07.200**, entirely gameplay. The opening Hangar
  room, movement and pistol fire are visible; the complete status bar is retained.
- GIF: **640×480**, 4:3, 256-color palette, 88 frames, 7,627,269 bytes.
- Sampling: 17.5 presentation frames/s from the 35 FPS MP4. GIF's centisecond
  clock uses 50/60 ms delays, totaling **5.03 seconds**; the last frame's hold
  accounts for the small difference from the five-second source interval.
- Nearest-neighbor resize; no crop, frame interpolation, added graphics or
  altered gameplay. No EVM frames were rerendered.

Playback follows game time, not EVM computation throughput. Both MP4 encoding
and GIF quantization are lossy presentation steps. Native-exact indexed-byte
comparisons belong to the recording's declared profile, not this GIF. Virtual
pointer limits still apply; see [compatibility](../COMPATIBILITY.md).

| File | SHA-256 |
|---|---|
| Original MP4 | `6d65e321e75f3c787fc31dc758d7460b1f4cd25f27e0b193e1d7f204a82d12f4` |
| README GIF | `b811b92aab89e3fe4bbe93b8e051279f9de7a535a7b5aa94bd742eba91275288` |

## Reproduce without running EVM

Use the retained hash-matched MP4 and a new output filename:

```sh
ffmpeg -nostdin -v error -ss 2.2 -i /path/to/ultimate-e1m1-complete.mp4 \
  -t 5 \
  -filter_complex 'fps=35/2,scale=640:480:flags=neighbor,setsar=1,split[a][b];[a]palettegen=max_colors=256:stats_mode=full[p];[b][p]paletteuse=dither=none' \
  -loop 0 /path/to/new-ultimate-e1m1.gif
```

Generated with FFmpeg 9.0.1. Encoder versions can change the GIF hash; it is not
an acceptance golden. [Media check and source bindings](../../artifacts/public-release/readme-media-update.json),
[change/verification report](../release/README-MEDIA.md).

## Credits and retained earlier preview

The original E1M1 tape is **aconfusedhuman's `e1m1-903.lmp`**; author/archive
provenance is retained in the [episode summary](../../artifacts/full-videos/EPISODE-SUMMARY.md#gameplay-identities-and-authoritative-statistics)
and recording manifest. DOOM gameplay artwork belongs to id Software and its
respective owners. The repository's code license does not relicense commercial
artwork. No IWAD or source MP4 is committed with this preview.

The initial release-preparation checkpoint used the
[Freedoom E1M1 derivative](freedoom-evm.gif). It remains archived with its unchanged
[media record](../../artifacts/public-release/media.json) and
[original recording evidence](../../artifacts/speedrun-e1m1-video/verification.json).
Freedoom's [BSD notice](../../test/fixtures/wad/COPYING.txt) and
[contributor credits](../../test/fixtures/wad/CREDITS.txt) apply to that earlier
preview, not to Ultimate DOOM's artwork.
