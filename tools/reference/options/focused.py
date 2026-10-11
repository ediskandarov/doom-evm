#!/usr/bin/env python3
"""Bounded Options/menu and affected original HUD/input/gameflow gates."""
import datetime,hashlib,json,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
names={'OptionsMenu.t.sol','m_menu.t.sol','Menu.t.sol','hu_stuff.t.sol','HudMessages.t.sol','InputRuntime.t.sol','EpisodeLifecycle.t.sol','g_game_lifecycle.t.sol'}
keep={str(p.relative_to(ROOT)) for p in (ROOT/'test').rglob('*.t.sol') if p.name in names}
skips=sorted({p.name for p in (ROOT/'test').rglob('*.t.sol') if str(p.relative_to(ROOT)) not in keep})
skips+=[p.name for p in (ROOT/'src/support').glob('*.sol') if p.name.endswith('Probe.sol')]
skips+=['Doom.sol','Doom2.sol']
cmd=['.toolchain/bin/forge','test','--offline','--no-dynamic-test-linking','--match-path','{'+','.join(sorted(keep))+'}','--skip',*skips,'-vv']
start=datetime.datetime.now(datetime.timezone.utc).isoformat();timer=time.monotonic();r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True)
log=r.stdout+r.stderr;out=ROOT/'artifacts/local/options';out.mkdir(parents=True,exist_ok=True);(out/'focused.log').write_text(log)
counts=re.search(r'(\d+) tests passed, (\d+) failed, (\d+) skipped \((\d+) total tests\)',log)
report=dict(pass_=r.returncode==0,startedUtc=start,endedUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),seconds=time.monotonic()-timer,command=cmd,counts=list(map(int,counts.groups())) if counts else None,logSha256=hashlib.sha256(log.encode()).hexdigest())
(out/'focused.json').write_text(json.dumps(report,indent=2)+'\n');print(log[-4500:]);print(json.dumps(report));raise SystemExit(r.returncode)
