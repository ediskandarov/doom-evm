"""Focused original pickup and locked-door message producers, using existing declared native hosts."""
import importlib.util, pathlib, re, subprocess, os
HERE=pathlib.Path(__file__).resolve().parent
ROOT=HERE.parents[2]
SRC=ROOT/'original/DOOM/linuxdoom-1.10'
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module

def messages(tmp):
    combat=load('hud_combat',HERE.parent/'phase3_combat/reference.py')
    world=load('hud_world',HERE.parent/'phase3_world/reference.py')
    sprites=['ARM1','ARM2','BON1','BON2','SOUL','MEGA','BKEY','YKEY','RKEY','BSKU','YSKU','RSKU','STIM','MEDI','PINV','PSTR','PINS','SUIT','PMAP','PVIS','CLIP','AMMO','ROCK','BROK','CELL','CELP','SHEL','SBOX','BPAK','BFUG','MGUN','CSAW','LAUN','PLAS','SHOT','SGN2']
    info=(SRC/'info.h').read_text();names=re.findall(r'\bSPR_[A-Z0-9]+\b',info[info.index('SPR_TROO'):info.index('NUMSPRITES')])
    inputs=[[0,names.index('SPR_'+s),50] for s in sprites]+[[0,names.index('SPR_MEDI'),24],[0,names.index('SPR_STIM'),100]]
    units,records=zip(*(combat.extract('p_inter.c',n) for n in ['P_GiveAmmo','P_GiveWeapon','P_GiveBody','P_GiveArmor','P_GiveCard','P_GivePower','P_TouchSpecialThing']))
    data=(SRC/'p_inter.c').read_text();constants='\n'.join(re.findall(r'int\s+(?:maxammo|clipammo)\[NUMAMMO\]\s*=\s*\{[^}]+\};',data))
    data=(SRC/'info.c').read_text();states=re.search(r'state_t\s+states\[NUMSTATES\]\s*=\s*\{.*?\n\};',data,re.S)[0];states=re.sub(r'\{A_\w+\}','{NULL}',states)
    mobjs=re.search(r'mobjinfo_t\s+mobjinfo\[NUMMOBJTYPES\]\s*=\s*\{.*?\n\};',data,re.S)[0]
    driver='''
int main(void){int sprite,health;while(scanf("%d %d",&sprite,&health)==2){
 memset(players,0,sizeof(players));memset(actors,0,sizeof(actors));
 player_t *p=&players[0];p->mo=&actors[0];p->health=health;p->readyweapon=wp_pistol;
 for(int i=0;i<NUMAMMO;i++)p->maxammo[i]=maxammo[i];
 actors[0].player=p;actors[0].health=health;actors[0].height=56*FRACUNIT;
 actors[1].sprite=sprite;actors[1].flags=MF_SPECIAL|MF_COUNTITEM;
 gamemode=commercial;gameskill=sk_medium;P_TouchSpecialThing(&actors[1],&actors[0]);
 puts(p->message?p->message:"");}return 0;}
'''
    generated=(HERE.parent/'phase3_combat/host.c').read_text()+'\n#define BONUSADD 6\n'+constants+'\n'+states+'\n'+mobjs+'\n'+'\n'.join(units)+'\n'+driver
    (tmp/'pickup.c').write_text(generated)
    profiles=[('O0',['-O0']),('O2',['-O2']),('sanitized',['-O1','-fsanitize=address,undefined','-fno-sanitize-recover=all'])]
    results=[];metadata=[]
    env=os.environ.copy();env['ASAN_OPTIONS']='detect_leaks=0:halt_on_error=1';env['UBSAN_OPTIONS']='halt_on_error=1'
    for name,flags in profiles:
        cmd=['clang','-std=c11',*flags,'-I'+str(SRC),str(tmp/'pickup.c'),*[str(SRC/f) for f in ['m_random.c','tables.c','d_items.c']],'-o',str(tmp/('pickup-'+name))]
        r=subprocess.run(cmd,capture_output=True);assert r.returncode==0,r.stderr.decode()
        r=subprocess.run([str(tmp/('pickup-'+name))],input=''.join(f'{s} {h}\n' for _,s,h in inputs).encode(),capture_output=True,env=env);assert r.returncode==0,r.stderr.decode();results.append(r.stdout)
    assert results[0]==results[1]==results[2];texts=results[0].decode().splitlines();assert len(texts)==len(inputs)
    driver=tmp/'door_driver.c';driver.write_text('''int main(void){int special;while(scanf("%d",&special)==1){memset(players,0,sizeof(players));memset(&actor,0,sizeof(actor));memset(line_data,0,sizeof(line_data));actor.player=&players[0];lines[0].special=special;EV_VerticalDoor(&lines[0],&actor);puts(players[0].message?players[0].message:"");}return 0;}''')
    worlddir=tmp/'world';worlddir.mkdir();world.build(worlddir,driver)
    door_inputs=[[1,s,0] for s in [26,27,28,32,33,34]];results=[]
    for name in ['O0','O2','sanitize']:
        r=subprocess.run([str(worlddir/name)],input=''.join(f'{s}\n' for _,s,_ in door_inputs).encode(),capture_output=True,env=env);assert r.returncode==0,r.stderr.decode();results.append(r.stdout)
    assert results[0]==results[1]==results[2];texts+=results[0].decode().splitlines();inputs+=door_inputs
    return [{'kind':kind,'arg':arg,'health':health,'message':text} for (kind,arg,health),text in zip(inputs,texts)],{'pickupExtractions':records,'pickupGeneratedSha256':combat.p1.sha(generated.encode()),'doorDriverSha256':combat.p1.sha(driver.read_bytes()),'doorScope':'Entire original p_doors.c through existing world host; locked manual doors return before thinker allocation','profiles':'O0/O2/ASan+UBSan exact','hosts':{f:combat.p1.sha((HERE.parent/f).read_bytes()) for f in ['phase3_combat/host.c','phase3_combat/reference.py','phase3_world/host.c','phase3_world/reference.py']},'sources':{f:combat.p1.sha((SRC/f).read_bytes()) for f in ['p_inter.c','p_doors.c','info.c','d_englsh.h']}}
