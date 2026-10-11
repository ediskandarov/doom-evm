# Browser deployment integration handoff

Integrated from `feat/browser-deployment` onto clean, synchronized main
`59522a545d1311924a28875a098892c5e27c113b`. The feature contains exactly
`730596452d8fa314e3e1f14ceaabfbf0fc425876` and
`a19716983df0ef1504010957a474a93f30e5bb6c`; neither was previously integrated.
Normal `--no-ff` merge `96bd1bbd8d27a47f29cc24f05c7833afde728f6f` preserves
both original commits. There were no conflicts or implementation edits.

The default webpage now offers local installation when its optional diagnostic
`config.local.json` is absent. After installation, Play hides that launcher and
passes the verified deployment to `openMenu` in `web/menu-app.mjs`. New Game,
skill/map selection, Escape/Resume, input sequencing, gameplay, palette selection
and indexed Frame rendering remain owned by the existing EVM implementation.
No HTML gameplay menu or host scene rendering is introduced. Explicit diagnostic
configurations retain their established paths.

## Release and runtime ownership

The two reduced browser artifacts match main's current compiled creation/runtime
bytes, immutable references and method identifiers exactly. Their compiler metadata
binds all 78 production source files to unchanged Solidity 0.8.37, viaIR,
optimizer 200 and Cancun settings. The Doom artifact's measured runtime is
**853,325 bytes**; use this fresh measurement rather than the earlier 848,394-byte
prose figure in the preserved source report. Engine sources, memory policies,
default selections, original C, tests and historical evidence are unchanged.
Experimental virtual pointers remain explicitly opt-in in their existing adapters;
the installer does not enable them.

Fresh acceptance uses a tracked-file copy of the merged website and runner under
`artifacts/local/browser-deployment-main/runtime`, not another agent's worktree.
Only authenticated, redistributable Freedoom is staged as an ignored site payload.
The runner checks port availability, binds Anvil/site to loopback, restricts RPC
CORS to the exact site origin, uses an unlocked disposable development account,
and owns/stops its Chrome, Anvil and site processes. Ports 18880/8088 and the
parallel full-video worktree are untouched. No private keys or commercial bytes
are committed. Local commercial File API checks retain hashes and availability
results only.

## Commercial Play dependencies

**Ultimate DOOM remains authenticated but unavailable for production Play.**
This is not a missing browser address or button: `Doom` inherits the Freedoom-only
`WadResources` constructor, whose 1,755 chunks, 3,163 directory entries and exact
directory/chunk/identity hashes reject Ultimate's 756 chunks and 2,306 entries.
`Doom._newEpisodeContext` also calls the Freedoom-only
`EpisodeStartup.initialize/validate`. Browser-only wiring cannot change either
EVM admission boundary.

Reusable exact Ultimate admission/startup already exists separately in
`UltimateWadResources` and `UltimateStartup`. Its `UltimateSpeedrunProbe`
accepts authenticated input tapes and emits observations/world captures; it has
no production menu/input session, persistent Status Bar/HUD, intermission/finale
lifecycle or complete menu-compatible browser ABI. It cannot substitute for
the production `Doom` contract.

A separately scoped production integration must supply an authenticated Ultimate
production artifact and profile, route both constructor admission and initial
Episode context through the correct exact resource identity, and retain the
existing driver/counter/storage/Frame interfaces. It must bind the original UI,
menu, raw input and EpisodeRuntime hooks to that same resource view, verify
retail E1M1–E1M9 startup/gameplay and normal/secret exits/intermission/E1M8 finale,
and declare/test its memory policy without silently enabling the experimental
profile. Then installer artifact pins, constructor dimensions/discovery, journal
release/profile identity and browser presentation labels must become explicitly
profile-aware. Validate installation, genuine movement and reload/recovery on
real EVM before enabling Play. A hash check alone establishes none of these.

**DOOM II remains authenticated but unavailable.** Only its local IWAD identity
is pinned in the launcher; no authenticated packed bundle/chunk/directory profile
or production adapter is integrated. `G_Game` initialization/lifecycle currently
rejects commercial gamemode 2, `WI_Stuff` excludes commercial intermission, and
`F_Finale` is restricted to Episode One. The menu's episode and nine-map domain
also differs from commercial startup. Required separate work includes exact
resource admission, MAP01–MAP32 startup and original commercial map/secret-route
progression, commercial menu/intermission/finale behavior, and native/EVM proofs
for the resulting gameplay/resource domain. Existing shared gameplay routines
are not thereby claimed incompatible or complete. No DOOM II engine work was
performed during this integration.

Both profiles retain disabled Install and Play after successful File API
authentication, with zero deployment transactions. Full historical acceptance,
commercial gameplay acceptance, and enhanced Status Bar/intermission/EVM melt
recordings remain separate goals. The nine technical Ultimate MP4s and accepted
frame/snapshot/provenance evidence are preserved.

## Verification attribution

The source agent's 62 tests, real Chrome/Anvil acceptance, six exact Canvas
checkpoints, interruption/reload/reset recovery and concurrency evidence remain
immutable under `artifacts/browser-deployment/`. Fresh results, command timing,
source/artifact checks, receipts and Canvas screenshots are recorded separately
under `artifacts/phase4/browser-deployment-main/`; the authoritative completion
entry in [the Phase 4 ledger](../PHASE4-PLAN.md) distinguishes these checks.
