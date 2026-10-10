import { countProvidedArgs, getWasmGcExports, liftValue, lowerValue, unsupportedExport } from "../runtime.js";

const wasm = await getWasmGcExports();

export function binaryDifferentialClassificationLabel(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["cmd__binary_differential_classification_label"](lowerValue({ kind: "named", brand: "cmd.BinaryDifferentialClassification", showExport: null }, arg0, wasm)), wasm);
}

export function binaryDifferentialFailedValidationResult(arg0, arg1, arg2) {
  return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialAdapterResult", showExport: null }, wasm["cmd__binary_differential_failed_validation_result"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_67_new","push":"__js_array_67_push","length":"__js_array_67_length","get":"__js_array_67_get"}} }, arg1, wasm), lowerValue({ kind: "string", moonType: "String" }, arg2, wasm)), wasm);
}

export function chooseSimpleExportInvocationArgs(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_11_is_ok","unwrapOk":"__js_result_11_unwrap_ok","unwrapErr":"__js_result_11_unwrap_err"}, ok: { kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } }, err: { kind: "string", moonType: "String" } }, wasm["cmd__choose_simple_export_invocation_args"](lowerValue({ kind: "array", helper: {"new":"__js_array_9_new","push":"__js_array_9_push","length":"__js_array_9_length","get":"__js_array_9_get"}, item: { kind: "named", brand: "lib.ValType", showExport: "__js_show_lib_ValType" } }, arg0, wasm)), wasm);
}

export function classifyBinaryCanonicalityDifferential(arg0, arg1, arg2, arg3) {
  return liftValue({ kind: "named", brand: "cmd.BinaryCanonicalityClassification", showExport: null }, wasm["cmd__classify_binary_canonicality_differential"](lowerValue({ kind: "named", brand: "cmd.BinaryCanonicalityInputClass", showExport: null }, arg0, wasm), lowerValue({ kind: "bool", moonType: "Bool" }, arg1, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, arg2, wasm), lowerValue({ kind: "option", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, arg3, wasm)), wasm);
}

export function classifyBinaryDifferentialResults(arg0) {
  return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialClassification", showExport: null }, wasm["cmd__classify_binary_differential_results"](lowerValue({ kind: "array", helper: {"new":"__js_array_10_new","push":"__js_array_10_push","length":"__js_array_10_length","get":"__js_array_10_get"}, item: { kind: "named", brand: "cmd.BinaryDifferentialAdapterResult", showExport: null } }, arg0, wasm)), wasm);
}

export function classifyExportInvocationMatrix(arg0) {
  return liftValue({ kind: "named", brand: "cmd.ExportInvocationMatrixOutcome", showExport: null }, wasm["cmd__classify_export_invocation_matrix"](lowerValue({ kind: "named", brand: "cmd.ExportInvocationMatrixSummary", showExport: null }, arg0, wasm)), wasm);
}

export function classifyExportInvocationResults(arg0, arg1) {
  return liftValue({ kind: "named", brand: "cmd.ExportInvocationClassification", showExport: null }, wasm["cmd__classify_export_invocation_results"](lowerValue({ kind: "named", brand: "cmd.ExportInvocationResult", showExport: null }, arg0, wasm), lowerValue({ kind: "named", brand: "cmd.ExportInvocationResult", showExport: null }, arg1, wasm)), wasm);
}

export function classifyNWayTextAggregate(arg0) {
  return liftValue({ kind: "named", brand: "cmd.TextAggregateClassification", showExport: null }, wasm["cmd__classify_n_way_text_aggregate"](lowerValue({ kind: "array", helper: {"new":"__js_array_11_new","push":"__js_array_11_push","length":"__js_array_11_length","get":"__js_array_11_get"}, item: { kind: "named", brand: "cmd.TextAggregateAdapterResult", showExport: null } }, arg0, wasm)), wasm);
}

export function cmdFuzzHarnessProfileConfig(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_12_is_ok","unwrapOk":"__js_result_12_unwrap_ok","unwrapErr":"__js_result_12_unwrap_err"}, ok: { kind: "named", brand: "cmd.CmdFuzzHarnessProfileConfig", showExport: null }, err: { kind: "string", moonType: "String" } }, wasm["cmd__cmd_fuzz_harness_profile_config"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
}

export function cmdFuzzHarnessProfileConfigWithSeed(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_12_is_ok","unwrapOk":"__js_result_12_unwrap_ok","unwrapErr":"__js_result_12_unwrap_err"}, ok: { kind: "named", brand: "cmd.CmdFuzzHarnessProfileConfig", showExport: null }, err: { kind: "string", moonType: "String" } }, wasm["cmd__cmd_fuzz_harness_profile_config_with_seed"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function cmdFuzzRandomPassSequence(arg0, arg1) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } }, wasm["cmd__cmd_fuzz_random_pass_sequence"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function cmdHelpText() {
  return liftValue({ kind: "string", moonType: "String" }, wasm["cmd__cmd_help_text"](), wasm);
}

export function cmdVersionText() {
  return liftValue({ kind: "string", moonType: "String" }, wasm["cmd__cmd_version_text"](), wasm);
}

export function compareExportInvocationResults(arg0, arg1, arg2, arg3) {
  return liftValue({ kind: "named", brand: "cmd.ExportInvocationComparisonReport", showExport: null }, wasm["cmd__compare_export_invocation_results"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } }, arg1, wasm), lowerValue({ kind: "named", brand: "cmd.ExportInvocationResult", showExport: null }, arg2, wasm), lowerValue({ kind: "named", brand: "cmd.ExportInvocationResult", showExport: null }, arg3, wasm)), wasm);
}

export function differentialValidateWasm(arg0, adapters) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_13_is_ok","unwrapOk":"__js_result_13_unwrap_ok","unwrapErr":"__js_result_13_unwrap_err"}, ok: { kind: "named", brand: "cmd.DifferentialValidationReport", showExport: "__js_show_cmd_DifferentialValidationReport" }, err: { kind: "string", moonType: "String" } }, wasm["cmd__differential_validate_wasm"](lowerValue({ kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_67_new","push":"__js_array_67_push","length":"__js_array_67_length","get":"__js_array_67_get"}} }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_20_none","some":"__js_option_20_some","isSome":"__js_option_20_is_some","unwrap":"__js_option_20_unwrap"}, item: { kind: "named", brand: "cmd.DifferentialAdapters", showExport: null } }, adapters, wasm)), wasm);
}

