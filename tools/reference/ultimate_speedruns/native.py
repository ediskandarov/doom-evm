#!/usr/bin/env python3
"""Hash-bound authentic classic demos through the preserved original-C oracle."""
import argparse, gzip, hashlib, json, os, re, struct, subprocess, sys, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/reference/speedrun'))
import replay
from replay import sha, save, prove_decoder, build_replay, player_records, delta_encode, state_records


def decode(data):
    assert len(data)>=14
    h=dict(zip(['version','skill','episode','map','deathmatch','respawn','fast','nomonsters','consoleplayer'],data[:9]))
    h['playeringame']=list(data[9:13])
    assert h['version'] in (109,110), 'Only original four-byte short-tic formats supported'
    assert h['episode']==1 and 1<=h['map']<=9 and 0<=h['skill']<=4
    assert [h[k] for k in ['deathmatch','respawn','fast','consoleplayer']]==[0]*4
    assert h['nomonsters'] in (0,1) and h['playeringame']==[1,0,0,0]
    rows=[];pos=13
    while pos<len(data) and data[pos]!=0x80:
        assert pos+4<=len(data), 'Truncated ticcmd'
        b=data[pos:pos+4];f,s,a=struct.unpack('bbb',b[:3])
        rows.append(dict(tic=len(rows)+1,offset=pos,rawHex=b.hex(),forwardmove=f,sidemove=s,angleturn=a*256,buttons=b[3]));pos+=4
    assert pos<len(data) and data[pos]==0x80 and rows
    footer={};checksum=None
    if pos+1<len(data):
        b=data[pos+1:];assert b[:4]==b'PWAD'
        n,d=struct.unpack_from('<II',b,4);assert d+n*16<=len(b)
        for i in range(n):
            at,size,name=struct.unpack_from('<II8s',b,d+i*16);assert at+size<=len(b)
            footer[name.rstrip(b'\0').decode('ascii')]=b[at:at+size].decode('ascii')
        sig=re.search(r'\n0x([0-9a-f]+)-([0-9a-f]{32})',footer.get('FEATURES',''))
        if sig:
            checksum=hashlib.md5(data[:pos+1]+bytes.fromhex(sig[1])[::-1]).hexdigest()==sig[2]
            assert checksum, 'Demo/features checksum mismatch'
    return h,rows,pos,footer,checksum


