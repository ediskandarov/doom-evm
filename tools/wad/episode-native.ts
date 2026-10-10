// SPDX-License-Identifier: GPL-2.0-only
// Independent disk -> runtime-field expectation; only used to compare original-C resources.
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';
import { parseWad, mapLumps, records, canonical, sha256 } from './wad.ts';
import { packEpisode } from './episode.ts';

export function words(values: number[]) {
  const out = Buffer.alloc(values.length * 4);
  values.forEach((n, i) => out.writeUInt32LE(n >>> 0, i * 4));
  return out;
}
export function nativeMapExpectation(wad: ReturnType<typeof parseWad>, catalog: ReturnType<typeof packEpisode>['episode'], map: string) {
  const lumps = mapLumps(wad, map), r = Object.fromEntries(Object.entries(lumps).slice(0, 8).map(([key, l]) => [key, records(l)])) as Record<string, any[]>;
  const out: number[] = [], fixed = (v: number) => (v * 65536) | 0;
  const texture = (name: string) => name.startsWith('-') ? 0 : catalog.shared.textures.findIndex(t => t.name === name);
  const flat = (name: string) => wad.lumps.findLast(l => l.name === name)!.id - catalog.shared.flats.firstLumpId;
  out.push(r.VERTEXES.length); for (const v of r.VERTEXES) out.push(fixed(v.x), fixed(v.y));
  out.push(r.SECTORS.length); for (const s of r.SECTORS) out.push(fixed(s.floorheight), fixed(s.ceilingheight), flat(s.floorpic), flat(s.ceilingpic), s.lightlevel);
  out.push(r.SIDEDEFS.length); for (const s of r.SIDEDEFS) out.push(fixed(s.textureoffset), fixed(s.rowoffset), texture(s.toptexture), texture(s.bottomtexture), texture(s.midtexture), s.sector);
  out.push(r.LINEDEFS.length); for (const l of r.LINEDEFS) {
    const a = r.VERTEXES[l.v1], b = r.VERTEXES[l.v2], dx = (fixed(b.x) - fixed(a.x)) | 0, dy = (fixed(b.y) - fixed(a.y)) | 0;
    out.push(l.v1, l.v2, dx, dy, l.flags & 65535, l.special, l.tag, l.sidenum0, l.sidenum1,
      fixed(Math.max(a.y, b.y)), fixed(Math.min(a.y, b.y)), fixed(Math.min(a.x, b.x)), fixed(Math.max(a.x, b.x)),
      dx === 0 ? 1 : dy === 0 ? 0 : (dx < 0) === (dy < 0) ? 2 : 3,
      l.sidenum0 === -1 ? -1 : r.SIDEDEFS[l.sidenum0].sector, l.sidenum1 === -1 ? -1 : r.SIDEDEFS[l.sidenum1].sector);
  }
  out.push(r.SEGS.length); for (const s of r.SEGS) {
    const l = r.LINEDEFS[s.linedef], side = l[`sidenum${s.side}`], back = l[`sidenum${s.side ^ 1}`];
    out.push(s.v1, s.v2, fixed(s.offset), fixed(s.angle), side, s.linedef, r.SIDEDEFS[side].sector, l.flags & 4 ? r.SIDEDEFS[back].sector : -1);
  }
  out.push(r.SSECTORS.length); for (const s of r.SSECTORS) {
    const seg = r.SEGS[s.firstseg], l = r.LINEDEFS[seg.linedef];
    out.push(r.SIDEDEFS[l[`sidenum${seg.side}`]].sector, s.numsegs, s.firstseg);
  }
  out.push(r.NODES.length); for (const n of r.NODES) out.push(...['x', 'y', 'dx', 'dy', 'bbox0top', 'bbox0bottom', 'bbox0left', 'bbox0right', 'bbox1top', 'bbox1bottom', 'bbox1left', 'bbox1right'].map(k => fixed(n[k])), n.child0, n.child1);
  return words(out);
}

