/* SPDX-License-Identifier: GPL-2.0-only
 * Observations/platform boundaries only. Original algorithms are in generated
 * translation units; every run owns its directory and ordinary save files. */
#include <sys/stat.h>
int chdir(const char *);
#include "d_net.h"
#include "dstrings.h"
#include "p_saveg.h"
boolean respawnparm=false,fastparm=false,nomonsters=false,secretexit=false;
boolean menuactive=false;
gamestate_t wipegamestate=GS_DEMOSCREEN;
int ticdup=1,maketic=0;ticcmd_t netcmds[MAXPLAYERS][BACKUPTICS];
extern char *player_names[4];
extern boolean sendsave,sendpause,usergame,viewactive,demorecording,netdemo;
extern boolean gamekeydown[256];extern int turnheld,key_up,key_down,key_left,key_right,key_fire,key_use,key_speed,key_strafe,key_strafeleft,key_straferight;
extern int levelstarttic,starttime,savegameslot,fuzzpos,framecount;
extern char savedescription[32];extern byte *savebuffer;
extern boolean setsizeneeded;
extern plat_t *activeplats[MAXPLATS];extern ceiling_t *activeceilings[MAXCEILINGS];extern button_t buttonlist[MAXBUTTONS];
void Original_G_DoSaveGame(void);void Original_G_DoLoadGame(void);
void Original_G_InitNew(skill_t,int,int);void Original_G_DoLoadLevel(void);
void G_InitNew(skill_t,int,int);void G_DoSaveGame(void);void G_DoLoadGame(void);void G_DoLoadLevel(void);void G_Ticker(void);
/* These branches are not in the bounded single-player GS_LEVEL corpus. */
void G_DoPlayDemo(void){I_Error("excluded demo");}
void G_ReadDemoTiccmd(ticcmd_t *c){(void)c;I_Error("excluded demo");}
void G_WriteDemoTiccmd(ticcmd_t *c){(void)c;I_Error("excluded demo");}
void D_PageTicker(void){I_Error("excluded title ticker");}
void M_ScreenShot(void){I_Error("excluded screenshot");}
void WI_Start(wbstartstruct_t *w){(void)w;I_Error("excluded intermission");}
void WI_Ticker(void){I_Error("excluded intermission");}
void F_StartFinale(void){I_Error("excluded finale");}
void F_Ticker(void){I_Error("excluded finale");}
void S_PauseSound(void){}void S_ResumeSound(void){}
void S_ChangeMusic(int music,int looping){(void)music;(void)looping;}
int I_GetTime(void){return 123456;}
ticcmd_t *I_BaseTiccmd(void){static ticcmd_t base;memset(&base,0,sizeof(base));return &base;}

