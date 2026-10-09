#!/usr/bin/env python3
"""Prove original generic donutRaise leaves its sector pointer unset; EV_DoDonut is separate."""
import argparse
import importlib.util
import json
import pathlib
import subprocess
import tempfile
HERE=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('world',HERE/'reference.py');world=importlib.util.module_from_spec(spec);spec.loader.exec_module(world)
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='doom-undefined-floor-') as tmp:
        d=pathlib.Path(tmp);world.build(d,HERE/'undefined_floor.c')
        result=subprocess.run([str(d/'sanitize')],capture_output=True)
        text=result.stderr.decode().replace(str(d),'<build>').replace(str(world.p1.SOURCE),'original/linuxdoom-1.10')
        assert result.returncode and 'member access within null pointer' in text,text
    data={'upstreamCommit':world.p1.UPSTREAM,'compiler':world.p1.VERSION,'target':world.p1.TARGET,
          'classification':'Original EV_DoFloor(donutRaise) does not initialize floor->sector; zero-heap profile reaches null sector dereference on first thinker tic. Actual EV_DoDonut constructs its own initialized donut floor payload.',
          'sanitizerDiagnostic':text.strip(),'sourceSha256':world.p1.sha((world.p1.SOURCE/'p_floor.c').read_bytes()),
          'probeSha256':world.p1.sha((HERE/'undefined_floor.c').read_bytes()),'harnessSha256':world.p1.sha((HERE/'undefined_floor.py').read_bytes())}
    path=world.FIX/'undefined-floor.json';blob=(json.dumps(data,indent=2)+'\n').encode()
    if args.check:assert path.read_bytes()==blob,'Undefined floor audit drift'
    else:path.write_bytes(blob)
    print('PASS original generic donutRaise undefined sector pointer separately audited')
if __name__=='__main__':main()
