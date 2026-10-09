#!/usr/bin/env python3
"""Bounded original E1M1 rocket-world scenario; gold is comparison-only."""
import argparse
import gzip
import json
import os
import pathlib
import re
import struct
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[3]
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'gameplay'))
from build import build, ref, renderer, PUNITS
from verify import delta_encode, player_records, state_records

FIXTURES = ROOT / 'test/fixtures/gameplay_projectile'
WAD = ROOT / 'artifacts/local/freedoom/freedoom1.wad'
ACTOR_FIELDS = 'x y z angle sprite frame floorz ceilingz radius height momx momy momz type tics state flags health movedir movecount target reactiontime threshold player lastlook tracer subsector snext sprev bnext bprev spawnX spawnY spawnAngle spawnType spawnOptions'.split()
SPECIAL_LENGTHS = {2:7, 3:8, 4:9, 5:11, 6:6, 7:6, 8:4, 9:4}


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def actors(data):
    """Read only canonical thinker fields; never raw host memory or transcripts."""
    pos = 0
    rows = []
    while pos < len(data):
        size = struct.unpack_from('>I', data, pos)[0]
        pos += 4
        words = struct.unpack('>' + str(size // 4) + 'i', data[pos:pos+size])
        pos += size
        assert words[0] == 0x44534731
        cursor = 79  # 11 globals, 67 player words, one thinker count.
        current = {}
        for _ in range(words[78]):
            identity, kind, callback, prev, next_ = words[cursor:cursor+5]
            cursor += 5
            if kind == 1:
                current[identity] = dict(zip(ACTOR_FIELDS, words[cursor:cursor+36]))
                current[identity]['callback'] = callback
                cursor += 36
            else:
                cursor += SPECIAL_LENGTHS[kind]
        rows.append(current)
    assert pos == len(data)
    return rows


def compile_profile(out, opt, sanitize):
    build(out, opt, sanitize)
    manifest = json.loads((out / 'gameplay-build-manifest.json').read_text())
    # Entry observations count actual functions. Original function bodies remain unchanged.
    additions = []
    for filename, names in [('p_map.c', ['P_RadiusAttack']), ('p_mobj.c', ['P_ExplodeMissile', 'P_SpawnPlayerMissile']), ('p_inter.c', ['P_KillMobj'])]:
        path = out / filename
        source = path.read_text()
        for name in names:
            match = re.search(r'\n(?:void|mobj_t\s*\*)\s*' + name + r'\s*\([^;{}]*\)\s*\{', source)
            assert match, name
            source = source[:match.end()] + '\n    OracleEvent("' + name + '");\n' + source[match.end():]
            additions.append({'file':filename, 'function':name, 'kind':'observation-only entry count'})
        path.write_text(source)
    for filename,name,enter,leave in [
        ('p_map.c','P_RadiusAttack','ProjectileRadiusObserved(spot,source,damage,1);','ProjectileRadiusObserved(spot,source,damage,0);'),
        ('p_inter.c','P_DamageMobj','ProjectileDamageObserved(target,inflictor,source,damage);','')
    ]:
        path = out/filename
        source = path.read_text()
        match = re.search(r'\nvoid\s+'+name+r'\s*\([^;{}]*\)\s*\{',source)
        assert match,name
        pos = match.end()
        depth = 1
        while depth:
            if source[pos] == '{': depth += 1
            elif source[pos] == '}': depth -= 1
            pos += 1
        source = source[:pos-1]+'\n    '+leave+'\n'+source[pos-1:]
        source = source[:match.end()]+'\n    '+enter+'\n'+source[match.end():]
        path.write_text(source)
        additions.append({'file':filename,'function':name,'kind':'observation-only argument/radius nesting timeline'})
    with (out/'gameplay-observe.h').open('a') as header:
        header.write('\nvoid ProjectileDamageObserved(void *,void *,void *,int);\nvoid ProjectileRadiusObserved(void *,void *,int,int);\n')
    flags = [f.replace('<HARNESS>', str(HERE.parent)) for f in manifest['flags']]
    cmd = ['clang', *flags, '-I'+str(out), *[str(out/name) for name in renderer.UNITS+PUNITS], str(out/'game_functions.c'), str(HERE/'host.c'), '-Wl,-dead_strip', '-o', str(out/'projectile')]
    result = subprocess.run(cmd, text=True, capture_output=True)
    assert result.returncode == 0, result.stderr
    manifest['flags'] = [f.replace(str(out), '<BUILD>') for f in manifest['flags']]
    manifest['projectileEntryObservers'] = additions
    return out/'projectile', manifest


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    identity = json.loads((ROOT/'test/fixtures/wad/snapshot.json').read_text())['resourceIdentity']
    assert ref.sha(WAD.read_bytes()) == identity['wadSha256']
    # Original weapon raising, held fire and subsequent original explosion/removal thinkers.
    rows = [[0,0,0,0,0] for _ in range(35)] + [[0,0,0,1,0] for _ in range(80)] + [[0,0,0,0,0] for _ in range(35)]
    for tic in [1,35,44,49,65,115,150]:
        rows[tic-1][4] = 1
    commands = ''.join(' '.join(map(str,row))+'\n' for row in rows).encode()
    expected = None
    metadata = None
    with tempfile.TemporaryDirectory(prefix='doom-projectile-') as temporary:
        temp = pathlib.Path(temporary)
        commandpath = temp/'commands.txt'
        commandpath.write_bytes(commands)
        binaries = {}
        for profile,opt,san in [('O0','O0',False),('O2','O2',False),('asan','O2',True)]:
            binaries[profile], manifest = compile_profile(temp/profile,opt,san)
            if profile == 'O2':
                metadata = manifest
        for profile,fill in [('O0','0'),('O2','0'),('asan','0'),('asan','0xa5')]:
            dest = temp/(profile+'-'+fill)
            dest.mkdir()
            result = subprocess.run([str(binaries[profile]), str(WAD), str(dest), str(commandpath), 'ordinary'], text=True, capture_output=True, env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0','DOOM_ORACLE_ALLOCATION_FILL':fill})
            assert result.returncode == 0 and not result.stderr, (profile,fill,result.stderr)
            current = {p.name:p.read_bytes() for p in dest.iterdir()}
            if expected is None:
                expected = current
            else:
                assert current == expected, ('projectile four-profile mismatch',profile,fill)
            print(f'PASS original projectile {profile}/{fill}: 150 tics, seven frames and pre/post worlds exact', flush=True)
    trace = actors(expected['states.bin'])
    kinds = json.loads(expected['kinds.json'])
    players = player_records(expected['ticks.bin'])
    events = json.loads(expected['events.json'])
    damage_fields = 'tic kind target inflictor source damage radiusDepth targetHealthBefore targetType inflictorType targetFlags'.split()
    damage = [dict(zip(damage_fields,struct.unpack_from('>11i',expected['damage-timeline.bin'],pos))) for pos in range(0,len(expected['damage-timeline.bin']),44)]
    assert any(row['kind'] == 3 and row['radiusDepth'] > 0 for row in damage), 'actual radius traversal damage required'
    rockets = []
    known = set()
    removed = []
    for tic,current in enumerate(trace):
        rocket_ids = {i for i,a in current.items() if a['type'] == kinds['rocketType']}
        for identity_ in sorted(known - rocket_ids):
            removed.append({'tic':tic,'id':identity_})
        known = rocket_ids
        for identity_ in sorted(rocket_ids):
            rockets.append({'tic':tic,'id':identity_,**{f:current[identity_][f] for f in ['x','y','z','momx','momy','momz','state','tics','flags','health','target','callback']}})
    assert events['A_FireMissile'] > 0 and events['P_SpawnPlayerMissile'] > 0
    assert events['P_ExplodeMissile'] > 0 and events['P_RadiusAttack'] > 0 and events['P_KillMobj'] > 0
    assert rockets and removed and players[-1]['killcount'] >= 1 and players[-1]['ammoMissile'] < 6
    outputs = {name:data for name,data in expected.items() if name not in ['states.bin','post-render.bin']}
    outputs['commands.txt'] = commands
    outputs['states.delta.bin.gz'] = gzip.compress(delta_encode(expected['states.bin']),mtime=0)
    outputs['post-render.bin.gz'] = gzip.compress(expected['post-render.bin'],mtime=0)
    outputs['state-hashes.json'] = encoded(state_records(expected['states.bin']))
    outputs['projectile-evidence.json'] = encoded({'scope':'Original rocket-world observations, not EVM acceptance. Stable original thinker IDs, exact pre-render snapshots and separate post-render snapshots.','tics':150,'rocketObservations':rockets,'removedRocketThinkers':removed,'damageTimeline':damage,'events':events,'finalPlayer':players[-1]})
    outputs['setup.json'] = encoded({'kind':'projectile-arena','notes':'Original P_SetupLevel then actual possessed spawn 64 east, CheckPosition, angle ANG180, target player and original seestate; player angle0, blue armor200, missile owned/ready, pending nochange, six missiles, actual P_SetupPsprites. Host ordinary argv selects no alternate setup branch.'})
    paths = [HERE/'reference.py',HERE/'host.c',HERE.parent/'gameplay/build.py',HERE.parent/'gameplay/host.c',HERE.parent/'gameplay/observe.h',HERE.parent/'gameplay/diagnostics.h']
    outputs['manifest.json'] = encoded({'scope':'Bounded original E1M1 projectile integration; direct ticcmd inputs, controlled original-object setup. No production/EVM acceptance claim.','upstreamCommit':ref.UPSTREAM,'resourceIdentity':identity,'profiles':['O0','O2','ASan+UBSan','ASan+UBSan fill0xa5'],'tics':150,'frames':[{'tic':int(name[6:12]),'sha256':ref.sha(data)} for name,data in sorted(outputs.items()) if name.startswith('frame-')],'native':metadata,'sourceHashes':{str(p.relative_to(ROOT)):ref.sha(p.read_bytes()) for p in paths},'files':{name:ref.sha(data) for name,data in outputs.items()}})
    if args.check:
        assert {p.name for p in FIXTURES.iterdir()} == set(outputs), "unexpected projectile fixture files"
    else:
        # Only generated frame files from this owned scenario can become stale.
        for path in FIXTURES.glob("frame-*.bin"):
            if path.name not in outputs:
                path.unlink()
    for name,data in outputs.items():
        path = FIXTURES/name
        if args.check:
            assert path.read_bytes() == data, 'stale projectile fixture '+name
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(data)
    print('PASS native rocket spawn/radius damage/death/removal evidence')


if __name__ == '__main__':
    main()
