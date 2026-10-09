#!/usr/bin/env python3
"""Install checksum-pinned binaries locally, never alter global Foundry/Solidity."""
import hashlib, io, json, os, pathlib, platform, subprocess, tarfile, urllib.request
ROOT = pathlib.Path(__file__).resolve().parents[1]
lock = json.loads((ROOT / 'toolchain.lock.json').read_text())
arch = {'aarch64': 'arm64', 'x86_64': 'amd64'}.get(platform.machine(), platform.machine())
key = platform.system().lower() + '_' + arch
if key not in lock['platforms']:
    raise SystemExit(f'No pinned binary set for {key}; do not substitute a compiler silently.')
bindir = ROOT / '.toolchain' / 'bin'
bindir.mkdir(parents=True, exist_ok=True)
downloads = {}
for tool, spec in lock['platforms'][key].items():
    print(f'Downloading {tool} for {key}', flush=True)
    with urllib.request.urlopen(spec['url'], timeout=120) as response:
        data = response.read()
    if hashlib.sha256(data).hexdigest() != spec['sha256']:
        raise SystemExit(f'{tool}: checksum mismatch')
    downloads[tool] = data
# No installed binary is touched until every download has passed its checksum.
for tool, data in downloads.items():
    if tool == 'foundry':
        with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
            for name in ('forge', 'cast', 'anvil', 'chisel'):
                member = next(m for m in archive.getmembers() if pathlib.PurePosixPath(m.name).name == name and m.isfile())
                (bindir / name).write_bytes(archive.extractfile(member).read())
                (bindir / name).chmod(0o755)
    else:
        (bindir / 'solc').write_bytes(data)
        (bindir / 'solc').chmod(0o755)
for name in ('forge', 'anvil', 'solc'):
    output = subprocess.check_output([str(bindir / name), '--version'], text=True)
    expected = lock['solc'] if name == 'solc' else lock['foundry']
    if expected not in output: raise SystemExit(f'Unexpected {name} version: {output}')
    print(output.strip())
