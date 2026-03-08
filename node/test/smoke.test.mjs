import assert from 'node:assert/strict';
import childProcess from 'node:child_process';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { binary, cli, cmd, passes, validate, wast } from '../index.js';
import { runWasmStart } from '../internal/wasi-runner.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

test('wast and binary adapters roundtrip a binary module', () => {
  const parsed = wast.wastToBinaryModule('(module (func (export "run")))');
  assert.equal(parsed.ok, true);

  const encoded = binary.encodeModule(parsed.value);
  assert.equal(encoded.ok, true);
  assert(encoded.value instanceof Uint8Array);
  assert(encoded.value.length > 0);

  const decoded = binary.decodeModule(encoded.value);
  assert.equal(decoded.ok, true);

  const validated = validate.validateModule(decoded.value);
  assert.equal(validated.ok, true);
});

test('cli adapter honors omitted optional arguments', () => {
  const parsed = cli.parseCliArgs(['--help']);
  assert.equal(parsed.ok, true);
  assert.deepEqual(cli.resolvePassFlags(parsed.value), []);
});

test('binary adapter lifts bigint arguments', () => {
  const sized = binary.sizeUnsigned(255n, 32);
  assert.equal(sized.ok, true);
  assert.equal(typeof sized.value, 'number');
});

test('passes module exposes ordered manual pass constructors', () => {
  const parsed = wast.wastToBinaryModule('(module (func (export "run") nop drop unreachable))');
  assert.equal(parsed.ok, true);

  const options = passes.OptimizeOptions.new();
  const pipeline = passes.defaultFunctionOptimizationPasses(parsed.value, options);
  pipeline.push(passes.deadArgumentElimination());
  pipeline.push(passes.vacuum());

  const optimized = passes.optimizeModuleWithOptions(parsed.value, pipeline, options);
  assert.equal(optimized.ok, true);
  assert.match(passes.ModulePass.show(pipeline.at(-2)), /DeadArgumentElimination/);
  assert.match(passes.ModulePass.show(pipeline.at(-1)), /Vacuum/);
});

test('passes module replays optimize trace logs through a JS callback', () => {
  const parsed = wast.wastToBinaryModule(`
    (module
      (func (export "run") (result i32)
        (if (result i32)
          (i32.const 1)
          (then (i32.const 7))
          (else (i32.const 9))
        )
      )
    )
  `);
  assert.equal(parsed.ok, true);

  const traceLogs = [];
  const optimized = passes.optimizeModuleWithOptionsTrace(
    parsed.value,
    [passes.codeFolding()],
    passes.OptimizeOptions.new(),
    (msg) => {
      traceLogs.push(msg);
    },
  );

  assert.equal(optimized.ok, true);
  assert(traceLogs.some((line) => line === 'start passes=1'));
  assert(traceLogs.some((line) => line.includes('pass[1/1]:start pass=CodeFolding')));
  assert(traceLogs.some((line) => line.includes('pass[1/1]:code_folding:func[1] start')));
  assert(traceLogs.some((line) => line.includes('pass[1/1]:code_folding:func[1] done elapsed_ms=')));
});

test('cmd bridge minimizes pass lists with a JS callback', () => {
  const minimized = cmd.minimizeFuzzPasses(
    ['optimize', 'vacuum', 'flatten'],
    (passes) => passes.includes('vacuum'),
  );

  assert.deepEqual(minimized, ['vacuum']);
});

test('cmd bridge persists fuzz reports through JS IO hooks', () => {
  const writes = new Map();
  const io = cmd.FuzzFailurePersistIO.new(
    () => ({ ok: true, value: undefined }),
    (targetPath, bytes) => {
      writes.set(targetPath, bytes);
      return { ok: true, value: undefined };
    },
  );
  const report = cmd.FuzzFailureReport.new(
    0x5eedn,
    7,
    3,
    'differential',
    'mismatch',
    ['optimize'],
    ['vacuum'],
    new Uint8Array([0, 97, 115, 109]),
  );

  const persisted = cmd.persistFuzzFailureReport(report, io, 'tmp-corpus');
  assert.equal(persisted.ok, true);
  assert.equal(persisted.value[0].endsWith('.meta.txt'), true);
  assert.equal(persisted.value[1]?.endsWith('.wasm'), true);
  assert.equal(writes.has(persisted.value[0]), true);
  assert.equal(writes.has(persisted.value[1]), true);
});

