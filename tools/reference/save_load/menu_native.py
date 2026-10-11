#!/usr/bin/env python3
"""Original six-slot drawing/text-entry oracle; new Freedoom-only fixtures."""
import argparse,importlib.util,json,os,re,shutil,struct,subprocess,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE.parent));import reference as ref
spec=importlib.util.spec_from_file_location('save_menu_options_extract',HERE.parent/'options/reference.py')
options=importlib.util.module_from_spec(spec);spec.loader.exec_module(options)
NAMES=options.FUNCTIONS+['M_ReadSaveStrings','M_DrawLoad','M_DrawSaveLoadBorder','M_LoadSelect',
    'M_LoadGame','M_DrawSave','M_DoSave','M_SaveSelect','M_SaveGame']

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--wad',type=Path,required=True);ap.add_argument('--check',action='store_true');ap.add_argument('--output',type=Path,default=ROOT/'artifacts/local/save-load/menu-native-v2');a=ap.parse_args()
    assert ref.sha(a.wad.read_bytes())=='7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d'
    text=(ref.SOURCE/'m_menu.c').read_text();end=text.index('void M_ReadSaveStrings(void)\n{');prefix=text[:end]
    units=[];spans=[]
    for name in NAMES:body,span=options.extract(text,name);units.append(body);spans.append(span)
    prototypes=re.findall(r'void\s+(M_\w+)\s*\(([^;{}]*)\)\s*;',prefix)
    stubs='\n'.join('void '+name+'('+args+') { abort(); }' for name,args in prototypes if name not in NAMES)
    globals_=text[text.index('char    detailNames'):text.index('void M_DrawOptions(void)\n{')]
    host=(HERE.parent/'options/host.c').read_text()
    host=host.replace('void M_DoSave(int slot) { (void)slot;abort(); }','''gamestate_t gamestate=GS_LEVEL;
static int savedSlot=-1,loadedSlot=-1;static char savedName[24];
void G_SaveGame(int slot,char *description){savedSlot=slot;strcpy(savedName,description);}
void G_LoadGame(char *name){loadedSlot=name[strlen(name)-5]-'0';}
int M_CheckParm(char *name){(void)name;return 0;}''')
    host=host[:host.index('int main(int argc,char **argv) {')]+r'''
int main(int argc,char **argv) {
 if(argc!=3)abort();FILE*f=fopen(argv[1],"rb");fseek(f,0,SEEK_END);long n=ftell(f);rewind(f);wad=malloc(n);fread(wad,1,n,f);fclose(f);
 wadcount=read32(wad+4);waddir=read32(wad+8);gamemode=retail;screenblocks=10;showMessages=1;V_Init();
 for(int i=0;i<HU_FONTSIZE;i++){char name[9];snprintf(name,9,"STCFN%03d",33+i);hu_font[i]=W_CacheLumpName(name,PU_STATIC);}
 if(chdir(argv[2]))abort();
 for(int i=0;i<6;i++){char name[30];snprintf(name,30,"doomsav%d.dsg",i);if(i==0||i==2||i==5){char description[24]={0};strcpy(description,i==0?"MOVEMENT":i==2?"COMBAT":"PROJECTILE");FILE*g=fopen(name,"wb");fwrite(description,1,24,g);fclose(g);}}
 M_Init();usergame=true;M_ReadSaveStrings();
 for(int menu=0;menu<2;menu++)for(int slot=0;slot<6;slot++)for(int skull=0;skull<2;skull++){
  menuactive=true;currentMenu=menu?&SaveDef:&LoadDef;itemOn=slot;whichSkull=skull;char name[50];snprintf(name,50,"slots-%d-%d-%d.bin",menu,slot,skull);screen(argv[2],name);
 }
 menuactive=true;currentMenu=&SaveDef;itemOn=1;whichSkull=0;M_SaveSelect(1);
 int keys[]={'m','o','v','e',KEY_BACKSPACE,'e',KEY_ESCAPE};
 for(unsigned i=0;i<sizeof(keys)/sizeof(*keys);i++){event_t e={ev_keydown,keys[i],0,0};M_Responder(&e);}
 if(saveStringEnter||strcmp(savegamestrings[1],EMPTYSTRING))abort();
 M_SaveSelect(1);event_t e={ev_keydown,'x',0,0};M_Responder(&e);screen(argv[2],"entry.bin");
 e.data1=KEY_ENTER;M_Responder(&e);if(savedSlot!=1||strcmp(savedName,"X")||menuactive)abort();
 M_StartControlPanel();M_LoadGame(0);M_LoadSelect(2);if(loadedSlot!=2||menuactive)abort();
 printf("PASS original six-slot graphics, editing/cancel/save/load\n");return 0;
}
'''
    fixtures=ROOT/'test/fixtures/save_menu';fixtures.mkdir(parents=True,exist_ok=True);canonical=None;records=[]
    for label,opt,sanitize in [('O0','O0',False),('O2','O2',False),('sanitize','O2',True)]:
        out=a.output/label;out.mkdir(parents=True,exist_ok=True)
        generated=prefix+globals_+'\nint epi;\nvoid M_VerifyNightmare(int);void M_EndGameResponse(int);void M_DoSave(int);\n'+stubs+'\n'+'\n'.join(units)+'\n#include "host.c"\n'
        (out/'menu.c').write_text(generated);(out/'host.c').write_text(host)
        (out/'values.h').write_text('#include <limits.h>\n#define MININT INT_MIN\n#define MAXINT INT_MAX\n')
        for name in ['v_video.c','m_bbox.c','doomstat.c']:shutil.copyfile(ref.SOURCE/name,out/name)
        flags=[('-'+opt if f=='-O2' else f) for f in ref.FLAGS]+['-fsigned-char','-DNORMALUNIX','-include','stdint.h','-include','stdlib.h','-include','string.h','-include','stdio.h','-include','unistd.h','-ffunction-sections','-fdata-sections','-Wno-incompatible-pointer-types','-Wno-implicit-function-declaration']
        if sanitize:flags+=['-fsanitize=address,undefined','-fno-sanitize=array-bounds','-fno-sanitize-recover=all']
        cmd=['clang',*flags,'-I'+str(ref.SOURCE),'-I'+str(out),str(out/'menu.c'),*[str(out/n) for n in ['v_video.c','m_bbox.c','doomstat.c']],'-Wl,-dead_strip','-o',str(out/'menu')]
        build=subprocess.run(cmd,text=True,capture_output=True);(out/'build.log').write_text(build.stdout+build.stderr);assert build.returncode==0,build.stderr
        run=subprocess.run([str(out/'menu'),str(a.wad.resolve()),str(out.resolve())],env=dict(os.environ,ASAN_OPTIONS='detect_leaks=0'),text=True,capture_output=True)
        (out/'run.log').write_text(run.stdout+run.stderr);assert run.returncode==0,run.stderr
        rows={p.name:p.read_bytes() for p in out.glob('*.bin')}
        if canonical is None:canonical=rows
        assert rows==canonical,label
        records.append({'profile':label,'executableSha256':ref.sha((out/'menu').read_bytes()),'command':cmd,'generatedSha256':ref.sha(generated.encode()),'hostSha256':ref.sha(host.encode())})
        print('PASS original six-slot menu',label,len(rows),'frames',flush=True)
    # A new immutable UI pack; accepted earlier fixtures remain untouched.
    wad=a.wad.read_bytes();count,offset=struct.unpack_from('<II',wad,4)
    names={'TITLEPIC','M_LOADG','M_SAVEG','M_LSLEFT','M_LSCNTR','M_LSRGHT','M_SKULL1','M_SKULL2'}|{f'STCFN{i:03d}' for i in range(33,96)}
    blob=bytearray();directory=bytearray()
    for i in range(count):
        pos,length=struct.unpack_from('<II',wad,offset+i*16);raw=wad[offset+i*16+8:offset+i*16+16];name=raw.rstrip(b'\0').decode('ascii')
        if name not in names:continue
        directory+=raw+struct.pack('<II',len(blob),length);blob+=wad[pos:pos+length]
    canonical.update({'resources.bin':bytes(blob),'directory.bin':bytes(directory)})
    for name,b in canonical.items():
        p=fixtures/name
        if a.check:assert p.read_bytes()==b,name
        else:p.write_bytes(b)
    shutil.copyfile(ROOT/'test/fixtures/evm_menu/COPYING.txt',fixtures/'COPYING.txt')
    manifest={'upstreamCommit':ref.UPSTREAM,'scope':__doc__,'sourceSha256':ref.sha(text.encode()),'extractions':spans,'profiles':records,'files':{n:ref.sha(b) for n,b in canonical.items()}}
    (fixtures/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')

if __name__=='__main__':main()
