#!/usr/bin/env python3
"""Measured original allocation-byte domains, LP64 door/plat overlap and fatal registry errors."""
import argparse
import importlib.util
import json
import pathlib
import struct
import subprocess
import tempfile
HERE=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('world',HERE/'reference.py');world=importlib.util.module_from_spec(spec);spec.loader.exec_module(world)
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='doom-world-domains-') as tmp:
        d=pathlib.Path(tmp);world.build(d,HERE/'domains.c');out=[]
        for name in ['O0','O2','sanitize']:
            result=subprocess.run([str(d/name)],capture_output=True,check=True);assert not result.stderr;out.append(json.loads(result.stdout))
        assert out[0]==out[1]==out[2]
    data=out[0];data['upstreamCommit']=world.p1.UPSTREAM;data['profiles']='O0/O2/full ASan+UBSan exact'
    data['probeSha256']=world.p1.sha((HERE/'domains.c').read_bytes());data['harnessSha256']=world.p1.sha((HERE/'domains.py').read_bytes())
    data['hostSha256']=world.p1.sha((HERE/'host.c').read_bytes())
    rows=data['incompatibleDoorPlat']['cases'];vectors=struct.pack('>I',len(rows))
    for row in rows:vectors+=struct.pack('>III',int(row['player']),row['countBefore']&0xffffffff,row['countAfter']&0xffffffff)
    for name,blob in [('original-domains.json',(json.dumps(data,indent=2)+'\n').encode()),('door-plat.bin',vectors)]:
        path=world.FIX/name
        if args.check:assert path.read_bytes()==blob,'Domain fixture drift '+name
        else:path.write_bytes(blob)
    print('PASS original domain audit and four LP64 door/plat cases; O0/O2/full ASan+UBSan exact')
if __name__=='__main__':main()
