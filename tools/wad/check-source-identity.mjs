#!/usr/bin/env node
// Verify the production contract's authenticated chunk commitment from the pinned raw bundle.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {canonical} from './wad.ts';
import {validateSchema} from './schema.ts';

const sha = value => createHash('sha256').update(value).digest();
const bundle = JSON.parse(await readFile('artifacts/local/wad/bundle.json', 'utf8'));
validateSchema(bundle, JSON.parse(await readFile('schemas/resource-bundle-v0.schema.json', 'utf8')));
const pinned = JSON.parse(await readFile('test/fixtures/wad/snapshot.json', 'utf8'));
assert.deepEqual(bundle.resourceIdentity, pinned.resourceIdentity);
const manifest = Object.fromEntries(Object.entries(bundle).filter(([key]) => !['resourceIdentity', 'blobFile'].includes(key)));
assert.equal(sha(canonical(manifest)).toString('hex'), bundle.resourceIdentity.bundleSha256);
const blob = await readFile('artifacts/local/wad/resources.bin');
assert.equal(blob.length, bundle.blobByteLength);
assert.equal(sha(blob).toString('hex'), bundle.blobSha256);
const directory = Buffer.alloc(bundle.lumps.length * 16);
let cursor = 0;
for (const [i, lump] of bundle.lumps.entries()) {
  assert.equal(lump.id, i);
  assert.equal(lump.offset, cursor);
  cursor += lump.length;
  assert(cursor <= blob.length);
  Buffer.from(lump.nameHex, 'hex').copy(directory, i * 16);
  directory.writeUInt32LE(lump.offset, i * 16 + 8);
  directory.writeUInt32LE(lump.length, i * 16 + 12);
}
assert.equal(cursor, blob.length);
assert.deepEqual(directory, await readFile('test/fixtures/phase2_data/directory.bin'));
const hashes = [];
for (let offset = 0; offset < blob.length; offset += 16384) {
  hashes.push(sha(Buffer.concat([Buffer.from([0]), blob.subarray(offset, offset + 16384)])));
}
assert.equal(hashes.length, 1755);
assert.equal(directory.length, 3163 * 16);
const source = await readFile('src/evm/WadResources.sol', 'utf8');
for (const [name, digest] of [
  ['DIRECTORY_SHA256', sha(directory)],
  ['CHUNK_HASHES_SHA256', sha(Buffer.concat(hashes))],
]) {
  const constant = source.match(new RegExp(`${name}\\s*=\\s*0x([a-f0-9]{64})`));
  assert(constant, `missing ${name}`);
  assert.equal(constant[1], digest.toString('hex'), `${name} differs from pinned bundle`);
}
for (const key of ['wadSha256', 'bundleSha256', 'paletteSha256']) {
  assert(source.includes('0x' + pinned.resourceIdentity[key]), `contract ${key} differs from pinned identity`);
}
console.log('PASS authenticated resource commitments: pinned bundle, packed directory, all 1,755 STOP-prefixed chunk hashes');
