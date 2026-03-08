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
    size_mib: Number((bytes.length / (1024 * 1024)).toFixed(3)),
    sha256: sha256(bytes),
  };
}

function computeDiff(left, right) {
  const minLen = Math.min(left.length, right.length);
  let changedInSharedPrefix = 0;
  for (let i = 0; i < minLen; i += 1) {
    if (left[i] !== right[i]) changedInSharedPrefix += 1;
  }
  const denominator = left.length === 0 ? 1 : left.length;
  return {
    size_delta_bytes: right.length - left.length,
    size_delta_percent: Number((((right.length - left.length) / denominator) * 100).toFixed(3)),
    shared_prefix_len: minLen,
    changed_bytes_in_shared_prefix: changedInSharedPrefix,
  };
}

function logFileStats(label, stats) {
  console.log(`${label}: ${stats.path}`);
  console.log(`  size=${stats.size_bytes} bytes (${stats.size_mib} MiB)`);
  console.log(`  sha256=${stats.sha256}`);
}

function logDiff(label, diff) {
  console.log(`${label}:`);
  console.log(`  size_delta_bytes=${diff.size_delta_bytes}`);
  console.log(`  size_delta_percent=${diff.size_delta_percent}`);
  console.log(`  shared_prefix_len=${diff.shared_prefix_len}`);
  console.log(`  changed_bytes_in_shared_prefix=${diff.changed_bytes_in_shared_prefix}`);
}

const repoRoot = repoRootFromScript(import.meta.url);
const dist = distArtifactPaths(repoRoot);

const debug = fs.readFileSync(dist.debug);
const optimized = fs.readFileSync(dist.optimized);

const baseReport = {
  generated_at: new Date().toISOString(),
  files: {
    debug: summarize('tests/node/dist/starshine-debug-wasi.wasm', debug),
    optimized: summarize('tests/node/dist/starshine-optimized-wasi.wasm', optimized),
  },
  diff: {
    debug_to_optimized: computeDiff(debug, optimized),
  },
};

let report = baseReport;
if (fs.existsSync(dist.selfOptimized)) {
  const selfOptimized = fs.readFileSync(dist.selfOptimized);
  report = {
    ...baseReport,
    files: {
      ...baseReport.files,
      self_optimized: summarize('tests/node/dist/starshine-self-optimized-wasi.wasm', selfOptimized),
    },
    diff: {
      ...baseReport.diff,
      optimized_to_self_optimized: computeDiff(optimized, selfOptimized),
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
      message: 'Could not compare starshine optimized and self-optimized outputs.',
      optimize_error: optimizeError.trim(),
    },
  };
}

fs.writeFileSync(dist.compareReport, JSON.stringify(report, null, 2) + '\n');
console.log('WASM artifact stats:');
logFileStats('debug', report.files.debug);
logFileStats('optimized', report.files.optimized);
if (report.files.self_optimized) {
  logFileStats('self_optimized', report.files.self_optimized);
}
console.log('WASM artifact comparisons:');
logDiff('debug_to_optimized', report.diff.debug_to_optimized);
if (report.diff.optimized_to_self_optimized) {
  logDiff('optimized_to_self_optimized', report.diff.optimized_to_self_optimized);
}
if (report.diff.debug_to_self_optimized) {
  logDiff('debug_to_self_optimized', report.diff.debug_to_self_optimized);
}
if (report.blocker) {
  console.warn(`warning: ${report.blocker.message}`);
}
console.log(`Wrote comparison report: ${dist.compareReport}`);
