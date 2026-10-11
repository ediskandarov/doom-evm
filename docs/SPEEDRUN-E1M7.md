# E1M7 speedrun acquisition checkpoint

Status: blocked before native or EVM replay. The complete Speedrun.com API query
returned 36 runs, no pagination remainder. This map's indexed tapes belong to
Freedoom 0.12.1 EC-Max; each author-linked original download returned HTTP 403
on 2026-10-10. No verified original input bytes or compatible pinned-0.13.0
recording were acquired. Compatibility cannot be inferred from a map name.

- [Shepardus — EC-Max (0.12.1)](https://www.speedrun.com/freedoom_phase_1/runs/zx62vd5z): original demo URL `https://www.doomworld.com/applications/core/interface/file/attachment.php?id=109917`; HTTP 403.

The search also checked current PdKM-Speed, EC-Speed and 0.13.0 EC-Max listings,
map-specific web queries and the DSDA Freedoom endpoint (HTTP 404). This is a
bounded source search, not a claim that no compatible demo exists anywhere.
Browser surfaces were unavailable and native computer access lacked permission.
No inputs were synthesized or reconstructed from videos.

[Per-map result](../artifacts/episode-speedruns/E1M7/result.json) and
[evidence manifest](../artifacts/episode-speedruns/E1M7/evidence-manifest.json)
preserve candidates, authors, URLs, actual failures and unmeasured fields.
Gameplay tics, native/EVM agreement, pixel equality, virtual-derived pixel counts,
execution time and MP4 are unestablished; EVM frames and gas consumed are zero.

The recorder calls `EpisodeStartup.initialize` directly and calls `DoomGame.load`
once before `G_InitNew`; it does not use the menu first-game startup path.
E1M7 was not executed: no MemoryOOG occurred in this goal and neither map complexity nor the menu duplicate-context issue is asserted. No fix integration is requested without a reproducer.

Next action: supply/recover the original downloadable tape, verify its SHA-256
and original-C compatibility against the pinned IWAD, then independently record
it with the reusable tooling. This map does not invalidate other recordings.
