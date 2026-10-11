# Ultimate DOOM browser deployment

Goal start: 2026-10-11 10:14:16 UTC. Owner: single Ultimate browser agent.
Worktree: `/Users/eduard/sandbox/doom-evm-ultimate-browser`.
Branch: `feat/ultimate-browser`; clean baseline
`3cc536dff6c84194bf3784d9183e0d082a2bcf0e`.

Scope: authenticated Ultimate 1.9 resource admission, production startup and
existing menu/UI/Episode lifecycle, profile-aware browser installation/recovery,
focused tests and real Chrome/isolated Anvil evidence. Main and DOOM II engine
work are excluded. Shared launcher changes must work for existing IWAD profiles.
The original C, engine algorithms, commercial resources, accepted tests/goldens,
compiler/viaIR/Cancun and Frame/input ABI remain protected.

Dependencies: UltimateWadResources/UltimateStartup identities, accepted owner-v1
memory domain, Doom/EpisodeRuntime/UI/menu, browser installer journal and release
artifacts. File MD5 checked before use:
`c4fe9fd920207691a9f493668e0a2083`.

Planned gates: affected production build; focused authentication/startup/menu/UI
Forge and Node tests; focused original-C/EVM frame comparisons; fresh Ultimate
Chrome installation, five skills, E1M1–E1M9, keyboard movement, Status Bar, genuine
exit/intermission, reload/reuse, interrupted resume, Freedoom switching and chain
reset. No nine-speedrun replay or full historical acceptance. Planned owned ports
19091/19092; refuse occupancy and never use 18880/8088. Stop only owned runtimes.

Stop condition: scoped gates verified, reproducible installation instructions,
small hash/receipt evidence with commercial bytes retained only locally,
Gitmoji commits and clean feature handoff. Integration into main remains owned
by the designated integrator; no merge or push main.

## Explicit interactive memory policy

The production adapter adds `initializeMenuWithPolicy(bool,uint8)` and
`initializeEpisodeWithPolicy(int32,int32,bool,uint8)`. Both use the same four
existing modes: 0 Strict, 1 initialized backing, 2 Episode pointer-high policy,
3 experimental deterministic virtual pointers including authenticated WAD owner
slots. `initializeMenu(bool)` and `initializeEpisode(...)` retain mode 2 and
legacy initializers remain unchanged. The selected policy is immutable for a
started session and visible through `resourceMemoryPolicy()` and the
`MemoryProfile(uint8)` initialization receipt event. Startup IWAD dispatch uses
`resourceProfile()` independently of memory policy.

Interactive browser configuration must explicitly request mode 3 through the
policy initializer. The same setting applies to Freedoom and Ultimate; it is
not inferred from the IWAD or enabled by a Solidity default. Strict remains
available through the policy API for diagnostics. No Relaxed Rendering is
implemented. Original backing/draw guards, owner validation and provenance
categories 0–5 are unchanged; existing observer telemetry remains intact.
Production Frame/FramePalette logs do not provide per-read provenance samples.

Mode 3 retains the accepted RESTRICT compatibility limitation: deterministic
zone links and validated WAD owner-slot addresses model virtual object identity,
not actual native process placement. Unknown owner domains, stale owner slots
and other unsupported memory reads still revert. Native-exact finite frames
are demonstrated only where compared; virtual bytes never imply universal
native pointer-byte or pixel equivalence.

DOOM II remains unavailable in this feature. The generic profile configuration
and policy initializer are the integration contract for its owner; no DOOM II
startup or browser gameplay verification is claimed here. Its owner must admit
exact authenticated resources and demonstrate mode 3 using the same API, or
report a supported-domain limitation without changing defaults or read guards.

## Verified feature handoff

