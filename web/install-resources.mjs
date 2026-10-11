// SPDX-License-Identifier: GPL-2.0-only
// Host adaptation: authenticated binary packing only; no gameplay or pixels.
export const PROFILES = [
 {id:'freedoom',wadName:'freedoom1.wad',license:'Freedoom BSD-3-Clause; see test/fixtures/wad/COPYING.txt',name:'Freedoom 0.13.0',available:true,chunks:1755,lumps:3163,memoryPolicy:3,url:'/install-assets/freedoom1.wad',wadSha256:'7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d',bundleSha256:'d379076f21645cf7cc5acb056663d0faacc4065489a0ca99738479323c9f7a47',directorySha256:'4acf70e1a550810a0682365afb4a717b8258082e18962f898554eac4dbd1d012',chunkHashesSha256:'62a3aec2214b5b7776713b87435b010d6f6300929e3b169d0b6e7e03de01fb6a'},
 {id:'ultimate',wadName:'DOOM.WAD',license:'Commercial id Software IWAD supplied by user; do not distribute resource payloads',name:'Ultimate DOOM 1.9',available:true,chunks:756,lumps:2306,memoryPolicy:3,wadSha256:'6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f',bundleSha256:'1154fc21f0fa60e793ffb6da569b2293191dfc7f1791e0c083672b764917d7ba',directorySha256:'6c5e07c8ea410c014b2dc57959c214bae0783c78668fb119d32c6a5514d33287',chunkHashesSha256:'0ab133e15d4bcfe400cf7106b8dc1d26ca62f912ca1314eac69a6c0e2bdc8c04'},
 {id:'doom2',memoryPolicy:3,wadName:'DOOM2.WAD',license:'Commercial id Software IWAD supplied by user; do not distribute resource payloads',name:'DOOM II 1.9',available:false,wadSha256:'10d67824b11025ddd9198e8cfc87ca335ee6e2d3e63af4180fa9b8a471893255',md5:'25e1459ca71d321525f84628f45ca8cd',reason:'No authenticated DOOM II runtime is integrated. DOOM II gameplay compatibility is outside this installer.'}
];
export const hex = bytes => [...bytes].map(n=>n.toString(16).padStart(2,'0')).join('');
export const unhex = value => {
 if(!/^(?:[\da-f]{2})*$/i.test(value))throw Error('Invalid bytes');
 return Uint8Array.from(value.match(/../g)??[],n=>parseInt(n,16));
};
export const sha256 = async bytes => hex(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)));
export const word = value => BigInt.asUintN(256,BigInt(value)).toString(16).padStart(64,'0');
export const abiBytes = bytes => word(bytes.length)+hex(bytes).padEnd(Math.ceil(bytes.length/32)*64,'0');
export function canonical(value){
 if(Array.isArray(value))return '['+value.map(canonical).join(',')+']';
 if(value!==null&&typeof value==='object')return '{'+Object.keys(value).sort().map(key=>JSON.stringify(key)+':'+canonical(value[key])).join(',')+'}';
 return JSON.stringify(value).replace(/[\u007f-\uffff]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0'));
}
export async function authenticateIWAD(bytes,profile){
 if(!profile.wadSha256)throw Error(profile.reason);
 const digest=await sha256(bytes);
 if(digest!==profile.wadSha256)throw Error(`IWAD identity mismatch: select the exact ${profile.name} IWAD`);
 return {wadSha256:digest};
}
export async function prepareResources(bytes,profile){
 if(!profile.wadSha256)throw Error(profile.reason);
 if(await sha256(bytes)!==profile.wadSha256)throw Error(`IWAD identity mismatch: select the exact ${profile.name} IWAD`);
 const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength),decoder=new TextDecoder('latin1');
 if(bytes.length<12||decoder.decode(bytes.subarray(0,4))!=='IWAD')throw Error('Invalid IWAD');
 const count=view.getInt32(4,true),start=view.getInt32(8,true);
 if(count<0||start<12||start+count*16>bytes.length)throw Error('Invalid IWAD directory');
 const lumps=[];let length=0,palette;
 for(let id=0;id<count;id++){
  const at=start+id*16,offset=view.getInt32(at,true),size=view.getInt32(at+4,true),name=bytes.slice(at+8,at+16);
  if(offset<0||size<0||offset+size>bytes.length)throw Error('IWAD lump out of bounds');
  lumps.push({id,nameHex:hex(name),offset:length,length:size,sourceOffset:offset});length+=size;
  if(decoder.decode(name).split('\0')[0]==='PLAYPAL')palette=bytes.slice(offset,offset+768);
 }
 const blob=new Uint8Array(length),directory=new Uint8Array(count*16),dv=new DataView(directory.buffer);
 for(const lump of lumps){
  blob.set(bytes.subarray(lump.sourceOffset,lump.sourceOffset+lump.length),lump.offset);
  directory.set(unhex(lump.nameHex),lump.id*16);dv.setUint32(lump.id*16+8,lump.offset,true);dv.setUint32(lump.id*16+12,lump.length,true);
  delete lump.sourceOffset;
 }
 const manifest={schemaVersion:0,provenance:{kind:'wad',wadName:profile.wadName,wadSha256:profile.wadSha256,upstreamCommit:'a77dfb96cb91780ca334d0d4cfd86957558007e0',license:profile.license},byteOrder:'little-endian',blobByteLength:blob.length,blobSha256:await sha256(blob),lumps};
 const bundleSha256=await sha256(new TextEncoder().encode(canonical(manifest)));
 if(bundleSha256!==profile.bundleSha256||await sha256(directory)!==profile.directorySha256)throw Error('Packed resource identity mismatch');
 const chunks=[],hashBytes=new Uint8Array(Math.ceil(length/16384)*32);
 for(let at=0;at<length;at+=16384){
  const payload=blob.subarray(at,at+16384),runtime=new Uint8Array(payload.length+1);runtime.set(payload,1);
  const digest=await sha256(runtime);hashBytes.set(unhex(digest),chunks.length*32);chunks.push({payload,runtime,digest});
 }
 if(await sha256(hashBytes)!==profile.chunkHashesSha256)throw Error('Resource chunk identity mismatch');
 const resourceIdentity={schemaVersion:0,wadSha256:profile.wadSha256,bundleSha256,paletteSha256:await sha256(palette),paletteVariant:0};
 // Both integrated authenticated resource profiles share this exact palette pin.
 if(resourceIdentity.paletteSha256!=='fd895921b5d0a394612bb29852ed003d44d69f76dec31c0dc6b5d5fc7d63f7bb')throw Error('Palette identity mismatch');
 return {directory,chunks,resourceIdentity,palette:{schemaVersion:0,resourceIdentity,kind:'wad',encoding:'rgb8',colorCount:256,rgbHex:hex(palette)}};
}
