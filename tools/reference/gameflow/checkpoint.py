#!/usr/bin/env python3
"""Focused verification and immutable-source checkpoint; no inherited full-suite run."""
import argparse,datetime,hashlib,json,pathlib,re,subprocess,time
ROOT=pathlib.Path(__file__).resolve().parents[3]
BASE='084764b'
EVIDENCE=ROOT/'artifacts/phase4/gameflow-verification.json'
LOGS=ROOT/'artifacts/local/gameflow'
FORGE=['.toolchain/bin/forge','test','--match-path','test/{unit/Gameflow*,unit/g_game,integration/GameflowE1M1}.t.sol',
       '--skip','GameplayProbe','--skip','RendererProbe','--skip','WadResourcesProbe','--skip','Doom.sol','--skip','DoomRenderer.t.sol','-vv']
STAGES=[('native',['python3','tools/reference/gameflow/reference.py','--check']),
        ('observation-schema',['python3','tools/reference/gameflow/snapshot.py','--check']),
        ('legacy-provenance',['python3','tools/reference/gameflow/legacy.py','--check']),
        ('inherited-input-native',['python3','tools/reference/phase3_input/reference.py','--check']),
        ('format',['.toolchain/bin/forge','fmt','--check','src/doom/g_game.sol','test/unit/Gameflow.t.sol',
                   'test/unit/GameflowHarness.sol','test/unit/GameflowTransactions.t.sol','test/integration/GameflowE1M1.t.sol']),
        ('evm',FORGE)]
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def files():
    names=['src/doom/g_game.sol','docs/PHASE4-GAMEFLOW.md','test/integration/GameflowE1M1.t.sol']
    for pattern in ('test/unit/Gameflow*.sol','test/fixtures/phase4_gameflow/*','tools/reference/gameflow/*'):
        names.extend(str(p.relative_to(ROOT)) for p in ROOT.glob(pattern) if p.is_file() and p.suffix!='.pyc')
    return {n:sha((ROOT/n).read_bytes()) for n in sorted(names)}
def protected():
    # Every pre-existing file except the explicitly owned g_game.sol is frozen.
    changed=git('diff','--name-only','--diff-filter=MDRT',BASE).splitlines()
    assert changed==['src/doom/g_game.sol'],('unexpected baseline modification',changed)
    assert not git('-C',str(ROOT/'original/DOOM'),'diff','--name-only','HEAD')
    return dict(baseline=git('rev-parse',BASE),onlyModifiedBaselineFile='src/doom/g_game.sol',
                productionAdapters='unchanged',sharedStateInterfaces='unchanged',inheritedFixtures='unchanged',
                compilerSettings='unchanged',fullInheritedSuiteRun=False)
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args()
    guards=protected();before=files()
    if args.check:
        evidence=json.loads(EVIDENCE.read_text())
        assert evidence['files']==before,'checkpoint file drift'
        assert evidence['preservation']==guards,'preservation drift'
        assert evidence['evm']['passed']==28 and evidence['evm']['failed']==evidence['evm']['skipped']==0
        assert evidence['native']['cases']==219
        print('PASS gameflow checkpoint hashes, ownership and 28-test / 219-case evidence bindings')
        return
    LOGS.mkdir(parents=True,exist_ok=True)
    stages=[];started=datetime.datetime.now(datetime.timezone.utc).isoformat()
    for name,command in STAGES:
        start=time.monotonic();print('RUN',name,flush=True)
        path=LOGS/(name+'.log')
        with path.open('w') as log:result=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
        assert result.returncode==0,(name,'failed; see '+str(path))
        output=path.read_bytes()
        stages.append(dict(name=name,command=command,exitCode=0,seconds=round(time.monotonic()-start,3),logSha256=sha(output)))
        print('PASS',name,flush=True)
    output=(LOGS/'evm.log').read_text()
    summary=re.search(r'Ran \d+ test suites?.*: (\d+) tests passed, (\d+) failed, (\d+) skipped',output)
    assert summary and tuple(map(int,summary.groups()))==(28,0,0),'unexpected EVM coverage'
    tests=[dict(name=n,gas=int(g)) for n,g in re.findall(r'\[PASS\] (\w+)\(\) \(gas: (\d+)\)',output)]
    assert len(tests)==28
    assert before==files(),'sources changed during verification'
    assert protected()==guards
    manifest=json.loads((ROOT/'test/fixtures/phase4_gameflow/manifest.json').read_text())
    assert manifest['cases']==219
    evidence=dict(goal='4.6',status='verified within gameflow ownership',startedAt=started,
        completedAt=datetime.datetime.now(datetime.timezone.utc).isoformat(),branch=git('branch','--show-current'),
        files=before,preservation=guards,stages=stages,
        native=dict(cases=manifest['cases'],profiles=list(manifest['profiles']),functions=len(manifest['extractions']),
                    fixture='test/fixtures/phase4_gameflow/manifest.json'),
        evm=dict(passed=28,failed=0,skipped=0,tests=tests,scope='Foundry EVM; external-call storage/rollback tests plus actual E1M1 setup/gameplay; no ordinary RPC receipt or browser claim'),
        inheritedInput=dict(nativeVectors=41007,evmTests=14),
        originalSourceMap=manifest['extractions'],
        integrationHandoff='docs/PHASE4-GAMEFLOW.md',
        limits=['Only one map is loaded; all nine map transition selections use explicit native boundary doubles.',
                'Intermission and finale presentation hooks are observed, graphics are excluded.',
                'Production storage/UI adapters remain integration-owned and unchanged.',
                'Native full E1M1 DSG1 comparison covers startup and first tic; later sequence assertions test invariants.',
                'No full inherited verification suite, main merge, or later goal.'])
    EVIDENCE.parent.mkdir(parents=True,exist_ok=True)
    EVIDENCE.write_text(json.dumps(evidence,indent=2)+'\n')
    print('PASS verified gameflow checkpoint written',flush=True)
if __name__=='__main__':main()
