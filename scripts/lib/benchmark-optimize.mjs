#!/usr/bin/env node

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

import {
  nativeStarshineBinaryPaths,
  repoRootFromScript,
  resolveMoonBin,
  run,
} from './self-optimized-artifacts.mjs';

// Named input sets used for benchmarking; each corpus is a deterministic list so
// scripts can compare runs across machines.
const CORPORA = {
  examples: [
    'examples/modules/simple.wat',
    'examples/modules/feature_mix.wat',
    'examples/modules/table_dispatch.wat',
    'examples/modules/simd_lane_mix.wat',
    'examples/modules/memory64_data.wat',
  ],
  'spec-sanity': [
    'tests/spec/align.wast',
    'tests/spec/br_table.wast',
    'tests/spec/local_set.wast',
    'tests/spec/memory_redundancy.wast',
    'tests/spec/try_table.wast',
  ],
  'dist-optimized': [
    'tests/node/dist/starshine-optimized-wasi.wasm',
  ],
  'self-opt-debug': [
    'tests/node/dist/starshine-debug-wasi.wasm',
  ],
};

const TRACE_PREFIX = '[trace] ';

function printHelp() {
  process.stdout.write(
    `Usage: bun make benchmark-optimize [options]

Run the native Starshine CLI with tracing enabled, then summarize per-pass timing,
change counts, and wasm size deltas across one or more inputs.

Options:
  --preset <optimize|shrink>     Run a preset pipeline.
  --passes <a,b,c>               Run explicit pass flags instead of a preset.
  --input <path>                 Add an explicit input. Repeatable.
  --corpus <name>                Add a named corpus. Repeatable.
  --list-corpora                 Print available corpus names and exit.
  --repeat <N>                   Number of runs per input. Default: 3.
  --binary <path>                Use a specific native starshine binary.
  --build-native-release         Build the native release CLI before benchmarking.
  --moon <path>                  Override moon binary when building.
  --trace-level <pass|phase|helper>
                                 Trace level to request. Default: pass.
  --no-serial-passes             Do not force --debug-serial-passes.
  --json-out <path>              Write raw structured results as JSON.
  --help                         Show this help text.

Corpora:
  examples       Small hand-written modules in examples/modules/*.wat
  spec-sanity    Fixed spec-style text corpus for broader control/memory coverage
  dist-optimized Existing optimized CLI wasm artifact in tests/node/dist
  self-opt-debug Debug CLI wasm artifact for user-run self-optimization checks

Examples:
  bun make benchmark-optimize --build-native-release --preset optimize --corpus examples --corpus dist-optimized
  bun make benchmark-optimize --build-native-release --passes simplify-locals,vacuum --corpus dist-optimized
  bun make benchmark-optimize --preset optimize --corpus self-opt-debug
`,
  );
}

function fail(message) {
  throw new Error(message);
}

