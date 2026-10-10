#!/usr/bin/env python3
"""Offline Codex accounting. Never exports message, reasoning or tool-output text."""
import argparse
import collections
import csv
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import sys
import time

FIELDS = ('input_tokens', 'cached_input_tokens', 'cache_write_input_tokens',
          'output_tokens', 'reasoning_tokens', 'total_tokens')
VERSION = 1
REPORT_VERSION = 2


def timestamp(value):
    if not isinstance(value, str):
        raise ValueError('timestamp must be an ISO-8601 string')
    parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if parsed.tzinfo is None:
        raise ValueError('timestamp requires timezone')
    return parsed.astimezone(timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z')


def now():
    return timestamp(datetime.now(timezone.utc).isoformat())


def digest(value):
    return hashlib.sha256(value).hexdigest()


def identity(value):
    return digest(str(value).encode())[:20]


def counts(value):
    value = value if isinstance(value, dict) else {}
    result = {}
    for key in FIELDS:
        v = value.get(key)
        if key == 'reasoning_tokens':
            v = value.get('reasoning_output_tokens', v)
            if v is None:
                v = (value.get('output_tokens_details') or {}).get('reasoning_tokens')
        if key == 'cached_input_tokens' and v is None:
            v = (value.get('input_tokens_details') or {}).get('cached_tokens')
        result[key] = v if type(v) is int and v >= 0 else None
    if result['total_tokens'] is None and all(result[k] is not None for k in ('input_tokens', 'output_tokens')):
        result['total_tokens'] = result['input_tokens'] + result['output_tokens']
    return result


def sum_counts(rows):
    result = {}
    for key in FIELDS:
        known = [r['tokens'][key] for r in rows if r['tokens'][key] is not None]
        result[key] = sum(known) if known else None
        result[key + '_missing_records'] = len(rows) - len(known)
    return result


def read_lines(path, diagnostics, receipt=None):
    """Bound reads to initial size. A live writer's incomplete tail is not a record."""
    size = path.stat().st_size
    sha = hashlib.sha256()
    with path.open('rb') as stream:
        remaining = size
        ordinal = 0
        while remaining:
            line = stream.readline(remaining)
            remaining -= len(line)
            sha.update(line)
            if not line.endswith(b'\n'):
                diagnostics['incomplete_tail_lines'] += 1
                break
            try:
                record = json.loads(line)
                if isinstance(record, dict):
                    yield ordinal, record
                else:
                    diagnostics['invalid_record_shapes'] += 1
            except (ValueError, UnicodeDecodeError):
                diagnostics['malformed_lines'] += 1
            ordinal += 1
    if receipt is not None:
        receipt.update(snapshot_bytes=size - remaining, initial_size_bytes=size, snapshot_sha256=sha.hexdigest())


def inventory(roots, project):
    """Only first metadata owns a rollout; later metadata can be inherited history."""
    files = {}
    for location in roots:
        location = Path(location).expanduser()
        paths = [location] if location.is_file() else location.rglob('*.jsonl')
        for path in paths:
            path = path.resolve()
            if path in files:
                continue
            diag = collections.Counter()
            for _, record in read_lines(path, diag):
                if record.get('type') != 'session_meta':
                    continue
                p = record.get('payload') or {}
                if not isinstance(p, dict) or not isinstance(p.get('id'), str):
                    break
                source = p.get('source')
                spawn = source.get('subagent', {}).get('thread_spawn', {}) if isinstance(source, dict) else {}
                files[path] = {
                    'thread_id': p['id'], 'session_id': p.get('session_id') or p['id'],
                    'parent_thread_id': p.get('parent_thread_id') or spawn.get('parent_thread_id'),
                    'agent': p.get('agent_path') or spawn.get('agent_path') or ('unknown-child' if p.get('forked_from_id') else '/root'),
                    'cwd': p.get('cwd'), 'cli_version': p.get('cli_version'),
                    'fork_ordinal': p.get('subagent_history_start_ordinal'),
                    'forked': bool(p.get('forked_from_id') or p.get('parent_thread_id') or spawn),
                }
                break
    project = Path(project).resolve()
    selected = {m['thread_id'] for m in files.values() if m['cwd'] and
                (Path(m['cwd']).resolve() == project or project in Path(m['cwd']).resolve().parents)}
    while True:
        children = {m['thread_id'] for m in files.values() if m['parent_thread_id'] in selected}
        if children <= selected:
            break
        selected |= children
    return {p: m for p, m in files.items() if m['thread_id'] in selected}, len(files)


def load_windows(path):
    config = json.loads(Path(path).read_text()) if path else {'version': VERSION, 'windows': []}
    if not isinstance(config, dict) or config.get('version') != VERSION or not isinstance(config.get('windows'), list):
        raise ValueError('unsupported phase ledger schema')
    windows = config.get('windows', [])
    for w in windows:
        if not isinstance(w.get('phase'), str) or not w['phase']:
            raise ValueError('phase requires a name')
        w['start'] = timestamp(w['start'])
        if w.get('end'):
            w['end'] = timestamp(w['end'])
            if w['end'] <= w['start']:
                raise ValueError('phase end must follow start')
    for i, a in enumerate(windows):
        for b in windows[i + 1:]:
            scopes_overlap = not a.get('session_id') or not b.get('session_id') or a['session_id'] == b['session_id']
            if scopes_overlap and a['start'] < (b.get('end') or '~') and b['start'] < (a.get('end') or '~'):
                raise ValueError('overlapping phase windows')
    return config


def phase_at(stamp, session, windows):
    names = [w['phase'] for w in windows if (not w.get('session_id') or w['session_id'] == session)
             and w['start'] <= stamp < (w.get('end') or '~')]
    return names[0] if names else 'unattributed'


def phase_interval(start, end, session, windows):
    # A cumulative delta spanning a boundary cannot be split into exact phase totals.
    points = [end] if start is None else [start, end]
    crossing = start is not None and any(start < point <= end for w in windows
                if not w.get('session_id') or w['session_id'] == session
                for point in (w['start'], w.get('end')) if point)
    names = {phase_at(p, session, windows) for p in points}
    return 'ambiguous-boundary' if crossing or len(names) != 1 else names.pop()


def parse_rollout(path, meta, diagnostics):
    events, models = [], []
    model = 'unknown'
    turn_id = None
    last_model = None
    model_by_turn = {}
    models_by_turn = collections.defaultdict(set)
    revision = 0
    receipt = {}
    own_start = meta['fork_ordinal'] if type(meta['fork_ordinal']) is int else None
    for ordinal, r in read_lines(path, diagnostics, receipt):
        p = r.get('payload')
        if not isinstance(p, dict):
            continue
        kind = r.get('type')
        if kind not in ('turn_context', 'token_usage_record', 'event_msg'):
            continue  # Message, reasoning, summaries and tool outputs never enter exports.
        if meta['forked'] and own_start is not None and ordinal < own_start:
            continue
        try:
            stamp = timestamp(r.get('timestamp'))
        except (ValueError, TypeError):
            diagnostics['invalid_timestamps'] += 1
            continue
        if kind == 'turn_context':
            model = p.get('model') if isinstance(p.get('model'), str) else 'unknown'
            turn_id = p.get('turn_id')
            model_by_turn[turn_id] = model
            models_by_turn[turn_id].add(model)
            if model != last_model:
                revision += 1
                models.append({'timestamp': stamp, 'model': model, 'thread_id': meta['thread_id'],
                               'turn_id': turn_id, 'evidence': 'turn_context', 'source_id': identity(path), 'line': ordinal + 1})
                last_model = model
        elif kind == 'token_usage_record':
            if p.get('thread_id') != meta['thread_id']:
                diagnostics['inherited_response_records_excluded'] += 1
                continue
            events.append({'kind': 'response', 'timestamp': stamp, 'model': model_by_turn.get(p.get('turn_id'), 'unknown'),
                           'turn_id': p.get('turn_id'), 'response_id': p.get('response_id'),
                           'tokens': counts(p.get('usage')), 'cumulative': counts(p.get('thread_token_usage')),
                           'source_id': identity(path), 'line': ordinal + 1})
        elif p.get('type') == 'token_count':
            if meta['forked'] and own_start is None:
                diagnostics['unbounded_fork_counters_excluded'] += 1
                continue
            info = p.get('info') or {}
            if isinstance(info, dict) and isinstance(info.get('total_token_usage'), dict):
                events.append({'kind': 'counter', 'timestamp': stamp, 'model': model, 'model_revision': revision, 'turn_id': turn_id,
                               'tokens': counts(info['total_token_usage']),
                               'last': counts(info.get('last_token_usage')),
                               'source_id': identity(path), 'line': ordinal + 1})
    for event in events:
        if event['kind'] == 'response' and event['model'] == 'unknown':
            candidates = models_by_turn.get(event.get('turn_id'), set()) - {'unknown'}
            if len(candidates) == 1:
                event['model'] = next(iter(candidates))
                event['model_evidence'] = 'configured_same_turn_late_context'
                diagnostics['models_recovered_from_late_same_turn_context'] += 1
    return events, models, receipt


def account_thread(meta, events, windows, diagnostics):
    events = sorted(events, key=lambda e: (e['timestamp'], e['source_id'], e['line']))
    responses = [e for e in events if e['kind'] == 'response']
    rows = []

    def add(event, tokens, method, start=None, unattributed=False, ambiguous_model=False):
        rows.append({k: meta[k] for k in ('session_id', 'thread_id', 'parent_thread_id', 'agent')})
        rows[-1].update(timestamp=event['timestamp'], interval_start=start,
                       phase='unattributed' if unattributed else phase_interval(start, event['timestamp'], meta['session_id'], windows),
                       model='unknown' if unattributed or ambiguous_model else event['model'],
                       model_evidence='unknown' if unattributed or ambiguous_model or event['model'] == 'unknown'
                       else event.get('model_evidence', 'configured_turn_context'),
                       method=method, tokens=tokens, source_id=event['source_id'], source_line=event['line'],
                       response_id=event.get('response_id'), turn_id=event.get('turn_id'))

    if responses:
        # These are individual responses. Neither turn/thread totals nor UI counters
        # are additive. Never blend cumulative and response sources for one thread.
        unique = {}
        conflicts = set()
        for e in responses:
            key = e.get('response_id')
            if not isinstance(key, str) or not key:
                diagnostics['response_records_without_id_excluded'] += 1
                continue
            if key in unique:
                if e['tokens'] != unique[key]['tokens']:
                    conflicts.add(key)
                else:
                    diagnostics['duplicate_response_copies_excluded'] += 1
            else:
                unique[key] = e
        diagnostics['conflicting_response_ids_excluded'] += len(conflicts)
        for key, e in unique.items():
            if key not in conflicts:
                add(e, e['tokens'], 'response_record')
        diagnostics['cumulative_events_not_added'] += len(events) - len(responses)
        # Report missing coverage; do not silently fill it using a second ledger.
        for field in FIELDS:
            known = [e['cumulative'][field] for e in responses if e['cumulative'][field] is not None]
            reported = sum(r['tokens'][field] or 0 for r in rows)
            if known and max(known) != reported:
                diagnostics['response_vs_cumulative_mismatch_' + field] += 1
        return rows

    previous = None
    frozen = False
    seen = set()
    for e in events:
        key = (e['timestamp'], tuple(e['tokens'].values()))
        if key in seen:
            diagnostics['duplicate_counter_copies_excluded'] += 1
            continue
        seen.add(key)
        c = e['tokens']
        if any(c[k] is None for k in ('input_tokens', 'output_tokens', 'total_tokens')):
            diagnostics['incomplete_cumulative_snapshots_excluded'] += 1
            continue
        if frozen:
            diagnostics['counter_snapshots_after_ambiguous_reset_excluded'] += 1
            continue
        if previous is None:
            last = e['last']
            valid_last = (all(last[k] is not None and last[k] <= c[k] for k in ('input_tokens', 'output_tokens', 'total_tokens'))
                          and all(last[k] <= c[k] for k in FIELDS if last[k] is not None and c[k] is not None))
            if valid_last:
                add(e, last, 'last_usage_at_first_snapshot')
            baseline = {k: (c[k] - last[k] if valid_last and last[k] is not None and c[k] is not None else c[k]) for k in FIELDS}
            if meta['forked']:
                diagnostics['fork_cumulative_baselines_excluded'] += 1
            elif not valid_last or any(v for v in baseline.values() if v is not None):
                add(e, baseline, 'unattributed_initial_cumulative', unattributed=True)
            previous = e
            continue
        if any(c[k] is not None and previous['tokens'][k] is not None and c[k] < previous['tokens'][k] for k in FIELDS):
            diagnostics['ambiguous_counter_reset_or_correction'] += 1
            frozen = True  # No evidence distinguishes reset from correction/replay.
            continue
        delta = {k: c[k] - previous['tokens'][k] if c[k] is not None and previous['tokens'][k] is not None else None for k in FIELDS}
        if any(v for v in delta.values() if v is not None):
            add(e, delta, 'cumulative_delta', previous['timestamp'],
                ambiguous_model=e['model'] != previous['model'] or e.get('model_revision') != previous.get('model_revision'))
        else:
            diagnostics['repeated_cumulative_snapshots_excluded'] += 1
        previous = e
    return rows


def aggregate(rows):
    buckets = collections.defaultdict(list)
    for row in rows:
        key = tuple(row[k] for k in ('session_id', 'thread_id', 'agent', 'phase', 'model', 'method'))
        buckets[key].append(row)
    return [{**dict(zip(('session_id', 'thread_id', 'agent', 'phase', 'model', 'method'), key)),
             'records': len(values), **sum_counts(values)} for key, values in sorted(buckets.items())]


def collect(roots, project, config, closed_only=False):
    files, discovered = inventory(roots, project)
    diagnostics = collections.Counter()
    by_thread = collections.defaultdict(list)
    metadata, sources, models = {}, [], []
    for path, meta in sorted(files.items()):
        events, switches, receipt = parse_rollout(path, meta, diagnostics)
        tid = meta['thread_id']
        if tid in metadata and any(meta[k] != metadata[tid][k] for k in ('session_id', 'agent', 'parent_thread_id')):
            raise ValueError('conflicting owning session metadata')
        metadata[tid] = meta
        by_thread[tid].extend(events)
        models.extend(switches)
        # Fingerprint exactly the bounded bytes used by this scan, independently of
        # any subsequent writes. Active files may grow; no transcript is copied.
        sources.append({'source_id': identity(path), 'thread_id': tid, 'cli_version': meta['cli_version'], **receipt})
    rows = []
    for tid, events in by_thread.items():
        rows += account_thread(metadata[tid], events, config['windows'], diagnostics)
    rows.sort(key=lambda r: (r['timestamp'], r['thread_id'], r.get('response_id') or ''))
    observed_records = len(rows)
    if closed_only:
        rows = [r for r in rows if any(w.get('end') and w['phase'] == r['phase']
                and (not w.get('session_id') or w['session_id'] == r['session_id'])
                and w['start'] <= r['timestamp'] < w['end'] for w in config['windows'])]
    segments = []
    for tid in sorted(metadata):
        current = []
        for r in [r for r in rows if r['thread_id'] == tid]:
            if current and tuple(r[k] for k in ('phase', 'model', 'method')) != tuple(current[-1][k] for k in ('phase', 'model', 'method')):
                segments.append(segment(current)); current = []
            current.append(r)
        if current:
            segments.append(segment(current))
    unique_models = {(m['thread_id'], m['turn_id'], m['timestamp'], m['model']): m for m in models}
    report = {'version': REPORT_VERSION, 'collected_at': now(), 'scope': 'project-matched rollouts and explicitly linked child threads',
            'selection': 'closed_phase_windows' if closed_only else 'all_observed_usage',
            'units': 'tokens; cached input and reasoning are subsets, not additional totals',
            'attribution': 'response event timestamps in half-open phase windows; configured model, not proof of backend routing',
            'coverage': {'discovered_rollouts': discovered, 'selected_rollouts': len(files), 'threads': len(metadata),
                         'usage_records': len(rows), 'observed_records_before_phase_filter': observed_records,
                         'diagnostics': dict(sorted(diagnostics.items()))},
            'phases': config, 'sources': sources, 'totals': sum_counts(rows),
            'phase_totals': [{'phase': phase, 'records': len(group), **sum_counts(group)}
                             for phase in sorted({r['phase'] for r in rows})
                             for group in [[r for r in rows if r['phase'] == phase]]],
            'aggregates': aggregate(rows), 'segments': segments,
            'model_events': sorted(unique_models.values(), key=lambda m: (m['timestamp'], m['thread_id'])), 'records': rows}
    from activity import collect_activity
    report['activity'] = collect_activity(files, config, closed_only)
    return report


def segment(rows):
    return {**{k: rows[0][k] for k in ('session_id', 'thread_id', 'agent', 'phase', 'model', 'method')},
            'start': rows[0]['timestamp'], 'end': rows[-1]['timestamp'], 'records': len(rows), **sum_counts(rows)}


def export(report, output):
    output = Path(output);output.mkdir(parents=True, exist_ok=True)
    temporary = output/'usage.json.tmp'
    temporary.write_text(json.dumps(report, indent=2) + '\n');temporary.replace(output/'usage.json')
    rows = report['aggregates']
    columns = ['session_id', 'thread_id', 'agent', 'phase', 'model', 'method', 'records',
               *[x for k in FIELDS for x in (k, k + '_missing_records')]]
    with (output/'metrics.csv.tmp').open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=columns);writer.writeheader();writer.writerows(rows)
    (output/'metrics.csv.tmp').replace(output/'metrics.csv')
    with (output/'phase-totals.csv.tmp').open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=['phase', 'records', *columns[7:]])
        writer.writeheader();writer.writerows(report['phase_totals'])
    (output/'phase-totals.csv.tmp').replace(output/'phase-totals.csv')
    from reporting import export_activity
    export_activity(report, output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--logs', action='append', help='JSONL file or directory; repeatable. Default: ~/.codex/{sessions,archived_sessions}')
    parser.add_argument('--project', default=str(Path.cwd()))
    parser.add_argument('--phases', help='audited half-open phase windows JSON')
    parser.add_argument('--output', default='artifacts/local/codex-usage')
    parser.add_argument('--closed-only', action='store_true', help='export only usage assigned to closed phase windows')
    parser.add_argument('--aggregate-only', action='store_true', help='omit individual response records; retain aggregates and chronology')
    parser.add_argument('--watch', type=float, help='refresh interval in seconds; foreground only, Ctrl-C stops')
    args = parser.parse_args()
    if args.watch is not None and args.watch < 1:
        parser.error('--watch must be at least one second')
    roots = args.logs or [Path.home()/'.codex/sessions', Path.home()/'.codex/archived_sessions']
    try:
        while True:
            result = collect(roots, args.project, load_windows(args.phases), args.closed_only)
            if args.aggregate_only:
                result.pop('records')
            export(result, args.output)
            print(json.dumps({'output': args.output, 'coverage': result['coverage'], 'totals': result['totals']}), flush=True)
            if not args.watch:
                return
            time.sleep(args.watch)
    except KeyboardInterrupt:
        return
    except (OSError, ValueError, TypeError) as error:
        # Never print a raw input record or a JSON decoding exception containing it.
        print('Collection failed (' + type(error).__name__ + '); check paths, permissions and phase configuration.', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
