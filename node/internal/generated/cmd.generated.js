import { countProvidedArgs, getWasmGcExports, liftValue, lowerValue, unsupportedExport } from "../runtime.js";

const wasm = await getWasmGcExports();

export function cmdHelpText() {
  return liftValue({ kind: "string" }, wasm["cmd__cmd_help_text"](), wasm);
}

export function cmdVersionText() {
  return liftValue({ kind: "string" }, wasm["cmd__cmd_version_text"](), wasm);
}

export function differentialValidateWasm(arg0, adapters) {
  const provided = countProvidedArgs(arguments);
  switch (provided) {
    case 1:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_6_is_ok","unwrapOk":"__js_result_6_unwrap_ok","unwrapErr":"__js_result_6_unwrap_err"}, ok: { kind: "named", brand: "cmd.DifferentialValidationReport", showExport: "__js_show_cmd_DifferentialValidationReport" }, err: { kind: "string" } }, wasm["cmd__differential_validate_wasm__arity_1"](lowerValue({ kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_36_new","push":"__js_array_36_push","length":"__js_array_36_length","get":"__js_array_36_get"}} }, arg0, wasm)), wasm);
    case 2:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_6_is_ok","unwrapOk":"__js_result_6_unwrap_ok","unwrapErr":"__js_result_6_unwrap_err"}, ok: { kind: "named", brand: "cmd.DifferentialValidationReport", showExport: "__js_show_cmd_DifferentialValidationReport" }, err: { kind: "string" } }, wasm["cmd__differential_validate_wasm"](lowerValue({ kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_36_new","push":"__js_array_36_push","length":"__js_array_36_length","get":"__js_array_36_get"}} }, arg0, wasm), lowerValue({ kind: "named", brand: "cmd.DifferentialAdapters", showExport: null }, adapters, wasm)), wasm);
    default:
      throw new TypeError("Invalid argument count for cmd.differentialValidateWasm.");
  }
}

export const minimizeFuzzPasses = unsupportedExport("cmd.minimizeFuzzPasses", "Higher-order function parameters are not available through the wasm-gc adapter.");

export function nativeDifferentialToolsAvailable() {
  return liftValue({ kind: "tuple", helper: {"make":"__js_tuple_2_new","getters":["__js_tuple_2_get_0","__js_tuple_2_get_1"]}, items: [{ kind: "bool" }, { kind: "bool" }] }, wasm["cmd__native_differential_tools_available"](), wasm);
}

export function persistFuzzFailureReport(arg0, arg1, corpusDir) {
  const provided = countProvidedArgs(arguments);
  switch (provided) {
    case 2:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_7_is_ok","unwrapOk":"__js_result_7_unwrap_ok","unwrapErr":"__js_result_7_unwrap_err"}, ok: { kind: "tuple", helper: {"make":"__js_tuple_3_new","getters":["__js_tuple_3_get_0","__js_tuple_3_get_1"]}, items: [{ kind: "string" }, { kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "string" } }] }, err: { kind: "string" } }, wasm["cmd__persist_fuzz_failure_report__arity_2"](lowerValue({ kind: "named", brand: "cmd.FuzzFailureReport", showExport: "__js_show_cmd_FuzzFailureReport" }, arg0, wasm), lowerValue({ kind: "named", brand: "cmd.FuzzFailurePersistIO", showExport: null }, arg1, wasm)), wasm);
    case 3:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_7_is_ok","unwrapOk":"__js_result_7_unwrap_ok","unwrapErr":"__js_result_7_unwrap_err"}, ok: { kind: "tuple", helper: {"make":"__js_tuple_3_new","getters":["__js_tuple_3_get_0","__js_tuple_3_get_1"]}, items: [{ kind: "string" }, { kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "string" } }] }, err: { kind: "string" } }, wasm["cmd__persist_fuzz_failure_report"](lowerValue({ kind: "named", brand: "cmd.FuzzFailureReport", showExport: "__js_show_cmd_FuzzFailureReport" }, arg0, wasm), lowerValue({ kind: "named", brand: "cmd.FuzzFailurePersistIO", showExport: null }, arg1, wasm), lowerValue({ kind: "string" }, corpusDir, wasm)), wasm);
    default:
      throw new TypeError("Invalid argument count for cmd.persistFuzzFailureReport.");
  }
}

