"""Atomic metadata-only exports and article-oriented measurement report."""
import csv
import json
from pathlib import Path

BASE = ['session_id', 'thread_id', 'agent', 'phase', 'goal_id', 'model', 'turn_id',
        'event_id', 'timestamp', 'source_id', 'line']
CSV_COLUMNS = {
    'compactions.csv': BASE + ['start', 'end', 'duration_seconds', 'context_tokens_before',
        'context_tokens_after', 'request_input_tokens', 'window_number', 'measurement'],
    'approvals.csv': BASE + ['start', 'end', 'resolver', 'outcome', 'waiting_seconds',
        'human_wait_seconds', 'automatic_wait_seconds'],
    'executions.csv': BASE + ['start', 'end', 'category', 'compiler', 'wall_seconds',
        'compiler_wall_seconds', 'compiler_measurement', 'test_wall_seconds', 'compiler_stages_observed', 'exit_code',
        'command_sha256', 'parent_execution_id', 'included_in_execution_sum',
        'nested_in_execution_id', 'compiler_time_included', 'measurement'],
    'goals.csv': ['session_id', 'goal_id', 'phase', 'start', 'end', 'status',
        'elapsed_wall_seconds', 'reported_goal_seconds', 'reported_goal_tokens'],
    'activity-phase-totals.csv': ['phase', 'compactions', 'compaction_seconds',
        'compaction_duration_missing', 'context_before_missing', 'context_after_missing',
        'approval_requests', 'approval_wait_seconds', 'human_wait_seconds', 'automatic_wait_seconds',
        'execution_records', 'execution_seconds_sum', 'execution_interval_union_seconds',
        'compiler_wall_seconds', 'compiler_duration_missing', 'test_wall_seconds',
        'forge_invocation_wall_seconds', 'other_tool_wall_seconds'],
}


def csv_file(path, columns, rows):
    tmp = path.with_suffix(path.suffix+'.tmp')
    with tmp.open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=columns, extrasaction='ignore', lineterminator='\n')
        writer.writeheader();writer.writerows(rows)
    tmp.replace(path)


def value(x):
    if x is None:
        return 'unavailable'
    return f'{x:,.3f}' if type(x) is float else f'{x:,}' if type(x) is int else str(x)


def markdown(report):
    a = report['activity']
    lines = ['# Codex Telemetry 2.0 — observed local measurements', '',
        'Snapshot: '+report['collected_at']+'. No transcripts, commands, objectives or tool output are exported.', '',
        'Cached input is included in input; reasoning is included in output. Neither is added a second time.', '',
        '| Phase | Responses | Input | Cached input | Output | Reasoning | Total |',
        '|---|---:|---:|---:|---:|---:|---:|']
    for r in report['phase_totals']:
        lines.append('| '+r['phase']+' | '+' | '.join(value(r[k]) for k in ('records','input_tokens','cached_input_tokens','output_tokens','reasoning_tokens','total_tokens'))+' |')
    lines += ['', '## Compaction and approval observations', '',
        '| Phase | Compactions | Compaction seconds | Missing duration | Before/after context unavailable | Approval requests | Human wait seconds | Automatic wait seconds |',
        '|---|---:|---:|---:|---:|---:|---:|---:|']
    for r in a['phase_totals']:
        lines.append('| '+r['phase']+' | '+' | '.join(value(r[k]) for k in ('compactions','compaction_seconds','compaction_duration_missing'))+
            f" | {r['context_before_missing']}/{r['context_after_missing']} | "+' | '.join(value(r[k]) for k in ('approval_requests','human_wait_seconds','automatic_wait_seconds'))+' |')
    lines += ['', 'Zero observed approval requests is not zero actual human waiting. Policy context alone proves no lifecycle or resolver.', '',
        'Compaction request input tokens are model-request usage, not a measurement of context occupancy before/after compaction.', '',
        '## Compiler, test and execution measurements', '',
        '| Phase | Command records | Execution sum seconds | Interval union seconds | Reported compiler seconds | Missing compiler stages | Overall test-suite seconds | Forge invocation seconds | Other command seconds |',
        '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|']
    for r in a['phase_totals']:
        lines.append('| '+r['phase']+' | '+' | '.join(value(r[k]) for k in ('execution_records','execution_seconds_sum','execution_interval_union_seconds',
            'compiler_wall_seconds','compiler_duration_missing','test_wall_seconds','forge_invocation_wall_seconds','other_tool_wall_seconds'))+' |')
    lines += ['', 'Compiler and test stage measurements are annotations inside command duration, not additional execution time. Per-suite CPU times are never summed as wall time.', '',
        'Execution sum can exceed elapsed wall time because concurrent commands/agents overlap. The interval union counts overlapping command coverage once; it is not goal time, CPU time, or time spent reasoning.', '',
        '## Goal elapsed and separate accounting', '',
        '| Goal ID | Phase | Status | Goal wall seconds | Reported goal seconds | Separate goal tokens |',
        '|---|---|---|---:|---:|---:|']
    for r in a['goals']:
        lines.append('| '+r['goal_id']+' | '+r['phase']+' | '+r['status']+' | '+' | '.join(value(r.get(k)) for k in ('elapsed_wall_seconds','reported_goal_seconds','reported_goal_tokens'))+' |')
    lines += ['', 'Separate goal counters retain their own semantics and are never added to response-token totals. Open/paused goals have no invented completion or elapsed duration.', '',
        '## Coverage and limitations', '']
    lines += ['- '+x for x in a['limitations']]
    lines += ['- Inherited/duplicate/conflicting events are excluded; reset window numbers do not create duplicate token charges.',
        '- Timing intervals crossing a phase/goal boundary remain ambiguous; they are never prorated.',
        '- Exact compaction start/end matching requires one same-thread, same-turn containing interval. Proximity alone is insufficient.',
        '- Missing before/after context sizes, unresolved approvals, absent resolver provenance and hidden subprocess stages stay null/blank.',
        '- Logs can be unavailable, rotated or unflushed. These are observed measurements, not proof of complete activity or a final bill.', '',
        'Activity diagnostics (numeric metadata only): `'+json.dumps(a['coverage']['diagnostics'],sort_keys=True)+'`.', '']
    return '\n'.join(lines)


def export_activity(report, output):
    if 'activity' not in report:
        return  # Legacy reports can still be exported.
    a=report['activity']
    for name, key in [('compactions.csv','compactions'),('approvals.csv','approvals'),
                      ('executions.csv','executions'),('goals.csv','goals'),('activity-phase-totals.csv','phase_totals')]:
        csv_file(Path(output)/name, CSV_COLUMNS[name], a[key])
    path=Path(output)/'telemetry-report.md';tmp=path.with_suffix('.md.tmp')
    tmp.write_text(markdown(report));tmp.replace(path)
