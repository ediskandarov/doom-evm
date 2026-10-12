# Canonical DOOM Save/Load discovery

Research authorized 2026-10-12 (local date); measured start 2026-10-11 20:03:42 UTC.
Owner/worktree: Save/Load, `feat/save-load`, `/Users/eduard/sandbox/doom-evm-save-load`.
Clean baseline: `01b09cdbc31e774b7da9937f3a9c67b3ad3d958b`.

Original DOOM behavior is the specification. Previous exact-snapshot acceptance
proves an extension, not canonical Save/Load. This investigation preserves that
implementation, all previous evidence/tests/goldens and pinned original C.
Scope: source review, controlled native lifecycle execution, comparison and design.
No production edits, no main integration/push, no expensive EVM experiments.

Verification gates: actual original G_SaveGame/G_BuildTiccmd/G_Ticker/
G_DoSaveGame/G_LoadGame/G_DoLoadGame/G_InitNew/G_DoLoadLevel plus p_saveg and
real map/gameplay/ST/HU/video functions; bounded authentic IWAD runs, declared
LP64/UI/platform adaptations, recorded phases and archive/continuation results.
Research tools/evidence are separate from existing runners and golden fixtures.
No network runtime is required. Stop after a source-faithful architecture
recommendation and wait for explicit architectural approval.

Status: research complete. Implementation/architecture approval remains pending.
The current Exact EVM Snapshot feature is preserved and must not be described
or integrated as canonical original DOOM Save/Load on the strength of its earlier
exact-replay acceptance. This report supersedes that acceptance criterion; it
does not erase or relabel the earlier measurements and tests.

## Recommendation

Implement the original G_* action lifecycle and all eight P_Saveg archive/
unarchive routines over a compact **semantic save record**, stored in six EVM
slots. Load into the **current** game context: run the existing G_InitNew /
G_DoLoadLevel / P_SetupLevel sequence, then unarchive players, world, actors and
specials in original order. Let the same G_Ticker continue with its already-built
command and normal ticker callbacks. Do not restore a saved GameState/UI/Input/
Episode root wholesale, rewind gametic, restore saved RNG or publish a saved
frame as the canonical load result.

Preserve the existing exact codec, tests and historical branch for debugging.
If it is exposed again, give it a separate explicitly noncanonical contract/API,
slot namespace, evidence scope and UI. It must not service F2/F3, original Save/
Load menus, canonical save slots or canonical acceptance. A dev-only probe is
preferable to adding debug endpoints to ordinary gameplay deployments.

Use the proven storage backend initially, with a different payload/schema.
The semantics must be settled before optimizing encoding/placement. Existing
immutable-data contracts remain a possible backend for the same canonical bytes;
they do not determine gameplay semantics. Measure the new codec and full load
path before choosing a final cost policy. No new canonical EVM cost is claimed
by this research.

## Executed reference and scope

[Native lifecycle evidence](../artifacts/save-load-canonical/native-lifecycle.json)
records **99 successful native runs**:11 cases ×3 authenticated IWADs ×O0/O2/
ASan+UBSan. All logical observations, allocator timeline hashes and captured
frame/palette hashes agree between profiles. The33 distinct game/case combinations
capture45 indexed frames and45 palettes per profile. These are finite first-map
references, not full-game acceptance or universal native-address equivalence.

The new research harness compiles actual original gameplay/map/allocator,
ST/HU/AM/video/renderer units and mechanically extracts20 G_* bodies plus original
M_ReadFile/M_WriteFile. It executes G_DoSaveGame and G_DoLoadGame, ordinary local
save files, G_BuildTiccmd, G_Ticker, G_InitNew and G_DoLoadLevel. Action wrappers
only record entry/exit around unchanged extracted bodies. Native commands fill
the original netcmds ring; the host increments gametic after G_Ticker, as
d_net.c does. Direct-action cases isolate restoration from the subsequent tic;
queued cases exercise the real save special and action dispatch.

