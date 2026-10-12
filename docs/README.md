# Documentation

Start with the [public README](../README.md). These documents describe the
integrated release; engineering reports below describe their own checkpoints.

| I want to… | Read |
|---|---|
| Install and play locally | [Getting started and Steam IWADs](GETTING-STARTED.md), [browser deployment](browser-deployment/README.md) |
| Understand where computation happens | [Architecture](ARCHITECTURE.md) |
| Check game support and fidelity limits | [Compatibility and completeness](COMPATIBILITY.md) |
| Build, test or reproduce evidence | [Development and verification](DEVELOPMENT.md) |
| Find the original-C function mapping | [Porting map](../PORTING.md) |
| Inspect the release cleanup and verification | [Release readiness](release/READINESS.md), [inventory](release/INVENTORY.md) |
| Audit measured development usage | [Final Codex usage report](metrics/CODEX-USAGE-FINAL.md) |

## Engineering archive

Historical paths are retained so certificates, source hashes and reproduction
commands remain meaningful. A report's “pending”, “current” or “unsupported”
refers to its recorded revision. Later integration reports may supersede its
product status without changing its evidence.

| Topic | Reports and evidence |
|---|---|
| Design and interfaces | [Decisions](01-IDEA-AND-DECISIONS.md), [specification](02-TECHNICAL-SPECIFICATION.md), [Phase 0–3 plan](03-IMPLEMENTATION-PLAN.md), [Phase 4 plan/policy](04-IMPLEMENTATION-PLAN-EXTRA.md), [schemas](SCHEMAS.md), [input protocol](../INPUT_PROTOCOL.md) |
| Foundation | [Phase 0](PHASE0-REPORT.md), [Phase 1](PHASE1-REPORT.md), [transport experiment](EVENT-TRANSPORT.md), [stack experiment](STACK-PRESSURE.md) |
| Renderer | [Phase 2 report](PHASE2-REPORT.md), [interfaces](PHASE2-INTERFACES.md), [evidence index](../artifacts/phase2/README.md) |
| Gameplay | [Phase 3 report](PHASE3-REPORT.md), [feature/function matrix](PHASE3-FEATURE-MATRIX.md), [ledger](PHASE3-PLAN.md) |
| Phase 4 integration | [Shared ledger](PHASE4-PLAN.md), [UI](PHASE4-UI-INTEGRATION.md), [episode completion](PHASE4-EPISODE-COMPLETION.md), [input runtime](PHASE4-INPUT-RUNTIME.md) |
| Memory fidelity | [Memory audit](PHASE4-MEMORY-AUDIT.md), [native audit](PHASE4-NATIVE-MEMORY-AUDIT.md), [virtual pointers](EXPERIMENTAL-VIRTUAL-POINTERS.md), [owner slots](ULTIMATE-OWNER-POINTERS.md), [failed DrawBounds diagnosis](DRAWBOUNDS-BLOOD-CRASH.md) |
| Browser/game profiles | [Installer acceptance](browser-deployment/REPORT.md), [three-game integration](browser-deployment/THREE-GAME-INTEGRATION.md), [Ultimate](ULTIMATE-BROWSER.md), [DOOM II](doom2/REPORT.md), [DOOM II integration](doom2/INTEGRATION.md) |
| Speedruns | [Freedoom episode](EPISODE-SPEEDRUNS.md), [first E1M1 video](SPEEDRUN-E1M1-VIDEO.md), [tic-52 investigation](SPEEDRUN-TIC52.md), [Ultimate](ULTIMATE-SPEEDRUNS.md), [owner-profile episode](ULTIMATE-OWNER-EPISODE.md) |
| Full recordings and Options | [Nine recording report](ULTIMATE-FULL-VIDEOS.md), [episode metrics](../artifacts/full-videos/EPISODE-SUMMARY.md), [Options](OPTIONS-LEVEL-SELECTION.md), [combined integration](FULL-VIDEO-OPTIONS-INTEGRATION.md) |
| Death and saving | [Death/respawn](DEATH-RESPAWN.md), [Exact EVM Snapshot](SAVE-LOAD.md), [combined integration](DEATH-SAVE-LOAD-INTEGRATION.md), [canonical save research](SAVE-LOAD-CANONICAL-DISCOVERY.md) |
| Development accounting | [Usage](CODEX-USAGE.md), [telemetry](CODEX-TELEMETRY-2.md) |

Per-module reports and per-map certificates are linked from these indexes and
the [porting map](../PORTING.md). Raw committed certificates live in
[`artifacts/`](../artifacts/); accepted fixtures in [`test/fixtures/`](../test/fixtures/).
Large recordings, commercial data and scratch runs stay in ignored
`artifacts/local/` and are not included in a clone.
