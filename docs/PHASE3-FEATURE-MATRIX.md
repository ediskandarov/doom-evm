# Phase 3 source coverage and acceptance boundaries

The frozen implementation now has bounded, completed kernel, public-contract and
Chrome integration proofs. **M2 and M3 remain pending final inherited gates,
integrator signoff.** This is not a complete original
DOOM port. All descriptions below distinguish source presence, actual integration
and the measured verification scope.

The [machine-readable matrix](../artifacts/phase3/feature-matrix.json) records every
original definition's source span/hash, its named port or explicit delegation,
helper roles, proof hashes, current source bindings and unsupported domains.
Refresh with `python3 tools/audit/phase3_features.py`; verify the snapshot with
`--check`. The generator reads code and summarized proof records, never Codex
session transcripts. This audit ran no compiler or engine tests.

## Source inventory

The pinned original checkout is `a77dfb96cb91780ca334d0d4cfd86957558007e0`. Across 18 core
`p_*.c` gameplay units there are **238 active definitions**: 231 named ports
and seven disk loaders delegated to `R_Data.R_LoadMap`. Setup is integrated and
verified, rather than a draft. Sector runtime initialization and native map
allocation chronology remain separate source-derived adapter responsibilities.

The expanded inventory covers **388 definitions**, including original
`p_saveg`, all `g_game`, RNG/bbox, all renderer units, `z_zone` and `w_wad`.
Original abandoned sliding doors are excluded from active gameplay counts.
Four of 32 `g_game` definitions are ported; eight original save/archive
definitions and the other gameflow definitions remain absent.

| Original unit | Definitions | Named / delegated / adapted / absent |
|---|---:|---|
| `p_ceilng` | 6 | named_port: 6 |
| `p_doors` | 10 | named_port: 6, disabled_upstream: 4 |
| `p_enemy` | 64 | named_port: 64 |
| `p_floor` | 4 | named_port: 4 |
| `p_inter` | 9 | named_port: 9 |
| `p_lights` | 11 | named_port: 11 |
| `p_map` | 20 | named_port: 20 |
| `p_maputl` | 15 | named_port: 15 |
| `p_mobj` | 16 | named_port: 16 |
| `p_plats` | 6 | named_port: 6 |
| `p_pspr` | 30 | named_port: 30 |
| `p_saveg` | 8 | not_ported: 8 |
| `p_setup` | 12 | delegated: 7, named_port: 5 |
| `p_sight` | 5 | named_port: 5 |
| `p_spec` | 18 | named_port: 18 |
| `p_switch` | 4 | named_port: 4 |
| `p_telept` | 1 | named_port: 1 |
| `p_tick` | 6 | named_port: 6 |
| `p_user` | 5 | named_port: 5 |
| `g_game` | 32 | not_ported: 28, named_port: 4 |
| `m_random` | 3 | named_port: 3 |
| `m_bbox` | 2 | named_port: 2 |
| `z_zone` | 10 | named_port: 8, not_ported: 2 |
| `w_wad` | 15 | adapted: 8, not_ported: 7 |
| `r_bsp` | 8 | named_port: 8 |
| `r_data` | 13 | named_port: 8, delegated: 4, not_ported: 1 |
| `r_draw` | 13 | named_port: 9, disabled_upstream: 2, not_ported: 2 |
| `r_main` | 17 | delegated: 3, named_port: 12, original_empty_noop: 2 |
| `r_plane` | 7 | named_port: 7 |
| `r_segs` | 3 | named_port: 3 |
| `r_sky` | 1 | delegated: 1 |
| `r_things` | 14 | named_port: 14 |

Counts establish source mapping, not per-function branch acceptance. Original
host file/reload/profile and heap dump functions remain host responsibilities;
immutable authenticated EVM resource readers adapt name/length/byte lookup.
Semantic `W_CacheLumpNum` hit/miss/tag/owner behavior is implemented separately.
`Z_ClearZone`, `Z_Init`, `Z_Free`, `Z_Malloc`, `Z_FreeTags`, `Z_CheckHeap`,
`Z_ChangeTag2` and `Z_FreeMemory` are the eight ported original allocator cores.

## Completed integration evidence