The corpus covers movement during save/load, paused save, fractional world values,
player inventory/references, mixed actor/special ordering, stasis ceiling/platform,
fire flicker, button timer, RNG/UI restart, repeated loading,24-bit time wrap,
cross-skill Nightmare behavior, invalid-version direct/ticker paths, rebirth
overriding load, dead-player save behavior and a real filesystem write failure.
Assertions are in the new research runner; no existing test or fixture changed.

Native profile adaptations are explicit: inherited LP64 allocator alignment,
pointer-array/disk-layout fixes, initialized64 MiB zone, immutable borrowed UI
resources, numeric compiler profile, original variable patch-tail sanitizer
exception, generated archive PADSAVEP align8/uintptr_t, and acceptance of original
AM C89 implicit-int declarations. These affect platform representation; archive
algorithms and G_* control flow are retained. Original repository files are
unchanged. Binary DOS save compatibility is not claimed. Original raw save files
contain process pointers/padding and are not used as cross-process goldens.

Captured frames use original ST_Drawer/R_RenderPlayerView/HU_Drawer. **Full
D_Display and its wall-clock wipe loop were source-reviewed, not executed in
this harness.** Audio/music, multiplayer and demo paths are outside the controlled
profile. The tracer fixture observes the raw pointer without dereferencing it.
All adaptations, source spans/hashes and failed harness-building attempts are
retained; see [attempts](../artifacts/save-load-canonical/attempts.json) and
[evidence bindings](../artifacts/save-load-canonical/evidence.json).

## Complete source lifecycle

Pinned original sources are at `a77dfb96cb91780ca334d0d4cfd86957558007e0`.
Important spans: `m_menu.c:582` M_LoadSelect,`:631` M_DoSave;
`g_game.c:237` G_BuildTiccmd,`:445` G_DoLoadLevel,`:605` G_Ticker,
`:1192` G_LoadGame,`:1202` G_DoLoadGame,`:1260` G_SaveGame,
`:1270` G_DoSaveGame,`:1365` G_InitNew; all of p_saveg.c/.h;
`p_setup.c:584` P_SetupLevel; `d_main.c:1150` command-line load and
`d_net.c:745` ticker/outer-clock boundary. Exact extracted spans are in the evidence.

### Save

1. Original menus edit one of six descriptions; M_DoSave calls G_SaveGame and
   clears menus. G_SaveGame sets savegameslot, copies the description, and sets
   sendsave. It does not archive or set ga_savegame itself.
2. G_BuildTiccmd consumes sendsave and replaces the command's buttons with
   BT_SPECIAL | BTS_SAVEGAME | encoded slot. It retains built movement/turn fields.
3. G_Ticker handles previously queued actions first. Later it reads the command,
   recognizes BTS_SAVEGAME, supplies “NET GAME” if no description is present,
   and queues ga_savegame. It then runs the normal GS_LEVEL callbacks. Thus the
   world can advance before the archive is written. A paused P_Ticker returns,
   while outer gametic and ST/HU ticker state still progress.
4. At the following G_Ticker's action loop, G_DoSaveGame archives **before** that
   tick's command copy and gameplay callbacks. It uses screens[1]+0x4000, writes
   description24/version16/skill/episode/map/player flags/time3, then calls the
   four archive families and appends0x1d. It checks SAVEGAMESIZE after encoding,
   calls M_WriteFile, clears action/description, sets the player “game saved.”
   message and calls R_FillBackScreen. The rest of that G_Ticker still runs.

In the measured moving case, confirmation starts at gametic/leveltime5/5.
The special-button tic ends6/6 with ga_savegame pending. The next ticker writes
leveltime6 and ends7/7. The Exact implementation archives immediately at the
control transaction and does neither gameplay tic. That is a semantic difference,
not an unavoidable EVM adaptation.

### Load

1. M_LoadSelect constructs the slot filename, calls G_LoadGame and clears menus.
   G_LoadGame queues ga_loadgame; it does not restore immediately. The -loadgame
   startup path uses the same action and bypasses normal title/new-game startup.
2. G_Ticker processes reborn players **before** the action loop. Rebirth can
   overwrite a pending load/save with ga_loadlevel. This priority must remain.
