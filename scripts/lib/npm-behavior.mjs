import assert from 'node:assert/strict';
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';

// Runs inside a standalone package copy or an installed consumer. No MoonBit,
// optimizer executable, source-tree fixtures, or repository imports are used.
export async function observePackage(packageRoot) {
  const api = await import(pathToFileURL(`${packageRoot}/index.js`));
  const manifest = JSON.parse(fs.readFileSync(`${packageRoot}/package.json`, 'utf8'));
  const exports = {};
  for (const [name, entry] of Object.entries(manifest.exports)) {
    const module = await import(pathToFileURL(`${packageRoot}/${entry.import}`));
    exports[name] = Object.keys(module).sort();
  }
  const { binary, cli, cmd, lib, passes, validate, wast, wat } = api;
  assert.equal(cmd.cmdVersionText(), `v${manifest.version}`, 'CLI/API version differs from packed metadata');
  const observations = [];
  for (const source of [
    '(module (func (export "answer") (result i32) i32.const 40 i32.const 2 i32.add))',
    '(module (func (export "answer") (result i32) (local i32) i32.const 7 local.set 0 local.get 0))',
    '(module (type $s (struct (field i32))) (func (export "answer") (result i32) i32.const 9 struct.new $s struct.get $s 0))',
  ]) {
    const parsed = wast.wastToBinaryModule(source, 'consumer.wat');
    assert.equal(parsed.ok, true);
    const before = binary.encodeModule(parsed.value);
    assert.equal(before.ok, true);
    const optimized = passes.optimizeModule(parsed.value, ['precompute', 'vacuum'], undefined, 1);
    assert.equal(optimized.ok, true);
    assert.equal(validate.validateModule(optimized.value).ok, true);
    const after = binary.encodeModule(optimized.value, false);
    assert.equal(after.ok, true);
    assert.equal(binary.decodeModule(after.value).ok, true);
    assert.equal(wat.libModuleToWat(optimized.value).ok, true);
    const values = [];
    for (const bytes of [before.value, after.value]) {
      assert.equal(WebAssembly.validate(bytes), true);
      const { instance } = await WebAssembly.instantiate(bytes);
      values.push(instance.exports.answer());
    }
    assert.equal(values[0], values[1]);
    const o4s = passes.optimizeModule(parsed.value, ['optimize'], 4, 1);
    assert.equal(o4s.ok, true);
    assert.equal(validate.validateModule(o4s.value).ok, true);
    const o4sBytes = binary.encodeModule(o4s.value);
    assert.equal(o4sBytes.ok, true);
    const o4sInstance = await WebAssembly.instantiate(o4sBytes.value);
    assert.equal(o4sInstance.instance.exports.answer(), values[0]);
    observations.push({ values, before: [...before.value], after: [...after.value], o4s: [...o4sBytes.value] });
  }
  assert.equal(binary.sizeUnsigned(255n, 32).ok, true);
  assert.equal(cli.resolvePassFlags(cli.parseCliArgs(['--help']).value).length, 0);
  const format = cli.CliInputFormat.wasm();
  const trapMode = cli.TrapMode.never();
  assert.equal(typeof cli.CliInputFormat.show(format), 'string');
  assert.equal(typeof cli.CliParseResult.new(undefined, [], undefined, undefined, undefined, undefined, undefined, format, undefined, undefined, undefined, trapMode), 'object');
  assert.equal(typeof lib.NumType.show(lib.NumType.i32()), 'string');
  assert.throws(() => binary.encodeModule({}), TypeError);
  assert.throws(() => binary.sizeUnsigned(-1n, 32), TypeError);
  assert.throws(() => cli.CliInputFormat.show(trapMode), TypeError);
  const stdout = [];
  const io = cmd.CmdIO.new(undefined, undefined, undefined, undefined, undefined, bytes => { stdout.push(new TextDecoder().decode(bytes)); return { ok: true, value: undefined }; });
  assert.equal(cmd.runCmdWithAdapter(['--help'], io).ok, true);
  assert.match(stdout.join(''), /Starshine Wasm Binary Toolkit/);
  assert.equal(cmd.runCmdWithAdapter([], cmd.CmdIO.new(), JSON.stringify({ optimize: { preset: 'osize' } })).ok, false);
  const fuzz = cmd.runCmdFuzzHarness(1, 0x5eedn, [], null, 0, null);
  assert.equal(fuzz.ok, true);
  assert.equal(fuzz.value.generatedValid, 1);
  const invalidText = wast.wastToBinaryModule('(module broken)');
  const invalidBytes = binary.decodeModule(new Uint8Array([1, 2, 3]));
  assert.equal(invalidText.ok, false);
  assert.equal(invalidBytes.ok, false);
  const badPass = passes.optimizeModule(wast.wastToBinaryModule('(module)').value, ['unknown-pass']);
  assert.equal(badPass.ok, false);
  return { exports, observations, fuzz: fuzz.value, errors: [invalidText.display ?? invalidText.error, invalidBytes.display ?? binary.DecodeError.show(invalidBytes.error), badPass.error] };
}

if (process.argv[2]) process.stdout.write(`${JSON.stringify(await observePackage(process.argv[2]))}\n`);
