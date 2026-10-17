import assert from 'node:assert/strict';
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';

export async function observeRecordCopyOutlining({ binary, passes, validate, wast }) {
  const fields = 12;
  let update = 'local.get 0';
  for (let selected = fields - 1; selected >= 0; selected--) {
    const operands = Array.from({ length: fields }, (_, field) => field === selected
      ? `i32.const ${selected + 41}` : `local.get 0 struct.get $r ${field}`).join(' ');
    update = `local.get 1 i32.const ${selected} i32.eq if (result (ref null $r)) ${operands} struct.new $r else ${update} end`;
  }
  const source = `(module
    (type $r (struct ${'(field i32) '.repeat(fields)}))
    (import "env" "observe" (func $observe (param i32)))
    (func (export "make") (result (ref $r)) ${Array.from({ length: fields }, (_, i) => `i32.const ${100 + i}`).join(' ')} struct.new $r)
    (func (export "update") (param (ref null $r) i32) (result (ref null $r)) local.get 1 call $observe ${update})
    (func (export "same") (param (ref null $r) (ref null $r)) (result i32) local.get 0 local.get 1 ref.eq)
    ${Array.from({ length: fields }, (_, field) => `(func (export "read${field}") (param (ref null $r)) (result i32) local.get 0 struct.get $r ${field})`).join('\n')}
    (func (export "f") (result i32) i32.const 42)
    (func (export "g") (result i32) i32.const 42))`;
  const parsed = wast.wastToBinaryModule(source, 'record-copy.wat');
  assert.equal(parsed.ok, true);
  const before = binary.encodeModule(parsed.value);
  assert.equal(before.ok, true);
  const variants = [before.value];
  for (const [flags, optimize, shrink] of [[['merge-similar-functions'], undefined, undefined], [['optimize'], 4, 1]]) {
    // Each route must optimize its own unchanged input, even if a future pass
    // accidentally mutates a handle owned by its caller.
    const fresh = wast.wastToBinaryModule(source, 'record-copy.wat');
    assert.equal(fresh.ok, true);
    const result = passes.optimizeModule(fresh.value, flags, optimize, shrink);
    assert.equal(result.ok, true);
    assert.equal(validate.validateModule(result.value).ok, true);
    const encoded = binary.encodeModule(result.value);
    assert.equal(encoded.ok, true);
    assert(encoded.value.length < before.value.length * 0.75, 'record copies were not profitably outlined');
    variants.push(encoded.value);
  }
  const observations = [];
  for (const bytes of variants) {
    assert.equal(WebAssembly.validate(bytes), true);
    const events = [];
    const { instance } = await WebAssembly.instantiate(bytes, { env: { observe: value => events.push(value) } });
    const e = instance.exports;
    assert.notEqual(e.f, e.g, 'distinct public functions were merged');
    assert.equal(e.f(), 42);
    assert.equal(e.g(), 42);
    const old = e.make();
    let checks = 0;
    for (const selected of [0, 5, 11]) {
      const first = e.update(old, selected);
      const second = e.update(old, selected);
      assert.notEqual(first, old);
      assert.notEqual(first, second);
      assert.equal(e.same(first, old), 0);
      assert.equal(e.same(first, second), 0);
      for (let field = 0; field < fields; field++) {
        assert.equal(e[`read${field}`](old), 100 + field);
        assert.equal(e[`read${field}`](first), field === selected ? selected + 41 : 100 + field);
        assert.equal(e[`read${field}`](second), field === selected ? selected + 41 : 100 + field);
        checks += 3;
      }
    }
    assert.throws(() => e.update(null, 0), WebAssembly.RuntimeError);
    assert.throws(() => e.update(null, 11), WebAssembly.RuntimeError);
    assert.equal(e.update(null, 12), null);
    assert.equal(e.update(old, 12), old);
    assert.equal(e.same(old, old), 1);
    assert.deepEqual(events, [0, 0, 5, 5, 11, 11, 0, 11, 12, 12]);
    observations.push({ checks, events, traps: 2, freshCopies: 6, oldUnchanged: true, distinctPublicFunctions: true });
  }
  assert.deepEqual(observations[1], observations[0]);
  assert.deepEqual(observations[2], observations[0]);
  return { bytes: variants.map(bytes => bytes.length), observations };
}

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
  const recordCopy = await observeRecordCopyOutlining(api);
  const copyProfile = validate.genValidProfileByName('merge-similar-functions-record-copy');
  assert.equal(copyProfile.ok, true);
  assert.equal(validate.genValidProfileName(copyProfile.value), 'merge-similar-functions-record-copy');
  return { exports, observations, recordCopy, recordCopyProfile: validate.genValidProfileName(copyProfile.value), fuzz: fuzz.value, errors: [invalidText.display ?? invalidText.error, invalidBytes.display ?? binary.DecodeError.show(invalidBytes.error), badPass.error] };
}

if (process.argv[2]) process.stdout.write(`${JSON.stringify(await observePackage(process.argv[2]))}\n`);