3. G_DoLoadGame first clears gameaction, uses M_ReadFile to allocate/read a
   PU_STATIC buffer, skips the description and checks “version109”. A bad version
   returns without level reconstruction; original code leaves the read allocation
   unreleased on that return. G_Ticker can still run the ordinary current-game tic.
4. For a valid file it assigns header skill/episode/map/player flags **before**
   calling G_InitNew. G_InitNew resets both RNG indices, clears pause/demo/automap,
   adjusts difficulty according to current globals, marks players reborn and
   calls G_DoLoadLevel. This is not G_DoNewGame: unrelated launch flags are not
   comprehensively reset.
5. G_DoLoadLevel sets levelstarttic to **current gametic**, prepares sky/wipe
   state, calls P_SetupLevel, checks the heap and clears keyboard/axis/button
   state and sendpause/sendsave/paused. P_SetupLevel frees level-tagged memory,
   reloads authenticated geometry, temporarily spawns the base map's actors and
   specials, resets relevant world globals/queues and invokes player UI starts.
6. After base setup, load restores the three-byte leveltime, then unarchives
   players/world/thinkers/specials, checks0x1d, frees the read buffer, applies a
   pending current view-size change and calls R_FillBackScreen.
7. G_Ticker then copies the command that was built **before** the action, processes
   specials and executes P/ST/AM/HU tickers. The outer loop increments gametic.
   Clearing keyboard globals inside load does not erase that already-built command.
   The next display renders the newly loaded/ticked game; it does not read saved
   framebuffer bytes.

In the queued moving case, load starts at gametic11. The action returns with
saved leveltime6, unchanged gametic11, restarted ST clock0 and cleared keys.
The rest of the ticker applies the prebuilt forward25 command, ends leveltime7 /
gametic12 / ST clock1, and the next command sees cleared keys. The earlier
“load must not advance a tic” requirement conflicts with this lifecycle.

### Display and error boundaries

G_DoLoadLevel forces wipegamestate=-1 when reloading from GS_LEVEL. D_Display
detects the transition, captures the previous screen, draws the new world/UI and
performs the melt. That presentation consumes M_Random as well: the full-width
wipe initializer has320 random calls. It can affect following ST face randomness,
although P_Random's gameplay stream is separate. View preferences and display
history are current-process globals, not file state. This source conclusion must
be included in eventual combined gameplay/display acceptance.

The production live Episode/menu adapters currently store wipegamestate but do
not call wipe_StartScreen/wipe_ScreenWipe; the original f_wipe library and separate
video/reference tooling exist. Integration of the load-triggered display lifecycle
must be resolved with the Full Video owner. Cached-frame emission or silently
omitting the wipe/RNG effects is not proof of full original display fidelity.

Original invalid-marker/unknown-class/missing-file paths use I_Error, potentially
after mutations; malformed files are not safely bounded. M_WriteFile failure is
ignored and the success message is still set, which the native failed-write case
executes. EVM bounds/integrity validation, exceptions and atomic rollback are
defensive/platform adaptations. Do not imitate native buffer overruns or pretend
a reverted storage write succeeded. Version-mismatch no-op plus continued ticker
is a defined original path; treat any intentional outer-API rejection policy as
a declared difference rather than claiming it is original behavior.

## What is preserved, reconstructed, reset and carried

