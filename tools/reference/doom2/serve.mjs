// SPDX-License-Identifier: GPL-2.0-only
// Goal-owned verification server; never write shared launcher/config files.
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {resolve,sep} from 'node:path';
export async function serve(port=0,root=resolve('web')){
 const server=createServer(async(req,res)=>{
  const path=resolve(root,'.'+new URL(req.url,'http://localhost').pathname.replace(/\/$/,'/index.html'));
  if(!path.startsWith(root+sep)){res.writeHead(403).end();return;}
  try{const bytes=await readFile(path);res.setHeader('Content-Type',path.endsWith('.html')?'text/html':path.endsWith('.mjs')?'text/javascript':'application/json');res.setHeader('Cache-Control','no-store');res.end(bytes);}catch{res.writeHead(404).end('Not found');}
 });await new Promise((done,fail)=>{server.once('error',fail);server.listen(port,'127.0.0.1',done);});return server;
}
