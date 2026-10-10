#!/usr/bin/env python3
"""Goal 4.11: original gameplay + ST/HU/video, with declared immutable UI borrowing."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE.parent / 'gameplay'))
from build import build, renderer, PUNITS, ref
from verify import player_records

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

production = load('ui_packets', HERE.parent / 'gameplay/production.py')

def packets():
    rows = []
    # Actual keyboard run/reverse reaches the original E1M1 health bonus. This
    # route is derived from the accepted movement scenario, with no state setup.
    for name, count, mask in [('run-forward', 56, 257), ('backward', 24, 2),
                              ('settle', 20, 0), ('fire', 25, 128), ('expiry', 85, 0)]:
        for _ in range(count):
            rows.append(dict(tic=len(rows)+1, segment=name, mask=mask, render=False))
    for row in rows:
        row['fullscreen'] = 70 <= row['tic'] <= 100
    for tic in [1,20,40,56,64,65,70,100,101,125,203,204,len(rows)]:
        rows[tic-1]['render'] = True
    return rows

UI_PLATFORM = r'''
static byte ui_rgb[768];
static unsigned ui_revision;
byte *I_AllocLow(int n) { return calloc(1,(size_t)n); }
void *UIAlloc(int n,int tag,void *user) { (void)tag;(void)user;return calloc(1,(size_t)n); }
void *UIWCacheNum(int n,int tag) {
    (void)tag;static void **cache;
    if(!cache)cache=calloc((size_t)numlumps,sizeof(*cache));
    if(!cache[n]) { cache[n]=malloc((size_t)W_LumpLength(n));W_ReadLump(n,cache[n]); }
    return cache[n];
}
void *UIWCacheName(char *name,int tag) {return UIWCacheNum(W_GetNumForName(name),tag);}
void I_SetPalette(byte *p) {for(int i=0;i<768;i++)ui_rgb[i]=gammatable[usegamma][p[i]];ui_revision++;}
int showMessages=1;
extern void UIStatusWords(int *);
extern void UIHudWords(int *);
extern char *UIMessageBytes(void);
static void ui_record(FILE *f) {
    int a[4],b[2];UIStatusWords(a);UIHudWords(b);
    for(int i=0;i<4;i++)word(f,a[i]);word(f,ui_revision);word(f,rndindex);
    for(int i=0;i<2;i++)word(f,b[i]);fwrite(UIMessageBytes(),1,81,f);
    for(int i=0;i<6;i++)word(f,players[0].cards[i]);
    for(int i=0;i<9;i++)word(f,players[0].weaponowned[i]);
}
'''

def build_ui(out, opt, sanitize):
    build(out, opt, sanitize)
    manifest = json.loads((out/'gameplay-build-manifest.json').read_text())
    host = (HERE.parent/'gameplay/host.c').read_text()
    for text in ['byte *screens[5];\n',
                 'void V_MarkRect(int x,int y,int width,int height) { (void)x;(void)y;(void)width;(void)height; }\n',
                 'void V_DrawPatch(int x,int y,int screen,patch_t *patch) { I_Error("Unexpected border draw"); }\n',
                 'void ST_Start(void) {}\n', 'void HU_Start(void) {}\n']:
        assert host.count(text) == 1, text
        host = host.replace(text, '')
    host = host.replace('#include "info.h"', '#include "info.h"\n#include "v_video.h"')
    host = host.replace('int main(int argc,char **argv) {', UI_PLATFORM+'\nint main(int argc,char **argv) {')
    host = host.replace('screens[0]=calloc(1,320*200);screens[1]=calloc(1,320*200);',
                        'V_Init();ST_Init();HU_Init();screenblocks=10;')
    host = host.replace('int forward,side,angle,buttons,render;',
                        'FILE *ui=fopen(strcat(strcpy(path,argv[2]),"/ui.bin"),"wb");if(!ui)abort();\n'
                        'int forward,side,angle,buttons,render,full,oldfull=0,refresh=1;')
    host = host.replace('fscanf(commands,"%d %d %d %d %d",&forward,&side,&angle,&buttons,&render)==5',
                        'fscanf(commands,"%d %d %d %d %d %d",&forward,&side,&angle,&buttons,&render,&full)==6')
    host = host.replace('P_Ticker();gametic++;', 'P_Ticker();ST_Ticker();HU_Ticker();gametic++;')
    host = host.replace('if(render) { R_RenderPlayerView(players);',
                        'if(full!=oldfull){R_SetViewSize(full?11:10,0);R_ExecuteSetViewSize();refresh=1;oldfull=full;}\n'
                        'if(render) { HU_Erase();ST_Drawer(full,refresh);refresh=0;R_RenderPlayerView(players);HU_Drawer();')
    host = host.replace('writefile(argv[2],name,screens[0],64000); }',
                        'writefile(argv[2],name,screens[0],64000);'
                        'snprintf(name,sizeof(name),"palette-%06d.bin",gametic);writefile(argv[2],name,ui_rgb,768); }\n'
                        'ui_record(ui);')
    host = host.replace('fclose(commands);', 'fclose(ui);fclose(commands);')
    (out/'ui-host.c').write_text(host)
    for name in ['st_stuff.c','st_lib.c','hu_stuff.c','hu_lib.c','v_video.c']:
        text = (ref.SOURCE/name).read_text()
        manifest['sources'][name] = ref.sha(text.encode())
        if name in ['st_stuff.c','hu_stuff.c']:
            text = '#define W_CacheLumpName UIWCacheName\n#define W_CacheLumpNum UIWCacheNum\n'+text
        if name == 'st_stuff.c':
            text = '#define Z_Malloc UIAlloc\n'+text
            text += '\nvoid UIStatusWords(int *a){a[0]=st_clock;a[1]=st_faceindex;a[2]=st_facecount;a[3]=st_palette;}\n'
        if name == 'hu_stuff.c':
            text += '\nvoid UIHudWords(int *a){a[0]=message_on;a[1]=message_counter;}\nchar *UIMessageBytes(void){return w_message.l[0].l;}\n'
        (out/name).write_text(text)
    flags = manifest['flags']
    flags = [f.replace('<HARNESS>',str(HERE.parent)).replace(str(out),str(out)) for f in flags]
    # Original patch_t uses a variable-length columnofs tail beyond its declared
    # eight entries. Keep ASan physical bounds; exclude that existing array-subobject check.
    if sanitize: flags += ['-fno-sanitize=array-bounds']
    cmd = ['clang',*flags,'-ffunction-sections','-fdata-sections','-I'+str(out),
           *[str(out/name) for name in renderer.UNITS+PUNITS], str(out/'game_functions.c'),
           *[str(out/name) for name in ['st_stuff.c','st_lib.c','hu_stuff.c','hu_lib.c','v_video.c']],
           str(out/'ui-host.c'),'-I'+str(HERE.parent/'gameplay'),'-Wl,-dead_strip','-o',str(out/'ui')]
    r = subprocess.run(cmd,capture_output=True,text=True)
    (out/'ui-build.log').write_text(r.stdout+r.stderr)
    if r.returncode: raise RuntimeError(r.stderr)
    manifest.update(uiHostSha256=ref.sha(host.encode()), uiPlatform=UI_PLATFORM,
                    adaptations=manifest['adaptations']+[
                        dict(scope='UI immutable host buffers', reason='ST/HU patch reads borrow exact WAD bytes outside the gameplay zone; screen4 is consumer-owned calloc. This matches the existing ResourceView/video consumer boundary, preserving accepted renderer physical backing. No claim of new whole-process zone equivalence.'),
                        dict(scope='UI dispatch', reason='Original P_Ticker -> ST_Ticker -> HU_Ticker and HU_Erase -> ST_Drawer -> R_RenderPlayerView -> HU_Drawer; view sizes10/11 and explicit refresh. Entire original ST/HU/video translation units, including inactive single-player chat code.')])
    (out/'ui-build-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return out/'ui'

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--check',action='store_true')
    p.add_argument('--output',type=Path,default=ROOT/'artifacts/local/ui-native')
    a = p.parse_args()
    rows = packets()
    outputs = {}
    with tempfile.TemporaryDirectory(prefix='doom-ui-native-') as temporary:
        tmp = Path(temporary)
        original, extraction = production.keyboard.extract()
        generated = (HERE.parent/'phase3_input/host.c').read_text()+'\n'+original+'\n'+production.DRIVER
        source = tmp/'keyboard.c';source.write_text(generated)
        ref.invoke(['clang','-std=c11','-fsigned-char','-O2','-I'+str(ref.SOURCE),str(source),'-o',str(tmp/'keyboard')])
        mask_input = ''.join(f"{r['mask']} {int(r['render'])}\n" for r in rows)
        result = subprocess.run([str(tmp/'keyboard')],input=mask_input.encode(),capture_output=True,check=True)
        assert not result.stderr
        commands = [list(map(int,l.split())) for l in result.stdout.decode().splitlines()]
        for row, cmd in zip(rows, commands):
            row['ticcmd'] = dict(zip(['forwardmove','sidemove','angleturn','buttons','render'],cmd))
        command_file = tmp/'commands.txt'
        command_file.write_text(''.join(' '.join(map(str,cmd+[int(r['fullscreen'])]))+'\n' for r,cmd in zip(rows,commands)))
        baseline = None
        for label,opt,san,fill in [('O0','O0',False,'0'),('O2','O2',False,'0'),('sanitize','O2',True,'0'),('fill','O2',True,'0xa5')]:
            binary = build_ui(tmp/label,opt,san)
            dest = tmp/(label+'-output');dest.mkdir()
            run = subprocess.run([str(binary),str(production.WAD),str(dest),str(command_file),'ordinary'],
                                 capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0:halt_on_error=1','UBSAN_OPTIONS':'halt_on_error=1','DOOM_ORACLE_ALLOCATION_FILL':fill})
            assert run.returncode == 0 and not run.stderr, (label,run.stderr.decode())
            current = {f.name:f.read_bytes() for f in dest.iterdir()}
            if baseline is None: baseline=current
            else:
                assert current.keys()==baseline.keys()
                for name in current: assert current[name]==baseline[name], (label,name)
        outputs['packets.json'] = (json.dumps(rows,indent=2)+'\n').encode()
        outputs['players.json'] = (json.dumps(player_records(baseline['ticks.bin']),indent=2)+'\n').encode()
        record_size = 8*4+81+15*4
        assert len(baseline['ui.bin']) == len(rows)*record_size
        states=[]
        fields=['clock','face','facecount','palette','revision','rndindex','messageOn','messageCounter']
        for i in range(len(rows)):
            b=baseline['ui.bin'][i*record_size:(i+1)*record_size]
            s=dict(zip(fields,struct.unpack('>8i',b[:32])))
            s['messageHex']=b[32:113].hex()
            s['cards']=list(struct.unpack('>6i',b[113:137]))
            s['weapons']=list(struct.unpack('>9i',b[137:]))
            states.append(s)
        outputs['ui.json']=(json.dumps(states,indent=2)+'\n').encode()
        for name,data in baseline.items():
            if name.startswith(('frame-','palette-')) or name in ['events.json','summary.json']: outputs[name]=data
        manifest=json.loads((tmp/'O2/ui-build-manifest.json').read_text())
        manifest['flags']=[f.replace(str(tmp/'O2'),'<BUILD>') for f in manifest['flags']]
        outputs['build-manifest.json']=(json.dumps(manifest,indent=2)+'\n').encode()
        identity=json.loads((ROOT/'artifacts/local/wad/bundle.json').read_text())['resourceIdentity']
        assert ref.sha(production.WAD.read_bytes())==identity['wadSha256']
        outputs['manifest.json']=(json.dumps(dict(kind='original-production-ui-oracle',upstreamCommit=ref.UPSTREAM,
            resourceIdentity=identity,tics=len(rows),profiles=['O0','O2','ASan/UBSan','ASan/UBSan allocation-fill0xa5'],
            keyboardExtraction=extraction, sourceHashes={str(Path(__file__).relative_to(ROOT)):ref.sha(Path(__file__).read_bytes())},
            files={n:ref.sha(d) for n,d in sorted(outputs.items())}),indent=2)+'\n').encode()
    for name,data in outputs.items():
        path=a.output/name
        if a.check: assert path.read_bytes()==data,name
        else: path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    print('PASS original production UI:',len(rows),'tics,',sum(r['render'] for r in rows),'frames; O0/O2/sanitizers/fill exact')

if __name__=='__main__': main()
