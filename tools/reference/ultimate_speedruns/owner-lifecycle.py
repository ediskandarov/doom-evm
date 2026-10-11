#!/usr/bin/env python3
"""Prove original allocator owner clearing, cache reuse and pointer layout."""
import hashlib,json,os,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];SRC=ROOT/'original/DOOM/linuxdoom-1.10';HERE=Path(__file__).parent
OUT=ROOT/'artifacts/local/ultimate-speedruns/owner-lifecycle';OUT.mkdir(exist_ok=True)
sha=lambda b:hashlib.sha256(b).hexdigest()
s=(SRC/'z_zone.c').read_text();assert s.count('size = (size + 3) & ~3;')==1
(OUT/'zone.c').write_text(s.replace('size = (size + 3) & ~3;','size = (size + 7) & ~7;'))
report=dict(sources={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in [SRC/'z_zone.c',SRC/'z_zone.h',HERE/'owner-lifecycle.c',Path(__file__)]},runs=[])
for name,flags in [('O0',['-O0']),('O2',['-O2']),('sanitize',['-O2','-fsanitize=address,undefined','-fno-sanitize-recover=all','-fno-omit-frame-pointer'])]:
 binary=OUT/name;cmd=['clang','-std=gnu11','-fsigned-char','-fwrapv','-fno-strict-aliasing',*flags,'-I'+str(SRC),'-I'+str(OUT),str(HERE/'owner-lifecycle.c'),'-o',str(binary)]
 c=subprocess.run(cmd,capture_output=True);assert c.returncode==0,c.stderr.decode()
 for repeat in range(2):
  c=subprocess.run([str(binary)],capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'});(OUT/(name+'-'+str(repeat)+'.log')).write_bytes(c.stdout+c.stderr);assert c.returncode==0 and not c.stderr,c.stdout.decode()+c.stderr.decode()
  rows=[json.loads(row) for row in c.stdout.splitlines()]
  for r in rows[:-1]:
   assert r['stride']==8 and r['relative']==r['index']*8 and r['slot']!=r['payload']
   assert bytes.fromhex(r['bytes'])==int(r['slot'],16).to_bytes(8,'little')
  assert len({r['slot'] for r in rows[:4]})==1
  report['runs'].append(dict(profile=name,repeat=repeat,buildCommand=cmd,binarySHA256=sha(binary.read_bytes()),observations=rows))
report.update(pass_=True,verdict='RESTRICT; owner identity/stride/lifetime stable; absolute addresses are observations only')
(OUT/'proof.json').write_text(json.dumps(report,indent=2)+'\n')
(ROOT/'artifacts/ultimate-speedruns/owner-pointer').mkdir(exist_ok=True)
(ROOT/'artifacts/ultimate-speedruns/owner-pointer/native-lifecycle.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(pass_=True,runs=len(report['runs']))))
