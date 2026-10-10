#!/usr/bin/env python3
"""Bind Goal 4.5 native, focused tests, exact compiler inputs, receipts and ownership."""
import argparse, hashlib, json, pathlib, re, subprocess
ROOT=pathlib.Path(__file__).resolve().parents[3]
BASE='9f98ed1d38e6de3f2577f5d76b07ec136fc70d52'
sha=lambda b:hashlib.sha256(b).hexdigest()
def read(p):return json.loads((ROOT/p).read_text())
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT).decode()
def allowed(p):
    return p in ['src/doom/am_map.sol','src/doom/am_map_types.sol','src/support/AutomapFixture.sol','src/support/AutomapProbe.sol','test/unit/am_map.t.sol','test/integration/AutomapVideo.t.sol','docs/PHASE4-AUTOMAP.md'] or p.startswith(('tools/reference/automap/','test/fixtures/phase4_automap/','artifacts/phase4/automap-'))
def span(text,name,solidity=False):
    pattern=(r'\bfunction\s+' if solidity else r'\b')+name+r'\s*\([^;{}]*\)[^{;]*\{'
    m=re.search(pattern,text);assert m,name
    opening=text.index('{',m.start());depth=1;end=opening+1
    while depth:
        if text[end]=='{':depth+=1
        if text[end]=='}':depth-=1
        end+=1
    return dict(lineStart=text.count('\n',0,m.start())+1,lineEnd=text.count('\n',0,end)+1,sourceSpanSha256=sha(text[m.start():end].encode()))
