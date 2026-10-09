#!/usr/bin/env python3
"""Keyboard packets -> unchanged original G_BuildTiccmd -> real original E1M1.

Only keyboard host setup and observations are generated here. No command,
gameplay, geometry, or pixel arithmetic is reproduced in Python.
"""
import argparse
import gzip
import importlib.util
import json
import os
import pathlib
import subprocess
import tempfile

from build import build, HERE, ref
from verify import PLAYER_FIELDS, player_records, delta_encode, encoded

spec = importlib.util.spec_from_file_location('keyboard_reference', HERE.parent / 'phase3_input/reference.py')
keyboard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(keyboard)

OUTPUT = ref.ROOT / 'artifacts/local/gameplay-production-native'
BROWSER_OUTPUT = ref.ROOT / 'artifacts/local/gameplay-browser-native'
WAD = ref.ROOT / 'artifacts/local/freedoom/freedoom1.wad'


def packets(profile='production'):
    # Physical held masks, not precomputed ticcmds. Segment lengths exercise
    # initial weapon raise, slow/accelerated turns, release, fire/use holds,
    # strafe modifier, speed and the original ignored digit9 request.
    if profile == 'browser':
        return [dict(tic=i + 1, segment=name, mask=mask, render=True)
                for i, (name, mask) in enumerate([('idle', 0), ('run-forward', 257),
                                                ('strafe-right', 8), ('turn-left', 16),
                                                ('fire', 128), ('use', 64)])]
    segments = [('idle', 20, 0), ('forward', 10, 1), ('run-forward', 10, 257),
                ('backward', 8, 2), ('strafe-left', 8, 4), ('strafe-right', 8, 8),
                ('turn-left', 12, 16), ('turn-right', 12, 32),
                ('run-strafe-modifier', 6, 16 | 256 | 512),
                ('fire', 25, 128), ('use', 3, 64), ('release', 5, 0),
                ('ignored-digit9', 1, 9 << 10), ('pistol-request', 1, 2 << 10)]
    rows = []
    for name, count, mask in segments:
        for _ in range(count):
            rows.append(dict(tic=len(rows) + 1, segment=name, mask=mask, render=False))
    for tic in [1, 20, 40, 69, 100, len(rows)]:
        rows[tic - 1]['render'] = True
    return rows


