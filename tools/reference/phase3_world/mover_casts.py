#!/usr/bin/env python3
"""Prove initialized int32 ceiling-speed/plat-count overlays; isolate a short-payload OOB."""
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
    with tempfile.TemporaryDirectory(prefix='doom-mover-casts-') as tmp:
        d=pathlib.Path(tmp);world.build(d,HERE/'mover_casts.c');out=[]
        for name in ['O0','O2','sanitize']:
            result=subprocess.run([str(d/name)],capture_output=True,check=True);assert not result.stderr;out.append(json.loads(result.stdout))
        assert out[0]==out[1]==out[2]
        result=subprocess.run([str(d/'sanitize'),'--flicker'],capture_output=True)
        diagnostic=result.stderr.decode().replace(str(d),'<build>').replace(str(world.p1.SOURCE),'original/linuxdoom-1.10')
        assert result.returncode and 'heap-buffer-overflow' in diagnostic
        # Addresses/process IDs vary. Retain only exact original frame and diagnostic class.
        sourceframes=[line.strip() for line in diagnostic.splitlines() if 'p_doors.c:' in line]
    data=out[0];data['upstreamCommit']=world.p1.UPSTREAM;data['profiles']='O0/O2/full ASan+UBSan exact'
    data['unsupportedLightPayload']={'classification':'AddressSanitizer heap-buffer-overflow: vldoor.direction offset48 reaches past sizeof(fireflicker_t)=48','originalSourceFrames':[line[line.index('original/linuxdoom-1.10'):] for line in sourceframes]}
    data['probeSha256']=world.p1.sha((HERE/'mover_casts.c').read_bytes());data['harnessSha256']=world.p1.sha((HERE/'mover_casts.py').read_bytes())
    data['sourceSha256']=world.p1.sha((world.p1.SOURCE/'p_doors.c').read_bytes());data['hostSha256']=world.p1.sha((HERE/'host.c').read_bytes())
    rows=[r for r in data['cases'] if r['kind']==4];vectors=struct.pack('>I',len(rows))
    for row in rows:vectors+=struct.pack('>III',int(row['player']),row['before']&0xffffffff,row['after']&0xffffffff)
    for name,blob in [('mover-casts.json',(json.dumps(data,indent=2)+'\n').encode()),('door-ceiling.bin',vectors)]:
        path=world.FIX/name
        if args.check:assert path.read_bytes()==blob,'Mover cast audit drift '+name
        else:path.write_bytes(blob)
    print('PASS original LP64 ceiling/plat overlays O0/O2/full ASan+UBSan; short light payload OOB separately audited')
if __name__=='__main__':main()
