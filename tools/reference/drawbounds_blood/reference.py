#!/usr/bin/env python3
"""Reproduce captured first blood-post sample using actual pinned C bodies."""
import hashlib,json,re,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent;SRC=ROOT/'original/DOOM/linuxdoom-1.10';FIX=ROOT/'test/fixtures/drawbounds_blood'
def body(path,name):
 s=path.read_text();m=re.search(r'void\s+'+name+r'\s*\([^)]*\)\s*\{',s);assert m,name
 at=m.end();depth=1
 while depth:
  depth+=(s[at]=='{')-(s[at]=='}');at+=1
 return s[m.start():at]
def run(args):return subprocess.check_output(args,stderr=subprocess.STDOUT)
zone=(SRC/'z_zone.c').read_text();assert zone.count('size = (size + 3) & ~3;')==1
zone=zone.replace('size = (size + 3) & ~3;','size = (size + 7) & ~7;')
rows=[]
with tempfile.TemporaryDirectory(prefix='doom-blood-native-') as td:
 p=Path(td);(p/'zone_generated.c').write_text(zone);(p/'draw_generated.c').write_text(body(SRC/'r_draw.c','R_DrawColumn'));(p/'masked_generated.c').write_text(body(SRC/'r_things.c','R_DrawMaskedColumn'))
 for profile,flags in [('O0',['-O0']),('O2',['-O2']),('sanitized',['-O2','-fsanitize=address,undefined','-fno-omit-frame-pointer'])]:
  exe=p/profile;run(['clang','-std=gnu11','-fsigned-char','-fwrapv','-fno-strict-aliasing','-ffp-contract=off','-fno-fast-math',*flags,'-I',str(SRC),'-I',str(p),str(HERE/'host.c'),'-o',str(exe)])
  for seed in [0,85,165]:
   row=json.loads(run([str(exe),str(FIX/'source.bin'),str(FIX/'colormap.bin'),str(seed)]));assert row['paddingBefore']==row['paddingAfter']==seed;assert row['firstPixel']==row['expectedPixel'];assert row['relativePhysicalAddress']==332;rows.append(dict(profile=profile,**row))
assert len({r['firstPixel'] for r in rows})==3
report={'scope':'Original unchanged renderer and allocator with accepted LP64 align8 adapter; controlled initial heap bytes demonstrate source-unwritten padding, not goldens for unmodified malloc. Zero-seed is the explicit deterministic platform profile.','pass':True,'rows':rows,'sourceHashes':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [SRC/'z_zone.c',SRC/'i_system.c',SRC/'r_draw.c',SRC/'r_things.c',HERE/'host.c',Path(__file__).resolve(),FIX/'source.bin',FIX/'colormap.bin']}}
(FIX/'native.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
