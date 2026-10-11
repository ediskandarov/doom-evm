#!/usr/bin/env python3
"""Original f_wipe.c extraction, independent native pixels/state/RNG; synthetic assets only."""
import hashlib,json,os,struct,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]; SRC=ROOT/'original/DOOM/linuxdoom-1.10'; OUT=ROOT/'test/fixtures/full_wipe'
sha=lambda b:hashlib.sha256(b).hexdigest()
text=(SRC/'f_wipe.c').read_text(); body=text[text.index('void\nwipe_shittyColMajorXform'):]
pre=r'''
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef unsigned char byte;
typedef int boolean;
#define false 0
#define true 1
#define PU_STATIC 1
static boolean go=0;
static byte *wipe_scr_start,*wipe_scr_end,*wipe_scr,*screens[5];
extern int rndindex;
int M_Random(void);
void *Z_Malloc(int n,int tag,void *user) {return malloc(n);}
void Z_Free(void *p) {free(p);}
void I_ReadScreen(byte *dest) {memcpy(dest,screens[0],64000);}
void V_DrawBlock(int x,int y,int scr,int width,int height,byte *src) {memcpy(screens[scr],src,width*height);}
void V_MarkRect(int x,int y,int width,int height) {}
'''
host=r'''
static void word(unsigned v) {byte b[]={v>>24,v>>16,v>>8,v};fwrite(b,1,4,stdout);}
int main(int argc,char **argv) {
 int seed=atoi(argv[1]),batch=atoi(argv[2]);rndindex=seed;
 screens[0]=malloc(64000);screens[2]=malloc(64000);screens[3]=malloc(64000);
 for(int i=0;i<64000;i++)screens[0][i]=(i*7+i/320)%256;
 wipe_StartScreen(0,0,320,200);
 for(int i=0;i<64000;i++)screens[0][i]=(i*11+73+i/160)%256;
 wipe_EndScreen(0,0,320,200);
 int done=0,count=0;
 while(!done) {
  done=wipe_ScreenWipe(1,0,0,320,200,batch);word(done);word(rndindex);word(done?0:320);
  if(!done)for(int i=0;i<320;i++)word(y[i]);
  fwrite(screens[0],1,64000,stdout);
  if(++count>100)abort();
 }
 return 0;
}
'''
OUT.mkdir(parents=True,exist_ok=True); manifest=dict(sourceSha256=sha(text.encode()),extractionSha256=sha(body.encode()),sourceStartLine=text[:text.index('void\nwipe_shittyColMajorXform')].count('\n')+1,adaptations=['Verbatim original f_wipe functions; C global pointers explicitly supplied; libc buffer allocation; I_ReadScreen/V_DrawBlock copies; dirtybox separately checked by Solidity consumer; deterministic synthetic start/end; no WAD artwork.'],profiles=[],cases=[])
with tempfile.TemporaryDirectory() as tmp:
 tmp=Path(tmp);(tmp/'driver.c').write_text(pre+body+host);baseline={}
 for profile,flags in [('O0',['-O0']),('O2',['-O2']),('sanitize',['-O2','-fsanitize=address,undefined','-fno-sanitize-recover=all'])]:
  cmd=['clang','-std=c99','-fwrapv',*flags,str(tmp/'driver.c'),str(SRC/'m_random.c'),'-o',str(tmp/profile)]
  subprocess.run(cmd,check=True);manifest['profiles'].append(dict(profile=profile,command=cmd))
  for seed,batch in [(0,1),(1,1),(127,1),(255,1),(0,3),(127,7),(255,200)]:
   raw=subprocess.check_output([str(tmp/profile),str(seed),str(batch)],env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'}); key=f'{seed}-{batch}'
   if profile!='O0':assert raw==baseline[key];continue
   baseline[key]=raw;pos=0;records=bytearray();count=0
   while pos<len(raw):
    done,rnd,n=struct.unpack_from('>III',raw,pos);pos+=12
    ys=struct.unpack_from('>'+str(n)+'i',raw,pos) if n else [];pos+=n*4
    abi=(32).to_bytes(32,'big')+n.to_bytes(32,'big')+b''.join((x%(1<<256)).to_bytes(32,'big') for x in ys)
    frame=raw[pos:pos+64000];pos+=64000
    records+=struct.pack('>II',done,rnd)+hashlib.sha256(abi).digest()+hashlib.sha256(frame).digest();count+=1
   (OUT/(key+'.bin')).write_bytes(records);manifest['cases'].append(dict(seed=seed,ticksPerStep=batch,steps=count,rawSha256=sha(raw),recordsSha256=sha(records)))
manifest['compiler']=subprocess.check_output(['clang','--version'],text=True).splitlines()[0];manifest['pass']=True
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(manifest['cases']))
