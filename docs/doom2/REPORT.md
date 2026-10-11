# DOOM II compatibility and browser handoff

Start: 2026-10-11T10:15:55.300902+00:00. Owner: single DOOM II agent.
Worktree: `/Users/eduard/sandbox/doom-evm-doom2-browser`.
Branch: `feat/doom2-browser`; clean baseline `3cc536dff6c84194bf3784d9183e0d082a2bcf0e`.

Authorized scope: classic DOOM II 1.9 resource admission, commercial source-derived
startup/gameflow/UI, MAP01 first then MAP07 investigation, two authentic DSDA
single-map replays with all EVM gameplay tics/frames, isolated deployment adapter,
menu support, focused verification and handoff. No main writes/pushes, episode-wide
suite, audio/music/multiplayer, relaxed rendering, unknown-byte substitution or
commercial payload distribution. Virtual pointers stay explicitly opt-in.

Ownership: this branch/worktree and new DOOM II files. Shared source additions
must be gated on commercial mode and provided to the Git integrator; existing
browser installer/launcher files remain untouched for the Ultimate agent.
Existing shared state/ABI/Frame/resource schemas remain frozen where possible.
Dependencies: pinned linuxdoom-1.10 at a77dfb96cb91780ca334d0d4cfd86957558007e0,
existing gameplay/renderer, authenticated resource pipeline, native startup/speedrun
oracles, browser installation/menu APIs and local pinned toolchain.

Planned owned runtime ports: 19071 (Anvil), 19072 (browser); refuse occupied
ports and stop only spawned instances. Reserved 18880/8088 remain untouched.
Verification gates: exact resource hashes; native/EVM MAP01 startup geometry,
spawn/player/zone chronology; MAP07 compatibility; commercial routes/skills/menu;
storage persistence/rollback; two completed authentic original-C/EVM replays,
frame provenance and supported native pixel comparisons; 35 FPS local media;
independently possible browser adapter verification. Full 32-map correctness is
not inferred from two demos. Infrastructure limits may be measured and adjusted.
Stop: verified feature commits, clean tree, exact SHAs/commands/evidence hashes,
explicit unsupported domains and final combined-wiring requirements for integrator.

Initial inspection: existing P_Setup handles MAPxx names and commercial monsters;
P_Enemy contains additional monster actions and MAP07 boss triggers; P_Pspr,
P_Inter and P_User contain commercial Super Shotgun behavior. G_Game admits only
Episode One; WI_Stuff and F_Finale have restricted Episode One domains. The current
production Doom inherits Freedoom-only resource/startup admission. The installer
already hashes classic DOOM II but disables installation/play.

Local commercial resource identity is recorded in
[metadata only](../../artifacts/doom2/iwad-identity.json); payloads stay ignored
under artifacts/local. The rerelease IWAD is not used.

## Verified compatibility/startup checkpoint

Exact classic packing validates all 32 map resource directories. Separate
Doom2WadResources and Doom2Startup retain exact chunk/directory/identity
reauthentication and existing P_Setup/DoomGame/zone startup chronology.
Commercial G_Game additions admit maps 1–32, preserve original SKY3/SKY1/SKY2
lookup order and commercial completion destinations/par times. These shared
changes require integrator reconciliation; Freedoom/Ultimate supported E1
branches remain unchanged.

MAP01 native UV Speed (Oree, DSDA-Doom cl2) completes tic 192; MAP07 native
UV Speed (Sedlo, original Doom2 1.9) completes tic 237. Full gameplay snapshots
agree across O0/O2/ASan+UBSan/allocation-fill profiles. Decoder bytes match the
extracted original G_ReadDemoTiccmd. VERSION109 demos remain incompatible with
the unmodified VERSION110 stock loader; the declared harness uses the original
command reader/ticker without changing VERSION. IWAD recording identity is
inferred by successful exact pinned-IWAD replay, not an author signature.
The initially inspected MAP07 DSDA-Doom demo was Pacifist 3.40, not 34 seconds;
its actual native evidence is preserved locally as an alternative. The selected
archive includes two recordings; only lv07-006.lmp is replayed.

