// SPDX-License-Identifier: GPL-2.0-only
import test from 'node:test';
import assert from 'node:assert/strict';
import { KeyboardInput, validateInputMask, inputStepData, bindKeyboard } from './input.mjs';
import { STEP_SELECTOR, stepData } from './protocol.mjs';

test('all valid packets encode exact existing uint32,uint32 ABI', () => {
  for (let weapon = 0; weapon <= 9; weapon++) {
    for (let keys = 0; keys < 1024; keys++) {
      const mask = keys | (weapon << 10);
      const data = inputStepData(mask, 0xffffffff);
      assert.equal(data.length, 138);
      assert.equal(data.slice(0, 10), STEP_SELECTOR);
      assert.equal(BigInt('0x' + data.slice(10, 74)), BigInt(mask));
      assert.equal(BigInt('0x' + data.slice(74)), 0xffffffffn);
    }
  }
  assert.equal(inputStepData(0, 1), stepData(1));
});

test('reserved and malformed packets/sequences rejected', () => {
  for (const value of [-1, 0.5, NaN, Infinity, 0x100000000, '1', null]) {
    assert.throws(() => validateInputMask(value));
  }
  for (let bit = 14; bit < 32; bit++) assert.throws(() => validateInputMask(2 ** bit));
  for (let weapon = 10; weapon < 16; weapon++) assert.throws(() => validateInputMask(weapon << 10));
  for (const sequence of [0, -1, 1.5, 0x100000000, NaN, '1']) {
    assert.throws(() => inputStepData(0, sequence));
  }
});

test('held keys, alias release, modifiers and original lowest-digit priority', () => {
  const keyboard = new KeyboardInput();
  assert.equal(keyboard.update('Unbound', true), false);
  keyboard.update('KeyW', true); keyboard.update('ArrowUp', true);
  assert.equal(keyboard.sample(), 1);
  keyboard.update('KeyW', false);
  assert.equal(keyboard.sample(), 1);
  keyboard.update('KeyS', true); keyboard.update('KeyD', true);
  keyboard.update('ArrowLeft', true); keyboard.update('Space', true);
  keyboard.update('ControlLeft', true); keyboard.update('ShiftRight', true);
  keyboard.update('AltLeft', true);
  keyboard.update('Digit9', true); keyboard.update('Digit3', true);
  assert.equal(keyboard.sample(), 1 | 2 | 8 | 16 | 64 | 128 | 256 | 512 | (3 << 10));
  assert.equal(keyboard.sample(), keyboard.sample()); // sampling preserves held input
  keyboard.update('Digit1', true);
  assert.equal(keyboard.sample() >>> 10, 1);
  keyboard.update('Digit1', false); keyboard.update('Digit3', false);
  assert.equal(keyboard.sample() >>> 10, 9);
  keyboard.clear(); assert.equal(keyboard.sample(), 0);
});

test('all logical keyboard bits map independently', () => {
  const keyboard = new KeyboardInput();
  const codes = ['ArrowUp', 'ArrowDown', 'Comma', 'Period', 'ArrowLeft', 'ArrowRight',
    'Space', 'ControlLeft', 'ShiftLeft', 'AltLeft'];
  codes.forEach((code, bit) => {
    keyboard.clear(); keyboard.update(code, true);
    assert.equal(keyboard.sample(), 1 << bit);
  });
});

test('binding handles repeats, focus loss, visibility and disposal', () => {
  const target = new EventTarget();
  const document = new EventTarget(); document.hidden = false;
  const { keyboard, dispose } = bindKeyboard(target, undefined, document);
  const key = (type, code) => {
    const event = new Event(type, { cancelable: true }); event.code = code;
    target.dispatchEvent(event); return event;
  };
  assert.equal(key('keydown', 'KeyW').defaultPrevented, true);
  key('keydown', 'KeyW'); assert.equal(keyboard.sample(), 1);
  key('keyup', 'KeyW'); assert.equal(keyboard.sample(), 0);
  assert.equal(key('keydown', 'Unbound').defaultPrevented, false);
  key('keydown', 'KeyW'); target.dispatchEvent(new Event('blur'));
  assert.equal(keyboard.sample(), 0);
  key('keydown', 'KeyW'); document.hidden = true;
  document.dispatchEvent(new Event('visibilitychange'));
  assert.equal(keyboard.sample(), 0);
  key('keydown', 'KeyW'); dispose(); assert.equal(keyboard.sample(), 0);
  assert.equal(key('keydown', 'KeyW').defaultPrevented, false);
  assert.equal(keyboard.sample(), 0);
});
