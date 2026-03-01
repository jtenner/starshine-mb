import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { pathToFileURL } from 'node:url';

import { runWasmStart } from './lib/moonbit-wasi-runner.mjs';
import { distArtifactPaths, repoRootFromScript } from './lib/paths.mjs';

export function parseCliArgs(argv) {
  let limit = null;
  let wasmPath = null;
  const onlyFiles = [];

  let i = 0;
  while (i < argv.length) {
    const token = argv[i];
    if (token === '--limit') {
      if (i + 1 >= argv.length) {
        throw new Error('Missing value for --limit');
      }
      const parsed = Number.parseInt(argv[i + 1], 10);
      if (!Number.isFinite(parsed) || parsed <= 0) {
        throw new Error(`Invalid --limit value: ${argv[i + 1]}`);
      }
      limit = parsed;
      i += 2;
      continue;
    }
    if (token === '--file') {
      if (i + 1 >= argv.length) {
        throw new Error('Missing value for --file');
      }
      onlyFiles.push(argv[i + 1]);
      i += 2;
      continue;
    }
    if (token === '--wasm') {
      if (i + 1 >= argv.length) {
        throw new Error('Missing value for --wasm');
      }
      wasmPath = argv[i + 1];
      i += 2;
      continue;
    }
    throw new Error(`Unknown option: ${token}`);
  }

  return { limit, onlyFiles, wasmPath };
}

export function collectSpecFiles(specRoot) {
  const out = [];

  function walk(current) {
    const entries = fs.readdirSync(current, { withFileTypes: true });
    for (const entry of entries) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else if (entry.isFile() && full.endsWith('.wast')) {
        out.push(full);
      }
    }
  }

  walk(specRoot);
  out.sort();
  return out;
}

function toPosixRelativePath(repoRoot, filePath) {
  const relative = path.relative(repoRoot, filePath);
  return relative.split(path.sep).join('/');
}

export async function runWasmSpecSuite({
  repoRoot,
  wasmPath = null,
  limit = null,
  onlyFiles = [],
} = {}) {
  const specRoot = path.join(repoRoot, 'tests', 'spec');
  const dist = distArtifactPaths(repoRoot);
  const runnerWasm = wasmPath ?? dist.optimized;
  let files = onlyFiles.length > 0
    ? onlyFiles.map((filePath) => path.isAbsolute(filePath) ? filePath : path.join(repoRoot, filePath))
    : collectSpecFiles(specRoot);

  if (limit !== null) {
    files = files.slice(0, limit);
  }
  if (files.length === 0) {
    throw new Error('No spec files selected');
  }
  if (!fs.existsSync(runnerWasm)) {
    throw new Error(`Missing wasm CLI artifact: ${runnerWasm}`);
  }

  const runnerArgs = ['spec', ...files.map((filePath) => toPosixRelativePath(repoRoot, filePath))];
  const exitCode = await runWasmStart({
    wasmPath: runnerWasm,
    args: runnerArgs,
    cwd: repoRoot,
    preopens: { '.': repoRoot },
  });

  return {
    selectedFileCount: files.length,
    runnerWasm,
    exitCode,
  };
}

async function main() {
  const repoRoot = repoRootFromScript(import.meta.url);
  const options = parseCliArgs(process.argv.slice(2));
  const result = await runWasmSpecSuite({
    repoRoot,
    wasmPath: options.wasmPath,
    limit: options.limit,
    onlyFiles: options.onlyFiles,
  });
  console.log(`Executed wasm CLI spec command for ${result.selectedFileCount} file(s).`);
  process.exitCode = result.exitCode;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
