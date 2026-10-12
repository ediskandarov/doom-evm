# EVM Save/Load goal

Six contract-local save slots are implemented in the existing EVM menu for
Freedoom 0.13.0, Ultimate DOOM 1.9 Episode One and DOOM II 1.9. Save and load
use the authoritative EVM state. Loading publishes its saved framebuffer and
palette without running a game tic or renderer. The feature is ready for the
designated integrator after the focused verification recorded below; it has
not been integrated into main.

Implementation authorized 2026-10-11; goal start 17:40:46 UTC.
Owner: Save/Load agent, `feat/save-load`, dedicated worktree
`/Users/eduard/sandbox/doom-evm-save-load`.
Baseline: fetched `origin/main` at `ff826659ceff0b3a5637e70109b62eb75a83d611`,
already contained by this clean branch. No main writes or Death/Respawn integration.

## Scope and retained discovery

Implement six original-style EVM save slots for Freedoom 0.13.0, Ultimate DOOM
Episode One, and DOOM II 1.9; save/load/overwrite/metadata/rejection, existing EVM
menu integration, exact restoration and focused native/EVM/browser proofs.
No audio, multiplayer, Relaxed Rendering, Solidity-default change or complete
historical acceptance. Stop after verified feature commits and handoff.

Discovery inspected `411e6049` and pinned C `a77dfb96cb91780ca334d0d4cfd86957558007e0`.
It found four authoritative roots (`GameState`, `UIState`, `InputRuntimeState`,
`EpisodeState`), explicit aliases reconstructed by DoomGame.load, and persistent
allocator history/render scratch. DSG1 and current-ring zone observations are
not complete restoration formats. Original C saves are lossy (RNG reset,
target/message clearing, short world coordinates, separate actor/special passes).
The proposed exact EVM continuation is an explicit archive/transaction adaptation,
not binary compatibility or equivalence to those original information losses.

Full Video/Options review at the new baseline: UIState now includes hideMessages;
MenuState owns Options preferences and SELECT LEVEL. Production display paths can
mutate rendering history without a gameplay tic. Current renderFrame still ticks;
load must use a separate control boundary. Immutable graphics/resource decodes
remain transient. Preserve existing schema, all allocator records/payloadExtent,
IDs/tombstones, array capacities, RNG, difficulty and rendering histories.

## Architecture gate

Measure actual initialized EVM state before selecting between typed slots,
ABI-byte slots, packed schema-bound slots and immutable code chunks. The discovery
preferred compact local slots provisionally. A storage-schema traversal is another
candidate: archive every word reachable from the four roots, without serializing
ephemeral GameContext/resources or unrelated transport/menu/resource storage.
Schema generated from pinned compiler storageLayout; no host gameplay injection.
No per-gameplay-tic snapshot copies. Compare size, save/restore gas, storage words,
memory high-water and wall time. Selection is complete: packed local slots. Actual authentic E1M1 archive859,296 bytes versus ABI5,639,104; fresh packed save584,309,294gas, overwrite129,653,992, restore123,304,814. Typed copies616,928,015/162,292,609/162,297,768; immutable chunks246,943,470/246,906,470/64,952,649. Immutable wins first-save and load cost; packed wins recurring overwrites and bounds retained slot storage instead of accumulating53 contracts per save. No full root decode on archive/restore. Pre-format measurement artifact retained; final production measurements remain pending.

## Shared interfaces and verification gates

This branch needs changes to Doom/Doom2 menu control boundaries and M_Menu; these
are authorized feature changes for later integrator reconciliation. Death/Respawn
owns its independent worktree. Avoid EpisodeRuntime/G_Ticker gameplay changes
where possible; any overlap must be documented, never independently merged.
Menu APIs must preserve Options, SELECT LEVEL, existing Frame/input protocols,
authenticated WAD identity and explicit browser profile3. Input/frame counters
must remain monotonic on load.

Gates: pinned-C save/menu investigation and focused source-preserving oracle;
schema coverage/round-trip/invalid/rollback Forge tests; affected Node input/menu/
release tests; actual isolated Anvil measurements and deterministic continuation
for movement/combat/movers/AI/projectiles/inventory/RNG/cross-map/repeated cycles;
real Chrome save/continue/load/continue/reload/game-switch/IWAD-isolation proof.
Reserved ports18880/8088 remain untouched. Track and stop only owned children.

