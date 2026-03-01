import childProcess from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import { TextDecoder, TextEncoder } from 'node:util';

import * as binaryModule from './binary.js';
import * as cliModule from './cli.js';
import * as generated from './internal/generated/cmd.generated.js';
import { countProvidedArgs, getWasmGcExports } from './internal/runtime.js';
import * as passesModule from './passes.js';
import * as validateModule from './validate.js';
import * as wastModule from './wast.js';

const binary = {
  ...binaryModule,
  decode_module: binaryModule.decodeModule,
  encode_module: binaryModule.encodeModule,
};

const cli = {
  ...cliModule,
  DEFAULT_CONFIG_PATH: cliModule.defaultConfigPath,
  expand_globs: cliModule.expandGlobs,
  infer_input_format: cliModule.inferInputFormat,
  normalize_cli_path: cliModule.normalizeCliPath,
  parse_cli_args: cliModule.parseCliArgs,
  resolve_pass_flags: cliModule.resolvePassFlags,
  resolve_traps_never_happen: cliModule.resolveTrapsNeverHappen,
};

const passes = {
  ...passesModule,
  default_function_optimization_passes: passesModule.defaultFunctionOptimizationPasses,
  default_global_optimization_post_passes: passesModule.defaultGlobalOptimizationPostPasses,
  default_global_optimization_pre_passes: passesModule.defaultGlobalOptimizationPrePasses,
  module_pass: passesModule.modulePass,
  optimize_module: passesModule.optimizeModule,
  optimize_module_with_options: passesModule.optimizeModuleWithOptions,
};

const validate = {
  ...validateModule,
  validate_module: validateModule.validateModule,
};

const wast = {
  ...wastModule,
  run_wast_spec_suite: wastModule.runWastSpecSuite,
  wast_to_binary_module: wastModule.wastToBinaryModule,
};

const wasm = await getWasmGcExports();

const textDecoder = new TextDecoder();
const textEncoder = new TextEncoder();

const BRAND_CMD_ENCODE_ERROR = 'cmd.CmdEncodeError';
const BRAND_CMD_ERROR = 'cmd.CmdError';
const BRAND_CMD_IO = 'cmd.CmdIO';
const BRAND_CMD_RUN_SUMMARY = 'cmd.CmdRunSummary';
const BRAND_DIFFERENTIAL_ADAPTERS = 'cmd.DifferentialAdapters';
const BRAND_DIFFERENTIAL_VALIDATION_REPORT = 'cmd.DifferentialValidationReport';
const BRAND_FUZZ_FAILURE_PERSIST_IO = 'cmd.FuzzFailurePersistIO';
const BRAND_FUZZ_FAILURE_REPORT = 'cmd.FuzzFailureReport';
const BRAND_WASM_SMITH_FUZZ_STATS = 'cmd.WasmSmithFuzzStats';

function ok(value) {
  return { ok: true, value };
}

function err(error, display = undefined) {
  return display === undefined
    ? { ok: false, error }
    : { ok: false, error, display };
}

function brand(name, fields) {
  return Object.freeze({
    __starshineBrand: name,
    ...fields,
  });
}

function isBranded(value, name) {
  return Boolean(value) && typeof value === 'object' && value.__starshineBrand === name;
}

function errorMessage(error) {
  if (error instanceof Error) {
    return error.message;
  }
  return String(error);
}

function bytesToString(bytes) {
  return textDecoder.decode(bytes);
}

function stringToBytes(text) {
  return textEncoder.encode(text);
}

function showValue(value) {
  if (Array.isArray(value)) {
    return `[${value.map(showValue).join(', ')}]`;
  }
  if (typeof value === 'string') {
    return JSON.stringify(value);
  }
  if (typeof value === 'bigint') {
    return `${value}n`;
  }
  if (value === null) {
    return 'null';
  }
  if (value === undefined) {
    return 'undefined';
  }
  return String(value);
}

function showStruct(name, fields) {
  return `${name}(${fields.map(([key, value]) => `${key}=${showValue(value)}`).join(', ')})`;
}

function outputTargetKind(target) {
  return wasm.__node_cli_output_target_kind(target);
}

function outputTargetPath(target) {
  return wasm.__node_cli_output_target_path(target);
}

function outputTargetKey(target) {
  const kind = outputTargetKind(target);
  return kind === 'stdout' ? kind : `${kind}:${outputTargetPath(target)}`;
}

function optimizationFlagKind(flag) {
  return wasm.__node_cli_optimization_flag_kind(flag);
}

function optimizationFlagLevel(flag) {
  return wasm.__node_cli_optimization_flag_level(flag);
}

function optimizationFlagSizeBias(flag) {
  return wasm.__node_cli_optimization_flag_size_bias(flag);
}

function inputFormatName(format) {
  return wasm.__node_cli_input_format_name(format);
}

function specSummaryFiles(summary) {
  const out = [];
  const length = wasm.__node_wast_spec_run_summary_files_length(summary);
  for (let index = 0; index < length; index += 1) {
    out.push(wasm.__node_wast_spec_run_summary_files_get(summary, index));
  }
  return out;
}

function specFileStatusKind(status) {
  return wasm.__node_wast_spec_file_status_kind(status);
}

function specFileStatusMessage(status) {
  return wasm.__node_wast_spec_file_status_message(status);
}

function cliParseResultToHost(value) {
  const inputGlobs = [];
  const outputTargets = [];
  const passFlags = [];
  const optimizeFlags = [];

  for (let index = 0; index < wasm.__node_cli_parse_result_input_globs_length(value); index += 1) {
    inputGlobs.push(wasm.__node_cli_parse_result_input_globs_get(value, index));
  }
  for (let index = 0; index < wasm.__node_cli_parse_result_output_targets_length(value); index += 1) {
    outputTargets.push(wasm.__node_cli_parse_result_output_targets_get(value, index));
  }
  for (let index = 0; index < wasm.__node_cli_parse_result_pass_flags_length(value); index += 1) {
    passFlags.push(wasm.__node_cli_parse_result_pass_flags_get(value, index));
  }
  for (let index = 0; index < wasm.__node_cli_parse_result_optimize_flags_length(value); index += 1) {
    optimizeFlags.push(wasm.__node_cli_parse_result_optimize_flags_get(value, index));
  }

  return {
    config_path: wasm.__node_cli_parse_result_has_config_path(value)
      ? wasm.__node_cli_parse_result_get_config_path(value)
      : null,
    input_globs: inputGlobs,
    glob_enabled: wasm.__node_cli_parse_result_glob_enabled(value),
    help_requested: wasm.__node_cli_parse_result_help_requested(value),
    version_requested: wasm.__node_cli_parse_result_version_requested(value),
    read_stdin: wasm.__node_cli_parse_result_read_stdin(value),
    input_format: wasm.__node_cli_parse_result_has_input_format(value)
      ? wasm.__node_cli_parse_result_get_input_format(value)
      : null,
    output_targets: outputTargets,
    pass_flags: passFlags,
    optimize_flags: optimizeFlags,
    trap_mode: wasm.__node_cli_parse_result_has_trap_mode(value)
      ? wasm.__node_cli_parse_result_get_trap_mode(value)
      : null,
    monomorphize_min_benefit: wasm.__node_cli_parse_result_has_monomorphize_min_benefit(value)
      ? wasm.__node_cli_parse_result_get_monomorphize_min_benefit(value)
      : null,
    low_memory_unused: wasm.__node_cli_parse_result_has_low_memory_unused(value)
      ? wasm.__node_cli_parse_result_get_low_memory_unused(value)
      : null,
    low_memory_bound: wasm.__node_cli_parse_result_has_low_memory_bound(value)
      ? BigInt(wasm.__node_cli_parse_result_get_low_memory_bound(value))
      : null,
  };
}

function createParseState() {
  return {
    config_path: null,
    input_globs: [],
    glob_enabled: false,
    help_requested: false,
    version_requested: false,
    read_stdin: false,
    input_format: null,
    output_targets: [],
    pass_flags: [],
    optimize_flags: [],
    trap_mode: null,
    monomorphize_min_benefit: null,
    low_memory_unused: null,
    low_memory_bound: null,
  };
}

function appendUnique(values, value) {
  if (!values.includes(value)) {
    values.push(value);
  }
}

function pushUniqueOutputTarget(values, target) {
  const key = outputTargetKey(target);
  for (const existing of values) {
    if (outputTargetKey(existing) === key) {
      return;
    }
  }
  values.push(target);
}

