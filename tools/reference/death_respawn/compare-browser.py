#!/usr/bin/env python3
"""Compare real DOM-command EVM observations and receipt frames with original C."""
import argparse, datetime, hashlib, json, os, subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
ap = argparse.ArgumentParser()
ap.add_argument('--game', choices=['freedoom', 'ultimate', 'doom2'])
ap.add_argument('--report', default='artifacts/local/death-respawn/browser.json')
a = ap.parse_args()
base = ROOT/'artifacts/local/death-respawn'
browser = json.loads((ROOT/a.report).read_text())
sha = lambda b: hashlib.sha256(b).hexdigest()
report = {'pass': False, 'startedUtc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'cases': {},
          'scope': 'Gameplay tics only: established menu adapter owns/freezes ordinary menu packets. Pending-reborn menu load is included. Original IDFA is declared. No host injection; all indexed receipt/Canvas bytes compared.'}
for game in [a.game] if a.game else ['freedoom', 'ultimate', 'doom2']:
    trace = base/'browser-traces'/game
    observations = json.loads((trace/'observations.json').read_text())
    commercial = game == 'doom2'
    wad = ROOT/('artifacts/local/freedoom/freedoom1.wad' if game == 'freedoom' else 'artifacts/local/options/'+('DOOM2.WAD' if commercial else 'DOOM.WAD'))
    report['cases'][game] = {}
    for profile in ['O0', 'O2', 'sanitize']:
        build = base/'native'/('commercial-'+profile if commercial else profile)
        manifest = json.loads((build/'death-build.json').read_text())
        assert manifest['deathBuilderSha256'] == sha((ROOT/'tools/reference/death_respawn/native.py').read_bytes()), 'stale native builder'
        dest = base/'browser-native'/game/profile
        dest.mkdir(parents=True, exist_ok=True)
        cmd = [str(build/'death-respawn'), str(wad), str(dest), str(trace/'commands.txt'), str(observations['map']), str(observations['skill']), '0']
        r = subprocess.run(cmd, capture_output=True, env={**os.environ, 'ASAN_OPTIONS': 'detect_leaks=0'})
        (dest/'stdout.log').write_bytes(r.stdout); (dest/'stderr.log').write_bytes(r.stderr)
        assert r.returncode == 0 and not r.stderr, (game, profile, r.stderr.decode())
        native = [json.loads(s) for s in (dest/'player.jsonl').read_text().splitlines()]
        assert len(native) == len(observations['observations'])
        fields = 0
        for i, (n, e) in enumerate(zip(native, observations['observations']), 1):
            expected = dict(gametic=e['status'][0], leveltime=e['status'][1], health=e['status'][2], armor=e['status'][3],
                            playerstate=e['lifecycle'][0], actorState=e['lifecycle'][1], actorTics=e['lifecycle'][2], viewheight=e['lifecycle'][3],
                            x=e['view'][0], y=e['view'][1], angle=e['view'][3], viewz=e['view'][7], prndindex=e['view'][8],
                            rndindex=e['rndindex'], face=e['face'], ammo=e['inventory'][:4], map=e['episode']['map'], skill=e['episode']['skill'])
            for key, value in expected.items():
                assert n[key] == value, (game, profile, i, e['label'], key, n[key], value)
                fields += 1
        frames = 0
        occurrences = {}
        for i, t in enumerate(observations['tape'], 1):
            if not t['render']:
                continue
            label = game+' '+('Ultra-Violence' if i == 1 else t['label'])
            matches = [f for f in browser['frames'] if f['label'] == label]
            occurrence = occurrences.get(label, 0)
            assert occurrence < len(matches), (label, 'missing browser frame')
            frame = matches[occurrence]
            occurrences[label] = occurrence + 1
            for native_name, browser_name in [('frame', 'indexed'), ('palette', 'rgb')]:
                n = (dest/f'{native_name}-{i:06d}.bin').read_bytes()
                e = (ROOT/frame[browser_name]).read_bytes()
                assert n == e, (game, profile, i, t['label'], native_name, sha(n), sha(e), sum(x!=y for x,y in zip(n,e)))
            frames += 1
        report['cases'][game][profile] = {'gameplayTics': len(native), 'fieldComparisons': fields, 'completeFramesAndPalettes': frames,
                                        'commandsSha256': sha((trace/'commands.txt').read_bytes()), 'nativeManifestSha256': sha((build/'death-build.json').read_bytes()),
                                        'playerRecordsSha256': sha((dest/'player.jsonl').read_bytes()), 'command': cmd}
        print('PASS browser/native', game, profile, len(native), 'tics', frames, 'full frames', flush=True)
report.update({'pass':True}, endedUtc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(base/('browser-native-'+a.game+'.json' if a.game else 'browser-native.json')).write_text(json.dumps(report, indent=2)+'\n')
