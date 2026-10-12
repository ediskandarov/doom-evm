# Public-release usage snapshot

This directory contains sanitized accounting metadata, not conversation exports.
The [final report](../../../docs/metrics/CODEX-USAGE-FINAL.md) explains scope,
limits and reproduction. The cutoff is `2026-10-12T08:01:42.000Z`, exclusive.

| File | Purpose |
|---|---|
| [usage.json](usage.json) | Totals, additive breakdowns, session/worktree coverage, goal and compaction evidence, task intervals and collector fingerprints |
| [records.csv](records.csv) | Every deduplicated included response, its token fields and attribution |
| [sources.json](sources.json) | All discovered source-file prefixes, SHA-256, byte length, parse status and inclusion decision |
| [coverage-summary.json](coverage-summary.json) | Coverage counts, ambiguity, incomplete telemetry and explicitly unknown missing intervals/tokens |
| [reconciliation.json](reconciliation.json) | Independent raw-event reconstruction and original Phase 0–2 JSON/CSV reconciliation |
| [verification.json](verification.json) | Focused test/reproduction results, measured command timings and protected baseline checks |
| [local-source-assessment.json](local-source-assessment.json) | Reviewed local discovery findings and separate database-counter diagnostics |
| [by_phase.csv](by_phase.csv), [by_workstream.csv](by_workstream.csv), [by_goal.csv](by_goal.csv) | Additive project partitions with explicit unassigned goal intervals |
| [by_model.csv](by_model.csv), [by_agent_kind.csv](by_agent_kind.csv) | Configured model and development/automatic-review partitions |
| [by_worktree_group.csv](by_worktree_group.csv) | Additive directory-group partition; multi-worktree sessions stay unsplit |
| [sessions.csv](sessions.csv) | Agent identity, parent/session relationships, usage bounds, totals and quality flags |
| [worktree_coverage.csv](worktree_coverage.csv) | Per-worktree coverage; shared session totals are repeated and **nonadditive** |
| [turn_intervals.csv](turn_intervals.csv) | Recorded completed task wall intervals; not model compute time |

`reasoning_tokens` is the normalized name for source `reasoning_output_tokens`.
`cached_input_tokens` is a subset of input; reasoning is a subset of output.
`non_cached_input_tokens = input_tokens - cached_input_tokens`.
`total_tokens = input_tokens + output_tokens`. Missing values are null/blank and
accompanied by missing-record counts in aggregates. All included release records
have the requested token fields.

Each response ledger row identifies its source by `source_id` and one-based
`source_line`. `source_id` is the first 20 hex characters of SHA-256 of the
resolved local path; the path itself is not exported. `event_sha256` hashes the
parsed full structured usage event serialized as sorted-key compact JSON.
`snapshot_sha256` instead hashes the exact original byte prefix, preserving its
on-disk serialization. The committed source manifest lets a local auditor check
the raw line and deduplication without publishing conversation contents.

The original reports in `../historical`, `../phase3`, `../phase3-complete` and
`../telemetry2` are separate immutable checkpoints. Do not append these totals
to their totals: their records overlap.

## Local metadata review

The source-assessment JSON is a reviewed inventory supplement, not another token
ledger. It records the discovered stores, state database coverage, and numeric
thread-counter comparison. The state database can be inspected in a local copy
using only `id, rollout_path, cwd, git_origin_url, git_branch, tokens_used` from
`threads` and the explicit `thread_spawn_edges`; never export its message, title,
preview, account or credential fields. Its data was copied for read-only analysis
at a different time from the fixed response cutoff. The changing release/audit
thread is marked noncomparable. All other 64 project thread counters reconcile
with the direct response ledger after the compaction subset is considered.

The other inspected sources provide discovery/timing context only: the default
Codex configuration and environment, shell startup `CODEX_HOME` declarations,
session index, app workspace/project metadata, goal/thread-history schemas and
application-log counter shapes. Their transcript-bearing databases and raw text
remain local. No authenticated API or billing data was queried.