function parseBoolString(raw) {
  const normalized = raw.trim().toLowerCase();
  switch (normalized) {
    case '1':
    case 'true':
    case 'yes':
    case 'on':
      return true;
    case '0':
    case 'false':
    case 'no':
    case 'off':
      return false;
    default:
      return null;
  }
}

function parseInputFormatName(raw) {
  switch (raw.trim().toLowerCase()) {
    case 'wasm':
      return cli.CliInputFormat.wasm();
    case 'wat':
      return cli.CliInputFormat.wat();
    case 'wast':
      return cli.CliInputFormat.wast();
    default:
      return null;
  }
}

function parseTrapModeName(raw) {
  switch (raw.trim().toLowerCase()) {
    case 'allow':
    case 'traps-may-happen':
      return cli.TrapMode.allow();
    case 'never':
    case 'traps-never-happen':
      return cli.TrapMode.never();
    default:
      return null;
  }
}

function parseNonNegativeDecimal(raw) {
  const text = raw.trim();
  if (text.length === 0 || !/^\d+$/.test(text)) {
    return null;
  }
  return Number.parseInt(text, 10);
}

function parseJsonNonNegativeInt(value) {
  if (typeof value === 'number' && Number.isInteger(value) && value >= 0) {
    return value;
  }
  if (typeof value === 'string') {
    return parseNonNegativeDecimal(value);
  }
  return null;
}

function parseJsonBool(value) {
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'string') {
    return parseBoolString(value);
  }
  return null;
}

function parseOLevelText(raw) {
  const trimmed = raw.trim();
  if (trimmed.length === 0) {
    return null;
  }
  const flag = trimmed.startsWith('-O')
    ? trimmed
    : trimmed.startsWith('O')
      ? `-${trimmed}`
      : '';
  if (flag.length === 0) {
    return null;
  }
  const parsed = cli.parse_cli_args([flag]);
  if (!parsed.ok) {
    return null;
  }
  const state = cliParseResultToHost(parsed.value);
  return state.optimize_flags.length === 1 ? state.optimize_flags[0] : null;
}

function parsePassList(raw) {
  return raw
    .split(',')
    .map((part) => part.trim().toLowerCase())
    .filter((part) => part.length > 0);
}

function parseConfigJson(text) {
  let root;
  try {
    root = JSON.parse(text);
  } catch (error) {
    return err(`invalid config json: ${errorMessage(error)}`);
  }

  if (root === null || typeof root !== 'object' || Array.isArray(root)) {
    return err('config root must be an object');
  }

  const out = createParseState();

  const inputs = root.inputs;
  if (inputs && typeof inputs === 'object' && !Array.isArray(inputs)) {
    if (Array.isArray(inputs.globs)) {
      for (const glob of inputs.globs) {
        if (typeof glob !== 'string') {
          continue;
        }
        const normalized = cli.normalize_cli_path(glob.trim());
        if (normalized.length > 0) {
          appendUnique(out.input_globs, normalized);
        }
      }
    }
    if (inputs.stdin === true) {
      out.read_stdin = true;
    }
    if (typeof inputs.format === 'string') {
      const format = parseInputFormatName(inputs.format);
      if (format) {
        out.input_format = format;
      }
    }
  }

  const outputs = root.outputs;
  if (outputs && typeof outputs === 'object' && !Array.isArray(outputs)) {
    if (outputs.stdout === true) {
      pushUniqueOutputTarget(out.output_targets, cli.CliOutputTarget.stdout());
    }
    if (typeof outputs.out === 'string') {
      const trimmed = outputs.out.trim();
      if (trimmed.length > 0) {
        pushUniqueOutputTarget(out.output_targets, cli.CliOutputTarget.file(cli.normalize_cli_path(trimmed)));
      }
    }
    const outDir = typeof outputs.outDir === 'string'
      ? outputs.outDir
      : typeof outputs['out-dir'] === 'string'
        ? outputs['out-dir']
        : null;
    if (outDir !== null) {
      const trimmed = outDir.trim();
      if (trimmed.length > 0) {
        pushUniqueOutputTarget(out.output_targets, cli.CliOutputTarget.dir(cli.normalize_cli_path(trimmed)));
      }
    }
  }

  if (Array.isArray(root.passes)) {
    for (const pass of root.passes) {
      if (typeof pass !== 'string') {
        continue;
      }
      const trimmed = pass.trim().toLowerCase();
      if (trimmed.length === 0) {
        continue;
      }
      out.pass_flags.push(trimmed);
      if (trimmed === 'optimize') {
        out.optimize_flags.push(cli.CliOptimizationFlag.optimize());
      } else if (trimmed === 'shrink') {
        out.optimize_flags.push(cli.CliOptimizationFlag.shrink());
      }
    }
  }

  const optimize = root.optimize;
  if (optimize && typeof optimize === 'object' && !Array.isArray(optimize)) {
    if (typeof optimize.preset === 'string') {
      switch (optimize.preset.trim().toLowerCase()) {
        case 'optimize':
          out.pass_flags.push('optimize');
          out.optimize_flags.push(cli.CliOptimizationFlag.optimize());
          break;
        case 'shrink':
          out.pass_flags.push('shrink');
          out.optimize_flags.push(cli.CliOptimizationFlag.shrink());
          break;
        default:
          break;
      }
    }
    const olevelValue = optimize.olevel ?? optimize.optimizeLevel;
    if (typeof olevelValue === 'string') {
      const flag = parseOLevelText(olevelValue);
      if (flag) {
        out.optimize_flags.push(flag);
      }
    } else {
      const level = parseJsonNonNegativeInt(olevelValue);
      if (level !== null) {
        out.optimize_flags.push(cli.CliOptimizationFlag.olevel(level, false));
      }
    }
    const shrinkLevelValue = optimize.shrinkLevel ?? optimize['shrink-level'];
    const shrinkLevel = parseJsonNonNegativeInt(shrinkLevelValue);
    if (shrinkLevel !== null) {
      out.optimize_flags.push(cli.CliOptimizationFlag.olevel(shrinkLevel, true));
    }
    const trapValue = optimize.trapMode ?? optimize['trap-mode'];
    if (typeof trapValue === 'string') {
      const trapMode = parseTrapModeName(trapValue);
      if (trapMode) {
        out.trap_mode = trapMode;
      }
    }
  }

  const options = root.options;
  if (options && typeof options === 'object' && !Array.isArray(options)) {
    const trapsValue = options.trapsNeverHappen ?? options['traps-never-happen'];
    const traps = parseJsonBool(trapsValue);
    if (traps === true) {
      out.trap_mode = cli.TrapMode.never();
    } else if (traps === false) {
      out.trap_mode = cli.TrapMode.allow();
    }

    const optimizeLevel = parseJsonNonNegativeInt(options.optimizeLevel ?? options['optimize-level']);
    if (optimizeLevel !== null) {
      out.optimize_flags.push(cli.CliOptimizationFlag.olevel(optimizeLevel, false));
    }

    const shrinkLevel = parseJsonNonNegativeInt(options.shrinkLevel ?? options['shrink-level']);
    if (shrinkLevel !== null) {
      out.optimize_flags.push(cli.CliOptimizationFlag.olevel(shrinkLevel, true));
    }

    const monomorphize = parseJsonNonNegativeInt(
      options.monomorphizeMinBenefit ?? options['monomorphize-min-benefit'],
    );
    if (monomorphize !== null) {
      out.monomorphize_min_benefit = monomorphize;
    }

    const lowMemoryUnused = parseJsonBool(options.lowMemoryUnused ?? options['low-memory-unused']);
    if (lowMemoryUnused !== null) {
      out.low_memory_unused = lowMemoryUnused;
    }

    const lowMemoryBound = parseJsonNonNegativeInt(options.lowMemoryBound ?? options['low-memory-bound']);
    if (lowMemoryBound !== null) {
      out.low_memory_bound = BigInt(lowMemoryBound);
    }
  }

  return ok(out);
}

