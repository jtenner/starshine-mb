import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

import { distArtifactPaths, nativeStarshineBinaryPaths } from './paths.mjs';

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

function streamToUtf8(value) {
  if (typeof value === 'string') {
    return value;
  }
  if (Buffer.isBuffer(value)) {
    return value.toString('utf8');
  }
  return '';
}

function envFlagEnabled(name) {
  const raw = process.env[name];
  if (typeof raw !== 'string') {
    return false;
  }
  switch (raw.trim().toLowerCase()) {
    case '1':
    case 'true':
    case 'yes':
    case 'on':
      return true;
    default:
      return false;
  }
}

export function optimizeDebugWasm({
  repoRoot,
  starshinePath,
  execFileSyncImpl = execFileSync,
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

  const verboseTrace = envFlagEnabled('STARSHINE_TRACE_OPTIMIZE_VERBOSE');

  try {
    execFileSyncImpl(binary, ['--optimize', '--out', dist.selfOptimized, dist.debug], {
      cwd: repoRoot,
      stdio: ['ignore', 'inherit', verboseTrace ? 'inherit' : 'pipe'],
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
        error: message,
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
