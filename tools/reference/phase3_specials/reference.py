#!/usr/bin/env python3
"""Original world helper/switch/animation/player/teleport unit oracle."""
import argparse, importlib.util, json, pathlib, random, re, struct, subprocess, tempfile
HERE=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('ref',HERE.parent/'reference.py');ref=importlib.util.module_from_spec(spec);spec.loader.exec_module(ref)
def extract(file,name,result=None):
    text=(ref.SOURCE/file).read_text();m=re.search(r'\n(?:fixed_t|int|void|boolean|side_t\*|sector_t\*)\s+'+name+r'\s*\([^;{}]*\)\s*\{',text);assert m,name
    start=m.start()+1;p=m.end();depth=1
    while depth:depth+=(text[p]=='{')-(text[p]=='}');p+=1
    body=text[start:p];return body,dict(file=file,function=name,startLine=text[:start].count('\n')+1,endLine=text[:p].count('\n')+1,sha256=ref.sha(body.encode()))
def tables():
    specSource=(ref.SOURCE/'p_spec.c').read_text();switchSource=(ref.SOURCE/'p_switch.c').read_text()
    def array(text,name):
        m=re.search(r'\b'+name+r'\s*\[\s*\]\s*=\s*\{',text);assert m;p=m.end();depth=1
        while depth:depth+=(text[p]=='{')-(text[p]=='}');p+=1
        return text[m.start():p]+';'
    arrays='switchlist_t '+array(switchSource,'alphSwitchList')+'\nanimdef_t '+array(specSource,'animdefs')
    switches=re.findall(r'\{"([A-Z0-9]+)",\s*"([A-Z0-9]+)",\s*(\d+)\}',switchSource)
    animations=re.findall(r'\{(false|true),\s*"([A-Z0-9]+)",\s*"([A-Z0-9]+)",\s*(\d+)\}',specSource)
    tex=[];flat=[]
    for first,second,_ in switches:tex.extend([first,second])
    for texture,end,start,_ in animations:
        names=tex if texture=='true' else flat
        assert start not in names and end not in names
        names.extend([start,f'X{len(names):06}',end])
    return arrays,tex,flat
def rows():
    rng=random.Random(0xD0035);rows=[]
    for _ in range(240):
        floors=[rng.randint(-1024,1024)*65536 for _ in range(4)];ceilings=[rng.randint(-2048,2048)*65536 for _ in range(4)];lights=[rng.randint(-32768,32767) for _ in range(4)];flags=[rng.choice([0,4,36]) for _ in range(3)]
        rows.append((0,floors+ceilings+lights+flags+[rng.randint(-500,500)*65536,rng.choice([-1,0,1,2,3]),rng.randrange(4),rng.randint(0,255)]))
    for where in range(3):
        for value in [10,11,20,21,30,31,999]:
            for repeat in [0,1]:
                vals=[999,999,999];vals[where]=value;rows.append((1,vals+[repeat,11]))
    rows += [(1,[30,10,20,1,46]),(1,[10,20,30,1,46]),(2,[0]),(2,[1])]
    for tick in [0,1,7,8,31,34,35,64]:
        for timer in [0,1]:rows.append((3,[tick,timer,1]))
    rows += [(4,[0]),(4,[1]),(4,[2])]+[(5,[mode]) for mode in range(4)]
    for special in [5,7,16,4,9,11]:
        for power in [0,1]:
            for tick in [0,1,31,32]:
                for prnd in [0,255]:rows.append((6,[special,power,tick,prnd,30,0]))
    rows += [(6,[11,0,0,0,10,0]),(6,[9,0,0,0,100,1])]
    rows += [(7,[v]) for v in range(8)]+[(8,[])]
    return rows
