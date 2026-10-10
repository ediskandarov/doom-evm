// SPDX-License-Identifier: GPL-2.0-only
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parseWad, packWad, lookup, mapLumps, validateMap, validateResources, canonical, sha256 } from './wad.ts';
import { EPISODE_ONE, EPISODE_SCHEMA, packEpisode, verifyEpisode } from './episode.ts';
import { validateSchema } from './schema.ts';
import { compareNative } from './episode-native.ts';

const bytes = readFileSync('artifacts/local/freedoom/freedoom1.wad'), wad = parseWad(bytes), packed = packEpisode(wad);
const fixture = JSON.parse(readFileSync('test/fixtures/phase4_episode/catalog.json', 'utf8'));
const old = JSON.parse(readFileSync('test/fixtures/wad/snapshot.json', 'utf8'));
test('nine-map package preserves accepted bundle and palette identities and exact golden catalog', () => {
  assert.deepEqual(packed.bundle.resourceIdentity, old.resourceIdentity);
  assert.deepEqual(packed.bundle, packWad(wad, 'E1M9').bundle);
  assert.deepEqual(packed.episode, fixture);
  assert.deepEqual(packed.episode.maps.map(m => m.map), EPISODE_ONE);
});
for (const map of EPISODE_ONE) test(`${map}: all ten raw lumps have original IDs, names, offsets, bytes and checksums`, () => {
  const pkg = packed.episode.maps.find(m => m.map === map)!, source = mapLumps(wad, map);
  assert.deepEqual(pkg.validation, validateResources(wad, map));
  assert.equal(pkg.marker.id, lookup(wad, map).id);
  for (const [name, desc] of Object.entries(pkg.lumps)) {
    const l = source[name]; assert.equal(desc.id, l.id); assert.equal(desc.id, pkg.marker.id + Object.keys(pkg.lumps).indexOf(name) + 1);
    assert.equal(desc.originalOffset, l.offset); assert.equal(desc.nameHex, l.nameHex); assert.equal(desc.sha256, sha256(l.data));
    assert.deepEqual(packed.blob.subarray(desc.offset, desc.offset + desc.length), l.data);
  }
  const { packageSha256, ...manifest } = pkg; assert.equal(packageSha256, sha256(canonical(manifest)));
  assert(pkg.dependencies.textureIndices.every(i => i < packed.episode.shared.textures.length));
  assert.deepEqual(pkg.dependencies.flatLumpIds, pkg.dependencies.flatIndices.map(i => packed.episode.shared.flats.firstLumpId + i));
  assert.deepEqual(pkg.dependencies.patchLumpIds, [...new Set(pkg.dependencies.textureIndices.flatMap(i => packed.episode.shared.textures[i].patchLumpIds))].sort((a, b) => a - b));
});
test('native C covers every map field, ten raw lumps and accepted shared resources', () => {
  const report = compareNative('artifacts/local/freedoom/freedoom1.wad', 'artifacts/local/wad/episode-native');
  assert.equal(report.results.length, 9); assert.equal(report.sharedResourcesMatchAcceptedNative, true);
});
test('full catalog, bundle and blob verify by deterministic regeneration', () => {
  assert.deepEqual(verifyEpisode(bytes, fixture, packed.bundle, packed.blob).episode, fixture);
});
test('forged catalog with freshly computed hashes cannot rebind E1M2 to E1M1', () => {
  const catalog = structuredClone(fixture), m = catalog.maps[1]; m.marker = catalog.maps[0].marker; m.lumps = catalog.maps[0].lumps;
  const { packageSha256, ...manifest } = m; m.packageSha256 = sha256(canonical(manifest));
  const { catalogSha256, ...root } = catalog; catalog.catalogSha256 = sha256(canonical(root));
  assert.throws(() => verifyEpisode(bytes, catalog, packed.bundle, packed.blob), /catalog mismatch/);
});
test('valid-looking catalog cannot omit or reorder maps or change provenance', () => {
  for (const edit of [(c: any) => c.maps.pop(), (c: any) => c.maps.reverse(), (c: any) => { c.provenance.upstreamCommit = '0'.repeat(40); }]) {
    const c = structuredClone(fixture); edit(c); assert.throws(() => verifyEpisode(bytes, c, packed.bundle, packed.blob), /catalog mismatch/);
  }
});
test('source corruption is rejected by WAD pin, bundle and blob verification', () => {
  const corrupt = Buffer.from(bytes); corrupt[12] ^= 1; assert.throws(() => packEpisode(parseWad(corrupt)), /pinned/);
  const bundle = structuredClone(packed.bundle); bundle.lumps[1].offset += 1;
  assert.throws(() => verifyEpisode(bytes, fixture, bundle, packed.blob), /bundle mismatch/);
  const blob = Buffer.from(packed.blob); blob[0] ^= 1; assert.throws(() => verifyEpisode(bytes, fixture, packed.bundle, blob), /blob mismatch/);
});
test('schema rejects unknown fields, other episodes, missing lumps, malformed hashes and signed offsets', () => {
  validateSchema(fixture, EPISODE_SCHEMA);
  for (const edit of [(c: any) => { c.extra = 1; }, (c: any) => { c.maps[0].map = 'E2M1'; }, (c: any) => { delete c.maps[0].lumps.REJECT; },
    (c: any) => { c.maps[0].lumps.NODES.sha256 = 'no'; }, (c: any) => { c.maps[0].lumps.NODES.offset = -1; }, (c: any) => { c.shared.sprites.count = true; }]) {
    const c = structuredClone(fixture); edit(c); assert.throws(() => validateSchema(c, EPISODE_SCHEMA));
  }
});
test('map-scoped parsing rejects E1M7 corruption without reading another maps geometry', () => {
  const corrupt = Buffer.from(bytes), lines = mapLumps(wad, 'E1M7').LINEDEFS; corrupt.writeInt16LE(-1, lines.offset);
  const source = parseWad(corrupt); assert.throws(() => validateMap(source, 'E1M7'), /VERTEXES index/); assert.deepEqual(validateMap(source, 'E1M1').count, packed.validation.counts);
});
test('later duplicate map markers retain original last-match selection and strict relative layout', () => {
  const source = parseWad(bytes); const first = lookup(source, 'E1M1'), last = lookup(source, 'E1M9');
  last.nameHex = first.nameHex; last.name = first.name;
  assert.equal(mapLumps(source, 'E1M1').VERTEXES.id, last.id + 4);
  assert.throws(() => mapLumps(source, 'E1M9'), /missing lump/);
  source.lumps[last.id + 1].name = 'VERTEXES'; assert.throws(() => mapLumps(source, 'E1M1'), /layout/);
});
