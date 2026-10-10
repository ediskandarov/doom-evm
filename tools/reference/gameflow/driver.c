static void word(FILE *f,int32_t value){uint32_t v=(uint32_t)value;unsigned char b[]={v>>24,v>>16,v>>8,v};if(fwrite(b,1,4,f)!=4)abort();}
#include "snapshot.inc"
static void setup(int map,int flags){
 memset(players,0,sizeof(players));memset(actors,0,sizeof(actors));memset(&wminfo,0,sizeof(wminfo));memset(playeringame,0,sizeof(playeringame));
 memset(netcmds,0,sizeof(netcmds));memset(states,0,sizeof(states));memset(mobjinfo,0,sizeof(mobjinfo));
 tracecount=0;gameepisode=1;gamemap=map;gamemode=(flags&64)?shareware:((flags&32768)?registered:retail);gameskill=sk_medium;
 gamestate=(flags&1024)?GS_INTERMISSION:((flags&2048)?GS_FINALE:GS_LEVEL);gameaction=(flags&16384)?ga_completed:ga_nothing;
 gametic=128;leveltime=315;totalkills=20;totalitems=21;totalsecret=22;consoleplayer=0;displayplayer=3;
 prndindex=77;rndindex=88;skyflatnum=3;skytexture=7;turnheld=9;onground=false;
 paused=!!(flags&4);menuactive=!!(flags&8);automapactive=!!(flags&2);viewactive=true;usergame=true;
 fastparm=!!(flags&16);respawnparm=!!(flags&32);respawnmonsters=false;nomonsters=true;
 netgame=netdemo=demoplayback=demorecording=deathmatch=false;sendpause=true;secretexit=!!(flags&1);
 d_skill=sk_hard;d_episode=1;d_map=7;levelstarttic=5;wipegamestate=GS_LEVEL;
 playeringame[0]=true;
 for(int i=0;i<4;i++){
  player_t *p=players+i;p->mo=actors+i;p->playerstate=PST_LIVE;p->health=91+i;p->armorpoints=30;p->armortype=2;
  p->viewheight=41*FRACUNIT;p->viewz=(flags&4096)?1:41*FRACUNIT;p->deltaviewheight=123;p->backpack=true;
  p->readyweapon=wp_shotgun;p->pendingweapon=wp_nochange;p->attackdown=1;p->usedown=0;p->cheats=2;p->refire=3;
  p->killcount=4+i;p->itemcount=5+i;p->secretcount=6+i;p->damagecount=7;p->bonuscount=8;p->extralight=2;p->fixedcolormap=3;p->colormap=4;p->message="sentinel";
  p->didsecret=!!(flags&512);actors[i].flags=MF_SHADOW|MF_SOLID;actors[i].ceilingz=128*FRACUNIT;
  p->cmd=(ticcmd_t){.forwardmove=3,.sidemove=-4,.angleturn=5,.consistancy=-6,.chatchar=7,.buttons=8};
  for(int j=0;j<6;j++){p->powers[j]=10+j;p->cards[j]=true;}
  for(int j=0;j<4;j++){p->frags[j]=i*10+j+1;p->ammo[j]=40+j;p->maxammo[j]=200+j;}
  for(int j=0;j<9;j++)p->weaponowned[j]=true;
  for(int j=0;j<2;j++){p->psprites[j].state=states+10+j;p->psprites[j].tics=9;p->psprites[j].sx=123;p->psprites[j].sy=456;}
  wminfo.plyr[i].score=100+i;
 }
 if(flags&128)players[0].playerstate=PST_DEAD;
 if(flags&256)players[0].playerstate=PST_REBORN;
 for(int i=477;i<=489;i++)states[i].tics=(i%5)+1;
 mobjinfo[16].speed=15*FRACUNIT;mobjinfo[31].speed=mobjinfo[32].speed=10*FRACUNIT;
}
static void tick(int buttons,int forward){ticcmd_t *cmd=&netcmds[0][gametic%BACKUPTICS];*cmd=(ticcmd_t){.forwardmove=forward,.sidemove=-2,.angleturn=320,.consistancy=-5,.chatchar=65,.buttons=buttons};G_Ticker();gametic++;}
static void run(int op,int map,int flags,int skill,int episode,int buttons){
 switch(op){
 case 0:G_InitNew(skill,episode,map);break;
 case 1:G_DeferedInitNew(skill,episode,map);tick(buttons,12);break;
 case 2:G_DoLoadLevel();break;
 case 3:if(flags&1)G_SecretExitLevel();else G_ExitLevel();tick(buttons,12);break;
 case 4:G_DoCompleted();break;
 case 5:G_DoCompleted();G_WorldDone();tick(buttons,12);break;
 case 6:tick(buttons,(flags&8192)?51:12);break;
 case 7:tick(buttons,12);tick(0,12);tick(0,12);break;
 case 8:G_InitNew(4,1,1);G_InitNew(4,1,1);G_InitNew(2,1,1);break;
 case 9:G_InitNew(2,1,1);G_InitNew(2,1,1);break;
 case 10:G_InitPlayer(0);break;
 default:abort();
 }
}
int main(void){int row[6];while(scanf("%d %d %d %d %d %d",row,row+1,row+2,row+3,row+4,row+5)==6){setup(row[1],row[2]);run(row[0],row[1],row[2],row[3],row[4],row[5]);FILE *f=tmpfile();if(!f)abort();for(int i=0;i<6;i++)word(f,row[i]);snapshot(f);long size=ftell(f);rewind(f);word(stdout,size/4);for(long i=0;i<size;i++)putchar(fgetc(f));fclose(f);}if(!feof(stdin))abort();return 0;}
