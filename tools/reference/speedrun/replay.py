#!/usr/bin/env python3
"""Decode the requested original demo and replay through existing original-C harnesses.

No upstream source or accepted fixture is written. Generated sources have only
input/exit observations and an explicit stop at the original completion action.
"""
import argparse
import gzip
import hashlib
import importlib.util
import json
import os
import re
from pathlib import Path
import struct
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE.parent / 'gameplay'))
from build import extract, ref, renderer, PUNITS
from verify import player_records, delta_encode, state_records

DEMO_SHA = '111aec6cabcd2718f0e4fab662980bb68c1831bfc1db12a438fe7e8af2fb5782'
WAD_SHA = '7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d'
SOURCE_URL = 'https://www.speedrun.com/freedoom_phase_1/runs/zg677ovm'
DOWNLOAD_URL = 'https://drive.google.com/uc?export=download&id=1ofW23JwBMdzYd_k3NCz0GdIV5FrlvolK'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def decode(data):
    assert sha(data) == DEMO_SHA, 'Not the requested original recording'
    header = dict(zip(['version', 'skill', 'episode', 'map', 'deathmatch',
                       'respawn', 'fast', 'nomonsters', 'consoleplayer'], data[:9]))
    header['playeringame'] = list(data[9:13])
    assert header == dict(version=109, skill=0, episode=1, map=1, deathmatch=0,
                          respawn=0, fast=0, nomonsters=0, consoleplayer=0,
                          playeringame=[1, 0, 0, 0])
    rows = []
    pos = 13
    while pos < len(data) and data[pos] != 0x80:
        assert pos + 4 <= len(data), 'truncated ticcmd'
        raw = data[pos:pos + 4]
        forward, side, angle = struct.unpack('bbb', raw[:3])
        rows.append(dict(tic=len(rows) + 1, offset=pos, rawHex=raw.hex(),
                         forwardmove=forward, sidemove=side,
                         angleturn=angle * 256, buttons=raw[3]))
        pos += 4
    assert pos < len(data) and data[pos] == 0x80
    assert data[pos + 1:pos + 5] == b'PWAD'
    footer = data[pos + 1:]
    count, directory = struct.unpack_from('<II', footer, 4)
    lumps = {}
    for i in range(count):
        at, size, name = struct.unpack_from('<II8s', footer, directory + i * 16)
        assert at + size <= len(footer)
        lumps[name.rstrip(b'\0').decode('ascii')] = footer[at:at + size].decode('ascii')
    signature = re.search(r'\n0x([0-9a-f]+)-([0-9a-f]{32})', lumps['FEATURES'])
    assert signature
    features = bytes.fromhex(signature[1])[::-1]
    checksum = hashlib.md5(data[:pos + 1] + features).hexdigest()
    assert checksum == signature[2], 'DSDA demo/features checksum mismatch'
    return header, rows, pos, lumps


def prove_decoder(out, demo, rows):
    body, span = extract('g_game.c', 'G_ReadDemoTiccmd')
    source = '''#include <stdio.h>
#include <stdlib.h>
#include "doomtype.h"
#include "d_ticcmd.h"
#define DEMOMARKER 0x80
static byte *demo_p;
void G_CheckDemoStatus(void) { abort(); }
''' + body + '''
int main(int argc, char **argv) {
    if(argc != 2) return 1;
    FILE *f=fopen(argv[1],"rb");if(!f)return 2;
    fseek(f,0,SEEK_END);long size=ftell(f);rewind(f);
    byte *data=malloc(size);if(fread(data,1,size,f)!=(size_t)size)return 3;
    demo_p=data+13;
    while(*demo_p!=DEMOMARKER) {
        if(demo_p+4>data+size)return 4;
        ticcmd_t cmd={0};G_ReadDemoTiccmd(&cmd);
        printf("%d %d %d %u 0\\n",cmd.forwardmove,cmd.sidemove,cmd.angleturn,cmd.buttons);
    }
    return 0;
}
'''
    (out / 'decode-original.c').write_text(source)
    ref.invoke(['clang', *ref.FLAGS, '-fsigned-char', '-I' + str(ref.SOURCE),
                str(out / 'decode-original.c'), '-o', str(out / 'decode-original')])
    actual = subprocess.check_output([str(out / 'decode-original'), str(demo)])
    expected = ''.join(f"{r['forwardmove']} {r['sidemove']} {r['angleturn']} {r['buttons']} 0\n"
                       for r in rows).encode()
    assert actual == expected, 'Python decoder differs from original G_ReadDemoTiccmd'
    (out / 'commands.txt').write_bytes(actual)
    return span


