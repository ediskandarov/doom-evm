# Original single-player death and rebirth

## Goal and ownership

Implementation started 2026-10-11 17:41:08 UTC on `feat/death-respawn`, owned
worktree `/Users/eduard/sandbox/doom-evm-respawn`. Refreshed `origin/main` and
confirmed clean synchronized baseline `ff826659ceff0b3a5637e70109b62eb75a83d611`.
Only this feature worktree is writable; no main/Save-Load integration or push.
Stop after focused verified implementation and recoverable Gitmoji handoff.

Preserved discovery baseline: `411e6049f9e2ad496d45264facbb6fdafc3dbfa7`.
Discovery checked original source and existing tests without writing files.
Its native checks passed 784 lifecycle, 219 E1 gameflow and 266 commercial
gameflow cases; 44 Node input/transaction tests passed. No fresh production
death/rebirth/Canvas acceptance was claimed at that checkpoint.

## Revalidated source and scope

Original source: `original/DOOM/linuxdoom-1.10`, upstream
`a77dfb96cb91780ca334d0d4cfd86957558007e0`. P_DamageMobj/P_KillMobj enter
PST_DEAD, drop the weapon and select death/xdeath states with original RNG.
P_DeathThink advances psprites, drops viewheight to six units, turns toward the
attacker, and accepts sampled BT_USE without an edge or animation-completion
gate. Attack alone does not rebirth. Next G_Ticker dispatches G_DoReborn and
G_DoLoadLevel, retaining map/skill/RNG/difficulty histories; P_SetupLevel frees
level tags and rebuilds the world. P_SpawnPlayer invokes G_PlayerReborn and
starts ST/HU. The already-built command is copied after load, then world ticks.

These source-derived functions are already implemented and Episode-integrated.
Do not replace them with NEW GAME, page reload, resource redeployment, fresh
zone initialization, host gameplay or arbitrary storage clearing.

First confirmed integration gap remains P_KillMobj's immediate AM_Stop after
P_DropWeapon: the original Solidity gameplay hook only drops the weapon.
Use that existing hook's exact boundary to bind the missing AM/UI behavior in
EpisodeRuntime. No persistent GameState, UIState, EpisodeState or input/Frame ABI
layout change is planned. EpisodeAux is transient callback data only. Its flow
copy supports original stop-notification dispatch during P_Ticker and is
reconciled to the authoritative flow before subsequent gameflow/UI callbacks.

Menu input remains menu-owned. A previously queued PST_REBORN must still pass
through original G_Ticker loading before the menu underlay is published;
ordinary dead/live menu packets retain the established frozen-world behavior.
This narrow production-adapter change is proposed for integrator review; no
menu API or menu-selection semantics change is planned.

Freedoom/Ultimate scope remains the authenticated E1M1–E1M9 runtime;
DOOM II MAP01–MAP32. Preserve all original skills and explicit browser profile3,
Solidity default2, unknown-byte rejection and allocator/backing provenance.
Legacy Phase3 startup modes without G_Ticker remain separately scoped.
Production melt orchestration was explicitly excluded by the combined Full
Video/Options integration; retain the original wipe and recording pipeline.

## Dependencies and verification gates

Options owns current menu settings and UIState.hideMessages; preserve screen
size, messages, gamma and original selected gameskill/gamemap across rebirth.
Save/Load owns slots/serialization: no save functionality is added. Persistent
layouts stay unchanged; loading a save remains separate from rebirth and must
respect original G_Ticker's reborn-before-action precedence.

Owned feature changes: EpisodeRuntime death callback, matching narrow Doom and
Doom2 menu adapters, dedicated tests/oracle/browser acceptance and this report.
Shared adapter edits are delivered to the integrator on the feature branch.
No original C, historical fixtures, WAD schemas or common runners are modified.

