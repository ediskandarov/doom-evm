# Goal 4.2 — Original status bar

The original `st_lib.c` widgets and status-bar portion of `st_stuff.c` are
implemented in `src/doom/st_lib.sol` and `src/doom/st_stuff.sol`, using the
accepted Goal 4.1 `V_*` operations. Upstream is
`a77dfb96cb91780ca334d0d4cfd86957558007e0`. This feature branch starts at
`084764b`. No existing engine interface, production adapter, browser, compiler
setting, historical fixture or acceptance certificate changes.

## Consumer interface

`STState` owns status globals and widget history. `STGraphics` owns original
lump bytes. Both types are local to the new module; the existing `GameState`,
`Player`, `GameDefinitions`, `ResourceView` and `VideoState` interfaces are used
unchanged. All patch decoding, widget composition, face selection, palette
selection and gamma lookup execute in the EVM.

1. Call `ST_Init(status, video, assets, source, consoleplayer)` once. It reads
   authentic named lumps using `R_Data` and allocates the original 320×32
   screen4 backing. Screen0 must reference the caller's 64,000-byte framebuffer.
2. Call `ST_Start(status, assets, game, definitions)` on player/level startup.
   Retain `STState` between tics, draws and restarts: original function statics
   and `st_facecount` survive `ST_Start`.
3. Call `ST_Ticker` after each game tick. It consumes the original miscellaneous
   `M_Random` stream, leaving the gameplay `P_Random` stream alone. Player,
   weapons, cards, damage, powers, attacker identity and coordinates come from
   existing game state. Call `ST_Drawer` for rendering, passing fullscreen,
   refresh and automap flags explicitly.
4. For the status mode, the caller selects
   `R_Main.R_ExecuteSetViewSize(renderState, 10, 0)` (320×168), renders the world,
   aliases `video.screens[0]` to that framebuffer and draws the status bar.
   Mode 11 retains the accepted 320×200 world; fullscreen hides status widgets.
   Switching visible modes requires the original refresh signal.
5. Consume `paletteRGB` when `paletteRevision` changes. It contains 768 RGB8
   bytes after the original gamma table. `st_palette` records the selected
   PLAYPAL bank; `ST_Stop` restores bank0 without changing `st_palette`, exactly
   as C does. `usegamma` is 0–4. Changing gamma alone does not invent an extra
   `ST_doPaletteStuff` upload; the caller retains the original palette lifecycle.

The dedicated `test/statusbar/StatusBarFrame.sol` consumer demonstrates complete
Frame emission and world composition. Its additive
`StatusPalette(uint64 indexed frameId, uint8 paletteIndex, bytes rgb)` event is a
**test consumer contract**, not a change to the frozen production Frame ABI or
an approved browser protocol. It precedes its associated Frame and carries the
actual EVM-selected RGB bytes. Production dispatch, persistence wiring and
browser palette transport remain with the integrator, as required by the
ownership boundary. There is no claim that the current production browser has
this feature enabled.

## Original behavior retained

- Ammo pointer redirection by weapon, 1994 no-ammo sentinel, zero and truncated
  positive numbers, width-dependent negative clamps, fixed minus placement,
  refresh-only percent signs and original unconditional numeric redraw.
- Health, armor, four ammo/current-max rows, six ownership indicators, arms
  background versus deathmatch frags, self-frag subtraction, keys with skull
  precedence and multiplayer face background.
- All 42 face patches in original order, pain offset/cache, random idle looks,
  weapon pickup grin, directional damage, self-damage, sustained fire delay,
  god/invulnerability and death; original priority and timer evaluation order.
  The original reversed `health - st_oldhealth > 20` ouch comparison is retained.
- Multi-icon `inum == -1` leaves the old icon/history intact. Refresh restores
  background before drawing. Binary icons restore their signed-offset rectangle
  when disabled by value; disabled widgets do not change history.
- Damage/berserk red, bonus gold and radiation suit green palette priorities,
  saturation and blink thresholds. With nonnegative normal counters the first
  red/gold banks (1 and 9) are not selected by the original `(count+7)>>3`
  formula. All five original gamma tables are copied byte-for-byte, including
  the nonidentity level0 table. The X11 `(c<<8)+c` channel representation maps
  exactly to these RGB8 components; no new color transform is introduced.
- Start/stop idempotence, palette restoration, fullscreen/automap flags and
  automap `ST_Responder` messages.

## Boundaries and adaptations

C globals/pointers become explicit memory contexts and update arguments. Widget
value inputs are evaluated at the original call sites; ammo remains live even
between ticker and draw, while the selected ammo pointer changes at ticker time.
Static C initializers execute only during the first `ST_Init`.

