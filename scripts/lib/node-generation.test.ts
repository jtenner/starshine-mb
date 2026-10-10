import { expect, test } from 'bun:test';
import { generateFfiPackage } from './ffi-generation';
import { parseTypeDescriptor } from './generate-node-package.mjs';

test('FFI schema retains authoritative signatures and optional forwarding semantics', () => {
  const generated = generateFfiPackage([{ alias: 'sample', packagePath: 'test/sample', interfaceText: `
pub type Module
pub fn parse(Bytes, filename? : String) -> Result[Module, String]
pub fn Module::new() -> Self
` }]);
  expect(generated.schema[0]).toMatchObject({
    sourceName: 'ffi_sample_parse', packageAlias: 'sample', name: 'parse',
    returnType: 'Result[@sample.Module, String]',
  });
  expect(generated.schema[0].params[1]).toMatchObject({ optional: true, type: 'String', name: 'filename' });
});

test('unknown or ambiguous JS type mappings fail generation', () => {
  expect(() => parseTypeDescriptor('UnresolvedType', { id: 'sample', types: new Map() })).toThrow();
  expect(() => parseTypeDescriptor('FixedArray[Int]', { id: 'sample', types: new Map() })).toThrow();
});

test('unsupported ABI policy accepts only the explicitly reviewed exceptions', async () => {
  const { assertUnsupportedAbiPolicy } = await import('./generate-node-package.mjs');
  const existing = [{ symbol: 'sample.callback', reason: 'callback requires an adapter' }];
  expect(() => assertUnsupportedAbiPolicy(existing, existing)).not.toThrow();
  expect(() => assertUnsupportedAbiPolicy([
    ...existing, { symbol: 'sample.new_callback', reason: 'callback requires an adapter' },
  ], existing)).toThrow('sample.new_callback');
});

test('unsupported ABI policy rejects changed reasons, stale entries, and duplicate symbols', async () => {
  const { assertUnsupportedAbiPolicy } = await import('./generate-node-package.mjs');
  const policy = [{ symbol: 'sample.callback', reason: 'callback requires an adapter' }];
  expect(() => assertUnsupportedAbiPolicy([
    { symbol: 'sample.callback', reason: 'new inaccessible type' },
  ], policy)).toThrow('reason changed');
  expect(() => assertUnsupportedAbiPolicy([], policy)).toThrow('stale');
  expect(() => assertUnsupportedAbiPolicy(policy, [...policy, ...policy])).toThrow('duplicate');
  expect(() => assertUnsupportedAbiPolicy([...policy, ...policy], policy)).toThrow('duplicate');
  expect(() => assertUnsupportedAbiPolicy([{ symbol: '', reason: '' }], policy)).toThrow('invalid');
});