Gates: pinned original-C lifecycle/gameflow checks; focused Forge lifecycle,
inventory/skill/RNG/allocator/persistence/rollback tests; Node input/menu gates;
actual three-game Anvil/Chrome death/rebirth/continued gameplay under profile3;
native/EVM canonical snapshots and selected complete indexed frames/palettes.
Include monster/environment/moving death, attack-only/held/new use, menu while
dead, repeated cycles, inventory reset, first rebirth frame and rollback.
Use free isolated ports, refuse reserved18880/8088, stop only owned children.
Do not run complete inherited acceptance or duplicate the recording pipeline.

Implementation, verification results, source/evidence hashes, measured limits
and final handoff will be appended at verified checkpoints. Unmeasured memory,
model/cost usage and unsupported source domains will not be estimated.

## Implemented checkpoint

The discovery findings were confirmed against the integrated baseline. Existing
damage, actor death states, P_DeathThink, G_PlayerReborn, G_DoReborn, G_Ticker,
P_SetupLevel and Episode reload logic were reused. Production changes are:

1. EpisodeRuntime binds the existing death/drop-weapon callback, performs the
   existing original P_DropWeapon, then immediately stops an active Automap and
   dispatches its original ST notification. Four transient flow fields preserve
   the stop responder's deferred-selection side effects. Death-state selection
   and RNG work still happen at their original boundary afterward.
2. Doom and Doom2 dispatch an already queued rebirth through original G_Ticker
   even if the next packet is menu-owned. They save the resulting authoritative
   state and use the existing video/Frame emission path with the menu overlay.
3. Both contracts expose read-only `playerLifecycle()` for acceptance and client
   inspection. Selector `9055e997`; outputs are player state, actor state/tics,
   viewheight, damagecount and backpack. Existing selectors and storage layouts
   remain unchanged. No production test-only configuration method is exposed.

| Lifecycle boundary | Existing implementation | Integration / evidence |
| --- | --- | --- |
| Lethal damage and player/actor death state | IMPLEMENTED in P_Inter/P_Mobj | INTEGRATED, VERIFIED: monster/floor/native snapshots and real browser gameplay |
| Death animation and psprites | IMPLEMENTED original states/actions | INTEGRATED, VERIFIED: all actor states/tics and canonical world snapshots |
| View drop and attacker rotation | IMPLEMENTED P_User.P_DeathThink | INTEGRATED, VERIFIED: inherited native DeathThink cases, camera snapshots, viewheight six units |
| Death closes Automap | PARTIAL before this feature | INTEGRATED, VERIFIED through the existing drop callback and stop notification |
| Rebirth input | IMPLEMENTED sampled BT_USE | INTEGRATED, VERIFIED: held/new use, attack-only remains dead, menu-owned use consumed |
| Deferred same-map reload | IMPLEMENTED G_Ticker/G_DoReborn | INTEGRATED, VERIFIED, including queued rebirth followed by a menu packet |
| Inventory/player reset and skill | IMPLEMENTED G_PlayerReborn/P_Setup | INTEGRATED, VERIFIED: inventory/powers/backpack reset, authoritative map/skill retained |
| Zone/thinker cleanup and RNG | IMPLEMENTED original zone/setup/gameflow | INTEGRATED, VERIFIED logical state/RNG, inherited heap/difficulty tests; physical trace limits below |
| Bar, palette and first post-rebirth frame | IMPLEMENTED ST/HU/Full Video | INTEGRATED, VERIFIED complete indexed frames/palettes and real Canvas pixels |
| Browser persistence and continued play | IMPLEMENTED transactions/journals | INTEGRATED, VERIFIED: continued movement/fire, switching/reopening the same contract, rollback |

## Original restart semantics retained

The source boundaries are `p_inter.c` P_KillMobj, `p_user.c:182` P_DeathThink,
`g_game.c:605` G_Ticker, `g_game.c:924` G_DoReborn, `g_game.c:445` G_DoLoadLevel,
`p_setup.c:584` P_SetupLevel, `p_mobj.c:659` P_SpawnPlayer and
`g_game.c:800` G_PlayerReborn. The use command first changes PST_DEAD to
PST_REBORN; the following G_Ticker loads the level. No edge requirement, wait
for the final animation state, or attack-triggered rebirth was introduced.

