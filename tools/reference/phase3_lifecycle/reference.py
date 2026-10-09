#!/usr/bin/env python3
"""Complete original player/mobj units with bounded observing boundary doubles."""
import argparse,json,pathlib,re,struct,subprocess,tempfile,sys,os
HERE=pathlib.Path(__file__).resolve().parent;sys.path.insert(0,str(HERE.parent));import reference as ref
SOURCE=ref.SOURCE;FIXTURES=ref.ROOT/'test/fixtures/phase3_lifecycle'

def extract(file,name):
 s=(SOURCE/file).read_text();m=re.search(r'\n(?:void|boolean|int|fixed_t|angle_t)\s+'+name+r'\s*\([^;{}]*\)\s*\{',s);assert m,name
 start=m.start()+1;end=m.end();depth=1
 while depth:
  if s[end]=='{':depth+=1
  elif s[end]=='}':depth-=1
  end+=1
 body=s[start:end];return body,dict(file=file,function=name,startLine=s[:start].count('\n')+1,endLine=s[:end].count('\n')+1,sha256=ref.sha(body.encode()))
def operations():
 names=[]
 for file in ['p_user.c','p_mobj.c']:
  names+=re.findall(r'\n(?:void|boolean|mobj_t\*)\s+(\w+)\s*\([^;{}]*\)\s*\{',(SOURCE/file).read_text())
 return names+['G_PlayerReborn','G_ExitLevel','G_SecretExitLevel']
def build(out,opt,sanitize,strict=False):
 out.mkdir();assert ref.invoke(['git','-C',str(SOURCE),'rev-parse','HEAD']).strip()==ref.UPSTREAM;ref.invoke(['git','-C',str(SOURCE),'diff','--exit-code','HEAD','--']);assert ref.invoke(['clang','--version']).splitlines()[:2]==[ref.VERSION,'Target: '+ref.TARGET]
 actions=re.findall(r'void\s+(A_\w+)\s*\(\s*\);',(SOURCE/'info.c').read_text());assert len(actions)==74
 header='#include "p_local.h"\n#include "doomstat.h"\n#include "g_game.h"\n#include "w_wad.h"\nextern boolean secretexit;\n'+''.join('void '+n+'(mobj_t *);\n' for n in actions)
 funcs=[];records=[]
 for file,name in [('r_main.c','R_PointToAngle'),('r_main.c','R_PointToAngle2'),('p_maputl.c','P_AproxDistance'),('p_maputl.c','P_UnsetThingPosition'),('p_maputl.c','P_SetThingPosition'),('g_game.c','G_PlayerReborn'),('g_game.c','G_ExitLevel'),('g_game.c','G_SecretExitLevel')]:
  body,record=extract(file,name);funcs.append(body);records.append(record)
 (out/'helpers.c').write_text(header+'\n'.join(funcs))
 (out/'actions.c').write_text('#include "p_local.h"\nvoid ObserveAction(int,mobj_t*);\n'+''.join('void '+n+'(mobj_t *m){ObserveAction('+str(i+1)+',m);}\n' for i,n in enumerate(actions)))
 driver=header+'#include "'+str(HERE/'host.c')+'"\nstatic int invoke(int op,int thingtype,int options,int angle) { mapthing_t thing={-64,16,(short)angle,(short)thingtype,(short)options};switch(op){\n'
 args={'P_Thrust':'players,(angle_t)angle,objects[0]->momx','P_CalcHeight':'players','P_MovePlayer':'players','P_DeathThink':'players','P_PlayerThink':'players','P_SetMobjState':'objects[0],900','P_SpawnMobj':'-64*FRACUNIT,16*FRACUNIT,(mode&32)?ONCEILINGZ:ONFLOORZ,objects[0]->type','P_RespawnSpecials':'','P_SpawnPlayer':'&thing','P_SpawnMapThing':'&thing','P_SpawnPuff':'-64*FRACUNIT,16*FRACUNIT,32*FRACUNIT','P_SpawnBlood':'-64*FRACUNIT,16*FRACUNIT,32*FRACUNIT,options','P_SpawnMissile':'objects[0],objects[1],MT_ROCKET','P_SpawnPlayerMissile':'objects[0],MT_ROCKET','G_PlayerReborn':'0','G_ExitLevel':'','G_SecretExitLevel':''}
 for i,name in enumerate(operations()):
  arg=args.get(name,'objects[0]')
  if name=='P_SetMobjState':call='return '+name+'('+arg+');'
  elif name in ['P_SpawnMobj','P_SpawnMissile']:call='return actorid('+name+'('+arg+'));'
  else:call=name+'('+arg+');return 0;'
  driver+=f'case {i}: {call}\n'
 driver+='default:I_Error("operation");}return 0;}\nint main(void){int op,kind,seed,mx,my,mz,z,ticks,skill,gm,thingtype,options,angle;unsigned flags;while(scanf("%d %d %d %u %d %d %d %d %d %d %d %d %d %d",&op,&kind,&seed,&flags,&mx,&my,&mz,&z,&ticks,&skill,&gm,&thingtype,&options,&angle)==14){setup(kind,seed,flags,mx,my,mz,z,skill,gm,angle,options);'
 respawn=operations().index('P_RespawnSpecials');driver+=f'if(op=={respawn}) P_RemoveMobj(objects[2]);'
 driver+='int32_t inputs[]={op,kind,seed,(int32_t)flags,mx,my,mz,z,ticks,skill,gm,thingtype,options,angle};FILE *record=tmpfile();if(!record)I_Error("tmpfile");for(int i=0;i<14;i++)word(record,inputs[i]);int result=0;for(int i=0;i<ticks;i++){result=invoke(op,thingtype,options,angle);leveltime++;gametic++;}snapshot(record,result);long size=ftell(record);rewind(record);word(stdout,size/4);for(long i=0;i<size;i++)putchar(fgetc(record));fclose(record);}if(!feof(stdin))I_Error("malformed input");return 0;}\n'
 (out/'oracle.c').write_text(driver)
 flags=[('-'+opt if f=='-O2' else f) for f in ref.FLAGS]+['-fsigned-char','-DNORMALUNIX','-include','stdint.h','-include','stddef.h','-include','stdlib.h','-include','string.h','-Wno-incompatible-pointer-types','-Wno-implicit-function-declaration']
 if strict:flags.remove('-fwrapv')
 if sanitize:flags+=['-fsanitize=address,undefined','-fno-sanitize-recover=all']
 cmd=['clang',*flags,'-I'+str(SOURCE),str(out/'oracle.c'),str(out/'helpers.c'),str(out/'actions.c'),*[str(SOURCE/n) for n in ['p_user.c','p_mobj.c','info.c','tables.c','m_fixed.c','m_random.c']],'-o',str(out/'oracle')]
 result=subprocess.run(cmd,capture_output=True,text=True)
 if result.returncode:raise RuntimeError(result.stderr)
 return out/'oracle',dict(upstreamCommit=ref.UPSTREAM,compiler=ref.VERSION,target=ref.TARGET,flags=flags,sources={p.name:ref.sha(p.read_bytes()) for p in sorted(SOURCE.glob('*.h'))}|{n:ref.sha((SOURCE/n).read_bytes()) for n in ['p_user.c','p_mobj.c','g_game.c','r_main.c','p_maputl.c','info.c','tables.c','m_fixed.c','m_random.c']},extractions=records,harness={p.name:ref.sha(p.read_bytes()) for p in [HERE/'host.c',HERE/'reference.py']},generatedSourceSha256=ref.sha(driver.replace(str(HERE),'<HARNESS>').encode()),scope='Whole original p_user/p_mobj, three original g_game lifecycle functions, original map links/math/RNG; observing boundary doubles; no integrated gameplay claim')