function parseEnvOverlay(io) {
  const out = createParseState();

  const starshineFormat = io.get_env('STARSHINE_FORMAT');
  if (starshineFormat !== null) {
    const format = parseInputFormatName(starshineFormat);
    if (format) {
      out.input_format = format;
    }
  }

  const starshineOut = io.get_env('STARSHINE_OUT');
  if (starshineOut !== null) {
    const trimmed = starshineOut.trim();
    if (trimmed.length > 0) {
      pushUniqueOutputTarget(out.output_targets, cli.CliOutputTarget.file(cli.normalize_cli_path(trimmed)));
    }
  }

  const starshineOutDir = io.get_env('STARSHINE_OUT_DIR');
  if (starshineOutDir !== null) {
    const trimmed = starshineOutDir.trim();
    if (trimmed.length > 0) {
      pushUniqueOutputTarget(out.output_targets, cli.CliOutputTarget.dir(cli.normalize_cli_path(trimmed)));
    }
  }

  const starshineStdout = io.get_env('STARSHINE_STDOUT');
  if (starshineStdout !== null && parseBoolString(starshineStdout) === true) {
    pushUniqueOutputTarget(out.output_targets, cli.CliOutputTarget.stdout());
  }

  const starshinePasses = io.get_env('STARSHINE_PASSES');
  if (starshinePasses !== null) {
    for (const pass of parsePassList(starshinePasses)) {
      out.pass_flags.push(pass);
    }
  }

  const starshineTrapMode = io.get_env('STARSHINE_TRAP_MODE');
  if (starshineTrapMode !== null) {
    const mode = parseTrapModeName(starshineTrapMode);
    if (mode) {
      out.trap_mode = mode;
    }
  }

  for (const key of ['STARSHINE_OPTIMIZE', 'STARSHINE_PRESET']) {
    const value = io.get_env(key);
    if (value === null) {
      continue;
    }
    for (const part of parsePassList(value)) {
      if (part === 'optimize') {
        out.pass_flags.push('optimize');
        out.optimize_flags.push(cli.CliOptimizationFlag.optimize());
      } else if (part === 'shrink') {
        out.pass_flags.push('shrink');
        out.optimize_flags.push(cli.CliOptimizationFlag.shrink());
      }
    }
  }

  const olevel = io.get_env('STARSHINE_OLEVEL');
  if (olevel !== null) {
    const flag = parseOLevelText(olevel);
    if (flag) {
      out.optimize_flags.push(flag);
    }
  }

  const monomorphize = io.get_env('STARSHINE_MONOMORPHIZE_MIN_BENEFIT');
  if (monomorphize !== null) {
    const parsedValue = parseNonNegativeDecimal(monomorphize);
    if (parsedValue !== null) {
      out.monomorphize_min_benefit = parsedValue;
    }
  }

  const lowMemoryUnused = io.get_env('STARSHINE_LOW_MEMORY_UNUSED');
  if (lowMemoryUnused !== null) {
    const parsedValue = parseBoolString(lowMemoryUnused);
    if (parsedValue !== null) {
      out.low_memory_unused = parsedValue;
    }
  }

  const lowMemoryBound = io.get_env('STARSHINE_LOW_MEMORY_BOUND');
  if (lowMemoryBound !== null) {
    const parsedValue = parseNonNegativeDecimal(lowMemoryBound);
    if (parsedValue !== null) {
      out.low_memory_bound = BigInt(parsedValue);
    }
  }

  return out;
}

function mergeParseResults(config, env, parsedCli) {
  const out = createParseState();

  for (const source of [config.input_globs, env.input_globs, parsedCli.input_globs]) {
    for (const glob of source) {
      appendUnique(out.input_globs, glob);
    }
  }

  out.glob_enabled = Boolean(config.glob_enabled || env.glob_enabled || parsedCli.glob_enabled);
  out.read_stdin = config.read_stdin || env.read_stdin || parsedCli.read_stdin;
  out.input_format = parsedCli.input_format ?? env.input_format ?? config.input_format;
  out.output_targets = parsedCli.output_targets.length > 0
    ? [...parsedCli.output_targets]
    : env.output_targets.length > 0
      ? [...env.output_targets]
      : [...config.output_targets];
  out.pass_flags = parsedCli.pass_flags.length > 0
    ? [...parsedCli.pass_flags]
    : config.pass_flags.length > 0
      ? [...config.pass_flags]
      : [...env.pass_flags];
  out.optimize_flags = parsedCli.optimize_flags.length > 0
    ? [...parsedCli.optimize_flags]
    : env.optimize_flags.length > 0
      ? [...env.optimize_flags]
      : [...config.optimize_flags];
  out.trap_mode = parsedCli.trap_mode ?? env.trap_mode ?? config.trap_mode;
  out.config_path = parsedCli.config_path ?? env.config_path ?? config.config_path;
  out.monomorphize_min_benefit = parsedCli.monomorphize_min_benefit
    ?? env.monomorphize_min_benefit
    ?? config.monomorphize_min_benefit;
  out.low_memory_unused = parsedCli.low_memory_unused ?? env.low_memory_unused ?? config.low_memory_unused;
  out.low_memory_bound = parsedCli.low_memory_bound ?? env.low_memory_bound ?? config.low_memory_bound;
  out.help_requested = parsedCli.help_requested;
  out.version_requested = parsedCli.version_requested;

  return out;
}

function buildCliParseResult(state) {
  return cli.CliParseResult.new(
    state.config_path ?? null,
    state.input_globs ?? [],
    Boolean(state.glob_enabled),
    Boolean(state.help_requested),
    Boolean(state.version_requested),
    Boolean(state.read_stdin),
    state.input_format ?? null,
    state.output_targets ?? [],
    state.pass_flags ?? [],
    state.optimize_flags ?? [],
    state.trap_mode ?? null,
    state.monomorphize_min_benefit ?? null,
    state.low_memory_unused ?? null,
    state.low_memory_bound ?? null,
  );
}

function hasGlobWildcard(pattern) {
  return pattern.includes('*') || pattern.includes('?');
}

function resolveInputFiles(globs, io) {
  const literal = [];
  const patterns = [];
  for (const raw of globs) {
    const normalized = cli.normalize_cli_path(raw.trim());
    if (normalized.length === 0) {
      continue;
    }
    if (hasGlobWildcard(normalized)) {
      appendUnique(patterns, normalized);
    } else {
      appendUnique(literal, normalized);
    }
  }
  const out = [...literal];
  if (patterns.length > 0) {
    for (const value of cli.expand_globs(patterns, io.list_candidates())) {
      appendUnique(out, value);
    }
  }
  return out;
}

function resolveOptimizeLevels(flags) {
  let optimizeLevel = 0;
  let shrinkLevel = 0;
  for (const flag of flags) {
    switch (optimizationFlagKind(flag)) {
      case 'olevel': {
        const level = optimizationFlagLevel(flag);
        optimizeLevel = Math.max(optimizeLevel, level);
        if (optimizationFlagSizeBias(flag)) {
          shrinkLevel = Math.max(shrinkLevel, level);
        }
        break;
      }
      case 'optimize':
        optimizeLevel = Math.max(optimizeLevel, 2);
        break;
      case 'shrink':
        shrinkLevel = Math.max(shrinkLevel, 2);
        break;
      default:
        break;
    }
  }
  return { optimizeLevel, shrinkLevel };
}

function resolveEffectivePassFlags(explicitPassFlags, optimizeLevel, shrinkLevel) {
  if (explicitPassFlags.length > 0) {
    return [...explicitPassFlags];
  }
  if (shrinkLevel > 0) {
    return ['shrink'];
  }
  if (optimizeLevel > 0) {
    return ['optimize'];
  }
  return [];
}

function basenameOfPath(filePath) {
  const normalized = cli.normalize_cli_path(filePath);
  const index = normalized.lastIndexOf('/');
  return index < 0 ? normalized : normalized.slice(index + 1);
}

function pathWithWasmExtension(filePath) {
  const normalized = cli.normalize_cli_path(filePath);
  const segments = normalized.split('/');
  const basename = segments.pop() ?? normalized;
  const dotIndex = basename.lastIndexOf('.');
  const nextBase = dotIndex >= 0 ? `${basename.slice(0, dotIndex)}.wasm` : `${basename}.wasm`;
  return segments.length === 0 ? nextBase : `${segments.join('/')}/${nextBase}`;
}

function outputBasenameForInput(filePath, format) {
  const base = basenameOfPath(filePath);
  return inputFormatName(format) === 'wasm' ? base : pathWithWasmExtension(base);
}

function joinCliPath(dir, file) {
  const normalizedDir = cli.normalize_cli_path(dir);
  if (normalizedDir.length === 0 || normalizedDir === '.') {
    return file;
  }
  return normalizedDir.endsWith('/') ? `${normalizedDir}${file}` : `${normalizedDir}/${file}`;
}

function outputPathForDefaultTarget(filePath, format) {
  return inputFormatName(format) === 'wasm'
    ? cli.normalize_cli_path(filePath)
    : pathWithWasmExtension(filePath);
}

function createCmdEncodeError(kind, display, cause = undefined) {
  return brand(BRAND_CMD_ENCODE_ERROR, {
    kind,
    display,
    cause,
  });
}

function createCmdError(kind, display, cause = undefined) {
  return brand(BRAND_CMD_ERROR, {
    kind,
    display,
    cause,
  });
}

