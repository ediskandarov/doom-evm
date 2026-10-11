#!/usr/bin/env python3
"""Build explicit affected test roots, keeping the pinned compiler/test policy."""
import argparse,datetime,hashlib,json,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
ap=argparse.ArgumentParser();ap.add_argument('--inherited',action='store_true');ap.add_argument('--cache-root',type=Path);a=ap.parse_args()
keep={'EpisodeLifecycle.t.sol','InputRuntime.t.sol','g_game_lifecycle.t.sol','p_user.t.sol','Gameflow.t.sol','GameflowTransactions.t.sol','OptionsMenu.t.sol','m_menu.t.sol','p_inter.t.sol','p_pspr.t.sol','st_stuff.t.sol','z_zone.t.sol'} if a.inherited else {'DeathRespawn.t.sol'}
paths=sorted(str(p.relative_to(ROOT)) for p in (ROOT/'test').rglob('*.t.sol') if p.name in keep)
skips=sorted({p.name for p in (ROOT/'test').rglob('*.t.sol') if p.name not in keep})
skips += [p.name for p in (ROOT/'src/support').glob('*.sol') if p.name.endswith('Probe.sol') and (a.inherited or p.name!='DeathRespawnProbe.sol')]
if a.inherited:skips += ['Doom.sol','Doom2.sol']
cmd=['.toolchain/bin/forge','test','--offline','--no-dynamic-test-linking','--gas-limit','200000000000','--match-path','{'+','.join(paths)+'}','--skip',*skips,'-vv']
if a.cache_root:cmd += ['--out',str(a.cache_root/'out'),'--cache-path',str(a.cache_root/'cache')]
start=datetime.datetime.now(datetime.timezone.utc).isoformat();timer=time.monotonic();r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True)
log=r.stdout+r.stderr;out=ROOT/'artifacts/local/death-respawn';out.mkdir(parents=True,exist_ok=True);name='inherited' if a.inherited else 'focused';(out/(name+'.log')).write_text(log)
counts=re.search(r'(\d+) tests passed, (\d+) failed, (\d+) skipped \((\d+) total tests\)',log)
report=dict(pass_=r.returncode==0,startedUtc=start,endedUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),seconds=time.monotonic()-timer,command=cmd,counts=list(map(int,counts.groups())) if counts else None,logSha256=hashlib.sha256(log.encode()).hexdigest())
(out/(name+'.json')).write_text(json.dumps(report,indent=2)+'\n');print(log[-4500:]);print(json.dumps(report));raise SystemExit(r.returncode)