// Parse CLI options and enforce value constraints before running any process-
// intensive benchmark command.
function parseArgs(argv) {
  const options = {
    preset: 'optimize',
    passes: [],
    inputs: [],
    corpora: [],
    repeat: 3,
    binary: null,
    buildNativeRelease: false,
    moonBin: resolveMoonBin(),
    traceLevel: 'pass',
    serialPasses: true,
    jsonOut: null,
    listCorpora: false,
  };

  let i = 0;
  while (i < argv.length) {
    const token = argv[i];
    switch (token) {
      case '--preset':
        i += 1;
        if (i >= argv.length) fail('missing value for --preset');
        options.preset = argv[i];
        i += 1;
        break;
      case '--passes':
        i += 1;
        if (i >= argv.length) fail('missing value for --passes');
        options.passes = argv[i]
          .split(',')
          .map((value) => value.trim())
          .filter((value) => value.length > 0);
        i += 1;
        break;
      case '--input':
        i += 1;
        if (i >= argv.length) fail('missing value for --input');
        options.inputs.push(argv[i]);
        i += 1;
        break;
      case '--corpus':
        i += 1;
        if (i >= argv.length) fail('missing value for --corpus');
        options.corpora.push(argv[i]);
        i += 1;
        break;
      case '--repeat':
        i += 1;
        if (i >= argv.length) fail('missing value for --repeat');
        options.repeat = Number.parseInt(argv[i], 10);
        if (!Number.isInteger(options.repeat) || options.repeat <= 0) {
          fail(`invalid repeat count: ${argv[i]}`);
        }
        i += 1;
        break;
      case '--binary':
        i += 1;
        if (i >= argv.length) fail('missing value for --binary');
        options.binary = argv[i];
        i += 1;
        break;
      case '--build-native-release':
        options.buildNativeRelease = true;
        i += 1;
        break;
      case '--moon':
        i += 1;
        if (i >= argv.length) fail('missing value for --moon');
        options.moonBin = argv[i];
        i += 1;
        break;
      case '--trace-level':
        i += 1;
        if (i >= argv.length) fail('missing value for --trace-level');
        options.traceLevel = argv[i];
        i += 1;
        break;
      case '--no-serial-passes':
        options.serialPasses = false;
        i += 1;
        break;
      case '--json-out':
        i += 1;
        if (i >= argv.length) fail('missing value for --json-out');
        options.jsonOut = argv[i];
        i += 1;
        break;
      case '--list-corpora':
        options.listCorpora = true;
        i += 1;
        break;
      case '--help':
        printHelp();
        process.exit(0);
      default:
        fail(`unknown option: ${token}`);
    }
  }

  if (options.preset !== null && options.passes.length > 0) {
    options.preset = null;
  }
  if (!['pass', 'phase', 'helper'].includes(options.traceLevel)) {
    fail(`invalid trace level: ${options.traceLevel}`);
  }
  if (options.preset !== null && !['optimize', 'shrink'].includes(options.preset)) {
    fail(`invalid preset: ${options.preset}`);
  }

  return options;
}

function resolveBinary(repoRoot, overridePath) {
  // Accept explicit binary override first; otherwise walk known native output
  // locations from build tooling and fail with the first expected path.
  if (overridePath) {
    const absolute = path.resolve(overridePath);
    if (!fs.existsSync(absolute)) {
      fail(`missing native starshine binary: ${absolute}`);
    }
    return absolute;
  }
  const candidates = nativeStarshineBinaryPaths(repoRoot);
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }
  fail(`missing native starshine binary: ${candidates[0]}`);
}

function resolveInputs(repoRoot, explicitInputs, corpora) {
  // Merge explicit inputs + corpus selections, dedupe by absolute path, and
  // fail fast when any requested file is missing.
  const resolved = [];
  const seen = new Set();

  function pushOne(inputPath) {
    const absolute = path.resolve(repoRoot, inputPath);
    if (!fs.existsSync(absolute)) {
      fail(`missing benchmark input: ${inputPath}`);
    }
    if (seen.has(absolute)) {
      return;
    }
    seen.add(absolute);
    resolved.push({
      absolute,
      relative: path.relative(repoRoot, absolute) || path.basename(absolute),
    });
  }

  for (const corpus of corpora) {
    const members = CORPORA[corpus];
    if (!members) {
      fail(`unknown corpus: ${corpus}`);
    }
    for (const member of members) {
      pushOne(member);
    }
  }

  for (const inputPath of explicitInputs) {
    pushOne(inputPath);
  }

  if (resolved.length === 0) {
    for (const corpus of ['examples', 'dist-optimized']) {
      for (const member of CORPORA[corpus]) {
        pushOne(member);
      }
    }
  }

  return resolved;
}

