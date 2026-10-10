#!/usr/bin/env python3
"""Bind Goal 4.4 evidence; protect accepted baseline and shared adapters."""
import argparse, hashlib, json, pathlib, re, subprocess
ROOT=pathlib.Path(__file__).resolve().parents[3]
BASE='9f98ed1d38e6de3f2577f5d76b07ec136fc70d52'
REPORT=ROOT/'artifacts/phase4/cheats-verification.json'
sha=lambda b:hashlib.sha256(b).hexdigest()
def protected():
    rows=subprocess.check_output(['git','ls-tree','-r',BASE],cwd=ROOT,text=True).splitlines()
    files=sum(row.split('\t',1)[0].split()[1]=='blob' for row in rows)
    changed=subprocess.check_output(['git','diff','--name-only',BASE,'--'],cwd=ROOT,text=True).splitlines()
    previous=subprocess.check_output(['git','show',BASE+':docs/PHASE4-PLAN.md'],cwd=ROOT)
    assert (ROOT/'docs/PHASE4-PLAN.md').read_bytes().startswith(previous), 'historical ledger was edited'
    baseline_paths={row.split('\t',1)[1] for row in rows}
    additions=[path for path in changed if path not in baseline_paths]
    prefixes=('src/doom/m_cheat.sol','src/doom/st_cheats.sol','src/support/Cheat','test/unit/m_cheat.t.sol','test/integration/Cheats.t.sol','test/fixtures/phase4_cheats/','tools/reference/cheats/','docs/PHASE4-CHEATS.md','artifacts/phase4/cheats-')
    assert all(path.startswith(prefixes) for path in additions),additions
    changed=[path for path in changed if path in baseline_paths]
    assert set(changed)<= {'docs/PHASE4-PLAN.md'},changed
    assert subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip()=='feat/phase4-cheats'
    return dict(baseline=BASE,baselineFiles=files,allowedChangedFiles=changed,
        sharedProductionInterfacesAdaptersBrowserCompilerHistoricalEvidence='unchanged',mainAndOtherBranchesModified=False)
def bound_paths():
    paths=[ROOT/p for p in ['src/doom/m_cheat.sol','src/doom/st_cheats.sol','src/support/CheatFixture.sol','src/support/CheatProbe.sol','test/unit/m_cheat.t.sol','test/integration/Cheats.t.sol','docs/PHASE4-CHEATS.md','foundry.toml','execution-budget.json','artifacts/phase4/cheats-evm.json']]
    paths += [p for folder in ['tools/reference/cheats','test/fixtures/phase4_cheats'] for p in (ROOT/folder).iterdir() if p.is_file()]
    return sorted(paths)
