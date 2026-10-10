#!/usr/bin/env python3
"""Unchanged pinned original WI/video/RNG oracle; state and complete indexed pixels."""
import argparse, hashlib, json, os, pathlib, re, shutil, struct, subprocess, tempfile

ROOT = pathlib.Path(__file__).resolve().parents[3]
HERE = pathlib.Path(__file__).resolve().parent
FIX = ROOT / 'test/fixtures/phase4_intermission'
PIN = 'a77dfb96cb91780ca334d0d4cfd86957558007e0'
WORDS = 113
RAW_SIZE = WORDS*4 + 16 + 128000
FUNCTIONS = ['WI_Start','WI_initVariables','WI_loadData','WI_unloadData','WI_End',
 'WI_Ticker','WI_checkForAccelerate','WI_Drawer','WI_Responder',
 'WI_initStats','WI_updateStats','WI_drawStats','WI_initShowNextLoc','WI_updateShowNextLoc',
 'WI_drawShowNextLoc','WI_initNoState','WI_updateNoState','WI_drawNoState',
 'WI_initAnimatedBack','WI_updateAnimatedBack','WI_drawAnimatedBack','WI_slamBackground',
 'WI_drawLF','WI_drawEL','WI_drawOnLnode','WI_drawNum','WI_drawPercent','WI_drawTime']
NAMES = ['WIMAP0',*[f'WILV0{i}' for i in range(9)],'WIURH0','WIURH1','WISPLAT',
 *[f'WIA0{j:02}{i:02}' for j in range(10) for i in range(3)],'WIMINUS',
 *[f'WINUM{i}' for i in range(10)],'WIPCNT','WIF','WIENTER','WIOSTK','WIOSTS','WISCRT2',
 'WIOSTI','WIFRGS','WICOLON','WITIME','WISUCKS','WIPAR','WIKILRS','WIVCTMS','WIMSTT',
 'STFST01','STFDEAD0',*[n for i in range(4) for n in (f'STPB{i}',f'WIBP{i+1}')]]
def sha(b): return hashlib.sha256(b).hexdigest()
def pack(values): return struct.pack('>'+str(len(values))+'i',*values)
def patch(w,h,left,top,color):
    posts=[bytes([0,h,0])+bytes((color+x+y)&255 for y in range(h))+bytes([0,255]) for x in range(w)]
    at=8+4*w; offsets=[]
    for post in posts: offsets.append(at);at+=len(post)
    return struct.pack('<4h',w,h,left,top)+struct.pack('<'+str(w)+'I',*offsets)+b''.join(posts)
def scenarios():
    rows=[]
    def add(name,actions,**kw):
        values=dict(mode=3,last=0,next=1,didsecret=0,maxkills=5,maxitems=3,maxsecret=2,
                    kills=3,items=2,secrets=1,time=35*89+34,par=35*120,attack=0,use=0,rng=0,assets=0)
        values.update(kw);rows.append(dict(name=name,header=list(values.values()),actions=actions))
    def tick(n=1,buttons=0,draw=1): return [0,n,buttons,draw,0]
    skip=[tick(1,1),tick(1,1),tick(1,0),tick(1,2),tick(1,2),tick(1,0),tick(1,1),tick(9,1),tick(1,0,0)]
    add('natural-counting-all-tics-and-timeout',
        [tick(1,0,int(i in {1,34,35,36,65,66,100,105,140,200,250,300,350})) for i in range(1,351)]
        +[tick(1,1),tick(100,1),tick(1,0),tick(39,0),tick(10,0,0)])
    for mode in [0,1,3]: add(f'zero-totals-mode-{mode}',[tick(1,0,int(i%35==0)) for i in range(200)]+[tick(1,1),tick(140,0),tick(10,0,0)],
        mode=mode,maxkills=0,maxitems=0,maxsecret=0,kills=0,items=0,secrets=0,time=0,par=0)
    add('fire-use-hold-release-and-skip',skip)
    add('secret-entry-visible-markers',skip,last=2,next=8,assets=1,rng=254)
    add('secret-return-visible-markers',skip,last=8,next=3,didsecret=1,assets=1,rng=255)
    add('repeated-intermission-pointer-latches-rng',skip+[[2,3,4,1,0]]+skip,assets=1)
    add('inherited-held-latches',[tick(1,3),tick(1,0)]+skip,attack=1,use=1)
    add('special-pause-attack-overlap',[tick(1,129),tick(1,129),tick(1,0),tick(1,129),tick(140,0),tick(10,0,0)])
    add('percentages-above-100-and-time-overflow',skip,kills=12,items=6,secrets=5,time=35*3600,par=35*3599)
    add('number-sentinel-percentage-1994',skip,maxkills=100,kills=1994)
    for last in range(9): add(f'finished-title-{last}',[[1,0,0,0,0],tick(1,1)],last=last,next=(last+1)%9)
    for nextmap in range(9): add(f'entering-title-node-{nextmap}',skip,next=nextmap,assets=1)
    add('draw-number-percent-time-quirks',
        [[3,270,90,n,d] for n,d in [(0,-1),(1,-1),(-12,-1),(12345,2),(1994,-1),(7,0)]]
        +[[4,270,110,n,0] for n in [-1,0,100,1994]]
        +[[5,270,150,n,0] for n in [-1,0,59,60,3599,3600]])
    add('pointer-fallback-second-candidate',[[6,n,0,0,0] for n in range(9)],assets=2)
    add('pointer-neither-candidate-fits',[[6,n,0,0,0] for n in range(9)],assets=3)
    add('pinned-animation-draw-suppressed',[[1,0,0,0,0],tick(25,0,0),[7,0,0,0,0]],assets=1)
    return rows
