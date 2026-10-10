#!/usr/bin/env python3
"""Bind executed goal gates to their exact sources/resources; does not replace execution."""
import argparse, datetime, hashlib, json, pathlib, subprocess
ROOT=pathlib.Path(__file__).resolve().parents[3]
REPORT=ROOT/'artifacts/phase4/intermission/verification.json'
BASE='9f7d09120a1a250fe38f85b4f4bcba6cc78b5117'
def sha(b):return hashlib.sha256(b).hexdigest()
def read(p):return json.loads((ROOT/p).read_text())
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args()
    native=read('test/fixtures/phase4_intermission/native.json')
    cases=read('test/fixtures/phase4_intermission/cases.json')
    evm=read('artifacts/phase4/intermission/evm.json')
    focused=read('artifacts/phase4/intermission/focused.json')
    assert native['exactNativeAgreement'] and native['caseCount']==34 and native['snapshots']==1215
    assert len(native['functionMapping'])==28 and len(native['resources'])==79
    assert native['casesSha256']==sha((ROOT/'test/fixtures/phase4_intermission/cases.bin').read_bytes())
    for name,h in native['harnessSha256'].items():assert sha((ROOT/'tools/reference/intermission'/name).read_bytes())==h,name
    for resource in native['resources']:
        assert sha((ROOT/'test/fixtures/phase4_intermission'/(resource['name']+'.bin')).read_bytes())==resource['sha256']
    for profile in native['assetProfiles']:
        assert sha((ROOT/f"test/fixtures/phase4_intermission/assets-{profile['profile']}.bin").read_bytes())==profile['sha256']
    for i,row in enumerate(cases['cases']):
        prefix=ROOT/f'test/fixtures/phase4_intermission/{i}'
        assert sha(prefix.with_suffix('.bin').read_bytes())==row['inputSha256']
        expected=prefix.with_suffix('.expected.bin').read_bytes();assert sha(expected)==row['expectedSha256']
        assert len(expected)==row['snapshots']*532
        for j,h in enumerate(row['hashes']):
            pos=j*532
            assert sha(expected[pos:pos+452])==h['stateSha256']
            assert expected[pos+468:pos+500].hex()==h['frameSha256']
            assert expected[pos+500:pos+532].hex()==h['backgroundSha256']
        assert sha(prefix.with_suffix('.pixels').read_bytes())==row['hashes'][-1]['frameSha256']
    assert evm['pass'] and len(evm['rows'])==34 and evm['snapshotsCompared']==1215
    assert len(evm['resources'])==44 and len(evm['storageRows'])==30 and len(evm['rejections'])==6
    assert all(r['storageRootUnchanged'] and r['logs']==0 for r in evm['rejections'])
    assert focused['pass_'] and focused['counts']==[28,0,0,28]
    for proof in [evm,focused]:
        for path,h in proof['sourceSha256'].items():assert sha((ROOT/path).read_bytes())==h,'changed after gate: '+path
    assert evm['compiler']['version']=='0.8.37+commit.f401782d'
    settings=evm['compiler']['settings']
    assert settings['viaIR'] and settings['optimizer']=={'enabled':True,'runs':200} and settings['evmVersion']=='cancun'
    assert evm['gasBudget']==10000000000
    protected=['AGENTS.md','src/evm/Doom.sol','src/evm/DoomGame.sol','src/evm/DoomUI.sol',
               'src/doom/g_game.sol','src/doom/p_game_state.sol','src/evm/InputProtocol.sol',
               'src/evm/FrameProtocol.sol','src/evm/ResourceTypes.sol','src/doom/v_video.sol',
               'src/doom/m_random.sol','web/app.mjs','web/input-loop.mjs','web/ui-palette.mjs',
               'docs/PHASE4-PLAN.md','foundry.toml','execution-budget.json']
    protected_hashes={}
    for path in protected:
        b=(ROOT/path).read_bytes();assert b==git('show',BASE+':'+path),'protected baseline changed: '+path
        protected_hashes[path]=sha(b)
    assert git('branch','--show-current').decode().strip()=='feat/phase4-intermission'
    subprocess.run(['git','merge-base','--is-ancestor',BASE,'HEAD'],cwd=ROOT,check=True)
    implementation=git('log','-1','--format=%H','--','src/doom/wi_stuff.sol').decode().strip()
    assert implementation,'commit verified implementation before certificate'
    for path in ['src/doom/wi_stuff.sol','src/doom/wi_stuff_types.sol','src/support/IntermissionFixture.sol',
                 'src/support/IntermissionProbe.sol','test/intermission/Intermission.t.sol']:
        assert git('show',implementation+':'+path)==(ROOT/path).read_bytes(),path
    previews=read('artifacts/phase4/intermission/previews.json')
    for row in previews['rows']:assert sha((ROOT/f"artifacts/phase4/intermission/{row['name']}.png").read_bytes())==row['pngSha256']
    paths=['docs/PHASE4-INTERMISSION.md','tools/reference/intermission/README.md',
           'tools/reference/intermission/checkpoint.py','tools/reference/intermission/preview.py',
           'artifacts/phase4/intermission/evm.json','artifacts/phase4/intermission/focused.json',
           'artifacts/phase4/intermission/focused.log','artifacts/phase4/intermission/previews.json',
           'test/fixtures/phase4_intermission/native.json','test/fixtures/phase4_intermission/cases.json']
    report=dict(schemaVersion=1,goal='4.14a',pass_=True,baseline=BASE,implementationCommit=implementation,
        upstreamCommit=native['upstreamCommit'],nativeCases=34,nativeSnapshots=1215,originalFunctions=28,
        originalResources=79,forgeCounts=focused['counts'],ordinaryFrames=34,ordinaryResourceCreates=44,
        ordinaryStorageCalls=30,ordinaryStorageRootRollbacks=6,protectedBaselineSha256=protected_hashes,
        evidenceSha256={p:sha((ROOT/p).read_bytes()) for p in paths},evmSourceSha256=evm['sourceSha256'],
        limits=['Independent WI support host only; no production Gameflow/Episode Runtime/browser wiring',
                'No native zone allocation/tag equivalence, palette/gamma/browser RGB or melt timeline acceptance',
                'Post-WI_End draw and arithmetic/invalid-resource undefined C domains excluded explicitly',
                'Synthetic marker resources declared separately; original WAD assets remain exact',
                'No complete inherited regression suite or whole-episode acceptance'])
    if args.check:assert read(str(REPORT.relative_to(ROOT)))==report,'stale verification certificate'
    else:REPORT.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(dict(pass_=True,goal='4.14a',implementationCommit=implementation,certificate=str(REPORT.relative_to(ROOT)))))
if __name__=='__main__':main()