Historical checkpoint before final production verification: codec and registry module verified; production/menu integration implemented, with verification then pending. Integration: feature branch only.

Focused codec/registry tests:9 passed (3 inherited codec methods also execute in the registry subclass;6 distinct cases). Historical menu/Options/commercial navigation:13 unchanged tests passed. Pinned schema:133 nodes, identical root type graphs in Doom/Doom2. Native archive O0/O2/ASan+UBSan pass with declared align8 archive adaptation; pristine align4 LP64 UBSan failure is retained, not relabeled passed. Original six-slot native menu:25 frame checkpoints agree across3 profiles; EVM pixel comparison is pending.
All measured evidence and failures are retained separately under
`artifacts/save-load/` (published metadata) and `artifacts/local/save-load/`
(ignored raw resources, frames and logs). No commercial assets in commits.

## Final architecture and original-C contract

`Doom`/`Doom2` own storage. Their ordinary call boundary reads `gameState` into
memory, `DoomGame.load` creates a fresh resource/definition context and binds
aliases/hooks, EpisodeRuntime executes the original gameflow/UI/gameplay, and
the adapters store the four updated roots. There is no separate
`DoomGame.store` function: `_saveEpisode` and the other adapter assignments perform
that storage step. Neither the compact DSG1 observation nor a current allocator
ring is a complete save representation.

The save codec traverses the **actual pinned-solc storage layout** of the four
roots. It copies each fixed word and each reachable dynamic payload once in a
deterministic order. A count pass bounds allocation before encoding. Arrays
include their full stored lengths, capacities and unused/tombstone records,
not merely active counts. Packed scalars remain packed; bytes remain bytes.
The generated 133-node schema checks both production adapters' type graphs.
Root slots come from typed storage references, so MenuState expansion or
adapter-specific root locations are not hardcoded into the codec.

`DoomSave` stores the resulting bytes, SHA-256 digest, description and metadata
in six `SaveSlot` entries appended to the existing contract storage. It performs
no gameplay/resource decode. Load copies one archive into memory, validates its
binding/digest, restores the roots, and checks redundant map/skill/time metadata.
The transaction either completes or rolls back every root, slot, counter and log.
There is no archive copy on ordinary gameplay tics; menu packets read only six
small descriptions/compatibility flags/revisions.

Pinned C sources reviewed are `g_game.c:1192` onward, all of `p_saveg.c` and
`p_saveg.h`, and the save/load definitions, drawing and responders in `m_menu.c`.
Source hashes and extracted function spans are retained in
[native-archive.json](../artifacts/save-load/native-archive.json) and the
[menu manifest](../test/fixtures/save_menu/manifest.json).

Original `G_SaveGame` queues slot/description through `sendsave`; the ticcmd's
save special eventually dispatches `G_DoSaveGame`. `G_LoadGame` queues a filename
and `ga_loadgame`. The file has a 24-byte description, 16-byte version string,
skill/episode/map/player flags, three-byte level time, player/world/thinker/special
archives and a `0x1d` consistency marker. Loading calls `G_InitNew` to create a
base level and then unarchives modifications. Original six-slot navigation,
empty-slot handling, skull positions, borders, text entry, uppercasing,
Backspace/Escape/Enter, and F2/F3 remain the user-facing model.

Literal original binary serialization would fail the requested exact continuation:
world heights and offsets lose their fractional bits; player message/attacker,
actor targets and sector sound targets are cleared; actors are allocated afresh;
actor and special thinkers are restored in separate passes; `G_InitNew` resets
RNG rather than restoring its progression; native allocation chronology is lost.
The native archive gate demonstrates fractional-floor truncation and cleared
references. It executes original archive/unarchive and original request queuing;
it **does not execute the full G_DoLoadGame action**. That action was source-reviewed.

The EVM archive is an explicit representation/control-boundary adaptation, not
a literal port of the eight C binary archive routines. It retains the save/load
concept, original menu behavior and all four state families, while extending the
archive to exact EVM continuation. No original binary compatibility is claimed.
The EVM save transaction does not inject the original `GGSAVED` player message,
restart the level, truncate coordinates, reset RNG or recreate actors. Save/load
are handled before EpisodeRuntime.tick. This also removes the queued-save extra
tic from the EVM control boundary, as required by the requested no-tic restore.

