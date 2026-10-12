"""Regression coverage for bounded, sanitized final-audit exports."""
import collections
import csv
import json
from pathlib import Path
import tempfile
import unittest

import audit
import collect
from test_collect import event, context, response, usage, ts


class AuditTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.root = Path(self.tmp.name)
        self.logs = self.root/'logs'; self.logs.mkdir()
        self.project = self.root/'project'; self.project.mkdir()
        self.policy = {'cutoff': ts(20), 'goal_labels': {}, 'sessions': {'root': {'workstream': 'Example'}},
                       'task_boundaries': [], 'worktree_ownership': []}
        self.config = {'version': 1, 'windows': []}

    def tearDown(self): self.tmp.cleanup()

    def file(self, records):
        p = self.logs/'a.jsonl'
        p.write_text('\n'.join(json.dumps(x) for x in [event('session_meta',
                     {'id': 'root', 'cwd': str(self.project), 'timestamp': ts(0)}), *records])+'\n')
        return p

    def run_audit(self, snapshot=None):
        return audit.scan([self.logs], self.project, self.policy, self.config, snapshot)

    def test_cutoff_model_switch_and_task_split(self):
        self.policy['task_boundaries'] = [{'session_id': 'root', 'start': ts(10), 'workstream': 'Research'}]
        self.file([context('a'), response('a', usage(100, 10, 80), n=2), context('b', 'b', 11),
                   response('b', usage(200, 20, 150), n=12, turn='b', cumulative=usage(300, 30, 230)),
                   response('later', usage(999), n=20)])
        report, rows = self.run_audit()
        self.assertEqual(report['totals']['total_tokens'], 330)
        self.assertEqual(report['totals']['non_cached_input_tokens'], 70)
        self.assertEqual([(r['model'], r['workstream']) for r in rows], [('a', 'Example'), ('b', 'Research')])

    def test_frozen_prefix_reproduction_and_tamper_rejection(self):
        p = self.file([context(), response('a', usage(100))])
        first, rows = self.run_audit()
        with p.open('a') as stream: stream.write(json.dumps(response('b', usage(200), n=3))+'\n')
        second, repeated = self.run_audit(first)
        self.assertEqual(rows, repeated)
        self.assertEqual(first['sources'], second['sources'])
        p.write_bytes(p.read_bytes().replace(b'100', b'101', 1))
        with self.assertRaisesRegex(ValueError, 'prefix changed'): self.run_audit(first)

    def test_partial_tail_and_missing_fields_remain_explicit(self):
        p = self.file([context(), response('a', usage(100, cached=None, reasoning=None))])
        with p.open('a') as stream: stream.write('{"secret":"DO_NOT_EXPORT')
        report, rows = self.run_audit()
        self.assertIsNone(report['totals']['non_cached_input_tokens'])
        self.assertEqual(report['source_coverage']['parse_diagnostics']['incomplete_tail_lines'], 1)
        audit.export(report, rows, self.root/'out')
        self.assertNotIn('DO_NOT_EXPORT', ''.join(p.read_text() for p in (self.root/'out').iterdir()))

    def test_compaction_usage_is_subset_and_duplicate_backup_not_added(self):
        compaction = event('compacted', {'window_id': 'window', 'compaction_response_id': 'r',
                           'message': 'DO_NOT_EXPORT', 'replacement_history': ['DO_NOT_EXPORT'],
                           'latest_token_usage_record': response('r', usage(100))['payload']}, 3)
        self.file([context(), response('r', usage(100)), compaction, compaction])
        report, rows = self.run_audit()
        self.assertEqual(len(report['compactions']), 1)
        self.assertEqual(report['compaction_usage_already_in_total']['total_tokens'], 110)
        self.assertEqual(report['totals']['total_tokens'], 110)
        self.assertNotIn('DO_NOT_EXPORT', json.dumps(report))

    def test_goal_counters_never_become_tokens_and_objective_never_leaks(self):
        g = {'threadId': 'root', 'createdAt': 1767225601, 'updatedAt': 1767225603,
             'status': 'complete', 'objective': 'DO_NOT_EXPORT password', 'tokensUsed': 9999999, 'timeUsedSeconds': 2}
        self.file([context(), response('r', usage(100)),
                   event('response_item', {'type': 'custom_tool_call_output', 'output': json.dumps({'goal': g})}, 3)])
        report, rows = self.run_audit()
        self.assertEqual(report['totals']['total_tokens'], 110)
        self.assertEqual(report['goals'][0]['separate_goal_counter']['tokensUsed'], 9999999)
        self.assertNotIn('DO_NOT_EXPORT', json.dumps(report))

    def test_invalid_subset_and_total_are_not_counted(self):
        bad = usage(100); bad['total_tokens'] = 999
        self.file([context(), response('bad-total', bad), response('bad-cache', usage(10, cached=20), n=3)])
        report, rows = self.run_audit()
        self.assertEqual(report['totals']['total_tokens'], 0)
        self.assertEqual(report['source_coverage']['accounting_diagnostics']['invalid_token_relationship_records_excluded'], 2)

    def test_turn_seconds_and_overlapping_wall_intervals_are_not_compute(self):
        self.assertEqual(audit.turn_time(1767225601), ts(1))
        self.assertEqual(audit.union_seconds([(ts(0), ts(10)), (ts(5), ts(15))]), 15)

    def test_parallelism_counts_distinct_threads_with_half_open_intervals(self):
        intervals = [{'thread_id': thread, 'started_at': ts(start), 'completed_at': ts(end)}
                     for thread, start, end in [('a', 0, 10), ('a', 2, 8), ('b', 5, 10), ('c', 10, 15)]]
        result = audit.concurrency(intervals)
        self.assertEqual(result['max_observed_concurrent_threads'], 2)
        self.assertEqual(result['wall_seconds_with_two_or_more_observed_threads'], 5)

    def test_ambiguous_reset_preserves_lower_bound(self):
        from test_collect import counter
        self.file([context(), counter(usage(100), n=2), counter(usage(5), n=3), counter(usage(50), n=4)])
        report, rows = self.run_audit()
        self.assertEqual(report['totals']['input_tokens'], 100)
        self.assertEqual(report['source_coverage']['accounting_diagnostics']['ambiguous_counter_reset_or_correction'], 1)


if __name__ == '__main__': unittest.main()