| State | Original behavior | Current Exact snapshot behavior / effect |
|---|---|---|
| Player/inventory/psprites | Copies active player structs; psprite states become indices. On load clears mo/message/attacker, fixes psprite states; actor pass assigns fresh mo. | Restores saved IDs/message/attacker directly. Health/ammo preservation overlaps, reference/message behavior does not. |
| Mutable sectors/lines/sides | Saves selected fields as signed16-bit words. Heights/offsets shift right16 before saving and left16 after load. Clears specialdata/soundtarget. | Restores full int32 precision and saved sound/special references. Fractional geometry and AI sound context differ. |
| Actors | Saves P_MobjThinker nodes in list order. Reallocates, copies values, fixes state/player/info, clears target, recomputes position/subsector/floor/ceiling and relinks. | Preserves arrays/IDs, targets, derived values and spatial links. AI/projectile ownership and collision iteration can differ. |
| Thinker/spatial ordering | Actors are reconstructed first, then recognized specials in a second pass; P_SetThingPosition insertion reconstructs sector/block lists. | Keeps original mixed thinker ordering and spatial chains. Original passes are not an exact graph restore. |
| Specials | Recognizes ceiling/door/floor/plat/flash/strobe/glow. Explicit NULL-function ceiling handling retains ceilings in stasis. NULL-function plats are skipped; T_FireFlicker is absent. | Preserves all kinds, including stasis plats and fire flickers. Their continued motion/lighting is an optional improvement, not canonical. |
| Buttons/other globals | Not archived. Setup clears button timers, item respawn queue and active lists; unarchive rebuilds supported active lists. Other globals can carry from current process. | Restores saved timers/queues/scratch/history. Pressed switch texture can remain after original timer loss; exact restore resumes its timer. |
| RNG | Not archived. Both streams reset by G_InitNew, then startup consumes P_Random; normal ST ticker/display may consume M_Random. | Restores saved indices. Deterministic continuation of the uninterrupted branch is a different specification. |
| Time/pause | Saves leveltime modulo2^24. Does not save/rewind gametic; resets pause, sets levelstarttic to load-time gametic and executes the rest of the load ticker. | Rewinds gametic/full leveltime, retains saved pause, emits cached frame without tick. Physics/timing/UI progression differs. |
| UI/automap | Base player spawn executes ST_Start/HU_Start; ST clock/face/palette reset, HUD visibility/text reinitialize and automap is deactivated. Not every static is zeroed. | Restores complete saved UI/automap. Saved messages, faces, map view and clocks return. |
| Input | Load clears device globals at G_DoLoadLevel; prebuilt current command still executes. turnheld/double-click globals are not comprehensively reset or archived. | Saves/restores GameInputState, normalizes held keys at the control boundary and executes no loaded command. |
| Options | showMessages/screenblocks/usegamma remain current; no file fields restore them. | Saved UI preferences and palette/gamma return, with menu mirrors synchronized to them. |
| Difficulty definitions | Not archived; G_InitNew runs on current globals after header skill assignment. Defined cross-skill quirks remain. | Saved fast tics/projectile speeds return, avoiding those original quirks. |
| Allocator/resources | Uses current process allocator/cache, read-buffer allocation, FreeTags/base spawning/unarchive allocations/free. Allocation history is not in the file or rewound. | Rewinds saved nativeZone/owners/history. Matching the old ledger is not original load chronology. |
| Renderer/frame | Rebuilds/draws according to current view/display history; no frame in file. | Restores all saved render history and cached pixels. The initial load frame itself differs. |

The exhaustive Player struct still matters: command fields, armor/cards/powers,
ammo/maxammo, weapons, counters, damage/bonus, view/bob, latches, frags, psprites
and didsecret are copied in C. Their subsequent load-ticker overwrites must happen
in source order. Original P_Saveg does not archive every GameState-like global;
absence from the file means **follow actual setup/current-global behavior**, not
“reset all missing fields” or “keep all saved fields.”

Measured rich Freedoom example: floor -10,485,637 becomes -10,485,760; side offset
3,473,864 becomes3,473,408. Saved RNG173/211 becomes59/0 after load; corresponding
startup P_Random indices are144 for Ultimate and73 for DOOM II. Pause1 becomes0,
targets/attacker/soundtarget clear, stasis ceiling survives, stasis plat/fire flicker
and button timer disappear. ST clock5 becomes0. HUD countdown140 remains the
**current** countdown despite HUD visibility clearing, and current turnheld37
survives rather than saved13 returning. Repeated load rebuilds again.

The cross-skill cases confirm a subtle source quirk. A Nightmare file saved with
S_SARG_RUN1 tics1 and troop-shot speed20*FRACUNIT, loaded from a medium game, has
saved skill4 but current tics2/speed10*FRACUNIT. Loading a medium file from a
Nightmare game leaves tics1/speed20 despite saved skill2. G_DoLoadGame assigns
gameskill before G_InitNew checks whether it is changing into/out of Nightmare.
Do not repair that ordering by invoking a convenient generic new-game function.

