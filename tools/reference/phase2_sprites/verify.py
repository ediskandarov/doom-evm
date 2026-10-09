#!/usr/bin/env python3
"""Observe original r_things through the shared renderer builder; no rewritten oracle math."""
import argparse,importlib.util,json,pathlib,shutil,subprocess,sys,tempfile,os
HERE=pathlib.Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent))
import reference as ref
spec=importlib.util.spec_from_file_location('renderer_build',HERE.parent/'renderer/build.py');builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
ROOT=ref.ROOT

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    fixture=ROOT/'test/fixtures/phase2_sprites';outputs={};profiles=[]
    wad=ROOT/'artifacts/local/freedoom/freedoom1.wad'
    assert ref.sha(wad.read_bytes())==json.loads((ROOT/'test/fixtures/wad/snapshot.json').read_text())['resourceIdentity']['wadSha256']
    original_host=(builder.HERE/'host.c').read_text();observer=(HERE/'observe.c').read_text()
    host=original_host.replace('int main(int argc,char **argv) {',observer+'\nint main(int argc,char **argv) {').replace('        spawned++;','        if(spawned_count==4096) I_Error("observer capacity"); spawned_objects[spawned_count++]=obj;\n        spawned++;').replace('    geometry_outputs(argv[2]);','    geometry_outputs(argv[2]);\n    sprite_outputs(argv[2]);\n    if(camera.angle==0)sprite_edges(argv[2]);')
    assert host!=original_host
    with tempfile.TemporaryDirectory() as tmp:
        temp=pathlib.Path(tmp);harness=temp/'harness';harness.mkdir();(harness/'host.c').write_text(host);shutil.copyfile(builder.HERE/'trace.h',harness/'trace.h');builder.HERE=harness
        for opt,san in [('O0',False),('O2',False),('O2',True)]:
            exe=builder.build(temp/(opt+str(san)),opt,san)
            profile={}
            for angle in range(8):
                dest=temp/('scene'+str(angle));dest.mkdir(exist_ok=True)
                env=dict(os.environ);env['ASAN_OPTIONS']='detect_leaks=0'
                subprocess.run([str(exe),str(wad),str(dest),str(angle*0x20000000),'walls'],check=True,capture_output=True,env=env)
                for name in ['definitions.bin','things.bin','vissprites.bin','sorted.bin']+(['projection-edges.bin']+[f'draw-edge{i}.bin' for i in range(14)] if angle==0 else []):
                    key=f'angle{angle}/{name}' if name in ['vissprites.bin','sorted.bin'] else name
                    data=(dest/name).read_bytes()
                    if key in profile:assert profile[key]==data
                    profile[key]=data
            if outputs:assert outputs==profile,'native profile divergence'
            outputs=profile;profiles.append(dict(opt=opt,sanitize=san,manifest=json.loads((exe.parent/'build-manifest.json').read_text())))
    manifest=dict(upstreamCommit=ref.UPSTREAM,resourceIdentity=json.loads((ROOT/'test/fixtures/wad/snapshot.json').read_text())['resourceIdentity'],scope='Original sprite definitions; static spawn fields and sector order; BSP-collected projected vissprites and original stable sort at eight E1M1 angles. Observation only; never renderer inputs.',observerSha256=ref.sha(observer.encode()),generatorSha256=ref.sha(pathlib.Path(__file__).read_bytes()),baseHostSha256=ref.sha(original_host.encode()),profiles=profiles,files={k:ref.sha(v) for k,v in outputs.items()})
    outputs['manifest.json']=(json.dumps(manifest,indent=2)+'\n').encode()
    for key,data in outputs.items():
        path=fixture/key
        if args.check:assert path.read_bytes()==data,'stale '+key
        else:path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    print('PASS original sprite definitions/spawn/projection/sort: eight scenes, O0/O2/ASan+UBSan agree')
if __name__=='__main__':main()