DRIVER = r'''
int main(void) {
    unsigned mask; int render;
    while (scanf("%u %d", &mask, &render) == 2) {
        if ((mask & ~16383u) || ((mask >> 10) & 15u) > 9u) abort();
        memset(gamekeydown, 0, sizeof(gamekeydown));
        for (unsigned bit=0; bit<10; bit++) gamekeydown[bit+1]=(mask>>bit)&1u;
        unsigned request=(mask>>10)&15u;
        if (request) gamekeydown['0'+request]=true;
        ticcmd_t cmd;
        G_BuildTiccmd(&cmd);
        if (cmd.consistancy || cmd.chatchar) abort();
        printf("%d %d %d %u %d\n",cmd.forwardmove,cmd.sidemove,cmd.angleturn,cmd.buttons,render);
    }
    return feof(stdin) && !ferror(stdout) ? 0 : 1;
}
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--profile', choices=['production', 'browser'], default='production',
                        help='129-tic production cadence or six-tic all-frame browser cadence')
    parser.add_argument('--output', type=pathlib.Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.output is None:
        args.output = BROWSER_OUTPUT if args.profile == 'browser' else OUTPUT
    identity = json.loads((ref.ROOT / 'test/fixtures/wad/snapshot.json').read_text())['resourceIdentity']
    assert ref.sha(WAD.read_bytes()) == identity['wadSha256']
    rows = packets(args.profile)
    mask_input = ''.join(f"{row['mask']} {int(row['render'])}\n" for row in rows)
    outputs = {}
    profiles = [('O0', 'O0', False), ('O2', 'O2', False), ('sanitize', 'O2', True)]
    with tempfile.TemporaryDirectory(prefix='doom-production-native-') as temporary:
        temp = pathlib.Path(temporary)
        original, extraction = keyboard.extract()
        generated = (HERE.parent / 'phase3_input/host.c').read_text() + '\n' + original + '\n' + DRIVER
        source = temp / 'keyboard.c'
        source.write_text(generated)
        commands = None
        builds = {}
        for profile, opt, sanitize in profiles:
            flags = ['-std=c11', '-fsigned-char', '-fno-strict-aliasing', '-ffp-contract=off', '-fno-fast-math', '-' + opt]
            if sanitize:
                flags += ['-fsanitize=address,undefined', '-fno-sanitize-recover=all']
            binary = temp / ('keyboard-' + profile)
            ref.invoke(['clang', *flags, '-I' + str(ref.SOURCE), str(source), '-o', str(binary)])
            result = subprocess.run([str(binary)], input=mask_input.encode(), capture_output=True, check=True)
            assert not result.stderr, result.stderr.decode()
            if commands is None:
                commands = result.stdout
            else:
                assert commands == result.stdout, 'keyboard compiler-profile divergence'
            builds[profile] = build(temp / profile, opt, sanitize)
        decoded = [list(map(int, line.split())) for line in commands.decode().splitlines()]
        assert len(decoded) == len(rows)
        for row, cmd in zip(rows, decoded):
            row['ticcmd'] = dict(zip(['forwardmove', 'sidemove', 'angleturn', 'buttons', 'render'], cmd))
        command_file = temp / 'commands.txt'
        command_file.write_bytes(commands)
        baseline = None
        for profile, fill in [('O0', '0'), ('O2', '0'), ('sanitize', '0'), ('sanitize', '0xa5')]:
            dest = temp / f'run-{profile}-{fill}'
            dest.mkdir()
            result = subprocess.run([str(builds[profile]), str(WAD), str(dest), str(command_file), 'ordinary'],
                                    capture_output=True, env={**os.environ, 'ASAN_OPTIONS': 'detect_leaks=0', 'DOOM_ORACLE_ALLOCATION_FILL': fill})
            assert result.returncode == 0 and not result.stderr, (profile, fill, result.stderr.decode())
            current = {path.name: path.read_bytes() for path in dest.iterdir()}
            if baseline is None:
                baseline = current
            else:
                assert current.keys() == baseline.keys()
                for name, data in baseline.items():
                    assert current[name] == data, f'native divergence {profile} {fill} {name}'
        players = player_records(baseline['ticks.bin'])
        assert len(players) == len(rows) + 1
        # Observed behavior coverage, not a replacement algorithm.
        events = json.loads(baseline['events.json'])
        assert events.get('P_UseLines', 0) == 1
        assert any(p['x'] != players[0]['x'] or p['y'] != players[0]['y'] for p in players)
        if args.profile == 'production':
            assert events.get('A_FirePistol', 0) > 0
            assert players[-1]['ammoClip'] < players[0]['ammoClip']
            turns = [r['ticcmd']['angleturn'] for r in rows if r['segment'] == 'turn-left']
            assert len(set(turns)) == 2, 'held acceleration must actually execute'
        else:
            # The initial weapon is still rising at tic5. This proves a fire
            # packet and unchanged original handling, not an actual shot.
            assert events.get('A_FirePistol', 0) == 0
        outputs['commands.txt'] = commands
        outputs['packets.json'] = encoded(rows)
        outputs['players.json'] = encoded(players)
        outputs['ticks.bin'] = baseline['ticks.bin']
        outputs['states.delta.bin.gz'] = gzip.compress(delta_encode(baseline['states.bin']), mtime=0)
        outputs['diagnostics.bin'] = baseline['diagnostics.bin']
        outputs['events.json'] = baseline['events.json']
        outputs['summary.json'] = baseline['summary.json']
        for name, data in baseline.items():
            if name.startswith('frame-'):
                assert len(data) == 64000
                outputs[name] = data
        native_build = json.loads((temp / 'O2/gameplay-build-manifest.json').read_text())
        native_build['flags'] = [f.replace(str(temp / 'O2'), '<BUILD>') for f in native_build['flags']]
        outputs['build-manifest.json'] = encoded(native_build)
    manifest = dict(schemaVersion=1, kind='original-keyboard-' + args.profile + '-oracle', profile=args.profile, upstreamCommit=ref.UPSTREAM,
                    resourceIdentity=identity, compiler=ref.VERSION, target=ref.TARGET,
                    profiles=['Keyboard O0/O2/ASan/UBSan exact', 'Gameplay O0/O2/ASan/UBSan exact', 'Gameplay ASan/UBSan allocation-fill 0xa5 exact'],
                    scope='Unmodified medium-skill single-player retail E1M1; physical held masks through unchanged original whole G_BuildTiccmd, ticdup1, no mouse/joystick/chat/net/special commands; real original gameplay and selected indexed8 player-weapon frames. No arena setup.',
                    limitations=['Native gameplay retains the previously documented -fwrapv signed-overflow profile and LP64/platform adaptations in build-manifest.json.', 'Only fields exported by production gameStatus/playerView are compared there; full native logical records are retained for diagnostics, not production state input.', 'No portable-C claim for uninitialized or undefined original domains beyond the documented native profile.'] +
                                 (['The six-tic browser stream includes the fire mask while the initial weapon is rising; no actual shot or damage is claimed by that short stream.'] if args.profile == 'browser' else []),
                    tics=len(rows), frames=[dict(tic=r['tic'], sha256=ref.sha(outputs[f"frame-{r['tic']:06d}.bin"])) for r in rows if r['render']],
                    playerTraceFields=PLAYER_FIELDS, extraction=extraction, generatedKeyboardSha256=ref.sha(generated.encode()),
                    sourceHashes={str(path.relative_to(ref.ROOT)): ref.sha(path.read_bytes()) for path in [pathlib.Path(__file__), HERE / 'build.py', HERE / 'host.c', HERE / 'observe.h', HERE / 'diagnostics.h', HERE / 'verify.py', HERE.parent / 'phase3_input/reference.py', HERE.parent / 'phase3_input/host.c']},
                    files={name: ref.sha(data) for name, data in sorted(outputs.items())})
    outputs['manifest.json'] = encoded(manifest)
    for name, data in outputs.items():
        path = args.output / name
        if args.check:
            assert path.read_bytes() == data, 'stale production oracle ' + name
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    print(f'PASS native keyboard {args.profile} oracle: {len(rows)} tics, {len(manifest["frames"])} exact live frames, O0/O2/sanitizers/alternate-fill', flush=True)


if __name__ == '__main__':
    main()
