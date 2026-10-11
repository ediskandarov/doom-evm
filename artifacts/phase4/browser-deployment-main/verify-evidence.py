#!/usr/bin/env python3
"""Verify frozen integration evidence and feature ancestry without running tests."""
import hashlib
import json
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parents[3]
folder = pathlib.Path(__file__).resolve().parent
manifest = json.loads((folder / 'integration.json').read_text())
for path, digest in manifest['fileSha256'].items():
    assert hashlib.sha256((root / path).read_bytes()).hexdigest() == digest, path
subprocess.run(['git', 'merge-base', '--is-ancestor', manifest['sourceTip'], 'HEAD'], cwd=root, check=True)
for report_name, checks, frames in [('fresh', 14, 6), ('resume', 15, 10)]:
    report = json.loads((folder / (report_name + '.json')).read_text())
    assert report['pass'] and report['stoppedOwnedRuntimes']
    assert len(report['checks']) == checks and all(row['pass'] for row in report['checks'])
    assert len(report['frames']) == frames and all(row['allCanvasPixelsExact'] for row in report['frames'])
    journal = (folder / (report_name + '.installation.json')).read_bytes()
    assert hashlib.sha256(journal).hexdigest() == report['installation']['receiptManifestSha256']
    for path, digest in report['sourceHashes'].items():
        actual = folder / 'resume-check.mjs' if path.endswith('/resume-check.mjs') else root / path
        assert hashlib.sha256(actual.read_bytes()).hexdigest() == digest, path
baseline = manifest['baseline']
for path in subprocess.check_output(['git', 'diff', '--name-only', baseline, manifest['sourceTip']], cwd=root).decode().splitlines():
    assert (root / path).read_bytes() == subprocess.check_output(['git', 'show', f"{manifest['sourceTip']}:{path}"], cwd=root), path
assert not subprocess.check_output(['git', 'diff', baseline, 'HEAD', '--', 'src', 'test', 'original', 'foundry.toml', 'AGENTS.md'], cwd=root)
old_ledger = subprocess.check_output(['git', 'show', f'{baseline}:docs/PHASE4-PLAN.md'], cwd=root)
heading, separator, historical_body = old_ledger.partition(b'\n\n')
new_ledger = (root / 'docs/PHASE4-PLAN.md').read_bytes()
# A new top checkpoint is inserted after the original heading. Preserve both
# the exact heading and the entire contiguous historical body below that insert.
assert new_ledger.startswith(heading + separator)
assert historical_body in new_ledger
print('PASS: frozen evidence, 51 delivered feature files, ancestry, protected engine/tests and historical ledger.')