def cases():
 rows=[];ops=operations()
 for op,name in enumerate(ops):
  kind=0 if name.startswith('P_') and name in ['P_Thrust','P_CalcHeight','P_MovePlayer','P_DeathThink','P_PlayerThink'] else (33 if name in ['P_ExplodeMissile','P_CheckMissileSpawn','P_SpawnMissile','P_SpawnPlayerMissile'] else 1)
  modes=[0,1,2,4,8,16,32,64,128|4|1,256,512,1024,2048,4096,8192,16384,32768,65536,131072|262144,524288,1048576,2097152,4194304,8388608,16777216,33554432,67108864,134217728,268435456,536870912,1073741824,2147483648]
  for j,mode in enumerate(modes):
   mx,my,mz=[(0,0,0),(25*2048,24*2048,320),(-50*2048,-24*2048,-1280),(30*65536+1,-65536,-9*65536),(-30*65536-1,20*65536,2*65536),(4095,-4095,0),(4096,-4096,0)][j%7]
   z=[0,8*65536,-65536,96*65536][j%4];ticks=1 if name not in ['P_PlayerThink','P_DeathThink','P_MobjThinker','P_XYMovement','P_ZMovement'] else (3 if j%3==0 else 1)
   thingtype=1 if name=='P_SpawnPlayer' else [3004,2007,1,2,11][j%5]
   options=[0,1,2,4,7,15,16,2|(5<<3)|4,2|(6<<3)|4,128|2][j%10] if name=='P_PlayerThink' else ([1,2,4,7,15,16][j%6] if name in ['P_SpawnMapThing','P_SpawnPlayer'] else [0,8,9,12,16][j%5])
   rows.append([op,kind,[0,7,127,255,252][j%5],mode,mx,my,mz,z,ticks,j%5,j%4,thingtype,options,[0,0x20000000,0x40000000,-0x40000000,90,359,-45][j%7]])
  if name=='P_PlayerThink':
   for ground in [0,536870912]:
    for ticks in [1,3]:rows.append([op,0,7,2|ground,25*2048,24*2048,-320,8*65536,ticks,2,3,1,2,0])
 # Explicit rare/gate boundaries supplement the broad deterministic profile matrix.
 rows.extend([
  [ops.index('P_SpawnPlayerMissile'),0,7,3,0,0,0,0,1,2,3,1,7,0],
  [ops.index('G_SecretExitLevel'),0,7,134217728,0,0,0,0,1,2,2,1,7,0],
  [ops.index('P_MobjThinker'),1,252,131072|262144,0,0,0,0,1,2,3,3004,7,90],
  [ops.index('P_XYMovement'),18,7,9,0,0,0,0,1,2,3,3006,7,0],
  [ops.index('P_ZMovement'),18,7,9,0,0,-9*65536,0,1,2,3,3006,7,0],
  [ops.index('P_ZMovement'),18,7,9,0,0,9*65536,120*65536,1,2,3,3006,7,0],
  [ops.index('P_RemoveMobj'),63,7,1,0,0,0,0,1,2,3,2007,7,0],
  [ops.index('P_RemoveMobj'),63,7,1|32768,0,0,0,0,1,2,3,2007,7,0],
  [ops.index('P_RemoveMobj'),63,7,1|4096,0,0,0,0,1,2,3,2007,7,0],
  [ops.index('P_RemoveMobj'),56,7,1,0,0,0,0,1,2,3,2022,7,0],
  [ops.index('P_RemoveMobj'),58,7,1,0,0,0,0,1,2,3,2024,7,0],
  [ops.index('P_RespawnSpecials'),1,7,524288|32768,0,0,0,0,1,2,3,2007,7,0],
 ])
 return rows

