// SPDX-License-Identifier: GPL-2.0-only
// One durable record per local RPC / driver / release. Commercial WAD bytes are
// intentionally never journaled. IndexedDB atomic commits precede RPC submission.
export class InstallStorage {
 async open(){
  if(this.db)return;
  this.db=await new Promise((resolve,reject)=>{
   const request=indexedDB.open('doom-evm-installations',1);
   request.onupgradeneeded=()=>request.result.createObjectStore('journals');
   request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error);
  });
 }
 async read(key){await this.open();return new Promise((resolve,reject)=>{const tx=this.db.transaction('journals'),r=tx.objectStore('journals').get(key);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});}
 async write(key,value){await this.open();return new Promise((resolve,reject)=>{const tx=this.db.transaction('journals','readwrite');tx.objectStore('journals').put(value,key);tx.oncomplete=()=>resolve();tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error??Error('Journal commit aborted'));});}
}
