#!/usr/bin/env python3
"""Entire original world mover units, original neighbor/list helpers, canonical native snapshots."""
import argparse
import gzip
import importlib.util
import json
import pathlib
import re
import struct
import subprocess
import tempfile
ROOT=pathlib.Path(__file__).resolve().parents[3]
HERE=pathlib.Path(__file__).resolve().parent
FIX=ROOT/'test/fixtures/phase3_world'
spec=importlib.util.spec_from_file_location('p1',HERE.parent/'reference.py')
p1=importlib.util.module_from_spec(spec);spec.loader.exec_module(p1)
UNITS=['p_doors.c','p_floor.c','p_ceilng.c','p_plats.c','p_lights.c']
HELPERS=['getSide','getSector','twoSided','getNextSector','P_FindLowestFloorSurrounding','P_FindHighestFloorSurrounding','P_FindNextHighestFloor','P_FindLowestCeilingSurrounding','P_FindHighestCeilingSurrounding','P_FindSectorFromLineTag','P_FindMinSurroundingLight']

def extract(file,name):
    text=(p1.SOURCE/file).read_text()
    match=re.search(r'\n(?:void|int|fixed_t|side_t\*|sector_t\*|result_e)\s+'+name+r'\s*\(',text)
    assert match,name
    start=match.start()+1;end=text.index('{',match.end())+1;depth=1
    while depth:
        depth+=(text[end]=='{')-(text[end]=='}');end+=1
    body=text[start:end]
    return body,{'file':file,'function':name,'startLine':text[:start].count('\n')+1,'endLine':text[:end].count('\n')+1,'sha256':p1.sha(body.encode())}

def rows():
    out=[]
    def row(op,kind,obstruction=0,mode=0,amount=0,seed=0,ticks=160,light=0):out.append([op,kind,obstruction,mode,amount,seed,ticks,light])
    for kind in [0,1,2,3,5,6,7]:
        for obstruction in [0,1,2,3]:row(1,kind,obstruction,ticks=1250 if kind==1 else 240)
    for kind in [1,26,27,28,31,32,33,34,117,118]:
        for mode in [0,1]:
            for cards in [0,63]:row(2,kind,mode=mode,amount=cards,ticks=240)
    row(3,0,ticks=1130);row(3,1,ticks=10740)
    for kind in [0,1,2,3,4,5,6,7,8,9,10,12]:
        for obstruction in [0,1,2,3]:row(4,kind,obstruction,ticks=600 if kind==12 else 160)
    for kind in range(6):
        for obstruction in [0,1,2,3]:row(5,kind,obstruction,ticks=240)
    for kind in range(5):
        for obstruction in [0,1,2,3]:
            for seed in [0,17]:row(6,kind,obstruction,amount=24,seed=seed,ticks=320)
    for kind in range(8):
        for profile in [0,1]:
            for seed in [0,17,255]:
                if kind==2:
                    for sync in [0,1]:row(7,kind,mode=sync,amount=15 if profile else 35,seed=seed,ticks=160,light=profile)
                else:row(7,kind,seed=seed,ticks=160,light=profile)
    for kind in range(2):
        for obstruction in [0,1,2,3]:row(8,kind,obstruction,ticks=160)
        row(8,kind,ticks=160,light=2)
    for kind,direction in [(11,0),(6,1)]:
        for obstruction in [0,1,2,3]:
            for crush in [0,1]:row(9,kind,obstruction,mode=direction,amount=crush,ticks=32)
    row(10,0,ticks=0)
    for lock in [99,133,134,135,136,137]:
        for cards in [0,1,8,2,16,4,32,63]:
            for mode in [0,1]:row(11,lock,mode=mode,amount=cards,ticks=80,light=5)
    return out

