#!/usr/bin/env python3
"""Replay captured held-key inputs through original keyboard/gameplay/render code.

The existing native host's explicitly calloc-initialized zone is a platform
profile, not proof of indeterminate-byte pixels for original I_ZoneBase malloc.
"""
import sys,json,subprocess,tempfile,hashlib,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'tools/reference/gameplay'))
import production
from build import build
from verify import player_records
FIX=ROOT/'test/fixtures/drawbounds_blood';OUT=ROOT/'artifacts/local/drawbounds-crash/native';OUT.mkdir(parents=True,exist_ok=True)
def sha(b):return hashlib.sha256(b).hexdigest()
rows=json.loads((FIX/'commands.json').read_text());assert [r['sequence'] for r in rows]==list(range(1,446))
masks=''.join(f"{r['buttons']} {int(r['render'])}\n" for r in rows)
original,extraction=production.keyboard.extract();source=(ROOT/'tools/reference/phase3_input/host.c').read_text()+'\n'+original+'\n'+production.DRIVER
baseline=None;reports=[]
with tempfile.TemporaryDirectory(prefix='doom-crash-replay-') as td:
 p=Path(td);(p/'keyboard.c').write_text(source)
 for profile,opt,sanitized in [('O0','O0',False),('O2','O2',False),('sanitized','O2',True)]:
  flags=['-std=c11','-fsigned-char','-fno-strict-aliasing','-ffp-contract=off','-fno-fast-math','-'+opt]
  if sanitized:flags+=['-fsanitize=address,undefined','-fno-sanitize-recover=all']
  subprocess.run(['clang',*flags,'-I'+str(production.ref.SOURCE),str(p/'keyboard.c'),'-o',str(p/'keyboard')],check=True,capture_output=True)
  commands=subprocess.run([str(p/'keyboard')],input=masks.encode(),check=True,capture_output=True).stdout
  (p/'commands.txt').write_bytes(commands);binary=build(p/profile,opt,sanitized);dest=p/(profile+'-run');dest.mkdir()
  r=subprocess.run([str(binary),str(production.WAD),str(dest),str(p/'commands.txt'),'ordinary'],capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0','DOOM_ORACLE_ALLOCATION_FILL':'0'})
  assert r.returncode==0 and not r.stderr,(profile,r.stderr.decode())
  current={f.name:sha(f.read_bytes()) for f in dest.iterdir()}
  if baseline is None:
   baseline=current
   players=player_records((dest/'ticks.bin').read_bytes())
   keys=['gametic','leveltime','playerHealth','armorpoints','readyweapon','x','y','z','angle','momx','momy','momz','viewz','prndindex']
   players=[{k:(v[k]&0xffffffff if k=='angle' else v[k]) for k in keys} for v in players]
   (FIX/'players.json').write_text(json.dumps(players,separators=(',',':'))+'\n')
   for name in ['frame-000444.bin','frame-000445.bin']:(FIX/name).write_bytes((dest/name).read_bytes())
  else:assert current==baseline,'profile divergence'
  reports.append({'profile':profile,'filesCompared':len(current),'pass':True});print('PASS native captured inputs',profile,len(rows),'tics',flush=True)
report={'pass':True,'zonePolicy':'Existing explicit calloc zero-initialized platform host; no unmodified malloc pixel equivalence claimed.','profiles':reports,'commandsSha256':sha((FIX/'commands.json').read_bytes()),'playersSha256':sha((FIX/'players.json').read_bytes()),'frames':{k:v for k,v in baseline.items() if k.startswith('frame-')},'finalWorldHashes':{k:v for k,v in baseline.items() if not k.startswith('frame-')},'keyboardExtraction':extraction}
(FIX/'replay-native.json').write_text(json.dumps(report,indent=2)+'\n')