function createCmdRunSummary(
  input_files = [],
  output_files = [],
  resolved_passes = [],
  optimize_level = 0,
  shrink_level = 0,
  traps_never_happen = false,
  monomorphize_min_benefit = 5,
  low_memory_unused = false,
  low_memory_bound = 1024n,
) {
  return brand(BRAND_CMD_RUN_SUMMARY, {
    inputFiles: [...input_files],
    outputFiles: [...output_files],
    resolvedPasses: [...resolved_passes],
    optimizeLevel: optimize_level,
    shrinkLevel: shrink_level,
    trapsNeverHappen: traps_never_happen,
    monomorphizeMinBenefit: monomorphize_min_benefit,
    lowMemoryUnused: low_memory_unused,
    lowMemoryBound: low_memory_bound,
  });
}

function createDifferentialAdapters(wasm_tools_validate, binaryen_validate) {
  return brand(BRAND_DIFFERENTIAL_ADAPTERS, {
    wasmToolsValidate: wasm_tools_validate,
    binaryenValidate: binaryen_validate,
  });
}

function createDifferentialValidationReport(internal_valid, wasm_tools_valid, binaryen_valid) {
  return brand(BRAND_DIFFERENTIAL_VALIDATION_REPORT, {
    internalValid: internal_valid,
    wasmToolsValid: wasm_tools_valid,
    binaryenValid: binaryen_valid,
  });
}

function createFuzzFailurePersistIO(ensure_dir, write_file) {
  return brand(BRAND_FUZZ_FAILURE_PERSIST_IO, {
    ensureDir: ensure_dir,
    writeFile: write_file,
  });
}

function createFuzzFailureReport(
  seed,
  attempt,
  generated_valid,
  stage,
  message,
  optimize_passes = [],
  minimized_passes = [],
  wasm_bytes = null,
) {
  return brand(BRAND_FUZZ_FAILURE_REPORT, {
    seed,
    attempt,
    generatedValid: generated_valid,
    stage,
    message,
    optimizePasses: [...optimize_passes],
    minimizedPasses: [...minimized_passes],
    wasm: wasm_bytes,
  });
}

function createWasmSmithFuzzStats(
  attempts = 0,
  generated_valid = 0,
  generated_invalid = 0,
  pipeline_validated = 0,
  optimized = 0,
  roundtripped = 0,
  differential_checked = 0,
) {
  return brand(BRAND_WASM_SMITH_FUZZ_STATS, {
    attempts,
    generatedValid: generated_valid,
    generatedInvalid: generated_invalid,
    pipelineValidated: pipeline_validated,
    optimized,
    roundtripped,
    differentialChecked: differential_checked,
  });
}

function normalizeCmdIO(io) {
  return {
    get_env: io.getEnv ?? io.get_env,
    file_exists: io.fileExists ?? io.file_exists,
    read_file: io.readFile ?? io.read_file,
    encode_module: io.encodeModule ?? io.encode_module,
    write_file: io.writeFile ?? io.write_file,
    write_stdout: io.writeStdout ?? io.write_stdout,
    write_stderr: io.writeStderr ?? io.write_stderr,
    list_candidates: io.listCandidates ?? io.list_candidates,
    lower_text_module: io.lowerTextModule ?? io.lower_text_module,
  };
}

function normalizeDifferentialAdapters(adapters) {
  return {
    wasm_tools_validate: adapters.wasmToolsValidate ?? adapters.wasm_tools_validate,
    binaryen_validate: adapters.binaryenValidate ?? adapters.binaryen_validate,
  };
}

function normalizeFuzzFailurePersistIO(io) {
  return {
    ensure_dir: io.ensureDir ?? io.ensure_dir,
    write_file: io.writeFile ?? io.write_file,
  };
}

function showCmdEncodeError(value) {
  if (isBranded(value, BRAND_CMD_ENCODE_ERROR)) {
    return value.display;
  }
  return generated.CmdEncodeError.show(value);
}

function showCmdError(value) {
  if (isBranded(value, BRAND_CMD_ERROR)) {
    return value.display;
  }
  return generated.CmdError.show(value);
}

function showCmdRunSummary(value) {
  if (isBranded(value, BRAND_CMD_RUN_SUMMARY)) {
    return showStruct('CmdRunSummary', [
      ['inputFiles', value.inputFiles],
      ['outputFiles', value.outputFiles],
      ['resolvedPasses', value.resolvedPasses],
      ['optimizeLevel', value.optimizeLevel],
      ['shrinkLevel', value.shrinkLevel],
      ['trapsNeverHappen', value.trapsNeverHappen],
      ['monomorphizeMinBenefit', value.monomorphizeMinBenefit],
      ['lowMemoryUnused', value.lowMemoryUnused],
      ['lowMemoryBound', value.lowMemoryBound],
    ]);
  }
  return generated.CmdRunSummary.show(value);
}

function showDifferentialValidationReport(value) {
  if (isBranded(value, BRAND_DIFFERENTIAL_VALIDATION_REPORT)) {
    return showStruct('DifferentialValidationReport', [
      ['internalValid', value.internalValid],
      ['wasmToolsValid', value.wasmToolsValid],
      ['binaryenValid', value.binaryenValid],
    ]);
  }
  return generated.DifferentialValidationReport.show(value);
}

function showFuzzFailureReport(value) {
  if (isBranded(value, BRAND_FUZZ_FAILURE_REPORT)) {
    return showStruct('FuzzFailureReport', [
      ['seed', value.seed],
      ['attempt', value.attempt],
      ['generatedValid', value.generatedValid],
      ['stage', value.stage],
      ['message', value.message],
      ['optimizePasses', value.optimizePasses],
      ['minimizedPasses', value.minimizedPasses],
      ['wasm', value.wasm === null ? null : `Uint8Array(${value.wasm.length})`],
    ]);
  }
  return generated.FuzzFailureReport.show(value);
}

function showWasmSmithFuzzStats(value) {
  if (isBranded(value, BRAND_WASM_SMITH_FUZZ_STATS)) {
    return showStruct('WasmSmithFuzzStats', [
      ['attempts', value.attempts],
      ['generatedValid', value.generatedValid],
      ['generatedInvalid', value.generatedInvalid],
      ['pipelineValidated', value.pipelineValidated],
      ['optimized', value.optimized],
      ['roundtripped', value.roundtripped],
      ['differentialChecked', value.differentialChecked],
    ]);
  }
  return generated.WasmSmithFuzzStats.show(value);
}

function normalizeResult(result, context) {
  if (result && typeof result === 'object' && result.ok === true) {
    return result;
  }
  if (result && typeof result === 'object' && result.ok === false) {
    const display = result.display ?? errorMessage(result.error);
    return err(result.error, display);
  }
  return err(`${context} returned an invalid result`);
}

function invokeResultCallback(callback, args, context) {
  try {
    return normalizeResult(callback(...args), context);
  } catch (error) {
    return err(errorMessage(error));
  }
}

function defaultEncodeModule(mod) {
  const encoded = binary.encode_module(mod);
  if (encoded.ok) {
    return encoded;
  }
  return err(
    createCmdEncodeError('encode', encoded.display ?? String(encoded.error), encoded.error),
    encoded.display ?? String(encoded.error),
  );
}

function defaultLowerTextModule(filePath, format, bytes) {
  const source = bytesToString(bytes);
  const parsed = wast.wast_to_binary_module(source, filePath);
  if (!parsed.ok) {
    return err(`in-process text parse/lower failed: ${parsed.display ?? parsed.error}`);
  }
  const encoded = binary.encode_module(parsed.value);
  if (!encoded.ok) {
    return err(`in-process text encode failed: ${encoded.display ?? encoded.error}`);
  }
  return encoded;
}

function normalizeRelativePath(filePath) {
  return cli.normalize_cli_path(filePath.split(path.sep).join('/'));
}

function listCandidateFiles(rootDir) {
  const out = [];
  const visit = (absoluteDir, relativeDir) => {
    for (const entry of fs.readdirSync(absoluteDir, { withFileTypes: true })) {
      const absolutePath = path.join(absoluteDir, entry.name);
      const relativePath = relativeDir.length === 0 ? entry.name : path.join(relativeDir, entry.name);
      if (entry.isDirectory()) {
        visit(absolutePath, relativePath);
        continue;
      }
      if (!entry.isFile()) {
        continue;
      }
      const normalized = normalizeRelativePath(relativePath);
      if (normalized.length > 0 && normalized !== '.') {
        out.push(normalized);
      }
    }
  };
  visit(rootDir, '');
  return out;
}

