import { countProvidedArgs, getWasmGcExports, liftValue, lowerValue, unsupportedExport } from "./internal/runtime.js";

const wasm = await getWasmGcExports();

export const defaultConfigPath = "starshine.config.json";

export function cliConfigSchemaJson() {
  return liftValue({ kind: "string" }, wasm["cli__cli_config_schema_json"](), wasm);
}

export function expandGlobs(arg0, arg1) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, wasm["cli__expand_globs"](lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, arg1, wasm)), wasm);
}

export const expandGlobsWithAdapter = unsupportedExport("cli.expandGlobsWithAdapter", "Higher-order function parameters are not available through the wasm-gc adapter.");

export function globMatch(arg0, arg1) {
  return liftValue({ kind: "bool" }, wasm["cli__glob_match"](lowerValue({ kind: "string" }, arg0, wasm), lowerValue({ kind: "string" }, arg1, wasm)), wasm);
}

export function inferInputFormat(arg0) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_1_none","some":"__js_option_1_some","isSome":"__js_option_1_is_some","unwrap":"__js_option_1_unwrap"}, item: { kind: "named", brand: "cli.CliInputFormat", showExport: "__js_show_cli_CliInputFormat" } }, wasm["cli__infer_input_format"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
}

export function normalizeCliPath(arg0) {
  return liftValue({ kind: "string" }, wasm["cli__normalize_cli_path"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
}

export function parseCliArgs(arg0, starshineInput) {
  const provided = countProvidedArgs(arguments);
  switch (provided) {
    case 1:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_5_is_ok","unwrapOk":"__js_result_5_unwrap_ok","unwrapErr":"__js_result_5_unwrap_err"}, ok: { kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, err: { kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" } }, wasm["cli__parse_cli_args__arity_1"](lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, arg0, wasm)), wasm);
    case 2:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_5_is_ok","unwrapOk":"__js_result_5_unwrap_ok","unwrapErr":"__js_result_5_unwrap_err"}, ok: { kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, err: { kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" } }, wasm["cli__parse_cli_args"](lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, arg0, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "string" } }, starshineInput, wasm)), wasm);
    default:
      throw new TypeError("Invalid argument count for cli.parseCliArgs.");
  }
}

export function parseStarshineInputEnv(arg0) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, wasm["cli__parse_starshine_input_env"](lowerValue({ kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "string" } }, arg0, wasm)), wasm);
}

export function resolvePassFlags(arg0) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, wasm["cli__resolve_pass_flags"](lowerValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, arg0, wasm)), wasm);
}

export function resolveTrapsNeverHappen(arg0, defaultArg) {
  const provided = countProvidedArgs(arguments);
  switch (provided) {
    case 1:
      return liftValue({ kind: "bool" }, wasm["cli__resolve_traps_never_happen__arity_1"](lowerValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, arg0, wasm)), wasm);
    case 2:
      return liftValue({ kind: "bool" }, wasm["cli__resolve_traps_never_happen"](lowerValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, arg0, wasm), lowerValue({ kind: "bool" }, defaultArg, wasm)), wasm);
    default:
      throw new TypeError("Invalid argument count for cli.resolveTrapsNeverHappen.");
  }
}

export const CliInputFormat = Object.freeze({
  wasm() {
    return liftValue({ kind: "named", brand: "cli.CliInputFormat", showExport: "__js_show_cli_CliInputFormat" }, wasm["cli__CliInputFormat__wasm"](), wasm);
  },
  wast() {
    return liftValue({ kind: "named", brand: "cli.CliInputFormat", showExport: "__js_show_cli_CliInputFormat" }, wasm["cli__CliInputFormat__wast"](), wasm);
  },
  wat() {
    return liftValue({ kind: "named", brand: "cli.CliInputFormat", showExport: "__js_show_cli_CliInputFormat" }, wasm["cli__CliInputFormat__wat"](), wasm);
  },
  show(value) {
    return wasm["__js_show_cli_CliInputFormat"](value);
  },
});

export const CliOptimizationFlag = Object.freeze({
  olevel(arg0, arg1) {
    return liftValue({ kind: "named", brand: "cli.CliOptimizationFlag", showExport: "__js_show_cli_CliOptimizationFlag" }, wasm["cli__CliOptimizationFlag__olevel"](lowerValue({ kind: "number" }, arg0, wasm), lowerValue({ kind: "bool" }, arg1, wasm)), wasm);
  },
  optimize() {
    return liftValue({ kind: "named", brand: "cli.CliOptimizationFlag", showExport: "__js_show_cli_CliOptimizationFlag" }, wasm["cli__CliOptimizationFlag__optimize"](), wasm);
  },
  shrink() {
    return liftValue({ kind: "named", brand: "cli.CliOptimizationFlag", showExport: "__js_show_cli_CliOptimizationFlag" }, wasm["cli__CliOptimizationFlag__shrink"](), wasm);
  },
  show(value) {
    return wasm["__js_show_cli_CliOptimizationFlag"](value);
  },
});

