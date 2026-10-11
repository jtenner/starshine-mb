import { expect, test } from 'bun:test';
import { generateFfiPackage } from './ffi-generation';
import { parseTypeDescriptor } from './generate-node-package.mjs';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

test('registry release uses the authorized unscoped package name and default tag', () => {
  const manifest = JSON.parse(fs.readFileSync('node/package.json', 'utf8'));
  expect(manifest.name).toBe('starshine');
  expect(manifest.publishConfig.tag).toBe('latest');
  expect(manifest.private).not.toBe(true);
});

test('npm distributions carry scoped ownership and complete dependency license texts', () => {
  const manifest = JSON.parse(fs.readFileSync('node/package.json', 'utf8'));
  expect(manifest.license).toBe('SEE LICENSE IN LICENSE');
  for (const file of ['LICENSE', 'NOTICE', 'licenses/Apache-2.0.txt', 'licenses/Binaryen-LICENSE.txt', 'licenses/moonbit-core-NOTICE.txt']) {
    expect(manifest.files).toContain(file);
    expect(fs.readFileSync(`node/${file}`, 'utf8')).toBe(fs.readFileSync(file, 'utf8'));
  }
});

test('license generation restores missing notices and check mode rejects altered package notices', async () => {
  const { syncNpmLicenses } = await import('./npm-licenses.mjs');
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'npm-license-drift-'));
  try {
    for (const file of ['LICENSE', 'NOTICE', 'licenses/Apache-2.0.txt', 'licenses/Binaryen-LICENSE.txt', 'licenses/moonbit-core-NOTICE.txt']) {
      fs.mkdirSync(path.dirname(path.join(root, file)), { recursive: true });
      fs.copyFileSync(file, path.join(root, file));
    }
    syncNpmLicenses(root);
    fs.writeFileSync(path.join(root, 'node/licenses/moonbit-core-NOTICE.txt'), 'truncated notice');
    expect(() => syncNpmLicenses(root, { check: true })).toThrow('license drift');
    syncNpmLicenses(root);
    expect(() => syncNpmLicenses(root, { check: true })).not.toThrow();
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('an updated compiler dependency cannot build with stale reviewed notices', async () => {
  const { assertNpmDependencyLicenses } = await import('./npm-licenses.mjs');
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'npm-dependency-license-'));
  try {
    const core = path.join(root, 'core');
    fs.mkdirSync(core);
    fs.copyFileSync('licenses/Apache-2.0.txt', path.join(core, 'LICENSE'));
    fs.copyFileSync('licenses/moonbit-core-NOTICE.txt', path.join(core, 'NOTICE'));
    fs.writeFileSync(path.join(core, 'moon.mod'), 'name = "moonbitlang/core"\nversion = "0.10.14+7d59c7ec9"\nlicense = "Apache-2.0"\n');
    for (const prefix of ['', 'ffi/']) {
      const x = path.join(root, prefix, '.mooncakes/moonbitlang/x');
      fs.mkdirSync(x, { recursive: true });
      fs.writeFileSync(path.join(x, 'moon.mod'), 'name = "moonbitlang/x"\nversion = "0.5.1"\nlicense = "Apache-2.0"\n');
    }
    fs.cpSync('licenses', path.join(root, 'licenses'), { recursive: true });
    expect(() => assertNpmDependencyLicenses(root, core)).not.toThrow();
    fs.appendFileSync(path.join(core, 'NOTICE'), '\nnew upstream attribution\n');
    expect(() => assertNpmDependencyLicenses(root, core)).toThrow('NOTICE changed');
    fs.copyFileSync('licenses/moonbit-core-NOTICE.txt', path.join(core, 'NOTICE'));
    fs.appendFileSync(path.join(core, 'LICENSE'), '\nnew upstream term\n');
    expect(() => assertNpmDependencyLicenses(root, core)).toThrow('LICENSE changed');
    fs.copyFileSync('licenses/Apache-2.0.txt', path.join(core, 'LICENSE'));
    fs.writeFileSync(path.join(core, 'moon.mod'), 'version = "0.11.0"\nlicense = "Apache-2.0"\n');
    expect(() => assertNpmDependencyLicenses(root, core)).toThrow('version');
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('a clean FFI dependency tree is resolved before its license guard', async () => {
  const { prepareNpmDependencyLicenses } = await import('./npm-licenses.mjs');
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'npm-clean-dependency-license-'));
  try {
    const core = path.join(root, 'core');
    fs.mkdirSync(core);
    fs.copyFileSync('licenses/Apache-2.0.txt', path.join(core, 'LICENSE'));
    fs.copyFileSync('licenses/moonbit-core-NOTICE.txt', path.join(core, 'NOTICE'));
    fs.writeFileSync(path.join(core, 'moon.mod'), 'version = "0.10.14+7d59c7ec9"\nlicense = "Apache-2.0"\n');
    fs.cpSync('licenses', path.join(root, 'licenses'), { recursive: true });
    const manifest = 'version = "0.5.1"\nlicense = "Apache-2.0"\n';
    const rootX = path.join(root, '.mooncakes/moonbitlang/x');
    const ffiX = path.join(root, 'ffi/.mooncakes/moonbitlang/x');
    fs.mkdirSync(rootX, { recursive: true });
    fs.writeFileSync(path.join(rootX, 'moon.mod'), manifest);
    expect(fs.existsSync(ffiX)).toBe(false);
    const options = { moonBin: 'reviewed-moon', run: async (command, args, runOptions) => {
      expect(command).toBe('reviewed-moon');
      expect(args).toEqual(['-C', 'ffi', 'build', '--target', 'wasm-gc', '--release', 'src/npm', '--dry-run']);
      expect(runOptions.cwd).toBe(root);
      fs.mkdirSync(ffiX, { recursive: true });
      fs.writeFileSync(path.join(ffiX, 'moon.mod'), manifest);
    } };
    expect(await prepareNpmDependencyLicenses(root, core, options)).toMatchObject({ x: '0.5.1' });
    fs.writeFileSync(path.join(ffiX, 'NOTICE'), 'new upstream attribution');
    await expect(prepareNpmDependencyLicenses(root, core, options)).rejects.toThrow('NOTICE appeared');
    await expect(prepareNpmDependencyLicenses(root, core, { run: async () => { throw new Error('resolution failed'); } })).rejects.toThrow('resolution failed');
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

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
