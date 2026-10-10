# Local Codex usage collector

Python standard library only. No server, credentials, network requests, tokenizer,
or DOOM-engine dependency. It reads local Codex JSONL files and exports only
whitelisted accounting metadata. Messages, reasoning text, summaries, prompts,
commands and tool output are never included in usage exports or console output.

```sh
python3 tools/usage/collect.py --phases tools/usage/phases.json
# Optional foreground refresh; Ctrl-C stops it. No background service is installed.
python3 tools/usage/collect.py --phases tools/usage/phases.json --watch 60
python3 -m unittest discover -s tools/usage -p 'test_*.py' -v
```

Outputs default to ignored `artifacts/local/codex-usage/`:

- `usage.json`: totals, phase totals, session/agent/model breakdowns, chronological
  segments, model events, sanitized response-accounting records and diagnostics.
- `metrics.csv`: session × thread/agent × phase × model × accounting-method totals.
- `phase-totals.csv`: phase totals with missing-value counts.

Use `--closed-only --aggregate-only` for a compact article snapshot containing
only completed phase windows and aggregate/chronological metrics.

Reruns replace snapshots; they never append totals from an earlier collection.
`--logs` accepts a JSONL file or directory and can be repeated. The default scans
`~/.codex/sessions` and `~/.codex/archived_sessions`. `--project` defaults to the
working directory. First owning metadata selects matching project rollouts;
explicit parent-thread links include agents in separate worktrees. Other projects
are excluded. Paths are represented by hashes, with consumed-byte SHA-256 and
snapshot sizes for provenance. Reads stop at each file's initial size; an
incomplete live tail is counted as missing and retried on the next snapshot.

## Accounting rules

The observed local format is Codex CLI 0.162.0. These internal logs are not a
stable public schema; unknown record types are ignored, malformed lines counted,
and missing measurements retained as unknown.

1. Prefer `token_usage_record.usage` for each unique `(thread_id,response_id)`.
   `turn_token_usage`, `thread_token_usage` and `event_msg/token_count` are
   cumulative/summary information, **not additional usage**. Conflicting records
   with one response ID are withheld; identical copies count once. A cumulative
   high-water discrepancy is reported, never silently added to response totals.
2. For threads with no response records, recover monotonic cumulative deltas.
   Repeated snapshots count zero. The first known `last_token_usage` can be
   attributed to its event; the earlier cumulative balance stays unattributed.
   A child's initial balance is excluded because it may contain inherited usage.
   A decrease could be a reset, correction or replay: subsequent cumulative
   snapshots are withheld rather than invented as fresh usage. This is an
   explicitly reported lower bound, not complete recovery across resets.
3. Never combine the two accounting sources within a thread. Mixed-version logs
   with missing response records can therefore be incomplete; mismatched totals
   expose this limitation. Missing response IDs are excluded. There is no
   tokenization estimate for unavailable usage.
4. Input includes cached input; output includes reasoning. `total_tokens` is
   reported or derived as input + output, never all columns added together.
   Optional cache-write tokens are retained separately. Missing fields are JSON
   null / blank CSV, with per-field missing-record counts. Explicit zero is zero.
5. The first `session_meta` owns the file; later metadata may be inherited.
   Structured response thread IDs and `subagent_history_start_ordinal` prevent
   parent history from being charged to a child. Root and child usage are added
   once each; root aggregate/goal counters are never added again.
6. Models come from the matching `turn_context`. A later context for the same
   exact turn can supply a model only when it is unambiguous. These are configured
   model identities, not proof of an unreported backend reroute. A → B → A
   remains three chronological segments. A cumulative interval spanning a model
   change is attributed to unknown rather than split by guesswork.
7. Phase windows are half-open UTC `[start,end)`. Individual response records use
   their logged event timestamp; request start/finish times are unavailable, so
   an exact inference-time split at a boundary is not claimed. A cumulative delta
   spanning a phase boundary stays `ambiguous-boundary`. Gaps are `unattributed`.
   Separate sessions can have different phase windows.

## Phase history and future boundaries

The reviewed `phases.json` contains recovered Phase 0/1/2 goal starts/completions
and an explicit marker for this telemetry task. Its source IDs/line numbers are
metadata pointers, not transcript excerpts. Closed phase totals remain stable
when later work is collected.

Recover a fresh candidate ledger for review:

```sh
python3 tools/usage/phases.py recover --output artifacts/local/codex-usage/recovered-phases.json
```

Recovery processes structured goal events and programmatically extracts goal
objects from tool outputs. It saves only a phase label, timestamps, source
pointers and numeric goal counters. Objective strings and surrounding tool
output are discarded. Phase labels inferred from objectives must be reviewed;
only goals with both start and completion evidence become closed windows.
The separate goal counters have different accounting semantics and are retained
for provenance only. They are never combined with response token metrics.

Before starting another phase or work category, mark its boundary explicitly:

