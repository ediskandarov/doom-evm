#!/usr/bin/env python3
"""Run unchanged release packaging with asynchronous cast stdin for large sources."""
import argparse, subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
ap = argparse.ArgumentParser()
ap.add_argument('compiled')
a = ap.parse_args()
helper = """
const keccak = bytes => new Promise((done, fail) => {
 const child = spawn(resolve('.toolchain/bin/cast'), ['keccak']);
 let output='', error='';
 child.stdout.on('data', b=>output+=b);child.stderr.on('data', b=>error+=b);
 child.on('error', fail);child.on('exit', code=>code===0?done(output.trim()):fail(Error(error)));
 child.stdin.on('error', fail);child.stdin.end('0x'+bytes.toString('hex'));
});
"""
for path in ['tools/browser-deployment/package.mjs', 'tools/reference/doom2/package.mjs']:
    source = (ROOT/path).read_text().replace("import {execFileSync} from 'node:child_process';", "import {spawn} from 'node:child_process';")
    source = source.replace("const source=resolve", helper+"\nconst source=resolve") if 'browser-deployment' in path else source.replace("const sha=b=>", helper+"\nconst sha=b=>")
    old = "execFileSync(resolve('.toolchain/bin/cast'),['keccak'],{input:'0x'+bytes.toString('hex'),encoding:'utf8',maxBuffer:1048576}).trim()"
    source = source.replace(old, 'await keccak(bytes)')
    old = "execFileSync(resolve('.toolchain/bin/cast'),['keccak'],{input:'0x'+b.toString('hex'),encoding:'utf8',maxBuffer:1048576}).trim()"
    source = source.replace(old, 'await keccak(b)')
    source = source.replace("`${source}/artifacts/local/freedoom/freedoom1.wad`", "'artifacts/local/freedoom/freedoom1.wad'")
    if 'execFileSync' in source:
        raise SystemExit('Packaging template changed; inspect before adapting')
    subprocess.run(['node', '--input-type=module', '-', a.compiled], input=source, text=True, cwd=ROOT, check=True)