| Evidence | Actual scope | Result |
|---|---|---|
| [Atomic startup](../tools/reference/phase3_zone_setup/atomic-validation.json) | Single real `initializeNative`, original resource/level/player allocation order, all normalized headers/owners and actor/special/map counts; four tests | PASS |
| Full kernel, retained report `artifacts/local/gameplay-atomic-complete.json` | Nine declared scenarios, 2,355 tics, 31 selected complete frames, nine exact final stored logical states; direct ticcmds and test-only arena setup | PASS, run19797 |
| [Public production](../tools/reference/gameplay/production-atomic-evidence.json) | One ordinary `initializeGame` transaction; 129 keyboard tics, 130 rows ×14 fields, six native live frames, static pre-start Frame, thirteen whole-storage rollback checks | PASS, run93227 |
| [Repeated production](../tools/reference/gameplay/production-reproducibility-evidence.json) | Two fresh ordinary contracts: all130×14 rows, commands/sequences/cadence, seven totalFrames, gas and thirteen errors/rollback equal | PASS, run10416 |
| Chrome, retained report `artifacts/local/phase3-gameplay-browser-atomic.json` | Six actual Frames/Canvas, keyboard Start/Resume, blur stop, deduplication and controlled receipt fallback; prior failing tic5 now exact | PASS, run72876 |
| Memory clone reports `artifacts/local/gameplay-production-atomic-memory{,-cadence}.json` | Separate clone agrees with ordinary production storage/exported fields/Frames; patched/unpatched clone gas equal; all-render and no-render cadence | PASS, runs41920/74863 |

The repeated production stream has independent fresh state and rechecks all1,755 authenticated resource chunks. Only the repeat runner's optional palette-copy guard differs; production code/transactions/native stream are unchanged.

The full-kernel scenarios are idle70, movement275, pistol235, combat175,
damage350, death350, door-use375, door-obstructed375 and projectile-arena150 tics.
The last compares seven selected frames and actual rocket interactions. All
other cases compare three frames. Native instrumentation reports authoritative
logical world before rendering; final stored comparisons use the appropriate
post-render native boundary. This avoids treating renderer-mutated flags and
validcounts as a simulation mismatch. It does not imply comparison of every
renderer cache byte or arbitrary physical payload byte.

Public production verifies its real driver/strict consecutive sequence/input
validation and rollback, persisted whole game state and Frame transport, rather
than probe serialization. Five `gameStatus` and nine `playerView` fields are
checked at every selected tic. Chrome's short fire input arrives while the weapon
is raising; actual shooting has independent 129-tic production and kernel proofs.
Kernel direct-command coverage does not independently prove every keyboard path.

The retained module scopes remain useful: collision/sight 4,310 geometry cases
and71 scenarios; lifecycle784 cases; combat6,025 interaction cases and72 weapon
scenarios/11,520 tics; AI1,137 controlled cases/all64 active definitions; world
359 scenarios/79,021 snapshots/2,160 plane cases; specials416 unit cases plus
1,007 dispatch scenarios/4,048 paired snapshots; bbox521 streams/8,299 points;
input41,007 commands. The source/table export has967 states,137 actor/effect/item
definitions,nine weapons and74 actions. These are not137 monster species or
full-world execution of every entry. Exact original numeric special dispatch
coverage is72 crossing,63 use and3 shoot branches in declared synthetic fixtures.
Broad weapon/enemy/world module proofs use controlled neighbors or synthetic
geometry; they do not become complete integrated action/species coverage.

Allocator core proof covers1,624 original allocation snapshots and five fatal
conditions across O0/O2/full ASan/UBSan, plus two Solidity tests. Renderer backing
proof covers80 native cases/10,240 knownness positions/18 original draws and111
owned inherited/focused Solidity tests. Each checkpoint binds its own tested
source revision. Final inherited regression gates remain separate.

## Allocator/cache and representation adaptations

Stable logical actor/thinker/world IDs and capacity buffers preserve linked
thinker/sector/block order and same-tic tail execution. A separate native zone
ledger preserves source physical allocation offsets, list links, rover,
purge/merge/donated slack and logical owner clearing. Source-derived startup,
map setup, actors/movers/lazy frees and semantic renderer cache operations mutate
that ledger. Native allocation outputs are comparison gold only, never runtime
tapes. Owner namespace is lump ID; composites use `numlumps + textureID`.

