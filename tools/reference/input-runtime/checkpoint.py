#!/usr/bin/env python3
"""Export/check recorded Goal 4.12 proof bindings; does not replace execution."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[3]
LOCAL=ROOT/'artifacts/local/input-runtime'
DEST=ROOT/'artifacts/phase4/input-runtime'
BASE='9f7d09120a1a250fe38f85b4f4bcba6cc78b5117'
OWNED=['src/evm/Doom.sol','src/evm/DoomGame.sol','src/evm/DoomUI.sol','src/evm/InputProtocol.sol',
       'web/app.mjs','web/input.mjs','web/input-loop.mjs','web/input-runtime.test.mjs',
       'test/integration/InputRuntime.t.sol','tools/transport/input-runtime-browser-check.mjs']
OWNED += [str(p.relative_to(ROOT)) for p in sorted((ROOT/'tools/reference/input-runtime').glob('*')) if p.is_file()]
def sha(b):return hashlib.sha256(b).hexdigest()
def read(path):return json.loads(path.read_text())
def encoded(value):return (json.dumps(value,indent=2,sort_keys=True)+'\n').encode()
def validate():
    focused=read(LOCAL/'focused.json');node=read(LOCAL/'node.json')
    assert focused['exitCode']==node['exitCode']==0
    for name,record in [('focused',focused),('node',node)]:
        assert sha((LOCAL/(name+'.log')).read_bytes())==record['logSha256']
    assert re.search(r'220 tests passed, 0 failed, 0 skipped', (LOCAL/'focused.log').read_text())
    assert re.search(r'pass 56', (LOCAL/'node.log').read_text())
    assert re.search(r'fail 0', (LOCAL/'node.log').read_text())
    production=read(LOCAL/'production-final.json');browser=read(LOCAL/'production-final-browser.json')
    legacy=read(LOCAL/'ui-final.json')
    assert production['pass'] and browser['pass'] and legacy['pass']
    assert len(production['comparisons'])==browser['executedTics']==51
    assert len(production['frames'])==36 and len(browser['frames'])==35
    assert len(production['rejections'])==10 and all(r['allStorageRollback'] for r in production['rejections'])
    assert len(legacy['comparisons'])==210 and len(legacy['frames'])==14
    assert production['stoppedOwnedRuntime'] and legacy['stoppedOwnedRuntime']
    assert browser['fallbackVerified'] and browser['blurStopsBeforeNextCommand']
    assert all(r['all64000NativePixelsExact'] and r['allCanvasPixelsExact'] for r in browser['frames'])
    native=ROOT/'artifacts/local/input-runtime-native';manifest=read(native/'manifest.json')
    assert manifest['tics']==51 and manifest['frames']==35 and len(manifest['profiles'])==4
    assert production['nativeManifestSha256']==browser['nativeManifestSha256']==sha((native/'manifest.json').read_bytes())
    for name,digest in manifest['files'].items():assert sha((native/name).read_bytes())==digest,name
    for path,digest in manifest['sourceHashes'].items():assert sha((ROOT/path).read_bytes())==digest,path
    for report in [production,browser,legacy]:
        for path,digest in report.get('sourceHashes',report.get('sources',{})).items():
            assert sha((ROOT/path).read_bytes())==digest,path
    assert production['resourceIdentity']==browser['config']['resourceIdentity']==manifest['resourceIdentity']==legacy['resourceIdentity']
    assert subprocess.check_output(['git','-C',str(ROOT/'original/DOOM'),'rev-parse','HEAD'],text=True).strip()==manifest['upstreamCommit']
    subprocess.run(['git','-C',str(ROOT/'original/DOOM'),'diff','--exit-code','HEAD'],check=True,capture_output=True)
    artifact=read(ROOT/'out/Doom.sol/Doom.json');metadata=artifact['metadata']
    if isinstance(metadata,str):metadata=json.loads(metadata)
    assert metadata['compiler']['version'].startswith('0.8.37')
    settings=metadata['settings'];assert settings['viaIR'] and settings['optimizer']['runs']==200 and settings['evmVersion']=='cancun'
    frame=next(a for a in artifact['abi'] if a.get('type')=='event' and a['name']=='Frame')
    assert [i['type'] for i in frame['inputs']]==['uint64','uint32','uint16','uint16','bytes']
    assert [i['indexed'] for i in frame['inputs']]==[True,True,False,False,False]
    assert len(artifact['deployedBytecode']['object'][2:])//2==production['deployment']['runtimeBytes']
    return native,production,browser,legacy,artifact,metadata

def generate():
    native,production,browser,legacy,artifact,metadata=validate()
    pairs={'production.json':LOCAL/'production-final.json','browser.json':LOCAL/'production-final-browser.json',
        'ui-regression.json':LOCAL/'ui-final.json','focused.json':LOCAL/'focused.json','focused.log':LOCAL/'focused.log',
        'node.json':LOCAL/'node.json','node.log':LOCAL/'node.log','native.json':native/'manifest.json',
        'native-build.json':native/'build-manifest.json','packets.json':native/'packets.json',
        'native-runtime.json':native/'runtime.json','native-ui.json':native/'ui.json','native-players.json':native/'players.json'}
    outputs={name:path.read_bytes() for name,path in pairs.items()}
    for name in ['god-completion','IDDT-things-stage','open-map','pending-warp-keeps-current-level']:
        row=next(p for p in read(native/'packets.json') if p['name']==name)
        path=LOCAL/('production-final-browser-tic'+str(row['tic'])+'.png')
        outputs['canvas-'+name+'.png']=path.read_bytes()
    attempts=[]
    for name in ['production-first.json','failed-production-browser.json','failed-production-browser-browser.json',
                 'failed-focused.json','initial-adapter.json','initial-node.json']:
        path=LOCAL/name
        if path.exists():
            record=read(path);attempts.append(dict(path=str(path.relative_to(ROOT)),sha256=sha(path.read_bytes()),
                passed=record.get('pass',record.get('exitCode')==0),error=record.get('error'),exitCode=record.get('exitCode')))
    outputs['attempts.json']=encoded(attempts)
    rendered=[r['gas'] for r in production['comparisons'] if r['draw']]
    nondraw=[r['gas'] for r in production['comparisons'] if not r['draw']]
    certificate=dict(kind='phase4-goal4.12-production-input-runtime',baseline=BASE,branch='feat/phase4-input-runtime',
        complete=True,upstreamCommit=read(native/'manifest.json')['upstreamCommit'],resourceIdentity=production['resourceIdentity'],
        compiler=metadata['compiler'],settings=metadata['settings'],executionBudget=production['executionBudget'],
        abiSha256=sha(json.dumps(artifact['abi'],sort_keys=True,separators=(',',':')).encode()),
        runtimeTemplateSha256=sha(bytes.fromhex(artifact['deployedBytecode']['object'][2:])),
        sourceHashes={p:sha((ROOT/p).read_bytes()) for p in OWNED},
        evidenceHashes={n:sha(b) for n,b in sorted(outputs.items())},
        results=dict(forgePassed=220,nodePassed=56,nativeTics=51,nativeFrames=35,nativeProfiles=4,
            evmTics=51,evmFrames=35,staticFrames=1,minedRollbackChecks=10,chromeFrames=35,
            legacyUITics=210,legacyUIFrames=13,wholeEpisodeAcceptance=False,fullInheritedAcceptance=False),
        measurements=dict(startedUtc=production['startedUtc'],endedUtc=production['endedUtc'],runtimeBytes=production['deployment']['runtimeBytes'],
            startupGas=production['startup']['gas'],renderedGasRange=[min(rendered),max(rendered)],noRenderGasRange=[min(nondraw),max(nondraw)]),
        interfaces=dict(idDTOwner='AM_Map; AutomapState.cheatPos/cheating',
            eventPacket='<=64 ordered [type,key] byte pairs; keydown0/keyup1',
            idClev='GA_NEWGAME and exact deferred skill/episode/map persist; Episode Runtime owns consumption/loading',
            frame='unchanged indexed8 Frame plus existing Goal4.11 FramePalette'),
        limits=['Single-player retail E1M1 medium-skill startup; original US keyboard byte profile.',
            'No menu/demo/chat/network/mouse/joystick or full gameflow dispatch.',
            'Immutable borrowed UI/AM graphics boundary; no new whole-process zone or peak-memory claim.',
            'Finite native scalar/parser/flags/pixel coverage; not whole-world or episode acceptance.'])
    outputs['verification.json']=encoded(certificate)
    return outputs

def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
    if a.check:
        c=read(DEST/'verification.json')
        for path,digest in c['sourceHashes'].items():assert sha((ROOT/path).read_bytes())==digest,path
        for name,digest in c['evidenceHashes'].items():assert sha((DEST/name).read_bytes())==digest,name
        assert c['complete'] and c['results']['forgePassed']==220 and c['results']['nodePassed']==56
        print('PASS Goal4.12 committed source/evidence bindings; recorded gates only')
    else:
        outputs=generate();DEST.mkdir(parents=True,exist_ok=True)
        for name,data in outputs.items():(DEST/name).write_bytes(data)
        print('PASS Goal4.12 proof export:',len(outputs),'files; gates executed separately')

if __name__=='__main__':main()
