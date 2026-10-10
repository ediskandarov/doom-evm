#!/usr/bin/env python3
"""Focused Goal 4.12 gates; independent build exclusions never remove selected tests."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
TESTS = ['m_cheat', 'am_map', 'Cheats', 'AutomapVideo', 'InputRuntime',
         'ProductionUI', 'st_lib', 'st_stuff', 'hu_lib', 'hu_stuff', 'v_video',
         'p_inter', 'p_user', 'p_map', 'p_pspr', 'g_game', 'GameStorage',
         'StatusBar', 'HudMessages', 'VideoPrimitives', 'r_main', 'r_draw',
         'r_things', 'r_plane', 'RenderSequence']

def main():
    p=argparse.ArgumentParser();p.add_argument('--node-only',action='store_true');p.add_argument('--adapter-only',action='store_true');a=p.parse_args()
    if a.node_only:
        name='node';cmd=['node','--test','web/input-runtime.test.mjs','web/input.test.mjs','web/input-loop.test.mjs',
            'web/input-app.test.mjs','web/budget.test.mjs','tools/transport/ui-palette.test.mjs',
            'tools/transport/protocol.test.mjs','tools/transport/palette.test.mjs','tools/transport/lifecycle.test.mjs']
    else:
        name='adapter' if a.adapter_only else 'focused'
        allowed=['InputRuntime'] if a.adapter_only else TESTS
        paths=[f for f in sorted((ROOT/'test').rglob('*.t.sol')) if f.name[:-6] in allowed]
        assert all(any(f.name[:-6]==n for f in paths) for n in allowed), 'Missing requested test root'
        skips=[f.name for f in (ROOT/'test').rglob('*.t.sol') if f not in paths]
        cmd=['.toolchain/bin/forge','test','--offline','--fuzz-seed','0x412',
            '--match-path','{'+','.join(str(f.relative_to(ROOT)) for f in paths)+'}',
            '--skip','Doom.sol','--skip','GameplayProbe.sol','--skip','RendererProbe.sol','--skip','WadResourcesProbe.sol',
            *sum((['--skip',s] for s in skips),[]),'-vv']
    out=ROOT/'artifacts/local/input-runtime';out.mkdir(parents=True,exist_ok=True)
    start=time.time();r=subprocess.run(cmd,cwd=ROOT,capture_output=True)
    log=r.stdout+r.stderr;(out/(name+'.log')).write_bytes(log)
    result=dict(command=cmd,startedUtc=time.strftime('%Y-%m-%d %H:%M:%S UTC',time.gmtime(start)),
        seconds=time.time()-start,exitCode=r.returncode,logSha256=hashlib.sha256(log).hexdigest())
    (out/(name+'.json')).write_text(json.dumps(result,indent=2)+'\n')
    print(log.decode()[-5000:]);print(json.dumps(result));raise SystemExit(r.returncode)

if __name__=='__main__':main()
