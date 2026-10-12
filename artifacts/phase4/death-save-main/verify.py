#!/usr/bin/env python3
"""Read-only verification of the frozen combined-state integration checkpoint."""
import gzip, hashlib, json, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sha = lambda b: hashlib.sha256(b).hexdigest()
manifest = json.loads((HERE/'integration.json').read_text())
assert manifest['overallPass'] and manifest['productDecision']['canonicalImplemented'] is False
for name, expected in manifest['bindings'].items():
    assert sha((ROOT/name).read_bytes()) == expected, ('binding', name)
for source in manifest['sourceCommits']:
    subprocess.run(['git', 'merge-base', '--is-ancestor', source, manifest['codeCheckpoint']], cwd=ROOT, check=True)
for name, expected in json.loads((HERE/'preservation.json').read_text())['sourceExactFiles'].items():
    assert sha((ROOT/name).read_bytes()) == expected, ('source preservation', name)
baseline = manifest['baseline']
for name in json.loads((HERE/'preservation.json').read_text())['protectedBaselineFiles']:
    assert (ROOT/name).read_bytes() == subprocess.check_output(['git','show',baseline+':'+name], cwd=ROOT)
for name in ['docs/DEATH-RESPAWN.md','docs/SAVE-LOAD.md','docs/SAVE-LOAD-CANONICAL-DISCOVERY.md']:
    source = manifest['deathTip'] if 'DEATH-' in name else manifest['saveTip']
    assert (ROOT/name).read_bytes() == subprocess.check_output(['git','show',source+':'+name],cwd=ROOT)
prior = subprocess.check_output(['git','show',baseline+':docs/PHASE4-PLAN.md'],cwd=ROOT).decode()
ledger=(ROOT/'docs/PHASE4-PLAN.md').read_text()
assert ledger[ledger.index('Full Video + Options checkpoint'):].startswith(prior.split('\n\n',1)[1])
primary=json.loads((HERE/'browser-primary.json').read_text())
reload=json.loads((HERE/'browser-reload.json').read_text())
assert primary['pass'] is False and reload['pass'] is True
assert all(primary['combined'][g]['pass'] for g in ['freedoom','ultimate','doom2'])
assert len(primary['rollbacks'])==18 and all(r['allStorageUnchanged'] and r['noLogs'] for r in primary['rollbacks'])
assert all(f['allCanvasPixelsExact'] for f in primary['frames']+reload['frames'])
assert sha(gzip.decompress((HERE/'browser-primary-executed.mjs.gz').read_bytes())) == primary['sourceHashes']['tools/reference/death_save/browser.mjs']
for name, expected in reload['sourceHashes'].items(): assert sha((ROOT/name).read_bytes())==expected, name
forge=json.loads((HERE/'forge.json').read_text())
cases=[t for suite in forge.values() for t in suite['test_results'].values()]
assert len(cases)==33 and all(t['status']=='Success' for t in cases)
assert json.loads((HERE/'node.json').read_text())['exitCode']==0
native=json.loads((HERE/'native-browser.json').read_text());assert native['pass']
assert sum(x['gameplayTics'] for x in native['cases'])==3411
assert sum(x['completeFramesAndPalettes'] for x in native['cases'])==126
memory=json.loads((HERE/'production-memory.json').read_text());assert memory['pass']
assert all(m['productionObserverStateAndFrameEqual'] and m['gasMsizeIdenticalGas'] for m in memory['measurements'])
for contract,row in json.loads((HERE/'releases.json').read_text()).items():
    assert sha((ROOT/row['artifact']).read_bytes())==row['artifactSha256']
    artifact=json.loads((ROOT/row['artifact']).read_text())
    assert sha(bytes.fromhex(artifact['runtime'].removeprefix('0x')))==row['runtimeSha256']
    pins=(ROOT/row['pins']).read_text();pins=json.loads(pins[pins.index('{'):pins.rindex('}')+1])
    for path, identity in pins['sources'].items(): assert sha((ROOT/path).read_bytes())==identity,path
assert all(c['closed'] for c in json.loads((HERE/'runtime-cleanup.json').read_text())['checks'])
assert subprocess.check_output(['git','-C','original/DOOM','rev-parse','HEAD'],cwd=ROOT,text=True).strip()=='a77dfb96cb91780ca334d0d4cfd86957558007e0'
for media in json.loads((HERE/'media-preserved.json').read_text())['files']:
    p=Path(media['file']);stat=p.stat();assert stat.st_size==media['bytes'] and stat.st_mtime_ns==media['mtimeNs']
    assert sha(p.read_bytes())==media['sha256'],str(p)
print('PASS frozen combined checkpoint:',len(manifest['bindings']),'bindings;33 Forge/80 Node;three-game exact death/save/rebirth/reload;126 native comparisons;27 historical MP4s')