def check_bindings(report):
    for path,digest in report['sourceSha256'].items():assert sha((ROOT/path).read_bytes())==digest,'stale proof binding '+path
    receipt=json.loads((ROOT/'artifacts/phase4/cheats-evm.json').read_text())
    for path,digest in receipt['sourceSha256'].items():assert sha((ROOT/path).read_bytes())==digest,'stale receipt binding '+path
    for p in ['manifest.json','presentation.json']:
        native=json.loads((ROOT/'test/fixtures/phase4_cheats'/p).read_text())
        if p=='manifest.json':
            for name,digest in native['sources'].items():assert sha((ROOT/'original/DOOM/linuxdoom-1.10'/name).read_bytes())==digest,name
            for name,digest in native['harness'].items():assert sha((ROOT/'tools/reference/cheats'/name).read_bytes())==digest,name
            assert sha((ROOT/'test/fixtures/phase4_cheats/vectors.bin').read_bytes())==native['vectorsSha256']
            assert sha((ROOT/'test/fixtures/phase4_cheats/primitive.bin').read_bytes())==native['primitiveVectorsSha256']
        else:
            for name,digest in native['sourceSha256'].items():assert sha((ROOT/name).read_bytes())==digest,name
            assert sha((ROOT/'test/fixtures/phase4_cheats/presentation.bin').read_bytes())==native['vectorsSha256']
    assert receipt['pass'] and receipt['cases']==20 and receipt['snapshots']==491
    assert report['foundry']['passed']==69 and report['foundry']['failed']==0 and report['foundry']['skipped']==0
    assert report['native']['scenarios']==150 and report['native']['eventSnapshots']==4196 and report['native']['primitives']==793 and report['native']['presentationCheckpoints']==15
    for log,digest in report['localLogSha256'].items():
        path=ROOT/log
        if path.exists():assert sha(path.read_bytes())==digest,'local log differs '+log
    return protected()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args()
    if args.check:
        r=json.loads(REPORT.read_text());preservation=check_bindings(r)
        assert preservation==r['preservation'],preservation
        print('PASS Goal 4.4 proof/source bindings; accepted baseline and shared production files preserved');return
    logs=['artifacts/local/cheats/forge-final.log','artifacts/local/cheats/native-final.log','artifacts/local/cheats/presentation-final.log','artifacts/local/cheats/evm-final.log']
    forge=(ROOT/logs[0]).read_text();result=re.search(r'Ran (\d+) test suites.*?: (\d+) tests passed, (\d+) failed, (\d+) skipped',forge)
    assert result and result.groups()==('9','69','0','0'),result.groups() if result else forge[-1000:]
    assert 'PASS 793 primitive native cases' in (ROOT/logs[1]).read_text()
    assert '150 scenarios / 4196 event snapshots' in (ROOT/logs[1]).read_text()
    assert 'PASS 15 raw-cheat status/HUD pixel comparisons' in (ROOT/logs[2]).read_text()
    assert '"pass":true' in (ROOT/logs[3]).read_text()
    receipt=json.loads((ROOT/'artifacts/phase4/cheats-evm.json').read_text())
    native=json.loads((ROOT/'test/fixtures/phase4_cheats/manifest.json').read_text())
    pixel=json.loads((ROOT/'test/fixtures/phase4_cheats/presentation.json').read_text())
    gas=[tx['gasUsed'] for row in receipt['rows'] for tx in row['transactions']]
    names=re.findall(r'\[PASS\] ([^ (]+)',forge);assert len(names)==69
    report=dict(schemaVersion=1,goal='4.4',
        implementation='Complete original supported cheat recognition/effects in new Solidity modules; IDMUS/sound omitted.',
        integration='Independent accepted GameContext/Gameflow/ST/HU composition verified; shared production adapters unchanged. AM pixels, multi-map loading and browser routing deferred under ownership boundaries.',
        native=dict(scenarios=native['cases'],eventSnapshots=native['snapshots'],primitives=native['primitiveCases'],profiles=native['profiles'],sourceSpans=native['extractions'],presentationCheckpoints=pixel['cases'],presentationProfiles=pixel['profiles'],presentationSanitizerExclusions=pixel['sanitizerExclusions'],earlyNulWarp='Native uninitialized buf[1] gameplay domain excluded; exact primitive/parser mutations verified and Solidity rejects the request.'),
        foundry=dict(suites=9,passed=69,failed=0,skipped=0,newCheatTests=20,affectedInheritedTests=49,tests=names,command=".toolchain/bin/forge test --offline --fuzz-seed 0x434844 --match-path 'test/{unit/m_cheat,unit/p_inter,unit/p_user,unit/g_game_lifecycle,unit/st_lib,unit/st_stuff,unit/hu_lib,unit/hu_stuff,integration/Cheats}.t.sol' --skip Doom --skip GameplayProbe --skip RendererProbe --skip WadResourcesProbe -vv",compilerSeconds=float(re.search(r'Solc 0.8.37 finished in ([\d.]+)s',forge)[1]),fullInheritedRegression='deferred to final Phase 4'),
        ordinaryEvm=dict(cases=receipt['cases'],nativeSnapshots=receipt['snapshots'],inputTransactions=len(gas),deploymentGas=receipt['deploymentGas'],inputTransactionGasMin=min(gas),inputTransactionGasMax=max(gas),gasScope='Support probe includes storage and observation work, not isolated cheat or production engine cost.',storageRoundTrip=True,minedRollbackRetryAndSequenceRejection=True,report='artifacts/phase4/cheats-evm.json'),
        originalToSolidity={'m_cheat.c cht_CheckCheat/cht_GetParam':'src/doom/m_cheat.sol','st_stuff.c cheat sequences/ST_Responder cheat branches':'src/doom/st_cheats.sol ST_Responder','am_map.c cheat_amap/AM_Responder cheat branch':'src/doom/st_cheats.sol AM_CheckCheat','p_inter.c P_GivePower':'accepted src/doom/p_inter.sol','g_game.c G_DeferedInitNew':'accepted src/doom/g_game.sol'},
        agentAttribution='One root agent; no subagents. Runtime model identifier/category token usage unavailable from goal counter; no transcript mining.',
        sourceSha256={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in bound_paths()},localLogSha256={p:sha((ROOT/p).read_bytes()) for p in logs},preservation=protected())
    report['pass']=True
    check_bindings(report);REPORT.write_text(json.dumps(report,indent=2)+'\n')
    print('PASS Goal 4.4 evidence: 69 Foundry tests, native state/primitive/pixel comparisons, ordinary receipts and baseline preservation')
if __name__=='__main__':main()
