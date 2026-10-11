#!/usr/bin/env python3
"""Focused original-C death/rebirth host; reuse the accepted borrowed-UI builder.

Generated sources only: verbatim G_Ticker/G_DoReborn/AM_Stop and observation
identity reset on level load. Controlled scenarios are explicit host inputs.
No original source, historical golden or production state/frame is written.
"""
import argparse, hashlib, importlib.util, json, re, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/reference/gameplay'))
from build import ref,renderer,PUNITS,extract
ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--opt',default='O2');ap.add_argument('--sanitize',action='store_true');ap.add_argument('--commercial',action='store_true');a=ap.parse_args();out=a.output.resolve()
command=[sys.executable,str(ROOT/'tools/reference/full_videos/native-build-short.py'),'--output',str(out),'--opt',a.opt,'--borrow-all-ui']
if a.sanitize:command.append('--sanitize')
subprocess.run(command,check=True,stdout=subprocess.DEVNULL)
host=(out/'original-host.c').read_text()
host=host.replace('void AM_Stop(void) { automapactive=false; }','')
extra=r'''
#include "d_net.h"
#define TURBOTHRESHOLD 0x32
boolean netdemo=false,demorecording=false;
skill_t d_skill;int d_episode,d_map;
int ticdup=1;short consistancy[4][BACKUPTICS];ticcmd_t netcmds[4][BACKUPTICS];
char savedescription[32];int savegameslot;
extern char *player_names[4];
void S_PauseSound(void) {}
void G_DoLoadGame(void){I_Error("load outside death oracle");}
void G_DoSaveGame(void){I_Error("save outside death oracle");}
void G_DoPlayDemo(void){I_Error("demo outside death oracle");}
void G_ReadDemoTiccmd(ticcmd_t *p){I_Error("demo outside death oracle");}
void G_WriteDemoTiccmd(ticcmd_t *p){I_Error("demo outside death oracle");}
void D_PageTicker(void){I_Error("title outside death oracle");}
void M_ScreenShot(void){I_Error("screenshot outside death oracle");}
void G_DoNewGame(void){I_Error("new game outside death oracle");}
void G_DoWorldDone(void){I_Error("worlddone outside death oracle");}
boolean G_CheckSpot(int p,mapthing_t *m){I_Error("network outside death oracle");return false;}
static boolean stopped=true;
void AM_unloadPics(void) {}
void AM_Ticker(void) {}
'''
# Compile source functions in the host translation unit so observer identity
# can reset without exposing or modifying original thinker/allocator behavior.
spans=[]
for file,name in [('g_game.c','G_DoReborn'),('g_game.c','G_DeferedInitNew'),('g_game.c','G_Ticker'),('am_map.c','AM_Stop')]:
 body,span=extract(file,name);spans.append(span);extra+='\n'+body+'\n'