function createDefaultCmdIO() {
  return createCmdIO(
    (name) => process.env[name] ?? null,
    (filePath) => fs.existsSync(filePath),
    (filePath) => {
      try {
        return ok(fs.readFileSync(filePath));
      } catch (error) {
        return err(errorMessage(error));
      }
    },
    defaultEncodeModule,
    (filePath, bytes) => {
      try {
        fs.writeFileSync(filePath, bytes);
        return ok(undefined);
      } catch (error) {
        return err(errorMessage(error));
      }
    },
    (bytes) => {
      try {
        fs.writeSync(1, bytes);
        return ok(undefined);
      } catch (error) {
        return err(errorMessage(error));
      }
    },
    (bytes) => {
      try {
        fs.writeSync(2, bytes);
        return ok(undefined);
      } catch (error) {
        return err(errorMessage(error));
      }
    },
    () => listCandidateFiles(process.cwd()),
    defaultLowerTextModule,
  );
}

function createCmdIO(
  get_env = () => null,
  file_exists = () => false,
  read_file = () => err('readFile not configured'),
  encode_module = defaultEncodeModule,
  write_file = () => err('writeFile not configured'),
  write_stdout = () => ok(undefined),
  write_stderr = () => ok(undefined),
  list_candidates = () => [],
  lower_text_module = (filePath, format) => err(`text lowering not configured for ${filePath} (${inputFormatName(format)})`),
) {
  return brand(BRAND_CMD_IO, {
    getEnv: get_env,
    fileExists: file_exists,
    readFile: read_file,
    encodeModule: encode_module,
    writeFile: write_file,
    writeStdout: write_stdout,
    writeStderr: write_stderr,
    listCandidates: list_candidates,
    lowerTextModule: lower_text_module,
  });
}

function resolveConfigPath(parsedCli, io) {
  if (parsedCli.config_path !== null) {
    return [cli.normalize_cli_path(parsedCli.config_path), true];
  }
  const envConfig = io.get_env('STARSHINE_CONFIG');
  if (envConfig !== null) {
    const trimmed = envConfig.trim();
    if (trimmed.length > 0) {
      return [cli.normalize_cli_path(trimmed), true];
    }
  }
  if (io.file_exists(cli.DEFAULT_CONFIG_PATH)) {
    return [cli.DEFAULT_CONFIG_PATH, false];
  }
  return [null, false];
}

function decodeModuleForPipeline(filePath, bytes) {
  const decoded = binary.decode_module(bytes);
  if (decoded.ok) {
    return decoded;
  }
  return err(createCmdError('DecodeFailed', `${filePath}: ${decoded.display ?? decoded.error}`, decoded.error));
}

function encodeModuleForPipeline(io, filePath, mod) {
  const encoded = invokeResultCallback(io.encode_module, [mod], `encode_module(${filePath})`);
  if (encoded.ok) {
    return encoded;
  }
  const display = `${filePath}: ${showCmdEncodeError(encoded.error)}`;
  return err(createCmdError('EncodeFailed', display, encoded.error), display);
}

function lowerTextModuleForPipeline(io, filePath, format, bytes) {
  const lowered = invokeResultCallback(io.lower_text_module, [filePath, format, bytes], `lower_text_module(${filePath})`);
  if (lowered.ok) {
    return lowered;
  }
  const fallback = defaultLowerTextModule(filePath, format, bytes);
  if (fallback.ok) {
    return fallback;
  }
  return err(
    createCmdError(
      'TextLoweringFailed',
      `${filePath}: ${lowered.display ?? lowered.error}; fallback failed: ${fallback.display ?? fallback.error}`,
    ),
  );
}

function specCmdHelpText() {
  return 'Usage:\n  starshine spec <tests/spec/*.wast ...>\n\nOptions:\n  -h, --help\n      Show spec subcommand help.\n';
}

function specFailedPreview(summary, limit) {
  const out = [];
  for (const report of specSummaryFiles(summary)) {
    const status = wasm.__node_wast_spec_file_report_status(report);
    if (specFileStatusKind(status) === 'failed') {
      out.push(`${wasm.__node_wast_spec_file_report_path(report)}: ${specFileStatusMessage(status)}`);
    }
  }
  return out.slice(0, limit).join(' | ');
}

function runSpecCmdWithAdapter(args, io) {
  if (args.length === 0 || (args.length === 1 && (args[0] === '-h' || args[0] === '--help'))) {
    const written = invokeResultCallback(io.write_stdout, [stringToBytes(specCmdHelpText())], 'write_stdout(spec help)');
    if (!written.ok) {
      return err(createCmdError('OutputWriteFailed', `stdout for spec help text: ${written.display ?? written.error}`));
    }
    return ok(createCmdRunSummary());
  }

  const globs = [];
  for (const arg of args) {
    const normalized = cli.normalize_cli_path(arg.trim());
    if (normalized.length > 0) {
      appendUnique(globs, normalized);
    }
  }

  const inputFiles = resolveInputFiles(globs, io);
  if (inputFiles.length === 0) {
    return err(createCmdError('NoInputFiles', 'no input files'));
  }

  const files = [];
  for (const filePath of inputFiles) {
    const read = invokeResultCallback(io.read_file, [filePath], `read_file(${filePath})`);
    if (!read.ok) {
      return err(createCmdError('InputReadFailed', `${filePath}: ${read.display ?? read.error}`));
    }
    files.push([filePath, bytesToString(read.value)]);
  }

  const summary = wast.run_wast_spec_suite(files);
  const summaryLine =
    `spec suite summary: total=${wasm.__node_wast_spec_run_summary_total_files(summary)} `
    + `passed=${wasm.__node_wast_spec_run_summary_passed_files(summary)} `
    + `skipped=${wasm.__node_wast_spec_run_summary_skipped_files(summary)} `
    + `failed=${wasm.__node_wast_spec_run_summary_failed_files(summary)}\n`;
  const summaryWrite = invokeResultCallback(io.write_stdout, [stringToBytes(summaryLine)], 'write_stdout(spec summary)');
  if (!summaryWrite.ok) {
    return err(createCmdError('OutputWriteFailed', `stdout for spec summary: ${summaryWrite.display ?? summaryWrite.error}`));
  }

  if (wasm.__node_wast_spec_run_summary_failed_files(summary) > 0) {
    const preview = specFailedPreview(summary, 20);
    const previewLine = `failed files preview: ${preview}\n`;
    const previewWrite = invokeResultCallback(
      io.write_stdout,
      [stringToBytes(previewLine)],
      'write_stdout(spec failure preview)',
    );
    if (!previewWrite.ok) {
      return err(createCmdError('OutputWriteFailed', `stdout for spec failure preview: ${previewWrite.display ?? previewWrite.error}`));
    }
    return err(createCmdError('SpecFailed', previewLine.trim()));
  }

  return ok(createCmdRunSummary(inputFiles, [], ['spec']));
}

function expandPassesForCli(parsedCli, mod, options) {
  if (!wasm.__node_cmd_can_expand_passes_for_cli(parsedCli, mod, options)) {
    return err(wasm.__node_cmd_expand_passes_for_cli_error(parsedCli, mod, options));
  }
  const out = [];
  const length = wasm.__node_cmd_expand_passes_for_cli_length(parsedCli, mod, options);
  for (let index = 0; index < length; index += 1) {
    out.push(wasm.__node_cmd_expand_passes_for_cli_get(parsedCli, mod, options, index));
  }
  return ok(out);
}

