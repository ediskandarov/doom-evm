# Browser-managed deployment goal

Start: 2026-10-11 09:18:00 UTC. Owner: single browser-deployment agent.
Worktree: `/Users/eduard/sandbox/doom-evm-browser-deployment`.
Branch: `feat/browser-deployment`; clean baseline and integrated main: `59522a545d1311924a28875a098892c5e27c113b`.

Scope: browser-local authenticated IWAD preparation, precompiled production artifact delivery, localhost Anvil compatibility checks, verified resource reuse, durable resumable installation journal, launcher, existing EVM menu/input/Frame integration. No engine algorithms, shared Solidity interfaces, native oracle, main worktree, shared ledger or video runtimes are modified.

Profiles inspected: production Doom/WadResources admit Freedoom 0.13.0; UltimateWadResources/UltimateStartup/UltimateSpeedrunProbe admit Ultimate 1.9 in an observational speedrun adapter. Main explicitly records production Ultimate resource/UI wiring pending. No integrated DOOM II deployment/profile exists. Commercial selection will authenticate locally and report production availability honestly; no commercial bytes shipped or sent externally.

Dependencies: pinned production Doom and ResourceStore artifacts, existing Freedoom pipeline and original Frame/menu/input client. Freeze shared ABI unchanged. Build/package source hashes bind the browser artifact to this checkpoint.

Verification gates: focused browser installer security/resource/journal tests; inherited affected browser transport tests; real isolated Anvil and real headless Chrome installation, menu keyboard New Game/gameplay, reload without CREATE, interruption/resume, RPC interruption/uncertain transactions, reset with same chain ID, local commercial File selection. No Computer Use or full historical acceptance. Planned owned ports 18991/18992 (refuse occupancy; forbidden playground ports 18880/8088). Stop owned runtimes only.

Stop condition: verified implementation, reproducible instructions, preserved separate evidence, Gitmoji commits and recoverable handoff; no merge or push main. Missing coverage or unavailable profiles remain explicit.

## Implementation and boundaries

The website's default path is now a launcher when no diagnostic `config.local.json` exists. Existing explicit transport configurations and their historical tests are preserved. Launcher HTML manages connection/profile/File selection/install/progress/retry/Play only. Play hides the launcher and delegates the complete keyboard/menu/Episode/Frame path to the existing `openMenu` client. No HTML New Game, level, skill or gameplay menu was introduced.

`install-resources.mjs` performs bounded IWAD directory decoding and the exact existing concatenated-lump/canonical-manifest packing adaptation. It authenticates WAD SHA-256 before parsing, then canonical bundle, directory, ordered STOP-prefixed chunk hashes and palette. Production WadResources reauthenticates all chunks/directory during ordinary CREATE. No host gameplay, visibility, indexed frame or fabricated scene state is supplied.

`install-pins.mjs` binds reduced Doom/ResourceStore bytecode/runtime/immutable sites/method selectors to SHA-256. Release preparation checked 78 source identities against pinned compiler metadata using cast keccak and retained SHA-256 source attribution. Precompiled artifacts are committed; the redistributable Freedoom IWAD is staged as an ignored website payload. Solidity, ABI, compiler/viaIR/hardfork and original C remain unchanged.

`install-engine.mjs` accepts explicit HTTP loopback endpoints from loopback website origins, checks Anvil identity, unforked Cancun/31337, unlocked development account, balance and >=10B block budget. It neither uses injected wallet providers nor sends RPC configuration/reset/impersonation calls. Reproduction restricts Anvil's origin to the exact localhost site; the runner binds only owned loopback ports.

IndexedDB stores one atomic journal per endpoint, genesis hash, driver and release artifact. Installation is separate from input/game session state. Journals contain resource hashes/addresses, game identity/palette, operation receipts and at most one pending exact transaction. Commercial WAD/resource payloads are never persisted. An endpoint Web Lock excludes concurrent installation tabs. Completed resource operations are checked against live code; game runtime is compared byte-for-byte after patching the compiler's immutable driver sites, then its authenticated resource identity/receipt and every resource are checked.

Each operation reserves the live sender nonce and persists exact calldata before sending. Unknown-hash operations are located by sender/nonce and exact input/target in canonical blocks. Known pending transactions are awaited; consumed conflicting nonces/unrecoverable receipts are refused. Only a proven unused nonce can be retried, with the same nonce/data so late submissions cannot produce two mined operations. Canonical block/receipt hashes settle operations. First-operation anchors and genesis distinguish resets; old journals are preserved under orphan keys. A missing journal uses bounded on-chain discovery of this release's ordinary ResourceStore/Doom CREATE transactions and proves their live runtime bytes, constructor directory and game identity before reuse.

Limits: this is a dedicated localhost development runtime, not an Ethereum public-network deployment. Browser Web Locks/IndexedDB/secure-context crypto are required. On-chain discovery and uncertainty scans have a 10,000-block explicit cap, and unavailable/pruned canonical receipts block replay. Stable origin/RPC URL provides fast journal access; different origins can use on-chain discovery. Gameplay is the existing single-driver contract session, reused for New Game. Ultimate/DOOM II production Play remain unavailable, rather than presenting a speedrun observer as a playable menu runtime.

## Commercial input provenance and scope steering

Read-only local measurements:

| File | Size | MD5 | SHA-256 |
|---|---:|---|---|
| `~/Downloads/doom-steam/base/DOOM.WAD` | 12,408,292 | `c4fe9fd920207691a9f493668e0a2083` | `6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f` |
| `~/Downloads/doom-steam/base/doom2/DOOM2.WAD` | 14,604,584 | `25e1459ca71d321525f84628f45ca8cd` | `10d67824b11025ddd9198e8cfc87ca335ee6e2d3e63af4180fa9b8a471893255` |

