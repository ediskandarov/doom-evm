"""Synthetic telemetry only; no actual transcripts or engine fixtures."""
import json
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import activity
import collect
import test_collect as fixtures
context,response,usage,event,ts = fixtures.context,fixtures.response,fixtures.usage,fixtures.event,fixtures.ts


def item(kind,identity,start,end,**fields):
    return event('event_msg',{'type':'item_completed','thread_id':'root','turn_id':'turn',
        'started_at_ms':1767225600000+start*1000,'completed_at_ms':1767225600000+end*1000,
        'item':{'type':kind,'id':identity,**fields}},end)


def execution(identity,start,end,argv=None,output='',parent=None):
    return item('CommandExecution',identity,start,end,command=argv or ['.toolchain/bin/forge','build'],
        duration={'secs':end-start,'nanos':0},exit_code=0,aggregated_output=output,parent_execution_id=parent)


class ActivityTests(unittest.TestCase):
    setUp = fixtures.CollectorTests.setUp
    tearDown = fixtures.CollectorTests.tearDown
    file = fixtures.CollectorTests.file
    run_collect = fixtures.CollectorTests.run_collect
    def activity(self,records):
        self.file('a.jsonl',records)
        return self.run_collect()['activity']

    def test_compaction_join_and_usage_are_separate(self):
        c=event('compacted',{'compaction_response_id':'one','window_number':1,
            'latest_token_usage_record':{'response_id':'one','usage':usage(100)},
            'resume_metadata':{'last_started_turn_id':'turn'},'replacement_history':'DO_NOT_LEAK','message':'DO_NOT_LEAK'},5)
        a=self.activity([context(),response('one',usage(100),n=4),c,item('ContextCompaction','timing',2,6)])
        row=a['compactions'][0];self.assertEqual(row['duration_seconds'],4)
        self.assertEqual(row['request_input_tokens'],100);self.assertIsNone(row['context_tokens_before']);self.assertIsNone(row['context_tokens_after'])
        self.assertNotIn('DO_NOT_LEAK',json.dumps(a));self.assertEqual(self.run_collect()['totals']['input_tokens'],100)

    def test_compaction_missing_and_explicit_zero_and_reset_window(self):
        a=self.activity([context(),event('compacted',{'compaction_response_id':'a','window_number':1,'context_tokens_before':20,'context_tokens_after':0},2),
            event('compacted',{'compaction_response_id':'b','window_number':1,'context_tokens_before':-1,'context_tokens_after':None,'latest_token_usage_record':None},3)])
        self.assertEqual(len(a['compactions']),2);self.assertEqual(a['compactions'][0]['context_tokens_after'],0)
        self.assertIsNone(a['compactions'][1]['context_tokens_before']);self.assertIsNone(a['compactions'][1]['duration_seconds'])

    def test_duplicate_and_conflicting_activity(self):
        c=event('compacted',{'compaction_response_id':'a','context_tokens_before':10},2)
        self.file('a.jsonl',[context(),c]);self.file('copy.jsonl',[context(),c])
        self.assertEqual(len(self.run_collect()['activity']['compactions']),1)
        self.file('conflict.jsonl',[context(),event('compacted',{'compaction_response_id':'a','context_tokens_before':11},2)])
        a=self.run_collect()['activity'];self.assertEqual(a['compactions'],[]);self.assertEqual(a['coverage']['diagnostics']['conflicting_activity_identities_excluded'],1)

    def test_compaction_boundary_not_prorated(self):
        a=self.activity([context(),event('compacted',{'compaction_response_id':'a'},11),item('ContextCompaction','time',8,12)])
        self.assertEqual(a['compactions'][0]['phase'],'ambiguous-boundary');self.assertEqual(a['compactions'][0]['duration_seconds'],4)

    def test_compaction_overlapping_intervals_not_nearest_match(self):
        a=self.activity([context(),event('compacted',{'compaction_response_id':'a'},5),item('ContextCompaction','x',2,6),item('ContextCompaction','y',3,7)])
        self.assertEqual(len(a['compactions']),1);self.assertIsNone(a['compactions'][0]['duration_seconds'])
        self.assertEqual(a['coverage']['diagnostics']['ambiguous_compaction_timing'],1)

    def test_item_only_compaction(self):
        a=self.activity([context(),item('ContextCompaction','x',2,6)])
        self.assertEqual(a['compactions'][0]['duration_seconds'],4);self.assertEqual(a['compactions'][0]['measurement'],'item_interval_only')

    def test_human_automatic_unknown_approval_provenance(self):
        records=[context()]
        for i,resolver in enumerate(['human','auto_review',None]):
            records += [event('event_msg',{'type':'approval_request','approval_id':str(i)},2),event('event_msg',{'type':'approval_resolved','approval_id':str(i),'decision_source':resolver,'decision':'approved'},5)]
        a=self.activity(records);by={r['resolver']:r for r in a['approvals']}
        self.assertEqual(by['human']['human_wait_seconds'],3);self.assertIsNone(by['automatic']['human_wait_seconds'])
        self.assertEqual(by['automatic']['automatic_wait_seconds'],3);self.assertIsNone(by['unknown']['human_wait_seconds'])

    def test_policy_and_escalation_are_not_human_wait(self):
        a=self.activity([event('turn_context',{'model':'m','turn_id':'turn','approval_policy':'on-request','approvals_reviewer':'user'},1),
            event('response_item',{'type':'custom_tool_call','input':'sandbox_permissions="require_escalated" DO_NOT_LEAK'},2),execution('x',2,6)])
        self.assertEqual(a['approvals'],[]);self.assertIsNone(a['phase_totals'][0]['human_wait_seconds'])

    def test_unresolved_or_missing_request_approval(self):
        a=self.activity([context(),event('event_msg',{'type':'approval_request','request_id':'a'},2),event('event_msg',{'type':'approval_resolved','request_id':'b','reviewer':'human'},3)])
        self.assertTrue(all(r['waiting_seconds'] is None for r in a['approvals']))

    def test_approval_cross_goal_and_rejection(self):
        self.config['windows'][0]['goal_created_at_unix']=1767225600
        self.config['windows'][1]['goal_created_at_unix']=1767225610
        a=self.activity([context(),event('event_msg',{'type':'approval_request','request_id':'a'},8),event('event_msg',{'type':'approval_resolved','request_id':'a','reviewer':'human','decision':'rejected'},12)])
        r=a['approvals'][0];self.assertEqual(r['phase'],'ambiguous-boundary');self.assertIsNone(r['goal_id']);self.assertEqual(r['human_wait_seconds'],4)

    def test_compile_test_and_cpu_not_double_counted(self):
        out='Solc 0.8.37 finished in 2.50s\nSuite result: ok; 9s CPU time\nRan 2 test suites in 500ms (99s CPU time): 4 tests passed\n'
        a=self.activity([context(),execution('x',2,7,['forge','test'],out)])
        r=a['executions'][0];self.assertEqual(r['wall_seconds'],5);self.assertEqual(r['compiler_wall_seconds'],2.5);self.assertEqual(r['test_wall_seconds'],0.5)
        self.assertEqual(a['phase_totals'][0]['execution_seconds_sum'],5)

    def test_explicit_nested_solc_not_double_counted(self):
        a=self.activity([context(),execution('forge',2,8,['forge','build'],'Solc 0.8.37 finished in 3.0s\n'),execution('solc',3,6,['solc','--standard-json'],parent='forge')])
        r=a['phase_totals'][0];self.assertEqual(r['execution_seconds_sum'],6);self.assertEqual(r['compiler_wall_seconds'],3)
        child=next(r for r in a['executions'] if r['event_id']=='solc');self.assertFalse(child['included_in_execution_sum'])

    def test_concurrent_containment_not_inferred_parentage(self):
        a=self.activity([context(),execution('a',2,8,['node','task']),execution('b',3,6,['node','other'])])
        s=a['phase_totals'][0];self.assertEqual(s['execution_seconds_sum'],9);self.assertEqual(s['execution_interval_union_seconds'],6)

    def test_logged_summary_read_or_quoted_script_not_compiler(self):
        out='Solc 0.8.37 finished in 2.0s\n'
        a=self.activity([context(),execution('a',2,6,['cat','build.log'],out),execution('b',2,5,['zsh','-lc',"python3 -c 'print(\"forge build\")'"],out)])
        self.assertTrue(all(r['compiler_wall_seconds'] is None for r in a['executions']))

    def test_mixed_shell_stage_and_direct_forge_scope(self):
        a=self.activity([context(),execution('x',2,6,['zsh','-lc','cd project && forge build > out.log'],'Solc 0.8.37 finished in 800ms\n')])
        r=a['executions'][0];self.assertEqual(r['category'],'shell_with_forge_build');self.assertEqual(r['compiler_wall_seconds'],0.8)
        self.assertIsNone(a['phase_totals'][0]['forge_invocation_wall_seconds'])

    def test_compilation_skipped_is_known_zero(self):
        a=self.activity([context(),execution('a',2,4,output='No files changed, compilation skipped\n')])
        r=a['executions'][0];self.assertEqual(r['compiler_wall_seconds'],0);self.assertEqual(r['compiler_measurement'],'explicit_compilation_skipped')

    def test_missing_or_inconsistent_stages(self):
        a=self.activity([context(),execution('a',2,4,output='Solc 0.8.37 finished in 99s\n'),execution('b',4,5,output='')])
        self.assertTrue(all(r['compiler_wall_seconds'] is None for r in a['executions']))
        self.assertEqual(a['coverage']['diagnostics']['inconsistent_compiler_stage_duration'],1)

    def test_background_completion_uses_matching_turn_model(self):
        e=execution('x',2,6);e['payload']['turn_id']='old'
        a=self.activity([context('old-model','old'),context('new-model','new',3),e])
        self.assertEqual(a['executions'][0]['model'],'old-model')

    def test_goal_metadata_and_article_privacy(self):
        g={'threadId':'root','objective':'Phase0 DO_NOT_LEAK','createdAt':1767225600,'status':'complete','tokensUsed':99,'timeUsedSeconds':7}
        r=event('response_item',{'type':'custom_tool_call_output','output':json.dumps({'goal':g})},8)
        a=self.activity([context(),r]);self.assertNotIn('DO_NOT_LEAK',json.dumps(a));self.assertEqual(a['goals'][0]['elapsed_wall_seconds'],8)
        collect.export(self.run_collect(),self.base/'export');self.assertNotIn('DO_NOT_LEAK',(self.base/'export/telemetry-report.md').read_text())

    def test_compaction_inherited_thread_excluded(self):
        self.file('child.jsonl',[context(),event('compacted',{'compaction_response_id':'a','latest_token_usage_record':{'thread_id':'root'}},2)],thread='child',parent='root',fork=1)
        self.assertEqual(self.run_collect()['activity']['compactions'],[])

    def test_export_retains_legacy_csv_columns_and_null_blanks(self):
        self.activity([context(),response('a',usage(100)),event('compacted',{'compaction_response_id':'c'},3)])
        r=self.run_collect();collect.export(r,self.base/'export')
        self.assertEqual(r['version'],2)
        self.assertIn('cached_input_tokens_missing_records',(self.base/'export/metrics.csv').read_text().splitlines()[0])
        self.assertTrue((self.base/'export/approvals.csv').is_file());self.assertIn('unavailable',(self.base/'export/telemetry-report.md').read_text())

    def test_new_activity_recollection_is_idempotent(self):
        self.activity([context(),execution('a',2,4)])
        self.assertEqual(self.run_collect()['activity'],self.run_collect()['activity'])

    def test_pipeline_compiler_ms_not_wrapper_wall(self):
        out=json.dumps({'results':[{'compile_wall_ms':200},{'compile_wall_ms':300}]})
        a=self.activity([context(),execution('x',2,5,['python3','scripts/stack-pressure.py'],out)])
        self.assertEqual(a['executions'][0]['compiler_wall_seconds'],0.5);self.assertEqual(a['phase_totals'][0]['execution_seconds_sum'],3)

    def test_invalid_nonfinite_numbers_and_context_capacity(self):
        self.assertIsNone(activity.number(float('nan')));self.assertIsNone(activity.number(True))
        a=self.activity([context(),event('compacted',{'compaction_response_id':'a','model_context_window':200000,'total_token_usage':usage(1000000)},2)])
        self.assertIsNone(a['compactions'][0]['context_tokens_before'])

    def test_duplicate_approval_and_conflicting_resolution_withheld(self):
        req=event('event_msg',{'type':'approval_request','approval_id':'a'},2)
        yes=event('event_msg',{'type':'approval_resolved','approval_id':'a','reviewer':'human','decision':'approved'},5)
        self.file('a.jsonl',[context(),req,yes]);self.file('copy.jsonl',[context(),req,yes])
        self.assertEqual(len(self.run_collect()['activity']['approvals']),1)
        no=event('event_msg',{'type':'approval_resolved','approval_id':'a','reviewer':'human','decision':'denied'},5)
        self.file('conflict.jsonl',[context(),no]);a=self.run_collect()['activity']
        self.assertEqual(a['approvals'][0]['outcome'],'unresolved');self.assertIsNone(a['approvals'][0]['human_wait_seconds'])

    def test_reversed_approval_duration_not_negative_measurement(self):
        a=self.activity([context(),event('event_msg',{'type':'approval_request','approval_id':'a'},5),
            event('event_msg',{'type':'approval_resolved','approval_id':'a','reviewer':'human'},2)])
        self.assertIsNone(a['approvals'][0]['waiting_seconds']);self.assertEqual(a['coverage']['diagnostics']['invalid_approval_interval'],1)

    def test_closed_only_activity_filter(self):
        self.file('a.jsonl',[context(),execution('a',2,5),execution('later',41,45)])
        r=collect.collect([self.logs],self.project,self.config,closed_only=True)
        self.assertEqual(len(r['activity']['executions']),1)
