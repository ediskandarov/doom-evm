# Production input, Cheats and Automap — Goal 4.12

Baseline `9f7d09120a1a250fe38f85b4f4bcba6cc78b5117`; pinned original C,
Freedoom 0.13.0, solc 0.8.37/viaIR/optimizer200/Cancun and 10B gas budget.
Use the local toolchain, original checkout and immutable WAD/chunks under
`artifacts/local`. Verification generates separate outputs; accepted fixtures,
goldens, certificates and original C are never rewritten.

```sh
.toolchain/bin/forge build --offline src/evm/Doom.sol src/evm/ResourceStore.sol test/integration/InputRuntime.t.sol
python3 tools/reference/input-runtime/reference.py
python3 tools/reference/input-runtime/reference.py --check
python3 tools/reference/input-runtime/verify.py
python3 tools/reference/input-runtime/verify.py --node-only
node tools/reference/input-runtime/production.mjs --browser --port 18722 --output-prefix artifacts/local/input-runtime/production-final
python3 tools/reference/ui/reference.py
node tools/reference/ui/production.mjs --port 18723 --output-prefix artifacts/local/input-runtime/ui-final
python3 tools/reference/input-runtime/checkpoint.py
python3 tools/reference/input-runtime/checkpoint.py --check
```

`reference.py` executes unchanged original gameplay/renderer/AM/ST/HU/video/
cheat functions, verbatim extracted G_Responder/G_BuildTiccmd/G_DeferedInitNew,
and a named platform/tic/display adapter. Original ST's excluded IDMUS branch
matches the accepted cheat oracle. O0/O2/ASan+UBSan and alternate allocation
fill must agree for every output, including whole Frames. Native source spans,
compiler flags, hashes and adaptations are recorded. Original K&R implicit-int
AM declarations use the documented compiler extension; existing shift/patch
tail sanitizer boundaries remain recorded, not silently broadened.

The 51-tic corpus includes punctuation/mismatch consumption, repeated keydowns,
split prefixes and parameters, HUD Enter and F12 routing, original cheat effects,
AM follow/pan/zoom/grid/marks/overview, all IDDT stages, fullscreen/reopen/stop
notification quirks, pause, and persistent IDCLEV. JavaScript supplies only raw
original events to production; native state/commands/pixels are outputs only.

`production.mjs` refuses occupied/reserved ports, starts its own Anvil, uploads
all 1,755 authenticated immutable resource contracts with ordinary CREATE and
deploys source-bound production Doom. It compares 74 scalar fields, all15 ST
parser cursors and mutable sequences, the untouched standalone IDDT slot,
20 marker coordinates, all81 HUD bytes and every original linedef flag after
each tic. Each rendered receipt matches all64,000 original pixels and768
original palette bytes. Invalid later events and other mined failures must
preserve the complete contract storage root, sequence and logs.

`--browser` repeats the corpus on a fresh instance using actual Chrome Start,
DOM events, production event buffering and transaction APIs. Controlled
scheduling fixes tic boundaries; no-render packets use the same browser
transport. Receipt fallback is tested at the IDDT things frame. All Canvas
RGBA bytes must match native palette expansion. Blur stops the next command.
Node tests independently verify in-flight event retention, raw release flush,
failed/uncertain transaction handling, aliases and original key translation.
Every runner cleans up only its own node/server/Chrome/profile.

## Production API

Choose `initializeGameInput(bool fullscreen)` on a fresh deployment. Configure
browser clients with `gameplay:true`, `productionUI:true`, `rawKeyboard:true`
and optional `uiFullscreen:true`. Existing UI/world-only initializers and bitmap
commands remain accepted for their existing profiles; bitmap commands are
rejected after opting into raw mode.

`stepEvents(bytes,uint32)` and `stepEventsAndRender(bytes,uint32)` accept at most
64 ordered keyboard events, each encoded as two bytes `[type,key]` (`0` down,
`1` up). Empty batches tick held keys. Only responder-unconsumed events update
the persistent native key set. Browser US physical keys translate to original
unshifted ASCII/DOOM special numbers; WASD/E action aliases are applied in EVM.
Other OS/IME key symbols, mouse/joystick/chat/menu/demo/network input are outside
this keyboard profile. Recognizers remain case-sensitive at the raw ABI.

Stop/blur emits releases for held keys, preserving queued/in-flight events.
After a pending receipt settles, releases are sent in no-render tics, so AM
pan/zoom and ordinary keys cannot stick on resume. Failures do not automatically
retry a mutation; uncertain outcomes require normal channel reconciliation.
Pause (`255`) uses the original special command and original M_PAUSE pixels.

`cheatStatus`, `cheatSequence`, `automapStatus`, `automapMark` and
`automapDiscovery` expose authoritative inspection only. AM_Map owns production
IDDT; ST_Cheats.AM_CheckCheat is never called. Original Frame and Goal4.11
FramePalette remain unchanged, with one complete Frame per rendered command.

## Episode Runtime hook

IDCLEV retains `gameState.gameaction == GA_NEWGAME` and the exact
`inputRuntime.flow.deferredSkill/deferredEpisode/deferredMap`. It does not load
a map here. Episode Runtime must consume that existing request through original
gameflow ordering and synchronous P_SetupLevel; reject unsupported selections
atomically, never substitute E1M1. It must bind refreshed map/resource/zone
aliases and gameplay hooks, preserve mutable difficulty definitions, restart
ST/HU at the original console-player spawn boundary while retaining module
statics, synchronize AM/flow activity flags and clear native held keys at
G_DoLoadLevel. Do not reset cheat parsers or call AM_Init on map/rebirth/UI
lifecycle. Do not run the old P_Ticker path and full G_Ticker in the same tic.

AM marker bytes use the established immutable UI borrowing boundary. The
library's load/unload counters persist, including reentrant Stop->Start.
Original cache/tag requests are observed in native; no new whole-process zone
allocation equivalence or peak-memory claim is made. Full inherited Phase0–3,
episode/gameflow acceptance and multi-map loading remain later gates.
