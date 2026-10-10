import assert from 'node:assert/strict';
import test from 'node:test';
import { liftValue, lowerValue } from '../internal/runtime.js';

test('opaque handles cannot be forged or mixed across types', () => {
  assert.throws(() => lowerValue({ kind: 'named', brand: 'lib.Module' }, {}, {}), TypeError);
});

test('i64 inputs reject lossy numeric conversion', () => {
  assert.throws(() => lowerValue({ kind: 'bigint' }, 9007199254740992, {}), TypeError);
});

test('Char inputs must contain exactly one scalar value', () => {
  assert.throws(() => lowerValue({ kind: 'char' }, 'ab', {}), TypeError);
});

test('integer and byte mappings reject values outside their declared range', () => {
  assert.throws(() => lowerValue({ kind: 'number', moonType: 'Int' }, 1.5, {}), TypeError);
  assert.throws(() => lowerValue({ kind: 'number', moonType: 'UInt' }, -1, {}), TypeError);
  assert.throws(() => lowerValue({ kind: 'bigint', moonType: 'UInt64' }, -1n, {}), TypeError);
  assert.throws(() => lowerValue({ kind: 'byte' }, 256, {}), TypeError);
});

test('unsigned ABI returns preserve their high bit', () => {
  assert.equal(liftValue({ kind: 'number', moonType: 'UInt' }, -1, {}), 4294967295);
  assert.equal(liftValue({ kind: 'bigint', moonType: 'UInt64' }, -1n, {}), 0xffffffffffffffffn);
});

test('handles remain tied to their owning Wasm instance', () => {
  const owner = {};
  const descriptor = { kind: 'named', brand: 'lib.Module' };
  const handle = liftValue(descriptor, 0, owner);
  assert.equal(lowerValue(descriptor, handle, owner), 0);
  assert.throws(() => lowerValue(descriptor, handle, {}), TypeError);
});

test('the public API runs the active optimizer with semantic roundtrips', async () => {
  const { binary, passes, validate, wast } = await import('../index.js');
  const parsed = wast.wastToBinaryModule('(module (func (export "answer") (result i32) i32.const 40 i32.const 2 i32.add))');
  assert.equal(parsed.ok, true);
  const before = binary.encodeModule(parsed.value);
  assert.equal(before.ok, true);
  const optimized = passes.optimizeModule(parsed.value, ['precompute', 'vacuum']);
  assert.equal(optimized.ok, true);
  assert.equal(validate.validateModule(optimized.value).ok, true);
  const after = binary.encodeModule(optimized.value);
  assert.equal(after.ok, true);
  assert.notDeepEqual(after.value, before.value);
  for (const bytes of [before.value, after.value]) {
    assert.equal(WebAssembly.validate(bytes), true);
    const { instance } = await WebAssembly.instantiate(bytes);
    assert.equal(instance.exports.answer(), 42);
  }
  assert.equal(passes.optimizeModule(parsed.value, ['definitely-unknown']).ok, false);
  assert.equal(wast.wastToBinaryModule('(module broken)').ok, false);
  assert.equal(binary.decodeModule(new Uint8Array([1, 2, 3])).ok, false);
  assert.equal(passes.optimizeModule(parsed.value, ['vacuum'], undefined, 1).ok, true);
});
