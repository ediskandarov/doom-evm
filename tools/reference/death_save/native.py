#!/usr/bin/env python3
"""Fresh finite original-C comparisons; exact EVM restores replay native prefixes.

This does not use the lossy original C save-file semantics as the EVM oracle.
No native state/pixels are imported into EVM. Original files/goldens stay intact.
"""
import argparse, datetime, hashlib, json, os, struct, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / 'artifacts/local/death-save-main'
sha = lambda b: hashlib.sha256(b).hexdigest()
ap = argparse.ArgumentParser()
ap.add_argument('--fixtures', action='store_true')
ap.add_argument('--browser', default='artifacts/local/death-save-main/browser-final.json')
ap.add_argument('--completed-traces', action='store_true', help='Compare completed death traces in a preserved run with a separately verified later reload gate.')
args = ap.parse_args()
report = {'pass': False, 'startedUtc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'scope': __doc__, 'cases': []}

def run(binary, wad, output, commands, map_, skill):
    output.mkdir(parents=True, exist_ok=True)
    command = [str(binary), str(wad), str(output), str(commands), str(map_), str(skill), '0']
    r = subprocess.run(command, capture_output=True, env={**os.environ, 'ASAN_OPTIONS': 'detect_leaks=0'})
    (output/'stdout.log').write_bytes(r.stdout); (output/'stderr.log').write_bytes(r.stderr)
    assert r.returncode == 0 and not r.stderr, (command, r.stderr.decode())
    return command

if args.fixtures:
    for profile in ['O0', 'O2', 'sanitize']:
        for case in ['environment', 'monster']:
            dest = BASE/'native-fixtures'/profile/case
            command = run(BASE/'native/episode-'/profile/'death-respawn',
                          ROOT/'artifacts/local/freedoom/freedoom1.wad', dest,
                          ROOT/f'test/fixtures/death_respawn/{case}-commands.txt', 1, 3)
            raw = (dest/'states.bin').read_bytes(); states = []; offset = 0
            while offset < len(raw):
                n = struct.unpack_from('>I', raw, offset)[0]; offset += 4
                states.append(raw[offset:offset+n]); offset += n
            hashes = []
            for i, state in enumerate(states[1:], 1):
                hashes.append(hashlib.sha256(state).digest())
                for kind in ['frame', 'palette']:
                    p = dest/f'{kind}-{i:06d}.bin'
                    hashes.append(hashlib.sha256(p.read_bytes()).digest() if p.exists() else bytes(32))
            fixture = 'environment-display' if case == 'environment' else case
            golden = (ROOT/f'test/fixtures/death_respawn/{fixture}-hashes.bin').read_bytes()
            assert b''.join(hashes) == golden, (profile, case, 'unchanged native goldens')
            report['cases'].append({'profile': profile, 'case': case, 'worldSnapshots': len(states)-1,
                'framesAndPalettes': len(list(dest.glob('frame-*.bin'))), 'goldenSha256': sha(golden), 'command': command})
            print('PASS unchanged native golden', profile, case, flush=True)
else:
    browser = json.loads((ROOT/args.browser).read_text())
    if not browser['pass']:
        assert args.completed_traces
        assert all(browser['combined'][game]['pass'] for game in ['freedoom', 'ultimate', 'doom2'])
        assert len(browser['rollbacks']) == 18 and all(r['allStorageUnchanged'] and r['noLogs'] for r in browser['rollbacks'])
        assert all(f['allCanvasPixelsExact'] for f in browser['frames'])
        assert browser['frames'][-1]['label'] == 'freedoom reload living saved world'
        assert browser['frames'][-1]['menu']['screen'] == 3
        assert 'AssertionError' in browser['error']
        report['browserRunPass'] = False
        report['separateFailedBoundary'] = 'Harness F3 sent while main menu active; later reload gate must pass separately. Native checks cover completed gameplay traces only.'
    for game in ['freedoom', 'ultimate', 'doom2']:
        commercial = game == 'doom2'
        wad = ROOT/('artifacts/local/freedoom/freedoom1.wad' if game == 'freedoom' else
                   'artifacts/local/options/'+('DOOM2.WAD' if commercial else 'DOOM.WAD'))
        for scenario in ['first', 'loaded-replay', 'rebirth']:
            trace = BASE/'traces'/game/scenario
            observations = json.loads((trace/'observations.json').read_text())
            for profile in ['O0', 'O2', 'sanitize']:
                build = BASE/'native'/('commercial-' if commercial else 'episode-')/profile
                manifest = json.loads((build/'death-build.json').read_text())
                assert manifest['deathBuilderSha256'] == sha((ROOT/'tools/reference/death_respawn/native.py').read_bytes())
                dest = BASE/'native-browser'/game/scenario/profile
                command = run(build/'death-respawn', wad, dest, trace/'commands.txt', observations['map'], observations['skill'])
                rows = [json.loads(s) for s in (dest/'player.jsonl').read_text().splitlines()]
                assert len(rows) == len(observations['observations'])
                fields = frames = 0
                for i, (n, e, tic) in enumerate(zip(rows, observations['observations'], observations['tape']), 1):
                    expected = dict(gametic=e['status'][0], leveltime=e['status'][1], health=e['status'][2], armor=e['status'][3],
                        playerstate=e['lifecycle'][0], actorState=e['lifecycle'][1], actorTics=e['lifecycle'][2], viewheight=e['lifecycle'][3],
                        x=e['view'][0], y=e['view'][1], angle=e['view'][3], viewz=e['view'][7], prndindex=e['view'][8],
                        rndindex=e['rndindex'], face=e['face'], ammo=e['inventory'][:4], map=e['episode']['map'], skill=e['episode']['skill'])
                    for key, value in expected.items():
                        assert n[key] == value, (game, scenario, profile, i, e['label'], key, n[key], value)
                        fields += 1
                    if tic['render']:
                        label = game+' '+tic['label']
                        matches = [f for f in browser['frames'] if f.get('nativeLabel') == label]
                        assert matches, (game, scenario, label, 'missing actual receipt/Canvas frame')
                        frame = matches[0]
                        for native_kind, evm_kind in [('frame', 'indexed'), ('palette', 'rgb')]:
                            a = (dest/f'{native_kind}-{i:06d}.bin').read_bytes()
                            b = (ROOT/frame[evm_kind]).read_bytes()
                            assert a == b, (game, scenario, profile, i, tic['label'], native_kind,
                                sha(a), sha(b), sum(x != y for x, y in zip(a, b)))
                        frames += 1
                report['cases'].append({'game': game, 'scenario': scenario, 'profile': profile, 'gameplayTics': len(rows),
                    'fieldComparisons': fields, 'completeFramesAndPalettes': frames, 'command': command,
                    'commandsSha256': sha((trace/'commands.txt').read_bytes()), 'recordsSha256': sha((dest/'player.jsonl').read_bytes()),
                    'canonicalNativeWorldSha256': sha((dest/'states.bin').read_bytes()),
                    'nativeAllocationEventsSha256': sha((dest/'zone-events.jsonl').read_bytes())})
                print('PASS native/combined', game, scenario, profile, len(rows), frames, flush=True)
report['pass'] = True
report['endedUtc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
(BASE/('native-fixtures.json' if args.fixtures else 'native-browser.json')).write_text(json.dumps(report, indent=2)+'\n')
