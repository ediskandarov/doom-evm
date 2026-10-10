# Goal 4.3 — HUD messages

Implemented on `feat/phase4-hud`, based on accepted video checkpoint `084764b`.
The original source is `linuxdoom-1.10` at
`a77dfb96cb91780ca334d0d4cfd86957558007e0`. This goal owns only the two HUD
modules, dedicated tests, reference tooling/fixtures, and this report/evidence.
Production adapters, shared engine layouts, compiler settings, prior fixtures,
and accepted Phase 0–3 evidence are unchanged. No multiplayer chat is implemented.

## Source mapping and integration boundary

| Original | Solidity |
|---|---|
| `hu_stuff.c`: `HU_Init` | `HU_Stuff.HU_Init`: original `STCFN033` through `STCFN095` name construction and existing EVM WAD lookup/read; returns the cached patch bytes |
| `HU_Start`, `HU_Stop` | Explicit `HudState`; creates the one-line top-left message widget and title at `(0, 167 - firstGlyphHeight)`; original active map-title switch and literal tables |
| `HU_Ticker` | Consumes existing console `Player.message`, decrements timer before accepting new messages, retains pending messages while hidden/protected |
| `HU_Responder` | Original single-player keydown/Enter refresh branch; returns whether it consumes the event |
| `HU_Drawer`, `HU_Erase` | Original message/title drawing and erase order, with chat calls omitted; automap flag supplied by caller |
| `hu_lib.c`: init, clear/init/add/delete/draw/erase text line | `HU_Lib` functions with matching names; 80-character limit, 81-byte NUL-terminated backing, retained stale tail bytes and original update counts |
| init/add-line/add-message/draw/erase scrolling text | Four-slot `HuSText`, current-line wrapping and newest-to-oldest drawing; explicit `on` value replaces the C pointer |
| Input widgets, keyboard translations, chat macros/queues/receivers | Excluded under the no-chat scope |

`HUlib_drawTextLine` uppercases ASCII, advances spaces and unsupported characters
by four pixels, advances glyphs by the original patch width without spacing,
and stops at the original 320-pixel boundary. It calls accepted
`V_DrawPatchDirect` for every glyph. Patch offsets, transparent posts, and
whole-patch RANGECHECK rejection execute inside the EVM. No browser text drawing,
font conversion, scaling, or partial glyph clipping is introduced.

`HUlib_eraseTextLine` uses accepted `R_VideoErase` to copy screen1 to screen0:
whole rows outside the view and the original equal-width left/right borders
inside the view. The original first-font-height + 1 row count is retained.
Update counters decrease even when full-screen mode or automap prevents erasure.
The unused C `lastautomapactive` assignment supplies no transition refresh logic;
the port does not invent one. Disabling an active scrolling widget requests four
erase passes. Erasure does not mark the video dirty box.

Messages last 140 tics (four seconds at the original 35 Hz). The final decrement
hides the message and clears protection before the same tick can accept a pending
message. The forced-message flag bypasses the show/protection gates and transfers
to protection on acceptance. Changing `showMessages` does not immediately hide a
visible message. Enter refreshes even an empty widget and preserves protection.
`HU_Start` resets visibility/protection but preserves the counter, as in C.
`HU_Stop` only changes `headsupactive`; the original drawer/ticker do not test it.

Consumers pass the existing console `Player` memory reference, video buffers,
and render view. HUD memory contexts can be copied to/from storage; a dedicated
separate-call test proves protected pending-message and expiry behavior survives
that round trip. This goal supplies the HUD composition boundary, not production
adapter wiring (reserved for later Phase 4 integration). Dedicated integration
tests invoke actual `P_TouchSpecialThing` and `EV_VerticalDoor`, feed their
`Player.message` into this boundary, load WAD fonts through the existing resource
reader, and emit complete indexed8 Frames from EVM execution.

## Resources and declared adaptations

