// SPDX-License-Identifier: GPL-2.0-only
// Keyboard sampling and input packet encoding only. All gameplay runs in the EVM.
import { STEP_SELECTOR } from './protocol.mjs';

const bindings = new Map([
  ['ArrowUp', 0], ['KeyW', 0], ['ArrowDown', 1], ['KeyS', 1],
  ['Comma', 2], ['KeyA', 2], ['Period', 3], ['KeyD', 3],
  ['ArrowLeft', 4], ['ArrowRight', 5], ['Space', 6], ['KeyE', 6],
  ['ControlLeft', 7], ['ControlRight', 7],
  ['ShiftLeft', 8], ['ShiftRight', 8], ['AltLeft', 9], ['AltRight', 9],
]);

export function validateInputMask(mask) {
  if (!Number.isInteger(mask) || mask < 0 || mask > 0xffffffff
      || (mask & ~0x3fff) !== 0 || ((mask >>> 10) & 15) > 9) {
    throw Error('Invalid input mask');
  }
  return mask;
}

export function inputStepData(mask, sequence) {
  validateInputMask(mask);
  if (!Number.isInteger(sequence) || sequence < 1 || sequence > 0xffffffff) {
    throw Error('Invalid input sequence');
  }
  return STEP_SELECTOR + mask.toString(16).padStart(64, '0')
    + sequence.toString(16).padStart(64, '0');
}

export const EVENTS_STEP_SELECTOR = '0x9a5b61ba';
export const EVENTS_NO_RENDER_SELECTOR = '0xb3041722';

export function eventStepData(events, sequence, draw = true) {
  if (!(events instanceof Uint8Array) || events.length > 128 || events.length % 2 !== 0) {
    throw Error('Invalid keyboard events');
  }
  for (let i = 0; i < events.length; i += 2) {
    if (events[i] > 1) throw Error('Invalid keyboard event type');
  }
  if (!Number.isInteger(sequence) || sequence < 1 || sequence > 0xffffffff) throw Error('Invalid input sequence');
  const word = n => n.toString(16).padStart(64, '0');
  const hex = [...events].map(n => n.toString(16).padStart(2, '0')).join('');
  return (draw ? EVENTS_STEP_SELECTOR : EVENTS_NO_RENDER_SELECTOR) + word(64) + word(sequence)
    + word(events.length) + hex.padEnd(Math.ceil(events.length / 32) * 64, '0');
}

// i_video.c:xlatekey uses unshifted key symbols, lowercase letters and original
// DOOM special-key numbers. Translation does not recognize codes or compute actions.
export function nativeKey(code) {
  if (/^Key[A-Z]$/.test(code)) return code.charCodeAt(3) + 32;
  if (/^Digit[0-9]$/.test(code)) return code.charCodeAt(5);
  if (/^F([1-9]|1[0-2])$/.test(code)) {
    const n = Number(code.slice(1));
    return n <= 10 ? 0xba + n : 0xcc + n;
  }
  return ({ ArrowRight: 0xae, ArrowLeft: 0xac, ArrowUp: 0xad, ArrowDown: 0xaf,
    Tab: 9, Enter: 13, Escape: 27, Space: 32, Backspace: 127, Delete: 127,
    Equal: 61, NumpadEqual: 61, Minus: 45, NumpadSubtract: 45, Comma: 44, Period: 46,
    Semicolon: 59, Quote: 39, BracketLeft: 91, BracketRight: 93, Backslash: 92,
    Backquote: 96, Slash: 47, IntlBackslash: 60,
    ShiftLeft: 0xb6, ShiftRight: 0xb6, ControlLeft: 0x9d, ControlRight: 0x9d,
    AltLeft: 0xb8, AltRight: 0xb8, Pause: 255 })[code];
}

export class RawKeyboardInput {
  constructor() { this.raw = true; this.heldCodes = new Set(); this.events = []; }
  update(code, down) {
    const key = nativeKey(code);
    if (key === undefined) return false;
    if (down) this.heldCodes.add(code); else this.heldCodes.delete(code);
    this.events.push(down ? 0 : 1, key); // Repeat keydown is an original event too.
    return true;
  }
  clear() {
    const keys = new Set([...this.heldCodes].map(nativeKey));
    this.heldCodes.clear();
    for (const key of keys) this.events.push(1, key);
  }
  packet() { return Uint8Array.from(this.events.slice(0, 128)); }
  acknowledge(count) { this.events.splice(0, count); }
}

export class KeyboardInput {
  constructor() { this.heldCodes = new Set(); }
  // Physical key codes distinguish aliases; releasing one alias retains another held alias.
  update(code, down) {
    if (!bindings.has(code) && !/^Digit[1-9]$/.test(code)) return false;
    if (down) this.heldCodes.add(code); else this.heldCodes.delete(code);
    return true;
  }
  clear() { this.heldCodes.clear(); }
  sample() {
    let mask = 0;
    let weapon = 0;
    for (const code of this.heldCodes) {
      if (bindings.has(code)) mask |= 1 << bindings.get(code);
      else {
        const request = Number(code.slice(5));
        // Original G_BuildTiccmd scans ascending digits 1..8; 9 is ignored.
        // When 9 is held alongside another digit, the recognized lower digit wins.
        if (weapon === 0 || request < weapon) weapon = request;
      }
    }
    return validateInputMask(mask | (weapon << 10));
  }
}

// Optional native DOM binding; blur/hidden resets held keys to avoid stuck input.
// Caller samples once per accepted tic and submits via its existing transaction queue.
export function bindKeyboard(target, keyboard = new KeyboardInput(), visibilityTarget = target.document,
  { enabled = () => true, onReset = () => {} } = {}) {
  const keydown = event => { if (enabled() && keyboard.update(event.code, true)) event.preventDefault(); };
  const keyup = event => {
    if ((!keyboard.raw || enabled()) && keyboard.update(event.code, false) && enabled()) event.preventDefault();
  };
  const clear = () => { keyboard.clear(); onReset('blur'); };
  const visibility = () => { if (visibilityTarget.hidden) { keyboard.clear(); onReset('hidden'); } };
  target.addEventListener('keydown', keydown);
  target.addEventListener('keyup', keyup);
  target.addEventListener('blur', clear);
  visibilityTarget?.addEventListener('visibilitychange', visibility);
  return { keyboard, dispose() {
    target.removeEventListener('keydown', keydown);
    target.removeEventListener('keyup', keyup);
    target.removeEventListener('blur', clear);
    visibilityTarget?.removeEventListener('visibilitychange', visibility);
    keyboard.clear(); onReset('dispose');
  } };
}
