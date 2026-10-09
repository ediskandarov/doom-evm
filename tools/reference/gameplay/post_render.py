#!/usr/bin/env python3
"""Separate exact post-render observations; committed pre-render oracle stays unchanged."""
import argparse, gzip, json, os, pathlib, struct, subprocess, tempfile
from build import build, HERE, ref, renderer, PUNITS
from verify import delta_decode
FIXTURES=ref.ROOT/'test/fixtures/gameplay_post'
BASE=ref.ROOT/'test/fixtures/gameplay'
WAD=ref.ROOT/'artifacts/local/freedoom/freedoom1.wad'

def records(data):
    pos=0;rows=[]
    while pos<len(data):
        tic,size=struct.unpack_from('>II',data,pos);pos+=8
        payload=data[pos:pos+size];assert len(payload)==size and size%4==0;pos+=size
        rows.append(dict(tic=tic,bytes=size,sha256=ref.sha(payload)))
    assert pos==len(data);return rows

def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
    baseline=json.loads((BASE/'manifest.json').read_text());assert ref.sha(WAD.read_bytes())==baseline['resourceIdentity']['wadSha256']
    outputs={};metadata=None;cases=[]
    with tempfile.TemporaryDirectory(prefix='doom-post-render-') as temporary:
        temp=pathlib.Path(temporary);bins={}
        for profile,opt,san in [('O0','O0',False),('O2','O2',False),('asan','O2',True)]:
            out=temp/profile;build(out,opt,san)
            native=json.loads((out/'gameplay-build-manifest.json').read_text())
            flags=[flag.replace('<HARNESS>',str(HERE.parent)) for flag in native['flags']]
            cmd=['clang',*flags,'-I'+str(out),*[str(out/name) for name in renderer.UNITS+PUNITS],str(out/'game_functions.c'),str(HERE/'post_render_host.c'),'-Wl,-dead_strip','-o',str(out/'post-render')]
            result=subprocess.run(cmd,text=True,capture_output=True);assert result.returncode==0,result.stderr
            bins[profile]=out/'post-render'
            if profile=='O2':
                metadata=native;metadata['flags']=[flag.replace(str(out),'<BUILD>') for flag in metadata['flags']]
        for case in baseline['cases']:
            name=case['name'];setup=json.loads((BASE/name/'setup.json').read_text())['kind'];expected=None
            for profile,fill in [('O0','0'),('O2','0'),('asan','0'),('asan','0xa5')]:
                dest=temp/f'{name}-{profile}-{fill}';dest.mkdir()
                result=subprocess.run([str(bins[profile]),str(WAD),str(dest),str(BASE/name/'commands.txt'),setup],text=True,capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0','DOOM_ORACLE_ALLOCATION_FILL':fill})
                assert result.returncode==0 and not result.stderr,(name,profile,fill,result.stderr)
                # New observer must not change any accepted state, diagnostics, summary, event, or frame byte.
                assert (dest/'states.bin').read_bytes()==delta_decode(gzip.decompress((BASE/name/'states.delta.bin.gz').read_bytes()))
                for path in dest.iterdir():
                    if path.name not in ['states.bin','post-render.bin']:
                        assert path.read_bytes()==(BASE/name/path.name).read_bytes(),('observer changed accepted fixture',name,profile,path.name)
                current=(dest/'post-render.bin').read_bytes()
                if expected is None:expected=current
                else:assert current==expected,('post-render disagreement',name,profile,fill)
            rows=records(expected);assert [r['tic'] for r in rows]==[r['tic'] for r in case['frames']]
            outputs[name+'.bin.gz']=gzip.compress(expected,mtime=0);cases.append(dict(name=name,records=rows))
            print(f'PASS native post-render {name}: {len(rows)} states, unchanged pre-states/frames, four profiles exact',flush=True)
    outputs['manifest.json']=(json.dumps(dict(scope='Separate DSG1 immediately after selected original R_RenderPlayerView; rendering updates original ML_MAPPED and renderer globals. Existing pre-render fixtures unchanged.',upstreamCommit=ref.UPSTREAM,resourceIdentity=baseline['resourceIdentity'],profiles=['O0','O2','O2 ASan/UBSan','O2 ASan/UBSan allocation 0xa5'],encoding='gzip of [big-endian uint32 gametic, uint32 payload length, exact DSG1 payload] repeated for selected renders',cases=cases,native=metadata,sourceHashes={str(path.relative_to(ref.ROOT)):ref.sha(path.read_bytes()) for path in [HERE/'post_render.py',HERE/'post_render_host.c',HERE/'host.c',HERE/'observe.h',HERE/'build.py',BASE/'manifest.json']},files={name:ref.sha(data) for name,data in outputs.items()}),indent=2,sort_keys=True)+'\n').encode()
    for name,data in outputs.items():
        path=FIXTURES/name
        if a.check:assert path.read_bytes()==data,'stale post-render fixture '+name
        else:path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    print('PASS all24 native post-render observations')
if __name__=='__main__':main()
