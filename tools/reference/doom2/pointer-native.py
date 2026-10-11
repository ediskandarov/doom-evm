#!/usr/bin/env python3
"""Independently prove native ownership for the actual DOOM II virtual-source pixel."""
import ast,gzip,hashlib,json,os,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'tools/reference/speedrun'))
from replay import renderer,PUNITS
from verify_video import states
sha=lambda b:hashlib.sha256(b).hexdigest()
# Reuse the already audited observation hook, without running its old experiment.
tree=ast.parse((ROOT/'tools/reference/ultimate_speedruns/owner-native.py').read_text());hook=next(node.value.value for node in tree.body if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='hook' for t in node.targets))
base=ROOT/'artifacts/local/doom2/MAP01';evm=json.loads((base/'full-rate/evm.json').read_text());samples=[(f['tic'],s) for f in evm['frames'] for s in f['virtualSamples']];assert len(samples)==1
(tic,expected),=samples;assert tic==75 and expected['provenance']==5
out=base/'pointer-native';out.mkdir(exist_ok=True);report=dict(startUTC=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),scope='Original renderer/zone with read-only pointer observation; no fixed native mapping',profiles=[],virtualSample=expected)
for profile in ['O0','O2','sanitize']:
 build=out/('build-'+profile);shutil.copytree(base/'native-full'/('build-'+profile),build,dirs_exist_ok=True)
 p=build/'r_draw.c';s=p.read_text();needle='*dest = dc_colormap[dc_source[(frac>>FRACBITS)&127]];';assert s.count(needle)==2
 p.write_text('void OwnerSample(unsigned char*,int,unsigned char*,int,int,int,int);\n'+s.replace(needle,'OwnerSample(dc_source,(frac>>FRACBITS)&127,dest,dc_x,dc_yl,dc_yh,frac);\n'+needle,1))
 p=build/'z_zone.c';p.write_text(p.read_text()+'\n'+hook)
 m=json.loads((build/'single-capture-manifest.json').read_text());flags=[f.replace('<BUILD>',str(build)).replace('<HARNESS>',str(ROOT/'tools/reference')) for f in m['flags']]
 binary=build/'owner-sample';cmd=['clang',*flags,'-I'+str(build),*[str(build/n) for n in renderer.UNITS+PUNITS],str(build/'game_functions.c'),str(build/'episode-host.c'),'-Wl,-dead_strip','-o',str(binary)]
 r=subprocess.run(cmd,capture_output=True);(build/'pointer-build.log').write_bytes(r.stdout+r.stderr);assert r.returncode==0,r.stderr.decode()
 dest=out/profile;dest.mkdir(exist_ok=True);tape=(base/'level-commands.txt').read_text().splitlines()[:tic];(dest/'commands.txt').write_text('\n'.join(row.rsplit(' ',1)[0]+(' 1' if i+1==tic else ' 0') for i,row in enumerate(tape))+'\n')
 env={k:v for k,v in os.environ.items() if not k.startswith(('DOOM_','ASAN_','UBSAN_','Malloc','DYLD_'))};env.update(ASAN_OPTIONS='detect_leaks=0',SPEEDRUN_CAPTURE_TIC=str(tic),OWNER_PROBE_TIC=str(tic),OWNER_PROBE_DEST=str(expected['y']*320+expected['x']))
 cmd=[str(binary),str(Path.home()/'Downloads/doom-steam/base/doom2/DOOM2.WAD'),str(dest),str(dest/'commands.txt'),'1','3','0'];r=subprocess.run(cmd,capture_output=True,env=env);(dest/'stdout.log').write_bytes(r.stdout);(dest/'stderr.log').write_bytes(r.stderr);assert r.returncode==0 and not r.stderr,r.stderr.decode()
 rows=[json.loads(line[len('OWNER_SAMPLE '):]) for line in r.stdout.decode().splitlines() if line.startswith('OWNER_SAMPLE ')];assert len(rows)==1
 row=rows[0];native=states(gzip.decompress((base/'native-states.delta.bin.gz').read_bytes()),True);assert states((dest/'states.bin').read_bytes())==[native[0],native[tic]]
 assert row['slotIndex']==expected['ownerSlotIndex'] and row['sampleHeaderOffset']==expected['headerOffset'] and row['headerRelative']==expected['relative'] and row['sampleOffset']==expected['physicalOffset']
 assert row['slotStride']==8 and row['slotRelativeOffset']==expected['targetOffset'] and not row['slotInsideZone']
 ptr=int(row['slotAddress'],16);assert bytes.fromhex(row['headerPointerBytes'])==ptr.to_bytes(8,'little');assert row['sampleByte']==bytes.fromhex(row['headerPointerBytes'])[row['pointerByteIndex']]
 report['profiles'].append(dict(profile=profile,worldExact=True,observation=row,binarySHA256=sha(binary.read_bytes()),observedFrameSHA256=sha((dest/f'frame-{tic:06d}.bin').read_bytes())));print('PASS native owner-slot provenance',profile,row['slotIndex'],flush=True)
report.update(pass_=True,endUTC=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),verdict='Owner identity, stride and pointer representation proved. Absolute native addresses do not establish virtual byte/pixel equivalence.',hookSHA256=sha(hook.encode()))
(out/'proof.json').write_text(json.dumps(report,indent=2)+'\n');(ROOT/'artifacts/doom2/MAP01/pointer-native.json').write_text(json.dumps(report,indent=2)+'\n')
