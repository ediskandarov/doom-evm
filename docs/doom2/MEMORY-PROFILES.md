# Browser memory-profile policy and current wiring

User steering on 2026-10-11 requires interactive browser gameplay to explicitly
select the existing experimental deterministic virtual-pointer compatibility
profile, consistently across Freedoom 0.13.0, Ultimate DOOM 1.9 and DOOM II 1.9.
Strict remains an independent diagnostic/native-fidelity scenario. No Solidity
or Z_Init defaults, unknown-byte rejection, arithmetic or render bounds change.
Shared browser files are owned by the parallel Ultimate agent and integrator.

| Game | Actual baseline browser wiring at 3cc536d | This branch / integration requirement |
|---|---|---|
| Freedoom 0.13.0 | BrowserInstaller calls Doom.initializeMenu(bool). Startup selects deterministic initial-zone bytes and bounded pointer-high bytes; virtual=false. Strict is not this default. | Integrator must explicitly select profile3 through a supported production initializer and update the common profile descriptor. This branch preserves Freedoom engine/browser defaults. |
| Ultimate DOOM 1.9 | File authentication only; Install/Play disabled. No default interactive profile exists. UltimateSpeedrunProbe.initializeMap(3,…) supports explicit virtual pointers in observational replay, not a production menu session. | Ultimate owner supplies production profile/API; integrator must explicitly select virtual in the common deployment configuration. No alternate initializer or runtime is inferred from authentication. |
| DOOM II 1.9 | File authentication only; no production runtime/profile exists at baseline. | New Doom2 adapter preserves initializeMenu(bool)'s inherited profile2 policy. Isolated deployment profile explicitly requests initializeMenuWithMemoryProfile(bool,uint8) with 3; this is the intended interactive browser profile. Actual MAP01 DOM keyboard/transaction/Canvas and persisted policy verification passes; evidence is cited in REPORT.md. |

Doom2.initializeMenuWithMemoryProfile preserves the inherited numeric policies:
0=strict (no assumed initial bytes), 1=deterministic initial-zone bytes,
2=those bytes plus bounded pointer-high support, 3=the existing experimental
zone and authenticated lumpcache owner-slot virtual representations.
Profiles outside0..3 reject. The adapter binds this selection to the same
Doom2Startup/DoomGame/P_Setup/EpisodeRuntime graph and persists all three policy
flags across game state reloads. memoryStatus exposes the actual saved flags.
It introduces no commercial special-case byte reconstruction.

The existing production Doom menu API cannot explicitly select virtual pointers;
that limitation was reported before extending the isolated DOOM II adapter.
The common initializer signature/descriptor is proposed for integrator adoption
across all three production artifacts. It does not make another agent's
unfinished commercial integration available. Existing test-only initializeMap
supports explicit profile3 for the new authenticated commercial speedrun host.

Strict MAP01 replay is a verification scenario through
Doom2SpeedrunProbe.initializeMap(0,1,3,false); it is never selected by this browser
adapter. It stops at tic75 after74 rendered Frames with DrawBounds and complete
storage rollback. The existing profile2 also stops at75. Their native gameplay
snapshots remain exact. The virtual run is separately recorded, explicitly
selected with --memory-profile virtual, with observation-only provenance events.

Virtual pointer bytes use the existing fixed zone and proven authenticated WAD
owner-slot address domains. They do not equal arbitrary native process addresses.
Native compiler/allocation-dependent pixels remain outside whole-frame equality;
all common supported pixels must still compare exactly. Provenance4/5 draw
samples retain physical/header offsets, field/slot identity, virtual address,
byte value, destination and whether the drawn value survives. Unknown or
unproven pointer fields and genuinely unsupported reads still reject.
No Relaxed Rendering, arbitrary unknown-byte fill, native-state injection or
native-rendered Frame injection is introduced.
