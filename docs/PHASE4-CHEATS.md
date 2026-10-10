# Goal 4.4 — Original DOOM cheat codes

The cheat subsystem ports the pinned linuxdoom-1.10 `m_cheat.c` recognizer and
cheat branches of `ST_Responder` and `AM_Responder`. All recognition, messages,
parameter handling and gameplay changes execute in Solidity. `IDDQD`, `IDKFA`,
`IDFA`, both noclip codes, `IDBEHOLD` and all six variants, `IDCHOPPERS`,
`IDMYPOS`, `IDCLEV`, and `IDDT` are implemented. IDMUS and sound are excluded.

The implementation uses accepted `GameContext`, `Player`, `Mobj`, `GameConst`,
`P_Inter.P_GivePower`, and `G_Game.G_DeferedInitNew` interfaces. The accepted
status bar and HUD remain unchanged. This branch owns new `m_cheat.sol`,
`st_cheats.sol`, cheat-only support probes, reference tools, fixtures and tests.
It does not wire production adapters or change browser/Frame/input interfaces.

## Original behavior

| Input | Original effects retained |
|---|---|
| IDDQD | XOR god flag; enabling sets player health and non-null actor health to 100, including dead players; disabling leaves health alone |
| IDKFA / IDFA | Armor 200/type 2, every one of nine weapons, ammo set to current maxammo; only IDKFA grants all six cards; no pickup bonuses or weapon switch |
| IDSPISPOPD / IDCLIP | Either works in every mode; XOR player noclip flag, actor flag updates through the next existing `P_PlayerThink` |
| IDBEHOLD | Original menu message; each V/S/I/R/A/L recognizer also advances on the prefix |
| IDBEHOLD variants | Call existing `P_GivePower` when absent; existing strength clears to zero, every other existing power becomes one; invisibility clears its actor shadow flag on the next player tic; allmap's one is retained |
| IDCHOPPERS | Own chainsaw, invulnerability **one**, original message; expires through the next player tic, no weapon switch |
| IDMYPOS | Lowercase unpadded `%x` equivalent for angle and signed fixed-point coordinates interpreted as 32-bit unsigned; original message punctuation |
| IDCLEV | Capture two raw char bytes, clear parameter slots, apply original mode limits, retain skill and defer `GA_NEWGAME`; no synchronous map load |
| IDDT | In the entered active-automap keydown branch, outside deathmatch, cycle original `cheating` 0 → 1 → 2 → 0; completed code forces AM's result to false |

Mismatch resets the cursor and consumes the mismatching key, without retrying it
as a new prefix. Recognition is case sensitive. The responder preserves original
`else if` and short-circuit evaluation order, including stalled later recognizers
on a successful earlier code. Power variants advance independently. Keyup and
mouse/joystick events leave recognizers unchanged. `data1` narrows to its low
byte, including values outside ASCII. There is no timing window, tick counter,
uppercase conversion, retry, difficulty, health, pause or menu filter here.

ST cheats are gated by `!netgame`; IDCLEV is outside that guard, exactly as in C.
IDDT checks `deathmatch`, rather than `netgame`, and recognizes only within AM's
active branch. Multiplayer gameplay is not added; these native gate cases ensure
future routing does not silently change the original restrictions.

The pinned release computes commercial IDCLEV episode zero and then rejects
episode < 1. Consequently **every commercial warp is rejected**, including valid
DOOM II map numbers. This historical bug is preserved. Registered/retail episode
limits remain 3/4; shareware remains episode 1, all with maps 1–9. Actual accepted
gameflow currently supports Episode One. Recognizing other native-valid episode
requests is independently verified; loading them is not a capability claim.

`CheatSequence.cursor` replaces a native pointer with an offset. Scrambling is a
pure equivalent of the original lazily initialized 256-byte translation table.
Parameterized sequences remain mutable bytes, not a separate digit parser;
embedded zero, marker-like and terminator-like key bytes are tested against C.
`cht_GetParam` returns exactly the bytes C writes, including terminating zeros,
and clears only visited parameter slots. A first NUL in an IDCLEV parameter can
leave C's stack `buf[1]` uninitialized. Solidity retains the exact parser changes
but rejects that undefined gameplay request; no native gameplay equivalence is
claimed for uninitialized C reads. Invalid pointers/cursors and missing actors
for dereferencing cheats are outside the defined native domain and revert with
Solidity bounds checks. IDDQD's original null-actor case is supported explicitly.

## Required integration API

Create one `CheatState` for the engine lifetime and persist it atomically with
`GameState` and `GameflowState`, including all sixteen cursors, mutable sequences,
`positionMessage`, and `automapCheating`. Lazy `ST_Cheats.initialize` installs the
original encoded sequences. Do **not** reset recognizers on ST/HU/AM start/stop,
map changes, death or rebirth: original globals survive those operations.
An explicit new engine instance starts fresh. Use the same console player binding
as `STState.player` and `GameState.consoleplayer`.