def main():
    ap=argparse.ArgumentParser();ap.add_argument('directory',type=Path);ap.add_argument('--wad',type=Path,default=ROOT/'artifacts/local/ultimate-doom/DOOM.WAD');a=ap.parse_args();out=a.directory.resolve();out.mkdir(parents=True,exist_ok=True)
    source=json.loads((out/'source.json').read_text());demo=out/'source-download';data=demo.read_bytes()
    assert sha(data)==source['demoSha256'];assert hashlib.md5(a.wad.read_bytes()).hexdigest()=='c4fe9fd920207691a9f493668e0a2083'; assert sha(a.wad.read_bytes())=='6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f'
    assert subprocess.check_output(['git','-C',str(replay.ref.SOURCE),'rev-parse','HEAD'],text=True).strip()==replay.ref.UPSTREAM
    h,rows,marker,footer,checksum=decode(data);assert f"E1M{h['map']}"==source['map']
    span=prove_decoder(out,demo,rows);save(out/'tape.json',dict(header=h,ticRate=35,commands=rows))
    source.update(header=h,totalDemoTics=len(rows),markerOffset=marker,footer=footer,dsdaFooterChecksumVerified=checksum,originalDecoder=span,decoderExact=True,wadSha256='6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f',stockLoaderCompatible=h['version']==110,recordingWadIdentity='Not independently known; compatible pinned IWAD replay must be demonstrated.')
    save(out/'source.json',source);start=time.time();runs=[];baseline=None;failure=None
    for name,opt,sanitize,fill in [('O2','O2',False,None),('O0','O0',False,None),('sanitize','O2',True,None),('sanitize-fill','O2',True,'0xa5')]:
        build=ROOT/'artifacts/local/episode-speedruns'/('native-build-'+('sanitize' if sanitize else name));binary=build/'speedrun'
        assert binary.exists(), 'Build shared original-C reference binaries in this worktree first'
        dest=out/('native-'+name);dest.mkdir(exist_ok=True)
        cmd=[str(binary),str(a.wad.resolve()),str(dest),str(out/'commands.txt'),str(h['map']),str(h['skill']),str(h['nomonsters'])]
        env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'};env.pop('DOOM_ORACLE_ALLOCATION_FILL',None)
        if fill:env['DOOM_ORACLE_ALLOCATION_FILL']=fill
        began=time.perf_counter();p=subprocess.run(cmd,capture_output=True,env=env);elapsed=time.perf_counter()-began
        (dest/'stdout.log').write_bytes(p.stdout);(dest/'stderr.log').write_bytes(p.stderr)
        row=dict(profile=name,command=cmd,elapsedSeconds=elapsed,returncode=p.returncode,stderrSha256=sha(p.stderr));runs.append(row)
        if p.returncode or p.stderr:failure=dict(stage='native-execution',profile=name,returncode=p.returncode,stderr=p.stderr.decode(errors='replace'));break
        current={k:(dest/k).read_bytes() for k in ['ticks.bin','states.bin','diagnostics.bin','events.json','summary.json']}
        # Preserve completed raw commercial-profile state streams losslessly and locally.
        raw=current['states.bin'];packed=gzip.compress(raw,compresslevel=1,mtime=0)
        assert gzip.decompress(packed)==raw
        (dest/'states.bin.gz').write_bytes(packed);(dest/'states.bin').unlink()
        row['statesSha256']=sha(raw);row['compressedStatesSha256']=sha(packed)
        if baseline is None:baseline=current
        elif baseline!=current:
            changed=[k for k in current if current[k]!=baseline[k]]
            failure=dict(stage='native-profile-divergence',profile=name,changedFiles=changed,baselineStatesSha256=sha(baseline['states.bin']),profileStatesSha256=sha(current['states.bin']))
            break
        players=player_records(current['ticks.bin']);exits=re.findall(rb'SPEEDRUN_EXIT (\d+) (\d+) (\d+) (\d+) (-?\d+)',p.stdout)
        row.update(executedTics=len(players)-1,exitEvents=[list(map(int,x)) for x in exits]);print(json.dumps(row),flush=True)
        if len(exits)!=1 or int(exits[0][2])!=6:failure=dict(stage='native-compatibility',reason='Original completion event absent with pinned IWAD',executedTics=len(players)-1);break
    result=dict(pass_=failure is None,startUnix=start,endUnix=time.time(),upstreamCommit=replay.ref.UPSTREAM,demoSha256=sha(data),wadSha256='6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f',settings=h,profiles=runs,exitReached=failure is None,allProfilesExact=failure is None,failure=failure)
    if baseline:
        players=player_records(baseline['ticks.bin']);tics=len(players)-1
        (out/'native-states.delta.bin.gz').write_bytes(gzip.compress(delta_encode(baseline['states.bin']),mtime=0));save(out/'native-state-hashes.json',state_records(baseline['states.bin']));save(out/'native-players.json',players)
        commands=(out/'commands.txt').read_bytes();level=b''.join(commands.splitlines(keepends=True)[:tics]);(out/'level-commands.txt').write_bytes(level)
        result.update(executedTics=tics,leveltime=players[-1]['leveltime'],inGameSeconds=players[-1]['leveltime']/35,finalPlayer=players[-1],statesSha256=sha(baseline['states.bin']),commandsSha256=sha(commands),levelCommandsSha256=sha(level))
    save(out/'native-result.json',result)
    if failure:raise SystemExit(json.dumps(failure))
if __name__=='__main__':main()
