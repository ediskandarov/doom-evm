#!/usr/bin/env python3
"""Observe tic52's disputed pixel through original draw and zone bodies."""
import json
import os
from pathlib import Path
import shutil
import subprocess
from replay import ROOT, renderer, PUNITS, sha, save

base = ROOT / 'artifacts/local/speedrun-tic52'
report = dict(scope='Observation-only generated native clone of established single-capture profile', profiles=[])
hook = r'''
extern byte *screens[];
void SpeedrunSample(byte *source,int index,byte *dest,int x,int yl,int yh,int frac) {
    if(gametic!=52 || dest!=screens[0]+49901)return;
    uintptr_t s=(uintptr_t)source,a=s+(unsigned)index,z=(uintptr_t)mainzone;
    if(s<z || a>=z+(unsigned)mainzone->size)I_Error("sample outside zone");
    memblock_t *sb=NULL,*ab=NULL;
    for(memblock_t *b=mainzone->blocklist.next;b!=&mainzone->blocklist;b=b->next) {
        uintptr_t lo=(uintptr_t)b,hi=lo+(unsigned)b->size;
        if(s>=lo && s<hi)sb=b;if(a>=lo && a<hi)ab=b;
    }
    if(!sb || !ab)I_Error("sample block missing");
    fprintf(stdout,"\nSPEEDRUN_SAMPLE {\"x\":%d,\"y\":155,\"yl\":%d,\"yh\":%d,\"frac\":%d,\"maskedIndex\":%d,\"source\":%d,\"sample\":%d,\"sourceOwner\":%d,\"sampleRelative\":%d,\"value\":%u,\"zoneAddress\":\"%p\",\"sourceBlock\":",x,yl,yh,frac,index,ZoneOffset(source),ZoneOffset((void*)a),owner(sb->user),(int)(a-(uintptr_t)ab),*(byte*)a,(void*)mainzone);
    blockrow(stdout,sb);fputs(",\"sampleBlock\":",stdout);blockrow(stdout,ab);fputs("}\n",stdout);
    ZoneStage("tic52_target");
}
'''
for name in ['O2', 'O0', 'sanitize']:
    build = base / 'native-sample' / ('build-' + name)
    shutil.copytree(base / 'native-frames-recheck' / ('build-' + name), build, dirs_exist_ok=True)
    p = build / 'r_draw.c'
    s = p.read_text()
    needle = '*dest = dc_colormap[dc_source[(frac>>FRACBITS)&127]];'
    assert needle in s
    s = 'void SpeedrunSample(unsigned char*,int,unsigned char*,int,int,int,int);\n' + s.replace(
        needle, 'SpeedrunSample(dc_source,(frac>>FRACBITS)&127,dest,dc_x,dc_yl,dc_yh,frac);\n\t' + needle, 1)
    p.write_text(s)
    p = build / 'z_zone.c'
    p.write_text(p.read_text() + hook)
    m = json.loads((build / 'single-capture-manifest.json').read_text())
    flags = [f.replace('<BUILD>', str(build)).replace('<HARNESS>', str(ROOT / 'tools/reference')) for f in m['flags']]
    binary = build / 'sample'
    cmd = ['clang', *flags, '-I' + str(build), *[str(build / n) for n in renderer.UNITS + PUNITS],
           str(build / 'game_functions.c'), str(build / 'episode-host.c'), '-Wl,-dead_strip', '-o', str(binary)]
    result = subprocess.run(cmd, capture_output=True)
    (build / 'sample-build.log').write_bytes(result.stdout + result.stderr)
    assert result.returncode == 0, result.stderr.decode()
    dest = base / 'native-sample' / name
    dest.mkdir(parents=True, exist_ok=True)
    rows = (ROOT / 'artifacts/speedrun-e1m1/level-commands.txt').read_text().splitlines()[:52]
    rows[-1] = rows[-1].rsplit(' ', 1)[0] + ' 1'
    (dest / 'commands.txt').write_text('\n'.join(rows) + '\n')
    env = {k: v for k, v in os.environ.items() if k != 'DOOM_ORACLE_ALLOCATION_FILL'}
    env.update(ASAN_OPTIONS='detect_leaks=0', SPEEDRUN_CAPTURE_TIC='52')
    cmd = [str(binary), str(ROOT / 'artifacts/local/speedrun-e1m1/freedoom1.wad'), str(dest),
           str(dest / 'commands.txt'), '1', '0', '0']
    result = subprocess.run(cmd, capture_output=True, env=env)
    (dest / 'stdout.log').write_bytes(result.stdout)
    (dest / 'stderr.log').write_bytes(result.stderr)
    assert result.returncode == 0 and not result.stderr, result.stderr.decode()
    samples = [json.loads(line.removeprefix('SPEEDRUN_SAMPLE ')) for line in result.stdout.decode().splitlines()
               if line.startswith('SPEEDRUN_SAMPLE ')]
    assert len(samples) == 1
    record = dict(profile=name, command=cmd, sample=samples[0],
                  frameSha256=sha((dest / 'frame-000052.bin').read_bytes()),
                  sources={n: sha((build / n).read_bytes()) for n in ['r_draw.c', 'z_zone.c', 'original-host.c']})
    report['profiles'].append(record)
    print(json.dumps(record), flush=True)
save(base / 'native-sample' / 'sample.json', report)
