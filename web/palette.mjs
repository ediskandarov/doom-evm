// SPDX-License-Identifier: GPL-2.0-only
// Resource identity and RGB decoding only; no geometry or rendering calculations.
export async function validatePalette(palette, expectedIdentity, expectedKind) {
  const keys=['schemaVersion','wadSha256','bundleSha256','paletteSha256','paletteVariant'];
  if(!palette||!['synthetic','wad'].includes(palette.kind)||palette.kind!==expectedKind||palette.schemaVersion!==0||palette.encoding!=='rgb8'||palette.colorCount!==256||! /^[0-9a-f]{1536}$/.test(palette.rgbHex)) throw Error('Unexpected palette format or kind');
  const identity=palette.resourceIdentity;
  if(!identity||!expectedIdentity||Object.keys(identity).length!==keys.length||Object.keys(expectedIdentity).length!==keys.length||keys.some(key=>identity[key]!==expectedIdentity[key])) throw Error('Resource/palette identity mismatch');
  if(identity.schemaVersion!==0||!Number.isInteger(identity.paletteVariant)||identity.paletteVariant<0||identity.paletteVariant>255||['wadSha256','bundleSha256','paletteSha256'].some(key=>! /^[0-9a-f]{64}$/.test(identity[key]))) throw Error('Invalid resource identity');
  if((identity.wadSha256==='0'.repeat(64))!==(palette.kind==='synthetic')) throw Error('WAD identity contradicts palette kind');
  const rgb=Uint8Array.from(palette.rgbHex.match(/../g),x=>parseInt(x,16));
  const digest=[...new Uint8Array(await crypto.subtle.digest('SHA-256',rgb))].map(x=>x.toString(16).padStart(2,'0')).join('');
  if(digest!==identity.paletteSha256)throw Error('Palette SHA-256 mismatch');
  return rgb;
}
