# DOOM on EVM: final Codex usage audit

**Measured usage through public release: 1,087,787,600 tokens across 7,284 model-response usage records.** This is a **lower bound from available local telemetry**, not a claim that every development interaction ever made has been recovered.

The total includes **1,057,880,149 development-agent tokens** and **29,907,451 automatic-review-agent tokens**. Cached context is counted as input consumption, not as unique written text. The old collector missed **440,200,214 tokens (40.47% of the recovered total)** in independent feature worktree sessions. Its original Phase 0–2 result was correct.

Snapshot cutoff: **2026-10-12 08:01:42 UTC, exclusive**, the start of this audit. This audit's own subsequent usage is excluded. Repository baseline: `4c7ed9c9c9bc706cff416bbb1a224b4a45117347`, after the public-release merge. No engine, browser, accepted evidence or historical usage export was changed.

[JSON](../../artifacts/usage/final/usage.json) · [Response ledger CSV](../../artifacts/usage/final/records.csv) · [Source manifest](../../artifacts/usage/final/sources.json) · [Independent reconciliation](../../artifacts/usage/final/reconciliation.json) · [Worktree matrix](WORKTREE-COVERAGE.md) · [Verification handoff](AUDIT-HANDOFF.md)

## Accounting and cache breakdown

| Measurement | Tokens |
|---|---:|
| Total input | 1,082,007,058 |
| Cached input, already within input | 1,057,635,712 |
| Non-cached input | 24,371,346 |
| Total output | 5,780,542 |
| Reasoning output, already within output | 2,558,605 |
| **Input + output** | **1,087,787,600** |

Cached input is **97.7476% of input tokens**. Cache-write input is explicitly zero in every included record. All requested token fields are present in all 7,284 records. Input can contain the same conversation context on many requests; these totals do not measure unique prompts or generated source code.

Each accepted entry is an original `token_usage_record.usage`, keyed by owning thread and response ID. The recorded thread cumulative high-water values reconcile with the per-response sums in every included thread that has usage. **7,588 cumulative events are deliberately not added.** Neither context-window size, remaining budget, `tokensUsed` goal counters nor database thread counters are additional response usage.