Implementation checkpoint: `4ffe8a1d52fc87d58348f3ebc87c714c541c6622`
(resource admission/policy API), then
`d6fde98d02a41b5f0b12b97a61f7f6aa65c81e05` (browser deployment/profile wiring).
Verification checkpoint: `13a361d86551771ad5a8630354ba1c420cb770c6`.
The final documentation commit is identified by the clean feature branch tip and
the final handoff message. No main merge or push occurred; integration and final historical
acceptance remain with the integrator.

Production `Doom` now uses `ProductionWadResources`, a pinned admission adapter
for Freedoom and Ultimate. Original `WadResources`, `UltimateWadResources`,
`UltimateStartup`, all original-source engine libraries and observational
speedrun adapters are unchanged. Ultimate startup dispatch reuses the existing
world context, then binds the existing DoomUI/InputProtocol/EpisodeRuntime hooks.
The existing menu handles all selections; no separate launcher or game engine
was introduced. Resource identity keeps its selector and is now a view over the
constructor-authenticated profile. Existing method selectors and Frame/input
interfaces are unchanged; policy APIs and profile inspection are additive.

The browser release contains 79 compiler-authenticated source identities.
Solidity 0.8.37, viaIR, optimizer 200, Cancun, 10B gas and 1GiB interpreter memory
remain unchanged. Runtime: **862,541 bytes**, unpatched compiler runtime SHA-256
`f8ba946f13bb39328b8e95737ca716df3b03fedb132fc7af2e7b81dcd0310350`.
Driver immutables are patched and every runtime byte checked during discovery.
No resource/gas/memory limit increase was needed. Peak MSIZE/RSS/FPS were not
measured and are not inferred from finite successful Frames.

[Accepted real Chrome/Anvil run](../artifacts/ultimate-browser/accepted.json):
**2026-10-11T10:43:03.199Z–10:49:41.275Z**, Chrome 155.0.8059.40,
owned ports 19151/19152, **34 checks and 24 complete Canvas comparisons**.
All 64,000 indexes, EVM-selected palette bytes and 256,000 expanded RGBA bytes
agree at every captured Frame. All five skills including Nightmare confirmation,
all E1M1–E1M9 selections, keyboard movement and persistent Status Bar pass.
Original skill screen and first E1M1 gameplay/Status Bar agree with the focused
original-C O0/O2/ASan-UBSan oracle. Screenshots were visually inspected and remain
local, along with all commercial frame/resource bytes.

Fresh installation uses **756 resource CREATEs + one game CREATE + one explicit
policy-3 menu initialization**, **2,985,360,725 total installation gas**.
[Canonical installation receipt metadata](../artifacts/ultimate-browser/installation-receipts.json)
contains no payloads; the full local journal hash is retained in the accepted
report. Largest captured input/Frame gas: **4,055,289,948**. This is scoped
coverage, not a throughput or universally native-exact rendering claim.

The genuine exit proof uses 273 original keyboard route tics with god/noclip
cheats, then movement/turn/use at authenticated E1M1 line 326 (special 11).
No host world/Frame, teleport/state injection or completion endpoint is used.
Original WI_Start reaches intermission (state 1, last 0, next 1), whose Canvas
matches the mined EVM Frame. This bounded route verifies production lifecycle;
the preserved nine speedruns supply independent authentic world exit evidence.
They were not replayed. Secret exits, complete E1M8 finale and full-episode
interactive progression were not newly accepted by this scoped browser run.

Interrupted upload, unknown-hash mined submission, real browser RPC failure,
unmined transaction across reload, resume, missing-journal discovery, same-chainId
reset/restart and resource/runtime reauthentication pass. Reload/discovery make
no deployment transactions. Freedoom is installed on the same chain, starts
through the same EVM menu with explicit policy 3, and renders actual gameplay.
Switching reuses both games with unchanged nonce; no resource or game redeploy
occurs. [Final stale-journal/lock proof](../artifacts/ultimate-browser/locks.json)
passes four checks, including reuse of eight resources with zero new transactions.