test('cmd bridge runs --help through a JS CmdIO adapter', () => {
  const stdout = [];
  const io = cmd.CmdIO.new(
    () => null,
    () => false,
    () => ({ ok: false, error: 'unexpected read' }),
    undefined,
    () => ({ ok: false, error: 'unexpected write_file' }),
    (bytes) => {
      stdout.push(new TextDecoder().decode(bytes));
      return { ok: true, value: undefined };
    },
    () => ({ ok: true, value: undefined }),
    () => [],
    () => ({ ok: false, error: 'unexpected lower_text_module' }),
  );

  const result = cmd.runCmdWithAdapter(['--help'], io);
  assert.equal(result.ok, true);
  assert.match(stdout.join(''), /Starshine Wasm Binary Toolkit/);
});

test('cmd bridge optimizes a wat input through JS IO hooks', () => {
  const files = new Map();
  files.set('sample.wat', new TextEncoder().encode('(module (func (export "run")))'));
  const writes = new Map();
  const io = cmd.CmdIO.new(
    () => null,
    (targetPath) => files.has(targetPath),
    (targetPath) => files.has(targetPath)
      ? { ok: true, value: files.get(targetPath) }
      : { ok: false, error: `missing file: ${targetPath}` },
    undefined,
    (targetPath, bytes) => {
      writes.set(targetPath, bytes);
      return { ok: true, value: undefined };
    },
    () => ({ ok: true, value: undefined }),
    () => ({ ok: true, value: undefined }),
    () => ['sample.wat'],
    () => ({ ok: false, error: 'use in-process fallback' }),
  );

  const result = cmd.runCmdWithAdapter(['sample.wat'], io);
  assert.equal(result.ok, true);
  assert.deepEqual(result.value.outputFiles, ['sample.wasm']);
  assert.equal(writes.has('sample.wasm'), true);
  const decoded = binary.decodeModule(writes.get('sample.wasm'));
  assert.equal(decoded.ok, true);
});

test('cmd bridge runs differential validation with JS adapters', () => {
  const parsed = wast.wastToBinaryModule('(module (func (export "run")))');
  assert.equal(parsed.ok, true);
  const encoded = binary.encodeModule(parsed.value);
  assert.equal(encoded.ok, true);

  const adapters = cmd.DifferentialAdapters.new(
    () => ({ ok: true, value: true }),
    () => ({ ok: true, value: true }),
  );
  const result = cmd.differentialValidateWasm(encoded.value, adapters);

  assert.equal(result.ok, true);
  assert.equal(result.value.internalValid, true);
  assert.equal(result.value.wasmToolsValid, true);
  assert.equal(result.value.binaryenValid, true);
});

test('cmd bridge reports fuzz harness configuration failures through the callback', () => {
  const failures = [];
  const result = cmd.runWasmSmithFuzzHarness(
    -1,
    0x5eedn,
    [],
    null,
    null,
    0,
    (report) => {
      failures.push(report);
      return { ok: true, value: undefined };
    },
  );

  assert.equal(result.ok, false);
  assert.match(result.error, /validTarget must be non-negative/);
  assert.equal(failures.length, 1);
  assert.equal(failures[0].stage, 'config');
});

test('optimized WASI artifact starts through the runner', () => {
  const wasmPath = new URL('../internal/starshine.wasm-wasi.wasm', import.meta.url);
  return runWasmStart({
    wasmPath,
    args: ['starshine', '--help'],
    cwd: path.join(__dirname, '..', '..'),
    env: process.env,
  }).then((exitCode) => {
    assert.equal(exitCode, 0);
  });
});

test('npm bin prints help text', () => {
  const binPath = path.join(__dirname, '..', 'bin', 'starshine.js');
  const result = childProcess.spawnSync(process.execPath, [binPath, '--help'], {
    cwd: path.join(__dirname, '..', '..'),
    encoding: 'utf8',
    env: {
      ...process.env,
      NODE_NO_WARNINGS: '1',
    },
  });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Starshine Wasm Binary Toolkit/);
  assert.match(result.stdout, /--help/);
});
