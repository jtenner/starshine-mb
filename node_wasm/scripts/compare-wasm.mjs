import fs from 'node:fs';
import crypto from 'node:crypto';

import { distArtifactPaths, repoRootFromScript } from './lib/paths.mjs';

function sha256(bytes) {
  return crypto.createHash('sha256').update(bytes).digest('hex');
}

function summarize(pathname, bytes) {
  return {
    path: pathname,
    size_bytes: bytes.length,
    sha256: sha256(bytes),
  };
}

function computeDiff(left, right) {
  const minLen = Math.min(left.length, right.length);
  let changedInSharedPrefix = 0;
  for (let i = 0; i < minLen; i += 1) {
    if (left[i] !== right[i]) changedInSharedPrefix += 1;
  }
  return {
    size_delta_bytes: right.length - left.length,
    size_delta_percent: Number((((right.length - left.length) / left.length) * 100).toFixed(3)),
    shared_prefix_len: minLen,
    changed_bytes_in_shared_prefix: changedInSharedPrefix,
  };
}

const repoRoot = repoRootFromScript(import.meta.url);
const dist = distArtifactPaths(repoRoot);

const debug = fs.readFileSync(dist.debug);
const release = fs.readFileSync(dist.release);

const baseReport = {
  generated_at: new Date().toISOString(),
  files: {
    debug: summarize('dist/starshine.debug.wasm', debug),
    release: summarize('dist/starshine.release.wasm', release),
  },
  diff: {
    debug_to_release: computeDiff(debug, release),
  },
};

let report = baseReport;
if (fs.existsSync(dist.selfOptimized)) {
  const selfOptimized = fs.readFileSync(dist.selfOptimized);
  report = {
    ...baseReport,
    files: {
      ...baseReport.files,
      self_optimized: summarize('dist/starshine.self-optimized.wasm', selfOptimized),
    },
    diff: {
      ...baseReport.diff,
      debug_to_self_optimized: computeDiff(debug, selfOptimized),
    },
  };
  if (fs.existsSync(dist.optimizeError)) {
    report = {
      ...report,
      blocker: {
        message: 'Self-optimized artifact was produced via debug-copy fallback after optimizer failure.',
        optimize_error: fs.readFileSync(dist.optimizeError, 'utf8').trim(),
      },
    };
  }
} else {
  const optimizeError = fs.existsSync(dist.optimizeError)
    ? fs.readFileSync(dist.optimizeError, 'utf8')
    : 'self-optimized wasm was not generated';
  report = {
    ...baseReport,
    blocker: {
      message: 'Could not compare against starshine self-optimized output.',
      optimize_error: optimizeError.trim(),
    },
  };
}

fs.writeFileSync(dist.compareReport, JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(report, null, 2));