export function exportInvocationMatrixShouldFail(arg0, arg1) {
  return liftValue({ kind: "bool", moonType: "Bool" }, wasm["cmd__export_invocation_matrix_should_fail"](lowerValue({ kind: "named", brand: "cmd.ExportInvocationMatrixSummary", showExport: null }, arg0, wasm), lowerValue({ kind: "named", brand: "cmd.ExportInvocationFailurePolicy", showExport: null }, arg1, wasm)), wasm);
}

export function exportInvocationSemanticMismatchReports(arg0) {
  return liftValue({ kind: "array", helper: {"new":"__js_array_12_new","push":"__js_array_12_push","length":"__js_array_12_length","get":"__js_array_12_get"}, item: { kind: "named", brand: "cmd.ExportInvocationComparisonReport", showExport: null } }, wasm["cmd__export_invocation_semantic_mismatch_reports"](lowerValue({ kind: "array", helper: {"new":"__js_array_12_new","push":"__js_array_12_push","length":"__js_array_12_length","get":"__js_array_12_get"}, item: { kind: "named", brand: "cmd.ExportInvocationComparisonReport", showExport: null } }, arg0, wasm)), wasm);
}

export function exportInvocationSummaryHasSemanticMismatch(arg0) {
  return liftValue({ kind: "bool", moonType: "Bool" }, wasm["cmd__export_invocation_summary_has_semantic_mismatch"](lowerValue({ kind: "named", brand: "cmd.ExportInvocationMatrixSummary", showExport: null }, arg0, wasm)), wasm);
}

export function formatBinaryDifferentialSmokeReportJson(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["cmd__format_binary_differential_smoke_report_json"](lowerValue({ kind: "named", brand: "cmd.BinaryDifferentialSmokeReport", showExport: null }, arg0, wasm)), wasm);
}

export const minimizeFuzzPasses = unsupportedExport("cmd.minimizeFuzzPasses", "Higher-order MoonBit callbacks require an explicit JavaScript adapter.");

export function nativeDifferentialToolsAvailable() {
  return liftValue({ kind: "tuple", helper: {"make":"__js_tuple_4_new","getters":["__js_tuple_4_get_0","__js_tuple_4_get_1"]}, items: [{ kind: "bool", moonType: "Bool" }, { kind: "bool", moonType: "Bool" }] }, wasm["cmd__native_differential_tools_available"](), wasm);
}

export function persistFuzzFailureReport(arg0, arg1, corpusDir) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_14_is_ok","unwrapOk":"__js_result_14_unwrap_ok","unwrapErr":"__js_result_14_unwrap_err"}, ok: { kind: "tuple", helper: {"make":"__js_tuple_5_new","getters":["__js_tuple_5_get_0","__js_tuple_5_get_1"]}, items: [{ kind: "string", moonType: "String" }, { kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }] }, err: { kind: "string", moonType: "String" } }, wasm["cmd__persist_fuzz_failure_report"](lowerValue({ kind: "named", brand: "cmd.FuzzFailureReport", showExport: "__js_show_cmd_FuzzFailureReport" }, arg0, wasm), lowerValue({ kind: "named", brand: "cmd.FuzzFailurePersistIO", showExport: null }, arg1, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, corpusDir, wasm)), wasm);
}

export function persistTextDifferentialArtifacts(arg0, arg1, arg2, arg3, arg4, reproDir, seed, attempt) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_15_is_ok","unwrapOk":"__js_result_15_unwrap_ok","unwrapErr":"__js_result_15_unwrap_err"}, ok: { kind: "named", brand: "cmd.TextDifferentialArtifactPaths", showExport: null }, err: { kind: "string", moonType: "String" } }, wasm["cmd__persist_text_differential_artifacts"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "named", brand: "cmd.TextParsePrintLowerReport", showExport: null }, arg1, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_11_new","push":"__js_array_11_push","length":"__js_array_11_length","get":"__js_array_11_get"}, item: { kind: "named", brand: "cmd.TextAggregateAdapterResult", showExport: null } }, arg2, wasm), lowerValue({ kind: "named", brand: "cmd.TextAggregateClassification", showExport: null }, arg3, wasm), lowerValue({ kind: "named", brand: "cmd.FuzzFailurePersistIO", showExport: null }, arg4, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, reproDir, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_17_none","some":"__js_option_17_some","isSome":"__js_option_17_is_some","unwrap":"__js_option_17_unwrap"}, item: { kind: "bigint", moonType: "UInt64" } }, seed, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, attempt, wasm)), wasm);
}

export const reduceFuzzBytesBySliceDeletion = unsupportedExport("cmd.reduceFuzzBytesBySliceDeletion", "Higher-order MoonBit callbacks require an explicit JavaScript adapter.");

export const reduceFuzzModuleFieldsByDeletion = unsupportedExport("cmd.reduceFuzzModuleFieldsByDeletion", "Higher-order MoonBit callbacks require an explicit JavaScript adapter.");

export const reduceFuzzSequenceByDeletion = unsupportedExport("cmd.reduceFuzzSequenceByDeletion", "The FFI excludes this generic or inaccessible signature.");

export const reduceFuzzTextTokensByDeletion = unsupportedExport("cmd.reduceFuzzTextTokensByDeletion", "Higher-order MoonBit callbacks require an explicit JavaScript adapter.");

export function runBinaryDifferentialSmoke(arg0, externalAdapters) {
  return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialSmokeReport", showExport: null }, wasm["cmd__run_binary_differential_smoke"](lowerValue({ kind: "array", helper: {"new":"__js_array_5_new","push":"__js_array_5_push","length":"__js_array_5_length","get":"__js_array_5_get"}, item: { kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_67_new","push":"__js_array_67_push","length":"__js_array_67_length","get":"__js_array_67_get"}} } }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_21_none","some":"__js_option_21_some","isSome":"__js_option_21_is_some","unwrap":"__js_option_21_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_13_new","push":"__js_array_13_push","length":"__js_array_13_length","get":"__js_array_13_get"}, item: { kind: "named", brand: "cmd.BinaryDifferentialSmokeAdapter", showExport: null } } }, externalAdapters, wasm)), wasm);
}

