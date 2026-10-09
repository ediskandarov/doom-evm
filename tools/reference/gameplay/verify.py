#!/usr/bin/env python3
"""Reproduce real original DOOM tics, full world observations and live frames."""
import argparse, gzip, json, os, pathlib, struct, subprocess, tempfile
from build import build, HERE, ref
FIXTURES=ref.ROOT/'test/fixtures/gameplay'
WAD=ref.ROOT/'artifacts/local/freedoom/freedoom1.wad'
PLAYER_FIELDS=['leveltime','gametic','prndindex','rndindex','x','y','z','angle','momx','momy','momz','viewz','viewheight','deltaviewheight','bob','floorz','ceilingz','subsector','playerHealth','actorHealth','armorpoints','armortype','readyweapon','pendingweapon','usedown','attackdown','refire','state','tics','flags','ammoClip','ammoShell','ammoCell','ammoMissile','weaponState','weaponTics','weaponX','weaponY','flashState','flashTics','flashX','flashY','thinkerCount','totalKills','totalItems','totalSecrets','killcount','itemcount','secretcount','damagecount','bonuscount','extralight','fixedcolormap']

def scenarios():
    def segment(count,forward=0,side=0,angle=0,buttons=0):return [[forward,side,angle,buttons,0] for _ in range(count)]
    cases={
      'idle':segment(70),
      'movement':segment(60,forward=50)+segment(25,forward=-25)+segment(35,side=24)+segment(35,side=-24)+segment(45,angle=640)+segment(35,forward=25,side=24)+segment(20,buttons=2)+segment(20),
      'combat-arena':segment(5)+segment(140,buttons=1)+segment(30),
      'damage-arena':segment(350),
      'death-arena':segment(350),
      'door-use':segment(5)+segment(20,buttons=2)+segment(350),
      'door-obstructed':segment(5)+segment(20,buttons=2)+segment(350),
      'pistol':segment(5)+segment(90,forward=25,buttons=1)+segment(50,angle=640,buttons=1)+segment(70,buttons=1)+segment(20),
    }
    for rows in cases.values():
        for tic in sorted(set([1,len(rows),len(rows)//2])):rows[tic-1][-1]=1
    return cases

def encoded(value):return (json.dumps(value,indent=2,sort_keys=True)+'\n').encode()
def player_records(data):
    size=4*len(PLAYER_FIELDS);assert len(data)%size==0
    return [dict(zip(PLAYER_FIELDS,struct.unpack('>'+str(len(PLAYER_FIELDS))+'i',data[pos:pos+size]))) for pos in range(0,len(data),size)]
def state_records(data):
    rows=[];pos=0
    while pos<len(data):
        size=struct.unpack_from('>I',data,pos)[0];pos+=4;payload=data[pos:pos+size];assert len(payload)==size and size%4==0
        rows.append(dict(tic=len(rows),bytes=size,sha256=ref.sha(payload)));pos+=size
    assert pos==len(data);return rows

def delta_encode(data):
    out=bytearray();previous=b'';pos=0
    while pos<len(data):
        size=struct.unpack_from('>I',data,pos)[0];pos+=4;payload=data[pos:pos+size];pos+=size
        out.extend(struct.pack('>I',size));out.extend(a^(previous[i] if i<len(previous) else 0) for i,a in enumerate(payload));previous=payload
    assert delta_decode(bytes(out))==data
    return bytes(out)
def delta_decode(data):
    out=bytearray();previous=b'';pos=0
    while pos<len(data):
        size=struct.unpack_from('>I',data,pos)[0];pos+=4;delta=data[pos:pos+size];assert len(delta)==size;pos+=size
        payload=bytes(a^(previous[i] if i<len(previous) else 0) for i,a in enumerate(delta));out.extend(struct.pack('>I',size));out.extend(payload);previous=payload
    assert pos==len(data);return bytes(out)

def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
    identity=json.loads((ref.ROOT/'test/fixtures/wad/snapshot.json').read_text())['resourceIdentity'];assert ref.sha(WAD.read_bytes())==identity['wadSha256']
    outputs={};case_metrics=[]
    with tempfile.TemporaryDirectory(prefix='doom-gameplay-') as temporary:
        temp=pathlib.Path(temporary)
        binaries={profile:build(temp/profile,opt,sanitize) for profile,opt,sanitize in [('O0','O0',False),('O2','O2',False),('asan','O2',True)]}
        native=json.loads((temp/'O2/gameplay-build-manifest.json').read_text())
        # Temporary generated header path is not part of stable compiler identity.
        native['flags']=[flag.replace(str(temp/'O2'),'<BUILD>') for flag in native['flags']]
        outputs['build-manifest.json']=encoded(native)
        for name,rows in scenarios().items():
            commands=''.join(' '.join(map(str,row))+'\n' for row in rows).encode();commandpath=temp/(name+'.txt');commandpath.write_bytes(commands)
            baseline=None
            for profile,fill in [('O0','0'),('O2','0'),('asan','0'),('asan','0xa5')]:
                dest=temp/f'{name}-{profile}-{fill}';dest.mkdir()
                result=subprocess.run([str(binaries[profile]),str(WAD),str(dest),str(commandpath),name if name.endswith('-arena') or name in ['door-use','door-obstructed'] else 'ordinary'],text=True,capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0','DOOM_ORACLE_ALLOCATION_FILL':fill})
                assert result.returncode==0,(name,profile,fill,result.stderr)
                assert not result.stderr,(name,profile,fill,result.stderr)
                current={path.name:path.read_bytes() for path in dest.iterdir()}
                if baseline is None:baseline=current
                else:
                    for key,data in baseline.items():
                        if current[key]!=data:
                            debug=ref.ROOT/'artifacts/local/native-gameplay/mismatch';debug.mkdir(parents=True,exist_ok=True);(debug/(name+'-baseline-'+key)).write_bytes(data);(debug/(name+'-'+profile+'-'+fill+'-'+key)).write_bytes(current[key])
                            raise AssertionError((name,profile,fill,key,'native mismatch'))
            players=player_records(baseline['ticks.bin']);states=state_records(baseline['states.bin']);assert len(players)==len(states)==len(rows)+1
            outputs[name+'/commands.txt']=commands;outputs[name+'/setup.json']=encoded(dict(kind=name if name.endswith('-arena') or name in ['door-use','door-obstructed'] else 'ordinary',notes='Door-use sets original nomonsters before setup for a full unobstructed cycle; door-obstructed retains monsters and proves reversal. Both use original P_TeleportMove to (832,576), facing south at real E1M1 door line55. Arena scenarios spawn one possessed enemy64 units east of actual E1M1 start, original P_CheckPosition validates and P_SetMobjState(seestate) starts AI. Damage gives green armor100; death starts both player health fields at3.' if name.endswith('-arena') or name in ['door-use','door-obstructed'] else 'Unmodified medium-skill single-player E1M1 setup.'));outputs[name+'/ticks.bin']=baseline['ticks.bin'];outputs[name+'/diagnostics.bin']=baseline['diagnostics.bin'];outputs[name+'/states.delta.bin.gz']=gzip.compress(delta_encode(baseline['states.bin']),mtime=0)
            outputs[name+'/state-hashes.json']=encoded(states);outputs[name+'/summary.json']=baseline['summary.json'];outputs[name+'/events.json']=baseline['events.json']
            frames=[]
            for path,data in sorted(baseline.items()):
                if path.startswith('frame-'):
                    assert len(data)==64000;outputs[name+'/'+path]=data;frames.append(dict(tic=int(path[6:12]),sha256=ref.sha(data)))
            events=json.loads(baseline['events.json']);summary=json.loads(baseline['summary.json'])
            if name=='idle':assert all((row['x'],row['y'])==(players[0]['x'],players[0]['y']) for row in players)
            if name=='movement':assert players[-1]['x']!=players[0]['x'] and events.get('P_SlideMove',0)>0 and max(row['itemcount'] for row in players)>0
            if name=='pistol':assert events.get('A_FirePistol',0)>0 and players[-1]['ammoClip']<players[0]['ammoClip']
            if name=='combat-arena':assert events.get('A_Chase',0)>0 and events.get('P_DamageMobj',0)>0 and players[-1]['killcount']==1
            if name=='damage-arena':assert events.get('A_PosAttack',0)>0 and players[-1]['playerHealth']<100 and players[-1]['armorpoints']<100
            if name=='death-arena':assert players[-1]['playerHealth']==0 and events.get('A_PlayerScream',0)>0
            if name=='door-use':assert events.get('P_UseLines',0)==events.get('EV_VerticalDoor',0)==1 and summary['maxDoorCeiling']>summary['initialDoorCeiling'] and summary['finalDoorCeiling']==summary['initialDoorCeiling']
            if name=='door-obstructed':assert events.get('EV_VerticalDoor',0)==1 and summary['doorReversals']>=2 and summary['finalDoorCeiling']>summary['initialDoorCeiling']
            case_metrics.append(dict(name=name,tics=len(rows),frames=frames,finalPlayer=players[-1],events=events))
            print(f'PASS native {name}: {len(rows)} original gameplay tics, {len(frames)} live frames, O0/O2/ASan + allocation-fill exact',flush=True)
    outputs['manifest.json']=encoded(dict(upstreamCommit=ref.UPSTREAM,resourceIdentity=identity,profiles=['O0','O2','O2 ASan/UBSan','O2 ASan/UBSan allocation 0xa5'],playerTraceFields=PLAYER_FIELDS,scope='Original medium-skill single-player E1M1 gameplay and full-screen world view with player psprites. Does not certify Solidity M2/M3. Direct ticcmd inputs bypass keyboard/net/demo/UI layers.',stateEncoding='gzip of length-prefixed bytewise XOR against previous record, zero-extended/truncated to current length; delta_decode in verify.py reconstructs exact states.bin',stateSchema='DSG1; fixed big-endian words, documented observe.h field order; stable monotonic thinker IDs observed at original P_AddThinker; pointer/padding-free.',cases=case_metrics,files={name:ref.sha(data) for name,data in sorted(outputs.items())}))
    if a.check:
        for name,data in outputs.items():assert (FIXTURES/name).read_bytes()==data,'stale gameplay fixture '+name
    else:
        for name,data in outputs.items():path=FIXTURES/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    print('PASS original-C gameplay oracle fixtures')
if __name__=='__main__':main()