function makeCommandArgs(options, outputPath, inputPath) {
  // Convert benchmark mode configuration into Starshine CLI args, preserving
  // explicit pass strings that may already include a leading --.
  const args = ['--tracing', options.traceLevel];
  if (options.serialPasses) {
    args.push('--debug-serial-passes');
  }
  if (options.preset !== null) {
    args.push(`--${options.preset}`);
  } else {
    for (const passName of options.passes) {
      if (passName.startsWith('--')) {
        args.push(passName);
      } else {
        args.push(`--${passName}`);
      }
    }
  }
  args.push('--out', outputPath, inputPath);
  return args;
}

function parseTraceMetricValue(raw) {
  if (raw === 'true') {
    return true;
  }
  if (raw === 'false') {
    return false;
  }
  if (/^-?\d+$/.test(raw)) {
    return Number.parseInt(raw, 10);
  }
  return raw;
}

function splitPassNameAndMetrics(text) {
  const marker = text.match(
    / (changed=|funcs_visited=|funcs_changed=|instrs_before=|instrs_after=|transform_elapsed_ms=|validation_elapsed_ms=|elapsed_ms=)/,
  );
  if (!marker || marker.index === undefined) {
    return { passName: text.trim(), metricsText: '' };
  }
  return {
    passName: text.slice(0, marker.index).trim(),
    metricsText: text.slice(marker.index + 1).trim(),
  };
}

function parseKeyValueMetrics(text) {
  const metrics = {};
  if (text.length === 0) {
    return metrics;
  }
  for (const token of text.split(/\s+/)) {
    const separator = token.indexOf('=');
    if (separator <= 0) {
      continue;
    }
    const key = token.slice(0, separator);
    const value = token.slice(separator + 1);
    metrics[key] = parseTraceMetricValue(value);
  }
  return metrics;
}

function parseTraceLog(logText) {
  // Trace lines are prefixed by `[trace] `; only those lines participate in
  // benchmark metrics, everything else is ignored as command noise.
  const lines = logText.split(/\r?\n/);
  const parsed = {
    rawBytes: null,
    loweredBytes: null,
    encodedBytes: null,
    passCount: null,
    optimizeElapsedMs: null,
    passes: [],
  };

  for (const line of lines) {
    if (!line.startsWith(TRACE_PREFIX)) {
      continue;
    }
    const message = line.slice(TRACE_PREFIX.length);

    let match = message.match(/^input (.+):read bytes=(\d+)$/);
    if (match) {
      parsed.rawBytes = Number.parseInt(match[2], 10);
      continue;
    }

    match = message.match(/^input (.+):lowered bytes=(\d+)$/);
    if (match) {
      parsed.loweredBytes = Number.parseInt(match[2], 10);
      continue;
    }

    match = message.match(/^input (.+):encode bytes=(\d+)$/);
    if (match) {
      parsed.encodedBytes = Number.parseInt(match[2], 10);
      continue;
    }

    match = message.match(/^input (.+):pass_count=(\d+) optimize:start$/);
    if (match) {
      parsed.passCount = Number.parseInt(match[2], 10);
      continue;
    }

    match = message.match(/^input (.+):opt done elapsed_ms=(\d+)$/);
    if (match) {
      parsed.optimizeElapsedMs = Number.parseInt(match[2], 10);
      continue;
    }

    match = message.match(/^input (.+):opt pass\[(.+?)\]:done pass=(.+)$/);
    if (match) {
      const { passName, metricsText } = splitPassNameAndMetrics(match[3]);
      parsed.passes.push({
        ordinal: match[2],
        passName,
        metrics: parseKeyValueMetrics(metricsText),
      });
      continue;
    }
  }

  return parsed;
}

function median(values) {
  if (values.length === 0) {
    return null;
  }
  const sorted = [...values].sort((left, right) => left - right);
  const middle = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 1) {
    return sorted[middle];
  }
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

function sum(values) {
  let total = 0;
  for (const value of values) {
    total += value;
  }
  return total;
}

