#!/usr/bin/env python3
"""Extract active finale functions verbatim; compare O0/O2/ASan+UBSan outputs."""
import hashlib, json, pathlib, re, struct, subprocess, tempfile, sys
ROOT = pathlib.Path(__file__).resolve().parents[3]
HERE = pathlib.Path(__file__).resolve().parent
SRC = ROOT/'original/DOOM/linuxdoom-1.10'
OUT = ROOT/'test/fixtures/phase4_finale'
sha = lambda b: hashlib.sha256(b).hexdigest()
pin = 'a77dfb96cb91780ca334d0d4cfd86957558007e0'
assert subprocess.check_output(['git','-C',str(SRC),'rev-parse','HEAD'],text=True).strip() == pin
source = (SRC/'f_finale.c').read_text()
mapping = []
functions = []
for name in ['F_StartFinale','F_Ticker','F_TextWrite','F_Drawer']:
    match = re.search(r'void\s+'+name+r'\s*\([^;]*?\)\s*\{',source)
    start, end = match.start(), match.end()
    depth = 1
    while depth:
        depth += (source[end]=='{') - (source[end]=='}'); end += 1
    body = source[start:end]
    functions.append(body)
    mapping.append(dict(function=name,startLine=source[:start].count('\n')+1,endLine=source[:end].count('\n')+1,sha256=sha(body.encode())))
wad = (ROOT/'artifacts/local/freedoom/freedoom1.wad').read_bytes()
assert sha(wad) == '7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d'
n, at = struct.unpack_from('<II',wad,4)
directory = {}
for i in range(n):
    p, size, name = struct.unpack_from('<II8s',wad,at+i*16)
    directory[name.rstrip(b'\0').decode()] = (i,wad[p:p+size])
names = ['FLOOR4_8','CREDIT','HELP2'] + [f'STCFN{i:03}' for i in range(33,96)]
host = r'''
static const char *assets;
static void *alloc;
void I_Error(char *fmt,...) { (void)fmt; abort(); }
byte *I_AllocLow(int n) { alloc=calloc(1,n); return alloc; }
void *W_CacheLumpName(char *name,int tag) {
 (void)tag; static void *cache[100]; static char labels[100][9]; static int count;
 for(int i=0;i<count;i++) if(!strcmp(labels[i],name)) return cache[i];
 char path[4096]; snprintf(path,sizeof(path),"%s/%s.bin",assets,name);
 FILE *f=fopen(path,"rb"); if(!f) abort(); fseek(f,0,SEEK_END); long size=ftell(f); rewind(f);
 void *p=malloc(size); if(fread(p,1,size,f)!=(size_t)size)abort(); fclose(f);
 strcpy(labels[count],name); cache[count++]=p; return p;
}
static void out(int x) { unsigned u=(unsigned)x; byte b[4]={u>>24,u>>16,u>>8,u}; fwrite(b,1,4,stdout); }
int main(int argc,char **argv) {
 if(argc!=2) return 1; assets=argv[1]; V_Init();
 for(int i=0;i<63;i++) { char name[9]; snprintf(name,9,"STCFN%03d",33+i); hu_font[i]=W_CacheLumpName(name,101); }
 int checkpoints[]={0,1,10,13,100,1000,strlen(e1text)*3+250,strlen(e1text)*3+251,strlen(e1text)*3+450};
 for(int mode=0;mode<=3;mode++) {
  if(mode==2)continue; gamemode=mode; gameaction=7; gamestate=0; viewactive=automapactive=1; wipegamestate=0;
  memset(screens[0],0,64000); F_StartFinale(); int tick=0;
  for(int i=0;i<9;i++) {
   while(tick<checkpoints[i]) { players[0].cmd.buttons=3; F_Ticker(); tick++; }
   F_Drawer(); out(finalestage);out(finalecount);out(gameaction);out(gamestate);out(viewactive);out(automapactive);out(wipegamestate);
   fwrite(screens[0],1,64000,stdout);
  }
 }
 return 0;
}
'''
OUT.mkdir(parents=True,exist_ok=True)
files = {}; profiles = {}
def save(name,data):
    path=OUT/name
    if '--check' in sys.argv: assert path.read_bytes()==data, name
    else: path.write_bytes(data)
