# README media correction

Started: **2026-10-12 07:14:03 UTC**. Baseline:
`947e788c863a1ed181584db3de03425769d0b575`. Owner: `feat/public-release` in
`/private/tmp/doom-evm-public-release`. This is a presentation-only follow-up to
[release readiness](READINESS.md), requested by the owner with an explicit local
source directory. Main and the recording owner's worktree remain read-only.

Scope: identify the MP4 in the specified `E1M1/pilot-v2` directory, validate its
existing evidence, select recognizable gameplay, preserve the complete 4:3 display
and status bar, optimize the GIF, and place it immediately after the unchanged
README introduction. No engine changes, new EVM rendering, source MP4 writes or
runtime launches. Stop after a verified Gitmoji commit and clean feature tree;
no merge or push.

## Source and result

The identified file is `ultimate-e1m1-complete.mp4`. Its SHA-256 matches
`6d65e321e75f3c787fc31dc758d7460b1f4cd25f27e0b193e1d7f204a82d12f4` in the
[committed long-pilot manifest](../../artifacts/full-videos/pilot-long-v2/E1M1/manifest.json).
The specified recording is 3,498 frames / 99.942857 seconds at 35 FPS, 1280×960,
4:3. The archive also contains a later abbreviated recording; this change uses
exactly the owner's requested `pilot-v2` source. Historical reports are not
rewritten to relabel either recording.

The source interval **2.2–7.2 seconds** contains 175 gameplay frames, with Hangar's
opening room, movement and pistol fire. The GIF samples these at 17.5 FPS,
retains the full viewport/status bar, and displays at 640×480. It has 88 frames,
5.03 seconds on GIF's centisecond clock, and is **7,627,269 bytes**. The source
MP4 remains local. [Current media provenance and reproduction command](../media/README.md).

An eight-second 640×480 trial was 11,764,583 bytes. Shortening the excerpt while
keeping the direct nearest-neighbor resize and 256-color palette reduced it to
7.6 MB. Smaller resolution/palette and native-grid resampling trials traded away
detail; per-frame palettes were larger. A Pillow re-encode preserved all decoded
pixels and delays but increased size, so the original FFmpeg output was kept.
No lossy post-compression or synthetic interpolation was added.

## Verification

- MP4 hash matches the committed certificate; its bytes and modification time
  remain unchanged after conversion.
- Source manifest confirms every frame in the selected interval is gameplay.
  Full-frame scaling preserves the status bar and 4:3 aspect ratio.
- Decoded GIF: 640×480, 88 frames, infinite loop, 50/60 ms frame delays, 5.03 s.
- Original contact sheet and final GIF frames inspected. At equal size and
  sampling, SSIM against the decoded source video was **0.987431**. This checks
  presentation quality; it is not a new native framebuffer comparison.
- Historical release evidence and the earlier Freedoom GIF remain unchanged.
  The README now uses the Ultimate GIF; its caption and credits identify the
  correct game. The introduction's wording is unchanged and navigation follows
  the image/caption.
- Documentation/preservation checker and Git whitespace checks run for this
  follow-up. No Solidity builds, EVM tests or recording-suite reruns are needed
  for this media/documentation-only change.

Machine-readable source/clip/GIF identities, exact FFmpeg command and checks:
[`readme-media-update.json`](../../artifacts/public-release/readme-media-update.json).
The separate [preservation and link audit](../../artifacts/public-release/readme-media-audit.json)
confirms 4,218 prior-release blobs remain unchanged outside the four current
documents intentionally updated here.
The prior release manifest remains immutable; this follow-up has separate
verification evidence. Trial GIFs and contact sheets remain ignored under
`artifacts/local/readme-media-update/`.

## Handoff

Changed: `README.md`, `docs/media/README.md`, new
`docs/media/ultimate-e1m1.gif`, follow-up notices in the release report/inventory,
and this report with separate media/audit evidence. No shared interfaces or
engine dependencies changed. Main is not modified, merged or pushed. The final
handoff message supplies the exact feature commit SHA.

Media verification completed **2026-10-12 07:24:11 UTC**, 10 minutes 8 seconds
from the measured start. Documentation/commit checks follow that checkpoint.
Per-model token/cost attribution for this follow-up is unavailable; none is
estimated.

Documentation/preservation verification completed at `2026-10-12T07:27:08.189884+00:00`: 159 Markdown documents, 894 local links, current anchors and unchanged
source/artifact/upstream bindings passed.
