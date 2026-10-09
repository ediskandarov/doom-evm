#!/usr/bin/env python3
"""Actual pinned allocator bytes plus original drawing; unknown bytes are not goldens."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[3];SRC=ROOT/'original/DOOM/linuxdoom-1.10';HERE=Path(__file__).resolve().parent;OUT=ROOT/'test/fixtures/phase3_zone_backing'
def sha(data):return hashlib.sha256(data).hexdigest()
def run(args,**kw):
 p=subprocess.run(args,capture_output=True,**kw)
 if p.returncode:raise RuntimeError(f'{args}: {p.stderr.decode(errors="replace")}')
 return p

def main():
 a=argparse.ArgumentParser();a.add_argument('--check',action='store_true');args=a.parse_args()
 assert run(['git','rev-parse','HEAD'],cwd=SRC).stdout.decode().strip()=='a77dfb96cb91780ca334d0d4cfd86957558007e0'
 assert not run(['git','status','--porcelain'],cwd=SRC).stdout.strip()
 zone=(SRC/'z_zone.c').read_text().replace('size = (size + 3) & ~3;','size = (size + 7) & ~7;')
 for old,new in [('block->id = 0;','block->id = 0; note(block, 1);'),('base->id = ZONEID;','base->id = ZONEID; note(base, 1);'),('newblock->size = extra;','newblock->size = extra; note(newblock, 0);')]:assert zone.count(old)==1;zone=zone.replace(old,new)
 original=(SRC/'r_draw.c').read_text();match=re.search(r'void R_DrawColumn\s*\(void\)\s*\{',original);assert match
 start=match.start();at=match.end();depth=1
 while depth:
  if original[at]=='{':depth+=1
  elif original[at]=='}':depth-=1
  at+=1
 draw=original[start:at];outputs=[]
 with tempfile.TemporaryDirectory(prefix='doom-backing-') as td:
  p=Path(td);(p/'zone_generated.c').write_text(zone);(p/'draw_generated.c').write_text(draw)
  for name,flags in [('O0',['-O0']),('O2',['-O2']),('sanitize',['-O2','-fsanitize=address,undefined','-fno-omit-frame-pointer'])]:
   exe=p/name;run(['clang','-std=gnu11','-fsigned-char','-fwrapv','-fno-strict-aliasing','-ffp-contract=off','-fno-fast-math',*flags,'-I',str(SRC),'-I',str(p),str(HERE/'host.c'),'-o',str(exe)])
   outputs.append(run([str(exe)]).stdout)
 assert outputs[0]==outputs[1]==outputs[2];data=outputs[0];assert len(data)==4+80*(20+256)
 meta={'schemaVersion':1,'scope':'Actual original LP64 zone integer headers and authenticated-shaped cached payload; original R_DrawColumn samples known header ID. Unknown bytes masked, no host pixel/heap data accepted by port.','upstream':'a77dfb96cb91780ca334d0d4cfd86957558007e0','cases':80,'profiles':['O0','O2','full ASan/UBSan'],'inputSchema':'16 payload lengths×5 successor kinds (cached resource, unowned, freed, fragment, donated slack); fields length/kind/tag/heapBytes; NULL pixel means no draw claim','outputSchema':'5BE32 input/pixel words then128value bytes and128known bytes; unknown values are comparison zero only, not claimed physical zero','layout':{'header':40,'idOffset':20,'alignment':8},'drawExtraction':{'function':'R_DrawColumn','startLine':original.count('\n',0,start)+1,'endLine':original.count('\n',0,at)+1,'sha256':sha(draw.encode())},'zoneGeneratedSha256':sha(zone.encode()),'compiler':run(['clang','--version']).stdout.decode().splitlines()[:2],'sourceHashes':{str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in [SRC/'z_zone.c',SRC/'r_draw.c',*sorted(SRC.glob('*.h')),HERE/'host.c',ROOT/'tools/reference/phase3_zone_allocator/host.c',Path(__file__).resolve()]},'goldSha256':sha(data)}
 for name,value in {'vectors.bin':data,'manifest.json':(json.dumps(meta,indent=2)+'\n').encode()}.items():
  target=OUT/name
  if args.check:assert target.read_bytes()==value,name
  else:target.write_bytes(value)
 print('PASS original zone backing:80cases +known integer-header drawing exact O0/O2/ASan/UBSan')
if __name__=='__main__':main()