## Architecture alternatives and measured selection

All candidates used the same authentic EVM-initialized Freedoom E1M1 world,
ordinary CREATE and the same 10-billion-gas local budget. Every candidate restored
the full packed root digest after health/RNG/floor divergence. The initial world
had no completed cached gameplay framebuffer; these architecture measurements
are distinct from the final production measurements below. The precise measured
artifact is preserved as `artifacts/save-load/SaveCostProbe-artifact.json.gz`.

| Candidate | Encoded bytes | Fresh save gas | Overwrite gas | Restore gas |
|---|---:|---:|---:|---:|
| Independent typed storage roots | No byte archive | 616,928,015 | 162,292,609 | 162,297,768 |
| ABI bytes in slot storage | 5,639,104 | 3,173,637,247 | 711,748,545 | 777,811,976 |
| Packed schema words in slot storage | 859,296 | 584,309,294 | 129,653,992 | 123,304,814 |
| Packed immutable data contracts, 16 KiB chunks | 859,296 | 246,943,470 | 246,906,470 | 64,952,649 |

The selected packed slots save ABI padding and avoid decoding/re-encoding a
full memory world. Their recurring overwrite cost is substantially lower than
allocating another immutable archive. Immutable chunks are a credible alternative
for predominantly new saves or frequent loads: they measured cheaper for first
save and load. However, each overwrite would leave another 53 immutable contracts
in this sample, requiring a chunk registry, deployment assembly and chunk integrity
checks. Their accumulated retained data is not bounded by six slot payloads.

A dedicated snapshot contract using storage does not avoid SSTORE costs. It adds
deployment/cross-contract interfaces, ownership and atomic read/restore concerns;
the typed-copy result is a useful storage-cost comparator, not a measurement of
that additional contract overhead. Versioned/delta authoritative worlds would
change the ordinary tick store path and create replay/materialization complexity.
A semantic compact archive could omit resource-derived geometry but must prove
reconstructed allocations, aliases and histories equivalent. These alternatives
were considered and not implemented; their unmeasured overhead is not presented
as a measurement. The selected design favors exact reuse of the existing state
model and bounded overwrite behavior. It does not claim every stored field is
theoretically minimal.

## Required state inventory and restoration

The exhaustive executable topology is
[schema.json](../artifacts/save-load/schema.json); declarations remain unchanged
in `p_game_state.sol`, `DoomUI.sol`, `InputProtocol.sol` and `EpisodeRuntime.sol`.
The fixed root spans are 469, 84, 72 and 28 storage words respectively, followed
by every dynamic descendant. The inventory was verified by storage traversal and
value/digest comparisons, not inferred from root type names.

| State | Preserved values and reason |
|---|---|
| Player/input | All four player records/participation flags; position reference, health/armor, cards/powers/weapons/ammo, psprites, damage/bonus counters, attacker/message, command and attack/use/refire latches; original GameInputState including turn progression. |
| Actors/thinkers | Complete actor and thinker arrays, active counts, stable IDs, allocation flags/tombstones, cap and prev/next links, kind/payload/action state, target/player/spatial references; all ordering is retained without reconstruction or ID renumbering. |
| World | Map vertices/lines/sides/sectors/BSP/seg data, mutable flags/textures/heights/light, GameSector thing lists and sound targets, sector/line specialdata and validcounts, blockmap links and REJECT bytes. |
| Specials | Doors, floors, ceilings, plats, lighting thinkers and counts; active ceiling/platform arrays including stasis; buttons/timers, animations/translations/scrollers/switches; level timer, item-respawn queues and starts; brain targets and progression. |
| RNG/gameflow | Both RNG indices, gametic/leveltime, mode/skill/episode/map, pause/actions/player flags/totals/secret exits, flow/deferred selection/WI-start data, automap and cheat parser progress. |
| UI/episode | Complete persistent ST/HU state, clocks/face/message/palette/gamma, fullscreen/messages preferences; WI/finale globals, difficulty-mutated fast tics/projectile speeds and displayed game state. Settled GS_LEVEL saves can therefore resume later gameflow. |
| Allocator/provenance | Zone size/rover/count, all block records including retired history and `payloadExtent`, ownerBlocks, nativeMapBlocks and nativePayloadBlocks; initialization/high-byte/virtual-pointer policy bits. The archive preserves the existing known-byte model; it does not invent unknown native pointer/padding bytes or claim to dump native RAM. |
| Historical engine globals | Movement/path scratch, wall/plane caches, fuzz/frame counts and complete indexed framebuffer. These already survive ordinary transactions and cannot safely be dropped just because their names suggest scratch data. |