`STlib_init`'s STTMINUS resource lookup is grouped with `ST_loadGraphics`, since
this consumer retains immutable resource bytes rather than engine zone cache
pointers. PLAYPAL is loaded at that boundary too. `ST_unloadGraphics` and
`ST_unloadData` only retag native zone allocations and are not exposed: graphics
lifetime belongs to the caller's memory context. No native zone-tag/allocation
trace equivalence is claimed, and no shared zone adapter is changed.

Cheat parsing/music/gameflow branches of `ST_Responder` are outside Goal 4.2;
only its automap status messages are ported. The original source plan assigns
cheats to Goal 4.4, which has not been started. In the oracle, unreachable music,
gameflow and give-power platform stubs abort if invoked; original cheat parsing
is linked, but tests dispatch only the automap key-up messages.

Malformed patches/backing use the accepted video rejection policy. Invalid
widget restore rectangles and undefined INT_MIN negation reject. Defined normal
int32 behavior, original unsigned clock wrapping and message-counter wrapping
are retained. The native no-ammo pointer created before the first ticker would
point beyond `ammo[4]`; this port resolves the 1994 sentinel safely at creation.
No equality is claimed for dereferencing that undefined native pointer, negative
or overflowing damage counters, invalid resource/actor indexes or malformed WADs.

## Verification

`tools/reference/statusbar/reference.py` compiles unchanged original
`st_stuff.c`, `st_lib.c`, `v_video.c`, random, angle/table and weapon-definition
code. The host supplies resource/platform boundaries and observes file globals;
it does not reproduce the status algorithms. **1,299 steps in 11 sequences**
agree across O0, O2 and ASan+UBSan under the original repository's int32 wrap
profile. The committed traces compare 24 state fields and SHA256 of all 64,000
screen0 pixels, all 10,240 background pixels and all 768 palette bytes at every
step. Tests cover idle/firing/pain/damage/death/pickup/god, keys, all weapon ammo
mappings, numeric edge cases, restart, automap and all 42 face assets. Direct
face-index inputs in `all_face_assets` test asset ordering and pixels; separate
sequences test actual transition logic.

The native sanitizer excludes array-bounds instrumentation for original
variable-size `patch_t.columnofs[8]`; ASan physical bounds remain active. Leak
detection is disabled for the short-lived resource host. Strict ISO-C undefined
behavior equivalence is not claimed. The renderer composition reuses the
accepted renderer oracle's documented LP64 and sentinel-object adaptations.

`world.py` makes one host-only change, `screenblocks=11` to `10`, using the
unchanged accepted renderer builder. O0/O2/sanitizers agree on the 320×168 native
world. Its bottom32 are combined with the native status first-refresh pixels.
The Solidity integration runs the actual existing renderer plus status modules
and compares the complete 320×200 result. A second test compares legacy mode to
the unchanged accepted Phase3-compatible full-world angle0 golden.

Focused result: **17 new Foundry tests pass**, plus **17 existing video tests**.
The full inherited regression and production browser acceptance are deferred to
Phase4 acceptance. No existing assertion or golden is weakened.

Ordinary isolated Anvil additionally deploys original resource chunks through
`ResourceStore` CREATE and emits three complete frames (192,000 pixels) with
native-matching palettes: base bar, damage flash and hidden fullscreen status.
A malformed STBAR transaction reverts with no logs or frame counter mutation.
Those receipts use a seeded upper background; the real world composition is the
separate Foundry/native proof above. Receipt gas includes resources/setup/events
and is not an isolated widget or production gameplay performance claim.

Fixtures use authentic **Freedoom 0.13.0** assets with its BSD license preserved;
the logic is the pinned original DOOM C. This does not redistribute proprietary
DOOM artwork. The full WAD remains local and checksum-verified.

Commands (pinned `.toolchain/bin` tools):

```sh
python3 tools/reference/statusbar/reference.py --check
python3 tools/reference/statusbar/world.py --check
.toolchain/bin/forge test --offline --match-path 'test/{unit/st_*,integration/StatusBar}.t.sol' --skip GameplayProbe --skip RendererProbe --skip WadResourcesProbe --skip Doom.sol --skip DoomGame.sol -vv
.toolchain/bin/forge test --offline --match-path 'test/{unit/v_video,integration/VideoPrimitives}.t.sol' --skip GameplayProbe --skip RendererProbe --skip WadResourcesProbe --skip Doom.sol --skip DoomGame.sol -vv
node tools/reference/statusbar/evm.mjs
python3 tools/reference/statusbar/checkpoint.py --check
```

The skips exclude unrelated build roots; no test in the named gate is skipped.
Evidence lives in `artifacts/phase4/statusbar-{verification,source-map,evm}.json`.
Stop after Goal4.2 on `feat/phase4-statusbar`; do not merge or start another goal.
