#!/usr/bin/env python3
"""Original allocator/draw proof for the declared low-48-bit native address domain."""
import hashlib, json, os, pathlib, re, subprocess, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[3];SRC=ROOT/'original/DOOM/linuxdoom-1.10'
sha=lambda b:hashlib.sha256(b).hexdigest()
s=(SRC/'r_draw.c').read_text();m=re.search(r'void\s+R_DrawColumn\s*\([^)]*\)\s*\{',s);end=m.end();depth=1
while depth:depth+=(s[end]=='{')-(s[end]=='}');end+=1
draw=s[m.start():end]
zone=(SRC/'z_zone.c').read_text();assert zone.count('size = (size + 3) & ~3;')==1
zone=zone.replace('size = (size + 3) & ~3;','size = (size + 7) & ~7;')
host=r'''
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include "r_local.h"
static byte *arena;
byte *I_ZoneBase(int *size) {*size=8192;arena=calloc(1,*size);return arena;}
void I_Error(char *fmt,...) {(void)fmt;abort();}
#include "zone.c"
int dc_x,dc_yl,dc_yh,centery;
fixed_t dc_iscale,dc_texturemid;
byte *dc_source;lighttable_t *dc_colormap;byte *ylookup[200];int columnofs[320];
#include "draw.c"
int main(void) {
 _Static_assert(sizeof(memblock_t)==40,"LP64 header");
 _Static_assert(offsetof(memblock_t,user)==8,"user at8");
 _Static_assert(sizeof(void*)==8,"LP64 pointers");
 Z_Init();void *owner1=0,*owner2=0;byte *p=Z_Malloc(512,PU_CACHE,&owner1);
 memset(p,165,512);Z_Malloc(4096,PU_CACHE,&owner2);
 memblock_t *b=((memblock_t*)(p-40))->next;
 uintptr_t pointers[3]={(uintptr_t)b->user,(uintptr_t)b->next,(uintptr_t)b->prev};
 for(int i=0;i<3;i++) if(pointers[i]>>48) return 3; // Profile guard, never assumed silently.
 byte screen[64000]={0},map[256];for(int i=0;i<256;i++)map[i]=(byte)i;
 for(int y=0;y<200;y++)ylookup[y]=screen+320*y;
 for(int x=0;x<320;x++)columnofs[x]=x;
 dc_x=287;dc_yl=dc_yh=139;centery=84;dc_iscale=9472;
 dc_texturemid=-33-(139-84)*dc_iscale;dc_source=p+400;dc_colormap=map;
 R_DrawColumn();
 if(screen[139*320+287]!=0||p[527]!=0) return 4;
 printf("{\"sample\":527,\"sourceLength\":512,\"sourceOffset\":400,\"frac\":-33,\"userByte7\":%u,\"pixel\":%u,\"allPointersBelow2Pow48\":true,\"userHighBytes\":[%u,%u],\"nextHighBytes\":[%u,%u],\"prevHighBytes\":[%u,%u]}\n",p[527],screen[139*320+287],((byte*)&b->user)[6],((byte*)&b->user)[7],((byte*)&b->next)[6],((byte*)&b->next)[7],((byte*)&b->prev)[6],((byte*)&b->prev)[7]);
 free(arena);return 0;
}
'''
rows=[]
with tempfile.TemporaryDirectory() as tmp:
    tmp=pathlib.Path(tmp);(tmp/'zone.c').write_text(zone);(tmp/'draw.c').write_text(draw);(tmp/'host.c').write_text(host)
    for profile,flags in [('O0',['-O0']),('O2',['-O2']),('san',['-O2','-fsanitize=address,undefined'])]:
        command=['clang','-std=gnu11','-fsigned-char','-fwrapv','-fno-strict-aliasing',*flags,'-I'+str(SRC),'-I'+str(tmp),str(tmp/'host.c'),'-o',str(tmp/profile)]
        subprocess.run(command,check=True,capture_output=True)
        result=subprocess.run([str(tmp/profile)],check=True,capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'})
        rows.append(dict(profile=profile,**json.loads(result.stdout)))
assert all({k:v for k,v in r.items() if k!='profile'}=={k:v for k,v in rows[0].items() if k!='profile'} for r in rows)
report=dict(pass_=True,kind='bounded-lp64-header-pointer-original-c',rows=rows,
    sourceHashes={'z_zone.c':sha((SRC/'z_zone.c').read_bytes()),'R_DrawColumn':sha(draw.encode()),'host':sha(host.encode()),'runner':sha(pathlib.Path(__file__).read_bytes())},
    scope='Captured E1M4 tail sample and current header pointer high-byte domain only. Low bytes, obsolete headers and bodies remain unknown. Original draw and zone bodies; accepted LP64 align8 adapter; no full frame or arbitrary process-address equivalence.')
out=ROOT/'artifacts/phase4/episode-completion/pointer-native.json';out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
