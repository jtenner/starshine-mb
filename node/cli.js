import { countProvidedArgs, getWasmGcExports, liftValue, lowerValue, unsupportedExport } from "./internal/runtime.js";

const wasm = await getWasmGcExports();

export const defaultConfigPath = "starshine.config.json";

export function cliConfigSchemaJson() {
  return liftValue({ kind: "string", moonType: "String" }, wasm["cli__cli_config_schema_json"](), wasm);
}

export function expandGlobs(arg0, arg1) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } }, wasm["cli__expand_globs"](lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } }, arg1, wasm)), wasm);
}

export const expandGlobsWithAdapter = unsupportedExport("cli.expandGlobsWithAdapter", "Higher-order MoonBit callbacks require an explicit JavaScript adapter.");

export function globMatch(arg0, arg1) {
  return liftValue({ kind: "bool", moonType: "Bool" }, wasm["cli__glob_match"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "string", moonType: "String" }, arg1, wasm)), wasm);
}

export function inferInputFormat(arg0) {
  return liftValue({ kind: "option", helper: {"none":"__js_option_4_none","some":"__js_option_4_some","isSome":"__js_option_4_is_some","unwrap":"__js_option_4_unwrap"}, item: { kind: "named", brand: "cli.CliInputFormat", showExport: "__js_show_cli_CliInputFormat" } }, wasm["cli__infer_input_format"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
}

export function normalizeCliPath(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["cli__normalize_cli_path"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
}

export function parseCliArgs(arg0, starshineInput) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_10_is_ok","unwrapOk":"__js_result_10_unwrap_ok","unwrapErr":"__js_result_10_unwrap_err"}, ok: { kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, err: { kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" } }, wasm["cli__parse_cli_args"](lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_5_none","some":"__js_option_5_some","isSome":"__js_option_5_is_some","unwrap":"__js_option_5_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } } }, starshineInput, wasm)), wasm);
}

export function parseStarshineInputEnv(arg0) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } }, wasm["cli__parse_starshine_input_env"](lowerValue({ kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, arg0, wasm)), wasm);
}

export function resolveClosedWorld(arg0, defaultArg) {
  return liftValue({ kind: "bool", moonType: "Bool" }, wasm["cli__resolve_closed_world"](lowerValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, defaultArg, wasm)), wasm);
}

export function resolveIgnoreImplicitTraps(arg0) {
  return liftValue({ kind: "bool", moonType: "Bool" }, wasm["cli__resolve_ignore_implicit_traps"](lowerValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, arg0, wasm)), wasm);
}

export function resolvePassFlags(arg0) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } }, wasm["cli__resolve_pass_flags"](lowerValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, arg0, wasm)), wasm);
}

export function resolveTrapsNeverHappen(arg0, defaultArg) {
  return liftValue({ kind: "bool", moonType: "Bool" }, wasm["cli__resolve_traps_never_happen"](lowerValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, defaultArg, wasm)), wasm);
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
    return wasm["__js_show_cli_CliInputFormat"](lowerValue({ kind: "named", brand: "cli.CliInputFormat" }, value, wasm));
  },
});

export const CliOptimizationFlag = Object.freeze({
  olevel(arg0, arg1) {
    return liftValue({ kind: "named", brand: "cli.CliOptimizationFlag", showExport: "__js_show_cli_CliOptimizationFlag" }, wasm["cli__CliOptimizationFlag__olevel"](lowerValue({ kind: "number", moonType: "Int" }, arg0, wasm), lowerValue({ kind: "bool", moonType: "Bool" }, arg1, wasm)), wasm);
  },
  optimize() {
    return liftValue({ kind: "named", brand: "cli.CliOptimizationFlag", showExport: "__js_show_cli_CliOptimizationFlag" }, wasm["cli__CliOptimizationFlag__optimize"](), wasm);
  },
  osize() {
    return liftValue({ kind: "named", brand: "cli.CliOptimizationFlag", showExport: "__js_show_cli_CliOptimizationFlag" }, wasm["cli__CliOptimizationFlag__osize"](), wasm);
  },
  shrink() {
    return liftValue({ kind: "named", brand: "cli.CliOptimizationFlag", showExport: "__js_show_cli_CliOptimizationFlag" }, wasm["cli__CliOptimizationFlag__shrink"](), wasm);
  },
  show(value) {
    return wasm["__js_show_cli_CliOptimizationFlag"](lowerValue({ kind: "named", brand: "cli.CliOptimizationFlag" }, value, wasm));
  },
});

