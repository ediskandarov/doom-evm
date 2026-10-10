#!/usr/bin/env python3
"""Bind executed Goal 4.11 gates; --check validates evidence, not a gate substitute."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'artifacts/phase4/ui'
BASELINE='b833ff844aeccc644a9174b63e8229f1dd40d567'
sha=lambda b:hashlib.sha256(b).hexdigest()
def read(path):return json.loads((ROOT/path).read_text())

def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
    if not a.check:
        OUT.mkdir(parents=True,exist_ok=True)
        sources={
            'native.json':'artifacts/local/ui-native/manifest.json',
            'native-build.json':'artifacts/local/ui-native/build-manifest.json',
            'production.json':'artifacts/local/ui/production-complete.json',
            'browser.json':'artifacts/local/ui/production-complete-browser.json',
            'legacy.json':'artifacts/local/ui/legacy.json',
            'focused.json':'artifacts/local/ui/focused.json',
            'node.json':'artifacts/local/ui/node.json',
            'focused.log':'artifacts/local/ui/focused.log',
            'node.log':'artifacts/local/ui/node.log',
        }
        for name,path in sources.items():shutil.copyfile(ROOT/path,OUT/name)
        for tic in [64,70,204]:
            shutil.copyfile(ROOT/f'artifacts/local/ui/production-complete-browser-tic{tic}.png',OUT/f'canvas-tic{tic}.png')
    production=read('artifacts/phase4/ui/production.json')
    browser=read('artifacts/phase4/ui/browser.json')
    legacy=read('artifacts/phase4/ui/legacy.json')
    native=read('artifacts/phase4/ui/native.json')
    focused=read('artifacts/phase4/ui/focused.json')
    node=read('artifacts/phase4/ui/node.json')
    assert production['pass'] and browser['pass'] and legacy['pass']
    assert len(production['comparisons'])==210 and len(production['frames'])==14
    assert browser['executedTics']==210 and len(browser['frames'])==13
    assert legacy['completeNativeStream'] and legacy['executedTics']==129 and len(legacy['frames'])==7
    assert focused['exitCode']==0 and node['exitCode']==0
    assert b'159 tests passed, 0 failed, 0 skipped' in (OUT/'focused.log').read_bytes()
    assert b'tests 50' in (OUT/'node.log').read_bytes() and b'fail 0' in (OUT/'node.log').read_bytes()
    assert production['stoppedOwnedRuntime'] and not legacy['nodeKeptRunning']
    assert production['resourceIdentity']==native['resourceIdentity']==legacy['resourceIdentity']==browser['config']['resourceIdentity']
    assert sha((OUT/'native.json').read_bytes())==production['nativeManifestSha256']==browser['nativeManifestSha256']
    assert sha((OUT/'focused.log').read_bytes())==focused['logSha256']
    assert sha((OUT/'node.log').read_bytes())==node['logSha256']
    for report in [production,legacy]:
        for path,digest in report['sourceHashes'].items():assert sha((ROOT/path).read_bytes())==digest,path
    for path,digest in browser['sources'].items():assert sha((ROOT/path).read_bytes())==digest,path
    unchanged=['src/doom/st_stuff.sol','src/doom/st_lib.sol','src/doom/hu_stuff.sol','src/doom/hu_lib.sol',
        'src/doom/v_video.sol','src/doom/v_video_types.sol','src/doom/p_game_state.sol',
        'src/evm/FrameProtocol.sol','src/evm/InputProtocol.sol','src/evm/WadResources.sol',
        'foundry.toml','execution-budget.json']
    for path in unchanged:
        assert (ROOT/path).read_bytes()==subprocess.check_output(['git','show',BASELINE+':'+path],cwd=ROOT),path
    assert not subprocess.check_output(['git','diff',BASELINE,'--','original','test/fixtures'],cwd=ROOT)
    runtime_paths=['src/evm/Doom.sol','src/evm/DoomGame.sol','src/evm/DoomUI.sol','web/app.mjs','web/input-loop.mjs','web/ui-palette.mjs']
    tools_paths=['tools/reference/ui/reference.py','tools/reference/ui/production.mjs','tools/reference/ui/verify.py',
                 'tools/reference/ui/checkpoint.py','tools/transport/ui-browser-check.mjs','tools/transport/ui-palette.test.mjs',
                 'test/integration/ProductionUI.t.sol','web/input-loop.test.mjs']
    code_commit=subprocess.check_output(['git','log','-1','--format=%H','--','src/evm/Doom.sol'],cwd=ROOT,text=True).strip()
    result=dict(status='passed',baseline=BASELINE,implementationCommit=code_commit,
        scope='Goal4.11 single-player retail E1M1; no complete Phase0-3/final Phase4 acceptance claim',
        sourceSha256={path:sha((ROOT/path).read_bytes()) for path in runtime_paths+tools_paths+unchanged},
        evidenceSha256={f.name:sha(f.read_bytes()) for f in sorted(OUT.iterdir()) if f.name!='verification.json'},
        native=dict(tics=210,frames=13,profiles=native['profiles'],upstreamCommit=native['upstreamCommit']),
        focusedTests=159,nodeTests=50,consumerStorageVectors=22+168+86,
        production=dict(tics=210,scalarNativeFieldsPerTic=45,allMessageBackingBytesPerTic=81,
            nativePixelFrames=14,nativeUIFrames=13,allFramePixels=64000,allPaletteBytes=768,
            rollbacks=len(production['rejections']),viewportTransitions=production['modes']),
        browser=dict(tics=210,nativeCanvasFrames=13,rgbaBytesPerFrame=256000,receiptFallback=True,blurStopsBeforeNextCommand=True),
        legacy=dict(tics=129,frames=7,rollbacks=len(legacy['rejections'])),
        measurements=dict(executionBudget=production['executionBudget'],startupGas=production['startup']['gas'],
            uiFrameGasRange=[min(r['gas'] for r in production['comparisons'] if r['draw']),max(r['gas'] for r in production['comparisons'] if r['draw'])],
            noRenderGasRange=[min(r['gas'] for r in production['comparisons'] if not r['draw']),max(r['gas'] for r in production['comparisons'] if not r['draw'])],
            uiFrameMsRange=[min(r['ms'] for r in production['comparisons'] if r['draw']),max(r['ms'] for r in production['comparisons'] if r['draw'])],
            productionStartedUtc=production['startedUtc'],productionEndedUtc=production['endedUtc'],
            browserMs=production['browserMs'],focusedGateSeconds=focused['seconds'],productionRuntimeBytes=production['deployment']['runtimeBytes'],
            peakEvmMemory='not measured in this goal; no MSIZE claim'),
        unchangedBaselineFiles=unchanged,
        limitations=['Ordinary production stream exercises natural health-bonus pickup, fire/ammo and HUD expiry; armor, every weapon/key, damage directions and original face quirks have controlled original-C consumer/storage vectors and inherited module proofs.',
            'Only exported production scalar fields and HUD backing are compared each transaction, not whole-world canonical records.',
            'Native immutable UI patch/screen4 buffers use declared consumer ownership outside the existing gameplay zone; no whole-process native-zone equivalence claim.',
            'UI startup uses default original gamma0/showMessages=true and no chat/automap/responders or lifecycle integration. Legacy startup remains world-only.',
            'Browser UI deployments require productionUI:true and use explicit UI startup; legacy configurations retain raw PLAYPAL behavior.'])
    data=(json.dumps(result,indent=2)+'\n').encode()
    if a.check:assert (OUT/'verification.json').read_bytes()==data,'stale certificate'
    else:(OUT/'verification.json').write_bytes(data)
    print(json.dumps(dict(status='passed',tests=159,nodeTests=50,tics=210,uiFrames=13,legacyTics=129,certificate='artifacts/phase4/ui/verification.json')))

if __name__=='__main__':main()
