// SPDX-License-Identifier: GPL-2.0-only
// Separate, explicit commercial IWAD profile; payloads must remain artifacts/local.
import {readFileSync, writeFileSync, mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {parseWad, validateResources, lookup, sha256, canonical} from '../../wad/wad.ts';
const input=resolve(process.argv[2] || 'artifacts/local/doom2/DOOM2.WAD');
const output=resolve(process.argv[3] || 'artifacts/local/doom2/wad');
if (!output.startsWith(resolve('artifacts/local')+'/')) throw Error('Commercial payload output must remain ignored artifacts/local');
const bytes=readFileSync(input);
if(createHash('md5').update(bytes).digest('hex')!=='25e1459ca71d321525f84628f45ca8cd'||sha256(bytes)!=='10d67824b11025ddd9198e8cfc87ca335ee6e2d3e63af4180fa9b8a471893255')throw Error('Exact classic DOOM II 1.9 required');
const wad=parseWad(bytes);const validations=[];
for(let i=1;i<=32;i++)validations.push(validateResources(wad,`MAP${String(i).padStart(2,'0')}`));
let offset=0;const lumps=wad.lumps.map(l=>{const r={id:l.id,nameHex:l.nameHex,offset,length:l.data.length};offset+=l.data.length;return r});
const blob=Buffer.concat(wad.lumps.map(l=>l.data));const rgb=lookup(wad,'PLAYPAL').data.subarray(0,768);
const manifest={schemaVersion:0,provenance:{kind:'wad',wadName:'DOOM2.WAD',wadSha256:sha256(bytes),upstreamCommit:'a77dfb96cb91780ca334d0d4cfd86957558007e0',license:'Commercial id Software IWAD supplied by user; do not distribute resource payloads'},byteOrder:'little-endian',blobByteLength:blob.length,blobSha256:sha256(blob),lumps};
const resourceIdentity={schemaVersion:0,wadSha256:sha256(bytes),bundleSha256:sha256(canonical(manifest)),paletteSha256:sha256(rgb),paletteVariant:0};
const directory=Buffer.alloc(lumps.length*16);
lumps.forEach((l,i)=>{Buffer.from(l.nameHex,'hex').copy(directory,i*16);directory.writeUInt32LE(l.offset,i*16+8);directory.writeUInt32LE(l.length,i*16+12)});
const chunks=[];for(let at=0;at<blob.length;at+=16384)chunks.push(Buffer.concat([Buffer.from([0]),blob.subarray(at,at+16384)]));
const pin={profile:'classic-doom2-1.9',MD5:'25e1459ca71d321525f84628f45ca8cd',resourceIdentity,blobBytes:blob.length,lumps:lumps.length,chunks:chunks.length,lastChunkRuntimeBytes:chunks.at(-1)!.length,directorySha256:sha256(directory),chunkHashesSha256:sha256(Buffer.concat(chunks.map(c=>Buffer.from(sha256(c),'hex'))))};
mkdirSync(output,{recursive:true});writeFileSync(output+'/resources.bin',blob);writeFileSync(output+'/directory.bin',directory);
for(const [n,v]of Object.entries({bundle:{...manifest,blobFile:'resources.bin',resourceIdentity},palette:{schemaVersion:0,resourceIdentity,kind:'wad',encoding:'rgb8',colorCount:256,rgbHex:rgb.toString('hex')},validation:validations,pin}))writeFileSync(output+'/'+n+'.json',JSON.stringify(v,null,2)+'\n');
console.log(JSON.stringify(pin,null,2));
