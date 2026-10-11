// SPDX-License-Identifier: GPL-2.0-only
// Isolated profile adapter. Shared launcher wiring belongs to the Git integrator.
import {prepareResources,sha256,canonical,hex} from './install-resources.mjs';
export const DOOM2_PROFILE=Object.freeze({id:'doom2',name:'DOOM II 1.9',available:true,
 wadSha256:'10d67824b11025ddd9198e8cfc87ca335ee6e2d3e63af4180fa9b8a471893255',md5:'25e1459ca71d321525f84628f45ca8cd',
 bundleSha256:'775bc8b01d44c2fb1c3a68a79b9864c2f36ebbb29746d31e9ca600ae226af5ad',
 directorySha256:'2d91a39dcf822b968a3719ef79bc2a7880b634432522300c575a76b970022515',
 chunkHashesSha256:'903d131f726847ec2afc79d24fa0a1c08d7c03fbacb135d23808d9a5b4a299c9',
 memoryProfile:3,memoryProfileName:'virtual',chunks:889,lumps:2919,blobBytes:14557275,mapRange:[1,32],memoryPolicy:'explicit deterministic virtual-pointer compatibility; unknown bytes rejected',initializationAPI:'initializeMenuWithMemoryProfile(bool,uint8)'});
// Existing packer labels every commercial manifest DOOM.WAD. Reuse its byte packing
// and authentication, then independently authenticate the actual DOOM2.WAD name.
const LEGACY_NAME_BUNDLE='fd4328f41746ea786460551db384cfd7d8b8d2861e22d1e8077c59f1366308ed';
export async function prepareDoom2Resources(bytes){
 const r=await prepareResources(bytes,{...DOOM2_PROFILE,bundleSha256:LEGACY_NAME_BUNDLE});
 const directory=r.directory,dv=new DataView(directory.buffer,directory.byteOffset,directory.byteLength),lumps=[];
 for(let id=0;id<DOOM2_PROFILE.lumps;id++)lumps.push({id,nameHex:hex(directory.subarray(id*16,id*16+8)),offset:dv.getUint32(id*16+8,true),length:dv.getUint32(id*16+12,true)});
 const blob=new Uint8Array(DOOM2_PROFILE.blobBytes);let at=0;
 for(const c of r.chunks){blob.set(c.payload,at);at+=c.payload.length;}
 if(at!==blob.length||r.chunks.length!==DOOM2_PROFILE.chunks)throw Error('DOOM II dimensions mismatch');
 const manifest={schemaVersion:0,provenance:{kind:'wad',wadName:'DOOM2.WAD',wadSha256:DOOM2_PROFILE.wadSha256,upstreamCommit:'a77dfb96cb91780ca334d0d4cfd86957558007e0',license:'Commercial id Software IWAD supplied by user; do not distribute resource payloads'},byteOrder:'little-endian',blobByteLength:blob.length,blobSha256:await sha256(blob),lumps};
 const digest=await sha256(new TextEncoder().encode(canonical(manifest)));
 if(digest!==DOOM2_PROFILE.bundleSha256)throw Error('DOOM II canonical manifest mismatch');
 r.resourceIdentity={...r.resourceIdentity,bundleSha256:digest};r.palette={...r.palette,resourceIdentity:r.resourceIdentity};return r;
}
