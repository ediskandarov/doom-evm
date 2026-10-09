// SPDX-License-Identifier: GPL-2.0-only
// Hash first, then extract only exact pinned members; no external unzip or npm dependencies.
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { inflateRawSync } from 'node:zlib';
import { sha256, requireValid } from './wad.ts';
const pin = JSON.parse(readFileSync(new URL('./freedoom.lock.json', import.meta.url), 'utf8'));
const output = resolve(process.argv[2] || 'artifacts/local/freedoom');
mkdirSync(output, { recursive: true });
const archivePath = resolve(output, 'freedoom-0.13.0.zip');
let archive: Buffer;
if (existsSync(archivePath)) archive = readFileSync(archivePath);
else {
  const response = await fetch(pin.archiveUrl, { signal: AbortSignal.timeout(120000) });
  requireValid(response.ok, `download failed: HTTP ${response.status}`);
  archive = Buffer.from(await response.arrayBuffer());
}
requireValid(sha256(archive) === pin.archiveSha256, 'archive SHA256 mismatch');
function member(name: string): Buffer {
  let end = archive.length - 22;
  while (end >= Math.max(0, archive.length - 65557) && archive.readUInt32LE(end) !== 0x06054b50) end--;
  requireValid(end >= 0 && archive.readUInt32LE(end) === 0x06054b50, 'ZIP end directory missing');
  requireValid(archive.readUInt16LE(end + 4) === 0 && archive.readUInt16LE(end + 6) === 0, 'multi-disk ZIP unsupported');
  const entries = archive.readUInt16LE(end + 10); let at = archive.readUInt32LE(end + 16);
  for (let i = 0; i < entries; i++) {
    requireValid(at + 46 <= archive.length && archive.readUInt32LE(at) === 0x02014b50, 'bad ZIP directory');
    const flags = archive.readUInt16LE(at + 8), method = archive.readUInt16LE(at + 10), size = archive.readUInt32LE(at + 20), rawSize = archive.readUInt32LE(at + 24);
    const nameLength = archive.readUInt16LE(at + 28), extraLength = archive.readUInt16LE(at + 30), commentLength = archive.readUInt16LE(at + 32), local = archive.readUInt32LE(at + 42);
    requireValid(at + 46 + nameLength + extraLength + commentLength <= archive.length, 'truncated ZIP directory entry');
    const entryName = archive.toString('utf8', at + 46, at + 46 + nameLength);
    if (entryName === name) {
      requireValid(!(flags & 1) && (method === 0 || method === 8), 'unsupported ZIP compression/encryption');
      requireValid(local + 30 <= archive.length && archive.readUInt32LE(local) === 0x04034b50, 'bad local ZIP header');
      const start = local + 30 + archive.readUInt16LE(local + 26) + archive.readUInt16LE(local + 28);
      requireValid(start + size <= archive.length && rawSize <= 32 * 1024 * 1024, 'ZIP member bounds');
      const compressed = archive.subarray(start, start + size), data = method === 0 ? compressed : inflateRawSync(compressed, { maxOutputLength: 32 * 1024 * 1024 });
      requireValid(data.length === rawSize, 'ZIP member length mismatch'); return data;
    }
    at += 46 + nameLength + extraLength + commentLength;
  }
  throw new Error(`ZIP member missing: ${name}`);
}
const wad = member(pin.wadMember), license = member(pin.licenseMember);
requireValid(sha256(wad) === pin.wadSha256, 'WAD SHA256 mismatch');
requireValid(license.equals(readFileSync(new URL('../../test/fixtures/wad/COPYING.txt', import.meta.url))), 'license differs from committed pinned copy');
writeFileSync(archivePath, archive);
writeFileSync(resolve(output, 'freedoom1.wad'), wad);
writeFileSync(resolve(output, 'COPYING.txt'), license);
console.log(JSON.stringify({ wad: resolve(output, 'freedoom1.wad'), archiveSha256: sha256(archive), wadSha256: sha256(wad), licenseSha256: sha256(license) }, null, 2));
