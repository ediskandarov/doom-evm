#!/usr/bin/env python3
"""Original r_data/p_setup bodies: native profile reuse, deterministic fixtures, explicit host ABI adapters."""
import importlib.util, pathlib, tempfile, json, argparse, subprocess, hashlib, struct, re
HERE=pathlib.Path(__file__).resolve().parent
ROOT=HERE.parents[2]
spec=importlib.util.spec_from_file_location('phase1_reference',HERE.parent/'reference.py')
ref=importlib.util.module_from_spec(spec);spec.loader.exec_module(ref)
FIX=ROOT/'test/fixtures/phase2_data'
PINS={'r_data.c':'0d0e83faec506d6bbf8d0a7aa5256b8e660f6deebc48c87d2c77bdb6ace4bf8d','w_wad.c':'a193860a2a1f671a680999aaa93ca294f90c9b1d6b5ba33152c0aa92000074a9','p_setup.c':'cc56c3ef5eb73aaec4db8be855fd3c192af19bf8f775478d002e9b2e9225872d','m_fixed.c':ref.PINS['m_fixed.c'],'r_defs.h':'d8856503bea02282f5f338f3533885e87c6c430ce4f11511d6a04b5fc040db31','doomdata.h':'f0504fd3926491ee56c61c8e9c732f0bf7e74306cba482eb267beda5022accca'}
FUNCTIONS=[('w_wad.c','W_CheckNumForName','int'),('w_wad.c','W_GetNumForName','int')]+[('r_data.c',n,t) for n,t in [('R_DrawColumnInCache','void'),('R_GenerateComposite','void'),('R_GenerateLookup','void'),('R_GetColumn','byte*'),('R_InitFlats','void'),('R_InitSpriteLumps','void'),('R_FlatNumForName','int'),('R_CheckTextureNumForName','int'),('R_TextureNumForName','int')]]+[('m_fixed.c','FixedDiv','fixed_t'),('m_fixed.c','FixedDiv2','fixed_t')]+[('p_setup.c',n,'void') for n in ['P_LoadVertexes','P_LoadSectors','P_LoadSideDefs','P_LoadLineDefs','P_LoadSegs','P_LoadSubsectors','P_LoadNodes']]
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');ap.add_argument('--wad',type=pathlib.Path,default=ROOT/'artifacts/local/freedoom/freedoom1.wad');a=ap.parse_args()
 assert ref.sha(a.wad.read_bytes())=='7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d'
 assert ref.invoke(['git','-C',str(ref.SOURCE),'rev-parse','HEAD']).strip()==ref.UPSTREAM
 for n,h in PINS.items():assert ref.sha((ref.SOURCE/n).read_bytes())==h,n
 version=ref.invoke(['clang','--version']).splitlines();assert version[:2]==[ref.VERSION,'Target: '+ref.TARGET]
 units=[];records=[]
 for file,name,result in FUNCTIONS:
  text=(ref.SOURCE/file).read_text()
  match=re.search(r'\n'+re.escape(result)+r'\s+'+name+r'\s*\(',text);assert match,name
  start=match.start()+1;end=text.index('{',match.end())+1;depth=1
  while depth:
   if text[end]=='{':depth+=1
   elif text[end]=='}':depth-=1
   end+=1
  body=text[start:end];record={'file':file,'function':name,'startLine':text[:start].count('\n')+1,'endLine':text[:end].count('\n')+1,'sha256':ref.sha(body.encode())}
  units.append(body);records.append(record)
 source='#include "compat.h"\n'+'\n'.join(units)+'\n#include "driver.c"\n'
 outputs={};runs={}
 with tempfile.TemporaryDirectory(prefix='doom-data-oracle-') as td:
  tmp=pathlib.Path(td);(tmp/'oracle.c').write_text(source)
  for opt in ['O0','O2','sanitize']:
   flags=[('-O0' if opt=='O0' and f=='-O2' else f) for f in ref.FLAGS]
   # Original p_setup negative signed shifts are UB; preserve pinned observed results, audit separately.
   if opt=='sanitize':flags += ['-fsanitize=undefined','-fno-sanitize=shift','-fno-sanitize-recover=all']
   ref.invoke(['clang',*flags,'-I'+str(HERE),str(tmp/'oracle.c'),'-o',str(tmp/opt)])
   paths=[tmp/(opt+'-'+n) for n in ['resources.bin','map.bin','clip.bin','getcolumns.bin']]
   ref.invoke([str(tmp/opt),str(a.wad),*map(str,paths)])
   ref.invoke([str(tmp/opt),'--subsector',str(tmp/(opt+'-subsector.bin'))])
   runs[opt]={n:p.read_bytes() for n,p in zip(['resources.bin','map.bin','clip.bin','getcolumns.bin'],paths)}
  assert (tmp/'O0-subsector.bin').read_bytes()==(tmp/'O2-subsector.bin').read_bytes()==(tmp/'sanitize-subsector.bin').read_bytes()
  outputs['subsector-signed.bin']=(tmp/'O2-subsector.bin').read_bytes()
  assert runs['O0']==runs['O2']==runs['sanitize'],'Native profile disagreement'
  outputs.update(runs['O2'])
  ref.invoke(['clang',*[f for f in ref.FLAGS if f!='-fwrapv'],'-fsanitize=undefined','-fno-sanitize-recover=all','-I'+str(HERE),str(tmp/'oracle.c'),'-o',str(tmp/'clip-sanitize')])
  ref.invoke([str(tmp/'clip-sanitize'),'--clip',str(tmp/'clip-strict.bin')])
  assert (tmp/'clip-strict.bin').read_bytes()==outputs['clip.bin']
  # Reduce the 7.5MiB native transcript to per-texture SHA-256 proofs; all raw bytes are regenerated above.
  raw=outputs['resources.bin'];pos=4;compact=bytearray(raw[:4])
  for i in range(struct.unpack_from('<I',raw)[0]):
   width,height,mask,size=struct.unpack_from('<4I',raw,pos);compact+=raw[pos:pos+16];pos+=16
   lookup=raw[pos:pos+width*8];pos+=width*8
   packed=raw[pos:pos+size*2];pos+=size*2
   valid=packed[::2];pixels=packed[1::2]
   compact+=hashlib.sha256(lookup).digest()+hashlib.sha256(pixels).digest()+struct.pack('<I',valid.count(0))
  compact+=raw[pos:];outputs['resources.bin']=bytes(compact)
 # Compact descriptor fixture, original bundle offsets and raw names; test etches needed chunks lazily.
 bundle=json.loads((ROOT/'artifacts/local/wad/bundle.json').read_text())
 outputs['directory.bin']=b''.join(bytes.fromhex(l['nameHex'])+struct.pack('<II',l['offset'],l['length']) for l in bundle['lumps'])
 metadata={'upstreamCommit':ref.UPSTREAM,'wadSha256':ref.sha(a.wad.read_bytes()),'compiler':ref.VERSION,'target':ref.TARGET,'flags':ref.FLAGS,'extractions':records,'sources':{f:ref.sha((ref.SOURCE/f).read_bytes()) for f in PINS},'shimSha256':{n:ref.sha((HERE/n).read_bytes()) for n in ['compat.h','driver.c','reference.py']},'generatedSourceSha256':ref.sha(source.encode()),'files':{n:ref.sha(b) for n,b in outputs.items()},'audit':{'p_setupSignedShift':'Negative signed left shifts are original C UB. Pinned O0/O2 results retained as documented extensions; sanitizer shift checks disabled only for this mixed map/sprite run. Composite-only clip bytes also match a separate full UBSan run without -fwrapv or suppressed shift checks.','uninitializedComposite':'Two native runs initialize fresh zone allocation with 0xa5 and 0x5a. Equal bytes are written/defined; unequal bytes explicitly marked unwritten. Solidity rejects requested textures containing any unwritten composite byte.','hostABI':'64-bit host runtime pointers; original disk structures packed 16/32-bit. R_InitTextures disk/allocator adapter is not presented as an extracted oracle. Lookup, composite, GetColumn, flat/sprite init, name and P_Load* bodies are verbatim.','memory':'Z_Free no-op for shared immutable input bytes; Z_Malloc otherwise ordinary allocation with explicit fill; no original pointer arithmetic changed.'}}
 outputs['manifest.json']=(json.dumps(metadata,indent=2)+'\n').encode()
 for n,b in outputs.items():
  p=FIX/n
  if a.check:assert p.read_bytes()==b,'Stale fixture '+str(p)
  else:p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
 print(json.dumps({'textures':struct.unpack_from('<I',outputs['resources.bin'])[0],'fixtures':{n:len(b) for n,b in outputs.items()},'nativeProfiles':['O0','O2','UBSan-except-signed-shift']},indent=2))
if __name__=='__main__':
 try:main()
 except subprocess.CalledProcessError as e:
  print(e.stdout or '');print(e.stderr or '');raise
