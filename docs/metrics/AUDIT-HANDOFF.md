# Codex usage audit work record

- Started: 2026-10-12T08:01:42Z.
- Baseline: `4c7ed9c9c9bc706cff416bbb1a224b4a45117347` (refreshed `origin/main`).
- Owner: this telemetry audit goal; branch `feat/codex-usage-audit` in its dedicated feature worktree.
- Scope: local Codex discovery, usage accounting, regression tests, sanitized metrics and reproducible reporting. No engine, browser, compiler, fixture or accepted evidence changes.
- Dependencies: available local rollout logs, metadata, Git worktree/commit history and historical usage exports. Missing sources must remain explicit; goal counters are diagnostic only.
- Verification gates: independent historical reconciliation; synthetic accounting/discovery/privacy tests; deduplicated record-to-aggregate checks; worktree coverage; source fingerprints; sanitized output and documentation links; unchanged historical evidence and clean feature commits.
- Stop condition: final human/machine reports, verified collector corrections and Gitmoji commits with a clean feature worktree. No merge or main push; no feature push requested for this goal.

## Outcome

Recovered **1,087,787,600 measured tokens** through `2026-10-12T08:01:42.000Z`
(exclusive), including 29,907,451 automatic-review tokens. This is a lower bound
from available local records. The old main-directory discovery rule omitted
33 sessions containing 440,200,214 tokens. The original Phase 0–2 total,
125,829,905 tokens / 1,213 responses, is independently reproduced exactly.

The [final report](CODEX-USAGE-FINAL.md), [worktree matrix](WORKTREE-COVERAGE.md)
and [machine exports](../../artifacts/usage/final/README.md) contain the detailed
accounting, source coverage, timeline, limits and public-friendly summary.

## Implementation and commits

Collector/tooling commit: `9c64fa2bbc9d24095359d7d068078fc69709405a`
(`🐛 Recover Codex usage across independent worktrees`).

A separate `🔧 Normalize audit CSV line endings for review` commit records the
LF-only CSV correction; the exact collector tip is stored in `verification.json`.
The nine focused audit tests and raw-event/byte-replay checks passed again after
that serialization-only change.

- `tools/usage/discovery.py`: repository/worktree identity discovery, active and
  archived alternate-home roots, explicit parent links and guardian identity.
- `tools/usage/collect.py`, `phases.py`, `README.md`: use that discovery and
  preserve the existing response-first accounting and legacy v2 exports; allow
  exact byte-bounded source replay.
- `tools/usage/audit.py`, `audit-policy.json`: fixed-cutoff release snapshot,
  reviewed goal/worktree labels, source fingerprints, timeline and sanitized
  JSON/CSV. Shared directory usage stays unsplit.
- `tools/usage/verify_audit.py`: independent direct-event and historical CSV/JSON
  reconciliation, without reusing the collector's accounting functions.
- `tools/usage/test_discovery.py`, `test_audit.py`: 16 additional synthetic
  regression tests; the original 50 remain unchanged.

The following documentation/evidence commit adds `docs/metrics/`, the docs index
entry and `artifacts/usage/final/`. Its exact SHA is supplied in the final handoff
and can be resolved with `git rev-parse feat/codex-usage-audit`. No files were
deleted. Existing historical usage reports and reviewed phase windows were not
rewritten. No shared engine/browser interface changes or integration dependencies.

## Verification

Reproducible commands are in the [final report](CODEX-USAGE-FINAL.md#reproduction).
Exact commands, measured UTC endpoints and elapsed times are in
[verification.json](../../artifacts/usage/final/verification.json).

| Check | Result |
|---|---|
| Full focused usage suite | **66 passed**, final run 2026-10-12 08:34:00.298–08:34:03.340 UTC; process wall 3.041362 s |
| Bounded audit replay | 3.679194 s; all **12 generated exports byte-identical** |
| Independent raw-event reconciliation | 1.179292 s; 7,284 records, every token field and response fingerprint matched |
| Historical reconciliation | All three phases, original JSON/metrics CSV and **10 original raw source prefixes** matched |
| Legacy collector from the feature checkout | 8.658727 s; closed windows preserved |
| Existing v2 JSON/CSV/privacy validation | Passed in 0.137322 s |
| Public export privacy | JSON transcript-field checks, private-path/account pattern scan, CSV structure checks passed |
| Current Markdown links/anchors | Checked for new reports, export index, collector README and docs index |
| Scope and original source | All baseline paths outside the four explicitly edited collector/index documents unchanged; original C gitlink preserved |

An initial audit run exposed integer Unix-second turn endpoints and failed before
producing a report. The adapter was corrected and regression-tested. Raw local
diagnostics remain ignored. The final publication check also caught CRLF CSV whitespace and a generic privacy
field-name check matching the deliberately recorded verification invocations. CSV
exports now use LF, and those reviewed invocation arrays have an explicit
`invocation_argv` field. Token values are unchanged. Later successful checks
supersede these failed checks;
it did not change source logs or historical evidence.

No Solidity/native/browser build or EVM replay was needed for this telemetry-only
change. No runtime was started. Main was neither modified nor pushed.

## Limits and remaining work

This completes the available-local-history audit. It cannot recover deleted,
off-device or never-recorded requests. Two review sessions have no usage records;
seven sessions have ten unclosed turn starts with usage (eight explicit aborts).
Existing usage reconciles with the recorded cumulative counters, but an absent
final call cannot be inferred. Some worktree splits and post-goal intervals are
intentionally ambiguous. Future releases need a newly reviewed policy/cutoff;
future mixed-project sessions need turn-level project review.

The current audit's separate goal tracker reported 221,304 tokens and 1,939 seconds
at its 2026-10-12 08:34:01 UTC checkpoint. These diagnostics are **excluded** from
the historical response ledger and are not an estimate of this audit's API token
consumption. Final goal-tool attribution is reported separately at completion.

Stop condition: verified collector and reports committed, clean feature worktree,
no merge or push. Integration remains with the designated main writer.
