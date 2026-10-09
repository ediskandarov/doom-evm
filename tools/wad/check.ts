// SPDX-License-Identifier: GPL-2.0-only
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';
import { parseWad, packWad, sha256, canonical, mapLumps, lookup, nameOf } from './wad.ts';
import { validateSchema } from './schema.ts';
const [input, output] = process.argv.slice(2);
if (!input || !output) throw new Error('usage: node tools/wad/check.ts PINNED_FREEDOOM.wad PACKED_DIRECTORY');
const json = (url: URL | string) => JSON.parse(readFileSync(url, 'utf8'));
const pin = json(new URL('./freedoom.lock.json', import.meta.url)), snapshot = json(new URL('../../test/fixtures/wad/snapshot.json', import.meta.url));
const wad = parseWad(readFileSync(input)); assert.equal(sha256(wad.bytes), pin.wadSha256);
const packed = packWad(wad), repeat = packWad(wad);
assert.equal(canonical(packed.bundle), canonical(repeat.bundle)); assert.equal(canonical(packed.palette), canonical(repeat.palette)); assert.ok(packed.blob.equals(repeat.blob));
for (const name of ['bundle', 'palette'] as const) {
  const schema = json(new URL(`../../schemas/${name === 'bundle' ? 'resource-bundle' : name}-v0.schema.json`, import.meta.url));
  validateSchema(packed[name], schema);
  const fromDisk = json(resolve(output, `${name}.json`)); validateSchema(fromDisk, schema); assert.deepEqual(fromDisk, packed[name]);
}
assert.deepEqual(json(resolve(output, 'validation.json')), packed.validation);
assert.ok(readFileSync(resolve(output, 'resources.bin')).equals(packed.blob));
let offset = 0;
for (const [index, entry] of packed.bundle.lumps.entries()) {
  assert.equal(entry.id, index); assert.equal(entry.offset, offset); assert.equal(entry.nameHex, wad.lumps[index].nameHex);
  assert.equal(entry.length, wad.lumps[index].data.length); assert.ok(packed.blob.subarray(offset, offset + entry.length).equals(wad.lumps[index].data)); offset += entry.length;
}
assert.equal(offset, packed.blob.length);
assert.deepEqual(snapshot.resourceIdentity, packed.bundle.resourceIdentity); assert.equal(snapshot.wadByteLength, wad.bytes.length);
assert.equal(snapshot.directoryEntryCount, wad.lumps.length); assert.equal(snapshot.packedByteLength, packed.blob.length); assert.equal(snapshot.packedBlobSha256, sha256(packed.blob));
assert.deepEqual(snapshot.validation, packed.validation); assert.equal(snapshot.schemaVersion, 1); assert.equal(snapshot.source, 'Freedoom v0.13.0 freedoom1.wad'); assert.equal(snapshot.map, 'E1M1');
assert.equal(snapshot.snapshotFile, 'selected-lumps.bin');
assert.deepEqual(Object.keys(snapshot).sort(), ['schemaVersion', 'source', 'map', 'resourceIdentity', 'wadByteLength', 'directoryEntryCount', 'packedByteLength', 'packedBlobSha256', 'snapshotFile', 'snapshotSha256', 'licenseSha256', 'lumps', 'validation'].sort());
const expectedSnapshot = [...Object.values(mapLumps(wad)), lookup(wad, 'PLAYPAL'), lookup(wad, 'COLORMAP'), lookup(wad, 'PNAMES'), lookup(wad, nameOf(lookup(wad, 'PNAMES').data.subarray(4, 12))), wad.lumps.slice(lookup(wad, 'F_START').id + 1, lookup(wad, 'F_END').id).find(lump => lump.data.length === 4096)!];
assert.deepEqual(snapshot.lumps.map((lump: any) => lump.id), expectedSnapshot.map(lump => lump.id));
const raw = readFileSync(new URL('../../test/fixtures/wad/selected-lumps.bin', import.meta.url));
assert.equal(sha256(raw), snapshot.snapshotSha256); offset = 0;
for (const entry of snapshot.lumps) {
  assert.deepEqual(Object.keys(entry).sort(), ['id', 'nameHex', 'originalOffset', 'offset', 'length', 'sha256'].sort());
  assert.ok(Number.isInteger(entry.id) && entry.id >= 0 && entry.id < wad.lumps.length);
  const original = wad.lumps[entry.id];
  assert.equal(entry.nameHex, original.nameHex); assert.equal(entry.originalOffset, original.offset); assert.equal(entry.length, original.data.length);
  assert.equal(entry.offset, offset); assert.equal(entry.sha256, sha256(original.data)); assert.ok(raw.subarray(offset, offset + entry.length).equals(original.data)); offset += entry.length;
}
assert.equal(offset, raw.length);
assert.equal(snapshot.licenseSha256, sha256(readFileSync(new URL('../../test/fixtures/wad/COPYING.txt', import.meta.url))));
assert.deepEqual(json(new URL('../../test/fixtures/wad/palette.json', import.meta.url)), packed.palette);
console.log(JSON.stringify({ result: 'pass', checks: ['pinned WAD identity', 'deterministic repeated packing', 'strict v0 schemas', 'all disk outputs match regeneration', 'every lump byte/name/order preserved', 'contiguous uint32 offsets', 'committed snapshots compared with original source bytes', 'license and palette identities'], directoryEntryCount: wad.lumps.length, snapshotBytes: raw.length, resourceIdentity: packed.bundle.resourceIdentity, validation: packed.validation }, null, 2));
