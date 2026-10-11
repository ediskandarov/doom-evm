#!/usr/bin/env python3
"""Independent original gameplay + borrowed ST/HU/WI/video + source-extracted finale/wipe.

Gameplay captures replay a fresh no-render prefix, then draw once, matching the
historical observer chronology. UI/wipe globals persist within each process.
Native bytes are verification-only and are never submitted to EVM.
"""
import argparse,sys,json,re,subprocess,hashlib,importlib.util
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
sys.path.insert(0,str(HERE.parent/'speedrun'));import replay
from replay import renderer,PUNITS,ref
spec=importlib.util.spec_from_file_location('full_ui_reference',HERE.parent/'ui/reference.py');ui=importlib.util.module_from_spec(spec);spec.loader.exec_module(ui)
ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--opt',default='O2');ap.add_argument('--sanitize',action='store_true');a=ap.parse_args();out=a.output.resolve()
replay.build_replay(out,a.opt,a.sanitize)
host=(out/'original-host.c').read_text()
for text in ['byte *screens[5];\n','void V_MarkRect(int x,int y,int width,int height) { (void)x;(void)y;(void)width;(void)height; }\n','void V_DrawPatch(int x,int y,int screen,patch_t *patch) { I_Error("Unexpected border draw"); }\n','void ST_Start(void) {}\n','void HU_Start(void) {}\n']:
 assert host.count(text)==1,text;host=host.replace(text,'')
