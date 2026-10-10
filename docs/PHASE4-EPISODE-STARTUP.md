# Goal 4.13a — Episode Runtime Foundation

## Scope, baseline and ownership

Baseline `9f7d09120a1a250fe38f85b4f4bcba6cc78b5117`; branch
`feat/phase4-episode-startup`; owned worktree `/private/tmp/doom-evm-episode-startup`.
Measured start: `2026-10-10 12:32:03 UTC`. Only this feature worktree and new
goal-specific runtime/support/test/reference/report files are owned.

Implement authenticated, synchronous Episode One startup from episode/map
identifiers using the original resource directory, P_SetupLevel, gameplay hooks
and native zone allocation chronology. Verify E1M2 against genuine pinned
original C and ordinary EVM transactions; extend map coverage where practical.
No progression, transitions, presentation, browser, cheats, automap or intermission.
Do not edit Doom.sol, DoomGame.sol, DoomUI.sol or shared state interfaces. Stop
after verified feature commits and the production integration handoff. No main
integration or push is authorized.

## Reconciliation with Goal 4.11

Goal 4.11 adds persistent UIState and authenticated borrowed ST/HU graphics,
view sizes10/11 and palette events, while retaining the legacy startup path.
It does not add Gameflow persistence or multi-map setup. DoomGame.load remains
usable to bind the existing gameplay callbacks without loading an E1M1 world.
The foundation will return GameContext/GameflowState and mutable definitions;
future integration owns their atomic persistence and ST/HU spawn lifecycle.
Previous discovery decisions remain: one shared authenticated WAD, original
marker-relative lookup, synchronous setup, persistent native allocation semantics,
explicit deterministic initial-zone policy, and no host world/state injection.

## Dependencies, verification gates and stop condition

- Pinned original C `a77dfb96cb91780ca334d0d4cfd86957558007e0`; use the existing
  clean source read-only through a local symlink. Borrow pinned toolchain binaries;
  keep generated files and copied WAD resources inside this worktree.
- Existing full resource identity, geometry/setup, original gameplay and zone
  libraries; Solc 0.8.37/viaIR/optimizer200/Cancun; existing 10B execution budget.
- Focused resource/selection/setup and allocator tests, original-C O0/O2/sanitizer
  startup snapshots, actual ordinary CREATE/startup, identity and rollback proofs.
- Isolated planned Anvil port18713; refuse occupied ports and never use18880/8088.
- No complete inherited suite or browser acceptance. Native expected data is
  comparison-only and never supplied as engine startup input.

## Progress

| Checkpoint | Implementation | Integration | Verification | Next action |
|---|---|---|---|---|
| Foundation verification | Implemented in independent EpisodeStartup library | Production adapters and shared interfaces unchanged | 12 native startup profiles;16 setup/identity tests;21 allocator tests;69 resource tests;12 ordinary-EVM comparisons and12 rollback receipts pass | Acceptance handoff ready; stop after evidence commit |

Usage attribution: goal-tool counters are available; no monetary usage measurement
has been collected. End time, exact commits, commands, results, evidence hashes,
limits and remaining production hooks will be recorded at verified checkpoints.


## Delivered API and source correspondence

`EpisodeStartup.initialize(source, episode, map, skill, nomonsters,
 deterministicInitialization)` returns `(GameContext, GameflowState)`. Domain:
retail single-player, episode1, maps1..9, skills0..4. Selection is exact: invalid
identifiers reject before original menu clamping. This is a fresh-runtime
initializer, not a reload or transition API. No command, tic or Frame is consumed.

`EpisodeStartup.validate(source)` checks the complete v0 resource identity,
byte/chunk/directory dimensions, original ordered directory SHA256 and ordered
SHA256 of every STOP-prefixed chunk runtime. Claiming the correct identity tuple
is insufficient. Authentication runs before resource decoding or setup. The
constant identities duplicate the existing frozen WadResources values because
this goal may not change the shared adapter. Both authenticated boundaries are
exercised by the ordinary support host. The episode catalog remains v1 while the
resource identity remains v0.

