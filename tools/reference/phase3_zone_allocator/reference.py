#!/usr/bin/env python3
"""Actual original z_zone.c sequence conformance; no gameplay results as inputs."""
from pathlib import Path
import argparse,hashlib,json,random,struct,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[3];SRC=ROOT/'original/DOOM/linuxdoom-1.10';HERE=Path(__file__).resolve().parent;OUT=ROOT/'test/fixtures/phase3_zone_allocator'
def sha(b):return hashlib.sha256(b).hexdigest()
def run(args,**kw):
 p=subprocess.run(args,capture_output=True,**kw)
 if p.returncode:raise RuntimeError(f"{args}: {p.stderr.decode(errors='replace')}")
 return p
def commands():
 r=random.Random(0x1D4A11);rows=[]
 for heap in [232,233,240,4096,8192,67108864]:
  rows.extend([(0,heap,0,0),(1,72,1,0),(2,0,0,0),(1,0,1,0),(2,0,0,0),(5,0,0,0),(6,0,0,0)])
 rows.extend([(0,1024,0,0),(1,64,1,0),(1,8,1,1),(5,0,0,0),(1,64,1,2),(2,2,0,0),(6,0,0,0),(0,512,0,0),(1,64,1,-1),(8,56,50,0),(7,56,0,0),(1,8,101,0),(3,100,255,0),(5,0,0,0)])
 for trial in range(64):
  rows.append((0,4096,0,0))
  for i in range(8):rows.append((1,r.randrange(380,421),101,i))
  rows.extend([(4,0,50,0),(4,0,101,0),(2,1,0,0),(2,3,0,0),(6,0,0,0)])
  if trial%2:rows.append((3,100,101,0))
  rows.extend([(1,1000,1,8),(2,8,0,0),(3,100,101,0),(5,0,0,0),(1,40,50,9),(1,48,51,10),(1,8,101,11),(3,50,51,0),(2,11,0,0),(6,0,0,0)])
 return rows
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
 pin=run(['git','rev-parse','HEAD'],cwd=SRC).stdout.decode().strip();assert pin=='a77dfb96cb91780ca334d0d4cfd86957558007e0'
 assert not run(['git','status','--porcelain'],cwd=SRC).stdout.strip()
 original=(SRC/'z_zone.c').read_text();patched=original.replace('size = (size + 3) & ~3;','size = (size + 7) & ~7;');assert patched!=original
 for old,new in [('block->id = 0;','block->id = 0; note(block, 1);'),('base->id = ZONEID;','base->id = ZONEID; note(base, 1);'),('newblock->size = extra;','newblock->size = extra; note(newblock, 0);')]:
  assert patched.count(old)==1;patched=patched.replace(old,new)
 failures=[]
 rows=commands();tape=''.join('%d %d %d %d\n'%row for row in rows).encode();outputs=[]
 with tempfile.TemporaryDirectory(prefix='doom-zone-') as td:
  temp=Path(td);(temp/'zone_generated.c').write_text(patched)
  for name,flags in [('O0',['-O0']),('O2',['-O2']),('sanitize',['-O2','-fsanitize=address,undefined','-fno-omit-frame-pointer'])]:
   exe=temp/name;run(['clang','-std=gnu11','-fsigned-char','-fwrapv','-fno-strict-aliasing','-ffp-contract=off','-fno-fast-math',*flags,'-I',str(SRC),'-I',str(temp),str(HERE/'host.c'),'-o',str(exe)])
   outputs.append(run([str(exe)],input=tape).stdout)
   probes=[("mallocUnownedCache",b"0 512 0 0\n1 8 101 -1\n","owner is required"),("changeUnownedCache",b"0 512 0 0\n1 8 1 -1\n8 56 100 0\n","owner is required"),("doubleFree",b"0 512 0 0\n1 8 1 -1\n7 56 0 0\n7 56 0 0\n","without ZONEID"),("exhaust",b"0 232 0 0\n1 72 1 -1\n1 0 1 -1\n","failed on allocation"),("corrupt",b"0 512 0 0\n1 8 1 -1\n9 0 0 0\n","back link")]
   for label,probe,message in probes:
    result=subprocess.run([str(exe)],input=probe,capture_output=True);text=result.stderr.decode();assert result.returncode==42 and message in text,(label,name,text);failures.append({"name":label,"profile":name,"exitCode":42,"originalError":text.strip()})
 assert outputs[0]==outputs[1]==outputs[2]
 data=outputs[0];pos=0;vectors=bytearray(struct.pack('>I',len(rows)))
 for row in rows:
  start=pos;count=struct.unpack_from('>I',data,pos+20)[0];pos+=(6+count*9+16)*4
  assert pos<=len(data);vectors+=struct.pack('>4iI',*row,pos-start)+data[start:pos]
 assert pos==len(data)
 manifest={'schemaVersion':1,'scope':'Actual original allocator linked-list/owner/core integer fields; zero initial backing and explicit known-ID observation masks. No pointer/padding/payload/header-overread proof.','upstreamCommit':pin,'commands':len(rows),'profiles':['O0','O2','ASan/UBSan'],'layout':{'memblock':40,'memzone':56,'alignment':8,'minFragment':64,'sentinelOffset':8,'idOffset':20,'validatedBy':'C _Static_assert sizeof/alignof/offsetof'},'inputSchema':'op,a,b,c. Owner16 slots; ops0init,1malloc,2free-owner,3freeTags,4changeTag-owner,5clear,6checkHeap,7free-header-offset,8changeTag-header-offset','outputSchema':'byteLength,roverOffset,capPrevOffset,capNextOffset,freeMemory,count; blocks[offset,size,allocated,owner,tag,idKnown,id-or0,prevOffset,nextOffset];16ownerPayloadOffsets. NULL=UINT32_MAX.','adaptations':['Original payload alignment4→8 for LP64 pointer-bearing headers','Read-only ID known-write observer after original alloc/free; split marker records original unset ID; no native field initialized by instrumentation'],'compiler':run(['clang','--version']).stdout.decode().splitlines()[:2],'numericFlags':['-std=gnu11','-fsigned-char','-fwrapv','-fno-strict-aliasing','-ffp-contract=off','-fno-fast-math'],'sourceHashes':{str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in [SRC/'z_zone.c',*sorted(SRC.glob('*.h')),HERE/'host.c',Path(__file__).resolve()]},'generatedSourceSha256':sha(patched.encode()),'goldSha256':sha(vectors),'fatalProbes':failures}
 generated={'vectors.bin':bytes(vectors),'commands.txt':tape,'manifest.json':(json.dumps(manifest,indent=2)+'\n').encode()}
 for name,b in generated.items():
  p=OUT/name
  if args.check:assert p.read_bytes()==b,name
  else:p.write_bytes(b)
 print(f'PASS original zone allocator: {len(rows)} sequence snapshots exact O0/O2/ASan/UBSan')
if __name__=='__main__':main()