The user's later message identified the classic DOOM II file and requested compatibility/native-EVM speedrun use. Its actual MD5 matches the supplied identity. A scope question was issued because the original installer goal explicitly excluded DOOM II engine work. Pending that answer, this goal authenticates local selection and records the verified file for subsequent compatibility work; it makes no DOOM II gameplay/native/speedrun claim. The rerelease files were found but not used. Freedoom and Ultimate engine sources/support are unchanged; no commercial bytes are committed, embedded, redistributed or sent to a website.

## Verification attempts

`attempt1` is retained as a failed gate. Browser-only resource/game deployment and initialization succeeded: 1,755 resource CREATEs, one Doom CREATE, one menu initialization, 6,614,091,135 cumulative gas. Initial menu Canvas matched actual EVM Frame/FramePalette. The initial keyboard harness stopped its loop and therefore disabled the genuine DOM handlers; its later labelled navigation frames were unchanged menu redraws. The assertion on actual Episode map failed. These labels confer no gameplay claim. The corrected harness keeps the real loop/input handlers active under controlled scheduling and asserts screen/map transitions and player movement. Failed report, receipts and screenshots remain separate.

Focused tests: 62 passed, zero failed, covering authenticated packing/artifact tampering/locality, exact nonce retry, known pending receipt recovery, conflicting/consumed nonce refusal, canonical/orphan receipt handling, reset anchoring, and inherited input/menu/Episode/legacy transport behavior. The first test run exposed a fetch-response compatibility issue in the inherited mock fixture; the production status check was corrected without changing tests or assertions. Final command/output is recorded in the verification manifest.


## Verified completion and handoff

Implementation commit: `730596452d8fa314e3e1f14ceaabfbf0fc425876` (Gitmoji). Integration: independent feature branch; **not merged to main**. Shared Phase 4 ledger is left to the integration owner. Changed files and complete source/evidence SHA-256 mappings are in [the verification manifest](../../artifacts/browser-deployment/verification.json). Source and artifact hashes match the final committed implementation in both the full and lock-specific real-browser checks.

[Final full browser/Anvil acceptance](../../artifacts/browser-deployment/accepted.json): **14 checks passed**, **6 full Canvas comparisons exact** against mined EVM Frame/FramePalette receipts. Measured start `2026-10-11T09:37:17.034Z`, end `2026-10-11T09:41:07.169Z`, elapsed **230.135 seconds** for the complete acceptance run (including interruptions, gameplay, discovery, commercial checks, reset and restart). Browser `Chrome/155.0.8059.40`; Anvil version and CLI limits are retained in the manifest/report. Installation: **1,755 resource CREATEs + one Doom CREATE + one menu initialization**, **6,614,091,135 cumulative gas**. The authenticated contract runtime is 848,394 bytes. No throughput/full-episode/native-exactness claim is inferred from these six Frames.

[Installation receipt journal](../../artifacts/browser-deployment/accepted.installation.json) SHA-256: `d4804dd82661eda986cf5237d8e99dd63af245d5320e8d53fb86e39188b976ac`. Runtime address `0x5ae1f4bb68f8eac39cfdbdfda2b7344ccbd80faf` belongs only to the stopped disposable acceptance chain; it is **not** a manual installation prerequisite. Reload and missing-journal discovery both left the live driver nonce unchanged. New Game reached E1M1 through original browser keyboard/menu events; held movement changed stored player position and produced authenticated gameplay Frames. Commercial File API checks proved exact Ultimate and classic DOOM II SHA-256/MD5 identities, disabled unsupported production Play and sent no transactions. Same-chainId reset cleared the actual game code and discovery rejected the stale installation; a new owned Anvil also reported no false installation.

[Focused concurrency browser check](../../artifacts/browser-deployment/locks.json): stale second installer refreshed the journal after acquiring endpoint ownership and reused all eight previously uploaded resources with **zero additional transactions**. An active endpoint lock refused a competing installer. [Launcher screenshot](../../artifacts/browser-deployment/locks-launcher.png) was visually inspected. [EVM main menu](../../artifacts/browser-deployment/accepted-0.png) and [actual gameplay](../../artifacts/browser-deployment/accepted-3.png) screenshots are retained. The earlier passing attempt2 preceded the final stale-journal fix; its evidence remains separate. The final acceptance re-ran the complete scoped path on the frozen fix.

Final focused suite: **62 passed, zero failed**; [recorded output](../../artifacts/browser-deployment/focused-tests.log). Engine sources, original C, native goldens, ABI/resource schemas, compiler policy and shared acceptance runners were not changed. No engine or commercial compatibility claim beyond integrated main is added. Reproduction is in [README.md](README.md).

Verification/handoff preparation end checkpoint: **2026-10-11 09:41:41 UTC**. Available goal-service attribution at that checkpoint: **163653 aggregate tokens**, **1391 elapsed service seconds**, captured verbatim in [usage-checkpoint.json](../../artifacts/browser-deployment/usage-checkpoint.json). Missing per-stage/model/cost/approval-wait counters are not estimated. Final documentation publication follows this measured checkpoint.

All owned Anvil/Chrome/site instances were stopped and owned temporary browser profiles removed. Forbidden playground/video ports were not used. No main changes, merge or push occurred. No commercial IWAD/extracted payload was copied into the site or committed. The only ignored website IWAD payload is authenticated redistributable Freedoom.

Remaining integration dependency: production Ultimate menu/UI wiring, and separate DOOM II compatibility/native/EVM speedrun work using the verified classic file if authorized as a later goal. This installer records those profiles honestly and preserves existing engine support. Stop after this handoff; do not automatically begin either dependency.