At the existing EVM level-event routing boundary, preserve native `G_Responder`
order: HUD first; status responder second; AM third; ordinary keyboard handling
last. If HUD consumed an event, stop routing it. In the status stage, call both
`ST_Stuff.ST_Responder(st, eventType, data1)` (automap notifications) and
`ST_Cheats.ST_Responder(context, flow, cheats, uint8(eventType), data1)`.
Both return false. Only valid original event types 0–3 should be passed; keydown
is zero. Game-level/menu/demo routing remains the adapter's responsibility.
Raw keydown events must be delivered once, in authenticated input order, even
when a key is already held; the original recognizer sees events, not a held-key
bitmap. Browser code forwards raw events; it performs no cheat matching,
parameter validation or gameplay mutation.

Inside AM's **entered active-map keydown branch, after its switch**, call:

```solidity
bool completed = ST_Cheats.AM_CheckCheat(cheats, 0, data1, true, state.deathmatch);
if (completed) rc = false;
```

Invoke it even when the switch just closed the map with TAB: native control flow
already entered the active branch. Do not invoke it for TAB opening an inactive
map or for keyup. The helper's `activeBranch` describes entry into that branch,
not AM's possibly changed active flag after the switch. The AM owner retains
navigation, switch messages, view changes and default `rc`. Rendering reads
`automapCheating`: nonzero reveals hidden/secret map lines and the cheat player
arrow; value 2 also draws things, through the original AM drawing logic. Goal
4.4 verifies recognition/reveal state independently; AM geometry/pixels await its
own integration goal.

IDCLEV already calls accepted `G_DeferedInitNew`. Persist the modified
`flow.deferredSkill`, `deferredEpisode`, `deferredMap` and `state.gameaction`
with the parser/player state. The existing ticker consumes the deferred action.
The setup hook/resource owner must synchronously load the requested map and
rebind context aliases/hooks; until multi-map support is integrated, it must
reject unsupported resource requests atomically. Never silently load E1M1 for a
request to E1M9. The pending request and player feedback are verified here;
actual E1M9 resource loading and map progression remain later goals.

On player tics, keep existing `P_PlayerThink` so noclip and power expiration
occur at the original time. Status reads the same player and actor; HUD consumes
`Player.message` through its existing ticker and draws through `VideoState`.
Independent native comparisons here cover those status/HUD pixels and palettes
without changing either module. Persist the complete transaction before exposing
its frame/message; a downstream failure must roll back parser, mutations,
messages, deferred requests and input sequence together.

`CheatProbe` demonstrates storage persistence and ordered raw-key processing on
ordinary EVM transactions. Its reset method and test-only downstream-revert flag
are verification boundaries, **not** production APIs or authorization policies.
Production must reuse its existing caller/inputSeq authorization and frozen Frame
protocol; neither is independently modified by this branch.

## Verification

- Native gameplay: 150 scenarios, 4,196 event snapshots; player/actor effects,
  messages, inventory, deferred request and every recognizer cursor/sequence.
- Native primitives: 793 cases; all 256 key bytes at a normal character and both
  parameter slots, plus embedded NUL/marker/terminator and signed-char cases.
- Native presentation: 15 sequential raw-code checkpoints through original
  ST_Responder, ST_Ticker/Drawer and HUlib widgets; exact 320×200 frames, 320×32
  status backgrounds, RGB palettes and face/palette state compared to Solidity's
  accepted ST/HU composition. Authentic existing Freedoom fixtures and licenses
  are reused; no proprietary DOOM artwork is added.
- Ordinary isolated Anvil: 20 scenarios, 491 native event hashes across 254 input
  transactions; split prefixes/parameters, storage persistence, mined downstream
  rollback/retry, duplicate sequence rejection. No preinstalled cheat logic or
  host-side state mutation; ordinary CREATE and raw key transactions only.
- Focused Foundry gate: new cheat tests and directly consumed gameplay,
  gameflow, status and HUD dependencies. Full inherited Phase 0–3 regression,
  production/browser wiring, AM pixels and actual map loading are deferred.

The state/primitive oracle extracts original functions verbatim and removes only
the explicit IDMUS branch. AM's exact cheat branch is extracted separately.
O0/O2 and ASan/UBSan outputs agree. Presentation compiles original status and
widget translation units; its sanitizer profile retains the accepted exclusion
for `v_video`'s variable-width column table array-bounds instrumentation and
process-lifetime asset leak detection. Source spans/hashes, profiles, fixture
encodings and proof bindings accompany the fixtures and evidence.

Reproduce from the worktree root with the pinned local toolchain:

```sh
python3 tools/reference/cheats/reference.py --check
python3 tools/reference/cheats/presentation.py --check
.toolchain/bin/forge test --offline --fuzz-seed 0x434844 --match-path 'test/{unit/m_cheat,unit/p_inter,unit/p_user,unit/g_game_lifecycle,unit/st_lib,unit/st_stuff,unit/hu_lib,unit/hu_stuff,integration/Cheats}.t.sol' --skip Doom --skip GameplayProbe --skip RendererProbe --skip WadResourcesProbe -vv
node tools/reference/cheats/evm.mjs
python3 tools/reference/cheats/checkpoint.py --check
```

The skips exclude unrelated build roots, not tests in the named gate. The
state oracle uses signed native chars; presentation reuses the accepted native
platform/resource boundaries. Evidence is separate from all historical
acceptance: `artifacts/phase4/cheats-verification.json` and `cheats-evm.json`.
Implementation and independent feature verification are complete; production
integration is deferred under this task's ownership boundaries. No merge into
main, another feature, or full Phase 4 acceptance is performed.