Real isolated Anvil startup acceptance compares five full native observations:
world/geometry/actors/player, collision/grouping, normalized live allocator
headers/owners, flow and difficulty. MAP01 and MAP07 both match after storage
round-trip. Startup receipt gas: 998,942,589 and 917,277,591 respectively.
All 889 resource CREATE runtime bytes are checked; eleven mined rejection
receipts prove whole-storage-root rollback and no emitted logs. The denied local
socket attempt remains separate failed evidence. Accepted evidence:
[startup](../../artifacts/doom2/startup-evm-accepted.json),
[native metadata](../../artifacts/doom2/startup-native.json).

Commands:

```sh
node tools/reference/doom2/pack.ts ~/Downloads/doom-steam/base/doom2/DOOM2.WAD
python3 tools/reference/doom2/native.py artifacts/local/doom2/MAP01 --wad ~/Downloads/doom-steam/base/doom2/DOOM2.WAD
python3 tools/reference/doom2/native.py artifacts/local/doom2/MAP07 --wad ~/Downloads/doom-steam/base/doom2/DOOM2.WAD
python3 tools/reference/doom2/startup-native.py
.toolchain/bin/forge build src/support/Doom2StartupProbe.sol src/support/Doom2SpeedrunProbe.sol src/evm/ResourceStore.sol --offline --no-lint
node tools/reference/doom2/startup-evm.mjs --port 19071 --output artifacts/doom2/startup-evm-accepted.json
```

EVM full-tape rendering, commercial UI/menu, final browser adapter and final
handoff remain pending at this checkpoint. No complete DOOM II correctness claim.

## Verified commercial lifecycle and menu

The final Doom2 contract is an isolated resource/startup deployment adapter copied
from the existing Doom adapter. It reuses the same source-derived gameplay,
visibility, renderer, UI, input and EpisodeRuntime. No alternative game engine,
Frame ABI, execution budget or memory reconstruction was introduced.
The pinned classic resource constructor and startup select gamemode2 explicitly.
All32 maps at medium skill pass native/EVM startup, including five complete
observations and stored-state recomputation; this adds startup coverage only,
not32-map playthrough or rendering acceptance.

G_Game adds commercial sky lookup order, cpars, normal exits, MAP15→MAP31,
MAP31→MAP32 secret exits, and MAP31/MAP32→MAP16 normal returns. The original
secret-switch missing-default behavior is preserved. Commercial MAP08 does not
trigger the Episode One finale, and MAP09 does not become an Episode secret map.
The G_WorldDone overload invokes the original commercial finale boundary on6,
11,20,30 and secret15/31. Continuation from supported commercial text uses
GA_WORLDDONE and the stored next map. No map is chosen by browser JavaScript.

WI_Stuff adds INTERPIC/CWILV00–31, commercial no-animation/RNG branches,
skips the location-screen timer after stats, retains the original ten-tic
NoState completion, and suppresses the entering title before MAP31. The original
Episode One loader remains the default overload. WI_Start binds commercial mode;
unadmitted/mid-context mode changes still reject, preserving inherited guards.
F_Finale adds exact C1TEXT–C6TEXT and the original flat lookup, commercial button
skip after finalecount>50, and continuation. MAP30 text renders; F_StartCast is
unsupported and rejects at that boundary. No invented post-MAP30 progression.

MenuState's explicit commercial flag makes New Game go directly to the original
five-skill screen, remembers map/skill, retains Nightmare confirmation and
Escape/Resume. Select Level is the existing EVM font extension, paged eight rows
across MAP01–MAP32; it is not an original-C menu screen/pixel-equivalence claim.
Original skill patches, skull, title background and keyboard semantics are reused.

