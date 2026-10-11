#!/usr/bin/env python3
"""Bind finite feature evidence to current source and preserved integration boundaries."""
import argparse,datetime,hashlib,json,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];LOCAL=ROOT/'artifacts/local/options';OUT=ROOT/'artifacts/options-level-selection/api-compatibility'
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda p:json.loads(p.read_text())
ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');a=ap.parse_args()
browser=read(LOCAL/'browser-api-final.json');focused=read(LOCAL/'focused.json');native=read(LOCAL/'startup-native/result.json');status=read(LOCAL/'status-resize-native/result.json');assert status['pass_'];menus=read(ROOT/'test/fixtures/options_menu/manifest.json')
assert browser['pass'] and focused['pass_'] and native['pass_']
assert focused['counts']==[34,0,0,34]
node=(LOCAL/'node.log').read_text();assert re.search(r'(?:ℹ |# )pass 72\b',node) and re.search(r'(?:ℹ |# )fail 0\b',node)
assert len(native['cases'])==21 and len(native['builds'])==6
assert len(menus['nativeCheckpoints'])==146 and len(menus['builds'])==3
for profile in menus['builds']:assert not profile['stderr'] and profile['outputs']==menus['nativeCheckpoints']
for f,digest in menus['fixtures'].items():assert sha((ROOT/'test/fixtures/options_menu'/f).read_bytes())==digest
for game in ['freedoom','ultimate','doom2']:
 rows=[x for x in browser['selections'] if x['game']==game]
 assert {x['skill'] for x in rows if x['map']==1}==set(range(5))
 assert {x['map'] for x in rows}==({1,7,32} if game=='doom2' else {1,2,9})
 assert all(x['nativeSpawnAndRNGExact'] and x['originalInventoryRestored'] and x['noIntermission'] and x['leveltime']==1 for x in rows)
 assert len([x for x in browser['rollbacks'] if x['game']==game])==5
 assert browser['installations'][game]['config']['memoryPolicy']==3
assert sum('existing setUIFullscreen API' in x['label'] and x['pass'] for x in browser['checks'])==3
assert len(browser['rollbacks'])==15 and all(x['allStorageUnchanged'] and x['noLogs'] for x in browser['rollbacks'])
assert all(f['allCanvasPixelsExact'] for f in browser['frames'])
assert browser['stoppedOwnedRuntimes']
source={}
for release in ['install','doom2']:
 text=(ROOT/f'web/{release}-pins.mjs').read_text();pins=json.loads(text[text.index('{'):text.rindex('}')+1])
 assert pins['compiler']=='0.8.37' and pins['evmVersion']=='cancun'
 for p,d in pins['sources'].items():assert sha((ROOT/p).read_bytes())==d,('source drift',p);source[p]=d
 for name,pin in pins['artifacts'].items():assert sha((ROOT/'web'/pin['url'].lstrip('/')).read_bytes())==pin['sha256'];source['web/'+pin['url'].lstrip('/')]=pin['sha256']
for path,digest in status['sourceSha256'].items():assert sha((ROOT/path).read_bytes())==digest;source[path]=digest
for path,digest in browser['sourceHashes'].items():assert sha((ROOT/path).read_bytes())==digest;source[path]=digest
# Engine/memory/Frame/install source and accepted prior oracle files remain exact baseline bytes.
protected=['src/evm/DoomGame.sol','src/evm/InputProtocol.sol','src/evm/FrameProtocol.sol','src/evm/ProductionWadResources.sol','src/evm/Doom2WadResources.sol','src/evm/EpisodeStartup.sol','src/evm/Doom2Startup.sol','src/doom/g_game.sol','foundry.toml','execution-budget.json']
protected+=['src/doom/'+n for n in ['r_main.sol','r_draw.sol','r_segs.sol','r_plane.sol','r_things.sol','hu_stuff.sol','st_stuff.sol','z_zone.sol','z_zone_backing.sol','z_zone_virtual.sol','z_zone_types.sol']]
protected+=[str(p.relative_to(ROOT)) for p in (ROOT/'test/fixtures/evm_menu').glob('*')]
protected+=['tools/reference/statusbar/reference.py','tools/reference/statusbar/host.c']
protected+=['web/'+n for n in ['install-engine.mjs','install-storage.mjs','install-resources.mjs','launcher.mjs','menu-app.mjs','menu-input.mjs']]
for p in protected:
 baseline=subprocess.check_output(['git','show','411e604:'+p],cwd=ROOT);assert baseline==(ROOT/p).read_bytes(),('protected file changed',p);source[p]=sha(baseline)
