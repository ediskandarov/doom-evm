"""Exercise the installer CLI with local checksum-pinned executable archives."""
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class InstallToolchainTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / 'scripts').mkdir()
        shutil.copyfile(ROOT / 'scripts/install-toolchain.py', self.root / 'scripts/install-toolchain.py')
        self.bin = self.root / '.toolchain/bin'
        self.bin.mkdir(parents=True)
        archive = self.root / 'foundry.tar.gz'
        with tarfile.open(archive, 'w:gz') as tar:
            for name in ('forge', 'anvil', 'cast', 'chisel'):
                data = b'#!/bin/sh\necho "tool version test-1"\n'
                entry = tarfile.TarInfo(name)
                entry.size = len(data)
                tar.addfile(entry, io.BytesIO(data))
        solc = self.root / 'solc'
        solc.write_bytes(b'#!/bin/sh\necho "solc version test-2"\n')
        platform_key = platform.system().lower() + '_' + {
            'aarch64': 'arm64', 'x86_64': 'amd64'
        }.get(platform.machine(), platform.machine())
        self.lock = {'foundry': 'test-1', 'solc': 'test-2', 'platforms': {platform_key: {
            name: {'url': p.as_uri(), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
            for name, p in [('foundry', archive), ('solc', solc)]
        }}}

    def run_installer(self):
        (self.root / 'toolchain.lock.json').write_text(json.dumps(self.lock))
        return subprocess.run([sys.executable, 'scripts/install-toolchain.py'],
                              cwd=self.root, text=True, capture_output=True)

    def test_install_and_repeat_leave_existing_inode_intact(self):
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        old = self.root / 'running-forge'
        os.link(self.bin / 'forge', old)
        old.write_bytes(b'previous executable contents')
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(old.read_bytes(), b'previous executable contents')
        self.assertNotEqual(old.stat().st_ino, (self.bin / 'forge').stat().st_ino)
        self.assertEqual(sorted(p.name for p in self.bin.iterdir()),
                         ['anvil', 'cast', 'chisel', 'forge', 'solc'])
        self.assertTrue(all(os.access(p, os.X_OK) for p in self.bin.iterdir()))

    def test_checksum_failure_preserves_all_existing_binaries(self):
        self.assertEqual(self.run_installer().returncode, 0)
        before = {p.name: (p.read_bytes(), p.stat().st_ino) for p in self.bin.iterdir()}
        next(iter(self.lock['platforms'].values()))['solc']['sha256'] = '0' * 64
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('checksum mismatch', result.stderr)
        self.assertEqual(before, {p.name: (p.read_bytes(), p.stat().st_ino) for p in self.bin.iterdir()})


if __name__ == '__main__':
    unittest.main()