Rebirth loads the current map with existing gameskill and game profile. It
reuses P_SetupLevel, frees level allocation tags, rebuilds thinkers/actors and
spawns the original player start. Setup resets per-map player counters and
totals; G_PlayerReborn then resets health to 100, armor to zero, fist/pistol,
50 bullets, normal ammo maxima, empty cards/powers and no backpack. ST_Start
and HU_Start restart level UI while keeping source file-static histories.
RNG indices and established Nightmare/fast definition histories survive;
new-game G_InitNew/M_ClearRandom behavior is not substituted. Fresh monsters
are skill-filtered again; the existing Nightmare respawn policy is retained.

With a menu active on the reload tic, G_PlayerReborn clears viewz to zero.
Original P_Ticker's menu guard therefore leaves leveltime at zero. Resuming and
accepting the next world tic yields leveltime one. The first test incorrectly
expected one behind the open menu; the original-C comparison established zero.
The failed attempt is retained in `artifacts/local/death-respawn/focused-run.log`.

## Verified acceptance

Portable hashes and measured results are in
[artifacts/death-respawn/acceptance.json](../artifacts/death-respawn/acceptance.json).
Detailed local traces, receipts, source/build manifests, indexed images,
palettes and screenshots are under `artifacts/local/death-respawn/`.

- Affected production roots built successfully with solc 0.8.37, viaIR,
  optimizer 200 and Cancun. Runtime sizes: Doom 905,970 bytes; Doom2 886,293.
  Browser release packaging checked every compiler metadata source hash.
- Four new Forge tests passed. They compare 92 complete canonical native world
  snapshots and 17 complete indexed framebuffer/palette pairs, and cover floor
  damage while moving, a real possessed actor's lethal attack, acquired
  inventory/powers, attacker/death view, new/held use, attack-only behavior,
  Automap stop, menu ownership/loading, repeated cycles, Options preferences,
  continued gameplay and stale/malformed/non-driver rollback.
- All 85 focused inherited Forge tests passed: original lifecycle, damage,
  psprites, death view, status widgets, zone heap, E1/commercial gameflow,
  persistent transactions, Options and input. Native DeathThink/PlayerReborn
  and Nightmare definition history are included. No complete historical suite
  was run. Earlier native checks also passed 219 E1 gameflow, 784 lifecycle and
  266 commercial gameflow cases.
- All 44 Node keyboard/input/menu/transaction tests passed.
- Real Anvil/Chrome ran 18:51:04.987–19:00:53.057 UTC on isolated ports
  19421/19422. All three profiles installed authenticated resources through the
  browser, used original menu map/skill selection and explicit memory profile3,
  then completed two actual deaths/use/rebirths each. Freedoom/Ultimate used
  E1M1 UV; DOOM II used MAP07 UV. Original IDFA supplies inventory for a
  reproducible rocket/real-geometry/monster route; no state injection or probe
  contract enters the browser. Both cycles remain on the same deployed
  contract/resources. The second proves queued rebirth under an open menu.
- All 75 rendered Canvas checks match every expanded receipt pixel and palette.
  Each game has 12 selected complete gameplay frames compared with original C
  under O0, O2 and ASan/UBSan: 36 unique frames/palettes, 108 profile comparisons.
  All 770 gameplay tics match 18 observed native fields under each profile:
  2,310 tic comparisons and 41,580 field comparisons. These include health,
  actor state/tics, camera, ammo, both RNG indices, face, map and skill.
- Three real reverted transactions leave the complete `eth_getProof`
  storageRoot unchanged and emit no logs. Forge additionally checks the
  serialized world/input/UI/menu/Episode state digest on invalid operations.
- Browser switching/reload detection preserved each installed contract and
  player state; no resource redeployment was used for rebirth. Only owned
  Anvil/Chrome/server instances were stopped. Reserved ports were untouched.