host=host.replace('#include "info.h"','#include "info.h"\n#include "v_video.h"\n#include "wi_stuff.h"\n#include "f_finale.h"\n#include "f_wipe.h"')
host=host.replace('int detailLevel=0, screenblocks=11;','int detailLevel=0, screenblocks=10;')
platform=ui.UI_PLATFORM+r'''
void S_ChangeMusic(int music,int loop) {}
void S_StartMusic(int music) {}
void *statcopy=NULL;
char *pagename=NULL;
extern int finalestage,finalecount;
extern void FullWiWords(int *);
void I_ReadScreen(byte *p) {memcpy(p,screens[0],64000);}
static int display_state=GS_DEMOSCREEN,video_frame=0,demo_tic=0,gameplay_tic=0;
static void frame(int kind,int stage,int count) {
 char name[100];snprintf(name,sizeof(name),"%06d-%d-%d-%d-%d-%d-%d.indexed8",++video_frame,kind,demo_tic,gameplay_tic,rndindex,stage,count);
 writefile(full_dest,name,screens[0],64000);
 snprintf(name,sizeof(name),"palette-%06d.bin",video_frame);writefile(full_dest,name,ui_rgb,768);
}
static void finish_display(int kind,int stage,int count,boolean force) {
 if(force || gamestate!=display_state) {
  wipe_EndScreen(0,0,320,200);display_state=gamestate;
  boolean done=false;while(!done) {done=wipe_ScreenWipe(1,0,0,320,200,1);frame(2,0,0);}
 } else frame(kind,stage,count);
}
'''
# full_dest must precede platform functions; UI observer declarations remain original.
host=host.replace('int speedrun_exit_line=-1;', 'static const char *full_dest;\n'+platform+'\nint speedrun_exit_line=-1;')
host=host.replace('screens[0]=calloc(1,320*200);screens[1]=calloc(1,320*200);','V_Init();ST_Init();HU_Init();full_dest=argv[2];')
loopstart=host.index('    int forward,side,angle,buttons,render;')
loopend=host.index('    char summary[1024];',loopstart)
loop=r'''
    int forward,side,angle,buttons,render,post=0;int capture=atoi(getenv("FULL_CAPTURE_TIC")?getenv("FULL_CAPTURE_TIC"):"0");
    if(!capture) {
      I_SetPalette(UIWCacheName("PLAYPAL",PU_CACHE));V_DrawPatch(0,0,0,UIWCacheName("TITLEPIC",PU_CACHE));
      for(int i=0;i<35;i++)frame(1,0,0);
    }
    int tail_count=0,final_hold=0,stats_hold=0;
    while(fscanf(commands,"%d %d %d %d %d",&forward,&side,&angle,&buttons,&render)==5 || (!capture && post && (gamestate==GS_FINALE ? final_hold<105 : stats_hold<105))) {
        if(feof(commands)){forward=side=angle=buttons=0;tail_count++;} else demo_tic++;
        if(gameaction==ga_completed) {G_DoCompleted();post=1;if(gameaction==ga_victory)F_StartFinale();}
        if(post && gameaction==ga_worlddone)I_Error("tape requires a next gameplay level outside standalone profile");
        players[0].cmd=(ticcmd_t){.forwardmove=forward,.sidemove=side,.angleturn=angle,.buttons=buttons};
        if(!post) {
          P_Ticker();ST_Ticker();HU_Ticker();gametic++;gameplay_tic=gametic;
          int rng=rndindex;rndindex=0;
          if(gametic==capture || (!capture && gameaction==ga_completed)) {snapshot(ticks);world_record(world);diagnostic_record(diagnostics);}
          rndindex=rng;
          if(gametic==1) {
            if(!capture)wipe_StartScreen(0,0,320,200);
            if(!capture){for(int i=0;i<320;i++)M_Random();display_state=GS_LEVEL;}
            else for(int i=0;i<320;i++)M_Random();
          }
          if(gametic==capture || (!capture && gameaction==ga_completed)) {
            HU_Erase();ST_Drawer(false,true);R_RenderPlayerView(players);HU_Drawer();
            if(capture){char name[100];snprintf(name,sizeof(name),"gameplay-%06d.indexed8",gametic);writefile(argv[2],name,screens[0],64000);snprintf(name,sizeof(name),"gameplay-%06d.palette",gametic);writefile(argv[2],name,ui_rgb,768);break;}
            // Preserve the last original world as the source of the exit wipe. No extra video frame.
          }
        } else {
          boolean transition=gamestate!=display_state;
          if(transition)wipe_StartScreen(0,0,320,200);
          int stage=0,count=0;
          if(gamestate==GS_INTERMISSION) {
            WI_Ticker();int words[4];FullWiWords(words);stage=words[0];count=words[1];
            if(gameaction!=ga_worlddone)WI_Drawer();
            if(feof(commands) && (stage==10 || words[2]!=0))stats_hold++;
            if(gameaction==ga_worlddone)stats_hold=105;
          } else if(gamestate==GS_FINALE) {
            F_Ticker();stage=finalestage;count=finalecount;
            if(wipegamestate==-1){transition=true;wipe_StartScreen(0,0,320,200);}
            F_Drawer();if(feof(commands) && finalestage==1)final_hold++;
          } else I_Error("unsupported presentation state");
          if(transition)I_SetPalette(UIWCacheName("PLAYPAL",PU_CACHE));
          finish_display(gamestate==GS_INTERMISSION?3:4,stage,count,transition);wipegamestate=gamestate;
          if(gameaction==ga_worlddone && !feof(commands))I_Error("native tape ends after WI worlddone");
          if(tail_count>5000)I_Error("UI continuation bound");
        }
    }
    fclose(commands);fclose(ticks);fclose(world);fclose(diagnostics);
'''
host=host[:loopstart]+loop+host[loopend:];(out/'original-host.c').write_text(host)
units=[]
for name in ['st_stuff.c','st_lib.c','hu_stuff.c','hu_lib.c','v_video.c','wi_stuff.c']:
 text=(ref.SOURCE/name).read_text()
 if name in ['st_stuff.c','hu_stuff.c','wi_stuff.c']:
  text='#define W_CacheLumpName UIWCacheName\n#define W_CacheLumpNum UIWCacheNum\n'+text
  text=text.replace('#include "z_zone.h"','#include "z_zone.h"\n#undef Z_ChangeTag\n#define Z_ChangeTag(p,t) ((void)0)')
 if name=='st_stuff.c':text='#define Z_Malloc UIAlloc\n'+text+'\nvoid UIStatusWords(int *a){a[0]=st_clock;a[1]=st_faceindex;a[2]=st_facecount;a[3]=st_palette;}\n'
 if name=='hu_stuff.c':text+='\nvoid UIHudWords(int *a){a[0]=message_on;a[1]=message_counter;}\nchar *UIMessageBytes(void){return w_message.l[0].l;}\n'
 if name=='wi_stuff.c':text+='\nvoid FullWiWords(int *a){a[0]=sp_state;a[1]=bcnt;a[2]=state;a[3]=cnt;}\n'
 (out/name).write_text(text);units.append(name)
