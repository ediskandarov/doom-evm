#!/usr/bin/env python3
"""Whole original G_BuildTiccmd, unchanged; explicit keyboard-only host profile."""
import argparse
import importlib.util
import json
import pathlib
import re
import struct
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[3]
HERE = pathlib.Path(__file__).resolve().parent
FIX = ROOT / 'test/fixtures/phase3_input'
spec = importlib.util.spec_from_file_location('phase1', HERE.parent / 'reference.py')
p1 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p1)


def extract():
    text = (p1.SOURCE / 'g_game.c').read_text()
    match = re.search(r'\nvoid\s+G_BuildTiccmd\s*\(', text)
    assert match
    start = match.start() + 1
    end = text.index('{', match.end()) + 1
    depth = 1
    while depth:
        if text[end] == '{':
            depth += 1
        elif text[end] == '}':
            depth -= 1
        end += 1
    body = text[start:end]
    constants = []
    for name in ['forwardmove', 'sidemove', 'angleturn']:
        constants.append(re.search(r'fixed_t\s+' + name + r'\[\d+\]\s*=\s*\{[^}]*\};', text)[0])
    for name in ['MAXPLMOVE', 'SLOWTURNTICS']:
        constants.append(re.search(r'^#define\s+' + name + r'[^\n]*', text, re.M)[0])
    backup = re.search(r'^#define\s+BACKUPTICS[^\n]*', (p1.SOURCE / 'd_net.h').read_text(), re.M)[0]
    constants += [backup, 'short consistancy[MAXPLAYERS][BACKUPTICS];']
    record = {'file': 'g_game.c', 'function': 'G_BuildTiccmd',
              'startLine': text[:start].count('\n') + 1,
              'endLine': text[:end].count('\n') + 1, 'sha256': p1.sha(body.encode())}
    return '\n'.join(constants) + '\n' + body, record


def generate(directory):
    assert p1.invoke(['git', '-C', str(p1.SOURCE), 'rev-parse', 'HEAD']).strip() == p1.UPSTREAM
    assert not p1.invoke(['git', '-C', str(p1.SOURCE), 'diff', '--name-only', 'HEAD'])
    version = p1.invoke(['clang', '--version']).splitlines()
    assert version[0] == p1.VERSION and version[1] == 'Target: ' + p1.TARGET
    original, record = extract()
    generated = (HERE / 'host.c').read_text() + '\n' + original + '\n' + (HERE / 'driver.c').read_text()
    cfile = directory / 'input.c'
    cfile.write_text(generated)
    flags = ['-std=c11', '-fsigned-char', '-fno-strict-aliasing', '-ffp-contract=off', '-fno-fast-math']
    profiles = {'O0': ['-O0'], 'O2': ['-O2'],
                'sanitize': ['-O2', '-fsanitize=address,undefined', '-fno-sanitize-recover=all']}
    outputs = []
    for name, profile in profiles.items():
        binary = directory / name
        p1.invoke(['clang', *flags, *profile, '-I' + str(p1.SOURCE), str(cfile), '-o', str(binary)])
        result = subprocess.run([str(binary)], check=True, capture_output=True)
        assert not result.stderr, result.stderr.decode()
        outputs.append(result.stdout)
    assert outputs[0] == outputs[1] == outputs[2], 'Native profile divergence'
    data = outputs[0]
    count, = struct.unpack_from('>I', data)
    assert count == 41007 and len(data) == 4 + count * 28
    sources = ['g_game.c', 'doomdef.h', 'doomtype.h', 'd_ticcmd.h', 'd_event.h', 'm_fixed.h', 'd_net.h']
    manifest = {'schemaVersion': 1, 'upstreamCommit': p1.UPSTREAM,
                'compiler': p1.VERSION, 'target': p1.TARGET, 'flags': flags,
                'profiles': profiles, 'caseCount': count, 'independentCases': 40960,
                'sequenceCases': count - 40960,
                'scope': 'keyboard masks 0..1023 x requests 0..9 x turnheld 0,4,5,20; persistent sequence; ticdup=1; zero base/chat/consistency/mouse/joystick/special inputs',
                'extraction': record,
                'sources': {f: p1.sha((p1.SOURCE / f).read_bytes()) for f in sources},
                'harnessSha256': {f: p1.sha((HERE / f).read_bytes()) for f in ['reference.py', 'host.c', 'driver.c']},
                'generatedSourceSha256': p1.sha(generated.encode()), 'vectorsSha256': p1.sha(data)}
    return data, (json.dumps(manifest, indent=2) + '\n').encode()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='doom-phase3-input-') as tmp:
        vectors, manifest = generate(pathlib.Path(tmp))
    if not args.check:
        FIX.mkdir(parents=True, exist_ok=True)
    for name, data in [('vectors.bin', vectors), ('manifest.json', manifest)]:
        path = FIX / name
        if args.check:
            assert path.read_bytes() == data, 'Fixture drift ' + name
        else:
            path.write_bytes(data)
    print('PASS original G_BuildTiccmd: 41007 cases, O0/O2/ASan/UBSan exact; upstream unchanged')


if __name__ == '__main__':
    main()
