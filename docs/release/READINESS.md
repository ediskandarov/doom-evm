# Public release preparation

The initial release checkpoint below used a Freedoom preview. The subsequent
[README media correction](README-MEDIA.md) replaces the public demonstration
with the owner's specified verified Ultimate DOOM E1M1 recording. Initial
verification records and their media remain preserved.

## Scope and baseline

Started: 2026-10-12 06:25:08 UTC. Owner: release-preparation agent, branch
`feat/public-release`, worktree `/private/tmp/doom-evm-public-release`.
Baseline: stable integrated `origin/main` at
`1b728fe3f8307a49f71437d5af75a4935df81492`; clean after fetch. Its
[combined integration certificate](../../artifacts/phase4/death-save-main/integration.json)
reports `overallPass: true`. Main is read-only to this goal. Future feature
recommendations are deferred by that checkpoint, not part of this release work.

Authorized scope: complete repository inventory, evidence-based cleanup and
entry-point consolidation, public README and current documentation, bounded
completeness/source-fidelity audit, existing-media presentation, focused release
checks. No engine refactor, allocator/pointer/profile changes, fixture changes,
compiler changes, historical evidence rewrites, or full speedrun reruns.

Ownership: current documentation, release-specific evidence/tools and README
media. Shared Solidity, ABIs, schemas, browser protocols, historical runners,
accepted reports and fixtures remain protected. No other worktree or local user
asset may be modified. The integrator owns the shared Phase 4 ledger and main.

Dependencies: pinned original C at `a77dfb96cb91780ca334d0d4cfd86957558007e0`,
existing packaged production contracts, local pinned Foundry/solc, Node 24.11.0,
Freedoom 0.13.0, Chrome and existing accepted media. Any cache reuse copies both
`out` and `cache` into this worktree; Forge validates the unchanged sources.
Owned verification ports: 19671/19672, then 19673/19674 for quick-start checks;
refuse occupied ports, stop only owned
processes. Reserved playground ports 18880/8088 are excluded.

Verification gates: source/artifact identity, pinned upstream, preserved tracked
evidence and fixtures, no commercial IWADs in Git, Markdown links, documented
quick start, focused Node/WAD tests, production-root build and a fresh real
browser-managed Freedoom installation/gameplay/Frame proof. Source-fidelity audit
separates code reachability, finite native comparison, EVM output provenance and
unsupported domains. Historical acceptances stay tied to their original profiles.

Stop condition: Gitmoji commits, reproducible results and limitations, exact
handoff SHA, clean feature worktree. No merge or push to main; no subsequent goal.
Model/token/cost measurements are recorded only when available from this session;
missing attribution is not estimated.

## Delivered changes

- [Public README](../../README.md): compact introduction, authentic existing
  Freedoom gameplay, sourced metrics, game profiles, local quick start and
  explicit native-pointer/performance/feature limits. The 1.9 MB GIF is derived
  from the unchanged accepted recording; no new gameplay was executed for media.
- [Documentation index](../README.md), [getting started](../GETTING-STARTED.md),
  [architecture](../ARCHITECTURE.md), [compatibility audit](../COMPATIBILITY.md)
  and [development](../DEVELOPMENT.md) form the current entry structure.
  SteamCMD instructions target macOS and retain the required distribution
  override. Ultimate's user-tested procedure and DOOM II's separately verified
  app ID/download instructions have distinct verification labels.
- The deployment guide and porting map now point to current integrated behavior.
  Historical reports remain accessible at their original paths, unchanged.
- The toolchain installer replaces each verified executable atomically, avoiding
  in-place changes to the previous executable inode. Versions, checksums and
  compiler settings are unchanged; two focused CLI tests cover replacement and
  rejection of a bad checksum.
- Global case-insensitive IWAD/MP4 ignore patterns protect local assets. A small,
  read-only [release check](../../tools/release/check.py) verifies preservation,
  local links, source/artifact identities and compiler policy.

**Removed or moved files: none.** Current entry points were consolidated in the
documentation; hash-bound historical wrappers were retained. The
[inventory](INVENTORY.md) classifies every top-level area, actual consumers,
duplicate candidates and reasons for keeping them. No production Solidity,
browser runtime, shared ABI, schema, test fixture or accepted certificate changed.
AGENTS.md remains applicable and unchanged. The shared Phase 4 ledger is the
integrator's responsibility.