export const CliOutputTarget = Object.freeze({
  dir(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliOutputTarget", showExport: "__js_show_cli_CliOutputTarget" }, wasm["cli__CliOutputTarget__dir"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
  },
  file(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliOutputTarget", showExport: "__js_show_cli_CliOutputTarget" }, wasm["cli__CliOutputTarget__file"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
  },
  stdout() {
    return liftValue({ kind: "named", brand: "cli.CliOutputTarget", showExport: "__js_show_cli_CliOutputTarget" }, wasm["cli__CliOutputTarget__stdout"](), wasm);
  },
  show(value) {
    return wasm["__js_show_cli_CliOutputTarget"](value);
  },
});

export const CliParseError = Object.freeze({
  invalidInputFormat(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" }, wasm["cli__CliParseError__invalid_input_format"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
  },
  invalidLongFlag(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" }, wasm["cli__CliParseError__invalid_long_flag"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
  },
  invalidOptimizationFlag(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" }, wasm["cli__CliParseError__invalid_optimization_flag"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
  },
  invalidTrapMode(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" }, wasm["cli__CliParseError__invalid_trap_mode"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
  },
  missingFlagValue(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" }, wasm["cli__CliParseError__missing_flag_value"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
  },
  stdinNeedsFormat() {
    return liftValue({ kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" }, wasm["cli__CliParseError__stdin_needs_format"](), wasm);
  },
  unexpectedFlagValue(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" }, wasm["cli__CliParseError__unexpected_flag_value"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
  },
  unknownShortFlag(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" }, wasm["cli__CliParseError__unknown_short_flag"](lowerValue({ kind: "char" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_cli_CliParseError"](value);
  },
});

export const CliParseResult = Object.freeze({
  new(configPath, inputGlobs, helpRequested, versionRequested, readStdin, inputFormat, outputTargets, passFlags, optimizeFlags, trapMode, monomorphizeMinBenefit, lowMemoryUnused, lowMemoryBound) {
    const provided = countProvidedArgs(arguments);
    switch (provided) {
      case 0:
        return liftValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, wasm["cli__CliParseResult__new__arity_0"](), wasm);
      case 1:
        return liftValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, wasm["cli__CliParseResult__new__arity_1"](lowerValue({ kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "string" } }, configPath, wasm)), wasm);
      case 2:
        return liftValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, wasm["cli__CliParseResult__new__arity_2"](lowerValue({ kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "string" } }, configPath, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputGlobs, wasm)), wasm);
      case 3:
        return liftValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, wasm["cli__CliParseResult__new__arity_3"](lowerValue({ kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "string" } }, configPath, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputGlobs, wasm), lowerValue({ kind: "bool" }, helpRequested, wasm)), wasm);
      case 4:
        return liftValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, wasm["cli__CliParseResult__new__arity_4"](lowerValue({ kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "string" } }, configPath, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputGlobs, wasm), lowerValue({ kind: "bool" }, helpRequested, wasm), lowerValue({ kind: "bool" }, versionRequested, wasm)), wasm);
      case 5:
        return liftValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, wasm["cli__CliParseResult__new__arity_5"](lowerValue({ kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "string" } }, configPath, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputGlobs, wasm), lowerValue({ kind: "bool" }, helpRequested, wasm), lowerValue({ kind: "bool" }, versionRequested, wasm), lowerValue({ kind: "bool" }, readStdin, wasm)), wasm);
      case 6:
        return liftValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, wasm["cli__CliParseResult__new__arity_6"](lowerValue({ kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "string" } }, configPath, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputGlobs, wasm), lowerValue({ kind: "bool" }, helpRequested, wasm), lowerValue({ kind: "bool" }, versionRequested, wasm), lowerValue({ kind: "bool" }, readStdin, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_1_none","some":"__js_option_1_some","isSome":"__js_option_1_is_some","unwrap":"__js_option_1_unwrap"}, item: { kind: "named", brand: "cli.CliInputFormat", showExport: "__js_show_cli_CliInputFormat" } }, inputFormat, wasm)), wasm);
      case 7:
        return liftValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, wasm["cli__CliParseResult__new__arity_7"](lowerValue({ kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "string" } }, configPath, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputGlobs, wasm), lowerValue({ kind: "bool" }, helpRequested, wasm), lowerValue({ kind: "bool" }, versionRequested, wasm), lowerValue({ kind: "bool" }, readStdin, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_1_none","some":"__js_option_1_some","isSome":"__js_option_1_is_some","unwrap":"__js_option_1_unwrap"}, item: { kind: "named", brand: "cli.CliInputFormat", showExport: "__js_show_cli_CliInputFormat" } }, inputFormat, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_2_new","push":"__js_array_2_push","length":"__js_array_2_length","get":"__js_array_2_get"}, item: { kind: "named", brand: "cli.CliOutputTarget", showExport: "__js_show_cli_CliOutputTarget" } }, outputTargets, wasm)), wasm);
      case 8:
        return liftValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, wasm["cli__CliParseResult__new__arity_8"](lowerValue({ kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "string" } }, configPath, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputGlobs, wasm), lowerValue({ kind: "bool" }, helpRequested, wasm), lowerValue({ kind: "bool" }, versionRequested, wasm), lowerValue({ kind: "bool" }, readStdin, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_1_none","some":"__js_option_1_some","isSome":"__js_option_1_is_some","unwrap":"__js_option_1_unwrap"}, item: { kind: "named", brand: "cli.CliInputFormat", showExport: "__js_show_cli_CliInputFormat" } }, inputFormat, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_2_new","push":"__js_array_2_push","length":"__js_array_2_length","get":"__js_array_2_get"}, item: { kind: "named", brand: "cli.CliOutputTarget", showExport: "__js_show_cli_CliOutputTarget" } }, outputTargets, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, passFlags, wasm)), wasm);
      case 9:
        return liftValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, wasm["cli__CliParseResult__new__arity_9"](lowerValue({ kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "string" } }, configPath, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputGlobs, wasm), lowerValue({ kind: "bool" }, helpRequested, wasm), lowerValue({ kind: "bool" }, versionRequested, wasm), lowerValue({ kind: "bool" }, readStdin, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_1_none","some":"__js_option_1_some","isSome":"__js_option_1_is_some","unwrap":"__js_option_1_unwrap"}, item: { kind: "named", brand: "cli.CliInputFormat", showExport: "__js_show_cli_CliInputFormat" } }, inputFormat, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_2_new","push":"__js_array_2_push","length":"__js_array_2_length","get":"__js_array_2_get"}, item: { kind: "named", brand: "cli.CliOutputTarget", showExport: "__js_show_cli_CliOutputTarget" } }, outputTargets, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, passFlags, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_3_new","push":"__js_array_3_push","length":"__js_array_3_length","get":"__js_array_3_get"}, item: { kind: "named", brand: "cli.CliOptimizationFlag", showExport: "__js_show_cli_CliOptimizationFlag" } }, optimizeFlags, wasm)), wasm);
      case 10:
        return liftValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, wasm["cli__CliParseResult__new__arity_10"](lowerValue({ kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "string" } }, configPath, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputGlobs, wasm), lowerValue({ kind: "bool" }, helpRequested, wasm), lowerValue({ kind: "bool" }, versionRequested, wasm), lowerValue({ kind: "bool" }, readStdin, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_1_none","some":"__js_option_1_some","isSome":"__js_option_1_is_some","unwrap":"__js_option_1_unwrap"}, item: { kind: "named", brand: "cli.CliInputFormat", showExport: "__js_show_cli_CliInputFormat" } }, inputFormat, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_2_new","push":"__js_array_2_push","length":"__js_array_2_length","get":"__js_array_2_get"}, item: { kind: "named", brand: "cli.CliOutputTarget", showExport: "__js_show_cli_CliOutputTarget" } }, outputTargets, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, passFlags, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_3_new","push":"__js_array_3_push","length":"__js_array_3_length","get":"__js_array_3_get"}, item: { kind: "named", brand: "cli.CliOptimizationFlag", showExport: "__js_show_cli_CliOptimizationFlag" } }, optimizeFlags, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "named", brand: "cli.TrapMode", showExport: "__js_show_cli_TrapMode" } }, trapMode, wasm)), wasm);
      case 11:
        return liftValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, wasm["cli__CliParseResult__new__arity_11"](lowerValue({ kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "string" } }, configPath, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputGlobs, wasm), lowerValue({ kind: "bool" }, helpRequested, wasm), lowerValue({ kind: "bool" }, versionRequested, wasm), lowerValue({ kind: "bool" }, readStdin, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_1_none","some":"__js_option_1_some","isSome":"__js_option_1_is_some","unwrap":"__js_option_1_unwrap"}, item: { kind: "named", brand: "cli.CliInputFormat", showExport: "__js_show_cli_CliInputFormat" } }, inputFormat, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_2_new","push":"__js_array_2_push","length":"__js_array_2_length","get":"__js_array_2_get"}, item: { kind: "named", brand: "cli.CliOutputTarget", showExport: "__js_show_cli_CliOutputTarget" } }, outputTargets, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, passFlags, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_3_new","push":"__js_array_3_push","length":"__js_array_3_length","get":"__js_array_3_get"}, item: { kind: "named", brand: "cli.CliOptimizationFlag", showExport: "__js_show_cli_CliOptimizationFlag" } }, optimizeFlags, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "named", brand: "cli.TrapMode", showExport: "__js_show_cli_TrapMode" } }, trapMode, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_4_none","some":"__js_option_4_some","isSome":"__js_option_4_is_some","unwrap":"__js_option_4_unwrap"}, item: { kind: "number" } }, monomorphizeMinBenefit, wasm)), wasm);
      case 12:
        return liftValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, wasm["cli__CliParseResult__new__arity_12"](lowerValue({ kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "string" } }, configPath, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputGlobs, wasm), lowerValue({ kind: "bool" }, helpRequested, wasm), lowerValue({ kind: "bool" }, versionRequested, wasm), lowerValue({ kind: "bool" }, readStdin, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_1_none","some":"__js_option_1_some","isSome":"__js_option_1_is_some","unwrap":"__js_option_1_unwrap"}, item: { kind: "named", brand: "cli.CliInputFormat", showExport: "__js_show_cli_CliInputFormat" } }, inputFormat, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_2_new","push":"__js_array_2_push","length":"__js_array_2_length","get":"__js_array_2_get"}, item: { kind: "named", brand: "cli.CliOutputTarget", showExport: "__js_show_cli_CliOutputTarget" } }, outputTargets, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, passFlags, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_3_new","push":"__js_array_3_push","length":"__js_array_3_length","get":"__js_array_3_get"}, item: { kind: "named", brand: "cli.CliOptimizationFlag", showExport: "__js_show_cli_CliOptimizationFlag" } }, optimizeFlags, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "named", brand: "cli.TrapMode", showExport: "__js_show_cli_TrapMode" } }, trapMode, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_4_none","some":"__js_option_4_some","isSome":"__js_option_4_is_some","unwrap":"__js_option_4_unwrap"}, item: { kind: "number" } }, monomorphizeMinBenefit, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_5_none","some":"__js_option_5_some","isSome":"__js_option_5_is_some","unwrap":"__js_option_5_unwrap"}, item: { kind: "bool" } }, lowMemoryUnused, wasm)), wasm);
      case 13:
        return liftValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, wasm["cli__CliParseResult__new"](lowerValue({ kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "string" } }, configPath, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputGlobs, wasm), lowerValue({ kind: "bool" }, helpRequested, wasm), lowerValue({ kind: "bool" }, versionRequested, wasm), lowerValue({ kind: "bool" }, readStdin, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_1_none","some":"__js_option_1_some","isSome":"__js_option_1_is_some","unwrap":"__js_option_1_unwrap"}, item: { kind: "named", brand: "cli.CliInputFormat", showExport: "__js_show_cli_CliInputFormat" } }, inputFormat, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_2_new","push":"__js_array_2_push","length":"__js_array_2_length","get":"__js_array_2_get"}, item: { kind: "named", brand: "cli.CliOutputTarget", showExport: "__js_show_cli_CliOutputTarget" } }, outputTargets, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, passFlags, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_3_new","push":"__js_array_3_push","length":"__js_array_3_length","get":"__js_array_3_get"}, item: { kind: "named", brand: "cli.CliOptimizationFlag", showExport: "__js_show_cli_CliOptimizationFlag" } }, optimizeFlags, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "named", brand: "cli.TrapMode", showExport: "__js_show_cli_TrapMode" } }, trapMode, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_4_none","some":"__js_option_4_some","isSome":"__js_option_4_is_some","unwrap":"__js_option_4_unwrap"}, item: { kind: "number" } }, monomorphizeMinBenefit, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_5_none","some":"__js_option_5_some","isSome":"__js_option_5_is_some","unwrap":"__js_option_5_unwrap"}, item: { kind: "bool" } }, lowMemoryUnused, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "bigint" } }, lowMemoryBound, wasm)), wasm);
      default:
        throw new TypeError("Invalid argument count for cli.CliParseResult.new.");
    }
  },
  show(value) {
    return wasm["__js_show_cli_CliParseResult"](value);
  },
});

export const TrapMode = Object.freeze({
  allow() {
    return liftValue({ kind: "named", brand: "cli.TrapMode", showExport: "__js_show_cli_TrapMode" }, wasm["cli__TrapMode__allow"](), wasm);
  },
  never() {
    return liftValue({ kind: "named", brand: "cli.TrapMode", showExport: "__js_show_cli_TrapMode" }, wasm["cli__TrapMode__never"](), wasm);
  },
  show(value) {
    return wasm["__js_show_cli_TrapMode"](value);
  },
});
