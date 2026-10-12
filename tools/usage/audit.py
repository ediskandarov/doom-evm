#!/usr/bin/env python3
"""Reproduce the bounded public-release usage audit; export allowlisted metadata only."""
import argparse
import collections
import csv
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re

import collect
import discovery
from phases import strings

FIELDS = (*collect.FIELDS, 'non_cached_input_tokens')


def iso(seconds):
    return collect.timestamp(datetime.fromtimestamp(seconds, timezone.utc).isoformat())


def totals(rows):
    result = {'records': len(rows)}
    for field in FIELDS:
        values = [r['tokens'].get(field) for r in rows]
        result[field] = sum(v for v in values if v is not None) if any(v is not None for v in values) else (0 if not rows else None)
        result[field + '_missing_records'] = sum(v is None for v in values)
    return result


def group(rows, fields):
    buckets = collections.defaultdict(list)
    for row in rows:
        buckets[tuple(row[k] for k in fields)].append(row)
    return [{**dict(zip(fields, key)), **totals(values),
             'first_usage': min(r['timestamp'] for r in values),
             'last_usage': max(r['timestamp'] for r in values)}
            for key, values in sorted(buckets.items())]


def valid(tokens):
    i, o, t = (tokens.get(k) for k in ('input_tokens', 'output_tokens', 'total_tokens'))
    if all(v is not None for v in (i, o, t)) and i + o != t:
        return False
    return not any(tokens.get(a) is not None and tokens.get(b) is not None and tokens[a] > tokens[b]
                   for a, b in [('cached_input_tokens', 'input_tokens'), ('reasoning_tokens', 'output_tokens')])