function formatNumber(value) {
  if (value === null || Number.isNaN(value)) {
    return 'n/a';
  }
  if (typeof value === 'boolean') {
    return value ? 'true' : 'false';
  }
  if (!Number.isFinite(value)) {
    return String(value);
  }
  if (Math.abs(value) >= 1000) {
    return value.toLocaleString('en-US');
  }
  if (Math.abs(value - Math.round(value)) < 0.001) {
    return String(Math.round(value));
  }
  return value.toFixed(1);
}

function formatPercent(numerator, denominator) {
  if (denominator === 0) {
    return 'n/a';
  }
  return `${((numerator / denominator) * 100).toFixed(2)}%`;
}

function formatSignedNumber(value) {
  if (value === null || Number.isNaN(value)) {
    return 'n/a';
  }
  if (value > 0) {
    return `+${formatNumber(value)}`;
  }
  return formatNumber(value);
}

function formatTable(headers, rows) {
  const widths = headers.map((header) => header.length);
  for (const row of rows) {
    row.forEach((cell, index) => {
      widths[index] = Math.max(widths[index], cell.length);
    });
  }

  const renderRow = (row) =>
    row
      .map((cell, index) => cell.padEnd(widths[index]))
      .join('  ')
      .trimEnd();

  const divider = widths.map((width) => '-'.repeat(width)).join('  ');
  return [
    renderRow(headers),
    divider,
    ...rows.map((row) => renderRow(row)),
  ].join('\n');
}

function aggregateRuns(runRecords) {
  // Build two independent summaries: one grouped by input file and one by pass
  // name so both workload-level and pass-level deltas can be inspected.
  const byInput = new Map();
  const byPass = new Map();

  for (const record of runRecords) {
    let inputAggregate = byInput.get(record.inputRelative);
    if (!inputAggregate) {
      inputAggregate = {
        inputRelative: record.inputRelative,
        runs: [],
      };
      byInput.set(record.inputRelative, inputAggregate);
    }
    inputAggregate.runs.push(record);

    for (const pass of record.trace.passes) {
      let passAggregate = byPass.get(pass.passName);
      if (!passAggregate) {
        passAggregate = {
          passName: pass.passName,
          invocations: 0,
          changedInvocations: 0,
          elapsedMs: [],
          transformElapsedMs: [],
          validationElapsedMs: [],
          funcsVisited: 0,
          funcsChanged: 0,
          instrDelta: 0,
        };
        byPass.set(pass.passName, passAggregate);
      }

      passAggregate.invocations += 1;
      if (pass.metrics.changed === true) {
        passAggregate.changedInvocations += 1;
      }
      if (typeof pass.metrics.elapsed_ms === 'number') {
        passAggregate.elapsedMs.push(pass.metrics.elapsed_ms);
      }
      if (typeof pass.metrics.transform_elapsed_ms === 'number') {
        passAggregate.transformElapsedMs.push(pass.metrics.transform_elapsed_ms);
      }
      if (typeof pass.metrics.validation_elapsed_ms === 'number') {
        passAggregate.validationElapsedMs.push(pass.metrics.validation_elapsed_ms);
      }
      if (typeof pass.metrics.funcs_visited === 'number') {
        passAggregate.funcsVisited += pass.metrics.funcs_visited;
      }
      if (typeof pass.metrics.funcs_changed === 'number') {
        passAggregate.funcsChanged += pass.metrics.funcs_changed;
      }
      if (
        typeof pass.metrics.instrs_before === 'number' &&
        typeof pass.metrics.instrs_after === 'number'
      ) {
        passAggregate.instrDelta +=
          pass.metrics.instrs_after - pass.metrics.instrs_before;
      }
    }
  }

  const inputRows = [...byInput.values()]
    .map((aggregate) => {
      const firstRun = aggregate.runs[0];
      const wasmIn = firstRun.trace.loweredBytes ?? firstRun.trace.rawBytes ?? 0;
      const wasmOut = firstRun.trace.encodedBytes ?? 0;
      return {
        inputRelative: aggregate.inputRelative,
        runCount: aggregate.runs.length,
        wasmIn,
        wasmOut,
        deltaBytes: wasmOut - wasmIn,
        medianWallMs: median(aggregate.runs.map((run) => run.wallMs)),
        medianOptMs: median(
          aggregate.runs
            .map((run) => run.trace.optimizeElapsedMs)
            .filter((value) => typeof value === 'number'),
        ),
        passCount: firstRun.trace.passCount ?? aggregate.runs[0].trace.passes.length,
      };
    })
    .sort((left, right) => left.inputRelative.localeCompare(right.inputRelative));

  const passRows = [...byPass.values()]
    .map((aggregate) => ({
      passName: aggregate.passName,
      invocations: aggregate.invocations,
      changedInvocations: aggregate.changedInvocations,
      totalElapsedMs: sum(aggregate.elapsedMs),
      medianElapsedMs: median(aggregate.elapsedMs),
      totalTransformMs: sum(aggregate.transformElapsedMs),
      totalValidationMs: sum(aggregate.validationElapsedMs),
      funcsVisited: aggregate.funcsVisited,
      funcsChanged: aggregate.funcsChanged,
      instrDelta: aggregate.instrDelta,
    }))
    .sort((left, right) => {
      if (right.totalElapsedMs !== left.totalElapsedMs) {
        return right.totalElapsedMs - left.totalElapsedMs;
      }
      return left.passName.localeCompare(right.passName);
    });

  return { inputRows, passRows };
}

