#!/usr/bin/env python3
"""Bounded inherited input, video and lifecycle dependencies; pinned compiler unchanged."""
import datetime, hashlib, json, re, subprocess, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
keep={'InputRuntime.t.sol','EpisodeLifecycle.t.sol','v_video.t.sol','g_game_lifecycle.t.sol'}
paths=[p for p in (ROOT/'test').rglob('*.t.sol') if p.name in keep]
skips=sorted({p.name for p in (ROOT/'test').rglob('*.t.sol') if p.name not in keep})
skips += ['Doom.sol','GameplayProbe.sol','RendererProbe.sol','WadResourcesProbe.sol',
          'EpisodeStartupProbe.sol','EpisodeResourcesProbe.sol','IntermissionProbe.sol','CheatProbe.sol','AutomapProbe.sol','VideoProbe.sol']
cmd=['.toolchain/bin/forge','test','--offline','--no-dynamic-test-linking','--match-path',
     '{'+','.join(str(p.relative_to(ROOT)) for p in paths)+'}','--skip',*skips,'-vv']
out=ROOT/'artifacts/phase4/menu';out.mkdir(parents=True,exist_ok=True)
started=datetime.datetime.now(datetime.timezone.utc).isoformat();timer=time.monotonic()
result=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True)
log=result.stdout+result.stderr;(out/'inherited-focused.log').write_text(log)
counts=re.search(r'(\d+) tests passed, (\d+) failed, (\d+) skipped \((\d+) total tests\)',log)
report=dict(pass_=result.returncode==0,startedUtc=started,seconds=time.monotonic()-timer,command=cmd,
    counts=list(map(int,counts.groups())) if counts else None,logSha256=hashlib.sha256(log.encode()).hexdigest())
(out/'inherited-focused.json').write_text(json.dumps(report,indent=2)+'\n')
print(log[-4500:]);print(json.dumps(report));raise SystemExit(result.returncode)
