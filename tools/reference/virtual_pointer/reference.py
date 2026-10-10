#!/usr/bin/env python3
"""Independently check original-C pointer bytes using safe controlled offsets."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
SRC = ROOT / 'original/DOOM/linuxdoom-1.10'
OUT = ROOT / 'artifacts/local/virtual-pointer/native-pointer'
BASE = 0x0000001000000000
sha = lambda b: hashlib.sha256(b).hexdigest()


def main():
    started = time.time()
    OUT.mkdir(parents=True, exist_ok=True)
    source = (SRC / 'z_zone.c').read_text()
    assert source.count('size = (size + 3) & ~3;') == 1
    adapted = source.replace('size = (size + 3) & ~3;', 'size = (size + 7) & ~7;')
    (OUT / 'zone.c').write_text(adapted)
    report = dict(kind='safe-controlled-native-zone-placement', virtualBase=hex(BASE),
                  startedUTC=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(started)),
                  compiler=subprocess.check_output(['clang', '--version'], text=True),
                  target=subprocess.check_output(['clang', '-dumpmachine'], text=True).strip(),
                  sources={str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in
                           [SRC/'z_zone.c', SRC/'z_zone.h', HERE/'host.c', Path(__file__)]},
                  adaptedZoneSha256=sha(adapted.encode()), runs=[], pass_=False)
    for profile, extra in [('O0',['-O0']), ('O2',['-O2']),
                           ('sanitize',['-O2','-fsanitize=address,undefined',
                                        '-fno-sanitize-recover=all','-fno-omit-frame-pointer'])]:
        binary = OUT/profile
        command = ['clang','-std=gnu11','-fsigned-char','-fwrapv','-fno-strict-aliasing',
                   *extra, '-I'+str(SRC), '-I'+str(OUT), str(HERE/'host.c'), '-o',str(binary)]
        result = subprocess.run(command,capture_output=True)
        (OUT/(profile+'.build.log')).write_bytes(result.stdout+result.stderr)
        assert result.returncode == 0, result.stderr.decode()
        for placement in [0,8,256,4096]:
            began=time.perf_counter()
            result=subprocess.run([str(binary),str(placement)],capture_output=True,
                                  env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'})
            assert result.returncode==0 and not result.stderr, result.stderr.decode()
            name=f'{profile}-{placement}.jsonl'
            (OUT/name).write_bytes(result.stdout)
            rows=[json.loads(line) for line in result.stdout.splitlines()]
            info=rows.pop(0); base=int(info['base'],16)
            assert base==int(info['allocationBase'],16)+placement
            stages={}
            for row in rows: stages.setdefault(row['stage'],[]).append(row)
            for row in rows:
                value=int(row['value'],16)
                assert bytes.fromhex(row['bytes'])==value.to_bytes(8,'little')
                assert value < 2**48
                same_zone=base<=value<base+8192
                if row['field'] in ['next','prev','rover']:
                    assert same_zone
                    target=value-base
                    identities={r['blockOffset'] for r in stages[row['stage']]}
                    assert target in identities and target%8==0
                    virtual=BASE+target
                    row.update(targetOffset=target,virtualPointer=hex(virtual),
                               virtualBytes=virtual.to_bytes(8,'little').hex())
                elif row['blockOffset']==8:
                    assert value==base
                elif value in [0,2]:
                    row['classification']='null' if value==0 else 'unowned-marker'
                else:
                    row['classification']='zone-resident-owner' if same_zone else 'external-owner'
            assert any(r.get('classification')=='external-owner' for r in rows)
            assert any(r.get('classification')=='zone-resident-owner' for r in rows)
            report['runs'].append(dict(profile=profile,placement=placement,command=command,
                binarySha256=sha(binary.read_bytes()),rawFile=name,rawSha256=sha(result.stdout),
                base=hex(base),observations=rows,elapsedSeconds=time.perf_counter()-began))
    # General virtual mapping is independent of the actual process allocation.
    for stage in stages:
        canonical=None
        for run in report['runs']:
            values=[(r['blockOffset'],r['field'],r['virtualBytes']) for r in run['observations']
                    if r['stage']==stage and 'virtualBytes' in r]
            if canonical is None: canonical=values
            assert canonical==values
    report.update(pass_=True,elapsedSeconds=time.time()-started,
        endedUTC=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),
        fidelity='Integer/representation proof with independently controlled safe placement offsets. '
                 'No native allocation at virtualBase; virtual pointer pixels are deterministic extensions.')
    (OUT/'reference.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(dict(pass_=True,runs=len(report['runs']),
                         observations=sum(len(r['observations']) for r in report['runs']),
                         virtualBase=hex(BASE),elapsedSeconds=report['elapsedSeconds'])))


if __name__=='__main__': main()