function renderSummary(options, binaryPath, inputs, runRecords, aggregates) {
  const totalInputBytes = sum(aggregates.inputRows.map((row) => row.wasmIn));
  const totalOutputBytes = sum(aggregates.inputRows.map((row) => row.wasmOut));
  const totalDeltaBytes = totalOutputBytes - totalInputBytes;
  const medianWallMs = median(runRecords.map((record) => record.wallMs));
  const medianOptimizeMs = median(
    runRecords
      .map((record) => record.trace.optimizeElapsedMs)
      .filter((value) => typeof value === 'number'),
  );

  const lines = [];
  lines.push('Benchmark Summary');
  lines.push(`binary: ${binaryPath}`);
  lines.push(`mode: ${options.preset !== null ? `preset=${options.preset}` : `passes=${options.passes.join(',')}`}`);
  lines.push(`trace_level: ${options.traceLevel}`);
  lines.push(`serial_passes: ${options.serialPasses}`);
  lines.push(`inputs: ${inputs.length}`);
  lines.push(`repeats_per_input: ${options.repeat}`);
  lines.push(`total_runs: ${runRecords.length}`);
  lines.push(`median_wall_ms: ${formatNumber(medianWallMs)}`);
  lines.push(`median_optimize_ms: ${formatNumber(medianOptimizeMs)}`);
  lines.push(`aggregate_wasm_bytes: ${formatNumber(totalInputBytes)} -> ${formatNumber(totalOutputBytes)} (${formatSignedNumber(totalDeltaBytes)}, ${formatPercent(totalDeltaBytes, totalInputBytes)})`);
  lines.push('');

  const inputTable = formatTable(
    ['input', 'runs', 'wasm_in', 'wasm_out', 'delta', 'delta_pct', 'median_wall_ms', 'median_opt_ms', 'passes'],
    aggregates.inputRows.map((row) => [
      row.inputRelative,
      formatNumber(row.runCount),
      formatNumber(row.wasmIn),
      formatNumber(row.wasmOut),
      formatSignedNumber(row.deltaBytes),
      formatPercent(row.deltaBytes, row.wasmIn),
      formatNumber(row.medianWallMs),
      formatNumber(row.medianOptMs),
      formatNumber(row.passCount),
    ]),
  );
  lines.push('Per-input summary');
  lines.push(inputTable);
  lines.push('');

  const passRows = aggregates.passRows.slice(0, 25);
  const passTable = formatTable(
    [
      'pass',
      'invocations',
      'changed',
      'total_elapsed_ms',
      'median_elapsed_ms',
      'transform_ms',
      'validation_ms',
      'funcs_visited',
      'funcs_changed',
      'instr_delta',
    ],
    passRows.map((row) => [
      row.passName,
      formatNumber(row.invocations),
      formatNumber(row.changedInvocations),
      formatNumber(row.totalElapsedMs),
      formatNumber(row.medianElapsedMs),
      formatNumber(row.totalTransformMs),
      formatNumber(row.totalValidationMs),
      formatNumber(row.funcsVisited),
      formatNumber(row.funcsChanged),
      formatSignedNumber(row.instrDelta),
    ]),
  );
  lines.push('Per-pass summary (top 25 by total elapsed time)');
  lines.push(passTable);

  return lines.join('\n');
}