Raw columns/sprites use `PU_CACHE`; drawn flats use `PU_STATIC` then return to
`PU_CACHE`; composites allocate before patch-cache calls and become cache-tagged
after construction. Ephemeral immutable-data decoding is not an additional
native allocation. Existing composite bodies may be quietly rebuilt after an
EVM storage load, while a purged owner requires genuine original regeneration.

The pinned LP64 profile has40-byte block headers,56-byte zone header, sentinel
offset8 and8-byte alignment. Upstream4-byte alignment is explicitly adapted for
native LP64 gameplay. Allocation sets known `ZONEID`; free sets known0; initial
and split free IDs remain unknown, including physical reuse. Stable IDs are not
fabricated process pointer bytes.

The renderer can read beyond a logical lump only when the original physical
backing value is known: size/tag/known-ID header integers or authenticated live
adjacent cached-lump body bytes. It preserves the original column arithmetic,
including negative fraction wrap. No specific asset/frame/pixel exception exists.
Pointers, padding, uninitialized IDs, slack, free/unmodeled actor/mover/composite
bodies, stale owners and out-of-zone bytes remain unknown and rejected. The lazy
128-sample ordinary-column window is conservative for translated out-of-profile
indices; negative absolute indices still reject. Existing malformed draw/resource
checks remain. Selected recovered frames do not prove arbitrary native reads.

Call-local traversal, line-loader and tail-reader working structs resolve full
hook-graph compiler liveness without changing source math/order/loops/guards,
persisted semantics, limits or compiler settings.

## Supported and omitted profiles

| Feature | Implementation/integration boundary |
|---|---|
| `single_player` | **integrated_selected_world_verified**: Actual atomic medium retail E1M1, one player, source-driven native zone startup; whole-kernel nine declared scenarios, public 129 keyboard tics and Chrome six-frame stream. No arbitrary maps/modes acceptance. |
| `keyboard` | **integrated_production_and_browser_verified**: Original declared keyboard conversion, persistent input, actual public authentication/sequencing/rollback and Chrome Start/Resume, WebSocket/receipt fallback/Canvas in bounded retained streams. |
| `mouse_joystick_chat` | **unsupported**: G_BuildTiccmd profile holds these device inputs zero; no device, chat or double-click frontend. |
| `cli` | **unsupported_host_layer**: No original D_DoomMain CLI, -avg/-timer flags or arbitrary startup parsing. Timer update logic is separately implemented/tested; nomonsters is an adapter argument. |
| `multiplayer_deathmatch` | **unsupported_adapter**: Original branches and four player slots retained/tested in modules; no network G_Ticker/checksum/consistency path and P_SetupLevel rejects deathmatch startup. |
| `demo_record_playback` | **unsupported**: No G_Read/WriteDemoTiccmd or original demo gameflow implementation. Ticker demo exception fields do not imply demo support. |
| `audio_music` | **presentation_omitted**: Sound/music device calls omitted; P_NoiseAlert and sound-choice gameplay P_Random draws retained. Cosmetic M_Random profile is distinct. |
| `menu_hud_automap` | **presentation_omitted**: No original menu/status bar/HUD/automap; ticker menu guard retained, world view and PSprites rendered. |
| `save_load` | **unsupported**: EVM state persistence is a different mechanism; original p_saveg serialization and G_Load/SaveGame not ported. |
| `intermission_finale_level_progression` | **unsupported**: Exit/secret action flags implemented; G_DoCompleted/G_WorldDone/G_DoWorldDone/G_InitNew flow absent. No automatic next map, intermission or finale. |
| `death_respawn_flow` | **partial**: DeathThink and G_PlayerReborn/P_SpawnPlayer implemented; complete G_DoReborn/check-spot/level restart dispatch absent. |
| `other_maps_modes_skills` | **module_only**: Algorithms and dependent branches tested in isolated contexts. Production initializes fixed medium retail E1M1. No arbitrary WAD/map/episode runtime acceptance. |
| `sliding_doors` | **disabled_upstream**: Original #if0 code intentionally excluded, not an active missing gameplay feature. |

Original `G_Ticker`, `G_DoReborn`, `G_DoCompleted`, world transition/intermission,
finale, full new-game flow and save/archive format are absent. Exit/secret flags,
DeathThink/PlayerReborn/SpawnPlayer and a direct `P_Ticker` do not implement those
layers. World view/PSprites are rendered, but original HUD/menu/automap/audio
presentation is omitted. No complete playthrough, all-map, multiplayer, device,
demo or arbitrary WAD acceptance is claimed.

