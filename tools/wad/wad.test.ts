// SPDX-License-Identifier: GPL-2.0-only
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parseWad, lookup, mapLumps, records, validateMap, validateResources, validatePatch, canonical, sha256 } from './wad.ts';
function name(value: string) { const b = Buffer.alloc(8); b.write(value); return b; }
function words(values: number[]) { const b = Buffer.alloc(values.length * 2); values.forEach((v, i) => b.writeUInt16LE(v & 65535, i * 2)); return b; }
function i32(value: number) { const b = Buffer.alloc(4); b.writeInt32LE(value); return b; }
function fixture() {
  const patch = Buffer.concat([words([1, 1, 0, 0]), i32(12), Buffer.from([0, 1, 0, 42, 0, 255])]);
  const texture = Buffer.concat([i32(1), i32(8), name('WALL'), i32(0), words([1, 1]), i32(0), words([1, 0, 0, 0, 0, 0])]);
  return [
    ['E1M1', Buffer.alloc(0)], ['THINGS', words([0, 0, 0, 1, 7])],
    ['LINEDEFS', words([0, 1, 0, 0, 0, 0, -1])],
    ['SIDEDEFS', Buffer.concat([words([0, 0]), name('-'), name('-'), name('WALL'), words([0])])],
    ['VERTEXES', words([0, 0, 128, 0])], ['SEGS', words([0, 1, 0, 0, 0, 0])], ['SSECTORS', words([1, 0])],
    ['NODES', Buffer.concat([words(Array(12).fill(0)), words([0x8000, 0x8000])])],
    ['SECTORS', Buffer.concat([words([0, 128]), name('FLAT'), name('FLAT'), words([160, 0, 0])])],
    ['REJECT', Buffer.alloc(1)], ['BLOCKMAP', words([0, 0, 1, 1, 5, 0, 0, -1])],
    ['PLAYPAL', Buffer.alloc(14 * 768)], ['COLORMAP', Buffer.alloc(34 * 256)], ['PNAMES', Buffer.concat([i32(1), name('PATCH')])],
    ['TEXTURE1', texture], ['PATCH', patch], ['F_START', Buffer.alloc(0)], ['FLAT', Buffer.alloc(4096)], ['F_END', Buffer.alloc(0)],
  ] as [string, Buffer][];
}
function serialize(entries: [string, Buffer][]) {
  const data = Buffer.concat(entries.map(e => e[1])), header = Buffer.concat([Buffer.from('IWAD'), i32(entries.length), i32(12 + data.length)]);
  let offset = 12;
  const directory = Buffer.concat(entries.map(([key, val]) => { const row = Buffer.concat([i32(offset), i32(val.length), name(key)]); offset += val.length; return row; }));
  return Buffer.concat([header, data, directory]);
}
function mutate(lumpName: string, operation: (b: Buffer) => void | Buffer) {
  const entries = fixture(), entry = entries.find(e => e[0] === lumpName)!; const result = operation(entry[1]); if (result) entry[1] = result;
  return parseWad(serialize(entries));
}
test('complete minimal classic IWAD validates each resource family', () => {
  assert.equal(validateResources(parseWad(serialize(fixture()))).textureCount, 1);
});
test('directory last-match uses original strncpy padding; raw names, duplicates and markers preserved', () => {
  const raw = serialize([['DUP', Buffer.from([1])], ['MARKER', Buffer.alloc(0)], ['DUP', Buffer.from([2])], ['ABCDEFGH', Buffer.from([3])], ['lower', Buffer.from([4])]]);
  const wad = parseWad(raw); assert.equal(lookup(wad, 'dup').data[0], 2); assert.equal(lookup(wad, 'ABCDEFGH').data[0], 3);
  assert.equal(wad.lumps[1].data.length, 0); assert.equal(wad.lumps.length, 5); assert.throws(() => lookup(wad, 'lower'), /missing/);
  const dirty = parseWad(serialize([['DUP', Buffer.from([9])]])); dirty.lumps[0].nameHex = '4455500078000000'; assert.equal(lookup(dirty, 'DUP').data[0], 9); assert.equal(dirty.lumps[0].nameHex, '4455500078000000');
});
test('rejects invalid WAD envelope without allocating from hostile counts', () => {
  for (const [offset, value] of [[4, -1], [4, 2147483647], [8, -1], [8, 2147483647]]) { const b = serialize(fixture()); b.writeInt32LE(value, offset); assert.throws(() => parseWad(b)); }
  assert.throws(() => parseWad(Buffer.alloc(11))); const b = serialize(fixture()); b.write('NOPE'); assert.throws(() => parseWad(b), /magic/);
  for (const [field, value] of [[0, -1], [4, -1], [0, 2147483647], [4, 2147483647]]) { const b = serialize(fixture()); b.writeInt32LE(value, b.readInt32LE(8) + 16 + field); assert.throws(() => parseWad(b), /bounds/); }
});
const mutations: [string, string, (b: Buffer) => void | Buffer, RegExp][] = [
  ['vertex record remainder', 'VERTEXES', b => b.subarray(0, b.length - 1), /record length/],
  ['signed vertex reference', 'LINEDEFS', b => { b.writeInt16LE(-1, 0); }, /VERTEXES index/],
  ['oversized side reference', 'LINEDEFS', b => { b.writeInt16LE(2, 10); }, /SIDEDEFS index/],
  ['invalid negative side', 'LINEDEFS', b => { b.writeInt16LE(-2, 12); }, /SIDEDEFS index/],
  ['two-sided absent back', 'LINEDEFS', b => { b.writeInt16LE(4, 4); }, /two-sided/],
  ['missing front side', 'LINEDEFS', b => { b.writeInt16LE(-1, 10); }, /front side/],
  ['side sector index', 'SIDEDEFS', b => { b.writeInt16LE(-1, 28); }, /SECTORS index/],
  ['seg vertex index', 'SEGS', b => { b.writeInt16LE(4, 0); }, /VERTEXES index/],
  ['seg line index', 'SEGS', b => { b.writeInt16LE(-1, 6); }, /LINEDEFS index/],
  ['seg side domain', 'SEGS', b => { b.writeInt16LE(2, 8); }, /invalid side/],
  ['seg absent back', 'SEGS', b => { b.writeInt16LE(1, 8); }, /SIDEDEFS index/],
  ['subsector span', 'SSECTORS', b => { b.writeInt16LE(2, 0); }, /seg span/],
  ['negative firstseg', 'SSECTORS', b => { b.writeInt16LE(-1, 2); }, /seg span/],
  ['empty subsector', 'SSECTORS', b => { b.writeInt16LE(0, 0); }, /seg span/],
  ['node child index', 'NODES', b => { b.writeUInt16LE(1, 24); }, /NODES index/],
  ['leaf child index', 'NODES', b => { b.writeUInt16LE(0x8001, 24); }, /SSECTORS index/],
  ['BSP cycle', 'NODES', b => { b.writeUInt16LE(0, 24); }, /BSP cycle/],
  ['REJECT matrix', 'REJECT', () => Buffer.alloc(0), /truncated bit matrix/],
  ['BLOCKMAP dimensions', 'BLOCKMAP', b => { b.writeInt16LE(-1, 4); }, /dimensions/],
  ['BLOCKMAP negative offset', 'BLOCKMAP', b => { b.writeInt16LE(-1, 8); }, /list offset/],
  ['BLOCKMAP header offset', 'BLOCKMAP', b => { b.writeInt16LE(0, 8); }, /list offset/],
  ['BLOCKMAP initial zero', 'BLOCKMAP', b => { b.writeInt16LE(1, 10); }, /start with zero/],
  ['BLOCKMAP linedef', 'BLOCKMAP', b => { b.writeInt16LE(3, 12); }, /LINEDEFS index/],
  ['BLOCKMAP terminator', 'BLOCKMAP', b => { b.writeInt16LE(0, 14); }, /unterminated/],
  ['PLAYPAL stride', 'PLAYPAL', b => b.subarray(1), /palette length/],
  ['COLORMAP count', 'COLORMAP', () => Buffer.alloc(256), /table length/],
  ['PNAMES count', 'PNAMES', b => { b.writeInt32LE(-1); }, /PNAMES: invalid count/],
  ['PNAMES missing patch', 'PNAMES', b => { b.write('GONE', 4); }, /missing lump GONE/],
  ['TEXTURE count', 'TEXTURE1', b => { b.writeInt32LE(-1); }, /negative count/],
  ['TEXTURE offset', 'TEXTURE1', b => { b.writeInt32LE(4, 4); }, /definition offset/],
  ['TEXTURE dimensions', 'TEXTURE1', b => { b.writeInt16LE(0, 20); }, /dimensions/],
  ['TEXTURE patch count', 'TEXTURE1', b => { b.writeInt16LE(9, 28); }, /out of bounds/],
  ['TEXTURE patch index', 'TEXTURE1', b => { b.writeInt16LE(-1, 34); }, /PNAMES index/],
  ['patch column offset', 'PATCH', b => { b.writeInt32LE(-1, 8); }, /column offset/],
  ['patch length', 'PATCH', b => { b[13] = 255; }, /post pixels/],
  ['patch terminator', 'PATCH', b => b.subarray(0, b.length - 1), /patch post/],
  ['flat length', 'FLAT', b => b.subarray(1), /flat length/],
  ['missing sector flat', 'SECTORS', b => { b.write('GONE', 4); }, /missing lump GONE/],
  ['missing sidedef texture', 'SIDEDEFS', b => { b.write('GONE', 20); }, /missing texture/],
];
for (const [label, lump, edit, error] of mutations) test(`rejects ${label}`, () => assert.throws(() => validateResources(mutate(lump, edit)), error));
test('rejects extended map layouts and retains classic zero-node map', () => {
  const entries = fixture(); entries[1][0] = 'BEHAVIOR'; assert.throws(() => mapLumps(parseWad(serialize(entries))), /layout/);
  assert.equal(validateMap(mutate('NODES', () => Buffer.alloc(0))).count.NODES, 0);
});
test('snapshot raw bytes and record signedness retain upstream disk ABI', () => {
  const snapshot = JSON.parse(readFileSync(new URL('../../test/fixtures/wad/snapshot.json', import.meta.url), 'utf8'));
  const blob = readFileSync(new URL('../../test/fixtures/wad/selected-lumps.bin', import.meta.url)); assert.equal(sha256(blob), snapshot.snapshotSha256);
  let offset = 0; for (const lump of snapshot.lumps) { assert.equal(lump.offset, offset); assert.equal(sha256(blob.subarray(offset, offset + lump.length)), lump.sha256); offset += lump.length; } assert.equal(offset, blob.length);
  const wad = mutate('VERTEXES', () => words([-32768, 32767, -1, 0])); assert.deepEqual(records(lookup(wad, 'VERTEXES'))[0], { x: -32768, y: 32767 });
  assert.equal(records(lookup(parseWad(serialize(fixture())), 'LINEDEFS'))[0].sidenum1, -1);
  assert.equal(records(lookup(parseWad(serialize(fixture())), 'NODES'))[0].child0, 32768);
});
test('canonical manifest is recursive, compact ASCII JSON with sorted keys', () => assert.equal(canonical({ z: [{ b: 'é', a: 1 }], a: 0 }), '{"a":0,"z":[{"a":1,"b":"\\u00e9"}]}'));

