#!/usr/bin/env python3
"""Independent direct-response reconciliation of the final audit (no accounting adapter)."""
import argparse
import collections
import csv
from datetime import datetime
import hashlib
import json
from pathlib import Path


def sha(data): return hashlib.sha256(data).hexdigest()


def stamp(value): return datetime.fromisoformat(value.replace('Z', '+00:00'))


def verify(report_dir, roots, historical, phases):
    report_dir = Path(report_dir)
    report = json.loads((report_dir/'usage.json').read_text())
    exported = list(csv.DictReader((report_dir/'records.csv').open()))
    source_index = {s['source_id']: s for s in report['sources']}
    paths = {}
    for root in roots:
        root = Path(root).expanduser()
        for p in [root] if root.is_file() else root.rglob('*.jsonl'):
            paths[sha(str(p.resolve()).encode())[:20]] = p
    raw, duplicates, conflicts, backup_ids = {}, 0, set(), set()
    for sid, source in source_index.items():
        with paths[sid].open('rb') as stream:
            data = stream.read(source['snapshot_bytes'])
        assert sha(data) == source['snapshot_sha256'], 'source prefix identity changed'
        if source['decision'] != 'project': continue
        owner = None
        for number, line in enumerate(data.splitlines(keepends=True), 1):
            if not line.endswith(b'\n'): continue
            try: r = json.loads(line)
            except (ValueError, UnicodeError): continue
            p = r.get('payload') or {}
            if not isinstance(p, dict): continue
            if r.get('type') == 'session_meta' and owner is None: owner = p
            if not owner or stamp(r['timestamp']) >= stamp(report['cutoff_exclusive']): continue
            if r.get('type') == 'compacted':
                nested = p.get('latest_token_usage_record') or {}
                if nested.get('thread_id') == owner['id']:
                    backup_ids.add((owner['id'], nested.get('response_id')))
            if r.get('type') != 'token_usage_record' or p.get('thread_id') != owner['id']: continue
            u = p.get('usage') or {}
            key = (owner['id'], p.get('response_id'))
            if not key[1]: continue
            # This independent adapter is intentionally specific to the observed direct-field schema.
            counts = {k: u.get(k) for k in ('input_tokens', 'cached_input_tokens', 'output_tokens', 'total_tokens', 'cache_write_input_tokens')}
            counts['reasoning_tokens'] = u.get('reasoning_output_tokens')
            counts['non_cached_input_tokens'] = counts['input_tokens'] - counts['cached_input_tokens']
            assert all(type(n) is int and n >= 0 for n in counts.values()), 'incomplete/invalid direct usage requires review'
            assert counts['input_tokens'] + counts['output_tokens'] == counts['total_tokens']
            assert counts['reasoning_tokens'] <= counts['output_tokens']
            if key in raw:
                duplicates += 1
                if raw[key]['tokens'] != counts: conflicts.add(key)
            else:
                raw[key] = {'tokens': counts, 'timestamp': r['timestamp'], 'session_id': owner.get('session_id') or owner['id'],
                            'source_id': sid, 'source_line': number,
                            'event_sha256': sha(json.dumps(r, sort_keys=True, separators=(',', ':')).encode())}
    for key in conflicts: del raw[key]
    assert not backup_ids - raw.keys(), 'compaction backup contains usage absent from the direct event ledger'
    assert len(exported) == len(raw), 'raw/exported response counts differ'
    assert len({(r['thread_id'], r['response_id']) for r in exported}) == len(exported)
    for row in exported:
        direct = raw[(row['thread_id'], row['response_id'])]
        assert row['method'] == 'response_record', 'independent adapter requires direct response records'
        assert row['source_id'] == direct['source_id'] and int(row['source_line']) == direct['source_line']
        assert row['event_sha256'] == direct['event_sha256']
        for field, value in direct['tokens'].items(): assert int(row[field]) == value, field
    fields = list(next(iter(raw.values()))['tokens'])
    summed = {field: sum(v['tokens'][field] for v in raw.values()) for field in fields}
    for field in fields: assert summed[field] == report['totals'][field], field
    for category, keys in [('by_phase', ['phase']), ('by_workstream', ['workstream']), ('by_goal', ['goal_id', 'goal']),
                           ('by_model', ['model']), ('by_agent_kind', ['agent_kind']), ('by_worktree_group', ['worktree_group'])]:
        for aggregate in report[category]:
            selected = [r for r in exported if all(r[k] == aggregate[k] for k in keys)]
            assert len(selected) == aggregate['records']
            for field in fields: assert sum(int(r[field]) for r in selected) == aggregate[field], (category, field)
        assert sum(a['total_tokens'] for a in report[category]) == summed['total_tokens'], category
    for session in report['sessions']:
        selected = [r for r in exported if r['thread_id'] == session['thread_id']]
        assert len(selected) == session['records']
        for field in fields: assert sum(int(r[field]) for r in selected) == session[field]
    historical_report = json.loads(Path(historical).read_text())
    historical_csv = list(csv.DictReader(Path(historical).with_name('metrics.csv').open()))
    windows = json.loads(Path(phases).read_text())['windows']
    reconciliation = []
    for phase in ('phase0', 'phase1', 'phase2'):
        w = next(w for w in windows if w['phase'] == phase)
        selected = [v for v in raw.values() if v['session_id'] == w['session_id'] and stamp(w['start']) <= stamp(v['timestamp']) < stamp(w['end'])]
        old = next(v for v in historical_report['phase_totals'] if v['phase'] == phase)
        measured = {field: sum(v['tokens'][field] for v in selected) for field in fields}
        difference = {field: measured[field] - old[field] for field in fields if field in old}
        assert not any(difference.values()) and len(selected) == old['records']
        old_csv_rows = [r for r in historical_csv if r['phase'] == phase]
        for field in difference:
            assert sum(int(r[field]) for r in old_csv_rows) == measured[field], ('historical CSV', phase, field)
        assert sum(int(r['records']) for r in old_csv_rows) == len(selected)
        reconciliation.append({'phase': phase, 'old_records': old['records'], 'recovered_records': len(selected),
                               'original': {f: old[f] for f in fields if f in old}, 'recovered': measured,
                               'difference': difference, 'confidence': 'exact raw structured-record reproduction'})
    # Historical evidence fingerprints identify immutable exports; their raw source prefixes still verify.
    matched_historical_prefixes = 0
    for source in historical_report['sources']:
        with paths[source['source_id']].open('rb') as stream: data = stream.read(source['snapshot_bytes'])
        assert sha(data) == source['snapshot_sha256']
        matched_historical_prefixes += 1
    return {'status': 'pass', 'method': 'independent direct token_usage_record parser; no collect.account_thread or audit.scan accounting',
            'records': len(raw), 'totals': summed, 'duplicate_response_events': duplicates, 'conflicting_response_ids': len(conflicts),
            'compaction_backups_without_direct_usage_record': len(backup_ids - raw.keys()),
            'historical_source_prefixes_verified': matched_historical_prefixes,
            'historical_report_sha256': sha(Path(historical).read_bytes()),
            'historical_metrics_csv_sha256': sha(Path(historical).with_name('metrics.csv').read_bytes()),
            'historical_reconciliation': reconciliation}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', required=True)
    parser.add_argument('--logs', action='append')
    parser.add_argument('--historical', default='artifacts/usage/historical/usage.json')
    parser.add_argument('--phases', default='tools/usage/phases.json')
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    from discovery import default_roots
    result = verify(args.report, args.logs or default_roots(), args.historical, args.phases)
    Path(args.output).write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({'status': result['status'], 'records': result['records'], 'total_tokens': result['totals']['total_tokens']}))


if __name__ == '__main__': main()