## Monster and boss family evidence

The source-derived family matrix includes every `MF_COUNTKILL` actor plus lost
soul, Keen and brain/spitter/target actors. All original definitions are in the
foundation proof. Named enemy actions have isolated original-C module evidence;
this is not an integrated-world species claim. State-table traversal lists the
declared actions from spawn/see/pain/melee/missile/death/xdeath/raise roots;
dynamic calls from actions are covered by their own function inventory. Retained
native action counters are global and cannot attribute a shared action to an
actor species. **Individual integrated family entry coverage is uninstrumented.**

| Original actor family | Declared enemy state actions | Integrated species evidence |
|---|---|---|
| `MT_POSSESSED` | `A_Chase`, `A_FaceTarget`, `A_Fall`, `A_Look`, `A_Pain`, `A_PosAttack`, `A_Scream`, `A_XScream` | Shared entry counters only; species attribution not established |
| `MT_SHOTGUY` | `A_Chase`, `A_FaceTarget`, `A_Fall`, `A_Look`, `A_Pain`, `A_SPosAttack`, `A_Scream`, `A_XScream` | Shared entry counters only; species attribution not established |
| `MT_VILE` | `A_FaceTarget`, `A_Fall`, `A_Look`, `A_Pain`, `A_Scream`, `A_VileAttack`, `A_VileChase`, `A_VileStart`, `A_VileTarget` | Shared entry counters only; species attribution not established |
| `MT_UNDEAD` | `A_Chase`, `A_FaceTarget`, `A_Fall`, `A_Look`, `A_Pain`, `A_Scream`, `A_SkelFist`, `A_SkelMissile`, `A_SkelWhoosh` | Shared entry counters only; species attribution not established |
| `MT_FATSO` | `A_BossDeath`, `A_Chase`, `A_FaceTarget`, `A_Fall`, `A_FatAttack1`, `A_FatAttack2`, `A_FatAttack3`, `A_FatRaise`, `A_Look`, `A_Pain`, `A_Scream` | Shared entry counters only; species attribution not established |
| `MT_CHAINGUY` | `A_CPosAttack`, `A_CPosRefire`, `A_Chase`, `A_FaceTarget`, `A_Fall`, `A_Look`, `A_Pain`, `A_Scream`, `A_XScream` | Shared entry counters only; species attribution not established |
| `MT_TROOP` | `A_Chase`, `A_FaceTarget`, `A_Fall`, `A_Look`, `A_Pain`, `A_Scream`, `A_TroopAttack`, `A_XScream` | Shared entry counters only; species attribution not established |
| `MT_SERGEANT` | `A_Chase`, `A_FaceTarget`, `A_Fall`, `A_Look`, `A_Pain`, `A_SargAttack`, `A_Scream` | Shared entry counters only; species attribution not established |
| `MT_SHADOWS` | `A_Chase`, `A_FaceTarget`, `A_Fall`, `A_Look`, `A_Pain`, `A_SargAttack`, `A_Scream` | Shared entry counters only; species attribution not established |
| `MT_HEAD` | `A_Chase`, `A_FaceTarget`, `A_Fall`, `A_HeadAttack`, `A_Look`, `A_Pain`, `A_Scream` | Shared entry counters only; species attribution not established |
| `MT_BRUISER` | `A_BossDeath`, `A_BruisAttack`, `A_Chase`, `A_FaceTarget`, `A_Fall`, `A_Look`, `A_Pain`, `A_Scream` | Shared entry counters only; species attribution not established |
| `MT_KNIGHT` | `A_BruisAttack`, `A_Chase`, `A_FaceTarget`, `A_Fall`, `A_Look`, `A_Pain`, `A_Scream` | Shared entry counters only; species attribution not established |
| `MT_SKULL` | `A_Chase`, `A_FaceTarget`, `A_Fall`, `A_Look`, `A_Pain`, `A_Scream`, `A_SkullAttack` | Shared entry counters only; species attribution not established |
| `MT_SPIDER` | `A_BossDeath`, `A_Chase`, `A_FaceTarget`, `A_Fall`, `A_Look`, `A_Metal`, `A_Pain`, `A_SPosAttack`, `A_Scream`, `A_SpidRefire` | Shared entry counters only; species attribution not established |
| `MT_BABY` | `A_BabyMetal`, `A_BossDeath`, `A_BspiAttack`, `A_Chase`, `A_FaceTarget`, `A_Fall`, `A_Look`, `A_Pain`, `A_Scream`, `A_SpidRefire` | Shared entry counters only; species attribution not established |
| `MT_CYBORG` | `A_BossDeath`, `A_Chase`, `A_CyberAttack`, `A_FaceTarget`, `A_Fall`, `A_Hoof`, `A_Look`, `A_Metal`, `A_Pain`, `A_Scream` | Shared entry counters only; species attribution not established |
| `MT_PAIN` | `A_Chase`, `A_FaceTarget`, `A_Look`, `A_Pain`, `A_PainAttack`, `A_PainDie`, `A_Scream` | Shared entry counters only; species attribution not established |
| `MT_WOLFSS` | `A_CPosAttack`, `A_CPosRefire`, `A_Chase`, `A_FaceTarget`, `A_Fall`, `A_Look`, `A_Pain`, `A_Scream`, `A_XScream` | Shared entry counters only; species attribution not established |
| `MT_KEEN` | `A_KeenDie`, `A_Pain`, `A_Scream` | Shared entry counters only; species attribution not established |
| `MT_BOSSBRAIN` | `A_BrainDie`, `A_BrainPain`, `A_BrainScream` | Shared entry counters only; species attribution not established |
| `MT_BOSSSPIT` | `A_BrainAwake`, `A_BrainSpit`, `A_Look` | Shared entry counters only; species attribution not established |
| `MT_BOSSTARGET` |  | Shared entry counters only; species attribution not established |

