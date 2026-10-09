// SPDX-License-Identifier: GPL-2.0-only
import test from 'node:test';
import assert from 'node:assert/strict';
import { FRAME_TOPIC, decodeFrame, FrameInbox, expandPalette, stepData } from '../../web/protocol.mjs';
const word = n => BigInt(n).toString(16).padStart(64, '0');
const log = (id = 1, seq = id) => ({ topics: [FRAME_TOPIC, '0x'+word(id), '0x'+word(seq)], data: '0x'+word(2)+word(1)+word(96)+word(2)+'00ff'+'00'.repeat(30), transactionHash: '0x'+word(id), logIndex: '0x0' });
test('strict ABI decode and palette expansion only', () => {
  const frame = decodeFrame(log());
  assert.deepEqual([...frame.pixels], [0,255]);
  const rgb = new Uint8Array(768); rgb[767] = 99;
  assert.deepEqual([...expandPalette(frame,rgb)], [0,0,0,255,0,0,99,255]);
  assert.throws(() => decodeFrame({...log(),data:log().data.slice(0,-2)}));
  assert.throws(() => decodeFrame({...log(),topics:[FRAME_TOPIC]}));
  assert.throws(() => stepData(0));
  assert.equal(stepData(1).length,138);
});
test('duplicates, out-of-order delivery, gaps and removed logs', () => {
  const shown = [], inbox = new FrameInbox(f => shown.push(f.frameId));
  inbox.accept(log(2),'ws'); inbox.accept(log(2),'receipt'); inbox.accept(log(1),'backfill'); inbox.accept(log(4),'receipt');
  assert.deepEqual(shown,[2n,4n]); assert.equal(inbox.duplicates,1); assert.equal(inbox.stale,1);
  assert.throws(() => inbox.accept({...log(4),removed:true},'ws'), /Removed/);
});
