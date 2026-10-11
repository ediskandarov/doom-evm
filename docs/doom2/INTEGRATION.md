# DOOM II integration handoff

Feature baseline:3cc536dff6c84194bf3784d9183e0d082a2bcf0e.
Owner/worktree:feat/doom2-browser at
/Users/eduard/sandbox/doom-evm-doom2-browser. No main modification, merge or push.
The final handoff commit SHA is reported to the integrator outside this file.
The first focused startup checkpoint is8ecbd51.

Integrate the feature commits without rewriting history. Reconcile shared
G_Game, M_Menu/MenuState, WI_Stuff/WiState/WiGraphics, F_Finale/FinaleState and
EpisodeRuntime changes with the Ultimate owner's work before repackaging any
production artifact. The original Episode One branches remain covered by the
unchanged native/inherited tests. Newly appended context fields and the larger
borrowed lnames array require fresh deployment; no storage upgrade is claimed.
The original G_WorldDone state-only overload is retained. Commercial production
uses the context/hooks overload for the synchronous F_StartFinale boundary.

The isolated Doom2.sol adapter reuses the existing menu/input/Frame/status/HUD/
Episode APIs and preserves their method selectors. Doom2WadResources authenticates
only the exact classic1.9 identity; Doom2Startup admits episode1/maps1..32/skills0..4
and uses original gamemode2. Resource schemas, Frame/FramePalette and raw packet
formats are unchanged. Shared gameplay/visibility/rendering functions and native
memory libraries are unchanged. Missing cast/native undefined-pointer domains
remain explicit rather than fabricating progression or unknown pixels.

New common initialization proposal:
initializeMenuWithMemoryProfile(bool fullscreen,uint8 profile), with unchanged
0=strict,1=initialized,2=bounded high,3=experimental virtual semantics.
Doom2.initializeMenu(bool) retains the inherited profile2 default.
The isolated DOOM II profile explicitly selects3; the contract never silently
enables virtual pointers. Apply that explicit deployment descriptor/API policy
consistently to the final Freedoom and Ultimate production artifacts. Their
baseline production APIs cannot select virtual yet; the Ultimate speedrun probe
is not a production menu substitute. See [actual baseline and target policy](MEMORY-PROFILES.md).

For combined wiring, make BrowserInstaller release pins, journal keys, discovery
profile/dimensions/palette and initialization signature/arguments profile-aware.
Use Doom2's supplied exact resource pins and precompiled artifact; retain the
existing nonce/receipt/recovery/endpoint-lock implementations. Add the isolated
prepareDoom2Resources filename adaptation or support wadName in the shared
packer, preserving the supplied canonical bundle hash. Route profile selection
to the supplied adapter and existing openMenu. Do not add a second installer,
HTML gameplay menu, host frame generation or game-mode-specific memory byte fill.
After packaging, do real browser acceptance for the final combined artifacts;
this branch verifies a goal-owned website copy with only the DOOM II adapter wired.

New web files only:doom2-profile.mjs,doom2-install.mjs,doom2-pins.mjs,
doom2-profile.test.mjs and doom2-assets/{Doom,ResourceStore,palette}.json.
Shared launcher/installer/menu files and existing Freedoom release artifacts
are untouched. Commercial IWADs/graphics/geometry/Frames/MP4s/raw receipts remain
ignored and local. The new palette payload is sourced from the existing
redistributable Freedoom palette, not copied from the commercial IWAD.

Verification handoff:

- All32 medium-skill map startups compare five native observations and actual storage.
- Two completed authentic DSDA original-C/EVM runs,192+237 gameplay tics/Frames,
  complete mined receipt/state/pointer/media proof and35 FPS local MP4s.
-266 commercial original-C gameflow cases;36 commercial intermissions/252
  snapshots;42 complete commercial text-finale pixel captures.
-132 focused Forge tests and81 browser/transport Node tests pass.
- Production menu:all five skills, MAP01/07/15/31/32 starts,27 Frames,
 36 inputs, four whole-storage rollback receipts and persisted virtual policy.
- Real Chrome:browser-local IWAD File API, ordinary resource/game CREATE,
  interrupted/uncertain/unmined recovery, persisted MAP01 movement/Escape/Resume,
 nine exact Canvas checkpoints, missing-journal discovery, reset/restart handling.

[Report and reproducible commands](REPORT.md).
[Evidence directory](../../artifacts/doom2).
No full32-map gameplay correctness, MAP30 cast, multiplayer/audio/music or final
combined-launcher release acceptance is claimed. No complete historical suite ran.
All owned runtimes stop after verification; playground18880/8088 and other owners
are preserved. Stop here; the main integrator owns final combined wiring and ledger.

Verified implementation commit:9c5120db6c99110e91cc9ea279ab19a68fad18da.
Final verification/report checkpoint:2026-10-11T11:13:45.667359+00:00.
Available goal-tool attribution at this checkpoint:427,708 aggregate tokens and
3,474 elapsed seconds; missing monetary/approval/subtask measurements are not
estimated. Final evidence/clean-tree bookkeeping follows this checkpoint.
All owned Anvil/Chrome/site instances are stopped. No main merge/push, feature
push, published-history rewrite or automatic later goal is performed. Final
combined wiring remains the Git integrator's explicit responsibility.
