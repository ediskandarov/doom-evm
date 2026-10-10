#!/usr/bin/env python3
"""Rebuild status bar traces/pixels using unchanged original C translation units."""
import argparse, hashlib, json, os, platform, shutil, struct, subprocess, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
SOURCE=ROOT/'original/DOOM/linuxdoom-1.10'
OUTPUT=ROOT/'test/fixtures/phase4_statusbar'
def sha(b): return hashlib.sha256(b).hexdigest()
FIELDS=['op','health','armor','weapon','ammo0','ammo1','ammo2','ammo3','max0','max1','max2','max3','weapons','cards','damage','bonus','strength','suit','invul','cheats','attack','attacker','attackerX','attackerY','angle','fullscreen','refresh','automap','deathmatch','netgame','gamma','frag0','frag1','frag2','frag3','event']
STATES=['clock','face','facecount','oldhealth','random','rndindex','palette','paletteRevision','readyValue','readyWeapon','frags','key0','key1','key2','statusbaron','firsttime','stopped','gamestate','armson','fragson','notdeathmatch','oldReady','oldHealth','oldArmor']
DEFAULT=dict(zip(FIELDS,[0,100,0,1,50,0,0,0,200,50,300,50,3,0,0,0,0,0,0,0,0,0,655360,0,0,0,0,0,0,0,0,0,0,0,0,0]))
def steps():
    suites={}
    def add(name):
        rows=[];state=DEFAULT.copy()
        def emit(label,n=1,**kwargs):
            state.update(kwargs)
            for i in range(n): rows.append({'name':label if n==1 else f'{label}-{i}', 'inputs':[state[k] for k in FIELDS]})
        suites[name]=rows
        return emit
    e=add('receipt_damage');e('first-damage',damage=9)
    e=add('inventory')
    e('initial');e('ammo-and-armor',ammo0=123,armor=87,health=99)
    for w in range(9):e(f'weapon-{w}',weapon=w,ammo1=34,ammo2=201,ammo3=12)
    for i in range(6):e(f'key-{i}',cards=1<<i)
    e('skull-over-card',cards=63);e('key-removed-original-stale-icon',cards=0)
    e('forced-refresh-removes-stale',refresh=1);e('all-weapons-pickup',refresh=0,weapons=511,bonus=8)
    e('backpack',max0=400,max1=100,max2=600,max3=100)
    e('deathmatch-negative-frags',deathmatch=1,frag0=32,frag1=2,netgame=1,refresh=1)
    e('deathmatch-positive-frags',frag0=0,frag1=12,frag2=19,refresh=0)
    e('deathmatch-overflow-digits',frag1=1234);e('cooperative',deathmatch=0,netgame=1,refresh=1)
    e('live-ammo-after-ticker',op=2,ammo3=27,weapon=1,refresh=0)
    e=add('numeric_edges')
    e('initial')
    for value in [0,1,9,10,99,100,999,1000,1994,12345,-1,-9,-10,-99,-100,-1994]:
        e(f'number-{value}',op=2,health=value,armor=value,ammo0=value,ammo1=value,ammo2=value,ammo3=value)
    e('percent-refresh',refresh=1,health=100,armor=100)
    e('disabled-widgets',fullscreen=1,refresh=0,health=80,armor=90)
    e('refresh-enable',fullscreen=0,refresh=1)
    e=add('idle_pain')
    e('idle',n=55,op=1)
    for h in [200,101,100,81,80,61,60,41,40,21,20,1,0]:
        e(f'health-{h}',health=h,n=19)
    e('dead-still-wins',bonus=10,weapons=511,cheats=2,damage=30)
    e('restart-statics-survive',op=3,health=100,bonus=0,damage=0,cheats=0)
    e('reborn',op=1,n=19)
    e=add('firing')
    e('holding-trigger',op=1,attack=1,n=75)
    e('release-trigger',attack=0,n=20)
    e('press-again',attack=1,n=73)
    e=add('priorities')
    e('initial',op=1);e('god',cheats=2,n=3)
    e('pickup-beats-god',weapons=7,bonus=4);e('damage-during-grin',bonus=0,damage=20,health=70,attacker=2,n=72)
    e('damage-ceases',damage=0,cheats=0,n=37)
    e('invulnerability',invul=20,n=2);e('death-beats-all',health=0,bonus=8,weapons=511,damage=50)
    e('restart-with-damage',op=3,health=100);e('first-tick',op=1,bonus=0)
    e=add('directions')
    e('initial',op=1)
    for x,y,a in [(10,0,0),(0,10,0),(0,-10,0),(-10,0,0),(10,10,0),(-10,-10,0),(10,-1,0),(10,0,0xffffffff),(0,10,0x80000000),(10,10,0x20000000)]:
        a=a if a<2**31 else a-2**32
        e(f'attack-{x}-{y}-{a}',damage=1,attacker=2,attackerX=x*65536,attackerY=y*65536,angle=a)
    e('large-health-loss-not-ouch',health=30,damage=40)
    e('clear-priority',damage=0,n=36)
    e('health-gain-ouch-original',health=80,damage=2,attacker=1)
    e('clear-ouch',damage=0,n=36)
    e('self-damage',health=79,damage=1,attacker=1)
    e=add('palettes')
    e('base-fullscreen',fullscreen=1)
    for gamma in range(5):
        e(f'gamma-{gamma}-restart',op=3,gamma=gamma,damage=0,bonus=0,strength=0,suit=0)
        for damage in [0,1,8,9,16,17,24,25,32,33,40,41,48,49,56,100]:e(f'damage-{damage}-gamma-{gamma}',op=2,damage=damage)
        for bonus in [1,8,9,16,17,24,25,40]:e(f'bonus-{bonus}-gamma-{gamma}',damage=0,bonus=bonus)
        for strength in [1,63,64,255,256,703,704,767,768,1000]:e(f'berserk-{strength}-gamma-{gamma}',bonus=0,strength=strength)
        for suit in [129,128,127,120,119,112,8,7,0]:e(f'suit-{suit}-gamma-{gamma}',strength=0,suit=suit)
    e('damage-over-bonus-and-suit',damage=1,bonus=40,suit=200)
    e('bonus-over-suit',damage=0);e('stop-restores-base',op=4);e('stop-idempotent',op=4)
    e=add('visibility')
    e('hidden',fullscreen=1);e('enter-automap',op=5,event=0x616d6500)
    e('automap-draw',op=0,automap=1);e('exit-automap',op=5,event=0x616d7800)
    e('hidden-after-map',op=0,automap=0);e('show-refresh',fullscreen=0,refresh=1)
    e('no-refresh',refresh=0,n=4);e('level-restart',op=3);e('level-first-draw',op=0)
    e=add('all_face_assets')
    for face in range(42):e(f'face-asset-{face}',op=6,event=face)
    e=add('face_pixels')
    # Force each pain tier's idle, damage, grin, god/dead patterns with actual draw calls.
    e('initial')
    for h in [100,79,59,39,19]:
        e(f'pain-{h}',health=h,damage=0,bonus=0,cheats=0,op=1,n=36)
        e(f'pain-draw-{h}',op=0)
        e(f'right-{h}',damage=1,attacker=2,attackerX=0,attackerY=-655360)
        e(f'left-{h}',attackerY=655360)
        e(f'front-{h}',attackerX=655360,attackerY=0)
    e('grin',weapons=7,bonus=1);e('god-clear',bonus=0,damage=0,cheats=2,op=1,n=72);e('god-draw',op=0)
    e('death',health=0)
    return suites

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args()
    assert subprocess.check_output(['git','-C',str(SOURCE),'rev-parse','HEAD'],text=True).strip()=='a77dfb96cb91780ca334d0d4cfd86957558007e0'
    subprocess.run(['git','-C',str(SOURCE),'diff','--exit-code','HEAD','--'],check=True,capture_output=True)
    manifest=json.loads((ROOT/'artifacts/local/wad/bundle.json').read_text())
    resource=(ROOT/'artifacts/local/wad/resources.bin').read_bytes();assert sha(resource)==manifest['blobSha256']
    names=['PLAYPAL','STBAR','STTMINUS','STTPRCNT','STARMS']+[f'STFB{i}' for i in range(4)]
    names += [f'{p}{i}' for p in ['STTNUM','STYSNUM'] for i in range(10)]
    names += [f'STKEYS{i}' for i in range(6)]+[f'STGNUM{i}' for i in range(2,8)]
    for i in range(5):names += [f'STFST{i}{j}' for j in range(3)]+[f'STFTR{i}0',f'STFTL{i}0',f'STFOUCH{i}',f'STFEVL{i}',f'STFKILL{i}']
    names+=['STFGOD0','STFDEAD0']
    with tempfile.TemporaryDirectory(prefix='doom-statusbar-') as td:
        tmp=Path(td);out=tmp/'fixtures';out.mkdir()
        patches=[];blob=bytearray();directory=bytearray()
        for name in names:
            lump=[l for l in manifest['lumps'] if bytes.fromhex(l['nameHex']).rstrip(b'\0').decode()==name][-1]
            data=resource[lump['offset']:lump['offset']+lump['length']]
            (out/f'{name}.bin').write_bytes(data)
            directory+=name.encode().ljust(8,b'\0')+struct.pack('<II',len(blob),len(data));blob+=data
            patches.append({'name':name,'sha256':sha(data),'length':len(data),'lumpId':lump['id']})
        (out/'resources.bin').write_bytes(blob);(out/'directory.bin').write_bytes(directory)
        suites=steps();profiles=[];baseline={}
        sources=['st_lib','v_video','m_bbox','m_random','r_main','tables','d_items','m_cheat']
        compiler=shutil.which('clang');assert compiler
        for label,flags in [('O0',['-O0']),('O2',['-O2']),('sanitized',['-O1','-g','-fsanitize=address,undefined','-fno-sanitize=array-bounds','-fno-omit-frame-pointer'])]:
            binary=tmp/label
            cmd=[compiler,'-std=c11','-fwrapv','-ffunction-sections','-fdata-sections','-include',str(SOURCE/'doomdef.h'),'-I',str(HERE),'-I',str(SOURCE),*flags,str(HERE/'host.c'),*[str(SOURCE/(s+'.c')) for s in sources],'-Wl,-dead_strip' if platform.system()=='Darwin' else '-Wl,--gc-sections','-o',str(binary)]
            built=subprocess.run(cmd,capture_output=True,text=True)
            if built.returncode:raise RuntimeError(built.stderr)
            env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0:halt_on_error=1','UBSAN_OPTIONS':'halt_on_error=1:print_stacktrace=1'}
            hashes={}
            for name,rows in suites.items():
                inputs=struct.pack('>I',len(rows))+b''.join(struct.pack('>36i',*r['inputs']) for r in rows)
                (tmp/'inputs.bin').write_bytes(inputs)
                run=subprocess.run([str(binary),str(tmp/'inputs.bin'),str(out)],capture_output=True,env=env)
                if run.returncode:raise RuntimeError(f'{label}/{name}: {run.stderr.decode()}')
                raw=run.stdout;assert len(raw)==len(rows)*(96+64000+10240+768)
                hashes[name]=sha(raw)
                if label=='O0':baseline[name]=raw
                else:assert baseline[name]==raw,(label,name)
                if label!='O0':continue
                packed=bytearray()
                for i,row in enumerate(rows):
                    start=i*75104;record=raw[start:start+75104]
                    values=list(struct.unpack('>24i',record[:96]))
                    frame=record[96:64096];background=record[64096:74336];palette=record[74336:75104]
                    row['state']=values;row['sha256']=[sha(frame),sha(background),sha(palette)]
                    packed+=struct.pack('>36i',*row['inputs'])+record[:96]+b''.join(bytes.fromhex(h) for h in row['sha256'])
                    if row['inputs'][0]==0 and name in ['inventory','face_pixels','receipt_damage']:
                        (out/f'{name}-{i}.frame').write_bytes(frame)
                (out/f'{name}.bin').write_bytes(packed)
            profiles.append({'name':label,'flags':flags,'outputSha256':hashes})
        (out/'cases.json').write_text(json.dumps({'inputFields':FIELDS,'stateFields':STATES,'recordBytes':336,'suites':suites},indent=2)+'\n')
        sourcepaths=[SOURCE/(s+'.c') for s in sources+['st_stuff']]+sorted(SOURCE.glob('*.h'))+[HERE/'host.c',HERE/'reference.py',HERE/'values.h']
        evidence={'upstreamCommit':manifest['provenance']['upstreamCommit'],'wadProvenance':manifest['provenance'],'resourceBlobSha256':manifest['blobSha256'],'patches':patches,'profiles':profiles,'sourceSha256':{str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in sourcepaths},'caseCount':sum(map(len,suites.values())),'compiler':subprocess.check_output([compiler,'--version'],text=True).splitlines()[0],'exactAgreement':True}
        (out/'manifest.json').write_text(json.dumps(evidence,indent=2)+'\n')
        shutil.copyfile(ROOT/'test/fixtures/phase4_video/COPYING.txt',out/'FREEDOOM-LICENSE.txt')
        if args.check:
            assert {p.name for p in out.iterdir()}=={p.name for p in OUTPUT.iterdir()},'fixture inventory'
            for p in out.iterdir():assert p.read_bytes()==(OUTPUT/p.name).read_bytes(),p.name
        else:
            OUTPUT.mkdir(exist_ok=True)
            for p in out.iterdir():shutil.copyfile(p,OUTPUT/p.name)
        print(f'{evidence["caseCount"]} status steps, {len(suites)} sequences, O0/O2/ASan+UBSan exact')
if __name__=='__main__':main()