def build(directory,driver_override=None):
    assert p1.invoke(['git','-C',str(p1.SOURCE),'rev-parse','HEAD']).strip()==p1.UPSTREAM
    assert not p1.invoke(['git','-C',str(p1.SOURCE),'diff','--name-only','HEAD'])
    assert p1.invoke(['clang','--version']).splitlines()[:2]==[p1.VERSION,'Target: '+p1.TARGET]
    extracted=[extract('p_spec.c',name) for name in HELPERS]
    extracted += [extract('p_tick.c',name) for name in ['P_InitThinkers','P_AddThinker','P_RemoveThinker','P_RunThinkers']]
    driver=pathlib.Path(driver_override) if driver_override else HERE/'driver.c'
    limit=re.search(r'^#define\s+MAX_ADJOINING_SECTORS[^\n]*',(p1.SOURCE/'p_spec.c').read_text(),re.M)[0]
    generated=(HERE/'host.c').read_text()+'\n'+limit+'\n'+'\n'.join(body for body,_ in extracted)+'\n'+driver.read_text()
    source=directory/'world.c';source.write_text(generated)
    flags=['-std=c11','-fsigned-char','-fwrapv','-fno-strict-aliasing','-ffp-contract=off','-fno-fast-math']
    profiles={'O0':['-O0'],'O2':['-O2'],'sanitize':['-O2','-fsanitize=address,undefined','-fno-sanitize-recover=all']}
    for name,profile in profiles.items():
        cmd=['clang',*flags,*profile,'-I'+str(p1.SOURCE),str(source),*[str(p1.SOURCE/f) for f in UNITS],str(p1.SOURCE/'m_random.c'),'-o',str(directory/name)]
        try:p1.invoke(cmd)
        except subprocess.CalledProcessError as error:raise RuntimeError(error.stderr) from error
    metadata={'schemaVersion':1,'upstreamCommit':p1.UPSTREAM,'compiler':p1.VERSION,'target':p1.TARGET,'flags':flags,'profiles':profiles,
              'sources':{f:p1.sha((p1.SOURCE/f).read_bytes()) for f in UNITS+['p_spec.c','p_tick.c','p_spec.h','p_local.h','r_defs.h','doomdef.h','m_random.c']},
              'extractions':[record for _,record in extracted],'harnessSha256':{f:p1.sha((HERE/f).read_bytes()) for f in ['reference.py','host.c','driver.c']},'generatedSourceSha256':p1.sha(generated.encode())}
    return metadata

def parse(raw,inputs):
    pos=0; vectors=bytearray(struct.pack('>I',len(inputs)));descriptions=[];record_count=0
    for index,a in enumerate(inputs):
        actual=list(struct.unpack_from('>8i',raw,pos));pos+=32;assert actual==a
        count,=struct.unpack_from('>I',raw,pos);pos+=4;assert count==a[6]+1
        vectors+=struct.pack('>8iI',*a,count)
        for _ in range(count):
            words,=struct.unpack_from('>I',raw,pos);pos+=4
            data=raw[pos:pos+words*4];pos+=words*4;assert len(data)==words*4
            vectors+=bytes.fromhex(p1.sha(data));record_count+=1
        descriptions.append({'index':index,'inputs':a,'snapshots':count})
    assert pos==len(raw)
    return bytes(vectors),descriptions,record_count

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    inputs=rows();stdin=''.join(' '.join(map(str,a))+'\n' for a in inputs).encode()
    with tempfile.TemporaryDirectory(prefix='doom-phase3-world-') as tmp:
        directory=pathlib.Path(tmp);metadata=build(directory);outputs=[]
        for name in ['O0','O2','sanitize']:
            result=subprocess.run([str(directory/name)],input=stdin,capture_output=True,check=True)
            assert not result.stderr,result.stderr.decode();outputs.append(result.stdout)
        assert outputs[0]==outputs[1]==outputs[2],'Native world profile divergence'
    vectors,descriptions,count=parse(outputs[0],inputs)
    metadata.update({'scenarioCount':len(inputs),'snapshotCount':count,'vectorsSha256':p1.sha(vectors),'nativeSnapshotsSha256':p1.sha(outputs[0]),
        'scope':'all active movers/lights/locks/stairs, linked thinker order, stop/resume/retrigger, ceiling registry overflow, changeSector obstruction profiles; synthetic four-sector geometry; zero allocation profile; callback algorithms and exact immutable source units retained',
        'originalUninitializedFields':'P_SpawnDoorCloseIn30 leaves topheight/topwait unset; stair floors leave type/crush unset. Raw bytes of these fields are logically masked to zero in state snapshots; execution is explicitly the zero allocator profile. Stair crush is consumed by changeSector from the first tic, and timer-door topheight/topwait may become meaningful after obstruction reversal. Alternate-fill execution must be separately audited; these cases do not establish portable ISO-C behavior.'})
    files={'vectors.bin':vectors,'native-snapshots.bin.gz':gzip.compress(outputs[0],mtime=0),
           'manifest.json':(json.dumps(metadata,indent=2)+'\n').encode(),'scenarios.json':(json.dumps(descriptions,indent=2)+'\n').encode()}
    if not args.check:FIX.mkdir(parents=True,exist_ok=True)
    for name,data in files.items():
        path=FIX/name
        if args.check:assert path.read_bytes()==data,'Fixture drift '+name
        else:path.write_bytes(data)
    print(json.dumps({'result':'PASS','scenarios':len(inputs),'snapshots':count,'native':'entire original five units; O0/O2/full ASan+UBSan exact; zero heap profile','mode':'check' if args.check else 'generate'}))
if __name__=='__main__':main()
