# Codex usage telemetry

The local collector is separate from the engine in [`tools/usage`](../tools/usage/README.md).
It uses Python's standard library, reads existing JSONL logs, and makes no network
requests. No raw transcript was loaded into model context during recovery; scripts
emitted only field names, timestamps, IDs, phase labels and numeric accounting.

## Recovered historical usage

These are recorded per-response tokens assigned to explicit goal windows,
including root and child agents once each. Cached input is part of input;
reasoning is part of output. Total is input + output.

| Phase | Responses | Input | Cached input | Output | Reasoning | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 154 | 11,909,177 | 11,620,608 | 69,292 | 8,895 | 11,978,469 |
| 1 | 191 | 13,954,577 | 13,629,696 | 88,519 | 14,701 | 14,043,096 |
| 2 | 868 | 99,331,154 | 97,628,672 | 477,186 | 135,777 | 99,808,340 |

Input totals include repeatedly processed conversation context, not just unique
prompt text. All four requested categories were present for every included
response; cache-write input was explicitly zero. The configured model recorded
for these windows was `gpt-6-astra`; no configured model switch was observed in
this project snapshot. The collector preserves switches when present, including
returning to an earlier model.

Retained exports:

- [Aggregated JSON, segments, model events and source fingerprints](../artifacts/usage/historical/usage.json)
- [Per-session, agent, phase and model CSV](../artifacts/usage/historical/metrics.csv)
- [Phase totals CSV](../artifacts/usage/historical/phase-totals.csv)
- [Reviewed phase boundaries](../tools/usage/phases.json)

The scan found 20 local rollouts and selected the 10 owned by this project or
its explicit child threads. Unrelated project bodies were excluded. Phase 0
includes root, stack, transport and schema agents; Phase 1 includes root,
reference, numeric and asset agents; Phase 2 includes root, geometry, data and
draw agents. The first metadata record owns an agent log; later inherited root
metadata does not change that ownership.

## Boundaries and measurement limits

| Phase | Start UTC | End UTC | Evidence |
| --- | --- | --- | --- |
| 0 | 2026-10-09 09:10:22.952 | 2026-10-09 09:52:14.339 | Goal-start event and structured completion result |
| 1 | 2026-10-09 10:32:32.851 | 2026-10-09 11:07:21.766 | Goal-start event and structured completion result |
| 2 | 2026-10-09 11:11:47.796 | 2026-10-09 13:15:29.721 | Goal-start event and structured completion result |

Windows are half-open. Setup before Phase 0, gaps between goals, and work after
completion remain separately unattributed; they are not silently charged to the
nearest phase. Individual response placement uses its event timestamp. The logs
do not provide enough request-start timing to split an inference across a phase
boundary exactly. Cumulative-only intervals crossing boundaries remain ambiguous
instead of being prorated.

The completion records also contain goal `tokensUsed` counters (357,861;
412,801; 2,139,054). Those differ from total per-response usage. Their semantics
are not assumed equivalent, and they are never added to the exported totals.
Likewise, thread/turn cumulative totals and UI `token_count` snapshots are not
additional model calls. The source snapshot reconciles per-response sums with
the recorded thread cumulative high-water values without discrepancies.

The local metadata identifies configured models, not unreported backend reroutes.
Two response records outside the closed phases preceded their matching turn
contexts; their model was recovered from the unique later context for the same
turn. No transcript text was needed. A missing or ambiguous model stays unknown.

The collector cannot prove that unavailable/rotated logs never existed. It does
not estimate missing tokens or prices, and these logs are not a final bill.
Unflushed usage and the currently running response appear only in a later scan.
Malformed records, partial tails, missing fields, duplicate/conflicting IDs,
cumulative resets/corrections and incomplete accounting are explicit diagnostics.
For a cumulative reset without an unambiguous new accounting identity, later
counter snapshots are withheld rather than risk counting replayed usage twice.
Mixed-version threads use response records when present and report cumulative
mismatches instead of blending potentially overlapping ledgers.

## Repeat locally

