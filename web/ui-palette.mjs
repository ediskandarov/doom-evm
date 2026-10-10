// SPDX-License-Identifier: GPL-2.0-only
// Frame-associated EVM RGB8 only. No palette selection, gamma or UI drawing on the host.
export const FRAME_PALETTE_TOPIC = '0x825066992538b2e606a945966c0bd63dc4689e1f8efbdaed06e2d9602b4d275f';

export function decodeFramePalette(log, frame) {
  if (log.removed || log.address?.toLowerCase() !== frame.log.address?.toLowerCase()
    || log.transactionHash?.toLowerCase() !== frame.log.transactionHash?.toLowerCase()
    || log.blockHash?.toLowerCase() !== frame.log.blockHash?.toLowerCase()
    || log.topics?.length !== 3 || log.topics[0]?.toLowerCase() !== FRAME_PALETTE_TOPIC
    || BigInt(log.topics[1]) !== frame.frameId || BigInt(log.topics[2]) !== BigInt(frame.inputSeq)) {
    throw Error('Frame palette identity mismatch');
  }
  if (!/^0x[\da-f]{1856}$/i.test(log.data)) throw Error('Malformed Frame palette');
  const word = i => BigInt('0x' + log.data.slice(2 + i * 64, 66 + i * 64));
  const revision = word(0), palette = word(1), gamma = word(2);
  if (revision < 1n || revision > 0xffffffffn || palette > 13n || gamma > 4n
    || word(3) !== 128n || word(4) !== 768n) throw Error('Invalid Frame palette');
  return { revision: Number(revision), palette: Number(palette), gamma: Number(gamma),
    rgb: Uint8Array.from(log.data.slice(322).match(/../g), x => parseInt(x, 16)) };
}

export class FramePresentation {
  constructor(rpc, rgb, requirePalette, onFrame) {
    this.rpc = rpc; this.rgb = rgb; this.requirePalette = requirePalette; this.onFrame = onFrame;
    this.latest = 0n; this.invalidated = false;
  }
  invalidate() { this.invalidated = true; }
  async present(frame, source) {
    if (this.invalidated || frame.frameId <= this.latest) return false;
    this.latest = frame.frameId;
    let rgb = this.rgb, palette;
    // Active UI gameplay requires a companion from the same mined transaction.
    if (this.requirePalette) {
      const mined = await this.rpc('eth_getTransactionReceipt', [frame.log.transactionHash]);
      if (mined?.status !== '0x1' || mined.transactionHash?.toLowerCase() !== frame.log.transactionHash.toLowerCase()
        || mined.blockHash?.toLowerCase() !== frame.log.blockHash.toLowerCase()) throw Error('Frame receipt identity mismatch');
      const logs = mined.logs.filter(log => log.address?.toLowerCase() === frame.log.address.toLowerCase()
        && log.topics?.[0]?.toLowerCase() === FRAME_PALETTE_TOPIC);
      if (logs.length !== 1) throw Error('UI Frame must have exactly one palette');
      palette = decodeFramePalette(logs[0], frame); rgb = palette.rgb;
    }
    // A slow receipt for an older Frame must never overwrite a newer Canvas.
    if (this.invalidated || frame.frameId !== this.latest) return false;
    this.onFrame(frame, source, rgb, palette);
    return true;
  }
}