`GameContext.map`, `.move`, `.path`, resource translations and `.nativeZone`
are memory aliases of restored roots. The next ordinary DoomGame.load rebinds
them and original callbacks. Lazy texture/flat/sprite/font decodes, borrowed
patches, render callback pointers, GameDefinitions' source constants and ephemeral
`adapterData`/EpisodeAux remain reconstructed per call. They are not added to the
archive. Resource identity and semantic allocator owner IDs ensure that these
decodes refer to the same authenticated resources. Episode difficulty mutations
are restored separately through the existing EpisodeRuntime logic.

Menu navigation, immutable font metrics, archive registry, driver, authenticated
WAD contracts/directory and transport counters are outside the four roots.
Saving/loading closes the menu and clears held keyboard-device keys. Saved player
commands and gameplay latches remain intact. UI Options are restored and the
menu's preference mirrors are synchronized to them. `inputSeq` and `frameId`
advance monotonically for the new control transaction; gameplay/UI clocks are
restored, not advanced. The cached EVM framebuffer/palette is emitted immediately.

## Integrity, isolation and rollback

The write APIs are driver-only, require the existing Episode/menu/raw-input
deployment and the next uint32 input sequence, and use an expected uint64 slot
revision. Six slots are numbered 0–5. Revision 0 means empty. Overwrite atomically
increments one slot revision. A stale overwrite/load cannot silently use different
metadata. Driver/sequence/range/empty/revision failures preserve storage and emit
no logs.

Every slot is bound to the schema descriptor hash, **exact deployed runtime
codehash**, complete authenticated ResourceIdentity (schema version, WAD/bundle/
palette hashes and palette variant), and explicit selected memory profile.
Engine hashes also reject same-size static-field semantic/schema changes that a
topology-only descriptor might not distinguish. Runtime hashes include immutable
deployment bindings. This is strict compatibility, with no automatic migration
across engine upgrades or cross-contract save import. Saves remain in the same
installed game contract across browser reload; separate authenticated game
contracts own separate namespaces. A reset Anvil loses them unless separately
backed up. Browser installation journals only identify deployments; they do not
contain gameplay saves. No localStorage or Anvil dumpState save mechanism was added.

Save requires initialized single-player usergame, settled GS_LEVEL with no pending
gameaction, a 64,000-byte cached framebuffer and, when UI is enabled, a 768-byte
palette. Demos/netgame/deathmatch and intermission/finale/pending-transition saves
are rejected. Load may restore a compatible slot from a different current map or
the menu title/end-game boundary; it does not require the level to remain active.
The normal adapter is the only production archive writer. There is no untrusted
payload import, pointer graph rebuild or arbitrary raw-storage write API.
Digest checks, bounded traversal, length/alignment checks and redundant metadata
reject corrupt, truncated, trailing, oversized or incompatible archives.

Raw restore intentionally does not sweep old dynamic payload locations that fall
outside restored array/byte lengths. Those words become unreachable. Subsequent
ordinary memory-to-storage state assignments write complete reachable values;
grow/shrink/short-long-byte cycles were tested. This preserves logical exactness
but can retain a physical storage high-water mark. The report counts reachable
words, not trie/database disk bytes, and does not claim storage compaction.
If future code directly mutates/pushes these storage arrays instead of the existing
complete state assignment, this assumption needs review.

## Production costs, memory and limits

These are measured first-map profile3 snapshots after real movement and inventory
changes in Chrome. Gas includes the saving/loading transaction and cached Frame/
palette emission, excluding earlier menu-navigation packets. Cross-map loads are
included in the load range.