export function runBinaryenBinaryValidationAdapter(arg0) {
  return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialAdapterResult", showExport: null }, wasm["cmd__run_binaryen_binary_validation_adapter"](lowerValue({ kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_67_new","push":"__js_array_67_push","length":"__js_array_67_length","get":"__js_array_67_get"}} }, arg0, wasm)), wasm);
}

export function runCmd(arg0) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_16_is_ok","unwrapOk":"__js_result_16_unwrap_ok","unwrapErr":"__js_result_16_unwrap_err"}, ok: { kind: "named", brand: "cmd.CmdRunSummary", showExport: "__js_show_cmd_CmdRunSummary" }, err: { kind: "named", brand: "cmd.CmdError", showExport: "__js_show_cmd_CmdError" } }, wasm["cmd__run_cmd"](lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } }, arg0, wasm)), wasm);
}

export function runCmdExitCode(arg0) {
  return liftValue({ kind: "number", moonType: "Int" }, wasm["cmd__run_cmd_exit_code"](lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } }, arg0, wasm)), wasm);
}

export function runCmdExitCodeWithAdapter(arg0, arg1, configJson) {
  return liftValue({ kind: "number", moonType: "Int" }, wasm["cmd__run_cmd_exit_code_with_adapter"](lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } }, arg0, wasm), lowerValue({ kind: "named", brand: "cmd.CmdIO", showExport: null }, arg1, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_5_none","some":"__js_option_5_some","isSome":"__js_option_5_is_some","unwrap":"__js_option_5_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } } }, configJson, wasm)), wasm);
}

export const runCmdFuzzHarness = unsupportedExport("cmd.runCmdFuzzHarness", "Higher-order MoonBit callbacks require an explicit JavaScript adapter.");

export function runCmdFuzzHarnessProfile(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_17_is_ok","unwrapOk":"__js_result_17_unwrap_ok","unwrapErr":"__js_result_17_unwrap_err"}, ok: { kind: "named", brand: "cmd.CmdFuzzStats", showExport: "__js_show_cmd_CmdFuzzStats" }, err: { kind: "string", moonType: "String" } }, wasm["cmd__run_cmd_fuzz_harness_profile"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "bigint", moonType: "UInt64" }, arg1, wasm)), wasm);
}

export function runCmdWithAdapter(arg0, arg1, configJson) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_16_is_ok","unwrapOk":"__js_result_16_unwrap_ok","unwrapErr":"__js_result_16_unwrap_err"}, ok: { kind: "named", brand: "cmd.CmdRunSummary", showExport: "__js_show_cmd_CmdRunSummary" }, err: { kind: "named", brand: "cmd.CmdError", showExport: "__js_show_cmd_CmdError" } }, wasm["cmd__run_cmd_with_adapter"](lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } }, arg0, wasm), lowerValue({ kind: "named", brand: "cmd.CmdIO", showExport: null }, arg1, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_5_none","some":"__js_option_5_some","isSome":"__js_option_5_is_some","unwrap":"__js_option_5_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } } }, configJson, wasm)), wasm);
}

export function runLocalTextParsePrintLowerMatrix(arg0, filename) {
  return liftValue({ kind: "named", brand: "cmd.TextParsePrintLowerReport", showExport: null }, wasm["cmd__run_local_text_parse_print_lower_matrix"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, filename, wasm)), wasm);
}

export function runWabtBinaryValidationAdapter(arg0) {
  return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialAdapterResult", showExport: null }, wasm["cmd__run_wabt_binary_validation_adapter"](lowerValue({ kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_67_new","push":"__js_array_67_push","length":"__js_array_67_length","get":"__js_array_67_get"}} }, arg0, wasm)), wasm);
}

export function runWasmToolsBinaryValidationAdapter(arg0) {
  return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialAdapterResult", showExport: null }, wasm["cmd__run_wasm_tools_binary_validation_adapter"](lowerValue({ kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_67_new","push":"__js_array_67_push","length":"__js_array_67_length","get":"__js_array_67_get"}} }, arg0, wasm)), wasm);
}

export function summarizeBinaryCanonicalityClassifications(arg0) {
  return liftValue({ kind: "named", brand: "cmd.BinaryCanonicalitySummary", showExport: null }, wasm["cmd__summarize_binary_canonicality_classifications"](lowerValue({ kind: "array", helper: {"new":"__js_array_14_new","push":"__js_array_14_push","length":"__js_array_14_length","get":"__js_array_14_get"}, item: { kind: "named", brand: "cmd.BinaryCanonicalityClassification", showExport: null } }, arg0, wasm)), wasm);
}

export function summarizeExportInvocationMatrix(arg0) {
  return liftValue({ kind: "named", brand: "cmd.ExportInvocationMatrixSummary", showExport: null }, wasm["cmd__summarize_export_invocation_matrix"](lowerValue({ kind: "array", helper: {"new":"__js_array_12_new","push":"__js_array_12_push","length":"__js_array_12_length","get":"__js_array_12_get"}, item: { kind: "named", brand: "cmd.ExportInvocationComparisonReport", showExport: null } }, arg0, wasm)), wasm);
}

export function textAggregateClassificationLabel(arg0) {
  return liftValue({ kind: "string", moonType: "String" }, wasm["cmd__text_aggregate_classification_label"](lowerValue({ kind: "named", brand: "cmd.TextAggregateClassification", showExport: null }, arg0, wasm)), wasm);
}

export function textAggregateLocalResult(arg0, validatesOk) {
  return liftValue({ kind: "named", brand: "cmd.TextAggregateAdapterResult", showExport: null }, wasm["cmd__text_aggregate_local_result"](lowerValue({ kind: "named", brand: "cmd.TextParsePrintLowerReport", showExport: null }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_15_none","some":"__js_option_15_some","isSome":"__js_option_15_is_some","unwrap":"__js_option_15_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } } }, validatesOk, wasm)), wasm);
}