def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
    assert git('branch','--show-current').strip()=='feat/phase4-automap'
    for row in git('diff','--name-status',BASE,'--').splitlines():
        status,path=row.split('\t');assert status=='A' and allowed(path),row
    for path in git('ls-files','--others','--exclude-standard').splitlines():assert allowed(path),path
    native=read('test/fixtures/phase4_automap/native.json');cases=read('test/fixtures/phase4_automap/cases.json');evm=read('artifacts/phase4/automap-evm.json')
    assert native['status']=='passed' and native['exactAgreement'] and len(native['profiles'])==3
    assert len({r['outputSha256'] for r in native['profiles']})==1
    for path,digest in native['sourceSha256'].items():assert sha((ROOT/path).read_bytes())==digest,path
    assert sha((ROOT/'test/fixtures/phase4_automap/cases.bin').read_bytes())==cases['casesSha256']
    assert native['caseCount']==cases['caseCount']==22 and native['snapshots']==cases['snapshots']==383
    for i,row in enumerate(cases['cases']):
        assert sha((ROOT/f'test/fixtures/phase4_automap/{i}.bin').read_bytes())==row['inputSha256']
        pairs=b''.join(bytes.fromhex(h['stateSha256'])+bytes.fromhex(h['frameSha256']) for h in row['hashes'])
        assert (ROOT/f'test/fixtures/phase4_automap/{i}.hashes.bin').read_bytes()==pairs
    for patch in native['patches']:assert sha((ROOT/('test/fixtures/phase4_automap/'+patch['name']+'.bin')).read_bytes())==patch['sha256']
    log=(ROOT/'artifacts/local/automap-foundry.log').read_text()
    tests=['test/unit/am_map.t.sol','test/integration/AutomapVideo.t.sol']
    names=sorted(n for path in tests for n in re.findall(r'function\s+(test\w+)\(', (ROOT/path).read_text()))
    passes=sorted(re.findall(r'\[PASS\] (test\w+)\(',log))
    assert names==passes and len(names)==19,(names,passes)
    assert '19 tests passed, 0 failed, 0 skipped' in log and 'runs: 256' in log
    assert evm['pass'] and evm['nativeCases']==22 and evm['statesCompared']==383 and len(evm['rows'])==22
    assert evm['rollback']['status']=='0x0' and evm['rollback']['counterUnchanged'] and evm['rollback']['logs']==0
    for row,golden in zip(evm['rows'],cases['cases']):
        assert row['case']==golden['name'] and row['status']=='0x1' and row['statesCompared']==len(golden['hashes'])
        assert row['frameSha256']==golden['hashes'][-1]['frameSha256'] and row['pixels']==64000
    for path,digest in evm['sourceSha256'].items():assert sha((ROOT/path).read_bytes())==digest,('stale EVM evidence',path)
    artifact=read('out/AutomapProbe.sol/AutomapProbe.json')
    assert artifact['metadata']['compiler']['version']==evm['compiler']['version']
    assert artifact['metadata']['settings']==evm['compiler']['settings']
    runtime=bytes.fromhex(artifact['deployedBytecode']['object'].removeprefix('0x'))
    assert sha(runtime)==evm['runtimeSha256'] and len(runtime)==evm['runtimeBytes']
    compilerBindings={}
    for path,meta in artifact['metadata']['sources'].items():
        contents=(ROOT/path).read_bytes()
        digest=subprocess.check_output([str(ROOT/'.toolchain/bin/cast'),'keccak'],input=('0x'+contents.hex()).encode()).decode().strip()
        assert digest==meta['keccak256'],('stale compiler input',path)
        compilerBindings[path]=sha(contents)
    c=(ROOT/'original/DOOM/linuxdoom-1.10/am_map.c').read_text();sol=(ROOT/'src/doom/am_map.sol').read_text();mapping=[]
    for row in native['functionMapping']:
        original=span(c,row['function']);assert all(row[k]==v for k,v in original.items()),row['function']
        port=span(sol,row['function'],True)
        entry=dict(function=row['function'],original={'path':'original/DOOM/linuxdoom-1.10/am_map.c',**original},solidity={'path':'src/doom/am_map.sol',**port})
        if row['function'] in ['AM_loadPics','AM_unloadPics']:entry['adaptation']='Caller-supplied original marker patches; observable lifecycle request count replaces resource pointer/tag mutation.'
        if row['function']=='AM_initVariables':entry['adaptation']='Selected player index replaces pointer; raw status event exposed through state.'
        if row['function']=='AM_Stop':entry['adaptation']='Original malformed exit-event initializer retained as raw observation; Status Bar adapter remains integration-owned.'
        mapping.append(entry)
    assert len(mapping)==34
    sourcePaths=['src/doom/am_map.sol','src/doom/am_map_types.sol','src/support/AutomapFixture.sol','src/support/AutomapProbe.sol',*tests,'docs/PHASE4-AUTOMAP.md','tools/reference/automap/host.c','tools/reference/automap/compat.h','tools/reference/automap/reference.py','tools/reference/automap/evm.mjs','tools/reference/automap/verify.py','tools/reference/automap/README.md']
    bindings={path:sha((ROOT/path).read_bytes()) for path in sourcePaths}
    sourceMap=dict(schemaVersion=1,goal='4.5',upstreamCommit='a77dfb96cb91780ca334d0d4cfd86957558007e0',functions=mapping,sourceSha256=bindings,definitions={'am_map_types.sol':'am_map.c globals/points/lines; named-field r_defs.h/player_t/mobj_t projections','fixedArithmetic':'Existing src/doom/m_fixed.sol','angles':'Existing Tables.finesine/finecosine; original BAM >>19','markers':'Existing V_Video.V_DrawPatch with original AMMNUM0..9','framebuffer':'Existing VideoState.screens[0] alias and V_MarkRect'},deviations=['Original pointer/cache/status-bar calls represented by memory references, lifecycle counters and raw notifications','Original fixed 320x168 map within unchanged 320x200 framebuffer','Unused triangle_guy glyph is not drawn by original and is not exposed; all drawn glyph coordinates retained','Undefined C arithmetic/pointer cases are outside equivalence; invalid memory domains revert'])
    sourceMapBytes=(json.dumps(sourceMap,indent=2)+'\n').encode()
    verification=dict(schemaVersion=1,goal='4.5',**{'pass':True},baseline=BASE,initialBaseline='6d7630e603efd5f2c596fcc01d91a8521fcc3270',inheritedAdvance='Worktree reflog records external merge main fast-forward at 2026-10-10 14:14:20 +0400; all automap changes were untracked new files',branch='feat/phase4-automap',native={'profiles':3,'cases':22,'snapshots':383,'exactAgreement':True,'nativeManifestSha256':sha((ROOT/'test/fixtures/phase4_automap/native.json').read_bytes()),'fixtureSha256':cases['casesSha256']},foundry={'tests':19,'failed':0,'skipped':0,'fuzzRuns':256,'passedTests':names,'command':"forge test --match-path 'test/{unit/am_map,integration/AutomapVideo}.t.sol' --skip Doom --skip GameplayProbe --skip RendererProbe --skip WadResourcesProbe -vv"},evm={'ordinaryCreate':True,'frames':22,'statesCompared':383,'pixelsReturned':22*64000,'rollbackVerified':True,'receiptEvidenceSha256':sha((ROOT/'artifacts/phase4/automap-evm.json').read_bytes()),'gasRange':[min(r['gasUsed'] for r in evm['rows']),max(r['gasUsed'] for r in evm['rows'])]},ownership={'allPreexistingTrackedFilesUnchanged':True,'baselineTreeSha256':sha(git('ls-tree','-r',BASE).encode()),'productionAdaptersModified':False,'mainModified':False,'fullInheritedRegression':'deferred to final Phase 4 by user instruction'},compilerInputSha256=compilerBindings,sourceSha256=bindings,sourceMapSha256=sha(sourceMapBytes))
    outputs={'artifacts/phase4/automap-source-map.json':sourceMapBytes,'artifacts/phase4/automap-verification.json':(json.dumps(verification,indent=2)+'\n').encode()}
    for path,data in outputs.items():
        if args.check:assert (ROOT/path).read_bytes()==data,path
        else:(ROOT/path).write_bytes(data)
    print(json.dumps(dict(pass_=True,originalFunctions=34,tests=19,nativeSnapshots=383,ordinaryFrames=22,preexistingFilesUnchanged=True)))
if __name__=='__main__':main()
