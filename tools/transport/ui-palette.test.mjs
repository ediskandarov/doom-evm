// SPDX-License-Identifier: GPL-2.0-only
import test from 'node:test';
import assert from 'node:assert/strict';
import { decodeFramePalette, FramePresentation, FRAME_PALETTE_TOPIC } from '../../web/ui-palette.mjs';
const word = n => BigInt(n).toString(16).padStart(64, '0');
const frame = id => ({ frameId: BigInt(id), inputSeq: id, log: { address: '0xabc', transactionHash: '0x' + word(id), blockHash: '0xdef' } });
const palette = id => ({ ...frame(id).log, topics: [FRAME_PALETTE_TOPIC, '0x'+word(id), '0x'+word(id)],
  data: '0x'+[1,9,0,128,768].map(word).join('')+'a5'.repeat(768) });
const receipt = id => ({ status: '0x1', ...frame(id).log, logs: [palette(id)] });

test('palette is bound to frame/transaction/address/block with exact RGB8 ABI', () => {
  const p = decodeFramePalette(palette(1), frame(1));
  assert.equal(p.palette, 9); assert.equal(p.rgb.length, 768); assert(p.rgb.every(x => x === 0xa5));
  for (const [field,value] of [['address','0x123'],['transactionHash','0x123'],['blockHash','0x123'],['removed',true],['data','0x00']]) {
    assert.throws(() => decodeFramePalette({ ...palette(1), [field]:value },frame(1)));
  }
  assert.throws(() => decodeFramePalette(palette(2),frame(1)));
  for (const values of [[0,9,0,128,768],[1,14,0,128,768],[1,9,5,128,768],[1,9,0,160,768],[1,9,0,128,767]]) {
    assert.throws(() => decodeFramePalette({ ...palette(1), data:'0x'+values.map(word).join('')+'00'.repeat(768) },frame(1)));
  }
});

test('slow older palette receipt cannot overwrite newer Canvas presentation', async () => {
  let completeOlder; const seen=[];
  const p = new FramePresentation(async (_, [hash]) => hash === frame(1).log.transactionHash
    ? new Promise(resolve => {completeOlder=resolve;}) : receipt(2), new Uint8Array(768), true, f => seen.push(f.frameId));
  const older = p.present(frame(1),'ws');
  assert.equal(await p.present(frame(2),'receipt'),true);
  completeOlder(receipt(1)); assert.equal(await older,false); assert.deepEqual(seen,[2n]);
});

test('missing/duplicate/reverted receipt palettes fail and invalidated sessions do not paint', async () => {
  for (const mined of [{...receipt(1),logs:[]},{...receipt(1),logs:[palette(1),palette(1)]},{...receipt(1),status:'0x0'}]) {
    const p = new FramePresentation(async () => mined, new Uint8Array(768),true,() => assert.fail('unexpected paint'));
    await assert.rejects(p.present(frame(1),'receipt'));
  }
  let complete;
  const p = new FramePresentation(() => new Promise(resolve => {complete=resolve;}),new Uint8Array(768),true,() => assert.fail('invalidated paint'));
  const pending=p.present(frame(1),'ws');p.invalidate();complete(receipt(1));assert.equal(await pending,false);
});

test('legacy presentation retains synchronous raw palette and needs no receipt RPC', async () => {
  const rgb = new Uint8Array(768);let seen;
  const p = new FramePresentation(() => assert.fail('legacy RPC'),rgb,false,(_,source,value) => {seen=[source,value];});
  const pending=p.present(frame(1),'backfill');assert.deepEqual(seen,['backfill',rgb]);assert.equal(await pending,true);
});
