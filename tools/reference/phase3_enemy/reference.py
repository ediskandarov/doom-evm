#!/usr/bin/env python3
"""All original p_enemy entrypoints, native observing doubles and deterministic cases."""
import argparse,json,pathlib,re,struct,subprocess,tempfile,sys
HERE=pathlib.Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent));import reference as ref
SOURCE=ref.SOURCE
FIXTURES=ref.ROOT/'test/fixtures/phase3_enemy'

def extract(file,name):
 s=(SOURCE/file).read_text();m=re.search(r'\n(?:void|boolean|int|fixed_t|angle_t)\s+'+name+r'\s*\([^;{}]*\)\s*\{',s);assert m,name
 start=m.start()+1;opening=m.end()-1;end=opening+1;depth=1
 while depth:
  if s[end]=='{':depth+=1
  elif s[end]=='}':depth-=1
  end+=1
 body=s[start:end];return body,dict(file=file,function=name,startLine=s[:start].count('\n')+1,endLine=s[:end].count('\n')+1,sha256=ref.sha(body.encode()))
def operations():return re.findall(r'\n(?:void|boolean)\s+(\w+)\s*\([^;{}]*\)\s*\{',(SOURCE/'p_enemy.c').read_text())
def build(out,opt,sanitize):
 out.mkdir();assert ref.invoke(['git','-C',str(SOURCE),'rev-parse','HEAD']).strip()==ref.UPSTREAM;ref.invoke(['git','-C',str(SOURCE),'diff','--exit-code','HEAD','--']);assert ref.invoke(['clang','--version']).splitlines()[:2]==[ref.VERSION,'Target: '+ref.TARGET]
 bodies=[];records=[]
 for file,name in [('r_main.c','R_PointToAngle'),('r_main.c','R_PointToAngle2'),('p_maputl.c','P_AproxDistance'),('p_maputl.c','P_LineOpening')]:
  body,record=extract(file,name);bodies.append(body);records.append(record)
 text='#include "p_enemy.c"\n#include "r_main.h"\n'+'\n'.join(bodies)+'\n#include "'+str(HERE/'host.c')+'"\n'
 text+='static int invoke(int operation) { switch(operation) {\n'
 for i,name in enumerate(operations()):
  if name=='P_RecursiveSound':args='sectors,0'
  elif name=='P_NoiseAlert':args='objects+1,objects'
  elif name=='P_LookForPlayers':args='objects,!!(mode&512)'
  elif name=='PIT_VileCheck':args='objects+2'
  elif name=='A_PainShootSkull':args='objects,(mode&512)?ANG90:0'
  elif name in ['A_OpenShotgun2','A_LoadShotgun2','A_CloseShotgun2']:args='players,players[0].psprites'
  else:args='objects'
  prefix='return ' if name in ['P_CheckMeleeRange','P_CheckMissileRange','P_Move','P_TryWalk','P_LookForPlayers','PIT_VileCheck'] else ''
  suffix='' if prefix else ';return 0'
  text+=f'case {i}: {prefix}{name}({args}){suffix};\n'
 text+='default:I_Error("operation");}return 0;}\n'
 text+='''int main(void) {int op,type,seed,dx,dy,gm,episode,map,skill;unsigned flags;while(scanf("%d %d %d %u %d %d %d %d %d %d",&op,&type,&seed,&flags,&dx,&dy,&gm,&episode,&map,&skill)==10) {setup(type,seed,flags,dx,dy,gm,episode,map,skill);'''
 brainspit=operations().index('A_BrainSpit');fly=operations().index('A_SpawnFly');sound=operations().index('A_SpawnSound')
 text+=f'if(op=={fly} || op=={sound}) {{objects[0].target=objects+3;objects[0].reactiontime=(mode&8)?2:1;}}'
 text+='int32_t inputs[]={op,type,seed,(int32_t)flags,dx,dy,gm,episode,map,skill,easyShadow};FILE *record=tmpfile();if(!record) I_Error("tmpfile");for(int i=0;i<11;i++) word(record,inputs[i]);'
 text+=f'if(op=={brainspit}) easyShadow^=1;'
 text+='int result=invoke(op);snapshot(record,result);long size=ftell(record);rewind(record);word(stdout,size/4);for(long i=0;i<size;i++) putchar(fgetc(record));fclose(record);}if(!feof(stdin)) I_Error("malformed input");return 0;}\n'
 cfile=out/'oracle.c';cfile.write_text(text)
 implemented=set(operations());actions=re.findall(r'void\s+(A_\w+)\s*\(\s*\);',(SOURCE/'info.c').read_text())
 (out/'actions.c').write_text('#include "i_system.h"\n'+'\n'.join('void '+n+'(void){I_Error("unexpected neighboring action '+n+'");}' for n in actions if n not in implemented and n!='A_ReFire'))
 flags=[('-'+opt if f=='-O2' else f) for f in ref.FLAGS]+['-fsigned-char','-DNORMALUNIX','-include','stdint.h','-include','stddef.h','-include','stdlib.h','-include','string.h','-Wno-incompatible-pointer-types','-Wno-implicit-function-declaration']
 if sanitize:flags+=['-fsanitize=address,undefined','-fno-sanitize-recover=all']
 cmd=['clang',*flags,'-I'+str(SOURCE),str(cfile),str(out/'actions.c'),str(SOURCE/'info.c'),str(SOURCE/'tables.c'),str(SOURCE/'m_fixed.c'),str(SOURCE/'m_random.c'),'-o',str(out/'oracle')]
 result=subprocess.run(cmd,capture_output=True,text=True)
 if result.returncode:raise RuntimeError(result.stderr)
 return out/'oracle',dict(upstreamCommit=ref.UPSTREAM,compiler=ref.VERSION,target=ref.TARGET,flags=flags,sources={p.name:ref.sha(p.read_bytes()) for p in sorted(SOURCE.glob('*.h'))}|{n:ref.sha((SOURCE/n).read_bytes()) for n in ['p_enemy.c','r_main.c','p_maputl.c','info.c','tables.c','m_fixed.c','m_random.c']},extractions=records,harness={p.name:ref.sha(p.read_bytes()) for p in [HERE/'host.c',HERE/'reference.py']},generatedSourceSha256=ref.sha(text.replace(str(HERE),'<HARNESS>').encode()),scope='Whole original p_enemy.c with explicit observing doubles for neighboring modules; real original info/tables/math/RNG; not integrated-world evidence')
