#!/usr/bin/env python3
"""Extract original gameflow definitions verbatim; compare three native profiles."""
import argparse, hashlib, json, os, pathlib, re, struct, subprocess, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[3]
HERE = pathlib.Path(__file__).resolve().parent
SOURCE = ROOT / 'original/DOOM/linuxdoom-1.10'
FIX = ROOT / 'test/fixtures/phase4_gameflow'
UPSTREAM = 'a77dfb96cb91780ca334d0d4cfd86957558007e0'
FUNCTIONS = ['G_PlayerReborn', 'G_InitPlayer', 'G_PlayerFinishLevel', 'G_DoReborn',
             'G_ExitLevel', 'G_SecretExitLevel', 'G_DoCompleted', 'G_WorldDone',
             'G_DoWorldDone', 'G_DeferedInitNew', 'G_DoNewGame', 'G_InitNew',
             'G_DoLoadLevel', 'G_Ticker']
def sha(b): return hashlib.sha256(b).hexdigest()
def extract(file, name):
    source = (SOURCE / file).read_text()
    match = re.search(r'\nvoid\s+' + name + r'\s*\([^;{]*\)\s*\{', source)
    assert match, name
    start, end, depth = match.start()+1, match.end(), 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    body = source[start:end]
    return body, dict(file=file, function=name, startLine=source[:start].count('\n')+1,
                      endLine=source[:end].count('\n')+1, sha256=sha(body.encode()))
def cases():
    rows = []
    # Normal and secret completion on all nine maps, direct and dispatched.
    for op in (3,4,5):
        for map in range(1,10):
            if op == 5 and map == 8: continue
            for secret in (0,1): rows.append([op,map,secret|2,2,1,0])
    for op in (0,1):
        for skill in (0,1,2,3,4,7):
            for map in (0,1,9,12): rows.append([op,map,4|8,skill,1,0])
    # Shareware's episode clamp, low episode clamp; direct flags retain fast/respawn.
    rows += [[0,1,64,2,9,0],[0,1,0,2,-1,0],[0,1,16|32,2,1,0]]
    for flags in (0,2,4,8,128,256,512,128|4): rows.append([2,1,flags,2,1,0])
    for state in (0,1024,2048):
        for buttons in (0,1,2,128,129,131,133,255):
            for flags in (0,4,8,8|4096): rows.append([6,3,state|flags,2,1,buttons])
    rows += [[6,1,8192,2,1,0],[7,1,128,2,1,2],[7,1,128|4,2,1,2],
             [8,1,0,2,1,0],[9,1,16,2,1,0],[10,1,0,2,1,0],
             [6,1,256|16384,2,1,0]]
    rows += [[0,3,32768,2,1,0],[3,9,32768|2,2,1,0],
             [1,1,16|32,4,1,0],[1,1,256,3,1,0],[3,3,512,2,1,0]]
    return rows

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args()
    assert subprocess.check_output(['git','-C',str(SOURCE),'rev-parse','HEAD'],text=True).strip()==UPSTREAM
    assert not subprocess.check_output(['git','-C',str(SOURCE),'diff','--name-only','HEAD'],text=True)
    compiler=subprocess.check_output(['clang','--version'],text=True).splitlines()[:2]
    assert compiler == ['Apple clang version 17.0.0 (clang-1700.0.13.5)', 'Target: arm64-apple-darwin24.6.0'], compiler
    records=[];bodies=[]
    original=(SOURCE/'g_game.c').read_text()
    for name in ('pars','cpars'):
        bodies.append(re.search(r'int '+name+r'\[[^;]*?\};',original)[0])
    for name in FUNCTIONS:
        body,record=extract('g_game.c',name);bodies.append(body);records.append(record)
    for name in ('P_CalcHeight','P_DeathThink'):
        body,record=extract('p_user.c',name);bodies.append(body);records.append(record)
    body,record=extract('p_tick.c','P_Ticker');records.append(record)
    bodies += ['#define P_Ticker Original_P_Ticker\n'+body+'\n#undef P_Ticker']
    generated=(HERE/'host.c').read_text()+'\n'+'\n'.join(bodies)+'\n'+(HERE/'driver.c').read_text()
    rows=cases();inputs=''.join(' '.join(map(str,r))+'\n' for r in rows).encode()
    flags=['-std=c11','-fsigned-char','-fno-strict-aliasing','-ffp-contract=off','-fno-fast-math']
    profiles={'O0':['-O0'],'O2':['-O2'],'sanitize':['-O2','-fsanitize=address,undefined','-fno-sanitize-recover=all']}
    outputs=[]
    with tempfile.TemporaryDirectory(prefix='doom-gameflow-') as temp:
        path=pathlib.Path(temp);(path/'oracle.c').write_text(generated)
        for name,profile in profiles.items():
            cmd=['clang',*flags,*profile,'-I'+str(SOURCE),'-I'+str(HERE),str(path/'oracle.c'),str(SOURCE/'tables.c'),str(SOURCE/'m_fixed.c'),'-o',str(path/name)]
            compiled=subprocess.run(cmd,capture_output=True,text=True)
            assert compiled.returncode==0,compiled.stderr
            run=subprocess.run([str(path/name)],input=inputs,capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'})
            assert run.returncode==0 and not run.stderr,(name,run.stderr.decode())
            outputs.append(run.stdout)
    assert outputs[0]==outputs[1]==outputs[2], 'native profile divergence'
    data=struct.pack('>I',len(rows))+outputs[0]
    manifest=dict(upstreamCommit=UPSTREAM,compiler=compiler,flags=flags,profiles=profiles,cases=len(rows),
        inputFields=['operation','map','flags','skill','episode','buttons'],
        encoding='big endian uint32: count; each record has word count, six input words, state words, event count and event words',
        scope='Episode One single player; actual G_* plus P_Ticker/P_DeathThink/P_CalcHeight; observing setup/UI/thinker boundaries; no WAD or graphics in this isolated oracle',
        extractions=records,sources={p.name:sha(p.read_bytes()) for p in sorted(SOURCE.glob('*.h'))}|{f:sha((SOURCE/f).read_bytes()) for f in ['g_game.c','p_tick.c','p_user.c','tables.c','m_fixed.c']},
        harness={f:sha((HERE/f).read_bytes()) for f in ['reference.py','host.c','driver.c','snapshot.py']},
        generatedSourceSha256=sha(generated.encode()),vectorsSha256=sha(data))
    for name,value in [('vectors.bin',data),('manifest.json',(json.dumps(manifest,indent=2)+'\n').encode())]:
        if args.check: assert (FIX/name).read_bytes()==value,'stale '+name
        else: (FIX/name).write_bytes(value)
    print(f'PASS {len(rows)} original-C gameflow cases; O0/O2/ASan/UBSan exact')
if __name__=='__main__':main()
