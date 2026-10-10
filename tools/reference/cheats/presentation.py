#!/usr/bin/env python3
"""Raw original ST cheats -> status/palette and original HUD widgets, native pixels."""
import argparse, hashlib, json, os, pathlib, platform, struct, subprocess, tempfile
from reference import SOURCE,ROOT,HERE,FIX,extract,sha
CODES=['iddqd','iddqd','idfa','idkfa','idclip','idspispopd','idbehold','idbeholdv','idbeholds','idbeholdi','idbeholdr','idbeholda','idbeholdl','idchoppers','idmypos']
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args()
    # Reuse already-accepted resource/platform doubles, not its traces/fixtures.
    host=(HERE.parent/'statusbar/host.c').read_text().split('int main(')[0]
    host=host.replace('names[128][9]','names[256][9]').replace('lumps[128]','lumps[256]')
    body,bodymeta=extract('p_inter.c','P_GiveBody');power,powermeta=extract('p_inter.c','P_GivePower')
    host=host.replace('boolean P_GivePower(player_t *p,int power) { (void)p;(void)power;abort(); }',body+'\n'+power)
    generated=host+'\n'+(HERE/'presentation_driver.c').read_text()
    output=[];profiles={'O0':['-O0'],'O2':['-O2'],'sanitize':['-O1','-g','-fsanitize=address,undefined','-fno-sanitize=array-bounds','-fno-omit-frame-pointer']}
    inputs=struct.pack('>I',len(CODES))+b''.join(struct.pack('>I',len(c))+c.encode() for c in CODES)
    with tempfile.TemporaryDirectory(prefix='doom-cheat-presentation-') as temp:
        path=pathlib.Path(temp);(path/'oracle.c').write_text(generated);(path/'input.bin').write_bytes(inputs)
        assets=path/'assets';assets.mkdir()
        for folder in ('phase4_statusbar','phase4_hud'):
            for p in (ROOT/'test/fixtures'/folder).glob('*.bin'):
                if p.stem in ('PLAYPAL','STBAR','STTMINUS','STTPRCNT','STARMS') or p.stem.startswith(('STF','STTNUM','STYSNUM','STKEYS','STGNUM','STCFN')):(assets/p.name).write_bytes(p.read_bytes())
        sources=['st_lib','v_video','m_bbox','m_random','r_main','tables','d_items','m_cheat','hu_lib']
        flags=['-std=c11','-fsigned-char','-fwrapv','-ffunction-sections','-fdata-sections','-include',str(SOURCE/'doomdef.h'),'-I',str(HERE.parent/'statusbar'),'-I',str(SOURCE)]
        for name,opts in profiles.items():
            cmd=['clang',*flags,*opts,str(path/'oracle.c'),*[str(SOURCE/(s+'.c')) for s in sources],'-Wl,-dead_strip' if platform.system()=='Darwin' else '-Wl,--gc-sections','-o',str(path/name)]
            run=subprocess.run(cmd,capture_output=True,text=True);assert run.returncode==0,run.stderr
            run=subprocess.run([str(path/name),str(path/'input.bin'),str(assets)],capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0:halt_on_error=1','UBSAN_OPTIONS':'halt_on_error=1'});assert run.returncode==0 and not run.stderr,run.stderr.decode()
            output.append(run.stdout)
        assert output[0]==output[1]==output[2]
        data=output[0];assert len(data)==len(CODES)*75016
        binary=struct.pack('>I',len(CODES));rows=[]
        for i,code in enumerate(CODES):
            record=data[i*75016:(i+1)*75016]
            hashes=[hashlib.sha256(record[:64000]).digest(),hashlib.sha256(record[64000:74240]).digest(),hashlib.sha256(record[74240:75008]).digest()]
            binary+=struct.pack('>I',len(code))+code.encode()+b''.join(hashes)+record[-8:]
            rows.append(dict(code=code,sha256=[h.hex() for h in hashes],face=struct.unpack('>I',record[-8:-4])[0],palette=struct.unpack('>I',record[-4:])[0]))
        manifest=dict(cases=len(CODES),profiles=profiles,scope='Actual original ST_Responder (no music inputs), P_GivePower/P_GiveBody, ST_Ticker/Drawer and HUlib text drawing. Resource boundaries reuse accepted statusbar host; assets from accepted Freedoom fixtures. No AM rendering or map loading.',
            sanitizerExclusions='Native v_video variable-width column table excludes array-bounds instrumentation, as accepted video/statusbar profile; leak detection disabled for process-lifetime assets.',
            extractions=[bodymeta,powermeta],generatedSourceSha256=sha(generated.encode()),vectorsSha256=sha(binary),assetSha256={p.name:sha(p.read_bytes()) for p in sorted(assets.iterdir())},
            sourceSha256={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in [HERE/'presentation.py',HERE/'presentation_driver.c',HERE.parent/'statusbar/host.c',SOURCE/'st_stuff.c',*[SOURCE/(s+'.c') for s in sources]]},rows=rows)
        for name,value in [('presentation.bin',binary),('presentation.json',(json.dumps(manifest,indent=2)+'\n').encode())]:
            if args.check:assert (FIX/name).read_bytes()==value,'stale '+name
            else:(FIX/name).write_bytes(value)
    print(f'PASS {len(CODES)} raw-cheat status/HUD pixel comparisons; native O0/O2/sanitized exact')
if __name__=='__main__':main()