function runOneCase(repoRoot, binaryPath, options, input, iteration) {
  // Benchmark one input/iteration pair in an ephemeral directory to avoid stale
  // state leaking into subsequent runs.
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'starshine-bench-'));
  const outputPath = path.join(tempDir, `run-${iteration}.wasm`);
  const args = makeCommandArgs(options, outputPath, input.absolute);
  const start = process.hrtime.bigint();
  const result = spawnSync(binaryPath, args, {
    cwd: repoRoot,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
  });
  const end = process.hrtime.bigint();

  const stdout = result.stdout ?? '';
  const stderr = result.stderr ?? '';
  const combined = `${stdout}${stderr}`;

  if (result.status !== 0) {
    const detail = combined.trim().length > 0 ? `\n${combined.trim()}` : '';
    fail(
      `benchmark command failed for ${input.relative} (exit ${result.status})\n` +
        `${binaryPath} ${args.join(' ')}${detail}`,
    );
  }

  const trace = parseTraceLog(combined);
  if (trace.encodedBytes === null && fs.existsSync(outputPath)) {
    trace.encodedBytes = fs.statSync(outputPath).size;
  }
  if (trace.loweredBytes === null) {
    trace.loweredBytes = trace.rawBytes;
  }

  const wallMs = Number(end - start) / 1_000_000;
  fs.rmSync(tempDir, { recursive: true, force: true });
  return {
    inputAbsolute: input.absolute,
    inputRelative: input.relative,
    iteration,
    wallMs,
    trace,
  };
}

export async function main(argv = process.argv.slice(2)) {
  const repoRoot = repoRootFromScript(import.meta.url);
  const options = parseArgs(argv);

  if (options.listCorpora) {
    for (const corpus of Object.keys(CORPORA)) {
      process.stdout.write(`${corpus}\n`);
    }
    return;
  }

  const inputs = resolveInputs(repoRoot, options.inputs, options.corpora);
  if (options.buildNativeRelease) {
    run(
      options.moonBin,
      ['build', '--target', 'native', '--release', '--package', 'jtenner/starshine/cmd'],
      repoRoot,
    );
  }
  const binaryPath = resolveBinary(repoRoot, options.binary);

  const runRecords = [];
  for (const input of inputs) {
    for (let iteration = 1; iteration <= options.repeat; iteration += 1) {
      runRecords.push(runOneCase(repoRoot, binaryPath, options, input, iteration));
    }
  }

  const aggregates = aggregateRuns(runRecords);
  const summary = renderSummary(options, binaryPath, inputs, runRecords, aggregates);
  process.stdout.write(`${summary}\n`);

  if (options.jsonOut) {
    const outputPath = path.resolve(options.jsonOut);
    fs.mkdirSync(path.dirname(outputPath), { recursive: true });
    fs.writeFileSync(
      outputPath,
      JSON.stringify(
        {
          generatedAt: new Date().toISOString(),
          repoRoot,
          binaryPath,
          options,
          inputs,
          runRecords,
          aggregates,
        },
        null,
        2,
      ),
    );
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