def build_replay(out, opt, sanitize):
    spec = importlib.util.spec_from_file_location('startup_reference', HERE.parent / 'episode_startup/reference.py')
    startup = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(startup)
    _, manifest = startup.build_native(out, opt, sanitize)
    host = (out / 'original-host.c').read_text()
    # Stop after the genuine engine completion request. Remaining tape belongs
    # to intermission; this experiment does not simulate episode progression.
    before = 'if(!feof(commands)) I_Error("malformed commands");'
    assert host.count(before) == 1
    host = host.replace(before, 'if(!feof(commands) && gameaction!=ga_completed) I_Error("malformed commands");')
    before = 'if(render) { R_RenderPlayerView(players);'
    assert host.count(before) == 1
    host = host.replace(before, '''if(gameaction==ga_completed) {
            printf("\\nSPEEDRUN_EXIT %d %d %d %d %d\\n",gametic,leveltime,gameaction,secretexit,speedrun_exit_line);
            break;
        }
        ''' + before)
    host = host.replace('int main(int argc,char **argv) {', 'int speedrun_exit_line=-1;\nint main(int argc,char **argv) {', 1)
    (out / 'original-host.c').write_text(host)
    switch = (out / 'p_switch.c').read_text()
    before = 'case 11:'
    assert switch.count(before) == 1
    switch = switch.replace(before, 'case 11:\n        speedrun_exit_line=(int)(line-lines);')
    (out / 'p_switch.c').write_text('extern int speedrun_exit_line;\n' + switch)
    flags = [f.replace('<BUILD>', str(out)).replace('<HARNESS>', str(HERE.parent)) for f in manifest['flags']]
    binary = out / 'speedrun'
    result = subprocess.run(['clang', *flags, '-I' + str(out),
                             *[str(out / name) for name in renderer.UNITS + PUNITS],
                             str(out / 'game_functions.c'), str(out / 'episode-host.c'),
                             '-Wl,-dead_strip', '-o', str(binary)], capture_output=True, text=True)
    (out / 'speedrun-build.log').write_text(result.stdout + result.stderr)
    assert result.returncode == 0, result.stderr
    manifest['speedrunAdaptations'] = [
        'Generated host stops after original ga_completed, preserving final ticker/snapshot.',
        'Generated p_switch case11 observes line index before original switch/exit logic.',
        'Existing original G_InitNew selects header skill0 E1M1; no controlled scenario or teleport.',
    ]
    manifest['generatedReplayHostSha256'] = sha(host.encode())
    manifest['generatedReplaySwitchSha256'] = sha((out / 'p_switch.c').read_bytes())
    manifest['speedrunBuilderSha256'] = sha(Path(__file__).read_bytes())
    save(out / 'speedrun-build-manifest.json', manifest)
    return binary


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--demo', type=Path, default=ROOT / 'artifacts/local/speedrun-e1m1/source-download')
    ap.add_argument('--wad', type=Path, default=ROOT / 'artifacts/local/speedrun-e1m1/freedoom1.wad')
    ap.add_argument('--output', type=Path, default=ROOT / 'artifacts/local/speedrun-e1m1')
    args = ap.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    assert sha(args.wad.read_bytes()) == WAD_SHA
    assert ref.invoke(['git', '-C', str(ref.SOURCE), 'rev-parse', 'HEAD']).strip() == ref.UPSTREAM
    started = time.time()
    header, rows, marker, footer = decode(args.demo.read_bytes())
    span = prove_decoder(args.output, args.demo, rows)
    save(args.output / 'tape.json', dict(header=header, ticRate=35, commands=rows))
    save(args.output / 'source.json', dict(runUrl=SOURCE_URL, downloadUrl=DOWNLOAD_URL,
         demoSha256=DEMO_SHA, demoBytes=args.demo.stat().st_size, header=header,
         totalDemoTics=len(rows), markerOffset=marker, footer=footer, wadSha256=WAD_SHA,
         dsdaFooterChecksumVerified=True,
         dsdaFooterChecksumScope='MD5(demo bytes including marker + reversed FEATURES bitmap); not an IWAD hash or cryptographic signer identity.',
         originalDecoder=span, decoderExact=True,
         stockLoaderCompatible=False, reason='Demo VERSION109; pinned Linux DOOM VERSION110 rejects it before G_InitNew. Direct original command reader/ticker can be tested without editing VERSION.',
         recordingWadIdentity='Not independently known; footer CMDLINE names freedoom1.wad without a full IWAD checksum.'))
    runs = []
    baseline = None
    for name, opt, sanitize, fill in [('O2', 'O2', False, None), ('O0', 'O0', False, None),
                                      ('sanitize', 'O2', True, None), ('sanitize-fill', 'O2', True, '0xa5')]:
        build = args.output / ('build-' + ('sanitize' if sanitize else name))
        binary = build / 'speedrun'
        if name != 'sanitize-fill':
            binary = build_replay(build, opt, sanitize)
        dest = args.output / ('native-' + name)
        dest.mkdir(exist_ok=True)
        command = [str(binary), str(args.wad), str(dest), str(args.output / 'commands.txt'), '1', '0', '0']
        begin = time.perf_counter()
        env = {**os.environ, 'ASAN_OPTIONS': 'detect_leaks=0'}
        env.pop('DOOM_ORACLE_ALLOCATION_FILL', None)
        if fill is not None:
            env['DOOM_ORACLE_ALLOCATION_FILL'] = fill
        result = subprocess.run(command, capture_output=True, env=env)
        elapsed = time.perf_counter() - begin
        (dest / 'stdout.log').write_bytes(result.stdout)
        (dest / 'stderr.log').write_bytes(result.stderr)
        assert result.returncode == 0 and not result.stderr, (name, result.returncode, result.stderr.decode())
        players = player_records((dest / 'ticks.bin').read_bytes())
        states = (dest / 'states.bin').read_bytes()
        current = {key: (dest / key).read_bytes() for key in ['ticks.bin', 'states.bin', 'diagnostics.bin', 'events.json', 'summary.json']}
        if baseline is None:
            baseline = current
        else:
            assert current == baseline, name + ' native profile divergence'
        exits = re.findall(rb'SPEEDRUN_EXIT (\d+) (\d+) (\d+) (\d+) (-?\d+)', result.stdout)
        assert len(exits) == 1 and int(exits[0][2]) == 6, 'Original completion event missing'
        runs.append(dict(profile=name, command=command, elapsedSeconds=elapsed,
                         executedTics=len(players) - 1, exitEvents=[list(map(int, x)) for x in exits]))
        print(json.dumps(runs[-1]), flush=True)
    players = player_records(baseline['ticks.bin'])
    (args.output / 'native-states.delta.bin.gz').write_bytes(gzip.compress(delta_encode(baseline['states.bin']), mtime=0))
    save(args.output / 'native-state-hashes.json', state_records(baseline['states.bin']))
    save(args.output / 'native-players.json', players)
    actual_tics = len(players) - 1
    command_bytes = (args.output / 'commands.txt').read_bytes()
    (args.output / 'level-commands.txt').write_bytes(b''.join(command_bytes.splitlines(keepends=True)[:actual_tics]))
    save(args.output / 'native-result.json', dict(pass_=bool(runs[0]['exitEvents']),
         startUnix=started, endUnix=time.time(), upstreamCommit=ref.UPSTREAM,
         demoSha256=DEMO_SHA, wadSha256=WAD_SHA, settings=header, profiles=runs,
         exitReached=bool(runs[0]['exitEvents']), executedTics=actual_tics,
         leveltime=players[-1]['leveltime'], inGameSeconds=players[-1]['leveltime'] / 35,
         finalPlayer=players[-1], checkpoints=[players[i] for i in [0, 1, 35, 70, 140, 210, actual_tics] if i < len(players)],
         statesSha256=sha(baseline['states.bin']), commandsSha256=sha(command_bytes),
         levelCommandsSha256=sha((args.output / 'level-commands.txt').read_bytes()),
         allProfilesExact=True, performanceScope='Process elapsed including startup, full per-tic state/diagnostic/zone observation and file IO; excludes compilation. No renders.'))


if __name__ == '__main__':
    main()
