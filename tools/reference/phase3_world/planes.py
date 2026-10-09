#!/usr/bin/env python3
"""Exact endpoint/equality/crush/rollback coverage of unchanged original T_MovePlane."""
import argparse
import importlib.util
import json
import pathlib
import struct
import subprocess
import tempfile
HERE=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('world',HERE/'reference.py');world=importlib.util.module_from_spec(spec);spec.loader.exec_module(world)
p1=world.p1;FIX=world.FIX
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    inputs=[]
    for floor in [-32,0,32]:
      for ceiling in [64,128]:
       for speed in [0,1,16]:
        for dest in [-32,0,32,64,128]:
         for crush in [0,1]:
          for plane in [0,1]:
           for direction in [-1,1]:
            for obstruction in [0,1,2]:inputs.append([floor*65536,ceiling*65536,speed*65536,dest*65536,crush,plane,direction,obstruction])
    stdin=''.join(' '.join(map(str,a))+'\n' for a in inputs).encode();outputs=[]
    with tempfile.TemporaryDirectory(prefix='doom-world-planes-') as tmp:
        d=pathlib.Path(tmp);body,record=world.extract('p_floor.c','T_MovePlane')
        generated=(HERE/'plane_host.c').read_text()+'\n'+body+'\n'+(HERE/'plane_driver.c').read_text();path=d/'planes.c';path.write_text(generated)
        assert p1.invoke(['git','-C',str(p1.SOURCE),'rev-parse','HEAD']).strip()==p1.UPSTREAM
        assert not p1.invoke(['git','-C',str(p1.SOURCE),'diff','--name-only','HEAD'])
        assert p1.invoke(['clang','--version']).splitlines()[:2]==[p1.VERSION,'Target: '+p1.TARGET]
        flags=['-std=c11','-fsigned-char','-fwrapv','-fno-strict-aliasing']
        profiles={'O0':['-O0'],'O2':['-O2'],'sanitize':['-O2','-fsanitize=address,undefined','-fno-sanitize-recover=all']}
        for name,profile in profiles.items():
            p1.invoke(['clang',*flags,*profile,'-I'+str(p1.SOURCE),str(path),'-o',str(d/name)])
            result=subprocess.run([str(d/name)],input=stdin,capture_output=True,check=True);assert not result.stderr,result.stderr.decode();outputs.append(result.stdout)
    assert outputs[0]==outputs[1]==outputs[2] and len(outputs[0])==len(inputs)*52
    vectors=struct.pack('>I',len(inputs))+outputs[0]
    metadata={'schemaVersion':1,'upstreamCommit':p1.UPSTREAM,'compiler':p1.VERSION,'target':p1.TARGET,'flags':flags,'profiles':profiles,'caseCount':len(inputs),'extraction':record,'vectorsSha256':p1.sha(vectors),'generatedSourceSha256':p1.sha(generated.encode()),'harnessSha256':{f:p1.sha((HERE/f).read_bytes()) for f in ['planes.py','plane_host.c','plane_driver.c']},'scope':'all floor/ceiling directions x crush x three obstruction patterns x exact/undershoot/overshoot destination x zero/normal/large speeds; final plane heights/result and ordered callback hash'}
    if not args.check:FIX.mkdir(parents=True,exist_ok=True)
    for name,data in [('planes.bin',vectors),('planes.json',(json.dumps(metadata,indent=2)+'\n').encode())]:
        path=FIX/name
        if args.check:assert path.read_bytes()==data,'Fixture drift '+name
        else:path.write_bytes(data)
    print('PASS original T_MovePlane '+str(len(inputs))+'cases O0/O2/full ASan+UBSan exact')
if __name__=='__main__':main()