[The memory policy](MEMORY-PROFILES.md) distinguishes baseline wiring from the
requested common policy. Doom2.initializeMenu(bool) retains profile2;
initializeMenuWithMemoryProfile(bool,uint8) explicitly selects0..3. The browser
adapter explicitly calls that API with3, keeps profile identity in its journal,
and refuses a discovered installation with another selected policy. Default
Z_Init, knownness/provenance0–5, virtual address domains, all draw guards and
unknown-byte rejection remain unchanged. Strict and profile2 MAP01 attempts
remain failed at tic75 with rollback; they are diagnostic runs, not browser defaults.

132 focused Forge tests pass. The new commercial gameflow fixture contains266
original-C cases with O0/O2/ASan+UBSan agreement. Commercial UI covers36
intermission scenarios/252 snapshots with complete state, RNG, latches,
dirty rectangles, background and64000 pixel comparisons; six finale texts have42
complete native pixel/state captures. Existing Episode One menu/intermission/
finale,64 enemy/action tests and original Super Shotgun tests pass unchanged.
The first focused run's111 passes/two failures are preserved; neither inherited
assertions nor native goldens were weakened. Only the new large test batch was
split into separate transactions to retain every case within the memory limit.

Production EVM menu acceptance:36 input transactions,27 Frames, all five actual
skills on MAP01, menu launches on MAP07/MAP15/MAP31/MAP32, fresh inventory,
Escape pause/Resume, persisted virtual flags, and four whole-storage-root rollback
receipts. Underfunded first startup retries successfully with the same sequence.
Maximum measured Frame/input gas is3,141,197,557 under the unchanged10B budget.
Default profile2 and unsupported profile rejection are independently checked.
Evidence: [menu transactions](../../artifacts/doom2/menu-evm.json),
[all-map startup](../../artifacts/doom2/startup-all-evm.json),
[focused tests](../../artifacts/doom2/focused.json).

## Two authentic complete recordings

| Map / DSDA author | Original recording | Native/EVM tics and EVM Frames | 35 FPS duration | Native pixel domain |
|---|---|---:|---:|---|
| MAP01 / Oree | lv1x549.lmp |192 |5.485714s |191 whole Frames exact; one provenance5 destination excluded |
| MAP07 / Sedlo | lv07-006.lmp |237 |6.771429s |237 whole Frames exact in the measured native profiles |

Each input retains its exact original archive/demo hashes and author notes in
metadata. Each tic executes original source-derived gameplay inside EVM and
compares full native snapshots, then renders a separate genuine mined EVM Frame.
Saved gameplay remains unchanged after each capture. Final stored state reaches
the genuine GA_COMPLETED and matches the original exit, with no cheats or fabricated
input tape. Native inputs never supply gameplay/visibility/pixels to EVM.

Original native gameplay agrees in O0/O2/sanitizer/allocation-fill profiles.
Every Frame has independent O0/O2/sanitizer original-C captures. MAP01's native
frame75 varies with native process pointer representation; all12,287,999 common
supported pixels outside its one virtual destination match. MAP07 checks all
15,168,000 pixels across237 Frames. That finite result does not make arbitrary
native heap addresses universally portable. The exact sampled MAP01 owner slot
2166, header/physical offset, stride8 and native pointer representation are
independently proved in all three native profiles. Virtual provenance remains
an explicit compatibility extension, not native byte equality.

Independent receipt/state/provenance/palette/PNG/MP4 verification passes for both
recordings. Total measured receipt gas including resources/startup/gameplay/
captures:170,093,019,099 (MAP01),190,466,850,012 (MAP07). Replay wall times:
211.227s and204.234s, including RPC/comparison/capture IO. These are offline
35 FPS encodings; neither video duration nor compiler/budget settings imply
real-time EVM performance. MP4s, pixels, raw states, commercial resource bytes
and full receipts remain ignored and local. Contact sheets were visually inspected.
Evidence: [MAP01 verification](../../artifacts/doom2/MAP01/verification.json),
[MAP07 verification](../../artifacts/doom2/MAP07/verification.json),
[pointer provenance](../../artifacts/doom2/MAP01/pointer-native.json).