# Only E1 active finale functions are extracted verbatim; inactive cast/bunny abort.
source=(ref.SOURCE/'f_finale.c').read_text(); funcs=[]
for name in ['F_StartFinale','F_Ticker','F_TextWrite','F_Drawer']:
 match=re.search(r'void\s+'+name+r'\s*\([^;]*?\)\s*\{',source);start,end=match.start(),match.end();depth=1
 while depth:depth+=(source[end]=='{')-(source[end]=='}');end+=1
 funcs.append(source[start:end])
pre='''#include "doomdef.h"\n#include "doomstat.h"\n#include "v_video.h"\n#include "m_swap.h"\n#include "hu_stuff.h"\n#include "w_wad.h"\nextern patch_t *hu_font[HU_FONTSIZE];\n#include "s_sound.h"\n#include "sounds.h"\n#include "d_englsh.h"\n#define PU_CACHE 101\n#define TEXTSPEED 3\n#define TEXTWAIT 250\nextern gamestate_t wipegamestate;\nint finalestage,finalecount;char *finaleflat,*finaletext;\nchar *e1text=E1TEXT;\n'''+''.join('char *'+x+'="";\n' for x in ['e2text','e3text','e4text','c1text','c2text','c3text','c4text','c5text','c6text'])+'''void F_StartCast(void){abort();}void F_CastTicker(void){abort();}void F_CastDrawer(void){abort();}void F_BunnyScroll(void){abort();}\nvoid F_TextWrite(void);\n'''
(out/'full_finale.c').write_text('#define W_CacheLumpName UIWCacheName\n'+pre+'\n'.join(funcs));units.append('full_finale.c')
w=(ref.SOURCE/'f_wipe.c').read_text();(out/'full_wipe.c').write_text('#include "doomdef.h"\n#include "v_video.h"\n#include "m_random.h"\n#define PU_STATIC 1\n#define Z_Malloc UIAlloc\n#define Z_Free free\nvoid *UIAlloc(int,int,void*);void I_ReadScreen(byte*);\nstatic boolean go=0;static byte *wipe_scr_start,*wipe_scr_end,*wipe_scr;\n'+w[w.index('void\nwipe_shittyColMajorXform'):]);units.append('full_wipe.c')
game=(out/'game_functions.c').read_text();bodies=[]
for name in ['G_PlayerFinishLevel','G_DoCompleted','G_WorldDone']:
 b,_=replay.extract('g_game.c',name);bodies.append(b)
g=(ref.SOURCE/'g_game.c').read_text();constants='\n'.join(re.search(r'int '+name+r'\[[^;]*?\};',g)[0] for name in ['pars','cpars'])
(out/'game_functions.c').write_text(game+'\n#include "wi_stuff.h"\n#include "f_finale.h"\nextern void *statcopy;\n'+constants+'\n'+'\n'.join(bodies))
manifest=json.loads((out/'speedrun-build-manifest.json').read_text());flags=[f.replace('<BUILD>',str(out)).replace('<HARNESS>',str(HERE.parent)) for f in manifest['flags']]
if a.sanitize:flags+=['-fno-sanitize=array-bounds']
cmd=['clang',*flags,'-ffunction-sections','-fdata-sections','-I'+str(out),*[str(out/name) for name in renderer.UNITS+PUNITS+units],str(out/'game_functions.c'),str(out/'episode-host.c'),'-I'+str(HERE.parent/'gameplay'),'-Wl,-dead_strip','-o',str(out/'full-native')]
p=subprocess.run(cmd,capture_output=True,text=True);(out/'full-build.log').write_text(p.stdout+p.stderr)
assert p.returncode==0,p.stderr
manifest.update(command=cmd,generatedSources={str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*') if p.suffix in ['.c','.h','.inc']},scope='Borrowed original UI buffers; canonical no-UI world observations normalize only miscellaneous rndindex; real ST/HU/WI/finale/wipe original functions; gameplay prefix single-render history; native profile LP64 initialized-zone with preserved platform adaptations.')
(out/'full-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(out/'full-native')
