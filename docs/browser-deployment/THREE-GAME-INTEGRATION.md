# Three-game production browser integration

Integration owner: designated Single Writer to Main. Started 2026-10-11 11:27:14 UTC.
Clean synchronized baseline: `3cc536dff6c84194bf3784d9183e0d082a2bcf0e`.
Both completed feature trees were inspected read-only and remained clean.

## History and source preservation

Normal `--no-ff` merges preserve all checkpoints in order:

- Ultimate: `4ffe8a1d52fc87d58348f3ebc87c714c541c6622`,
  `d6fde98d02a41b5f0b12b97a61f7f6aa65c81e05`,
  `13a361d86551771ad5a8630354ba1c420cb770c6`,
  `f0a36ba765fa806e837b1f783e1827ad6bca65e2`;
  merge `42cd2ecf11e6a3aecf78a938898e543f3fa4c76a`.
- DOOM II: `8ecbd51b36d2081f5d84ba9eb7f3831199871f99`,
  `9c5120db6c99110e91cc9ea279ab19a68fad18da`,
  `399419ce2e86d548a55f250fd12c798a11a9f929`,
  `cfccc1044d5037a779d7dbe9d42e6f0f94863819`;
  merge `b4c812ff8cb06ac1a3bb57cb179bdfa59c6ace8d`.

Shared browser integration is checkpointed by `305e27f` (full SHA recorded in the publication manifest). Both merge bases equal the baseline. No duplicate or unrelated history, Git
conflicts, production Solidity edits beyond the merged features, original-C
changes, compiler changes or existing test/golden changes were introduced.
Historical source reports and certificates remain exact; their bindings are
checked against their original Git checkpoints. Current browser artifacts are
repackaged from combined main, rather than relabeling a source certificate.

## Shared browser boundary

`web/browser-profiles.mjs` selects the completed profile adapters.
BrowserInstaller accepts the authenticated release, admitted profiles, palette
location and profile initialization/inspection signatures. The DOOM II adapter
now delegates journal/discovery/recovery/nonce/lock/runtime/resource checks to
that same manager. Its legacy one-argument initializer adaptation is retained;
an already explicit two-argument initializer is passed unchanged.

The shared packer accepts the exact `DOOM2.WAD` filename/license directly,
retaining the canonical bundle, directory, resource bytes and ordered chunk
hashes. This removes the isolated adapter's former `DOOM.WAD` filename bridge.
The browser File API authenticates commercial files in memory; no developer
filesystem path, commercial IWAD, extracted assets or generated video is shipped.

Installation/game selection is HTML. New Game, skill, level selection, gameplay,
Status Bar/HUD, Automap/Cheats and menus use existing EVM adapters and Frames.
**Change game** stops input, waits for the current transaction and reloads the
page, disposing the old keyboard/subscription client. The selected game is
remembered within the tab; reconnection remains explicit. A new game client uses
its own address, resource identity, counter, runtime release and policy journal.
Identical authenticated resource contents may reuse addresses across profiles;
player/storage/input state remains separate.

| Game | Authentic identity | Supported production domain | Resource chunks |
|---|---|---|---:|
| Freedoom 0.13.0 | SHA256 `7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d` | Episode One, E1M1–E1M9, five skills | 1,755 |
| Ultimate DOOM 1.9 | MD5 `c4fe9fd920207691a9f493668e0a2083`; SHA256 `6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f` | Episode One, E1M1–E1M9, five skills | 756 |
| DOOM II 1.9 | MD5 `25e1459ca71d321525f84628f45ca8cd`; SHA256 `10d67824b11025ddd9198e8cfc87ca335ee6e2d3e63af4180fa9b8a471893255` | Commercial mode, MAP01–MAP32 naming/selection, five skills | 889 |

Both commercial MD5/SHA256 identities were independently measured locally.
Installation completion rechecks every resource/runtime byte, canonical receipt
and IWAD/palette identity. Journals bind endpoint/genesis/driver/release/game/policy.
The endpoint lock remains shared across game installers; lost submission responses
retain exact nonce/data recovery. Missing journals use bounded ordinary-CREATE
discovery; deployments of older incompatible releases are not storage-upgraded.

Browser gameplay explicitly selects profile 3 via
`initializeMenuWithPolicy(false,3)` (Freedoom/Ultimate) or
`initializeMenuWithMemoryProfile(false,3)` (DOOM II). Both deployed Solidity
initial values and legacy `initializeMenu(bool)` defaults remain profile 2.
Strict, deterministic initialization, Episode policy, experimental pointers,
provenance and unknown-byte guards remain intact. No Relaxed Rendering or
arbitrary unknown-byte substitution. Main's memory libraries are byte-exact to
baseline; defaults and MAP30 guard are exact to the feature sources.

The compiled Episode adapter runtime is **869,382 bytes** (79 source identities),
DOOM II **851,408 bytes** (78), ResourceStore **57 bytes**. Solidity 0.8.37,
viaIR/optimizer200/Cancun/10B gas/1GiB memory remain unchanged. Episode runtime
changes because the merged commercial UI/state libraries are included. DOOM II
creation/runtime bytes remain exact to its source artifact; only compiler-symbol
immutable reference IDs change in the combined compilation. Immutable spans and
runtime driver patching are reauthenticated, and public selectors are unchanged.

## Inherited verification and limitations

[Ultimate source report](../ULTIMATE-BROWSER.md): 45 Forge tests, 81 Node tests,
34 Chrome/Anvil checks and 24 complete Canvas comparisons, five skills, nine
map selections, bounded genuine exit/intermission and native menu/first-gameplay
comparisons. All nine existing authentic Ultimate speedruns remain preserved:
14,475 EVM-rendered gameplay frames, 14,484 exact snapshots, nine genuine exits.

