// SPDX-License-Identifier: GPL-2.0-only
// Binary layouts follow pinned linuxdoom-1.10/doomdata.h, p_setup.c and r_data.c.
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
export const sha256 = (data: Uint8Array | string): string => createHash('sha256').update(data).digest('hex');
export function requireValid(ok: unknown, message: string): asserts ok { if (!ok) throw new Error(message); }
export type Lump = { id: number; name: string; nameHex: string; offset: number; data: Buffer };
export type Wad = { kind: string; bytes: Buffer; lumps: Lump[] };
const layouts = JSON.parse(readFileSync(new URL('../../schemas/wad-layouts-v1.json', import.meta.url), 'utf8')).records;
export const nameOf = (data: Buffer): string => data.toString('latin1').split('\0', 1)[0].toUpperCase();
function range(data: Buffer, offset: number, length: number, label: string) {
  requireValid(Number.isSafeInteger(offset) && Number.isSafeInteger(length) && offset >= 0 && length >= 0 && offset <= data.length && length <= data.length - offset, `${label}: out of bounds`);
}
export function parseWad(bytes: Buffer): Wad {
  range(bytes, 0, 12, 'WAD header');
  const kind = bytes.toString('latin1', 0, 4);
  requireValid(kind === 'IWAD' || kind === 'PWAD', 'unsupported WAD magic');
  const count = bytes.readInt32LE(4), directory = bytes.readInt32LE(8);
  requireValid(count >= 0 && directory >= 12, 'negative count or invalid directory');
  range(bytes, directory, count * 16, 'WAD directory');
  const lumps: Lump[] = [];
  for (let id = 0; id < count; id++) {
    const at = directory + id * 16, offset = bytes.readInt32LE(at), length = bytes.readInt32LE(at + 4);
    range(bytes, offset, length, `lump ${id}`);
    const rawName = bytes.subarray(at + 8, at + 16);
    lumps.push({ id, name: nameOf(rawName), nameHex: rawName.toString('hex'), offset, data: bytes.subarray(offset, offset + length) });
  }
  return { kind, bytes, lumps };
}
export function lookup(wad: Wad, name: string): Lump {
  const query = Buffer.alloc(8); Buffer.from(name.split('\0', 1)[0].toUpperCase(), 'latin1').copy(query, 0, 0, 8);
  // W_AddFile uses strncpy(...,8): bytes after the first NUL become zero for lookup.
  // Preserve original raw bytes in nameHex for deterministic resource packing.
  const found = wad.lumps.findLast(lump => {
    const key = Buffer.from(lump.nameHex, 'hex'), nul = key.indexOf(0);
    if (nul >= 0) key.fill(0, nul);
    return key.equals(query);
  });
  requireValid(found, `missing lump ${name}`); return found;
}
export function records(lump: Lump): Record<string, number | string>[] {
  const layout = layouts[lump.name]; requireValid(layout, `unsupported records ${lump.name}`);
  requireValid(lump.data.length % layout.stride === 0, `${lump.name}: invalid record length`);
  const output = [];
  for (let start = 0; start < lump.data.length; start += layout.stride) {
    const row: Record<string, number | string> = {}; let offset = start;
    for (const field of layout.fields) {
      row[field.name] = field.type === 'bytes8' ? nameOf(lump.data.subarray(offset, offset + 8)) : field.type === 'i16' ? lump.data.readInt16LE(offset) : lump.data.readUInt16LE(offset);
      offset += field.type === 'bytes8' ? 8 : 2;
    }
    requireValid(offset === start + layout.stride, 'layout schema stride mismatch'); output.push(row);
  }
  return output;
}
export const MAP_LUMPS = ['THINGS', 'LINEDEFS', 'SIDEDEFS', 'VERTEXES', 'SEGS', 'SSECTORS', 'NODES', 'SECTORS', 'REJECT', 'BLOCKMAP'];
export function mapLumps(wad: Wad, map = 'E1M1'): Record<string, Lump> {
  const marker = lookup(wad, map); requireValid(marker.data.length === 0, 'unsupported nonempty map marker');
  const result: Record<string, Lump> = {};
  for (const [i, name] of MAP_LUMPS.entries()) {
    const lump = wad.lumps[marker.id + i + 1];
    requireValid(lump && lump.name === name, `${map}: unsupported map layout; expected ${name}`); result[name] = lump;
  }
  requireValid(wad.lumps[marker.id + 11]?.name !== 'BEHAVIOR', 'Hexen maps unsupported');
  return result;
}
export function validateMap(wad: Wad, map = 'E1M1') {
  const lumps = mapLumps(wad, map), rows: Record<string, any[]> = {};
  for (const name of MAP_LUMPS.slice(0, 8)) rows[name] = records(lumps[name]);
  const count = Object.fromEntries(Object.entries(rows).map(([key, val]) => [key, val.length]));
  for (const name of ['VERTEXES', 'LINEDEFS', 'SIDEDEFS', 'SECTORS', 'SEGS', 'SSECTORS']) requireValid(count[name] > 0, `${name}: empty map data`);
  const index = (value: number, name: string, label: string) => requireValid(value >= 0 && value < count[name], `${label}: invalid ${name} index ${value}`);
  for (const side of rows.SIDEDEFS) index(side.sector, 'SECTORS', 'SIDEDEFS');
  for (const line of rows.LINEDEFS) {
    index(line.v1, 'VERTEXES', 'LINEDEFS'); index(line.v2, 'VERTEXES', 'LINEDEFS');
    for (const side of [line.sidenum0, line.sidenum1]) if (side !== -1) index(side, 'SIDEDEFS', 'LINEDEFS');
    requireValid(line.sidenum0 !== -1, 'LINEDEFS: front side missing');
    if (line.flags & 4) requireValid(line.sidenum1 !== -1, 'LINEDEFS: two-sided flag with absent back side');
  }
  for (const seg of rows.SEGS) {
    index(seg.v1, 'VERTEXES', 'SEGS'); index(seg.v2, 'VERTEXES', 'SEGS'); index(seg.linedef, 'LINEDEFS', 'SEGS');
    requireValid(seg.side === 0 || seg.side === 1, 'SEGS: invalid side');
    index(rows.LINEDEFS[seg.linedef][`sidenum${seg.side}`], 'SIDEDEFS', 'SEGS');
  }
  for (const sub of rows.SSECTORS) requireValid(sub.numsegs > 0 && sub.firstseg >= 0 && sub.firstseg + sub.numsegs <= count.SEGS, 'SSECTORS: invalid seg span');
  requireValid(count.NODES <= 32768, 'NODES: root exceeds original 15-bit node domain');
  const children = rows.NODES.map(node => [node.child0, node.child1]);
  for (const pair of children) for (const child of pair) index(child & 0x8000 ? child & 0x7fff : child, child & 0x8000 ? 'SSECTORS' : 'NODES', 'NODES');
  // Iterative depth-first coloring avoids host call-stack limits on hostile graphs.
  const color = new Uint8Array(count.NODES);
  for (let start = 0; start < count.NODES; start++) {
    if (color[start]) continue;
    const stack: [number, boolean][] = [[start, false]];
    while (stack.length) {
      const [node, exit] = stack.pop()!;
      if (exit) { color[node] = 2; continue; }
      requireValid(color[node] !== 1, 'NODES: BSP cycle'); if (color[node] === 2) continue;
      color[node] = 1; stack.push([node, true]);
      for (const child of children[node]) if (!(child & 0x8000)) stack.push([child, false]);
    }
  }
  requireValid(count.NODES !== 0 || count.SSECTORS === 1, 'NODES: empty tree requires one subsector');
  requireValid(lumps.REJECT.data.length >= Math.ceil(count.SECTORS * count.SECTORS / 8), 'REJECT: truncated bit matrix');
  const bm = lumps.BLOCKMAP.data; requireValid(bm.length >= 8 && bm.length % 2 === 0, 'BLOCKMAP: invalid length');
  const width = bm.readInt16LE(4), height = bm.readInt16LE(6), cells = width * height;
  requireValid(width > 0 && height > 0 && cells <= (bm.length - 8) / 2, 'BLOCKMAP: invalid dimensions');
  const seen = new Set<number>();
  for (let i = 0; i < cells; i++) {
    const start = bm.readInt16LE(8 + i * 2); requireValid(start >= 4 + cells && start < bm.length / 2, 'BLOCKMAP: invalid list offset');
    if (seen.has(start)) continue; seen.add(start);
    requireValid(bm.readInt16LE(start * 2) === 0, 'BLOCKMAP: list must start with zero');
    let at = start + 1;
    while (true) {
      requireValid(at < bm.length / 2, 'BLOCKMAP: unterminated list');
      const line = bm.readInt16LE(at++ * 2); if (line === -1) break; index(line, 'LINEDEFS', 'BLOCKMAP');
    }
  }
  return { map, count, blockmap: { width, height, uniqueLists: seen.size }, rows, lumps };
}
export function validatePatch(lump: Lump) {
  const b = lump.data; range(b, 0, 8, `${lump.name} patch header`);
  const width = b.readInt16LE(0), height = b.readInt16LE(2);
  requireValid(width > 0 && height > 0, `${lump.name}: invalid patch dimensions`); range(b, 8, width * 4, 'patch columns');
  for (let column = 0; column < width; column++) {
    let at = b.readInt32LE(8 + column * 4); requireValid(at >= 8 + width * 4, 'patch: invalid column offset');
    while (true) {
      range(b, at, 1, 'patch post'); if (b[at] === 255) break;
      range(b, at, 4, 'patch post header'); const length = b[at + 1];
      range(b, at, length + 4, 'patch post pixels');
      // Original drawing clips posts to texture height; do not impose a non-original topdelta+length rule.
      at += length + 4;
    }
  }
  return { width, height };
}
export function validateResources(wad: Wad, map = 'E1M1') {
  const selected = validateMap(wad, map);
  const playpal = lookup(wad, 'PLAYPAL').data, colormap = lookup(wad, 'COLORMAP').data;
  requireValid(playpal.length >= 768 && playpal.length % 768 === 0 && playpal.length / 768 <= 256, 'PLAYPAL: invalid palette length');
  requireValid(colormap.length >= 34 * 256 && colormap.length % 256 === 0, 'COLORMAP: invalid table length');
  const pnames = lookup(wad, 'PNAMES').data; range(pnames, 0, 4, 'PNAMES header');
  const patchCount = pnames.readInt32LE(0); requireValid(patchCount >= 0 && pnames.length === 4 + patchCount * 8, 'PNAMES: invalid count');
  const patchNames = Array.from({ length: patchCount }, (_, i) => nameOf(pnames.subarray(4 + i * 8, 12 + i * 8)));
  const textures = new Set<string>(), patches = new Set<string>(); let textureCount = 0;
  for (const textureName of ['TEXTURE1', 'TEXTURE2']) {
    if (textureName === 'TEXTURE2' && !wad.lumps.some(l => l.name === textureName)) continue;
    const data = lookup(wad, textureName).data; range(data, 0, 4, textureName);
    const number = data.readInt32LE(0); requireValid(number >= 0, `${textureName}: negative count`); range(data, 4, number * 4, textureName);
    for (let i = 0; i < number; i++) {
      const at = data.readInt32LE(4 + i * 4); requireValid(at >= 4 + number * 4, `${textureName}: invalid definition offset`); range(data, at, 22, textureName);
      const name = nameOf(data.subarray(at, at + 8)), width = data.readInt16LE(at + 12), height = data.readInt16LE(at + 14), n = data.readInt16LE(at + 20);
      requireValid(width > 0 && height > 0 && n > 0, `${textureName}: invalid dimensions/patch count`); range(data, at + 22, n * 10, textureName);
      for (let p = 0; p < n; p++) {
        const patch = data.readInt16LE(at + 22 + p * 10 + 4); requireValid(patch >= 0 && patch < patchNames.length, `${textureName}: invalid PNAMES index`);
        const patchName = patchNames[patch]; if (!patches.has(patchName)) { validatePatch(lookup(wad, patchName)); patches.add(patchName); }
      }
      textures.add(name); textureCount++;
    }
  }
  const flatStart = lookup(wad, 'F_START').id, flatEnd = lookup(wad, 'F_END').id;
  requireValid(flatStart < flatEnd, 'flat namespace order'); const flats = new Set<string>();
  for (const lump of wad.lumps.slice(flatStart + 1, flatEnd)) {
    if (/^F[0-9]+_(START|END)$/.test(lump.name) && lump.data.length === 0) continue;
    requireValid(lump.data.length === 4096, `${lump.name}: invalid flat length`); flats.add(lump.name);
  }
  for (const sector of selected.rows.SECTORS) for (const name of [sector.floorpic, sector.ceilingpic]) { const flat = lookup(wad, name); requireValid(flats.has(name) && flat.id > flatStart && flat.id < flatEnd && flat.data.length === 4096, `SECTORS: missing flat ${name}`); }
  for (const side of selected.rows.SIDEDEFS) for (const name of [side.toptexture, side.bottomtexture, side.midtexture]) requireValid(name.startsWith('-') || textures.has(name), `SIDEDEFS: missing texture ${name}`);
  return { map, counts: selected.count, blockmap: selected.blockmap, paletteCount: playpal.length / 768, colormapCount: colormap.length / 256, pnamesCount: patchCount, textureCount, referencedPatchCount: patches.size, flatCount: flats.size };
}
export function canonical(value: any): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value !== null && typeof value === 'object') return `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`;
  return JSON.stringify(value).replace(/[\u007f-\uffff]/g, char => `\\u${char.charCodeAt(0).toString(16).padStart(4, '0')}`);
}
export function packWad(wad: Wad, map = 'E1M1') {
  const pin = JSON.parse(readFileSync(new URL('./freedoom.lock.json', import.meta.url), 'utf8'));
  requireValid(sha256(wad.bytes) === pin.wadSha256, 'packing requires pinned redistributable Freedoom WAD');
  const validation = validateResources(wad, map), blob = Buffer.concat(wad.lumps.map(lump => lump.data));
  requireValid(blob.length <= 0xffffffff && wad.lumps.length < 0xffffffff, 'resource bundle exceeds uint32 domain');
  let offset = 0;
  const lumps = wad.lumps.map(lump => { const result = { id: lump.id, nameHex: lump.nameHex, offset, length: lump.data.length }; offset += lump.data.length; return result; });
  const rgb = lookup(wad, 'PLAYPAL').data.subarray(0, 768), wadSha256 = sha256(wad.bytes);
  const manifest = { schemaVersion: 0, provenance: { kind: 'wad', wadName: 'freedoom1.wad', wadSha256, upstreamCommit: 'a77dfb96cb91780ca334d0d4cfd86957558007e0', license: 'Freedoom BSD-3-Clause; see test/fixtures/wad/COPYING.txt' }, byteOrder: 'little-endian', blobByteLength: blob.length, blobSha256: sha256(blob), lumps };
  const resourceIdentity = { schemaVersion: 0, wadSha256, bundleSha256: sha256(canonical(manifest)), paletteSha256: sha256(rgb), paletteVariant: 0 };
  return { blob, bundle: { ...manifest, blobFile: 'resources.bin', resourceIdentity }, palette: { schemaVersion: 0, resourceIdentity, kind: 'wad', encoding: 'rgb8', colorCount: 256, rgbHex: rgb.toString('hex') }, validation };
}
