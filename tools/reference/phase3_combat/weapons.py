#!/usr/bin/env python3
"""Unchanged entire original p_pspr.c with canonical states and declared cyclic hook sinks."""
import argparse
import importlib.util
import json
import pathlib
import re
import struct
import subprocess
import tempfile
ROOT=pathlib.Path(__file__).resolve().parents[3]
HERE=pathlib.Path(__file__).resolve().parent
FIX=ROOT/'test/fixtures/phase3_combat'
spec=importlib.util.spec_from_file_location('p1',HERE.parent/'reference.py')
p1=importlib.util.module_from_spec(spec);spec.loader.exec_module(p1)

def build(directory):
    assert p1.invoke(['git','-C',str(p1.SOURCE),'rev-parse','HEAD']).strip()==p1.UPSTREAM
    assert not p1.invoke(['git','-C',str(p1.SOURCE),'diff','--name-only','HEAD'])
    version=p1.invoke(['clang','--version']).splitlines()
    assert version[:2]==[p1.VERSION,'Target: '+p1.TARGET]
    info=(p1.SOURCE/'info.c').read_text()
    states=re.search(r'state_t\s+states\[NUMSTATES\]\s*=\s*\{.*?\n\};',info,re.S)[0]
    pspr=(p1.SOURCE/'p_pspr.c').read_text()
    implemented=set(re.findall(r'\b(A_\w+)\s*\([^)]*\)\s*\{',pspr,re.S))
    # Original weapon actions are real; unconsumed actor-only table actions are explicit no-op sinks.
    actions=list(dict.fromkeys(re.findall(r'\{(A_\w+)\}',states)))
    declarations='\n'.join('void '+name+'();' for name in actions)
    stubs='\n'.join('void '+name+'(){}' for name in actions if name not in implemented and name not in ['A_OpenShotgun2','A_LoadShotgun2','A_CloseShotgun2'])
    shotgun='\nvoid A_ReFire(player_t*,pspdef_t*);\nvoid A_OpenShotgun2(player_t*p,pspdef_t*s){(void)p;(void)s;}\nvoid A_LoadShotgun2(player_t*p,pspdef_t*s){(void)p;(void)s;}\nvoid A_CloseShotgun2(player_t*p,pspdef_t*s){A_ReFire(p,s);}\n'
    geometry='\n'.join(p1.extract('r_main.c',name,'angle_t')[0] for name in ['R_PointToAngle','R_PointToAngle2'])
    generated=(HERE/'weapon_host.c').read_text()+'\n'+declarations+'\n'+states+'\n'+stubs+shotgun+geometry+'\n'+(HERE/'weapon_driver.c').read_text()
    cfile=directory/'weapons.c';cfile.write_text(generated)
    flags=['-std=c11','-fsigned-char','-fwrapv','-fno-strict-aliasing','-ffp-contract=off','-fno-fast-math']
    profiles={'O0':['-O0'],'O2':['-O2'],'sanitize':['-O2','-fsanitize=address,undefined','-fno-sanitize=shift-base','-fno-sanitize-recover=all']}
    outputs=[]
    for name,profile in profiles.items():
        binary=directory/name
        buildflags = [f for f in flags if name != 'sanitize' or f != '-fwrapv']
        p1.invoke(['clang',*buildflags,*profile,'-Wno-deprecated-non-prototype','-I'+str(p1.SOURCE),str(cfile),str(p1.SOURCE/'p_pspr.c'),str(p1.SOURCE/'m_random.c'),str(p1.SOURCE/'m_fixed.c'),str(p1.SOURCE/'tables.c'),str(p1.SOURCE/'d_items.c'),'-o',str(binary)])
        result=subprocess.run([str(binary)],capture_output=True,check=True)
        assert not result.stderr,result.stderr.decode();outputs.append(result.stdout)
    assert outputs[0]==outputs[1]==outputs[2]
    data=outputs[0];scenarios,tics,words=struct.unpack_from('>III',data)
    assert (scenarios,tics,words)==(72,160,33) and len(data)==12+scenarios*tics*(5+words)*4
    # Prove why one UBSan category must be isolated: unchanged original negative RNG shift.
    audit=directory/'audit'
    p1.invoke(['clang',*[f for f in flags if f!='-fwrapv'],'-O2','-fsanitize=undefined','-fno-sanitize-recover=all','-Wno-deprecated-non-prototype','-I'+str(p1.SOURCE),str(cfile),str(p1.SOURCE/'p_pspr.c'),str(p1.SOURCE/'m_random.c'),str(p1.SOURCE/'m_fixed.c'),str(p1.SOURCE/'tables.c'),str(p1.SOURCE/'d_items.c'),'-o',str(audit)])
    result=subprocess.run([str(audit)],capture_output=True)
    assert result.returncode and b'left shift of negative value' in result.stderr
    manifest={'schemaVersion':1,'upstreamCommit':p1.UPSTREAM,'compiler':p1.VERSION,'target':p1.TARGET,'flags':flags,'profiles':profiles,
              'scenarioCount':scenarios,'ticsPerScenario':tics,'inputWords':5,'outputWords':words,
              'scope':'all9weapons x ammo0/100 x held/pulsedattack x hit/nohit, strengthat70, deathat120; BFGsprayat100; canonicalstateactioncascades; cyclicmap/missile/damage/noisehooks recorded sinks',
              'originalUndefinedShiftAudit':result.stderr.decode().replace(str(directory),'<build>').replace(str(p1.SOURCE),'original/linuxdoom-1.10').strip(),
              'undefinedSemantics':'Original negative (P_Random()-P_Random()) left shift is ISO C undefined; pinned O0/O2 equality audited. Solidity uses explicit wrapping multiplication; sanitizer/audit omit -fwrapv; all other UBSan categories and ASan active.',
              'sources':{f:p1.sha((p1.SOURCE/f).read_bytes()) for f in ['p_pspr.c','info.c','d_items.c','m_random.c','m_fixed.c','tables.c','r_main.c']},
              'harnessSha256':{f:p1.sha((HERE/f).read_bytes()) for f in ['weapons.py','weapon_host.c','weapon_driver.c']},
              'generatedSourceSha256':p1.sha(generated.encode()),'vectorsSha256':p1.sha(data)}
    return data,(json.dumps(manifest,indent=2)+'\n').encode()

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='doom-phase3-weapons-') as tmp: vectors,manifest=build(pathlib.Path(tmp))
    if not args.check:FIX.mkdir(parents=True,exist_ok=True)
    for name,data in [('weapons.bin',vectors),('weapons.json',manifest)]:
        path=FIX/name
        if args.check:assert path.read_bytes()==data,'Fixture drift '+name
        else:path.write_bytes(data)
    print('PASS original full p_pspr:72scenarios11520tics O0/O2/ASan+UBSan exact; negative-shift UB separately audited')
if __name__=='__main__':main()
