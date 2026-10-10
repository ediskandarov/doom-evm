// SPDX-License-Identifier: GPL-2.0-only
// Additive resource contract: original directory IDs always address the shared v0 bundle.
import { parseWad, packWad, lookup, mapLumps, records, validateResources, validatePatch, nameOf, sha256, canonical, requireValid } from './wad.ts';
import type { Wad, Lump } from './wad.ts';
import { readFileSync } from 'node:fs';
import { validateSchema } from './schema.ts';

export const EPISODE_ONE = Object.freeze(Array.from({ length: 9 }, (_, i) => `E1M${i + 1}`));
export const CHUNK_BYTES = 16384;
type Bundle = ReturnType<typeof packWad>['bundle'];
export const EPISODE_SCHEMA = JSON.parse(readFileSync(new URL('../../schemas/episode-resources-v1.schema.json', import.meta.url), 'utf8'));

/** Keep TEXTURE1 then TEXTURE2 order and first texture precedence; PNAMES uses last WAD match. */
function sharedResources(wad: Wad) {
  const names = lookup(wad, 'PNAMES').data;
  const patches = Array.from({ length: names.readInt32LE(0) }, (_, i) => lookup(wad, nameOf(names.subarray(4 + i * 8, 12 + i * 8))).id);
  const textures: { index: number; name: string; sourceLumpId: number; definitionOffset: number; patchLumpIds: number[] }[] = [];
  for (const key of ['TEXTURE1', 'TEXTURE2']) {
    if (key === 'TEXTURE2' && !wad.lumps.some(l => l.name === key)) continue;
    const lump = lookup(wad, key), b = lump.data;
    for (let i = 0; i < b.readInt32LE(0); ++i) {
      const at = b.readInt32LE(4 + i * 4);
      textures.push({ index: textures.length, name: nameOf(b.subarray(at, at + 8)), sourceLumpId: lump.id, definitionOffset: at,
        patchLumpIds: Array.from({ length: b.readInt16LE(at + 20) }, (_, p) => patches[b.readInt16LE(at + 26 + p * 10)]) });
    }
  }
  const flatStart = lookup(wad, 'F_START').id, flatEnd = lookup(wad, 'F_END').id;
  const spriteStart = lookup(wad, 'S_START').id, spriteEnd = lookup(wad, 'S_END').id;
  requireValid(spriteStart < spriteEnd, 'sprite namespace order');
  // R_InitSpriteLumps treats every entry inside the namespace as a patch.
  for (const lump of wad.lumps.slice(spriteStart + 1, spriteEnd)) validatePatch(lump);
  return { paletteLumpId: lookup(wad, 'PLAYPAL').id, colormapLumpId: lookup(wad, 'COLORMAP').id,
    pnamesLumpId: lookup(wad, 'PNAMES').id, pnamesPatchLumpIds: patches, textures,
    flats: { firstLumpId: flatStart + 1, count: flatEnd - flatStart - 1 },
    sprites: { firstLumpId: spriteStart + 1, count: spriteEnd - spriteStart - 1 } };
}

function descriptor(lump: Lump, bundle: Bundle) {
  const packed = bundle.lumps[lump.id];
  requireValid(packed && packed.nameHex === lump.nameHex && packed.length === lump.data.length, 'bundle/source directory mismatch');
  return { ...packed, originalOffset: lump.offset, sha256: sha256(lump.data) };
}

/** A package is an authenticated selection, not a renumbered or duplicated resource blob. */
function episodeCatalog(wad: Wad, bundle: Bundle) {
  requireValid(sha256(wad.bytes) === bundle.resourceIdentity.wadSha256, 'bundle/source WAD identity mismatch');
  const shared = sharedResources(wad);
  const maps = EPISODE_ONE.map(map => {
    const validation = validateResources(wad, map), selected = mapLumps(wad, map);
    const textureIndices = new Set<number>(), flatIndices = new Set<number>();
    for (const row of records(selected.SIDEDEFS)) for (const key of ['toptexture', 'bottomtexture', 'midtexture']) {
      const name = String(row[key]);
      const index = name.startsWith('-') ? 0 : shared.textures.findIndex(t => t.name === name);
      requireValid(index >= 0 && index <= 32767, `texture index outside original short domain: ${name}`);
      textureIndices.add(index);
    }
    for (const row of records(selected.SECTORS)) for (const key of ['floorpic', 'ceilingpic']) {
      const index = lookup(wad, String(row[key])).id - shared.flats.firstLumpId;
      requireValid(index >= 0 && index < shared.flats.count && index <= 32767, 'flat index outside original short domain');
      flatIndices.add(index);
    }
    const textures = [...textureIndices].sort((a, b) => a - b), flats = [...flatIndices].sort((a, b) => a - b);
    const bm = selected.BLOCKMAP.data;
    const manifest = { schemaVersion: 1, map, resourceIdentity: bundle.resourceIdentity,
      marker: descriptor(lookup(wad, map), bundle), lumps: Object.fromEntries(Object.entries(selected).map(([name, lump]) => [name, descriptor(lump, bundle)])),
      validation, blockmapOrigin: { x: bm.readInt16LE(0), y: bm.readInt16LE(2) },
      dependencies: { textureIndices: textures, patchLumpIds: [...new Set(textures.flatMap(i => shared.textures[i].patchLumpIds))].sort((a, b) => a - b),
        flatIndices: flats, flatLumpIds: flats.map(i => shared.flats.firstLumpId + i) } };
    return { ...manifest, packageSha256: sha256(canonical(manifest)) };
  });
  const manifest = { schemaVersion: 1, episode: 1, resourceIdentity: bundle.resourceIdentity, provenance: bundle.provenance,
    bundleFile: 'bundle.json', chunkBytes: CHUNK_BYTES, shared, maps };
  return { ...manifest, catalogSha256: sha256(canonical(manifest)) };
}

export function packEpisode(wad: Wad) {
  const packed = packWad(wad);
  const episode = episodeCatalog(wad, packed.bundle);
  validateSchema(episode, EPISODE_SCHEMA);
  return { ...packed, episode };
}

/** Regeneration binds checksums, map boundaries, all dependencies and original provenance. */
export function verifyEpisode(bytes: Buffer, catalog: ReturnType<typeof episodeCatalog>, bundle: Bundle, blob: Buffer) {
  validateSchema(catalog, EPISODE_SCHEMA);
  const expected = packEpisode(parseWad(bytes));
  requireValid(canonical(bundle) === canonical(expected.bundle), 'episode bundle mismatch');
  requireValid(blob.equals(expected.blob), 'episode blob mismatch');
  requireValid(canonical(catalog) === canonical(expected.episode), 'episode catalog mismatch');
  return expected;
}
