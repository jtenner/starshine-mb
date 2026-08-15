import fs from 'node:fs';
import path from 'node:path';
import { execFileSync, spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export function repoRootFromScript(importMetaUrl) {
  const scriptPath = fileURLToPath(importMetaUrl);
  let current = path.dirname(scriptPath);
  while (true) {
    if (fs.existsSync(path.join(current, 'moon.mod.json')) || fs.existsSync(path.join(current, 'moon.mod'))) {
      return current;
    }
    const parent = path.dirname(current);
    if (parent === current) {
      throw new Error(`Could not locate repository root from ${scriptPath}`);
    }
    current = parent;
  }
}

// Allow CI/local overrides for executable locations while preserving local defaults.
export function resolveMoonBin() {
  if (process.env.MOON_BIN) {
    return process.env.MOON_BIN;
  }
  return 'moon';
}

// Allow override for wasm-tools binary to support custom installations.
export function resolveWasmToolsBin() {
  if (process.env.WASM_TOOLS_BIN) {
    return process.env.WASM_TOOLS_BIN;
  }
  return 'wasm-tools';
}

// Centralize output layout so all self-optimization tooling reads/writes the same
// dist paths.
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

// Return expected build artifact locations for wasm outputs by profile.
export function wasmBuildArtifactPaths(repoRoot) {
  return {
    debug: path.join(repoRoot, '_build', 'wasm', 'debug', 'build', 'cmd', 'cmd.wasm'),
    release: path.join(repoRoot, '_build', 'wasm', 'release', 'build', 'cmd', 'cmd.wasm'),
  };
}

// Prefer release native binary first (then debug) when selecting the optimizer for
// local reproducible self-optimization runs.
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

export const DEFAULT_SELF_OPT_TIMEOUT_MS = 10 * 60 * 1000;
export const DEFAULT_SELF_OPT_STALL_TIMEOUT_MS = 90 * 1000;

function appendRollingOutput(current, chunk, limit = 16 * 1024) {
  const next = current + chunk;
  return next.length <= limit ? next : next.slice(next.length - limit);
}

function signalProcessTree(child, signal) {
  if (child.pid === undefined) {
    return;
  }
  if (process.platform !== 'win32') {
    try {
      process.kill(-child.pid, signal);
      return;
    } catch {
      // The process may have exited between the watchdog firing and this signal.
    }
  }
  try {
    child.kill(signal);
  } catch {
    // A raced process exit needs no further cleanup.
  }
}

// Execute a potentially expensive optimizer command with both a total deadline and
// a no-progress deadline. Output from either stream resets the progress watchdog.
// On timeout, terminate the whole process group so wrappers cannot leave orphaned
// optimizer children consuming CPU after the parent command has failed.
export async function runCommandWithProgressTimeout(
  command,
  args,
  {
    cwd = process.cwd(),
    env = process.env,
    totalTimeoutMs = DEFAULT_SELF_OPT_TIMEOUT_MS,
    stallTimeoutMs = DEFAULT_SELF_OPT_STALL_TIMEOUT_MS,
    killGraceMs = 2000,
    writeStdout = (chunk) => process.stdout.write(chunk),
    writeStderr = (chunk) => process.stderr.write(chunk),
  } = {},
) {
  if (!Number.isFinite(totalTimeoutMs) || totalTimeoutMs <= 0) {
    throw new Error(`invalid total timeout: ${totalTimeoutMs}`);
  }
  if (!Number.isFinite(stallTimeoutMs) || stallTimeoutMs <= 0) {
    throw new Error(`invalid no-progress timeout: ${stallTimeoutMs}`);
  }

  const startedAt = Date.now();
  let lastProgressAt = startedAt;
  let rollingOutput = '';
  let timeoutKind = null;
  let forceKillTimer = null;
  const child = spawn(command, args, {
    cwd,
    env,
    detached: process.platform !== 'win32',
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  function recordOutput(chunk, writer) {
    const text = String(chunk);
    lastProgressAt = Date.now();
    rollingOutput = appendRollingOutput(rollingOutput, text);
    writer(text);
  }

  child.stdout?.setEncoding('utf8');
  child.stderr?.setEncoding('utf8');
  child.stdout?.on('data', (chunk) => recordOutput(chunk, writeStdout));
  child.stderr?.on('data', (chunk) => recordOutput(chunk, writeStderr));

  const watchdogIntervalMs = Math.max(
    10,
    Math.min(1000, Math.floor(totalTimeoutMs / 4), Math.floor(stallTimeoutMs / 4)),
  );
  const watchdog = setInterval(() => {
    if (timeoutKind !== null) {
      return;
    }
    const now = Date.now();
    if (now - startedAt >= totalTimeoutMs) {
      timeoutKind = 'total';
    } else if (now - lastProgressAt >= stallTimeoutMs) {
      timeoutKind = 'stall';
    } else {
      return;
    }
    signalProcessTree(child, 'SIGTERM');
    forceKillTimer = setTimeout(() => signalProcessTree(child, 'SIGKILL'), killGraceMs);
    forceKillTimer.unref?.();
  }, watchdogIntervalMs);
  watchdog.unref?.();

  return await new Promise((resolve, reject) => {
    let spawnError = null;
    child.on('error', (error) => {
      spawnError = error;
    });
    child.on('close', (code, signal) => {
      clearInterval(watchdog);
      if (forceKillTimer !== null) {
        clearTimeout(forceKillTimer);
      }
      const elapsedMs = Date.now() - startedAt;
      if (timeoutKind !== null) {
        const timeoutMs = timeoutKind === 'total' ? totalTimeoutMs : stallTimeoutMs;
        const description = timeoutKind === 'total'
          ? `total deadline of ${timeoutMs}ms`
          : `no progress for ${timeoutMs}ms`;
        const error = new Error(
          `command timed out after ${description}: ${command} ${args.join(' ')}\n` +
          `elapsed_ms=${elapsedMs}\n` +
          `signal=${signal ?? 'unknown'}\n` +
          (rollingOutput.length > 0 ? `last_output:\n${rollingOutput}` : ''),
        );
        error.code = 'SELF_OPT_TIMEOUT';
        error.timeoutKind = timeoutKind;
        error.timeoutMs = timeoutMs;
        error.elapsedMs = elapsedMs;
        reject(error);
        return;
      }
      if (spawnError !== null) {
        reject(spawnError);
        return;
      }
      if (code !== 0) {
        reject(new Error(
          `command failed: ${command} ${args.join(' ')} (exit ${code ?? 'unknown'}, signal ${signal ?? 'none'})\n` +
          (rollingOutput.length > 0 ? `last_output:\n${rollingOutput}` : ''),
        ));
        return;
      }
      resolve({
        exitCode: code,
        signal,
        elapsedMs,
        timedOut: false,
        lastOutput: rollingOutput,
      });
    });
  });
}

// Validate a wasm file with wasm-tools and emit a single enriched failure message.
export function validateWasmArtifact({
  repoRoot,
  wasmPath,
  label,
  wasmToolsBin = resolveWasmToolsBin(),
}) {
  try {
    execFileSync(wasmToolsBin, ['validate', '--features', 'all', wasmPath], {
      cwd: repoRoot,
      stdio: ['ignore', 'pipe', 'pipe'],
      encoding: 'utf8',
    });
  } catch (error) {
    const stderr = streamToUtf8(error?.stderr).trim();
    const message =
      `${label} validation failed\n` +
      `artifact=${wasmPath}\n` +
      (stderr.length > 0 ? `stderr=${stderr}\n` : '');
    throw new Error(message);
  }
}

// Select a native Starshine binary, honoring explicit override first, then scanning
// known release/debug candidates.
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

// Copy debug/optimized build artifacts into test/dist and validate both immediately,
// returning size metadata for caller-visible logging.
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
  validateWasmArtifact({
    repoRoot,
    wasmPath: target.debug,
    label: 'debug wasm artifact',
  });
  validateWasmArtifact({
    repoRoot,
    wasmPath: target.optimized,
    label: 'optimized wasm artifact',
  });
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

// Turn execFileSync errors into stable strings for consistent error reporting.
function streamToUtf8(value) {
  if (typeof value === 'string') {
    return value;
  }
  if (Buffer.isBuffer(value)) {
    return value.toString('utf8');
  }
  return '';
}

// Run self-optimization over release WASM by default, with an explicit fallback
// that copies debug output only when `fallbackToDebugOnFailure` is set.
export async function optimizeDebugWasm({
  repoRoot,
  starshinePath,
  inputWasmPath,
  fallbackToDebugOnFailure = false,
  debugSerialPasses = false,
  totalTimeoutMs = DEFAULT_SELF_OPT_TIMEOUT_MS,
  stallTimeoutMs = DEFAULT_SELF_OPT_STALL_TIMEOUT_MS,
  runOptimizer = runCommandWithProgressTimeout,
  validateArtifact = validateWasmArtifact,
} = {}) {
  const dist = distArtifactPaths(repoRoot);
  const binary = resolveStarshineBinary(repoRoot, starshinePath);
  const input = inputWasmPath ?? dist.optimized;

  if (!fs.existsSync(input)) {
    throw new Error(`Missing self-opt wasm input: ${input}`);
  }

  if (fs.existsSync(dist.selfOptimized)) {
    fs.rmSync(dist.selfOptimized);
  }
  if (fs.existsSync(dist.optimizeError)) {
    fs.rmSync(dist.optimizeError);
  }

  try {
    const optimizerArgs = [
      ...(debugSerialPasses ? ['--debug-serial-passes'] : []),
      '--optimize',
      '-O4z',
      '--out',
      dist.selfOptimized,
      input,
    ];
    await runOptimizer(
      binary,
      optimizerArgs,
      {
        cwd: repoRoot,
        env: {
          ...process.env,
          STARSHINE_TRACING: process.env.STARSHINE_TRACING ?? 'phase',
        },
        totalTimeoutMs,
        stallTimeoutMs,
      },
    );
  } catch (error) {
    const status = error?.status ?? 'unknown';
    const signal = error?.signal ?? 'unknown';
    const stderr = streamToUtf8(error?.stderr).trim();
    const reason = error instanceof Error ? error.message : String(error);
    const message =
      `starshine self-optimize failed\n` +
      `status=${status}\n` +
      `signal=${signal}\n` +
      `total_timeout_ms=${totalTimeoutMs}\n` +
      `stall_timeout_ms=${stallTimeoutMs}\n` +
      `input=${input}\n` +
      `output=${dist.selfOptimized}\n` +
      `reason=${reason}\n` +
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

  validateArtifact({
    repoRoot,
    wasmPath: dist.selfOptimized,
    label: 'self-optimized wasm artifact',
  });

  return {
    outputPath: dist.selfOptimized,
    size: fs.statSync(dist.selfOptimized).size,
    fallback: false,
    errorPath: dist.optimizeError,
  };
}
