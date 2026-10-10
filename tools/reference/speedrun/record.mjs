// SPDX-License-Identifier: GPL-2.0-only
// One-command authenticated resource preparation -> actual EVM capture -> video encoding.
import {access, copyFile, mkdir, readFile} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {resolve, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
process.chdir(root);
const args = process.argv.slice(2);
if (args.includes('--help')) {
  console.log('node tools/reference/speedrun/record.mjs [--sample-every 5] [--port 18620] [--output-dir artifacts/local/speedrun-e1m1-video] [--encode-only]');
  process.exit(0);
}
const option = (name, fallback) => args.includes(name) ? args[args.indexOf(name) + 1] : fallback;
const output = resolve(option('--output-dir', 'artifacts/local/speedrun-e1m1-video'));
const base = resolve('artifacts/local/speedrun-e1m1');
assert(output.startsWith(resolve('artifacts/local') + '/'), 'Media must stay in ignored artifacts/local');
await mkdir(output, {recursive: true}); await mkdir(base, {recursive: true});
const run = (command, commandArgs) => new Promise((done, fail) => {
  const child = spawn(command, commandArgs, {stdio: 'inherit'});
  child.once('error', fail);
  child.once('exit', code => code === 0 ? done() : fail(Error(command + ' exited ' + code)));
});
if (!args.includes('--encode-only')) {
  await run('ffmpeg', ['-version']);
  await run('ffprobe', ['-version']);
  await run('python3', ['-c', 'from PIL import Image; print("Pillow", Image.__version__)']);
  for (const [source, target] of [['e1m1-easy.lmp', 'source-download'], ['tape.json', 'tape.json'],
      ['native-result.json', 'native-result.json'], ['native-states.delta.bin.gz', 'native-states.delta.bin.gz']]) {
    try {await access(base + '/' + target);} catch {await copyFile('artifacts/speedrun-e1m1/' + source, base + '/' + target);}
  }
  const pin = JSON.parse(await readFile('tools/wad/freedoom.lock.json', 'utf8'));
  try {await access(base + '/freedoom1.wad');} catch {await run('node', ['tools/wad/download.ts', base]);}
  const wad = await readFile(base + '/freedoom1.wad');
  assert.equal(createHash('sha256').update(wad).digest('hex'), pin.wadSha256);
  await run('node', ['tools/wad/pack.ts', base + '/freedoom1.wad', base + '/wad']);
  await run('python3', ['tools/reference/speedrun/verify_evidence.py']);
  await run(resolve('.toolchain/bin/forge'), ['build', 'src/support/SpeedrunVideoProbe.sol', 'src/evm/ResourceStore.sol']);
  await run('node', ['tools/reference/speedrun/evm-video.mjs', '--artifacts', base,
    '--output-prefix', output + '/evm', '--sample-every', option('--sample-every', '5'), '--port', option('--port', '18620')]);
}
await run('python3', ['tools/reference/speedrun/encode_video.py', output]);
await run('python3', ['tools/reference/speedrun/verify_video.py', output]);
console.log('Recorded EVM speedrun: ' + output + '/speedrun-e1m1.mp4');