host=host.replace('int speedrun_exit_line=-1;',extra+'\nint speedrun_exit_line=-1;')
start=host.index('    int forward,side,angle,buttons,render,post=0;');end=host.index('    char summary[1024];',start)
loop=r'''
    int forward,side,angle,buttons,render,op,seq=0;
    boolean redrawsbar=true;
    FILE *meta=fopen(strcat(strcpy(path,argv[2]),"/player.jsonl"),"w");if(!meta)I_Error("meta");
    while(fscanf(commands,"%d %d %d %d %d %d",&forward,&side,&angle,&buttons,&render,&op)==6) {
        player_t *p=players;mobj_t *m=p->mo;
        if(op==1) {
            mobj_t *enemy=P_SpawnMobj(m->x+64*FRACUNIT,m->y,ONFLOORZ,MT_POSSESSED);
            if(!P_CheckPosition(enemy,enemy->x,enemy->y))I_Error("arena blocked");
            enemy->angle=ANG180;enemy->target=m;P_SetMobjState(enemy,enemy->info->seestate);
            p->health=m->health=3;
        } else if(op==2) {p->health=m->health=3;leveltime=0;m->subsector->sector->special=7;}
        else if(op==3) {
            p->armorpoints=200;p->armortype=2;p->backpack=true;
            for(int i=0;i<NUMWEAPONS;i++)p->weaponowned[i]=true;
            for(int i=0;i<NUMAMMO;i++){p->maxammo[i]*=2;p->ammo[i]=p->maxammo[i];}
            for(int i=0;i<NUMCARDS;i++)p->cards[i]=true;
            p->powers[pw_invisibility]=100;m->flags|=MF_SHADOW;
        } else if(op==4) menuactive=true;
        else if(op==5) menuactive=false;
        else if(op==6) automapactive=true;
        else if(op==7 || op==8) {
            const char *text=op==7?"idfa":"idclip";
            for(;*text;text++){event_t e={ev_keydown,*text,0,0};ST_Responder(&e);}
        }
        else if(op!=0)I_Error("unknown scenario op");
        if(p->playerstate==PST_REBORN) {redrawsbar=true;observed_count=0;memset(observed,0,sizeof(observed));memset(observed_kind,0,sizeof(observed_kind));}
        netcmds[0][gametic%BACKUPTICS]=(ticcmd_t){.forwardmove=forward,.sidemove=side,.angleturn=angle,.buttons=buttons};
        G_Ticker();gametic++;seq++;
        int u[4];UIStatusWords(u);p=players;m=p->mo;
        fprintf(meta,"{\"seq\":%d,\"gametic\":%d,\"leveltime\":%d,\"map\":%d,\"skill\":%d,\"playerstate\":%d,\"health\":%d,\"actorHealth\":%d,\"actorState\":%ld,\"actorTics\":%d,\"viewheight\":%d,\"viewz\":%d,\"angle\":%u,\"x\":%d,\"y\":%d,\"prndindex\":%d,\"rndindex\":%d,\"face\":%d,\"palette\":%d,\"automap\":%d,\"ammo\":[%d,%d,%d,%d],\"armor\":%d}\n",seq,gametic,leveltime,gamemap,gameskill,p->playerstate,p->health,m->health,m->state-states,m->tics,p->viewheight,p->viewz,m->angle,m->x,m->y,prndindex,rndindex,u[1],u[3],automapactive,p->ammo[0],p->ammo[1],p->ammo[2],p->ammo[3],p->armorpoints);
        /* d_main.c D_Display: full bar redraw follows initial/load display
           history, not leveltime. Explicitly resetting a damage timer is not
           a load. Legacy mode reproduces the retained rejected v1 fixture. */
        if(render) {HU_Erase();ST_Drawer(false,getenv("DEATH_LEGACY_LEVELTIME_REFRESH")?leveltime==1:redrawsbar);redrawsbar=false;R_RenderPlayerView(players);HU_Drawer();
            char name[100];snprintf(name,sizeof(name),"frame-%06d.bin",seq);writefile(argv[2],name,screens[0],64000);
            snprintf(name,sizeof(name),"palette-%06d.bin",seq);writefile(argv[2],name,ui_rgb,768);}
        snapshot(ticks);world_record(world);
    }
    fclose(meta);fclose(commands);fclose(ticks);fclose(world);fclose(diagnostics);
'''
host=host[:start]+loop+host[end:]
if a.commercial:
 host=host.replace('gamemode=retail;gamemission=doom;','gamemode=commercial;gamemission=doom2;').replace('episode_map>9','episode_map>32').replace('"E1M%d",episode_map','"MAP%02d",episode_map')
(out/'original-host.c').write_text(host)
manifest=json.loads((out/'full-manifest.json').read_text())
cmd=manifest['command'].copy();cmd[-1]=str(out/'death-respawn');cmd.insert(-3,str(ref.SOURCE/'m_cheat.c'))
r=subprocess.run(cmd,capture_output=True);(out/'death-build.log').write_bytes(r.stdout+r.stderr)
assert r.returncode==0,r.stderr.decode()
manifest.update(deathSourceSpans=spans,generatedDeathHostSha256=ref.sha(host.encode()),deathBuilderSha256=ref.sha(Path(__file__).read_bytes()),deathCompile=cmd,displayPolicy='d_main.c D_Display redrawsbar: initial/load display history; supported view size 10, no help/view-size transition or production melt. DEATH_LEGACY_LEVELTIME_REFRESH only reproduces rejected v1 timer-derived refresh.',scope='Original full gameplay/zone and G_Ticker/G_DoReborn/G_DoLoadLevel; borrowed immutable ST/HU; explicit controlled operations; pointer-free observer IDs restart with logical pools, no gameplay mutation by observation. No production melt orchestration.')
(out/'death-build.json').write_text(json.dumps(manifest,indent=2)+'\n');print(out/'death-respawn')
