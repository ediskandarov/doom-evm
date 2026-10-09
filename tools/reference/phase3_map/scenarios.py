#!/usr/bin/env python3
"""Compile unchanged p_map/p_maputl/p_sight with explicit recorded higher-module hooks."""
import argparse, importlib.util, json, pathlib, struct, subprocess, tempfile
HERE=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('geom',HERE/'geometry.py');geom=importlib.util.module_from_spec(spec);spec.loader.exec_module(geom);ref=geom.ref
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');a=parser.parse_args()
    assert ref.invoke(['git','-C',str(ref.SOURCE),'rev-parse','HEAD']).strip()==ref.UPSTREAM
    assert not ref.invoke(['git','-C',str(ref.SOURCE),'diff','--name-only'])
    version=ref.invoke(['clang','--version']).splitlines();assert version[0]==ref.VERSION and version[1]=='Target: '+ref.TARGET
    sourceFiles=['p_map.c','p_maputl.c','p_sight.c','m_fixed.c','m_random.c','tables.c']
    extracted=[];bodies=[]
    for name in ['R_PointOnSide','R_PointToAngle','R_PointToAngle2','R_PointInSubsector']:
        body,meta=geom.extract('r_main.c',name);bodies.append(body);extracted.append(meta)
    geometry='#include "p_local.h"\n#include "r_state.h"\n#include "i_system.h"\n'+'\n'.join(bodies)+'\n'
    cases=[(op,v) for op,n in [(0,16),(1,16),(2,4),(3,2),(4,6),(5,6),(6,2),(7,4),(8,5),(9,4),(10,4)] for v in range(n)]
    cases += [(0,16),(5,6)] # Original shared globals can change in nested higher-module callbacks.
    commands=''.join(f'{op} {v}\n' for op,v in cases).encode();outputs=[];profiles=[]
    with tempfile.TemporaryDirectory(prefix='doom-map-scenarios-') as td:
        td=pathlib.Path(td);(td/'r_geometry.c').write_text(geometry)
        (td/'values.h').write_text('#include <limits.h>\n#include "doomtype.h"\n')
        for name,opt,sanitize in [('O0','-O0',False),('O2','-O2',False),('sanitized','-O2',True)]:
            flags=[opt if f=='-O2' else f for f in ref.FLAGS]+['-fsigned-char','-include','stdlib.h']
            if sanitize:flags+=['-fsanitize=address,undefined','-fno-sanitize-recover=all']
            ref.invoke(['clang',*flags,'-I'+str(td),'-I'+str(ref.SOURCE),*[str(ref.SOURCE/f) for f in sourceFiles],str(td/'r_geometry.c'),str(HERE/'scenario_host.c'),'-o',str(td/name)])
            run=subprocess.run([str(td/name)],input=commands,capture_output=True,check=True);outputs.append(run.stdout);profiles.append(dict(name=name,flags=flags,outputSha256=ref.sha(run.stdout)))
    assert all(o==outputs[0] for o in outputs),'Native scenario profile divergence'
    # Parse records by their original actor/callback counts; preserve variable observed lengths.
    data=outputs[0];p=0;encoded=bytearray(struct.pack('>I',len(cases)))
    for op,variant in cases:
        start=p;actors=struct.unpack_from('>I',data,p+9*4)[0];p+=4*(10+actors*17+8+16)
        calls=struct.unpack_from('>I',data,p)[0];p+=4*(1+calls)
        encoded.extend(struct.pack('>III',op,variant,(p-start)//4));encoded.extend(data[start:p])
    assert p==len(data)
    sourceFiles+=['r_main.c']
    manifest=dict(upstream=ref.UPSTREAM,compiler=ref.VERSION,target=ref.TARGET,cases=len(cases),sourceHashes={f:ref.sha((ref.SOURCE/f).read_bytes()) for f in sourceFiles},extractions=extracted,generatedGeometrySha256=ref.sha(geometry.encode()),harnessHashes={f:ref.sha((HERE/f).read_bytes()) for f in ['geometry.py','scenarios.py','scenario_host.c']},profiles=profiles,vectorSha256=ref.sha(encoded),scope='Full unchanged original map/maputl/sight units on declared synthetic map; higher-level gameplay side effects are recorded explicit mocks, not native engine substitution; whole-world gameplay oracle separately validates actual higher modules')
    dest=ref.ROOT/'test/fixtures/phase3_map';files={'scenarios.bin':bytes(encoded),'scenarios-manifest.json':(json.dumps(manifest,indent=2)+'\n').encode()}
    for name,value in files.items():
        if a.check:assert (dest/name).read_bytes()==value,name
        else:(dest/name).write_bytes(value)
    print(f'PASS original collision scenarios: {len(cases)} cases, O0/O2/ASan/UBSan exact')
if __name__=='__main__':
    try:main()
    except subprocess.CalledProcessError as error:
        print(error.stderr.decode() if isinstance(error.stderr,bytes) else error.stderr);raise
