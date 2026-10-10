#!/usr/bin/env bun
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { performance } from 'node:perf_hooks';
import { repoRootFromScript, resolveMoonBin } from './self-optimized-artifacts.mjs';
import { runFfi } from './ffi-task.ts';
import { generateNodePackage } from './generate-node-package.mjs';
import { stripWasmCustomSection, listWasmExportNames } from './wasm-export-renaming.ts';

const repoRoot = repoRootFromScript(import.meta.url);
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
function run(command, args, root, timeout = 180_000) {
  const result = spawnSync(command, args, { cwd: root, encoding: 'utf8', stdio: 'pipe', timeout, maxBuffer: 64 * 1024 * 1024 });
  if (result.error || result.status !== 0) throw new Error(`${command} ${args.join(' ')} failed: ${result.error?.message ?? result.stderr.slice(-8000)}`);
  return result.stdout;
}

export function buildNodePackage({ repoRoot: root = repoRoot, moonBin = resolveMoonBin() } = {}) {
  const internal = path.join(root, 'node/internal');
  const dist = path.join(root, 'dist/npm');
  fs.mkdirSync(dist, { recursive: true });
  // Never leave stale package bytes ready to pack after a failed rebuild.
  for (const name of ['starshine.wasm-gc.wasm', 'starshine.wasm-wasi.wasm']) fs.rmSync(path.join(internal, name), { force: true });
  const started = performance.now();
  const toolchains = {
    moon: run(moonBin, ['version', '--all'], root).trim(),
    node: run(process.env.NODE_BIN ?? 'node', ['--version'], root).trim(),
    wasmTools: run(process.env.WASM_TOOLS_BIN ?? 'wasm-tools', ['--version'], root).trim(),
    bun: process.versions.bun,
  };
  console.log('Generating the npm API from live FFI signatures...');
  runFfi('generate', root);
  generateNodePackage();
  run(moonBin, ['-C', 'ffi', 'build', '--target', 'wasm-gc', '--release', 'src/npm'], root);
  // Native bootstrap comes from this checkout; it never uses the npm package.
  console.log('Building native bootstrap and WASI CLI...');
  run(moonBin, ['build', '--target', 'native', '--release', 'src/cmd'], root);
  run(moonBin, ['build', '--target', 'wasm', '--release', 'src/cmd'], root);
  const optimizer = path.join(root, '_build/native/release/build/cmd/cmd.exe');
  const artifacts = [
    { name: 'starshine.wasm-gc.wasm', source: 'ffi/_build/wasm-gc/release/build/jtenner/starshine-ffi/npm/npm.wasm' },
    { name: 'starshine.wasm-wasi.wasm', source: '_build/wasm/release/build/cmd/cmd.wasm' },
  ];
  const report = { toolchains, bootstrapSha256: sha256(fs.readFileSync(optimizer)), preset: ['--optimize', '--optimize-level', '1'], artifacts: [], parity: null };
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'starshine-npm-parity-'));
  try {
    const fixture = path.join(scratch, 'bootstrap.wat');
    const fixtureBefore = path.join(scratch, 'bootstrap-before.wasm');
    const fixtureAfter = path.join(scratch, 'bootstrap-after.wasm');
    fs.writeFileSync(fixture, '(module (func $a (result i32) i32.const 42) (func $b (result i32) i32.const 42) (func (export "answer") (result i32) call $a call $b i32.add))');
    run(process.env.WASM_TOOLS_BIN ?? 'wasm-tools', ['parse', fixture, '-o', fixtureBefore], root);
    run(optimizer, [...report.preset, fixtureBefore, '--out', fixtureAfter], root);
    run(process.env.WASM_TOOLS_BIN ?? 'wasm-tools', ['validate', '--features', 'all', fixtureAfter], root);
    assert.notDeepEqual(fs.readFileSync(fixtureBefore), fs.readFileSync(fixtureAfter), 'bootstrap preset failed to transform its duplicate-function fixture');
    const fixtureObserver = path.join(scratch, 'bootstrap.mjs');
    fs.writeFileSync(fixtureObserver, `import fs from 'node:fs'; const values=[]; for(const file of process.argv.slice(2)){ const {instance}=await WebAssembly.instantiate(fs.readFileSync(file)); values.push(instance.exports.answer()); } console.log(JSON.stringify(values));`);
    assert.deepEqual(JSON.parse(run(process.env.NODE_BIN ?? 'node', [fixtureObserver, fixtureBefore, fixtureAfter], scratch)), [84, 84]);
    report.bootstrapFixture = { transformed: true, beforeBytes: fs.statSync(fixtureBefore).size, afterBytes: fs.statSync(fixtureAfter).size, result: 84 };
    for (const artifact of artifacts) {
      // The compiler's name subsection order is noncanonical; names are debug-only.
      const raw = stripWasmCustomSection(new Uint8Array(fs.readFileSync(path.join(root, artifact.source))), 'name');
      const before = path.join(dist, `${artifact.name}.unoptimized`);
      const after = path.join(dist, artifact.name);
      fs.writeFileSync(before, raw);
      run(process.env.WASM_TOOLS_BIN ?? 'wasm-tools', ['validate', '--features', 'all', before], root);
      fs.rmSync(after, { force: true });
      const optimizeStarted = performance.now();
      const diagnostics = run(optimizer, [...report.preset, before, '--out', after], root, Number(process.env.NPM_SELF_OPT_TIMEOUT_MS ?? 180_000));
      fs.writeFileSync(path.join(dist, `${artifact.name}.optimizer.log`), diagnostics);
      run(process.env.WASM_TOOLS_BIN ?? 'wasm-tools', ['validate', '--features', 'all', after], root);
      const optimized = fs.readFileSync(after);
      if (artifact.name.includes('wasm-gc')) {
        const available = new Set(listWasmExportNames(optimized));
        const required = JSON.parse(fs.readFileSync(path.join(internal, 'required-exports.json'), 'utf8'));
        assert.deepEqual(required.filter(name => !available.has(name)), [], 'self-optimization lost public ABI exports');
      }
      report.artifacts.push({ name: artifact.name, beforeBytes: raw.byteLength, afterBytes: optimized.byteLength, deltaBytes: optimized.byteLength - raw.byteLength, beforeSha256: sha256(raw), afterSha256: sha256(optimized), optimizeMs: Math.round(performance.now() - optimizeStarted) });
    }
    const beforePackage = path.join(scratch, 'before');
    const afterPackage = path.join(scratch, 'after');
    for (const [target, optimized] of [[beforePackage, false], [afterPackage, true]]) {
      fs.cpSync(path.join(root, 'node'), target, { recursive: true });
      for (const artifact of artifacts) fs.copyFileSync(path.join(dist, optimized ? artifact.name : `${artifact.name}.unoptimized`), path.join(target, 'internal', artifact.name));
    }
    const nodeBin = process.env.NODE_BIN ?? 'node';
    const observer = path.join(root, 'scripts/lib/npm-behavior.mjs');
    const observationStarted = performance.now();
    const observations = [beforePackage, afterPackage].map(pkg => JSON.parse(run(nodeBin, [observer, pkg], scratch)));
    assert.deepEqual(observations[1], observations[0], 'self-optimized API behavior differs from the unoptimized build');
    const help = [beforePackage, afterPackage].map(pkg => run(nodeBin, [path.join(pkg, 'bin/starshine.js'), '--help'], scratch));
    assert.equal(help[1], help[0]);
    report.parity = { api: true, cliHelp: true, observationSha256: sha256(JSON.stringify(observations[0])), wallMs: Math.round(performance.now() - observationStarted) };
    // Promote only validated, parity-checked optimized bytes.
    for (const artifact of artifacts) fs.copyFileSync(path.join(dist, artifact.name), path.join(internal, artifact.name));
    report.buildMs = Math.round(performance.now() - started);
    fs.writeFileSync(path.join(dist, 'build-report.json'), `${JSON.stringify(report, null, 2)}\n`);
    console.log(JSON.stringify(report, null, 2));
    return report;
  } catch (error) {
    report.error = String(error);
    fs.writeFileSync(path.join(dist, 'build-report.json'), `${JSON.stringify(report, null, 2)}\n`);
    throw error;
  } finally {
    fs.rmSync(scratch, { recursive: true, force: true });
  }
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) buildNodePackage();