def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
    assert ref.invoke(['git','-C',str(ref.SOURCE),'rev-parse','HEAD']).strip()==ref.UPSTREAM
    assert not ref.invoke(['git','-C',str(ref.SOURCE),'diff','--name-only'])
    version=ref.invoke(['clang','--version']).splitlines();assert version[0]==ref.VERSION and version[1]=='Target: '+ref.TARGET
    selected={'p_spec.c':['P_InitPicAnims','getSide','getSector','twoSided','getNextSector','P_FindLowestFloorSurrounding','P_FindHighestFloorSurrounding','P_FindNextHighestFloor','P_FindLowestCeilingSurrounding','P_FindHighestCeilingSurrounding','P_FindSectorFromLineTag','P_FindMinSurroundingLight','P_PlayerInSpecialSector','P_UpdateSpecials'],'p_switch.c':['P_InitSwitchList','P_StartButton','P_ChangeSwitchTexture'],'p_telept.c':['EV_Teleport']}
    functions=[];records=[]
    for file,names in selected.items():
        for name in names:body,meta=extract(file,name);functions.append(body);records.append(meta)
    arrays,tex,flat=tables();generated=(HERE/'host.c').read_text()+'\n'+arrays+'\n'+'\n'.join(functions)+'\n'+(HERE/'driver.c').read_text()
    nameheader='static const char *texnames[] = {'+','.join(json.dumps(s) for s in tex)+'};\nstatic const char *flatnames[] = {'+','.join(json.dumps(s) for s in flat)+'};\n'
    cases=rows();commands=''.join(f'{op} {len(args)} '+' '.join(map(str,args))+'\n' for op,args in cases).encode();outputs=[];profiles=[]
    with tempfile.TemporaryDirectory(prefix='doom-world-specials-') as td:
        td=pathlib.Path(td);(td/'oracle.c').write_text(generated);(td/'names.h').write_text(nameheader);(td/'values.h').write_text('#include <limits.h>\n#include "doomtype.h"\n')
        for name,opt,sanitize in [('O0','-O0',False),('O2','-O2',False),('sanitized','-O2',True)]:
            flags=[opt if f=='-O2' else f for f in ref.FLAGS]+['-fsigned-char']
            if sanitize:flags+=['-fsanitize=address,undefined','-fno-sanitize-recover=all']
            ref.invoke(['clang',*flags,'-I'+str(td),'-I'+str(ref.SOURCE),str(td/'oracle.c'),str(ref.SOURCE/'m_random.c'),str(ref.SOURCE/'tables.c'),'-o',str(td/name)])
            run=subprocess.run([str(td/name)],input=commands,capture_output=True,check=True);outputs.append(run.stdout);profiles.append(dict(name=name,flags=flags,outputSha256=ref.sha(run.stdout),stderrSha256=ref.sha(run.stderr)))
    assert all(o==outputs[0] for o in outputs),'Native world special profile divergence'
    encoded=bytearray(struct.pack('>I',len(cases)));data=outputs[0];at=0
    for op,args in cases:
        no=struct.unpack_from('>I',data,at)[0];at+=4;answer=data[at:at+no*4];at+=no*4
        encoded.extend(struct.pack('>III',op,len(args),no));encoded.extend(struct.pack('>'+str(len(args))+'i',*args));encoded.extend(answer)
    assert at==len(data)
    manifest=dict(upstream=ref.UPSTREAM,compiler=ref.VERSION,target=ref.TARGET,cases=len(cases),extractions=records,sourceHashes={file:ref.sha((ref.SOURCE/file).read_bytes()) for file in [*selected,'m_random.c']},harnessHashes={f:ref.sha((HERE/f).read_bytes()) for f in ['reference.py','host.c','driver.c']},generatedSha256=ref.sha(generated.encode()),namesHeaderSha256=ref.sha(nameheader.encode()),profiles=profiles,vectorSha256=ref.sha(encoded),scope='18 mechanically extracted unchanged original functions + original switch/animation definitions; declared synthetic geometry/resources; damage/teleport/fog callbacks recorded mocks, full mechanics proof separately')
    files={'vectors.bin':bytes(encoded),'manifest.json':(json.dumps(manifest,indent=2)+'\n').encode(),'names.bin':b''.join(s.encode().ljust(8,b'\0') for s in tex+flat),'names.json':(json.dumps({'textures':len(tex),'flats':len(flat)},indent=2)+'\n').encode()}
    dest=ref.ROOT/'test/fixtures/phase3_specials'
    for filename,value in files.items():
        if a.check:assert (dest/filename).read_bytes()==value,filename
        else:(dest/filename).write_bytes(value)
    print(f'PASS original world specials: {len(cases)} cases, O0/O2/ASan/UBSan exact')
if __name__=='__main__':
    try:main()
    except subprocess.CalledProcessError as error:
        print(error.stderr.decode() if isinstance(error.stderr,bytes) else error.stderr);raise