static FILE *records,*allocationfile;static int rows,ready;
typedef struct {int size;memblock_t blocklist;memblock_t *rover;} ObservedZone;
extern ObservedZone *mainzone;
void CanonicalAllocation(void *p,int size){if(allocationfile){memblock_t*b=(memblock_t*)((byte*)p-sizeof(memblock_t));fprintf(allocationfile,"%ld\t%d\t%d\n",(long)((byte*)b-(byte*)mainzone),size,b->tag);fflush(allocationfile);}}
static void string(FILE *f,const char *s){fputc('"',f);if(s)for(;*s;s++){if(*s=='"'||*s=='\\')fputc('\\',f);if((unsigned char)*s>=32)fputc(*s,f);}fputc('"',f);}
static int kind(thinker_t *t){
    if(!t->function.acp1){for(int i=0;i<MAXCEILINGS;i++)if((thinker_t*)activeceilings[i]==t)return 10;for(int i=0;i<MAXPLATS;i++)if((thinker_t*)activeplats[i]==t)return 11;return 0;}
    return thinker_kind(t);
}
static int alive_ref(mobj_t *m){if(!m||!ready)return 0;for(thinker_t*t=thinkercap.next;t!=&thinkercap;t=t->next)if(t->function.acp1==(actionf_p1)P_MobjThinker&&(mobj_t*)t==m)return 1;return 0;}
static void record(const char *phase){
    if(!records)return;int st[4],hu[2],counts[12]={0},targets=0;UIStatusWords(st);UIHudWords(hu);
    if(rows++)fputs(",\n",records);fputs("{\"phase\":",records);string(records,phase);
    fprintf(records,",\"gametic\":%d,\"leveltime\":%d,\"gameaction\":%d,\"gamestate\":%d,\"map\":%d,\"skill\":%d,\"levelstarttic\":%d,\"paused\":%d,\"menuactive\":%d,\"prndindex\":%d,\"rndindex\":%d,\"turnheld\":%d,\"keysUp\":%d,\"sendsave\":%d,\"sargTics\":%d,\"projectileSpeed\":%d,\"respawnmonsters\":%d,\"stClock\":%d,\"stFace\":%d,\"stPalette\":%d,\"hudOn\":%d,\"hudCounter\":%d,\"automapactive\":%d,\"renderFramecount\":%d,\"renderFuzzpos\":%d,\"nativeThinkerAllocations\":%d",gametic,leveltime,gameaction,gamestate,gamemap,gameskill,levelstarttic,paused,menuactive,prndindex,rndindex,turnheld,gamekeydown[key_up],sendsave,states[S_SARG_RUN1].tics,mobjinfo[MT_TROOPSHOT].speed,respawnmonsters,st[0],st[1],st[3],hu[0],hu[1],automapactive,framecount,fuzzpos,observed_count);
    int blocks=0,allocated=0;for(memblock_t*b=mainzone->blocklist.next;b!=&mainzone->blocklist;b=b->next){blocks++;allocated+=!!b->user;}
    fprintf(records,",\"zoneRoverOffset\":%ld,\"zoneBlockCount\":%d,\"zoneAllocatedCount\":%d",(long)((byte*)mainzone->rover-(byte*)mainzone),blocks,allocated);
    fputs(",\"playerMessage\":",records);string(records,players[0].message);
    if(ready&&players[0].mo){mobj_t*m=players[0].mo;fprintf(records,",\"health\":%d,\"ammo\":%d,\"x\":%d,\"y\":%d,\"floorz\":%d,\"attacker\":%d,\"playerTarget\":%d,\"playerTracer\":%d,\"tracerResolvesToLiveActor\":%d,\"floorHeight\":%d,\"sideTextureOffset\":%d,\"sectorSoundTarget\":%d,\"buttonTimer\":%d,\"cmdForward\":%d,\"cmdButtons\":%d",players[0].health,players[0].ammo[0],m->x,m->y,m->floorz,!!players[0].attacker,!!m->target,!!m->tracer,alive_ref(m->tracer),sectors[0].floorheight,sides[0].textureoffset,!!sectors[0].soundtarget,buttonlist[0].btimer,players[0].cmd.forwardmove,players[0].cmd.buttons);
      fputs(",\"thinkerOrder\":[",records);int n=0;for(thinker_t*t=thinkercap.next;t!=&thinkercap;t=t->next){int k=kind(t);if(n++)fputc(',',records);fprintf(records,"%d",k);counts[k]++;if(k==1)targets+=!!((mobj_t*)t)->target;}fputc(']',records);
    }
    fprintf(records,",\"actorTargets\":%d,\"actors\":%d,\"fireFlickers\":%d,\"stasisCeilings\":%d,\"stasisPlats\":%d}",targets,counts[1],counts[9],counts[10],counts[11]);fflush(records);
}
void G_DoSaveGame(void){record("before-write");Original_G_DoSaveGame();record("after-write");}
void G_DoLoadGame(void){record("before-load");Original_G_DoLoadGame();record("after-load");}
void G_InitNew(skill_t skill,int episode,int map){record("before-init-new");Original_G_InitNew(skill,episode,map);ready=1;record("after-init-new");}
void G_DoLoadLevel(void){record("before-setup");Original_G_DoLoadLevel();ready=1;record("after-setup");}
static void tick(void){ticcmd_t cmd;memset(&cmd,0,sizeof(cmd));G_BuildTiccmd(&cmd);netcmds[0][(gametic/ticdup)%BACKUPTICS]=cmd;maketic++;G_Ticker();gametic++;}
static void draw(const char *name){HU_Erase();ST_Drawer(false,true);R_RenderPlayerView(players);HU_Drawer();char n[128];snprintf(n,sizeof(n),"%s.indexed8",name);writefile(".",n,screens[0],64000);snprintf(n,sizeof(n),"%s.palette",name);writefile(".",n,ui_rgb,768);}
static void rich(void){
    players[0].health=73;players[0].mo->health=73;players[0].ammo[0]=43;players[0].cards[0]=true;players[0].weaponowned[wp_shotgun]=true;
    players[0].message="PRIOR HUD";HU_Ticker();players[0].message="SAVED PLAYER MESSAGE";
    sectors[0].floorheight+=123;sides[0].textureoffset+=456;
    sectors[0].tag=9999;lines[0].tag=9999;EV_DoPlat(&lines[0],perpetualRaise,0);EV_StopPlat(&lines[0]);
    sectors[1].tag=9998;lines[1].tag=9998;EV_DoCeiling(&lines[1],crushAndRaise);EV_CeilingCrushStop(&lines[1]);
    sectors[2].special=17;P_SpawnFireFlicker(&sectors[2]);
    mobj_t *other=P_SpawnMobj(players[0].mo->x+128*FRACUNIT,players[0].mo->y,ONFLOORZ,MT_POSSESSED);
    players[0].mo->target=other;players[0].mo->tracer=other;players[0].attacker=other;sectors[0].soundtarget=other;
    buttonlist[0].line=&lines[0];buttonlist[0].btimer=9;buttonlist[0].where=middle;buttonlist[0].btexture=sides[lines[0].sidenum[0]].midtexture;
    prndindex=173;rndindex=211;turnheld=13;paused=true;AM_Start();
}
static void header(void){FILE*f=fopen("doomsav2.dsg","rb");if(!f)I_Error("missing save");byte b[50];if(fread(b,1,50,f)!=50)I_Error("save header");fseek(f,0,SEEK_END);long size=ftell(f);fclose(f);fprintf(records,",\n{\"phase\":\"file-header\",\"bytes\":%ld,\"skill\":%u,\"episode\":%u,\"map\":%u,\"savedLeveltime\":%u}",size,b[40],b[41],b[42],((unsigned)b[47]<<16)|((unsigned)b[48]<<8)|b[49]);rows++;}
int main(int argc,char **argv){
    if(argc!=5)I_Error("WAD directory game case");Z_Init();char*files[]={argv[1],NULL};W_InitMultipleFiles(files);
    gamemode=!strcmp(argv[3],"doom2")?commercial:retail;gamemission=!strcmp(argv[3],"doom2")?doom2:doom;
    playeringame[0]=true;precache=false;consoleplayer=displayplayer=0;gameskill=sk_medium;
    key_up=KEY_UPARROW;key_down=KEY_DOWNARROW;key_left=KEY_LEFTARROW;key_right=KEY_RIGHTARROW;key_fire=KEY_RCTRL;key_use=' ';key_speed=KEY_RSHIFT;key_strafe=KEY_RALT;key_strafeleft=',';key_straferight='.';
    V_Init();ST_Init();HU_Init();
    char *sprite_names[NUMSPRITES+1];memcpy(sprite_names,sprnames,NUMSPRITES*sizeof(*sprite_names));sprite_names[NUMSPRITES]=NULL;
    R_Init();R_InitSprites(sprite_names);R_ExecuteSetViewSize();P_InitSwitchList();P_InitPicAnims();
    if(chdir(argv[2]))I_Error("run directory");records=fopen("observations.json","w");allocationfile=fopen("allocations.tsv","w");if(!records||!allocationfile)I_Error("observations");fputs("[\n",records);
    G_InitNew(sk_medium,1,1);for(int i=0;i<5;i++)tick();draw("baseline");record("baseline");
    if(!strcmp(argv[4],"queued")||!strcmp(argv[4],"paused-queued")){
      paused=!strcmp(argv[4],"paused-queued");gamekeydown[key_up]=true;
      G_SaveGame(2,"CANONICAL");record("save-request");tick();record("after-save-command-tic");
      gamekeydown[key_up]=false;tick();record("after-write-tic");header();
      paused=false;for(int i=0;i<4;i++)tick();gamekeydown[key_up]=true;
      G_LoadGame("doomsav2.dsg");record("load-request");tick();record("after-load-tic");draw("loaded");record("after-load-display");
    }else if(!strcmp(argv[4],"dead-save")){
      P_DamageMobj(players[0].mo,NULL,NULL,1000);record("dead-save-request");G_SaveGame(2,"DEAD SAVE");tick();record("dead-save-command-tic");tick();record("dead-save-rebirth-tic");
      FILE*f=fopen("doomsav2.dsg","rb");if(f)I_Error("unexpected dead save file");
    }else if(!strcmp(argv[4],"reborn-load")||!strcmp(argv[4],"bad-version-queued")){
      players[0].health=players[0].mo->health=73;players[0].ammo[0]=43;G_SaveGame(2,"QUEUED GUARDS");tick();tick();header();
      if(!strcmp(argv[4],"reborn-load")){G_LoadGame("doomsav2.dsg");players[0].playerstate=PST_REBORN;record("reborn-load-request");tick();record("reborn-load-tic");}
      else{FILE*f=fopen("doomsav2.dsg","r+b");fseek(f,24,SEEK_SET);fputc('X',f);fclose(f);G_LoadGame("doomsav2.dsg");record("invalid-load-request");tick();record("invalid-load-tic");}
    }else if(!strcmp(argv[4],"nightmare-archive")||!strcmp(argv[4],"medium-archive")){
      skill_t saved=!strcmp(argv[4],"nightmare-archive")?sk_nightmare:sk_medium;
      G_InitNew(saved,1,1);record("saved-difficulty");G_SaveGame(2,"DIFFICULTY");G_DoSaveGame();header();
      G_InitNew(saved==sk_nightmare?sk_medium:sk_nightmare,1,1);record("current-difficulty");
      G_LoadGame("doomsav2.dsg");G_DoLoadGame();record("loaded-difficulty");
    }else if(!strcmp(argv[4],"write-failure")){
      if(mkdir("doomsav2.dsg",0700))I_Error("failure fixture");G_SaveGame(2,"FAILED WRITE");G_DoSaveGame();record("write-failure-return");
    }else{
      if(!strcmp(argv[4],"rich-direct"))rich();if(!strcmp(argv[4],"time-wrap"))leveltime=0x1000005;
      record("presave");G_SaveGame(2,"CANONICAL");G_DoSaveGame();header();
      players[0].health=7;players[0].ammo[0]=0;prndindex=99;rndindex=87;turnheld=37;gametic+=19;gamekeydown[key_up]=true;
      if(!strcmp(argv[4],"bad-version")){FILE*f=fopen("doomsav2.dsg","r+b");fseek(f,24,SEEK_SET);fputc('X',f);fclose(f);}
      record("diverged");G_LoadGame("doomsav2.dsg");G_DoLoadGame();record("loaded-direct");
      if(strcmp(argv[4],"bad-version")){tick();record("next-tic");draw("loaded");record("after-load-display");}
      if(!strcmp(argv[4],"rich-direct")){G_LoadGame("doomsav2.dsg");G_DoLoadGame();record("loaded-again");}
    }
    fputs("\n]\n",records);fclose(records);fclose(allocationfile);printf("PASS %s %s\n",argv[3],argv[4]);return 0;
}