Native host domains retain the established LP64, `-fwrapv`, initialized-zone
and borrowed immutable UI adaptations. Pointer-free observer IDs restart with
the logical actor pools after loading; gameplay does not consult those IDs.
The inherited raw collision-scratch diagnostic attempts to identify stale
native pointers after level cleanup. That observation is excluded in this new
host; full canonical world snapshots remain checked. No original C, historical
test/golden, unknown-byte compatibility policy or allocator implementation was
modified. Physical native zone operation traces are retained (environment:
16,097 operations; monster: 13,063 per profile). No universal equality of native
physical addresses/backing bytes with virtual-pointer EVM storage is claimed.

## Rejected oracle attempt retained

The new v1 environmental oracle used `leveltime == 1` as ST_Drawer's refresh
flag. Its controlled floor setup reset leveltime mid-level, incorrectly
forcing a full bar redraw at tic11. The EVM/world/palette checks passed, but
seven health-percent widget pixels differed at tics11/12. Original
`d_main.c:224–250` derives redrawsbar from display/wipe history;
`g_game.c:472–473` forces that history on actual loading, not floor damage.

The source-derived host display flag was corrected without a production
rendering change. The rejected `environment-hashes.bin`, its original manifest
entries/build identities and failed local output remain intact. A separate
`environment-display-hashes.bin` now records the corrected independent C
oracle; all 14 full world and ten complete frame/palette checks remain.
O0/O2/sanitizer results agree. `DEATH_LEGACY_LEVELTIME_REFRESH=1` reproduces all
42 rejected v1 hash words exactly; it is never used for acceptance. No native
golden was rewritten to match EVM output. Monster hashes stayed unchanged.

## Reproduction

Run from this feature worktree with authenticated local WADs/chunks available.
The browser command requires the user-owned exact Ultimate/DOOM II IWADs;
commercial resources and images are not shipped in the certificate.

```sh
python3 tools/reference/death_respawn/verify-native.py
python3 tools/reference/death_respawn/focused.py --cache-root artifacts/local/death-respawn/focus-cache
python3 tools/reference/death_respawn/focused.py --inherited --cache-root artifacts/local/death-respawn/cached
node --test web/input.test.mjs web/input-loop.test.mjs web/input-runtime.test.mjs web/menu-input.test.mjs
.toolchain/bin/forge build src/evm/Doom.sol src/evm/Doom2.sol --skip test --skip script --skip DeathRespawnProbe --out artifacts/local/death-respawn/production/out --cache-path artifacts/local/death-respawn/production/cache
python3 tools/reference/death_respawn/package.py artifacts/local/death-respawn/production
node tools/reference/death_respawn/browser.mjs --ultimate-wad artifacts/local/options/DOOM.WAD --doom2-wad artifacts/local/options/DOOM2.WAD
python3 tools/reference/death_respawn/native.py --output artifacts/local/death-respawn/native/commercial-O0 --opt O0 --commercial
python3 tools/reference/death_respawn/native.py --output artifacts/local/death-respawn/native/commercial-O2 --opt O2 --commercial
python3 tools/reference/death_respawn/native.py --output artifacts/local/death-respawn/native/commercial-sanitize --sanitize --commercial
python3 tools/reference/death_respawn/compare-browser.py
python3 tools/reference/death_respawn/certificate.py
git diff --check
```

Packaging also needs the unchanged ResourceStore artifact. This run reused the
main worktree's copied artifact and verified its metadata source identity.
`package.py` preserves the existing release templates/policy but streams large
cast-keccak input asynchronously; synchronous Node stdin stalled locally.
Forge's default gas limit remains unchanged. The new long multi-tic Forge
tests use a local aggregate 200-billion gas allowance; individual browser
transactions retain Anvil's 10-billion limit and 1-GiB memory allowance.

## Cache investigation and agent guide

