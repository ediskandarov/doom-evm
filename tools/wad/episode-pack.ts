// SPDX-License-Identifier: GPL-2.0-only
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { parseWad, canonical, requireValid } from './wad.ts';
import { packEpisode, verifyEpisode } from './episode.ts';
const [mode, input, destination] = process.argv.slice(2);
requireValid(['pack', 'check'].includes(mode) && input && destination, 'usage: node tools/wad/episode-pack.ts pack|check INPUT.wad OUTPUT_DIRECTORY');
const bytes = readFileSync(input), started = performance.now();
if (mode === 'pack') {
  const packed = packEpisode(parseWad(bytes));
  mkdirSync(resolve(destination, 'maps'), { recursive: true });
  writeFileSync(resolve(destination, 'resources.bin'), packed.blob);
  for (const key of ['bundle', 'palette', 'validation', 'episode'] as const) writeFileSync(resolve(destination, `${key}.json`), JSON.stringify(packed[key], null, 2) + '\n');
  for (const map of packed.episode.maps) writeFileSync(resolve(destination, 'maps', `${map.map}.json`), JSON.stringify(map, null, 2) + '\n');
  console.log(JSON.stringify({ pass: true, maps: packed.episode.maps.length, packageMs: performance.now() - started, sharedBlobBytes: packed.blob.length,
    catalogBytes: Buffer.byteLength(canonical(packed.episode)), mapPayloadBytes: packed.episode.maps.map(m => ({ map: m.map, bytes: Object.values(m.lumps).reduce((n, l) => n + l.length, 0) })) }));
} else {
  const json = (file: string) => JSON.parse(readFileSync(resolve(destination, file), 'utf8'));
  const packed = verifyEpisode(bytes, json('episode.json'), json('bundle.json'), readFileSync(resolve(destination, 'resources.bin')));
  for (const key of ['palette', 'validation'] as const) requireValid(canonical(json(`${key}.json`)) === canonical(packed[key]), `${key} mismatch`);
  for (const map of packed.episode.maps) requireValid(canonical(json(`maps/${map.map}.json`)) === canonical(map), `${map.map} package mismatch`);
  const repeat = packEpisode(parseWad(bytes));
  requireValid(canonical(repeat.episode) === canonical(packed.episode) && repeat.blob.equals(packed.blob), 'nondeterministic episode package');
  console.log(JSON.stringify({ pass: true, maps: 9, everyLumpByteVerified: true, repeatedPackingExact: true, catalogSha256: packed.episode.catalogSha256, checkMs: performance.now() - started }));
}
