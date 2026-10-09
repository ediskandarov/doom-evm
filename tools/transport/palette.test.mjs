// SPDX-License-Identifier: GPL-2.0-only
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {validatePalette} from '../../web/palette.mjs';
const sample=JSON.parse(await readFile(new URL('../../web/palette.synthetic.json',import.meta.url),'utf8'));
test('palette validates RGB bytes, kind and identity independent of key order',async()=>{
  const shuffled=Object.fromEntries(Object.entries(sample.resourceIdentity).reverse());
  assert.equal((await validatePalette(sample,shuffled,'synthetic')).length,768);
  const wad=structuredClone(sample);wad.kind='wad';wad.resourceIdentity.wadSha256='1'.repeat(64);
  assert.equal((await validatePalette(wad,wad.resourceIdentity,'wad')).length,768);
  await assert.rejects(validatePalette(wad,wad.resourceIdentity,'synthetic'));
  const corrupt=structuredClone(wad);corrupt.rgbHex='ff'+corrupt.rgbHex.slice(2);
  await assert.rejects(validatePalette(corrupt,wad.resourceIdentity,'wad'),/SHA-256/);
  const mismatch=structuredClone(wad.resourceIdentity);mismatch.bundleSha256='2'.repeat(64);
  await assert.rejects(validatePalette(wad,mismatch,'wad'),/identity mismatch/);
  wad.resourceIdentity.wadSha256='0'.repeat(64);
  await assert.rejects(validatePalette(wad,wad.resourceIdentity,'wad'),/contradicts/);
});