| Authenticated game | Snapshot bytes | Payload words | Fresh save gas range | Overwrite gas range | Load gas range |
|---|---:|---:|---:|---:|---:|
| Freedoom E1M1 | 928,064 | 29,002 | 654,276,743–654,421,109 | 156,657,816–156,667,809 | 146,424,212–192,713,652 |
| Ultimate DOOM E1M1 | 461,888 | 14,434 | 312,234,886–312,280,683 | 78,468,457–78,478,189 | 74,953,986–92,905,981 |
| DOOM II MAP01 | 406,560 | 12,705 | 296,478,814–296,533,067 | 71,924,171–71,932,618 | 66,538,753–83,757,720 |

Each occupied slot adds eight header words (including short description and data
heads) to its payload words. Six equal-sized Freedoom samples would occupy
174,060 reachable slot words, or 5,569,920 logical storage bytes; this is a
projection from measured size, not a six-slot full-game trie measurement.
The codec caps each payload at 262,144 words/8 MiB. Six maximum payloads would
retain 48 MiB plus headers, also a projection. Geometry, retained capacities and
historical allocator records mean archives can grow over long play/level changes.

The production observation gate compared unmodified Doom, an observer-only clone
and a source-mapped GAS→MSIZE clone, all deployed ordinarily. GAS and MSIZE have
equal opcode cost/stack effect; the two clones had identical transaction gas.
Their state projections, full root digests, indexed Frames and palettes matched
unmodified production. The measured Freedoom sample had:

| Operation | Production gas | Local RPC/mining seconds | Call-frame memory boundary |
|---|---:|---:|---:|
| Save | 654,020,187 | 0.108083 | 2,325,024 bytes |
| Load | 146,140,798 | 0.106934 | 1,858,880 bytes |
| Overwrite | 156,363,797 | 0.107071 | 2,325,024 bytes |

Memory is MSIZE after the production save/load and Frame encoding, immediately
before the following observer encoding. Separate SHA-256 precompile frames and
host process RSS are not included. It is measured for Freedoom here; commercial
memory peaks are not inferred as measured. Native/EVM comparison adapters measured
approximately 1.86 MB for the same operation families. All final runs retained
Cancun, pinned compiler/viaIR/optimizer, 10B gas and 1 GiB managed-memory limits;
no limit increase was necessary for these snapshots.

These costs need the project's high-gas development EVM. A standard Ethereum
mainnet block cannot accommodate the measured save transactions. A worst-case
8 MiB archive's SSTORE work alone can be billions of gas; traversal, hashing,
memory expansion and UI work add to it. The format size cap is not a proof that
every possible long-running world fits 10B gas. Large-map and sustained-history
cost ceilings remain a future performance gate. A complete typed/ABI decode can
also multiply memory and gas; the selected raw word codec avoids it. No expensive
full-game memory/gas sweep or historical Phase0–4 acceptance was run.

## Menu and ABI integration contract

The existing production main menu retains NEW GAME, SELECT LEVEL and OPTIONS and
adds LOAD GAME/SAVE GAME using `M_LOADG`/`M_SAVEG`. Load/Save screens are 5/6;
Options stays 4 and SELECT LEVEL stays 3. F2=188 and F3=189 use pinned doomdef.h
symbols. Six borders use the original M_LSLEFT/M_LSCNTR/M_LSRGHT patches at the
original coordinates; fonts, skulls, selection keys and entry cursor are EVM-drawn.
The SELECT LEVEL S hotkey is preserved; Save uses G in the extended main menu.
No HTML gameplay controls or replacement menu system was added.

| Interface | Contract |
|---|---|
| `readSaveSlot(uint8)` | Read one SaveSlotMetadata without decoding/ticking. |
| `listSaveSlots()` | Read six metadata entries, including empty/compatible flags. |
| `saveGame(uint8,bytes,uint64,uint32)` | Slot, validated description, expected revision, next input sequence. The same API overwrites occupied slots. |
| `loadGame(uint8,uint64,uint32)` | Slot, exact expected revision, next input sequence; emits restored cached output. |
| `GameSaved(uint8,uint64,bytes32,uint32)` | Indexed slot, new revision, payload digest, byte length. |
| `GameLoaded(uint8,uint64,bytes32)` | Indexed slot, loaded revision, payload digest. |

