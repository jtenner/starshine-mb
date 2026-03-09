import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export function repoRootFromScript(importMetaUrl) {
  const scriptPath = fileURLToPath(importMetaUrl);
  let current = path.dirname(scriptPath);
  while (true) {
    if (fs.existsSync(path.join(current, 'moon.mod.json'))) {
      return current;
    }
    const parent = path.dirname(current);
    if (parent === current) {
      throw new Error(`Could not locate repository root from ${scriptPath}`);
    }
    current = parent;
  }
}

export function resolveMoonBin() {
  if (process.env.MOON_BIN) {
    return process.env.MOON_BIN;
  }
  return 'moon';
}

export function distArtifactPaths(repoRoot) {
  const distDir = path.join(repoRoot, 'tests', 'node', 'dist');
  return {
    distDir,
    debug: path.join(distDir, 'starshine-debug-wasi.wasm'),
    optimized: path.join(distDir, 'starshine-optimized-wasi.wasm'),
    selfOptimized: path.join(distDir, 'starshine-self-optimized-wasi.wasm'),
    optimizeError: path.join(distDir, 'optimize.error.txt'),
  };
}

export function wasmBuildArtifactPaths(repoRoot) {
  return {
    debug: path.join(repoRoot, '_build', 'wasm', 'debug', 'build', 'cmd', 'cmd.wasm'),
    release: path.join(repoRoot, '_build', 'wasm', 'release', 'build', 'cmd', 'cmd.wasm'),
  };
}

export function nativeStarshineBinaryPaths(repoRoot) {
  return [
    path.join(repoRoot, '_build', 'native', 'release', 'build', 'cmd', 'cmd.exe'),
    path.join(repoRoot, '_build', 'native', 'debug', 'build', 'cmd', 'cmd.exe'),
  ];
}

export function run(command, args, repoRoot) {
  execFileSync(command, args, {
    cwd: repoRoot,
    stdio: 'inherit',
  });
}

function resolveStarshineBinary(repoRoot, overridePath) {
  if (overridePath) {
    if (!fs.existsSync(overridePath)) {
      throw new Error(`Missing starshine native binary: ${overridePath}`);
    }
    return overridePath;
  }
  const candidates = nativeStarshineBinaryPaths(repoRoot);
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }
  throw new Error(`Missing starshine native binary: ${candidates[0]}`);
}

export function copyWasmArtifacts({ repoRoot }) {
  const source = wasmBuildArtifactPaths(repoRoot);
  const target = distArtifactPaths(repoRoot);
  if (!fs.existsSync(source.debug)) {
    throw new Error(`Missing wasm build artifact: ${source.debug}`);
  }
  if (!fs.existsSync(source.release)) {
    throw new Error(`Missing wasm build artifact: ${source.release}`);
  }
  fs.mkdirSync(target.distDir, { recursive: true });
  fs.copyFileSync(source.debug, target.debug);
  fs.copyFileSync(source.release, target.optimized);
  return {
    debug: {
      path: target.debug,
      size: fs.statSync(target.debug).size,
    },
    optimized: {
      path: target.optimized,
      size: fs.statSync(target.optimized).size,
    },
  };
}

function streamToUtf8(value) {
  if (typeof value === 'string') {
    return value;
  }
  if (Buffer.isBuffer(value)) {
    return value.toString('utf8');
  }
  return '';
}

export function optimizeDebugWasm({
  repoRoot,
  starshinePath,
  fallbackToDebugOnFailure = false,
} = {}) {
  const dist = distArtifactPaths(repoRoot);
  const binary = resolveStarshineBinary(repoRoot, starshinePath);

  if (!fs.existsSync(dist.debug)) {
    throw new Error(`Missing debug wasm input: ${dist.debug}`);
  }

  if (fs.existsSync(dist.selfOptimized)) {
    fs.rmSync(dist.selfOptimized);
  }
  if (fs.existsSync(dist.optimizeError)) {
    fs.rmSync(dist.optimizeError);
  }

  try {
    execFileSync(binary, ['--optimize', '-O4z', '--out', dist.selfOptimized, dist.debug], {
      cwd: repoRoot,
      env: {
        ...process.env,
        STARSHINE_TRACE_OPTIMIZE: '1',
      },
      stdio: ['ignore', 'inherit', 'pipe'],
    });
  } catch (error) {
    const status = error?.status ?? 'unknown';
    const signal = error?.signal ?? 'unknown';
    const stderr = streamToUtf8(error?.stderr).trim();
    const message =
      `starshine optimize failed for debug wasm\n` +
      `status=${status}\n` +
      `signal=${signal}\n` +
      `input=${dist.debug}\n` +
      `output=${dist.selfOptimized}\n` +
      (stderr.length > 0 ? `stderr=${stderr}\n` : '');
    fs.writeFileSync(dist.optimizeError, message);
    if (fallbackToDebugOnFailure) {
      fs.copyFileSync(dist.debug, dist.selfOptimized);
      return {
        outputPath: dist.selfOptimized,
        size: fs.statSync(dist.selfOptimized).size,
        fallback: true,
        errorPath: dist.optimizeError,
      };
    }
    throw new Error(message);
  }

  return {
    outputPath: dist.selfOptimized,
    size: fs.statSync(dist.selfOptimized).size,
    fallback: false,
    errorPath: dist.optimizeError,
  };
}