for p,d in menus['sourceHashes'].items():assert sha((ROOT/'original/DOOM/linuxdoom-1.10'/p).read_bytes())==d;source['original/DOOM/linuxdoom-1.10/'+p]=d
paths=[*LOCAL.glob('*.log'),LOCAL/'focused.json',LOCAL/'browser-api-final.json',LOCAL/'startup-native/result.json',LOCAL/'status-resize-native/result.json',LOCAL/'browser.json',LOCAL/'browser-final.json',ROOT/'test/fixtures/options_menu/manifest.json']
paths+=[p for p in (ROOT/'tools/reference/options').glob('*') if p.is_file()]
paths+=[ROOT/'test/unit/OptionsMenu.t.sol',ROOT/'test/unit/m_menu.t.sol']
paths+=[p for p in (ROOT/'test/fixtures/options_menu').glob('*') if p.is_file()]
files={str(p.relative_to(ROOT)):dict(bytes=p.stat().st_size,sha256=sha(p.read_bytes())) for p in paths}
for f in browser['frames']:
 p=ROOT/f['screenshot'];assert sha(p.read_bytes())==f['screenshotSha256'];files[f['screenshot']]=dict(bytes=p.stat().st_size,sha256=f['screenshotSha256'])
production={}
for name in ['Doom','Doom2','ResourceStore']:
 artifact=read(ROOT/f'out/{name}.sol/{name}.json')
 metadata=artifact['metadata'];metadata=json.loads(metadata) if isinstance(metadata,str) else metadata
 settings=metadata['settings'];assert metadata['compiler']['version'].startswith('0.8.37') and settings['viaIR'] and settings['optimizer']=={'enabled':True,'runs':200} and settings['evmVersion']=='cancun'
 production[name]=dict(abiSha256=sha(json.dumps(artifact['abi'],sort_keys=True,separators=(',',':')).encode()),compiler=metadata['compiler'],settings=settings)
record=dict(kind='options-level-selection-feature-certificate',pass_=True,baseline='411e6049f9e2ad496d45264facbb6fdafc3dbfa7',scope='Isolated feature handoff, no main integration or full historical acceptance',
 counts=dict(forgeTests=34,nodeTests=72,originalMenuCheckpoints=146,originalMenuProfiles=3,originalStartupCases=21,originalStartupProfiles=3,productionSelections=len(browser['selections']),rollbackReceipts=15,canvasFrames=len(browser['frames'])),
 productionABICompiler=production,sourceSha256=source,evidence=files,startedUtc='2026-10-11T15:15:28Z',endedUtc=browser['endedUtc'],runtime=browser['runtime'],
 limits=['Functional Options are End Game/Messages/blocks10-11; detail, smaller bordered views, mouse, audio and F11 gamma dispatch are unsupported as documented.',
 'SELECT LEVEL and supported-row omissions are intentional extensions, not original complete-menu pixel-equivalence claims.',
 'Finite original-C startup/one-tic and menu borrowing profiles, not full-process allocation or universal rendering equivalence.',
 'Interactive profile3/provenance, pinned compiler/viaIR/Cancun and existing memory defaults preserved; no relaxed rendering.',
 'No full map replay, FPS, peak MSIZE, historical suite, main integration or main push claim.'])
OUT.mkdir(parents=True,exist_ok=True)
if a.check:
 old=read(OUT/'verification.json');assert old==record,'certificate drift'
else:
 for name,payload in [('browser.json',browser),('focused.json',focused),('native-startup.json',native),('native-status-resize.json',status)]:
  # Native source build manifests are small proof metadata, no IWAD/artwork/world bytes.
  (OUT/name).write_text(json.dumps(payload,indent=2)+'\n')
 (OUT/'verification.json').write_text(json.dumps(record,indent=2)+'\n')
print('PASS feature source/evidence certificate',record['counts'])