[Focused Forge](../artifacts/ultimate-browser/forge.json): **45 passed**;
[Node log](../artifacts/ultimate-browser/node.log.gz): **81 passed**, zero failed.
[Original-C proof](../artifacts/ultimate-browser/native.json) and
[source/ABI/resource/evidence certificate](../artifacts/ultimate-browser/verification.json)
bind the exact release and results. These gates cover affected authentication,
input/menu/video/lifecycle and owner-policy dependencies. No full historical
Phase 0–4 acceptance or all-nine-speedrun rerun was performed.

[Failed attempts](../artifacts/ultimate-browser/attempts.json) remain failed.
Sandbox socket refusals preceded escalated local runs. Two early browser runs
collided with a diagnostic config written by an inherited cleanup test; acceptance
now serves its own website snapshot, and WebSocket closure rejects pending CDP
commands. Their exact owned processes were stopped, with local partial evidence
retained. One route stopped outside use range; another over-tight route did not
settle. The corrected accepted route and its receipt/Frame are separate proof.
Other agents' runtimes, profiles, worktrees and files were preserved.

Measured handoff-preparation checkpoint: **2026-10-11 10:56:47 UTC**.
[Available goal-service usage](../artifacts/ultimate-browser/usage-checkpoint.json)
records **254,716 aggregate tokens and 2,551 elapsed service seconds** at that
checkpoint. Missing model/cost/approval/per-stage attribution is not estimated.
Final documentation/certificate checks and commits follow this checkpoint.
All owned acceptance runtimes are stopped; only ignored local resources/evidence
and redistributable staged Freedoom remain. Commercial assets are absent from Git.

Reproduction: [browser installation instructions](browser-deployment/README.md).
After preparing local test chunks as described there, run:

```sh
source scripts/env.sh
python3 tools/ultimate-browser/prepare.py
python3 tools/ultimate-browser/native.py
python3 tools/ultimate-browser/forge.py
node --test web/*.test.mjs tools/transport/protocol.test.mjs \
  tools/transport/palette.test.mjs tools/transport/ui-palette.test.mjs \
  tools/transport/lifecycle.test.mjs
node tools/browser-deployment/check.mjs --profile ultimate \
  --port 19091 --http-port 19092 \
  --output-prefix artifacts/local/ultimate-browser/reproduction
python3 tools/ultimate-browser/checkpoint.py
```

The certificate checks the frozen evidence; it does not rerun execution gates.
The inherited cleanup test generates a diagnostic `web/config.local.json`;
remove only that generated file before a normal manual launcher session, or
serve a website copy that excludes diagnostic configs as the acceptance runner
now does. The goal handoff leaves the default website in installation mode.

## Contract for the DOOM II integration owner

Use `BrowserInstaller.connect(endpoint, profile)` or
`selectProfile(PROFILES[index])` before discovery/installation. Profile fields
include `id`, `wadName`, `license`, `available`, optional bundled-file `url`, exact
IWAD/bundle/directory/ordered chunk hashes, `chunks`, `lumps`, and `memoryPolicy`.
Packing is independent of the game name. Journals bind release/IWAD/policy;
resource discovery verifies exact ResourceStore runtime and game constructor
bytes/directory/profile. Ready games with another policy are excluded; a ready
compatible game takes priority over an uninitialized duplicate. Palette RGB
identity is checked and its profile envelope is rebound on on-chain recovery.

Keep DOOM II unavailable until its exact constructor/startup/resource domain,
commercial menu/lifecycle and browser proofs pass. Set `memoryPolicy:3` and call
`initializeMenuWithPolicy(false,3)` explicitly; do not change legacy defaults or
infer policy from IWAD identity. Extend authenticated startup dispatch separately
from backing policy. `configuration()` carries profile/name/policy and the
unchanged driver/counters/resource identity/Frame transport. Constructor ABI
remains `(address[] chunks, bytes directory)` for this release. A new release
must package its artifact/source hashes and use its own journal release identity.
Existing deployments are not storage-upgraded or silently reconfigured.
