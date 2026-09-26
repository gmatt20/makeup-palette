import { test } from 'node:test';
import assert from 'node:assert/strict';
import { emptyLook, validateLook, setMakeup, clearTreatment, composePixels, colorFromHex, colorToHex } from './look.mjs';

test('replacement, isolated clear, JSON restoration, and trust-boundary validation', () => {
  const red = colorFromHex('#c03060');
  const start = emptyLook();
  const lips = setMakeup(start, 'lipstick', red, 0.75);
  const both = setMakeup(lips, 'blush', colorFromHex('#ec9482'), 0.3);
  assert.deepEqual(start, emptyLook());
  assert.deepEqual(setMakeup(both, 'lipstick', red, 0.75), both);
  assert.deepEqual(clearTreatment(both, 'blush'), lips);
  assert.deepEqual(validateLook(JSON.parse(JSON.stringify(both))), both);
  assert.equal(colorToHex(red), '#c03060');
  for (const value of [-1, 1.1, NaN, Infinity, '0.5', null]) {
    assert.throws(() => setMakeup(lips, 'blush', red, value));
    assert.throws(() => setMakeup(lips, 'blush', { ...red, blue: value }, 0.5));
  }
  assert.throws(() => setMakeup(lips, 'unknown', red, 0.5));
  assert.throws(() => validateLook({ version: 2, treatments: {} }));
  assert.throws(() => validateLook({ version: 1, treatments: [] }));
  assert.deepEqual(lips.treatments.lipstick.color, red);
});

test('masked blend preserves excluded pixels, source detail, deterministic layer order, and original', () => {
  const original = new Uint8ClampedArray([200, 150, 100, 255, 120, 120, 120, 255]);
  const masks = { lipstick: new Uint8Array([255, 0]), blush: new Uint8Array([128, 255]) };
  const red = { red: 1, green: 0, blue: 0 };
  const lips = setMakeup(emptyLook(), 'lipstick', red, 1);
  assert.deepEqual([...composePixels(original, masks, lips)], [201, 30, 20, 255, 120, 120, 120, 255]);
  assert.deepEqual(composePixels(original, masks, emptyLook()), original);
  assert.deepEqual(composePixels(original, masks, setMakeup(lips, 'lipstick', red, 0)), original);
  const a = setMakeup(lips, 'blush', colorFromHex('#ff8080'), 0.4);
  const b = setMakeup(setMakeup(emptyLook(), 'blush', colorFromHex('#ff8080'), 0.4), 'lipstick', red, 1);
  assert.deepEqual(composePixels(original, masks, a), composePixels(original, masks, b));
  assert.throws(() => composePixels(original, {}, lips));
  assert.deepEqual([...original], [200, 150, 100, 255, 120, 120, 120, 255]);
});
