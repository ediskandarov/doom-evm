#!/usr/bin/env python3
"""Actual original ST_Drawer size-refresh history, comparison-only for the browser gate."""
import hashlib,importlib.util,json,os,struct,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];SOURCE=ROOT/'original/DOOM/linuxdoom-1.10'
spec=importlib.util.spec_from_file_location('original_status_reference',ROOT/'tools/reference/statusbar/reference.py')
st=importlib.util.module_from_spec(spec);spec.loader.exec_module(st)
base=ROOT/'artifacts/local/options/status-resize-native';base.mkdir(parents=True,exist_ok=True)
sha=lambda b:hashlib.sha256(b).hexdigest()
sources=['st_lib','v_video','m_bbox','m_random','r_main','tables','d_items','m_cheat']
report=dict(startedUtc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),profiles=[],games={})
rows=[]
for values in [dict(op=0),dict(op=0,cheats=2),dict(op=2,cheats=2,fullscreen=1,refresh=1),dict(op=2,cheats=2,fullscreen=0,refresh=1)]:
    d={**st.DEFAULT,**values};rows.append([d[k] for k in st.FIELDS])
inputs=base/'inputs.bin';inputs.write_bytes(struct.pack('>I',len(rows))+b''.join(struct.pack('>36i',*r) for r in rows))
for game,wad in [('freedoom','artifacts/local/freedoom/freedoom1.wad'),('ultimate','artifacts/local/options/DOOM.WAD'),('doom2','artifacts/local/options/DOOM2.WAD')]:
    out=base/game;out.mkdir(exist_ok=True);b=(ROOT/wad).read_bytes();count,offset=struct.unpack_from('<II',b,4)
    # Immutable original WAD borrowing only; extraction never changes palette or patch bytes.
    for i in range(count):
        pos,size,name=struct.unpack_from('<II8s',b,offset+i*16);name=name.rstrip(b'\0').decode('ascii')
        if name.startswith(('ST','PLAYPAL')):(out/(name+'.bin')).write_bytes(b[pos:pos+size])
    report['games'][game]=dict(wadSha256=sha(b),outputs={})
canonical={}
for label,flags in [('O0',['-O0']),('O2',['-O2']),('sanitized',['-O1','-g','-fsanitize=address,undefined','-fno-sanitize=array-bounds','-fno-sanitize-recover=all'])]:
    binary=base/label;cmd=['clang','-std=c11','-fwrapv','-ffunction-sections','-fdata-sections','-include',str(SOURCE/'doomdef.h'),'-I',str(ROOT/'tools/reference/statusbar'),'-I',str(SOURCE),*flags,
        str(ROOT/'tools/reference/statusbar/host.c'),*[str(SOURCE/(n+'.c')) for n in sources],'-Wl,-dead_strip','-o',str(binary)]
    r=subprocess.run(cmd,capture_output=True);assert r.returncode==0,r.stderr.decode();profile=dict(profile=label,command=cmd,binarySha256=sha(binary.read_bytes()),outputs={})
    for game in report['games']:
        r=subprocess.run([str(binary),str(inputs),str(base/game)],capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'});assert r.returncode==0 and not r.stderr,r.stderr.decode()
        assert len(r.stdout)==4*75104
        if game in canonical:assert r.stdout==canonical[game],(game,label)
        else:canonical[game]=r.stdout
        profile['outputs'][game]=sha(r.stdout)
    report['profiles'].append(profile)
for game,raw in canonical.items():
    prior=raw[75104+96+320*168:75104+64096];restored=raw[3*75104+96+320*168:3*75104+64096]
    differences=sum(a!=b for a,b in zip(prior,restored))
    assert len(prior)==len(restored)==10240
    for name,payload in [('prior.pixels',prior),('restored.pixels',restored)]:
        (base/game/name).write_bytes(payload);report['games'][game]['outputs'][name]=sha(payload)
    report['games'][game].update(originalRefreshChangedPixels=differences,face=struct.unpack_from('>i',raw,3*75104+4)[0])
report.update(pass_=True,sourceSha256={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in [SOURCE/(n+'.c') for n in sources+['st_stuff']]})
report['sourceSha256'].update({str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in [ROOT/'tools/reference/statusbar/host.c',ROOT/'tools/reference/statusbar/values.h',Path(__file__).resolve()]})
report['endedUtc']=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime());(base/'result.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({g:r['originalRefreshChangedPixels'] for g,r in report['games'].items()}))
