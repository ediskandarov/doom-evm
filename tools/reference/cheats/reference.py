#!/usr/bin/env python3
"""Source-extracted original DOOM cheats; signed-char O0/O2/ASan/UBSan oracle."""
import argparse, hashlib, json, os, pathlib, random, re, struct, subprocess, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[3]
HERE=pathlib.Path(__file__).resolve().parent
SOURCE=ROOT/'original/DOOM/linuxdoom-1.10'
FIX=ROOT/'test/fixtures/phase4_cheats'
def sha(b): return hashlib.sha256(b).hexdigest()
def extract(file,name):
    source=(SOURCE/file).read_text()
    m=re.search(r'\n(?:boolean|int|void)\s+'+name+r'\s*\([^;{]*\)\s*\{',source);assert m,name
    start,end,depth=m.start()+1,m.end(),1
    masked=re.sub(r'/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"',lambda x:' '*len(x[0]),source,flags=re.S)
    while depth:
        depth+=(masked[end]=='{')-(masked[end]=='}');end+=1
    body=source[start:end]
    return body,dict(file=file,function=name,startLine=source[:start].count('\n')+1,endLine=source[:end].count('\n')+1,sha256=sha(body.encode()))
def cases():
    rows=[]
    default=[0,0,4,0,1,37,29,0]
    def add(name,text,config=None,active=1,dm=0):
        events=[[0,k,active,dm] for k in text.encode('latin1')] if isinstance(text,str) else text
        rows.append(dict(name=name,initial=config or default,events=events))
    codes=['iddqd','idkfa','idfa','idspispopd','idclip','idbehold','idbeholdv','idbeholds','idbeholdi','idbeholdr','idbeholda','idbeholdl','idchoppers','idmypos','idclev11','iddt']
    for code in codes:
        add(code,code*3)
        add(code+'-mismatch','i'+code+'x'+code)
        add(code+'-keyup',[[v,k,1,0] for k in code.encode() for v in (0,1)])
        add(code+'-uppercase',code.upper()+code)
    for cp in (1,3):add('console-'+str(cp),'iddqd idbeholds idmypos',[1,0,4,cp,1,7,3,0])
    add('null-mo','iddqdiddqd',[0,0,4,0,0,-7,29,0])
    for power in (1,123,-3):add('existing-powers-'+str(power),''.join(codes[6:12])*2,[3,0,4,0,1,170,23,power])
    add('dead-strength','idbeholds',[0,0,2,0,1,-20,-20,0])
    add('netgame',''.join(codes),[0,1,2,0,1,37,29,0])
    add('dt-inactive','iddtiddt',active=0)
    add('dt-deathmatch','iddtiddt',dm=1)
    add('dt-gated-interleave',[[0,k,a,d] for k,a,d in [(105,1,0),(120,0,0),(100,1,0),(120,1,1),(100,1,0),(116,1,0)]])
    add('st-high-key-bits',[[0,256+k,1,0] for k in b'iddqd'])
    add('st-partial-keyup','idd')
    add('music-excluded','idmus11iddqd')
    for mode in range(4):
        for param in ('00','01','10','11','19','21','39','49','51',':1','1:','\xff1','1\x80'):
            add('warp-'+str(mode)+'-'+param.encode('latin1').hex(),'idclev'+param+'idclev11',[mode,0,3,0,1,37,29,0])
    rng=random.Random(0x434844)
    for i in range(20):
        events=[]
        for j in range(12):
            text=rng.choice(codes)
            if j%3==0:text=text[:rng.randrange(len(text))]
            events += [[0,k,1,0] for k in text.encode()]
            events += [[rng.choice([0,1,2,3]),rng.randrange(1,256),rng.randrange(2),rng.randrange(2)]]
        add('mixed-'+str(i),events)
    return rows

def primitive_cases():
    rows=[]
    # Every char value at an ordinary character and both raw parameter slots.
    for key in range(256):
        for cursor in (0,7,8):
            rows.append(dict(sequence='b226e236a66e010000ff',cursor=cursor,key=key,getParam=0))
    # GetParam after completions, embedded NUL, bytes which resemble control markers.
    for a in (0,1,49,128,255):
        for b in (0,1,57,128,255):
            rows.append(dict(sequence='b226e236a66e01'+bytes([a,b]).hex()+'ff',cursor=0,key=120,getParam=1))
    return rows