Local videos:
`artifacts/local/doom2/MAP01/full-rate/speedrun-map01.mp4` and
`artifacts/local/doom2/MAP07/full-rate/speedrun-map07.mp4`.

## Independently verified browser adapter

web/doom2-profile.mjs and web/doom2-install.mjs reuse prepareResources and
BrowserInstaller's ordinary CREATE, exact nonce journal, recovery, canonical
receipts, IndexedDB, endpoint locks, resource/runtime authentication and menu
configuration. The packer filename adaptation authenticates the actual canonical
DOOM2.WAD manifest without changing packed bytes or shared resource schemas.
The separate release has851,408 runtime bytes and binds78 source files to
Solidity0.8.37, optimizer200, viaIR and Cancun. ResourceStore is the identical
existing artifact. The optional discovery palette reuses redistributable Freedoom
palette bytes with the same authenticated hash and DOOM II identity metadata;
no commercial IWAD, graphics, map geometry or Frame bytes are packaged.

The shared launcher, installer, menu client and original production Doom files
are untouched in this feature. Browser proof wires the adapter only in an ignored
website copy. This harness is not final combined launcher wiring. The Git
integrator owns profile-aware combined Freedoom/Ultimate/DOOM II wiring and the
corresponding explicit virtual production APIs for the other two game modes.
At this baseline Freedoom still uses profile2 and Ultimate Play is unavailable;
this feature does not silently alter those defaults or claim their integration done.

Final real Chrome/Anvil acceptance uses owned19073/19072, while the separate
EVM proof uses19071; occupied ports are refused. Nine Canvas checkpoints match
all indexed bytes, receipt-selected palettes and256000 expanded RGBA bytes.
Actual DOM keys start commercial New Game/MAP01, move the player, open the menu,
freeze movement, Escape/Resume and continue gameplay. memoryStatus reads
[3,1,1,1,1] from actual persisted state: explicitly selected virtual policy,
started game, deterministic initial bytes, bounded high bytes and virtual pointers.
No HTML gameplay/menu implementation is added; Debug remains collapsed.

Browser-only resource/game installation, interruption after eight resources,
lost send response after mining, real RPC disconnect, unmined transaction reload,
recovery, reload without transactions, missing-journal on-chain discovery,
same-chainId reset and owned-runtime restart pass. The new discovery guard also
rejects a ready profile2 installation. The initial socket-denied attempts and
missing test-payload/socket Node failures remain separate evidence. Final81
browser/transport Node tests pass; unchanged assertions are retained.
Evidence: [browser proof](../../artifacts/doom2/browser.json),
[Node tests](../../artifacts/doom2/node.json).

## Reproduction and limits

