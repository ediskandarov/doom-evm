#!/usr/bin/env python3
"""Read-only release checks; write only the explicitly selected new report."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import subprocess
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[2]
BASELINE = '1b728fe3f8307a49f71437d5af75a4935df81492'
UPSTREAM = 'a77dfb96cb91780ca334d0d4cfd86957558007e0'
CURRENT = ['README.md', 'PORTING.md', 'docs/README.md', 'docs/ARCHITECTURE.md',
           'docs/COMPATIBILITY.md', 'docs/DEVELOPMENT.md', 'docs/GETTING-STARTED.md',
           'docs/browser-deployment/README.md', 'docs/media/README.md',
           'docs/release/INVENTORY.md', 'docs/release/READINESS.md']
EDITED = {'.gitignore', 'README.md', 'PORTING.md',
          'docs/browser-deployment/README.md', 'scripts/install-toolchain.py'}


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT).decode().strip()


def sha(data):
    return hashlib.sha256(data).hexdigest()


def anchors(path):
    used = Counter()
    result = set()
    for title in re.findall(r'^#{1,6}\s+(.+?)\s*#*$', path.read_text(), re.M):
        slug = re.sub(r'[^\w\- ]', '', title.lower()).replace(' ', '-')
        suffix = used[slug]
        used[slug] += 1
        result.add(slug + (f'-{suffix}' if suffix else ''))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', default=BASELINE)
    parser.add_argument('--compiled', type=Path, help='Directory containing Forge out/')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    # Never replace accepted certificates, fixtures or a prior release check.
    output = args.output.resolve()
    assert output.is_relative_to(ROOT / 'artifacts/local'), 'Use a fresh artifacts/local/ output'
    assert not output.exists(), 'Refusing to overwrite a previous report'
    report = {'baseline': git('rev-parse', args.baseline), 'pass': False}
    preserved = []
    counts = Counter()
    for line in git('ls-tree', '-r', args.baseline).splitlines():
        mode, kind, identity, path = line.split(None, 3)
        counts[path.split('/')[0] if '/' in path else '(root)'] += 1
        if kind != 'blob' or path in EDITED:
            continue
        data = (ROOT / path).read_bytes()
        assert hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest() == identity, path
        preserved.append(f'{path}\0{sha(data)}')
    report['inventory'] = dict(sorted(counts.items()))
    report['preservation'] = {'unchangedBaselineFiles': len(preserved),
                              'pathAndSHA256Digest': sha('\n'.join(preserved).encode()),
                              'allowedEdits': sorted(EDITED)}
    assert git('ls-tree', 'HEAD', 'original/DOOM').split()[2] == UPSTREAM
    assert git('-C', 'original/DOOM', 'rev-parse', 'HEAD') == UPSTREAM
    assert not git('-C', 'original/DOOM', 'status', '--porcelain')
    report['upstream'] = UPSTREAM
    tracked = git('ls-files').splitlines()
    assert not [p for p in tracked if Path(p).suffix.lower() in {'.wad', '.mp4'}], 'Tracked IWAD/video'
    report['trackedIWADsAndMP4s'] = 0
    packages = []
    for pinfile, contract in [('web/install-pins.mjs', 'Doom'), ('web/doom2-pins.mjs', 'Doom2')]:
        pins = json.loads((ROOT / pinfile).read_text().split('export default ', 1)[1].strip().removesuffix(';'))
        for path, expected in pins['sources'].items():
            assert sha((ROOT / path).read_bytes()) == expected, path
        for name, entry in pins['artifacts'].items():
            payload = (ROOT / 'web' / entry['url'].lstrip('/')).read_bytes()
            assert sha(payload) == entry['sha256'], entry['url']
            if args.compiled:
                compiled_name = contract if name == 'Doom' else name
                artifact = json.loads((args.compiled / 'out' / (compiled_name + '.sol') / (compiled_name + '.json')).read_text())
                expected = {'bytecode': artifact['bytecode']['object'],
                            'runtime': artifact['deployedBytecode']['object'],
                            'methods': artifact['methodIdentifiers']}
                if 'immutableReferences' in artifact['deployedBytecode']:
                    expected['immutableReferences'] = artifact['deployedBytecode']['immutableReferences']
                assert json.loads(payload) == expected, 'Packaged/compiled artifact mismatch'
                meta = artifact['metadata']
                if isinstance(meta, str):
                    meta = json.loads(meta)
                settings = meta['settings']
                assert meta['compiler']['version'].startswith('0.8.37+commit.f401782d')
                assert settings['viaIR'] and settings['optimizer'] == {'enabled': True, 'runs': 200}
                assert settings['evmVersion'] == 'cancun'
        packages.append({'pins': pinfile, 'sourceCount': len(pins['sources']),
                         'artifacts': pins['artifacts'], 'compiledCompared': bool(args.compiled)})
    report['packages'] = packages
    link_count = 0
    checked_docs = sorted({*ROOT.glob('*.md'), *ROOT.glob('docs/**/*.md'),
                           *ROOT.glob('tools/**/*.md'), *ROOT.glob('test/**/*.md'),
                           *[p for p in ROOT.glob('artifacts/**/*.md') if 'local' not in p.parts]})
    for path in checked_docs:
        text = path.read_text()
        links = re.findall(r'\]\(([^\s)]+)(?:\s+"[^"]*")?\)', text)
        links += re.findall(r'(?:href|src)="([^"]+)"', text)
        for target in links:
            parts = urlsplit(target)
            if parts.scheme or parts.netloc:
                continue
            resolved = (path.parent / unquote(parts.path)).resolve() if parts.path else path
            assert resolved.exists(), f'{path.relative_to(ROOT)}: missing {target}'
            if str(path.relative_to(ROOT)) in CURRENT and parts.fragment and resolved.suffix == '.md':
                assert unquote(parts.fragment) in anchors(resolved), f'{path.relative_to(ROOT)}: missing anchor {target}'
            link_count += 1
    report['documentation'] = {'filesChecked': len(checked_docs), 'localLinksChecked': link_count,
                               'currentDocumentAnchorsChecked': True,
                               'externalLinks': 'Not covered by this local checker'}
    report['pass'] = True
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