export const CliOutputTarget = Object.freeze({
  dir(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliOutputTarget", showExport: "__js_show_cli_CliOutputTarget" }, wasm["cli__CliOutputTarget__dir"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
  file(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliOutputTarget", showExport: "__js_show_cli_CliOutputTarget" }, wasm["cli__CliOutputTarget__file"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
  stdout() {
    return liftValue({ kind: "named", brand: "cli.CliOutputTarget", showExport: "__js_show_cli_CliOutputTarget" }, wasm["cli__CliOutputTarget__stdout"](), wasm);
  },
  show(value) {
    return wasm["__js_show_cli_CliOutputTarget"](lowerValue({ kind: "named", brand: "cli.CliOutputTarget" }, value, wasm));
  },
});

export const CliParseError = Object.freeze({
  invalidDumpPath(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" }, wasm["cli__CliParseError__invalid_dump_path"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
  invalidFunctionIndexList(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" }, wasm["cli__CliParseError__invalid_function_index_list"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
  invalidInputFormat(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" }, wasm["cli__CliParseError__invalid_input_format"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
  invalidLongFlag(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" }, wasm["cli__CliParseError__invalid_long_flag"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
  invalidOptimizationFlag(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" }, wasm["cli__CliParseError__invalid_optimization_flag"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
  invalidTracingLevel(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" }, wasm["cli__CliParseError__invalid_tracing_level"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
  invalidTrapMode(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" }, wasm["cli__CliParseError__invalid_trap_mode"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
  missingFlagValue(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" }, wasm["cli__CliParseError__missing_flag_value"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
  stdinNeedsFormat() {
    return liftValue({ kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" }, wasm["cli__CliParseError__stdin_needs_format"](), wasm);
  },
  unexpectedFlagValue(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" }, wasm["cli__CliParseError__unexpected_flag_value"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
  unknownShortFlag(arg0) {
    return liftValue({ kind: "named", brand: "cli.CliParseError", showExport: "__js_show_cli_CliParseError" }, wasm["cli__CliParseError__unknown_short_flag"](lowerValue({ kind: "char", moonType: "Char" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_cli_CliParseError"](lowerValue({ kind: "named", brand: "cli.CliParseError" }, value, wasm));
  },
});

export const CliParseResult = Object.freeze({
  new(configPath, inputGlobs, globEnabled, helpRequested, versionRequested, debugSerialPasses, readStdin, inputFormat, outputTargets, passFlags, optimizeFlags, trapMode, monomorphizeMinBenefit, lowMemoryUnused, lowMemoryBound, tracing, ignoreImplicitTraps, inliningAlwaysInlineMaxSize, inliningOneCallerInlineMaxSize, inliningFlexibleInlineMaxSize, inliningMaxCombinedBinarySize, inliningAllowFunctionsWithLoops, inliningPartialInliningIfs, closedWorld, compilerFactsPolicy) {
    return liftValue({ kind: "named", brand: "cli.CliParseResult", showExport: "__js_show_cli_CliParseResult" }, wasm["cli__CliParseResult__new"](lowerValue({ kind: "optional", helper: {"none":"__js_option_5_none","some":"__js_option_5_some","isSome":"__js_option_5_is_some","unwrap":"__js_option_5_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } } }, configPath, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_7_none","some":"__js_option_7_some","isSome":"__js_option_7_is_some","unwrap":"__js_option_7_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } } }, inputGlobs, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, globEnabled, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, helpRequested, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, versionRequested, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, debugSerialPasses, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, readStdin, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_8_none","some":"__js_option_8_some","isSome":"__js_option_8_is_some","unwrap":"__js_option_8_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_4_none","some":"__js_option_4_some","isSome":"__js_option_4_is_some","unwrap":"__js_option_4_unwrap"}, item: { kind: "named", brand: "cli.CliInputFormat", showExport: "__js_show_cli_CliInputFormat" } } }, inputFormat, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_9_none","some":"__js_option_9_some","isSome":"__js_option_9_is_some","unwrap":"__js_option_9_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_7_new","push":"__js_array_7_push","length":"__js_array_7_length","get":"__js_array_7_get"}, item: { kind: "named", brand: "cli.CliOutputTarget", showExport: "__js_show_cli_CliOutputTarget" } } }, outputTargets, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_7_none","some":"__js_option_7_some","isSome":"__js_option_7_is_some","unwrap":"__js_option_7_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } } }, passFlags, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_10_none","some":"__js_option_10_some","isSome":"__js_option_10_is_some","unwrap":"__js_option_10_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_8_new","push":"__js_array_8_push","length":"__js_array_8_length","get":"__js_array_8_get"}, item: { kind: "named", brand: "cli.CliOptimizationFlag", showExport: "__js_show_cli_CliOptimizationFlag" } } }, optimizeFlags, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_11_none","some":"__js_option_11_some","isSome":"__js_option_11_is_some","unwrap":"__js_option_11_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_12_none","some":"__js_option_12_some","isSome":"__js_option_12_is_some","unwrap":"__js_option_12_unwrap"}, item: { kind: "named", brand: "cli.TrapMode", showExport: "__js_show_cli_TrapMode" } } }, trapMode, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_13_none","some":"__js_option_13_some","isSome":"__js_option_13_is_some","unwrap":"__js_option_13_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } } }, monomorphizeMinBenefit, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_15_none","some":"__js_option_15_some","isSome":"__js_option_15_is_some","unwrap":"__js_option_15_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } } }, lowMemoryUnused, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_16_none","some":"__js_option_16_some","isSome":"__js_option_16_is_some","unwrap":"__js_option_16_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_17_none","some":"__js_option_17_some","isSome":"__js_option_17_is_some","unwrap":"__js_option_17_unwrap"}, item: { kind: "bigint", moonType: "UInt64" } } }, lowMemoryBound, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_18_none","some":"__js_option_18_some","isSome":"__js_option_18_is_some","unwrap":"__js_option_18_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_19_none","some":"__js_option_19_some","isSome":"__js_option_19_is_some","unwrap":"__js_option_19_unwrap"}, item: { kind: "named", brand: "cli.CliTracingLevel", showExport: "__js_show_cli_CliTracingLevel" } } }, tracing, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, ignoreImplicitTraps, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_13_none","some":"__js_option_13_some","isSome":"__js_option_13_is_some","unwrap":"__js_option_13_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } } }, inliningAlwaysInlineMaxSize, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_13_none","some":"__js_option_13_some","isSome":"__js_option_13_is_some","unwrap":"__js_option_13_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } } }, inliningOneCallerInlineMaxSize, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_13_none","some":"__js_option_13_some","isSome":"__js_option_13_is_some","unwrap":"__js_option_13_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } } }, inliningFlexibleInlineMaxSize, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_13_none","some":"__js_option_13_some","isSome":"__js_option_13_is_some","unwrap":"__js_option_13_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } } }, inliningMaxCombinedBinarySize, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_15_none","some":"__js_option_15_some","isSome":"__js_option_15_is_some","unwrap":"__js_option_15_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } } }, inliningAllowFunctionsWithLoops, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_13_none","some":"__js_option_13_some","isSome":"__js_option_13_is_some","unwrap":"__js_option_13_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } } }, inliningPartialInliningIfs, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_15_none","some":"__js_option_15_some","isSome":"__js_option_15_is_some","unwrap":"__js_option_15_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } } }, closedWorld, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_5_none","some":"__js_option_5_some","isSome":"__js_option_5_is_some","unwrap":"__js_option_5_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } } }, compilerFactsPolicy, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_cli_CliParseResult"](lowerValue({ kind: "named", brand: "cli.CliParseResult" }, value, wasm));
  },
});

export const CliTracingLevel = Object.freeze({
  helper() {
    return liftValue({ kind: "named", brand: "cli.CliTracingLevel", showExport: "__js_show_cli_CliTracingLevel" }, wasm["cli__CliTracingLevel__helper"](), wasm);
  },
  pass() {
    return liftValue({ kind: "named", brand: "cli.CliTracingLevel", showExport: "__js_show_cli_CliTracingLevel" }, wasm["cli__CliTracingLevel__pass"](), wasm);
  },
  phase() {
    return liftValue({ kind: "named", brand: "cli.CliTracingLevel", showExport: "__js_show_cli_CliTracingLevel" }, wasm["cli__CliTracingLevel__phase"](), wasm);
  },
  show(value) {
    return wasm["__js_show_cli_CliTracingLevel"](lowerValue({ kind: "named", brand: "cli.CliTracingLevel" }, value, wasm));
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
    return wasm["__js_show_cli_TrapMode"](lowerValue({ kind: "named", brand: "cli.TrapMode" }, value, wasm));
  },
});
