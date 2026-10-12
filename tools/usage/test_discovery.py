"""Real temporary Git worktrees and synthetic rollouts; no personal telemetry."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import collect
import discovery
from test_collect import event, context, response, usage


class DiscoveryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.repo = self.base/'main'; self.repo.mkdir()
        self.logs = self.base/'sessions'; self.logs.mkdir()
        self.archive = self.base/'archived'; self.archive.mkdir()
        self.git('init', '-q')
        self.git('-c', 'user.email=test@example.invalid', '-c', 'user.name=Test',
                 'commit', '--allow-empty', '-qm', 'fixture')
        self.git('remote', 'add', 'origin', 'https://example.invalid/team/project.git')

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args):
        subprocess.run(['git', '-C', str(self.repo), *args], check=True, capture_output=True)

    def rollout(self, name, cwd, remote=None, parent=None, guardian=False, root=None):
        meta = {'id': name, 'cwd': str(cwd), 'parent_thread_id': parent,
                'git': {'repository_url': remote},
                'source': {'subagent': {'other': 'guardian'}} if guardian else 'cli'}
        path = (root or self.logs)/(name+'.jsonl')
        path.write_text('\n'.join(json.dumps(r) for r in [event('session_meta', meta),
                        context(), response(name, usage(100), thread=name)])+'\n')
        return path

    def test_independent_parallel_worktrees_and_feature_invocation(self):
        a, b = self.base/'feature-a', self.base/'feature-b'
        self.git('worktree', 'add', '-qb', 'a', str(a))
        self.git('worktree', 'add', '-qb', 'b', str(b))
        self.rollout('main', self.repo); self.rollout('a', a); self.rollout('b', b)
        selected, count = collect.inventory([self.logs], a)
        self.assertEqual(count, 3)
        self.assertEqual({m['thread_id'] for m in selected.values()}, {'main', 'a', 'b'})

    def test_deleted_or_renamed_directory_uses_recorded_identity_not_name(self):
        self.rollout('renamed', self.base/'old-name', 'git@example.invalid:team/project.git')
        self.rollout('false-friend', self.base/'main-feature', 'https://else.invalid/team/project.git')
        selected, _ = collect.inventory([self.logs], self.repo)
        self.assertEqual([m['thread_id'] for m in selected.values()], ['renamed'])

    def test_active_archive_overlap_counts_once(self):
        path = self.rollout('same', self.repo)
        (self.archive/path.name).write_bytes(path.read_bytes())
        report = collect.collect([self.logs, self.archive], self.repo, {'version': 1, 'windows': []})
        self.assertEqual(report['totals']['total_tokens'], 110)
        self.assertEqual(report['coverage']['diagnostics']['duplicate_response_copies_excluded'], 1)

    def test_explicit_guardian_parent_is_not_labeled_root(self):
        self.rollout('parent', self.repo)
        self.rollout('child', self.base/'outside', parent='parent', guardian=True)
        selected, _ = collect.inventory([self.logs], self.repo)
        child = next(m for m in selected.values() if m['thread_id'] == 'child')
        self.assertEqual(child['agent'], '/guardian')
        self.assertIn('explicit_parent_thread', child['selection_evidence'])

    def test_alternate_home_includes_active_and_archived_and_default(self):
        with patch.dict(os.environ, {'CODEX_HOME': str(self.base/'alternate')}):
            roots = discovery.default_roots()
        self.assertIn(self.base/'alternate/sessions', roots)
        self.assertIn(self.base/'alternate/archived_sessions', roots)
        self.assertIn(Path.home()/'.codex/sessions', roots)

    def test_missing_metadata_is_discovered_but_rejected(self):
        (self.logs/'partial.jsonl').write_text('{"unfinished":')
        selected, all_files, rejected, _ = discovery.discover([self.logs], self.repo)
        self.assertEqual((len(selected), len(all_files), len(rejected)), (0, 0, 1))

    def test_credentials_are_not_repository_identity(self):
        self.assertEqual(discovery.repository_key('https://private:secret@example.invalid/team/project.git'),
                         'example.invalid/team/project')


if __name__ == '__main__':
    unittest.main()
