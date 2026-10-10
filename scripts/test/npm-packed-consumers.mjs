import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { repoRootFromScript } from '../lib/self-optimized-artifacts.mjs';
import { runNpmCommand } from '../lib/npm-process.mjs';

const root = repoRootFromScript(import.meta.url);
const dist = path.join(root, 'dist/npm');
fs.mkdirSync(dist, { recursive: true });
const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'starshine-npm-consumers-'));
const nodeBin = process.env.NODE_BIN ?? 'node';
const npmBin = process.env.NPM_BIN ?? 'npm';
async function run(command, args, cwd, env = process.env, stage = 'consumer', logFile) {
  return runNpmCommand(command, args, { cwd, env, stage, logFile });
}
try {
  let tarball = process.argv[2];
  let pack;
  if (!tarball) {
    const output = await run(npmBin, ['pack', '--json', '--pack-destination', dist], path.join(root, 'node'), process.env, 'pack', path.join(dist, 'pack.log'));
    pack = JSON.parse(output.slice(output.lastIndexOf('\n[') + 1))[0];
    tarball = path.join(dist, pack.filename);
    const buildReport = JSON.parse(fs.readFileSync(path.join(dist, 'build-report.json'), 'utf8'));
    assert.equal(buildReport.presetName, 'O4s', 'npm builds must use the requested O4s preset');
    assert.equal(buildReport.optimizeLevel, 4);
    assert.equal(buildReport.shrinkLevel, 1);
    assert.deepEqual(buildReport.expandedPasses, ['duplicate-function-elimination', 'constraint-analysis', 'vacuum', 'reorder-locals', 'strip-debug']);
  }
  tarball = path.resolve(tarball);
  const files = (await run('tar', ['-tzf', tarball], scratch)).trim().split('\n');
  assert.equal(files.some(file => /(?:\.mbt|\.mbti|\.map|\.log|\.unoptimized|build-report\.json|\/test\/|credentials|unsupported-exports|export-schema)/.test(file)), false, 'private/build-only files entered npm tarball');
  assert(files.includes('package/internal/starshine.wasm-gc.wasm'));
  assert(files.includes('package/internal/starshine.wasm-wasi.wasm'));
  assert.equal(files.includes('package/internal/generated/cmd.generated.d.ts'), false, 'unused private backend declarations entered the tarball');
  const consumerEnv = { ...process.env, PATH: `${path.dirname(fs.realpathSync((await run('which', [nodeBin], root)).trim()))}:/usr/bin:/bin`, npm_config_cache: path.join(scratch, 'cache'), npm_config_offline: 'true' };
  const report = { tarball, sha256: createHash('sha256').update(fs.readFileSync(tarball)).digest('hex'), packedBytes: fs.statSync(tarball).size, node: (await run(nodeBin, ['--version'], scratch, consumerEnv)).trim(), typescript: (await run(process.env.TSC_BIN ?? 'tsc', ['--version'], scratch, consumerEnv)).trim(), files, consumers: [] };
  for (const kind of ['javascript', 'typescript']) {
    const cwd = path.join(scratch, kind);
    fs.mkdirSync(cwd);
    fs.writeFileSync(path.join(cwd, 'package.json'), '{"private":true,"type":"module"}\n');
    await run(npmBin, ['install', '--ignore-scripts', '--no-audit', '--no-fund', tarball], cwd, consumerEnv);
    const pkg = path.join(cwd, 'node_modules/@jtenner/starshine');
    const runtimeArgs = ['--permission', `--allow-fs-read=${cwd}`, `--allow-fs-write=${cwd}`];
    fs.writeFileSync(path.join(cwd, 'isolation.mjs'), `import assert from 'node:assert/strict'; import fs from 'node:fs'; for (const file of process.argv.slice(2)) assert.throws(() => fs.readFileSync(file), { code: 'ERR_ACCESS_DENIED' });`);
    await run(nodeBin, [...runtimeArgs, 'isolation.mjs', path.join(root, 'moon.mod'), path.join(os.homedir(), '.moon/bin/moon')], cwd, consumerEnv);
    const manifest = JSON.parse(fs.readFileSync(path.join(pkg, 'package.json'), 'utf8'));
    for (const entry of Object.values(manifest.exports)) for (const field of ['types', 'import']) assert(fs.existsSync(path.join(pkg, entry[field])));
    // Copy the observation harness into the empty consumer. It imports only
    // the installed package, with no source-tree module or compiler available.
    fs.copyFileSync(path.join(root, 'scripts/lib/npm-behavior.mjs'), path.join(cwd, 'observe.mjs'));
    const observation = JSON.parse(await run(nodeBin, [...runtimeArgs, 'observe.mjs', pkg], cwd, consumerEnv));
    fs.writeFileSync(path.join(cwd, 'imports.mjs'), Object.keys(manifest.exports).map(name => `await import(${JSON.stringify(manifest.name + (name === '.' ? '' : name.slice(1)))});`).join('\n'));
    await run(nodeBin, [...runtimeArgs, 'imports.mjs'], cwd, consumerEnv);
    const bin = path.join(cwd, 'node_modules/.bin/starshine');
    const cliArgs = [...runtimeArgs, '--allow-wasi'];
    assert.match(await run(nodeBin, [...cliArgs, bin, '--help'], cwd, consumerEnv), /Starshine Wasm Binary Toolkit/);
    fs.writeFileSync(path.join(cwd, 'answer.wat'), '(module (func (export "answer") (result i32) i32.const 40 i32.const 2 i32.add))');
    await run(nodeBin, [...cliArgs, bin, '--precompute', '--vacuum', 'answer.wat', '--out', 'answer.wasm'], cwd, consumerEnv);
    const bytes = fs.readFileSync(path.join(cwd, 'answer.wasm'));
    assert.equal(WebAssembly.validate(bytes), true);
    const { instance } = await WebAssembly.instantiate(bytes);
    assert.equal(instance.exports.answer(), 42);
    fs.writeFileSync(path.join(cwd, 'ambient-stack.wat'), '(module (func (export "answer") (param i32 i64) (result i32) local.get 0 local.get 1 i32.const 42 return))');
    await run(nodeBin, [...cliArgs, bin, '--optimize', '--optimize-level', '4', '--shrink-level', '1', 'ambient-stack.wat', '--out', 'ambient-stack.wasm'], cwd, consumerEnv);
    const ambientBytes = fs.readFileSync(path.join(cwd, 'ambient-stack.wasm'));
    assert.equal(WebAssembly.validate(ambientBytes), true);
    const ambient = await WebAssembly.instantiate(ambientBytes);
    assert.equal(ambient.instance.exports.answer(7, 9n), 42);
    await runNpmCommand(nodeBin, [...cliArgs, bin, '--not-a-real-pass'], { cwd, env: consumerEnv, stage: 'consumer', expectFailure: true });
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
      await run(process.env.TSC_BIN ?? 'tsc', ['--project', 'tsconfig.json'], cwd, consumerEnv);
    }
    report.consumers.push({ kind, exports: Object.keys(observation.exports), behavior: true, cli: true, runtimeIsolation: 'consumer-only filesystem permissions; checkout and MoonBit reads denied', strictTypes: kind === 'typescript' });
  }
  fs.writeFileSync(path.join(dist, 'consumer-report.json'), `${JSON.stringify(report, null, 2)}\n`);
  console.log(JSON.stringify(report, null, 2));
} finally {
  fs.rmSync(scratch, { recursive: true, force: true });
}
