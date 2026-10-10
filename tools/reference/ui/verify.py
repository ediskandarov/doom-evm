#!/usr/bin/env python3
"""Focused Goal 4.11 test roots; skipped build roots never remove tests in the gate."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT=Path(__file__).resolve().parents[3]
TESTS=['st_lib','st_stuff','hu_lib','hu_stuff','v_video','p_inter','p_user','p_pspr',
       'GameStorage','r_main','r_draw','r_things','r_plane','RenderSequence',
       'ProductionUI','StatusBar','HudMessages','VideoPrimitives']

def main():
    p=argparse.ArgumentParser();p.add_argument('--consumer-only',action='store_true');p.add_argument('--node-only',action='store_true');a=p.parse_args()
    if a.node_only:
        cmd=['node','--test','tools/transport/ui-palette.test.mjs','tools/transport/protocol.test.mjs',
             'tools/transport/palette.test.mjs','tools/transport/lifecycle.test.mjs','web/input-loop.test.mjs',
             'web/input-app.test.mjs','web/input.test.mjs','web/budget.test.mjs']
        start=time.time();r=subprocess.run(cmd,cwd=ROOT,capture_output=True)
        out=ROOT/'artifacts/local/ui';out.mkdir(parents=True,exist_ok=True);log=r.stdout+r.stderr
        (out/'node.log').write_bytes(log)
        (out/'node.json').write_text(json.dumps(dict(command=cmd,exitCode=r.returncode,seconds=time.time()-start,
            logSha256=hashlib.sha256(log).hexdigest()),indent=2)+'\n')
        print(log.decode()[-1200:]);raise SystemExit(r.returncode)
    allowed=['ProductionUI','st_stuff'] if a.consumer_only else TESTS
    paths=[f for f in (ROOT/'test').rglob('*.t.sol') if f.name[:-6] in allowed]
    skips=[f.name for f in (ROOT/'test').rglob('*.t.sol') if f not in paths]
    cmd=['.toolchain/bin/forge','test','--offline','--match-path','{'+','.join(str(f.relative_to(ROOT)) for f in paths)+'}',
         '--skip','GameplayProbe.sol','--skip','RendererProbe.sol','--skip','WadResourcesProbe.sol',
         '--skip','Doom.sol',*sum((['--skip',s] for s in skips),[]),'-vv']
    if a.consumer_only:cmd+=['--match-test','testConsumer']
    start=time.time();r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True)
    out=ROOT/'artifacts/local/ui';out.mkdir(parents=True,exist_ok=True)
    name='consumer' if a.consumer_only else 'focused'
    log=(r.stdout+r.stderr).encode();(out/(name+'.log')).write_bytes(log)
    result=dict(command=cmd,startedUtc=time.strftime('%Y-%m-%d %H:%M:%S UTC',time.gmtime(start)),
                seconds=time.time()-start,exitCode=r.returncode,logPath=str((out/(name+'.log')).relative_to(ROOT)),
                logSha256=hashlib.sha256(log).hexdigest(),testRoots=[str(f.relative_to(ROOT)) for f in paths])
    (out/(name+'.json')).write_text(json.dumps(result,indent=2)+'\n')
    print(r.stdout[-5000:]);print(r.stderr[-1000:]);print(json.dumps(result))
    raise SystemExit(r.returncode)

if __name__=='__main__':main()
