#!/usr/bin/env python3
"""Publish compact measured evidence, without commercial WADs or image payloads."""
import datetime, hashlib, json, subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
base = ROOT/'artifacts/local/death-respawn'
sha = lambda b: hashlib.sha256(b).hexdigest()
read = lambda name: json.loads((base/name).read_text())
browser, native, compared = read('browser.json'), read('native-verification.json'), read('browser-native.json')
focused, inherited = read('focused.json'), read('inherited.json')
assert all(r['pass'] for r in [browser, native, compared])
assert focused['pass_'] and inherited['pass_']
assert focused['counts'] == [4, 0, 0, 4] and inherited['counts'] == [85, 0, 0, 85]
for path, identity in browser['sourceHashes'].items():
    assert sha((ROOT/path).read_bytes()) == identity, ('browser acceptance source changed', path)
artifacts = {}
for name in ['Doom', 'Doom2']:
    p = base/f'production/out/{name}.sol/{name}.json'
    a = json.loads(p.read_text())
    metadata = a['metadata'] if isinstance(a['metadata'], dict) else json.loads(a['metadata'])
    assert metadata['compiler']['version'].startswith('0.8.37')
    assert metadata['settings']['viaIR'] and metadata['settings']['optimizer']['runs'] == 200
    assert metadata['settings']['evmVersion'] == 'cancun'
    artifacts[name] = {'artifactSha256': sha(p.read_bytes()), 'runtimeBytes': (len(a['deployedBytecode']['object'])-2)//2,
                       'playerLifecycleSelector': a['methodIdentifiers']['playerLifecycle()'], 'compiler': metadata['compiler'],
                       'settings': {k: metadata['settings'][k] for k in ['viaIR', 'optimizer', 'evmVersion']}}
paths = ['src/evm/Doom.sol', 'src/evm/Doom2.sol', 'src/evm/EpisodeRuntime.sol', 'src/support/DeathRespawnProbe.sol',
         'test/death_respawn/DeathRespawn.t.sol', 'web/install-pins.mjs', 'web/doom2-pins.mjs']
paths += [str(p.relative_to(ROOT)) for folder in ['tools/reference/death_respawn', 'test/fixtures/death_respawn']
          for p in (ROOT/folder).iterdir() if p.is_file()]
cases = [p for game in compared['cases'].values() for p in game.values()]
report = {'schemaVersion': 1, 'pass': True, 'generatedUtc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'baseline': 'ff826659ceff0b3a5637e70109b62eb75a83d611', 'upstream': 'a77dfb96cb91780ca334d0d4cfd86957558007e0',
          'sourceHashes': {p: sha((ROOT/p).read_bytes()) for p in sorted(paths)}, 'productionArtifacts': artifacts,
          'forge': {'new': focused, 'inheritedWarm': inherited}, 'node': {'tests': 44, 'passed': 44, 'logSha256': sha((base/'node.log').read_bytes())},
          'native': native, 'browserNative': compared,
          'browser': {k: browser[k] for k in ['startedUtc', 'endedUtc', 'port', 'httpPort', 'browser', 'runtime', 'sourceHashes', 'deaths', 'rollbacks', 'checks', 'frames', 'stoppedOwnedRuntimes']},
          'browserCounts': {'actualDeathsAndRebirths': len(browser['deaths']), 'fullCanvasChecks': len(browser['frames']),
                            'uniqueComparedGameplayTics': sum(g['O2']['gameplayTics'] for g in compared['cases'].values()),
                            'nativeProfileTics': sum(p['gameplayTics'] for p in cases), 'fieldComparisons': sum(p['fieldComparisons'] for p in cases),
                            'uniqueNativeFramesAndPalettes': sum(g['O2']['completeFramesAndPalettes'] for g in compared['cases'].values()),
                            'nativeProfileFramesAndPalettes': sum(p['completeFramesAndPalettes'] for p in cases)},
          'evidenceHashes': {p: sha((base/p).read_bytes()) for p in ['browser.json', 'browser-native.json', 'native-verification.json', 'focused.log', 'inherited.log', 'production-build.log', 'production-warm.log', 'environment-diagnostic.log']},
          'limits': 'Focused acceptance only. E1 profiles and commercial MAP07 UV shown in Chrome; support domain remains E1M1-M9 and DOOM2 MAP01-MAP32. No melt orchestration, sound/music, multiplayer, save slots, unknown-byte compatibility changes or universal physical-pointer equivalence. Menu-owned ordinary packets follow inherited frozen-world adaptation and are excluded from native gameplay tape. Native floor/monster initial conditions controlled; browser deaths use actual rocket/geometry/monster gameplay with original IDFA inventory.'}
dest = ROOT/'artifacts/death-respawn'; dest.mkdir(exist_ok=True)
(dest/'acceptance.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps({'pass': True, 'certificate': str(dest/'acceptance.json'), 'sha256': sha((dest/'acceptance.json').read_bytes()), **report['browserCounts']}))
