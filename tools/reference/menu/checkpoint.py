#!/usr/bin/env python3
"""Source/evidence binding only; does not replace native/EVM/Canvas execution."""
import argparse, hashlib, json, re, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=ROOT/'artifacts/phase4/menu'
sha=lambda data:hashlib.sha256(data).hexdigest()
read=lambda path:json.loads((ROOT/path).read_text())
ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args()
release=read('artifacts/phase4/menu/accepted.json')
browser=read('artifacts/phase4/menu/accepted-browser.json')
inherited=read('artifacts/phase4/menu/inherited-focused.json')
native=read('test/fixtures/evm_menu/manifest.json')
assert release['pass'] and browser['pass'] and inherited['pass_']
assert inherited['counts']==[27,0,0,27]
assert sorted(row['map'] for row in release['selections'])==list(range(1,10))
assert sorted(row['map'] for row in release['freshSelections'])==list(range(1,10))
assert len(release['rollbacks'])>=8 and all(row['allStorageUnchanged'] and row['noLogs'] for row in release['rollbacks'])
assert release['firstGameplayFrameMatchesCheckpointC'] and release['legacy']['nativeFirstFrameExact']
assert all(row['allCanvasPixelsExact'] for row in browser['frames'])
assert browser['noVisibleHTMLLauncher'] and browser['storageReload'] and browser['receiptFallbackAndDedup']
assert release['stoppedOwnedAnvil'] and browser['stoppedOwnedBrowser']
assert release['executionBudget']['gasLimit']==10000000000
assert max(row['gas'] for row in release['inputs'])<=10000000000
assert all(row['state']==0 and row['leveltime']==1 for row in release['freshSelections'])
bound={}
for report in [release,browser]:
    for path,digest in report['sourceHashes'].items():
        assert sha((ROOT/path).read_bytes())==digest,('source drift',path)
        bound[path]=digest
for path,digest in native['sourceHashes'].items():
    filename='original/DOOM/linuxdoom-1.10/'+path
    assert sha((ROOT/filename).read_bytes())==digest
    bound[filename]=digest
for name,digest in native['fixtures'].items():
    path='test/fixtures/evm_menu/'+name
    assert sha((ROOT/path).read_bytes())==digest
    bound[path]=digest
for profile in native['builds']:
    assert not profile['stderr']
    assert profile['outputs']==native['fixtures']
for frame in release['frames']:
    assert sha((ROOT/frame['pixelsPath']).read_bytes())==frame['pixelSha256']
for frame in browser['frames']:
    assert (ROOT/frame['screenshot']).is_file()
protected=['src/doom/g_game.sol','src/doom/v_video.sol','src/evm/EpisodeRuntime.sol','src/evm/EpisodeStartup.sol',
    'src/evm/DoomGame.sol','src/evm/InputProtocol.sol','src/evm/FrameProtocol.sol','foundry.toml','execution-budget.json',
    'src/doom/z_zone.sol','src/doom/z_zone_backing.sol','src/doom/z_zone_types.sol','src/doom/native_zone_layout.sol']
for path in protected:
    baseline=subprocess.check_output(['git','show','1e7033c:'+path],cwd=ROOT)
    assert baseline==(ROOT/path).read_bytes(),('protected source changed',path)
    bound[path]=sha(baseline)
for path in [*HERE.glob('*'),*(ROOT/'tools/reference/menu').glob('*.py'),
             ROOT/'web/menu-input.test.mjs',ROOT/'docs/EVM-MENU.md']:
    if path.is_file() and path.name!='verification.json':bound[str(path.relative_to(ROOT))]=sha(path.read_bytes())
node=read('artifacts/phase4/menu/node.json');assert node['passed']==66 and node['failed']==0
source=list(bound.items())
record=dict(kind='original-evm-menu-feature-certificate',pass_=True,
    baseline='1e7033c149ddab6641be3116af3974d5ed585183',
    checkpoints=['2406f71','fd90725','7ef2412'],
    scope='Feature verification only; no main integration or final historical Phase4 acceptance.',
    sourceEvidenceSha256=dict(sorted(source)),
    counts=dict(nativeScreens=9,nativeProfiles=3,nativeResponderEvents=28,nativeFieldsPerEvent=13,
        menuForgeTests=5,inheritedForgeTests=27,nodeTests=66,evmInputs=len(release['inputs']),
        evmFrames=len(release['frames']),rollbackReceipts=len(release['rollbacks']),
        retainedMapSelections=9,freshMapSelections=9,canvasCheckpoints=len(browser['frames'])),
    maxInputGas=max(row['gas'] for row in release['inputs']),
    limits=['Modified Main/Episode/Select Level screens have no original pixel-equivalence claim.',
            'Native borrowing profile excludes whole-process allocation equivalence.',
            'Inherited original Episode initial-zero and bounded LP64 pointer-high assumptions unchanged.',
            'Peak EVM MSIZE/memory not measured; successful transactions fit unchanged interpreter limit.',
            'No FPS, exhaustive episode replay or public-chain deployment claim.'])
path=HERE/'verification.json'
if args.check:assert json.loads(path.read_text())==record,'certificate drift'
else:path.write_text(json.dumps(record,indent=2)+'\n')
print('PASS source/evidence certificate',record['counts'])