See the [AI family/function proof](PHASE3-AI.md) for controlled module conditions
and remaining integrated species/attack/resurrection/boss-map domains. The JSON
retains each family's state roots, table actions and global native observations;
zero or absent observations do not prove absence of execution.

## Native domains and execution policy

- **numeric-profile — Pinned implementation equivalence, not universal ISO C.** 32-bit wrapping, signed narrowing, arithmetic shifts and ordered RNG use explicit implementations. Negative signed shifts remain original undefined ISO C behavior, measured under pinned native profiles.
- **allocation-profile — Explicit deterministic extension in isolated zero-filled world tests.** Original timed-close door topheight/topwait and stair type/crush are uninitialized. Snapshot masking does not prove gameplay equivalence when consumed under arbitrary heap fills; whole-world 0xa5 evidence covers only selected scenarios.
- **zone-identity — Stable logical IDs plus original physical zone mirror.** Typed payload IDs/tombstones preserve live linked order; native zone separately preserves original physical offsets/rover/free/purge/cache owner chronology. Actor/mover body and pointer bytes are not generally reconstructed. Actual startup/header proof plus selected full-world/public/browser comparisons establish bounded integration, not all future allocation histories.
- **mover-casts — Measured pinned LP64 integer overlaps only.** Manual doors preserve byte48 overlap with plat.count/ceiling.speed. Floor texture/padding representation not proven; fire-flicker reinterpretation is out-of-bounds. Other unsupported casts reject InvalidDoorThinker.
- **undefined-generic-donut — Reject undefined initialized-payload domain.** EV_DoFloor(donutRaise) rejects where original sector pointer was never initialized. Actual EV_DoDonut creates valid donutRaise thinkers and is compared.
- **geometry-and-capacity — Retain valid original control flow; explicit failures outside supported domain.** Reject abs(INT_MIN), >8 crossed specials, >128 intercepts, >64 scrollers, malformed BLOCKMAP/BSP/REJECT and null donut topology. P_PathTraverse original64-step bound retained. Next-highest floor original first20 eligible values is a defined break, not a rejected overflow.
- **original-fatal-limits — Original I_Error becomes revert; original nonfatal behavior retained.** Exhausted16 buttons, full/missing30 platform registry and unknown pickups become explicit errors. Full30 ceiling registry originally silently fails registration and remains so. Valid animation/resource lookup prerequisites enforced.
- **invalid-ai-indices — Reject original undefined/caller-invalid states.** Reject invalid movement direction, no enabled player during player search, >32/missing brain targets, zero cube speed/tics or target mass, invalid actor/state/weapon/ammo indices; native proof excludes undefined cases except explicit diagnostic probes.
- **production-resources — Configurable local execution budget; independent code/memory/compiler constraints.** Default local 10B gas, env/config override. No fixed 1B economic fidelity gate and no production startup split to satisfy such a gate. Actual ordinary initialization1621868997 gas, selected steps309171400..312238893 and liveFrames719455170..781684253. Clone engine-boundary memory initialization19665056B/liveFrames<=11956800B/steps<=8753856B; not exact untouched-production peak. Enlarged local code limits do not imply public-chain deployability.
- **physical-backing-knownness — Known bytes only; unknown remains a rejection.** Allocated/free size/tag/known-ID integer bytes and authenticated adjacent cached lump bodies may be read through source-derived links. Pointers, padding, initial/split unknown IDs, slack, free/unmodeled payload bodies, stale cache ownership, negative absolute indices and out-of-zone positions remain unreadable. Ordinary128-sample lazy tail window rejects arbitrary translated out-of-profile indices. Logical-lump overread can be within original whole-zone backing; no asset/frame/pixel exception.
- **native-layout — Pinned LP64 implementation profile.** memblock40,memzone56,cap8,headerID20,align8 are measured native adaptation; upstream align4 replaced for LP64 gameplay validity. Stable IDs substitute process pointers. Fresh split IDs intentionally unknown. This is not universal compiler/architecture/pointer-byte fidelity.
- **source-liveness-adaptations — Call-local working-set representation only.** P_PathTraverse working struct, R_LoadMap line aliases/offset scratch and physical tail reader scratch allow unchanged production compiler settings to generate the full hook graph. No source loop/math/order/guard changes or persisted scratch injection.