Metadata returns occupied/compatible/revision, gametic/leveltime,
skill/episode/map/mode/profile, byteLength, schema/engine/resource/digest and
description. Descriptions are nonempty, at most23 characters, uppercased original
font-domain text with the original pre-append width limit. `DoomMenu.respond`
stops dispatch after a save/load request and preserves whole-packet menu isolation;
letters/navigation cannot leak into cheats, movement or firing. Empty Load
selections never request a load; all-empty navigation terminates. Existing
Frame/raw-input/menuStatus APIs and Solidity memory-profile defaults are unchanged.

Shared integration touch points are `m_menu.sol` MenuState and the two adapter
`_stepMenu` control branches, plus appended slot storage/ABI and authenticated
release pins. No EpisodeRuntime, g_game, DoomGame, InputProtocol, GameState type,
allocator implementation or rendering algorithm was changed. The Death/Respawn
integrator must reconcile adapter edits on its current main, regenerate/check
the root schema if shared state changes, rebuild both releases and rerun relevant
save continuations. This branch never independently integrated that agent's branch.

## Focused correctness evidence and reproducibility

[evidence.json](../artifacts/save-load/evidence.json) binds published report hashes;
[release.json](../artifacts/save-load/release.json) binds source/ABI/artifacts,
toolchain and all three resource identities. Reports distinguish finite native
coverage from production EVM continuation and list exact transaction hashes.

* **Forge:**25 successful executions (22 distinct methods; inherited codec tests
  execute again in SaveSlotsTest). Covers nested packed/dynamic roots, all bytes
  encodings, thinker ordering, stable references/tombstones/capacity, allocator
  history, grow/shrink/repeated loads, six independent slots, overwrites/revisions,
  schema/engine/IWAD/profile/digest guards, missing/incomplete snapshots and rollback.
  Three new menu methods compare all25 native frames and exercise editing,
  cancellation, function keys, empty navigation and packet isolation. All13
  inherited menu/Options/commercial-selection tests remain unchanged and pass.
* **Node:**67 affected input/menu/profile/install/instrumentation checks pass,
  including a new pinned original-C F-key symbol/packet regression.
* **Original C:**O0/O2/ASan+UBSan save archive/request and menu gates agree.
  Original align4 archive writes fail LP64 UBSan; the executed passing archive
  gate explicitly adapts PADSAVEP to align8 using uintptr_t. Pristine original
  files are untouched; that failure is retained, not reported passed. Existing
  native renderer/LP64 harness adaptations and compiler flags remain declared.
* **Native/EVM:**five fresh finite Freedoom kernel worlds—movement160tics,
  combat100, door125, projectile65, active platform125. Three native compiler
  profiles agree; ordinary EVM and same-gas MSIZE probes compare all580 startup/
  tic observations and15 full64,000-pixel native frame checkpoints. Each case
  restores and replays twice (580 continuation rows per deployment), checks the
  entire root digest at restore and at replay termination, and preserves allocator
  chronology/RNG/references. The platform/arena fixtures call original functions
  on authentic geometry; native state/pixels are never imported into the EVM.
  This native profile uses direct ticcmds without ST/HU ticks, not universal
  arbitrary-native-pointer equivalence or a commercial native replay claim.
* **Production Chrome/Anvil:**18 checks and173 exact Canvas/Frame checkpoints
  across all3 authenticated browser-managed installations. Each game proves
  movement/combat input, genuine IDKFA inventory change, original Save/Load menus,
  multiple slots/overwrite, full-root and complete-frame continuation replay,
  no-tic load, RNG/history preservation by digest, Options/SELECT LEVEL and
  cross-map restoration. All18 failed write transactions (six per game) prove
  full contract storage-root rollback/no logs. Browser reload/game switching
  retains the same slots/contracts with isolated IWAD identities and unchanged
  default2/explicit browser3 policy. Commercial coverage here is production EVM
  restore/replay, not an additional original-C commercial oracle run.

Reproduction uses the worktree's pinned tools and its own free ports. For example:

