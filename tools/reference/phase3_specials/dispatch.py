#!/usr/bin/env python3
"""All original special-number dispatch cases driving actual original world action units."""
import argparse, gzip, importlib.util, json, pathlib, struct, subprocess, tempfile
HERE=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('world',HERE.parent/'phase3_world/reference.py');world=importlib.util.module_from_spec(spec);spec.loader.exec_module(world)
spec=importlib.util.spec_from_file_location('special',HERE/'reference.py');special=importlib.util.module_from_spec(spec);spec.loader.exec_module(special)
def rows():
    matrix=json.loads((special.ref.ROOT/'test/fixtures/phase3_specials/dispatch-matrix.json').read_text())['functions'];out=[]
    for op,name in [(0,'P_CrossSpecialLine'),(1,'P_ShootSpecialLine'),(2,'P_UseSpecialLine')]:
        cases=sorted(set(matrix[name]['specials']+[0,145]+([124] if op==2 else [])))
        for kind in cases:
            for actor in [0,1,2]:
                for side in ([0] if op==1 else [0,1]):
                    for cards in ([0,63] if op==2 and actor==0 else [0]):
                        out.append([op,kind,0,actor,cards,0,3,side])
    for sector_special in range(18):out.append([3,sector_special,0,0,0,0,4,0])
    out += [[4,0,0,0,0,0,4,0],[4,0,0,1,0,0,4,0]]
    return out
def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');p.add_argument('--refresh-metadata',action='store_true');args=p.parse_args();inputs=rows();stdin=''.join(' '.join(map(str,a))+'\n' for a in inputs).encode()
    selected={'p_spec.c':['P_CrossSpecialLine','P_ShootSpecialLine','EV_DoDonut','P_SpawnSpecials','P_UpdateSpecials'],'p_switch.c':['P_StartButton','P_ChangeSwitchTexture','P_UseSpecialLine'],'p_telept.c':['EV_Teleport']}
    extra=[];records=[]
    for file,names in selected.items():
        for name in names:body,record=special.extract(file,name);extra.append(body);records.append(record)
    generated=(HERE/'dispatch_host.c').read_text()+'\n'+'\n'.join(extra)+'\n'+(HERE/'dispatch_driver.c').read_text();outputs=[]
    with tempfile.TemporaryDirectory(prefix='doom-dispatch-') as td:
        td=pathlib.Path(td);driver=td/'dispatch.c';driver.write_text(generated);world.UNITS=world.UNITS+['tables.c'];metadata=world.build(td,driver)
        # Teleport references original trigonometric symbols; no marker is spawned in this dispatch-only profile.
        for name,profile in metadata['profiles'].items():
            run=subprocess.run([str(td/name)],input=stdin,capture_output=True,check=True);assert not run.stderr,run.stderr.decode();outputs.append(run.stdout)
    assert all(o==outputs[0] for o in outputs),'Original dispatch profile divergence'
    raw=outputs[0];pos=0;vectors=bytearray(struct.pack('>I',len(inputs)));snapshots=0
    for a in inputs:
        assert list(struct.unpack_from('>8i',raw,pos))==a;pos+=32;count=struct.unpack_from('>I',raw,pos)[0];pos+=4;assert count==a[6]+1
        vectors.extend(struct.pack('>8iI',*a,count))
        for _ in range(count):
            for kind in ['world','overlay']:
                words=struct.unpack_from('>I',raw,pos)[0];pos+=4;data=raw[pos:pos+words*4];pos+=words*4;vectors.extend(bytes.fromhex(world.p1.sha(data)))
            snapshots+=1
    assert pos==len(raw)
    # The override driver is compiled instead of world/driver.c; omit that unused dependency.
    metadata['harnessSha256'].pop('driver.c',None)
    metadata.update(scope='All original numeric special switches, use guards, cross guards, shoot guards, donut, spawn-specials; actual original world movers/lights + linked thinkers; zero allocator profile; synthetic topology; no teleport marker in dispatch profile (success teleports covered separately)',scenarioCount=len(inputs),snapshotCount=snapshots,extractions=metadata['extractions']+records,harnessHashes={f:world.p1.sha((HERE/f).read_bytes()) for f in ['dispatch.py','dispatch_host.c','dispatch_driver.c','reference.py','generate_dispatch.py']},generatedExtraSourceSha256=world.p1.sha(generated.encode()),extraSources={f:world.p1.sha((world.p1.SOURCE/f).read_bytes()) for f in [*selected,'tables.c']},vectorsSha256=world.p1.sha(vectors),rawNativeSha256=world.p1.sha(raw))
    dest=special.ref.ROOT/'test/fixtures/phase3_specials';files={'dispatch-vectors.bin':bytes(vectors),'dispatch-native.bin.gz':gzip.compress(raw,mtime=0),'dispatch-manifest.json':(json.dumps(metadata,indent=2)+'\n').encode(),'dispatch-scenarios.json':(json.dumps(inputs,indent=2)+'\n').encode()}
    for file,value in files.items():
        if args.refresh_metadata and file=='dispatch-manifest.json':(dest/file).write_bytes(value)
        elif args.check or args.refresh_metadata:assert (dest/file).read_bytes()==value,file
        else:(dest/file).write_bytes(value)
    print(json.dumps({'result':'PASS','scenarios':len(inputs),'snapshots':snapshots,'native':'All original dispatch branches + actual original world action units; O0/O2/ASan/UBSan exact'}))
if __name__=='__main__':
    try:main()
    except subprocess.CalledProcessError as error:
        print(error.stderr.decode() if isinstance(error.stderr,bytes) else error.stderr);raise
