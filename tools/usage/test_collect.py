"""Synthetic fixtures only: no private logs or transcripts are used by tests."""
import collections
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import sys
sys.path.insert(0, str(Path(__file__).parent))
import collect
import phases


def ts(n):
    return f'2026-01-01T00:00:{n:02d}.000Z'


def event(kind, payload, n=0):
    return {'timestamp': ts(n), 'type': kind, 'payload': payload}


def usage(i, o=10, cached=0, reasoning=2):
    r = {'input_tokens': i, 'output_tokens': o, 'total_tokens': i+o}
    if cached is not None:r['cached_input_tokens'] = cached
    if reasoning is not None:r['reasoning_output_tokens'] = reasoning
    return r


def context(model='model-a', turn='turn', n=1):
    return event('turn_context', {'model': model, 'turn_id': turn, 'summary': 'DO_NOT_LEAK'}, n)


def response(rid, tokens, n=2, thread='root', turn='turn', cumulative=None):
    return event('token_usage_record', {'thread_id': thread, 'session_id': 'root', 'turn_id': turn,
                'response_id': rid, 'usage': tokens, 'thread_token_usage': cumulative or tokens}, n)


def counter(tokens, last=None, n=2):
    return event('event_msg', {'type': 'token_count', 'info': {'total_token_usage': tokens, 'last_token_usage': last}}, n)


class CollectorTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.project = self.base/'project';self.project.mkdir()
        self.logs = self.base/'logs';self.logs.mkdir()
        self.config = {'version': 1, 'windows': [{'phase': 'phase0', 'start': ts(0), 'end': ts(10)},
                                              {'phase': 'phase1', 'start': ts(10), 'end': ts(40)}]}

    def tearDown(self):
        self.tmp.cleanup()

    def file(self, name, records, thread='root', parent=None, fork=None, cwd=None):
        meta = {'id': thread, 'session_id': 'root' if parent else thread,
                'cwd': str(cwd or self.project), 'agent_path': '/root/'+thread if parent else '/root',
                'parent_thread_id': parent, 'subagent_history_start_ordinal': fork}
        p=self.logs/name
        p.write_text('\n'.join(json.dumps(x) for x in [event('session_meta', meta), *records])+'\n')
        return p

    def run_collect(self):
        return collect.collect([self.logs], self.project, self.config)

    def test_response_totals_ignore_all_cumulative_levels_and_copies(self):
        rows=[context(),response('one',usage(100,10,80),cumulative=usage(1000,100,800)),
              counter(usage(1000,100,800)),counter(usage(1000,100,800),n=3)]
        self.file('a.jsonl',rows);self.file('duplicate.jsonl',rows)
        r=self.run_collect()
        self.assertEqual(r['totals']['total_tokens'],110)
        self.assertEqual(r['totals']['cached_input_tokens'],80)
        self.assertEqual(r['totals']['reasoning_tokens'],2)
        self.assertEqual(len(r['records']),1)
        self.assertEqual(r['coverage']['diagnostics']['duplicate_response_copies_excluded'],1)
        self.assertIn('response_vs_cumulative_mismatch_input_tokens',r['coverage']['diagnostics'])

    def test_child_owner_survives_inherited_metadata_and_parent_usage(self):
        self.file('root.jsonl',[context(),response('one',usage(100))])
        inherited=event('session_meta',{'id':'root','cwd':str(self.project)})
        self.file('child.jsonl',[inherited,context('wrong'),response('one',usage(100)),
                                context('child-model',n=3),response('two',usage(30),n=4,thread='child')],
                  thread='child',parent='root',fork=4,cwd=self.base/'worktree')
        r=self.run_collect();self.assertEqual(r['totals']['input_tokens'],130)
        child=next(x for x in r['records'] if x['thread_id']=='child')
        self.assertEqual(child['model'],'child-model');self.assertEqual(child['session_id'],'root')

    def test_missing_fields_remain_unknown_and_csv_blank(self):
        self.file('a.jsonl',[context(),response('one',usage(100,cached=None,reasoning=None))])
        r=self.run_collect();self.assertIsNone(r['totals']['reasoning_tokens'])
        self.assertEqual(r['totals']['reasoning_tokens_missing_records'],1)
        collect.export(r,self.base/'export')
        self.assertTrue((self.base/'export/metrics.csv').exists())

    def test_monotonic_legacy_deltas_not_sum_of_cumulative(self):
        self.file('a.jsonl',[context(),counter(usage(100),usage(40,4),n=2),
                            counter(usage(100),usage(40,4),n=3),counter(usage(140,14),usage(40,4),n=4)])
        r=self.run_collect();self.assertEqual(r['totals']['input_tokens'],140)
        self.assertEqual(r['totals']['output_tokens'],14)
        self.assertEqual(sum(x['tokens']['input_tokens'] for x in r['records'] if x['phase']=='unattributed'),60)

    def test_legacy_delta_crossing_phase_is_not_prorated(self):
        self.file('a.jsonl',[context(),counter(usage(10),n=5),counter(usage(30),n=15)])
        rows=self.run_collect()['records'];delta=next(x for x in rows if x['method']=='cumulative_delta')
        self.assertEqual(delta['phase'],'ambiguous-boundary');self.assertEqual(delta['tokens']['input_tokens'],20)

    def test_model_switches_a_b_a_are_preserved(self):
        self.file('a.jsonl',[context(),response('a',usage(10)),context('model-b','b',3),
                            response('b',usage(20),4,turn='b'),context('model-a','c',5),response('c',usage(30),6,turn='c')])
        r=self.run_collect();self.assertEqual([s['model'] for s in r['segments']],['model-a','model-b','model-a'])

    def test_legacy_switch_and_return_is_ambiguous_even_same_end_model(self):
        self.file('a.jsonl',[context(),counter(usage(10),n=2),context('model-b','b',3),
                            context('model-a','c',4),counter(usage(20),n=5)])
        delta=next(x for x in self.run_collect()['records'] if x['method']=='cumulative_delta')
        self.assertEqual(delta['model'],'unknown')

    def test_reset_or_correction_is_withheld_not_counted_as_new_tokens(self):
        self.file('a.jsonl',[context(),counter(usage(100),n=2),counter(usage(20),n=3),counter(usage(100),n=4)])
        r=self.run_collect();self.assertEqual(r['totals']['input_tokens'],100)
        self.assertEqual(r['coverage']['diagnostics']['ambiguous_counter_reset_or_correction'],1)

    def test_conflicting_response_id_is_quarantined(self):
        self.file('a.jsonl',[context(),response('same',usage(10)),response('same',usage(20),3)])
        r=self.run_collect();self.assertEqual(len(r['records']),0)
        self.assertEqual(r['coverage']['diagnostics']['conflicting_response_ids_excluded'],1)

    def test_incomplete_tail_and_transcripts_do_not_leak(self):
        p=self.file('a.jsonl',[context(),event('response_item',{'type':'message','content':'DO_NOT_LEAK'}),response('a',usage(10))])
        with p.open('a') as stream:stream.write('{"secret":"DO_NOT_LEAK')
        r=self.run_collect();self.assertNotIn('DO_NOT_LEAK',json.dumps(r))
        self.assertEqual(r['coverage']['diagnostics']['incomplete_tail_lines'],1)
        self.assertEqual(r['sources'][0]['snapshot_sha256'],collect.digest(p.read_bytes()))

    def test_unrelated_project_not_ingested(self):
        self.file('a.jsonl',[context(),response('a',usage(10))])
        self.file('other.jsonl',[context(),response('secret',usage(99999),thread='other')],thread='other',cwd=self.base/'other')
        r=self.run_collect();self.assertEqual(r['totals']['input_tokens'],10);self.assertEqual(r['coverage']['selected_rollouts'],1)

    def test_overlapping_windows_rejected_and_timezone_required(self):
        p=self.base/'phases.json';p.write_text(json.dumps({'version':1,'windows':[{'phase':'a','start':ts(1),'end':ts(20)},{'phase':'b','start':ts(10)}]}))
        with self.assertRaises(ValueError):collect.load_windows(p)
        with self.assertRaises(ValueError):collect.timestamp('2026-01-01T00:00:00')

    def test_idempotent_recollection_does_not_accumulate(self):
        self.file('a.jsonl',[context(),response('a',usage(10))])
        a=self.run_collect();b=self.run_collect();self.assertEqual(a['aggregates'],b['aggregates'])

    def test_fork_legacy_baseline_is_not_attributed_to_child(self):
        self.file('child.jsonl',[context(),counter(usage(100),usage(10),n=3),counter(usage(120,20),n=4)],thread='child',parent='root',fork=1)
        r=self.run_collect();self.assertEqual(r['totals']['input_tokens'],30)

    def test_historical_goal_recovery_exports_metadata_only(self):
        goal={'threadId':'root','objective':'Complete Phase 0. DO_NOT_LEAK','createdAt':1,'status':'active','tokensUsed':0}
        self.file('root.jsonl',[event('event_msg',{'type':'thread_goal_updated','goal':goal},1),
                  event('response_item',{'type':'custom_tool_call_output','output':json.dumps({'goal':{**goal,'status':'complete','tokensUsed':99}})},8)])
        r=phases.recover([self.logs],self.project)
        self.assertNotIn('DO_NOT_LEAK',json.dumps(r));self.assertEqual(r['windows'][0]['start'],ts(1));self.assertEqual(r['windows'][0]['end'],ts(8))
        self.assertEqual(r['windows'][0]['separate_goal_counter']['tokensUsed'],99)

    def test_response_with_unknown_turn_does_not_borrow_new_model(self):
        self.file('a.jsonl',[context('new-model','new'),response('a',usage(10),turn='missing')])
        self.assertEqual(self.run_collect()['records'][0]['model'],'unknown')

    def test_late_context_requires_matching_turn_and_one_model(self):
        self.file('a.jsonl',[response('a',usage(10),n=1),context('model-a','turn',2)])
        row=self.run_collect()['records'][0]
        self.assertEqual(row['model'],'model-a')
        self.assertEqual(row['model_evidence'],'configured_same_turn_late_context')

    def test_late_context_with_conflicting_models_remains_unknown(self):
        self.file('a.jsonl',[response('a',usage(10),n=1),context('model-a','turn',2),context('model-b','turn',3)])
        self.assertEqual(self.run_collect()['records'][0]['model'],'unknown')

    def test_explicit_zero_is_not_missing(self):
        self.file('a.jsonl',[context(),counter(usage(0,0,0,0),n=2)])
        self.assertEqual(self.run_collect()['totals']['input_tokens'],0)

    def test_closed_phase_snapshot_excludes_later_work(self):
        self.file('a.jsonl',[context(),response('a',usage(10),n=2),response('later',usage(90),n=45)])
        r=collect.collect([self.logs],self.project,self.config,closed_only=True)
        self.assertEqual(r['totals']['input_tokens'],10)
        self.assertEqual(r['coverage']['observed_records_before_phase_filter'],2)


if __name__=='__main__':unittest.main()
