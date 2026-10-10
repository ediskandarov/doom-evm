// Download only a publicly author-linked archive; session credentials remain local.
import {ProtonDriveClient, OpenPGPCryptoWithCryptoProxy, MemoryCache} from '@protontech/drive-sdk';
import {CryptoProxy} from '@protontech/crypto';
import {Api} from '@protontech/crypto/proxy/endpoint/api.ts';
import {getSrp, computeKeyPassword, generateKeySalt} from '@protontech/crypto/srp';
import {writeFile} from 'node:fs/promises';
Uint8Array.fromBase64 ??= (s) => new Uint8Array(Buffer.from(s,'base64'));
Uint8Array.prototype.toBase64 ??= function(){return Buffer.from(this).toString('base64')};
Uint8Array.prototype.toHex ??= function(){return Buffer.from(this).toString('hex')};
Uint8Array.fromHex ??= s=>new Uint8Array(Buffer.from(s,'hex'));
Api.init({}); CryptoProxy.setEndpoint(new Api());
const fetchRequest = r => {r.headers.set("x-pm-appversion","web-drive@5.0.0");return fetch(r.url,{method:r.method,headers:r.headers,body:r.json?JSON.stringify(r.json):r.body,signal:r.signal??AbortSignal.timeout(r.timeoutMs)});};
const client=new ProtonDriveClient({httpClient:{fetchJson:fetchRequest,fetchBlob:fetchRequest},entitiesCache:new MemoryCache(),cryptoCache:new MemoryCache(),account:{getPublicKeys:async()=>[]},openPGPCryptoModule:new OpenPGPCryptoWithCryptoProxy(CryptoProxy),srpModule:{getSrp:(version,modulus,serverEphemeral,salt,password)=>getSrp({Version:version,Modulus:modulus,ServerEphemeral:serverEphemeral,Salt:salt},{username:'',password}),computeKeyPassword,generateKeySalt},config:{baseUrl:'drive.proton.me/api'}});
const link=process.argv[2];
console.log(await client.experimental.getURLAccessInfo(link));
const publicClient=await client.experimental.authURLAccess(link,undefined,true);
const root=await publicClient.getRootNode();console.log({name:root.name, mediaType:root.mediaType});
if (!root.name.ok || root.type !== 'file') throw Error('Public share is not a named file');
const dl=await publicClient.getFileDownloader(root.uid);const chunks=[];
const controller=dl.downloadToStream(new WritableStream({write(c){chunks.push(c)}}));
await controller.completion(); // Do not accept signature/integrity failures.
await writeFile(process.argv[3],Buffer.concat(chunks));console.log('Downloaded',Buffer.concat(chunks).length);