def build_source(driver="driver.c"):
    records=[];bodies=[]
    for name in ('cht_CheckCheat','cht_GetParam'):
        body,r=extract('m_cheat.c',name);records.append(r);bodies.append(body)
    bodies.insert(0,'static int firsttime=1; static unsigned char cheat_xlate_table[256];')
    st=(SOURCE/'st_stuff.c').read_text()
    definitions=st[st.index('unsigned char\tcheat_mus_seq[]'):st.index('// Now what?')]
    definitions+=st[st.index('cheatseq_t\tcheat_mus ='):st.index('// \nextern char*\tmapnames')]
    bodies.append(definitions)
    body,r=extract('st_stuff.c','ST_Responder');records.append(r)
    start=body.index('      // \'mus\' cheat')
    end=body.index('      // Simplified,',start)
    r['excludedMusicBranchSha256']=sha(body[start:end].encode())
    body=body[:start]+body[end:]
    bodies.append(body)
    for name in ('P_GiveBody','P_GivePower'):
        body,r=extract('p_inter.c',name);records.append(r);bodies.append(body)
    am=(SOURCE/'am_map.c').read_text()
    bodies.append('static int cheating=0;\n'+re.search(r'static unsigned char cheat_amap_seq\[\].*?static cheatseq_t cheat_amap.*?;',am,re.S)[0])
    start=am.index('if (!deathmatch && cht_CheckCheat(&cheat_amap, ev->data1))')
    end=am.index('}',start)+1
    branch=am[start:end]
    records.append(dict(file='am_map.c',function='AM_Responder cheat branch',startLine=am[:start].count('\n')+1,endLine=am[:end].count('\n')+1,sha256=sha(branch.encode())))
    bodies.append('static void AM_Cheat(event_t *ev){int rc=0;'+branch+'}')
    return (HERE/'host.c').read_text()+'\n'+'\n'.join(bodies)+'\n'+(HERE/driver).read_text(),records

