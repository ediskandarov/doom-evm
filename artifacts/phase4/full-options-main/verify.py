#!/usr/bin/env python3
"""Read-only integrity/coverage verifier for this frozen integration checkpoint."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def read(file):return json.loads((ROOT/file).read_text())
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
manifest=json.loads((HERE/'integration.json').read_text())
for file,digest in manifest['bindings'].items():assert sha((ROOT/file).read_bytes())==digest,file
for tip in manifest['sourceTips'].values():
    subprocess.run(['git','merge-base','--is-ancestor',tip,'HEAD'],cwd=ROOT,check=True)
preserved=read('artifacts/phase4/full-options-main/preservation.json')
for feature in preserved['features']:
    for row in feature['preservedFiles']:
        assert (ROOT/row['file']).read_bytes()==git('show',feature['tip']+':'+row['file']),row['file']
for row in preserved['protectedBoundaries']:
    assert (ROOT/row['file']).read_bytes()==git('show',manifest['baseline']+':'+row['file']),row['file']
old=git('show',manifest['baseline']+':docs/PHASE4-PLAN.md').decode().split('\n\n',1)[1]
assert old in (ROOT/'docs/PHASE4-PLAN.md').read_text(),'historical ledger body lost'
for file,compiled,pins in [('web/install-assets/Doom.json','out/Doom.sol/Doom.json','web/install-pins.mjs'),
                            ('web/doom2-assets/Doom.json','out/Doom2.sol/Doom2.json','web/doom2-pins.mjs')]:
    release=read(file);a=read(compiled)
    assert release['bytecode']==a['bytecode']['object'] and release['runtime']==a['deployedBytecode']['object']
    assert release['methods']==a['methodIdentifiers']
    assert release['immutableReferences']==a['deployedBytecode']['immutableReferences']
    p=json.loads((ROOT/pins).read_text().split('export default ',1)[1].rstrip().rstrip(';'))
    assert p['artifacts']['Doom']['sha256']==sha((ROOT/file).read_bytes())
    for source,digest in p['sources'].items():assert sha((ROOT/source).read_bytes())==digest,source
chrome=read('artifacts/phase4/full-options-main/chrome.json')
assert chrome['pass'] and len(chrome['frames'])==210 and len(chrome['checks'])==23
assert len(chrome['selections'])==15 and len(chrome['rollbacks'])==15
assert all(f['allCanvasPixelsExact'] for f in chrome['frames'])
assert any(s['game']=='doom2' and s['map']==32 for s in chrome['selections'])
assert {s['game'] for s in chrome['selections'] if s['skill']==4}=={'freedoom','ultimate','doom2'}
for installed in chrome['installations'].values():
    assert installed['defaultPolicy']==2 and installed['config']['memoryPolicy']==3
evm=read('artifacts/phase4/full-options-main/evm.json');two=read('artifacts/phase4/full-options-main/evm-e1m2.json')
assert evm['pass'] and two['pass'] and len(evm['frames'])==287 and len(two['frames'])==45
assert sum(bool(f.get('nativePixelsAndPaletteExact')) for f in evm['frames'])==279
assert sum(bool(f.get('nativePixelsAndPaletteExact')) for f in two['frames'])==44
assert [c['canonicalSnapshots'] for c in evm['checks'][:2]]==[317,317]
assert two['checks'][0]['canonicalSnapshots']==85
assert all(f['gameplayFrozen'] for f in evm['frames']+two['frames'])
assert len(evm['rollbacks'])==8 and len(two['rollbacks'])==1
assert all(x['allStorageUnchanged'] and x['noLogs'] for x in evm['rollbacks']+two['rollbacks'])
assert not evm['checks'][-1]['realE1M8ExitReplayed']
assert all(not c['G_WorldDoneVerified'] for c in evm['checks'][:2])
for label,count in [('forge-options',34),('forge-video',14),('forge-wi',4)]:
    log=(HERE/(label+'.log')).read_text()
    assert re.search(rf'{count} tests passed, 0 failed, 0 skipped',log),label
assert 'pass 72' in (HERE/'node.log').read_text()
resolution=read('artifacts/phase4/full-options-main/fullscreen-resolution.json')
assert resolution['correctedNativeEqualsAlreadyMinedEVM'] and not resolution['productionChanged']
cleanup=read('artifacts/phase4/full-options-main/runtime-cleanup.json')
assert all(p['closed'] for p in cleanup['ports'])
assert read('artifacts/phase4/full-options-main/media-preserved.json')['unchangedMp4Count']==27
changed=git('diff','--name-only',manifest['baseline'],'HEAD').decode().splitlines()
assert not any(p.lower().endswith(('.wad','.mp4')) or p.startswith('artifacts/local/') for p in changed)
assert git('-C','original/DOOM','rev-parse','HEAD').decode().strip()=='a77dfb96cb91780ca334d0d4cfd86957558007e0'
assert not git('-C','original/DOOM','status','--porcelain')
print(json.dumps({'pass':True,'bindings':len(manifest['bindings']),'sourceAncestry':True,
                 'freshForge':52,'freshNode':72,'chromeFrames':210,'nativeEqualSampledFrames':323,
                 'historicalRecordingsPreserved':27,'historicalEvidenceUnchanged':True},indent=2))
