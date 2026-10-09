// SPDX-License-Identifier: GPL-2.0-only
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { parseWad, packWad } from './wad.ts';
const [input, destination, map = 'E1M1'] = process.argv.slice(2);
if (!input || !destination) throw new Error('usage: node tools/wad/pack.ts INPUT.wad OUTPUT_DIRECTORY [E1M1]');
const packed = packWad(parseWad(readFileSync(input)), map);
mkdirSync(destination, { recursive: true });
writeFileSync(resolve(destination, 'resources.bin'), packed.blob);
for (const name of ['bundle', 'palette', 'validation'] as const) writeFileSync(resolve(destination, `${name}.json`), JSON.stringify(packed[name], null, 2) + '\n');
console.log(JSON.stringify({ output: resolve(destination), identity: packed.bundle.resourceIdentity, validation: packed.validation }, null, 2));