def take_snapshot(raw,at):
    start=at
    # 40 state words, then message length and bytes.
    at=start+41*4
    length=struct.unpack_from('>I',raw,start+40*4)[0];at+=length
    for _ in range(16):
        n=struct.unpack_from('>I',raw,at+4)[0];at+=8+n
    return raw[start:at],at

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args()
    upstream=subprocess.check_output(['git','-C',str(SOURCE),'rev-parse','HEAD'],text=True).strip()
    assert upstream=='a77dfb96cb91780ca334d0d4cfd86957558007e0'
    subprocess.run(['git','-C',str(SOURCE),'diff','--exit-code','HEAD','--'],check=True,capture_output=True)
    generated,records=build_source();rows=cases();lines=[]
    for row in rows:
        lines.append('0 '+' '.join(map(str,row['initial'])))
        lines += ['1 '+' '.join(map(str,e)) for e in row['events']]
    inputs=('\n'.join(lines)+'\n').encode();outputs=[]
    profiles={'O0':['-O0'],'O2':['-O2'],'sanitize':['-O2','-fsanitize=address,undefined','-fno-sanitize-recover=all']}
    flags=['-std=c11','-fsigned-char','-fno-strict-aliasing','-ffp-contract=off','-fno-fast-math']
    with tempfile.TemporaryDirectory(prefix='doom-cheats-') as temp:
        path=pathlib.Path(temp);(path/'oracle.c').write_text(generated)
        for name,opts in profiles.items():
            run=subprocess.run(['clang',*flags,*opts,'-I'+str(SOURCE),str(path/'oracle.c'),'-o',str(path/name)],capture_output=True,text=True)
            assert run.returncode==0,run.stderr
            run=subprocess.run([str(path/name)],input=inputs,capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'})
            assert run.returncode==0 and not run.stderr,(name,run.stderr.decode())
            outputs.append(run.stdout)
    assert outputs[0]==outputs[1]==outputs[2]
    raw=outputs[0];at=0;binary=struct.pack('>I',len(rows));snapshots=0
    def words(values):return b''.join(struct.pack('>I',v&0xffffffff) for v in values)
    for row in rows:
        binary+=words(row['initial'])+words([len(row['events'])]);hashes=[]
        for event in row['events']:
            snap,at=take_snapshot(raw,at);digest=hashlib.sha256(snap).digest()
            binary+=words(event)+digest;hashes.append(digest.hex());snapshots+=1
        row['snapshotSha256']=hashes
    assert at==len(raw),(at,len(raw))
    manifest=dict(upstreamCommit=upstream,cases=len(rows),snapshots=snapshots,compiler=subprocess.check_output(['clang','--version'],text=True).splitlines()[:2],flags=flags,profiles=profiles,
        extractions=records,sources={p.name:sha(p.read_bytes()) for p in sorted(SOURCE.glob('*.h'))}|{name:sha((SOURCE/name).read_bytes()) for name in ['m_cheat.c','st_stuff.c','am_map.c','p_inter.c']},
        harness={f:sha((HERE/f).read_bytes()) for f in ['host.c','driver.c','reference.py']},generatedSourceSha256=sha(generated.encode()),vectorsSha256=sha(binary),
        scope='Original ST_Responder minus IDMUS branch; actual cht_CheckCheat/cht_GetParam/P_GivePower/P_GiveBody. AM cheat branch only, navigation/rendering excluded. Snapshot every event including all 16 recognition cursors and mutable sequence bytes. No early NUL warp parameters (uninitialized native buffer).',
        initialFields=['gamemode','netgame','skill','consoleplayer','hasMobj','health','actorHealth','initialPower'],eventFields=['type','data1','activeAutomapBranch','deathmatch'])
    for name,data in [('vectors.bin',binary),('cases.json',(json.dumps(rows,indent=2)+'\n').encode())]:
        if args.check:assert (FIX/name).read_bytes()==data,'stale '+name
        else:(FIX/name).write_bytes(data)
    primitive_source,_=build_source('primitive_driver.c')
    primitive=primitive_cases();primitive_input=''.join(f"10 {r['cursor']} {r['key']} {r['getParam']} "+' '.join(str(v) for v in bytes.fromhex(r['sequence']))+'\n' for r in primitive).encode()
    primitive_outputs=[]
    with tempfile.TemporaryDirectory(prefix='doom-cheat-primitive-') as temp:
        path=pathlib.Path(temp);(path/'oracle.c').write_text(primitive_source)
        for name,opts in profiles.items():
            run=subprocess.run(['clang',*flags,*opts,'-I'+str(SOURCE),str(path/'oracle.c'),'-o',str(path/name)],capture_output=True,text=True);assert run.returncode==0,run.stderr
            run=subprocess.run([str(path/name)],input=primitive_input,capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'});assert run.returncode==0 and not run.stderr,run.stderr
            primitive_outputs.append(run.stdout)
    assert primitive_outputs[0]==primitive_outputs[1]==primitive_outputs[2]
    primitive_binary=words([len(primitive)]);at=0;raw=primitive_outputs[0]
    for row in primitive:
        n=struct.unpack_from('>I',raw,at+8)[0];size=struct.unpack_from('>I',raw,at+12+n)[0]
        snap=raw[at:at+16+n+size];at+=len(snap)
        primitive_binary+=bytes.fromhex(row['sequence'])+words([row['cursor'],row['key'],row['getParam']])+hashlib.sha256(snap).digest()
    assert at==len(raw)
    manifest.update(primitiveCases=len(primitive),primitiveVectorsSha256=sha(primitive_binary),primitiveGeneratedSourceSha256=sha(primitive_source.encode()))
    manifest['harness']['primitive_driver.c']=sha((HERE/'primitive_driver.c').read_bytes())
    for name,data in [('primitive.bin',primitive_binary),('manifest.json',(json.dumps(manifest,indent=2)+'\n').encode())]:
        if args.check:assert (FIX/name).read_bytes()==data,'stale '+name
        else:(FIX/name).write_bytes(data)
    print(f'PASS {len(primitive)} primitive native cases')
    print(f'PASS {len(rows)} scenarios / {snapshots} event snapshots; original C O0/O2/ASan/UBSan exact')
if __name__=='__main__':main()