export function verifyReadmeApiSignatures(arg0, arg1) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_18_is_ok","unwrapOk":"__js_result_18_unwrap_ok","unwrapErr":"__js_result_18_unwrap_err"}, ok: { kind: "unit", moonType: "Unit" }, err: { kind: "string", moonType: "String" } }, wasm["cmd__verify_readme_api_signatures"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_15_new","push":"__js_array_15_push","length":"__js_array_15_length","get":"__js_array_15_get"}, item: { kind: "tuple", helper: {"make":"__js_tuple_6_new","getters":["__js_tuple_6_get_0","__js_tuple_6_get_1"]}, items: [{ kind: "string", moonType: "String" }, { kind: "string", moonType: "String" }] } }, arg1, wasm)), wasm);
}

export function verifyReadmeApiSignaturesWithRequiredBlocks(arg0, arg1, arg2) {
  return liftValue({ kind: "result", helper: {"isOk":"__js_result_18_is_ok","unwrapOk":"__js_result_18_unwrap_ok","unwrapErr":"__js_result_18_unwrap_err"}, ok: { kind: "unit", moonType: "Unit" }, err: { kind: "string", moonType: "String" } }, wasm["cmd__verify_readme_api_signatures_with_required_blocks"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_15_new","push":"__js_array_15_push","length":"__js_array_15_length","get":"__js_array_15_get"}, item: { kind: "tuple", helper: {"make":"__js_tuple_6_new","getters":["__js_tuple_6_get_0","__js_tuple_6_get_1"]}, items: [{ kind: "string", moonType: "String" }, { kind: "string", moonType: "String" }] } }, arg1, wasm), lowerValue({ kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } }, arg2, wasm)), wasm);
}

export const BinaryCanonicalityClassification = Object.freeze({
  acceptedNoncanonical() {
    return liftValue({ kind: "named", brand: "cmd.BinaryCanonicalityClassification", showExport: null }, wasm["cmd__BinaryCanonicalityClassification__accepted_noncanonical"](), wasm);
  },
  canonicalAccepted() {
    return liftValue({ kind: "named", brand: "cmd.BinaryCanonicalityClassification", showExport: null }, wasm["cmd__BinaryCanonicalityClassification__canonical_accepted"](), wasm);
  },
  decoderBugDisagreement() {
    return liftValue({ kind: "named", brand: "cmd.BinaryCanonicalityClassification", showExport: null }, wasm["cmd__BinaryCanonicalityClassification__decoder_bug_disagreement"](), wasm);
  },
  externalPolicyDisagreement() {
    return liftValue({ kind: "named", brand: "cmd.BinaryCanonicalityClassification", showExport: null }, wasm["cmd__BinaryCanonicalityClassification__external_policy_disagreement"](), wasm);
  },
  malformedRejected() {
    return liftValue({ kind: "named", brand: "cmd.BinaryCanonicalityClassification", showExport: null }, wasm["cmd__BinaryCanonicalityClassification__malformed_rejected"](), wasm);
  },
});

export const BinaryCanonicalityInputClass = Object.freeze({
  acceptedNoncanonical() {
    return liftValue({ kind: "named", brand: "cmd.BinaryCanonicalityInputClass", showExport: null }, wasm["cmd__BinaryCanonicalityInputClass__accepted_noncanonical"](), wasm);
  },
  canonical() {
    return liftValue({ kind: "named", brand: "cmd.BinaryCanonicalityInputClass", showExport: null }, wasm["cmd__BinaryCanonicalityInputClass__canonical"](), wasm);
  },
  malformed() {
    return liftValue({ kind: "named", brand: "cmd.BinaryCanonicalityInputClass", showExport: null }, wasm["cmd__BinaryCanonicalityInputClass__malformed"](), wasm);
  },
});

export const BinaryCanonicalitySummary = Object.freeze({
});

export const BinaryDifferentialAdapterResult = Object.freeze({
  adapterUnavailable(arg0, arg1) {
    return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialAdapterResult", showExport: null }, wasm["cmd__BinaryDifferentialAdapterResult__adapter_unavailable"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "string", moonType: "String" }, arg1, wasm)), wasm);
  },
  invalidDecode(arg0, arg1) {
    return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialAdapterResult", showExport: null }, wasm["cmd__BinaryDifferentialAdapterResult__invalid_decode"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "string", moonType: "String" }, arg1, wasm)), wasm);
  },
  invalidValidate(arg0, arg1) {
    return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialAdapterResult", showExport: null }, wasm["cmd__BinaryDifferentialAdapterResult__invalid_validate"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "string", moonType: "String" }, arg1, wasm)), wasm);
  },
  toolFailure(arg0, arg1) {
    return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialAdapterResult", showExport: null }, wasm["cmd__BinaryDifferentialAdapterResult__tool_failure"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "string", moonType: "String" }, arg1, wasm)), wasm);
  },
  unsupportedFeature(arg0, arg1) {
    return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialAdapterResult", showExport: null }, wasm["cmd__BinaryDifferentialAdapterResult__unsupported_feature"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "string", moonType: "String" }, arg1, wasm)), wasm);
  },
  valid(arg0) {
    return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialAdapterResult", showExport: null }, wasm["cmd__BinaryDifferentialAdapterResult__valid"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
});

export const BinaryDifferentialClassification = Object.freeze({
  adapterUnavailable() {
    return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialClassification", showExport: null }, wasm["cmd__BinaryDifferentialClassification__adapter_unavailable"](), wasm);
  },
  agreeInvalid() {
    return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialClassification", showExport: null }, wasm["cmd__BinaryDifferentialClassification__agree_invalid"](), wasm);
  },
  agreeValid() {
    return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialClassification", showExport: null }, wasm["cmd__BinaryDifferentialClassification__agree_valid"](), wasm);
  },
  decoderStageDisagreement() {
    return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialClassification", showExport: null }, wasm["cmd__BinaryDifferentialClassification__decoder_stage_disagreement"](), wasm);
  },
  proposalGap() {
    return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialClassification", showExport: null }, wasm["cmd__BinaryDifferentialClassification__proposal_gap"](), wasm);
  },
  toolFailure() {
    return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialClassification", showExport: null }, wasm["cmd__BinaryDifferentialClassification__tool_failure"](), wasm);
  },
  unsupportedFeature() {
    return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialClassification", showExport: null }, wasm["cmd__BinaryDifferentialClassification__unsupported_feature"](), wasm);
  },
  validatorStageDisagreement() {
    return liftValue({ kind: "named", brand: "cmd.BinaryDifferentialClassification", showExport: null }, wasm["cmd__BinaryDifferentialClassification__validator_stage_disagreement"](), wasm);
  },
});

export const BinaryDifferentialSmokeAdapter = Object.freeze({
  new: unsupportedExport("cmd.BinaryDifferentialSmokeAdapter.new", "Higher-order MoonBit callbacks require an explicit JavaScript adapter."),
});

export const BinaryDifferentialSmokeReport = Object.freeze({
});

export const BinaryValidationOutcome = Object.freeze({
});

export const CmdEncodeError = Object.freeze({
  adapter(arg0) {
    return liftValue({ kind: "named", brand: "cmd.CmdEncodeError", showExport: "__js_show_cmd_CmdEncodeError" }, wasm["cmd__CmdEncodeError__adapter"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
  encode(arg0) {
    return liftValue({ kind: "named", brand: "cmd.CmdEncodeError", showExport: "__js_show_cmd_CmdEncodeError" }, wasm["cmd__CmdEncodeError__encode"](lowerValue({ kind: "named", brand: "binary.EncodeError", showExport: "__js_show_binary_EncodeError" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_cmd_CmdEncodeError"](lowerValue({ kind: "named", brand: "cmd.CmdEncodeError" }, value, wasm));
  },
});

export const CmdError = Object.freeze({
  ambiguousOutputFile(arg0) {
    return liftValue({ kind: "named", brand: "cmd.CmdError", showExport: "__js_show_cmd_CmdError" }, wasm["cmd__CmdError__ambiguous_output_file"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
  unknownPassFlag(arg0) {
    return liftValue({ kind: "named", brand: "cmd.CmdError", showExport: "__js_show_cmd_CmdError" }, wasm["cmd__CmdError__unknown_pass_flag"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_cmd_CmdError"](lowerValue({ kind: "named", brand: "cmd.CmdError" }, value, wasm));
  },
});

export const CmdFuzzHarnessProfileConfig = Object.freeze({
});

export const CmdFuzzStats = Object.freeze({
  new(attempts, generatedValid, generatedInvalid, pipelineValidated, optimized, roundtripped, differentialChecked, optimizeIdempotenceChecked, encodeDecodeIdempotenceChecked, optimizerDeterminismChecked, generatorProfile, passProfile) {
    return liftValue({ kind: "named", brand: "cmd.CmdFuzzStats", showExport: "__js_show_cmd_CmdFuzzStats" }, wasm["cmd__CmdFuzzStats__new"](lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, attempts, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, generatedValid, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, generatedInvalid, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, pipelineValidated, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, optimized, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, roundtripped, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, differentialChecked, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, optimizeIdempotenceChecked, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, encodeDecodeIdempotenceChecked, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, optimizerDeterminismChecked, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, generatorProfile, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, passProfile, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_cmd_CmdFuzzStats"](lowerValue({ kind: "named", brand: "cmd.CmdFuzzStats" }, value, wasm));
  },
});

export const CmdIO = Object.freeze({
  new: unsupportedExport("cmd.CmdIO.new", "Higher-order MoonBit callbacks require an explicit JavaScript adapter."),
});

export const CmdOptimizerReportMode = Object.freeze({
});

export const CmdPipelineDumpFormat = Object.freeze({
});

export const CmdPipelinePrintSelector = Object.freeze({
});

export const CmdPipelineStep = Object.freeze({
});

export const CmdRunSummary = Object.freeze({
  new(inputFiles, outputFiles, resolvedPasses, optimizeLevel, shrinkLevel, trapsNeverHappen, ignoreImplicitTraps, monomorphizeMinBenefit, closedWorld, lowMemoryUnused, lowMemoryBound) {
    return liftValue({ kind: "named", brand: "cmd.CmdRunSummary", showExport: "__js_show_cmd_CmdRunSummary" }, wasm["cmd__CmdRunSummary__new"](lowerValue({ kind: "optional", helper: {"none":"__js_option_7_none","some":"__js_option_7_some","isSome":"__js_option_7_is_some","unwrap":"__js_option_7_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } } }, inputFiles, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_7_none","some":"__js_option_7_some","isSome":"__js_option_7_is_some","unwrap":"__js_option_7_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } } }, outputFiles, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_7_none","some":"__js_option_7_some","isSome":"__js_option_7_is_some","unwrap":"__js_option_7_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } } }, resolvedPasses, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, optimizeLevel, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, shrinkLevel, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, trapsNeverHappen, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, ignoreImplicitTraps, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, monomorphizeMinBenefit, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, closedWorld, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, lowMemoryUnused, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_17_none","some":"__js_option_17_some","isSome":"__js_option_17_is_some","unwrap":"__js_option_17_unwrap"}, item: { kind: "bigint", moonType: "UInt64" } }, lowMemoryBound, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_cmd_CmdRunSummary"](lowerValue({ kind: "named", brand: "cmd.CmdRunSummary" }, value, wasm));
  },
});

export const DifferentialAdapters = Object.freeze({
  new: unsupportedExport("cmd.DifferentialAdapters.new", "Higher-order MoonBit callbacks require an explicit JavaScript adapter."),
});

export const DifferentialValidationReport = Object.freeze({
  show(value) {
    return wasm["__js_show_cmd_DifferentialValidationReport"](lowerValue({ kind: "named", brand: "cmd.DifferentialValidationReport" }, value, wasm));
  },
});

export const ExportInvocationClassification = Object.freeze({
  equalResult() {
    return liftValue({ kind: "named", brand: "cmd.ExportInvocationClassification", showExport: null }, wasm["cmd__ExportInvocationClassification__equal_result"](), wasm);
  },
  equalTrap() {
    return liftValue({ kind: "named", brand: "cmd.ExportInvocationClassification", showExport: null }, wasm["cmd__ExportInvocationClassification__equal_trap"](), wasm);
  },
  nondeterministicImport() {
    return liftValue({ kind: "named", brand: "cmd.ExportInvocationClassification", showExport: null }, wasm["cmd__ExportInvocationClassification__nondeterministic_import"](), wasm);
  },
  semanticMismatch(arg0) {
    return liftValue({ kind: "named", brand: "cmd.ExportInvocationClassification", showExport: null }, wasm["cmd__ExportInvocationClassification__semantic_mismatch"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
  unsupportedRuntime() {
    return liftValue({ kind: "named", brand: "cmd.ExportInvocationClassification", showExport: null }, wasm["cmd__ExportInvocationClassification__unsupported_runtime"](), wasm);
  },
});

export const ExportInvocationComparisonReport = Object.freeze({
});

export const ExportInvocationFailurePolicy = Object.freeze({
  failOnSemanticMismatch() {
    return liftValue({ kind: "named", brand: "cmd.ExportInvocationFailurePolicy", showExport: null }, wasm["cmd__ExportInvocationFailurePolicy__fail_on_semantic_mismatch"](), wasm);
  },
  informational() {
    return liftValue({ kind: "named", brand: "cmd.ExportInvocationFailurePolicy", showExport: null }, wasm["cmd__ExportInvocationFailurePolicy__informational"](), wasm);
  },
});

export const ExportInvocationMatrixOutcome = Object.freeze({
  allEqual() {
    return liftValue({ kind: "named", brand: "cmd.ExportInvocationMatrixOutcome", showExport: null }, wasm["cmd__ExportInvocationMatrixOutcome__all_equal"](), wasm);
  },
  blocked() {
    return liftValue({ kind: "named", brand: "cmd.ExportInvocationMatrixOutcome", showExport: null }, wasm["cmd__ExportInvocationMatrixOutcome__blocked"](), wasm);
  },
  empty() {
    return liftValue({ kind: "named", brand: "cmd.ExportInvocationMatrixOutcome", showExport: null }, wasm["cmd__ExportInvocationMatrixOutcome__empty"](), wasm);
  },
  semanticMismatch() {
    return liftValue({ kind: "named", brand: "cmd.ExportInvocationMatrixOutcome", showExport: null }, wasm["cmd__ExportInvocationMatrixOutcome__semantic_mismatch"](), wasm);
  },
});

export const ExportInvocationMatrixSummary = Object.freeze({
});

export const ExportInvocationResult = Object.freeze({
  nondeterministicImport(arg0) {
    return liftValue({ kind: "named", brand: "cmd.ExportInvocationResult", showExport: null }, wasm["cmd__ExportInvocationResult__nondeterministic_import"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
  trap(arg0) {
    return liftValue({ kind: "named", brand: "cmd.ExportInvocationResult", showExport: null }, wasm["cmd__ExportInvocationResult__trap"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
  unsupportedRuntime(arg0) {
    return liftValue({ kind: "named", brand: "cmd.ExportInvocationResult", showExport: null }, wasm["cmd__ExportInvocationResult__unsupported_runtime"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
  value(arg0) {
    return liftValue({ kind: "named", brand: "cmd.ExportInvocationResult", showExport: null }, wasm["cmd__ExportInvocationResult__value"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm)), wasm);
  },
});

export const FuzzCorpusDedupDecision = Object.freeze({
});

export const FuzzCorpusDedupHashEntry = Object.freeze({
});

export const FuzzCorpusDedupIndex = Object.freeze({
  new() {
    return liftValue({ kind: "named", brand: "cmd.FuzzCorpusDedupIndex", showExport: null }, wasm["cmd__FuzzCorpusDedupIndex__new"](), wasm);
  },
  record(arg0, arg1, arg2) {
    return liftValue({ kind: "named", brand: "cmd.FuzzCorpusDedupDecision", showExport: null }, wasm["cmd__FuzzCorpusDedupIndex__record"](lowerValue({ kind: "named", brand: "cmd.FuzzCorpusDedupIndex", showExport: null }, arg0, wasm), lowerValue({ kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_67_new","push":"__js_array_67_push","length":"__js_array_67_length","get":"__js_array_67_get"}} }, arg1, wasm), lowerValue({ kind: "named", brand: "cmd.FuzzCorpusSource", showExport: null }, arg2, wasm)), wasm);
  },
  toText(arg0) {
    return liftValue({ kind: "string", moonType: "String" }, wasm["cmd__FuzzCorpusDedupIndex__to_text"](lowerValue({ kind: "named", brand: "cmd.FuzzCorpusDedupIndex", showExport: null }, arg0, wasm)), wasm);
  },
});

export const FuzzCorpusDedupSourceEntry = Object.freeze({
});

export const FuzzCorpusSource = Object.freeze({
  new(arg0, arg1, arg2, arg3, arg4) {
    return liftValue({ kind: "named", brand: "cmd.FuzzCorpusSource", showExport: null }, wasm["cmd__FuzzCorpusSource__new"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm), lowerValue({ kind: "number", moonType: "Int" }, arg1, wasm), lowerValue({ kind: "string", moonType: "String" }, arg2, wasm), lowerValue({ kind: "string", moonType: "String" }, arg3, wasm), lowerValue({ kind: "string", moonType: "String" }, arg4, wasm)), wasm);
  },
});

export const FuzzFailurePersistIO = Object.freeze({
  new: unsupportedExport("cmd.FuzzFailurePersistIO.new", "Higher-order MoonBit callbacks require an explicit JavaScript adapter."),
});

export const FuzzFailureReport = Object.freeze({
  new(arg0, arg1, arg2, arg3, arg4, optimizePasses, minimizedPasses, generatorProfile, passProfile, generatorConfigLabel, generatedAttempts, featureFacts, wasm, reducedWasm, reductionOriginalSize, reductionFinalSize, reductionPredicateEvaluations, reductionSteps) {
    return liftValue({ kind: "named", brand: "cmd.FuzzFailureReport", showExport: "__js_show_cmd_FuzzFailureReport" }, wasm["cmd__FuzzFailureReport__new"](lowerValue({ kind: "bigint", moonType: "UInt64" }, arg0, wasm), lowerValue({ kind: "number", moonType: "Int" }, arg1, wasm), lowerValue({ kind: "number", moonType: "Int" }, arg2, wasm), lowerValue({ kind: "string", moonType: "String" }, arg3, wasm), lowerValue({ kind: "string", moonType: "String" }, arg4, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_7_none","some":"__js_option_7_some","isSome":"__js_option_7_is_some","unwrap":"__js_option_7_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } } }, optimizePasses, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_7_none","some":"__js_option_7_some","isSome":"__js_option_7_is_some","unwrap":"__js_option_7_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_6_new","push":"__js_array_6_push","length":"__js_array_6_length","get":"__js_array_6_get"}, item: { kind: "string", moonType: "String" } } }, minimizedPasses, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, generatorProfile, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, passProfile, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, generatorConfigLabel, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, generatedAttempts, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_6_none","some":"__js_option_6_some","isSome":"__js_option_6_is_some","unwrap":"__js_option_6_unwrap"}, item: { kind: "string", moonType: "String" } }, featureFacts, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_22_none","some":"__js_option_22_some","isSome":"__js_option_22_is_some","unwrap":"__js_option_22_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_23_none","some":"__js_option_23_some","isSome":"__js_option_23_is_some","unwrap":"__js_option_23_unwrap"}, item: { kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_67_new","push":"__js_array_67_push","length":"__js_array_67_length","get":"__js_array_67_get"}} } } }, wasm, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_22_none","some":"__js_option_22_some","isSome":"__js_option_22_is_some","unwrap":"__js_option_22_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_23_none","some":"__js_option_23_some","isSome":"__js_option_23_is_some","unwrap":"__js_option_23_unwrap"}, item: { kind: "bytes", helper: {"fromArray":"__js_bytes_from_array","length":"__js_bytes_length","get":"__js_bytes_get","byteArray":{"new":"__js_array_67_new","push":"__js_array_67_push","length":"__js_array_67_length","get":"__js_array_67_get"}} } } }, reducedWasm, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_13_none","some":"__js_option_13_some","isSome":"__js_option_13_is_some","unwrap":"__js_option_13_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } } }, reductionOriginalSize, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_13_none","some":"__js_option_13_some","isSome":"__js_option_13_is_some","unwrap":"__js_option_13_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } } }, reductionFinalSize, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_13_none","some":"__js_option_13_some","isSome":"__js_option_13_is_some","unwrap":"__js_option_13_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } } }, reductionPredicateEvaluations, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_24_none","some":"__js_option_24_some","isSome":"__js_option_24_is_some","unwrap":"__js_option_24_unwrap"}, item: { kind: "array", helper: {"new":"__js_array_16_new","push":"__js_array_16_push","length":"__js_array_16_length","get":"__js_array_16_get"}, item: { kind: "named", brand: "cmd.FuzzReductionStep", showExport: null } } }, reductionSteps, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_cmd_FuzzFailureReport"](lowerValue({ kind: "named", brand: "cmd.FuzzFailureReport" }, value, wasm));
  },
});

export const FuzzReductionReport = Object.freeze({
});

export const FuzzReductionStep = Object.freeze({
});

export const InliningOptions = Object.freeze({
  new(alwaysInlineMaxSize, oneCallerInlineMaxSize, flexibleInlineMaxSize, maxCombinedBinarySize, allowFunctionsWithLoops, partialInliningIfs) {
    return liftValue({ kind: "named", brand: "cmd.InliningOptions", showExport: "__js_show_cmd_InliningOptions" }, wasm["cmd__InliningOptions__new"](lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, alwaysInlineMaxSize, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, oneCallerInlineMaxSize, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, flexibleInlineMaxSize, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, maxCombinedBinarySize, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, allowFunctionsWithLoops, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, partialInliningIfs, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_cmd_InliningOptions"](lowerValue({ kind: "named", brand: "cmd.InliningOptions" }, value, wasm));
  },
});

export const OptimizeOptions = Object.freeze({
  new(optimizeLevel, shrinkLevel, inlining, monomorphizeMinBenefit, closedWorld, zeroFilledMemory, fastMath, lowMemoryUnused, lowMemoryBound, trapsNeverHappen, ignoreImplicitTraps, compilerFactPolicy, validationPolicy, stackFunctionPasses) {
    return liftValue({ kind: "named", brand: "cmd.OptimizeOptions", showExport: "__js_show_cmd_OptimizeOptions" }, wasm["cmd__OptimizeOptions__new"](lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, optimizeLevel, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, shrinkLevel, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_25_none","some":"__js_option_25_some","isSome":"__js_option_25_is_some","unwrap":"__js_option_25_unwrap"}, item: { kind: "named", brand: "cmd.InliningOptions", showExport: "__js_show_cmd_InliningOptions" } }, inlining, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_14_none","some":"__js_option_14_some","isSome":"__js_option_14_is_some","unwrap":"__js_option_14_unwrap"}, item: { kind: "number", moonType: "Int" } }, monomorphizeMinBenefit, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, closedWorld, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, zeroFilledMemory, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, fastMath, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, lowMemoryUnused, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_17_none","some":"__js_option_17_some","isSome":"__js_option_17_is_some","unwrap":"__js_option_17_unwrap"}, item: { kind: "bigint", moonType: "UInt64" } }, lowMemoryBound, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, trapsNeverHappen, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, ignoreImplicitTraps, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_26_none","some":"__js_option_26_some","isSome":"__js_option_26_is_some","unwrap":"__js_option_26_unwrap"}, item: { kind: "opaque", brand: "@passes.CompilerFactUsePolicy" } }, compilerFactPolicy, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_27_none","some":"__js_option_27_some","isSome":"__js_option_27_is_some","unwrap":"__js_option_27_unwrap"}, item: { kind: "named", brand: "cmd.OptimizeValidationPolicy", showExport: "__js_show_cmd_OptimizeValidationPolicy" } }, validationPolicy, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } }, stackFunctionPasses, wasm)), wasm);
  },
  show(value) {
    return wasm["__js_show_cmd_OptimizeOptions"](lowerValue({ kind: "named", brand: "cmd.OptimizeOptions" }, value, wasm));
  },
});

export const OptimizeTracingLevel = Object.freeze({
  helper() {
    return liftValue({ kind: "named", brand: "cmd.OptimizeTracingLevel", showExport: "__js_show_cmd_OptimizeTracingLevel" }, wasm["cmd__OptimizeTracingLevel__helper"](), wasm);
  },
  pass() {
    return liftValue({ kind: "named", brand: "cmd.OptimizeTracingLevel", showExport: "__js_show_cmd_OptimizeTracingLevel" }, wasm["cmd__OptimizeTracingLevel__pass"](), wasm);
  },
  phase() {
    return liftValue({ kind: "named", brand: "cmd.OptimizeTracingLevel", showExport: "__js_show_cmd_OptimizeTracingLevel" }, wasm["cmd__OptimizeTracingLevel__phase"](), wasm);
  },
  show(value) {
    return wasm["__js_show_cmd_OptimizeTracingLevel"](lowerValue({ kind: "named", brand: "cmd.OptimizeTracingLevel" }, value, wasm));
  },
});

export const OptimizeValidationPolicy = Object.freeze({
  afterSegment() {
    return liftValue({ kind: "named", brand: "cmd.OptimizeValidationPolicy", showExport: "__js_show_cmd_OptimizeValidationPolicy" }, wasm["cmd__OptimizeValidationPolicy__after_segment"](), wasm);
  },
  finalModuleOnly() {
    return liftValue({ kind: "named", brand: "cmd.OptimizeValidationPolicy", showExport: "__js_show_cmd_OptimizeValidationPolicy" }, wasm["cmd__OptimizeValidationPolicy__final_module_only"](), wasm);
  },
  show(value) {
    return wasm["__js_show_cmd_OptimizeValidationPolicy"](lowerValue({ kind: "named", brand: "cmd.OptimizeValidationPolicy" }, value, wasm));
  },
});

export const ReadmeApiVerifyBlock = Object.freeze({
  show(value) {
    return wasm["__js_show_cmd_ReadmeApiVerifyBlock"](lowerValue({ kind: "named", brand: "cmd.ReadmeApiVerifyBlock" }, value, wasm));
  },
});

export const TextAggregateAdapterResult = Object.freeze({
  externalAccepted(arg0, validatesOk) {
    return liftValue({ kind: "named", brand: "cmd.TextAggregateAdapterResult", showExport: null }, wasm["cmd__TextAggregateAdapterResult__external_accepted"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "optional", helper: {"none":"__js_option_15_none","some":"__js_option_15_some","isSome":"__js_option_15_is_some","unwrap":"__js_option_15_unwrap"}, item: { kind: "option", helper: {"none":"__js_option_3_none","some":"__js_option_3_some","isSome":"__js_option_3_is_some","unwrap":"__js_option_3_unwrap"}, item: { kind: "bool", moonType: "Bool" } } }, validatesOk, wasm)), wasm);
  },
  externalParseError(arg0, arg1) {
    return liftValue({ kind: "named", brand: "cmd.TextAggregateAdapterResult", showExport: null }, wasm["cmd__TextAggregateAdapterResult__external_parse_error"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "string", moonType: "String" }, arg1, wasm)), wasm);
  },
  externalUnavailable(arg0, arg1) {
    return liftValue({ kind: "named", brand: "cmd.TextAggregateAdapterResult", showExport: null }, wasm["cmd__TextAggregateAdapterResult__external_unavailable"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "string", moonType: "String" }, arg1, wasm)), wasm);
  },
  externalUnsupportedSyntax(arg0, arg1) {
    return liftValue({ kind: "named", brand: "cmd.TextAggregateAdapterResult", showExport: null }, wasm["cmd__TextAggregateAdapterResult__external_unsupported_syntax"](lowerValue({ kind: "string", moonType: "String" }, arg0, wasm), lowerValue({ kind: "string", moonType: "String" }, arg1, wasm)), wasm);
  },
});

export const TextAggregateClassification = Object.freeze({
  accepted() {
    return liftValue({ kind: "named", brand: "cmd.TextAggregateClassification", showExport: null }, wasm["cmd__TextAggregateClassification__accepted"](), wasm);
  },
  adapterUnavailable() {
    return liftValue({ kind: "named", brand: "cmd.TextAggregateClassification", showExport: null }, wasm["cmd__TextAggregateClassification__adapter_unavailable"](), wasm);
  },
  lowerDisagreement() {
    return liftValue({ kind: "named", brand: "cmd.TextAggregateClassification", showExport: null }, wasm["cmd__TextAggregateClassification__lower_disagreement"](), wasm);
  },
  parseDisagreement() {
    return liftValue({ kind: "named", brand: "cmd.TextAggregateClassification", showExport: null }, wasm["cmd__TextAggregateClassification__parse_disagreement"](), wasm);
  },
  printDisagreement() {
    return liftValue({ kind: "named", brand: "cmd.TextAggregateClassification", showExport: null }, wasm["cmd__TextAggregateClassification__print_disagreement"](), wasm);
  },
  semanticValidationDisagreement() {
    return liftValue({ kind: "named", brand: "cmd.TextAggregateClassification", showExport: null }, wasm["cmd__TextAggregateClassification__semantic_validation_disagreement"](), wasm);
  },
  unsupportedSyntax() {
    return liftValue({ kind: "named", brand: "cmd.TextAggregateClassification", showExport: null }, wasm["cmd__TextAggregateClassification__unsupported_syntax"](), wasm);
  },
});

export const TextDifferentialArtifactPaths = Object.freeze({
});

export const TextParsePrintLowerReport = Object.freeze({
});
