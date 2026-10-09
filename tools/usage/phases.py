#!/usr/bin/env python3
"""Recover structured goal boundaries or mark future phases; never export transcripts."""
import argparse
import json
from pathlib import Path
import re
import sys
from collect import VERSION, identity, inventory, load_windows, now, read_lines, timestamp
import collections


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for v in value:
            yield from strings(v)
    elif isinstance(value, dict):
        for key in ('text', 'content', 'output'):
            if key in value:
                yield from strings(value[key])


def recover(roots, project):
    files, _ = inventory(roots, project)
    goals = {}
    decoder = json.JSONDecoder()
    for path, meta in files.items():
        if meta['forked']:
            continue  # Root goal boundaries; inherited child history is not new evidence.
        for ordinal, r in read_lines(path, collections.Counter()):
            p = r.get('payload')
            if not isinstance(p, dict):
                continue
            candidates = []
            kind = r.get('type')
            if kind == 'event_msg' and p.get('type') == 'thread_goal_updated':
                candidates = [p.get('goal')]
            elif kind == 'response_item' and p.get('type') in ('custom_tool_call_output', 'function_call_output'):
                # Programmatically extract only an explicitly structured goal object.
                # The surrounding output is discarded and never printed or saved.
                for text in strings(p.get('output')):
                    for match in re.finditer(r'\{\s*"goal"\s*:', text):
                        try:
                            obj, _ = decoder.raw_decode(text[match.start():])
                            candidates.append(obj.get('goal'))
                        except (ValueError, AttributeError):
                            continue
            for goal in candidates:
                if not isinstance(goal, dict) or goal.get('threadId') != meta['thread_id']:
                    continue
                match = re.search(r'\bPhase\s+([0-9]+)\b', goal.get('objective', ''), re.I)
                if not match or type(goal.get('createdAt')) is not int:
                    continue
                key = (meta['session_id'], goal['createdAt'])
                evidence = {'timestamp': timestamp(r['timestamp']), 'source_id': identity(path),
                            'line': ordinal + 1, 'event_type': kind, 'goal_created_at_unix': goal['createdAt']}
                row = goals.setdefault(key, {'phase': 'phase' + match[1], 'session_id': meta['session_id']})
                if kind == 'event_msg' and goal.get('status') == 'active' and goal.get('tokensUsed') == 0:
                    if 'start' not in row or evidence['timestamp'] < row['start']:
                        row.update(start=evidence['timestamp'], start_evidence=evidence)
                if goal.get('status') == 'complete':
                    if 'end' not in row or evidence['timestamp'] < row['end']:
                        row.update(end=evidence['timestamp'], end_evidence=evidence)
                        row['separate_goal_counter'] = {k: goal.get(k) for k in ('tokensUsed', 'timeUsedSeconds')}
    complete = [r for r in goals.values() if 'start' in r and 'end' in r]
    return {'version': VERSION, 'policy': 'Half-open windows from recorded goal start/completion events; gaps remain unattributed. Goal counters are retained separately and never summed with response usage.',
            'windows': sorted(complete, key=lambda w: w['start']),
            'incomplete_goals': [r for r in goals.values() if 'start' not in r or 'end' not in r]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    recovery = sub.add_parser('recover')
    recovery.add_argument('--logs', action='append')
    recovery.add_argument('--project', default=str(Path.cwd()))
    recovery.add_argument('--output', required=True)
    marker = sub.add_parser('mark')
    marker.add_argument('--file', required=True)
    marker.add_argument('--phase', required=True)
    marker.add_argument('--session', required=True)
    marker.add_argument('--at', help='ISO timestamp with timezone; defaults to now')
    marker.add_argument('--evidence', default='explicit local phase marker')
    args = parser.parse_args()
    try:
        if args.command == 'recover':
            target = Path(args.output)
            if target.exists():
                raise ValueError('Refusing to overwrite existing phase ledger; use a new output and review')
            config = recover(args.logs or [Path.home()/'.codex/sessions', Path.home()/'.codex/archived_sessions'], args.project)
        else:
            target = Path(args.file);config = load_windows(target)
            at = timestamp(args.at) if args.at else now()
            for window in config['windows']:
                if window.get('session_id') == args.session and not window.get('end'):
                    window['end'] = at
            config['windows'].append({'phase': args.phase, 'session_id': args.session, 'start': at,
                                      'end': None, 'start_evidence': {'kind': 'explicit_marker', 'note': args.evidence}})
        target.parent.mkdir(parents=True, exist_ok=True)
        temp = target.with_suffix(target.suffix + '.tmp')
        temp.write_text(json.dumps(config, indent=2) + '\n')
        load_windows(temp)  # Reject invalid/overlapping intervals before replacing anything.
        temp.replace(target)
        print(json.dumps({'file': str(target), 'windows': len(config['windows'])}))
    except (OSError, ValueError, TypeError):
        print('Phase ledger operation failed; verify timestamps, destination and non-overlapping windows.', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
