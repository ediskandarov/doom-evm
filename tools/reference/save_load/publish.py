#!/usr/bin/env python3
"""Publish compact Save/Load evidence without commercial assets or runtime journals."""
import argparse, hashlib, json, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
ap=argparse.ArgumentParser();ap.add_argument('--browser',default='artifacts/local/save-load/browser-final.json');args=ap.parse_args()
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
read=lambda p:json.loads((ROOT/p).read_text())
write=lambda p,d:(ROOT/p).write_text(json.dumps(d,indent=2)+'\n')
browser=read(args.browser);assert browser['pass'] and all(f['allCanvasPixelsExact'] for f in browser['frames'])
for p,h in browser['sourceHashes'].items():assert sha(ROOT/p)==h,p
browser['rawReportSha256']=sha(ROOT/args.browser);browser['rawReportPath']=args.browser
browser['installations']={game:{'address':v['config']['address'],'driver':v['config']['driver'],
    'resourceIdentity':v['config']['resourceIdentity'],'resourceCount':v['resourceCount'],
    'receiptCount':len(v['receipts']),'journalSha256':v['journalSha256'],
    'defaultPolicy':v['defaultPolicy'],'initializationAPI':v['initializationAPI']}
    for game,v in browser['installations'].items()}
for row in browser['saveCosts']:row['gas']=int(row['gasUsed'],16)
browser['visualReview']={'screenshots':['artifacts/local/save-load/browser-final-8.png',
    'artifacts/local/save-load/browser-final-132.png'],'result':'Freedoom six empty Save rows and DOOM II occupied rows/text-entry cursor visually inspected.'}
write('artifacts/save-load/browser.json',browser)
release={'kind':'final production source/ABI/resource/toolchain binding','productionCommit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
         'compiler':'0.8.37','optimizerRuns':200,'viaIR':True,'hardfork':'cancun','gasLimit':10000000000,'memoryLimit':1073741824,
         'browserMemoryProfile':3,'solidityDefaultProfile':2,'artifacts':{},'sourceHashes':{},'toolchain':{}}
for name in ['Doom','Doom2','SaveReplayProbe','DoomSaveMemoryProbe']:
    p=f'out/{name}.sol/{name}.json';a=read(p);m=a['metadata'];assert m['settings']['viaIR'] and m['settings']['optimizer']['runs']==200
    release['artifacts'][name]={'path':p,'sha256':sha(ROOT/p),'runtimeBytes':(len(a['deployedBytecode']['object'])-2)//2,
       'abiSha256':hashlib.sha256(json.dumps(a['abi'],sort_keys=True,separators=(',',':')).encode()).hexdigest()}
    for source in m['sources']:release['sourceHashes'][source]=sha(ROOT/source)
for command in [['.toolchain/bin/forge','--version'],['.toolchain/bin/solc','--version'],['node','--version'],['clang','--version']]:
    release['toolchain'][command[0]]=subprocess.check_output(command,cwd=ROOT,text=True).strip()
for p in ['web/install-assets/Doom.json','web/install-pins.mjs','web/doom2-assets/Doom.json','web/doom2-pins.mjs']:
    release['artifacts'][p]={'sha256':sha(ROOT/p)}
release['resourceIdentities']={g:v['resourceIdentity'] for g,v in browser['installations'].items()}
release['verificationToolHashes']={str(p.relative_to(ROOT)):sha(p) for p in sorted((ROOT/'tools/reference/save_load').iterdir()) if p.is_file()}
release['originalCommit']=subprocess.check_output(['git','-C','original/DOOM/linuxdoom-1.10','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
assert release['originalCommit']=='a77dfb96cb91780ca334d0d4cfd86957558007e0'
preserved=['original','foundry.toml','src/evm/EpisodeRuntime.sol','src/evm/DoomGame.sol',
           'src/evm/InputProtocol.sol','src/doom/p_game_state.sol','src/doom/z_zone.sol',
           'src/doom/z_zone_backing.sol','src/doom/z_zone_virtual.sol','test/unit/m_menu.t.sol',
           'test/unit/OptionsMenu.t.sol','test/doom2/Menu.t.sol']
assert not subprocess.check_output(['git','diff','ff826659ceff0b3a5637e70109b62eb75a83d611','--name-only','--',*preserved],cwd=ROOT,text=True).strip()
release['preservedBaselinePaths']=preserved
write('artifacts/save-load/release.json',release)
attempts={'kind':'retained failures and corrections; never relabel failed evidence as passed','attempts':[]}
for label,p,result in [
 ('native result parser','artifacts/local/save-load/native/O0/save-run.log','Native process output lacked a separating newline; corrected result parser.'),
 ('unmodified LP64 archive alignment','artifacts/local/save-load/native-v2/sanitize/save-run.log','Original four-byte archive alignment fails LP64 UBSan. Declared align8 uintptr_t adaptation, original repository untouched.'),
 ('native menu extraction prototype','artifacts/local/save-load/menu-native/O0/build.log','Generated extraction lacked M_DoSave forward declaration; corrected harness prototype.'),
 ('browser sandbox','artifacts/local/save-load/browser.json','Local socket access denied in sandbox; reran using approved isolated runtime.'),
 ('incorrect production F2/F3 symbols','artifacts/local/save-load/browser-real.json','Real Chrome found F2 opening Load. Fixed numeric symbols to pinned KEY_F2=188 and KEY_F3=189; added source/key packet regression and rebuilt both production releases.'),
 ('pre-game memory observation','artifacts/local/save-load/memory-real/report.json','Harness queried gameplay-only views before gameStarted; changed title observation to menuStatus. Production unchanged.')]:
    assert (ROOT/p).is_file(),p
    attempts['attempts'].append({'label':label,'retainedPath':p,'sha256':sha(ROOT/p),'resolution':result})
attempts['interruptedWork']=[{'command':'.toolchain/bin/forge test --match-path test/unit/p_saveg.t.sol',
    'result':'Default root discovery began compiling123 files; interrupted before tests and used the isolated focused import root. No full historical acceptance run.'}]
write('artifacts/save-load/attempts.json',attempts)
reports=['architecture-cost','native-archive','native-continuation','evm-continuation','production-memory','focused','browser','release','attempts','schema']
index={'kind':__doc__,'reports':{n:{'path':f'artifacts/save-load/{n}.json','sha256':sha(ROOT/f'artifacts/save-load/{n}.json')} for n in reports}}
write('artifacts/save-load/evidence.json',index)
print('PASS published',len(reports),'bound reports,',len(browser['frames']),'Canvas checkpoints')
