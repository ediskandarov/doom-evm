// SPDX-License-Identifier: GPL-2.0-only
// Explicit regeneration command; normal verification never overwrites committed expectations.
import { readFileSync, writeFileSync } from 'node:fs';
import { parseWad, mapLumps, lookup, packWad, sha256 } from './wad.ts';
const input = process.argv[2]; if (!input) throw new Error('usage: node tools/wad/snapshot.ts PINNED_FREEDOOM.wad');
const wad = parseWad(readFileSync(input)), packed = packWad(wad);
const selected = [...Object.values(mapLumps(wad)), lookup(wad, 'PLAYPAL'), lookup(wad, 'COLORMAP'), lookup(wad, 'PNAMES')];
const patchName = lookup(wad, 'PNAMES').data.subarray(4, 12).toString('ascii').split('\0')[0];
selected.push(lookup(wad, patchName));
const flat = wad.lumps.slice(lookup(wad, 'F_START').id + 1, lookup(wad, 'F_END').id).find(lump => lump.data.length === 4096)!; selected.push(flat);
const blob = Buffer.concat(selected.map(lump => lump.data)); let offset = 0;
const lumps = selected.map(lump => { const result = { id: lump.id, nameHex: lump.nameHex, originalOffset: lump.offset, offset, length: lump.data.length, sha256: sha256(lump.data) }; offset += lump.data.length; return result; });
const snapshot = { schemaVersion: 1, source: 'Freedoom v0.13.0 freedoom1.wad', map: 'E1M1', resourceIdentity: packed.bundle.resourceIdentity, wadByteLength: wad.bytes.length, directoryEntryCount: wad.lumps.length, packedByteLength: packed.blob.length, packedBlobSha256: sha256(packed.blob), snapshotFile: 'selected-lumps.bin', snapshotSha256: sha256(blob), licenseSha256: sha256(readFileSync(new URL('../../test/fixtures/wad/COPYING.txt', import.meta.url))), lumps, validation: packed.validation };
writeFileSync(new URL('../../test/fixtures/wad/selected-lumps.bin', import.meta.url), blob);
writeFileSync(new URL('../../test/fixtures/wad/snapshot.json', import.meta.url), JSON.stringify(snapshot, null, 2) + '\n');
writeFileSync(new URL('../../test/fixtures/wad/palette.json', import.meta.url), JSON.stringify(packed.palette, null, 2) + '\n');
console.log(JSON.stringify({ snapshotBytes: blob.length, directoryEntryCount: wad.lumps.length, resourceIdentity: snapshot.resourceIdentity }, null, 2));
