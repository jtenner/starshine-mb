import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { repoRootFromScript } from '../lib/self-optimized-artifacts.mjs';

const root = repoRootFromScript(import.meta.url);
const dist = path.join(root, 'dist/npm');
fs.mkdirSync(dist, { recursive: true });
const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'starshine-npm-consumers-'));
const nodeBin = process.env.NODE_BIN ?? 'node';
const npmBin = process.env.NPM_BIN ?? 'npm';
function run(command, args, cwd, env = process.env) {
  const result = spawnSync(command, args, { cwd, env, encoding: 'utf8', stdio: 'pipe', timeout: 240_000, maxBuffer: 64 * 1024 * 1024 });
  if (result.error || result.status !== 0) throw new Error(`${command} ${args.join(' ')}: ${result.error?.message ?? result.stdout + result.stderr}`);
  return result.stdout;
}
try {
  let tarball = process.argv[2];
  let pack;
  if (!tarball) {
    const output = run(npmBin, ['pack', '--json', '--pack-destination', dist], path.join(root, 'node'));
    pack = JSON.parse(output.slice(output.lastIndexOf('\n[') + 1))[0];
    tarball = path.join(dist, pack.filename);
  }
  tarball = path.resolve(tarball);
  const files = run('tar', ['-tzf', tarball], scratch).trim().split('\n');
  assert.equal(files.some(file => /(?:\.mbt|\.mbti|\.map|\.log|\.unoptimized|build-report\.json|\/test\/|credentials|unsupported-exports|export-schema)/.test(file)), false, 'private/build-only files entered npm tarball');
  assert(files.includes('package/internal/starshine.wasm-gc.wasm'));
  assert(files.includes('package/internal/starshine.wasm-wasi.wasm'));
  assert.equal(files.includes('package/internal/generated/cmd.generated.d.ts'), false, 'unused private backend declarations entered the tarball');
  const consumerEnv = { ...process.env, PATH: `${path.dirname(fs.realpathSync(run('which', [nodeBin], root).trim()))}:/usr/bin:/bin`, npm_config_cache: path.join(scratch, 'cache'), npm_config_offline: 'true' };
  const report = { tarball, sha256: createHash('sha256').update(fs.readFileSync(tarball)).digest('hex'), packedBytes: fs.statSync(tarball).size, node: run(nodeBin, ['--version'], scratch, consumerEnv).trim(), typescript: run(process.env.TSC_BIN ?? 'tsc', ['--version'], scratch, consumerEnv).trim(), files, consumers: [] };
  for (const kind of ['javascript', 'typescript']) {
    const cwd = path.join(scratch, kind);
    fs.mkdirSync(cwd);
    fs.writeFileSync(path.join(cwd, 'package.json'), '{"private":true,"type":"module"}\n');
    run(npmBin, ['install', '--ignore-scripts', '--no-audit', '--no-fund', tarball], cwd, consumerEnv);
    const pkg = path.join(cwd, 'node_modules/@jtenner/starshine');
    const runtimeArgs = ['--permission', `--allow-fs-read=${cwd}`, `--allow-fs-write=${cwd}`];
    fs.writeFileSync(path.join(cwd, 'isolation.mjs'), `import assert from 'node:assert/strict'; import fs from 'node:fs'; for (const file of process.argv.slice(2)) assert.throws(() => fs.readFileSync(file), { code: 'ERR_ACCESS_DENIED' });`);
    run(nodeBin, [...runtimeArgs, 'isolation.mjs', path.join(root, 'moon.mod'), path.join(os.homedir(), '.moon/bin/moon')], cwd, consumerEnv);
    const manifest = JSON.parse(fs.readFileSync(path.join(pkg, 'package.json'), 'utf8'));
    for (const entry of Object.values(manifest.exports)) for (const field of ['types', 'import']) assert(fs.existsSync(path.join(pkg, entry[field])));
    // Copy the observation harness into the empty consumer. It imports only
    // the installed package, with no source-tree module or compiler available.
    fs.copyFileSync(path.join(root, 'scripts/lib/npm-behavior.mjs'), path.join(cwd, 'observe.mjs'));
    const observation = JSON.parse(run(nodeBin, [...runtimeArgs, 'observe.mjs', pkg], cwd, consumerEnv));
    fs.writeFileSync(path.join(cwd, 'imports.mjs'), Object.keys(manifest.exports).map(name => `await import(${JSON.stringify(manifest.name + (name === '.' ? '' : name.slice(1)))});`).join('\n'));
    run(nodeBin, [...runtimeArgs, 'imports.mjs'], cwd, consumerEnv);
    const bin = path.join(cwd, 'node_modules/.bin/starshine');
    const cliArgs = [...runtimeArgs, '--allow-wasi'];
    assert.match(run(nodeBin, [...cliArgs, bin, '--help'], cwd, consumerEnv), /Starshine Wasm Binary Toolkit/);
    fs.writeFileSync(path.join(cwd, 'answer.wat'), '(module (func (export "answer") (result i32) i32.const 40 i32.const 2 i32.add))');
    run(nodeBin, [...cliArgs, bin, '--precompute', '--vacuum', 'answer.wat', '--out', 'answer.wasm'], cwd, consumerEnv);
    const bytes = fs.readFileSync(path.join(cwd, 'answer.wasm'));
    assert.equal(WebAssembly.validate(bytes), true);
    const { instance } = await WebAssembly.instantiate(bytes);
    assert.equal(instance.exports.answer(), 42);
    const failure = spawnSync(nodeBin, [...cliArgs, bin, '--not-a-real-pass'], { cwd, env: consumerEnv, encoding: 'utf8' });
    if (failure.error) throw failure.error;
    assert.equal(Number.isInteger(failure.status), true, 'CLI did not exit normally');
    assert.notEqual(failure.status, 0);
    if (kind === 'typescript') {
      const imports = Object.keys(manifest.exports).map((name, index) => `import * as surface${index} from ${JSON.stringify(manifest.name + (name === '.' ? '' : name.slice(1)))}; void surface${index};`).join('\n');
      fs.writeFileSync(path.join(cwd, 'consumer.ts'), imports + `
import { binary, cli, cmd, passes, validate, wast } from '@jtenner/starshine';
const parsed = wast.wastToBinaryModule('(module)');
if (parsed.ok) {
  const optimized = passes.optimizeModule(parsed.value, ['vacuum'], undefined, 1);
  if (optimized.ok) { binary.encodeModule(optimized.value); validate.validateModule(optimized.value); }
}
binary.sizeUnsigned(255n, 32);
cli.CliParseResult.new(undefined, [], undefined, undefined, undefined, undefined, undefined, cli.CliInputFormat.wasm());
cmd.runCmdWithAdapter(['--help'], cmd.CmdIO.new());
// @ts-expect-error opaque Module handles cannot be constructed structurally
binary.encodeModule({});
// @ts-expect-error UInt64 is bigint
binary.sizeUnsigned(255, 32);
// @ts-expect-error nominal handle type mismatch
binary.encodeModule(cli.TrapMode.never());
`);
      fs.writeFileSync(path.join(cwd, 'tsconfig.json'), JSON.stringify({ compilerOptions: { strict: true, target: 'ES2022', module: 'NodeNext', moduleResolution: 'NodeNext', noEmit: true, skipLibCheck: false }, files: ['consumer.ts'] }));
      run(process.env.TSC_BIN ?? 'tsc', ['--project', 'tsconfig.json'], cwd, consumerEnv);
    }
    report.consumers.push({ kind, exports: Object.keys(observation.exports), behavior: true, cli: true, runtimeIsolation: 'consumer-only filesystem permissions; checkout and MoonBit reads denied', strictTypes: kind === 'typescript' });
  }
  fs.writeFileSync(path.join(dist, 'consumer-report.json'), `${JSON.stringify(report, null, 2)}\n`);
  console.log(JSON.stringify(report, null, 2));
} finally {
  fs.rmSync(scratch, { recursive: true, force: true });
}
