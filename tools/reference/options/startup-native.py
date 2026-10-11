#!/usr/bin/env python3
"""Finite skill-filtered startup/tic observations from pinned original C; no EVM inputs."""
import hashlib, importlib.util, json, os, struct, subprocess, sys, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/reference/doom2'))
import oracle
spec=importlib.util.spec_from_file_location('options_startup',ROOT/'tools/reference/episode_startup/reference.py')
startup=importlib.util.module_from_spec(spec);spec.loader.exec_module(startup)
from verify import player_records
sha=lambda b:hashlib.sha256(b).hexdigest()
base=ROOT/'artifacts/local/options/startup-native';base.mkdir(parents=True,exist_ok=True)
commands=base/'one-tic.txt';commands.write_text('0 0 0 0 0\n')
started=time.time();report=dict(startedUtc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),upstreamCommit=startup.ref.UPSTREAM,builds=[],cases=[])
wads={'freedoom':ROOT/'artifacts/local/freedoom/freedoom1.wad','ultimate':ROOT/'artifacts/local/options/DOOM.WAD','doom2':ROOT/'artifacts/local/options/DOOM2.WAD'}
pins={'freedoom':'7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d','ultimate':'6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f','doom2':'10d67824b11025ddd9198e8cfc87ca335ee6e2d3e63af4180fa9b8a471893255'}
for name,path in wads.items():assert sha(path.read_bytes())==pins[name]
canonical={}
for profile,opt,sanitized in [('O0','O0',False),('O2','O2',False),('sanitized','O2',True)]:
    for commercial in [False,True]:
        build=base/('commercial' if commercial else 'episode')/profile
        if commercial:
            binary=oracle.build_replay(build,opt,sanitized)
            manifest=json.loads((build/'speedrun-build-manifest.json').read_text())
        else:binary,manifest=startup.build_native(build,opt,sanitized)
        report['builds'].append(dict(profile=profile,commercial=commercial,binarySha256=sha(binary.read_bytes()),manifest=manifest))
        for game in (['doom2'] if commercial else ['freedoom','ultimate']):
            cases=[(1,skill) for skill in range(5)]+([(7,2),(32,2)] if commercial else [(2,2),(9,2)])
            for map_,skill in cases:
                key=f'{game}-{map_}-{skill}';out=base/key/profile;out.mkdir(parents=True,exist_ok=True)
                cmd=[str(binary),str(wads[game]),str(out),str(commands),str(map_),str(skill),'0']
                r=subprocess.run(cmd,capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'})
                (out/'stdout.log').write_bytes(r.stdout);(out/'stderr.log').write_bytes(r.stderr)
                assert r.returncode==0 and not r.stderr,(key,profile,r.stderr.decode())
                summary=json.loads((out/'summary.json').read_text());ticks=(out/'ticks.bin').read_bytes();fields=player_records(ticks)[-1]
                actual=dict(game=game,map=map_,skill=skill,totalKills=summary['totalKills'],totalItems=summary['totalItems'],totalSecrets=fields['totalSecrets'],
                    leveltime=summary['leveltime'],prndindex=summary['prndindex'],health=summary['health'],x=summary['x'],y=summary['y'],ammo=[fields[k] for k in ['ammoClip','ammoShell','ammoCell','ammoMissile']],
                    ticksSha256=sha(ticks),difficultySha256=sha((out/'difficulty.bin').read_bytes()))
                # Whole pointer-free player/totals/difficulty records agree across compiler profiles.
                if key in canonical:assert canonical[key]==actual,(key,profile)
                else:canonical[key]=actual
                print('PASS original skill startup',key,profile,flush=True)
report.update(pass_=True,cases=list(canonical.values()),wadSha256=pins,endedUtc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),seconds=time.time()-started,
    scope='Original G_InitNew/P_SetupLevel and one original idle P_Ticker; no original menu/renderer/full-playthrough acceptance; no native data is injected into EVM.')
(base/'result.json').write_text(json.dumps(report,indent=2)+'\n')