The default **local gas budget is10B and configurable** through the shared config
and environment helper. There is no fixed1B economic fidelity gate. Production
startup remains one atomic transaction. Existing historical1B reports retain
their original values and scopes; no measurement has been rewritten.

Actual ordinary production initialization costs1,621,868,997 gas; selected
no-render steps309,171,400–312,238,893 and live frames719,455,170–781,684,253.
These include storage/gameplay/render/Frame work and exclude probe serialization.
They describe enlarged local Cancun execution, not protocol-limit public-chain
deployment. Compiler remains solc0.8.37,viaIR,optimizer200,Cancun.

Measured clone engine-boundary memory high-water is19,665,056 bytes for atomic
initialization, at most11,956,800 bytes for selected live frames and8,753,856 bytes
for selected no-render steps. The marker follows actual engine work; later
observer event encoding and separate calls/precompiles are outside that reading.
The clone can change compiler memory reuse. **Exact untouched-production memory
peak remains unmeasured.** This limitation survives equal storage, pixels and
patched/unpatched clone gas. See [memory method](../tools/reference/gameplay/PRODUCTION-MEMORY.md).

## Remaining final acceptance

- **inherited-final-gates: pending.** Run required final inherited Phase0/1/2 and complete Phase3 regression gates against frozen source; bind final tested source hashes.
- **repeat-production-stream: verified.** Completed retained reproducibility proof: two independent ordinary production deployments, complete129-tic stream, all fields/cadence/Frames/gas/thirteen error and rollback checks equal.
- **feature-domain-signoff: pending.** Integrator final source/function/domain review; preserve explicitly unsupported profiles and all rejected unknown backing/undefined domains.
- **M2-final-acceptance: pending.** Integrator accepts bounded startup/input/movement/world/render/persistence/browser scope only after final inherited/repeat gates.
- **M3-final-acceptance: pending.** Integrator accepts declared integrated combat/AI/damage/pickup/door/projectile scenarios after final gates; isolated all-nine-weapon/all-enemy-action proofs do not become complete full-world branch coverage.
- **usage-article: continuing.** Keep existing local collector boundaries/model/agent/phase evidence and missing historical measurements; do not read raw transcripts or infer absent token counts.

Commands are copied exactly when present in retained records. Where a local
report does not retain a command, the matrix does not invent it from current
script defaults. Source-at-run bindings remain distinct from the current audit
snapshot; runner-only changes are listed even when production Solidity is
unchanged. The machine-readable evidence registry binds every retained report
by SHA256, including ignored local reports. No new test result is inferred by
this audit.
