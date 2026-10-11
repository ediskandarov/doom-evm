#!/usr/bin/env python3
"""Read-only frozen integration integrity; never rewrite source certificates."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
BASE = '3cc536dff6c84194bf3784d9183e0d082a2bcf0e'
MERGED = 'b4c812ff8cb06ac1a3bb57cb179bdfa59c6ace8d'
sha = lambda b: hashlib.sha256(b).hexdigest()
def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)
def read(path):
    return (ROOT / path).read_bytes()

manifest = json.loads((HERE / 'integration.json').read_text())
for path, digest in manifest['evidenceSHA256'].items():
    assert sha(read(path)) == digest, path
for tip in manifest['sourceTips'].values():
    git('merge-base', '--is-ancestor', tip, 'HEAD')
preserved = json.loads((HERE / 'preservation.json').read_text())
for feature in ('ultimate', 'doom2'):
    item = preserved[feature]
    for path in item['unchangedFeatureFiles']:
        assert read(path) == git('show', item['tip'] + ':' + path), path
# Integration-specific work is browser wiring, packaging, tests and documentation.
assert not git('diff', MERGED, '--', 'src', 'test', 'original', 'foundry.toml', 'AGENTS.md')
for module in ('install-pins.mjs', 'doom2-pins.mjs'):
    pins = json.loads(read('web/' + module).decode().split('export default ', 1)[1].rstrip(';\n'))
    for path, digest in pins['sources'].items():
        assert sha(read(path)) == digest, path
    for pin in pins['artifacts'].values():
        assert sha(read('web' + pin['url'])) == pin['sha256']
for tip, certificate, group in (
    ('f0a36ba765fa806e837b1f783e1827ad6bca65e2', 'artifacts/ultimate-browser/verification.json', 'evidenceHashes'),
    ('cfccc1044d5037a779d7dbe9d42e6f0f94863819', 'artifacts/doom2/certificate.json', 'evidenceSHA256'),
):
    assert read(certificate) == git('show', tip + ':' + certificate)
    for path, digest in json.loads(read(certificate))[group].items():
        assert sha(git('show', tip + ':' + path)) == digest, path
acceptance = json.loads((HERE / 'chrome.json').read_text())
assert acceptance['pass'] and acceptance['stoppedOwnedRuntimes']
assert len(acceptance['frames']) == manifest['freshCanvasFrames']
assert len(acceptance['checks']) == manifest['freshChromeChecks']
for path, digest in acceptance['sourceHashes'].items():
    assert sha(read(path)) == digest, path
assert set(acceptance['installations']) == {'freedoom', 'ultimate', 'doom2'}
assert all(f['allCanvasPixelsExact'] for f in acceptance['frames'])
for game, item in acceptance['installations'].items():
    assert item['defaultPolicy'] == 2 and item['config']['memoryPolicy'] == 3
    assert item['journalKey'].endswith('|' + game + '|memory=3')
old_ledger = git('show', BASE + ':docs/PHASE4-PLAN.md')
assert old_ledger.split(b'\n', 1)[1] in read('docs/PHASE4-PLAN.md')
assert b'Final presentation recording pipeline pending: EVM status bar, original intermission, and EVM melt transitions.' in read('docs/PHASE4-PLAN.md')
changed = git('diff', '--name-only', BASE).decode().splitlines()
assert not any(p.lower().endswith(('.wad', '.mp4')) or p.startswith('artifacts/local/') for p in changed)
print(json.dumps({'pass': True, 'sourceAncestry': True, 'sourceEvidenceUnmodified': True,
                  'productionEngineExactMergedFeatures': True, 'currentReleaseBindings': True,
                  'freshCanvasFrames': len(acceptance['frames']), 'historicalLedgerPreserved': True,
                  'commercialPayloadsInDiff': False}))