blob = bytearray(); records = bytearray()
for name in names:
    data = directory[name][1]
    records += name.encode().ljust(8,b'\0') + struct.pack('<II',len(blob),len(data))
    blob += data
save('resources.bin',bytes(blob)); save('directory.bin',bytes(records))
save('COPYING.txt',(ROOT/'test/fixtures/phase4_episode_startup/COPYING.txt').read_bytes())
files.update({name:sha((OUT/name).read_bytes()) for name in ['resources.bin','directory.bin','COPYING.txt']})
with tempfile.TemporaryDirectory() as tmp:
    tmp = pathlib.Path(tmp)
    for name in names:
        blob = directory[name][1]; (tmp/(name+'.bin')).write_bytes(blob)
    texts = '#include "d_englsh.h"\nchar *e1text=E1TEXT;\n' + '\n'.join('char *'+name+'="";' for name in ['e2text','e3text','e4text','c1text','c2text','c3text','c4text','c5text','c6text'])
    (tmp/'driver.c').write_text('#include "compat.h"\n'+texts+'\n'+'\n'.join(functions)+'\n'+host)
    # Only the variable-tail columnofs header array is a native layout extension.
    for profile, extra in [('O0',['-O0']),('O2',['-O2']),('san',['-O1','-fsanitize=address,undefined','-fno-sanitize=array-bounds'])]:
        binary = tmp/profile
        command=['clang','-std=c11','-fsigned-char',*extra,'-include',str(HERE/'../video/compat.h'),'-I'+str(HERE),'-I'+str(SRC),str(tmp/'driver.c'),str(SRC/'v_video.c'),str(SRC/'m_bbox.c'),'-o',str(binary)]
        compiled = subprocess.run(command,capture_output=True)
        if compiled.returncode:
            raise RuntimeError(compiled.stderr.decode())
        import os
        run=subprocess.run([str(binary),str(tmp)],check=True,capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'})
        profiles[profile]=sha(run.stdout)
        if profile=='O0': expected=run.stdout
        else: assert run.stdout==expected
    size=64028
    assert len(expected)==27*size
    checkpoints=[0,1,10,13,100,1000]
    # Native total-tic checkpoints and state are carried by the exact observations.
    for i in range(27):
        record=expected[i*size:(i+1)*size]
        save(f'{i}.bin',record)
        files[f'{i}.bin']=sha(record)
manifest=dict(kind='original-e1-finale',upstreamCommit=pin,wadSha256=sha(wad),functionMapping=mapping,
    sourceHashes={name:sha((SRC/name).read_bytes()) for name in ['f_finale.c','d_englsh.h','v_video.c','m_bbox.c']},
    harnessHashes={name:sha((HERE/name).read_bytes()) for name in ['finale.py','compat.h']},
    compiler=subprocess.check_output(['clang','--version'],text=True).splitlines()[0],
    profiles=profiles,exactNativeAgreement=True,records=27,files=files,
    resources=[dict(name=name,lumpId=directory[name][0],sha256=sha(directory[name][1])) for name in names],
    adaptations=['Audio omitted; other-episode/cast boundaries abort if reached; borrowed immutable WAD buffers; calloc video backing.',
        'ASan/UBSan disables variable-tail columnofs array-bounds only; leak detection off for borrowed process-lifetime assets.',
        'No physical-zone or browser/playthrough acceptance claim.'])
save('manifest.json',(json.dumps(manifest,indent=2)+'\n').encode())
print(json.dumps(dict(pass_=True,records=27,profiles=profiles)))