The reborn-load corpus shows G_DoReborn superseding ga_loadgame: no load action
runs, the current level reloads and health/ammo become100/50. The dead-save corpus
shows why priority matters: BTS_SAVEGAME uses the same low bit as BT_USE;
P_DeathThink sees it before live-player special-button clearing, marks reborn,
and the following tick replaces ga_savegame with ga_loadlevel. No file is written.
These cases are immediate Death/Respawn integration requirements.

## Allocator and pointer findings that prevent a simple normalization pass

M_ReadFile's temporary PU_STATIC allocation precedes G_InitNew. G_InitNew's
FreeTags and base spawns operate on the **load-time** zone and cache. Then
P_UnArchiveThinkers removes temporary actors through P_RemoveMobj, whose removal
is lazy, but calls P_InitThinkers before a P_RunThinkers free pass. Their blocks
remain allocated until a later level-tag cleanup. Temporary non-actor thinkers
are freed directly. Unarchived actors **and specials** use PU_LEVEL in C; ordinary
special spawning often uses PU_LEVSPEC. Reusing an ordinary special-spawn factory
that always chooses tag51 would therefore change native header bytes/history.

The native rich Freedoom case moves rover13,944,480 →14,512,760 after load and
15,081,040 after another load. Allocated block count grows5156 →5364 on the first
load, despite the same final live gameplay population. Allocation timeline hashes
agree across all native profiles. A canonical port must model these calls, tags,
orphan bodies and known-byte history under the declared memory profile. It must
not eagerly free temporary actors, reset the whole zone, or overwrite current
history with the saved exact ledger. Existing NativeZoneLayout/P_Heap/P_Zone_Setup
are useful primitives but their call/tag choices need a source-specific audit.

The file buffer's representation can be portable without claiming binary
compatibility. However, the modeled native buffer allocation size must not simply
be replaced by the shorter EVM payload length if allocator/backing fidelity is
claimed. Calculate the declared LP64 archive footprint from source record sizes,
class counts and alignment, while storing compact bytes separately. Written-body
provenance and freed-buffer history require an explicit backing design; decoded
resource caching is a different issue.

**mobj.tracer is not fixed up or cleared by p_saveg.** The controlled saved tracer
is non-NULL after native load but does not resolve to an actor in the live thinker
list in any of the three games. That does not prove every such pointer always
faults: it may point to an orphan body, reused storage or another allocation. The
probe does not dereference it. Homing missiles/arch-vile links and MAP30 brain
target globals need a separate raw-pointer/provenance audit before claiming
canonical coverage of those paths.

Necessary stable-index adaptation must not quietly preserve the saved live target
ID as a “fix.” Preferred investigation direction is a declared native-offset /
generation/provenance reference, resolved against the current native allocation
model when used; unsupported byte/type interpretations remain rejected like the
existing backing policy. If a portable safety policy clears or rejects these
references instead, name that restricted compatibility profile and get approval.
There is no universal source-defined portable behavior for stale process pointers.
This is an architectural decision/blocker, not evidence that exact live-reference
restoration is canonical.

## Proposed modules, interfaces and reuse

### Canonical data and algorithms

Port same-named G_SaveGame/G_LoadGame/G_DoSaveGame/G_DoLoadGame and all eight
P_Archive*/P_UnArchive* operations with source-shaped loops and class selection.
The semantic payload should contain description/version/profile wrapper;
skill/episode/map/player flags;24-bit leveltime; player records; quantized world
records; ordered actor records; ordered supported special records. Encode
nullable player/psprite/state/resource identities with explicit EVM indices.
Omit ignored pointer fields and process padding while retaining their required
clearing/reconstruction effects. Handle unfixed pointers through the approved
profile, not invented swizzling.

Do not archive RNG, allocator history, cached framebuffer, options, the whole
UI/Input/Episode root, immutable geometry or resource decodes as canonical save
state. Preserve current process globals through their original paths. Difficulty
mutations use current EpisodeRuntime state, then execute original G_InitNew's
ordering; saved EpisodeState.fastTics must not override that result.

