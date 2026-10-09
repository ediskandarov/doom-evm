// SPDX-License-Identifier: GPL-2.0-only
// Native host for the unchanged original renderer. Platform and static scene setup only.
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "doomdef.h"
#include "doomstat.h"
#include "r_local.h"
#include "r_sky.h"
#include "w_wad.h"
#include "z_zone.h"
#include "p_local.h"
#include "info.h"

static FILE *tracefile;
void OracleTrace(const char *function,int a,int b) { if(tracefile) fprintf(tracefile,"%s %d %d\n",function,a,b); }
byte *screens[5];
int detailLevel=0, screenblocks=11;
int consoleplayer=0, displayplayer=0;
int leveltime=0;
boolean demoplayback=false;
player_t players[MAXPLAYERS];
thinker_t thinkercap;
void I_Error(char *format,...) { va_list ap; va_start(ap,format); vfprintf(stderr,format,ap); va_end(ap); fputc('\n',stderr); exit(2); }
void *Z_Malloc(int size,int tag,void *user) {
    if(size<0) I_Error("negative allocation");
    memblock_t *block=calloc(1,sizeof(*block)+(size_t)size);
    if(!block) I_Error("allocation failed");
    block->size=size; block->tag=tag; block->id=0x1d4a11; block->user=user;
    void *p=block+1; const char *fill=getenv("DOOM_ORACLE_ALLOCATION_FILL");
    if(fill) memset(p,(unsigned char)strtoul(fill,NULL,0),(size_t)size);
    if(user) *(void**)user=p; return p;
}
void Z_Free(void *ptr) { memblock_t *b=(memblock_t*)ptr-1; if(b->id!=0x1d4a11) I_Error("bad free"); if(b->user) *b->user=NULL; free(b); }
void Z_ChangeTag2(void *ptr,int tag) { ((memblock_t*)ptr-1)->tag=tag; }
void NetUpdate(void) {}
void I_BeginRead(void) {}
void I_EndRead(void) {}
void V_MarkRect(int x,int y,int width,int height) {}
void V_DrawPatch(int x,int y,int screen,patch_t *patch) { I_Error("Unexpected border draw"); }
void P_MobjThinker(mobj_t *mobj) { I_Error("Unexpected simulation"); }

void P_LoadVertexes(int); void P_LoadSectors(int); void P_LoadSideDefs(int); void P_LoadLineDefs(int);
void P_LoadSubsectors(int); void P_LoadNodes(int); void P_LoadSegs(int);
extern char *sprnames[];
extern vissprite_t vissprites[], *vissprite_p;
extern visplane_t visplanes[], *lastvisplane;
static void writefile(const char *directory,const char *name,const void *data,size_t size) {
    char path[4096]; snprintf(path,sizeof(path),"%s/%s",directory,name);
    FILE *f=fopen(path,"wb"); if(!f || fwrite(data,1,size,f)!=size) I_Error("write %s",path); fclose(f);
}

