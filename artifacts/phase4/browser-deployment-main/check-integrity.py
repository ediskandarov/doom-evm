#!/usr/bin/env python3
"""Read-only browser release/source integrity check; no certificate rewriting."""
import hashlib
import json
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[3]
BASE = '59522a545d1311924a28875a098892c5e27c113b'
TIP = 'a19716983df0ef1504010957a474a93f30e5bb6c'
sha = lambda data: hashlib.sha256(data).hexdigest()
def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

git('merge-base', '--is-ancestor', TIP, 'HEAD')
delivered = git('diff', '--name-only', BASE, TIP).decode().splitlines()
for path in delivered:
    assert (ROOT / path).read_bytes() == git('show', f'{TIP}:{path}'), path
assert not git('diff', BASE, 'HEAD', '--', 'src', 'test', 'original', 'foundry.toml', 'AGENTS.md')
manifest = json.loads((ROOT / 'artifacts/browser-deployment/verification.json').read_text())
for group in ('sourceHashes', 'evidenceHashes'):
    for path, digest in manifest[group].items():
        assert sha((ROOT / path).read_bytes()) == digest, path
pins = json.loads((ROOT / 'web/install-pins.mjs').read_text().split('export default ', 1)[1].rstrip(';\n'))
for path, digest in pins['sources'].items():
    assert sha((ROOT / path).read_bytes()) == digest, path
artifacts = {}
for name, pin in pins['artifacts'].items():
    raw = (ROOT / 'web' / pin['url'].lstrip('/')).read_bytes()
    assert sha(raw) == pin['sha256'], name
    release = json.loads(raw)
    compiled = json.loads((ROOT / f'out/{name}.sol/{name}.json').read_text())
    metadata = compiled['metadata']
    if isinstance(metadata, str):
        metadata = json.loads(metadata)
    settings = metadata['settings']
    assert metadata['compiler']['version'].startswith('0.8.37')
    assert settings['viaIR'] and settings['evmVersion'] == 'cancun'
    assert settings['optimizer']['enabled'] and settings['optimizer']['runs'] == 200
    assert release['bytecode'] == compiled['bytecode']['object']
    assert release['runtime'] == compiled['deployedBytecode']['object']
    assert release['methods'] == compiled['methodIdentifiers']
    assert release.get('immutableReferences', {}) == compiled['deployedBytecode'].get('immutableReferences', {})
    for path, identity in metadata['sources'].items():
        digest = subprocess.check_output([str(ROOT / '.toolchain/bin/cast'), 'keccak'],
            input=b'0x' + (ROOT / path).read_bytes().hex().encode()).decode().strip()
        assert digest == identity['keccak256'], path
    artifacts[name] = {'sha256': pin['sha256'], 'runtimeBytes': len(release['runtime'][2:]) // 2,
                       'compilerSources': len(metadata['sources']), 'matchesCurrentCompiledArtifact': True}
result = {'pass': True, 'baseline': BASE, 'sourceTip': TIP,
          'verifiedMain': git('rev-parse', 'HEAD').decode().strip(),
          'deliveredFilesExact': len(delivered), 'pinnedProductionSourcesExact': len(pins['sources']),
          'sourceAndHistoricalEvidenceHashesExact': True,
          'engineTestsOriginalCSettingsAndInstructionsUnchanged': True, 'artifacts': artifacts}
print(json.dumps(result, indent=2))
