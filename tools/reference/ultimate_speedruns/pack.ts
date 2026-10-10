// SPDX-License-Identifier: GPL-2.0-only
// Separate, explicit commercial IWAD profile; payloads must remain artifacts/local.
import {readFileSync, writeFileSync, mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {parseWad, validateResources, lookup, sha256, canonical} from '../../wad/wad.ts';
const input=resolve(process.argv[2] || 'artifacts/local/ultimate-doom/DOOM.WAD');
const output=resolve(process.argv[3] || 'artifacts/local/ultimate-speedruns/wad');
if (!output.startsWith(resolve('artifacts/local')+'/')) throw Error('Commercial payload output must remain ignored artifacts/local');
const bytes=readFileSync(input);
if(createHash('md5').update(bytes).digest('hex')!=='c4fe9fd920207691a9f493668e0a2083'||sha256(bytes)!=='6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f')throw Error('Exact classic Ultimate DOOM 1.9 required');
const wad=parseWad(bytes);const validations=[];
for(let i=1;i<=9;i++)validations.push(validateResources(wad,`E1M${i}`));
let offset=0;const lumps=wad.lumps.map(l=>{const r={id:l.id,nameHex:l.nameHex,offset,length:l.data.length};offset+=l.data.length;return r});
const blob=Buffer.concat(wad.lumps.map(l=>l.data));const rgb=lookup(wad,'PLAYPAL').data.subarray(0,768);
const manifest={schemaVersion:0,provenance:{kind:'wad',wadName:'DOOM.WAD',wadSha256:sha256(bytes),upstreamCommit:'a77dfb96cb91780ca334d0d4cfd86957558007e0',license:'Commercial id Software IWAD supplied by user; do not distribute resource payloads'},byteOrder:'little-endian',blobByteLength:blob.length,blobSha256:sha256(blob),lumps};
const resourceIdentity={schemaVersion:0,wadSha256:sha256(bytes),bundleSha256:sha256(canonical(manifest)),paletteSha256:sha256(rgb),paletteVariant:0};
const directory=Buffer.alloc(lumps.length*16);
lumps.forEach((l,i)=>{Buffer.from(l.nameHex,'hex').copy(directory,i*16);directory.writeUInt32LE(l.offset,i*16+8);directory.writeUInt32LE(l.length,i*16+12)});
const chunks=[];for(let at=0;at<blob.length;at+=16384)chunks.push(Buffer.concat([Buffer.from([0]),blob.subarray(at,at+16384)]));
const pin={profile:'classic-ultimate-doom-1.9',MD5:'c4fe9fd920207691a9f493668e0a2083',resourceIdentity,blobBytes:blob.length,lumps:lumps.length,chunks:chunks.length,lastChunkRuntimeBytes:chunks.at(-1)!.length,directorySha256:sha256(directory),chunkHashesSha256:sha256(Buffer.concat(chunks.map(c=>Buffer.from(sha256(c),'hex'))))};
mkdirSync(output,{recursive:true});writeFileSync(output+'/resources.bin',blob);writeFileSync(output+'/directory.bin',directory);
for(const [n,v]of Object.entries({bundle:{...manifest,blobFile:'resources.bin',resourceIdentity},palette:{schemaVersion:0,resourceIdentity,kind:'wad',encoding:'rgb8',colorCount:256,rgbHex:rgb.toString('hex')},validation:validations,pin}))writeFileSync(output+'/'+n+'.json',JSON.stringify(v,null,2)+'\n');
console.log(JSON.stringify(pin,null,2));
