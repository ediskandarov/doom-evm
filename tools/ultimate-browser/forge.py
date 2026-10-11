#!/usr/bin/env python3
"""Focused affected authentication, menu, input, UI and owner-policy dependencies."""
from pathlib import Path
import subprocess, json, datetime, time, hashlib
ROOT=Path(__file__).resolve().parents[2]
keep={'ProductionWadResources.t.sol','UltimateProductionResources.t.sol','VirtualOwnerPointers.t.sol','m_menu.t.sol','InputRuntime.t.sol','EpisodeLifecycle.t.sol','v_video.t.sol','g_game_lifecycle.t.sol'}
paths=[p for p in (ROOT/'test').rglob('*.t.sol') if p.name in keep]
skips=sorted({p.name for p in (ROOT/'test').rglob('*.t.sol') if p.name not in keep})
skips += ['Doom.sol','GameplayProbe.sol','RendererProbe.sol','WadResourcesProbe.sol','EpisodeStartupProbe.sol','EpisodeResourcesProbe.sol','IntermissionProbe.sol','CheatProbe.sol','AutomapProbe.sol','VideoProbe.sol']
cmd=['.toolchain/bin/forge','test','--offline','--no-dynamic-test-linking','--match-path','{'+','.join(str(p.relative_to(ROOT)) for p in paths)+'}','--skip',*skips,'-vv']
out=ROOT/'artifacts/local/ultimate-browser';out.mkdir(parents=True,exist_ok=True)
start=datetime.datetime.now(datetime.timezone.utc).isoformat();timer=time.monotonic();p=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True)
log=p.stdout+p.stderr;(out/'forge.log').write_text(log)
report=dict(pass_=p.returncode==0,startedUtc=start,seconds=time.monotonic()-timer,command=cmd,logSha256=hashlib.sha256(log.encode()).hexdigest())
(out/'forge.json').write_text(json.dumps(report,indent=2)+'\n');print(log[-6500:]);raise SystemExit(p.returncode)
