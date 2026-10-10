"""Whitelist-only activity telemetry; never exports transcript or command text.

This adapter is independent of the existing token ledger. Nested timings are
annotations on one execution, not extra elapsed time to add to its parent.
"""
import collections
from datetime import datetime, timezone
import hashlib
import json
import math
import re
import shlex


def number(value):
    return value if type(value) in (int, float) and math.isfinite(value) and value >= 0 else None


def seconds(value):
    if isinstance(value, dict):
        a, b = number(value.get('secs')), number(value.get('nanos', 0))
        return a + b / 1e9 if a is not None and b is not None and b < 1e9 else None
    return number(value)


def mapping(value):
    return value if isinstance(value,dict) else {}


def safe_timestamp(value):
    from collect import timestamp
    try:return timestamp(value)
    except (ValueError,TypeError):return None


def iso_ms(value):
    return datetime.fromtimestamp(value / 1000, timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z')


def elapsed(start, end):
    if not start or not end:
        return None
    delta = (datetime.fromisoformat(end.replace('Z', '+00:00')) - datetime.fromisoformat(start.replace('Z', '+00:00'))).total_seconds()
    return delta if delta >= 0 else None


def interval(payload):
    a, b = number(payload.get('started_at_ms')), number(payload.get('completed_at_ms'))
    if a is not None and b is not None and b >= a:
        return iso_ms(a), iso_ms(b), (b-a)/1000
    return None, None, None


def command_kind(argv):
    """Classify executed heads, not compiler names quoted inside scripts/text.

    Compound/multiline shell programs are deliberately ambiguous. A short
    simple shell invocation, optionally redirected to a log, is supported.
    """
    if not isinstance(argv, list) or not all(isinstance(x, str) for x in argv):
        return 'unknown', None
    words = argv
    if words and words[0].rsplit('/', 1)[-1] in ('bash', 'zsh', 'sh'):
        if len(words) != 3 or words[1] not in ('-c', '-lc') or '<<' in words[2]:
            return 'other', None
        try:
            lexer = shlex.shlex(words[2], posix=True, punctuation_chars=';&|()<>')
            lexer.whitespace_split = True
            words = list(lexer)
        except ValueError:
            return 'unknown', None
        if '\n' in argv[2] or any(x in (';', '&&', '||', '|', '(', ')', '&') for x in words):
            # Multi-command wall time is not a standalone Forge duration. Still
            # recover a reported stage when one actual executed head is Forge.
            text = argv[2]
            segments, quote, escaped, begin, j = [], None, False, 0, 0
            while j < len(text):
                ch=text[j]
                if escaped:escaped=False
                elif ch=='\\' and quote!="'":escaped=True
                elif quote:
                    if ch==quote:quote=None
                elif ch in ("'", '"'):quote=ch
                elif ch=='`' or text[j:j+2]=='$(' or ch in '|()&' and text[j:j+2] not in ('&&','||'):
                    return 'mixed', None
                elif ch in ';\n' or text[j:j+2] in ('&&','||'):
                    segments.append(text[begin:j]);j += 0 if ch in ';\n' else 1;begin=j+1
                j+=1
            segments.append(text[begin:])
            try:heads=[command_kind(shlex.split(s)) for s in segments if s.strip()]
            except ValueError:return 'mixed',None
            compilers=[(c,k) for c,k in heads if c in ('forge_build','forge_test','solc','native_compiler','compiler_pipeline_wrapper')]
            if len(compilers)==1 and compilers[0][0] in ('forge_build','forge_test'):
                return 'shell_with_'+compilers[0][0], 'forge'
            if len(compilers)==1 and compilers[0][0]=='compiler_pipeline_wrapper':
                return 'compiler_pipeline_wrapper','solc'
            return 'mixed', None
    words = list(words)
    while words and (re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*=.*', words[0]) or words[0] == 'env'):
        words.pop(0)
    if not words:
        return 'unknown', None
    head = words[0].rsplit('/', 1)[-1]
    if head in ('python','python3') and len(words)>1 and (words[1]=='scripts/stack-pressure.py' or words[1].endswith('/scripts/stack-pressure.py')):
        return 'compiler_pipeline_wrapper', 'solc'
    if head == 'forge':
        sub = words[1] if len(words) > 1 else ''
        category = 'forge_build' if sub == 'build' else 'forge_test' if sub == 'test' else 'other'
        return category, 'forge' if category != 'other' else None
    if head == 'solc':
        return ('other', None) if any(x in words for x in ('--version', '--help')) else ('solc', 'solc')
    if head in ('clang', 'clang++', 'gcc', 'g++') and not any(x in words for x in ('--version', '--help')):
        return 'native_compiler', head
    return 'other', None


def stage_timings(output, kind):
    # Only compiler-bearing executed heads qualify. Log readers/echo/embedded
    # Python documentation must never manufacture compiler invocations.
    if kind == 'compiler_pipeline_wrapper' and isinstance(output,str):
        try:
            data=json.loads(output)
            rows=data.get('results',[])
            if isinstance(rows,list) and rows and all(isinstance(r,dict) and number(r.get('compile_wall_ms')) is not None for r in rows):
                return sum(r['compile_wall_ms'] for r in rows)/1000,None,len(rows)
        except (ValueError,TypeError,AttributeError):pass
        return None,None,0
    if kind not in ('forge_build', 'forge_test', 'shell_with_forge_build', 'shell_with_forge_test', 'solc') or not isinstance(output, str):
        return None, None, 0
    units={'s':1,'ms':0.001,'us':0.000001,'µs':0.000001,'μs':0.000001,'ns':0.000000001}
    compiles = re.findall(r'^Solc\s+[^\n]+?finished in\s+([0-9]+(?:\.[0-9]+)?)(ms|us|µs|μs|ns|s)\s*$', output, re.M)
    tests = re.findall(r'^Ran\s+\d+\s+test suites? in\s+([0-9]+(?:\.[0-9]+)?)(ms|us|µs|μs|ns|s)\b', output, re.M)
    # One well-identified stage only. Repeated/multiple summaries stay unknown.
    return (float(compiles[0][0])*units[compiles[0][1]] if len(compiles) == 1 else None,
            float(tests[0][0])*units[tests[0][1]] if kind.endswith('forge_test') and len(tests) == 1 else None,
            len(compiles))


def union_seconds(rows):
    spans = sorted((r['start'], r['end']) for r in rows if r.get('start') and r.get('end'))
    result, active = 0.0, None
    for a, b in spans:
        if active and a <= active[1]:
            active = (active[0], max(active[1], b))
        else:
            if active:
                result += elapsed(*active)
            active = (a, b)
    return result + (elapsed(*active) if active else 0)


def collect_activity(files, config, closed_only=False):
    from collect import read_lines, identity, timestamp, phase_at, phase_interval, counts
    diag = collections.Counter()
    sources, events, goals = [], [], {}
    policies = collections.Counter()
    models_by_turn = collections.defaultdict(set)
    decoder = json.JSONDecoder()

    def base(meta, stamp, ordinal, path):
        return {k: meta[k] for k in ('session_id', 'thread_id', 'agent')} | {
            'timestamp': stamp, 'source_id': identity(path), 'line': ordinal+1}

    def goal_record(g, meta, stamp, pointer):
        if not isinstance(g, dict) or g.get('threadId') != meta['thread_id'] or meta['forked'] or type(g.get('createdAt')) is not int:
            return
        gid = meta['session_id'] + ':' + str(g['createdAt'])
        state = g.get('status') if g.get('status') in ('active', 'paused', 'complete', 'blocked', 'budget_limit', 'usage_limit') else 'unknown'
        row = goals.setdefault(gid, {'goal_id': gid, 'session_id': meta['session_id'], 'created_at': iso_ms(g['createdAt']*1000), 'states': []})
        entry = {'timestamp': stamp, 'status': state, 'reported_goal_tokens': number(g.get('tokensUsed')),
                 'reported_goal_seconds': number(g.get('timeUsedSeconds')), 'source': pointer}
        if entry not in row['states']:
            row['states'].append(entry)

    def structured_goals(output):
        if isinstance(output, list):
            for x in output:
                yield from structured_goals(x)
        elif isinstance(output, dict):
            if isinstance(output.get('goal'), dict):
                yield output['goal']
            for k in ('text', 'output', 'content'):
                yield from structured_goals(output.get(k))
        elif isinstance(output, str):
            for m in re.finditer(r'\{\s*"goal"\s*:', output):
                try:
                    value, _ = decoder.raw_decode(output[m.start():])
                    if isinstance(value.get('goal'), dict):
                        yield value['goal']
                except (ValueError, AttributeError):
                    pass

    for path, meta in sorted(files.items()):
        model, turn, receipt = 'unknown', None, {}
        for ordinal, record in read_lines(path, diag, receipt):
            p = record.get('payload')
            if not isinstance(p, dict):
                continue
            if type(meta.get('fork_ordinal')) is int and ordinal < meta['fork_ordinal']:
                continue
            # Child logs may contain inherited root history after metadata.
            tid = p.get('thread_id', mapping(p.get('latest_token_usage_record')).get('thread_id'))
            if tid and tid != meta['thread_id']:
                diag['inherited_activity_excluded'] += 1
                continue
            try:
                stamp = timestamp(record.get('timestamp'))
            except (ValueError, TypeError):
                diag['invalid_activity_timestamps'] += 1
                continue
            kind, sub = record.get('type'), p.get('type')
            if kind == 'turn_context':
                model, turn = p.get('model') or 'unknown', p.get('turn_id')
                if isinstance(model,str) and isinstance(turn,str):models_by_turn[(meta['thread_id'],turn)].add(model)
                policies[(str(p.get('approval_policy')), str(p.get('approvals_reviewer')))] += 1
                continue
            common = base(meta, stamp, ordinal, path) | {'model': 'unknown', 'turn_id': p.get('turn_id') or turn}
            if kind == 'event_msg' and sub == 'thread_goal_updated':
                goal_record(p.get('goal'), meta, stamp, {'source_id': identity(path), 'line': ordinal+1})
            elif kind == 'response_item' and sub in ('function_call_output', 'custom_tool_call_output'):
                for goal in structured_goals(p.get('output')):
                    goal_record(goal, meta, stamp, {'source_id': identity(path), 'line': ordinal+1})
            if kind == 'compacted' or (kind == 'event_msg' and sub in ('context_compacted', 'compaction_completed')):
                cid = p.get('compaction_response_id') or p.get('compaction_id') or p.get('id') or p.get('window_id')
                if not cid:
                    diag['compactions_without_identity'] += 1
                    cid = identity(meta['thread_id']+':'+stamp)
                latest = mapping(p.get('latest_token_usage_record'))
                same_response = latest.get('response_id') == p.get('compaction_response_id') and bool(p.get('compaction_response_id'))
                resume=mapping(p.get('resume_metadata'));settings = mapping(resume.get('previous_turn_settings'))
                events.append(common | {'kind': 'compaction', 'event_id': str(cid),
                    'turn_id': resume.get('last_started_turn_id') or common['turn_id'],
                    'model': settings.get('model') or 'unknown',
                    'model_evidence': 'compaction_resume_settings' if settings.get('model') else 'unknown',
                    'context_tokens_before': p.get('context_tokens_before') if type(p.get('context_tokens_before')) is int and p['context_tokens_before']>=0 else None,
                    'context_tokens_after': p.get('context_tokens_after') if type(p.get('context_tokens_after')) is int and p['context_tokens_after']>=0 else None,
                    'duration_seconds': seconds(p.get('duration_seconds')),
                    'start': safe_timestamp(p.get('started_at')), 'end': safe_timestamp(p.get('completed_at')),
                    'request_input_tokens': counts(latest.get('usage'))['input_tokens'] if same_response else None,
                    'window_number': p.get('window_number') if type(p.get('window_number')) is int else None,
                    'measurement': 'explicit_compaction_record'})
            elif kind == 'event_msg' and sub == 'item_completed':
                item = mapping(p.get('item'))
                start, end, span = interval(p)
                if item.get('type') == 'ContextCompaction':
                    events.append(common | {'kind': 'compaction_interval', 'event_id': str(item.get('id') or identity(meta['thread_id']+stamp)),
                                           'start': start, 'end': end, 'duration_seconds': span})
                elif item.get('type') == 'CommandExecution':
                    category, compiler = command_kind(item.get('command'))
                    wall = seconds(item.get('duration'))
                    compile_sec, test_sec, stage_count = stage_timings(item.get('aggregated_output'), category)
                    skipped=category.endswith(('forge_build','forge_test')) and bool(re.search(r'^No files changed, compilation skipped\s*$',item.get('aggregated_output',''),re.M))
                    if skipped and stage_count==0:compile_sec=0.0
                    if category in ('solc', 'native_compiler'):
                        compile_sec = wall  # A directly observed compiler process.
                    events.append(common | {'kind': 'execution', 'event_id': str(item.get('id') or identity(meta['thread_id']+stamp)),
                        'start': start, 'end': end, 'wall_seconds': wall,
                        'category': category, 'compiler': compiler, 'compiler_wall_seconds': compile_sec,
                        'compiler_measurement': 'explicit_compilation_skipped' if skipped else 'direct_compiler_process' if category in ('solc','native_compiler') else 'reported_stdout_stage' if compile_sec is not None else 'unavailable',
                        'test_wall_seconds': test_sec, 'compiler_stages_observed': stage_count,
                        'exit_code': item.get('exit_code') if type(item.get('exit_code')) is int else None,
                        'command_sha256': hashlib.sha256(json.dumps(item.get('command'), sort_keys=True).encode()).hexdigest(),
                        'parent_execution_id': item.get('parent_execution_id'), 'measurement': 'structured_command_duration'})
            elif kind == 'event_msg' and sub in ('approval_request', 'exec_approval_request', 'apply_patch_approval_request',
                                                'approval_resolved', 'exec_approval_response', 'apply_patch_approval_response'):
                aid = p.get('approval_id') or p.get('request_id') or p.get('call_id')
                if not aid:
                    diag['approvals_without_identity'] += 1
                    continue
                resolver = p.get('decision_source') or p.get('reviewer')
                actor = 'human' if resolver in ('human', 'user') else 'automatic' if resolver in ('automatic', 'auto_review', 'policy') else 'unknown'
                outcome = p.get('outcome') or p.get('decision')
                outcome = outcome if outcome in ('approved', 'denied', 'rejected', 'cancelled', 'abort', 'accept', 'decline') else 'unknown'
                events.append(common | {'kind': 'approval_request' if sub.endswith('request') else 'approval_resolution',
                                       'event_id': str(aid), 'resolver': actor, 'outcome': outcome})

        sources.append({'source_id': identity(path), 'thread_id': meta['thread_id'], **receipt})

    # Same identity and conflicting metadata is not a safe duplicate. Withhold it.
    grouped = collections.defaultdict(list)
    for e in events:
        grouped[(e['thread_id'], e['kind'], e['event_id'])].append(e)
    clean = []
    for key, group in grouped.items():
        semantic = [{k:v for k,v in e.items() if k not in ('source_id', 'line')} for e in group]
        if any(e != semantic[0] for e in semantic[1:]):
            diag['conflicting_activity_identities_excluded'] += 1
            continue
        clean.append(group[0]); diag['duplicate_activity_copies_excluded'] += len(group)-1
    clean.sort(key=lambda e:(e['timestamp'], e['thread_id'], e['event_id']))
    for e in clean:
        if e.get('model_evidence')=='compaction_resume_settings':continue
        choices=models_by_turn.get((e['thread_id'],e['turn_id']),set())-{'unknown'}
        e['model']=next(iter(choices)) if len(choices)==1 else 'unknown'
        e['model_evidence']='matching_turn_context' if len(choices)==1 else 'unknown'

    # Audited phase windows can supply exact known goal IDs even where creation
    # snapshots were absent. Never export or infer objective prose.
    for w in config['windows']:
        created = w.get('goal_created_at_unix') or (w.get('start_evidence') or {}).get('goal_created_at_unix') or (w.get('end_evidence') or {}).get('goal_created_at_unix')
        if type(created) is int and w.get('session_id'):
            gid=w['session_id']+':'+str(created)
            g=goals.setdefault(gid, {'goal_id':gid,'session_id':w['session_id'],'created_at':iso_ms(created*1000),'states':[]})
            g.update(phase=w['phase'], start=w['start'], end=w.get('end'), boundary_evidence='audited_phase_window')
            g.update({k:v for k,v in (w.get('separate_goal_counter') or {}).items() if k in ('tokensUsed','timeUsedSeconds')})
    goal_rows=[]
    for g in goals.values():
        states=sorted(g.pop('states'),key=lambda e:e['timestamp'])
        complete=[e for e in states if e['status']=='complete']
        g.setdefault('start',g['created_at']);g.setdefault('end',complete[0]['timestamp'] if complete else None)
        g.setdefault('phase', phase_at(g['start'],g['session_id'],config['windows']))
        g.update(status='complete' if g['end'] else states[-1]['status'] if states else 'active',
                 elapsed_wall_seconds=elapsed(g['start'],g['end']),
                 reported_goal_tokens=g.get('tokensUsed',states[-1]['reported_goal_tokens'] if states else None),
                 reported_goal_seconds=g.get('timeUsedSeconds',states[-1]['reported_goal_seconds'] if states else None),
                 state_events=states)
        goal_rows.append(g)

    def attribute(e, start=None, end=None):
        e['phase']=phase_interval(start,end or e['timestamp'],e['session_id'],config['windows'])
        points=(start or e['timestamp'],end or e['timestamp'])
        def active_at(g, t):
            states=[s for s in g['state_events'] if s['timestamp']<=t]
            return not states or states[-1]['status']=='active'
        matches=[g for g in goal_rows if g['session_id']==e['session_id'] and all(g['start']<=t<(g['end'] or '~') and active_at(g,t) for t in points)]
        e['goal_id']=matches[0]['goal_id'] if len(matches)==1 else None
        if len(matches)>1:diag['ambiguous_goal_intervals']+=1

    compactions=[];used=set()
    intervals=[e for e in clean if e['kind']=='compaction_interval']
    for e in [e for e in clean if e['kind']=='compaction']:
        candidates=[i for i in intervals if i['thread_id']==e['thread_id'] and i['turn_id']==e['turn_id']
                    and i['start'] and i['end'] and i['start']<=e['timestamp']<=i['end']]
        if len(candidates)==1:
            i=candidates[0];used.add((i['thread_id'],i['event_id']))
            e.update(start=i['start'],end=i['end'],duration_seconds=i['duration_seconds'],measurement='unique_same_turn_containing_item_interval')
        elif len(candidates)>1:diag['ambiguous_compaction_timing']+=1
        attribute(e,e.get('start'),e.get('end'));compactions.append(e)
    for i in intervals:
        if (i['thread_id'],i['event_id']) not in used:
            # Ambiguous overlapping candidates are timing evidence, not additional
            # compactions to count beside their compacted record.
            if any(e['thread_id']==i['thread_id'] and e['turn_id']==i['turn_id'] and i['start'] and i['end'] and i['start']<=e['timestamp']<=i['end'] for e in compactions):continue
            e=i | {'kind':'compaction','context_tokens_before':None,'context_tokens_after':None,'request_input_tokens':None,'window_number':None,'measurement':'item_interval_only'}
            attribute(e,e['start'],e['end']);compactions.append(e)

    approvals=[];requests={(e['thread_id'],e['event_id']):e for e in clean if e['kind']=='approval_request'}
    resolutions={(e['thread_id'],e['event_id']):e for e in clean if e['kind']=='approval_resolution'}
    for key in sorted(requests.keys()|resolutions.keys()):
        req,res=requests.get(key),resolutions.get(key);e=dict(req or res)
        start,end=req['timestamp'] if req else None,res['timestamp'] if res else None
        wait=elapsed(start,end);actor=res['resolver'] if res else 'unknown'
        if start and end and wait is None:diag['invalid_approval_interval']+=1
        e.update(kind='approval',start=start,end=end,resolver=actor,outcome=res['outcome'] if res else 'unresolved',
                 waiting_seconds=wait,human_wait_seconds=wait if actor=='human' else None,
                 automatic_wait_seconds=wait if actor=='automatic' else None)
        attribute(e,start,end);approvals.append(e)

    executions=[e for e in clean if e['kind']=='execution']
    for e in executions:
        e['reported_compiler_wall_seconds']=e['compiler_wall_seconds']
        e['reported_test_wall_seconds']=e['test_wall_seconds']
        e['timing_tolerance_seconds']=0.5  # Different timer origins/rounded stdout; not a time estimate.
        attribute(e,e['start'],e['end'])
        parents=[p for p in executions if p is not e and p['thread_id']==e['thread_id'] and
                 e.get('parent_execution_id') and p['event_id']==e['parent_execution_id']]
        e['included_in_execution_sum']=not parents
        e['nested_in_execution_id']=parents[0]['event_id'] if parents else None
        if e['compiler_wall_seconds'] is not None and e['wall_seconds'] is not None and e['compiler_wall_seconds']>e['wall_seconds']+e['timing_tolerance_seconds']:
            diag['inconsistent_compiler_stage_duration']+=1;e['compiler_wall_seconds']=None
        if e['test_wall_seconds'] is not None and e['wall_seconds'] is not None and e['test_wall_seconds']>e['wall_seconds']+e['timing_tolerance_seconds']:
            diag['inconsistent_test_stage_duration']+=1;e['test_wall_seconds']=None
        if e['compiler_wall_seconds'] is not None and e['test_wall_seconds'] is not None and e['wall_seconds'] is not None and e['compiler_wall_seconds']+e['test_wall_seconds']>e['wall_seconds']+e['timing_tolerance_seconds']:
            diag['inconsistent_sequential_stage_sum']+=1;e['compiler_wall_seconds']=None;e['test_wall_seconds']=None
        # Explicit nested compiler records supersede their parent's stdout stage
        # annotation. Containment alone does not prove parentage/concurrency.
        e['compiler_time_included']=not any(child.get('parent_execution_id')==e['event_id'] and
                 child['thread_id']==e['thread_id'] and child['compiler_wall_seconds'] is not None for child in executions)

    if closed_only:
        def keep(e):return any(w.get('end') and w['phase']==e['phase'] and (not w.get('session_id') or w['session_id']==e['session_id']) for w in config['windows'])
        compactions=list(filter(keep,compactions));approvals=list(filter(keep,approvals));executions=list(filter(keep,executions))
        goal_rows=[g for g in goal_rows if g['end'] and any(w.get('end') and w['phase']==g['phase'] for w in config['windows'])]

    summaries=[]
    for phase in sorted({e['phase'] for e in compactions+approvals+executions}|{g['phase'] for g in goal_rows}):
        c=[e for e in compactions if e['phase']==phase];a=[e for e in approvals if e['phase']==phase];x=[e for e in executions if e['phase']==phase]
        top=[e for e in x if e['included_in_execution_sum']]
        def total(rows,key):
            values=[r[key] for r in rows if r.get(key) is not None]
            return sum(values) if values else None
        summaries.append({'phase':phase,'compactions':len(c),'compaction_seconds':total(c,'duration_seconds'),
            'compaction_duration_missing':sum(e['duration_seconds'] is None for e in c),
            'context_before_missing':sum(e['context_tokens_before'] is None for e in c),'context_after_missing':sum(e['context_tokens_after'] is None for e in c),
            'approval_requests':sum(e['start'] is not None for e in a),'approval_wait_seconds':total(a,'waiting_seconds'),
            'human_wait_seconds':total(a,'human_wait_seconds'),'automatic_wait_seconds':total(a,'automatic_wait_seconds'),
            'execution_records':len(x),'execution_seconds_sum':total(top,'wall_seconds'),'execution_interval_union_seconds':union_seconds(top) if top else None,
            'compiler_wall_seconds':total([e for e in x if e['compiler_time_included']],'compiler_wall_seconds'),'compiler_duration_missing':sum(e['compiler'] is not None and e['compiler_wall_seconds'] is None for e in x),
            'test_wall_seconds':total(x,'test_wall_seconds'),
            'forge_invocation_wall_seconds':total([e for e in top if e['category'] in ('forge_build','forge_test')],'wall_seconds'),
            'other_tool_wall_seconds':total([e for e in top if e['category']=='other'],'wall_seconds')})
    return {'schema_version':1,'sources':sources,'compactions':compactions,'approvals':approvals,'executions':executions,
            'goals':sorted(goal_rows,key=lambda g:g['start']),'phase_totals':summaries,
            'compactions_by_goal_agent':[{'goal_id':gid,'phase':phase,'agent':agent,'count':n} for (gid,phase,agent),n in sorted(collections.Counter((e['goal_id'] or 'unknown',e['phase'],e['agent']) for e in compactions).items())],
            'coverage':{'diagnostics':dict(diag),'execution_classification_counts':dict(collections.Counter(e['category'] for e in executions)),
                'approval_policy_observations':[{'policy':p,'reviewer':r,'contexts':n} for (p,r),n in sorted(policies.items())]},
            'limitations':['No raw messages, compaction summaries, objectives, commands or tool output exported.',
                'Compaction request input usage is not an exact before-context size; cumulative usage and context-window capacity are not context occupancy.',
                'Approval policy/escalation intent/tool delay does not prove a request or human wait; missing lifecycle/resolver fields stay unknown.',
                'Human-wait means a logged human-resolved approval interval; human thinking, delivery and routing cannot be isolated from those endpoints.',
                'Execution sum is not goal elapsed/CPU time. Concurrent agents overlap; interval union is wall coverage, not an additive task budget.',
                'Forge duration includes overhead/possible tests. Solc-reported stage and overall suite wall are separate annotations, never added again to execution totals.',
                'Reported stage values are preserved separately. Inconsistent stages are withheld from subtotals with a0.5s tolerance for different timers/rounded stdout; no durations are adjusted to fit.',
                'Compound commands and wrapper-hidden compiler/test subprocesses stay unclassified; redirected compiler output may be unavailable. Missing stage durations are not zero.']}