function run_cmd_with_adapter(args, io, config_json) {
  if (!isBranded(io, BRAND_CMD_IO)) {
    throw new TypeError('Expected a CmdIO created with cmd.CmdIO.new().');
  }
  io = normalizeCmdIO(io);

  if (args.length > 0 && (args[0] === 'spec' || args[0] === 'spec-runner')) {
    return runSpecCmdWithAdapter(args.slice(1), io);
  }

  const starshineInput = io.get_env('STARSHINE_INPUT');
  const parsedCli = cli.parse_cli_args(args, starshineInput);
  if (!parsedCli.ok) {
    return err(createCmdError('CliParse', parsedCli.display ?? String(parsedCli.error), parsedCli.error));
  }

  const cliState = cliParseResultToHost(parsedCli.value);
  if (cliState.help_requested) {
    const written = invokeResultCallback(io.write_stdout, [stringToBytes(cmdHelpText())], 'write_stdout(help)');
    if (!written.ok) {
      return err(createCmdError('OutputWriteFailed', `stdout for --help: ${written.display ?? written.error}`));
    }
    return ok(createCmdRunSummary());
  }
  if (cliState.version_requested) {
    const written = invokeResultCallback(io.write_stdout, [stringToBytes(`${cmdVersionText()}\n`)], 'write_stdout(version)');
    if (!written.ok) {
      return err(createCmdError('OutputWriteFailed', `stdout for --version: ${written.display ?? written.error}`));
    }
    return ok(createCmdRunSummary());
  }

  let configState;
  if (config_json !== undefined && config_json !== null) {
    const parsedConfig = parseConfigJson(config_json);
    if (!parsedConfig.ok) {
      return err(createCmdError('InvalidConfig', parsedConfig.error));
    }
    configState = parsedConfig.value;
  } else {
    const [maybeConfigPath, configRequired] = resolveConfigPath(cliState, io);
    if (maybeConfigPath === null) {
      configState = createParseState();
    } else if (!io.file_exists(maybeConfigPath)) {
      if (configRequired) {
        return err(createCmdError('ConfigNotFound', maybeConfigPath));
      }
      configState = createParseState();
    } else {
      const read = invokeResultCallback(io.read_file, [maybeConfigPath], `read_file(${maybeConfigPath})`);
      if (!read.ok) {
        return err(createCmdError('ConfigReadFailed', `${maybeConfigPath}: ${read.display ?? read.error}`));
      }
      const parsedConfig = parseConfigJson(bytesToString(read.value));
      if (!parsedConfig.ok) {
        return err(createCmdError('InvalidConfig', parsedConfig.error));
      }
      configState = parsedConfig.value;
    }
  }

  const envState = parseEnvOverlay(io);
  const mergedState = mergeParseResults(configState, envState, cliState);
  const mergedCli = buildCliParseResult(mergedState);

  const inputFiles = resolveInputFiles(mergedState.input_globs, io);
  if (inputFiles.length === 0) {
    return err(createCmdError('NoInputFiles', 'no input files'));
  }

  const trapsNeverHappen = cli.resolve_traps_never_happen(mergedCli);
  const { optimizeLevel, shrinkLevel } = resolveOptimizeLevels(mergedState.optimize_flags);
  const resolvedPasses = resolveEffectivePassFlags(cli.resolve_pass_flags(mergedCli), optimizeLevel, shrinkLevel);
  const monomorphizeMinBenefit = mergedState.monomorphize_min_benefit ?? 5;
  const lowMemoryUnused = mergedState.low_memory_unused ?? false;
  const lowMemoryBound = mergedState.low_memory_bound ?? 1024n;
  const options = passes.OptimizeOptions.new(
    optimizeLevel,
    shrinkLevel,
    passes.InliningOptions.new(),
    monomorphizeMinBenefit,
    lowMemoryUnused,
    lowMemoryBound,
    trapsNeverHappen,
  );

  if (inputFiles.length > 1) {
    for (const target of mergedState.output_targets) {
      if (outputTargetKind(target) === 'file') {
        return err(createCmdError('AmbiguousOutputFile', outputTargetPath(target)));
      }
    }
  }

  const outputFiles = [];
  for (const inputPath of inputFiles) {
    const format = mergedState.input_format ?? cli.infer_input_format(inputPath) ?? cli.CliInputFormat.wasm();
    const read = invokeResultCallback(io.read_file, [inputPath], `read_file(${inputPath})`);
    if (!read.ok) {
      return err(createCmdError('InputReadFailed', `${inputPath}: ${read.display ?? read.error}`));
    }

    const wasmBytes = inputFormatName(format) === 'wasm'
      ? read.value
      : (() => {
          const lowered = lowerTextModuleForPipeline(io, inputPath, format, read.value);
          return lowered.ok ? lowered.value : lowered;
        })();
    if (!wasmBytes || (wasmBytes.ok === false)) {
      const failure = wasmBytes;
      return err(failure.error);
    }

    const decoded = decodeModuleForPipeline(inputPath, wasmBytes);
    if (!decoded.ok) {
      return decoded;
    }

    const expanded = expandPassesForCli(mergedCli, decoded.value, options);
    if (!expanded.ok) {
      return err(createCmdError('UnknownPassFlag', expanded.error));
    }

    const optimized = passes.optimize_module_with_options(decoded.value, expanded.value, options);
    if (!optimized.ok) {
      return err(createCmdError('OptimizeFailed', `${inputPath}: ${optimized.display ?? optimized.error}`));
    }

    const encoded = encodeModuleForPipeline(io, inputPath, optimized.value);
    if (!encoded.ok) {
      return encoded;
    }

    if (mergedState.output_targets.length === 0) {
      const outPath = outputPathForDefaultTarget(inputPath, format);
      const written = invokeResultCallback(io.write_file, [outPath, encoded.value], `write_file(${outPath})`);
      if (!written.ok) {
        return err(createCmdError('OutputWriteFailed', `${outPath}: ${written.display ?? written.error}`));
      }
      outputFiles.push(outPath);
      continue;
    }

    for (const target of mergedState.output_targets) {
      const kind = outputTargetKind(target);
      if (kind === 'stdout') {
        const written = invokeResultCallback(io.write_stdout, [encoded.value], `write_stdout(${inputPath})`);
        if (!written.ok) {
          return err(createCmdError('OutputWriteFailed', `stdout for ${inputPath}: ${written.display ?? written.error}`));
        }
        continue;
      }
      if (kind === 'file') {
        const outPath = cli.normalize_cli_path(outputTargetPath(target));
        const written = invokeResultCallback(io.write_file, [outPath, encoded.value], `write_file(${outPath})`);
        if (!written.ok) {
          return err(createCmdError('OutputWriteFailed', `${outPath}: ${written.display ?? written.error}`));
        }
        outputFiles.push(outPath);
        continue;
      }
      const outPath = joinCliPath(outputTargetPath(target), outputBasenameForInput(inputPath, format));
      const written = invokeResultCallback(io.write_file, [outPath, encoded.value], `write_file(${outPath})`);
      if (!written.ok) {
        return err(createCmdError('OutputWriteFailed', `${outPath}: ${written.display ?? written.error}`));
      }
      outputFiles.push(outPath);
    }
  }

  return ok(
    createCmdRunSummary(
      inputFiles,
      outputFiles,
      resolvedPasses,
      optimizeLevel,
      shrinkLevel,
      trapsNeverHappen,
      monomorphizeMinBenefit,
      lowMemoryUnused,
      lowMemoryBound,
    ),
  );
}

function run_cmd_exit_code_with_adapter(args, io, config_json) {
  const normalizedIo = normalizeCmdIO(io);
  const result = run_cmd_with_adapter(args, io, config_json);
  if (result.ok) {
    return 0;
  }
  invokeResultCallback(normalizedIo.write_stderr, [stringToBytes(`error: ${showCmdError(result.error)}\n`)], 'write_stderr(error)');
  return 1;
}

function run_cmd(args) {
  return run_cmd_with_adapter(args, createDefaultCmdIO());
}

function run_cmd_exit_code(args) {
  return run_cmd_exit_code_with_adapter(args, createDefaultCmdIO());
}

function hasCommand(name) {
  const pathValue = process.env.PATH ?? '';
  const dirs = pathValue.split(path.delimiter).filter((dir) => dir.length > 0);
  for (const dir of dirs) {
    const fullPath = path.join(dir, name);
    if (fs.existsSync(fullPath)) {
      return true;
    }
    if (process.platform === 'win32') {
      for (const ext of ['.exe', '.cmd', '.bat']) {
        if (fs.existsSync(`${fullPath}${ext}`)) {
          return true;
        }
      }
    }
  }
  return false;
}

function validateWasmWith(executable, command, bytes) {
  if (!hasCommand(executable)) {
    return err(`${executable} not available`);
  }
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'starshine-node-'));
  const wasmPath = path.join(tempDir, 'differential.wasm');
  try {
    fs.writeFileSync(wasmPath, bytes);
    const result = childProcess.spawnSync(command[0], [...command.slice(1), wasmPath], {
      stdio: 'ignore',
    });
    if (result.error) {
      return err(errorMessage(result.error));
    }
    return ok(result.status === 0);
  } finally {
    fs.rmSync(tempDir, { recursive: true, force: true });
  }
}

function defaultDifferentialAdapters() {
  return createDifferentialAdapters(
    (bytes) => validateWasmWith('wasm-tools', ['wasm-tools', 'validate'], bytes),
    (bytes) => validateWasmWith('wasm-validate', ['wasm-validate'], bytes),
  );
}

function native_differential_tools_available() {
  return [hasCommand('wasm-tools'), hasCommand('wasm-validate')];
}