int main(int argc,char **argv) {
    if(argc<3) I_Error("renderer WAD output-directory [angle-uint32] [walls|full]");
    char *files[]={argv[1],NULL}; W_InitMultipleFiles(files);
    gamemode=retail; gamemission=doom;
    screens[0]=calloc(1,320*200); screens[1]=calloc(1,320*200);
    char *sprite_names[NUMSPRITES+1];
    memcpy(sprite_names,sprnames,NUMSPRITES*sizeof(*sprite_names)); sprite_names[NUMSPRITES]=NULL;
    R_Init(); R_InitSprites(sprite_names); R_ExecuteSetViewSize();
    skyflatnum=R_FlatNumForName("F_SKY1"); skytexture=R_TextureNumForName("SKY1");
    int map=W_GetNumForName("E1M1");
    P_LoadVertexes(map+ML_VERTEXES); P_LoadSectors(map+ML_SECTORS); P_LoadSideDefs(map+ML_SIDEDEFS);
    P_LoadLineDefs(map+ML_LINEDEFS); P_LoadSubsectors(map+ML_SSECTORS); P_LoadNodes(map+ML_NODES); P_LoadSegs(map+ML_SEGS);
    // Same first stage as P_GroupLines. Remaining group fields support collision/sound only.
    for(int i=0;i<numsubsectors;i++) subsectors[i].sector=segs[subsectors[i].firstline].sidedef->sector;
    int thingslump=map+ML_THINGS; mapthing_t *things=W_CacheLumpNum(thingslump,PU_STATIC);
    int count=W_LumpLength(thingslump)/sizeof(*things); mobj_t camera={0}; int spawn=0, spawned=0;
    for(int i=0;i<count;i++) {
        mapthing_t *t=things+i;
        if(t->type==1) { camera.x=(int32_t)t->x*65536; camera.y=(int32_t)t->y*65536; camera.angle=(t->angle/45)*ANG45; spawn=1; continue; }
        if(t->type<=4 || t->type==11 || (t->options&16) || !(t->options&2)) continue;
        int type; for(type=0;type<NUMMOBJTYPES;type++) if(mobjinfo[type].doomednum==t->type) break;
        if(type==NUMMOBJTYPES) I_Error("Unknown mapthing %d",t->type);
        // Static spawnstate projection, equivalent initial rendering fields of P_SpawnMobj.
        mobj_t *obj=calloc(1,sizeof(*obj)); obj->type=type; obj->info=mobjinfo+type;
        obj->x=(int32_t)t->x*65536; obj->y=(int32_t)t->y*65536; obj->angle=(t->angle/45)*ANG45;
        obj->flags=obj->info->flags; obj->height=obj->info->height; obj->radius=obj->info->radius;
        obj->state=states+obj->info->spawnstate; obj->sprite=obj->state->sprite; obj->frame=obj->state->frame;
        obj->subsector=R_PointInSubsector(obj->x,obj->y); sector_t *sector=obj->subsector->sector;
        obj->z=(obj->flags&MF_SPAWNCEILING)?sector->ceilingheight-obj->height:sector->floorheight;
        if(!(obj->flags&MF_NOSECTOR)) { obj->snext=sector->thinglist; if(obj->snext) obj->snext->sprev=obj; sector->thinglist=obj; }
        spawned++;
    }
    if(!spawn) I_Error("No player start");
    if(argc>3) camera.angle=(uint32_t)strtoul(argv[3],NULL,0);
    camera.subsector=R_PointInSubsector(camera.x,camera.y); camera.player=players;
    players[0].mo=&camera; players[0].viewz=camera.subsector->sector->floorheight+41*FRACUNIT;
    if(players[0].viewz>camera.subsector->sector->ceilingheight-4*FRACUNIT) players[0].viewz=camera.subsector->sector->ceilingheight-4*FRACUNIT;
    char tracepath[4096]; snprintf(tracepath,sizeof(tracepath),"%s/trace.txt",argv[2]); tracefile=fopen(tracepath,"w"); if(!tracefile) I_Error("trace output");
    // Camera-only static scene: no player psprite/HUD, no gameplay actions or time advancement.
    if(argc>4 && !strcmp(argv[4],"walls")) { R_SetupFrame(players); R_ClearClipSegs(); R_ClearDrawSegs(); R_ClearPlanes(); R_ClearSprites(); R_RenderBSPNode(numnodes-1); }
    else R_RenderPlayerView(players);
    fclose(tracefile); tracefile=NULL;
    writefile(argv[2],"pixels.bin",screens[0],64000);
    char summary[2048]; int len=snprintf(summary,sizeof(summary),"{\"x\":%d,\"y\":%d,\"z\":%d,\"angle\":%u,\"spawnedThings\":%d,\"drawsegs\":%ld,\"visplanes\":%ld,\"vissprites\":%ld,\"subsectors\":%d}\n",viewx,viewy,viewz,viewangle,spawned,(long)(ds_p-drawsegs),(long)(lastvisplane-visplanes),(long)(vissprite_p-vissprites),sscount);
    writefile(argv[2],"scene.json",summary,len);
    return 0;
}