Load must allocate/copy records without calling ordinary actor spawn functions
that consume RNG or run state actions. Reuse P_SetThingPosition, P_AddThinker,
active-list registration, resource/state identity tables and size constants at
the precise original steps. Clear temporary lists as the C code does. Rebind
existing GameContext map/scratch/resource/nativeZone aliases and hooks whenever
setup/unarchive replaces their roots; decoded geometry/assets remain authenticated
EVM resource work. Restore player UI only through the original temporary player
spawn path, before player unarchive, rather than restarting it again afterward.

### EVM I/O and action boundary

Reuse contract-local six-slot storage, metadata/empty-slot handling, driver and
input sequence validation, overwrite/revision bookkeeping and atomic storage
updates. Give canonical payloads a new explicit codec/version/model identity and
authenticated IWAD binding. Existing exact runtime-codehash compatibility is an
optional strict-upgrade policy, not an original requirement; decide it separately
from semantic archive version compatibility. Profile/resource binding is part of
this project's authenticated platform boundary, not a field original files have.

G_Game currently rejects load/save actions and BTS_SAVEGAME. GameflowState needs
the source's sendsave/slot/description/load request globals, and G_Ticker needs
I/O action hooks/results. A practical adapter keeps I/O storage ownership outside
original libraries: read immutable slot bytes into an ephemeral transfer context,
capture the semantic write bytes at G_DoSaveGame's source point, then flush the
**captured pre-tic archive** to storage when that same EVM transaction finishes.
Do not serialize the later post-tic world instead. Native read-buffer allocation
and interpretation happen only if the load action actually executes after reborn
priority; speculative slot reads must not mutate game/native state.

The physical end-of-transaction flush is invisible to successful gameplay because
no later ticker branch reads the file; EVM atomic rollback is declared for failures.
This permits memory/view hooks and avoids giving doom libraries arbitrary storage
access. Use a small explicit ephemeral I/O carrier, avoiding repeated full archive
copies through every UI callback's adapterData. Mutable slot revision and GameSaved
events update only when the write action runs, not when the menu queues a request.

Retain one ordinary G_Ticker per declared input tic. A save can therefore remain
pending between two transactions and across browser reload until the next ticker.
Do not force two ticks with duplicated input inside one confirmation transaction
just to make a receipt mean “already written.” The source can also supersede a
queued action. Authentication/metadata reads are side-effect-free; valid original
action timing is not replaced by immediate snapshot endpoints.

### Menu/display/client

Reuse the original six-slot patch/font/skull/text-entry implementation and existing
Options/SELECT LEVEL routes. Replace menu action dispatch to immediate _saveGame/
_loadGame with G_SaveGame/G_LoadGame requests entering EpisodeRuntime/G_Ticker.
Keep canonical Save/Load labels bound exclusively to that path. No HTML gameplay
save controls are needed. F6/F9 quicksave/quickload use the same original request
paths if their separately scoped menu support is authorized; -loadgame startup
also needs an equivalent adapter path for complete lifecycle coverage.

Audit the existing blanket menu/held-key clearing policy: it is an adapter choice,
not a source requirement. M_ClearMenus does not clear all game keys. Filtering
consumed menu events while allowing original unconsumed keyups, and building the
load tic command before G_DoLoadLevel clears keys, is required for the native
command-carry behavior. Save-description letters remain consumed by the original
entry responder. This is a shared input/menu interface decision; do not rewrite
the menu system to hide the mismatch.

Use the existing normal EVM draw/display path after the load ticker. Coordinate
wipe state/frames and miscellaneous RNG with Full Video. EVM's one-Frame-per-input
protocol and blockless wall-clock require an explicit presentation scheduling
adaptation for a multi-frame blocking native wipe. That needs design/approval;
source timing/RNG effects cannot be replaced by a saved frame and called faithful.

### Exact machinery reuse assessment