| Original source / boundary | Foundation connection |
|---|---|
| R_Init/R_InitData and P_Init sprite/resource preparation | Existing DoomGame.load binds gameplay callbacks and decodes once; existing R_Things and DoomZoneStartup produce original physical startup allocations |
| R_InitData translation initialization | Restore fresh identity translation arrays from decoded texture/flat counts after DoomGame.load aliases the empty fresh state; no second resource decode |
| G_InitNew/G_DoLoadLevel | Existing G_Game functions, exact selection parameters, source sky-lookup order, RNG/difficulty mutations, rebirth, input clearing and live-player completion guard |
| P_SetupLevel supplemental wminfo globals | Setup callback sets maxfrags0 and partime180 before world setup |
| P_SetupLevel/P_Load*/P_GroupLines/P_LoadThings/P_SpawnSpecials | Existing unchanged source-mapped loaders, skill/type filtering, ordered actor/special spawning, thinker lists and collision links |
| Z_Init / Z_FreeTags / Z_CheckHeap | One 64 MiB zone, existing source-driven startup/setup ledger, original level-tag free and post-setup heap validation |
| I_ZoneBase | Preserved explicit deterministic initial-zero policy; strict policy remains selectable and produces equal logical startup/allocation results |
| ST_Start/HU_Start, sound and I_GetTime | Declared world-only UI/platform boundaries; production UI wiring remains outside this goal |

All original C translation units, source spans/hashes, LP64 pointer-array/disk
adaptations, compiler profile and observer hashes are in the new native manifest.
Original source and inherited fixtures were not modified. The accepted DSG1
serializer is copied into a separate support library; its world observation body
is preserved. Additional collision, flow, difficulty and zone serializers only
observe EVM-derived results. Expected native bytes never enter EpisodeStartup or
EpisodeStartupProbe.

## Production integration contract

1. Obtain the authenticated shared ResourceView and invoke this initializer once
   for initial gameplay. Persist returned GameState and GameflowState atomically.
   Retain the 13 demon-state tic values and three projectile speeds from
   GameContext.definitions; do not derive them from gameskill on later loads.
2. Rebind existing gameplay callbacks and all memory aliases on subsequent calls.
   Preserve map==state.map, move/path aliases, translations and nativeZone aliases.
   The foundation tests mutate the map alias and verify matching native results;
   ordinary receipts also reobserve actual persisted typed state.
3. Goal 4.11's DoomUI.initialize can consume the selected map context for initial
   UI startup using its accepted borrowed-graphics profile. This goal adds no UI
   callback/state ABI. Exact reload ST_Start/HU_Start lifecycles, Gameflow tick
   callbacks and presentation dispatch must be defined by the later integrator.
4. Leave production authorization, input sequence, frame counters and palette
   events with Doom.sol. This support host has only one-shot startup/status and
   deliberate test-only rejection routes; it is not a production endpoint.
5. Do not invoke this fresh initializer on a live player to implement progression:
   that would recreate the zone and inventory. Future transitions need a separate
   prepared-context setup hook preserving original player/global/cache history.
   No transition is implemented or accepted here.
6. Production adapters Doom.sol, DoomGame.sol and DoomUI.sol, all src/doom files,
   browser files and shared Phase4 ledger remain byte-identical to the baseline.

## Verification and measured scope

- Original native O0/O2/ASan+UBSan: all nine medium-skill maps plus E1M2 baby,
  nightmare and no-monsters,12 cases. The --check rebuild reproduces every new
  fixture. Initial run 22.104s; reproducibility run 21.431s (whole command elapsed).
- Native profiles use the existing pinned -fwrapv/LP64 policy and initial calloc
  zone, with no per-allocation fill. This proves this initialization profile,
  not arbitrary heap fills, universally defined ISO C behavior or future stale
  memory/render samples. Sanitizer output is empty for all startup runs.
- 16 focused Forge tests pass: all native cases, E1M2 strict policy, exact invalid
  selections, identity/directory/chunk authentication and level-tag retention.
- 21 directly relevant inherited allocator/setup/backing/heap tests pass unchanged.
- 69 Node resource tests pass. The first Node attempt failed solely because the
  independent worktree lacked generated resource-oracle inputs. Its log is kept;
  existing resource reference.py --check generated those local inputs, then all
  tests passed. No expected fixture or assertion was changed.
- 12 fresh ordinary EVM startup transactions and actual persisted-state digests
  match five native observations each. The support host stores real GameState,
  GameflowState and difficulty values. All 1,755 ResourceStore CREATE runtime bytes
  are verified; native expected data is compared only by the external runner.
- 12 mined rejections prove whole-storage-root rollback and zero logs: non-driver,
  five invalid selections, identity/directory/runtime-order/missing-runtime faults,
  injected failure after successful setup/storage/event, and repeated startup.
- Anvil 1.8.5/Cancun, isolated port18713,10B gas budget,1GiB interpreter memory
  limit; owned process stopped. The sandbox socket denial is preserved separately
  and the authorized run proceeded with local-network permission.
