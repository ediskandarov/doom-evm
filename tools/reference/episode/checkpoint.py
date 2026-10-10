#!/usr/bin/env python3
"""Goal 4.7a evidence/source ownership check; does not run inherited regressions."""
import argparse, hashlib, json, pathlib, re, subprocess

ROOT = pathlib.Path(__file__).resolve().parents[3]
BASELINE = '9f98ed1d38e6de3f2577f5d76b07ec136fc70d52'
TARGET = ROOT/'artifacts/phase4/episode-verification.json'
MAPS = [f'E1M{i}' for i in range(1, 10)]

def sha(b): return hashlib.sha256(b).hexdigest()
def read(name): return json.loads((ROOT/name).read_text())
def git(*args): return subprocess.check_output(['git', '-C', str(ROOT), *args])

def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--check', action='store_true'); args = ap.parse_args()
    assert git('branch', '--show-current').decode().strip() == 'feat/phase4-multimap', 'Wrong feature branch'
    assert subprocess.run(['git', '-C', str(ROOT), 'merge-base', '--is-ancestor', BASELINE, 'HEAD']).returncode == 0
    protected = {}
    allowed_edits = {'docs/PHASE4-PLAN.md', 'tools/wad/README.md'}
    for row in git('ls-tree', '-r', BASELINE).decode().splitlines():
        prefix, name = row.split('\t', 1); mode, kind, digest = prefix.split()
        if name in allowed_edits or kind != 'blob': continue
        content = (ROOT/name).read_bytes()
        original = git('cat-file', 'blob', digest)
        assert content == original, 'Protected baseline changed: '+name
        protected[name] = sha(content)
    catalog = read('test/fixtures/phase4_episode/catalog.json')
    native = read('test/fixtures/phase4_episode/native.json')
    comparison = read('artifacts/phase4/episode-native-comparison.json')
    evm = read('artifacts/phase4/episode-evm.json')
    packaging = read('artifacts/phase4/episode-packaging.json')
    for report in [comparison, evm, packaging]:
        assert report['catalogSha256'] == catalog['catalogSha256']
        assert report['resourceIdentity'] == catalog['resourceIdentity']
    assert comparison['pass'] and comparison['sharedResourcesMatchAcceptedNative'] and evm['pass']
    assert [m['map'] for m in catalog['maps']] == [m['map'] for m in comparison['results']] == [m['map'] for m in evm['results']] == MAPS
    assert native['maps'] == MAPS and len(native['profiles']) == 3
    canonical = lambda x: json.dumps(x, sort_keys=True, separators=(',', ':')).encode()
    assert comparison['nativeManifestSha256'] == sha(canonical(native))
    for report in [evm, packaging]:
        for name, digest in report['sourceSha256'].items(): assert sha((ROOT/name).read_bytes()) == digest, 'Evidence source drift: '+name
    for name, digest in native['harness'].items(): assert sha((ROOT/name).read_bytes()) == digest, 'Native harness drift: '+name
    for name, digest in native['sources'].items(): assert sha((ROOT/'original/DOOM/linuxdoom-1.10'/name).read_bytes()) == digest
    for i, pkg in enumerate(catalog['maps']):
        c, e = comparison['results'][i], evm['results'][i]
        assert c['tenRawLumpsExact'] and c['packageSha256'] == pkg['packageSha256'] == e['packageSha256']
        for key in ['geometrySha256', 'thingsSha256', 'blockmapSha256', 'rejectSha256']: assert c[key] == e[key]
        for key, suffix in [('geometrySha256', 'map.bin'), ('thingsSha256', 'things.bin'), ('blockmapSha256', 'blockmap.bin')]: assert c[key] == native['outputs'][pkg['map']+'.'+suffix]['sha256']
        assert c['rejectSha256'] == pkg['lumps']['REJECT']['sha256']
        assert e['transactionGas'] <= evm['gasLimit']
    assert evm['deployment']['chunks'] == packaging['sharedChunkCount'] == 1755
    assert evm['deployment']['allRuntimeBytesVerified'] and evm['deployment']['blobBytes'] == packaging['sharedBlobBytes'] == 28741889
    assert evm['otherEpisodeRejected']['status'] == '0x0' and evm['otherEpisodeRejected']['logs'] == 0
    logs = ROOT/'artifacts/local/episode-verification'
    node = (logs/'node.log').read_text(); forge = (logs/'forge.log').read_text()
    assert re.search(r'ℹ tests 69\b', node) and re.search(r'ℹ pass 69\b', node) and re.search(r'ℹ fail 0\b', node)
    assert '4 tests passed, 0 failed, 0 skipped' in forge and forge.count('[PASS]') == 4
    assert read('artifacts/local/wad/episode.json') == catalog
    for pkg in catalog['maps']: assert read('artifacts/local/wad/maps/'+pkg['map']+'.json') == pkg
    packer = json.loads((logs/'packer.log').read_text()); assert packer['pass'] and packer['maps'] == 9 and packer['everyLumpByteVerified'] and packer['repeatedPackingExact']
    legacy = json.loads((logs/'legacy-packer.log').read_text()); assert legacy['result'] == 'pass' and legacy['resourceIdentity'] == catalog['resourceIdentity']
    owned = ['docs/PHASE4-EPISODE-RESOURCES.md', 'schemas/episode-resources-v1.schema.json', 'src/support/EpisodeResourcesProbe.sol',
             'tools/wad/episode.ts', 'tools/wad/episode-pack.ts', 'tools/wad/episode-native.ts', 'tools/wad/episode-measure.ts', 'tools/wad/episode.test.ts',
             'tools/reference/episode/reference.py', 'tools/reference/episode/driver.c', 'tools/reference/episode/evm.mjs', 'tools/reference/episode/checkpoint.py',
             'test/fixtures/phase4_episode/catalog.json', 'test/fixtures/phase4_episode/native.json',
             'artifacts/phase4/episode-native-comparison.json', 'artifacts/phase4/episode-packaging.json', 'artifacts/phase4/episode-evm.json']
    report = dict(schemaVersion=1, goal='4.7a', baseline=BASELINE, branch='feat/phase4-multimap', resourceIdentity=catalog['resourceIdentity'],
                  catalogSha256=catalog['catalogSha256'], maps=MAPS, nodeTests=dict(passed=69, failed=0, originalParserTests=51, episodeTests=18),
                  focusedFoundryTests=dict(passed=4, failed=0, skipped=0, names=re.findall(r'\[PASS\] (test\w+)\(', forge)),
                  nativeProfiles=native['profiles'], tenRawLumpsPerMapVerified=True, allRuntimeGeometryFieldsVerified=True,
                  sharedNativeResourcesExact=True, ordinaryEvmMapReceipts=9, all1755OrdinaryCreateRuntimesExact=True,
                  protectedBaselineFileCount=len(protected), protectedBaselineSha256=sha(canonical(protected)),
                  protectedScope='Every tracked baseline file except the two explicitly owned documentation updates; includes all engine/production adapters, existing tests/fixtures, browser, compiler/config/scripts and historical evidence.',
                  sourceSha256={name: sha((ROOT/name).read_bytes()) for name in owned},
                  logSha256={p.name: sha(p.read_bytes()) for p in sorted(logs.glob('*.log'))},
                  requirements={
                    'parserAndNineMapPackages': 'Strict schema, regenerated catalog/map files, 18 focused episode tests and unchanged 51 parser cases',
                    'originalSemanticsAndSharedResources': 'Unchanged v0 identity/bytes/directory, per-map descriptor proofs, accepted native texture/composite/flat/sprite comparison',
                    'nativeCAllNineMaps': 'Three native profiles, seven original geometry loaders, P_LoadBlockMap, original signed mapthing_t, all raw lumps including REJECT',
                    'costsAndRealEvm': 'Three packaging runs, full ordinary resource deployment, nine mined native-equal map receipts and measured operation/receipt gas',
                    'integrationContract': 'Versioned schema, packEpisode/verifyEpisode interfaces, PHASE4-EPISODE-RESOURCES.md',
                    'boundaries': 'No baseline code/adapter/test/config/history modifications, resource-only new support harness, no main merge or full regression suite'},
                  exclusions=['Gameplay startup/Frames, level progression/transitions/intermission, renderer algorithms, browser WAD upload, sound and other-episode support', 'Full inherited regression suite'])
    report['pass'] = True
    encoded = (json.dumps(report, indent=2)+'\n').encode()
    if args.check: assert TARGET.read_bytes() == encoded, 'Verification checkpoint drift'
    else: TARGET.write_bytes(encoded)
    print(json.dumps(dict(pass_=True, maps=9, nodeTests=69, foundryTests=4, protectedBaselineFiles=len(protected))))

if __name__ == '__main__': main()