test('v0 palette schema rejects unknown fields, missing identity, malformed hex and booleans', async () => {
  const { validateSchema } = await import('./schema.ts');
  const schema = JSON.parse(readFileSync(new URL('../../schemas/palette-v0.schema.json', import.meta.url), 'utf8'));
  const original = JSON.parse(readFileSync(new URL('../../test/fixtures/wad/palette.json', import.meta.url), 'utf8'));
  validateSchema(original, schema);
  for (const edit of [(x: any) => { x.extra = 1; }, (x: any) => { delete x.resourceIdentity; }, (x: any) => { x.rgbHex = 'ff'; }, (x: any) => { x.resourceIdentity.paletteVariant = true; }, (x: any) => { x.resourceIdentity.extra = 1; }, (x: any) => { x.resourceIdentity.paletteVariant = 256; }]) {
    const doc = structuredClone(original); edit(doc); assert.throws(() => validateSchema(doc, schema));
  }
  assert.throws(() => validateSchema(original, { ...schema, unknownKeyword: true }), /unsupported schema/);
});

test('BSP detects multi-node and disconnected cycles while permitting shared children', () => {
  const base = fixture().find(e => e[0] === 'NODES')![1];
  const cycle = Buffer.concat([base, base]); cycle.writeUInt16LE(1, 24); cycle.writeUInt16LE(0, 28 + 24);
  assert.throws(() => validateMap(mutate('NODES', () => cycle)), /BSP cycle/);
  const unreachable = Buffer.concat([base, base]); unreachable.writeUInt16LE(0, 24);
  assert.throws(() => validateMap(mutate('NODES', () => unreachable)), /BSP cycle/);
  const dag = Buffer.concat([base, base]); dag.writeUInt16LE(1, 24); dag.writeUInt16LE(1, 26);
  assert.equal(validateMap(mutate('NODES', () => dag)).count.NODES, 2);
});
test('near-end offsets and counts reject one-byte truncations, not only integer extremes', () => {
  const wad = serialize(fixture()), directory = wad.readInt32LE(8); wad.writeInt32LE(wad.length, directory + 16); wad.writeInt32LE(1, directory + 20);
  assert.throws(() => parseWad(wad), /bounds/);
  assert.throws(() => validateResources(mutate('TEXTURE1', b => { b.writeInt32LE(b.length - 21, 4); })), /out of bounds/);
  assert.throws(() => validateResources(mutate('PNAMES', b => b.subarray(0, b.length - 1))), /invalid count/);
  assert.throws(() => validateResources(mutate('PATCH', b => { b.writeInt32LE(b.length, 8); })), /patch post/);
  assert.throws(() => validateResources(mutate('BLOCKMAP', b => { b.writeInt16LE(b.length / 2, 8); })), /list offset/);
});
test('original absolute patch post offsets permit clipping without tall-patch normalization', () => {
  const wad = mutate('PATCH', b => { b[12] = 200; }); const patch = lookup(wad, 'PATCH');
  assert.deepEqual(validatePatch(patch), { width: 1, height: 1 }); assert.equal(patch.data[12], 200);
});

test('BSP root cannot overlap NF_SUBSECTOR flag', () => {
  const node = Buffer.alloc(28); node.writeUInt16LE(32768,24); node.writeUInt16LE(32768,26);
  assert.throws(() => validateMap(mutate('NODES', () => Buffer.concat(Array(32769).fill(node)))), /root exceeds/);
  assert.equal(validateMap(mutate('NODES', () => Buffer.concat(Array(32768).fill(node)))).count.NODES, 32768);
});

test('WAD magic compares all eight bits of each byte', () => {
  for(let i=0;i<4;i++){const wad=serialize(fixture());wad[i]|=128;assert.throws(()=>parseWad(wad),/magic/);}
});
