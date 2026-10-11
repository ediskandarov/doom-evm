#!/usr/bin/env python3
"""Independent original-C post-tic captures; oracle bytes never enter EVM.

Each process replays the exact no-render prefix then renders its final tic once,
matching SpeedrunVideoProbe's temporary-copy capture chronology. Generated host
changes only observation volume and moving the exit stop after the requested
render, including tic279. Original renderer/gameplay/allocator bodies are kept.
"""
import argparse
import gzip
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

from native import ROOT, build_replay, sha, save
from replay import renderer, PUNITS
import sys
sys.path.insert(0,str(ROOT / "tools/reference/speedrun"))
from verify_video import states


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--tics', default='all')
    ap.add_argument('--source', type=Path, required=True)
    args = ap.parse_args()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    info=json.loads((args.source / 'native-result.json').read_text()); end=info['executedTics']; header=info['settings']
    tics = list(range(1, end+1)) if args.tics == 'all' else list(map(int, args.tics.split(',')))
    assert tics and all(1 <= tic <= end for tic in tics)
    tape = (args.source / 'level-commands.txt').read_text().splitlines()
    native = states(gzip.decompress((args.source / 'native-states.delta.bin.gz').read_bytes()), True)
    wad = Path.home() / 'Downloads/doom-steam/base/doom2/DOOM2.WAD'
    assert sha(wad.read_bytes()) == '10d67824b11025ddd9198e8cfc87ca335ee6e2d3e63af4180fa9b8a471893255'
    report = dict(startedUTC=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                  scope='Independent no-render prefix + one original-C full-screen render per process; no persistent render history',
                  profiles=[], frames=[], pass_=False)
    expected = {}
    started = time.perf_counter()
    for name, opt, sanitize in [('O2', 'O2', False), ('O0', 'O0', False), ('sanitize', 'O2', True)]:
        build = args.output / ('build-' + name)
        binary = build_replay(build, opt, sanitize)
        host = build / 'original-host.c'
        text = host.read_text()
        before = 'snapshot(ticks);world_record(world);diagnostic_record(diagnostics);'
        assert text.count(before) == 1
        text = text.replace(before, 'if(feof(commands)) I_Error("unexpected command EOF");\n' +
                            'if(gametic==atoi(getenv("SPEEDRUN_CAPTURE_TIC"))) {' + before + '}')
        # This is an adapter stop/observation change, outside original functions.
        before = '''if(gameaction==ga_completed) {
            printf("\\nSPEEDRUN_EXIT %d %d %d %d %d\\n",gametic,leveltime,gameaction,secretexit,speedrun_exit_line);
            break;
        }
        '''
        assert text.count(before) == 1
        text = text.replace(before, '')
        before = 'if(!feof(commands) && gameaction!=ga_completed) I_Error("malformed commands");'
        assert text.count(before) == 1
        text = text.replace(before, 'if(gameaction==ga_completed) printf("\\nSPEEDRUN_EXIT %d %d %d %d %d\\n",gametic,leveltime,gameaction,secretexit,speedrun_exit_line);\n' + before)
        host.write_text(text)
        manifest = json.loads((build / 'speedrun-build-manifest.json').read_text())
        manifest['singleCaptureHostSha256'] = sha(text.encode())
        manifest['singleCaptureAdaptations'] = [
            'Observe initial world and target pre-render world only; keep all original gameplay execution.',
            'Stop at command EOF after requested render; observe original completion action also at279.',
            'Each capture starts a fresh64MiB zero-initialized zone; no alternate allocation fill.',
        ]
        flags = [f.replace('<BUILD>', str(build)).replace('<HARNESS>', str(ROOT / 'tools/reference')) for f in manifest['flags']]
        command = ['clang', *flags, '-I' + str(build),
                   *[str(build / n) for n in renderer.UNITS + PUNITS],
                   str(build / 'game_functions.c'), str(build / 'episode-host.c'),
                   '-Wl,-dead_strip', '-o', str(binary)]
        result = subprocess.run(command, capture_output=True)
        (build / 'single-capture-build.log').write_bytes(result.stdout + result.stderr)
        assert result.returncode == 0, result.stderr.decode()
        manifest['singleCaptureCommand'] = command
        save(build / 'single-capture-manifest.json', manifest)
        profile = dict(name=name, captures=[], compiler=subprocess.check_output(['clang', '--version'], text=True).splitlines()[0],
                       buildManifestSha256=sha((build / 'single-capture-manifest.json').read_bytes()))
        report['profiles'].append(profile)
        for tic in tics:
            with tempfile.TemporaryDirectory(prefix='doom-speedrun-frame-') as tmp:
                dest = Path(tmp)
                commands = dest / 'commands.txt'
                rows = [r.rsplit(' ', 1)[0] + (' 1' if i + 1 == tic else ' 0') for i, r in enumerate(tape[:tic])]
                commands.write_text('\n'.join(rows) + '\n')
                invocation = [str(binary), str(wad), str(dest), str(commands), str(header['map']), str(header['skill']), str(header['nomonsters'])]
                began = time.perf_counter()
                env = {k: v for k, v in os.environ.items() if k != 'DOOM_ORACLE_ALLOCATION_FILL'}
                env.update(ASAN_OPTIONS='detect_leaks=0', SPEEDRUN_CAPTURE_TIC=str(tic))
                result = subprocess.run(invocation, capture_output=True, env=env)
                elapsed = time.perf_counter() - began
                assert result.returncode == 0 and not result.stderr, (name, tic, result.stderr.decode())
                observed = states((dest / 'states.bin').read_bytes())
                assert observed == [native[0], native[tic]], (name, tic, 'pre-render native world changed')
                if tic == end:
                    assert f'SPEEDRUN_EXIT {end} {end} 6 {info["profiles"][0]["exitEvents"][0][3]} {info["profiles"][0]["exitEvents"][0][4]}'.encode() in result.stdout
                pixels = (dest / f'frame-{tic:06d}.bin').read_bytes()
                assert len(pixels) == 64000
                digest = sha(pixels)
                if name == 'O2':
                    expected[tic] = digest
                    filename = f'frame-{tic:06d}.indexed8'
                    (args.output / filename).write_bytes(pixels)
                    report['frames'].append(dict(tic=tic, file=filename, indexed8Sha256=digest))
                if digest != expected[tic]:
                    filename = f'{name}-frame-{tic:06d}.indexed8'
                    (args.output / filename).write_bytes(pixels)
                    reference = (args.output / f'frame-{tic:06d}.indexed8').read_bytes()
                    differences = [dict(offset=i, x=i % 320, y=i // 320, O2=a, actual=b)
                                   for i, (a, b) in enumerate(zip(reference, pixels)) if a != b]
                    report.setdefault('divergences', []).append(dict(profile=name, tic=tic, file=filename,
                                                                   sha256=digest, pixels=len(differences), first=differences[:16]))
                profile['captures'].append(dict(tic=tic, sha256=digest, preRenderWorldExact=True,
                                                elapsedSeconds=elapsed, stdoutSha256=sha(result.stdout)))
            save(args.output / 'native-frames.json', report)
            if tic % 25 == 0 or tic == 52 or tic == end:
                print(f'PASS native {name} independent capture tic{tic}: {digest}', flush=True)
    report.update(pass_=not report.get('divergences'), endedUTC=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), elapsedSeconds=time.perf_counter()-started)
    save(args.output / 'native-frames.json', report)


if __name__ == '__main__':
    main()