[DOOM II source report](../doom2/REPORT.md): all 32 map startups, 132 Forge tests,
81 Node tests, commercial menu/lifecycle/native UI proofs and real MAP01 browser
play. The accepted MAP01/MAP07 authentic full-rate EVM runs remain untouched:
192/237 gameplay tics/Frames and genuine completions, complete gameplay snapshots,
35 FPS local MP4s. MAP01 frame75 has one virtual owner-byte destination excluded
from native pixel equality; its other 12,287,999 pixels agree. MAP07's 15,168,000
pixels agree across its finite native profiles. All commercial video/frame bytes
remain local. Seventeen preflight-bound historical MP4s were read-only hashed.

These are finite declared native-profile proofs, not universal native heap/pixel
equivalence. Deterministic virtual zone/owner addresses retain their explicit
provenance and RESTRICT applicability. Existing native undefined-memory/profile
limitations remain preserved in the reports. Source evidence does not imply
32 complete DOOM II playthroughs. **MAP30 text is supported; the unported cast
sequence rejects at its existing F_StartCast boundary.** No host-rendered cast,
audio/music or multiplayer is introduced.

Ultimate Episode gameplay/full-rate world rendering complete. Final presentation recording pipeline pending: EVM status bar, original intermission, and EVM melt transitions.

The parallel full-video worktree/branch/runtime was not modified or merged.
No new recordings, full speedrun replays or complete historical Phase 0–4
acceptance were run. Full regression remains deferred to final acceptance.

## Fresh combined-main verification

Fresh accepted run: **2026-10-11T11:52:23.270330Z–12:00:23.869963Z**,
owned ports **19171/19172**, Chrome 155.0.8059.40, Anvil v1.8.5. All processes
were stopped and both ports independently checked closed. No playground access.
[Fresh metadata](../../artifacts/phase4/three-game-browser-main/chrome.json)
records **21 checks and 20 complete Canvas comparisons**, each 64,000 indexed
pixels, receipt-selected palette bytes and 256,000 expanded RGBA bytes.

All three actual installation→EVM menu→New Game→first-map starts and keyboard
movement pass. Switching/reload/Play reuses the same three contract addresses,
resource identities, policy journals and stored players. Other games' player
states remain unchanged. Every switch-created transaction targets the selected
game; no resource/game CREATE occurs. Browser reload remembers DOOM II and
read-only discovery emits no transactions. Interrupted DOOM II upload and a
real mined CREATE with a lost response recover exact nonces without duplicates.
The first eight selected chunks are verified even when the shared authenticated
content cache already contains resources from earlier games.

Each deployed contract reports default policy 2 immediately before its real
explicit policy-3 initialization. Every installed/current browser configuration
and stored profile reports 3; DOOM II additionally reads memoryStatus=[3,1,1,1,1].
Actual same-chainId reset rejects all three stale runtimes and disables Play.
This run's changed genesis keeps old records under their distinct keys and opens
fresh journals; changed-anchor archival remains covered by the focused Node gate.
The production browser does not invoke reset; only the owned acceptance runner does.
Exact-origin CORS allows the localhost site and does not grant an arbitrary origin.

Fresh installation operations/gas:

| Game | New resource CREATEs | Game CREATE + explicit initializer | Recorded installation gas |
|---|---:|---:|---:|
| Freedoom | 1,755 | 2 | 6,617,758,188 |
| Ultimate | 756 | 2 | 2,986,873,121 |
| DOOM II | 888 (one authenticated prior resource reused) | 2 | 3,484,642,152 |

These are finite installation measurements, not live FPS, peak-memory or cost claims.
First gameplay indexed hashes for **all three games** equal their previously
accepted source checkpoints; [read-only comparison](../../artifacts/phase4/three-game-browser-main/initial-frame-compatibility.json).
No historical hash was changed. Ultimate and DOOM II screenshots were visually
inspected; screenshots/commercial Frames and exact journals stay local, with
hashes in the metadata. No video was regenerated.

Other fresh gates: one affected-root build (**82 modules, 244.327 seconds**),
**18 focused Forge tests** (8 Episode/commercial menu + 10 existing Episode
gameflow), **71 focused Node tests**, 6 final release/adapter checks (repeat
coverage, not six additional distinct tests), 10 changed-module parses,
compiler-source Keccak/pinned-release/ABI/immutable-span checks, original Git
certificate bindings, protected memory/default/cast/source and document checks.
No fresh native recompilation, nine Ultimate replays, complete DOOM II replays,
all32 startup rerun or historical Phase0–4 acceptance.

Two new-harness failures remain separate in [attempts](../../artifacts/phase4/three-game-browser-main/attempts.json):
(1) total cache entries were incorrectly treated as selected-IWAD chunk count;
(2) a changed-genesis fresh journal was incorrectly required to have an archive
counter. Corrected selected-chunk/nonce and genesis-key/anchor assertions retain
all meaningful acceptance conditions; no production change or inherited assertion
was needed. The initial DOOM II packer interface failure was fixed in the browser
adapter using the exact accepted manifest. Failed attempts are never relabeled green.

[Publication manifest](../../artifacts/phase4/three-game-browser-main/integration.json)
and `python3 artifacts/phase4/three-game-browser-main/verify.py` bind current
source/releases, preserved original evidence, accepted checks and ledger.
The original Ultimate/DOOM II extensive verification remains inherited evidence.

Publication usage checkpoint: **2026-10-11 12:03:21 UTC**; measured wall interval **2,167 seconds**, goal-service **240,647 aggregate tokens / 2,155 elapsed seconds**. Missing cost/model/subtask/approval attribution is not estimated. Final Git publication follows this checkpoint.