def extra_metadata(path, meta, size, cutoff):
    """Read only structured goal objects, turn timing and compaction identifiers.

    Tool-output text is parsed in memory to recover goal objects, then discarded.
    Objective strings are never returned. They cannot affect token accounting.
    """
    goals, turns, compactions, contexts, fingerprints = [], [], [], [], {}
    diagnostics = collections.Counter()
    decoder = json.JSONDecoder()
    first, last = None, None
    for ordinal, record in collect.read_lines(path, diagnostics, max_bytes=size):
        payload = record.get('payload')
        if not isinstance(payload, dict):
            continue
        if meta['forked'] and type(meta['fork_ordinal']) is int and ordinal < meta['fork_ordinal']:
            continue
        try:
            stamp = collect.timestamp(record.get('timestamp'))
        except (TypeError, ValueError):
            continue
        if stamp >= cutoff:
            continue
        first = min(first or stamp, stamp); last = max(last or stamp, stamp)
        pointer = {'source_id': collect.identity(path), 'line': ordinal + 1, 'timestamp': stamp}
        kind = record.get('type')
        if kind == 'token_usage_record' and payload.get('thread_id') == meta['thread_id']:
            rid = payload.get('response_id')
            fingerprints[(collect.identity(path), ordinal + 1)] = hashlib.sha256(json.dumps(record, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        if kind == 'turn_context':
            contexts.append({**pointer, 'turn_id': payload.get('turn_id'), 'cwd': payload.get('cwd')})
        if kind == 'compacted':
            nested = payload.get('latest_token_usage_record') or {}
            # Forks without a boundary require an explicit owning nested usage identity.
            if meta['forked'] and meta['fork_ordinal'] is None and nested.get('thread_id') != meta['thread_id']:
                continue
            compactions.append({**pointer, 'thread_id': meta['thread_id'],
                                'response_id': payload.get('compaction_response_id'),
                                'window_id': payload.get('window_id'),
                                'nested_response_id': nested.get('response_id')})
        candidates = []
        if kind == 'event_msg':
            subtype = payload.get('type')
            if subtype in ('task_started', 'task_complete', 'turn_aborted'):
                turns.append({**pointer, 'thread_id': meta['thread_id'], 'type': subtype,
                              **{k: payload.get(k) for k in ('turn_id', 'started_at', 'completed_at', 'duration_ms')}})
            if subtype == 'thread_goal_updated':
                candidates.append(payload.get('goal'))
        elif kind == 'response_item' and payload.get('type') in ('function_call_output', 'custom_tool_call_output'):
            for text in strings(payload.get('output')):
                for match in re.finditer(r'\{\s*"goal"\s*:', text):
                    try:
                        obj, _ = decoder.raw_decode(text[match.start():])
                        candidates.append(obj.get('goal'))
                    except (ValueError, AttributeError):
                        pass
        for goal in candidates:
            if not isinstance(goal, dict) or goal.get('threadId') != meta['thread_id'] or type(goal.get('createdAt')) is not int:
                continue
            goals.append({**pointer, 'thread_id': meta['thread_id'],
                          **{k: goal.get(k) for k in ('createdAt', 'updatedAt', 'status', 'tokensUsed', 'timeUsedSeconds')}})
    return {'goals': goals, 'turns': turns, 'compactions': compactions, 'contexts': contexts,
            'fingerprints': fingerprints, 'first': first, 'last': last}


def goal_windows(events, labels):
    buckets = collections.defaultdict(list)
    for event in events:
        buckets[(event['thread_id'], event['createdAt'])].append(event)
    result = []
    for (thread, created), values in sorted(buckets.items()):
        values.sort(key=lambda e: e['timestamp'])
        completed = [e for e in values if e['status'] == 'complete']
        end = completed[0] if completed else None
        latest = end or values[-1]
        result.append({'goal_id': f'{thread}:{created}', 'thread_id': thread,
                       'label': labels.get(str(created), 'Unreviewed structured goal'),
                       'start': iso(created), 'end': iso(end['updatedAt']) if end and type(end['updatedAt']) is int else None,
                       'status': latest['status'], 'observed_statuses': sorted({e['status'] for e in values if e['status']}),
                       'first_evidence': {k: values[0][k] for k in ('source_id', 'line', 'timestamp')},
                       'end_or_latest_evidence': {k: latest[k] for k in ('source_id', 'line', 'timestamp')},
                       'separate_goal_counter': {k: latest[k] for k in ('tokensUsed', 'timeUsedSeconds')},
                       'boundary_precision': 'createdAt/updatedAt integer seconds; usage placed by event timestamp'})
    # Open/paused goals cannot claim a later replacement goal's usage.
    for window in result:
        next_start = min((g['start'] for g in result if g['thread_id'] == window['thread_id'] and g['start'] > window['start']), default=None)
        if not window['end'] and next_start:
            window['attribution_end'] = next_start
        else:
            window['attribution_end'] = window['end']
    return result


def annotate(rows, metadata, goals, policy, config):
    owners = {x['thread_id']: x['worktrees'] for x in policy['worktree_ownership']}
    goal_by_thread = collections.defaultdict(list)
    for g in goals:
        goal_by_thread[g['thread_id']].append(g)
    for row in rows:
        tid = row['thread_id']; root = row['session_id']; meta = metadata[tid]
        # Guardian and child sessions follow an explicit ancestor only, never time overlap.
        ancestor = tid; visited = set()
        while ancestor not in policy['sessions'] and ancestor in metadata and ancestor not in visited:
            visited.add(ancestor)
            ancestor = metadata[ancestor].get('parent_thread_id')
        session_policy = policy['sessions'].get(ancestor, {})
        row['workstream'] = session_policy.get('workstream', 'Unreviewed project session')
        for change in policy['task_boundaries']:
            if change['session_id'] == ancestor and row['timestamp'] >= change['start']:
                row['workstream'] = change['workstream']
        candidates = [g for g in goal_by_thread[ancestor] if g['start'] <= row['timestamp'] < (g['attribution_end'] or policy['cutoff'])]
        row['goal_id'] = candidates[0]['goal_id'] if len(candidates) == 1 else 'unassigned'
        row['goal'] = candidates[0]['label'] if len(candidates) == 1 else 'Outside recovered goal windows'
        row['agent_kind'] = 'automatic-review' if meta['agent'] == '/guardian' else 'development'
        ws = owners.get(tid) or (owners.get(ancestor) if row['agent_kind'] == 'automatic-review' else None)
        ws = ws or [Path(meta['cwd']).name if meta.get('cwd') else 'unknown']
        row['worktree_group'] = '|'.join(ws)
        row['worktree_confidence'] = 'shared-session-unsplit' if len(ws) > 1 else 'reviewed-goal' if tid in owners or ancestor in owners else 'owning-metadata'
        historical = row['phase']
        if historical == 'unattributed':
            if row['workstream'] == 'Public Release Readiness':
                row['phase'] = 'public-release'
            elif config['windows'] and row['timestamp'] < config['windows'][0]['start']:
                row['phase'] = 'initial-project-preparation'
            elif row['timestamp'] < '2026-10-10T04:58:39.000Z':
                row['phase'] = 'between-phase-windows'
            else:
                row['phase'] = 'phase4-parallel-and-integration'
        row['record_id'] = collect.identity(f"{tid}:{row.get('response_id')}:{row['method']}:{row['timestamp']}")
        i, c = row['tokens']['input_tokens'], row['tokens']['cached_input_tokens']
        row['tokens']['non_cached_input_tokens'] = i - c if i is not None and c is not None else None


def union_seconds(intervals):
    def t(s): return datetime.fromisoformat(s.replace('Z', '+00:00')).timestamp()
    edges = sorted((t(a), t(b)) for a, b in intervals if a and b and b >= a)
    merged = []
    for a, b in edges:
        if merged and a <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], b)
        else:
            merged.append([a, b])
    return sum(b-a for a, b in merged)


