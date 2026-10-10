# Goal 4.6 — Episode One gameflow

The gameflow core is in `src/doom/g_game.sol`. This work owns that file and
new dedicated tests/reference fixtures. Shared `p_game_state.sol`, input/Frame
protocols, production adapters, resources and inherited fixtures are unchanged.
The user explicitly includes completion and secret-exit semantics in this goal;
this ports those transitions without implementing the later multi-map loader,
intermission graphics or episode-ending presentation.

## Source correspondence

Pinned original: `a77dfb96cb91780ca334d0d4cfd86957558007e0`.
`test/fixtures/phase4_gameflow/manifest.json` records exact function spans,
SHA-256 hashes, headers, native compiler/profile and observing harness hashes.
All original C functions in the transition oracle are extracted verbatim.

| Original source | Port / responsibility |
|---|---|
| `G_DeferedInitNew`, `G_DoNewGame`, `G_InitNew` | Deferred request, original menu flag resets, difficulty/episode/map normalization, RNG reset, nightmare/fast definition mutation, player rebirth and synchronous setup |
| `G_DoLoadLevel` | Sky lookup, wipe/levelstarttic, dead-to-reborn, all-player frag reset, setup and heap callbacks, input/pause clearing |
| `G_Ticker` | Rebirth before action loop, action loop before command copy, special-button handling, state-specific ticker dispatch |
| `G_Responder` pause branch; `G_BuildTiccmd` sendpause branch | `G_RequestPause` and new builder overload; existing keyboard builder remains unchanged |
| `G_InitPlayer`, `G_PlayerReborn`, `G_DoReborn` | Original reset/stat preservation; single-player restart reloads the whole current level |
| `G_PlayerFinishLevel`, `G_DoCompleted` | Remove powers/cards/visual effects, retain inventory, copy intermission stats, select next map or victory |
| `G_ExitLevel`, `G_SecretExitLevel` | Existing gameplay requests retained, including original commercial missing-MAP31 behavior in the existing helper |
| `G_WorldDone`, `G_DoWorldDone` | Deferred continuation, secret credit timing, zero-based next map conversion and level-load lifecycle |
| `d_player.h` `wb*` structures | `GameflowIntermission` / `GameflowPlayerStats`, including preserved `score` |
| `p_user.c` / `p_inter.c` | Existing death/use/damage behavior, exercised unchanged by the dedicated tests |

Subtle original behavior is retained: a reborn player overwrites a previously
queued action; E1M8 completion reaches `F_StartFinale` in the same action loop;
UI tickers still run while paused; WI/F ticker dispatch is not stopped by pause;
resume advances the world in that tic; a command built before level setup is
copied after setup; `gametic` advances outside `G_Ticker`; `turnheld` and RNG are
not reset by a level reload. E1M9 marks **all four player slots** as having done
the secret level. A secret exit credits the console player at `G_WorldDone`,
after the intermission snapshot. Stats/frags and incoming commands are copied,
not aliased to Solidity memory arrays/structs.

The original cross-enum comparison in `G_DoLoadLevel` treats retail (3) like
`pack_plut` (3), so it looks up SKY3 and then SKY1 on Episode One loads. The port
preserves both lookups. Repeated `fastparm` initialization halves the demon
state tics repeatedly; leaving nightmare doubles the current values and can
retain odd-tic loss. The port does not normalize these source behaviors.

## Required integration API

These are handoff requirements, not changes made to integration-owned files.
The dedicated hosts demonstrate the API without altering production adapters.

1. Persist `GameState` and `GameflowState` together, after the whole action/tic
   succeeds. Initial caller state has player 0 active, consoleplayer 0, a supported
   game mode and loaded definitions/resources/hooks. Use `G_InitNew` for startup;
   menus use `G_DeferedInitNew` then `G_Ticker`. `initialized` becomes true only
   after successful synchronous setup and a live, allocated player actor check.
   It is an adapter guard, not a new original DOOM global.
2. Preserve mutable definitions across transactions: specifically
   `states[S_SARG_RUN1..S_SARG_PAIN2].tics` and the three projectile speeds for
   `MT_BRUISERSHOT`, `MT_HEADSHOT`, `MT_TROOPSHOT`. Full `GameDefinitions` storage
   is demonstrated in the transaction test; an exact compact representation is
   also possible. **`DoomGame.load` currently reloads defaults**; integration must
   restore these values after it loads definitions, before any gameflow/world
   work. Reconstructing them from `gameskill` alone loses repeated-fast semantics.
3. Rebind `GameflowHooks` after loading state. These are internal function
   pointers, never serialized. All callbacks receive the same memory aliases:

   | Hook | Required original boundary |
   |---|---|
   | `setupLevel` | Call `P_SetupLevel(c, episode, map, 0, skill)` using `c.state` parameters; complete all setup synchronously or revert. Refresh `c.map == c.state.map` and resource/zone aliases as required by the existing setup implementation. Do not return a pending resource request as successful setup. |
   | `checkHeap` | Original `Z_CheckHeap` at the post-setup boundary, with the selected zone policy |
   | `flatNumForName`, `textureNumForName` | Existing `R_Data` lookup functions; preserve call order |
   | `levelTicker` | `P_Tick.P_Ticker(c)` using the normal gameplay hooks |
   | `statusTicker`, `automapTicker`, `hudTicker` | ST, AM, HU tickers in this order, even if P_Ticker returns for pause/menu |
   | `automapStop` | Original `AM_Stop`, including clearing `f.automapactive` |
   | `intermissionStart`, `intermissionTicker` | WI boundaries; start consumes `f.wminfo`. When WI finishes, call `G_WorldDone`; the next outer tic handles loading. |
   | `finaleStart`, `finaleTicker` | F boundaries. Start must clear gameaction, set gamestate to GS_FINALE, and clear view/automap activity, as original F_StartFinale does. Presentation remains outside this goal. |

