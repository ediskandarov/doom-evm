### Reusable presentation entry points (read-only inventory)

| Capability | Existing EVM entry points | Recording boundary |
|---|---|---|
| Classic status bar, health/armor/ammo/weapons/keys/face and palette | `DoomUI.initialize/restart/tick/drawStatus/drawHUD`; `ST_Init/ST_Start/ST_Ticker/ST_Drawer/ST_doPaletteStuff` | Use the existing non-fullscreen320x200 screen with `DoomGame.render(c,10)` (320x168 world plus32-pixel bar), authenticated original UI assets and persisted widget/face history. Current technical probe uses default view11/fullscreen and no ST/HU tickers. |
| Genuine completion and original statistics | `G_Game.G_DoCompleted`; `WI_Stuff.WI_Start/WI_Ticker/WI_Drawer`; `EpisodeRuntime.tick/draw` | Completion builds kills/items/secrets/time and original PAR from EVM state into `wminfo`; reuse original counter/acceleration/next-location phases, without host statistics or fabricated completion. |
| E1M8 and secret routing | `G_DoCompleted/G_WorldDone/G_DoWorldDone`; `F_StartFinale/F_Ticker/F_Drawer` | Map8 queues victory/finale instead of ordinary WI; genuine secret exits target E1M9, whose normal exit returns E1M4. Future recording must follow actual gameflow, not invent another level. |
| Indexed pixels, palette and encoding | Existing `Frame`/`FramePalette`, `VideoState.screens[0..4]`, authenticated `ResourceView`, recorder manifests/35Hz codec clock | Browser/encoder may present EVM indexes/palette only. Maintain4:3 display, authentic tapes and separate gameplay/wipe/WI/finale frame accounting. |

**Missing:** there is no Solidity `f_wipe` or EVM
`wipe_StartScreen/wipe_EndScreen/wipe_ScreenWipe`. `wipegamestate` is only a
marker. Pinned `f_wipe.c` captures start/end buffers in screens2/3, transforms
short pairs into column-major two-pixel slices, uses uneven `M_Random` delays,
then falls by `y+1` below16 and8 rows per tick, clipped at screen height.
Original `D_Display` advances its wipe using `I_GetTime` deltas, with no
`G_Ticker/P_Ticker` in that loop; menus draw over the wipe. This source was read,
not ported or executed during integration.

The current probe's `advance()` uses `DoomGame.tick`, refuses pending gameactions,
and `capture()` calls world-only `DoomGame.render` on a temporary copy. A separate
recording adapter still needs persistent UI/gameflow, EVM wipe state/buffers,
completion/finale sequencing and a distinct presentation clock. `EpisodeRuntime`
increments global gametic across game states; additional WI/finale updates must
not be reported as extra gameplay tics. Wipe frames must not advance gameplay.

Keep declared profile limits: UI borrows authenticated immutable assets;
pinned `WI_drawAnimatedBack` preserves C's unconditional `if (commercial) return`,
so counters/RNG advance but visible animated backgrounds are absent in that
profile. Production Doom/EpisodeStartup remain Freedoom-pinned; separate
UltimateStartup/UltimateWadResources admit the exact Ultimate IWAD. Future reuse
must retain that authenticated boundary and existing native/virtual distinctions.

The separately authorized follow-up must record gameplay with the original EVM
status bar, genuine post-level statistics/finale and EVM melt/end transitions,
with source-faithful timing and native/virtual pixel labels. No HTML/Canvas,
ffmpeg or CSS scene/status/wipe rendering, placeholder transition, host-computed
stats or invented next-level progression is permitted. Preserve all nine current
technical videos, tapes, snapshots, accepted indexed hashes and manifests;
write future publication attempts separately. This integration implements none
of those presentation features and regenerates no MP4.
