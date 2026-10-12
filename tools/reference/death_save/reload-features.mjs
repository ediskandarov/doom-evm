// SPDX-License-Identifier: GPL-2.0-only
// Bounded supplemental gate; all combined-death scenarios retain their own report.
import assert from 'node:assert/strict';
import {decodeSlot} from '../save_load/browser-features.mjs';
const word=n=>BigInt(n).toString(16).padStart(64,'0');
export async function verifyReloadSetup(game,{keys,readGame,rpc,report,install,evaluate,until}){
 await evaluate('window.fixtureClient.startGame();true');
 await until(()=>evaluate('!!window.__tick&&!window.fixtureClient.loop.starting'),'supplemental active keyboard loop');
 const fresh=await keys([],game+' supplemental current gameplay framebuffer');
 const before=await readGame(game,'playerView()'),pixel=fresh.pixelSha256;
 await keys(['F2'],game+' supplemental Save menu');assert.equal((await evaluate('window.fixtureClient.transactions.menuStatus()')).screen,6);
 const selected=(await evaluate('window.fixtureClient.transactions.menuStatus()')).item;
 await keys([...Array((6-selected)%6).fill('ArrowDown'),'Enter'],game+' supplemental slot zero');
 await keys(['KeyR','KeyE','KeyL','KeyO','KeyA','KeyD','Enter'],game+' supplemental snapshot');
 const raw=await rpc('eth_call',[{to:install.config.address,data:'0x'+install.methods['readSaveSlot(uint8)']+word(0),gas:'0x2540be400'},'latest']);
 const s=decodeSlot(raw);assert(s.occupied&&s.compatible&&s.policy===3);assert.equal(await readGame(game,'playerView()'),before);assert.equal(report.frames.at(-1).pixelSha256,pixel);
 report.saveSlots??={};report.saveSlots[game]={slot0ABI:raw,slot0:s};
 report.combined??={};report.combined[game]={scope:'reload supplemental setup only',alivePixels:pixel,aliveView:before,aliveDigest:s.digest};
 report.checks.push({label:game+' supplemental exact no-tic snapshot before browser reload',pass:true});
}