4. Feed existing held keyboard events into `f.keys`; pause keydown calls
   `G_RequestPause`. The new `G_BuildTiccmd(s, f)` overload consumes `sendpause`
   once and replaces buttons with `BT_SPECIAL | BTS_PAUSE`, retaining movement.
   Level setup clears held keys/sendpause. Do not reintroduce stale host-held
   keys after setup. The original packet ABI and `InputProtocol` reserved bits
   have not changed; the integration owner must select its explicit input route.
5. Build the command before `G_Ticker`, then increment `s.gametic` once after
   return, including paused/menu/intermission/finale tics. Commit state and any
   output event atomically. Do not also call the old `DoomGame.tick` in that tic.
   Death-use merely sets `PST_REBORN`; the following `G_Ticker` reloads and then
   runs the normal world ticker. Avoid an extra immediate restart in the adapter.
6. Use the existing exit helpers from gameplay. `G_DoCompleted` dispatch requires
   an initialized level; `G_WorldDone` / `G_DoWorldDone` require intermission.
   The loader receives E1M1..E1M9 selections, including E1M3→E1M9→E1M4.
   This goal supplies selection/lifecycle, not multi-map resource availability.

No new shared state interface was required to verify this work. Production
storage/UI wiring is the integration owner's responsibility under the user's
ownership boundary. The test host proves serializability and transaction
rollback; it is not installed as a production endpoint.

## Supported domain and exclusions

Single player, consoleplayer 0, ticdup=1, Episode One, shareware/registered/retail,
original skills 0..4 (high values clamp as C does), current map 1..9. New-game
map/episode clamps run before enforcing the Episode One scope. Negative skill
is rejected rather than entering original undefined downstream shift behavior.
Network/deathmatch/demos, other episodes/commercial dispatch, save buttons and
save/demo/screenshot actions fail explicitly instead of being silently ignored.
The pre-existing exit helper retains its broader original compatibility.

Startup without successful initialization, completion outside a level,
world-done outside intermission, invalid next-map values, unsupported actions
and unsuccessful setup revert. Original defined transitions keep their order;
these adapter domain guards prevent publishing incomplete state. Callbacks are
trusted integration bindings, not caller-supplied external addresses.

Sound calls, wall-clock `I_GetTime`/benchmark starttime, mouse/joystick/chat driver,
network consistency, external `statcopy`, saves, demos, multi-map resource
loading, intermission/finale graphics and browser UI work are excluded.
No replacement save/demo/sound implementation or new pixel transport is added.
The inherited keyboard builder and all inherited M3 fixtures are preserved.

## Focused verification

- 219 isolated cases compare original C against Solidity, including complete
  player/global/intermission snapshots, mutable difficulty definitions and
  boundary call order. O0, O2 and ASan/UBSan outputs agree without `-fwrapv` or
  sanitizer exclusions except disabling leak detection for the host run.
  Native setup, UI and thinker boundary doubles are declared in `host.c`;
  original P_Ticker, P_DeathThink and P_CalcHeight are also extracted verbatim.
- Dedicated unit tests cover pause production, memory-copy behavior and source
  vectors. Transaction tests persist deferred requests, pause, difficulty data,
  intermission and finale between external calls, and verify unchanged committed
  state/counters after rejected actions and setup failures.
- The E1M1 test uses the unchanged DoomGame/P_Setup/P_Tick/P_Inter implementation
  and authentic pinned resources. Full DSG1 setup and first-tic states equal the
  accepted native idle fixtures. It then exercises pause/resume, damage-induced
  death, next-tic restart and level completion. Later sequence assertions prove
  integration invariants, not a new full native trace or pixel comparison.
- 14 inherited input tests / 41,007 native keyboard vectors run unchanged.
  No entire inherited suite, browser acceptance, multi-map load or later goal is run.

Reproduce from a configured worktree with the existing pinned compiler and WAD
chunks available under `artifacts/local/wad/phase2-chunks/`:

```sh
python3 tools/reference/gameflow/reference.py --check
python3 tools/reference/gameflow/snapshot.py --check
python3 tools/reference/gameflow/legacy.py --check
python3 tools/reference/phase3_input/reference.py --check
.toolchain/bin/forge test --match-path 'test/{unit/Gameflow*,unit/g_game,integration/GameflowE1M1}.t.sol' --skip GameplayProbe --skip RendererProbe --skip WadResourcesProbe --skip Doom.sol --skip DoomRenderer.t.sol -vv
python3 tools/reference/gameflow/checkpoint.py --check
```

`legacy.py` copies only the accepted observation serializer and extracts the
first two accepted native states into new fixtures, recording their source
hashes; it does not regenerate or edit any inherited fixture. `snapshot.py`
generates observation serializers from a field schema, never expected results.
The pinned 10-billion gas test envelope is unchanged. Test gas includes setup,
fixture decoding and many cases in a single call; it is not production gas.

Evidence is in `artifacts/phase4/gameflow-verification.json`. Stop after Goal 4.6;
no merge into main and no later Phase 4 implementation is part of this work.
