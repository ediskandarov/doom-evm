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
  const keyup = event => { if (keyboard.update(event.code, false) && enabled()) event.preventDefault(); };
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