def mapping(source):
    text=(source/'wi_stuff.c').read_text();rows=[]
    for name in FUNCTIONS:
        m=re.search(r'\n(?:void|boolean|int)\s+'+name+r'\s*\([^;{]*\)\s*\{',text);assert m,name
        start=m.start()+1;end=m.end();depth=1
        while depth: depth+=(text[end]=='{')-(text[end]=='}');end+=1
        rows.append(dict(function=name,startLine=text[:start].count('\n')+1,endLine=text[:end].count('\n')+1,sha256=sha(text[start:end].encode())))
    return rows
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true')
    ap.add_argument('--source',default=os.environ.get('DOOM_ORIGINAL',str(ROOT/'original/DOOM/linuxdoom-1.10')))
    ap.add_argument('--wad',default=os.environ.get('DOOM_WAD',str(ROOT/'artifacts/local/freedoom/freedoom1.wad')))
    args=ap.parse_args();source=pathlib.Path(args.source).resolve();wad=pathlib.Path(args.wad).read_bytes()
    assert subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip()==PIN
    assert not subprocess.check_output(['git','-C',str(source),'diff','--name-only','HEAD'],text=True)
    count,at=struct.unpack_from('<ii',wad,4);directory={}
    for i in range(count):
        offset,n,name=struct.unpack_from('<ii8s',wad,at+16*i);directory[name.rstrip(b'\0').decode()]=(i,offset,n)
    expected=json.loads((ROOT/'test/fixtures/wad/manifest.json').read_text()) if (ROOT/'test/fixtures/wad/manifest.json').exists() else None
    assert sha(wad)=='7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d'
    rows=scenarios();files={};resources=[];warnings=[]
    for name in NAMES:
        i,offset,n=directory[name];b=wad[offset:offset+n];files[name+'.bin']=b
        resources.append(dict(name=name,lumpId=i,length=n,sha256=sha(b)))
    synthetic={'WIURH0':patch(8,6,4,3,240),'WIURH1':patch(5,5,2,2,0),
               'WISPLAT':patch(3,3,1,1,253),'WIA00000':patch(3,3,0,0,128),'HUGE':patch(320,200,0,0,37)}
    for name,b in synthetic.items():files['synthetic/'+name+'.bin']=b
    asset_profiles=[]
    for profile in range(4):
        blob=bytearray();entries=bytearray()
        for name in NAMES:
            b=files[name+'.bin']
            if profile and name in synthetic: b=synthetic[name]
            if profile>=2 and name=='WIURH0': b=synthetic['HUGE']
            if profile==3 and name=='WIURH1': b=synthetic['HUGE']
            entries+=name.encode().ljust(8,b'\0')+struct.pack('>II',len(blob),len(b));blob+=b
        data=struct.pack('>I',len(NAMES))+entries+blob;files[f'assets-{profile}.bin']=bytes(data)
        asset_profiles.append(dict(profile=profile,sha256=sha(data),blobSha256=sha(blob),blobBytes=len(blob),namedLumps=len(NAMES)))
    profiles={'O0':['-O0'],'O2':['-O2'],'sanitized':['-O1','-g','-fsanitize=address,undefined','-fno-sanitize=array-bounds','-fno-sanitize-recover=all']}
    flags=['-std=c11','-DRANGECHECK','-fsigned-char','-fno-strict-aliasing','-ffp-contract=off','-fno-fast-math']
    snapshots=0;packed=bytearray();compiler=subprocess.check_output(['clang','--version'],text=True).splitlines()[:2]
    with tempfile.TemporaryDirectory(prefix='doom-intermission-') as tmpname:
        tmp=pathlib.Path(tmpname);assets=tmp/'assets';assets.mkdir()
        for name,b in files.items():p=assets/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
        binaries=[]
        for label,profile in profiles.items():
            binary=tmp/label;cmd=['clang',*flags,*profile,'-include',str(HERE/'compat.h'),'-I'+str(source),str(HERE/'host.c'),str(source/'v_video.c'),str(source/'m_bbox.c'),str(source/'m_random.c'),'-o',str(binary)]
            r=subprocess.run(cmd,capture_output=True);assert r.returncode==0,r.stderr.decode();warnings.append({'profile':label,'stderr':r.stderr.decode().replace(str(ROOT),'.').replace(str(source),'original/DOOM/linuxdoom-1.10')});binaries.append(binary)
        for i,row in enumerate(rows):
            data=pack(row['header'])+pack([len(row['actions'])])+b''.join(pack(a) for a in row['actions']);files[f'{i}.bin']=data
            inputpath=tmp/'input.bin';inputpath.write_bytes(data);outputs=[]
            for binary in reversed(binaries):
                r=subprocess.run([str(binary),str(inputpath),str(assets)],capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0:halt_on_error=1','UBSAN_OPTIONS':'halt_on_error=1'})
                assert r.returncode==0 and not r.stderr,(row['name'],binary.name,r.returncode,r.stderr.decode());outputs.append(r.stdout)
            assert outputs[0]==outputs[1]==outputs[2],row['name'];raw=outputs[0]
            assert len(raw)==(len(row['actions'])+1)*RAW_SIZE,(row['name'],len(raw),RAW_SIZE)
            compact=bytearray();checks=[]
            for j in range(len(row['actions'])+1):
                base=j*RAW_SIZE;state=raw[base:base+WORDS*4];dirty=raw[base+WORDS*4:base+WORDS*4+16]
                frame=raw[base+WORDS*4+16:base+WORDS*4+16+64000];bg=raw[base+WORDS*4+16+64000:base+RAW_SIZE]
                compact+=state+dirty+hashlib.sha256(frame).digest()+hashlib.sha256(bg).digest()
                checks.append(dict(stateSha256=sha(state),frameSha256=sha(frame),backgroundSha256=sha(bg)))
            files[f'{i}.expected.bin']=bytes(compact);files[f'{i}.pixels']=frame
            packed+=struct.pack('>I',len(data))+data+struct.pack('>I',len(compact))+compact
            row.update(inputSha256=sha(data),expectedSha256=sha(compact),snapshots=len(checks),hashes=checks)
            snapshots+=len(checks)
    files['cases.bin']=bytes(packed)
    manifest=dict(schemaVersion=1,goal='4.14a',upstreamCommit=PIN,compiler=compiler,flags=flags,profiles=profiles,
        exactNativeAgreement=True,caseCount=len(rows),snapshots=snapshots,stateWords=WORDS,compactSnapshotBytes=WORDS*4+80,
        wadSha256=sha(wad),resources=resources,assetProfiles=asset_profiles,synthetic={n:sha(b) for n,b in synthetic.items()},
        functionMapping=mapping(source),sourceSha256={name:sha((source/name).read_bytes()) for name in ['wi_stuff.c','wi_stuff.h','v_video.c','v_video.h','m_random.c','m_bbox.c','d_player.h','doomdef.h','d_event.h']},
        harnessSha256={name:sha((HERE/name).read_bytes()) for name in ['reference.py','compat.h','host.c']},
        casesSha256=sha(packed),compileWarnings=warnings,
        hostAdaptations=['Original wi_stuff.c included unchanged, original video/bbox/RNG compiled unchanged; platform declarations only',
          'Immutable named WAD buffers borrowed by W_CacheLumpName; Z_Malloc owns lnames only, Z_ChangeTag inert; no native zone trace claim',
          'Audio calls inert permanently; G_WorldDone records completion without loading/progression',
          'Host diagnostic printf inert; visible synthetic markers and oversized candidates are separately declared resource profiles',
          'ASan/UBSan disables only original variable-length patch columnofs array-bounds check; physical ASan remains active; borrowed-buffer leak checks disabled',
          'Only Episode One, player0, modes0/1/3; native signed overflow and invalid pointers excluded'])
    files['native.json']=(json.dumps(manifest,indent=2)+'\n').encode()
    files['cases.json']=(json.dumps(dict(caseCount=len(rows),snapshots=snapshots,stateWords=WORDS,snapshotBytes=WORDS*4+80,cases=rows),indent=2)+'\n').encode()
    files['COPYING.txt']=(ROOT/'test/fixtures/wad/COPYING.txt').read_bytes()
    if args.check:
        for name,b in files.items():assert (FIX/name).read_bytes()==b,'stale '+name
    else:
        for name,b in files.items():p=FIX/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
    print(json.dumps(dict(pass_=True,cases=len(rows),snapshots=snapshots,profiles=3,casesSha256=sha(packed))))
if __name__=='__main__':main()
