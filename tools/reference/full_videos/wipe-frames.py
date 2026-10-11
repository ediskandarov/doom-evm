#!/usr/bin/env python3
"""Native-only comparison tool: actual original melt on independently rendered endpoints."""
import argparse,subprocess,hashlib,json,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];SRC=ROOT/'original/DOOM/linuxdoom-1.10'
ap=argparse.ArgumentParser();ap.add_argument('--start',type=Path,required=True);ap.add_argument('--end',type=Path,required=True);ap.add_argument('--seed',type=int,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();a.output.mkdir(parents=True,exist_ok=True)
pre=r'''
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef unsigned char byte;typedef int boolean;
#define true 1
#define false 0
#define PU_STATIC 1
static boolean go=0;static byte *wipe_scr_start,*wipe_scr_end,*wipe_scr,*screens[5];
extern int rndindex;int M_Random(void);
void *Z_Malloc(int n,int tag,void *owner){return malloc(n);}void Z_Free(void *p){free(p);}
void I_ReadScreen(byte *p){memcpy(p,screens[0],64000);}void V_DrawBlock(int x,int y,int scr,int w,int h,byte *p){memcpy(screens[scr],p,w*h);}void V_MarkRect(int x,int y,int w,int h){}
'''
body=(SRC/'f_wipe.c').read_text();body=body[body.index('void\nwipe_shittyColMajorXform'):]
host=r'''
static void readscreen(char *name){FILE *f=fopen(name,"rb");if(!f||fread(screens[0],1,64000,f)!=64000)abort();fclose(f);}
int main(int argc,char **argv){
 rndindex=atoi(argv[3]);for(int i=0;i<4;i++)screens[i]=malloc(64000);
 readscreen(argv[1]);wipe_StartScreen(0,0,320,200);readscreen(argv[2]);wipe_EndScreen(0,0,320,200);
 int done=0,count=0;while(!done){done=wipe_ScreenWipe(1,0,0,320,200,1);char name[4096];snprintf(name,sizeof(name),"%s/%03d-%d.indexed8",argv[4],++count,rndindex);FILE *f=fopen(name,"wb");fwrite(screens[0],1,64000,f);fclose(f);if(count>100)abort();}return 0;
}
'''
source=a.output/'wipe.c';source.write_text(pre+body+host);binary=a.output/'wipe-native';cmd=['clang','-std=c99','-O2','-fwrapv',str(source),str(SRC/'m_random.c'),'-o',str(binary)];subprocess.run(cmd,check=True);subprocess.run([str(binary),str(a.start.resolve()),str(a.end.resolve()),str(a.seed),str(a.output.resolve())],check=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();report=dict(seed=a.seed,startSHA256=sha(a.start),endSHA256=sha(a.end),sourceSHA256=sha(source),originalWipeSHA256=sha(SRC/'f_wipe.c'),originalRNGSHA256=sha(SRC/'m_random.c'),command=cmd,frames=[dict(file=p.name,sha256=sha(p)) for p in sorted(a.output.glob('*.indexed8'))]);(a.output/'manifest.json').write_text(json.dumps(report,indent=2)+'\n');print(len(report['frames']))