def turn_time(value):
    # Observed task_* schema uses Unix seconds; duration_ms is a separate field.
    if type(value) is int:
        return iso(value)
    if isinstance(value, str):
        return collect.timestamp(value)
    return None


def concurrency(intervals):
    edges = []
    for interval in intervals:
        if interval['started_at'] < interval['completed_at']:
            edges.extend([(interval['started_at'], 1, interval['thread_id']),
                          (interval['completed_at'], -1, interval['thread_id'])])
    counts = collections.Counter(); peak = 0; peak_at = None; previous = None; overlap = 0
    for time, delta, thread in sorted(edges):
        if previous and sum(v > 0 for v in counts.values()) >= 2:
            overlap += union_seconds([(previous, time)])
        counts[thread] += delta
        active = sum(v > 0 for v in counts.values())
        if active > peak:
            peak, peak_at = active, time
        previous = time
    return {'max_observed_concurrent_threads': peak, 'first_peak_at': peak_at,
            'wall_seconds_with_two_or_more_observed_threads': overlap,
            'measurement': 'complete recorded task wall intervals, rounded endpoint seconds; lower bound on observed concurrency, not compute'}


def scan(roots, project, policy, config, snapshot=None):
    selected, files, rejected, repo = discovery.discover(roots, project)
    snapshot_by_id = {s['source_id']: s for s in snapshot['sources']} if snapshot else {}
    if snapshot and set(snapshot_by_id) - {collect.identity(p) for p in files} - {collect.identity(p) for p in rejected}:
        raise ValueError('snapshot source missing; restore original local paths before reproducing')
    sources, metadata, extras, events_by_thread = [], {}, {}, collections.defaultdict(list)
    all_diagnostics = collections.Counter(); adapter_diagnostics = collections.Counter(); per_thread = {}
    for path in sorted(set(files) | set(rejected)):
        sid = collect.identity(path)
        if snapshot and sid not in snapshot_by_id:
            continue
        meta = files.get(path)
        limit = snapshot_by_id[sid]['snapshot_bytes'] if snapshot else path.stat().st_size
        receipt = {}; diag = collections.Counter(); records = 0
        # Fingerprint and parse every discovered source, including excluded/rejected sources.
        for _, _ in collect.read_lines(path, diag, receipt, limit):
            records += 1
        if snapshot and receipt['snapshot_sha256'] != snapshot_by_id[sid]['snapshot_sha256']:
            raise ValueError('source prefix changed; refusing to reproduce from different evidence')
        decision = 'project' if path in selected else 'unrelated' if meta else 'rejected-no-owning-metadata'
        if meta and collect.timestamp(meta['created_at']) >= policy['cutoff']:
            decision = 'after-cutoff'
        sources.append({'source_id': sid, 'location_kind': 'archived' if 'archived_sessions' in path.parts else 'active-or-explicit',
                        'decision': decision, 'thread_id': meta['thread_id'] if decision == 'project' else None,
                        'cli_version': meta['cli_version'] if meta else None,
                        'selection_evidence': meta['selection_evidence'] if decision == 'project' else [],
                        'parsed_records': records, 'diagnostics': dict(diag), **receipt})
        all_diagnostics.update(diag)
        if decision != 'project':
            continue
        tid = meta['thread_id']
        if tid in metadata and any(meta[k] != metadata[tid][k] for k in ('session_id', 'parent_thread_id', 'agent')):
            raise ValueError('conflicting owning session metadata')
        metadata[tid] = meta
        parsed, _, _ = collect.parse_rollout(path, meta, adapter_diagnostics, limit)
        events_by_thread[tid] += [e for e in parsed if e['timestamp'] < policy['cutoff']]
        extra = extra_metadata(path, meta, limit, policy['cutoff'])
        if tid in extras:
            for key in ('goals', 'turns', 'compactions', 'contexts'):
                extras[tid][key] += extra[key]
            extras[tid]['fingerprints'].update(extra['fingerprints'])
        else:
            extras[tid] = extra
    rows = []
    for tid, events in events_by_thread.items():
        diag = collections.Counter()
        records = collect.account_thread(metadata[tid], events, config['windows'], diag)
        good = []
        for row in records:
            if valid(row['tokens']):
                row['event_sha256'] = extras[tid]['fingerprints'].get((row['source_id'], row['source_line']))
                good.append(row)
            else:
                diag['invalid_token_relationship_records_excluded'] += 1
        rows += good; per_thread[tid] = dict(diag)
    rows.sort(key=lambda r: (r['timestamp'], r['thread_id'], r.get('response_id') or ''))
    goals = goal_windows([g for e in extras.values() for g in e['goals']], policy['goal_labels'])
    annotate(rows, metadata, goals, policy, config)
    compactions = {(e['thread_id'], e.get('window_id') or e['timestamp']): e for x in extras.values() for e in x['compactions']}
    compaction_ids = {e['response_id'] for e in compactions.values()}
    for row in rows:
        row['response_kind'] = 'compaction' if row.get('response_id') in compaction_ids else 'ordinary-or-unclassified'
    own_turns = {(r['thread_id'], r['turn_id']) for r in rows if r.get('turn_id')}
    turns = {(e['thread_id'], e['turn_id'], e['type']): e for x in extras.values() for e in x['turns']
             if (e['thread_id'], e['turn_id']) in own_turns}
    for e in turns.values():
        e['started_at'] = turn_time(e['started_at'])
        e['completed_at'] = turn_time(e['completed_at'])
    complete_turns = [v for k, v in turns.items() if k[2] == 'task_complete' and v.get('started_at') and v.get('completed_at')]
    unfinished_turns = [v for k, v in turns.items() if k[2] == 'task_started' and
                        (k[0], k[1], 'task_complete') not in turns]
    for turn in unfinished_turns:
        turn['terminal_event'] = 'turn_aborted' if (turn['thread_id'], turn['turn_id'], 'turn_aborted') in turns else 'not observed'
    sessions = []
    for tid, m in metadata.items():
        rs = [r for r in rows if r['thread_id'] == tid]
        if not rs:
            # A created guardian with zero records is unknown, not proof of zero consumption.
            model_labels = []
        else:
            model_labels = sorted({r['model'] for r in rs})
        sessions.append({'thread_id': tid, 'session_id': m['session_id'], 'parent_thread_id': m['parent_thread_id'],
                         'agent': m['agent'], 'agent_kind': 'automatic-review' if m['agent'] == '/guardian' else 'development',
                         'metadata_worktree': Path(m['cwd']).name if m.get('cwd') else 'unknown',
                         'first_observed': extras[tid]['first'], 'last_observed': extras[tid]['last'],
                         'models': model_labels, 'worktree_groups': sorted({r['worktree_group'] for r in rs}),
                         'diagnostics': per_thread[tid], 'measurement': 'response records' if rs else 'no recorded usage',
                         'unclosed_turns_with_usage': sum(e['thread_id'] == tid for e in unfinished_turns),
                         **totals(rs)})
    worktrees = []
    for tree in repo['worktrees']:
        name = tree['path'].name
        if name == 'doom-evm-usage-audit':
            continue
        exact = [r for r in rows if r['worktree_group'] == name]
        shared = [r for r in rows if name in r['worktree_group'].split('|') and r not in exact]
        rs = exact + shared
        worktrees.append({'worktree': name, 'path_alias': '$REPO' if name == 'doom-evm' else '$WORKTREES/'+name,
                          'branch': (tree['branch'] or 'detached').removeprefix('refs/heads/'), 'head': tree['head'],
                          'sessions': sorted({r['thread_id'] for r in rs}), 'agents': sorted({r['agent'] for r in rs}),
                          'workstreams': sorted({r['workstream'] for r in rs}),
                          'first_usage': min((r['timestamp'] for r in rs), default=None),
                          'last_usage': max((r['timestamp'] for r in rs), default=None),
                          'exclusive_total_tokens': sum(r['tokens']['total_tokens'] or 0 for r in exact),
                          'shared_session_total_tokens_nonadditive': sum(r['tokens']['total_tokens'] or 0 for r in shared),
                          'attribution': 'shared-session-unsplit' if shared else 'reviewed-or-metadata' if exact else 'no-separate-session-attribution',
                          'missing_or_ambiguous': 'Exact division among directories unavailable' if shared else None if exact else 'No independently attributable usage; zero is not a measured cost'})
    sources.sort(key=lambda s: s['source_id'])
    phases = group(rows, ['phase'])
    legacy_threads = {m['thread_id'] for m in metadata.values() if m.get('cwd') and discovery.beneath(Path(m['cwd']).resolve(), next((w['path'] for w in repo['worktrees'] if w['path'].name == 'doom-evm'), Path(project).resolve()))}
    while True:
        children = {m['thread_id'] for m in metadata.values() if m['parent_thread_id'] in legacy_threads}
        if children <= legacy_threads: break
        legacy_threads |= children
    missing_from_legacy = [r for r in rows if r['thread_id'] not in legacy_threads]
    return {'version': 1, 'cutoff_exclusive': policy['cutoff'], 'completeness': 'measured lower bound from available local structured records',
            'totals': totals(rows), 'by_phase': phases, 'by_workstream': group(rows, ['workstream']),
            'by_goal': group(rows, ['goal_id', 'goal']), 'by_agent_kind': group(rows, ['agent_kind']),
            'by_model': group(rows, ['model']), 'by_worktree_group': group(rows, ['worktree_group']),
            'sessions': sorted(sessions, key=lambda s: (s['first_observed'] or '', s['thread_id'])),
            'worktree_coverage': worktrees, 'goals': goals,
            'compactions': sorted(compactions.values(), key=lambda c: c['timestamp']),
            'compaction_usage_already_in_total': totals([r for r in rows if r['response_kind'] == 'compaction']),
            'turn_intervals': sorted(complete_turns, key=lambda t: t['timestamp']),
            'unclosed_turns_with_usage': sorted(unfinished_turns, key=lambda t: t['timestamp']),
            'parallel_activity': concurrency(complete_turns),
            'time': {'first_usage': rows[0]['timestamp'] if rows else None, 'last_usage': rows[-1]['timestamp'] if rows else None,
                     'completed_turn_wall_seconds_sum': sum(e['duration_ms']/1000 for e in complete_turns if type(e['duration_ms']) in (int, float)),
                     'completed_turn_interval_union_seconds': union_seconds([(e['started_at'], e['completed_at']) for e in complete_turns]),
                     'active_model_compute_seconds': None, 'human_approval_wait_seconds': None,
                     'caution': 'Turn wall intervals include tools and waiting, can overlap, and are not model compute time.'},
            'legacy_discovery_comparison': {'selected_threads': len(legacy_threads), 'missed_threads_with_usage': len({r['thread_id'] for r in missing_from_legacy}),
                                            'missed_usage': totals(missing_from_legacy),
                                            'legacy_usage_same_cutoff': totals([r for r in rows if r['thread_id'] in legacy_threads])},
            'source_coverage': {'discovered_files': len(sources), 'successfully_parsed_files': sum(s['parsed_records'] > 0 for s in sources),
                                'project_files': sum(s['decision'] == 'project' for s in sources),
                                'rejected_files': sum(s['decision'].startswith('rejected') for s in sources),
                                'decisions': dict(collections.Counter(s['decision'] for s in sources)),
                                'parse_diagnostics': dict(all_diagnostics),
                                'adapter_diagnostics': dict(adapter_diagnostics),
                                'duplicate_project_session_files': sum(s['decision'] == 'project' for s in sources) - len(metadata),
                                'duplicate_response_copies': sum(v.get('duplicate_response_copies_excluded', 0) for v in per_thread.values()),
                                'conflicting_response_ids': sum(v.get('conflicting_response_ids_excluded', 0) for v in per_thread.values()),
                                'sessions_without_usage': sum(not s['records'] for s in sessions),
                                'sessions_with_unclosed_turns': sum(bool(s['unclosed_turns_with_usage']) for s in sessions),
                                'accounting_diagnostics': dict(sum((collections.Counter(v) for v in per_thread.values()), collections.Counter()))},
            'sources': sources}, rows