```sh
node tools/wad/pack.ts artifacts/local/freedoom/freedoom1.wad artifacts/local/wad
python3 tools/reference/save_load/schema.py --check
python3 tools/reference/save_load/native.py --wad artifacts/local/freedoom/freedoom1.wad --output artifacts/local/save-load/native-aligned
python3 tools/reference/save_load/menu_native.py --wad artifacts/local/freedoom/freedoom1.wad --check
python3 tools/reference/save_load/replay_native.py --wad artifacts/local/freedoom/freedoom1.wad
python3 tools/reference/save_load/memory.py
.toolchain/bin/forge build src/evm/Doom.sol src/evm/Doom2.sol src/support/SaveReplayProbe.sol artifacts/local/save-load/memory/DoomSaveMemoryProbe.sol
python3 tools/reference/save_load/focused.py
node tools/reference/save_load/replay.mjs --resources artifacts/local/wad --output artifacts/local/save-load/replay-reproduction
node tools/reference/save_load/memory.mjs --resources artifacts/local/wad --output artifacts/local/save-load/memory-reproduction
node tools/browser-deployment/package.mjs .
node tools/reference/doom2/package.mjs .
node tools/reference/save_load/browser.mjs --ultimate-wad artifacts/local/options/DOOM.WAD --doom2-wad artifacts/local/options/DOOM2.WAD --output-prefix artifacts/local/save-load/browser-reproduction
```

Cost-architecture replay requires the preserved measurement artifact (the old
artifact intentionally predates final source formatting/complete-frame guards),
or a fresh separately labelled current build of SaveCostProbe. Do not relabel
new costs as the historical selection measurement. Runtime runners refuse
occupied ports and stop only owned children: architecture19391, native/EVM19393,
browser19395/19396 and production memory19397. Reserved18880/8088 were untouched.
Raw inputs, receipts, logs, source clones and screenshots remain under ignored
`artifacts/local/save-load`; published metadata/fixtures contain no commercial IWAD.

## Checkpoints, files and remaining integration work

Measured verification window: goal start2026-10-11 17:40:46 UTC; last native/EVM
terminal-root gate completed19:38:58 UTC; report/runtime cleanup checked19:40:32 UTC.
At that check the goal tool attributed956,051 tokens and7,186 seconds to the goal.
These are available tool counters at that timestamp, not estimates of monetary
cost or final billing. No model-by-model billing attribution was supplied.

Checkpoint1 (`d3c33c471f026e1e915893821b497ccc9b9d09b3`): architecture gate,
native archive investigation, bounded codec, generated schema and six-slot registry.
Checkpoint2 (`8e19ace`): production no-tic boundary, original menu integration,
complete-frame guards, source-bound browser releases and25/67 focused test gates.
Checkpoint3 records native continuation, actual EVM/Chrome restore/replay and
production memory evidence. The final handoff names its exact commit SHA.
Implementation and focused feature verification are complete; main integration,
Death/Respawn regression and final historical acceptance are separate work.

Production files changed/added are `src/doom/p_saveg.sol`, `src/doom/m_menu.sol`,
`src/evm/SaveSchema.sol`, `src/evm/DoomSave.sol`, `src/evm/Doom.sol`,
`src/evm/Doom2.sol`, `src/evm/DoomMenu.sol`, `web/install-assets/Doom.json`,
`web/install-pins.mjs`, `web/doom2-assets/Doom.json`, and `web/doom2-pins.mjs`.
Support modules are `src/support/SaveCostProbe.sol` and `SaveReplayProbe.sol`.
New tests are `test/unit/p_saveg.t.sol`, `SaveSlots.t.sol`, `SaveMenu.t.sol` and
`test/fixtures/save_menu/`. Goal tooling is `tools/reference/save_load/`;
reports are this document, the PORTING.md adaptation row and `artifacts/save-load/`.
Existing historical goldens/tests, original C, shared state types and memory
algorithms/defaults were preserved. No commit, merge or push targeted main.

After Death/Respawn integration, specifically test saves while dead, lazy removed
actors/thinkers, corpse references, rebirth/deferred restart and monster respawn;
load before/after those transitions and compare exact roots, thinker order,
RNG/allocation chronology and following native-compatible frames. Also repeat
cross-map/Options/browser tests after adapter reconciliation and schema/release
regeneration. This feature's initial acceptance does not depend on unfinished
Respawn behavior. Engine upgrade migration, maximum-history cost bounds and
optional immutable/semantic compression are open future choices, not hidden
requirements for the verified v1 contract-local slots.

All failed probes and corrections are separately indexed in
[attempts.json](../artifacts/save-load/attempts.json), including the real Chrome
F2/F3 failure and the pre-game memory-harness error. No accepted assertion or
original golden was weakened. The feature stops at handoff; further integration
or scope expansion requires the designated owner's next instruction.