```sh
python3 tools/reference/doom2/acquire.py
node tools/reference/doom2/pack.ts ~/Downloads/doom-steam/base/doom2/DOOM2.WAD
python3 tools/reference/doom2/native.py artifacts/local/doom2/MAP01 --wad ~/Downloads/doom-steam/base/doom2/DOOM2.WAD
python3 tools/reference/doom2/native.py artifacts/local/doom2/MAP07 --wad ~/Downloads/doom-steam/base/doom2/DOOM2.WAD
python3 tools/reference/doom2/startup-all.py
python3 tools/reference/doom2/gameflow-native.py --check
python3 tools/reference/doom2/intermission-native.py
python3 tools/reference/doom2/finale-native.py
python3 tools/reference/doom2/focused.py
python3 tools/reference/doom2/observer.py
.toolchain/bin/forge build artifacts/local/doom2/observer/src/support/Doom2SpeedrunProbe.sol src/evm/ResourceStore.sol --out artifacts/local/doom2/observer/out --cache-path artifacts/local/doom2/observer/cache --offline --no-lint
node tools/reference/doom2/evm.mjs --artifacts artifacts/local/doom2/MAP01 --port 19071 --memory-profile virtual --output-prefix artifacts/local/doom2/MAP01/reproduction/evm
node tools/reference/doom2/evm.mjs --artifacts artifacts/local/doom2/MAP07 --port 19071 --memory-profile virtual --output-prefix artifacts/local/doom2/MAP07/reproduction/evm
python3 tools/reference/doom2/native-frames.py --source artifacts/local/doom2/MAP01 --output artifacts/local/doom2/MAP01/native-full
python3 tools/reference/doom2/native-frames.py --source artifacts/local/doom2/MAP07 --output artifacts/local/doom2/MAP07/native-full
python3 tools/reference/doom2/encode.py artifacts/local/doom2/MAP01/reproduction
python3 tools/reference/doom2/encode.py artifacts/local/doom2/MAP07/reproduction
python3 tools/reference/doom2/verify.py artifacts/local/doom2/MAP01 artifacts/local/doom2/MAP01/reproduction --native-frames artifacts/local/doom2/MAP01/native-full
python3 tools/reference/doom2/verify.py artifacts/local/doom2/MAP07 artifacts/local/doom2/MAP07/reproduction --native-frames artifacts/local/doom2/MAP07/native-full
.toolchain/bin/forge build src/evm/Doom2.sol src/evm/ResourceStore.sol --out artifacts/local/doom2/production/out --cache-path artifacts/local/doom2/production/cache --offline --no-lint
node tools/reference/doom2/package.mjs
node tools/reference/doom2/stage-browser.mjs
node tools/reference/doom2/browser.mjs --port 19073 --http-port 19072 --output-prefix artifacts/local/doom2/browser-reproduction/real
node tools/reference/doom2/menu-evm.mjs --port 19071 --output-prefix artifacts/local/doom2/menu-reproduction/evm
```

The complete historical Phase0–4 suite and full32-map speedrun coverage were not
run. Other maps' gameplay/rendering over time, every special combination,
multiplayer/audio/music and MAP30 cast are not accepted by these finite proofs.
Virtual reads remain restricted to proven address domains; genuinely unknown
bytes reject. No Relaxed Rendering, relaxed assertion, altered original C,
modified accepted golden, changed compiler/hardfork or new game engine is used.
Native UI resource borrowing is the existing declared adaptation, not a claim
of complete native UI allocation chronology. Peak interpreter memory, host
RSS/swap and monetary costs are not measured or estimated.


Final diagnostic tag correction: initializeGameStrict already selected strict
byte semantics; its new inspection tag now also reports profile0 instead of the
menu default2. The default menu policy remains2 and interactive browser explicitly
selects3. Fresh production/menu/browser evidence replaces the final acceptance
entry; earlier successful receipts/artifacts remain separately preserved.

The inherited browser lifecycle test leaves a synthetic18551 diagnostic config.
The goal's Node wrapper now restores the pre-test config/palette state, and its
isolated browser staging excludes diagnostic overrides and WAD payloads. One
final-browser attempt was interrupted before launcher acceptance; only its exact
parent and eight spawned child processes were stopped. This failed attempt and
cleanup identity remain separate. Shared launcher source and other owners were
not modified.

Verified implementation commit:9c5120db6c99110e91cc9ea279ab19a68fad18da.
Final verification/report checkpoint:2026-10-11T11:13:45.667359+00:00.
Available goal-tool attribution at this checkpoint:427,708 aggregate tokens and
3,474 elapsed seconds; missing monetary/approval/subtask measurements are not
estimated. Final evidence/clean-tree bookkeeping follows this checkpoint.
All owned Anvil/Chrome/site instances are stopped. No main merge/push, feature
push, published-history rewrite or automatic later goal is performed. Final
combined wiring remains the Git integrator's explicit responsibility.
