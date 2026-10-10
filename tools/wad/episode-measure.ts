// SPDX-License-Identifier: GPL-2.0-only
import { readFileSync, writeFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { parseWad, canonical, sha256 } from './wad.ts';
import { packEpisode, CHUNK_BYTES } from './episode.ts';
const [input, output] = process.argv.slice(2);
assert(input && output, 'usage: node tools/wad/episode-measure.ts INPUT.wad REPORT.json');
const bytes = readFileSync(input), runs: { parseMs: number; packMs: number; rssBeforeBytes: number; rssAfterBytes: number }[] = [];
let packed: ReturnType<typeof packEpisode> | undefined;
for (let i = 0; i < 3; ++i) {
  const rssBeforeBytes = process.memoryUsage().rss, start = performance.now(), wad = parseWad(bytes), parsed = performance.now();
  const next = packEpisode(wad), end = performance.now();
  if (packed) assert.equal(next.episode.catalogSha256, packed.episode.catalogSha256);
  packed = next; runs.push({ parseMs: parsed - start, packMs: end - parsed, rssBeforeBytes, rssAfterBytes: process.memoryUsage().rss });
}
assert(packed);
const report = { schemaVersion: 1, goal: '4.7a', nodeVersion: process.version, resourceIdentity: packed.bundle.resourceIdentity,
  catalogSha256: packed.episode.catalogSha256, runs, sharedBlobBytes: packed.blob.length, sharedChunkCount: Math.ceil(packed.blob.length / CHUNK_BYTES),
  catalogCanonicalBytes: Buffer.byteLength(canonical(packed.episode)),
  totalMapPayloadBytes: packed.episode.maps.reduce((n, m) => n + Object.values(m.lumps).reduce((n, l) => n + l.length, 0), 0),
  maps: packed.episode.maps.map(m => { const chunks = new Set<number>(); for (const l of Object.values(m.lumps)) if (l.length) for (let i = Math.floor(l.offset / CHUNK_BYTES); i <= Math.floor((l.offset + l.length - 1) / CHUNK_BYTES); ++i) chunks.add(i);
    return { map: m.map, packageSha256: m.packageSha256, descriptorCanonicalBytes: Buffer.byteLength(canonical(m)),
      rawMapBytes: Object.values(m.lumps).reduce((n, l) => n + l.length, 0), mapChunkSpans: chunks.size,
      textureDependencies: m.dependencies.textureIndices.length, flatDependencies: m.dependencies.flatIndices.length, patchDependencies: m.dependencies.patchLumpIds.length }; }),
  sourceSha256: Object.fromEntries(['tools/wad/episode.ts', 'tools/wad/episode-measure.ts', 'tools/wad/wad.ts', 'schemas/episode-resources-v1.schema.json'].map(file => [file, sha256(readFileSync(file))])),
  notes: ['Three in-process runs parse the complete WAD and pack/validate all nine maps; packing includes canonical identity computation and full blob construction, excludes filesystem writes.',
    'RSS values are process snapshots before/after each run, not isolated allocator peaks. GC and earlier runs may affect them.',
    'Map chunk spans count existing full-bundle chunks touched by ten map lumps, excluding shared asset reads. No resource reindexing or selective production deployment is proposed.'] };
writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ pass: true, maps: 9, sharedBlobBytes: report.sharedBlobBytes, totalMapPayloadBytes: report.totalMapPayloadBytes, packMs: runs.map(r => r.packMs), output }));