export function compareNative(input: string, directory: string) {
  const wad = parseWad(readFileSync(input)), packed = packEpisode(wad), native = JSON.parse(readFileSync('test/fixtures/phase4_episode/native.json', 'utf8'));
  for (const [name, proof] of Object.entries(native.outputs) as [string, any][]) {
    const raw = readFileSync(resolve(directory, name)); assert.equal(raw.length, proof.bytes); assert.equal(sha256(raw), proof.sha256);
  }
  const expectedShared = [words([packed.episode.shared.textures.length]), ...packed.episode.shared.textures.flatMap(t => [Buffer.from(wad.lumps[t.sourceLumpId].data.subarray(t.definitionOffset, t.definitionOffset + 8)), words([t.patchLumpIds.length, ...t.patchLumpIds])]), words([packed.episode.shared.flats.firstLumpId, packed.episode.shared.flats.count, packed.episode.shared.sprites.firstLumpId, packed.episode.shared.sprites.count])];
  assert.deepEqual(readFileSync(resolve(directory, 'shared.indices.bin')), Buffer.concat(expectedShared));
  // All native texture lookups/composites and sprite dimensions still equal the accepted shared fixture.
  const shared = readFileSync(resolve(directory, 'shared.bin')); let at = 4;
  const compact = [shared.subarray(0, 4)];
  for (let i = 0; i < shared.readUInt32LE(0); ++i) {
    const width = shared.readUInt32LE(at), size = shared.readUInt32LE(at + 12);
    compact.push(shared.subarray(at, at + 16)); at += 16;
    compact.push(Buffer.from(sha256(shared.subarray(at, at + width * 8)), 'hex')); at += width * 8;
    const raw = shared.subarray(at, at + size * 2); at += size * 2;
    const pixels = Buffer.alloc(size); let undefinedBytes = 0;
    for (let j = 0; j < size; ++j) { if (!raw[j * 2]) ++undefinedBytes; pixels[j] = raw[j * 2 + 1]; }
    compact.push(Buffer.from(sha256(pixels), 'hex'), words([undefinedBytes]));
  }
  compact.push(shared.subarray(at));
  assert.deepEqual(Buffer.concat(compact), readFileSync('test/fixtures/phase2_data/resources.bin'));
  const results = packed.episode.maps.map(pkg => {
    const lumps = mapLumps(wad, pkg.map), geometry = readFileSync(resolve(directory, `${pkg.map}.map.bin`));
    assert.deepEqual(geometry, nativeMapExpectation(wad, packed.episode, pkg.map), pkg.map+' all geometry runtime fields');
    const things = records(lumps.THINGS), expectedThings = words([things.length, ...things.flatMap(t => ['x', 'y', 'angle', 'type', 'options'].map(k => Number(t[k])))]);
    assert.deepEqual(readFileSync(resolve(directory, `${pkg.map}.things.bin`)), expectedThings);
    const bm = lumps.BLOCKMAP.data, bmWords = Array.from({ length: bm.length / 2 }, (_, i) => bm.readInt16LE(i * 2));
    assert.deepEqual(readFileSync(resolve(directory, `${pkg.map}.blockmap.bin`)), words([bmWords[0] * 65536, bmWords[1] * 65536, bmWords[2], bmWords[3], ...bmWords]));
    const raw = readFileSync(resolve(directory, `${pkg.map}.raw.bin`)); let at = 4; assert.equal(raw.readUInt32LE(0), pkg.marker.id);
    for (const l of Object.values(lumps)) {
      assert.equal(raw.readUInt32LE(at), l.id); assert.equal(raw.readUInt32LE(at + 4), l.data.length); at += 8;
      assert.deepEqual(raw.subarray(at, at + l.data.length), l.data); at += l.data.length;
    }
    assert.equal(at, raw.length);
    return { map: pkg.map, packageSha256: pkg.packageSha256, counts: pkg.validation.counts, geometrySha256: sha256(geometry), thingsSha256: sha256(expectedThings), blockmapSha256: sha256(words([bmWords[0] * 65536, bmWords[1] * 65536, bmWords[2], bmWords[3], ...bmWords])), rejectSha256: sha256(lumps.REJECT.data), tenRawLumpsExact: true };
  });
  return { schemaVersion: 1, goal: '4.7a', pass: true, resourceIdentity: packed.bundle.resourceIdentity, catalogSha256: packed.episode.catalogSha256, nativeManifestSha256: sha256(canonical(native)), sharedResourcesMatchAcceptedNative: true, results };
}

if (process.argv[1]?.endsWith('/episode-native.ts') || process.argv[1] === 'tools/wad/episode-native.ts') {
  const [wad, native, output] = process.argv.slice(2);
  assert(wad && native && output, 'usage: node tools/wad/episode-native.ts INPUT.wad NATIVE_DIRECTORY REPORT.json');
  const report = compareNative(wad, native); writeFileSync(output, JSON.stringify(report, null, 2)+'\n');
  console.log(JSON.stringify({ pass: true, maps: report.results.length, sharedResourcesMatchAcceptedNative: true, output }));
}