| Existing component | Reuse |
|---|---|
| Six-slot registry/storage/metadata/authentication | Reuse platform infrastructure with canonical payload and revised compatibility/timing contract. |
| Original menu graphics/editing/native25-frame fixtures | Reuse; change request dispatch and input action boundary, retain source graphics. |
| DoomGame context/alias/hooks, EpisodeRuntime setup/UI callbacks | Reuse current-context lifecycle; add canonical I/O hooks. |
| Z_Zone, NativeZoneLayout, P_Heap, map/spatial/thinker primitives | Reuse selectively with source allocation tags, order, orphan/provenance handling; do not reset/rewind the zone. |
| Exact bounded byte/storage walker and generated schema tooling | Useful for dev snapshots or a separately typed semantic record backend; rooted GameState unarchive is not a canonical load operation. |
| Exact whole-state snapshot as an internal temporary input | Technically could extract canonical fields, but expensive/unnecessary. It still must run current-context reconstruction and original timing; normalization after restoring saved roots is insufficient. |
| Precomputed “canonicalized exact snapshot” | Reject: current gametic, globals/UI counters, difficulty mutations, allocator/cache history and unfixed pointers depend on load-time context. One save-time result cannot capture original behavior for every load site. |
| Existing exact continuation tests/evidence | Preserve as explicit noncanonical/debug acceptance. They must not be weakened or silently relabeled canonical. New canonical tests compare the C **loaded branch**, not an uninterrupted exact-replay branch. |
| Prior gas/memory/native report | Retain as historical exact-backend measurements; use for backend comparisons only, not new canonical-load costs or fidelity. |

## Necessary adaptations versus optional improvements

Necessary/declared platform choices: EVM slots instead of filesystem paths; bounds
and validated identifiers instead of unsafe pointer copies; explicit native memory/
numeric profile; authenticated IWADs; atomic rollback; monotonic transport sequences;
resource reads/decodes in EVM; controlled display timing instead of OS wall-clock.
Original binary layout/alignment/process addresses/padding can change. The original
archive selection, quantization, reset/reconstruction behavior and G_Ticker/RNG
order cannot be upgraded merely because the new platform permits it.

Optional improvements that must stay separate or receive explicit noncanonical
approval: full-precision world save, saved RNG/gametic/UI/options, all-thinker
preservation, retained targets/tracers, timer/flicker/stasis-plat repairs, corrected
Nightmare-load behavior, saved-frame/no-tic load, eager orphan cleanup, portable
pointer fixes, automatic engine migration, richer descriptions and stricter-than-
semantic engine hashes. Exact snapshots are especially useful for debugging
determinism and allocator regressions; that usefulness does not make them original
Save/Load.

## Costs, change list and implementation checkpoints

Measured ordinary native file sizes in this declared LP64 profile are77,562 bytes
for Freedoom E1M1,32,770 for Ultimate E1M1 and18,923 for DOOM II MAP01. These are
not prospective EVM encoded sizes. The old exact production samples were928,064 /
461,888 /406,560 bytes. A semantic archive can omit immutable geometry, process
padding, ignored pointers and saved UI/history, but its actual size/gas must be
measured after porting. Source-faithful loading performs base setup and additional
allocations, so it can be **more expensive to load** than raw exact storage restore.
Do not estimate total load gas from payload size alone. Review large-map/double-
context memory risks and the read-buffer/orphan lifecycle before choosing limits.

Likely production changes, **not made in this research**:

* `src/doom/g_game.sol`: source save/load globals, request functions, action
  branches/special-button dispatch and I/O hook/result interface.
* `src/doom/p_saveg.sol`: canonical eight source-family operations; move/rename the
  exact rooted codec into an explicit dev/platform namespace if retained.
* `src/evm/DoomSave.sol`, new semantic record/codec/I/O carrier module: keep slot
  infrastructure, change payload/metadata/version semantics and write timing.
* `src/evm/EpisodeRuntime.sol`: wire current-context load/save callbacks and
  original auxiliary/UI/order behavior without fresh R_Init/zone construction.
* `src/evm/Doom.sol`, `Doom2.sol`, `DoomMenu.sol`, `src/doom/m_menu.sol`: queue source
  requests, key/event boundary and normal post-load display, not immediate restore.