## Verification performed

New evidence is under [`artifacts/public-release/`](../../artifacts/public-release/README.md).
Full local reports, journals and screenshots remain under
`artifacts/local/public-release/`; committed browser summaries retain hashes and
transaction identities without commercial palettes or pixels.

| Check | Actual result |
|---|---|
| Pinned production build | 85 Solidity files, solc 0.8.37, success in 252.305174 seconds; existing source-faithful warnings retained |
| Warm build | `No files changed, compilation skipped`; 0.074382 seconds |
| Production packaging | Doom and Doom2 packages reproduced byte-for-byte; 82/81 source identities plus compiler metadata checked |
| Toolchain | Actual checksum-pinned reinstall passed after atomic replacement; Foundry 1.8.5, solc 0.8.37, Node 24.11.0 |
| Installer regression tests | 2 passed; old inode stays intact and checksum failure changes no installed binary |
| WAD/native resources | Authenticated Freedoom download/episode pack; nine maps in O0/O2/UBSan-except-shift, 38 generated local files matching the accepted manifest |
| Browser/WAD/budget Node tests | 153 passed, 0 failed; 17.342515 seconds |
| Resource identity | Original-source directory/bundle and 1,755 STOP-prefixed chunks verified |
| Three-game real browser | 21 checks and 20 complete 64,000-pixel EVM-to-Canvas comparisons passed; fresh installs, keyboard movement, interruption/reload, profile isolation and chain-reset invalidation |
| Documented static server/Anvil | Seven actual HTTP responses matched repository/staged bytes; JavaScript MIME, JSON packages, WAD, CORS, chain ID and 10-billion gas limit passed |
| Preservation | 4,184 protected baseline blobs unchanged; original C pinned and clean; no tracked WAD or MP4; source/compiler/resource bindings valid |
| Documentation | Repository-relative paths and current-document anchors passed; external Steam/Homebrew sources checked separately; exact totals in `audit.json` |

The production build copied **both** cache and output from the prior integrated
build into this goal's private directory. Forge elected to compile 85 files;
no cache hashes were edited. The warm check then skipped compilation. Repackaging
produced no Git diff in the pinned release assets.

The three-game browser run measured 06:39:07.309–06:45:34.379 UTC on
2026-10-12. It used headless Chrome 155.0.8059.40 and isolated Anvil 1.8.5 on
19671/19672. The quick-start check ran 06:57:29.994–06:57:30.182 UTC on
19673/19674. Both checks report owned runtimes stopped. Reserved playground
ports 18880/8088 were never used.

## Reproduction commands

From this feature checkout, follow the environment/resource prerequisites in
[Development](../DEVELOPMENT.md), then run:

```sh
source scripts/env.sh
forge build src/evm/Doom.sol src/evm/Doom2.sol src/evm/ResourceStore.sol \
  --offline --no-lint --skip test script \
  --out artifacts/local/public-release/production/out \
  --cache-path artifacts/local/public-release/production/cache
python3 tools/reference/death_respawn/package.py artifacts/local/public-release/production
python3 -m unittest discover -s test/tooling -p 'test_*.py' -v
node --test web/*.test.mjs tools/wad/*.test.ts tools/execution-budget.test.mjs
node tools/wad/check-source-identity.mjs
python3 tools/release/check.py \
  --compiled artifacts/local/public-release/production \
  --output artifacts/local/public-release/new-audit.json
```