function decodeThenValidate(bytes) {
  const decoded = binary.decode_module(bytes);
  if (!decoded.ok) {
    return ok(false);
  }
  const validated = validate.validate_module(decoded.value);
  return ok(validated.ok);
}

function differential_validate_wasm(bytes, adapters = defaultDifferentialAdapters()) {
  const internalValid = decodeThenValidate(bytes);
  if (!internalValid.ok) {
    return err(`internal validation execution failed: ${internalValid.display ?? internalValid.error}`);
  }

  const chosenAdapters = normalizeDifferentialAdapters(adapters ?? defaultDifferentialAdapters());
  const wasmToolsResult = invokeResultCallback(
    chosenAdapters.wasm_tools_validate,
    [bytes],
    'wasm_tools_validate(bytes)',
  );
  const binaryenResult = invokeResultCallback(
    chosenAdapters.binaryen_validate,
    [bytes],
    'binaryen_validate(bytes)',
  );
  const wasmToolsValid = wasmToolsResult.ok ? wasmToolsResult.value : null;
  const binaryenValid = binaryenResult.ok ? binaryenResult.value : null;

  if (wasmToolsValid !== null && wasmToolsValid !== internalValid.value) {
    return err(`differential mismatch against wasm-tools: internal=${internalValid.value} wasm-tools=${wasmToolsValid}`);
  }
  if (binaryenValid !== null && binaryenValid !== internalValid.value) {
    return err(`differential mismatch against binaryen: internal=${internalValid.value} binaryen=${binaryenValid}`);
  }

  return ok(createDifferentialValidationReport(internalValid.value, wasmToolsValid, binaryenValid));
}

function fuzzClonePasses(values) {
  return [...values];
}

function fuzzWithoutPassIndex(values, skip) {
  return values.filter((_, index) => index !== skip);
}

function minimize_fuzz_passes(passNames, reproduces) {
  if (!reproduces(passNames)) {
    return fuzzClonePasses(passNames);
  }
  let current = fuzzClonePasses(passNames);
  let index = 0;
  while (index < current.length) {
    const candidate = fuzzWithoutPassIndex(current, index);
    if (reproduces(candidate)) {
      current = candidate;
    } else {
      index += 1;
    }
  }
  return current;
}

function fuzzSlug(value) {
  const lower = value.toLowerCase();
  const cleaned = lower.replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
  return cleaned.length === 0 ? 'unknown' : cleaned;
}

function fuzzJoinCsv(values) {
  return values.join(',');
}

function fuzzSingleLine(text) {
  return text.replace(/[\r\n]+/g, ' ');
}

function fuzzFailureMetaText(report) {
  return [
    `seed=${report.seed}`,
    `attempt=${report.attempt}`,
    `generatedValid=${report.generatedValid}`,
    `stage=${fuzzSingleLine(report.stage)}`,
    `message=${fuzzSingleLine(report.message)}`,
    `optimizePasses=${fuzzJoinCsv(report.optimizePasses)}`,
    `minimizedPasses=${fuzzJoinCsv(report.minimizedPasses)}`,
    '',
  ].join('\n');
}

function persist_fuzz_failure_report(report, io, corpus_dir = 'fuzz-corpus') {
  if (!isBranded(io, BRAND_FUZZ_FAILURE_PERSIST_IO)) {
    throw new TypeError('Expected a FuzzFailurePersistIO created with cmd.FuzzFailurePersistIO.new().');
  }
  io = normalizeFuzzFailurePersistIO(io);

  const trimmed = corpus_dir.trim();
  const dir = trimmed.length === 0 ? 'fuzz-corpus' : trimmed;
  const ensured = invokeResultCallback(io.ensure_dir, [dir], `ensure_dir(${dir})`);
  if (!ensured.ok) {
    return err(`failed to ensure corpus dir ${dir}: ${ensured.display ?? ensured.error}`);
  }

  const slug = fuzzSlug(report.stage);
  const prefix = `${dir}/seed-${report.seed}-attempt-${report.attempt}-valid-${report.generatedValid}-${slug}`;
  const metaPath = `${prefix}.meta.txt`;
  const metaBytes = stringToBytes(fuzzFailureMetaText(report));
  const metaWrite = invokeResultCallback(io.write_file, [metaPath, metaBytes], `write_file(${metaPath})`);
  if (!metaWrite.ok) {
    return err(`failed to write corpus metadata ${metaPath}: ${metaWrite.display ?? metaWrite.error}`);
  }

  let wasmPath = null;
  if (report.wasm !== null) {
    wasmPath = `${prefix}.wasm`;
    const wasmWrite = invokeResultCallback(io.write_file, [wasmPath, report.wasm], `write_file(${wasmPath})`);
    if (!wasmWrite.ok) {
      return err(`failed to write corpus wasm ${wasmPath}: ${wasmWrite.display ?? wasmWrite.error}`);
    }
  }

  return ok([metaPath, wasmPath]);
}

function fuzzFinalizeFailure(on_failure, report, message) {
  if (on_failure === null || on_failure === undefined) {
    return message;
  }
  const result = invokeResultCallback(on_failure, [report], 'on_failure(report)');
  return result.ok ? message : `${message}; failure callback error: ${result.display ?? result.error}`;
}

function run_wasm_smith_fuzz_harness(
  valid_target,
  seed = 0x5eedn,
  optimize_passes = [],
  optimize_pass_names = null,
  differential_adapters = null,
  differential_every = 0,
  on_failure = null,
) {
  const passNames = optimize_pass_names !== null
    ? fuzzClonePasses(optimize_pass_names)
    : optimize_passes.map((_, index) => `pass-${index}`);

  if (valid_target < 0) {
    const report = createFuzzFailureReport(
      seed,
      0,
      0,
      'config',
      'validTarget must be non-negative',
      passNames,
      passNames,
    );
    return err(fuzzFinalizeFailure(on_failure, report, 'validTarget must be non-negative'));
  }

  const rnd = wasm.__node_splitmix_new(seed);
  let attempts = 0;
  let generatedValid = 0;
  let generatedInvalid = 0;
  let pipelineValidated = 0;
  let optimizedCount = 0;
  let roundtripped = 0;
  let differentialChecked = 0;
  const maxAttempts = valid_target <= 0 ? 0 : valid_target * 25;

  while (generatedValid < valid_target) {
    if (attempts >= maxAttempts) {
      const message =
        `failed to reach valid target: target=${valid_target} attempts=${attempts} `
        + `valid=${generatedValid} invalid=${generatedInvalid}`;
      const report = createFuzzFailureReport(
        seed,
        attempts,
        generatedValid,
        'generation-target',
        message,
        passNames,
        passNames,
      );
      return err(fuzzFinalizeFailure(on_failure, report, message));
    }

    attempts += 1;
    const mod = validate.gen_valid_module(rnd);
    const validated = validate.validate_module(mod);
    if (!validated.ok) {
      generatedInvalid += 1;
      continue;
    }

    const encoded = binary.encode_module(mod);
    if (!encoded.ok) {
      generatedInvalid += 1;
      continue;
    }

    const decoded = binary.decode_module(encoded.value);
    if (!decoded.ok) {
      const message = `decode failed at attempt #${attempts}: ${decoded.display ?? decoded.error}`;
      const report = createFuzzFailureReport(
        seed,
        attempts,
        generatedValid,
        'decode',
        decoded.display ?? String(decoded.error),
        passNames,
        passNames,
        encoded.value,
      );
      return err(fuzzFinalizeFailure(on_failure, report, message));
    }

    const postDecodeValidated = validate.validate_module(decoded.value);
    if (!postDecodeValidated.ok) {
      const display = postDecodeValidated.display ?? String(postDecodeValidated.error);
      const message = `decoded module failed validation at attempt #${attempts}: ${display}`;
      const report = createFuzzFailureReport(
        seed,
        attempts,
        generatedValid,
        'post-decode-validate',
        display,
        passNames,
        passNames,
        encoded.value,
      );
      return err(fuzzFinalizeFailure(on_failure, report, message));
    }
    pipelineValidated += 1;

    const optimized = passes.optimize_module_with_options(decoded.value, optimize_passes, passes.OptimizeOptions.new());
    if (!optimized.ok) {
      const message = `optimize failed at attempt #${attempts}: ${optimized.display ?? optimized.error}`;
      const report = createFuzzFailureReport(
        seed,
        attempts,
        generatedValid,
        'optimize',
        optimized.display ?? String(optimized.error),
        passNames,
        passNames,
        encoded.value,
      );
      return err(fuzzFinalizeFailure(on_failure, report, message));
    }
    optimizedCount += 1;

    const roundtripBytes = binary.encode_module(optimized.value);
    if (!roundtripBytes.ok) {
      const message = `post-opt encode failed at attempt #${attempts}: ${roundtripBytes.display ?? roundtripBytes.error}`;
      const report = createFuzzFailureReport(
        seed,
        attempts,
        generatedValid,
        'post-opt-encode',
        roundtripBytes.display ?? String(roundtripBytes.error),
        passNames,
        passNames,
        encoded.value,
      );
      return err(fuzzFinalizeFailure(on_failure, report, message));
    }

    const roundtripMod = binary.decode_module(roundtripBytes.value);
    if (!roundtripMod.ok) {
      const message = `post-opt decode failed at attempt #${attempts}: ${roundtripMod.display ?? roundtripMod.error}`;
      const report = createFuzzFailureReport(
        seed,
        attempts,
        generatedValid,
        'post-opt-decode',
        roundtripMod.display ?? String(roundtripMod.error),
        passNames,
        passNames,
        roundtripBytes.value,
      );
      return err(fuzzFinalizeFailure(on_failure, report, message));
    }

    const postOptValidated = validate.validate_module(roundtripMod.value);
    if (!postOptValidated.ok) {
      const display = postOptValidated.display ?? String(postOptValidated.error);
      const message = `roundtripped module failed validation at attempt #${attempts}: ${display}`;
      const report = createFuzzFailureReport(
        seed,
        attempts,
        generatedValid,
        'post-opt-validate',
        display,
        passNames,
        passNames,
        roundtripBytes.value,
      );
      return err(fuzzFinalizeFailure(on_failure, report, message));
    }
    roundtripped += 1;
    generatedValid += 1;

    if (differential_every > 0 && generatedValid % differential_every === 0) {
      const adapters = differential_adapters ?? defaultDifferentialAdapters();
      const differential = differential_validate_wasm(roundtripBytes.value, adapters);
      if (!differential.ok) {
        const message = `differential validation failed at module #${generatedValid}: ${differential.display ?? differential.error}`;
        const report = createFuzzFailureReport(
          seed,
          attempts,
          generatedValid,
          'differential',
          differential.display ?? String(differential.error),
          passNames,
          passNames,
          roundtripBytes.value,
        );
        return err(fuzzFinalizeFailure(on_failure, report, message));
      }
      differentialChecked += 1;
    }
  }

  return ok(
    createWasmSmithFuzzStats(
      attempts,
      generatedValid,
      generatedInvalid,
      pipelineValidated,
      optimizedCount,
      roundtripped,
      differentialChecked,
    ),
  );
}