All 63 glyph fixtures are exact original lump bytes from the project's pinned
Freedoom 0.13.0 resource bundle. `fonts.json` binds their names, lump IDs,
dimensions/offsets, individual SHA-256 hashes, full resource hash and provenance.
Freedoom's redistribution license accompanies the fixtures. Proprietary id WAD
assets are not bundled. The HUD accepts the same original STCFN patch format.

The existing engine represents a null message pointer as an empty Solidity
string; native pending-message inputs use C NULL for that sentinel. Embedded NUL
terminates the widget message as in C. A separately allocated C empty string
cannot be represented distinctly by the existing `Player` interface. ASCII C
locale uppercasing is preserved; extended bytes have deterministic four-pixel
advances rather than invoking signed-char `toupper` undefined behavior. Invalid
map indexes, zero/>4 scrolling heights and invalid font spans are rejected
instead of exercising C out-of-bounds behavior. Existing video malformed-patch
and physical-buffer diagnostics apply unchanged.

The pinned C has commented-out Plutonia/TNT title switch cases. The port retains
the active Doom/Doom II switch, including Doom's nine `NEWLEVEL` fallback titles;
it does not enable those commented-out branches.

## Verification

- Native C O0/O2/ASan+UBSan profiles agree exactly: 209 scenarios, 575 snapshots.
  Each snapshot compares HUD flags/counter, responder consumption, pending player
  message, all four scrolling lines and title (including coordinates, lengths,
  NUL/stale backing bytes, update counters), dirty box and all 64,000 screen bytes.
- Native cases cover every glyph, every active map-title entry, mixed ASCII,
  right/bottom/negative positioning, cursor drawing, prefix/line truncation,
  four-line rotation, message replacement, forced protection, hidden pending
  messages, restart/stop, Enter/key-up/unrelated events, timeout boundaries,
  full/reduced-view/automap erasure and automap transitions.
- Forty-four producer cases run original C pickup/door logic before the native
  HUD, and actual Solidity gameplay before Solidity HUD: all 36 pickup types,
  needy-medikit and rejected full-health pickup, and six locked-door variants.
  Text and complete Frame pixel hashes agree. The world background is an explicit
  reproducible indexed pattern; topology/hooks isolate the message producers.
  This is a controlled gameplay composition proof, not a new full-world replay.
- Fourteen focused Foundry tests pass, including 256 capacity/NUL fuzz cases,
  exact WAD resource loading, patch offsets/transparency, storage round trips,
  complete Frame protocol output and inactive-HUD framebuffer preservation.
- Legacy production sources are byte-identical to the accepted baseline; the HUD
  has no implicit production dispatch. Full inherited regression is deferred to
  final Phase 4 as requested.

The [verification certificate](../artifacts/phase4/hud/verification.json) binds
the focused command results, HUD/fixture hashes and every accepted engine,
adapter and compiler-configuration file. Reproduce it with
`python3 tools/reference/hud/verify.py`.

Commands:

```sh
python3 tools/reference/hud/reference.py --check
.toolchain/bin/forge fmt --check src/doom/hu_stuff.sol src/doom/hu_lib.sol test/unit/hu_stuff.t.sol test/unit/hu_lib.t.sol test/integration/HudMessages.t.sol
.toolchain/bin/forge test --match-path 'test/{unit/hu_*,integration/HudMessages}.t.sol' --skip Doom --skip GameplayProbe --skip RendererProbe --skip WadResourcesProbe -vv
```

The skips exclude unrelated build roots, not tests within this goal. Native
source spans and hashes, exact host projections, profiles and scope are recorded
in `test/fixtures/phase4_hud/native.json` and `gameplay.json`. The original widget
and video translation units are compiled unchanged. HUD functions are extracted
mechanically with only the explicitly excluded chat branches removed. The
responder uses the exact extracted Enter branch and keydown gate. Native
`R_VideoErase` is the equivalent bounded screen1-to-screen0 memcpy. ASan retains
physical allocation checking; only the original variable-size
`patch_t.columnofs[8]` array-bounds check is disabled. Leak checking is disabled
for fixture-lifetime borrowed text/font allocations.

Goal 4.3 ends at the verified feature-branch commit. No merge into main and no
Goal 4.4 work are part of this change.