export function runCmd(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_8_is_ok","unwrapOk":"__js_result_8_unwrap_ok","unwrapErr":"__js_result_8_unwrap_err"}, ok: { kind: "named", brand: "cmd.CmdRunSummary", showExport: "__js_show_cmd_CmdRunSummary" }, err: { kind: "named", brand: "cmd.CmdError", showExport: "__js_show_cmd_CmdError" } }, wasm["cmd__run_cmd"](lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, arg0, wasm)), wasm);
}

export function runCmdExitCode(arg0) {
  return liftValue({ kind: "number" }, wasm["cmd__run_cmd_exit_code"](lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, arg0, wasm)), wasm);
}

export function runCmdExitCodeWithAdapter(arg0, arg1, configJson) {
  const provided = countProvidedArgs(arguments);
  switch (provided) {
    case 2:
      return liftValue({ kind: "number" }, wasm["cmd__run_cmd_exit_code_with_adapter__arity_2"](lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, arg0, wasm), lowerValue({ kind: "named", brand: "cmd.CmdIO", showExport: null }, arg1, wasm)), wasm);
    case 3:
      return liftValue({ kind: "number" }, wasm["cmd__run_cmd_exit_code_with_adapter"](lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, arg0, wasm), lowerValue({ kind: "named", brand: "cmd.CmdIO", showExport: null }, arg1, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "string" } }, configJson, wasm)), wasm);
    default:
      throw new TypeError("Invalid argument count for cmd.runCmdExitCodeWithAdapter.");
  }
}

export function runCmdWithAdapter(arg0, arg1, configJson) {
  const provided = countProvidedArgs(arguments);
  switch (provided) {
    case 2:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_8_is_ok","unwrapOk":"__js_result_8_unwrap_ok","unwrapErr":"__js_result_8_unwrap_err"}, ok: { kind: "named", brand: "cmd.CmdRunSummary", showExport: "__js_show_cmd_CmdRunSummary" }, err: { kind: "named", brand: "cmd.CmdError", showExport: "__js_show_cmd_CmdError" } }, wasm["cmd__run_cmd_with_adapter__arity_2"](lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, arg0, wasm), lowerValue({ kind: "named", brand: "cmd.CmdIO", showExport: null }, arg1, wasm)), wasm);
    case 3:
      return liftValue({ kind: "result", helper: {"isOk":"__js_result_8_is_ok","unwrapOk":"__js_result_8_unwrap_ok","unwrapErr":"__js_result_8_unwrap_err"}, ok: { kind: "named", brand: "cmd.CmdRunSummary", showExport: "__js_show_cmd_CmdRunSummary" }, err: { kind: "named", brand: "cmd.CmdError", showExport: "__js_show_cmd_CmdError" } }, wasm["cmd__run_cmd_with_adapter"](lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, arg0, wasm), lowerValue({ kind: "named", brand: "cmd.CmdIO", showExport: null }, arg1, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_2_none","some":"__js_option_2_some","isSome":"__js_option_2_is_some","unwrap":"__js_option_2_unwrap"}, item: { kind: "string" } }, configJson, wasm)), wasm);
    default:
      throw new TypeError("Invalid argument count for cmd.runCmdWithAdapter.");
  }
}

export const runWasmSmithFuzzHarness = unsupportedExport("cmd.runWasmSmithFuzzHarness", "Higher-order function parameters are not available through the wasm-gc adapter.");

export function verifyReadmeApiSignatures(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_9_is_ok","unwrapOk":"__js_result_9_unwrap_ok","unwrapErr":"__js_result_9_unwrap_err"}, ok: { kind: "unit" }, err: { kind: "string" } }, wasm["cmd__verify_readme_api_signatures"](lowerValue({ kind: "string" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_4_new","push":"__js_array_4_push","length":"__js_array_4_length","get":"__js_array_4_get"}, item: { kind: "tuple", helper: {"make":"__js_tuple_4_new","getters":["__js_tuple_4_get_0","__js_tuple_4_get_1"]}, items: [{ kind: "string" }, { kind: "string" }] } }, arg1, wasm)), wasm);
}

