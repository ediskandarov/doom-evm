#!/usr/bin/env python3
"""Bind finite startup acceptance to actual sources, fixtures, artifacts and logs."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
EVIDENCE=ROOT/'artifacts/phase4/episode-startup'
BASELINE='9f7d09120a1a250fe38f85b4f4bcba6cc78b5117'

def sha(data):return hashlib.sha256(data).hexdigest()
def read(path):return (ROOT/path).read_bytes()
def json_(path):return json.loads(read(path))

def generate():
    evm=json_('artifacts/phase4/episode-startup/evm.json')
    native=json_('test/fixtures/phase4_episode_startup/manifest.json')
    assert evm['pass'] and evm['stoppedOwnedRuntime']
    assert len(evm['cases'])==len(native['cases'])==12 and len(evm['rejections'])==12
    assert evm['executionBudget']['gasLimit']==10000000000
    assert evm['compiler']['version']=='0.8.37+commit.f401782d'
    settings=evm['compiler']['settings']
    assert settings['viaIR'] and settings['optimizer']==dict(enabled=True,runs=200) and settings['evmVersion']=='cancun'
    assert evm['nativeManifestSha256']==sha(read('test/fixtures/phase4_episode_startup/manifest.json'))
    assert native['status']=='O0/O2/ASan+UBSan exact'
    assert evm['resourceIdentity']==native['resourceIdentity']==json_('test/fixtures/phase4_episode/catalog.json')['resourceIdentity']
    for p,h in evm['sourceHashes'].items():assert sha(read(p))==h,'EVM source drift '+p
    for p,h in native['sourceHashes'].items():assert sha(read(p))==h,'native harness drift '+p
    for p,h in native['build']['sources'].items():assert sha(read('original/DOOM/linuxdoom-1.10/'+p))==h,'original C drift '+p
    for p,h in native['files'].items():assert sha(read('test/fixtures/phase4_episode_startup/'+p))==h,'native fixture drift '+p
    for actual,expected in zip(evm['cases'],native['cases']):
        assert actual['name']==expected['name'] and actual['persistedWorldExact'] and actual['emittedFrames']==0
        assert actual['startupStatus'][3:5]==[0,0]
        for k,h in actual['digests'].items():assert h==expected['files'][k+'.bin']['sha256']
    assert all(r['allStorageRollback'] and r['logs']==0 for r in evm['rejections'])
    logs={}
    for name,count in [('setup',16),('allocator',21)]:
        s=(EVIDENCE/(name+'.log')).read_text()
        assert re.search(rf'{count} tests passed, 0 failed, 0 skipped',s),name
        assert '[FAIL]' not in s
        logs[name]=dict(tests=count,sha256=sha(s.encode()))
    s=(EVIDENCE/'node.log').read_text()
    assert 'tests 69' in s and 'pass 69' in s and 'fail 0' in s
    logs['node']=dict(tests=69,sha256=sha(s.encode()))
    assert 'cases": 12' in (EVIDENCE/'native-recheck.log').read_text()
    protected=['src/evm/Doom.sol','src/evm/DoomGame.sol','src/evm/DoomUI.sol','src/doom','web','docs/PHASE4-PLAN.md',
               'test/fixtures/gameplay','test/fixtures/phase4_gameflow','test/fixtures/phase4_episode',
               'tools/reference/gameplay','tools/reference/episode','tools/reference/ui']
    subprocess.run(['git','diff','--exit-code',BASELINE,'--',*protected],cwd=ROOT,check=True,capture_output=True)
    consumed=dict(evm['sourceHashes'])
    for p in ['test/integration/EpisodeStartup.t.sol','tools/reference/episode_startup/checkpoint.py',
              'tools/reference/episode_startup/observe.inc']:
        consumed[p]=sha(read(p))
    artifacts={}
    for p in ['out/EpisodeStartupProbe.sol/EpisodeStartupProbe.json','out/ResourceStore.sol/ResourceStore.json']:
        b=read(p);a=json.loads(b)
        artifacts[p]=dict(sha256=sha(b),abiSha256=sha(json.dumps(a['abi'],sort_keys=True,separators=(',',':')).encode()))
    probe=json_('out/EpisodeStartupProbe.sol/EpisodeStartupProbe.json')
    runtime=bytearray.fromhex(probe['deployedBytecode']['object'][2:])
    driver='f39fd6e51aad88f6f4ce6ab8827279cfffb92266'
    driver_word=bytes.fromhex(driver.rjust(64,'0'))
    for spans in probe['deployedBytecode']['immutableReferences'].values():
        for span in spans:
            assert span['length']==32
            runtime[span['start']:span['start']+32]=driver_word
    runtime_hash=sha(runtime)
    for case in evm['cases']:
        assert case['deployment']['runtimeBytes']==len(runtime)
        assert case['deployment']['runtimeSha256']==runtime_hash,'current artifact differs from executed runtime'
    return dict(schemaVersion=1,goal='4.13a',pass_=True,baseline=BASELINE,
                implementationCommit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                nativeCases=12,nativeProfiles=native['profiles'],ordinaryEvmCases=12,rollbackReceipts=12,
                logs=logs,sourceSha256=consumed,artifacts=artifacts,
                executedRuntimeSha256=runtime_hash,immutableDriver=driver,
                evidenceSha256={p.name:sha(p.read_bytes()) for p in sorted(EVIDENCE.iterdir()) if p.name!='verification.json'},
                protectedScopes=protected,protectedScopesUnchanged=True,
                integration='Independent foundation only; no production adapters, transitions, tics, Frames or presentation',
                limits=['Pinned deterministic initial-zero/native LP64 profile; unknown mutable payload/pointer/padding bytes remain outside the proof.',
                        'Accepted DSG1 plus named supplementary observations; not every scratch field or all native undefined domains.',
                        'Gas is support-host authentication/setup/serialization/storage/event receipt cost. No production or EVM-memory peak claim.',
                        'No complete inherited suite, browser, rendering, transition/reuse or completed-episode acceptance.'])

def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
    path=EVIDENCE/'verification.json'
    current=generate()
    if a.check:
        old=json.loads(path.read_bytes())
        # The evidence commit follows the implementation commit; both bind the
        # same consumed source/artifacts. Preserve the recorded implementation SHA.
        current['implementationCommit']=old['implementationCommit']
        assert old==current,'checkpoint drift'
    else:path.write_text(json.dumps(current,indent=2,sort_keys=True)+'\n')
    print('PASS Goal4.13a:12 native/EVM startups,12 rollbacks,37 Forge and69 Node tests; protected scopes unchanged')

if __name__=='__main__':main()