```sh
python3 tools/usage/collect.py --phases tools/usage/phases.json
python3 tools/usage/collect.py --phases tools/usage/phases.json \
  --closed-only --aggregate-only --output artifacts/local/codex-usage/historical
python3 -m unittest discover -s tools/usage -p 'test_*.py' -v
```

The default detailed snapshot stays in ignored local artifacts. The committed
historical snapshot contains aggregates and chronology, not transcripts or
individual response bodies. Optional `--watch 60` refreshes in the foreground;
there is no installed daemon or telemetry service. Explicit phase markers and
recovery commands are documented in the [collector README](../tools/usage/README.md).

Twenty synthetic tests cover duplicate/cumulative accounting, inherited agent
history, model switches and delayed contexts, boundary crossings, resets,
missing versus zero fields, closed-window selection, partial writes, repeated
collection, and exclusion of transcript text. Engine contracts are unaffected.

For the public terminology, see the official
[usage field definitions](https://developers.openai.com/api/docs/guides/agents-api/observability#understand-token-usage)
and [Codex thread usage notifications](https://learn.chatgpt.com/docs/app-server#turn-events).
The private local JSONL adapters are based on observed CLI 0.162.0 records; the
public documentation is not treated as a stable schema guarantee for those logs.

## Phase 3 engineering snapshot

The [aggregate-only JSON](../artifacts/usage/phase3/usage.json),
[session/agent/phase/model CSV](../artifacts/usage/phase3/metrics.csv) and
[phase totals CSV](../artifacts/usage/phase3/phase-totals.csv) preserve the observed
model switches and agent ownership. Historical Phase 0/1/2 totals are unchanged.
No raw transcript or per-response message body is included.

| Phase | Responses | Input | Cached input | Output | Reasoning | Total |
|---|---:|---:|---:|---:|---:|---:|
| 3 | 1,885 | 327,953,798 | 322,382,080 | 1,363,816 | 605,056 | 329,317,614 |

That engineering snapshot window ends at **2026-10-09T21:13:08Z**, an explicit integrator M2/M3
engineering acceptance marker backed by `artifacts/phase3/acceptance.json`. It
is not an inferred goal-counter completion timestamp. Documentation publication,
push bookkeeping and the current unflushed response can fall outside this window
and remain unattributed. Inference time crossing a boundary cannot be split
exactly from these event timestamps. The snapshot is observed evidence, not a
final bill or an estimate of absent usage.

This scan discovered24 rollouts and selected14 project-owned threads;3,160
response usage records were retained. All requested token fields are present in
these observed records. **3,554 cumulative events were not added** to response
usage, preventing overlapping counters from being counted twice. Three model
contexts were recovered from unique later metadata in the same turn; unknown
backend reroutes are still unmeasured. Cached input remains part of input and
reasoning remains part of output. No prices or missing-token estimates are made.

The historical goal counters and current goal accounting use separate semantics;
never add them to these response totals. The reusable local collector and all
twenty accounting/attribution/privacy regression tests remain separate from the
DOOM engine and use no external telemetry service.

## Structured goal completion snapshot

After clean publication at2696ff7, the goal tool reported completion at
**2026-10-09T21:31:33Z** (second precision). The current phase policy uses this
recorded goal endpoint and preserves the earlier engineering acceptance marker
separately. The engineering exports above remain unchanged.

[Completion aggregate JSON](../artifacts/usage/phase3-complete/usage.json),
[session/agent/phase/model CSV](../artifacts/usage/phase3-complete/metrics.csv) and
[phase totals CSV](../artifacts/usage/phase3-complete/phase-totals.csv) contain the
observed response totals through that configured boundary.

| Phase | Responses | Input | Cached input | Output | Reasoning | Total |
|---|---:|---:|---:|---:|---:|---:|
| 3 | 1,902 | 332,256,311 | 326,402,688 | 1,397,046 | 625,089 | 333,653,357 |

The tool's separate goal accounting is **6,818,723 tokens and26,155 seconds
(about7h16m)**. This is not added to, or interpreted as equivalent to, session
response usage. Current unflushed response usage may arrive later; inference
crossing either boundary cannot be split exactly. No missing values or backend
routes are estimated. Later accounting publication is outside the completed goal
window. The collector's twenty tests pass after closing the actual goal boundary.