The browser command is in [Development](../DEVELOPMENT.md#real-browser-deployment).
This run used the owner's existing Ultimate file at
`$HOME/Downloads/doom-steam/base/DOOM.WAD` and DOOM II file at
`$HOME/Downloads/doom-steam/base/doom2/DOOM2.WAD`. Those paths are local input
locations, not evidence that the Ultimate SteamCMD command installs both games.
Use your own authenticated files and fresh output prefixes/free ports. The exact
build and quick-start commands, source hashes, runtime settings and artifact
identities are also recorded in the machine-readable evidence.

## Failed attempts retained

- Two early Node attempts lacked generated prerequisites (first staged IWADs,
  then the native episode outputs). Their logs remain separate; after running
  the documented preparation, all 153 tests passed without changing assertions.
- The historical single-profile browser runner completed 13 checks and six
  Canvas comparisons but failed its obsolete “commercial profile unavailable”
  assertion. It remains a failed run, with its error and metadata preserved.
  The existing current three-game runner passed; neither runner was edited.
- The original installer's first real reinstall encountered SIGKILL at Forge's
  immediate version check, despite identical pinned bytes. A later invocation
  worked. The atomic replacement fix and fresh reinstall passed. A macOS
  code-signature cache interaction is suspected, not established by OS evidence.
- Sandbox restrictions initially blocked network download/local server binding;
  isolated authorized checks subsequently passed. The optional README browser
  preview was not used for acceptance. No computer-use inspection is required.

## Limits and remaining debt

This is verified **release preparation**, ready for the designated integrator's
review. It is not integration into main or final whole-engine acceptance.
No full historical suite or 18,175-frame recording was rerun. No new Forge
behavioral suite was needed for unchanged engine source; the fresh build,
resource/native checks, Node tests and production-browser checks cover this scope.

The [compatibility audit](../COMPATIBILITY.md) records remaining original feature
gaps and strict fidelity domains: pointer policy 3 is experimental, full DOOM II
gameplay acceptance covers only MAP01/MAP07, production melt is absent, saves
are Exact EVM Snapshots, and sound/music/multiplayer are out of scope. Existing
finite native comparisons do not become universal fidelity claims.

The [inventory's follow-ups](INVENTORY.md#remaining-maintenance-debt--proposed-follow-ups)
cover misleading historical paths, wrapper duplication, write-prone historical
defaults and environment portability. These require separate measured work.
Authenticated Steam downloads were not repeated in this goal. GitHub's live
rendering and other operating systems were not tested; Markdown structure,
relative links, the media file and rendered HTML were checked locally.

## Handoff

The feature branch is `feat/public-release`; worktree:
`/private/tmp/doom-evm-public-release`. No shared interface requirements or pending
engine dependencies are introduced. Preserve the feature commits, documents and
new evidence when integrating on top of the latest stable main. Do not substitute
new compiler packages or reinterpret historical evidence as a current full run.

Installer commit: `4a7cecdc402b32f22380483f9451aaf7873a4a01`
(`🐛 Install pinned toolchain binaries atomically`). The public documentation,
audit and evidence form the following release-preparation commit. Resolve its
exact handoff SHA with `git rev-parse feat/public-release`; the handoff message
also supplies that SHA. No history is rewritten and no branch is pushed.

Verification checkpoint completed: **2026-10-12 07:02:53 UTC**, 37 minutes
45 seconds after the measured start. At that checkpoint the session goal meter
reported `tokensUsed: 328297` and `timeUsedSeconds: 2265`. These are the tool's
goal-level counters, not per-model billing attribution; token splits and cost
were unavailable and are not estimated. Final commit/clean-tree confirmation
follows this checkpoint and is reported at handoff.

## README wording and community credits follow-up

Started 2026-10-12 07:30:49 UTC at feature baseline
`de6e1be707d2dcc901a25c3dc0af144b523ad32d`. Same owner/worktree. Scope is the
owner's verbatim opening and explicit speedrunning-community credit, keeping
the GIF immediately after the introduction. Only README and this checkpoint
record are owned; no engine/media/interface changes or runtime dependencies.
Gate: exact wording, attribution links, preservation and whitespace checks.
Stop after a Gitmoji commit and clean feature tree; no merge or push.

Verified 2026-10-12T07:32:32.262636+00:00: opening matches the owner's supplied text exactly,
GIF placement is retained, and explicit community/DSDA/featured-runner credit
links to preserved author/tape provenance. 159 Markdown documents and
895 local links/current anchors passed the release checker; 4,184
protected baseline blobs and pinned source/artifact identities are unchanged.
Only README and this report changed; no engine build or EVM rerun was needed.
Local check: `artifacts/local/public-release/readme-opening-audit.json`.
Per-model usage/cost attribution is unavailable for this follow-up.
