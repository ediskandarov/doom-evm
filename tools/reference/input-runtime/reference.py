#!/usr/bin/env python3
"""Original production keyboard/responders/gameplay/AM/ST/HU; outputs only."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE.parent / 'gameplay'))
from build import extract, renderer, PUNITS, ref
from verify import player_records

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

ui = load('input_runtime_ui', HERE.parent / 'ui/reference.py')

def packets():
    rows = []
    def add(name, events=(), render=True, full=False):
        events = list(events)
        assert len(events) <= 64
        rows.append(dict(tic=len(rows)+1, name=name, events=events, render=render, fullscreen=full))
    def text(name, value, render=True, full=False):
        add(name, [(kind, ord(ch)) for ch in value for kind in (0, 1)], render, full)
    text('prefix-before-punctuation', 'idd', False)
    add('punctuation-resets-prefix', [(0, 59), (1, 59)], False)
    text('suffix-after-reset-does-not-cheat', 'qd', False)
    text('god-prefix', 'idd', False)
    add('HUD-consumes-enter', [(0, 13), (1, 13)], False)
    add('spy-key-preserves-prefix', [(0, 216), (1, 216)], False)
    text('god-completion', 'qd')
    text('all-keys-weapons-ammo', 'idkfa')
    text('no-keys-ammo', 'idfa')
    text('noclip-on', 'idclip')
    add('move-with-held-alias', [(0, 119)], False)
    add('hold-moves-without-new-events', [], False)
    add('release-alias', [(1, 119)])
    text('original-noclip-off', 'idspispopd')
    text('power-menu', 'idbehold')
    for suffix in 'vsiral':
        text('power-'+suffix, 'idbehold'+suffix)
    text('position-message', 'idmypos')
    text('choppers-one-tic-expiry', 'idchoppers')
    text('inactive-IDDT', 'iddt', False)
    add('open-map', [(0, 9), (1, 9)])
    add('follow-arrow-falls-through', [(0, 0xad)], False)
    add('follow-held-movement', [], False)
    add('release-and-disable-follow', [(1, 0xad), (0, 102), (1, 102)])
    add('pan-right-consumed', [(0, 0xae)], False)
    add('pan-held', [])
    add('pan-release', [(1, 0xae)])
    add('zoom-in-held', [(0, 61)], False)
    add('zoom-in-tic', [])
    add('zoom-release-and-grid', [(1, 61), (0, 103), (1, 103)])
    add('mark-center', [(0, 109), (1, 109)])
    text('IDDT-wall-stage', 'iddt')
    text('IDDT-things-stage', 'iddt', full=True)
    add('overview', [(0, 48), (1, 48)], full=True)
    add('overview-restore', [(0, 48), (1, 48)], full=True)
    text('IDDT-normal-stage', 'iddt', full=True)
    add('close-map-fullscreen', [(0, 9), (1, 9)], full=True)
    add('reopen-same-map', [(0, 9), (1, 9)])
    add('clear-marks', [(0, 99), (1, 99)])
    text('warp-prefix-before-close', 'idclev', False)
    add('stop-notification-enters-ST-parser', [(0, 9), (1, 9)])
    text('warp-new-prefix', 'idclev1', False)
    text('warp-selection-persisted', '9')
    add('pending-warp-keeps-current-level', [])
    add('pause', [(0, 255), (1, 255)], False)
    text('paused-god-off', 'iddqd')
    add('resume', [(0, 255), (1, 255)])
    # Leave every physical key released for deterministic browser stop/blur.
    return rows

KEYBOARD = r'''
int key_up=KEY_UPARROW,key_down=KEY_DOWNARROW,key_strafeleft=',',key_straferight='.';
int key_left=KEY_LEFTARROW,key_right=KEY_RIGHTARROW,key_use=' ',key_fire=KEY_RCTRL;
int key_speed=KEY_RSHIFT,key_strafe=KEY_RALT;
boolean gamekeydown[256],mousearray[4],joyarray[5];
boolean *mousebuttons=&mousearray[1],*joybuttons=&joyarray[1];
int mousebfire=-1,mousebstrafe=-1,mousebforward=-1;
int joybfire=-1,joybstrafe=-1,joybuse=-1,joybspeed=-1;
int mousex,mousey,joyxmove,joyymove,mouseSensitivity=5;
int dclicktime,dclickstate,dclicks,dclicktime2,dclickstate2,dclicks2;
int turnheld,ticdup=1,maketic,savegameslot;
boolean sendpause,sendsave,singledemo=false,viewactive=true;
skill_t d_skill;int d_episode,d_map;
static ticcmd_t base;
ticcmd_t *I_BaseTiccmd(void){return &base;}
void M_StartControlPanel(void){I_Error("Demo/menu outside keyboard profile");}
boolean F_Responder(event_t *ev){(void)ev;I_Error("Finale outside keyboard profile");return false;}
#define NUMKEYS 256
static void native_command(ticcmd_t *cmd) {
    int native[5]={KEY_UPARROW,KEY_DOWNARROW,',','.',' '},aliases[5]={'w','s','a','d','e'};
    boolean saved[5];for(int i=0;i<5;i++){saved[i]=gamekeydown[native[i]];gamekeydown[native[i]]|=gamekeydown[aliases[i]];}
    G_BuildTiccmd(cmd);
    for(int i=0;i<5;i++)gamekeydown[native[i]]=saved[i];
}
extern void IRAMWords(int *);
extern void IRAMMarks(int *);
extern void IRSTSequences(FILE *);
static void runtime_record(FILE *f) {
    word(f,players[0].cheats);for(int i=0;i<6;i++)word(f,players[0].powers[i]);
    word(f,gameaction);word(f,d_skill);word(f,d_episode);word(f,d_map);
    for(int i=7;i>=0;i--){uint32_t bits=0;for(int j=0;j<32;j++)bits|=(uint32_t)gamekeydown[i*32+j]<<j;word(f,bits);}
    int a[17],marks[20];IRAMWords(a);IRAMMarks(marks);
    for(int i=0;i<17;i++)word(f,a[i]);for(int i=0;i<20;i++)word(f,marks[i]);
    IRSTSequences(f);
    word(f,numlines);for(int i=0;i<numlines;i++)word(f,lines[i].flags);
}
'''

ST_OBSERVE = r'''
void IRSTSequences(FILE *f) {
    cheatseq_t *seqs[15]={&cheat_god,&cheat_ammonokey,&cheat_ammo,&cheat_noclip,
        &cheat_commercial_noclip,&cheat_powerup[0],&cheat_powerup[1],&cheat_powerup[2],
        &cheat_powerup[3],&cheat_powerup[4],&cheat_powerup[5],&cheat_powerup[6],
        &cheat_choppers,&cheat_mypos,&cheat_clev};
    int lengths[15]={6,5,6,11,7,10,10,10,10,10,10,9,11,8,10};
    for(int i=0;i<15;i++){
        uint32_t vals[2]={seqs[i]->p?(uint32_t)(seqs[i]->p-seqs[i]->sequence):0,(uint32_t)lengths[i]};
        for(int j=0;j<2;j++){byte b[4]={vals[j]>>24,vals[j]>>16,vals[j]>>8,vals[j]};fwrite(b,1,4,f);}
        fwrite(seqs[i]->sequence,1,(size_t)lengths[i],f);
    }
}
'''

AM_OBSERVE = r'''
static int ir_loads,ir_unloads;
void *IRAMCacheName(char *name,int tag){if(!strcmp(name,"AMMNUM0"))ir_loads++;return UIWCacheName(name,tag);}
void IRAMChangeTag(void *p,int tag){(void)p;(void)tag;ir_unloads++;}
void IRAMWords(int *a){
    int v[17]={automapactive,viewactive,followplayer,grid,cheating,
        cheat_amap.p?cheat_amap.p-cheat_amap.sequence:0,m_x,m_y,m_w,m_h,scale_mtof,
        mtof_zoommul,m_paninc.x,m_paninc.y,markpointnum,ir_loads,ir_unloads/10};
    memcpy(a,v,sizeof(v));
}
void IRAMMarks(int *a){for(int i=0;i<10;i++){a[2*i]=markpoints[i].x;a[2*i+1]=markpoints[i].y;}}
'''

def build_native(out, opt, sanitize):
    ui.build_ui(out, opt, sanitize)
    manifest=json.loads((out/'ui-build-manifest.json').read_text())
    host=(out/'ui-host.c').read_text()
    host=host.replace('boolean precache=false, secretexit=false, automapactive=false;',
                      'boolean precache=false, secretexit=false;')
    host=host.replace('void AM_Stop(void) { automapactive=false; }\n','')
    bodies=[];records=[]
    for name in ['G_Responder','G_DeferedInitNew']:
        body,record=extract('g_game.c',name);bodies.append(body);records.append(record)
    keyboard,record=ui.production.keyboard.extract();records.append(record)
    platform=KEYBOARD.replace('static void native_command',keyboard+'\n'+'\n'.join(bodies)+'\nstatic void native_command')
    host=host.replace('int main(int argc,char **argv) {',platform+'\nint main(int argc,char **argv) {')
    host=host.replace('int forward,side,angle,buttons,render,full,oldfull=0,refresh=1;',
        'FILE *runtime=fopen(strcat(strcpy(path,argv[2]),"/runtime.bin"),"wb");if(!runtime)abort();\n'
        'int render,full,count,oldfull=0,refresh=1;')
    start=host.index('    while(fscanf(commands,')
    end=host.index('        P_Ticker();',start)
    host=host[:start]+'''    while(fscanf(commands,"%d %d %d",&render,&full,&count)==3) {
        for(int i=0;i<count;i++){int type,key;if(fscanf(commands,"%d %d",&type,&key)!=2)abort();event_t ev={type,key,0,0};G_Responder(&ev);}
        ticcmd_t cmd;native_command(&cmd);players[0].cmd=cmd;
        if((cmd.buttons&BT_SPECIAL)&&(cmd.buttons&BT_SPECIALMASK)==BTS_PAUSE)paused=!paused;
'''+host[end:]
    host=host.replace('P_Ticker();ST_Ticker();HU_Ticker();gametic++;', 'P_Ticker();ST_Ticker();AM_Ticker();HU_Ticker();gametic++;')
    host=host.replace('if(render) { HU_Erase();ST_Drawer(full,refresh);refresh=0;R_RenderPlayerView(players);HU_Drawer();',
        'if(render) { HU_Erase();if(automapactive)AM_Drawer();ST_Drawer(full,refresh);refresh=0;if(!automapactive)R_RenderPlayerView(players);HU_Drawer();if(paused)V_DrawPatchDirect((320-68)/2,4,0,UIWCacheName("M_PAUSE",PU_CACHE));')
    host=host.replace('ui_record(ui);','ui_record(ui);runtime_record(runtime);')
    host=host.replace('fclose(ui);','fclose(runtime);fclose(ui);')
    (out/'input-host.c').write_text(host)
    st=(out/'st_stuff.c').read_text()
    start=st.index("      // 'mus' cheat");end=st.index('      // Simplified,',start)
    excluded=ref.sha(st[start:end].encode());st=st[:start]+st[end:]
    (out/'st_stuff.c').write_text(st+ST_OBSERVE)
    am=(ref.SOURCE/'am_map.c').read_text()
    manifest['sources']['am_map.c']=ref.sha(am.encode())
    am = am.replace('#include "z_zone.h"', '#include "z_zone.h"\n#undef Z_ChangeTag\n#define Z_ChangeTag IRAMChangeTag\nvoid IRAMChangeTag(void *,int);')
    (out/'am_map.c').write_text('#define W_CacheLumpName IRAMCacheName\nvoid *UIWCacheName(char *,int);\n'+am+AM_OBSERVE)
    (out/'m_cheat.c').write_bytes((ref.SOURCE/'m_cheat.c').read_bytes())
    manifest['sources']['m_cheat.c']=ref.sha((out/'m_cheat.c').read_bytes())
    flags=[f.replace('<HARNESS>',str(HERE.parent)) for f in manifest['flags']]
    flags+=['-Wno-implicit-int'] # Original AM has K&R implicit-int declarations.
    if sanitize:flags+=['-fno-sanitize=array-bounds']
    cmd=['clang',*flags,'-ffunction-sections','-fdata-sections','-I'+str(out),
         *[str(out/name) for name in renderer.UNITS+PUNITS],str(out/'game_functions.c'),
         *[str(out/name) for name in ['st_stuff.c','st_lib.c','hu_stuff.c','hu_lib.c','v_video.c','am_map.c','m_cheat.c']],
         str(out/'input-host.c'),'-I'+str(HERE.parent/'gameplay'),'-Wl,-dead_strip','-o',str(out/'input-runtime')]
    r=subprocess.run(cmd,capture_output=True,text=True);(out/'input-build.log').write_text(r.stdout+r.stderr)
    if r.returncode:raise RuntimeError(r.stderr)
    manifest.update(inputExtractions=records,excludedMusicBranchSha256=excluded,
        inputCompilerFlags=flags,
        inputHostSha256=ref.sha(host.encode()),STObservationSha256=ref.sha(ST_OBSERVE.encode()),
        AMObservationSha256=ref.sha(AM_OBSERVE.encode()),inputBuilderSha256=ref.sha(Path(__file__).read_bytes()))
    manifest['adaptations'] += [dict(scope='Raw input',reason='Verbatim G_Responder/G_BuildTiccmd/G_DeferedInitNew; keyboard only, single-player level. WASD/E aliases temporarily project into native default keys only for command building; original responder bytes/order and gamekeydown remain unchanged.'),
        dict(scope='Deferred IDCLEV',reason='Persist original request; action loop and multi-map loading excluded identically in native and EVM profiles.'),
        dict(scope='AM graphics',reason='Unchanged original AM bodies; exact immutable marker bytes borrowed through the same UI cache boundary; cache/tag counters observed outside gameplay zone. No new whole-process zone equivalence claim.'),
        dict(scope='IDMUS',reason='Same explicit music branch exclusion as accepted cheat oracle; no audio support.')]
    return out/'input-runtime',manifest

def runtime_records(raw,count):
    at=0;records=[]
    def words(n):
        nonlocal at
        result=list(struct.unpack_from('>'+str(n)+'i',raw,at));at+=n*4;return result
    for _ in range(count):
        s={};s['cheatWords']=words(11)
        s['gamekeydownHex']=raw[at:at+32].hex();at+=32
        s['automapWords']=words(17);s['marks']=words(20);s['sequences']=[]
        for _ in range(15):
            cursor,length=words(2);s['sequences'].append(dict(cursor=cursor,hex=raw[at:at+length].hex()));at+=length
        n=words(1)[0];s['lineFlags']=words(n);records.append(s)
    assert at==len(raw),(at,len(raw))
    return records

def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true')
    p.add_argument('--output',type=Path,default=ROOT/'artifacts/local/input-runtime-native');a=p.parse_args()
    rows=packets();outputs={}
    with tempfile.TemporaryDirectory(prefix='doom-input-native-') as temporary:
        tmp=Path(temporary);commands=tmp/'commands.txt'
        commands.write_text(''.join(' '.join(map(str,[int(r['render']),int(r['fullscreen']),len(r['events']),*[v for ev in r['events'] for v in ev]]))+'\n' for r in rows))
        baseline=None;manifest=None
        for label,opt,san,fill in [('O0','O0',False,'0'),('O2','O2',False,'0'),('sanitize','O2',True,'0'),('fill','O2',True,'0xa5')]:
            binary,build=build_native(tmp/label,opt,san);dest=tmp/(label+'-output');dest.mkdir()
            run=subprocess.run([str(binary),str(ui.production.WAD),str(dest),str(commands),'ordinary'],capture_output=True,
                env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0:halt_on_error=1','UBSAN_OPTIONS':'halt_on_error=1','DOOM_ORACLE_ALLOCATION_FILL':fill})
            assert run.returncode==0 and not run.stderr,(label,run.stderr.decode())
            current={f.name:f.read_bytes() for f in dest.iterdir()}
            if baseline is None:baseline=current
            else:
                assert current.keys()==baseline.keys()
                for name in current:assert current[name]==baseline[name],(label,name)
            if label=='O2':manifest=build
        outputs['packets.json']=(json.dumps(rows,indent=2)+'\n').encode()
        outputs['players.json']=(json.dumps(player_records(baseline['ticks.bin']),indent=2)+'\n').encode()
        outputs['runtime.json']=(json.dumps(runtime_records(baseline['runtime.bin'],len(rows)),indent=2)+'\n').encode()
        states=[];record_size=173
        assert len(baseline['ui.bin'])==len(rows)*record_size
        for i in range(len(rows)):
            b=baseline['ui.bin'][i*record_size:(i+1)*record_size]
            s=dict(zip(['clock','face','facecount','palette','revision','rndindex','messageOn','messageCounter'],struct.unpack('>8i',b[:32])))
            s.update(messageHex=b[32:113].hex(),cards=list(struct.unpack('>6i',b[113:137])),weapons=list(struct.unpack('>9i',b[137:])))
            states.append(s)
        outputs['ui.json']=(json.dumps(states,indent=2)+'\n').encode()
        for name,data in baseline.items():
            if name.startswith(('frame-','palette-')) or name in ['events.json','summary.json']:outputs[name]=data
        manifest['flags']=[f.replace(str(tmp/'O2'),'<BUILD>') for f in manifest['flags']]
        manifest['inputCompilerFlags']=[f.replace(str(tmp/'O2'),'<BUILD>') for f in manifest['inputCompilerFlags']]
        outputs['build-manifest.json']=(json.dumps(manifest,indent=2)+'\n').encode()
        identity=json.loads((ROOT/'artifacts/local/wad/bundle.json').read_text())['resourceIdentity']
        assert ref.sha(ui.production.WAD.read_bytes())==identity['wadSha256']
        outputs['manifest.json']=(json.dumps(dict(kind='original-production-input-runtime-oracle',upstreamCommit=ref.UPSTREAM,
            resourceIdentity=identity,tics=len(rows),events=sum(len(r['events']) for r in rows),frames=sum(r['render'] for r in rows),
            profiles=['O0','O2','ASan/UBSan','ASan/UBSan allocation-fill0xa5'],
            sourceHashes={str(Path(__file__).relative_to(ROOT)):ref.sha(Path(__file__).read_bytes())},
            files={n:ref.sha(d) for n,d in sorted(outputs.items())}),indent=2)+'\n').encode()
    for name,data in outputs.items():
        path=a.output/name
        if a.check:assert path.read_bytes()==data,name
        else:path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    print('PASS original production input:',len(rows),'tics,',sum(r['render'] for r in rows),'frames; four native profiles exact')

if __name__=='__main__':main()