* `src/doom/p_heap.sol`, native layout/backing helpers if needed: explicit
  unarchive PU_LEVEL allocations, archive read-buffer/history, orphan bodies and
  approved unfixed-pointer provenance. Preserve defaults and all memory profiles.
* Display adapter/input/client integration if necessary for wipe scheduling;
  generated SaveSchema/release pins when shared types/artifacts change.
* Add separate canonical native/Forge/Node/Anvil/Chrome tests and reports; preserve
  previous exact tests as a named debug corpus. No existing golden is changed to
  make a new port pass.

Proposed small checkpoints after approval:

1. Freeze canonical source/format/profile contracts, including unfixed pointers,
   memory buffer footprint, menu command timing and display/wipe scope with owners.
2. Port player/world/actor/special codecs and source-shaped unarchive; prove
   quantization/class selection/order/clearing against native action boundaries.
   Measure compact storage versus immutable data using the actual new payload.
3. Connect G_SaveGame/G_LoadGame/G_BuildTiccmd/G_Ticker and read/write carrier.
   Prove save pre-tic capture, load command-carry, clocks, RNG, UI and invalid-version
   behavior; verify allocator chronology including orphan/tag differences.
4. Reuse menus and integrate display/wipe policy. Run native **save/load followed
   by continuation** against EVM on all three IWADs, including combat/projectiles/
   movers/inventory, cross-map and cross-skill cases. Add approved pointer-domain
   cases and source-defined omissions; do not require uninterrupted replay equality.
5. Reconcile Death/Respawn's shared interfaces with the integrator. Test reborn
   load priority, dead save cancellation, corpse/lazy-removal and deferred actions.
6. Measure full save/load gas/memory/time/storage; verify actual Chrome persistence,
   menu controls and IWAD isolation. Preserve existing Options/SELECT LEVEL and
   profile defaults. Commit/handoff the approved canonical feature separately.

## Approval decisions and remaining limits

Approve the semantic archive + original current-context G_Ticker lifecycle, and
separate the exact codec as dev-only/noncanonical. Before implementation, settle:

* Raw tracer and other unswizzled/global pointer domains: model supported native
  offset/provenance behavior or explicitly approve a restricted safety profile.
  Silently making saved references valid is not the recommended canonical behavior.
* Original load-triggered display/wipe and misc RNG integration with Full Video,
  within the frozen one-Frame protocol and local execution/memory budget.
* Version-error/API rejection policy and semantic upgrade compatibility, rather
  than automatically inheriting the exact engine-codehash gate.
* Shared GameflowState/IO-hook/key-event interfaces and Death/Respawn reconciliation.

Native coverage is finite. Not all special subtypes, maps, homing/arch-vile/brain
pointer cases or full D_Display loops were executed. They remain explicit future
acceptance work, not silently assumed passed. No canonical EVM code or costs were
produced. No existing implementation/test/evidence was discarded or weakened.

Reproduce the native reference and compact publication:

```sh
python3 tools/reference/save_load_research/lifecycle.py --output artifacts/local/save-load-canonical/reproduction
python3 tools/reference/save_load_research/publish.py --run artifacts/local/save-load-canonical/reproduction
```

The default input paths refer only to this worktree's authenticated local IWAD
copies. Raw logs/generated sources/native files/frames remain in ignored
`artifacts/local/save-load-canonical`; the published report contains hashes and
logical observations, no commercial image/WAD/save payloads. No Anvil, browser,
network service, main worktree write, merge or push was used for this research.
Scope preservation is bound in [scope.json](../artifacts/save-load-canonical/scope.json).
Measured final native gate:2026-10-11 20:25:23–20:25:41 UTC. Report/scope check:
20:48:18 UTC. At the latter checkpoint the goal tool attributed217,002 tokens
and2,675 elapsed seconds; these are tool counters at that timestamp, not estimated
billing or model-specific attribution. All native children finished; no persistent
runtime was started. The final response records the research commit SHA.
Stop here and wait for architectural approval.