def cases():
 kinds={'A_KeenDie':24,'A_VileChase':3,'A_VileTarget':3,'A_VileAttack':3,'A_Fire':4,'A_StartFire':4,'A_FireCrackle':4,'A_FatRaise':8,'A_FatAttack1':8,'A_FatAttack2':8,'A_FatAttack3':8,'A_SkullAttack':18,'A_PainShootSkull':22,'A_PainAttack':22,'A_PainDie':22,'A_BrainAwake':25,'A_BrainSpit':25,'A_BrainScream':25,'A_BrainExplode':25,'A_SpawnFly':28,'A_SpawnSound':28,'A_SkelMissile':5,'A_Tracer':6,'A_SkelWhoosh':5,'A_SkelFist':5,'A_BspiAttack':20,'A_CyberAttack':21,'A_SargAttack':12,'A_TroopAttack':11,'A_HeadAttack':14,'A_BruisAttack':15}
 rows=[]
 for op,name in enumerate(operations()):
  kind=kinds.get(name,1)
  modes=[0,1,2,4,8,32,64,256,512,1024|4,2048|4,4096,65536,131072,262144,524288,1048576]
  if name in ['A_PainShootSkull','A_PainDie','A_PainAttack']:modes+=[2097152]
  for j,mode in enumerate(modes):
   dx,dy=[(32,8),(128,96),(-128,64),(768,384),(1536,512)][j%5]
   if name=='A_BrainSpit':dy=256
   rows.append([op,kind,[0,7,127,255][j%4],mode,dx,dy,3,1,1,j%5])
  if name in ['P_CheckMeleeRange','A_Look','A_Chase','A_FaceTarget','A_PosAttack','A_SPosAttack','A_CPosAttack','A_CPosRefire','A_SpidRefire','A_BspiAttack','A_TroopAttack','A_SargAttack','A_HeadAttack','A_CyberAttack','A_BruisAttack','A_SkelMissile','A_SkelWhoosh','A_SkelFist','A_VileTarget','A_VileAttack','A_SkullAttack','A_PainAttack']:rows.append([op,kind,13,16,128,96,3,1,1,2])
  if name=='A_BossDeath':
   for gm,episode,map,kind in [(2,1,7,8),(2,1,7,20),(3,1,8,15),(3,2,8,21),(3,3,8,19),(3,4,6,21),(3,4,8,19),(3,4,7,19)]:
    for mode in [0,64,256]:rows.append([op,kind,0,mode,128,96,gm,episode,map,2])
 return rows

def main():
 p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args();rows=cases();inputs=''.join(' '.join(map(str,r))+'\n' for r in rows);base=None
 with tempfile.TemporaryDirectory(prefix='doom-enemy-') as td:
  for name,opt,sanitize in [('O0','O0',False),('O2','O2',False),('asan','O2',True)]:
   binary,metadata=build(pathlib.Path(td)/name,opt,sanitize);result=subprocess.run([str(binary)],input=inputs.encode(),capture_output=True);assert result.returncode==0,(name,result.stderr.decode());assert not result.stderr,(name,result.stderr.decode())
   if base is None:base=result.stdout
   else:assert base==result.stdout,(name,'native mismatch')
   if name=='O2':manifest=metadata
 outputs={'vectors.bin':base,'manifest.json':(json.dumps(dict(manifest,operations=operations(),cases=len(rows),inputFields=['operation','kind','rngBefore','mode','targetXUnits','targetYUnits','gamemode','episode','map','skill','brainEasyBefore'],encoding='big-endian u32 word count;11 input words;7 fixed outputs;actor count×21 fields;3 sector×3 fields;call count×6 words',profiles=['O0','O2','O2 ASan/UBSan -fwrapv']),indent=2)+'\n').encode()}
 if a.check:
  for name,data in outputs.items():assert (FIXTURES/name).read_bytes()==data,'stale '+name
 else:
  for name,data in outputs.items():(FIXTURES/name).write_bytes(data)
 print(f'PASS all {len(operations())} original p_enemy definitions, {len(rows)} controlled cases, O0/O2/ASan exact')
if __name__=='__main__':main()