export const cmdHelpText = generated.cmdHelpText;
export const cmdVersionText = generated.cmdVersionText;
export const verifyReadmeApiSignatures = generated.verifyReadmeApiSignatures;
export const verifyReadmeApiSignaturesWithRequiredBlocks =
  generated.verifyReadmeApiSignaturesWithRequiredBlocks;

export const CmdEncodeError = Object.freeze({
  adapter(message) {
    return createCmdEncodeError('adapter', message, message);
  },
  encode(value) {
    return createCmdEncodeError('encode', binary.EncodeError.show(value), value);
  },
  show: showCmdEncodeError,
});

export const CmdError = Object.freeze({
  ambiguousOutputFile(filePath) {
    return createCmdError('AmbiguousOutputFile', filePath);
  },
  unknownPassFlag(flag) {
    return createCmdError('UnknownPassFlag', `unknown pass flag: ${flag}`);
  },
  show: showCmdError,
});

export const CmdIO = Object.freeze({
  new(...args) {
    const provided = countProvidedArgs(args);
    switch (provided) {
      case 0:
        return createCmdIO();
      case 1:
        return createCmdIO(args[0]);
      case 2:
        return createCmdIO(args[0], args[1]);
      case 3:
        return createCmdIO(args[0], args[1], args[2]);
      case 4:
        return createCmdIO(args[0], args[1], args[2], args[3]);
      case 5:
        return createCmdIO(args[0], args[1], args[2], args[3], args[4]);
      case 6:
        return createCmdIO(args[0], args[1], args[2], args[3], args[4], args[5]);
      case 7:
        return createCmdIO(args[0], args[1], args[2], args[3], args[4], args[5], args[6]);
      case 8:
        return createCmdIO(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]);
      case 9:
        return createCmdIO(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]);
      default:
        throw new TypeError('Invalid argument count for cmd.CmdIO::new.');
    }
  },
});

export const CmdRunSummary = Object.freeze({
  new(...args) {
    const provided = countProvidedArgs(args);
    switch (provided) {
      case 0:
        return createCmdRunSummary();
      case 1:
        return createCmdRunSummary(args[0]);
      case 2:
        return createCmdRunSummary(args[0], args[1]);
      case 3:
        return createCmdRunSummary(args[0], args[1], args[2]);
      case 4:
        return createCmdRunSummary(args[0], args[1], args[2], args[3]);
      case 5:
        return createCmdRunSummary(args[0], args[1], args[2], args[3], args[4]);
      case 6:
        return createCmdRunSummary(args[0], args[1], args[2], args[3], args[4], args[5]);
      case 7:
        return createCmdRunSummary(args[0], args[1], args[2], args[3], args[4], args[5], args[6]);
      case 8:
        return createCmdRunSummary(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]);
      case 9:
        return createCmdRunSummary(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]);
      default:
        throw new TypeError('Invalid argument count for cmd.CmdRunSummary::new.');
    }
  },
  show: showCmdRunSummary,
});

export const DifferentialAdapters = Object.freeze({
  new(wasmToolsValidate, binaryenValidate) {
    return createDifferentialAdapters(
      wasmToolsValidate ?? (() => err('wasm-tools differential validator unavailable')),
      binaryenValidate ?? (() => err('binaryen differential validator unavailable')),
    );
  },
});

export const DifferentialValidationReport = Object.freeze({
  show: showDifferentialValidationReport,
});

export const FuzzFailurePersistIO = Object.freeze({
  new(ensureDir, writeFile) {
    return createFuzzFailurePersistIO(
      ensureDir ?? ((dir) => err(`ensureDir not configured: ${dir}`)),
      writeFile ?? ((filePath) => err(`writeFile not configured: ${filePath}`)),
    );
  },
});

export const FuzzFailureReport = Object.freeze({
  new(...args) {
    const provided = countProvidedArgs(args);
    switch (provided) {
      case 5:
        return createFuzzFailureReport(args[0], args[1], args[2], args[3], args[4]);
      case 6:
        return createFuzzFailureReport(args[0], args[1], args[2], args[3], args[4], args[5]);
      case 7:
        return createFuzzFailureReport(args[0], args[1], args[2], args[3], args[4], args[5], args[6]);
      case 8:
        return createFuzzFailureReport(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]);
      default:
        throw new TypeError('Invalid argument count for cmd.FuzzFailureReport::new.');
    }
  },
  show: showFuzzFailureReport,
});

export const ReadmeApiVerifyBlock = generated.ReadmeApiVerifyBlock;

export const WasmSmithFuzzStats = Object.freeze({
  new(...args) {
    const provided = countProvidedArgs(args);
    switch (provided) {
      case 0:
        return createWasmSmithFuzzStats();
      case 1:
        return createWasmSmithFuzzStats(args[0]);
      case 2:
        return createWasmSmithFuzzStats(args[0], args[1]);
      case 3:
        return createWasmSmithFuzzStats(args[0], args[1], args[2]);
      case 4:
        return createWasmSmithFuzzStats(args[0], args[1], args[2], args[3]);
      case 5:
        return createWasmSmithFuzzStats(args[0], args[1], args[2], args[3], args[4]);
      case 6:
        return createWasmSmithFuzzStats(args[0], args[1], args[2], args[3], args[4], args[5]);
      case 7:
        return createWasmSmithFuzzStats(args[0], args[1], args[2], args[3], args[4], args[5], args[6]);
      default:
        throw new TypeError('Invalid argument count for cmd.WasmSmithFuzzStats::new.');
    }
  },
  show: showWasmSmithFuzzStats,
});

export {
  differential_validate_wasm as differentialValidateWasm,
  minimize_fuzz_passes as minimizeFuzzPasses,
  native_differential_tools_available as nativeDifferentialToolsAvailable,
  persist_fuzz_failure_report as persistFuzzFailureReport,
  run_cmd as runCmd,
  run_cmd_exit_code as runCmdExitCode,
  run_cmd_exit_code_with_adapter as runCmdExitCodeWithAdapter,
  run_cmd_with_adapter as runCmdWithAdapter,
  run_wasm_smith_fuzz_harness as runWasmSmithFuzzHarness,
};