```sh
python3 tools/usage/phases.py mark --file tools/usage/phases.json \
  --phase phase3 --session 01a11fdf-1d25-7201-abb8-1afdaaab6b9c
```

This closes the previous open window for that session and starts the new one.
Use `--at` only for an evidence-backed historical timestamp. Overlaps and naive
timestamps are rejected. For a new root session, supply its own session ID;
phases are not guessed from filenames or agent names. Collect again at milestones
or leave the foreground watcher running. Codex already writes the source logs;
no new recording hook or external telemetry is necessary.

## Evidence and limitations

[Historical project metrics](../../docs/CODEX-USAGE.md) describe the observed
coverage and ambiguity. The collector cannot prove absent/rotated logs never
existed, recover an unrecorded category, infer backend model routing, or convert
these counters into a final bill. A live snapshot excludes the still-running
response and any usage not flushed yet.

Official documentation describes
[thread usage notifications](https://learn.chatgpt.com/docs/app-server#turn-events)
and the [input/cache/output/reasoning subset relationship](https://developers.openai.com/api/docs/guides/agents-api/observability#understand-token-usage).
The latter describes public API accounting, not a promise about this internal
JSONL schema. The collector's adapters are based on the local structured records
and synthetic regression tests.

## Telemetry 2.0 activity adapter

Goal 4.0 adds `activity.py` independently of the token ledger. The additive JSON
report is v2; phase configuration and legacy token CSV columns remain compatible.
All existing historical exports are retained. New files:

- `compactions.csv`: event ID, thread/agent, configured model, goal/phase, matched
  interval, duration, dedicated context sizes (nullable), separate request input.
- `approvals.csv`: explicit request/resolution lifecycle, resolver provenance and
  human/automatic/unknown waiting intervals. Header-only is valid when absent.
- `executions.csv`: command hash only, process-wall duration, compiler/test stage
  annotations, preserved reported values, consistency flags and nesting links.
- `goals.csv`: structured goal IDs/status, audited wall interval and separate
  goal counters; objective prose is discarded.
- `activity-phase-totals.csv`: observed counts, known/missing duration fields,
  process sum versus interval union, partial compiler/test/direct Forge totals.
- `telemetry-report.md`: human-readable tables with measurement limitations.

```sh
python3 tools/usage/collect.py --phases tools/usage/phases.json \
  --aggregate-only --output artifacts/local/codex-telemetry2
python3 tools/usage/validate.py artifacts/local/codex-telemetry2
```

Formal JSON/CSV contracts are under `schemas/`. The standard-library validator
checks the documented schema subset, forbidden transcript fields and exact new
CSV row reconciliation. It is not a general-purpose JSON Schema implementation.

Compaction duration joins require a unique same-thread/same-turn containing
ContextCompaction interval; timestamps merely nearby are insufficient. Dedicated
context occupancy is not derived from cumulative counters, context capacity,
request input tokens, output/summary length or a tokenizer. Current local data
has request input usage and timing, but no exact before/after context occupancy.

Approval lifecycle support uses explicit event_msg types `approval_request`,
`exec_approval_request`, `apply_patch_approval_request`, and matching
`approval_resolved`, `exec_approval_response`, `apply_patch_approval_response`,
with approval/request/call IDs. These conservative adapters are synthetic-tested;
no such historical records are visible in this project's observed CLI snapshot.
Policy/escalation intent, reviewer settings and tool delays cannot manufacture
actual human waiting time. Human-resolved intervals cannot isolate thinking
from delivery/routing unless more explicit timestamps exist.

Compiler-bearing heads include Forge build/test, direct Solc/Clang/GCC, and the
known stack-pressure script's structured compile_wall_ms reports. Shells with
one actual Forge head can provide stdout stage time but never a standalone
Forge duration. Heredoc source/log readers/quoted programs are not parsed as
executed compiler commands. Hidden subprocesses remain unavailable.

Reported Solc and overall suite wall summaries are distinct from whole command
duration and per-suite CPU. Explicit skipped compilation is known zero. Larger
timing conflicts are withheld from subtotals with numeric diagnostics; raw
reported numbers are still preserved, not adjusted. 0.5s is a consistency tolerance
for timer origins/rounded output, not an estimate of unrecorded work.

Explicit nested parent IDs suppress repeated elapsed/compile charges. Temporal
containment alone does not prove parentage; concurrent execution coverage uses
an interval union separately from summed process duration. Cross-phase/goal
intervals remain ambiguous, never prorated. Sources have their own bounded-scan
fingerprints because the activity pass can observe a different live file size
from the token pass. Duplicates/conflicts/fork history are not new usage.

[Goal 4.0 report and recovered data](../../docs/CODEX-TELEMETRY-2.md) document
observability gaps. No before/after context, human approval duration, backend
model reroute, absent goal endpoint or compiler stage is estimated. No service
or background hook is installed.