- Focused build 58 files 38.85s; setup test compilation 91 files 100.22s; allocator
  compilation 95 files 108.29s. Solc 0.8.37/viaIR/optimizer200/Cancun unchanged.

| Map, medium skill | Ordinary support-host initialization gas |
|---|---:|
| E1M1 |2,385,103,843 |
| E1M2 |3,423,997,552 |
| E1M3 |3,179,331,576 |
| E1M4 |3,325,158,270 |
| E1M5 |2,405,931,774 |
| E1M6 |3,905,863,064 |
| E1M7 |6,087,177,788 |
| E1M8 |2,052,734,836 |
| E1M9 |3,097,307,861 |

Gas includes full foundation authentication, setup, comparison serialization,
real typed-state persistence and proof events. It is not Doom.sol startup or
frame cost. Resource deployment is cumulative over 1,755 transactions. No EVM
MSIZE/untouched-production memory peak, frame, browser, tick, map transition or
full inherited acceptance is claimed. E1M7 remains the largest demonstrated
startup; future transitions must measure retained allocator history separately.

Native coverage is the accepted DSG1 schema (active player, live actors/movers,
sectors/lines/sides/blocklinks, translations and registries), extended with all
BLOCKMAP words, raw REJECT, ordered grouped sector lines/sound origins/blockboxes,
map starts and scrollers, startup flow/difficulty, and all normalized live zone
headers/owners. It does not serialize every scratch global or unknown native
payload/padding/pointer byte. Existing nine-map resource proofs cover geometry
fields absent from DSG1; these resource tests also run unchanged.

## Reproduction

The worktree needs the pinned toolchain, original submodule/source and local WAD.
Do not reuse an occupied Anvil port. Commands use only this goal's own artifacts.

```sh
node tools/wad/episode-pack.ts pack artifacts/local/freedoom/freedoom1.wad artifacts/local/wad
python3 tools/reference/phase2_data/prepare_chunks.py
python3 tools/reference/episode/reference.py --check
python3 tools/reference/episode_startup/reference.py --check
node --test tools/wad/episode.test.ts tools/wad/wad.test.ts
.toolchain/bin/forge build src/support/EpisodeStartupProbe.sol src/evm/ResourceStore.sol --no-lint
.toolchain/bin/forge test --match-path test/integration/EpisodeStartup.t.sol --skip Doom.sol --skip GameplayProbe --skip RendererProbe --skip WadResourcesProbe --skip ProductionUI.t.sol --skip DoomRenderer.t.sol -vv
.toolchain/bin/forge test --match-path 'test/unit/{z_zone,z_zone_initialization,z_zone_backing,GameZoneHeap,p_zone_setup}.t.sol' --skip Doom.sol --skip GameplayProbe --skip RendererProbe --skip WadResourcesProbe --skip ProductionUI.t.sol --skip DoomRenderer.t.sol -vv
node tools/reference/episode_startup/evm.mjs --port 18713
```

Reproduction changes
receipt/timing metadata; preserve historical evidence and create a new report
with `--output` when rerunning.

## Remaining dependencies and stop condition

No startup blocker remains for the declared domain. Later goals own production
endpoint/state integration, input/Gameflow dispatch, UI/cheat/automap lifecycles,
intermission/finale, progression, reuse/restart runtime APIs, renderer/backing
coverage under new allocation histories, and final inherited/E2E acceptance.
The existing source limits and strict unknown-byte failures remain unchanged.
Stop after the feature commits and clean-tree handoff. No push or main integration.


Evidence: [ordinary EVM receipts](../artifacts/phase4/episode-startup/evm.json),
[native manifest](../test/fixtures/phase4_episode_startup/manifest.json), and the
[acceptance certificate](../artifacts/phase4/episode-startup/verification.json).
Source-bound logs are retained beside the certificate. The certificate checker
is `python3 tools/reference/episode_startup/checkpoint.py --check`.


## Verified handoff checkpoint

Implementation commit: `ff1ba3a648b494560a80ed03146da7198c89fcef` —
`✨ Add authenticated Episode One startup foundation`.

Verification/handoff checkpoint: `2026-10-10 12:56:36 UTC`, 24m33s after the
measured start. Goal-tool usage snapshot at that checkpoint: 150,487 attributed
tokens and 1,473 elapsed seconds. This is available tool attribution, not a
monetary estimate; publication of the evidence commit follows this checkpoint.

The evidence commit records the certificate and source-bound logs. Both feature
commits must be preserved when handing this branch to the integrator. No main
merge, push, production integration or later goal was performed.