export function verifyReadmeApiSignaturesWithRequiredBlocks(arg0, arg1, arg2) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_9_is_ok","unwrapOk":"__js_result_9_unwrap_ok","unwrapErr":"__js_result_9_unwrap_err"}, ok: { kind: "unit" }, err: { kind: "string" } }, wasm["cmd__verify_readme_api_signatures_with_required_blocks"](lowerValue({ kind: "string" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_4_new","push":"__js_array_4_push","length":"__js_array_4_length","get":"__js_array_4_get"}, item: { kind: "tuple", helper: {"make":"__js_tuple_4_new","getters":["__js_tuple_4_get_0","__js_tuple_4_get_1"]}, items: [{ kind: "string" }, { kind: "string" }] } }, arg1, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, arg2, wasm)), wasm);
}

export const CmdEncodeError = Object.freeze({
  adapter(arg0) {
    return liftValue({ kind: "named", brand: "cmd.CmdEncodeError", showExport: "__js_show_cmd_CmdEncodeError" }, wasm["cmd__CmdEncodeError__adapter"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
  },
  encode(arg0) {
    return liftValue({ kind: "named", brand: "cmd.CmdEncodeError", showExport: "__js_show_cmd_CmdEncodeError" }, wasm["cmd__CmdEncodeError__encode"](lowerValue({ kind: "named", brand: "binary.EncodeError", showExport: "__js_show_binary_EncodeError" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_cmd_CmdEncodeError"](value);
  },
});

export const CmdError = Object.freeze({
  ambiguousOutputFile(arg0) {
    return liftValue({ kind: "named", brand: "cmd.CmdError", showExport: "__js_show_cmd_CmdError" }, wasm["cmd__CmdError__ambiguous_output_file"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
  },
  unknownPassFlag(arg0) {
    return liftValue({ kind: "named", brand: "cmd.CmdError", showExport: "__js_show_cmd_CmdError" }, wasm["cmd__CmdError__unknown_pass_flag"](lowerValue({ kind: "string" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_cmd_CmdError"](value);
  },
});

export const CmdIO = Object.freeze({
  new: unsupportedExport("cmd.CmdIO.new", "Higher-order function parameters are not available through the wasm-gc adapter."),
});

export const CmdRunSummary = Object.freeze({
  new(inputFiles, outputFiles, resolvedPasses, optimizeLevel, shrinkLevel, trapsNeverHappen, monomorphizeMinBenefit, lowMemoryUnused, lowMemoryBound) {
    const provided = countProvidedArgs(arguments);
    switch (provided) {
      case 0:
        return liftValue({ kind: "named", brand: "cmd.CmdRunSummary", showExport: "__js_show_cmd_CmdRunSummary" }, wasm["cmd__CmdRunSummary__new__arity_0"](), wasm);
      case 1:
        return liftValue({ kind: "named", brand: "cmd.CmdRunSummary", showExport: "__js_show_cmd_CmdRunSummary" }, wasm["cmd__CmdRunSummary__new__arity_1"](lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputFiles, wasm)), wasm);
      case 2:
        return liftValue({ kind: "named", brand: "cmd.CmdRunSummary", showExport: "__js_show_cmd_CmdRunSummary" }, wasm["cmd__CmdRunSummary__new__arity_2"](lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputFiles, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, outputFiles, wasm)), wasm);
      case 3:
        return liftValue({ kind: "named", brand: "cmd.CmdRunSummary", showExport: "__js_show_cmd_CmdRunSummary" }, wasm["cmd__CmdRunSummary__new__arity_3"](lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputFiles, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, outputFiles, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, resolvedPasses, wasm)), wasm);
      case 4:
        return liftValue({ kind: "named", brand: "cmd.CmdRunSummary", showExport: "__js_show_cmd_CmdRunSummary" }, wasm["cmd__CmdRunSummary__new__arity_4"](lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputFiles, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, outputFiles, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, resolvedPasses, wasm), lowerValue({ kind: "number" }, optimizeLevel, wasm)), wasm);
      case 5:
        return liftValue({ kind: "named", brand: "cmd.CmdRunSummary", showExport: "__js_show_cmd_CmdRunSummary" }, wasm["cmd__CmdRunSummary__new__arity_5"](lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputFiles, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, outputFiles, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, resolvedPasses, wasm), lowerValue({ kind: "number" }, optimizeLevel, wasm), lowerValue({ kind: "number" }, shrinkLevel, wasm)), wasm);
      case 6:
        return liftValue({ kind: "named", brand: "cmd.CmdRunSummary", showExport: "__js_show_cmd_CmdRunSummary" }, wasm["cmd__CmdRunSummary__new__arity_6"](lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputFiles, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, outputFiles, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, resolvedPasses, wasm), lowerValue({ kind: "number" }, optimizeLevel, wasm), lowerValue({ kind: "number" }, shrinkLevel, wasm), lowerValue({ kind: "bool" }, trapsNeverHappen, wasm)), wasm);
      case 7:
        return liftValue({ kind: "named", brand: "cmd.CmdRunSummary", showExport: "__js_show_cmd_CmdRunSummary" }, wasm["cmd__CmdRunSummary__new__arity_7"](lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputFiles, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, outputFiles, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, resolvedPasses, wasm), lowerValue({ kind: "number" }, optimizeLevel, wasm), lowerValue({ kind: "number" }, shrinkLevel, wasm), lowerValue({ kind: "bool" }, trapsNeverHappen, wasm), lowerValue({ kind: "number" }, monomorphizeMinBenefit, wasm)), wasm);
      case 8:
        return liftValue({ kind: "named", brand: "cmd.CmdRunSummary", showExport: "__js_show_cmd_CmdRunSummary" }, wasm["cmd__CmdRunSummary__new__arity_8"](lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputFiles, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, outputFiles, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, resolvedPasses, wasm), lowerValue({ kind: "number" }, optimizeLevel, wasm), lowerValue({ kind: "number" }, shrinkLevel, wasm), lowerValue({ kind: "bool" }, trapsNeverHappen, wasm), lowerValue({ kind: "number" }, monomorphizeMinBenefit, wasm), lowerValue({ kind: "bool" }, lowMemoryUnused, wasm)), wasm);
      case 9:
        return liftValue({ kind: "named", brand: "cmd.CmdRunSummary", showExport: "__js_show_cmd_CmdRunSummary" }, wasm["cmd__CmdRunSummary__new"](lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, inputFiles, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, outputFiles, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, resolvedPasses, wasm), lowerValue({ kind: "number" }, optimizeLevel, wasm), lowerValue({ kind: "number" }, shrinkLevel, wasm), lowerValue({ kind: "bool" }, trapsNeverHappen, wasm), lowerValue({ kind: "number" }, monomorphizeMinBenefit, wasm), lowerValue({ kind: "bool" }, lowMemoryUnused, wasm), lowerValue({ kind: "bigint" }, lowMemoryBound, wasm)), wasm);
      default:
        throw new TypeError("Invalid argument count for cmd.CmdRunSummary.new.");
    }
  },
  show(value) {
    return wasm["__js_show_cmd_CmdRunSummary"](value);
  },
});

export const DifferentialAdapters = Object.freeze({
  new: unsupportedExport("cmd.DifferentialAdapters.new", "Higher-order function parameters are not available through the wasm-gc adapter."),
});

export const DifferentialValidationReport = Object.freeze({
  show(value) {
    return wasm["__js_show_cmd_DifferentialValidationReport"](value);
  },
});

export const FuzzFailurePersistIO = Object.freeze({
  new: unsupportedExport("cmd.FuzzFailurePersistIO.new", "Higher-order function parameters are not available through the wasm-gc adapter."),
});

export const FuzzFailureReport = Object.freeze({
  new(arg0, arg1, arg2, arg3, arg4, optimizePasses, minimizedPasses, wasm) {
    const provided = countProvidedArgs(arguments);
    switch (provided) {
      case 5:
        return liftValue({ kind: "named", brand: "cmd.FuzzFailureReport", showExport: "__js_show_cmd_FuzzFailureReport" }, wasm["cmd__FuzzFailureReport__new__arity_5"](lowerValue({ kind: "bigint" }, arg0, wasm), lowerValue({ kind: "number" }, arg1, wasm), lowerValue({ kind: "number" }, arg2, wasm), lowerValue({ kind: "string" }, arg3, wasm), lowerValue({ kind: "string" }, arg4, wasm)), wasm);
      case 6:
        return liftValue({ kind: "named", brand: "cmd.FuzzFailureReport", showExport: "__js_show_cmd_FuzzFailureReport" }, wasm["cmd__FuzzFailureReport__new__arity_6"](lowerValue({ kind: "bigint" }, arg0, wasm), lowerValue({ kind: "number" }, arg1, wasm), lowerValue({ kind: "number" }, arg2, wasm), lowerValue({ kind: "string" }, arg3, wasm), lowerValue({ kind: "string" }, arg4, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, optimizePasses, wasm)), wasm);
      case 7:
        return liftValue({ kind: "named", brand: "cmd.FuzzFailureReport", showExport: "__js_show_cmd_FuzzFailureReport" }, wasm["cmd__FuzzFailureReport__new__arity_7"](lowerValue({ kind: "bigint" }, arg0, wasm), lowerValue({ kind: "number" }, arg1, wasm), lowerValue({ kind: "number" }, arg2, wasm), lowerValue({ kind: "string" }, arg3, wasm), lowerValue({ kind: "string" }, arg4, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, optimizePasses, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, minimizedPasses, wasm)), wasm);
      case 8:
        return liftValue({ kind: "named", brand: "cmd.FuzzFailureReport", showExport: "__js_show_cmd_FuzzFailureReport" }, wasm["cmd__FuzzFailureReport__new"](lowerValue({ kind: "bigint" }, arg0, wasm), lowerValue({ kind: "number" }, arg1, wasm), lowerValue({ kind: "number" }, arg2, wasm), lowerValue({ kind: "string" }, arg3, wasm), lowerValue({ kind: "string" }, arg4, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, optimizePasses, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_1_new","push":"__js_array_1_push","length":"__js_array_1_length","get":"__js_array_1_get"}, item: { kind: "string" } }, minimizedPasses, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_7_none","some":"__js_option_7_some","isSome":"__js_option_7_is_some","unwrap":"__js_option_7_unwrap"}, item: { kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_36_new","push":"__js_array_36_push","length":"__js_array_36_length","get":"__js_array_36_get"}} } }, wasm, wasm)), wasm);
      default:
        throw new TypeError("Invalid argument count for cmd.FuzzFailureReport.new.");
    }
  },
  show(value) {
    return wasm["__js_show_cmd_FuzzFailureReport"](value);
  },
});

export const ReadmeApiVerifyBlock = Object.freeze({
  show(value) {
    return wasm["__js_show_cmd_ReadmeApiVerifyBlock"](value);
  },
});

export const WasmSmithFuzzStats = Object.freeze({
  new(attempts, generatedValid, generatedInvalid, pipelineValidated, optimized, roundtripped, differentialChecked) {
    const provided = countProvidedArgs(arguments);
    switch (provided) {
      case 0:
        return liftValue({ kind: "named", brand: "cmd.WasmSmithFuzzStats", showExport: "__js_show_cmd_WasmSmithFuzzStats" }, wasm["cmd__WasmSmithFuzzStats__new__arity_0"](), wasm);
      case 1:
        return liftValue({ kind: "named", brand: "cmd.WasmSmithFuzzStats", showExport: "__js_show_cmd_WasmSmithFuzzStats" }, wasm["cmd__WasmSmithFuzzStats__new__arity_1"](lowerValue({ kind: "number" }, attempts, wasm)), wasm);
      case 2:
        return liftValue({ kind: "named", brand: "cmd.WasmSmithFuzzStats", showExport: "__js_show_cmd_WasmSmithFuzzStats" }, wasm["cmd__WasmSmithFuzzStats__new__arity_2"](lowerValue({ kind: "number" }, attempts, wasm), lowerValue({ kind: "number" }, generatedValid, wasm)), wasm);
      case 3:
        return liftValue({ kind: "named", brand: "cmd.WasmSmithFuzzStats", showExport: "__js_show_cmd_WasmSmithFuzzStats" }, wasm["cmd__WasmSmithFuzzStats__new__arity_3"](lowerValue({ kind: "number" }, attempts, wasm), lowerValue({ kind: "number" }, generatedValid, wasm), lowerValue({ kind: "number" }, generatedInvalid, wasm)), wasm);
      case 4:
        return liftValue({ kind: "named", brand: "cmd.WasmSmithFuzzStats", showExport: "__js_show_cmd_WasmSmithFuzzStats" }, wasm["cmd__WasmSmithFuzzStats__new__arity_4"](lowerValue({ kind: "number" }, attempts, wasm), lowerValue({ kind: "number" }, generatedValid, wasm), lowerValue({ kind: "number" }, generatedInvalid, wasm), lowerValue({ kind: "number" }, pipelineValidated, wasm)), wasm);
      case 5:
        return liftValue({ kind: "named", brand: "cmd.WasmSmithFuzzStats", showExport: "__js_show_cmd_WasmSmithFuzzStats" }, wasm["cmd__WasmSmithFuzzStats__new__arity_5"](lowerValue({ kind: "number" }, attempts, wasm), lowerValue({ kind: "number" }, generatedValid, wasm), lowerValue({ kind: "number" }, generatedInvalid, wasm), lowerValue({ kind: "number" }, pipelineValidated, wasm), lowerValue({ kind: "number" }, optimized, wasm)), wasm);
      case 6:
        return liftValue({ kind: "named", brand: "cmd.WasmSmithFuzzStats", showExport: "__js_show_cmd_WasmSmithFuzzStats" }, wasm["cmd__WasmSmithFuzzStats__new__arity_6"](lowerValue({ kind: "number" }, attempts, wasm), lowerValue({ kind: "number" }, generatedValid, wasm), lowerValue({ kind: "number" }, generatedInvalid, wasm), lowerValue({ kind: "number" }, pipelineValidated, wasm), lowerValue({ kind: "number" }, optimized, wasm), lowerValue({ kind: "number" }, roundtripped, wasm)), wasm);
      case 7:
        return liftValue({ kind: "named", brand: "cmd.WasmSmithFuzzStats", showExport: "__js_show_cmd_WasmSmithFuzzStats" }, wasm["cmd__WasmSmithFuzzStats__new"](lowerValue({ kind: "number" }, attempts, wasm), lowerValue({ kind: "number" }, generatedValid, wasm), lowerValue({ kind: "number" }, generatedInvalid, wasm), lowerValue({ kind: "number" }, pipelineValidated, wasm), lowerValue({ kind: "number" }, optimized, wasm), lowerValue({ kind: "number" }, roundtripped, wasm), lowerValue({ kind: "number" }, differentialChecked, wasm)), wasm);
      default:
        throw new TypeError("Invalid argument count for cmd.WasmSmithFuzzStats.new.");
    }
  },
  show(value) {
    return wasm["__js_show_cmd_WasmSmithFuzzStats"](value);
  },
});
