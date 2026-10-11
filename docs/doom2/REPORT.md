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