def export(report, rows, output):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    (output/'usage.json').write_text(json.dumps(report, indent=2)+'\n')
    (output/'sources.json').write_text(json.dumps({'cutoff_exclusive': report['cutoff_exclusive'], 'sources': report['sources']}, indent=2)+'\n')
    tables = {key+'.csv': report[key] for key in ('by_phase', 'by_workstream', 'by_goal', 'by_model', 'by_agent_kind', 'by_worktree_group', 'sessions', 'worktree_coverage', 'turn_intervals')}
    tables['records.csv'] = [{**{k: v for k, v in r.items() if k != 'tokens'}, **r['tokens']} for r in rows]
    for name, data in tables.items():
        columns = list(dict.fromkeys(k for row in data for k in row))
        with (output/name).open('w', newline='') as stream:
            writer = csv.DictWriter(stream, fieldnames=columns, lineterminator='\n'); writer.writeheader()
            writer.writerows({k: json.dumps(v, sort_keys=True) if isinstance(v, (list, dict)) else v for k, v in row.items()} for row in data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', default=str(Path.cwd()))
    parser.add_argument('--logs', action='append')
    parser.add_argument('--policy', default='tools/usage/audit-policy.json')
    parser.add_argument('--phases', default='tools/usage/phases.json')
    parser.add_argument('--snapshot', help='sources.json: verify and read precisely the original source prefixes')
    parser.add_argument('--output', default='artifacts/local/usage-audit/final')
    args = parser.parse_args()
    policy = json.loads(Path(args.policy).read_text())
    snapshot = json.loads(Path(args.snapshot).read_text()) if args.snapshot else None
    report, rows = scan(args.logs or discovery.default_roots(), args.project, policy, collect.load_windows(args.phases), snapshot)
    report['inputs'] = {name: {'filename': Path(path).name, 'sha256': collect.digest(Path(path).read_bytes())}
                        for name, path in [('policy', args.policy), ('historical_phases', args.phases)]}
    report['collector_sources'] = {p.name: collect.digest(p.read_bytes()) for p in
                                   (Path(__file__).with_name(name) for name in
                                    ('audit.py', 'collect.py', 'discovery.py', 'phases.py', 'verify_audit.py'))}
    export(report, rows, args.output)
    print(json.dumps({'totals': report['totals'], 'source_coverage': report['source_coverage'], 'legacy_discovery_comparison': report['legacy_discovery_comparison']}))


if __name__ == '__main__':
    main()
