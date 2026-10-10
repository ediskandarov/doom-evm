#!/usr/bin/env python3
"""Focused native memory audit. Writes only a new audit evidence directory.
No historical fixture generation, production mutation, or running engine required.
"""
import argparse, datetime, hashlib, json, os, pathlib, platform, re, shutil, subprocess, tempfile, time
ROOT=pathlib.Path(__file__).resolve().parents[3]
HERE=pathlib.Path(__file__).resolve().parent
SRC=ROOT/'original/DOOM/linuxdoom-1.10'
SHA=lambda b:hashlib.sha256(b).hexdigest()

def extract(file,name):
    text=(SRC/file).read_text()
    m=re.search(r'\nvoid\s+'+name+r'\s*\([^;{}]*\)\s*\{',text);assert m,name
    end=m.end();depth=1
    while depth:depth+=(text[end]=='{')-(text[end]=='}');end+=1
    body=text[m.start()+1:end]
    return body,dict(file=file,function=name,startLine=text[:m.start()+1].count('\n')+1,endLine=text[:end].count('\n')+1,sha256=SHA(body.encode()))

def invoke(cmd,**kwargs):
    return subprocess.run([str(x) for x in cmd],capture_output=True,**kwargs)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',type=pathlib.Path,default=ROOT/'artifacts/phase4/native-memory-audit');ap.add_argument('--repeats',type=int,default=3);args=ap.parse_args()
    assert args.repeats>=2
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    start=datetime.datetime.now(datetime.timezone.utc).isoformat();timer=time.monotonic()
    compiler=shutil.which('clang');version=invoke([compiler,'--version']).stdout.decode()
    assert version.splitlines()[:2]==['Apple clang version 17.0.0 (clang-1700.0.13.5)','Target: arm64-apple-darwin24.6.0']
    assert invoke(['git','-C',SRC,'rev-parse','HEAD']).stdout.decode().strip()=='a77dfb96cb91780ca334d0d4cfd86957558007e0'
    assert not invoke(['git','-C',SRC,'status','--porcelain']).stdout.strip()
    draw,draw_span=extract('r_draw.c','R_DrawColumn');cache,cache_span=extract('r_data.c','R_DrawColumnInCache')
    original=(SRC/'z_zone.c').read_text();needle='size = (size + 3) & ~3;';assert original.count(needle)==1
    base=['-std=gnu11','-fsigned-char','-fwrapv','-fno-strict-aliasing','-ffp-contract=off','-fno-fast-math']
    profiles=[('O0',['-O0'],8),('O2',['-O2'],8),('asan-ubsan',['-O2','-fsanitize=address,undefined','-fno-sanitize-recover=all','-fno-omit-frame-pointer'],8),('auto-init-zero',['-O2','-ftrivial-auto-var-init=zero'],8),('no-wrapv',['-O2','-fno-wrapv'],8),('original-align4',['-O2'],4),('original-align4-sanitized',['-O2','-fsanitize=address,undefined','-fno-sanitize-recover=all'],4)]
    builds=[];runs=[];checks=[]
    env={k:v for k,v in os.environ.items() if not k.startswith(('ASAN_','UBSAN_','Malloc','DYLD_','DOOM_'))}
    env.update(ASAN_OPTIONS='detect_leaks=0',UBSAN_OPTIONS='halt_on_error=1:print_stacktrace=0')
    with tempfile.TemporaryDirectory(prefix='doom-native-memory-audit-') as td:
        temp=pathlib.Path(td);(temp/'draw.c').write_text(draw);(temp/'cache.c').write_text(cache)
        for label,flags,alignment in profiles:
            zone=original if alignment==4 else original.replace(needle,'size = (size + 7) & ~7;')
            (temp/'zone.c').write_text(zone);binary=temp/label
            cmd=[compiler,*base,*flags,'-I'+str(SRC),'-I'+str(temp),str(HERE/'probe.c'),'-o',str(binary)]
            built=invoke(cmd);assert built.returncode==0,built.stderr.decode()
            (out/(label+'-build.log')).write_bytes(built.stdout+built.stderr)
            builds.append(dict(profile=label,alignment=alignment,command=[str(x) for x in cmd],executableSha256=SHA(binary.read_bytes()),generatedZoneSha256=SHA(zone.encode()),buildLogSha256=SHA(built.stdout+built.stderr)))
            policies=['calloc','malloc-zero','a5','malloc'] if alignment==8 else ['calloc']
            for policy in policies:
                for repetition in range(args.repeats):
                    r=invoke([binary,policy],env=env)
                    name=f'{label}-{policy}-{repetition}'
                    (out/(name+'.jsonl')).write_bytes(r.stdout);(out/(name+'.stderr')).write_bytes(r.stderr)
                    expected_failure=label=='original-align4-sanitized'
                    if expected_failure:
                        assert r.returncode!=0 and b'misaligned address' in r.stderr
                    else:
                        assert r.returncode==0,r.stderr.decode()
                        assert not r.stderr,r.stderr.decode()
                    rows=[json.loads(line) for line in r.stdout.splitlines()] if not expected_failure else []
                    runs.append(dict(profile=label,policy=policy,repetition=repetition,exitCode=r.returncode,expectedFailure=expected_failure,stdout=name+'.jsonl',stderr=name+'.stderr',stdoutSha256=SHA(r.stdout),stderrSha256=SHA(r.stderr),rows=rows))
    # Check relationships without blessing arbitrary pointer or malloc bytes as expected data.
    for r in runs:
        if r['expectedFailure']:continue
        rows=r['rows'];layout=rows[0]
        assert [layout[k] for k in ['int','long','pointer','boolean','memblock','memblockAlign','memzone']]==[4,8,8,4,40,8,56]
        assert layout['offsets']==[0,8,16,20,24,32] and layout['littleEndian'] and layout['plainCharSigned']
        zones={x['stage']:x for x in rows if x['kind']=='zone'}
        assert all(b['allPointersBelow2Pow48'] for z in zones.values() for b in z['blocks'])
        if r['profile']!='original-align4':
            assert [b['offset'] for b in zones['alloc1-17-64']['blocks']]==[56,104,168,272]
            assert [b['size'] for b in zones['alloc1-17-64']['blocks']]==[48,64,104,7920]
            assert [b['offset'] for b in zones['coalesce1-17']['blocks']]==[56,168,272]
            raw=bytes.fromhex(zones['reuse7']['first256Bytes'])
            assert raw[96:103]==bytes([0x44])*7 and raw[144:161]==bytes([0x22])*17
        if r['policy'] in ['calloc','malloc-zero','a5']:
            fill=165 if r['policy']=='a5' else 0
            header=bytes.fromhex(zones['alloc1-17-64']['blocks'][0]['header'])
            assert header[4:8]==bytes([fill])*4
            if r['profile']!='original-align4':
                raw=bytes.fromhex(zones['alloc1-17-64']['first256Bytes']);assert raw[97:104]==bytes([fill])*7
        drawrow=next(x for x in rows if x['kind']=='draw')
        assert [drawrow[k] for k in ['headerByte527','payloadByte559','pixel527','pixel559']]==[0,98,0,98]
        comp=[x for x in rows if x['kind']=='composite']
        assert comp[0]['bytes']=='0a141516'+'00'*12
        assert comp[1]['bytes']=='0a141516'+'a5'*12
    checks=['LP64 little-endian signed-char layout: all successful runs', 'align8 chronology: block offsets56/104/168/272, sizes48/64/104/7920', 'free/coalesce/Clear/reuse preserve historical body0x22 while current payload changes', 'header padding and allocation slack follow explicit initial fill, not optimization/auto-var-init', 'conditional pointer high bytes zero; raw addresses retained, never normalized into expected pointer values', 'original R_DrawColumn crosses logical source512 into header527 and live neighbor559: actual0/98 pixels', 'original R_DrawColumnInCache leaves12 holes; negative-origin source and overlapping writes preserved', 'unadapted align4 UBSan rejects misaligned LP64 memblock in every repetition']
    pointers={}
    for label,_,_ in profiles:
        rr=[r for r in runs if r['profile']==label and not r['expectedFailure']]
        pointers[label]=dict(uniqueZoneBases=len({x['base'] for r in rr for x in r['rows'] if x['kind']=='zone'}),runs=len(rr))
    # Raw rows remain in JSONL; manifest carries replay commands and cryptographic identities.
    for r in runs:r.pop('rows')
    relevant=[SRC/'z_zone.c',SRC/'r_draw.c',SRC/'r_data.c',SRC/'Makefile',SRC/'i_system.c',*sorted(SRC.glob('*.h')),HERE/'run.py',HERE/'probe.c']
    report=dict(schemaVersion=1,status='PASS with expected align4 sanitizer failures',start=start,end=datetime.datetime.now(datetime.timezone.utc).isoformat(),elapsedSeconds=time.monotonic()-timer,baseline=invoke(['git','rev-parse','HEAD']).stdout.decode().strip(),upstreamCommit='a77dfb96cb91780ca334d0d4cfd86957558007e0',compiler=compiler,version=version,platform=platform.platform(),macOS=invoke(['sw_vers']).stdout.decode(),environmentPolicy='Inherited environment minus ASAN_*, UBSAN_*, Malloc*, DYLD_*, DOOM_*; then explicit ASAN_OPTIONS and UBSAN_OPTIONS below. No runtime ASLR changes.',sanitizerEnvironment={k:env[k] for k in ['ASAN_OPTIONS','UBSAN_OPTIONS']},extractions=[draw_span,cache_span],sourceHashes={str(p.relative_to(ROOT)):SHA(p.read_bytes()) for p in relevant},builds=builds,runs=runs,checks=checks,addressDiversity=pointers,scope='Focused original function experiments, not full engine/ISO-definedness proof. Raw malloc and ABI-padding bytes are observations, not portable expected values. The neighboring4096-byte body is explicit synthetic source-written data, not a native texture fixture.',noMemorySanitizer='ASan/UBSan do not track initialization; MSan is unsupported by this Apple arm64 toolchain and was not run.')
    (out/'experiment.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(dict(status=report['status'],builds=len(builds),runs=len(runs),expectedFailures=sum(r['expectedFailure'] for r in runs),elapsedSeconds=report['elapsedSeconds'],addressDiversity=pointers),indent=2))

if __name__=='__main__':main()