def main():
 p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args();rows=cases();inputs=''.join(' '.join(map(str,r))+'\n' for r in rows);base=None
 with tempfile.TemporaryDirectory(prefix='doom-lifecycle-') as td:
  for name,opt,sanitize,fill in [('O0','O0',False,False),('O2','O2',False,False),('asan','O2',True,False),('fill','O2',True,True)]:
   binary,metadata=build(pathlib.Path(td)/name,opt,sanitize);env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'}
   if fill:env['ALLOCATION_FILL']='0xa5'
   result=subprocess.run([str(binary)],input=inputs.encode(),capture_output=True,env=env);assert result.returncode==0,(name,result.stderr.decode());assert not result.stderr,(name,result.stderr.decode())
   if base is None:base=result.stdout
   else:assert base==result.stdout,(name,'native mismatch')
   if name=='O2':manifest=metadata
  strictbin,_=build(pathlib.Path(td)/'strict','O2',True,True)
  audit=[]
  for opname,seed,flags,mz in [('P_MovePlayer',0,0,-1280),('P_NightmareRespawn',0,0,0),('P_RespawnSpecials',0,524288|32768,0),('P_SpawnPlayer',0,0,0),('P_SpawnMapThing',0,0,0),('P_SpawnPuff',0,0,0),('P_SpawnBlood',0,0,0),('P_SpawnMissile',7,67108864,0)]:
   row=[operations().index(opname),0 if opname in ['P_MovePlayer','P_SpawnPlayer'] else 33,seed,flags,25*2048,0,mz,0,1,2,3,1 if opname=='P_SpawnPlayer' else 3004,7,0]
   result=subprocess.run([str(strictbin)],input=(' '.join(map(str,row))+'\n').encode(),capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'})
   diagnostic=re.search(r'(p_(?:user|mobj)\.c:\d+:\d+: runtime error: [^\n]+)',result.stderr.decode())
   assert result.returncode!=0 and diagnostic,(opname,result.stderr.decode())
   audit.append(dict(function=opname,inputs=row,strictDiagnostic=diagnostic.group(1),classification='Original ISO C undefined operation; admitted only under documented pinned -fwrapv implementation profile'))
 outputs={'undefined-audit.json':(json.dumps(dict(profile='O2 full ASan/UBSan without -fwrapv; every diagnostic deliberately observed rather than suppressed',cases=audit),indent=2)+'\n').encode(),'vectors.bin':base,'manifest.json':(json.dumps(dict(manifest,operations=operations(),cases=len(rows),inputFields=['operation','kind','rngBefore','mode','momx','momy','momz','z','ticks','skill','gamemode','thingtype','options','angle'],encoding='big-endian u32 word count;14 input words;documented complete lifecycle snapshot',profiles=['O0','O2','O2 ASan/UBSan -fwrapv','O2 ASan/UBSan allocation0xa5']),indent=2)+'\n').encode()}
 if a.check:
  for name,data in outputs.items():assert (FIXTURES/name).read_bytes()==data,'stale '+name
 else:
  for name,data in outputs.items():(FIXTURES/name).write_bytes(data)
 print(f'PASS {len(operations())} original lifecycle definitions, {len(rows)} controlled cases, O0/O2/ASan/fill exact')
if __name__=='__main__':main()
