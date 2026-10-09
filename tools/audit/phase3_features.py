#!/usr/bin/env python3
"""Inventory code and summarized retained proof evidence; never reads session logs.

Run after an explicit integration evidence checkpoint. --check compares generated
content with the checked-in JSON/Markdown without modifying them. Local reports
are required and hash-bound; no compiler, network, engine or fixture writes occur.
"""
from pathlib import Path
import re,json,hashlib,datetime,collections
ROOT=Path(__file__).resolve().parents[2]
import os,argparse
os.chdir(ROOT)
ORIG=Path('original/DOOM/linuxdoom-1.10')
def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def scrub(t):
 return re.sub(r'/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'',lambda m:re.sub(r'[^\n]',' ',m[0]),t,flags=re.S)
def spans(p,sol=False):
 raw=Path(p).read_text();t=scrub(raw)
 pat=r'\bfunction\s+(\w+)\s*\([^;{}]*\)[^;{}]*\{' if sol else r'(?m)^(?:[A-Za-z_]\w*[\t *]+)*([A-Za-z_]\w*)\s*\([^;{}]*\)\s*\{'
 out={}
 for m in re.finditer(pat,t):
  a=m.start();b=m.end()-1;level=1;k=b+1
  while level and k<len(t):
   if t[k]=='{':level+=1
   elif t[k]=='}':level-=1
   k+=1
  key=m[1] if m[1] not in out else m[1]+'#'+str(sum(k.split('#')[0]==m[1] for k in out)+1)
  out[key]={'path':str(p),'startLine':raw.count('\n',0,a)+1,'endLine':raw.count('\n',0,k)+1,'bodySha256':hashlib.sha256(raw[a:k].encode()).hexdigest()}
 return out

ev={
 'collision':{'scope':'Isolated algorithms; recorded higher-module collision damage/state/pickup/cross/fog callbacks','reference':'test/fixtures/phase3_map/validation.json','documentation':'docs/PHASE3-COLLISION.md','native':{'geometryCases':4310,'scenarios':71},'evm':{'tests':3,'result':'pass'}},
 'combat':{'scope':'Isolated real PSprite actions and interaction algorithms; aim/line/missile/damage/noise/state boundary doubles','reference':'test/fixtures/phase3_combat/validation.json','documentation':'docs/PHASE3-COMBAT.md','native':{'interactionCases':6025,'weaponScenarios':72,'weaponTics':11520},'evm':{'tests':24,'result':'pass'}},
 'ai':{'scope':'Entire original enemy unit; ordered visibility/movement/spawn/damage/state doubles','reference':'test/fixtures/phase3_enemy/validation.json','documentation':'docs/PHASE3-AI.md','native':{'cases':1137,'functions':64},'evm':{'tests':64,'result':'pass'}},
 'lifecycle':{'scope':'Original player/mobj/game reset and exit algorithms; recorded neighboring actions/collision/weapon callbacks; actual spatial links','reference':'test/fixtures/phase3_lifecycle/validation.json','documentation':'docs/PHASE3-LIFECYCLE.md','native':{'cases':784,'functions':24},'evm':{'tests':24,'result':'pass; corrected positive respawn test separately rerun'}},
 'tick':{'scope':'Original scheduling under observing callbacks; deallocation records retain static node bytes','reference':'artifacts/phase3/tick-checkpoint.json','documentation':'docs/PHASE3-TICK.md','native':{'snapshots':8,'functions':6},'evm':{'tests':1,'result':'pass'}},
 'world':{'scope':'Five complete original mover/light units; synthetic four-sector chain and obstruction callback; zero allocator execution','reference':'test/fixtures/phase3_world/validation.json','documentation':'docs/PHASE3-WORLD-ACTIONS.md','native':{'scenarios':359,'snapshots':79021,'planeCases':2160,'doorPlatOverlapCases':4,'doorCeilingOverlapCases':4},'evm':{'tests':28,'result':'pass'}},
 'specials':{'scope':'Helpers/switches/animation/player sector/teleport boundary doubles; dispatch into real five native world units, synthetic geometry and zero allocator','reference':'test/fixtures/phase3_specials/validation.json','documentation':'docs/PHASE3-WORLD-SPECIALS.md','native':{'unitCases':416,'dispatchScenarios':1007,'pairedSnapshots':4048,'crossSpecialNumbers':72,'useSpecialNumbers':63,'shootSpecialNumbers':3},'evm':{'tests':25,'result':'pass'}},
 'input':{'scope':'Single-player keyboard G_BuildTiccmd; zero base cmd, ticdup1, no mouse/joystick/chat/save/pause','reference':'artifacts/phase3/input-checkpoint.json','documentation':'INPUT_PROTOCOL.md','native':{'cases':41007},'evm':{'tests':14,'result':'pass'},'browserUnitTests':5},
 'foundation':{'scope':'Complete state/mobj/weapon/action tables and independent random stream operations; no integrated action coverage implied','reference':'artifacts/phase3/foundation-checkpoint.json','native':{'states':967,'mobjDefinitions':137,'weapons':9,'actions':74},'evm':{'result':'isolated checkpoint pass'}},
 'bbox':{'scope':'Original bbox operations; every prefix of point streams','reference':'test/fixtures/phase3_bbox/validation.json','native':{'streams':521,'points':8299},'evm':{'tests':1,'result':'pass'}},
 'storage':{'scope':'Synthetic nonempty actor/thinker/door/map/resource/scratch/framebuffer/cache roundtrip; not full E1M1 or production transaction','reference':'artifacts/phase3/storage-checkpoint.json','evm':{'tests':1,'result':'pass','aggregateTestGas':9959477}},
 'native-world':{'scope':'Real original E1M1 P_SetupLevel/gameplay/renderer/zone allocator; direct ticcmd host profile; native reference only','reference':'artifacts/phase3/native-reference-checkpoint.json','documentation':'tools/reference/gameplay/README.md','manifest':'test/fixtures/gameplay/manifest.json','native':{'scenarios':8,'tics':2205,'frames':24,'frameBytes':64000,'profiles':['O0','O2','O2 ASan/UBSan','O2 ASan/UBSan allocation 0xa5']},'evm':{'result':'pending'}}
}

profiles=[
 ('single_player','draft_supported','DoomGame initializes retail E1M1, skill2, one player; nomonsters optional. Actual engine acceptance pending.',['src/evm/DoomGame.sol','src/doom/p_setup.sol']),
 ('keyboard','module_verified','Keyboard held bits and weapon requests; authentic sequence/driver/WebSocket/receipt/Canvas integration pending.',['INPUT_PROTOCOL.md','artifacts/phase3/input-checkpoint.json']),
 ('mouse_joystick_chat','unsupported','G_BuildTiccmd profile holds these device inputs zero; no device, chat or double-click frontend.',['src/doom/g_game.sol']),
 ('cli','unsupported_host_layer','No original D_DoomMain CLI, -avg/-timer flags or arbitrary startup parsing. Timer update logic is separately implemented/tested; nomonsters is an adapter argument.',['src/doom/p_spec.sol','src/evm/DoomGame.sol']),
 ('multiplayer_deathmatch','unsupported_adapter','Original branches and four player slots retained/tested in modules; no network G_Ticker/checksum/consistency path and P_SetupLevel rejects deathmatch startup.',['src/doom/p_setup.sol','src/doom/g_game.sol']),
 ('demo_record_playback','unsupported','No G_Read/WriteDemoTiccmd or original demo gameflow implementation. Ticker demo exception fields do not imply demo support.',['original/DOOM/linuxdoom-1.10/g_game.c','src/doom/p_tick.sol']),
 ('audio_music','presentation_omitted','Sound/music device calls omitted; P_NoiseAlert and sound-choice gameplay P_Random draws retained. Cosmetic M_Random profile is distinct.',['docs/PHASE3-AI.md','tools/reference/gameplay/README.md']),
 ('menu_hud_automap','presentation_omitted','No original menu/status bar/HUD/automap; ticker menu guard retained, world view and PSprites rendered.',['src/doom/p_tick.sol','src/evm/DoomGame.sol']),
 ('save_load','unsupported','EVM state persistence is a different mechanism; original p_saveg serialization and G_Load/SaveGame not ported.',['artifacts/phase3/storage-checkpoint.json','original/DOOM/linuxdoom-1.10/p_saveg.c']),
 ('intermission_finale_level_progression','unsupported','Exit/secret action flags implemented; G_DoCompleted/G_WorldDone/G_DoWorldDone/G_InitNew flow absent. No automatic next map, intermission or finale.',['src/doom/g_game.sol','original/DOOM/linuxdoom-1.10/g_game.c']),
 ('death_respawn_flow','partial','DeathThink and G_PlayerReborn/P_SpawnPlayer implemented; complete G_DoReborn/check-spot/level restart dispatch absent.',['src/doom/p_user.sol','src/doom/p_mobj.sol','src/doom/g_game.sol']),
 ('other_maps_modes_skills','module_only','Skill/mode/map-dependent algorithms exercised in isolated contexts. Adapter initializes fixed medium retail E1M1; arbitrary WAD/map/episode acceptance absent.',['src/evm/DoomGame.sol','docs/PHASE3-AI.md']),
 ('sliding_doors','disabled_upstream','Original #if0 code intentionally excluded, not an active missing gameplay feature.',['original/DOOM/linuxdoom-1.10/p_doors.c'])
]

domains=[
 {'id':'numeric-profile','policy':'Pinned implementation equivalence, not universal ISO C','detail':'32-bit wrapping, signed narrowing, arithmetic shifts and ordered RNG use explicit implementations. Negative signed shifts remain original undefined ISO C behavior, measured under pinned native profiles.','references':['docs/PHASE3-COMBAT.md','test/fixtures/phase3_lifecycle/undefined-audit.json','tools/reference/reference.py']},
 {'id':'allocation-profile','policy':'Explicit deterministic extension in isolated zero-filled world tests','detail':'Original timed-close door topheight/topwait and stair type/crush are uninitialized. Snapshot masking does not prove gameplay equivalence when consumed under arbitrary heap fills; whole-world 0xa5 evidence covers only selected scenarios.','references':['test/fixtures/phase3_world/original-domains.json','docs/PHASE3-WORLD-ACTIONS.md','tools/reference/gameplay/README.md']},
 {'id':'zone-identity','policy':'Stable IDs and tombstones replace pointers/free/reuse','detail':'P_Heap grows memory buffers; thinker/sector/block order preserved. Full native oracle retains original z_zone with LP64 alignment8 and sector pointer-array sizeof fixes. Full EVM world persistence/allocator-observable behavior remains pending.','references':['src/doom/p_heap.sol','src/doom/p_tick.sol','tools/reference/gameplay/README.md']},
 {'id':'mover-casts','policy':'Measured pinned LP64 integer overlaps only','detail':'Manual doors preserve byte48 overlap with plat.count/ceiling.speed. Floor texture/padding representation not proven; fire-flicker reinterpretation is out-of-bounds. Other unsupported casts reject InvalidDoorThinker.','references':['test/fixtures/phase3_world/mover-casts.json','docs/PHASE3-WORLD-ACTIONS.md']},
 {'id':'undefined-generic-donut','policy':'Reject undefined initialized-payload domain','detail':'EV_DoFloor(donutRaise) rejects where original sector pointer was never initialized. Actual EV_DoDonut creates valid donutRaise thinkers and is compared.','references':['test/fixtures/phase3_world/undefined-floor.json','src/doom/p_floor.sol','src/doom/p_spec.sol']},
 {'id':'geometry-and-capacity','policy':'Retain valid original control flow; explicit failures outside supported domain','detail':'Reject abs(INT_MIN), >8 crossed specials, >128 intercepts, >64 scrollers, malformed BLOCKMAP/BSP/REJECT and null donut topology. P_PathTraverse original64-step bound retained. Next-highest floor original first20 eligible values is a defined break, not a rejected overflow.','references':['docs/PHASE3-COLLISION.md','docs/PHASE3-WORLD-SPECIALS.md']},
 {'id':'original-fatal-limits','policy':'Original I_Error becomes revert; original nonfatal behavior retained','detail':'Exhausted16 buttons, full/missing30 platform registry and unknown pickups become explicit errors. Full30 ceiling registry originally silently fails registration and remains so. Valid animation/resource lookup prerequisites enforced.','references':['src/doom/p_switch.sol','src/doom/p_plats.sol','src/doom/p_ceilng.sol','src/doom/p_inter.sol','src/doom/p_spec.sol']},
 {'id':'invalid-ai-indices','policy':'Reject original undefined/caller-invalid states','detail':'Reject invalid movement direction, no enabled player during player search, >32/missing brain targets, zero cube speed/tics or target mass, invalid actor/state/weapon/ammo indices; native proof excludes undefined cases except explicit diagnostic probes.','references':['docs/PHASE3-AI.md','docs/PHASE3-COMBAT.md','docs/PHASE3-LIFECYCLE.md']},
 {'id':'production-resources','policy':'Finite EVM gas/memory still requires real-world measurements','detail':'Pool doubling avoids per-spawn quadratic copies; aggregate module test gas is not per-tic/frame production cost. Pool uint32 capacity exhaustion and malformed resources fail explicitly. No actual production full-level performance acceptance yet.','references':['src/doom/p_heap.sol','artifacts/phase3/storage-checkpoint.json']}
]

# Historical component counts describe their own checkpoint, not a final rerun.
ev.pop('native-world')
extras={
 'zone':('test/fixtures/phase3_zone_allocator/validation.json','docs/PHASE3-ZONE.md','Eight original allocation/list algorithms; small heaps/commands, declared backing profile; 1,624 native snapshots and five fatal domains, two Solidity tests.'),
 'zone-lifecycle':('test/fixtures/phase3_zone_lifecycle/validation.json','tools/reference/phase3_zone_lifecycle/README.md','Native-only allocation/layout/cache observations and knownness; outputs never supplied as runtime allocation inputs.'),
 'backing':('artifacts/phase3/renderer-backing-checkpoint.json','docs/PHASE3-BACKING-INTEGRATION.md','111 renderer/cache/backing component tests; native 80 backing cases, 10,240 masks and 18 column draws. Historical full-setup proof separate.'),
 'zone-heap':('artifacts/phase3/zone-heap-checkpoint.json','docs/PHASE3-ZONE.md','Synthetic typed physical allocation/lazy-free/storage proof; not arbitrary native actor/mover payload byte reconstruction.'),
 'atomic-setup':('tools/reference/phase3_zone_setup/final-validation.json','docs/PHASE3-ZONE-SETUP.md','Four tests: actual single-call resource preparation + level/player startup; all normalized original setup headers/owners/counts and nine typed map allocation slots. No full-level gameplay branch claim.'),
 'repeat-production':('tools/reference/gameplay/production-release-reproducibility-evidence.json','tools/reference/gameplay/PRODUCTION-MEMORY.md','Two independent ordinary CREATE contracts; complete129 keyboard tics, all130x14 fields, identical commands/sequences/cadence/seven totalFrames/transactiongas/thirteen errors and storage rollback.'),
 'production':('tools/reference/gameplay/production-release-evidence.json','docs/PHASE3-GAMEPLAY-TRANSPORT.md','Actual ordinary public Doom keyboard transactions; 129 tics, fourteen exported fields, six complete live Frames, static pre-start Frame and thirteen whole-storage rollback checks.'),
 'browser-input':('tools/transport/evidence/gameplay-atomic-input.json','docs/PHASE3-GAMEPLAY-TRANSPORT.md','Isolated Node input/config tests; browser execution is independently recorded below.'),
 'whole-kernel':('artifacts/local/gameplay-kernel-final.json','tools/reference/gameplay/README.md','Ordinary EVM GameplayProbe: startup + direct ticcmd logical-world streams, selected live frames and final stored logical world. Test-only arena setup; not public keyboard ABI or branch-complete DOOM.'),
 'browser':('artifacts/local/phase3-gameplay-browser-release.json','docs/PHASE3-GAMEPLAY-TRANSPORT.md','Actual Chrome Start/Resume for five commands and controlled sixth receipt fallback; six original native Frames and every Canvas pixel. Short fire command while raising is not independent shooting coverage.'),
 'memory-all-render':('artifacts/local/gameplay-production-release-memory.json','tools/reference/gameplay/PRODUCTION-MEMORY.md','Separately deployed source-mapped MSIZE clone, six-tic all-render stream; storage/exported fields/Frames agree with ordinary production and unpatched clone; This is its complete six-tic all-render native stream, separate from the 129-tic public cadence proof.'),
 'memory-cadence':('artifacts/local/gameplay-production-release-memory-cadence.json','tools/reference/gameplay/PRODUCTION-MEMORY.md','Separately deployed clone, six tics with five no-render steps; actual engine-boundary high-water, excludes later observer encoding and separate call frames; not an exact untouched-production peak.')
}
reports={}
for key,(path,doc,scope) in extras.items():
 reports[key]=json.loads(Path(path).read_text())
 ev[key]={'reference':path,'documentation':doc,'scope':scope}
for key,item in ev.items():
 item['referenceSha256']=digest(item['reference'])
 item['universalBranchCoverage']=False
 item['historicalCheckpoint']=key not in ('production','repeat-production','whole-kernel','browser','atomic-setup','memory-all-render','memory-cadence')
 item['localOnlyReport']=item['reference'].startswith('artifacts/local/')
 # A later tooling edit must not silently inherit a historical runner identity.
 data=reports.get(key,json.loads(Path(item['reference']).read_text()))
 hashes=data.get('sourceHashesAtRun',data.get('sourceHashes',data.get('sourceSha256',data.get('files',data.get('sources',{})))))
 if isinstance(hashes,dict):
  declared={p:h for p,h in hashes.items() if isinstance(h,str) and re.fullmatch(r'[0-9a-f]{64}',h)}
  bindings={p:h for p,h in declared.items() if Path(p).is_file()}
  item['currentSourceBindings']={'checkedFiles':len(bindings),'mismatches':[p for p,h in bindings.items() if digest(p)!=h],'missingFiles':[p for p,h in hashes.items() if isinstance(h,str) and len(h)==64 and not Path(p).is_file()]}
  item['sourceHashesAtRun']=declared
 command=data.get('executedCommand',data.get('command',data.get('commands')))
 if command:item['executedCommand']=command

def report_bindings(data):
 """Verify explicit retained report identities, not source-at-run revisions."""
 found={}
 def walk(value):
  if isinstance(value,dict):
   if isinstance(value.get('path'),str) and isinstance(value.get('sha256'),str):
    found[value['path']]=value['sha256']
   for name in ('rawReport','resourcesReport','sourceReport'):
    if isinstance(value.get(name),str) and isinstance(value.get(name+'Sha256'),str):
     found[value[name]]=value[name+'Sha256']
   for child in value.values():walk(child)
  elif isinstance(value,list):
   for child in value:walk(child)
 walk(data)
 return [{'path':p,'sha256':h,'status':'missing' if not Path(p).is_file() else 'match' if digest(p)==h else 'mismatch'} for p,h in sorted(found.items())]
for key,item in ev.items():
 item['retainedReportBindings']=report_bindings(reports.get(key,json.loads(Path(item['reference']).read_text())))
# Bind the compact memory-method proof as well as its two ignored detailed reports.
memory_proof='tools/reference/gameplay/production-release-memory-evidence.json'
for key in ('memory-all-render','memory-cadence'):
 ev[key]['methodEvidence']={'path':memory_proof,'sha256':digest(memory_proof),'retainedReportBindings':report_bindings(json.loads(Path(memory_proof).read_text()))}

parent_commands={
 'whole-kernel':'node tools/reference/gameplay/compare.mjs --skip-build --output-prefix artifacts/local/gameplay-kernel-final',
 'browser':'node tools/transport/gameplay-browser-check.mjs --config artifacts/local/gameplay-production-release.config.json --palette artifacts/local/gameplay-production-release.palette.json --native artifacts/local/gameplay-browser-native-final --output-prefix artifacts/local/phase3-gameplay-browser-release',
 'memory-all-render':'node tools/reference/gameplay/production-memory.mjs --resources-report artifacts/local/gameplay-production-release.json --rpc http://127.0.0.1:18579 --native artifacts/local/gameplay-browser-native-final --output-prefix artifacts/local/gameplay-production-release-memory',
 'memory-cadence':'node tools/reference/gameplay/production-memory.mjs --resources-report artifacts/local/gameplay-production-release.json --rpc http://127.0.0.1:18579 --native artifacts/local/gameplay-production-native-final --limit 6 --output-prefix artifacts/local/gameplay-production-release-memory-cadence'
}
for key,command in parent_commands.items():ev[key].update(executedCommand=command,commandProvenance='Parent exact completed-execution record; command not retained in local report')
ev['memory-all-render']['cloneBuild']={'session':'44843','executedCommand':'.toolchain/bin/forge build artifacts/local/production-memory/DoomMemoryProbe.sol','commandProvenance':'Parent execution record','limitation':'Current clone compiles in46.64s. Historical import failure remains separately documented. Current receipt-timeout failure and sequential resolution are in the method proof.'}
repeat=reports['repeat-production'];ev['repeat-production'].update(result='pass' if repeat['pass'] else 'fail',session='47208',coverage=repeat['coverage'],executionBudget=repeat['executionBudget'],reports=repeat['reports'],toolOnlyDifference=repeat['toolOnlyDifference'])
prod=reports['production']; cov=prod['coverage']
ev['production'].update(result='pass' if prod['pass'] else 'fail',session='38271',coverage={k:cov[k] for k in ['tics','noRenderTics','nativeLiveFrames','observedRows','fieldsPerRow','exactFieldComparisons','exactLivePixelComparisons','wholeStorageRollback']},rejectionChecks=len(cov['rejections']),actualProductionGas=prod['actualProductionGas'],runtime=prod['runtime'],compiler=prod['compiler'],executionBudget=prod['executionBudget'])
ev['production']['rawReport']={'path':prod['rawReport'],'sha256':prod['rawReportSha256']}
k=reports['whole-kernel']; cases=k['cases']
ev['whole-kernel'].update(result='pass' if k['pass'] else 'fail',session='60930',coverage={'scenarios':len(cases),'tics':sum(c['tics'] for c in cases),'frames':sum(len(c['frames']) for c in cases),'exactFinalStoredStates':sum(c['finalStoredState']['exact'] for c in cases),'completeNativeScenarioSet':k['completeNativeScenarioSet']},initialization=k['initialization'],executionBudget=k['executionBudget'],compiler=k['compiler'])
ev['whole-kernel']['scenarios']=[{'name':c['name'],'tics':c['tics'],'frameTics':[f['tic'] for f in c['frames']],'finalStoredState':c['finalStoredState'],'stateStreamSha256':c['stateStreamSha256']} for c in cases]
b=reports['browser']; ev['browser'].update(result='pass' if b['pass'] else 'fail',session='24522',coverage={'frames':len(b['frames']),'nativePixelsExact':all(f['all64000NativePixelsExact'] for f in b['frames']),'canvasPixelsExact':all(f['allCanvasPixelsExact'] for f in b['frames']),'nativeFieldsExact':all(f['nativeFieldsExact'] for f in b['frames']),'fallbackVerified':b['fallbackVerified'],'duplicates':b['duplicates'],'blurStopsBeforeNextCommand':b['blurStopsBeforeNextCommand']},runtimeSha256=b['runtimeSha256'],browser=b['browser'])
for key,session in [('memory-all-render','81374'),('memory-cadence','81374')]:
 data=reports[key]; limits=collections.defaultdict(list)
 for row in data['boundaries']:limits[row['method']].append(row['highWaterBytes'])
 ev[key].update(result='pass' if data['pass'] else 'fail',session=session,coverage={'tics':data['executedTics'],'completeNativeStream':data['completeNativeStream'],'comparedCalls':len(data['comparisons']),'storageRootsEqual':all(r['allStorageRootsEqual'] for r in data['comparisons']),'exportedStateEqual':all(r['allExportedStateEqual'] for r in data['comparisons']),'patchedUnpatchedCloneGasEqual':all(r['cloneGasEqual'] for r in data['comparisons'])},highWaterBytes={method:{'min':min(vals),'max':max(vals)} for method,vals in limits.items()},actualUntouchedProductionHighWaterBytes=None,executionBudget=data['executionBudget'],source=data['source'],instrumentation=data['instrumentation'])
ev['atomic-setup'].update(result='pass' if reports['atomic-setup']['testsFailed']==0 else 'fail',coverage={'testsPassed':reports['atomic-setup']['testsPassed'],'testsFailed':reports['atomic-setup']['testsFailed']},session=reports['atomic-setup'].get('session'))

module_group={**dict.fromkeys(['p_map','p_maputl','p_sight'],'collision'),**dict.fromkeys(['p_pspr','p_inter'],'combat'),'p_enemy':'ai',**dict.fromkeys(['p_user','p_mobj'],'lifecycle'),'p_tick':'tick',**dict.fromkeys(['p_doors','p_floor','p_ceilng','p_plats','p_lights'],'world'),**dict.fromkeys(['p_spec','p_switch','p_telept'],'specials'),'p_setup':'atomic-setup','m_random':'foundation','m_bbox':'bbox','z_zone':'zone',**dict.fromkeys(['r_data','r_draw','r_things','r_segs','r_plane'],'backing')}
soldefs={str(p):spans(p,True) for p in sorted(Path('src').rglob('*.sol'))}
def target(path,name):return soldefs[str(path)][name]
event_paths=sorted(Path('test/fixtures/gameplay').glob('*/events.json'))+[Path('test/fixtures/gameplay_projectile/events.json')]
events={('projectile-arena' if p.parent.name=='gameplay_projectile' else p.parent.name):json.loads(p.read_text()) for p in event_paths}
event_proofs=[{'path':str(p),'sha256':digest(p)} for p in event_paths]
records=[]; modules=[];disabled={'P_InitSlidingDoorFrames','P_FindSlidingDoorType','T_SlidingDoor','EV_SlidingDoor'}
# Explicit delegations preserve semantic ownership, without treating helpers as C ports.
wmap={'W_CacheLumpNum':('src/doom/w_zone_cache.sol','cacheLump'),'W_CacheLumpName':('src/doom/w_zone_cache.sol','cacheLump'),'W_ReadLump':('src/doom/r_data.sol','W_CacheLumpNum'),'W_CheckNumForName':('src/doom/r_data.sol','W_CheckNumForName'),'W_GetNumForName':('src/doom/r_data.sol','W_GetNumForName'),'W_NumLumps':('src/doom/r_data.sol','W_CheckNumForName'),'W_LumpLength':('src/doom/r_data.sol','W_CacheLumpNum'),'strupr':('src/doom/r_data.sol','name8')}
# Some immutable-source operations are methods on the ResourceView adapter.
for name,(path,func) in list(wmap.items()):
 if func not in soldefs[path]:del wmap[name]
renderer_delegations={**dict.fromkeys(['R_InitTextures','R_InitFlats','R_InitSpriteLumps','R_InitColormaps'],('src/doom/r_data.sol','initData')),'R_AddPointToBox':('src/doom/m_bbox.sol','M_AddToBox'),'R_SetViewSize':('src/doom/r_main.sol','R_ExecuteSetViewSize'),'R_Init':('src/evm/DoomGame.sol','initializeNative'),'R_InitSkyMap':('src/evm/DoomGame.sol','render')}

for stem in [p.stem for p in sorted(ORIG.glob('p_*.c'))]+['g_game','m_random','m_bbox','z_zone','w_wad']+[p.stem for p in sorted(ORIG.glob('r_*.c'))]:
 original=ORIG/(stem+'.c');port=Path('src/doom')/(stem+'.sol');src=spans(original);dst=soldefs.get(str(port),{});counts=collections.Counter()
 for name,source in src.items():
  active=name not in disabled and not (stem=='r_draw' and name in ['R_DrawColumn#2','R_DrawSpan#2']); mapped='M_RandomValue' if stem=='m_random' and name=='M_Random' else name
  ref=dst.get(mapped);implementation='named_port' if ref else 'not_ported';group=module_group.get(stem);note=None
  if not active:implementation='disabled_upstream';group=None
  elif stem=='p_setup' and not ref:
   implementation='delegated';ref=target('src/doom/r_data.sol','R_LoadMap');note='Seven original disk loaders delegate to immutable-source R_LoadMap; runtime sector fields separately initialized by P_LoadSectorRuntime. Native allocation chronology is P_Zone_Setup, not incidental decoder allocation.'
  elif stem=='r_main' and name in ('R_InitPointToAngle','R_InitTables'):
   implementation='original_empty_noop';note='Active original body is empty; lookup-generation body is inside #if0, values use frozen Tables. No runtime call is necessary.';group=None
  elif stem=='w_wad' and name in wmap:
   path,func=wmap[name];implementation='adapted';ref=target(path,func);group='backing';note='Immutable authenticated EVM resources replace host file/malloc data loading. W_CacheLumpName lookup composes name resolution with numeric cache bookkeeping; no host file reload/profile implementation.'
  elif stem.startswith('r_') and not ref and name in renderer_delegations:
   path,func=renderer_delegations[name]
   if func in soldefs[path]:implementation='delegated';ref=target(path,func);note='Renderer immutable-resource/context adaptation; does not reproduce host device presentation.'
  if stem=='w_wad' and name in ('W_NumLumps','W_LumpLength'):note='Original scalar accessor replaced with ResourceView.lumps.length or LumpDescriptor.length. Port span anchors consuming lookup/read code, not an independent accessor algorithm.'
  if stem=='w_wad' and name=='strupr':note='Query uppercase conversion delegated to name8, preserving original case policy.'
  if stem=='r_data' and name=='R_PrecacheLevel':note='Optional native precache startup path is disabled in declared host/EVM profile; cache chronology only covers actual selected source calls.'
  if stem=='g_game' and ref:group='input' if name=='G_BuildTiccmd' else 'lifecycle'
  if stem=='z_zone' and not ref:note='Host console/file heap diagnostic omitted; core heap checker/free-memory accounting is present.'
  if name=='P_AllocateThinker':note='Empty original body retained. Typed state capacity/physical allocations are implemented by P_Heap.'
  if stem=='g_game' and name=='G_BuildTiccmd':note='Declared one-player keyboard profile; device/base-command/chat/save/pause branches omitted.'
  ispresent=implementation in ('named_port','delegated','adapted','original_empty_noop')
  integration='linked_kernel_public_profile; individual invocation not asserted' if ispresent else 'unsupported'
  if not active:integration='disabled_upstream'
  if stem=='r_main' and name in ('R_InitPointToAngle','R_InitTables'):integration='frozen_lookup_data_substitution'
  if stem=='g_game' and name in ('G_ExitLevel','G_SecretExitLevel','G_PlayerReborn'):integration='hook_wired_gameflow_incomplete'
  # Full-world proofs establish selected source contexts, not every function/branch.
  engine=['whole-kernel','production','browser'] if ispresent else []
  observations={case:vals[name] for case,vals in events.items() if name in vals}
  item={'module':stem,'function':name,'activeUpstream':active,'source':source,'implementation':implementation,'port':ref,'integration':integration,'verification':{'moduleEvidence':[group] if group and ispresent else [],'selectedWorldEvidence':engine,'individualEvmFunctionEntryCoverage':'not instrumented','nativeEntryObservations':observations or None,'allBranchesVerified':False}}
  if note:item['note']=note
  if not ispresent and active and stem.startswith('r_'):item['note']='No same-name or explicit delegation in this inventory. Presentation borders/backscreen, optional precache or unsupported host modes are explicitly omitted.'
  records.append(item);counts[implementation]+=1
 modules.append({'module':stem,'sourcePath':str(original),'sourceSha256':digest(original),'portPath':str(port) if port.exists() else None,'portSha256':digest(port) if port.exists() else None,'counts':dict(counts)})

# Source-derived monster/boss family inventory. State-table edges identify declared
# actions only: dynamic action calls and full gameplay coverage are not inferred.
info_source=ORIG/'info.c';info_text=info_source.read_text()
state_pattern=r'\{\s*(SPR_\w+)\s*,\s*([^,]+),\s*([^,]+),\s*\{\s*(\w+)\s*\}\s*,\s*(S_\w+)\s*,[^}]+\},?\s*//\s*(S_\w+)'
state_defs={m[6]:{'action':m[4],'next':m[5]} for m in re.finditer(state_pattern,info_text)}
mobj_defs=re.findall(r'\{\s*//\s*(MT_\w+)(.*?)\n\s*\}',info_text,re.S)
assert len(state_defs)==967 and len(mobj_defs)==137, 'Original state/mobj table parser lost definitions'
enemy_operations=set(json.loads(Path('test/fixtures/phase3_enemy/manifest.json').read_text())['operations'])
actor_families=[]
for actor,body in mobj_defs:
 if 'MF_COUNTKILL' not in body and actor not in ('MT_SKULL','MT_KEEN','MT_BOSSBRAIN','MT_BOSSSPIT','MT_BOSSTARGET'):continue
 roots=re.findall(r'^\s*(S_\w+)\s*,?\s*//\s*(?:spawnstate|seestate|painstate|meleestate|missilestate|deathstate|xdeathstate|raisestate)\s*$',body,re.M)
 visited=set();pending=list(roots)
 while pending:
  state=pending.pop()
  if state=='S_NULL' or state in visited:continue
  assert state in state_defs,state
  visited.add(state);pending.append(state_defs[state]['next'])
 actions=sorted({state_defs[state]['action'] for state in visited}-{ 'NULL' })
 enemy_actions=[action for action in actions if action in soldefs['src/doom/p_enemy.sol']]
 assert set(enemy_actions)<=enemy_operations, 'Actor state action lacks isolated enemy operation'
 actor_families.append({'actorType':actor,'stateRoots':roots,'tableReferencedActions':actions,'enemyModuleActions':enemy_actions,'moduleEvidence':['foundation','ai','lifecycle'],'sourcePresence':'complete original definition and named actions present','integratedFamilyEntryCoverage':'not instrumented; shared action counts cannot identify actor species','globalNativeActionObservations':{action:{case:counts[action] for case,counts in events.items() if action in counts} for action in actions if any(action in counts for counts in events.values())},'allFamilyBranchesVerified':False})
actor_family_inventory={'sourcePath':str(info_source),'sourceSha256':digest(info_source),'selection':'All MF_COUNTKILL definitions plus lost soul, Keen and brain/spitter/target boss actors; effects/projectiles and pickups remain in complete 137-definition foundation inventory.','method':'Follow nextstate from eight declared actor roots until null/cycle; actions called dynamically by another action are not additional table edges. Native action entry counts are global, not attributed to an actor family.','nativeEventCounterBindings':event_proofs,'families':actor_families}

# Audit all integration helper definitions, including private functions/overloads.
helper_roles={
 'src/doom/p_heap.sol':'Stable actor/thinker/world payload IDs and capacity buffers; physical original-size allocation/free mirror, separate from native pointer representation.',
 'src/doom/native_zone_layout.sol':'Generated pinned LP64 sizeof/offsetof constants, not an original gameplay algorithm.',
 'src/doom/w_zone_cache.sol':'Original cache hit/miss tags and owner semantics over authenticated immutable resources; composite owner namespace.',
 'src/doom/z_zone_backing.sol':'Conservative physical backing materialization for known integer header/authenticated adjacent lump bytes; every unknown byte stays rejected.',
 'src/doom/p_zone_setup.sol':'Source-derived P_Setup allocation/cache/free chronology, including original typed map allocations; observed digest overloads are proof instrumentation.',
 'src/evm/DoomZoneStartup.sol':'Source-derived R_Init/R_InitSprites allocation/cache chronology; observed wrappers produce proof digests, not runtime native tapes.',
 'src/evm/DoomGame.sol':'Memory aliases/full hook dispatch, actual atomic native startup, load/tick/render and actor/map/PSprite projection; alternative initializers are test/component scaffolding.',
 'src/evm/Doom.sol':'Public driver authentication, strict sequence, keyboard input, one-transaction initialization, storage commit/rollback and Frame event.',
 'src/evm/InputProtocol.sol':'Held-key ABI validation and original keyboard ticcmd adapter with persisted turn acceleration.',
 'src/evm/ResourceStore.sol':'Authenticated STOP-prefixed chunk/address/identity and bounded immutable byte reader; EVM adaptation.',
 'src/evm/WadResources.sol':'Packed immutable WAD directory/lump metadata and byte reads; no host file I/O.',
 'src/doom/p_info.sol':'Generated complete original states/mobj/weapon/action definitions; data presence is not integrated coverage of every entry.'
}
helpers=[{'path':p,'sha256':digest(p),'role':role,'functions':[{'function':name,'source':span} for name,span in soldefs[p].items()]} for p,role in helper_roles.items()]
# Update preserved feature policy; retained omitted modes remain explicitly omitted.
profiles=[{'id':i,'status':s,'detail':d,'references':r} for i,s,d,r in profiles]
for p in profiles:
 if p['id']=='single_player':p.update(status='integrated_selected_world_verified',detail='Actual atomic medium retail E1M1, one player, source-driven native zone startup; whole-kernel nine declared scenarios, public 129 keyboard tics and Chrome six-frame stream. No arbitrary maps/modes acceptance.')
 if p['id']=='keyboard':p.update(status='integrated_production_and_browser_verified',detail='Original declared keyboard conversion, persistent input, actual public authentication/sequencing/rollback and Chrome Start/Resume, WebSocket/receipt fallback/Canvas in bounded retained streams.')
 if p['id']=='other_maps_modes_skills':p['detail']='Algorithms and dependent branches tested in isolated contexts. Production initializes fixed medium retail E1M1. No arbitrary WAD/map/episode runtime acceptance.'
for d in domains:
 if d['id']=='zone-identity':d.update(policy='Stable logical IDs plus original physical zone mirror',detail='Typed payload IDs/tombstones preserve live linked order; native zone separately preserves original physical offsets/rover/free/purge/cache owner chronology. Actor/mover body and pointer bytes are not generally reconstructed. Actual startup/header proof plus selected full-world/public/browser comparisons establish bounded integration, not all future allocation histories.',references=['src/doom/z_zone.sol','src/doom/p_heap.sol','src/doom/p_tick.sol','src/doom/p_zone_setup.sol','src/evm/DoomZoneStartup.sol','docs/PHASE3-ZONE-SETUP.md'])
 if d['id']=='production-resources':d.update(policy='Configurable local execution budget; independent code/memory/compiler constraints',detail='Default local 10B gas, env/config override. No fixed 1B economic fidelity gate and no production startup split to satisfy such a gate. Actual ordinary initialization1621885757 gas, selected steps309171400..312238893 and liveFrames719455170..781684253. Clone engine-boundary memory initialization19665056B/liveFrames<=11956800B/steps<=8753856B; not exact untouched-production peak. Enlarged local code limits do not imply public-chain deployability.',references=['execution-budget.json','tools/execution-budget.mjs','tools/reference/gameplay/production-release-evidence.json','tools/reference/gameplay/PRODUCTION-MEMORY.md'])
domains.extend([
 {'id':'physical-backing-knownness','policy':'Known bytes only; unknown remains a rejection', 'detail':'Allocated/free size/tag/known-ID integer bytes and authenticated adjacent cached lump bodies may be read through source-derived links. Pointers, padding, initial/split unknown IDs, slack, free/unmodeled payload bodies, stale cache ownership, negative absolute indices and out-of-zone positions remain unreadable. Ordinary128-sample lazy tail window rejects arbitrary translated out-of-profile indices. Logical-lump overread can be within original whole-zone backing; no asset/frame/pixel exception.', 'references':['src/doom/z_zone_backing.sol','src/doom/r_draw.sol','docs/PHASE3-BACKING.md','docs/PHASE3-BACKING-INTEGRATION.md']},
 {'id':'native-layout','policy':'Pinned LP64 implementation profile','detail':'memblock40,memzone56,cap8,headerID20,align8 are measured native adaptation; upstream align4 replaced for LP64 gameplay validity. Stable IDs substitute process pointers. Fresh split IDs intentionally unknown. This is not universal compiler/architecture/pointer-byte fidelity.','references':['test/fixtures/phase3_zone_lifecycle/layout.json','src/doom/native_zone_layout.sol','docs/PHASE3-ZONE.md']},
 {'id':'source-liveness-adaptations','policy':'Call-local working-set representation only','detail':'P_PathTraverse working struct, R_LoadMap line aliases/offset scratch and physical tail reader scratch allow unchanged production compiler settings to generate the full hook graph. No source loop/math/order/guard changes or persisted scratch injection.','references':['artifacts/phase3/path-traversal-checkpoint.json','artifacts/phase3/renderer-backing-checkpoint.json']}
])
remaining=[
 {'id':'inherited-final-gates','status':'pending','requirement':'Run required final inherited Phase0/1/2 and complete Phase3 regression gates against frozen source; bind final tested source hashes.'},
 {'id':'repeat-production-stream','status':'verified','requirement':'Completed retained reproducibility proof: two independent ordinary production deployments, complete129-tic stream, all fields/cadence/Frames/gas/thirteen error and rollback checks equal.'},
 {'id':'feature-domain-signoff','status':'pending','requirement':'Integrator final source/function/domain review; preserve explicitly unsupported profiles and all rejected unknown backing/undefined domains.'},
 {'id':'M2-final-acceptance','status':'pending','requirement':'Integrator accepts bounded startup/input/movement/world/render/persistence/browser scope only after final inherited/repeat gates.'},
 {'id':'M3-final-acceptance','status':'pending','requirement':'Integrator accepts declared integrated combat/AI/damage/pickup/door/projectile scenarios after final gates; isolated all-nine-weapon/all-enemy-action proofs do not become complete full-world branch coverage.'},
 {'id':'usage-article','status':'continuing','requirement':'Keep existing local collector boundaries/model/agent/phase evidence and missing historical measurements; do not read raw transcripts or infer absent token counts.'}
]
# Acceptance is an integrator decision backed by checked proof/source identities.
acceptance_path=Path('artifacts/phase3/acceptance.json')
acceptance_record=json.loads(acceptance_path.read_text()) if acceptance_path.is_file() else None
accepted=bool(acceptance_record and acceptance_record.get('M2')=='passed' and acceptance_record.get('M3')=='passed')
if accepted:
 for item in acceptance_record['proofs'].values():
  assert digest(item['path'])==item['sha256'], 'stale acceptance proof '+item['path']
 for path,h in acceptance_record['sourceHashes'].items():
  assert digest(path)==h, 'stale accepted source '+path
 assert all(item['status']=='passed' for item in acceptance_record['requirements'].values())
 build=acceptance_record['currentProductionArtifact']
 assert digest(build['artifactPath'])==build['artifactSha256'], 'current production artifact differs from accepted build'
 for item in remaining:
  if item['id']!='usage-article':item['status']='verified'

core=[x for x in records if x['module'].startswith('p_') and x['module']!='p_saveg' and x['activeUpstream']]
source_snapshots=[{'path':str(p),'sha256':digest(p)} for p in sorted(Path('src').rglob('*.sol'))]
payload={'schemaVersion':2,'scope':'Current source/function/feature evidence audit; M2/M3 accepted within documented scope' if accepted else 'Current source/function/feature evidence audit; final milestone gates pending','upstreamCommit':'a77dfb96cb91780ca334d0d4cfd86957558007e0','acceptance':{'M2':'passed' if accepted else 'pending_final_gates','M3':'passed' if accepted else 'pending_final_gates','selectedProductionGameplay':'verified','selectedWholeKernel':'verified','selectedBrowser':'verified','completeOriginalDOOM':'not_claimed'},'methodology':{'sourceInventory':'Brace-balanced definitions after comments/string removal; explicit disabled #if0 sliding-door exclusion; every original p/game/RNG/bbox/zone/WAD/renderer definition within listed translation units. Overloaded Solidity helper definitions preserved.','sourcePresenceIsNotEquivalence':True,'selectedWorldEvidenceIsNotPerFunctionBranchCoverage':True,'nativeEntryCountsAreNotBranchCoverage':True,'absentEntryObservation':'null means absent from retained instrumentation, not proof of nonexecution.','sourceHashes':'Current files and separate source-at-run bindings; component evidence remains historical until final frozen rerun. Runner-only drift is explicitly retained.','evidence':'Programmatic summary of retained proof reports and parent execution records; no compiler/network/engine tests run by this audit.','localReports':'Ignored detailed reports remain hash-bound here; localOnlyReport explicitly identifies those dependencies.','sessionTranscripts':'Never read or included.','commandAttribution':'Commands present in retained reports are copied exactly; missing execution commands are not inferred from current defaults.','compilerBlocker':None},'summary':{'inventoriedOriginalDefinitions':len(records),'implementationCounts':dict(collections.Counter(x['implementation'] for x in records)),'activeCoreGameplayDefinitions':len(core),'activeCoreGameplayNamedPorts':sum(x['implementation']=='named_port' for x in core),'activeCoreGameplayDelegatedLoaders':sum(x['implementation']=='delegated' for x in core),'disabledSlidingDoorDefinitions':4,'helperDefinitions':sum(len(h['functions']) for h in helpers),'monsterBossActorFamilies':len(actor_families)},'executionPolicy':{'config':'execution-budget.json','configSha256':digest('execution-budget.json'),'defaultGasLimit':10000000000,'configurable':True,'fixedEconomicGasGate':None,'compilerUnchanged':'solc0.8.37 viaIR optimizer200 Cancun','constraints':'Local code/memory/protocol gates remain separate; historical gas reports never rewritten.'},'modules':modules,'functions':records,'helpers':helpers,'evidence':ev,'profiles':profiles,'domains':domains,'remainingAcceptance':remaining,'sourceSnapshots':source_snapshots,'actorFamilyMatrix':actor_family_inventory,'specialNumberMatrix':{'path':'test/fixtures/phase3_specials/dispatch-matrix.json','sha256':digest('test/fixtures/phase3_specials/dispatch-matrix.json')}}

payload['acceptanceRecord']={'path':str(acceptance_path),'sha256':digest(acceptance_path)} if accepted else None

# Markdown is generated from the same audited inventory/policy as the JSON.
md='''# Phase 3 source coverage and acceptance boundaries

The frozen implementation now has bounded, completed kernel, public-contract and
Chrome integration proofs on the formatted build. Historical pre-format proofs remain
separate and are not relabeled current. **M2 and M3 remain pending final inherited gates,
integrator signoff.** This is not a complete original
DOOM port. All descriptions below distinguish source presence, actual integration
and the measured verification scope.

The [machine-readable matrix](../artifacts/phase3/feature-matrix.json) records every
original definition's source span/hash, its named port or explicit delegation,
helper roles, proof hashes, current source bindings and unsupported domains.
Refresh with `python3 tools/audit/phase3_features.py`; verify the snapshot with
`--check`. The generator reads code and summarized proof records, never Codex
session transcripts. This audit ran no compiler or engine tests.

## Source inventory

'''
md+=f'The pinned original checkout is `{payload["upstreamCommit"]}`. Across 18 core\n`p_*.c` gameplay units there are **{len(core)} active definitions**: {payload["summary"]["activeCoreGameplayNamedPorts"]} named ports\nand seven disk loaders delegated to `R_Data.R_LoadMap`. Setup is integrated and\nverified, rather than a draft. Sector runtime initialization and native map\nallocation chronology remain separate source-derived adapter responsibilities.\n\n'
md+=f'The expanded inventory covers **{len(records)} definitions**, including original\n`p_saveg`, all `g_game`, RNG/bbox, all renderer units, `z_zone` and `w_wad`.\nOriginal abandoned sliding doors are excluded from active gameplay counts.\nFour of 32 `g_game` definitions are ported; eight original save/archive\ndefinitions and the other gameflow definitions remain absent.\n\n'
md+='| Original unit | Definitions | Named / delegated / adapted / absent |\n|---|---:|---|\n'
for m in modules:
 c=m['counts'];md+=f'| `{m["module"]}` | {sum(c.values())} | '+', '.join(f'{name}: {count}' for name,count in c.items())+' |\n'
md+='''
Counts establish source mapping, not per-function branch acceptance. Original
host file/reload/profile and heap dump functions remain host responsibilities;
immutable authenticated EVM resource readers adapt name/length/byte lookup.
Semantic `W_CacheLumpNum` hit/miss/tag/owner behavior is implemented separately.
`Z_ClearZone`, `Z_Init`, `Z_Free`, `Z_Malloc`, `Z_FreeTags`, `Z_CheckHeap`,
`Z_ChangeTag2` and `Z_FreeMemory` are the eight ported original allocator cores.

## Completed integration evidence

| Evidence | Actual scope | Result |
|---|---|---|
| [Atomic startup](../tools/reference/phase3_zone_setup/final-validation.json) | Single real `initializeNative`, original resource/level/player allocation order, all normalized headers/owners and actor/special/map counts; four tests | PASS |
| Full kernel, retained report `artifacts/local/gameplay-kernel-final.json` | Nine declared scenarios, 2,355 tics, 31 selected complete frames, nine exact final stored logical states; direct ticcmds and test-only arena setup | PASS, run60930 |
| [Public production](../tools/reference/gameplay/production-release-evidence.json) | One ordinary `initializeGame` transaction; 129 keyboard tics, 130 rows ×14 fields, six native live frames, static pre-start Frame, thirteen whole-storage rollback checks | PASS, run38271 |
| [Repeated production](../tools/reference/gameplay/production-release-reproducibility-evidence.json) | Two fresh ordinary contracts: all130×14 rows, commands/sequences/cadence, seven totalFrames, gas and thirteen errors/rollback equal | PASS, run47208 |
| Chrome, retained report `artifacts/local/phase3-gameplay-browser-release.json` | Six actual Frames/Canvas, keyboard Start/Resume, blur stop, deduplication and controlled receipt fallback; prior failing tic5 now exact | PASS, run24522 |
| Memory clone reports `artifacts/local/gameplay-production-release-memory{,-cadence}.json` | Separate clone agrees with ordinary production storage/exported fields/Frames; patched/unpatched clone gas equal; all-render and no-render cadence | PASS, run81374 |

The repeated production stream has independent fresh state and rechecks all1,755 authenticated resource chunks. Only the repeat runner's optional palette-copy guard differs; production code/transactions/native stream are unchanged.

The full-kernel scenarios are idle70, movement275, pistol235, combat175,
damage350, death350, door-use375, door-obstructed375 and projectile-arena150 tics.
The last compares seven selected frames and actual rocket interactions. All
other cases compare three frames. Native instrumentation reports authoritative
logical world before rendering; final stored comparisons use the appropriate
post-render native boundary. This avoids treating renderer-mutated flags and
validcounts as a simulation mismatch. It does not imply comparison of every
renderer cache byte or arbitrary physical payload byte.

Public production verifies its real driver/strict consecutive sequence/input
validation and rollback, persisted whole game state and Frame transport, rather
than probe serialization. Five `gameStatus` and nine `playerView` fields are
checked at every selected tic. Chrome's short fire input arrives while the weapon
is raising; actual shooting has independent 129-tic production and kernel proofs.
Kernel direct-command coverage does not independently prove every keyboard path.

The retained module scopes remain useful: collision/sight 4,310 geometry cases
and71 scenarios; lifecycle784 cases; combat6,025 interaction cases and72 weapon
scenarios/11,520 tics; AI1,137 controlled cases/all64 active definitions; world
359 scenarios/79,021 snapshots/2,160 plane cases; specials416 unit cases plus
1,007 dispatch scenarios/4,048 paired snapshots; bbox521 streams/8,299 points;
input41,007 commands. The source/table export has967 states,137 actor/effect/item
definitions,nine weapons and74 actions. These are not137 monster species or
full-world execution of every entry. Exact original numeric special dispatch
coverage is72 crossing,63 use and3 shoot branches in declared synthetic fixtures.
Broad weapon/enemy/world module proofs use controlled neighbors or synthetic
geometry; they do not become complete integrated action/species coverage.

Allocator core proof covers1,624 original allocation snapshots and five fatal
conditions across O0/O2/full ASan/UBSan, plus two Solidity tests. Renderer backing
proof covers80 native cases/10,240 knownness positions/18 original draws and111
owned inherited/focused Solidity tests. Each checkpoint binds its own tested
source revision. Final inherited regression gates remain separate.

## Allocator/cache and representation adaptations

Stable logical actor/thinker/world IDs and capacity buffers preserve linked
thinker/sector/block order and same-tic tail execution. A separate native zone
ledger preserves source physical allocation offsets, list links, rover,
purge/merge/donated slack and logical owner clearing. Source-derived startup,
map setup, actors/movers/lazy frees and semantic renderer cache operations mutate
that ledger. Native allocation outputs are comparison gold only, never runtime
tapes. Owner namespace is lump ID; composites use `numlumps + textureID`.

Raw columns/sprites use `PU_CACHE`; drawn flats use `PU_STATIC` then return to
`PU_CACHE`; composites allocate before patch-cache calls and become cache-tagged
after construction. Ephemeral immutable-data decoding is not an additional
native allocation. Existing composite bodies may be quietly rebuilt after an
EVM storage load, while a purged owner requires genuine original regeneration.

The pinned LP64 profile has40-byte block headers,56-byte zone header, sentinel
offset8 and8-byte alignment. Upstream4-byte alignment is explicitly adapted for
native LP64 gameplay. Allocation sets known `ZONEID`; free sets known0; initial
and split free IDs remain unknown, including physical reuse. Stable IDs are not
fabricated process pointer bytes.

The renderer can read beyond a logical lump only when the original physical
backing value is known: size/tag/known-ID header integers or authenticated live
adjacent cached-lump body bytes. It preserves the original column arithmetic,
including negative fraction wrap. No specific asset/frame/pixel exception exists.
Pointers, padding, uninitialized IDs, slack, free/unmodeled actor/mover/composite
bodies, stale owners and out-of-zone bytes remain unknown and rejected. The lazy
128-sample ordinary-column window is conservative for translated out-of-profile
indices; negative absolute indices still reject. Existing malformed draw/resource
checks remain. Selected recovered frames do not prove arbitrary native reads.

Call-local traversal, line-loader and tail-reader working structs resolve full
hook-graph compiler liveness without changing source math/order/loops/guards,
persisted semantics, limits or compiler settings.

## Supported and omitted profiles

| Feature | Implementation/integration boundary |
|---|---|
'''
for p in profiles:md+=f'| `{p["id"]}` | **{p["status"]}**: {p["detail"]} |\n'
md+='''
Original `G_Ticker`, `G_DoReborn`, `G_DoCompleted`, world transition/intermission,
finale, full new-game flow and save/archive format are absent. Exit/secret flags,
DeathThink/PlayerReborn/SpawnPlayer and a direct `P_Ticker` do not implement those
layers. World view/PSprites are rendered, but original HUD/menu/automap/audio
presentation is omitted. No complete playthrough, all-map, multiplayer, device,
demo or arbitrary WAD acceptance is claimed.

## Monster and boss family evidence

The source-derived family matrix includes every `MF_COUNTKILL` actor plus lost
soul, Keen and brain/spitter/target actors. All original definitions are in the
foundation proof. Named enemy actions have isolated original-C module evidence;
this is not an integrated-world species claim. State-table traversal lists the
declared actions from spawn/see/pain/melee/missile/death/xdeath/raise roots;
dynamic calls from actions are covered by their own function inventory. Retained
native action counters are global and cannot attribute a shared action to an
actor species. **Individual integrated family entry coverage is uninstrumented.**

| Original actor family | Declared enemy state actions | Integrated species evidence |
|---|---|---|
'''
for family in actor_families:
 md+=f'| `{family["actorType"]}` | '+', '.join(f'`{action}`' for action in family['enemyModuleActions'])+' | Shared entry counters only; species attribution not established |\n'
md+='''
See the [AI family/function proof](PHASE3-AI.md) for controlled module conditions
and remaining integrated species/attack/resurrection/boss-map domains. The JSON
retains each family's state roots, table actions and global native observations;
zero or absent observations do not prove absence of execution.

## Native domains and execution policy

'''
for d in domains:md+=f'- **{d["id"]} — {d["policy"]}.** {d["detail"]}\n'
md+='''
The default **local gas budget is10B and configurable** through the shared config
and environment helper. There is no fixed1B economic fidelity gate. Production
startup remains one atomic transaction. Existing historical1B reports retain
their original values and scopes; no measurement has been rewritten.

Actual ordinary production initialization costs1,621,885,757 gas; selected
no-render steps309,171,400–312,238,893 and live frames719,455,170–781,684,253.
These include storage/gameplay/render/Frame work and exclude probe serialization.
They describe enlarged local Cancun execution, not protocol-limit public-chain
deployment. Compiler remains solc0.8.37,viaIR,optimizer200,Cancun.

Measured clone engine-boundary memory high-water is19,665,056 bytes for atomic
initialization, at most11,956,800 bytes for selected live frames and8,753,856 bytes
for selected no-render steps. The marker follows actual engine work; later
observer event encoding and separate calls/precompiles are outside that reading.
The clone can change compiler memory reuse. **Exact untouched-production memory
peak remains unmeasured.** This limitation survives equal storage, pixels and
patched/unpatched clone gas. See [memory method](../tools/reference/gameplay/PRODUCTION-MEMORY.md).

## Remaining final acceptance

'''
for r in remaining:md+=f'- **{r["id"]}: {r["status"]}.** {r["requirement"]}\n'
md+='''
Commands are copied exactly when present in retained records. Where a local
report does not retain a command, the matrix does not invent it from current
script defaults. Source-at-run bindings remain distinct from the current audit
snapshot; runner-only changes are listed even when production Solidity is
unchanged. The machine-readable evidence registry binds every retained report
by SHA256, including ignored local reports. No new test result is inferred by
this audit.
'''

if accepted:
 md=md.replace('**M2 and M3 remain pending final inherited gates,\nintegrator signoff.**', '**M2 and M3 passed the original Phase 3 gates.**\nThe [acceptance record](../artifacts/phase3/acceptance.json) binds all required\nfrozen regressions and final-artifact runtime proofs.')
 md=md.replace('Final inherited regression gates remain separate.', 'Final inherited regressions pass; their frozen scope is recorded separately.')
 md+='\nThe final renderer build and full-project build emit different runtime artifacts\nwith identical consumed sources/compiler settings. Both complete production\nstreams are retained separately; current acceptance uses the final renderer\nbuild, ordinary129-tic repeat, six-frame Chrome and sequential memory proofs.\nExact build command and hashes are in the current production evidence.\n'

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
 for key,item in ev.items():
  bindings=item['retainedReportBindings']+item.get('methodEvidence',{}).get('retainedReportBindings',[])
  bad=[binding for binding in bindings if binding['status']!='match']
  if bad:raise SystemExit('INVALID retained report binding '+key+' '+json.dumps(bad))
 outputs={'artifacts/phase3/feature-matrix.json':json.dumps(payload,indent=2)+'\n','docs/PHASE3-FEATURE-MATRIX.md':md}
 for path,content in outputs.items():
  if args.check:
   if Path(path).read_text()!=content:raise SystemExit('STALE '+path)
  else:Path(path).write_text(content)
 print(json.dumps({'mode':'check' if args.check else 'refresh','summary':payload['summary'],'evidence':{key:item.get('coverage',{}) for key,item in ev.items() if key in extras},'sourceBindingMismatches':{key:item['currentSourceBindings']['mismatches'] for key,item in ev.items() if item.get('currentSourceBindings',{}).get('mismatches')}},indent=2))
if __name__=='__main__':main()