Copied `/Users/eduard/sandbox/doom-evm/cache` and `out` into this goal's local
cache directory, never writing the source worktree. The first inherited run
compiled changed roots and passed 85 tests (768.86 seconds total, 764.06 seconds
compiler time). The warm focused inherited run passed 85 tests in 3.68 seconds.
The production warm build reported `No files changed, compilation skipped`
and took 0.046 seconds. A subsequent changed test compiled one file in 1.10
seconds. These are individual measurements, not a controlled cold/warm speedup
benchmark. Source invalidation and metadata identity were checked.

The user-authorized successful-cache guide is added to AGENTS.md. It requires
copying both cache and artifacts, matching toolchain/settings, independent
writable paths, Foundry source validation and explicit compile-root filtering.
The initial broad own compiler was stopped after its ownership was established;
all subsequent Forge runs finished. No external compiler/runtime was terminated.

## Ownership, interfaces and remaining dependencies

- Feature ownership: three production adapter files, dedicated probe/tests,
  fixtures and tools, regenerated browser artifacts/pins, this report and the
  acceptance certificate. The probe's controlled configuration is test-only.
- Integrator review: adopt Doom/Doom2/EpisodeRuntime changes together and both
  regenerated browser artifact sets; the getter's new selector must accompany
  the matching bytecode. Existing menu/input/Frame APIs and resource schemas
  are unchanged. AGENTS cache guidance is handed off as a separate change.
- Save/Load: no slots/serialization were implemented and its worktree was
  untouched. GameState, InputRuntimeState, UIState, MenuState and EpisodeState
  storage layouts are unchanged. EpisodeAux/DeathFlow are ephemeral. A future
  load/save action must retain original reborn-before-gameaction ordering; do
  not serialize a replacement startup or reset RNG on rebirth.
- Options: original selected gameskill/gamemap are authoritative at reload;
  menu selection is used only for NEW GAME. Messages/view size survive and
  dead/post-rebirth menu navigation remains owned by M_Menu. Ordinary menu
  packets retain the inherited frozen-world adapter, including its UI clock
  adaptation; they are explicitly excluded from native gameplay command tapes.
- Full Video: existing ST/HU/indexed draw and Frame/FramePalette events are
  reused. Original melt code and accepted recording runners are unchanged.
  Production melt orchestration remains the documented separate integration
  dependency; this feature does not claim browser melt playback.
- Coverage limits: Chrome demonstrates E1M1 and commercial MAP07 at UV,
  not every map/skill combination. Existing E1M1–M9 and MAP01–32 support domains
  and original skill behavior remain. Ultimate E2–E4, legacy Phase3 startup
  without G_Ticker, sound/music/multiplayer and arbitrary unsupported memory
  bytes are outside this feature. No claim of relaxed rendering is made.

Verification checkpoint completed 2026-10-11 19:09:44 UTC. Goal service at
19:08:57 UTC reported 492,019 consumed tokens and 5,269 elapsed seconds; no
monetary usage attribution was available. Final Gitmoji commit identities and
clean-tree handoff are recorded below and in the final response. Stop after
handoff; do not merge or push main or start later feature work.

## Git handoff

Implementation: `3b3fd15607d9f48846a8cf0da4ae1ea8bf21b420`
(`🐛 Integrate original single-player death and rebirth`). Cache guide:
`14251b6e998fecccaab8c265f92ef4ad8c933109`
(`⚡ Document verified Forge compilation cache reuse`). The final documentation
and evidence commit follows these without squashing or rewriting history;
its exact SHA is supplied in the handoff response.

After tests, one extra trailing blank line was removed from the test-only
probe to pass `git diff --cached --check`. Its compiled metadata source hash
was checked against final source plus that single newline; there is no semantic
change. Production browser-source hashes still match the accepted run exactly.
Final report/link/format checks passed. No main/other-worktree writes, merge,
cherry-pick or push occurred. No feature runtime remains from the accepted
session; unrelated Chrome/runtime instances were preserved.