The subset rules agree with [OpenAI's usage field definitions](https://developers.openai.com/api/docs/guides/agents-api/observability#understand-token-usage). Public [Codex usage notifications](https://learn.chatgpt.com/docs/app-server#turn-events) do not guarantee the private JSONL schema; the adapters are tested against observed local records and synthetic fixtures.

## Development phases

| Phase or explicitly separate interval | Usage records | Total tokens |
|---|---:|---:|
| Initial recorded project preparation | 12 | 409,661 |
| Phase 0 — feasibility | 154 | 11,978,469 |
| Phase 1 — numeric/assets/reference | 191 | 14,043,096 |
| Phase 2 — renderer | 868 | 99,808,340 |
| Between explicit early phase windows | 16 | 3,148,215 |
| Original usage collector | 37 | 5,085,341 |
| Phase 3 — gameplay | 1,902 | 333,653,357 |
| Goal 4.0 — activity telemetry | 54 | 17,395,270 |
| Later Phase 4 workstreams and integration | 3,912 | 587,136,391 |
| Public Release Readiness and follow-ups | 138 | 15,129,460 |
| **Total** | **7,284** | **1,087,787,600** |

Phase 0–3 and telemetry boundaries retain the [original reviewed ledger](../../tools/usage/phases.json). Later Phase 4 is a project workstream category, not a fabricated single goal window. The named feature sessions and integration session establish its scope. Preparation and gaps between early goals remain separate. The public-release category includes media, credit and publication follow-ups after its original goal completed.

The broad phase categories partition the total. They do not assert that every response was generated entirely inside the corresponding goal interval. Requests crossing a boundary cannot be split precisely from response-event timestamps.

## Goals, workstreams and timeline

The [goal CSV](../../artifacts/usage/final/by_goal.csv) and JSON retain **54 recovered structured goals**, their source pointers, start/end evidence, paused/completed status and separate diagnostic goal counters. **77,333,679 tokens** fall outside recovered goal windows; they remain included in the project total and in their reviewed workstreams. Examples include discovery before a goal, follow-up verification, integration preparation and publication after completion. They are not silently assigned to a nearby goal.

Structured goal objects expose integer-second start/end times, while the retained Phase 0–2 ledger uses finer event timestamps. With the conservative goal-window endpoints, one response near each of those three completion boundaries remains outside the goal bucket: **438,628 tokens combined**. They remain in their correct historical phases and the project total. This is a documented boundary-precision difference, not lost or duplicated usage.

This compact workstream view includes those follow-ups. Times below are first/last **usage events**, in UTC during October 2026, not measured continuous execution.

| Workstream | Usage records | Total tokens | First → last UTC |
|---|---:|---:|---|
| Automap | 63 | 6,410,950 | 10-10 10:03 → 10-10 10:41 |
| Browser-managed deployment | 54 | 5,649,252 | 10-11 09:18 → 10-11 09:44 |
| Canonical Save/Load research | 42 | 11,125,068 | 10-11 20:03 → 10-12 04:50 |
| Cheats | 52 | 4,787,057 | 10-10 10:03 → 10-10 10:40 |
| Core engine, original phases and verification | 3,478 | 517,245,123 | 10-09 09:06 → 10-10 08:14 |
| DOOM II development | 96 | 20,385,492 | 10-11 10:14 → 10-11 11:16 |
| Death/Respawn | 198 | 34,068,806 | 10-11 16:17 → 10-11 19:36 |
| Episode One completion and memory audit | 254 | 37,169,776 | 10-10 14:49 → 10-10 17:20 |
| Episode One resources | 47 | 4,810,895 | 10-10 10:04 → 10-10 10:38 |
| Episode runtime discovery and startup | 62 | 11,370,515 | 10-10 11:23 → 10-10 13:08 |
| Episode speedruns: Freedoom and Ultimate | 100 | 11,204,936 | 10-10 19:24 → 10-10 19:42 |
| Feature integration | 750 | 108,711,221 | 10-10 09:50 → 10-12 06:18 |
| Freedoom E1M1 replay and video | 72 | 10,171,969 | 10-10 14:56 → 10-10 16:01 |
| Full Speedrun Videos | 338 | 62,396,212 | 10-11 09:18 → 10-11 16:41 |
| Full-rate tic-52 investigation | 76 | 9,983,538 | 10-10 17:20 → 10-10 17:51 |
| Gameflow | 51 | 5,561,638 | 10-10 08:20 → 10-10 09:42 |
| HUD | 35 | 3,188,285 | 10-10 08:20 → 10-10 09:43 |
| Input runtime discovery and integration | 65 | 13,695,050 | 10-10 11:23 → 10-10 13:43 |
| Intermission discovery and implementation | 67 | 12,485,777 | 10-10 11:23 → 10-10 13:26 |
| Memory architecture audit | 58 | 6,366,542 | 10-10 07:51 → 10-10 09:47 |
| Memory audit setup | 4 | 135,040 | 10-10 07:49 → 10-10 07:50 |
| Options menu | 118 | 20,320,811 | 10-11 15:15 → 10-11 16:27 |
| Original main menu | 100 | 16,687,146 | 10-10 17:43 → 10-10 19:15 |
| Production UI | 65 | 9,806,357 | 10-10 11:18 → 10-10 12:01 |
| Public Release Readiness | 138 | 15,129,460 | 10-12 06:25 → 10-12 08:01 |
| Save/Load discovery and exact snapshots | 131 | 25,394,186 | 10-11 16:17 → 10-11 19:47 |
| Status bar | 56 | 6,009,798 | 10-10 08:19 → 10-10 09:52 |
| Ultimate DOOM browser deployment | 83 | 12,043,434 | 10-11 10:14 → 10-11 11:03 |
| Ultimate DOOM episode verification | 530 | 73,364,702 | 10-10 19:43 → 10-11 07:50 |
| Virtual pointer modeling | 71 | 8,513,256 | 10-10 18:05 → 10-10 18:39 |
| Visual completeness audit | 30 | 3,595,308 | 10-11 15:08 → 10-11 15:26 |

The core-engine row includes the original experiments, renderer/gameplay work, native-equivalence investigations, early memory compatibility work and their child agents. The separate phase table provides the finer original phase breakdown. Episode completion also includes its later native-memory audit.

The speedrun thread changed from Freedoom to original Ultimate DOOM at an explicit user scope update on **October 10, 19:42:45.793 UTC**. Its worktrees remained separately identifiable; the token split uses that task marker, not a guessed branch-change time. Exact EVM Save/Load and canonical lifecycle research are separated at the explicit request on **October 11, 20:03:32.356 UTC**. These markers and source lines are preserved in [the reviewed audit policy](../../tools/usage/audit-policy.json).

Original phase endpoints remain:

| Phase | Start UTC | End UTC |
|---|---|---|
| 0 | Oct 9 09:10:22.952 | Oct 9 09:52:14.339 |
| 1 | Oct 9 10:32:32.851 | Oct 9 11:07:21.766 |
| 2 | Oct 9 11:11:47.796 | Oct 9 13:15:29.721 |
| 3 | Oct 9 14:10:28.000 | Oct 9 21:31:33.000 |

The first available project session metadata is **October 9, 09:06:28.632 UTC**; its first usage event is **09:06:34.477**. The last included usage event is **October 12, 08:01:04.066 UTC**. The measured usage span is **2 days, 22 hours, 54 minutes, 29.589 seconds**. It is an observed calendar span, not total human effort or model execution time.

Git independently brackets the release: the initial commit `4d6f44e` is dated October 9, 09:09:23 UTC; the public-release merge `4c7ed9c` is dated October 12, 07:43:35 UTC. Commit dates corroborate chronology; they do not allocate tokens or prove the first project idea occurred then. Earlier planning or experiments outside the available project logs are unmeasured.

## Agents and parallel worktrees

| Agent category | Usage records | Total tokens |
|---|---:|---:|
| Development roots and explicit subagents | 6,894 | 1,057,880,149 |
| Automatic approval/review agents (`/guardian`) | 390 | 29,907,451 |

There are **65 project session files**, with usage in **63**. Parent/child links and the first owning metadata record establish agent identity; inherited parent history is not charged again to a child. Review agents are measured separately because they are real model calls with their own response IDs, not a parent aggregate. This audit did not launch additional development agents.

The [worktree coverage matrix](WORKTREE-COVERAGE.md) covers **49 pre-audit registered worktrees**. Full session IDs, agent identities, branches, activity bounds, exclusive/shared totals and confidence are in [the matrix CSV](../../artifacts/usage/final/worktree_coverage.csv); [session CSV](../../artifacts/usage/final/sessions.csv) provides the per-agent totals.

Some agents operated in several worktrees while session metadata continued to say the main checkout. Phase 2 geometry/data/draw, discovery-to-runtime sessions and Freedoom-to-Ultimate speedruns therefore use **shared, unsplit session buckets**. Their shared totals appear in every associated matrix row for coverage and **must not be added across rows**. The [worktree-group CSV](../../artifacts/usage/final/by_worktree_group.csv) is an additive partition. Setup and handoff for a dedicated goal follow that goal's reviewed worktree assignment; this is not a per-command CPU accounting system.

The browser-deploy, game-launcher and playground checkouts have no separately attributable session usage. They are visible in integration context and Git, but no invented token total is assigned to them. Zero in their exclusive column means “no separately assigned records,” not proven zero cost.

Across **560 completed task intervals**, the sum of reported wall durations is **295,855.035 seconds**; their endpoint interval union is **178,411 seconds**. At least **four threads** have overlapping recorded task intervals. At least two overlap for **67,062 seconds**. Endpoint timestamps have whole-second precision; duration fields have millisecond precision. These measurements include tool execution and waits. Parent and child wall intervals overlap, and sum/union are intentionally different.

**Actual active model compute time and human approval waiting time are unavailable.** Goal elapsed time is also a different clock; a paused or overnight goal can span many hours without proving continuous work.

## Model distribution and compaction

| Configured model/route | Usage records | Input | Output | Total |
|---|---:|---:|---:|---:|
| `codex-auto-review` | 390 | 29,868,448 | 39,003 | 29,907,451 |
| `gpt-6-astra` | 1,649 | 172,392,674 | 983,134 | 173,375,808 |
| `gpt-6.1-sol` | 5,245 | 879,745,936 | 4,758,405 | 884,504,341 |

Models come from matching `turn_context` records, including unambiguous delayed contexts for the same turn. These are configured identities, not proof of an unreported backend reroute. The `codex-auto-review` label does not identify an underlying commercial model SKU. No included model remains unknown. Model changes within sessions are retained per response, rather than assigning the session's last model to all of its history.

**39 context compactions** are recoverable. Their associated responses consume **10,881,848 tokens, already included in the total**. The embedded compaction backup usage records all match direct usage records; they are not extra calls. Context contents and before/after summaries are never exported.

The local thread database counts reconcile for **all 64 quiescent project threads** after accounting for the compaction responses already in the event ledger. The original root is a concrete example: its database count is 217,719,677, its direct response total is 220,473,810, and its ten compaction responses account for the exact **2,754,133** difference. The release/audit thread was still changing when the metadata copy was taken, so its differently timed database snapshot is explicitly not compared as an exact same-cutoff measurement. See [local source assessment](../../artifacts/usage/final/local-source-assessment.json).

No price estimate is provided. These usage counts are not subscription charges or an invoice.

## Collector defects and historical reconciliation

The current collector is [`tools/usage/collect.py`](../../tools/usage/collect.py), with [`docs/CODEX-USAGE.md`](../CODEX-USAGE.md) and the existing `artifacts/usage/` exports. The suggested `scripts/codex-usage.py` and root `CODEX-USAGE.md` were not present in this baseline or their queried Git path history. The historical metrics CSV is still at its original location.

| Finding | Effect | Correction and confidence |
|---|---|---|
| Discovery accepted only the requested directory/descendants plus explicit child threads | Independent sibling-worktree roots were omitted; invoking from a feature checkout could also miss the original main session | Resolve registered worktrees/shared Git directory and recorded repository identity before following parent links. **33 sessions with usage, 440,200,214 tokens recovered; high confidence.** |
| Default roots ignored an alternate `CODEX_HOME` environment setting | Could miss a configured alternate local store | Scan active/archive directories under both default and configured homes. **No additional home was found on this machine; no invented recovery.** |
| Automatic-review source metadata lacked `agent_path` | Review sessions could be labeled `/root` | Preserve `/guardian` identity and separate its totals. **High confidence from explicit source metadata and model route.** |
| Historical phase ledger stopped after Goal 4.0 | Later discovered usage remained unattributed to a phase/goal | Add a separate release-audit policy and structured goal recovery. Preserve old phase ledger and ambiguous gaps. |
| Cumulative counters were not interchangeable with response usage | Summing them again, or substituting database/goal counts, would misstate usage | Existing response-first accounting was correct. Keep counter reconciliation and compaction subsets separate. |

At the same fixed cutoff, the former discovery predicate would measure **647,587,386** tokens. Repository-aware discovery measures **1,087,787,600**. The difference is entirely the 33 previously omitted sessions; it is not a correction to Phase 0–2 arithmetic.

| Historical phase | Original | Independently recovered | Difference | Responses |
|---|---:|---:|---:|---:|
| 0 | 11,978,469 | 11,978,469 | 0 | 154 |
| 1 | 14,043,096 | 14,043,096 | 0 | 191 |
| 2 | 99,808,340 | 99,808,340 | 0 | 868 |
| **Total** | **125,829,905** | **125,829,905** | **0** | **1,213** |

All original input/cache/output/reasoning fields also match exactly. Historical cached input is **122,878,976 / 125,194,908 = 98.1501%**, which rounds to the reported **98.2%**. The 125.83M figure is correctly rounded. All ten historical raw source-prefix hashes still verify. The original JSON, both CSVs, report, source fingerprints and phase windows remain untouched. Phase 3's later completion snapshot also remains **333,653,357 tokens**; its earlier engineering-only snapshot had a different documented endpoint, not an arithmetic contradiction.

## Source coverage and completeness limits

| Coverage item | Result |
|---|---:|
| Rollout files discovered / parsed | 79 / 79 |
| Active / archived locations | 74 / 5 |
| Project files before cutoff | 65 |
| Unrelated files excluded | 13 |
| After-cutoff session excluded | 1 |
| Rejected files / malformed lines / incomplete tails in the frozen prefixes | 0 / 0 / 0 |
| Duplicate session files / duplicate response copies / conflicting response IDs | 0 / 0 / 0 |
| Included responses missing requested usage fields | 0 |
| Project sessions without usage records | 2 |
| Sessions with unclosed turns containing usage | 7 |
| Unclosed turn starts containing usage | 10 |
| Known cumulative-response discrepancies | 0 |

Discovery inspected default active/archive logs, the configured `CODEX_HOME`, shell startup declarations, app workspace/project metadata, session index, state/goals/thread-history database metadata, app log counter shapes, and likely alternate local locations. The database listed 79 threads and no missing rollout path. No alternate home was found in the inspected configuration; no unrelated session was selected merely because it occurred during the same dates. The archived files were inspected and excluded as unrelated, rather than silently ignored.

The manifest includes fingerprints and parse results for **all 79 sources**, even exclusions. The [coverage summary](../../artifacts/usage/final/coverage-summary.json) records incomplete-session flags, unassigned usage and unknown missing intervals in machine-readable form. Rejected or malformed inputs would be reported rather than discarded invisibly. The 145 unbounded fork UI counters withheld by the adapter are redundant summaries; direct child-owned responses still count. Adapter diagnostics describe the frozen source prefixes, which can also contain ignored post-cutoff events.

Two empty guardian logs and ten starts lacking a task-complete event are explicit telemetry limits. Eight of those ten starts have abort records. Their existing usage is counted; absent final requests or missing usage cannot be estimated from a wall clock. There is no known missing *whole day* inside October 9–12 based on available files, but that cannot prove all requests were logged. Earlier project history, arbitrary unconfigured stores, deleted/rotated logs, other machines, backend reroutes and unflushed tails remain unquantified. **Missing date ranges and missing token amounts are therefore unknown, not zero.**

The audit preserves a conservative legacy-counter fallback: take monotonic deltas, distinguish an unattributed initial balance, and withhold later counters after an ambiguous reset/correction. It never blindly treats a decrease as new usage. In mixed-format sessions, response and cumulative ledgers are not blended. These limitations are regression-tested; every record in this actual final total uses a direct response event, so no fallback or estimated token quantity contributes.

Repository identity can recover a renamed/deleted checkout from its recorded remote, while reviewed task pointers bind the actual known worktrees. A completely missing log without any surviving metadata is unrecoverable. A future mixed-project session needs explicit turn-level review; the inspected project sessions had no observed foreign project `turn_context.cwd` switch.

Raw rollouts were only read, never rewritten or copied into Git. Public outputs allowlist counts, IDs, timestamps, source hashes and curated project labels; no raw prompts, responses, tool outputs, credentials, personal account fields or private absolute paths are included. Path aliases deliberately conceal the local filesystem layout.

## Reproduction

Run from a checkout with the original local Codex logs available. No API request, engine build or EVM replay is required.

```sh
python3 -m unittest discover -s tools/usage -p 'test_*.py' -v

python3 tools/usage/audit.py \
  --snapshot artifacts/usage/final/sources.json \
  --output artifacts/local/usage-audit/reproduced

python3 tools/usage/verify_audit.py \
  --report artifacts/local/usage-audit/reproduced \
  --output artifacts/local/usage-audit/independent-reconciliation.json
```

`--snapshot` reads exactly the recorded byte prefixes and refuses changed or missing sources. Appended later activity cannot inflate the snapshot. Source IDs hash resolved local paths; this exact replay therefore requires those original paths. A relocated archive can be rescanned without `--snapshot` and independently reconciled by response IDs, but it produces new provenance fingerprints. `--logs PATH` is repeatable for explicitly located alternate stores. `--project PATH` identifies any checkout in the same Git worktree family.

The [audit policy](../../tools/usage/audit-policy.json) fixes the cutoff, manually reviewed workstream labels, explicit task boundaries and goal-owned worktree groups. Review that policy for a different project or later release; do not extend old goal windows by assumption. Source hashes for the collector and policy are embedded in the JSON. [Export format notes](../../artifacts/usage/final/README.md) explain row-level traceability and the metadata-only local inventory review.

The independent verifier reads original structured records without the collector's accounting functions, checks every exported response hash and token field, sums all additive breakdowns, verifies all original source prefixes and reconciles the historical JSON/metrics CSV. The synthetic suite covers discovery across simultaneous worktrees and renames, archive overlap, inherited histories, duplicates/conflicts, model changes, task boundaries, counter resets, missing fields, partial tails, frozen-prefix replay and privacy. Verification outcomes and command durations are recorded in [the handoff](AUDIT-HANDOFF.md).

## Public-friendly summary

> The available Codex logs record about **1.09 billion tokens** used to develop and prepare DOOM on EVM for release: **1.06 billion from development agents** and **29.9 million from automatic review**. About **97.75% of input tokens were cached context**. The audit recovered **440 million tokens** missed when development moved into independent Git worktrees. The original 125.83-million-token Phase 0–2 report was reproduced exactly. These are measured usage totals from available logs, not unique words, subscription charges or proof that no history is missing.
