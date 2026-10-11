#!/usr/bin/env python3
"""Focused original-C references for the diagnostic display cadence.

Original bodies stay unchanged. The comparison host samples gameplay displays
at tics 1, 20 and the genuine exit, with a supported size10→11→10 refresh at20.
Immutable ST resources, including STTMINUS, are borrowed consistently. Temporary
world rendering is retained; independently native-generated prior screens only.
No pixels or native state are supplied to EVM.
"""
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'artifacts/local/full-options-main/native'
SOURCE=ROOT/'original/DOOM/linuxdoom-1.10'
spec=importlib.util.spec_from_file_location('full_options_original_menu',ROOT/'tools/reference/options/reference.py')
options=importlib.util.module_from_spec(spec);spec.loader.exec_module(options)
sha=lambda b:hashlib.sha256(b).hexdigest()
OUT.mkdir(parents=True,exist_ok=False)
wad=ROOT/'artifacts/local/options/DOOM.WAD'
assert sha(wad.read_bytes())=='6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f'
tape=json.loads((ROOT/'artifacts/local/ultimate-speedruns/E1M1/tape.json').read_text())
info=json.loads((ROOT/'artifacts/local/ultimate-speedruns/E1M1/native-result.json').read_text())
commands=''.join(f"{r['forwardmove']} {r['sidemove']} {r['angleturn']} {r['buttons']} 0\n" for r in tape['commands'][:info['executedTics']])
recipe=[0,1,0,1,0,1]+[0]*9 # Original edge acceleration, short integration endpoint.
inputs=OUT/'commands.txt';inputs.write_text(commands+''.join(f'0 0 0 {b} 0\n' for b in recipe))
report={'startedUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'profiles':{},'scope':__doc__,'pass':False}
size_body,size_span=options.extract((SOURCE/'m_menu.c').read_text(),'M_SizeDisplay')
for profile in ['O2','O0','sanitize']:
    build=OUT/profile
    cmd=['python3','tools/reference/full_videos/native-build-short.py','--output',str(build),'--opt','O0' if profile=='O0' else 'O2','--borrow-all-ui','--display-history']
    if profile=='sanitize':cmd+=['--sanitize']
    subprocess.run(cmd,cwd=ROOT,check=True,stdout=subprocess.DEVNULL)
    p=build/'original-host.c';s=p.read_text()
    # Match the EVM's deliberately sampled display cadence; all ST/HU tickers still run.
    old='          HU_Erase();ST_Drawer(false,gametic==1);\n          if(gametic!=capture && (capture || gameaction!=ga_completed))HU_Drawer();'
    assert s.count(old)==1
    new='''          if(gametic==1 || gametic==20 || gametic==capture || (!capture && gameaction==ga_completed)) {
            HU_Erase();ST_Drawer(false,gametic==1);
            if(gametic==20 && getenv("FULL_OPTIONS_HISTORY")) {
              M_SizeDisplay(1);R_ExecuteSetViewSize();ST_Drawer(true,true);
              if(!(capture==20 && getenv("FULL_OPTIONS_FULL"))) {M_SizeDisplay(0);R_ExecuteSetViewSize();ST_Drawer(false,true);}
            }
          }
'''
    s=s.replace(old,new)
    s=s.replace('static int display_state=', 'static int screenSize=7;\n'+size_body+'\nstatic int display_state=')
    s=s.replace('    int tail_count=0,final_hold=0,stats_hold=0;',
                '    if(getenv("FULL_FINALE_FIXTURE")){F_StartFinale();post=1;}\n    int tail_count=0,final_hold=0,stats_hold=0;')
    p.write_text(s)
    manifest=json.loads((build/'full-manifest.json').read_text())
    completed=subprocess.run(manifest['command'],capture_output=True)
    (build/'integration-build.log').write_bytes(completed.stdout+completed.stderr)
    assert completed.returncode==0,completed.stderr.decode()
    env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0:halt_on_error=1','UBSAN_OPTIONS':'halt_on_error=1'}
    env.pop('DOOM_ORACLE_ALLOCATION_FILL',None)
    rows={}
    def execute(label,tic,history=False,fullscreen=False,previous=None,finale=False):
        dest=build/label;dest.mkdir()
        ins=dest/'commands.txt'
        ins.write_text('0 0 0 0 0\n' if finale else commands if tic==316 else ''.join(f"{r['forwardmove']} {r['sidemove']} {r['angleturn']} {r['buttons']} 0\n" for r in tape['commands'][:tic]) if tic else inputs.read_text())
        flags={**env}
        if tic:flags['FULL_CAPTURE_TIC']=str(tic)
        if history:flags['FULL_OPTIONS_HISTORY']='1'
        if fullscreen:flags['FULL_OPTIONS_FULL']='1'
        if previous:flags['FULL_PREVIOUS_SCREEN']=str(previous)
        if finale:flags['FULL_FINALE_FIXTURE']='1'
        run=subprocess.run([str(build/'full-native'),str(wad),str(dest),str(ins),'8' if finale else '1',str(tape['header']['skill']),str(tape['header']['nomonsters'])],capture_output=True,env=flags)
        (dest/'stdout.log').write_bytes(run.stdout);(dest/'stderr.log').write_bytes(run.stderr)
        assert run.returncode==0 and not run.stderr,(profile,label,run.stderr.decode())
        rows[label]={p.name:{'sha256':sha(p.read_bytes()),'bytes':p.stat().st_size} for p in dest.iterdir() if p.suffix in ['.indexed8','.palette','.bin']}
        return dest
    first=execute('tic1',1)
    prior=first/'gameplay-000001.indexed8'
    default20=execute('tic20',20,previous=prior)/'gameplay-000020.indexed8'
    execute('exit-default',316,False,False,default20)
    execute('presentation-default',0,False,False,default20)
    execute('tic20-full',20,True,True,prior)
    restored=execute('tic20-restored',20,True,False,prior)/'gameplay-000020.indexed8'
    exit_=execute('exit',316,True,False,restored)
    execute('presentation',0,True,False,restored)
    execute('finale-fixture',0,False,False,finale=True)
    report['profiles'][profile]={'originalSizeDisplay':size_span,'nativeBinarySha256':sha((build/'full-native').read_bytes()),'generatedHostSha256':sha(p.read_bytes()),'originalManifest':manifest,'rows':rows}
    print('PASS focused native reference',profile,flush=True)
entry=OUT/'entry-wipe'
start=sorted((OUT/'O2/presentation').glob('*-1-*.indexed8'))[0]
subprocess.run(['python3','tools/reference/full_videos/wipe-frames.py','--start',str(start),'--end',str(OUT/'O2/tic1/gameplay-000001.indexed8'),'--seed','1','--output',str(entry)],cwd=ROOT,check=True)
report['entryWipe']=json.loads((entry/'manifest.json').read_text())
report.update(pass_=True,endedUtc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(OUT/'result.json').write_text(json.dumps(report,indent=2)+'\n')
