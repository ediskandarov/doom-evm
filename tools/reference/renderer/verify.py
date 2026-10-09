#!/usr/bin/env python3
"""Original-C wall/full world-view goldens, never an EVM completion claim."""
import argparse, hashlib, json, os, pathlib, re, struct, subprocess, tempfile, zlib
from build import build, ROOT, HERE, ref
FIXTURES=ROOT/'test/fixtures/renderer'
WAD=ROOT/'artifacts/local/freedoom/freedoom1.wad'

def encoded(value): return (json.dumps(value,indent=2)+'\n').encode()
def png(pixels,palette):
    def chunk(kind,data): return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data))
    raw=b''.join(b'\0'+b''.join(palette[v*3:v*3+3] for v in pixels[y*320:(y+1)*320]) for y in range(200))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',320,200,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b'')

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--check',action='store_true'); args=parser.parse_args()
    snapshot=json.loads((ROOT/'test/fixtures/wad/snapshot.json').read_text()); identity=snapshot['resourceIdentity']
    assert ref.sha(WAD.read_bytes())==identity['wadSha256']
    palette=bytes.fromhex(json.loads((ROOT/'test/fixtures/wad/palette.json').read_text())['rgbHex'])
    outputs={}; cases=[]
    with tempfile.TemporaryDirectory(prefix='doom-renderer-') as temporary:
        temp=pathlib.Path(temporary)
        binaries={profile:build(temp/profile,opt,sanitize,strict) for profile,opt,sanitize,strict in [('O0','O0',False,False),('O2','O2',False,False),('asan','O2',True,False),('strict','O2',True,True)]}
        native=json.loads((temp/'O2/build-manifest.json').read_text())
        outputs['build-manifest.json']=encoded(native)
        nativebuild=dict(compiler='clang',version=ref.VERSION,target=ref.TARGET,flags=native['flags'],patchSha256=ref.sha(ref.canonical(native['adaptations'])),harnessSha256=ref.sha(ref.canonical({name:ref.sha((HERE/name).read_bytes()) for name in ['build.py','host.c','trace.h','verify.py']})),integerSemantics='Pinned 32-bit signed -fwrapv/arithmetic-shift profile. Original negative-left-shift UB is audited separately. LP64 disk/pointer and visplane object-representation adapters are explicit.',doubleSemantics='Original FixedDiv2 binary64 expression; no fast math or contraction.')
        for mode in ['walls','full']:
            for angle_index in range(8):
                angle=angle_index*0x20000000; slug=f'{mode}-angle{angle_index}'
                baseline=None
                for profile,fill in [('O0','0'),('O2','0'),('asan','0'),('asan','0xa5')]:
                    dest=temp/f'{slug}-{profile}-{fill}'; dest.mkdir()
                    result=subprocess.run([str(binaries[profile]),str(WAD),str(dest),str(angle),mode],text=True,capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0','DOOM_ORACLE_ALLOCATION_FILL':fill})
                    assert result.returncode==0,(slug,profile,result.stderr)
                    assert not result.stderr,(slug,profile,result.stderr)
                    current={name:(dest/name).read_bytes() for name in ['pixels.bin','scene.json','trace.txt']}
                    assert len(current['pixels.bin'])==64000
                    if baseline is None: baseline=current
                    else: assert current==baseline,(slug,profile,fill,'native mismatch')
                scene=json.loads(baseline['scene.json'])
                metadata=dict(schemaVersion=0,resourceIdentity=identity,provenance=dict(kind='wad',wadName='Freedoom Phase 1 v0.13.0',wadSha256=identity['wadSha256'],upstreamCommit=ref.UPSTREAM,license='BSD-3-Clause',map='E1M1',build=nativebuild),scope='world-view',camera={**{key:scene[key] for key in ['x','y','z','angle']},'coordinateFormat':'signed-16.16','angleFormat':'binary-angle-uint32'},detail='high',colormap=0,lighting=dict(extraLight=0,fixedColormap=-1),gametic=0,width=320,height=200,frameSha256=ref.sha(baseline['pixels.bin']))
                # Existing strict reference-v0 validator, including WAD/camera/pixel identity.
                import sys
                sys.path.insert(0,str(HERE.parent)); import pixel_diff
                pixel_diff.validate_reference(metadata,baseline['pixels.bin'])
                for name,data in baseline.items(): outputs[slug+'/'+name]=data
                outputs[slug+'/reference.json']=encoded(metadata)
                outputs[slug+'/frame.png']=png(baseline['pixels.bin'],palette)
                cases.append(dict(name=slug,mode=mode,angle=angle,frameSha256=metadata['frameSha256'],traceSha256=ref.sha(baseline['trace.txt']),scene=scene))
        auditdest=temp/'strict-audit'; auditdest.mkdir()
        result=subprocess.run([str(binaries['strict']),str(WAD),str(auditdest),'0','full'],text=True,capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'})
        assert result.returncode!=0 and 'left shift of negative value' in result.stderr
        diagnostic=re.search(r'r_data.c:\d+:\d+: runtime error: [^\n]+',result.stderr).group(0)
        outputs['undefined-audit.json']=encoded(dict(profile='strict ISO C UBSan without -fwrapv',expectedFailure=diagnostic,interpretation='Native full-render goldens are equivalence to the explicitly pinned implementation profile, not a claim that original renderer is free of ISO C undefined behavior. Earlier independent foundation vectors retain their stricter defined-C claims.'))
    outputs['manifest.json']=encoded(dict(upstreamCommit=ref.UPSTREAM,resourceIdentity=identity,scope='Original full-screen world view including WAD sprites and masked walls; no player weapon overlay, HUD, gameplay ticks or EVM rendering claim. Wall-only intermediate deliberately omits planes and masked pass.',scenePolicy='E1M1 player start, stationary floor+41 clamped to ceiling-4; original medium-skill single-player mapthing spawnstate rendering fields, no state action/tick. Eight ANG45 viewpoints. Native renders all visibility in original C.',verifiedProfiles=['O0 -fwrapv','O2 -fwrapv','O2 ASan/UBSan -fwrapv','O2 ASan/UBSan -fwrapv with 0xa5 allocation fill'],cases=cases,files={name:ref.sha(data) for name,data in sorted(outputs.items())}))
    if args.check:
        for name,data in outputs.items(): assert (FIXTURES/name).read_bytes()==data, 'stale reference '+name
    else:
        for name,data in outputs.items():
            path=FIXTURES/name; path.parent.mkdir(parents=True,exist_ok=True); path.write_bytes(data)
    print(f'PASS {len(cases)} original C wall/world-view fixtures; O0/O2/ASan and allocation-fill agreement; strict UB audit')
if __name__=='__main__': main()
