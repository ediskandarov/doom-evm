#!/usr/bin/env python3
"""Explicit affected test roots; preserve the shared compiler and test policy."""
import datetime, hashlib, json, pathlib, re, subprocess, time
ROOT=pathlib.Path(__file__).resolve().parents[3]
keep={'Finale.t.sol','Gameflow.t.sol','GameflowTransactions.t.sol','g_game_lifecycle.t.sol',
      'g_game.t.sol','p_mobj.t.sol','st_stuff.t.sol','Intermission.t.sol','m_random.t.sol',
      'v_video.t.sol','EpisodeStartup.t.sol','InputRuntime.t.sol','ProductionUI.t.sol','EpisodeLifecycle.t.sol','GameflowE1M1.t.sol',
      'PointerHighBytes.t.sol','CompositeBacking.t.sol','r_data.t.sol','z_zone_backing.t.sol','z_zone_initialization.t.sol','z_zone.t.sol','r_draw.t.sol'}
if '--finale-only' in __import__('sys').argv: keep={'Finale.t.sol'}
if '--input-only' in __import__('sys').argv: keep={'InputRuntime.t.sol','p_enemy.t.sol','EpisodeLifecycle.t.sol'}
skips=sorted({p.name for d in ['src/support','test'] for p in (ROOT/d).rglob('*.sol')
    if p.name not in keep and p.name.endswith('.t.sol')})
skips += ['GameplayProbe.sol','RendererProbe.sol','WadResourcesProbe.sol','EpisodeResourcesProbe.sol',
    'EpisodeStartupProbe.sol','IntermissionProbe.sol','CheatProbe.sol','AutomapProbe.sol','VideoProbe.sol','Doom.sol']
cmd=['.toolchain/bin/forge','test','--offline','--no-dynamic-test-linking','--match-path',
     '{'+','.join(str(p.relative_to(ROOT)) for p in (ROOT/'test').rglob('*.t.sol') if p.name in keep)+'}',
     '--skip',*skips,'-vv']
out=ROOT/'artifacts/phase4/episode-completion';out.mkdir(parents=True,exist_ok=True)
start=datetime.datetime.now(datetime.timezone.utc).isoformat(); timer=time.monotonic()
run=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True)
log=run.stdout+run.stderr; name='finale-forge' if len(keep)==1 else ('input-final' if '--input-only' in __import__('sys').argv else 'focused-final')
(out/(name+'.log')).write_text(log)
counts=re.search(r'(\d+) tests passed, (\d+) failed, (\d+) skipped \((\d+) total tests\)',log)
report=dict(pass_=run.returncode==0,start=start,seconds=time.monotonic()-timer,command=cmd,
    counts=list(map(int,counts.groups())) if counts else None,logSha256=hashlib.sha256(log.encode()).hexdigest())
(out/(name+'.json')).write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report)); print(log[-4000:]); raise SystemExit(run.returncode)
