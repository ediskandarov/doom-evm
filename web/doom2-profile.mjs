// SPDX-License-Identifier: GPL-2.0-only
// Isolated profile adapter. Shared launcher wiring belongs to the Git integrator.
import {prepareResources} from './install-resources.mjs';
export const DOOM2_PROFILE=Object.freeze({id:'doom2',wadName:'DOOM2.WAD',license:'Commercial id Software IWAD supplied by user; do not distribute resource payloads',name:'DOOM II 1.9',available:true,
 wadSha256:'10d67824b11025ddd9198e8cfc87ca335ee6e2d3e63af4180fa9b8a471893255',md5:'25e1459ca71d321525f84628f45ca8cd',
 bundleSha256:'775bc8b01d44c2fb1c3a68a79b9864c2f36ebbb29746d31e9ca600ae226af5ad',
 directorySha256:'2d91a39dcf822b968a3719ef79bc2a7880b634432522300c575a76b970022515',
 chunkHashesSha256:'903d131f726847ec2afc79d24fa0a1c08d7c03fbacb135d23808d9a5b4a299c9',
 memoryProfile:3,memoryProfileName:'virtual',chunks:889,lumps:2919,blobBytes:14557275,mapRange:[1,32],memoryPolicy:'explicit deterministic virtual-pointer compatibility; unknown bytes rejected',memoryStatusAPI:'selectedMemoryProfile()',initializationAPI:'initializeMenuWithMemoryProfile(bool,uint8)'});
// Shared packing now accepts the exact filename/license metadata directly.
// Resource bytes, dimensions, directory and canonical bundle pin are unchanged.
export function prepareDoom2Resources(bytes){return prepareResources(bytes,DOOM2_PROFILE);}
