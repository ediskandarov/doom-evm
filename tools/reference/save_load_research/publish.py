#!/usr/bin/env python3
"""Bind compact canonical-lifecycle research evidence; preserve raw attempts."""
import argparse,hashlib,itertools,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
ap=argparse.ArgumentParser();ap.add_argument('--run',default='artifacts/local/save-load-canonical/final-death');a=ap.parse_args()
sha=lambda b:hashlib.sha256(b).hexdigest()
raw=ROOT/a.run/'report.json';report=json.loads(raw.read_text());assert report['pass']
assert len(report['profiles'])==3 and len(report['cases'])==11
for p,h in report['harnessHashes'].items():assert sha((ROOT/p).read_bytes())==h,p
canonical=report['profiles'][1]['games']
for profile in report['profiles']:assert profile['games']==canonical
compact={k:v for k,v in report.items() if k!='profiles'}
compact['rawReportPath']=str(raw.relative_to(ROOT));compact['rawReportSha256']=sha(raw.read_bytes())
compact['profiles']=[{'profile':p['profile'],'manifestSha256':sha(json.dumps(p['manifest'],sort_keys=True).encode()),
 'caseResultsSha256':sha(json.dumps(p['games'],sort_keys=True).encode()),'flags':p['manifest']['flags'],
 'adaptations':p['manifest']['adaptations']} for p in report['profiles']]
compact['extractions']=report['profiles'][1]['manifest']['extractions'];compact['games']=canonical
for game in canonical.values():
 for case in game['cases'].values():
  for row in case['observations']:
   if 'thinkerOrder' in row:
    order=row.pop('thinkerOrder');row['thinkerOrderSha256']=sha(json.dumps(order,separators=(',',':')).encode())
    row['thinkerOrderRuns']=[[k,len(list(v))] for k,v in itertools.groupby(order)]
compact['scope']=[
 'Actual original G_DoSaveGame/G_DoLoadGame with ordinary filesystem IO, authentic map rebuild, original P_* game logic, G_BuildTiccmd/G_Ticker action dispatch and real ST/HU/AM/video/renderer.',
 'Direct action calls isolate restore boundaries; queued cases execute the normal special-button/action/ticker ordering. Full D_Display/wall-clock wipe loop is source-reviewed, not executed; captured frames use original ST_Drawer/R_RenderPlayerView/HU_Drawer without wipes.',
 'Original repository/goldens untouched. Generated LP64 archive align8, inherited allocator/disk/UI borrowing adaptations and C89 implicit-int acceptance are recorded. Unsafe tracer pointer is compared, never dereferenced in the controlled case.',
 'Eleven finite first-map cases per IWAD; not all maps, all special types, multiplayer/audio or universal process-pointer equivalence. Native frames and raw commercial save/WAD bytes remain ignored verification artifacts.']
pub=ROOT/'artifacts/save-load-canonical';pub.mkdir(exist_ok=True)
(pub/'native-lifecycle.json').write_text(json.dumps(compact,indent=2)+'\n')
attempts=[]
for name in ['run1','run2','run3','run4','run5','full1','final']:
 p=ROOT/'artifacts/local/save-load-canonical'/name/'report.json'
 if p.exists():
  value=json.loads(p.read_text());attempts.append({'path':str(p.relative_to(ROOT)),'sha256':sha(p.read_bytes()),'pass':value['pass'],'error':value.get('error')})
(pub/'attempts.json').write_text(json.dumps({'kind':'Separate research attempts retained; passing pre-expansion runs remain preserved.','attempts':attempts},indent=2)+'\n')
invariants={'baseline':report['baseline'],'productionOriginalTestsAndEarlierEvidenceUnchanged':True,
 'checkedPaths':['src','web','test','original','foundry.toml','PORTING.md','docs/SAVE-LOAD.md','artifacts/save-load','tools/reference/save_load'],
 'newFilesOnly':['docs/SAVE-LOAD-CANONICAL-DISCOVERY.md','tools/reference/save_load_research/','artifacts/save-load-canonical/']}
assert not subprocess.check_output(['git','diff',report['baseline'],'--name-only','--',*invariants['checkedPaths']],cwd=ROOT,text=True).strip()
(pub/'scope.json').write_text(json.dumps(invariants,indent=2)+'\n')
index={'reports':{p.name:sha(p.read_bytes()) for p in sorted(pub.glob('*.json')) if p.name!='evidence.json'}}
(pub/'evidence.json').write_text(json.dumps(index,indent=2)+'\n')
print('PASS compact evidence:99 native lifecycle runs, preserved production/original/tests/evidence')
