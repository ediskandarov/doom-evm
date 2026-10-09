#!/usr/bin/env python3
"""Complete Phase 1 gates, including the unchanged Phase 0 gate runner."""
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/local/phase1-verification'
WAD = 'artifacts/local/freedoom/freedoom1.wad'
BUNDLE = 'artifacts/local/wad'
commands = [
    ('wad-download', ['node', 'tools/wad/download.ts', 'artifacts/local/freedoom'], 180),
    ('wad-pack', ['node', 'tools/wad/pack.ts', WAD, BUNDLE], 60),
    ('wad-tests', ['node', '--test', 'tools/wad/wad.test.ts'], 60),
    ('wad-reproducibility', ['node', 'tools/wad/check.ts', WAD, BUNDLE], 60),
    ('original-c-oracle', ['python3', 'tools/reference/reference.py', '--check', '--wad', WAD], 180),
    ('reference-infrastructure', ['python3', 'tools/reference/test_reference.py'], 180),
    ('native-tables', ['python3', 'tools/tables/generate.py'], 60),
    ('phase1-schemas', ['python3', 'scripts/check-phase1-schemas.py'], 60),
    ('palette-validation', ['node', '--test', 'tools/transport/palette.test.mjs'], 60),
    ('all-phase0-gates', ['python3', 'scripts/verify-phase0.py'], 600),
    ('resource-identity-rejections', ['node', '--test', 'tools/resources/identity.test.mjs'], 60),
    ('resource-placement', ['node', 'tools/resources/benchmark.mjs', '--bundle', BUNDLE+'/bundle.json'], 120),
    ('wad-palette-browser', ['node', 'tools/transport/browser-check.mjs', '--palette', BUNDLE+'/palette.json', '--output-prefix', 'artifacts/local/wad-browser'], 120),
]


def source_hashes():
    result = {}
    for folder in ('src', 'test', 'tools', 'scripts', 'schemas', 'web'):
        for path in sorted((ROOT / folder).rglob('*')):
            if not path.is_file() or '__pycache__' in path.parts or path.name in ('config.local.json', 'palette.local.json'):
                continue
            if path.suffix in ('.sol', '.py', '.sh', '.c', '.h', '.ts', '.mjs', '.json', '.bin', '.html'):
                result[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    for name in ('foundry.toml', 'toolchain.lock.json'):
        result[name] = hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
    return result


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    report = {'scope': 'Phase 1 foundations and all Phase 0 regressions; no Phase 2 renderer',
              'utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
              'git_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'source_sha256': source_hashes(), 'results': [], 'passed': False}
    for name, args, timeout in commands:
        print(f'Running {name}...', flush=True)
        start = time.monotonic()
        log_path = OUT/(name+'.log')
        with log_path.open('w') as log:
            process = subprocess.Popen(args, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            try: code = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGTERM)
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL); process.wait()
                code = 124
        report['results'].append({'gate': name, 'command': args, 'exit_code': code,
                                  'elapsed_seconds': round(time.monotonic()-start, 3),
                                  'log': str(log_path.relative_to(ROOT))})
        report['passed'] = len(report['results']) == len(commands) and all(row['exit_code'] == 0 for row in report['results'])
        if report['passed']:
            assert source_hashes() == report['source_sha256'], 'Sources changed while verification ran'
        (OUT/'summary.json').write_text(json.dumps(report, indent=2)+'\n')
        if code:
            print(log_path.read_text()[-7000:])
            raise SystemExit(f'FAILED: {name}; {log_path}')
        print(f'PASS {name} ({report["results"][-1]["elapsed_seconds"]}s)', flush=True)
    print(f'PASS: all {len(commands)} Phase 1 gates; {OUT / "summary.json"}')


if __name__ == '__main__':
    main()
