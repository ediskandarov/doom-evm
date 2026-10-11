#!/usr/bin/env python3
"""Focused commercial gates and inherited affected engine/UI dependencies only."""
from pathlib import Path
import datetime,hashlib,json,re,subprocess,time
ROOT=Path(__file__).resolve().parents[3]
names={'Gameflow.t.sol','m_menu.t.sol','Intermission.t.sol','Finale.t.sol','p_pspr.t.sol','p_enemy.t.sol'}
keep={str(p.relative_to(ROOT)) for p in (ROOT/'test').rglob('*.t.sol') if p.name in names or str(p.relative_to(ROOT)).startswith('test/doom2/')}
skips=sorted({p.name for p in (ROOT/'test').rglob('*.t.sol') if str(p.relative_to(ROOT)) not in keep})+['Doom.sol','Doom2.sol','GameplayProbe.sol','RendererProbe.sol','WadResourcesProbe.sol','Doom2StartupProbe.sol','Doom2SpeedrunProbe.sol','UltimateSpeedrunProbe.sol','SpeedrunProbe.sol','SpeedrunVideoProbe.sol','EpisodeSpeedrunProbe.sol','EpisodeStartupProbe.sol']
cmd=['.toolchain/bin/forge','test','--offline','--no-dynamic-test-linking','--match-path','{'+','.join(sorted(keep))+'}','--skip',*skips,'-vv'];start=datetime.datetime.now(datetime.timezone.utc).isoformat();timer=time.monotonic()
r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True);log=r.stdout+r.stderr;out=ROOT/'artifacts/doom2';out.mkdir(exist_ok=True)
(out/'focused.log').write_text(log);counts=re.search(r'(\d+) tests passed, (\d+) failed, (\d+) skipped \((\d+) total tests\)',log)
report=dict(pass_=r.returncode==0,startUTC=start,endUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),seconds=time.monotonic()-timer,command=cmd,counts=list(map(int,counts.groups())) if counts else None,logSHA256=hashlib.sha256(log.encode()).hexdigest());(out/'focused.json').write_text(json.dumps(report,indent=2)+'\n');print(log[-3500:]);print(json.dumps(report));raise SystemExit(r.returncode)
