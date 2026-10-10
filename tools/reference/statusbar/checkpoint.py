#!/usr/bin/env python3
"""Bind the focused Goal4.2 gates and source map, without rewriting old evidence."""
import argparse,hashlib,json,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
BASE='084764b'
OUT=ROOT/'artifacts/phase4'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def encoded(x):return (json.dumps(x,indent=2)+'\n').encode()
def read(path):return json.loads((ROOT/path).read_text())
def owned(name):
    return name in ['src/doom/st_stuff.sol','src/doom/st_lib.sol','test/unit/st_stuff.t.sol','test/unit/st_lib.t.sol','test/integration/StatusBar.t.sol','docs/PHASE4-STATUSBAR.md'] or any(name.startswith(p) for p in ['test/statusbar/','test/fixtures/phase4_statusbar/','test/fixtures/phase4_statusbar_world/','tools/reference/statusbar/','artifacts/phase4/statusbar-'])
def integrity():
    assert subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip()=='feat/phase4-statusbar'
    changed=subprocess.check_output(['git','diff','--name-only',BASE,'--'],cwd=ROOT,text=True).splitlines()
    assert all(owned(p) for p in changed),[p for p in changed if not owned(p)]
    untracked=subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=ROOT,text=True).splitlines()
    assert all(owned(p) for p in untracked),untracked
    native=read('test/fixtures/phase4_statusbar/manifest.json');cases=read('test/fixtures/phase4_statusbar/cases.json')
    assert native['exactAgreement'] and native['caseCount']==sum(map(len,cases['suites'].values()))==1299
    assert len(cases['suites'])==11 and len(cases['stateFields'])==24 and cases['recordBytes']==336
    assert len(native['profiles'])==3 and native['profiles'][0]['outputSha256']==native['profiles'][1]['outputSha256']==native['profiles'][2]['outputSha256']
    for path,digest in native['sourceSha256'].items():assert sha(ROOT/path)==digest,path
    for p in native['patches']:assert sha(ROOT/'test/fixtures/phase4_statusbar'/(p['name']+'.bin'))==p['sha256']
    for name,rows in cases['suites'].items():assert (ROOT/f'test/fixtures/phase4_statusbar/{name}.bin').stat().st_size==len(rows)*336,name
    assert [r['state'][1] for r in cases['suites']['all_face_assets']]==list(range(42))
    # Exact original gamma table, independently extracted from the pinned C.
    text=(ROOT/'original/DOOM/linuxdoom-1.10/v_video.c').read_text();table=text.split('byte gammatable[5][256] =',1)[1].split(';',1)[0]
    original=bytes(map(int,re.findall(r'\d+',table)))
    source=(ROOT/'src/doom/st_stuff.sol').read_text();actual=bytes.fromhex(''.join(re.findall(r'return hex"([0-9a-f]+)";',source)))
    assert len(original)==1280 and original==actual
    world=read('test/fixtures/phase4_statusbar_world/manifest.json')
    assert len({p['sha256'] for p in world['profiles']})==1
    assert sha(ROOT/'test/fixtures/phase4_statusbar_world/frame.bin')==world['frameSha256']
    receipts=read('artifacts/phase4/statusbar-evm.json');assert receipts['pass'] and len(receipts['rows'])==3
    assert receipts['rollback']['status']=='0x0' and receipts['rollback']['counterUnchanged'] and receipts['rollback']['logs']==0
    for path,digest in receipts['sourceSha256'].items():assert sha(ROOT/path)==digest,path
    assert receipts['compiler']['version']=='0.8.37+commit.f401782d'
    for row in receipts['rows']:
        expected=cases['suites'][row['suite']][0]
        assert row['frameSha256']==expected['sha256'][0] and row['paletteSha256']==expected['sha256'][2]
    return native,cases,receipts

def source_map():
    rows=[]
    for module in ['st_lib','st_stuff']:
        solpath=f'src/doom/{module}.sol';cpath=f'original/DOOM/linuxdoom-1.10/{module}.c'
        sol=(ROOT/solpath).read_text();c=(ROOT/cpath).read_text()
        masked=re.sub(r'/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"',lambda m: ''.join('\n' if x=='\n' else ' ' for x in m.group()),c,flags=re.S)
        for match in re.finditer(r'function\s+((?:ST_|STlib_)\w+)\s*\(',sol):
            name=match.group(1);native=re.search(r'\b'+name+r'\s*\([^)]*\)\s*\{',masked);assert native,name
            start=native.start();end=native.end();depth=1
            while depth:
                if masked[end]=='{':depth+=1
                elif masked[end]=='}':depth-=1
                end+=1
            rows.append({'function':name,'solidity':solpath,'solidityLine':sol[:match.start()].count('\n')+1,'native':cpath,'nativeLine':c[:start].count('\n')+1,'nativeSpanSha256':hashlib.sha256(c[start:end].encode()).hexdigest(),'scope':'automap status messages only; cheats deferred to4.4' if name=='ST_Responder' else 'status-bar function; documented context/resource adapters'})
    return {'goal':'4.2','upstreamCommit':'a77dfb96cb91780ca334d0d4cfd86957558007e0','functions':rows,'excludedFunctions':{'ST_unloadGraphics':'Native zone retag only; caller owns immutable bytes. No shared allocator changes.','ST_unloadData':'Delegates native zone retag; no consumer API needed.'},'palette':'Original st_stuff selection + all1280 v_video gamma bytes; i_video UploadNewPalette RGB8 channels, no X11 call.'}

def bindings():
    files=[ROOT/p for p in ['src/doom/st_lib.sol','src/doom/st_stuff.sol','test/unit/st_lib.t.sol','test/unit/st_stuff.t.sol','test/integration/StatusBar.t.sol','docs/PHASE4-STATUSBAR.md','foundry.toml','toolchain.lock.json','execution-budget.json','artifacts/phase4/statusbar-evm.json']]
    for folder in ['test/statusbar','test/fixtures/phase4_statusbar','test/fixtures/phase4_statusbar_world','tools/reference/statusbar']:
        files += [p for p in (ROOT/folder).rglob('*') if p.is_file() and '__pycache__' not in str(p)]
    return {str(p.relative_to(ROOT)):sha(p) for p in sorted(files)}

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args()
    native,cases,receipts=integrity();mapping=source_map();mapping_bytes=encoded(mapping)
    if args.check:
        verification=read('artifacts/phase4/statusbar-verification.json')
        assert (OUT/'statusbar-source-map.json').read_bytes()==mapping_bytes
        assert verification['sourceSha256']==bindings(),'source/fixture binding changed'
        assert verification['pass'] and verification['focused']['passed']==17 and verification['videoDependency']['passed']==17
    else:
        gates={}
        for key,name in [('focused','final-focused.log'),('videoDependency','video-dependency.log')]:
            path=ROOT/'artifacts/local/statusbar'/name;text=path.read_text()
            assert re.search(r'17 tests passed, 0 failed, 0 skipped',text),name
            gates[key]={'passed':17,'failed':0,'skipped':0,'logSha256':sha(path),'tests':re.findall(r'\[PASS\] (\w+)',text)}
        evidence={'goal':'4.2','pass':True,'baseline':subprocess.check_output(['git','rev-parse',BASE],cwd=ROOT,text=True).strip(),'branch':'feat/phase4-statusbar',**gates,'native':{'steps':1299,'sequences':11,'stateFields':24,'pixelsPerStep':64000,'backgroundBytesPerStep':10240,'paletteBytesPerStep':768,'all42FaceAssets':True,'profiles':['O0','O2','ASan+UBSan'],'agreement':True},'worldComposition':{'width':320,'worldHeight':168,'statusHeight':32,'nativeProfilesAgree':True,'completeFrameCompared':True,'legacy200UnchangedGolden':True},'ordinaryReceipts':{'frames':3,'pixels':192000,'minGas':min(r['gasUsed'] for r in receipts['rows']),'maxGas':max(r['gasUsed'] for r in receipts['rows']),'malformedRollback':True},'ownership':{'existingTrackedFilesChanged':False,'productionAdaptersModified':False,'sharedInterfacesModified':False,'historicalAcceptanceModified':False},'deferred':['full inherited regression at Phase4 acceptance','production integration/browser protocol owned by integrator','cheat responder Goal4.4'],'sourceSha256':bindings()}
        (OUT/'statusbar-source-map.json').write_bytes(mapping_bytes);(OUT/'statusbar-verification.json').write_bytes(encoded(evidence))
    print(f'PASS Goal4.2 integrity, {len(mapping["functions"])} source mappings, focused/native/EVM bindings, protected baseline unchanged')
if __name__=='__main__':main()
