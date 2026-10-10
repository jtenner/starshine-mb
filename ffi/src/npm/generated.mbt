// Generated from the FFI export schema. DO NOT EDIT.

///|
#doc(hidden)
pub fn ffi_binary_compiler_fact_module_opcode_offsets(
  value0 : @lib.Module,
) -> Result[Array[Array[UInt]], @binary.BinaryEncodeError] {
  @binary.compiler_fact_module_opcode_offsets(value0)
}

///|
#doc(hidden)
pub fn ffi_binary_compiler_fact_module_opcode_sites(
  value0 : @lib.Module,
) -> Result[Array[Array[(UInt, @lib.Instruction)]], @binary.BinaryEncodeError] {
  @binary.compiler_fact_module_opcode_sites(value0)
}

///|
#doc(hidden)
pub fn ffi_binary_compiler_fact_opcode_offsets(
  value0 : @lib.Expr,
  stringrefs : Array[Bytes]??,
) -> Result[Array[UInt], @binary.BinaryEncodeError] {
  @binary.compiler_fact_opcode_offsets(value0, stringrefs?)
}

///|
#doc(hidden)
pub fn ffi_binary_compiler_fact_opcode_sites(
  value0 : @lib.Expr,
  stringrefs : Array[Bytes]??,
) -> Result[Array[(UInt, @lib.Instruction)], @binary.BinaryEncodeError] {
  @binary.compiler_fact_opcode_sites(value0, stringrefs?)
}

///|
#doc(hidden)
pub fn ffi_binary_decode_module(
  value0 : Bytes,
) -> Result[@lib.Module, @binary.DecodeError] {
  @binary.decode_module(value0)
}

///|
#doc(hidden)
pub fn ffi_binary_decode_module_with_detail(
  value0 : Bytes,
  value1 : Int,
) -> Result[(@lib.Module, Int), @binary.ModuleDecodeErrorDetail] {
  @binary.decode_module_with_detail(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_binary_encode_module(
  value0 : @lib.Module,
  compact_imports : Bool?,
) -> Result[Bytes, @binary.EncodeError] {
  @binary.encode_module(value0, compact_imports?)
}

///|
#doc(hidden)
pub fn ffi_binary_encoded_module_sizes(
  value0 : @lib.Module,
  value1 : @lib.Module,
) -> Result[(Int, Int), @binary.EncodeError] {
  @binary.encoded_module_sizes(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_binary_size_signed(
  value0 : Int64,
  value1 : Int,
) -> Result[Int, @binary.BinaryEncodeError] {
  @binary.size_signed(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_binary_size_unsigned(
  value0 : UInt64,
  value1 : Int,
) -> Result[Int, @binary.BinaryEncodeError] {
  @binary.size_unsigned(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_cli_cli_config_schema_json() -> String {
  @cli.cli_config_schema_json()
}

///|
#doc(hidden)
pub fn ffi_cli_expand_globs(
  value0 : Array[String],
  value1 : Array[String],
) -> Array[String] {
  @cli.expand_globs(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_cli_glob_match(value0 : String, value1 : String) -> Bool {
  @cli.glob_match(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_cli_infer_input_format(value0 : String) -> @cli.CliInputFormat? {
  @cli.infer_input_format(value0)
}

///|
#doc(hidden)
pub fn ffi_cli_normalize_cli_path(value0 : String) -> String {
  @cli.normalize_cli_path(value0)
}

///|
#doc(hidden)
pub fn ffi_cli_parse_cli_args(
  value0 : Array[String],
  starshine_input : String??,
) -> Result[@cli.CliParseResult, @cli.CliParseError] {
  @cli.parse_cli_args(value0, starshine_input?)
}

///|
#doc(hidden)
pub fn ffi_cli_parse_starshine_input_env(value0 : String?) -> Array[String] {
  @cli.parse_starshine_input_env(value0)
}

///|
#doc(hidden)
pub fn ffi_cli_resolve_closed_world(
  value0 : @cli.CliParseResult,
  default : Bool?,
) -> Bool {
  @cli.resolve_closed_world(value0, default?)
}

///|
#doc(hidden)
pub fn ffi_cli_resolve_ignore_implicit_traps(
  value0 : @cli.CliParseResult,
) -> Bool {
  @cli.resolve_ignore_implicit_traps(value0)
}

///|
#doc(hidden)
pub fn ffi_cli_resolve_pass_flags(
  value0 : @cli.CliParseResult,
) -> Array[String] {
  @cli.resolve_pass_flags(value0)
}

///|
#doc(hidden)
pub fn ffi_cli_resolve_traps_never_happen(
  value0 : @cli.CliParseResult,
  default : Bool?,
) -> Bool {
  @cli.resolve_traps_never_happen(value0, default?)
}

///|
#doc(hidden)
pub fn ffi_cli_CliInputFormat_wasm() -> @cli.CliInputFormat {
  @cli.CliInputFormat::wasm()
}

///|
#doc(hidden)
pub fn ffi_cli_CliInputFormat_wast() -> @cli.CliInputFormat {
  @cli.CliInputFormat::wast()
}

///|
#doc(hidden)
pub fn ffi_cli_CliInputFormat_wat() -> @cli.CliInputFormat {
  @cli.CliInputFormat::wat()
}

///|
#doc(hidden)
pub fn ffi_cli_CliOptimizationFlag_olevel(
  value0 : Int,
  value1 : Bool,
) -> @cli.CliOptimizationFlag {
  @cli.CliOptimizationFlag::olevel(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_cli_CliOptimizationFlag_optimize() -> @cli.CliOptimizationFlag {
  @cli.CliOptimizationFlag::optimize()
}

///|
#doc(hidden)
pub fn ffi_cli_CliOptimizationFlag_osize() -> @cli.CliOptimizationFlag {
  @cli.CliOptimizationFlag::osize()
}

///|
#doc(hidden)
pub fn ffi_cli_CliOptimizationFlag_shrink() -> @cli.CliOptimizationFlag {
  @cli.CliOptimizationFlag::shrink()
}

///|
#doc(hidden)
pub fn ffi_cli_CliOutputTarget_dir(value0 : String) -> @cli.CliOutputTarget {
  @cli.CliOutputTarget::dir(value0)
}

///|
#doc(hidden)
pub fn ffi_cli_CliOutputTarget_file(value0 : String) -> @cli.CliOutputTarget {
  @cli.CliOutputTarget::file(value0)
}

///|
#doc(hidden)
pub fn ffi_cli_CliOutputTarget_stdout() -> @cli.CliOutputTarget {
  @cli.CliOutputTarget::stdout()
}

///|
#doc(hidden)
pub fn ffi_cli_CliParseError_invalid_dump_path(
  value0 : String,
) -> @cli.CliParseError {
  @cli.CliParseError::invalid_dump_path(value0)
}

///|
#doc(hidden)
pub fn ffi_cli_CliParseError_invalid_function_index_list(
  value0 : String,
) -> @cli.CliParseError {
  @cli.CliParseError::invalid_function_index_list(value0)
}

///|
#doc(hidden)
pub fn ffi_cli_CliParseError_invalid_input_format(
  value0 : String,
) -> @cli.CliParseError {
  @cli.CliParseError::invalid_input_format(value0)
}

///|
#doc(hidden)
pub fn ffi_cli_CliParseError_invalid_long_flag(
  value0 : String,
) -> @cli.CliParseError {
  @cli.CliParseError::invalid_long_flag(value0)
}

///|
#doc(hidden)
pub fn ffi_cli_CliParseError_invalid_optimization_flag(
  value0 : String,
) -> @cli.CliParseError {
  @cli.CliParseError::invalid_optimization_flag(value0)
}

///|
#doc(hidden)
pub fn ffi_cli_CliParseError_invalid_tracing_level(
  value0 : String,
) -> @cli.CliParseError {
  @cli.CliParseError::invalid_tracing_level(value0)
}

///|
#doc(hidden)
pub fn ffi_cli_CliParseError_invalid_trap_mode(
  value0 : String,
) -> @cli.CliParseError {
  @cli.CliParseError::invalid_trap_mode(value0)
}

///|
#doc(hidden)
pub fn ffi_cli_CliParseError_missing_flag_value(
  value0 : String,
) -> @cli.CliParseError {
  @cli.CliParseError::missing_flag_value(value0)
}

///|
#doc(hidden)
pub fn ffi_cli_CliParseError_stdin_needs_format() -> @cli.CliParseError {
  @cli.CliParseError::stdin_needs_format()
}

///|
#doc(hidden)
pub fn ffi_cli_CliParseError_unexpected_flag_value(
  value0 : String,
) -> @cli.CliParseError {
  @cli.CliParseError::unexpected_flag_value(value0)
}

///|
#doc(hidden)
pub fn ffi_cli_CliParseError_unknown_short_flag(
  value0 : Char,
) -> @cli.CliParseError {
  @cli.CliParseError::unknown_short_flag(value0)
}

///|
#doc(hidden)
pub fn ffi_cli_CliParseResult_new(
  config_path : String??,
  input_globs : Array[String]?,
  glob_enabled : Bool?,
  help_requested : Bool?,
  version_requested : Bool?,
  debug_serial_passes : Bool?,
  read_stdin : Bool?,
  input_format : @cli.CliInputFormat??,
  output_targets : Array[@cli.CliOutputTarget]?,
  pass_flags : Array[String]?,
  optimize_flags : Array[@cli.CliOptimizationFlag]?,
  trap_mode : @cli.TrapMode??,
  ignore_implicit_traps : Bool?,
  monomorphize_min_benefit : Int??,
  inlining_always_inline_max_size : Int??,
  inlining_one_caller_inline_max_size : Int??,
  inlining_flexible_inline_max_size : Int??,
  inlining_max_combined_binary_size : Int??,
  inlining_allow_functions_with_loops : Bool??,
  inlining_partial_inlining_ifs : Int??,
  low_memory_unused : Bool??,
  low_memory_bound : UInt64??,
  closed_world : Bool??,
  compiler_facts_policy : String??,
  tracing : @cli.CliTracingLevel??,
) -> @cli.CliParseResult {
  @cli.CliParseResult::new(
    config_path?,
    input_globs?,
    glob_enabled?,
    help_requested?,
    version_requested?,
    debug_serial_passes?,
    read_stdin?,
    input_format?,
    output_targets?,
    pass_flags?,
    optimize_flags?,
    trap_mode?,
    ignore_implicit_traps?,
    monomorphize_min_benefit?,
    inlining_always_inline_max_size?,
    inlining_one_caller_inline_max_size?,
    inlining_flexible_inline_max_size?,
    inlining_max_combined_binary_size?,
    inlining_allow_functions_with_loops?,
    inlining_partial_inlining_ifs?,
    low_memory_unused?,
    low_memory_bound?,
    closed_world?,
    compiler_facts_policy?,
    tracing?,
  )
}

///|
#doc(hidden)
pub fn ffi_cli_CliTracingLevel_helper() -> @cli.CliTracingLevel {
  @cli.CliTracingLevel::helper()
}

///|
#doc(hidden)
pub fn ffi_cli_CliTracingLevel_pass() -> @cli.CliTracingLevel {
  @cli.CliTracingLevel::pass()
}

///|
#doc(hidden)
pub fn ffi_cli_CliTracingLevel_phase() -> @cli.CliTracingLevel {
  @cli.CliTracingLevel::phase()
}

///|
#doc(hidden)
pub fn ffi_cli_TrapMode_allow() -> @cli.TrapMode {
  @cli.TrapMode::allow()
}

///|
#doc(hidden)
pub fn ffi_cli_TrapMode_never() -> @cli.TrapMode {
  @cli.TrapMode::never()
}

///|
#doc(hidden)
pub fn ffi_cmd_binary_differential_classification_label(
  value0 : @cmd.BinaryDifferentialClassification,
) -> String {
  @cmd.binary_differential_classification_label(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_binary_differential_failed_validation_result(
  value0 : String,
  value1 : Bytes,
  value2 : String,
) -> @cmd.BinaryDifferentialAdapterResult {
  @cmd.binary_differential_failed_validation_result(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_cmd_choose_simple_export_invocation_args(
  value0 : Array[@lib.ValType],
) -> Result[Array[String], String] {
  @cmd.choose_simple_export_invocation_args(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_classify_binary_canonicality_differential(
  value0 : @cmd.BinaryCanonicalityInputClass,
  value1 : Bool,
  value2 : Bool?,
  value3 : Bool?,
) -> @cmd.BinaryCanonicalityClassification {
  @cmd.classify_binary_canonicality_differential(value0, value1, value2, value3)
}

///|
#doc(hidden)
pub fn ffi_cmd_classify_binary_differential_results(
  value0 : Array[@cmd.BinaryDifferentialAdapterResult],
) -> @cmd.BinaryDifferentialClassification {
  @cmd.classify_binary_differential_results(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_classify_export_invocation_matrix(
  value0 : @cmd.ExportInvocationMatrixSummary,
) -> @cmd.ExportInvocationMatrixOutcome {
  @cmd.classify_export_invocation_matrix(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_classify_export_invocation_results(
  value0 : @cmd.ExportInvocationResult,
  value1 : @cmd.ExportInvocationResult,
) -> @cmd.ExportInvocationClassification {
  @cmd.classify_export_invocation_results(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_cmd_classify_n_way_text_aggregate(
  value0 : Array[@cmd.TextAggregateAdapterResult],
) -> @cmd.TextAggregateClassification {
  @cmd.classify_n_way_text_aggregate(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_cmd_fuzz_harness_profile_config(
  value0 : String,
) -> Result[@cmd.CmdFuzzHarnessProfileConfig, String] {
  @cmd.cmd_fuzz_harness_profile_config(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_cmd_fuzz_harness_profile_config_with_seed(
  value0 : String,
  value1 : UInt64,
) -> Result[@cmd.CmdFuzzHarnessProfileConfig, String] {
  @cmd.cmd_fuzz_harness_profile_config_with_seed(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_cmd_cmd_fuzz_random_pass_sequence(
  value0 : String,
  value1 : UInt64,
) -> Array[String] {
  @cmd.cmd_fuzz_random_pass_sequence(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_cmd_cmd_help_text() -> String {
  @cmd.cmd_help_text()
}

///|
#doc(hidden)
pub fn ffi_cmd_cmd_version_text() -> String {
  @cmd.cmd_version_text()
}

///|
#doc(hidden)
pub fn ffi_cmd_compare_export_invocation_results(
  value0 : String,
  value1 : Array[String],
  value2 : @cmd.ExportInvocationResult,
  value3 : @cmd.ExportInvocationResult,
) -> @cmd.ExportInvocationComparisonReport {
  @cmd.compare_export_invocation_results(value0, value1, value2, value3)
}

///|
#doc(hidden)
pub fn ffi_cmd_differential_validate_wasm(
  value0 : Bytes,
  adapters : @cmd.DifferentialAdapters?,
) -> Result[@cmd.DifferentialValidationReport, String] {
  @cmd.differential_validate_wasm(value0, adapters?)
}

///|
#doc(hidden)
pub fn ffi_cmd_export_invocation_matrix_should_fail(
  value0 : @cmd.ExportInvocationMatrixSummary,
  value1 : @cmd.ExportInvocationFailurePolicy,
) -> Bool {
  @cmd.export_invocation_matrix_should_fail(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_cmd_export_invocation_semantic_mismatch_reports(
  value0 : Array[@cmd.ExportInvocationComparisonReport],
) -> Array[@cmd.ExportInvocationComparisonReport] {
  @cmd.export_invocation_semantic_mismatch_reports(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_export_invocation_summary_has_semantic_mismatch(
  value0 : @cmd.ExportInvocationMatrixSummary,
) -> Bool {
  @cmd.export_invocation_summary_has_semantic_mismatch(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_format_binary_differential_smoke_report_json(
  value0 : @cmd.BinaryDifferentialSmokeReport,
) -> String {
  @cmd.format_binary_differential_smoke_report_json(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_native_differential_tools_available() -> (Bool, Bool) {
  @cmd.native_differential_tools_available()
}

///|
#doc(hidden)
pub fn ffi_cmd_persist_fuzz_failure_report(
  value0 : @cmd.FuzzFailureReport,
  value1 : @cmd.FuzzFailurePersistIO,
  corpus_dir : String?,
) -> Result[(String, String?), String] {
  @cmd.persist_fuzz_failure_report(value0, value1, corpus_dir?)
}

///|
#doc(hidden)
pub fn ffi_cmd_persist_text_differential_artifacts(
  value0 : String,
  value1 : @cmd.TextParsePrintLowerReport,
  value2 : Array[@cmd.TextAggregateAdapterResult],
  value3 : @cmd.TextAggregateClassification,
  value4 : @cmd.FuzzFailurePersistIO,
  repro_dir : String?,
  seed : UInt64?,
  attempt : Int?,
) -> Result[@cmd.TextDifferentialArtifactPaths, String] {
  @cmd.persist_text_differential_artifacts(
    value0,
    value1,
    value2,
    value3,
    value4,
    repro_dir?,
    seed?,
    attempt?,
  )
}

///|
#doc(hidden)
pub fn ffi_cmd_run_binary_differential_smoke(
  value0 : Array[Bytes],
  external_adapters : Array[@cmd.BinaryDifferentialSmokeAdapter]?,
) -> @cmd.BinaryDifferentialSmokeReport {
  @cmd.run_binary_differential_smoke(value0, external_adapters?)
}

///|
#doc(hidden)
pub fn ffi_cmd_run_binaryen_binary_validation_adapter(
  value0 : Bytes,
) -> @cmd.BinaryDifferentialAdapterResult {
  @cmd.run_binaryen_binary_validation_adapter(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_run_cmd(
  value0 : Array[String],
) -> Result[@cmd.CmdRunSummary, @cmd.CmdError] {
  @cmd.run_cmd(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_run_cmd_exit_code(value0 : Array[String]) -> Int {
  @cmd.run_cmd_exit_code(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_run_cmd_exit_code_with_adapter(
  value0 : Array[String],
  value1 : @cmd.CmdIO,
  config_json : String??,
) -> Int {
  @cmd.run_cmd_exit_code_with_adapter(value0, value1, config_json?)
}

///|
#doc(hidden)
pub fn ffi_cmd_run_cmd_fuzz_harness_profile(
  value0 : String,
  value1 : UInt64,
) -> Result[@cmd.CmdFuzzStats, String] {
  @cmd.run_cmd_fuzz_harness_profile(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_cmd_run_cmd_with_adapter(
  value0 : Array[String],
  value1 : @cmd.CmdIO,
  config_json : String??,
) -> Result[@cmd.CmdRunSummary, @cmd.CmdError] {
  @cmd.run_cmd_with_adapter(value0, value1, config_json?)
}

///|
#doc(hidden)
pub fn ffi_cmd_run_local_text_parse_print_lower_matrix(
  value0 : String,
  filename : String?,
) -> @cmd.TextParsePrintLowerReport {
  @cmd.run_local_text_parse_print_lower_matrix(value0, filename?)
}

///|
#doc(hidden)
pub fn ffi_cmd_run_wabt_binary_validation_adapter(
  value0 : Bytes,
) -> @cmd.BinaryDifferentialAdapterResult {
  @cmd.run_wabt_binary_validation_adapter(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_run_wasm_tools_binary_validation_adapter(
  value0 : Bytes,
) -> @cmd.BinaryDifferentialAdapterResult {
  @cmd.run_wasm_tools_binary_validation_adapter(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_summarize_binary_canonicality_classifications(
  value0 : Array[@cmd.BinaryCanonicalityClassification],
) -> @cmd.BinaryCanonicalitySummary {
  @cmd.summarize_binary_canonicality_classifications(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_summarize_export_invocation_matrix(
  value0 : Array[@cmd.ExportInvocationComparisonReport],
) -> @cmd.ExportInvocationMatrixSummary {
  @cmd.summarize_export_invocation_matrix(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_text_aggregate_classification_label(
  value0 : @cmd.TextAggregateClassification,
) -> String {
  @cmd.text_aggregate_classification_label(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_text_aggregate_local_result(
  value0 : @cmd.TextParsePrintLowerReport,
  validates_ok : Bool??,
) -> @cmd.TextAggregateAdapterResult {
  @cmd.text_aggregate_local_result(value0, validates_ok?)
}

///|
#doc(hidden)
pub fn ffi_cmd_verify_readme_api_signatures(
  value0 : String,
  value1 : Array[(String, String)],
) -> Result[Unit, String] {
  @cmd.verify_readme_api_signatures(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_cmd_verify_readme_api_signatures_with_required_blocks(
  value0 : String,
  value1 : Array[(String, String)],
  value2 : Array[String],
) -> Result[Unit, String] {
  @cmd.verify_readme_api_signatures_with_required_blocks(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_cmd_CmdEncodeError_adapter(value0 : String) -> @cmd.CmdEncodeError {
  @cmd.CmdEncodeError::adapter(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_CmdEncodeError_encode(
  value0 : @binary.EncodeError,
) -> @cmd.CmdEncodeError {
  @cmd.CmdEncodeError::encode(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryCanonicalityClassification_accepted_noncanonical() -> @cmd.BinaryCanonicalityClassification {
  @cmd.BinaryCanonicalityClassification::accepted_noncanonical()
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryCanonicalityClassification_canonical_accepted() -> @cmd.BinaryCanonicalityClassification {
  @cmd.BinaryCanonicalityClassification::canonical_accepted()
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryCanonicalityClassification_decoder_bug_disagreement() -> @cmd.BinaryCanonicalityClassification {
  @cmd.BinaryCanonicalityClassification::decoder_bug_disagreement()
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryCanonicalityClassification_external_policy_disagreement() -> @cmd.BinaryCanonicalityClassification {
  @cmd.BinaryCanonicalityClassification::external_policy_disagreement()
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryCanonicalityClassification_malformed_rejected() -> @cmd.BinaryCanonicalityClassification {
  @cmd.BinaryCanonicalityClassification::malformed_rejected()
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryCanonicalityInputClass_accepted_noncanonical() -> @cmd.BinaryCanonicalityInputClass {
  @cmd.BinaryCanonicalityInputClass::accepted_noncanonical()
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryCanonicalityInputClass_canonical() -> @cmd.BinaryCanonicalityInputClass {
  @cmd.BinaryCanonicalityInputClass::canonical()
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryCanonicalityInputClass_malformed() -> @cmd.BinaryCanonicalityInputClass {
  @cmd.BinaryCanonicalityInputClass::malformed()
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryDifferentialAdapterResult_adapter_unavailable(
  value0 : String,
  value1 : String,
) -> @cmd.BinaryDifferentialAdapterResult {
  @cmd.BinaryDifferentialAdapterResult::adapter_unavailable(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryDifferentialAdapterResult_invalid_decode(
  value0 : String,
  value1 : String,
) -> @cmd.BinaryDifferentialAdapterResult {
  @cmd.BinaryDifferentialAdapterResult::invalid_decode(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryDifferentialAdapterResult_invalid_validate(
  value0 : String,
  value1 : String,
) -> @cmd.BinaryDifferentialAdapterResult {
  @cmd.BinaryDifferentialAdapterResult::invalid_validate(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryDifferentialAdapterResult_tool_failure(
  value0 : String,
  value1 : String,
) -> @cmd.BinaryDifferentialAdapterResult {
  @cmd.BinaryDifferentialAdapterResult::tool_failure(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryDifferentialAdapterResult_unsupported_feature(
  value0 : String,
  value1 : String,
) -> @cmd.BinaryDifferentialAdapterResult {
  @cmd.BinaryDifferentialAdapterResult::unsupported_feature(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryDifferentialAdapterResult_valid(
  value0 : String,
) -> @cmd.BinaryDifferentialAdapterResult {
  @cmd.BinaryDifferentialAdapterResult::valid(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryDifferentialClassification_adapter_unavailable() -> @cmd.BinaryDifferentialClassification {
  @cmd.BinaryDifferentialClassification::adapter_unavailable()
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryDifferentialClassification_agree_invalid() -> @cmd.BinaryDifferentialClassification {
  @cmd.BinaryDifferentialClassification::agree_invalid()
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryDifferentialClassification_agree_valid() -> @cmd.BinaryDifferentialClassification {
  @cmd.BinaryDifferentialClassification::agree_valid()
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryDifferentialClassification_decoder_stage_disagreement() -> @cmd.BinaryDifferentialClassification {
  @cmd.BinaryDifferentialClassification::decoder_stage_disagreement()
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryDifferentialClassification_proposal_gap() -> @cmd.BinaryDifferentialClassification {
  @cmd.BinaryDifferentialClassification::proposal_gap()
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryDifferentialClassification_tool_failure() -> @cmd.BinaryDifferentialClassification {
  @cmd.BinaryDifferentialClassification::tool_failure()
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryDifferentialClassification_unsupported_feature() -> @cmd.BinaryDifferentialClassification {
  @cmd.BinaryDifferentialClassification::unsupported_feature()
}

///|
#doc(hidden)
pub fn ffi_cmd_BinaryDifferentialClassification_validator_stage_disagreement() -> @cmd.BinaryDifferentialClassification {
  @cmd.BinaryDifferentialClassification::validator_stage_disagreement()
}

///|
#doc(hidden)
pub fn ffi_cmd_CmdError_ambiguous_output_file(value0 : String) -> @cmd.CmdError {
  @cmd.CmdError::ambiguous_output_file(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_CmdError_unknown_pass_flag(value0 : String) -> @cmd.CmdError {
  @cmd.CmdError::unknown_pass_flag(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_CmdFuzzStats_new(
  attempts : Int?,
  generated_valid : Int?,
  generated_invalid : Int?,
  pipeline_validated : Int?,
  optimized : Int?,
  roundtripped : Int?,
  differential_checked : Int?,
  optimize_idempotence_checked : Int?,
  encode_decode_idempotence_checked : Int?,
  optimizer_determinism_checked : Int?,
  generator_profile : String?,
  pass_profile : String?,
) -> @cmd.CmdFuzzStats {
  @cmd.CmdFuzzStats::new(
    attempts?,
    generated_valid?,
    generated_invalid?,
    pipeline_validated?,
    optimized?,
    roundtripped?,
    differential_checked?,
    optimize_idempotence_checked?,
    encode_decode_idempotence_checked?,
    optimizer_determinism_checked?,
    generator_profile?,
    pass_profile?,
  )
}

///|
#doc(hidden)
pub fn ffi_cmd_CmdRunSummary_new(
  input_files : Array[String]?,
  output_files : Array[String]?,
  resolved_passes : Array[String]?,
  optimize_level : Int?,
  shrink_level : Int?,
  traps_never_happen : Bool?,
  ignore_implicit_traps : Bool?,
  monomorphize_min_benefit : Int?,
  closed_world : Bool?,
  low_memory_unused : Bool?,
  low_memory_bound : UInt64?,
) -> @cmd.CmdRunSummary {
  @cmd.CmdRunSummary::new(
    input_files?,
    output_files?,
    resolved_passes?,
    optimize_level?,
    shrink_level?,
    traps_never_happen?,
    ignore_implicit_traps?,
    monomorphize_min_benefit?,
    closed_world?,
    low_memory_unused?,
    low_memory_bound?,
  )
}

///|
#doc(hidden)
pub fn ffi_cmd_ExportInvocationClassification_equal_result() -> @cmd.ExportInvocationClassification {
  @cmd.ExportInvocationClassification::equal_result()
}

///|
#doc(hidden)
pub fn ffi_cmd_ExportInvocationClassification_equal_trap() -> @cmd.ExportInvocationClassification {
  @cmd.ExportInvocationClassification::equal_trap()
}

///|
#doc(hidden)
pub fn ffi_cmd_ExportInvocationClassification_nondeterministic_import() -> @cmd.ExportInvocationClassification {
  @cmd.ExportInvocationClassification::nondeterministic_import()
}

///|
#doc(hidden)
pub fn ffi_cmd_ExportInvocationClassification_semantic_mismatch(
  value0 : String,
) -> @cmd.ExportInvocationClassification {
  @cmd.ExportInvocationClassification::semantic_mismatch(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_ExportInvocationClassification_unsupported_runtime() -> @cmd.ExportInvocationClassification {
  @cmd.ExportInvocationClassification::unsupported_runtime()
}

///|
#doc(hidden)
pub fn ffi_cmd_ExportInvocationFailurePolicy_fail_on_semantic_mismatch() -> @cmd.ExportInvocationFailurePolicy {
  @cmd.ExportInvocationFailurePolicy::fail_on_semantic_mismatch()
}

///|
#doc(hidden)
pub fn ffi_cmd_ExportInvocationFailurePolicy_informational() -> @cmd.ExportInvocationFailurePolicy {
  @cmd.ExportInvocationFailurePolicy::informational()
}

///|
#doc(hidden)
pub fn ffi_cmd_ExportInvocationMatrixOutcome_all_equal() -> @cmd.ExportInvocationMatrixOutcome {
  @cmd.ExportInvocationMatrixOutcome::all_equal()
}

///|
#doc(hidden)
pub fn ffi_cmd_ExportInvocationMatrixOutcome_blocked() -> @cmd.ExportInvocationMatrixOutcome {
  @cmd.ExportInvocationMatrixOutcome::blocked()
}

///|
#doc(hidden)
pub fn ffi_cmd_ExportInvocationMatrixOutcome_empty() -> @cmd.ExportInvocationMatrixOutcome {
  @cmd.ExportInvocationMatrixOutcome::empty()
}

///|
#doc(hidden)
pub fn ffi_cmd_ExportInvocationMatrixOutcome_semantic_mismatch() -> @cmd.ExportInvocationMatrixOutcome {
  @cmd.ExportInvocationMatrixOutcome::semantic_mismatch()
}

///|
#doc(hidden)
pub fn ffi_cmd_ExportInvocationResult_nondeterministic_import(
  value0 : String,
) -> @cmd.ExportInvocationResult {
  @cmd.ExportInvocationResult::nondeterministic_import(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_ExportInvocationResult_trap(
  value0 : String,
) -> @cmd.ExportInvocationResult {
  @cmd.ExportInvocationResult::trap(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_ExportInvocationResult_unsupported_runtime(
  value0 : String,
) -> @cmd.ExportInvocationResult {
  @cmd.ExportInvocationResult::unsupported_runtime(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_ExportInvocationResult_value(
  value0 : String,
) -> @cmd.ExportInvocationResult {
  @cmd.ExportInvocationResult::value(value0)
}

///|
#doc(hidden)
pub fn ffi_cmd_FuzzCorpusDedupIndex_new() -> @cmd.FuzzCorpusDedupIndex {
  @cmd.FuzzCorpusDedupIndex::new()
}

///|
#doc(hidden)
pub fn ffi_cmd_FuzzCorpusDedupIndex_record(
  receiver : @cmd.FuzzCorpusDedupIndex,
  value1 : Bytes,
  value2 : @cmd.FuzzCorpusSource,
) -> @cmd.FuzzCorpusDedupDecision {
  @cmd.FuzzCorpusDedupIndex::record(receiver, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_cmd_FuzzCorpusDedupIndex_to_text(
  receiver : @cmd.FuzzCorpusDedupIndex,
) -> String {
  @cmd.FuzzCorpusDedupIndex::to_text(receiver)
}

///|
#doc(hidden)
pub fn ffi_cmd_FuzzCorpusSource_new(
  value0 : UInt64,
  value1 : Int,
  value2 : String,
  value3 : String,
  value4 : String,
) -> @cmd.FuzzCorpusSource {
  @cmd.FuzzCorpusSource::new(value0, value1, value2, value3, value4)
}

///|
#doc(hidden)
pub fn ffi_cmd_FuzzFailureReport_new(
  value0 : UInt64,
  value1 : Int,
  value2 : Int,
  value3 : String,
  value4 : String,
  optimize_passes : Array[String]?,
  minimized_passes : Array[String]?,
  generator_profile : String?,
  pass_profile : String?,
  generator_config_label : String?,
  generated_attempts : Int?,
  feature_facts : String?,
  wasm : Bytes??,
  reduced_wasm : Bytes??,
  reduction_original_size : Int??,
  reduction_final_size : Int??,
  reduction_predicate_evaluations : Int??,
  reduction_steps : Array[@cmd.FuzzReductionStep]?,
) -> @cmd.FuzzFailureReport {
  @cmd.FuzzFailureReport::new(
    value0,
    value1,
    value2,
    value3,
    value4,
    optimize_passes?,
    minimized_passes?,
    generator_profile?,
    pass_profile?,
    generator_config_label?,
    generated_attempts?,
    feature_facts?,
    wasm?,
    reduced_wasm?,
    reduction_original_size?,
    reduction_final_size?,
    reduction_predicate_evaluations?,
    reduction_steps?,
  )
}

///|
#doc(hidden)
pub fn ffi_cmd_InliningOptions_new(
  always_inline_max_size : Int?,
  one_caller_inline_max_size : Int?,
  flexible_inline_max_size : Int?,
  max_combined_binary_size : Int?,
  allow_functions_with_loops : Bool?,
  partial_inlining_ifs : Int?,
) -> @cmd.InliningOptions {
  @cmd.InliningOptions::new(
    always_inline_max_size?,
    one_caller_inline_max_size?,
    flexible_inline_max_size?,
    max_combined_binary_size?,
    allow_functions_with_loops?,
    partial_inlining_ifs?,
  )
}

///|
#doc(hidden)
pub fn ffi_cmd_OptimizeOptions_new(
  optimize_level : Int?,
  shrink_level : Int?,
  inlining : @cmd.InliningOptions?,
  monomorphize_min_benefit : Int?,
  closed_world : Bool?,
  zero_filled_memory : Bool?,
  fast_math : Bool?,
  low_memory_unused : Bool?,
  low_memory_bound : UInt64?,
  traps_never_happen : Bool?,
  ignore_implicit_traps : Bool?,
  compiler_fact_policy : @passes.CompilerFactUsePolicy?,
  validation_policy : @cmd.OptimizeValidationPolicy?,
  stack_function_passes : Bool?,
) -> @cmd.OptimizeOptions {
  @cmd.OptimizeOptions::new(
    optimize_level?,
    shrink_level?,
    inlining?,
    monomorphize_min_benefit?,
    closed_world?,
    zero_filled_memory?,
    fast_math?,
    low_memory_unused?,
    low_memory_bound?,
    traps_never_happen?,
    ignore_implicit_traps?,
    compiler_fact_policy?,
    validation_policy?,
    stack_function_passes?,
  )
}

///|
#doc(hidden)
pub fn ffi_cmd_OptimizeTracingLevel_helper() -> @cmd.OptimizeTracingLevel {
  @cmd.OptimizeTracingLevel::helper()
}

///|
#doc(hidden)
pub fn ffi_cmd_OptimizeTracingLevel_pass() -> @cmd.OptimizeTracingLevel {
  @cmd.OptimizeTracingLevel::pass()
}

///|
#doc(hidden)
pub fn ffi_cmd_OptimizeTracingLevel_phase() -> @cmd.OptimizeTracingLevel {
  @cmd.OptimizeTracingLevel::phase()
}

///|
#doc(hidden)
pub fn ffi_cmd_OptimizeValidationPolicy_after_segment() -> @cmd.OptimizeValidationPolicy {
  @cmd.OptimizeValidationPolicy::after_segment()
}

///|
#doc(hidden)
pub fn ffi_cmd_OptimizeValidationPolicy_final_module_only() -> @cmd.OptimizeValidationPolicy {
  @cmd.OptimizeValidationPolicy::final_module_only()
}

///|
#doc(hidden)
pub fn ffi_cmd_TextAggregateAdapterResult_external_accepted(
  value0 : String,
  validates_ok : Bool??,
) -> @cmd.TextAggregateAdapterResult {
  @cmd.TextAggregateAdapterResult::external_accepted(value0, validates_ok?)
}

///|
#doc(hidden)
pub fn ffi_cmd_TextAggregateAdapterResult_external_parse_error(
  value0 : String,
  value1 : String,
) -> @cmd.TextAggregateAdapterResult {
  @cmd.TextAggregateAdapterResult::external_parse_error(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_cmd_TextAggregateAdapterResult_external_unavailable(
  value0 : String,
  value1 : String,
) -> @cmd.TextAggregateAdapterResult {
  @cmd.TextAggregateAdapterResult::external_unavailable(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_cmd_TextAggregateAdapterResult_external_unsupported_syntax(
  value0 : String,
  value1 : String,
) -> @cmd.TextAggregateAdapterResult {
  @cmd.TextAggregateAdapterResult::external_unsupported_syntax(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_cmd_TextAggregateClassification_accepted() -> @cmd.TextAggregateClassification {
  @cmd.TextAggregateClassification::accepted()
}

///|
#doc(hidden)
pub fn ffi_cmd_TextAggregateClassification_adapter_unavailable() -> @cmd.TextAggregateClassification {
  @cmd.TextAggregateClassification::adapter_unavailable()
}

///|
#doc(hidden)
pub fn ffi_cmd_TextAggregateClassification_lower_disagreement() -> @cmd.TextAggregateClassification {
  @cmd.TextAggregateClassification::lower_disagreement()
}

///|
#doc(hidden)
pub fn ffi_cmd_TextAggregateClassification_parse_disagreement() -> @cmd.TextAggregateClassification {
  @cmd.TextAggregateClassification::parse_disagreement()
}

///|
#doc(hidden)
pub fn ffi_cmd_TextAggregateClassification_print_disagreement() -> @cmd.TextAggregateClassification {
  @cmd.TextAggregateClassification::print_disagreement()
}

///|
#doc(hidden)
pub fn ffi_cmd_TextAggregateClassification_semantic_validation_disagreement() -> @cmd.TextAggregateClassification {
  @cmd.TextAggregateClassification::semantic_validation_disagreement()
}

///|
#doc(hidden)
pub fn ffi_cmd_TextAggregateClassification_unsupported_syntax() -> @cmd.TextAggregateClassification {
  @cmd.TextAggregateClassification::unsupported_syntax()
}

///|
#doc(hidden)
pub fn ffi_ffi_bridge_optimize_module(
  value0 : @lib.Module,
  value1 : Array[String],
  optimize_level : Int?,
  shrink_level : Int?,
) -> Result[@lib.Module, String] {
  @ffi_bridge.optimize_module(value0, value1, optimize_level?, shrink_level?)
}

///|
#doc(hidden)
pub fn ffi_lib_apply_pretty_context(
  value0 : String,
  value1 : @lib.PrettyPrintContext,
) -> String {
  @lib.apply_pretty_context(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_array_comp_type(value0 : @lib.FieldType) -> @lib.CompType {
  @lib.array_comp_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_comp_type_sub_type(
  value0 : @lib.CompType,
  metadata : @lib.TypeMetadata?,
) -> @lib.SubType {
  @lib.comp_type_sub_type(value0, metadata?)
}

///|
#doc(hidden)
pub fn ffi_lib_func_comp_type(
  value0 : Array[@lib.ValType],
  value1 : Array[@lib.ValType],
) -> @lib.CompType {
  @lib.func_comp_type(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_func_extern_idx(value0 : @lib.FuncIdx) -> @lib.ExternIdx {
  @lib.func_extern_idx(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_func_extern_type(value0 : @lib.TypeIdx) -> @lib.ExternType {
  @lib.func_extern_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_func_idx(value0 : UInt) -> @lib.FuncIdx {
  @lib.func_idx(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_get_struct_field(
  value0 : Array[@lib.FieldType],
  value1 : @lib.U32,
) -> Result[@lib.FieldType, String] {
  @lib.get_struct_field(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_global_extern_idx(value0 : @lib.GlobalIdx) -> @lib.ExternIdx {
  @lib.global_extern_idx(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_global_extern_type(value0 : @lib.GlobalType) -> @lib.ExternType {
  @lib.global_extern_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_global_idx(value0 : UInt) -> @lib.GlobalIdx {
  @lib.global_idx(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_global_type(
  value0 : @lib.ValType,
  value1 : Bool,
) -> @lib.GlobalType {
  @lib.global_type(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_group_rec_type(value0 : Array[@lib.SubType]) -> @lib.RecType {
  @lib.group_rec_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_has_default(value0 : @lib.ValType) -> Bool {
  @lib.has_default(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_mem_extern_idx(value0 : @lib.MemIdx) -> @lib.ExternIdx {
  @lib.mem_extern_idx(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_mem_extern_type(value0 : @lib.MemType) -> @lib.ExternType {
  @lib.mem_extern_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_mem_type(value0 : @lib.Limits, shared : Bool?) -> @lib.MemType {
  @lib.mem_type(value0, shared?)
}

///|
#doc(hidden)
pub fn ffi_lib_min_addr(
  value0 : @lib.Limits,
  value1 : @lib.Limits,
) -> @lib.Limits {
  @lib.min_addr(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_min_addr_valtype(
  value0 : @lib.Limits,
  value1 : @lib.Limits,
) -> @lib.ValType {
  @lib.min_addr_valtype(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_module_uses_custom_descriptors(value0 : @lib.Module) -> Bool {
  @lib.module_uses_custom_descriptors(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_rec_idx(value0 : UInt) -> @lib.TypeIdx {
  @lib.rec_idx(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_result_type(value0 : Array[@lib.ValType]) -> Array[@lib.ValType] {
  @lib.result_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_single_rec_type(value0 : @lib.SubType) -> @lib.RecType {
  @lib.single_rec_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_struct_comp_type(
  value0 : Array[@lib.FieldType],
) -> @lib.CompType {
  @lib.struct_comp_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_sub_type(
  value0 : Bool,
  value1 : Array[@lib.TypeIdx],
  value2 : @lib.CompType,
  metadata : @lib.TypeMetadata?,
) -> @lib.SubType {
  @lib.sub_type(value0, value1, value2, metadata?)
}

///|
#doc(hidden)
pub fn ffi_lib_table_extern_idx(value0 : @lib.TableIdx) -> @lib.ExternIdx {
  @lib.table_extern_idx(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_table_extern_type(value0 : @lib.TableType) -> @lib.ExternType {
  @lib.table_extern_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_table_idx(value0 : UInt) -> @lib.TableIdx {
  @lib.table_idx(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_tag_extern_idx(value0 : @lib.TagIdx) -> @lib.ExternIdx {
  @lib.tag_extern_idx(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_tag_extern_type(value0 : @lib.TagType) -> @lib.ExternType {
  @lib.tag_extern_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_tag_type(value0 : @lib.TypeIdx) -> @lib.TagType {
  @lib.tag_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_trace_delta_us_to_ms(value0 : UInt64) -> UInt64 {
  @lib.trace_delta_us_to_ms(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_trace_elapsed_ms(value0 : UInt64) -> UInt64 {
  @lib.trace_elapsed_ms(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_trace_elapsed_us_since(value0 : UInt64) -> UInt64 {
  @lib.trace_elapsed_us_since(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_trace_now_ms() -> UInt64 {
  @lib.trace_now_ms()
}

///|
#doc(hidden)
pub fn ffi_lib_trace_now_us() -> UInt64 {
  @lib.trace_now_us()
}

///|
#doc(hidden)
pub fn ffi_lib_AbsHeapType_any() -> @lib.AbsHeapType {
  @lib.AbsHeapType::any()
}

///|
#doc(hidden)
pub fn ffi_lib_AbsHeapType_array() -> @lib.AbsHeapType {
  @lib.AbsHeapType::array()
}

///|
#doc(hidden)
pub fn ffi_lib_AbsHeapType_cont() -> @lib.AbsHeapType {
  @lib.AbsHeapType::cont()
}

///|
#doc(hidden)
pub fn ffi_lib_AbsHeapType_eq() -> @lib.AbsHeapType {
  @lib.AbsHeapType::eq()
}

///|
#doc(hidden)
pub fn ffi_lib_AbsHeapType_exn() -> @lib.AbsHeapType {
  @lib.AbsHeapType::exn()
}

///|
#doc(hidden)
pub fn ffi_lib_AbsHeapType_extern_() -> @lib.AbsHeapType {
  @lib.AbsHeapType::extern_()
}

///|
#doc(hidden)
pub fn ffi_lib_AbsHeapType_func() -> @lib.AbsHeapType {
  @lib.AbsHeapType::func()
}

///|
#doc(hidden)
pub fn ffi_lib_AbsHeapType_i31() -> @lib.AbsHeapType {
  @lib.AbsHeapType::i31()
}

///|
#doc(hidden)
pub fn ffi_lib_AbsHeapType_no_cont() -> @lib.AbsHeapType {
  @lib.AbsHeapType::no_cont()
}

///|
#doc(hidden)
pub fn ffi_lib_AbsHeapType_no_exn() -> @lib.AbsHeapType {
  @lib.AbsHeapType::no_exn()
}

///|
#doc(hidden)
pub fn ffi_lib_AbsHeapType_no_extern() -> @lib.AbsHeapType {
  @lib.AbsHeapType::no_extern()
}

///|
#doc(hidden)
pub fn ffi_lib_AbsHeapType_no_func() -> @lib.AbsHeapType {
  @lib.AbsHeapType::no_func()
}

///|
#doc(hidden)
pub fn ffi_lib_AbsHeapType_no_waitqueue() -> @lib.AbsHeapType {
  @lib.AbsHeapType::no_waitqueue()
}

///|
#doc(hidden)
pub fn ffi_lib_AbsHeapType_none() -> @lib.AbsHeapType {
  @lib.AbsHeapType::none()
}

///|
#doc(hidden)
pub fn ffi_lib_AbsHeapType_string_() -> @lib.AbsHeapType {
  @lib.AbsHeapType::string_()
}

///|
#doc(hidden)
pub fn ffi_lib_AbsHeapType_struct_() -> @lib.AbsHeapType {
  @lib.AbsHeapType::struct_()
}

///|
#doc(hidden)
pub fn ffi_lib_AbsHeapType_waitqueue() -> @lib.AbsHeapType {
  @lib.AbsHeapType::waitqueue()
}

///|
#doc(hidden)
pub fn ffi_lib_AggregateAtomicRmwOp_add() -> @lib.AggregateAtomicRmwOp {
  @lib.AggregateAtomicRmwOp::add()
}

///|
#doc(hidden)
pub fn ffi_lib_AggregateAtomicRmwOp_and_() -> @lib.AggregateAtomicRmwOp {
  @lib.AggregateAtomicRmwOp::and_()
}

///|
#doc(hidden)
pub fn ffi_lib_AggregateAtomicRmwOp_or_() -> @lib.AggregateAtomicRmwOp {
  @lib.AggregateAtomicRmwOp::or_()
}

///|
#doc(hidden)
pub fn ffi_lib_AggregateAtomicRmwOp_sub() -> @lib.AggregateAtomicRmwOp {
  @lib.AggregateAtomicRmwOp::sub()
}

///|
#doc(hidden)
pub fn ffi_lib_AggregateAtomicRmwOp_xchg() -> @lib.AggregateAtomicRmwOp {
  @lib.AggregateAtomicRmwOp::xchg()
}

///|
#doc(hidden)
pub fn ffi_lib_AggregateAtomicRmwOp_xor() -> @lib.AggregateAtomicRmwOp {
  @lib.AggregateAtomicRmwOp::xor()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicCmpxchgOp_i32() -> @lib.AtomicCmpxchgOp {
  @lib.AtomicCmpxchgOp::i32()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicCmpxchgOp_i32_16_u() -> @lib.AtomicCmpxchgOp {
  @lib.AtomicCmpxchgOp::i32_16_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicCmpxchgOp_i32_8_u() -> @lib.AtomicCmpxchgOp {
  @lib.AtomicCmpxchgOp::i32_8_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicCmpxchgOp_i64() -> @lib.AtomicCmpxchgOp {
  @lib.AtomicCmpxchgOp::i64()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicCmpxchgOp_i64_16_u() -> @lib.AtomicCmpxchgOp {
  @lib.AtomicCmpxchgOp::i64_16_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicCmpxchgOp_i64_32_u() -> @lib.AtomicCmpxchgOp {
  @lib.AtomicCmpxchgOp::i64_32_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicCmpxchgOp_i64_8_u() -> @lib.AtomicCmpxchgOp {
  @lib.AtomicCmpxchgOp::i64_8_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicOrder_acq_rel() -> @lib.AtomicOrder {
  @lib.AtomicOrder::acq_rel()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicOrder_relaxed() -> @lib.AtomicOrder {
  @lib.AtomicOrder::relaxed()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicOrder_seq_cst() -> @lib.AtomicOrder {
  @lib.AtomicOrder::seq_cst()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i32_16_add_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i32_16_add_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i32_16_and_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i32_16_and_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i32_16_or_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i32_16_or_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i32_16_sub_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i32_16_sub_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i32_16_xchg_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i32_16_xchg_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i32_16_xor_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i32_16_xor_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i32_8_add_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i32_8_add_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i32_8_and_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i32_8_and_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i32_8_or_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i32_8_or_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i32_8_sub_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i32_8_sub_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i32_8_xchg_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i32_8_xchg_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i32_8_xor_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i32_8_xor_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i32_add() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i32_add()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i32_and() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i32_and()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i32_or() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i32_or()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i32_sub() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i32_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i32_xchg() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i32_xchg()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i32_xor() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i32_xor()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_16_add_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_16_add_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_16_and_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_16_and_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_16_or_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_16_or_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_16_sub_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_16_sub_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_16_xchg_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_16_xchg_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_16_xor_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_16_xor_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_32_add_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_32_add_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_32_and_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_32_and_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_32_or_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_32_or_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_32_sub_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_32_sub_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_32_xchg_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_32_xchg_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_32_xor_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_32_xor_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_8_add_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_8_add_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_8_and_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_8_and_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_8_or_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_8_or_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_8_sub_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_8_sub_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_8_xchg_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_8_xchg_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_8_xor_u() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_8_xor_u()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_add() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_add()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_and() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_and()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_or() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_or()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_sub() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_xchg() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_xchg()
}

///|
#doc(hidden)
pub fn ffi_lib_AtomicRmwOp_i64_xor() -> @lib.AtomicRmwOp {
  @lib.AtomicRmwOp::i64_xor()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32_add() -> @lib.BinaryOp {
  @lib.BinaryOp::f32_add()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32_copysign() -> @lib.BinaryOp {
  @lib.BinaryOp::f32_copysign()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32_div() -> @lib.BinaryOp {
  @lib.BinaryOp::f32_div()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32_eq() -> @lib.BinaryOp {
  @lib.BinaryOp::f32_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32_ge() -> @lib.BinaryOp {
  @lib.BinaryOp::f32_ge()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32_gt() -> @lib.BinaryOp {
  @lib.BinaryOp::f32_gt()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32_le() -> @lib.BinaryOp {
  @lib.BinaryOp::f32_le()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32_lt() -> @lib.BinaryOp {
  @lib.BinaryOp::f32_lt()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32_max() -> @lib.BinaryOp {
  @lib.BinaryOp::f32_max()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32_min() -> @lib.BinaryOp {
  @lib.BinaryOp::f32_min()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32_mul() -> @lib.BinaryOp {
  @lib.BinaryOp::f32_mul()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32_ne() -> @lib.BinaryOp {
  @lib.BinaryOp::f32_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32_sub() -> @lib.BinaryOp {
  @lib.BinaryOp::f32_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32x4_add() -> @lib.BinaryOp {
  @lib.BinaryOp::f32x4_add()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32x4_div() -> @lib.BinaryOp {
  @lib.BinaryOp::f32x4_div()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32x4_eq() -> @lib.BinaryOp {
  @lib.BinaryOp::f32x4_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32x4_ge() -> @lib.BinaryOp {
  @lib.BinaryOp::f32x4_ge()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32x4_gt() -> @lib.BinaryOp {
  @lib.BinaryOp::f32x4_gt()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32x4_le() -> @lib.BinaryOp {
  @lib.BinaryOp::f32x4_le()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32x4_lt() -> @lib.BinaryOp {
  @lib.BinaryOp::f32x4_lt()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32x4_max() -> @lib.BinaryOp {
  @lib.BinaryOp::f32x4_max()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32x4_min() -> @lib.BinaryOp {
  @lib.BinaryOp::f32x4_min()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32x4_mul() -> @lib.BinaryOp {
  @lib.BinaryOp::f32x4_mul()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32x4_ne() -> @lib.BinaryOp {
  @lib.BinaryOp::f32x4_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32x4_pmax() -> @lib.BinaryOp {
  @lib.BinaryOp::f32x4_pmax()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32x4_pmin() -> @lib.BinaryOp {
  @lib.BinaryOp::f32x4_pmin()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32x4_relaxed_max() -> @lib.BinaryOp {
  @lib.BinaryOp::f32x4_relaxed_max()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32x4_relaxed_min() -> @lib.BinaryOp {
  @lib.BinaryOp::f32x4_relaxed_min()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f32x4_sub() -> @lib.BinaryOp {
  @lib.BinaryOp::f32x4_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64_add() -> @lib.BinaryOp {
  @lib.BinaryOp::f64_add()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64_copysign() -> @lib.BinaryOp {
  @lib.BinaryOp::f64_copysign()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64_div() -> @lib.BinaryOp {
  @lib.BinaryOp::f64_div()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64_eq() -> @lib.BinaryOp {
  @lib.BinaryOp::f64_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64_ge() -> @lib.BinaryOp {
  @lib.BinaryOp::f64_ge()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64_gt() -> @lib.BinaryOp {
  @lib.BinaryOp::f64_gt()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64_le() -> @lib.BinaryOp {
  @lib.BinaryOp::f64_le()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64_lt() -> @lib.BinaryOp {
  @lib.BinaryOp::f64_lt()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64_max() -> @lib.BinaryOp {
  @lib.BinaryOp::f64_max()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64_min() -> @lib.BinaryOp {
  @lib.BinaryOp::f64_min()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64_mul() -> @lib.BinaryOp {
  @lib.BinaryOp::f64_mul()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64_ne() -> @lib.BinaryOp {
  @lib.BinaryOp::f64_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64_sub() -> @lib.BinaryOp {
  @lib.BinaryOp::f64_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64x2_add() -> @lib.BinaryOp {
  @lib.BinaryOp::f64x2_add()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64x2_div() -> @lib.BinaryOp {
  @lib.BinaryOp::f64x2_div()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64x2_eq() -> @lib.BinaryOp {
  @lib.BinaryOp::f64x2_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64x2_ge() -> @lib.BinaryOp {
  @lib.BinaryOp::f64x2_ge()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64x2_gt() -> @lib.BinaryOp {
  @lib.BinaryOp::f64x2_gt()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64x2_le() -> @lib.BinaryOp {
  @lib.BinaryOp::f64x2_le()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64x2_lt() -> @lib.BinaryOp {
  @lib.BinaryOp::f64x2_lt()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64x2_max() -> @lib.BinaryOp {
  @lib.BinaryOp::f64x2_max()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64x2_min() -> @lib.BinaryOp {
  @lib.BinaryOp::f64x2_min()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64x2_mul() -> @lib.BinaryOp {
  @lib.BinaryOp::f64x2_mul()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64x2_ne() -> @lib.BinaryOp {
  @lib.BinaryOp::f64x2_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64x2_pmax() -> @lib.BinaryOp {
  @lib.BinaryOp::f64x2_pmax()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64x2_pmin() -> @lib.BinaryOp {
  @lib.BinaryOp::f64x2_pmin()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64x2_relaxed_max() -> @lib.BinaryOp {
  @lib.BinaryOp::f64x2_relaxed_max()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64x2_relaxed_min() -> @lib.BinaryOp {
  @lib.BinaryOp::f64x2_relaxed_min()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_f64x2_sub() -> @lib.BinaryOp {
  @lib.BinaryOp::f64x2_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_add() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_add()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_add_sat_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_add_sat_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_add_sat_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_add_sat_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_avgr_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_avgr_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_eq() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_extmul_high_i8x16s() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_extmul_high_i8x16s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_extmul_high_i8x16u() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_extmul_high_i8x16u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_extmul_low_i8x16s() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_extmul_low_i8x16s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_extmul_low_i8x16u() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_extmul_low_i8x16u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_ge_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_ge_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_ge_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_ge_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_gt_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_gt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_gt_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_gt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_le_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_le_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_le_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_le_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_lt_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_lt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_lt_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_lt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_max_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_max_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_max_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_max_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_min_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_min_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_min_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_min_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_mul() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_mul()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_narrow_i32x4s() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_narrow_i32x4s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_narrow_i32x4u() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_narrow_i32x4u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_ne() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_relaxed_dot_i8x16i7x16s() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_relaxed_dot_i8x16i7x16s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_relaxed_q15mulr_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_relaxed_q15mulr_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_sub() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_sub_sat_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_sub_sat_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8_sub_sat_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8_sub_sat_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i16x8q15mulr_sat_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i16x8q15mulr_sat_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_add() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_add()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_and() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_and()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_div_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_div_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_div_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_div_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_eq() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_ge_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_ge_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_ge_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_ge_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_gt_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_gt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_gt_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_gt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_le_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_le_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_le_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_le_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_lt_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_lt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_lt_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_lt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_mul() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_mul()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_ne() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_or() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_or()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_rem_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_rem_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_rem_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_rem_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_rotl() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_rotl()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_rotr() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_rotr()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_shl() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_shl()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_shr_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_shr_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_shr_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_shr_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_sub() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32_xor() -> @lib.BinaryOp {
  @lib.BinaryOp::i32_xor()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_add() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_add()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_dot_i16x8s() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_dot_i16x8s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_eq() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_extmul_high_i16x8s() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_extmul_high_i16x8s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_extmul_high_i16x8u() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_extmul_high_i16x8u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_extmul_low_i16x8s() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_extmul_low_i16x8s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_extmul_low_i16x8u() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_extmul_low_i16x8u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_ge_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_ge_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_ge_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_ge_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_gt_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_gt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_gt_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_gt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_le_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_le_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_le_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_le_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_lt_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_lt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_lt_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_lt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_max_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_max_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_max_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_max_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_min_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_min_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_min_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_min_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_mul() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_mul()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_ne() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i32x4_sub() -> @lib.BinaryOp {
  @lib.BinaryOp::i32x4_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_add() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_add()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_and() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_and()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_div_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_div_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_div_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_div_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_eq() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_ge_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_ge_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_ge_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_ge_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_gt_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_gt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_gt_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_gt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_le_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_le_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_le_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_le_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_lt_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_lt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_lt_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_lt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_mul() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_mul()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_ne() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_or() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_or()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_rem_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_rem_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_rem_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_rem_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_rotl() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_rotl()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_rotr() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_rotr()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_shl() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_shl()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_shr_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_shr_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_shr_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_shr_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_sub() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64_xor() -> @lib.BinaryOp {
  @lib.BinaryOp::i64_xor()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64x2_add() -> @lib.BinaryOp {
  @lib.BinaryOp::i64x2_add()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64x2_eq() -> @lib.BinaryOp {
  @lib.BinaryOp::i64x2_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64x2_extmul_high_i32x4s() -> @lib.BinaryOp {
  @lib.BinaryOp::i64x2_extmul_high_i32x4s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64x2_extmul_high_i32x4u() -> @lib.BinaryOp {
  @lib.BinaryOp::i64x2_extmul_high_i32x4u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64x2_extmul_low_i32x4s() -> @lib.BinaryOp {
  @lib.BinaryOp::i64x2_extmul_low_i32x4s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64x2_extmul_low_i32x4u() -> @lib.BinaryOp {
  @lib.BinaryOp::i64x2_extmul_low_i32x4u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64x2_ge_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i64x2_ge_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64x2_gt_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i64x2_gt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64x2_le_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i64x2_le_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64x2_lt_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i64x2_lt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64x2_mul() -> @lib.BinaryOp {
  @lib.BinaryOp::i64x2_mul()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64x2_ne() -> @lib.BinaryOp {
  @lib.BinaryOp::i64x2_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i64x2_sub() -> @lib.BinaryOp {
  @lib.BinaryOp::i64x2_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_add() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_add()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_add_sat_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_add_sat_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_add_sat_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_add_sat_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_avgr_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_avgr_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_eq() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_ge_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_ge_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_ge_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_ge_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_gt_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_gt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_gt_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_gt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_le_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_le_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_le_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_le_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_lt_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_lt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_lt_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_lt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_max_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_max_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_max_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_max_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_min_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_min_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_min_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_min_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_narrow_i16x8s() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_narrow_i16x8s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_narrow_i16x8u() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_narrow_i16x8u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_ne() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_sub() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_sub_sat_s() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_sub_sat_s()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_i8x16_sub_sat_u() -> @lib.BinaryOp {
  @lib.BinaryOp::i8x16_sub_sat_u()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_v128_and() -> @lib.BinaryOp {
  @lib.BinaryOp::v128_and()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_v128_andnot() -> @lib.BinaryOp {
  @lib.BinaryOp::v128_andnot()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_v128_or() -> @lib.BinaryOp {
  @lib.BinaryOp::v128_or()
}

///|
#doc(hidden)
pub fn ffi_lib_BinaryOp_v128_xor() -> @lib.BinaryOp {
  @lib.BinaryOp::v128_xor()
}

///|
#doc(hidden)
pub fn ffi_lib_BlockType_type_idx(value0 : @lib.TypeIdx) -> @lib.BlockType {
  @lib.BlockType::type_idx(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_BlockType_val_type(value0 : @lib.ValType) -> @lib.BlockType {
  @lib.BlockType::val_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_BlockType_void_() -> @lib.BlockType {
  @lib.BlockType::void_()
}

///|
#doc(hidden)
pub fn ffi_lib_CastOp_new(
  value0 : Bool,
  value1 : Bool,
  source_exact : Bool?,
  target_exact : Bool?,
) -> @lib.CastOp {
  @lib.CastOp::new(value0, value1, source_exact?, target_exact?)
}

///|
#doc(hidden)
pub fn ffi_lib_CastOp_source_exact(receiver : @lib.CastOp) -> Bool {
  @lib.CastOp::source_exact(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_CastOp_source_nullable(receiver : @lib.CastOp) -> Bool {
  @lib.CastOp::source_nullable(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_CastOp_target_exact(receiver : @lib.CastOp) -> Bool {
  @lib.CastOp::target_exact(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_CastOp_target_nullable(receiver : @lib.CastOp) -> Bool {
  @lib.CastOp::target_nullable(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_Catch_all(value0 : @lib.LabelIdx) -> @lib.Catch {
  @lib.Catch::all(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Catch_all_ref(value0 : @lib.LabelIdx) -> @lib.Catch {
  @lib.Catch::all_ref(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Catch_new(
  value0 : @lib.TagIdx,
  value1 : @lib.LabelIdx,
) -> @lib.Catch {
  @lib.Catch::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Catch_ref_(
  value0 : @lib.TagIdx,
  value1 : @lib.LabelIdx,
) -> @lib.Catch {
  @lib.Catch::ref_(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_CodeSec_new(value0 : Array[@lib.Func]) -> @lib.CodeSec {
  @lib.CodeSec::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_CompType_array(value0 : @lib.FieldType) -> @lib.CompType {
  @lib.CompType::array(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_CompType_cont(value0 : @lib.TypeIdx) -> @lib.CompType {
  @lib.CompType::cont(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_CompType_func(
  value0 : Array[@lib.ValType],
  value1 : Array[@lib.ValType],
) -> @lib.CompType {
  @lib.CompType::func(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_CompType_struct_(
  value0 : Array[@lib.FieldType],
) -> @lib.CompType {
  @lib.CompType::struct_(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_CustomSec_new(
  value0 : @lib.Name,
  value1 : Bytes,
) -> @lib.CustomSec {
  @lib.CustomSec::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Data_new(value0 : @lib.DataMode, value1 : Bytes) -> @lib.Data {
  @lib.Data::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_DataCntSec_new(value0 : @lib.U32) -> @lib.DataCntSec {
  @lib.DataCntSec::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_DataIdx_new(value0 : UInt) -> @lib.DataIdx {
  @lib.DataIdx::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_DataMode_active(
  value0 : @lib.MemIdx,
  value1 : @lib.Expr,
) -> @lib.DataMode {
  @lib.DataMode::active(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_DataMode_passive() -> @lib.DataMode {
  @lib.DataMode::passive()
}

///|
#doc(hidden)
pub fn ffi_lib_DataSec_new(value0 : Array[@lib.Data]) -> @lib.DataSec {
  @lib.DataSec::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_DefType_new(
  value0 : @lib.RecType,
  value1 : UInt,
) -> @lib.DefType {
  @lib.DefType::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_DefType_project(receiver : @lib.DefType) -> @lib.SubType? {
  @lib.DefType::project(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_Elem_new(
  value0 : @lib.ElemMode,
  value1 : @lib.ElemKind,
) -> @lib.Elem {
  @lib.Elem::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Elem_reftype(receiver : @lib.Elem) -> @lib.RefType {
  @lib.Elem::reftype(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_ElemIdx_new(value0 : UInt) -> @lib.ElemIdx {
  @lib.ElemIdx::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ElemKind_func_exprs(value0 : Array[@lib.Expr]) -> @lib.ElemKind {
  @lib.ElemKind::func_exprs(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ElemKind_funcs(value0 : Array[@lib.FuncIdx]) -> @lib.ElemKind {
  @lib.ElemKind::funcs(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ElemKind_typed_exprs(
  value0 : @lib.RefType,
  value1 : Array[@lib.Expr],
) -> @lib.ElemKind {
  @lib.ElemKind::typed_exprs(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_ElemMode_active(
  value0 : @lib.TableIdx,
  value1 : @lib.Expr,
) -> @lib.ElemMode {
  @lib.ElemMode::active(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_ElemMode_declarative() -> @lib.ElemMode {
  @lib.ElemMode::declarative()
}

///|
#doc(hidden)
pub fn ffi_lib_ElemMode_passive() -> @lib.ElemMode {
  @lib.ElemMode::passive()
}

///|
#doc(hidden)
pub fn ffi_lib_ElemSec_new(value0 : Array[@lib.Elem]) -> @lib.ElemSec {
  @lib.ElemSec::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Export_new(
  value0 : @lib.Name,
  value1 : @lib.ExternIdx,
) -> @lib.Export {
  @lib.Export::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_ExportSec_new(value0 : Array[@lib.Export]) -> @lib.ExportSec {
  @lib.ExportSec::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Expr_new(value0 : Array[@lib.Instruction]) -> @lib.Expr {
  @lib.Expr::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ExternIdx_func(value0 : @lib.FuncIdx) -> @lib.ExternIdx {
  @lib.ExternIdx::func(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ExternIdx_global(value0 : @lib.GlobalIdx) -> @lib.ExternIdx {
  @lib.ExternIdx::global(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ExternIdx_mem(value0 : @lib.MemIdx) -> @lib.ExternIdx {
  @lib.ExternIdx::mem(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ExternIdx_table(value0 : @lib.TableIdx) -> @lib.ExternIdx {
  @lib.ExternIdx::table(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ExternIdx_tag(value0 : @lib.TagIdx) -> @lib.ExternIdx {
  @lib.ExternIdx::tag(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ExternType_func(value0 : @lib.TypeIdx) -> @lib.ExternType {
  @lib.ExternType::func(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ExternType_global(value0 : @lib.GlobalType) -> @lib.ExternType {
  @lib.ExternType::global(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ExternType_mem(value0 : @lib.MemType) -> @lib.ExternType {
  @lib.ExternType::mem(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ExternType_table(value0 : @lib.TableType) -> @lib.ExternType {
  @lib.ExternType::table(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ExternType_tag(value0 : @lib.TagType) -> @lib.ExternType {
  @lib.ExternType::tag(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ExtractLaneOp_f32x4_extract_lane() -> @lib.ExtractLaneOp {
  @lib.ExtractLaneOp::f32x4_extract_lane()
}

///|
#doc(hidden)
pub fn ffi_lib_ExtractLaneOp_f64x2_extract_lane() -> @lib.ExtractLaneOp {
  @lib.ExtractLaneOp::f64x2_extract_lane()
}

///|
#doc(hidden)
pub fn ffi_lib_ExtractLaneOp_i16x8_extract_lane_s() -> @lib.ExtractLaneOp {
  @lib.ExtractLaneOp::i16x8_extract_lane_s()
}

///|
#doc(hidden)
pub fn ffi_lib_ExtractLaneOp_i16x8_extract_lane_u() -> @lib.ExtractLaneOp {
  @lib.ExtractLaneOp::i16x8_extract_lane_u()
}

///|
#doc(hidden)
pub fn ffi_lib_ExtractLaneOp_i32x4_extract_lane() -> @lib.ExtractLaneOp {
  @lib.ExtractLaneOp::i32x4_extract_lane()
}

///|
#doc(hidden)
pub fn ffi_lib_ExtractLaneOp_i64x2_extract_lane() -> @lib.ExtractLaneOp {
  @lib.ExtractLaneOp::i64x2_extract_lane()
}

///|
#doc(hidden)
pub fn ffi_lib_ExtractLaneOp_i8x16_extract_lane_s() -> @lib.ExtractLaneOp {
  @lib.ExtractLaneOp::i8x16_extract_lane_s()
}

///|
#doc(hidden)
pub fn ffi_lib_ExtractLaneOp_i8x16_extract_lane_u() -> @lib.ExtractLaneOp {
  @lib.ExtractLaneOp::i8x16_extract_lane_u()
}

///|
#doc(hidden)
pub fn ffi_lib_F32_new(value0 : Float) -> @lib.F32 {
  @lib.F32::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_F64_new(value0 : Double) -> @lib.F64 {
  @lib.F64::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_FieldType_get_storage_type(
  receiver : @lib.FieldType,
) -> @lib.StorageType {
  @lib.FieldType::get_storage_type(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_FieldType_is_mutable(receiver : @lib.FieldType) -> Bool {
  @lib.FieldType::is_mutable(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_FieldType_new(
  value0 : @lib.StorageType,
  value1 : @lib.Mut,
) -> @lib.FieldType {
  @lib.FieldType::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_FieldType_unpack(receiver : @lib.FieldType) -> @lib.ValType {
  @lib.FieldType::unpack(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_Func_new(value0 : @lib.Locals, value1 : @lib.Expr) -> @lib.Func {
  @lib.Func::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_FuncAnnotation_new(
  value0 : String,
  args : Array[String]?,
) -> @lib.FuncAnnotation {
  @lib.FuncAnnotation::new(value0, args?)
}

///|
#doc(hidden)
pub fn ffi_lib_FuncAnnotationAssoc_new(
  value0 : UInt,
  value1 : Array[@lib.FuncAnnotation],
) -> @lib.FuncAnnotationAssoc {
  @lib.FuncAnnotationAssoc::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_FuncAnnotationSec_new(
  value0 : Array[@lib.FuncAnnotationAssoc],
) -> @lib.FuncAnnotationSec {
  @lib.FuncAnnotationSec::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_FuncIdx_new(value0 : UInt) -> @lib.FuncIdx {
  @lib.FuncIdx::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_FuncSec_new(value0 : Array[@lib.TypeIdx]) -> @lib.FuncSec {
  @lib.FuncSec::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_FuncType_new(
  value0 : Array[@lib.ValType],
  value1 : Array[@lib.ValType],
) -> @lib.FuncType {
  @lib.FuncType::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_FunctionLocals_all_locals(
  receiver : @lib.FunctionLocals,
) -> @lib.Locals {
  @lib.FunctionLocals::all_locals(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_FunctionLocals_body_locals(
  receiver : @lib.FunctionLocals,
) -> @lib.Locals {
  @lib.FunctionLocals::body_locals(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_FunctionLocals_from_local_decls(
  value0 : Array[@lib.ValType],
  value1 : @lib.Locals,
) -> Result[@lib.FunctionLocals, String] {
  @lib.FunctionLocals::from_local_decls(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_FunctionLocals_from_typed_func(
  value0 : Array[@lib.ValType],
  value1 : Array[@lib.ValType],
  value2 : @lib.Locals,
) -> Result[@lib.FunctionLocals, String] {
  @lib.FunctionLocals::from_typed_func(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_lib_FunctionLocals_from_typed_func_for_pass(
  value0 : Array[@lib.ValType],
  value1 : Array[@lib.ValType],
  value2 : @lib.Locals,
) -> Result[@lib.FunctionLocals, String] {
  @lib.FunctionLocals::from_typed_func_for_pass(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_lib_FunctionLocals_local_type(
  receiver : @lib.FunctionLocals,
  value1 : @lib.LocalIdx,
) -> @lib.ValType? {
  @lib.FunctionLocals::local_type(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_FunctionLocals_new(
  value0 : Array[@lib.ValType],
  value1 : @lib.Locals,
) -> @lib.FunctionLocals {
  @lib.FunctionLocals::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_FunctionLocals_param_count(
  receiver : @lib.FunctionLocals,
) -> Int {
  @lib.FunctionLocals::param_count(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_FunctionLocals_params(
  receiver : @lib.FunctionLocals,
) -> Array[@lib.ValType] {
  @lib.FunctionLocals::params(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_Global_new(
  value0 : @lib.GlobalType,
  value1 : @lib.Expr,
) -> @lib.Global {
  @lib.Global::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_GlobalIdx_new(value0 : UInt) -> @lib.GlobalIdx {
  @lib.GlobalIdx::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_GlobalSec_new(value0 : Array[@lib.Global]) -> @lib.GlobalSec {
  @lib.GlobalSec::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_GlobalType_new(
  value0 : @lib.ValType,
  value1 : Bool,
) -> @lib.GlobalType {
  @lib.GlobalType::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_HeapType_abs(value0 : @lib.AbsHeapType) -> @lib.HeapType {
  @lib.HeapType::abs(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_HeapType_bottom() -> @lib.HeapType {
  @lib.HeapType::bottom()
}

///|
#doc(hidden)
pub fn ffi_lib_HeapType_def_type(value0 : @lib.DefType) -> @lib.HeapType {
  @lib.HeapType::def_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_HeapType_is_array(receiver : @lib.HeapType) -> Bool {
  @lib.HeapType::is_array(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_HeapType_is_gc_aggregate(receiver : @lib.HeapType) -> Bool {
  @lib.HeapType::is_gc_aggregate(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_HeapType_is_shared(receiver : @lib.HeapType) -> Bool {
  @lib.HeapType::is_shared(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_HeapType_is_struct(receiver : @lib.HeapType) -> Bool {
  @lib.HeapType::is_struct(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_HeapType_new(value0 : @lib.TypeIdx) -> @lib.HeapType {
  @lib.HeapType::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_HeapType_shared_abs(value0 : @lib.AbsHeapType) -> @lib.HeapType {
  @lib.HeapType::shared_abs(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_I32_new(value0 : Int) -> @lib.I32 {
  @lib.I32::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_I64_new(value0 : Int64) -> @lib.I64 {
  @lib.I64::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Import_new(
  value0 : @lib.Name,
  value1 : @lib.Name,
  value2 : @lib.ExternType,
) -> @lib.Import {
  @lib.Import::new(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_lib_ImportSec_new(value0 : Array[@lib.Import]) -> @lib.ImportSec {
  @lib.ImportSec::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_IndirectNameAssoc_new(
  value0 : UInt,
  value1 : @lib.NameMap,
) -> @lib.IndirectNameAssoc {
  @lib.IndirectNameAssoc::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_IndirectNameMap_new(
  value0 : Array[@lib.IndirectNameAssoc],
) -> @lib.IndirectNameMap {
  @lib.IndirectNameMap::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_any_convert_extern() -> @lib.Instruction {
  @lib.Instruction::any_convert_extern()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_atomic_cmpxchg(
  value0 : @lib.TypeIdx,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::array_atomic_cmpxchg(value0, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_atomic_get(
  value0 : @lib.AtomicOrder,
  value1 : @lib.TypeIdx,
) -> @lib.Instruction {
  @lib.Instruction::array_atomic_get(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_atomic_get_s(
  value0 : @lib.AtomicOrder,
  value1 : @lib.TypeIdx,
) -> @lib.Instruction {
  @lib.Instruction::array_atomic_get_s(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_atomic_get_u(
  value0 : @lib.AtomicOrder,
  value1 : @lib.TypeIdx,
) -> @lib.Instruction {
  @lib.Instruction::array_atomic_get_u(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_atomic_rmw(
  value0 : @lib.AggregateAtomicRmwOp,
  value1 : @lib.TypeIdx,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::array_atomic_rmw(value0, value1, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_atomic_set(
  value0 : @lib.AtomicOrder,
  value1 : @lib.TypeIdx,
) -> @lib.Instruction {
  @lib.Instruction::array_atomic_set(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_copy(
  value0 : @lib.TypeIdx,
  value1 : @lib.TypeIdx,
) -> @lib.Instruction {
  @lib.Instruction::array_copy(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_fill(
  value0 : @lib.TypeIdx,
) -> @lib.Instruction {
  @lib.Instruction::array_fill(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_get(value0 : @lib.TypeIdx) -> @lib.Instruction {
  @lib.Instruction::array_get(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_get_s(
  value0 : @lib.TypeIdx,
) -> @lib.Instruction {
  @lib.Instruction::array_get_s(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_get_u(
  value0 : @lib.TypeIdx,
) -> @lib.Instruction {
  @lib.Instruction::array_get_u(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_init_data(
  value0 : @lib.TypeIdx,
  value1 : @lib.DataIdx,
) -> @lib.Instruction {
  @lib.Instruction::array_init_data(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_init_elem(
  value0 : @lib.TypeIdx,
  value1 : @lib.ElemIdx,
) -> @lib.Instruction {
  @lib.Instruction::array_init_elem(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_len() -> @lib.Instruction {
  @lib.Instruction::array_len()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_load(
  value0 : @lib.LoadOp,
  value1 : @lib.TypeIdx,
  memarg : @lib.MemArg?,
) -> @lib.Instruction {
  @lib.Instruction::array_load(value0, value1, memarg?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_new(value0 : @lib.TypeIdx) -> @lib.Instruction {
  @lib.Instruction::array_new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_new_data(
  value0 : @lib.TypeIdx,
  value1 : @lib.DataIdx,
) -> @lib.Instruction {
  @lib.Instruction::array_new_data(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_new_default(
  value0 : @lib.TypeIdx,
) -> @lib.Instruction {
  @lib.Instruction::array_new_default(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_new_elem(
  value0 : @lib.TypeIdx,
  value1 : @lib.ElemIdx,
) -> @lib.Instruction {
  @lib.Instruction::array_new_elem(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_new_fixed(
  value0 : @lib.TypeIdx,
  value1 : @lib.U32,
) -> @lib.Instruction {
  @lib.Instruction::array_new_fixed(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_set(value0 : @lib.TypeIdx) -> @lib.Instruction {
  @lib.Instruction::array_set(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_array_store(
  value0 : @lib.StoreOp,
  value1 : @lib.TypeIdx,
  memarg : @lib.MemArg?,
) -> @lib.Instruction {
  @lib.Instruction::array_store(value0, value1, memarg?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_atomic_cmpxchg(
  value0 : @lib.AtomicCmpxchgOp,
  value1 : @lib.MemArg,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::atomic_cmpxchg(value0, value1, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_atomic_fence(
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::atomic_fence(order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_atomic_rmw(
  value0 : @lib.AtomicRmwOp,
  value1 : @lib.MemArg,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::atomic_rmw(value0, value1, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_block(
  value0 : @lib.BlockType,
  value1 : @lib.Expr,
) -> @lib.Instruction {
  @lib.Instruction::block(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_br(value0 : @lib.LabelIdx) -> @lib.Instruction {
  @lib.Instruction::br(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_br_if(value0 : @lib.LabelIdx) -> @lib.Instruction {
  @lib.Instruction::br_if(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_br_on_cast(
  value0 : @lib.LabelIdx,
  value1 : Bool,
  value2 : @lib.HeapType,
  value3 : Bool,
  value4 : @lib.HeapType,
  source_exact : Bool?,
  target_exact : Bool?,
) -> @lib.Instruction {
  @lib.Instruction::br_on_cast(
    value0,
    value1,
    value2,
    value3,
    value4,
    source_exact?,
    target_exact?,
  )
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_br_on_cast_desc_eq(
  value0 : @lib.LabelIdx,
  value1 : @lib.RefType,
  value2 : @lib.RefType,
) -> @lib.Instruction {
  @lib.Instruction::br_on_cast_desc_eq(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_br_on_cast_desc_eq_fail(
  value0 : @lib.LabelIdx,
  value1 : @lib.RefType,
  value2 : @lib.RefType,
) -> @lib.Instruction {
  @lib.Instruction::br_on_cast_desc_eq_fail(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_br_on_cast_fail(
  value0 : @lib.LabelIdx,
  value1 : Bool,
  value2 : @lib.HeapType,
  value3 : Bool,
  value4 : @lib.HeapType,
  source_exact : Bool?,
  target_exact : Bool?,
) -> @lib.Instruction {
  @lib.Instruction::br_on_cast_fail(
    value0,
    value1,
    value2,
    value3,
    value4,
    source_exact?,
    target_exact?,
  )
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_br_on_non_null(
  value0 : @lib.LabelIdx,
) -> @lib.Instruction {
  @lib.Instruction::br_on_non_null(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_br_on_null(
  value0 : @lib.LabelIdx,
) -> @lib.Instruction {
  @lib.Instruction::br_on_null(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_br_table(
  value0 : Array[@lib.LabelIdx],
  value1 : @lib.LabelIdx,
) -> @lib.Instruction {
  @lib.Instruction::br_table(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_call(value0 : @lib.FuncIdx) -> @lib.Instruction {
  @lib.Instruction::call(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_call_indirect(
  value0 : @lib.TypeIdx,
  value1 : @lib.TableIdx,
) -> @lib.Instruction {
  @lib.Instruction::call_indirect(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_call_ref(value0 : @lib.TypeIdx) -> @lib.Instruction {
  @lib.Instruction::call_ref(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_cont_bind(
  value0 : @lib.TypeIdx,
  value1 : @lib.TypeIdx,
) -> @lib.Instruction {
  @lib.Instruction::cont_bind(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_cont_new(value0 : @lib.TypeIdx) -> @lib.Instruction {
  @lib.Instruction::cont_new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_data_drop(value0 : @lib.DataIdx) -> @lib.Instruction {
  @lib.Instruction::data_drop(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_drop() -> @lib.Instruction {
  @lib.Instruction::drop()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_elem_drop(value0 : @lib.ElemIdx) -> @lib.Instruction {
  @lib.Instruction::elem_drop(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_extern_convert_any() -> @lib.Instruction {
  @lib.Instruction::extern_convert_any()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_abs() -> @lib.Instruction {
  @lib.Instruction::f32_abs()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_add() -> @lib.Instruction {
  @lib.Instruction::f32_add()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_ceil() -> @lib.Instruction {
  @lib.Instruction::f32_ceil()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_const(value0 : @lib.F32) -> @lib.Instruction {
  @lib.Instruction::f32_const(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_convert_i32s() -> @lib.Instruction {
  @lib.Instruction::f32_convert_i32s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_convert_i32u() -> @lib.Instruction {
  @lib.Instruction::f32_convert_i32u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_convert_i64s() -> @lib.Instruction {
  @lib.Instruction::f32_convert_i64s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_convert_i64u() -> @lib.Instruction {
  @lib.Instruction::f32_convert_i64u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_copysign() -> @lib.Instruction {
  @lib.Instruction::f32_copysign()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_demote_f64() -> @lib.Instruction {
  @lib.Instruction::f32_demote_f64()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_div() -> @lib.Instruction {
  @lib.Instruction::f32_div()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_eq() -> @lib.Instruction {
  @lib.Instruction::f32_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_floor() -> @lib.Instruction {
  @lib.Instruction::f32_floor()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_ge() -> @lib.Instruction {
  @lib.Instruction::f32_ge()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_gt() -> @lib.Instruction {
  @lib.Instruction::f32_gt()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_le() -> @lib.Instruction {
  @lib.Instruction::f32_le()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_load(value0 : @lib.MemArg) -> @lib.Instruction {
  @lib.Instruction::f32_load(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_lt() -> @lib.Instruction {
  @lib.Instruction::f32_lt()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_max() -> @lib.Instruction {
  @lib.Instruction::f32_max()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_min() -> @lib.Instruction {
  @lib.Instruction::f32_min()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_mul() -> @lib.Instruction {
  @lib.Instruction::f32_mul()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_ne() -> @lib.Instruction {
  @lib.Instruction::f32_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_nearest() -> @lib.Instruction {
  @lib.Instruction::f32_nearest()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_neg() -> @lib.Instruction {
  @lib.Instruction::f32_neg()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_reinterpret_i32() -> @lib.Instruction {
  @lib.Instruction::f32_reinterpret_i32()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_sqrt() -> @lib.Instruction {
  @lib.Instruction::f32_sqrt()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_store(value0 : @lib.MemArg) -> @lib.Instruction {
  @lib.Instruction::f32_store(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_sub() -> @lib.Instruction {
  @lib.Instruction::f32_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32_trunc() -> @lib.Instruction {
  @lib.Instruction::f32_trunc()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_abs() -> @lib.Instruction {
  @lib.Instruction::f32x4_abs()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_add() -> @lib.Instruction {
  @lib.Instruction::f32x4_add()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_ceil() -> @lib.Instruction {
  @lib.Instruction::f32x4_ceil()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_convert_i32x4s() -> @lib.Instruction {
  @lib.Instruction::f32x4_convert_i32x4s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_convert_i32x4u() -> @lib.Instruction {
  @lib.Instruction::f32x4_convert_i32x4u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_demote_f64x2_zero() -> @lib.Instruction {
  @lib.Instruction::f32x4_demote_f64x2_zero()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_div() -> @lib.Instruction {
  @lib.Instruction::f32x4_div()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_eq() -> @lib.Instruction {
  @lib.Instruction::f32x4_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_extract_lane(
  value0 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::f32x4_extract_lane(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_floor() -> @lib.Instruction {
  @lib.Instruction::f32x4_floor()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_ge() -> @lib.Instruction {
  @lib.Instruction::f32x4_ge()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_gt() -> @lib.Instruction {
  @lib.Instruction::f32x4_gt()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_le() -> @lib.Instruction {
  @lib.Instruction::f32x4_le()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_lt() -> @lib.Instruction {
  @lib.Instruction::f32x4_lt()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_max() -> @lib.Instruction {
  @lib.Instruction::f32x4_max()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_min() -> @lib.Instruction {
  @lib.Instruction::f32x4_min()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_mul() -> @lib.Instruction {
  @lib.Instruction::f32x4_mul()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_ne() -> @lib.Instruction {
  @lib.Instruction::f32x4_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_nearest() -> @lib.Instruction {
  @lib.Instruction::f32x4_nearest()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_neg() -> @lib.Instruction {
  @lib.Instruction::f32x4_neg()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_pmax() -> @lib.Instruction {
  @lib.Instruction::f32x4_pmax()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_pmin() -> @lib.Instruction {
  @lib.Instruction::f32x4_pmin()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_relaxed_madd() -> @lib.Instruction {
  @lib.Instruction::f32x4_relaxed_madd()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_relaxed_max() -> @lib.Instruction {
  @lib.Instruction::f32x4_relaxed_max()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_relaxed_min() -> @lib.Instruction {
  @lib.Instruction::f32x4_relaxed_min()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_relaxed_nmadd() -> @lib.Instruction {
  @lib.Instruction::f32x4_relaxed_nmadd()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_replace_lane(
  value0 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::f32x4_replace_lane(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_splat() -> @lib.Instruction {
  @lib.Instruction::f32x4_splat()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_sqrt() -> @lib.Instruction {
  @lib.Instruction::f32x4_sqrt()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_sub() -> @lib.Instruction {
  @lib.Instruction::f32x4_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f32x4_trunc() -> @lib.Instruction {
  @lib.Instruction::f32x4_trunc()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_abs() -> @lib.Instruction {
  @lib.Instruction::f64_abs()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_add() -> @lib.Instruction {
  @lib.Instruction::f64_add()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_ceil() -> @lib.Instruction {
  @lib.Instruction::f64_ceil()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_const(value0 : @lib.F64) -> @lib.Instruction {
  @lib.Instruction::f64_const(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_convert_i32s() -> @lib.Instruction {
  @lib.Instruction::f64_convert_i32s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_convert_i32u() -> @lib.Instruction {
  @lib.Instruction::f64_convert_i32u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_convert_i64s() -> @lib.Instruction {
  @lib.Instruction::f64_convert_i64s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_convert_i64u() -> @lib.Instruction {
  @lib.Instruction::f64_convert_i64u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_copysign() -> @lib.Instruction {
  @lib.Instruction::f64_copysign()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_div() -> @lib.Instruction {
  @lib.Instruction::f64_div()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_eq() -> @lib.Instruction {
  @lib.Instruction::f64_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_floor() -> @lib.Instruction {
  @lib.Instruction::f64_floor()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_ge() -> @lib.Instruction {
  @lib.Instruction::f64_ge()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_gt() -> @lib.Instruction {
  @lib.Instruction::f64_gt()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_le() -> @lib.Instruction {
  @lib.Instruction::f64_le()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_load(value0 : @lib.MemArg) -> @lib.Instruction {
  @lib.Instruction::f64_load(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_lt() -> @lib.Instruction {
  @lib.Instruction::f64_lt()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_max() -> @lib.Instruction {
  @lib.Instruction::f64_max()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_min() -> @lib.Instruction {
  @lib.Instruction::f64_min()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_mul() -> @lib.Instruction {
  @lib.Instruction::f64_mul()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_ne() -> @lib.Instruction {
  @lib.Instruction::f64_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_nearest() -> @lib.Instruction {
  @lib.Instruction::f64_nearest()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_neg() -> @lib.Instruction {
  @lib.Instruction::f64_neg()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_promote_f32() -> @lib.Instruction {
  @lib.Instruction::f64_promote_f32()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_reinterpret_i64() -> @lib.Instruction {
  @lib.Instruction::f64_reinterpret_i64()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_sqrt() -> @lib.Instruction {
  @lib.Instruction::f64_sqrt()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_store(value0 : @lib.MemArg) -> @lib.Instruction {
  @lib.Instruction::f64_store(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_sub() -> @lib.Instruction {
  @lib.Instruction::f64_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64_trunc() -> @lib.Instruction {
  @lib.Instruction::f64_trunc()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_abs() -> @lib.Instruction {
  @lib.Instruction::f64x2_abs()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_add() -> @lib.Instruction {
  @lib.Instruction::f64x2_add()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_ceil() -> @lib.Instruction {
  @lib.Instruction::f64x2_ceil()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_convert_low_i32x4s() -> @lib.Instruction {
  @lib.Instruction::f64x2_convert_low_i32x4s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_convert_low_i32x4u() -> @lib.Instruction {
  @lib.Instruction::f64x2_convert_low_i32x4u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_div() -> @lib.Instruction {
  @lib.Instruction::f64x2_div()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_eq() -> @lib.Instruction {
  @lib.Instruction::f64x2_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_extract_lane(
  value0 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::f64x2_extract_lane(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_floor() -> @lib.Instruction {
  @lib.Instruction::f64x2_floor()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_ge() -> @lib.Instruction {
  @lib.Instruction::f64x2_ge()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_gt() -> @lib.Instruction {
  @lib.Instruction::f64x2_gt()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_le() -> @lib.Instruction {
  @lib.Instruction::f64x2_le()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_lt() -> @lib.Instruction {
  @lib.Instruction::f64x2_lt()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_max() -> @lib.Instruction {
  @lib.Instruction::f64x2_max()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_min() -> @lib.Instruction {
  @lib.Instruction::f64x2_min()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_mul() -> @lib.Instruction {
  @lib.Instruction::f64x2_mul()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_ne() -> @lib.Instruction {
  @lib.Instruction::f64x2_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_nearest() -> @lib.Instruction {
  @lib.Instruction::f64x2_nearest()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_neg() -> @lib.Instruction {
  @lib.Instruction::f64x2_neg()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_pmax() -> @lib.Instruction {
  @lib.Instruction::f64x2_pmax()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_pmin() -> @lib.Instruction {
  @lib.Instruction::f64x2_pmin()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_promote_low_f32x4() -> @lib.Instruction {
  @lib.Instruction::f64x2_promote_low_f32x4()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_relaxed_madd() -> @lib.Instruction {
  @lib.Instruction::f64x2_relaxed_madd()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_relaxed_max() -> @lib.Instruction {
  @lib.Instruction::f64x2_relaxed_max()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_relaxed_min() -> @lib.Instruction {
  @lib.Instruction::f64x2_relaxed_min()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_relaxed_nmadd() -> @lib.Instruction {
  @lib.Instruction::f64x2_relaxed_nmadd()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_replace_lane(
  value0 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::f64x2_replace_lane(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_splat() -> @lib.Instruction {
  @lib.Instruction::f64x2_splat()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_sqrt() -> @lib.Instruction {
  @lib.Instruction::f64x2_sqrt()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_sub() -> @lib.Instruction {
  @lib.Instruction::f64x2_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_f64x2_trunc() -> @lib.Instruction {
  @lib.Instruction::f64x2_trunc()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_global_get(
  value0 : @lib.GlobalIdx,
) -> @lib.Instruction {
  @lib.Instruction::global_get(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_global_set(
  value0 : @lib.GlobalIdx,
) -> @lib.Instruction {
  @lib.Instruction::global_set(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_abs() -> @lib.Instruction {
  @lib.Instruction::i16x8_abs()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_add() -> @lib.Instruction {
  @lib.Instruction::i16x8_add()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_add_sat_s() -> @lib.Instruction {
  @lib.Instruction::i16x8_add_sat_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_add_sat_u() -> @lib.Instruction {
  @lib.Instruction::i16x8_add_sat_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_all_true() -> @lib.Instruction {
  @lib.Instruction::i16x8_all_true()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_avgr_u() -> @lib.Instruction {
  @lib.Instruction::i16x8_avgr_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_bitmask() -> @lib.Instruction {
  @lib.Instruction::i16x8_bitmask()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_eq() -> @lib.Instruction {
  @lib.Instruction::i16x8_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_extadd_pairwise_i8x16s() -> @lib.Instruction {
  @lib.Instruction::i16x8_extadd_pairwise_i8x16s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_extadd_pairwise_i8x16u() -> @lib.Instruction {
  @lib.Instruction::i16x8_extadd_pairwise_i8x16u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_extend_high_i8x16s() -> @lib.Instruction {
  @lib.Instruction::i16x8_extend_high_i8x16s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_extend_high_i8x16u() -> @lib.Instruction {
  @lib.Instruction::i16x8_extend_high_i8x16u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_extend_low_i8x16s() -> @lib.Instruction {
  @lib.Instruction::i16x8_extend_low_i8x16s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_extend_low_i8x16u() -> @lib.Instruction {
  @lib.Instruction::i16x8_extend_low_i8x16u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_extmul_high_i8x16s() -> @lib.Instruction {
  @lib.Instruction::i16x8_extmul_high_i8x16s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_extmul_high_i8x16u() -> @lib.Instruction {
  @lib.Instruction::i16x8_extmul_high_i8x16u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_extmul_low_i8x16s() -> @lib.Instruction {
  @lib.Instruction::i16x8_extmul_low_i8x16s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_extmul_low_i8x16u() -> @lib.Instruction {
  @lib.Instruction::i16x8_extmul_low_i8x16u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_extract_lane_s(
  value0 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::i16x8_extract_lane_s(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_extract_lane_u(
  value0 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::i16x8_extract_lane_u(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_ge_s() -> @lib.Instruction {
  @lib.Instruction::i16x8_ge_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_ge_u() -> @lib.Instruction {
  @lib.Instruction::i16x8_ge_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_gt_s() -> @lib.Instruction {
  @lib.Instruction::i16x8_gt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_gt_u() -> @lib.Instruction {
  @lib.Instruction::i16x8_gt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_le_s() -> @lib.Instruction {
  @lib.Instruction::i16x8_le_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_le_u() -> @lib.Instruction {
  @lib.Instruction::i16x8_le_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_lt_s() -> @lib.Instruction {
  @lib.Instruction::i16x8_lt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_lt_u() -> @lib.Instruction {
  @lib.Instruction::i16x8_lt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_max_s() -> @lib.Instruction {
  @lib.Instruction::i16x8_max_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_max_u() -> @lib.Instruction {
  @lib.Instruction::i16x8_max_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_min_s() -> @lib.Instruction {
  @lib.Instruction::i16x8_min_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_min_u() -> @lib.Instruction {
  @lib.Instruction::i16x8_min_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_mul() -> @lib.Instruction {
  @lib.Instruction::i16x8_mul()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_narrow_i32x4s() -> @lib.Instruction {
  @lib.Instruction::i16x8_narrow_i32x4s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_narrow_i32x4u() -> @lib.Instruction {
  @lib.Instruction::i16x8_narrow_i32x4u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_ne() -> @lib.Instruction {
  @lib.Instruction::i16x8_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_neg() -> @lib.Instruction {
  @lib.Instruction::i16x8_neg()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_relaxed_dot_i8x16i7x16s() -> @lib.Instruction {
  @lib.Instruction::i16x8_relaxed_dot_i8x16i7x16s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_relaxed_laneselect() -> @lib.Instruction {
  @lib.Instruction::i16x8_relaxed_laneselect()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_relaxed_q15mulr_s() -> @lib.Instruction {
  @lib.Instruction::i16x8_relaxed_q15mulr_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_replace_lane(
  value0 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::i16x8_replace_lane(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_shl() -> @lib.Instruction {
  @lib.Instruction::i16x8_shl()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_shr_s() -> @lib.Instruction {
  @lib.Instruction::i16x8_shr_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_shr_u() -> @lib.Instruction {
  @lib.Instruction::i16x8_shr_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_splat() -> @lib.Instruction {
  @lib.Instruction::i16x8_splat()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_sub() -> @lib.Instruction {
  @lib.Instruction::i16x8_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_sub_sat_s() -> @lib.Instruction {
  @lib.Instruction::i16x8_sub_sat_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8_sub_sat_u() -> @lib.Instruction {
  @lib.Instruction::i16x8_sub_sat_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i16x8q15mulr_sat_s() -> @lib.Instruction {
  @lib.Instruction::i16x8q15mulr_sat_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i31_get_s() -> @lib.Instruction {
  @lib.Instruction::i31_get_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i31_get_u() -> @lib.Instruction {
  @lib.Instruction::i31_get_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_add() -> @lib.Instruction {
  @lib.Instruction::i32_add()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_and() -> @lib.Instruction {
  @lib.Instruction::i32_and()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_atomic_load(
  value0 : @lib.MemArg,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::i32_atomic_load(value0, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_atomic_load16_u(
  value0 : @lib.MemArg,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::i32_atomic_load16_u(value0, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_atomic_load8_u(
  value0 : @lib.MemArg,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::i32_atomic_load8_u(value0, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_atomic_store(
  value0 : @lib.MemArg,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::i32_atomic_store(value0, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_atomic_store16(
  value0 : @lib.MemArg,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::i32_atomic_store16(value0, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_atomic_store8(
  value0 : @lib.MemArg,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::i32_atomic_store8(value0, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_clz() -> @lib.Instruction {
  @lib.Instruction::i32_clz()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_const(value0 : @lib.I32) -> @lib.Instruction {
  @lib.Instruction::i32_const(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_ctz() -> @lib.Instruction {
  @lib.Instruction::i32_ctz()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_div_s() -> @lib.Instruction {
  @lib.Instruction::i32_div_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_div_u() -> @lib.Instruction {
  @lib.Instruction::i32_div_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_eq() -> @lib.Instruction {
  @lib.Instruction::i32_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_eqz() -> @lib.Instruction {
  @lib.Instruction::i32_eqz()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_extend16s() -> @lib.Instruction {
  @lib.Instruction::i32_extend16s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_extend8s() -> @lib.Instruction {
  @lib.Instruction::i32_extend8s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_ge_s() -> @lib.Instruction {
  @lib.Instruction::i32_ge_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_ge_u() -> @lib.Instruction {
  @lib.Instruction::i32_ge_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_gt_s() -> @lib.Instruction {
  @lib.Instruction::i32_gt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_gt_u() -> @lib.Instruction {
  @lib.Instruction::i32_gt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_le_s() -> @lib.Instruction {
  @lib.Instruction::i32_le_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_le_u() -> @lib.Instruction {
  @lib.Instruction::i32_le_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_load(value0 : @lib.MemArg) -> @lib.Instruction {
  @lib.Instruction::i32_load(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_load16s(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::i32_load16s(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_load16u(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::i32_load16u(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_load8s(value0 : @lib.MemArg) -> @lib.Instruction {
  @lib.Instruction::i32_load8s(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_load8u(value0 : @lib.MemArg) -> @lib.Instruction {
  @lib.Instruction::i32_load8u(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_lt_s() -> @lib.Instruction {
  @lib.Instruction::i32_lt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_lt_u() -> @lib.Instruction {
  @lib.Instruction::i32_lt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_mul() -> @lib.Instruction {
  @lib.Instruction::i32_mul()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_ne() -> @lib.Instruction {
  @lib.Instruction::i32_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_or() -> @lib.Instruction {
  @lib.Instruction::i32_or()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_popcnt() -> @lib.Instruction {
  @lib.Instruction::i32_popcnt()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_reinterpret_f32() -> @lib.Instruction {
  @lib.Instruction::i32_reinterpret_f32()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_rem_s() -> @lib.Instruction {
  @lib.Instruction::i32_rem_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_rem_u() -> @lib.Instruction {
  @lib.Instruction::i32_rem_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_rotl() -> @lib.Instruction {
  @lib.Instruction::i32_rotl()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_rotr() -> @lib.Instruction {
  @lib.Instruction::i32_rotr()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_shl() -> @lib.Instruction {
  @lib.Instruction::i32_shl()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_shr_s() -> @lib.Instruction {
  @lib.Instruction::i32_shr_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_shr_u() -> @lib.Instruction {
  @lib.Instruction::i32_shr_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_store(value0 : @lib.MemArg) -> @lib.Instruction {
  @lib.Instruction::i32_store(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_store16(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::i32_store16(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_store8(value0 : @lib.MemArg) -> @lib.Instruction {
  @lib.Instruction::i32_store8(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_sub() -> @lib.Instruction {
  @lib.Instruction::i32_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_trunc_f32s() -> @lib.Instruction {
  @lib.Instruction::i32_trunc_f32s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_trunc_f32u() -> @lib.Instruction {
  @lib.Instruction::i32_trunc_f32u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_trunc_f64s() -> @lib.Instruction {
  @lib.Instruction::i32_trunc_f64s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_trunc_f64u() -> @lib.Instruction {
  @lib.Instruction::i32_trunc_f64u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_trunc_sat_f32s() -> @lib.Instruction {
  @lib.Instruction::i32_trunc_sat_f32s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_trunc_sat_f32u() -> @lib.Instruction {
  @lib.Instruction::i32_trunc_sat_f32u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_trunc_sat_f64s() -> @lib.Instruction {
  @lib.Instruction::i32_trunc_sat_f64s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_trunc_sat_f64u() -> @lib.Instruction {
  @lib.Instruction::i32_trunc_sat_f64u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_wrap_i64() -> @lib.Instruction {
  @lib.Instruction::i32_wrap_i64()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32_xor() -> @lib.Instruction {
  @lib.Instruction::i32_xor()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_abs() -> @lib.Instruction {
  @lib.Instruction::i32x4_abs()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_add() -> @lib.Instruction {
  @lib.Instruction::i32x4_add()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_all_true() -> @lib.Instruction {
  @lib.Instruction::i32x4_all_true()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_bitmask() -> @lib.Instruction {
  @lib.Instruction::i32x4_bitmask()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_dot_i16x8s() -> @lib.Instruction {
  @lib.Instruction::i32x4_dot_i16x8s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_eq() -> @lib.Instruction {
  @lib.Instruction::i32x4_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_extadd_pairwise_i16x8s() -> @lib.Instruction {
  @lib.Instruction::i32x4_extadd_pairwise_i16x8s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_extadd_pairwise_i16x8u() -> @lib.Instruction {
  @lib.Instruction::i32x4_extadd_pairwise_i16x8u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_extend_high_i16x8s() -> @lib.Instruction {
  @lib.Instruction::i32x4_extend_high_i16x8s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_extend_high_i16x8u() -> @lib.Instruction {
  @lib.Instruction::i32x4_extend_high_i16x8u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_extend_low_i16x8s() -> @lib.Instruction {
  @lib.Instruction::i32x4_extend_low_i16x8s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_extend_low_i16x8u() -> @lib.Instruction {
  @lib.Instruction::i32x4_extend_low_i16x8u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_extmul_high_i16x8s() -> @lib.Instruction {
  @lib.Instruction::i32x4_extmul_high_i16x8s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_extmul_high_i16x8u() -> @lib.Instruction {
  @lib.Instruction::i32x4_extmul_high_i16x8u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_extmul_low_i16x8s() -> @lib.Instruction {
  @lib.Instruction::i32x4_extmul_low_i16x8s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_extmul_low_i16x8u() -> @lib.Instruction {
  @lib.Instruction::i32x4_extmul_low_i16x8u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_extract_lane(
  value0 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::i32x4_extract_lane(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_ge_s() -> @lib.Instruction {
  @lib.Instruction::i32x4_ge_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_ge_u() -> @lib.Instruction {
  @lib.Instruction::i32x4_ge_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_gt_s() -> @lib.Instruction {
  @lib.Instruction::i32x4_gt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_gt_u() -> @lib.Instruction {
  @lib.Instruction::i32x4_gt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_le_s() -> @lib.Instruction {
  @lib.Instruction::i32x4_le_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_le_u() -> @lib.Instruction {
  @lib.Instruction::i32x4_le_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_lt_s() -> @lib.Instruction {
  @lib.Instruction::i32x4_lt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_lt_u() -> @lib.Instruction {
  @lib.Instruction::i32x4_lt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_max_s() -> @lib.Instruction {
  @lib.Instruction::i32x4_max_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_max_u() -> @lib.Instruction {
  @lib.Instruction::i32x4_max_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_min_s() -> @lib.Instruction {
  @lib.Instruction::i32x4_min_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_min_u() -> @lib.Instruction {
  @lib.Instruction::i32x4_min_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_mul() -> @lib.Instruction {
  @lib.Instruction::i32x4_mul()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_ne() -> @lib.Instruction {
  @lib.Instruction::i32x4_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_neg() -> @lib.Instruction {
  @lib.Instruction::i32x4_neg()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_relaxed_dot_i8x16i7x16_add_s() -> @lib.Instruction {
  @lib.Instruction::i32x4_relaxed_dot_i8x16i7x16_add_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_relaxed_laneselect() -> @lib.Instruction {
  @lib.Instruction::i32x4_relaxed_laneselect()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_relaxed_trunc_f32x4s() -> @lib.Instruction {
  @lib.Instruction::i32x4_relaxed_trunc_f32x4s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_relaxed_trunc_f32x4u() -> @lib.Instruction {
  @lib.Instruction::i32x4_relaxed_trunc_f32x4u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_relaxed_trunc_zero_f64x2s() -> @lib.Instruction {
  @lib.Instruction::i32x4_relaxed_trunc_zero_f64x2s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_relaxed_trunc_zero_f64x2u() -> @lib.Instruction {
  @lib.Instruction::i32x4_relaxed_trunc_zero_f64x2u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_replace_lane(
  value0 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::i32x4_replace_lane(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_shl() -> @lib.Instruction {
  @lib.Instruction::i32x4_shl()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_shr_s() -> @lib.Instruction {
  @lib.Instruction::i32x4_shr_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_shr_u() -> @lib.Instruction {
  @lib.Instruction::i32x4_shr_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_splat() -> @lib.Instruction {
  @lib.Instruction::i32x4_splat()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_sub() -> @lib.Instruction {
  @lib.Instruction::i32x4_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_trunc_sat_f32x4s() -> @lib.Instruction {
  @lib.Instruction::i32x4_trunc_sat_f32x4s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_trunc_sat_f32x4u() -> @lib.Instruction {
  @lib.Instruction::i32x4_trunc_sat_f32x4u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_trunc_sat_f64x2s_zero() -> @lib.Instruction {
  @lib.Instruction::i32x4_trunc_sat_f64x2s_zero()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i32x4_trunc_sat_f64x2u_zero() -> @lib.Instruction {
  @lib.Instruction::i32x4_trunc_sat_f64x2u_zero()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_add() -> @lib.Instruction {
  @lib.Instruction::i64_add()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_and() -> @lib.Instruction {
  @lib.Instruction::i64_and()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_atomic_load(
  value0 : @lib.MemArg,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::i64_atomic_load(value0, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_atomic_load16_u(
  value0 : @lib.MemArg,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::i64_atomic_load16_u(value0, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_atomic_load32_u(
  value0 : @lib.MemArg,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::i64_atomic_load32_u(value0, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_atomic_load8_u(
  value0 : @lib.MemArg,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::i64_atomic_load8_u(value0, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_atomic_store(
  value0 : @lib.MemArg,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::i64_atomic_store(value0, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_atomic_store16(
  value0 : @lib.MemArg,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::i64_atomic_store16(value0, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_atomic_store32(
  value0 : @lib.MemArg,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::i64_atomic_store32(value0, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_atomic_store8(
  value0 : @lib.MemArg,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::i64_atomic_store8(value0, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_clz() -> @lib.Instruction {
  @lib.Instruction::i64_clz()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_const(value0 : @lib.I64) -> @lib.Instruction {
  @lib.Instruction::i64_const(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_ctz() -> @lib.Instruction {
  @lib.Instruction::i64_ctz()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_div_s() -> @lib.Instruction {
  @lib.Instruction::i64_div_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_div_u() -> @lib.Instruction {
  @lib.Instruction::i64_div_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_eq() -> @lib.Instruction {
  @lib.Instruction::i64_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_eqz() -> @lib.Instruction {
  @lib.Instruction::i64_eqz()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_extend16s() -> @lib.Instruction {
  @lib.Instruction::i64_extend16s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_extend32s() -> @lib.Instruction {
  @lib.Instruction::i64_extend32s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_extend8s() -> @lib.Instruction {
  @lib.Instruction::i64_extend8s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_extend_i32s() -> @lib.Instruction {
  @lib.Instruction::i64_extend_i32s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_extend_i32u() -> @lib.Instruction {
  @lib.Instruction::i64_extend_i32u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_ge_s() -> @lib.Instruction {
  @lib.Instruction::i64_ge_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_ge_u() -> @lib.Instruction {
  @lib.Instruction::i64_ge_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_gt_s() -> @lib.Instruction {
  @lib.Instruction::i64_gt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_gt_u() -> @lib.Instruction {
  @lib.Instruction::i64_gt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_le_s() -> @lib.Instruction {
  @lib.Instruction::i64_le_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_le_u() -> @lib.Instruction {
  @lib.Instruction::i64_le_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_load(value0 : @lib.MemArg) -> @lib.Instruction {
  @lib.Instruction::i64_load(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_load16s(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::i64_load16s(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_load16u(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::i64_load16u(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_load32s(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::i64_load32s(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_load32u(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::i64_load32u(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_load8s(value0 : @lib.MemArg) -> @lib.Instruction {
  @lib.Instruction::i64_load8s(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_load8u(value0 : @lib.MemArg) -> @lib.Instruction {
  @lib.Instruction::i64_load8u(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_lt_s() -> @lib.Instruction {
  @lib.Instruction::i64_lt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_lt_u() -> @lib.Instruction {
  @lib.Instruction::i64_lt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_mul() -> @lib.Instruction {
  @lib.Instruction::i64_mul()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_ne() -> @lib.Instruction {
  @lib.Instruction::i64_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_or() -> @lib.Instruction {
  @lib.Instruction::i64_or()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_popcnt() -> @lib.Instruction {
  @lib.Instruction::i64_popcnt()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_reinterpret_f64() -> @lib.Instruction {
  @lib.Instruction::i64_reinterpret_f64()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_rem_s() -> @lib.Instruction {
  @lib.Instruction::i64_rem_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_rem_u() -> @lib.Instruction {
  @lib.Instruction::i64_rem_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_rotl() -> @lib.Instruction {
  @lib.Instruction::i64_rotl()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_rotr() -> @lib.Instruction {
  @lib.Instruction::i64_rotr()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_shl() -> @lib.Instruction {
  @lib.Instruction::i64_shl()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_shr_s() -> @lib.Instruction {
  @lib.Instruction::i64_shr_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_shr_u() -> @lib.Instruction {
  @lib.Instruction::i64_shr_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_store(value0 : @lib.MemArg) -> @lib.Instruction {
  @lib.Instruction::i64_store(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_store16(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::i64_store16(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_store32(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::i64_store32(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_store8(value0 : @lib.MemArg) -> @lib.Instruction {
  @lib.Instruction::i64_store8(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_sub() -> @lib.Instruction {
  @lib.Instruction::i64_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_trunc_f32s() -> @lib.Instruction {
  @lib.Instruction::i64_trunc_f32s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_trunc_f32u() -> @lib.Instruction {
  @lib.Instruction::i64_trunc_f32u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_trunc_f64s() -> @lib.Instruction {
  @lib.Instruction::i64_trunc_f64s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_trunc_f64u() -> @lib.Instruction {
  @lib.Instruction::i64_trunc_f64u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_trunc_sat_f32s() -> @lib.Instruction {
  @lib.Instruction::i64_trunc_sat_f32s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_trunc_sat_f32u() -> @lib.Instruction {
  @lib.Instruction::i64_trunc_sat_f32u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_trunc_sat_f64s() -> @lib.Instruction {
  @lib.Instruction::i64_trunc_sat_f64s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_trunc_sat_f64u() -> @lib.Instruction {
  @lib.Instruction::i64_trunc_sat_f64u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64_xor() -> @lib.Instruction {
  @lib.Instruction::i64_xor()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_abs() -> @lib.Instruction {
  @lib.Instruction::i64x2_abs()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_add() -> @lib.Instruction {
  @lib.Instruction::i64x2_add()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_all_true() -> @lib.Instruction {
  @lib.Instruction::i64x2_all_true()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_bitmask() -> @lib.Instruction {
  @lib.Instruction::i64x2_bitmask()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_eq() -> @lib.Instruction {
  @lib.Instruction::i64x2_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_extend_high_i32x4s() -> @lib.Instruction {
  @lib.Instruction::i64x2_extend_high_i32x4s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_extend_high_i32x4u() -> @lib.Instruction {
  @lib.Instruction::i64x2_extend_high_i32x4u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_extend_low_i32x4s() -> @lib.Instruction {
  @lib.Instruction::i64x2_extend_low_i32x4s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_extend_low_i32x4u() -> @lib.Instruction {
  @lib.Instruction::i64x2_extend_low_i32x4u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_extmul_high_i32x4s() -> @lib.Instruction {
  @lib.Instruction::i64x2_extmul_high_i32x4s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_extmul_high_i32x4u() -> @lib.Instruction {
  @lib.Instruction::i64x2_extmul_high_i32x4u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_extmul_low_i32x4s() -> @lib.Instruction {
  @lib.Instruction::i64x2_extmul_low_i32x4s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_extmul_low_i32x4u() -> @lib.Instruction {
  @lib.Instruction::i64x2_extmul_low_i32x4u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_extract_lane(
  value0 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::i64x2_extract_lane(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_ge_s() -> @lib.Instruction {
  @lib.Instruction::i64x2_ge_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_gt_s() -> @lib.Instruction {
  @lib.Instruction::i64x2_gt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_le_s() -> @lib.Instruction {
  @lib.Instruction::i64x2_le_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_lt_s() -> @lib.Instruction {
  @lib.Instruction::i64x2_lt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_mul() -> @lib.Instruction {
  @lib.Instruction::i64x2_mul()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_ne() -> @lib.Instruction {
  @lib.Instruction::i64x2_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_neg() -> @lib.Instruction {
  @lib.Instruction::i64x2_neg()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_relaxed_laneselect() -> @lib.Instruction {
  @lib.Instruction::i64x2_relaxed_laneselect()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_replace_lane(
  value0 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::i64x2_replace_lane(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_shl() -> @lib.Instruction {
  @lib.Instruction::i64x2_shl()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_shr_s() -> @lib.Instruction {
  @lib.Instruction::i64x2_shr_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_shr_u() -> @lib.Instruction {
  @lib.Instruction::i64x2_shr_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_splat() -> @lib.Instruction {
  @lib.Instruction::i64x2_splat()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i64x2_sub() -> @lib.Instruction {
  @lib.Instruction::i64x2_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_abs() -> @lib.Instruction {
  @lib.Instruction::i8x16_abs()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_add() -> @lib.Instruction {
  @lib.Instruction::i8x16_add()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_add_sat_s() -> @lib.Instruction {
  @lib.Instruction::i8x16_add_sat_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_add_sat_u() -> @lib.Instruction {
  @lib.Instruction::i8x16_add_sat_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_all_true() -> @lib.Instruction {
  @lib.Instruction::i8x16_all_true()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_avgr_u() -> @lib.Instruction {
  @lib.Instruction::i8x16_avgr_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_bitmask() -> @lib.Instruction {
  @lib.Instruction::i8x16_bitmask()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_eq() -> @lib.Instruction {
  @lib.Instruction::i8x16_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_extract_lane_s(
  value0 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::i8x16_extract_lane_s(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_extract_lane_u(
  value0 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::i8x16_extract_lane_u(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_ge_s() -> @lib.Instruction {
  @lib.Instruction::i8x16_ge_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_ge_u() -> @lib.Instruction {
  @lib.Instruction::i8x16_ge_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_gt_s() -> @lib.Instruction {
  @lib.Instruction::i8x16_gt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_gt_u() -> @lib.Instruction {
  @lib.Instruction::i8x16_gt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_le_s() -> @lib.Instruction {
  @lib.Instruction::i8x16_le_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_le_u() -> @lib.Instruction {
  @lib.Instruction::i8x16_le_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_lt_s() -> @lib.Instruction {
  @lib.Instruction::i8x16_lt_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_lt_u() -> @lib.Instruction {
  @lib.Instruction::i8x16_lt_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_max_s() -> @lib.Instruction {
  @lib.Instruction::i8x16_max_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_max_u() -> @lib.Instruction {
  @lib.Instruction::i8x16_max_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_min_s() -> @lib.Instruction {
  @lib.Instruction::i8x16_min_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_min_u() -> @lib.Instruction {
  @lib.Instruction::i8x16_min_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_narrow_i16x8s() -> @lib.Instruction {
  @lib.Instruction::i8x16_narrow_i16x8s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_narrow_i16x8u() -> @lib.Instruction {
  @lib.Instruction::i8x16_narrow_i16x8u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_ne() -> @lib.Instruction {
  @lib.Instruction::i8x16_ne()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_neg() -> @lib.Instruction {
  @lib.Instruction::i8x16_neg()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_popcnt() -> @lib.Instruction {
  @lib.Instruction::i8x16_popcnt()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_relaxed_laneselect() -> @lib.Instruction {
  @lib.Instruction::i8x16_relaxed_laneselect()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_relaxed_swizzle() -> @lib.Instruction {
  @lib.Instruction::i8x16_relaxed_swizzle()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_replace_lane(
  value0 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::i8x16_replace_lane(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_shl() -> @lib.Instruction {
  @lib.Instruction::i8x16_shl()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_shr_s() -> @lib.Instruction {
  @lib.Instruction::i8x16_shr_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_shr_u() -> @lib.Instruction {
  @lib.Instruction::i8x16_shr_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_shuffle(
  value0 : @lib.LaneIdx,
  value1 : @lib.LaneIdx,
  value2 : @lib.LaneIdx,
  value3 : @lib.LaneIdx,
  value4 : @lib.LaneIdx,
  value5 : @lib.LaneIdx,
  value6 : @lib.LaneIdx,
  value7 : @lib.LaneIdx,
  value8 : @lib.LaneIdx,
  value9 : @lib.LaneIdx,
  value10 : @lib.LaneIdx,
  value11 : @lib.LaneIdx,
  value12 : @lib.LaneIdx,
  value13 : @lib.LaneIdx,
  value14 : @lib.LaneIdx,
  value15 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::i8x16_shuffle(
    value0, value1, value2, value3, value4, value5, value6, value7, value8, value9,
    value10, value11, value12, value13, value14, value15,
  )
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_splat() -> @lib.Instruction {
  @lib.Instruction::i8x16_splat()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_sub() -> @lib.Instruction {
  @lib.Instruction::i8x16_sub()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_sub_sat_s() -> @lib.Instruction {
  @lib.Instruction::i8x16_sub_sat_s()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_sub_sat_u() -> @lib.Instruction {
  @lib.Instruction::i8x16_sub_sat_u()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_i8x16_swizzle() -> @lib.Instruction {
  @lib.Instruction::i8x16_swizzle()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_if_(
  value0 : @lib.BlockType,
  value1 : Array[@lib.Instruction],
  value2 : Array[@lib.Instruction]?,
) -> @lib.Instruction {
  @lib.Instruction::if_(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_local_get(
  value0 : @lib.LocalIdx,
) -> @lib.Instruction {
  @lib.Instruction::local_get(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_local_set(
  value0 : @lib.LocalIdx,
) -> @lib.Instruction {
  @lib.Instruction::local_set(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_local_tee(
  value0 : @lib.LocalIdx,
) -> @lib.Instruction {
  @lib.Instruction::local_tee(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_loop_(
  value0 : @lib.BlockType,
  value1 : @lib.Expr,
) -> @lib.Instruction {
  @lib.Instruction::loop_(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_memory_atomic_notify(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::memory_atomic_notify(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_memory_atomic_wait32(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::memory_atomic_wait32(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_memory_atomic_wait64(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::memory_atomic_wait64(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_memory_copy(
  value0 : @lib.MemIdx,
  value1 : @lib.MemIdx,
) -> @lib.Instruction {
  @lib.Instruction::memory_copy(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_memory_fill(
  value0 : @lib.MemIdx,
) -> @lib.Instruction {
  @lib.Instruction::memory_fill(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_memory_grow(
  value0 : @lib.MemIdx,
) -> @lib.Instruction {
  @lib.Instruction::memory_grow(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_memory_init(
  value0 : @lib.DataIdx,
  value1 : @lib.MemIdx,
) -> @lib.Instruction {
  @lib.Instruction::memory_init(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_memory_size(
  value0 : @lib.MemIdx,
) -> @lib.Instruction {
  @lib.Instruction::memory_size(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_nop() -> @lib.Instruction {
  @lib.Instruction::nop()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_publish() -> @lib.Instruction {
  @lib.Instruction::publish()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_ref_as_non_null() -> @lib.Instruction {
  @lib.Instruction::ref_as_non_null()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_ref_cast(
  value0 : Bool,
  value1 : @lib.HeapType,
) -> @lib.Instruction {
  @lib.Instruction::ref_cast(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_ref_cast_desc_eq(
  value0 : Bool,
  value1 : @lib.HeapType,
) -> @lib.Instruction {
  @lib.Instruction::ref_cast_desc_eq(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_ref_cast_desc_eq_type(
  value0 : @lib.RefType,
) -> @lib.Instruction {
  @lib.Instruction::ref_cast_desc_eq_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_ref_cast_exact(
  value0 : Bool,
  value1 : @lib.HeapType,
) -> @lib.Instruction {
  @lib.Instruction::ref_cast_exact(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_ref_cast_type(
  value0 : @lib.RefType,
) -> @lib.Instruction {
  @lib.Instruction::ref_cast_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_ref_eq() -> @lib.Instruction {
  @lib.Instruction::ref_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_ref_func(value0 : @lib.FuncIdx) -> @lib.Instruction {
  @lib.Instruction::ref_func(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_ref_get_desc(
  value0 : @lib.TypeIdx,
) -> @lib.Instruction {
  @lib.Instruction::ref_get_desc(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_ref_i31() -> @lib.Instruction {
  @lib.Instruction::ref_i31()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_ref_i31_shared() -> @lib.Instruction {
  @lib.Instruction::ref_i31_shared()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_ref_is_null() -> @lib.Instruction {
  @lib.Instruction::ref_is_null()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_ref_null(value0 : @lib.HeapType) -> @lib.Instruction {
  @lib.Instruction::ref_null(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_ref_null_type(
  value0 : @lib.RefType,
) -> @lib.Instruction {
  @lib.Instruction::ref_null_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_ref_test(
  value0 : Bool,
  value1 : @lib.HeapType,
) -> @lib.Instruction {
  @lib.Instruction::ref_test(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_ref_test_desc(
  value0 : Bool,
  value1 : @lib.HeapType,
) -> @lib.Instruction {
  @lib.Instruction::ref_test_desc(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_ref_test_exact(
  value0 : Bool,
  value1 : @lib.HeapType,
) -> @lib.Instruction {
  @lib.Instruction::ref_test_exact(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_ref_test_type(
  value0 : @lib.RefType,
) -> @lib.Instruction {
  @lib.Instruction::ref_test_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_resume_(
  value0 : @lib.TypeIdx,
  value1 : Array[@lib.ResumeHandler],
) -> @lib.Instruction {
  @lib.Instruction::resume_(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_resume_throw(
  value0 : @lib.TypeIdx,
  value1 : @lib.TagIdx,
  value2 : Array[@lib.ResumeHandler],
) -> @lib.Instruction {
  @lib.Instruction::resume_throw(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_resume_throw_ref(
  value0 : @lib.TypeIdx,
  value1 : Array[@lib.ResumeHandler],
) -> @lib.Instruction {
  @lib.Instruction::resume_throw_ref(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_rethrow(value0 : @lib.LabelIdx) -> @lib.Instruction {
  @lib.Instruction::rethrow(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_return_() -> @lib.Instruction {
  @lib.Instruction::return_()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_return_call(
  value0 : @lib.FuncIdx,
) -> @lib.Instruction {
  @lib.Instruction::return_call(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_return_call_indirect(
  value0 : @lib.TypeIdx,
  value1 : @lib.TableIdx,
) -> @lib.Instruction {
  @lib.Instruction::return_call_indirect(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_return_call_ref(
  value0 : @lib.TypeIdx,
) -> @lib.Instruction {
  @lib.Instruction::return_call_ref(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_select(
  types : Array[@lib.ValType]??,
) -> @lib.Instruction {
  @lib.Instruction::select(types?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_stack_switch(
  value0 : @lib.TypeIdx,
  value1 : @lib.TagIdx,
) -> @lib.Instruction {
  @lib.Instruction::stack_switch(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_string_as_wtf16() -> @lib.Instruction {
  @lib.Instruction::string_as_wtf16()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_string_concat() -> @lib.Instruction {
  @lib.Instruction::string_concat()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_string_const(value0 : Bytes) -> @lib.Instruction {
  @lib.Instruction::string_const(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_string_encode_lossy_utf8_array() -> @lib.Instruction {
  @lib.Instruction::string_encode_lossy_utf8_array()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_string_encode_utf8_array() -> @lib.Instruction {
  @lib.Instruction::string_encode_utf8_array()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_string_encode_wtf16_array() -> @lib.Instruction {
  @lib.Instruction::string_encode_wtf16_array()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_string_encode_wtf8_array() -> @lib.Instruction {
  @lib.Instruction::string_encode_wtf8_array()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_string_eq() -> @lib.Instruction {
  @lib.Instruction::string_eq()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_string_measure_wtf16() -> @lib.Instruction {
  @lib.Instruction::string_measure_wtf16()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_string_new_lossy_utf8_array() -> @lib.Instruction {
  @lib.Instruction::string_new_lossy_utf8_array()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_string_new_utf8_array() -> @lib.Instruction {
  @lib.Instruction::string_new_utf8_array()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_string_new_wtf16_array() -> @lib.Instruction {
  @lib.Instruction::string_new_wtf16_array()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_string_new_wtf8_array() -> @lib.Instruction {
  @lib.Instruction::string_new_wtf8_array()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_stringview_wtf16_get_codeunit() -> @lib.Instruction {
  @lib.Instruction::stringview_wtf16_get_codeunit()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_stringview_wtf16_slice() -> @lib.Instruction {
  @lib.Instruction::stringview_wtf16_slice()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_struct_atomic_cmpxchg(
  value0 : @lib.TypeIdx,
  value1 : @lib.U32,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::struct_atomic_cmpxchg(value0, value1, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_struct_atomic_get(
  value0 : @lib.AtomicOrder,
  value1 : @lib.TypeIdx,
  value2 : @lib.U32,
) -> @lib.Instruction {
  @lib.Instruction::struct_atomic_get(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_struct_atomic_get_s(
  value0 : @lib.AtomicOrder,
  value1 : @lib.TypeIdx,
  value2 : @lib.U32,
) -> @lib.Instruction {
  @lib.Instruction::struct_atomic_get_s(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_struct_atomic_get_u(
  value0 : @lib.AtomicOrder,
  value1 : @lib.TypeIdx,
  value2 : @lib.U32,
) -> @lib.Instruction {
  @lib.Instruction::struct_atomic_get_u(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_struct_atomic_rmw(
  value0 : @lib.AggregateAtomicRmwOp,
  value1 : @lib.TypeIdx,
  value2 : @lib.U32,
  order : @lib.AtomicOrder?,
) -> @lib.Instruction {
  @lib.Instruction::struct_atomic_rmw(value0, value1, value2, order?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_struct_atomic_set(
  value0 : @lib.AtomicOrder,
  value1 : @lib.TypeIdx,
  value2 : @lib.U32,
) -> @lib.Instruction {
  @lib.Instruction::struct_atomic_set(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_struct_get(
  value0 : @lib.TypeIdx,
  value1 : @lib.U32,
) -> @lib.Instruction {
  @lib.Instruction::struct_get(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_struct_get_s(
  value0 : @lib.TypeIdx,
  value1 : @lib.U32,
) -> @lib.Instruction {
  @lib.Instruction::struct_get_s(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_struct_get_u(
  value0 : @lib.TypeIdx,
  value1 : @lib.U32,
) -> @lib.Instruction {
  @lib.Instruction::struct_get_u(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_struct_new(
  value0 : @lib.TypeIdx,
) -> @lib.Instruction {
  @lib.Instruction::struct_new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_struct_new_default(
  value0 : @lib.TypeIdx,
) -> @lib.Instruction {
  @lib.Instruction::struct_new_default(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_struct_new_default_desc(
  value0 : @lib.TypeIdx,
) -> @lib.Instruction {
  @lib.Instruction::struct_new_default_desc(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_struct_new_desc(
  value0 : @lib.TypeIdx,
) -> @lib.Instruction {
  @lib.Instruction::struct_new_desc(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_struct_set(
  value0 : @lib.TypeIdx,
  value1 : @lib.U32,
) -> @lib.Instruction {
  @lib.Instruction::struct_set(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_struct_wait(
  value0 : @lib.TypeIdx,
  value1 : @lib.U32,
) -> @lib.Instruction {
  @lib.Instruction::struct_wait(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_suspend(value0 : @lib.TagIdx) -> @lib.Instruction {
  @lib.Instruction::suspend(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_table_copy(
  value0 : @lib.TableIdx,
  value1 : @lib.TableIdx,
) -> @lib.Instruction {
  @lib.Instruction::table_copy(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_table_fill(
  value0 : @lib.TableIdx,
) -> @lib.Instruction {
  @lib.Instruction::table_fill(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_table_get(
  value0 : @lib.TableIdx,
) -> @lib.Instruction {
  @lib.Instruction::table_get(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_table_grow(
  value0 : @lib.TableIdx,
) -> @lib.Instruction {
  @lib.Instruction::table_grow(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_table_init(
  value0 : @lib.ElemIdx,
  value1 : @lib.TableIdx,
) -> @lib.Instruction {
  @lib.Instruction::table_init(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_table_set(
  value0 : @lib.TableIdx,
) -> @lib.Instruction {
  @lib.Instruction::table_set(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_table_size(
  value0 : @lib.TableIdx,
) -> @lib.Instruction {
  @lib.Instruction::table_size(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_throw_(value0 : @lib.TagIdx) -> @lib.Instruction {
  @lib.Instruction::throw_(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_throw_ref() -> @lib.Instruction {
  @lib.Instruction::throw_ref()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_try_(
  value0 : @lib.BlockType,
  value1 : @lib.Expr,
  value2 : Array[@lib.LegacyCatch],
  delegate : @lib.LabelIdx??,
) -> @lib.Instruction {
  @lib.Instruction::try_(value0, value1, value2, delegate?)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_try_table(
  value0 : @lib.BlockType,
  value1 : Array[@lib.Catch],
  value2 : @lib.Expr,
) -> @lib.Instruction {
  @lib.Instruction::try_table(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_unreachable_() -> @lib.Instruction {
  @lib.Instruction::unreachable_()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_and() -> @lib.Instruction {
  @lib.Instruction::v128_and()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_andnot() -> @lib.Instruction {
  @lib.Instruction::v128_andnot()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_any_true() -> @lib.Instruction {
  @lib.Instruction::v128_any_true()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_bitselect() -> @lib.Instruction {
  @lib.Instruction::v128_bitselect()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_const(
  value0 : Byte,
  value1 : Byte,
  value2 : Byte,
  value3 : Byte,
  value4 : Byte,
  value5 : Byte,
  value6 : Byte,
  value7 : Byte,
  value8 : Byte,
  value9 : Byte,
  value10 : Byte,
  value11 : Byte,
  value12 : Byte,
  value13 : Byte,
  value14 : Byte,
  value15 : Byte,
) -> @lib.Instruction {
  @lib.Instruction::v128_const(
    value0, value1, value2, value3, value4, value5, value6, value7, value8, value9,
    value10, value11, value12, value13, value14, value15,
  )
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_load(value0 : @lib.MemArg) -> @lib.Instruction {
  @lib.Instruction::v128_load(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_load16_lane(
  value0 : @lib.MemArg,
  value1 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::v128_load16_lane(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_load16_splat(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::v128_load16_splat(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_load16x4s(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::v128_load16x4s(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_load16x4u(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::v128_load16x4u(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_load32_lane(
  value0 : @lib.MemArg,
  value1 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::v128_load32_lane(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_load32_splat(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::v128_load32_splat(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_load32_zero(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::v128_load32_zero(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_load32x2s(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::v128_load32x2s(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_load32x2u(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::v128_load32x2u(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_load64_lane(
  value0 : @lib.MemArg,
  value1 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::v128_load64_lane(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_load64_splat(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::v128_load64_splat(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_load64_zero(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::v128_load64_zero(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_load8_lane(
  value0 : @lib.MemArg,
  value1 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::v128_load8_lane(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_load8_splat(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::v128_load8_splat(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_load8x8s(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::v128_load8x8s(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_load8x8u(
  value0 : @lib.MemArg,
) -> @lib.Instruction {
  @lib.Instruction::v128_load8x8u(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_not() -> @lib.Instruction {
  @lib.Instruction::v128_not()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_or() -> @lib.Instruction {
  @lib.Instruction::v128_or()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_store(value0 : @lib.MemArg) -> @lib.Instruction {
  @lib.Instruction::v128_store(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_store16_lane(
  value0 : @lib.MemArg,
  value1 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::v128_store16_lane(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_store32_lane(
  value0 : @lib.MemArg,
  value1 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::v128_store32_lane(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_store64_lane(
  value0 : @lib.MemArg,
  value1 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::v128_store64_lane(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_store8_lane(
  value0 : @lib.MemArg,
  value1 : @lib.LaneIdx,
) -> @lib.Instruction {
  @lib.Instruction::v128_store8_lane(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_v128_xor() -> @lib.Instruction {
  @lib.Instruction::v128_xor()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_waitqueue_new() -> @lib.Instruction {
  @lib.Instruction::waitqueue_new()
}

///|
#doc(hidden)
pub fn ffi_lib_Instruction_waitqueue_notify() -> @lib.Instruction {
  @lib.Instruction::waitqueue_notify()
}

///|
#doc(hidden)
pub fn ffi_lib_LabelIdx_new(value0 : UInt) -> @lib.LabelIdx {
  @lib.LabelIdx::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_LaneIdx_new(value0 : Byte) -> @lib.LaneIdx {
  @lib.LaneIdx::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_LegacyCatch_all(value0 : @lib.Expr) -> @lib.LegacyCatch {
  @lib.LegacyCatch::all(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_LegacyCatch_tagged(
  value0 : @lib.TagIdx,
  value1 : @lib.Expr,
) -> @lib.LegacyCatch {
  @lib.LegacyCatch::tagged(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Limits_addr_valtype(receiver : @lib.Limits) -> @lib.ValType {
  @lib.Limits::addr_valtype(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_Limits_i32(value0 : UInt, value1 : UInt?) -> @lib.Limits {
  @lib.Limits::i32(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Limits_i64(value0 : UInt64, value1 : UInt64?) -> @lib.Limits {
  @lib.Limits::i64(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Limits_mem_addr_bits(receiver : @lib.Limits) -> Int {
  @lib.Limits::mem_addr_bits(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_f32_load() -> @lib.LoadOp {
  @lib.LoadOp::f32_load()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_f64_load() -> @lib.LoadOp {
  @lib.LoadOp::f64_load()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_i32_atomic_load() -> @lib.LoadOp {
  @lib.LoadOp::i32_atomic_load()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_i32_atomic_load16_u() -> @lib.LoadOp {
  @lib.LoadOp::i32_atomic_load16_u()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_i32_atomic_load8_u() -> @lib.LoadOp {
  @lib.LoadOp::i32_atomic_load8_u()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_i32_load() -> @lib.LoadOp {
  @lib.LoadOp::i32_load()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_i32_load16s() -> @lib.LoadOp {
  @lib.LoadOp::i32_load16s()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_i32_load16u() -> @lib.LoadOp {
  @lib.LoadOp::i32_load16u()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_i32_load8s() -> @lib.LoadOp {
  @lib.LoadOp::i32_load8s()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_i32_load8u() -> @lib.LoadOp {
  @lib.LoadOp::i32_load8u()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_i64_atomic_load() -> @lib.LoadOp {
  @lib.LoadOp::i64_atomic_load()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_i64_atomic_load16_u() -> @lib.LoadOp {
  @lib.LoadOp::i64_atomic_load16_u()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_i64_atomic_load32_u() -> @lib.LoadOp {
  @lib.LoadOp::i64_atomic_load32_u()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_i64_atomic_load8_u() -> @lib.LoadOp {
  @lib.LoadOp::i64_atomic_load8_u()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_i64_load() -> @lib.LoadOp {
  @lib.LoadOp::i64_load()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_i64_load16s() -> @lib.LoadOp {
  @lib.LoadOp::i64_load16s()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_i64_load16u() -> @lib.LoadOp {
  @lib.LoadOp::i64_load16u()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_i64_load32s() -> @lib.LoadOp {
  @lib.LoadOp::i64_load32s()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_i64_load32u() -> @lib.LoadOp {
  @lib.LoadOp::i64_load32u()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_i64_load8s() -> @lib.LoadOp {
  @lib.LoadOp::i64_load8s()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_i64_load8u() -> @lib.LoadOp {
  @lib.LoadOp::i64_load8u()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_v128_load() -> @lib.LoadOp {
  @lib.LoadOp::v128_load()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_v128_load16_splat() -> @lib.LoadOp {
  @lib.LoadOp::v128_load16_splat()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_v128_load16x4s() -> @lib.LoadOp {
  @lib.LoadOp::v128_load16x4s()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_v128_load16x4u() -> @lib.LoadOp {
  @lib.LoadOp::v128_load16x4u()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_v128_load32_splat() -> @lib.LoadOp {
  @lib.LoadOp::v128_load32_splat()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_v128_load32_zero() -> @lib.LoadOp {
  @lib.LoadOp::v128_load32_zero()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_v128_load32x2s() -> @lib.LoadOp {
  @lib.LoadOp::v128_load32x2s()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_v128_load32x2u() -> @lib.LoadOp {
  @lib.LoadOp::v128_load32x2u()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_v128_load64_splat() -> @lib.LoadOp {
  @lib.LoadOp::v128_load64_splat()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_v128_load64_zero() -> @lib.LoadOp {
  @lib.LoadOp::v128_load64_zero()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_v128_load8_splat() -> @lib.LoadOp {
  @lib.LoadOp::v128_load8_splat()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_v128_load8x8s() -> @lib.LoadOp {
  @lib.LoadOp::v128_load8x8s()
}

///|
#doc(hidden)
pub fn ffi_lib_LoadOp_v128_load8x8u() -> @lib.LoadOp {
  @lib.LoadOp::v128_load8x8u()
}

///|
#doc(hidden)
pub fn ffi_lib_LocalIdx_new(value0 : UInt) -> @lib.LocalIdx {
  @lib.LocalIdx::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_LocalRun_count(receiver : @lib.LocalRun) -> UInt {
  @lib.LocalRun::count(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_LocalRun_new(
  value0 : UInt,
  value1 : @lib.ValType,
) -> @lib.LocalRun {
  @lib.LocalRun::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_LocalRun_val_type(receiver : @lib.LocalRun) -> @lib.ValType {
  @lib.LocalRun::val_type(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_append(
  receiver : @lib.Locals,
  value1 : @lib.Locals,
) -> Unit {
  @lib.Locals::append(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_append_types(
  receiver : @lib.Locals,
  value1 : Array[@lib.ValType],
) -> Unit {
  @lib.Locals::append_types(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_at(receiver : @lib.Locals, value1 : Int) -> @lib.ValType? {
  @lib.Locals::at(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_copy(receiver : @lib.Locals) -> @lib.Locals {
  @lib.Locals::copy(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_empty() -> @lib.Locals {
  @lib.Locals::empty()
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_ensure_index(receiver : @lib.Locals) -> Array[Int] {
  @lib.Locals::ensure_index(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_from_decl_runs_preserving_groups(
  value0 : Array[@lib.LocalRun],
) -> @lib.Locals {
  @lib.Locals::from_decl_runs_preserving_groups(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_from_types(value0 : Array[@lib.ValType]) -> @lib.Locals {
  @lib.Locals::from_types(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_get(receiver : @lib.Locals, value1 : Int) -> @lib.ValType {
  @lib.Locals::get(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_insert_run(
  receiver : @lib.Locals,
  value1 : Int,
  value2 : @lib.LocalRun,
) -> Unit {
  @lib.Locals::insert_run(receiver, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_invalidate_indices(receiver : @lib.Locals) -> Unit {
  @lib.Locals::invalidate_indices(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_is_empty(receiver : @lib.Locals) -> Bool {
  @lib.Locals::is_empty(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_iter(receiver : @lib.Locals) -> Iter[@lib.ValType] {
  @lib.Locals::iter(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_length(receiver : @lib.Locals) -> Int {
  @lib.Locals::length(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_merge_adjacent_runs(receiver : @lib.Locals) -> Unit {
  @lib.Locals::merge_adjacent_runs(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_new(value0 : Array[@lib.LocalRun]) -> @lib.Locals {
  @lib.Locals::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_push(
  receiver : @lib.Locals,
  value1 : @lib.ValType,
) -> Unit {
  @lib.Locals::push(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_push_run(
  receiver : @lib.Locals,
  value1 : @lib.LocalRun,
) -> Unit {
  @lib.Locals::push_run(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_remove_run(
  receiver : @lib.Locals,
  value1 : Int,
) -> @lib.LocalRun? {
  @lib.Locals::remove_run(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_run_count(receiver : @lib.Locals) -> Int {
  @lib.Locals::run_count(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_runs(receiver : @lib.Locals) -> Array[@lib.LocalRun] {
  @lib.Locals::runs(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_set(
  receiver : @lib.Locals,
  value1 : Int,
  value2 : @lib.ValType,
) -> Bool {
  @lib.Locals::set(receiver, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_set_run_count(
  receiver : @lib.Locals,
  value1 : Int,
  value2 : UInt,
) -> Bool {
  @lib.Locals::set_run_count(receiver, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_single(
  value0 : UInt,
  value1 : @lib.ValType,
) -> @lib.Locals {
  @lib.Locals::single(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_unsafe_get(
  receiver : @lib.Locals,
  value1 : Int,
) -> @lib.ValType {
  @lib.Locals::unsafe_get(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Locals_without_prefix(
  receiver : @lib.Locals,
  value1 : Int,
) -> @lib.Locals {
  @lib.Locals::without_prefix(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_MemArg_new(
  value0 : @lib.U32,
  value1 : @lib.MemIdx?,
  value2 : @lib.U64,
) -> @lib.MemArg {
  @lib.MemArg::new(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_lib_MemIdx_new(value0 : UInt) -> @lib.MemIdx {
  @lib.MemIdx::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_MemSec_new(value0 : Array[@lib.MemType]) -> @lib.MemSec {
  @lib.MemSec::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_MemType_new(
  value0 : @lib.Limits,
  shared : Bool?,
) -> @lib.MemType {
  @lib.MemType::new(value0, shared?)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_new(
  custom_secs : Array[@lib.CustomSec]?,
  type_sec : @lib.TypeSec??,
  import_sec : @lib.ImportSec??,
  func_annotation_sec : @lib.FuncAnnotationSec??,
  func_sec : @lib.FuncSec??,
  table_sec : @lib.TableSec??,
  mem_sec : @lib.MemSec??,
  tag_sec : @lib.TagSec??,
  stringrefs_sec : @lib.StringRefsSec??,
  global_sec : @lib.GlobalSec??,
  export_sec : @lib.ExportSec??,
  start_sec : @lib.StartSec??,
  elem_sec : @lib.ElemSec??,
  data_cnt_sec : @lib.DataCntSec??,
  code_sec : @lib.CodeSec??,
  data_sec : @lib.DataSec??,
  name_sec : @lib.NameSec??,
  raw_name_sec_payload : Bytes??,
  compiler_fact_custom_section : @representation.CompilerFactCustomSection??,
) -> @lib.Module {
  @lib.Module::new(
    custom_secs?,
    type_sec?,
    import_sec?,
    func_annotation_sec?,
    func_sec?,
    table_sec?,
    mem_sec?,
    tag_sec?,
    stringrefs_sec?,
    global_sec?,
    export_sec?,
    start_sec?,
    elem_sec?,
    data_cnt_sec?,
    code_sec?,
    data_sec?,
    name_sec?,
    raw_name_sec_payload?,
    compiler_fact_custom_section?,
  )
}

///|
#doc(hidden)
pub fn ffi_lib_Module_pretty_print_defined_func(
  receiver : @lib.Module,
  value1 : UInt,
) -> String {
  @lib.Module::pretty_print_defined_func(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_pretty_print_func(
  receiver : @lib.Module,
  value1 : @lib.FuncIdx,
) -> String {
  @lib.Module::pretty_print_func(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_with_code_sec(
  receiver : @lib.Module,
  value1 : @lib.CodeSec,
) -> @lib.Module {
  @lib.Module::with_code_sec(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_with_compiler_fact_custom_section(
  receiver : @lib.Module,
  value1 : @representation.CompilerFactCustomSection,
) -> @lib.Module {
  @lib.Module::with_compiler_fact_custom_section(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_with_custom_secs(
  receiver : @lib.Module,
  value1 : Array[@lib.CustomSec],
) -> @lib.Module {
  @lib.Module::with_custom_secs(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_with_data_cnt_sec(
  receiver : @lib.Module,
  value1 : @lib.DataCntSec,
) -> @lib.Module {
  @lib.Module::with_data_cnt_sec(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_with_data_sec(
  receiver : @lib.Module,
  value1 : @lib.DataSec,
) -> @lib.Module {
  @lib.Module::with_data_sec(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_with_elem_sec(
  receiver : @lib.Module,
  value1 : @lib.ElemSec,
) -> @lib.Module {
  @lib.Module::with_elem_sec(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_with_export_sec(
  receiver : @lib.Module,
  value1 : @lib.ExportSec,
) -> @lib.Module {
  @lib.Module::with_export_sec(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_with_func_annotation_sec(
  receiver : @lib.Module,
  value1 : @lib.FuncAnnotationSec,
) -> @lib.Module {
  @lib.Module::with_func_annotation_sec(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_with_func_sec(
  receiver : @lib.Module,
  value1 : @lib.FuncSec,
) -> @lib.Module {
  @lib.Module::with_func_sec(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_with_global_sec(
  receiver : @lib.Module,
  value1 : @lib.GlobalSec,
) -> @lib.Module {
  @lib.Module::with_global_sec(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_with_import_sec(
  receiver : @lib.Module,
  value1 : @lib.ImportSec,
) -> @lib.Module {
  @lib.Module::with_import_sec(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_with_mem_sec(
  receiver : @lib.Module,
  value1 : @lib.MemSec,
) -> @lib.Module {
  @lib.Module::with_mem_sec(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_with_name_sec(
  receiver : @lib.Module,
  value1 : @lib.NameSec,
) -> @lib.Module {
  @lib.Module::with_name_sec(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_with_raw_name_sec_payload(
  receiver : @lib.Module,
  value1 : Bytes,
) -> @lib.Module {
  @lib.Module::with_raw_name_sec_payload(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_with_start_sec(
  receiver : @lib.Module,
  value1 : @lib.StartSec,
) -> @lib.Module {
  @lib.Module::with_start_sec(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_with_stringrefs_sec(
  receiver : @lib.Module,
  value1 : @lib.StringRefsSec,
) -> @lib.Module {
  @lib.Module::with_stringrefs_sec(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_with_table_sec(
  receiver : @lib.Module,
  value1 : @lib.TableSec,
) -> @lib.Module {
  @lib.Module::with_table_sec(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_with_tag_sec(
  receiver : @lib.Module,
  value1 : @lib.TagSec,
) -> @lib.Module {
  @lib.Module::with_tag_sec(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_with_type_sec(
  receiver : @lib.Module,
  value1 : @lib.TypeSec,
) -> @lib.Module {
  @lib.Module::with_type_sec(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_without_compiler_fact_custom_section(
  receiver : @lib.Module,
) -> @lib.Module {
  @lib.Module::without_compiler_fact_custom_section(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_Module_without_name_sec(receiver : @lib.Module) -> @lib.Module {
  @lib.Module::without_name_sec(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_Mut_const_() -> @lib.Mut {
  @lib.Mut::const_()
}

///|
#doc(hidden)
pub fn ffi_lib_Mut_var_() -> @lib.Mut {
  @lib.Mut::var_()
}

///|
#doc(hidden)
pub fn ffi_lib_Name_from_string(value0 : String) -> @lib.Name {
  @lib.Name::from_string(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_NameAssoc_new(
  value0 : UInt,
  value1 : @lib.Name,
) -> @lib.NameAssoc {
  @lib.NameAssoc::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_NameMap_new(value0 : Array[@lib.NameAssoc]) -> @lib.NameMap {
  @lib.NameMap::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_NameSec_new(
  module_name : @lib.Name??,
  func_names : @lib.NameMap??,
  local_names : @lib.IndirectNameMap??,
  label_names : @lib.IndirectNameMap??,
  type_names : @lib.NameMap??,
  table_names : @lib.NameMap??,
  memory_names : @lib.NameMap??,
  global_names : @lib.NameMap??,
  elem_names : @lib.NameMap??,
  data_names : @lib.NameMap??,
  field_names : @lib.IndirectNameMap??,
  tag_names : @lib.NameMap??,
) -> @lib.NameSec {
  @lib.NameSec::new(
    module_name?,
    func_names?,
    local_names?,
    label_names?,
    type_names?,
    table_names?,
    memory_names?,
    global_names?,
    elem_names?,
    data_names?,
    field_names?,
    tag_names?,
  )
}

///|
#doc(hidden)
pub fn ffi_lib_NumType_f32() -> @lib.NumType {
  @lib.NumType::f32()
}

///|
#doc(hidden)
pub fn ffi_lib_NumType_f64() -> @lib.NumType {
  @lib.NumType::f64()
}

///|
#doc(hidden)
pub fn ffi_lib_NumType_i32() -> @lib.NumType {
  @lib.NumType::i32()
}

///|
#doc(hidden)
pub fn ffi_lib_NumType_i64() -> @lib.NumType {
  @lib.NumType::i64()
}

///|
#doc(hidden)
pub fn ffi_lib_PackType_i16() -> @lib.PackType {
  @lib.PackType::i16()
}

///|
#doc(hidden)
pub fn ffi_lib_PackType_i8() -> @lib.PackType {
  @lib.PackType::i8()
}

///|
#doc(hidden)
pub fn ffi_lib_PrettyPrintContext_indent(
  receiver : @lib.PrettyPrintContext,
  value1 : UInt,
) -> String {
  @lib.PrettyPrintContext::indent(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_PrettyPrintContext_indent_unit(
  receiver : @lib.PrettyPrintContext,
) -> String {
  @lib.PrettyPrintContext::indent_unit(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_PrettyPrintContext_new(
  max_line_width : UInt?,
  tabs_or_spaces : @lib.TabsOrSpaces?,
  tab_width : UInt?,
  continuation_indent : UInt?,
  source_indent_width : UInt?,
) -> @lib.PrettyPrintContext {
  @lib.PrettyPrintContext::new(
    max_line_width?,
    tabs_or_spaces?,
    tab_width?,
    continuation_indent?,
    source_indent_width?,
  )
}

///|
#doc(hidden)
pub fn ffi_lib_RecType_get_subtype(
  receiver : @lib.RecType,
  value1 : UInt,
) -> @lib.SubType? {
  @lib.RecType::get_subtype(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_RecType_group(value0 : Array[@lib.SubType]) -> @lib.RecType {
  @lib.RecType::group(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_RecType_new(value0 : @lib.SubType) -> @lib.RecType {
  @lib.RecType::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_RefType_abs(value0 : @lib.AbsHeapType) -> @lib.RefType {
  @lib.RefType::abs(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_RefType_get_heap_type(receiver : @lib.RefType) -> @lib.HeapType {
  @lib.RefType::get_heap_type(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_RefType_is_defaultable(receiver : @lib.RefType) -> Bool {
  @lib.RefType::is_defaultable(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_RefType_is_exact(receiver : @lib.RefType) -> Bool {
  @lib.RefType::is_exact(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_RefType_is_non_nullable(receiver : @lib.RefType) -> Bool {
  @lib.RefType::is_non_nullable(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_RefType_is_nullable(receiver : @lib.RefType) -> Bool {
  @lib.RefType::is_nullable(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_RefType_make_nullable(receiver : @lib.RefType) -> @lib.RefType {
  @lib.RefType::make_nullable(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_RefType_new(
  value0 : Bool,
  value1 : @lib.HeapType,
  exact : Bool?,
) -> @lib.RefType {
  @lib.RefType::new(value0, value1, exact?)
}

///|
#doc(hidden)
pub fn ffi_lib_ReplaceLaneOp_f32x4_replace_lane() -> @lib.ReplaceLaneOp {
  @lib.ReplaceLaneOp::f32x4_replace_lane()
}

///|
#doc(hidden)
pub fn ffi_lib_ReplaceLaneOp_f64x2_replace_lane() -> @lib.ReplaceLaneOp {
  @lib.ReplaceLaneOp::f64x2_replace_lane()
}

///|
#doc(hidden)
pub fn ffi_lib_ReplaceLaneOp_i16x8_replace_lane() -> @lib.ReplaceLaneOp {
  @lib.ReplaceLaneOp::i16x8_replace_lane()
}

///|
#doc(hidden)
pub fn ffi_lib_ReplaceLaneOp_i32x4_replace_lane() -> @lib.ReplaceLaneOp {
  @lib.ReplaceLaneOp::i32x4_replace_lane()
}

///|
#doc(hidden)
pub fn ffi_lib_ReplaceLaneOp_i64x2_replace_lane() -> @lib.ReplaceLaneOp {
  @lib.ReplaceLaneOp::i64x2_replace_lane()
}

///|
#doc(hidden)
pub fn ffi_lib_ReplaceLaneOp_i8x16_replace_lane() -> @lib.ReplaceLaneOp {
  @lib.ReplaceLaneOp::i8x16_replace_lane()
}

///|
#doc(hidden)
pub fn ffi_lib_ResumeHandler_on_label(
  value0 : @lib.TagIdx,
  value1 : @lib.LabelIdx,
) -> @lib.ResumeHandler {
  @lib.ResumeHandler::on_label(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_ResumeHandler_on_switch(
  value0 : @lib.TagIdx,
) -> @lib.ResumeHandler {
  @lib.ResumeHandler::on_switch(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_S33_new(value0 : UInt) -> @lib.S33 {
  @lib.S33::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_StartSec_new(value0 : @lib.FuncIdx) -> @lib.StartSec {
  @lib.StartSec::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_StorageType_is_packed(receiver : @lib.StorageType) -> Bool {
  @lib.StorageType::is_packed(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_StorageType_pack_type(
  value0 : @lib.PackType,
) -> @lib.StorageType {
  @lib.StorageType::pack_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_StorageType_unpack(receiver : @lib.StorageType) -> @lib.ValType {
  @lib.StorageType::unpack(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_StorageType_val_type(value0 : @lib.ValType) -> @lib.StorageType {
  @lib.StorageType::val_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_StoreOp_f32_store() -> @lib.StoreOp {
  @lib.StoreOp::f32_store()
}

///|
#doc(hidden)
pub fn ffi_lib_StoreOp_f64_store() -> @lib.StoreOp {
  @lib.StoreOp::f64_store()
}

///|
#doc(hidden)
pub fn ffi_lib_StoreOp_i32_atomic_store() -> @lib.StoreOp {
  @lib.StoreOp::i32_atomic_store()
}

///|
#doc(hidden)
pub fn ffi_lib_StoreOp_i32_atomic_store16() -> @lib.StoreOp {
  @lib.StoreOp::i32_atomic_store16()
}

///|
#doc(hidden)
pub fn ffi_lib_StoreOp_i32_atomic_store8() -> @lib.StoreOp {
  @lib.StoreOp::i32_atomic_store8()
}

///|
#doc(hidden)
pub fn ffi_lib_StoreOp_i32_store() -> @lib.StoreOp {
  @lib.StoreOp::i32_store()
}

///|
#doc(hidden)
pub fn ffi_lib_StoreOp_i32_store16() -> @lib.StoreOp {
  @lib.StoreOp::i32_store16()
}

///|
#doc(hidden)
pub fn ffi_lib_StoreOp_i32_store8() -> @lib.StoreOp {
  @lib.StoreOp::i32_store8()
}

///|
#doc(hidden)
pub fn ffi_lib_StoreOp_i64_atomic_store() -> @lib.StoreOp {
  @lib.StoreOp::i64_atomic_store()
}

///|
#doc(hidden)
pub fn ffi_lib_StoreOp_i64_atomic_store16() -> @lib.StoreOp {
  @lib.StoreOp::i64_atomic_store16()
}

///|
#doc(hidden)
pub fn ffi_lib_StoreOp_i64_atomic_store32() -> @lib.StoreOp {
  @lib.StoreOp::i64_atomic_store32()
}

///|
#doc(hidden)
pub fn ffi_lib_StoreOp_i64_atomic_store8() -> @lib.StoreOp {
  @lib.StoreOp::i64_atomic_store8()
}

///|
#doc(hidden)
pub fn ffi_lib_StoreOp_i64_store() -> @lib.StoreOp {
  @lib.StoreOp::i64_store()
}

///|
#doc(hidden)
pub fn ffi_lib_StoreOp_i64_store16() -> @lib.StoreOp {
  @lib.StoreOp::i64_store16()
}

///|
#doc(hidden)
pub fn ffi_lib_StoreOp_i64_store32() -> @lib.StoreOp {
  @lib.StoreOp::i64_store32()
}

///|
#doc(hidden)
pub fn ffi_lib_StoreOp_i64_store8() -> @lib.StoreOp {
  @lib.StoreOp::i64_store8()
}

///|
#doc(hidden)
pub fn ffi_lib_StoreOp_v128_store() -> @lib.StoreOp {
  @lib.StoreOp::v128_store()
}

///|
#doc(hidden)
pub fn ffi_lib_StringRefsSec_new(value0 : Array[Bytes]) -> @lib.StringRefsSec {
  @lib.StringRefsSec::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_SubType_comp_type(
  value0 : @lib.CompType,
  metadata : @lib.TypeMetadata?,
) -> @lib.SubType {
  @lib.SubType::comp_type(value0, metadata?)
}

///|
#doc(hidden)
pub fn ffi_lib_SubType_describes_type(receiver : @lib.SubType) -> @lib.TypeIdx? {
  @lib.SubType::describes_type(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_SubType_descriptor_type(
  receiver : @lib.SubType,
) -> @lib.TypeIdx? {
  @lib.SubType::descriptor_type(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_SubType_get_comptype(receiver : @lib.SubType) -> @lib.CompType {
  @lib.SubType::get_comptype(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_SubType_metadata(receiver : @lib.SubType) -> @lib.TypeMetadata {
  @lib.SubType::metadata(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_SubType_new(
  value0 : Bool,
  value1 : Array[@lib.TypeIdx],
  value2 : @lib.CompType,
  metadata : @lib.TypeMetadata?,
) -> @lib.SubType {
  @lib.SubType::new(value0, value1, value2, metadata?)
}

///|
#doc(hidden)
pub fn ffi_lib_SubType_super_types(
  receiver : @lib.SubType,
) -> Array[@lib.TypeIdx] {
  @lib.SubType::super_types(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_Table_new(
  value0 : @lib.TableType,
  value1 : @lib.Expr?,
) -> @lib.Table {
  @lib.Table::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_TableIdx_new(value0 : UInt) -> @lib.TableIdx {
  @lib.TableIdx::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_TableSec_new(value0 : Array[@lib.Table]) -> @lib.TableSec {
  @lib.TableSec::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_TableType_new(
  value0 : @lib.RefType,
  value1 : @lib.Limits,
) -> @lib.TableType {
  @lib.TableType::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_TabsOrSpaces_spaces() -> @lib.TabsOrSpaces {
  @lib.TabsOrSpaces::spaces()
}

///|
#doc(hidden)
pub fn ffi_lib_TabsOrSpaces_tabs() -> @lib.TabsOrSpaces {
  @lib.TabsOrSpaces::tabs()
}

///|
#doc(hidden)
pub fn ffi_lib_TagIdx_new(value0 : UInt) -> @lib.TagIdx {
  @lib.TagIdx::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_TagSec_new(value0 : Array[@lib.TagType]) -> @lib.TagSec {
  @lib.TagSec::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_TagType_new(value0 : @lib.TypeIdx) -> @lib.TagType {
  @lib.TagType::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_TypeIdx_new(value0 : UInt) -> @lib.TypeIdx {
  @lib.TypeIdx::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_TypeIdx_rec(value0 : UInt) -> @lib.TypeIdx {
  @lib.TypeIdx::rec(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_TypeMetadata_is_shared(receiver : @lib.TypeMetadata) -> Bool {
  @lib.TypeMetadata::is_shared(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_TypeMetadata_new(
  describes : @lib.TypeIdx??,
  descriptor : @lib.TypeIdx??,
  shared : Bool?,
) -> @lib.TypeMetadata {
  @lib.TypeMetadata::new(describes?, descriptor?, shared?)
}

///|
#doc(hidden)
pub fn ffi_lib_TypeMetadata_with_shared(
  receiver : @lib.TypeMetadata,
  value1 : Bool,
) -> @lib.TypeMetadata {
  @lib.TypeMetadata::with_shared(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_lib_TypeSec_new(value0 : Array[@lib.RecType]) -> @lib.TypeSec {
  @lib.TypeSec::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_U32_new(value0 : UInt) -> @lib.U32 {
  @lib.U32::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_U64_new(value0 : UInt64) -> @lib.U64 {
  @lib.U64::new(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32_abs() -> @lib.UnaryOp {
  @lib.UnaryOp::f32_abs()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32_ceil() -> @lib.UnaryOp {
  @lib.UnaryOp::f32_ceil()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32_convert_i32s() -> @lib.UnaryOp {
  @lib.UnaryOp::f32_convert_i32s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32_convert_i32u() -> @lib.UnaryOp {
  @lib.UnaryOp::f32_convert_i32u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32_convert_i64s() -> @lib.UnaryOp {
  @lib.UnaryOp::f32_convert_i64s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32_convert_i64u() -> @lib.UnaryOp {
  @lib.UnaryOp::f32_convert_i64u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32_demote_f64() -> @lib.UnaryOp {
  @lib.UnaryOp::f32_demote_f64()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32_floor() -> @lib.UnaryOp {
  @lib.UnaryOp::f32_floor()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32_nearest() -> @lib.UnaryOp {
  @lib.UnaryOp::f32_nearest()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32_neg() -> @lib.UnaryOp {
  @lib.UnaryOp::f32_neg()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32_reinterpret_i32() -> @lib.UnaryOp {
  @lib.UnaryOp::f32_reinterpret_i32()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32_sqrt() -> @lib.UnaryOp {
  @lib.UnaryOp::f32_sqrt()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32_trunc() -> @lib.UnaryOp {
  @lib.UnaryOp::f32_trunc()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32x4_abs() -> @lib.UnaryOp {
  @lib.UnaryOp::f32x4_abs()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32x4_ceil() -> @lib.UnaryOp {
  @lib.UnaryOp::f32x4_ceil()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32x4_convert_i32x4s() -> @lib.UnaryOp {
  @lib.UnaryOp::f32x4_convert_i32x4s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32x4_convert_i32x4u() -> @lib.UnaryOp {
  @lib.UnaryOp::f32x4_convert_i32x4u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32x4_demote_f64x2_zero() -> @lib.UnaryOp {
  @lib.UnaryOp::f32x4_demote_f64x2_zero()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32x4_floor() -> @lib.UnaryOp {
  @lib.UnaryOp::f32x4_floor()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32x4_nearest() -> @lib.UnaryOp {
  @lib.UnaryOp::f32x4_nearest()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32x4_neg() -> @lib.UnaryOp {
  @lib.UnaryOp::f32x4_neg()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32x4_sqrt() -> @lib.UnaryOp {
  @lib.UnaryOp::f32x4_sqrt()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f32x4_trunc() -> @lib.UnaryOp {
  @lib.UnaryOp::f32x4_trunc()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64_abs() -> @lib.UnaryOp {
  @lib.UnaryOp::f64_abs()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64_ceil() -> @lib.UnaryOp {
  @lib.UnaryOp::f64_ceil()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64_convert_i32s() -> @lib.UnaryOp {
  @lib.UnaryOp::f64_convert_i32s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64_convert_i32u() -> @lib.UnaryOp {
  @lib.UnaryOp::f64_convert_i32u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64_convert_i64s() -> @lib.UnaryOp {
  @lib.UnaryOp::f64_convert_i64s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64_convert_i64u() -> @lib.UnaryOp {
  @lib.UnaryOp::f64_convert_i64u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64_floor() -> @lib.UnaryOp {
  @lib.UnaryOp::f64_floor()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64_nearest() -> @lib.UnaryOp {
  @lib.UnaryOp::f64_nearest()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64_neg() -> @lib.UnaryOp {
  @lib.UnaryOp::f64_neg()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64_promote_f32() -> @lib.UnaryOp {
  @lib.UnaryOp::f64_promote_f32()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64_reinterpret_i64() -> @lib.UnaryOp {
  @lib.UnaryOp::f64_reinterpret_i64()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64_sqrt() -> @lib.UnaryOp {
  @lib.UnaryOp::f64_sqrt()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64_trunc() -> @lib.UnaryOp {
  @lib.UnaryOp::f64_trunc()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64x2_abs() -> @lib.UnaryOp {
  @lib.UnaryOp::f64x2_abs()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64x2_ceil() -> @lib.UnaryOp {
  @lib.UnaryOp::f64x2_ceil()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64x2_convert_low_i32x4s() -> @lib.UnaryOp {
  @lib.UnaryOp::f64x2_convert_low_i32x4s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64x2_convert_low_i32x4u() -> @lib.UnaryOp {
  @lib.UnaryOp::f64x2_convert_low_i32x4u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64x2_floor() -> @lib.UnaryOp {
  @lib.UnaryOp::f64x2_floor()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64x2_nearest() -> @lib.UnaryOp {
  @lib.UnaryOp::f64x2_nearest()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64x2_neg() -> @lib.UnaryOp {
  @lib.UnaryOp::f64x2_neg()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64x2_promote_low_f32x4() -> @lib.UnaryOp {
  @lib.UnaryOp::f64x2_promote_low_f32x4()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64x2_sqrt() -> @lib.UnaryOp {
  @lib.UnaryOp::f64x2_sqrt()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_f64x2_trunc() -> @lib.UnaryOp {
  @lib.UnaryOp::f64x2_trunc()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i16x8_abs() -> @lib.UnaryOp {
  @lib.UnaryOp::i16x8_abs()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i16x8_all_true() -> @lib.UnaryOp {
  @lib.UnaryOp::i16x8_all_true()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i16x8_bitmask() -> @lib.UnaryOp {
  @lib.UnaryOp::i16x8_bitmask()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i16x8_extadd_pairwise_i8x16s() -> @lib.UnaryOp {
  @lib.UnaryOp::i16x8_extadd_pairwise_i8x16s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i16x8_extadd_pairwise_i8x16u() -> @lib.UnaryOp {
  @lib.UnaryOp::i16x8_extadd_pairwise_i8x16u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i16x8_extend_high_i8x16s() -> @lib.UnaryOp {
  @lib.UnaryOp::i16x8_extend_high_i8x16s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i16x8_extend_high_i8x16u() -> @lib.UnaryOp {
  @lib.UnaryOp::i16x8_extend_high_i8x16u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i16x8_extend_low_i8x16s() -> @lib.UnaryOp {
  @lib.UnaryOp::i16x8_extend_low_i8x16s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i16x8_extend_low_i8x16u() -> @lib.UnaryOp {
  @lib.UnaryOp::i16x8_extend_low_i8x16u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i16x8_neg() -> @lib.UnaryOp {
  @lib.UnaryOp::i16x8_neg()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32_clz() -> @lib.UnaryOp {
  @lib.UnaryOp::i32_clz()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32_ctz() -> @lib.UnaryOp {
  @lib.UnaryOp::i32_ctz()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32_eqz() -> @lib.UnaryOp {
  @lib.UnaryOp::i32_eqz()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32_extend16s() -> @lib.UnaryOp {
  @lib.UnaryOp::i32_extend16s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32_extend8s() -> @lib.UnaryOp {
  @lib.UnaryOp::i32_extend8s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32_popcnt() -> @lib.UnaryOp {
  @lib.UnaryOp::i32_popcnt()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32_reinterpret_f32() -> @lib.UnaryOp {
  @lib.UnaryOp::i32_reinterpret_f32()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32_trunc_f32s() -> @lib.UnaryOp {
  @lib.UnaryOp::i32_trunc_f32s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32_trunc_f32u() -> @lib.UnaryOp {
  @lib.UnaryOp::i32_trunc_f32u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32_trunc_f64s() -> @lib.UnaryOp {
  @lib.UnaryOp::i32_trunc_f64s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32_trunc_f64u() -> @lib.UnaryOp {
  @lib.UnaryOp::i32_trunc_f64u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32_trunc_sat_f32s() -> @lib.UnaryOp {
  @lib.UnaryOp::i32_trunc_sat_f32s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32_trunc_sat_f32u() -> @lib.UnaryOp {
  @lib.UnaryOp::i32_trunc_sat_f32u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32_trunc_sat_f64s() -> @lib.UnaryOp {
  @lib.UnaryOp::i32_trunc_sat_f64s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32_trunc_sat_f64u() -> @lib.UnaryOp {
  @lib.UnaryOp::i32_trunc_sat_f64u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32_wrap_i64() -> @lib.UnaryOp {
  @lib.UnaryOp::i32_wrap_i64()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32x4_abs() -> @lib.UnaryOp {
  @lib.UnaryOp::i32x4_abs()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32x4_all_true() -> @lib.UnaryOp {
  @lib.UnaryOp::i32x4_all_true()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32x4_bitmask() -> @lib.UnaryOp {
  @lib.UnaryOp::i32x4_bitmask()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32x4_extadd_pairwise_i16x8s() -> @lib.UnaryOp {
  @lib.UnaryOp::i32x4_extadd_pairwise_i16x8s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32x4_extadd_pairwise_i16x8u() -> @lib.UnaryOp {
  @lib.UnaryOp::i32x4_extadd_pairwise_i16x8u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32x4_extend_high_i16x8s() -> @lib.UnaryOp {
  @lib.UnaryOp::i32x4_extend_high_i16x8s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32x4_extend_high_i16x8u() -> @lib.UnaryOp {
  @lib.UnaryOp::i32x4_extend_high_i16x8u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32x4_extend_low_i16x8s() -> @lib.UnaryOp {
  @lib.UnaryOp::i32x4_extend_low_i16x8s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32x4_extend_low_i16x8u() -> @lib.UnaryOp {
  @lib.UnaryOp::i32x4_extend_low_i16x8u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32x4_neg() -> @lib.UnaryOp {
  @lib.UnaryOp::i32x4_neg()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32x4_relaxed_trunc_f32x4s() -> @lib.UnaryOp {
  @lib.UnaryOp::i32x4_relaxed_trunc_f32x4s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32x4_relaxed_trunc_f32x4u() -> @lib.UnaryOp {
  @lib.UnaryOp::i32x4_relaxed_trunc_f32x4u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32x4_relaxed_trunc_zero_f64x2s() -> @lib.UnaryOp {
  @lib.UnaryOp::i32x4_relaxed_trunc_zero_f64x2s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32x4_relaxed_trunc_zero_f64x2u() -> @lib.UnaryOp {
  @lib.UnaryOp::i32x4_relaxed_trunc_zero_f64x2u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32x4_trunc_sat_f32x4s() -> @lib.UnaryOp {
  @lib.UnaryOp::i32x4_trunc_sat_f32x4s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32x4_trunc_sat_f32x4u() -> @lib.UnaryOp {
  @lib.UnaryOp::i32x4_trunc_sat_f32x4u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32x4_trunc_sat_f64x2s_zero() -> @lib.UnaryOp {
  @lib.UnaryOp::i32x4_trunc_sat_f64x2s_zero()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i32x4_trunc_sat_f64x2u_zero() -> @lib.UnaryOp {
  @lib.UnaryOp::i32x4_trunc_sat_f64x2u_zero()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64_clz() -> @lib.UnaryOp {
  @lib.UnaryOp::i64_clz()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64_ctz() -> @lib.UnaryOp {
  @lib.UnaryOp::i64_ctz()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64_eqz() -> @lib.UnaryOp {
  @lib.UnaryOp::i64_eqz()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64_extend16s() -> @lib.UnaryOp {
  @lib.UnaryOp::i64_extend16s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64_extend32s() -> @lib.UnaryOp {
  @lib.UnaryOp::i64_extend32s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64_extend8s() -> @lib.UnaryOp {
  @lib.UnaryOp::i64_extend8s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64_extend_i32s() -> @lib.UnaryOp {
  @lib.UnaryOp::i64_extend_i32s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64_extend_i32u() -> @lib.UnaryOp {
  @lib.UnaryOp::i64_extend_i32u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64_popcnt() -> @lib.UnaryOp {
  @lib.UnaryOp::i64_popcnt()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64_reinterpret_f64() -> @lib.UnaryOp {
  @lib.UnaryOp::i64_reinterpret_f64()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64_trunc_f32s() -> @lib.UnaryOp {
  @lib.UnaryOp::i64_trunc_f32s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64_trunc_f32u() -> @lib.UnaryOp {
  @lib.UnaryOp::i64_trunc_f32u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64_trunc_f64s() -> @lib.UnaryOp {
  @lib.UnaryOp::i64_trunc_f64s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64_trunc_f64u() -> @lib.UnaryOp {
  @lib.UnaryOp::i64_trunc_f64u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64_trunc_sat_f32s() -> @lib.UnaryOp {
  @lib.UnaryOp::i64_trunc_sat_f32s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64_trunc_sat_f32u() -> @lib.UnaryOp {
  @lib.UnaryOp::i64_trunc_sat_f32u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64_trunc_sat_f64s() -> @lib.UnaryOp {
  @lib.UnaryOp::i64_trunc_sat_f64s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64_trunc_sat_f64u() -> @lib.UnaryOp {
  @lib.UnaryOp::i64_trunc_sat_f64u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64x2_abs() -> @lib.UnaryOp {
  @lib.UnaryOp::i64x2_abs()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64x2_all_true() -> @lib.UnaryOp {
  @lib.UnaryOp::i64x2_all_true()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64x2_bitmask() -> @lib.UnaryOp {
  @lib.UnaryOp::i64x2_bitmask()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64x2_extend_high_i32x4s() -> @lib.UnaryOp {
  @lib.UnaryOp::i64x2_extend_high_i32x4s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64x2_extend_high_i32x4u() -> @lib.UnaryOp {
  @lib.UnaryOp::i64x2_extend_high_i32x4u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64x2_extend_low_i32x4s() -> @lib.UnaryOp {
  @lib.UnaryOp::i64x2_extend_low_i32x4s()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64x2_extend_low_i32x4u() -> @lib.UnaryOp {
  @lib.UnaryOp::i64x2_extend_low_i32x4u()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i64x2_neg() -> @lib.UnaryOp {
  @lib.UnaryOp::i64x2_neg()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i8x16_abs() -> @lib.UnaryOp {
  @lib.UnaryOp::i8x16_abs()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i8x16_all_true() -> @lib.UnaryOp {
  @lib.UnaryOp::i8x16_all_true()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i8x16_bitmask() -> @lib.UnaryOp {
  @lib.UnaryOp::i8x16_bitmask()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i8x16_neg() -> @lib.UnaryOp {
  @lib.UnaryOp::i8x16_neg()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_i8x16_popcnt() -> @lib.UnaryOp {
  @lib.UnaryOp::i8x16_popcnt()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_v128_any_true() -> @lib.UnaryOp {
  @lib.UnaryOp::v128_any_true()
}

///|
#doc(hidden)
pub fn ffi_lib_UnaryOp_v128_not() -> @lib.UnaryOp {
  @lib.UnaryOp::v128_not()
}

///|
#doc(hidden)
pub fn ffi_lib_V128LoadLaneOp_v128_load16_lane() -> @lib.V128LoadLaneOp {
  @lib.V128LoadLaneOp::v128_load16_lane()
}

///|
#doc(hidden)
pub fn ffi_lib_V128LoadLaneOp_v128_load32_lane() -> @lib.V128LoadLaneOp {
  @lib.V128LoadLaneOp::v128_load32_lane()
}

///|
#doc(hidden)
pub fn ffi_lib_V128LoadLaneOp_v128_load64_lane() -> @lib.V128LoadLaneOp {
  @lib.V128LoadLaneOp::v128_load64_lane()
}

///|
#doc(hidden)
pub fn ffi_lib_V128LoadLaneOp_v128_load8_lane() -> @lib.V128LoadLaneOp {
  @lib.V128LoadLaneOp::v128_load8_lane()
}

///|
#doc(hidden)
pub fn ffi_lib_V128ShiftOp_i16x8_shl() -> @lib.V128ShiftOp {
  @lib.V128ShiftOp::i16x8_shl()
}

///|
#doc(hidden)
pub fn ffi_lib_V128ShiftOp_i16x8_shr_s() -> @lib.V128ShiftOp {
  @lib.V128ShiftOp::i16x8_shr_s()
}

///|
#doc(hidden)
pub fn ffi_lib_V128ShiftOp_i16x8_shr_u() -> @lib.V128ShiftOp {
  @lib.V128ShiftOp::i16x8_shr_u()
}

///|
#doc(hidden)
pub fn ffi_lib_V128ShiftOp_i32x4_shl() -> @lib.V128ShiftOp {
  @lib.V128ShiftOp::i32x4_shl()
}

///|
#doc(hidden)
pub fn ffi_lib_V128ShiftOp_i32x4_shr_s() -> @lib.V128ShiftOp {
  @lib.V128ShiftOp::i32x4_shr_s()
}

///|
#doc(hidden)
pub fn ffi_lib_V128ShiftOp_i32x4_shr_u() -> @lib.V128ShiftOp {
  @lib.V128ShiftOp::i32x4_shr_u()
}

///|
#doc(hidden)
pub fn ffi_lib_V128ShiftOp_i64x2_shl() -> @lib.V128ShiftOp {
  @lib.V128ShiftOp::i64x2_shl()
}

///|
#doc(hidden)
pub fn ffi_lib_V128ShiftOp_i64x2_shr_s() -> @lib.V128ShiftOp {
  @lib.V128ShiftOp::i64x2_shr_s()
}

///|
#doc(hidden)
pub fn ffi_lib_V128ShiftOp_i64x2_shr_u() -> @lib.V128ShiftOp {
  @lib.V128ShiftOp::i64x2_shr_u()
}

///|
#doc(hidden)
pub fn ffi_lib_V128ShiftOp_i8x16_shl() -> @lib.V128ShiftOp {
  @lib.V128ShiftOp::i8x16_shl()
}

///|
#doc(hidden)
pub fn ffi_lib_V128ShiftOp_i8x16_shr_s() -> @lib.V128ShiftOp {
  @lib.V128ShiftOp::i8x16_shr_s()
}

///|
#doc(hidden)
pub fn ffi_lib_V128ShiftOp_i8x16_shr_u() -> @lib.V128ShiftOp {
  @lib.V128ShiftOp::i8x16_shr_u()
}

///|
#doc(hidden)
pub fn ffi_lib_V128StoreLaneOp_v128_store16_lane() -> @lib.V128StoreLaneOp {
  @lib.V128StoreLaneOp::v128_store16_lane()
}

///|
#doc(hidden)
pub fn ffi_lib_V128StoreLaneOp_v128_store32_lane() -> @lib.V128StoreLaneOp {
  @lib.V128StoreLaneOp::v128_store32_lane()
}

///|
#doc(hidden)
pub fn ffi_lib_V128StoreLaneOp_v128_store64_lane() -> @lib.V128StoreLaneOp {
  @lib.V128StoreLaneOp::v128_store64_lane()
}

///|
#doc(hidden)
pub fn ffi_lib_V128StoreLaneOp_v128_store8_lane() -> @lib.V128StoreLaneOp {
  @lib.V128StoreLaneOp::v128_store8_lane()
}

///|
#doc(hidden)
pub fn ffi_lib_V128TernaryOp_f32x4_relaxed_madd() -> @lib.V128TernaryOp {
  @lib.V128TernaryOp::f32x4_relaxed_madd()
}

///|
#doc(hidden)
pub fn ffi_lib_V128TernaryOp_f32x4_relaxed_nmadd() -> @lib.V128TernaryOp {
  @lib.V128TernaryOp::f32x4_relaxed_nmadd()
}

///|
#doc(hidden)
pub fn ffi_lib_V128TernaryOp_f64x2_relaxed_madd() -> @lib.V128TernaryOp {
  @lib.V128TernaryOp::f64x2_relaxed_madd()
}

///|
#doc(hidden)
pub fn ffi_lib_V128TernaryOp_f64x2_relaxed_nmadd() -> @lib.V128TernaryOp {
  @lib.V128TernaryOp::f64x2_relaxed_nmadd()
}

///|
#doc(hidden)
pub fn ffi_lib_V128TernaryOp_i16x8_relaxed_laneselect() -> @lib.V128TernaryOp {
  @lib.V128TernaryOp::i16x8_relaxed_laneselect()
}

///|
#doc(hidden)
pub fn ffi_lib_V128TernaryOp_i32x4_relaxed_dot_i8x16i7x16_add_s() -> @lib.V128TernaryOp {
  @lib.V128TernaryOp::i32x4_relaxed_dot_i8x16i7x16_add_s()
}

///|
#doc(hidden)
pub fn ffi_lib_V128TernaryOp_i32x4_relaxed_laneselect() -> @lib.V128TernaryOp {
  @lib.V128TernaryOp::i32x4_relaxed_laneselect()
}

///|
#doc(hidden)
pub fn ffi_lib_V128TernaryOp_i64x2_relaxed_laneselect() -> @lib.V128TernaryOp {
  @lib.V128TernaryOp::i64x2_relaxed_laneselect()
}

///|
#doc(hidden)
pub fn ffi_lib_V128TernaryOp_i8x16_relaxed_laneselect() -> @lib.V128TernaryOp {
  @lib.V128TernaryOp::i8x16_relaxed_laneselect()
}

///|
#doc(hidden)
pub fn ffi_lib_V128TernaryOp_v128_bitselect() -> @lib.V128TernaryOp {
  @lib.V128TernaryOp::v128_bitselect()
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_anyref() -> @lib.ValType {
  @lib.ValType::anyref()
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_bottom() -> @lib.ValType {
  @lib.ValType::bottom()
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_eqref_null() -> @lib.ValType {
  @lib.ValType::eqref_null()
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_externref() -> @lib.ValType {
  @lib.ValType::externref()
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_f32() -> @lib.ValType {
  @lib.ValType::f32()
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_f64() -> @lib.ValType {
  @lib.ValType::f64()
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_funcref() -> @lib.ValType {
  @lib.ValType::funcref()
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_i31ref() -> @lib.ValType {
  @lib.ValType::i31ref()
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_i31ref_nullable() -> @lib.ValType {
  @lib.ValType::i31ref_nullable()
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_i32() -> @lib.ValType {
  @lib.ValType::i32()
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_i64() -> @lib.ValType {
  @lib.ValType::i64()
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_is_ref_type(receiver : @lib.ValType) -> Bool {
  @lib.ValType::is_ref_type(receiver)
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_num_type(value0 : @lib.NumType) -> @lib.ValType {
  @lib.ValType::num_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_ref_array_nonnull(value0 : @lib.TypeIdx) -> @lib.ValType {
  @lib.ValType::ref_array_nonnull(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_ref_array_nullable(
  value0 : @lib.TypeIdx,
) -> @lib.ValType {
  @lib.ValType::ref_array_nullable(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_ref_null(value0 : @lib.HeapType) -> @lib.ValType {
  @lib.ValType::ref_null(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_ref_null_array_of(value0 : @lib.TypeIdx) -> @lib.ValType {
  @lib.ValType::ref_null_array_of(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_ref_null_exn() -> @lib.ValType {
  @lib.ValType::ref_null_exn()
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_ref_null_type(value0 : @lib.RefType) -> @lib.ValType {
  @lib.ValType::ref_null_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_ref_type(value0 : @lib.RefType) -> @lib.ValType {
  @lib.ValType::ref_type(value0)
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_stringref() -> @lib.ValType {
  @lib.ValType::stringref()
}

///|
#doc(hidden)
pub fn ffi_lib_ValType_v128() -> @lib.ValType {
  @lib.ValType::v128()
}

///|
#doc(hidden)
pub fn ffi_validate_apply_validate_invalid_ast_strategy(
  value0 : @validate.ValidateInvalidAstStrategyId,
  value1 : @lib.Module,
) -> Result[@validate.ValidateInvalidAstMutation, String] {
  @validate.apply_validate_invalid_ast_strategy(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_build_validate_invalid_ast_minimal_repro(
  value0 : @validate.ValidateInvalidAstStrategyId,
) -> Result[@lib.Module, String] {
  @validate.build_validate_invalid_ast_minimal_repro(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_build_validate_invalid_ast_minimal_repro_by_stable_id(
  value0 : String,
) -> Result[@lib.Module, String] {
  @validate.build_validate_invalid_ast_minimal_repro_by_stable_id(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_check_validate_valid_feature_floors(
  value0 : @validate.GenValidFeatureStats,
  value1 : Array[@validate.ValidateValidFeatureFloor],
) -> Array[@validate.ValidateValidFeatureFloorFailure] {
  @validate.check_validate_valid_feature_floors(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_controlled_proposal_features() -> Array[
  @validate.ProposalFeature,
] {
  @validate.controlled_proposal_features()
}

///|
#doc(hidden)
pub fn ffi_validate_default_gen_valid_config() -> @validate.GenValidConfig {
  @validate.default_gen_valid_config()
}

///|
#doc(hidden)
pub fn ffi_validate_descriptor_compatible(
  value0 : @lib.RefType,
  value1 : @lib.RefType,
  value2 : @validate.Env,
) -> Bool {
  @validate.descriptor_compatible(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_validate_diff(
  value0 : @lib.RefType,
  value1 : @lib.RefType,
) -> Result[@lib.RefType, String] {
  @validate.diff(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_empty_env() -> @validate.Env {
  @validate.empty_env()
}

///|
#doc(hidden)
pub fn ffi_validate_gen_invalid_ast_generate(
  value0 : @splitmix.RandomState,
  value1 : @validate.GenInvalidAstParams,
) -> Result[@validate.GenInvalidAstGenerated, String] {
  @validate.gen_invalid_ast_generate(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_invalid_ast_generate_from_seed(
  value0 : UInt64,
  value1 : @validate.GenInvalidAstParams,
) -> Result[@validate.GenInvalidAstGenerated, String] {
  @validate.gen_invalid_ast_generate_from_seed(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_invalid_ast_params_profile_name(
  value0 : @validate.GenInvalidAstParams,
) -> String {
  @validate.gen_invalid_ast_params_profile_name(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_invalid_ast_seed_config(
  value0 : @validate.GenInvalidAstParams,
) -> @validate.GenValidConfig {
  @validate.gen_invalid_ast_seed_config(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_invalid_ast_seed_module(
  value0 : @splitmix.RandomState,
  value1 : @validate.GenInvalidAstParams,
) -> Result[@lib.Module, String] {
  @validate.gen_invalid_ast_seed_module(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_invalid_ast_strategy_seed_prerequisites(
  value0 : @validate.ValidateInvalidAstStrategyId,
) -> Array[@validate.ValidateInvalidAstSeedPrerequisite] {
  @validate.gen_invalid_ast_strategy_seed_prerequisites(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_invalid_coverage_seed_generator_config() -> @validate.GenValidConfig {
  @validate.gen_invalid_coverage_seed_generator_config()
}

///|
#doc(hidden)
pub fn ffi_validate_gen_invalid_named_seed_profile_name(
  value0 : @validate.GenInvalidNamedSeedProfile,
) -> String {
  @validate.gen_invalid_named_seed_profile_name(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_invalid_require_defined_func_gen_valid_config(
  value0 : @validate.GenValidConfig,
) -> @validate.GenValidConfig {
  @validate.gen_invalid_require_defined_func_gen_valid_config(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_invalid_require_memory_data_gen_valid_config(
  value0 : @validate.GenValidConfig,
) -> @validate.GenValidConfig {
  @validate.gen_invalid_require_memory_data_gen_valid_config(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_invalid_seed_mode_name(
  value0 : @validate.GenInvalidSeedMode,
) -> String {
  @validate.gen_invalid_seed_mode_name(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_invalid_small_gen_valid_config(
  value0 : @validate.GenValidConfig,
) -> @validate.GenValidConfig {
  @validate.gen_invalid_small_gen_valid_config(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_case_seed(
  value0 : UInt64,
  value1 : Int,
) -> UInt64 {
  @validate.gen_valid_case_seed(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_code_folding_profile_case_label(
  value0 : @validate.GenValidProfile,
  value1 : UInt64,
) -> String? {
  @validate.gen_valid_code_folding_profile_case_label(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_config_label(
  value0 : @validate.GenValidConfig,
) -> String {
  @validate.gen_valid_config_label(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_const_expr_allowed_op_matrix() -> Array[
  @validate.GenValidConstExprAllowedOps,
] {
  @validate.gen_valid_const_expr_allowed_op_matrix()
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_const_expr_observed_op_matrix(
  value0 : @lib.Module,
) -> Array[@validate.GenValidConstExprObservedOps] {
  @validate.gen_valid_const_expr_observed_op_matrix(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_coverage_template_signature(
  value0 : @lib.Module,
) -> String {
  @validate.gen_valid_coverage_template_signature(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_dae_optimizing_profile_case_label(
  value0 : @validate.GenValidProfile,
  value1 : UInt64,
) -> String? {
  @validate.gen_valid_dae_optimizing_profile_case_label(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_dead_argument_elimination_profile_config(
  value0 : @validate.GenValidProfile,
) -> @validate.GenValidConfig {
  @validate.gen_valid_dead_argument_elimination_profile_config(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_derive_stream_seed(
  value0 : UInt64,
  value1 : @validate.GenValidRandomStreamLabel,
) -> UInt64 {
  @validate.gen_valid_derive_stream_seed(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_directize_profile_case_label(
  value0 : @validate.GenValidProfile,
  value1 : UInt64,
) -> String? {
  @validate.gen_valid_directize_profile_case_label(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_duplicate_import_elimination_profile_case_label(
  value0 : @validate.GenValidProfile,
  value1 : UInt64,
) -> String? {
  @validate.gen_valid_duplicate_import_elimination_profile_case_label(
    value0, value1,
  )
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_engine_state_cross_instance_support_module(
  value0 : UInt64,
) -> @lib.Module {
  @validate.gen_valid_engine_state_cross_instance_support_module(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_engine_state_failure_family(
  value0 : @validate.GenValidProfile,
  value1 : UInt64,
) -> String {
  @validate.gen_valid_engine_state_failure_family(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_engine_state_indirect_trap_family(
  value0 : UInt64,
) -> String {
  @validate.gen_valid_engine_state_indirect_trap_family(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_engine_state_instantiation_failure_family(
  value0 : UInt64,
) -> String {
  @validate.gen_valid_engine_state_instantiation_failure_family(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_engine_state_invalid_module_family(
  value0 : UInt64,
) -> String {
  @validate.gen_valid_engine_state_invalid_module_family(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_engine_state_link_graph_support_modules(
  value0 : UInt64,
) -> Array[@lib.Module] {
  @validate.gen_valid_engine_state_link_graph_support_modules(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_engine_state_metamorphic_comparison_module(
  value0 : UInt64,
) -> @lib.Module {
  @validate.gen_valid_engine_state_metamorphic_comparison_module(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_engine_state_outcome(
  value0 : @validate.GenValidProfile,
) -> String {
  @validate.gen_valid_engine_state_outcome(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_engine_state_profile() -> @validate.GenValidProfile {
  @validate.gen_valid_engine_state_profile()
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_engine_state_static_instruction_count(
  value0 : @lib.Module,
) -> Int {
  @validate.gen_valid_engine_state_static_instruction_count(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_engine_state_trap_commit_family(
  value0 : UInt64,
) -> String {
  @validate.gen_valid_engine_state_trap_commit_family(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_engine_state_trap_family(
  value0 : UInt64,
) -> String {
  @validate.gen_valid_engine_state_trap_family(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_engine_tiering_profile_case_label(
  value0 : @validate.GenValidProfile,
  value1 : UInt64,
) -> String? {
  @validate.gen_valid_engine_tiering_profile_case_label(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_feature_facts(
  value0 : @lib.Module,
  value1 : @validate.GenValidMode,
) -> @validate.GenValidFeatureFacts {
  @validate.gen_valid_feature_facts(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_flatten_profile_case_label(
  value0 : @validate.GenValidProfile,
  value1 : UInt64,
) -> String? {
  @validate.gen_valid_flatten_profile_case_label(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_heap_store_optimization_profile_case_label(
  value0 : @validate.GenValidProfile,
) -> String? {
  @validate.gen_valid_heap_store_optimization_profile_case_label(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_inlining_optimizing_profile_case_label(
  value0 : @validate.GenValidProfile,
  value1 : UInt64,
) -> String? {
  @validate.gen_valid_inlining_optimizing_profile_case_label(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_memory_packing_profile_case_label(
  value0 : @validate.GenValidProfile,
) -> String? {
  @validate.gen_valid_memory_packing_profile_case_label(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_merge_blocks_profile_case_label(
  value0 : @validate.GenValidProfile,
  value1 : UInt64,
) -> String? {
  @validate.gen_valid_merge_blocks_profile_case_label(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_merge_locals_profile_case_label(
  value0 : @validate.GenValidProfile,
  value1 : UInt64,
) -> String? {
  @validate.gen_valid_merge_locals_profile_case_label(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_merge_ssa_func_facts(
  value0 : @validate.GenValidSsaFuncFacts,
  value1 : @validate.GenValidSsaFuncFacts,
) -> @validate.GenValidSsaFuncFacts {
  @validate.gen_valid_merge_ssa_func_facts(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_module(
  value0 : @splitmix.RandomState,
) -> @lib.Module {
  @validate.gen_valid_module(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_module_from_seed(
  value0 : UInt64,
  value1 : @validate.GenValidConfig,
) -> Result[@validate.GenValidModuleGenerated, @validate.GenValidFailure] {
  @validate.gen_valid_module_from_seed(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_module_result(
  value0 : @splitmix.RandomState,
  value1 : @validate.GenValidConfig,
) -> Result[@validate.GenValidGenerated, @validate.GenValidFailure] {
  @validate.gen_valid_module_result(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_module_result_from_seed(
  value0 : UInt64,
  value1 : @validate.GenValidConfig,
) -> Result[@validate.GenValidGenerated, @validate.GenValidFailure] {
  @validate.gen_valid_module_result_from_seed(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_module_with_config(
  value0 : @splitmix.RandomState,
  value1 : @validate.GenValidConfig,
) -> @lib.Module {
  @validate.gen_valid_module_with_config(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_msf_profile_case_label(
  value0 : @validate.GenValidProfile,
  value1 : UInt64,
) -> String? {
  @validate.gen_valid_msf_profile_case_label(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_oi_trigger_profile_case_for_seed(
  value0 : UInt64,
) -> Int {
  @validate.gen_valid_oi_trigger_profile_case_for_seed(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_oi_trigger_profile_case_label(
  value0 : @validate.GenValidProfile,
  value1 : UInt64,
) -> String? {
  @validate.gen_valid_oi_trigger_profile_case_label(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_profile_by_name(
  value0 : String,
) -> Result[@validate.GenValidProfile, String] {
  @validate.gen_valid_profile_by_name(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_profile_is_composite(
  value0 : @validate.GenValidProfile,
) -> Bool {
  @validate.gen_valid_profile_is_composite(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_profile_leaf_for_case(
  value0 : @validate.GenValidProfile,
  value1 : UInt64,
  value2 : Int,
) -> @validate.GenValidProfile {
  @validate.gen_valid_profile_leaf_for_case(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_profile_members(
  value0 : @validate.GenValidProfile,
) -> Array[@validate.GenValidProfileMember] {
  @validate.gen_valid_profile_members(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_profile_name(
  value0 : @validate.GenValidProfile,
) -> String {
  @validate.gen_valid_profile_name(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_profile_names() -> Array[String] {
  @validate.gen_valid_profile_names()
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_profiles() -> Array[@validate.GenValidProfile] {
  @validate.gen_valid_profiles()
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_proposal_feature_enabled(
  value0 : @validate.GenValidFeatureToggles,
  value1 : @validate.GenValidProposalFeature,
) -> Bool {
  @validate.gen_valid_proposal_feature_enabled(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_proposal_feature_gate_matrix() -> Array[
  @validate.GenValidProposalFeatureGateRow,
] {
  @validate.gen_valid_proposal_feature_gate_matrix()
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_proposal_feature_label(
  value0 : @validate.GenValidProposalFeature,
) -> String {
  @validate.gen_valid_proposal_feature_label(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_proposal_features() -> Array[
  @validate.GenValidProposalFeature,
] {
  @validate.gen_valid_proposal_features()
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_random_stream_label_name(
  value0 : @validate.GenValidRandomStreamLabel,
) -> String {
  @validate.gen_valid_random_stream_label_name(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_random_stream_labels() -> Array[
  @validate.GenValidRandomStreamLabel,
] {
  @validate.gen_valid_random_stream_labels()
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_reorder_globals_profile_case_label(
  value0 : @validate.GenValidProfile,
  value1 : UInt64,
) -> String? {
  @validate.gen_valid_reorder_globals_profile_case_label(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_rume_profile_case_label(
  value0 : @validate.GenValidProfile,
  value1 : UInt64,
) -> String? {
  @validate.gen_valid_rume_profile_case_label(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_scan_func_ssa_facts(
  value0 : Int,
  value1 : @lib.Locals,
  value2 : @lib.Expr,
) -> @validate.GenValidSsaFuncFacts {
  @validate.gen_valid_scan_func_ssa_facts(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_ssa_full_profile_case_label(
  value0 : @validate.GenValidProfile,
) -> String? {
  @validate.gen_valid_ssa_full_profile_case_label(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_stream_random_state(
  value0 : UInt64,
  value1 : @validate.GenValidRandomStreamLabel,
) -> @splitmix.RandomState {
  @validate.gen_valid_stream_random_state(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_tuple_optimization_trigger_profile_case_label(
  value0 : @validate.GenValidProfile,
  value1 : UInt64,
) -> String? {
  @validate.gen_valid_tuple_optimization_trigger_profile_case_label(
    value0, value1,
  )
}

///|
#doc(hidden)
pub fn ffi_validate_gen_valid_undersampled_pass_profile_case_label(
  value0 : @validate.GenValidProfile,
  value1 : UInt64,
) -> String? {
  @validate.gen_valid_undersampled_pass_profile_case_label(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_make_state(
  value0 : @validate.Env,
  value1 : Array[@lib.ValType],
) -> @validate.TcState {
  @validate.make_state(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_make_state_owned(
  value0 : @validate.Env,
  value1 : Array[@lib.ValType],
) -> @validate.TcState {
  @validate.make_state_owned(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_module_proposal_features(
  value0 : @lib.Module,
) -> Array[@validate.ProposalFeature] {
  @validate.module_proposal_features(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_proposal_feature_by_name(
  value0 : String,
) -> @validate.ProposalFeature? {
  @validate.proposal_feature_by_name(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_proposal_feature_name(
  value0 : @validate.ProposalFeature,
) -> String {
  @validate.proposal_feature_name(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_run_validate_invalid_ast_fuzz(
  value0 : String,
  value1 : UInt64,
) -> Result[@validate.ValidateInvalidAstFuzzStats, String] {
  @validate.run_validate_invalid_ast_fuzz(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_run_validate_valid_fuzz(
  value0 : String,
  value1 : UInt64,
) -> Result[@validate.ValidateValidFuzzStats, String] {
  @validate.run_validate_valid_fuzz(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_tc_escape_none() -> @validate.TcEscape {
  @validate.tc_escape_none()
}

///|
#doc(hidden)
pub fn ffi_validate_tc_escape_terminal() -> @validate.TcEscape {
  @validate.tc_escape_terminal()
}

///|
#doc(hidden)
pub fn ffi_validate_tc_state_clone(
  value0 : @validate.TcState,
) -> @validate.TcState {
  @validate.tc_state_clone(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_tc_state_finish_block(
  value0 : @validate.TcState,
  value1 : @validate.TcState,
  value2 : @validate.TcState,
  value3 : Array[@lib.ValType],
) -> Result[@validate.TcState, String] {
  @validate.tc_state_finish_block(value0, value1, value2, value3)
}

///|
#doc(hidden)
pub fn ffi_validate_tc_state_finish_if(
  value0 : @validate.TcState,
  value1 : @validate.TcState,
  value2 : @validate.TcState,
  value3 : @validate.TcState,
  value4 : Array[@lib.ValType],
) -> Result[@validate.TcState, String] {
  @validate.tc_state_finish_if(value0, value1, value2, value3, value4)
}

///|
#doc(hidden)
pub fn ffi_validate_tc_state_finish_loop(
  value0 : @validate.TcState,
  value1 : @validate.TcState,
  value2 : @validate.TcState,
  value3 : Array[@lib.ValType],
) -> Result[@validate.TcState, String] {
  @validate.tc_state_finish_loop(value0, value1, value2, value3)
}

///|
#doc(hidden)
pub fn ffi_validate_tc_state_finish_try_table(
  value0 : @validate.TcState,
  value1 : @validate.TcState,
  value2 : @validate.TcState,
  value3 : Array[@lib.ValType],
  value4 : Array[@lib.Catch],
) -> Result[@validate.TcState, String] {
  @validate.tc_state_finish_try_table(value0, value1, value2, value3, value4)
}

///|
#doc(hidden)
pub fn ffi_validate_tc_state_fork_body(
  value0 : @validate.TcState,
  value1 : @validate.Env,
  value2 : Array[@lib.ValType],
) -> @validate.TcState {
  @validate.tc_state_fork_body(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_validate_tc_state_merge_nonfallthrough_if_exits(
  value0 : @validate.TcEscape,
  value1 : @validate.TcEscape,
) -> @validate.TcEscape {
  @validate.tc_state_merge_nonfallthrough_if_exits(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_tc_state_new(
  value0 : @validate.Env,
  value1 : Array[@lib.ValType],
  value2 : Bool,
  value3 : @validate.TcEscape,
) -> @validate.TcState {
  @validate.tc_state_new(value0, value1, value2, value3)
}

///|
#doc(hidden)
pub fn ffi_validate_tc_state_normalize_untyped_block_exit(
  value0 : @validate.TcState,
  value1 : Array[@lib.ValType],
) -> Result[(Bool, @validate.TcEscape), String] {
  @validate.tc_state_normalize_untyped_block_exit(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_tc_state_normalize_untyped_if_branch_exit(
  value0 : @validate.TcState,
  value1 : Array[@lib.ValType],
) -> Result[(Bool, @validate.TcEscape), String] {
  @validate.tc_state_normalize_untyped_if_branch_exit(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_tc_state_pop_expect(
  value0 : @validate.TcState,
  value1 : @lib.ValType,
) -> Result[@validate.TcState, String] {
  @validate.tc_state_pop_expect(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_tc_state_pop_types(
  value0 : @validate.TcState,
  value1 : Array[@lib.ValType],
) -> Result[@validate.TcState, String] {
  @validate.tc_state_pop_types(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_tc_state_push_types(
  value0 : @validate.TcState,
  value1 : Array[@lib.ValType],
) -> @validate.TcState {
  @validate.tc_state_push_types(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_tc_state_typecheck_catch_clause(
  value0 : @validate.TcState,
  value1 : @lib.Catch,
) -> Result[Unit, String] {
  @validate.tc_state_typecheck_catch_clause(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_tc_state_validate_end_stack(
  value0 : @validate.TcState,
  value1 : Array[@lib.ValType],
) -> Result[Unit, String] {
  @validate.tc_state_validate_end_stack(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_tc_state_with_owned_stack(
  value0 : @validate.TcState,
  value1 : Array[@lib.ValType],
) -> @validate.TcState {
  @validate.tc_state_with_owned_stack(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_tc_state_with_stack(
  value0 : @validate.TcState,
  value1 : Array[@lib.ValType],
) -> @validate.TcState {
  @validate.tc_state_with_stack(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_typecheck_expr_for_probe(
  value0 : @lib.Expr,
  value1 : @validate.TcState,
) -> Result[@validate.TcState, String] {
  @validate.typecheck_expr_for_probe(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_codesec(
  value0 : @lib.CodeSec?,
  value1 : @lib.FuncSec?,
  value2 : @validate.Env,
) -> Result[Unit, String] {
  @validate.validate_codesec(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_datacnt(
  value0 : @lib.DataCntSec?,
  value1 : @lib.DataSec?,
) -> Result[Unit, String] {
  @validate.validate_datacnt(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_datasec(
  value0 : @lib.DataSec?,
  value1 : @validate.Env,
) -> Result[@validate.Env, String] {
  @validate.validate_datasec(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_defined_func_against_module(
  value0 : @lib.Module,
  value1 : @lib.FuncIdx,
  value2 : @lib.Func,
) -> Result[Unit, String] {
  @validate.validate_defined_func_against_module(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_defined_funcs_against_module(
  value0 : @lib.Module,
  value1 : Array[(@lib.FuncIdx, @lib.Func)],
) -> Result[Array[(@lib.FuncIdx, String)], @validate.ValidationError] {
  @validate.validate_defined_funcs_against_module(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_elemsec(
  value0 : @lib.ElemSec?,
  value1 : @validate.Env,
) -> Result[@validate.Env, String] {
  @validate.validate_elemsec(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_exportsec(
  value0 : @lib.ExportSec?,
  value1 : @validate.Env,
) -> Result[Unit, String] {
  @validate.validate_exportsec(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_func_body_against_functype(
  value0 : @validate.Env,
  value1 : @lib.FuncType,
  value2 : @lib.Func,
) -> Result[Unit, String] {
  @validate.validate_func_body_against_functype(value0, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_funcsec(
  value0 : @lib.FuncSec?,
  value1 : @validate.Env,
) -> Result[@validate.Env, String] {
  @validate.validate_funcsec(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_globalsec(
  value0 : @lib.GlobalSec?,
  value1 : @validate.Env,
) -> Result[@validate.Env, String] {
  @validate.validate_globalsec(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_importsec(
  value0 : @lib.ImportSec?,
  value1 : @validate.Env,
) -> Result[@validate.Env, String] {
  @validate.validate_importsec(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_invalid_ast_attempt_seed_for_profile(
  value0 : UInt64,
  value1 : String,
  value2 : String,
) -> UInt64 {
  @validate.validate_invalid_ast_attempt_seed_for_profile(
    value0, value1, value2,
  )
}

///|
#doc(hidden)
pub fn ffi_validate_validate_invalid_ast_registry() -> Array[
  @validate.ValidateInvalidAstStrategySpec,
] {
  @validate.validate_invalid_ast_registry()
}

///|
#doc(hidden)
pub fn ffi_validate_validate_invalid_ast_run_config(
  value0 : String,
) -> Result[@validate.ValidateInvalidAstRunConfig, String] {
  @validate.validate_invalid_ast_run_config(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_invalid_ast_strategy_by_stable_id(
  value0 : String,
) -> @validate.ValidateInvalidAstStrategySpec? {
  @validate.validate_invalid_ast_strategy_by_stable_id(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_invalid_ast_strategy_spec_by_id(
  value0 : @validate.ValidateInvalidAstStrategyId,
) -> @validate.ValidateInvalidAstStrategySpec? {
  @validate.validate_invalid_ast_strategy_spec_by_id(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_memsec(
  value0 : @lib.MemSec?,
  value1 : @validate.Env,
) -> Result[@validate.Env, String] {
  @validate.validate_memsec(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_module(
  value0 : @lib.Module,
  disabled_features : Array[@validate.ProposalFeature]?,
) -> Result[Unit, @validate.ValidationError] {
  @validate.validate_module(value0, disabled_features?)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_startsec(
  value0 : @lib.StartSec?,
  value1 : @validate.Env,
) -> Result[Unit, String] {
  @validate.validate_startsec(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_tablesec(
  value0 : @lib.TableSec?,
  value1 : @validate.Env,
) -> Result[@validate.Env, String] {
  @validate.validate_tablesec(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_tagsec(
  value0 : @lib.TagSec?,
  value1 : @validate.Env,
) -> Result[@validate.Env, String] {
  @validate.validate_tagsec(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_typesec(
  value0 : @lib.TypeSec?,
  value1 : @validate.Env,
) -> Result[@validate.Env, String] {
  @validate.validate_typesec(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_valid_feature_actual_count(
  value0 : @validate.GenValidFeatureStats,
  value1 : @validate.ValidateValidFeatureKey,
) -> Int {
  @validate.validate_valid_feature_actual_count(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_valid_feature_actual_count_by_label(
  value0 : @validate.GenValidFeatureStats,
  value1 : String,
) -> Result[Int, String] {
  @validate.validate_valid_feature_actual_count_by_label(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_valid_feature_floor(
  value0 : @validate.ValidateValidFeatureKey,
  value1 : Int,
) -> @validate.ValidateValidFeatureFloor {
  @validate.validate_valid_feature_floor(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_valid_feature_floor_by_label(
  value0 : String,
  value1 : Int,
) -> Result[@validate.ValidateValidFeatureFloor, String] {
  @validate.validate_valid_feature_floor_by_label(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_valid_feature_ledger(
  value0 : @validate.GenValidFeatureStats,
  value1 : Array[@validate.ValidateValidFeatureFloor],
) -> Array[@validate.ValidateValidFeatureLedgerEntry] {
  @validate.validate_valid_feature_ledger(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_validate_valid_run_config(
  value0 : String,
) -> Result[@validate.ValidateValidRunConfig, String] {
  @validate.validate_valid_run_config(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_validation_error_diagnostic(
  value0 : @validate.ValidationError,
) -> @validate.ValidationDiagnostic {
  @validate.validation_error_diagnostic(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_validation_error_func_idx(
  value0 : @validate.ValidationError,
) -> @lib.FuncIdx? {
  @validate.validation_error_func_idx(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_validation_error_message(
  value0 : @validate.ValidationError,
) -> String {
  @validate.validation_error_message(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_validation_issue_family(
  value0 : @validate.ValidationIssue,
) -> @validate.ValidationIssueFamily {
  @validate.validation_issue_family(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_validation_issue_message(
  value0 : @validate.ValidationIssue,
) -> String {
  @validate.validation_issue_message(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_append_rectype_types(
  receiver : @validate.Env,
  value1 : @lib.RecType,
) -> @validate.Env {
  @validate.Env::append_rectype_types(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_descriptor_result_type(
  receiver : @validate.Env,
  value1 : @lib.TypeIdx,
  value2 : @lib.RefType?,
) -> Result[@lib.ValType, String] {
  @validate.Env::descriptor_result_type(receiver, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_expand_blocktype(
  receiver : @validate.Env,
  value1 : @lib.BlockType,
) -> Result[(Array[@lib.ValType], Array[@lib.ValType]), String] {
  @validate.Env::expand_blocktype(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_get_catch_label_types(
  receiver : @validate.Env,
  value1 : @lib.LabelIdx,
) -> Array[@lib.ValType]? {
  @validate.Env::get_catch_label_types(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_get_elem(
  receiver : @validate.Env,
  value1 : @lib.ElemIdx,
) -> @lib.Elem? {
  @validate.Env::get_elem(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_get_functype_by_funcidx(
  receiver : @validate.Env,
  value1 : @lib.FuncIdx,
) -> @lib.FuncType? {
  @validate.Env::get_functype_by_funcidx(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_get_functypeidx_by_funcidx(
  receiver : @validate.Env,
  value1 : @lib.FuncIdx,
) -> @lib.TypeIdx? {
  @validate.Env::get_functypeidx_by_funcidx(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_get_global_type(
  receiver : @validate.Env,
  value1 : @lib.GlobalIdx,
) -> @lib.GlobalType? {
  @validate.Env::get_global_type(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_get_label(
  receiver : @validate.Env,
  value1 : @lib.LabelIdx,
) -> Array[@lib.ValType]? {
  @validate.Env::get_label(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_get_label_types(
  receiver : @validate.Env,
  value1 : @lib.LabelIdx,
) -> Array[@lib.ValType]? {
  @validate.Env::get_label_types(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_get_local_type(
  receiver : @validate.Env,
  value1 : @lib.LocalIdx,
) -> @lib.ValType? {
  @validate.Env::get_local_type(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_get_memtype(
  receiver : @validate.Env,
  value1 : @lib.MemIdx,
) -> @lib.MemType? {
  @validate.Env::get_memtype(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_get_table_type(
  receiver : @validate.Env,
  value1 : @lib.TableIdx,
) -> @lib.TableType? {
  @validate.Env::get_table_type(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_get_tag(
  receiver : @validate.Env,
  value1 : @lib.TagIdx,
) -> @lib.TagType? {
  @validate.Env::get_tag(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_has_data(
  receiver : @validate.Env,
  value1 : @lib.DataIdx,
) -> Bool {
  @validate.Env::has_data(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_has_func(
  receiver : @validate.Env,
  value1 : @lib.FuncIdx,
) -> Bool {
  @validate.Env::has_func(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_legacy_rethrow_catch_ordinal(
  receiver : @validate.Env,
  value1 : UInt,
) -> Int? {
  @validate.Env::legacy_rethrow_catch_ordinal(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_new() -> @validate.Env {
  @validate.Env::new()
}

///|
#doc(hidden)
pub fn ffi_validate_Env_push_data(
  receiver : @validate.Env,
  value1 : @lib.Data,
) -> @validate.Env {
  @validate.Env::push_data(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_push_elem(
  receiver : @validate.Env,
  value1 : @lib.Elem,
) -> @validate.Env {
  @validate.Env::push_elem(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_push_func(
  receiver : @validate.Env,
  value1 : @lib.FuncType,
) -> @validate.Env {
  @validate.Env::push_func(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_push_func_with_typeidx(
  receiver : @validate.Env,
  value1 : @lib.FuncType,
  value2 : @lib.TypeIdx?,
) -> @validate.Env {
  @validate.Env::push_func_with_typeidx(receiver, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_push_global(
  receiver : @validate.Env,
  value1 : @lib.GlobalType,
) -> @validate.Env {
  @validate.Env::push_global(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_push_mem(
  receiver : @validate.Env,
  value1 : @lib.MemType,
) -> @validate.Env {
  @validate.Env::push_mem(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_push_table(
  receiver : @validate.Env,
  value1 : @lib.TableType,
) -> @validate.Env {
  @validate.Env::push_table(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_push_tag(
  receiver : @validate.Env,
  value1 : @lib.TagType,
) -> @validate.Env {
  @validate.Env::push_tag(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_resolve_array_field(
  receiver : @validate.Env,
  value1 : @lib.TypeIdx,
) -> Result[@lib.FieldType, String] {
  @validate.Env::resolve_array_field(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_resolve_comptype(
  receiver : @validate.Env,
  value1 : @lib.TypeIdx,
) -> @lib.CompType? {
  @validate.Env::resolve_comptype(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_resolve_cont_functype(
  receiver : @validate.Env,
  value1 : @lib.TypeIdx,
) -> @lib.FuncType? {
  @validate.Env::resolve_cont_functype(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_resolve_descriptor_target_ref_type(
  receiver : @validate.Env,
  value1 : Bool,
  value2 : @lib.HeapType,
) -> Result[@lib.RefType, String] {
  @validate.Env::resolve_descriptor_target_ref_type(receiver, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_resolve_functype(
  receiver : @validate.Env,
  value1 : @lib.TypeIdx,
) -> @lib.FuncType? {
  @validate.Env::resolve_functype(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_resolve_heaptype_subtype(
  receiver : @validate.Env,
  value1 : @lib.HeapType,
) -> @lib.SubType? {
  @validate.Env::resolve_heaptype_subtype(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_resolve_struct_descriptor_type(
  receiver : @validate.Env,
  value1 : @lib.TypeIdx,
) -> Result[@lib.TypeIdx?, String] {
  @validate.Env::resolve_struct_descriptor_type(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_resolve_struct_fields(
  receiver : @validate.Env,
  value1 : @lib.TypeIdx,
) -> Result[Array[@lib.FieldType], String] {
  @validate.Env::resolve_struct_fields(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_resolve_struct_subtype(
  receiver : @validate.Env,
  value1 : @lib.TypeIdx,
) -> Result[@lib.SubType, String] {
  @validate.Env::resolve_struct_subtype(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_resolve_subtype(
  receiver : @validate.Env,
  value1 : @lib.TypeIdx,
) -> @lib.SubType? {
  @validate.Env::resolve_subtype(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_resolve_tag_functype(
  receiver : @validate.Env,
  value1 : @lib.TagIdx,
) -> @lib.FuncType? {
  @validate.Env::resolve_tag_functype(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_resolve_typeidx_subtype(
  receiver : @validate.Env,
  value1 : @lib.TypeIdx,
) -> @lib.SubType? {
  @validate.Env::resolve_typeidx_subtype(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_with_datas(
  receiver : @validate.Env,
  value1 : Array[@lib.Data],
) -> @validate.Env {
  @validate.Env::with_datas(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_with_elems(
  receiver : @validate.Env,
  value1 : Array[@lib.Elem],
) -> @validate.Env {
  @validate.Env::with_elems(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_with_exact_reference_inference(
  receiver : @validate.Env,
  value1 : Bool,
) -> @validate.Env {
  @validate.Env::with_exact_reference_inference(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_with_funcs(
  receiver : @validate.Env,
  value1 : Array[@lib.FuncType],
) -> @validate.Env {
  @validate.Env::with_funcs(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_with_funcs_and_type_idxs(
  receiver : @validate.Env,
  value1 : Array[@lib.FuncType],
  value2 : Array[@lib.TypeIdx?],
) -> @validate.Env {
  @validate.Env::with_funcs_and_type_idxs(receiver, value1, value2)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_with_globals(
  receiver : @validate.Env,
  value1 : Array[@lib.GlobalType],
) -> @validate.Env {
  @validate.Env::with_globals(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_with_label(
  receiver : @validate.Env,
  value1 : Array[@lib.ValType],
) -> @validate.Env {
  @validate.Env::with_label(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_with_labels(
  receiver : @validate.Env,
  value1 : Array[Array[@lib.ValType]],
) -> @validate.Env {
  @validate.Env::with_labels(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_with_legacy_catch_depth(
  receiver : @validate.Env,
  value1 : Int,
) -> @validate.Env {
  @validate.Env::with_legacy_catch_depth(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_with_locals(
  receiver : @validate.Env,
  value1 : @lib.Locals,
) -> @validate.Env {
  @validate.Env::with_locals(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_with_mems(
  receiver : @validate.Env,
  value1 : Array[@lib.MemType],
) -> @validate.Env {
  @validate.Env::with_mems(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_with_module(
  receiver : @validate.Env,
  value1 : @lib.Module,
) -> @validate.Env {
  @validate.Env::with_module(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_with_rectype(
  receiver : @validate.Env,
  value1 : @lib.RecType,
) -> @validate.Env {
  @validate.Env::with_rectype(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_with_return_type(
  receiver : @validate.Env,
  value1 : Array[@lib.ValType]?,
) -> @validate.Env {
  @validate.Env::with_return_type(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_with_tables(
  receiver : @validate.Env,
  value1 : Array[@lib.TableType],
) -> @validate.Env {
  @validate.Env::with_tables(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_with_tags(
  receiver : @validate.Env,
  value1 : Array[@lib.TagType],
) -> @validate.Env {
  @validate.Env::with_tags(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_Env_with_types(
  receiver : @validate.Env,
  value1 : Array[@lib.SubType],
) -> @validate.Env {
  @validate.Env::with_types(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_GenInvalidAstParams_coverage_forced_seed(
  value0 : @validate.ValidateInvalidAstStrategyId,
  generator_config : @validate.GenValidConfig?,
  require_strategy_prereqs : Bool?,
) -> @validate.GenInvalidAstParams {
  @validate.GenInvalidAstParams::coverage_forced_seed(
    value0,
    generator_config?,
    require_strategy_prereqs?,
  )
}

///|
#doc(hidden)
pub fn ffi_validate_GenInvalidAstParams_minimal_seed(
  value0 : @validate.ValidateInvalidAstStrategyId,
  generator_config : @validate.GenValidConfig?,
  require_strategy_prereqs : Bool?,
) -> @validate.GenInvalidAstParams {
  @validate.GenInvalidAstParams::minimal_seed(
    value0,
    generator_config?,
    require_strategy_prereqs?,
  )
}

///|
#doc(hidden)
pub fn ffi_validate_GenInvalidAstParams_natural_seed(
  value0 : @validate.ValidateInvalidAstStrategyId,
  generator_config : @validate.GenValidConfig?,
  require_strategy_prereqs : Bool?,
) -> @validate.GenInvalidAstParams {
  @validate.GenInvalidAstParams::natural_seed(
    value0,
    generator_config?,
    require_strategy_prereqs?,
  )
}

///|
#doc(hidden)
pub fn ffi_validate_GenInvalidAstParams_new(
  value0 : @validate.ValidateInvalidAstStrategyId,
  seed_mode : @validate.GenInvalidSeedMode?,
  generator_config : @validate.GenValidConfig?,
  require_strategy_prereqs : Bool?,
) -> @validate.GenInvalidAstParams {
  @validate.GenInvalidAstParams::new(
    value0,
    seed_mode?,
    generator_config?,
    require_strategy_prereqs?,
  )
}

///|
#doc(hidden)
pub fn ffi_validate_GenInvalidAstParams_repro_seed(
  value0 : @validate.ValidateInvalidAstStrategyId,
  generator_config : @validate.GenValidConfig?,
  require_strategy_prereqs : Bool?,
) -> @validate.GenInvalidAstParams {
  @validate.GenInvalidAstParams::repro_seed(
    value0,
    generator_config?,
    require_strategy_prereqs?,
  )
}

///|
#doc(hidden)
pub fn ffi_validate_GenInvalidAstParams_rich_seed(
  value0 : @validate.ValidateInvalidAstStrategyId,
  generator_config : @validate.GenValidConfig?,
  require_strategy_prereqs : Bool?,
) -> @validate.GenInvalidAstParams {
  @validate.GenInvalidAstParams::rich_seed(
    value0,
    generator_config?,
    require_strategy_prereqs?,
  )
}

///|
#doc(hidden)
pub fn ffi_validate_GenInvalidAstParams_small_coverage_forced_seed(
  value0 : @validate.ValidateInvalidAstStrategyId,
  generator_config : @validate.GenValidConfig?,
  require_strategy_prereqs : Bool?,
) -> @validate.GenInvalidAstParams {
  @validate.GenInvalidAstParams::small_coverage_forced_seed(
    value0,
    generator_config?,
    require_strategy_prereqs?,
  )
}

///|
#doc(hidden)
pub fn ffi_validate_GenInvalidAstParams_small_natural_seed(
  value0 : @validate.ValidateInvalidAstStrategyId,
  generator_config : @validate.GenValidConfig?,
  require_strategy_prereqs : Bool?,
) -> @validate.GenInvalidAstParams {
  @validate.GenInvalidAstParams::small_natural_seed(
    value0,
    generator_config?,
    require_strategy_prereqs?,
  )
}

///|
#doc(hidden)
pub fn ffi_validate_GenValidConfig_binaryen_oracle_coverage_forced_default() -> @validate.GenValidConfig {
  @validate.GenValidConfig::binaryen_oracle_coverage_forced_default()
}

///|
#doc(hidden)
pub fn ffi_validate_GenValidConfig_coverage_forced_default() -> @validate.GenValidConfig {
  @validate.GenValidConfig::coverage_forced_default()
}

///|
#doc(hidden)
pub fn ffi_validate_GenValidConfig_for_profile(
  value0 : @validate.GenValidProfile,
) -> @validate.GenValidConfig {
  @validate.GenValidConfig::for_profile(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_GenValidConfig_natural_default() -> @validate.GenValidConfig {
  @validate.GenValidConfig::natural_default()
}

///|
#doc(hidden)
pub fn ffi_validate_GenValidConfig_portable_coverage_forced_default() -> @validate.GenValidConfig {
  @validate.GenValidConfig::portable_coverage_forced_default()
}

///|
#doc(hidden)
pub fn ffi_validate_GenValidConfig_profile(
  value0 : String,
) -> Result[@validate.GenValidConfig, String] {
  @validate.GenValidConfig::profile(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_GenValidConfig_wat_text_roundtrip_default() -> @validate.GenValidConfig {
  @validate.GenValidConfig::wat_text_roundtrip_default()
}

///|
#doc(hidden)
pub fn ffi_validate_GenValidExactOpcodeCounts_add(
  receiver : @validate.GenValidExactOpcodeCounts,
  value1 : @validate.GenValidExactOpcodeCounts,
) -> @validate.GenValidExactOpcodeCounts {
  @validate.GenValidExactOpcodeCounts::add(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_GenValidExactOpcodeCounts_empty() -> @validate.GenValidExactOpcodeCounts {
  @validate.GenValidExactOpcodeCounts::empty()
}

///|
#doc(hidden)
pub fn ffi_validate_GenValidFeatureStats_empty(
  value0 : @validate.GenValidMode,
) -> @validate.GenValidFeatureStats {
  @validate.GenValidFeatureStats::empty(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_GenValidFeatureStats_record(
  receiver : @validate.GenValidFeatureStats,
  value1 : @validate.GenValidFeatureFacts,
) -> @validate.GenValidFeatureStats {
  @validate.GenValidFeatureStats::record(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_GenValidFeatureToggles_coverage_forced_default() -> @validate.GenValidFeatureToggles {
  @validate.GenValidFeatureToggles::coverage_forced_default()
}

///|
#doc(hidden)
pub fn ffi_validate_GenValidFeatureToggles_natural_default() -> @validate.GenValidFeatureToggles {
  @validate.GenValidFeatureToggles::natural_default()
}

///|
#doc(hidden)
pub fn ffi_validate_GenValidProfileMember_new(
  value0 : @validate.GenValidProfile,
  value1 : Int,
) -> @validate.GenValidProfileMember {
  @validate.GenValidProfileMember::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_GenValidSectionBias_coverage_forced_default() -> @validate.GenValidSectionBias {
  @validate.GenValidSectionBias::coverage_forced_default()
}

///|
#doc(hidden)
pub fn ffi_validate_GenValidSectionBias_natural_default() -> @validate.GenValidSectionBias {
  @validate.GenValidSectionBias::natural_default()
}

///|
#doc(hidden)
pub fn ffi_validate_GenValidSsaFuncFacts_empty() -> @validate.GenValidSsaFuncFacts {
  @validate.GenValidSsaFuncFacts::empty()
}

///|
#doc(hidden)
pub fn ffi_validate_LabelStack_copy(
  receiver : @validate.LabelStack,
) -> @validate.LabelStack {
  @validate.LabelStack::copy(receiver)
}

///|
#doc(hidden)
pub fn ffi_validate_LabelStack_from_labels(
  value0 : Array[Array[@lib.ValType]],
) -> @validate.LabelStack {
  @validate.LabelStack::from_labels(value0)
}

///|
#doc(hidden)
pub fn ffi_validate_LabelStack_get(
  receiver : @validate.LabelStack,
  value1 : Int,
) -> Array[@lib.ValType]? {
  @validate.LabelStack::get(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_LabelStack_length(receiver : @validate.LabelStack) -> Int {
  @validate.LabelStack::length(receiver)
}

///|
#doc(hidden)
pub fn ffi_validate_LabelStack_new() -> @validate.LabelStack {
  @validate.LabelStack::new()
}

///|
#doc(hidden)
pub fn ffi_validate_LabelStack_push(
  receiver : @validate.LabelStack,
  value1 : Array[@lib.ValType],
) -> Unit {
  @validate.LabelStack::push(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_validate_ValidationDiagnostic_new(
  value0 : @validate.ValidationIssue,
  func_idx : @lib.FuncIdx??,
) -> @validate.ValidationDiagnostic {
  @validate.ValidationDiagnostic::new(value0, func_idx?)
}

///|
#doc(hidden)
pub fn ffi_wast_evaluate_wast_static_assertion(
  value0 : @wast.WastCommand,
  value1 : String,
) -> Result[@wast.WastStaticAssertionResult, String] {
  @wast.evaluate_wast_static_assertion(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_wast_lookup_keyword(value0 : String) -> @wast.TokenType? {
  @wast.lookup_keyword(value0)
}

///|
#doc(hidden)
pub fn ffi_wast_module_to_wast(value0 : @wast.Module) -> Result[String, String] {
  @wast.module_to_wast(value0)
}

///|
#doc(hidden)
pub fn ffi_wast_module_to_wast_with_context(
  value0 : @wast.Module,
  value1 : @lib.PrettyPrintContext,
) -> Result[String, String] {
  @wast.module_to_wast_with_context(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_wast_run_wast_roundtrip_fuzz(
  value0 : String,
  value1 : UInt64,
) -> Result[@wast.WastRoundtripFuzzStats, String] {
  @wast.run_wast_roundtrip_fuzz(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_wast_run_wast_spec_file(
  value0 : String,
  value1 : String,
) -> @wast.WastSpecFileReport {
  @wast.run_wast_spec_file(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_wast_run_wast_spec_suite(
  value0 : Array[(String, String)],
) -> @wast.WastSpecRunSummary {
  @wast.run_wast_spec_suite(value0)
}

///|
#doc(hidden)
pub fn ffi_wast_script_to_wast(
  value0 : @wast.WastScript,
) -> Result[String, String] {
  @wast.script_to_wast(value0)
}

///|
#doc(hidden)
pub fn ffi_wast_script_to_wast_with_context(
  value0 : @wast.WastScript,
  value1 : @lib.PrettyPrintContext,
) -> Result[String, String] {
  @wast.script_to_wast_with_context(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_wast_wast_arbitrary_feature_stats(
  value0 : @wast.Module,
) -> @wast.WastArbitraryFeatureStats {
  @wast.wast_arbitrary_feature_stats(value0)
}

///|
#doc(hidden)
pub fn ffi_wast_wast_ast_to_binary_module(
  value0 : @wast.Module,
) -> Result[@lib.Module, String] {
  @wast.wast_ast_to_binary_module(value0)
}

///|
#doc(hidden)
pub fn ffi_wast_wast_text_binary_roundtrip(
  value0 : String,
  filename : String?,
) -> Result[(String, @lib.Module), String] {
  @wast.wast_text_binary_roundtrip(value0, filename?)
}

///|
#doc(hidden)
pub fn ffi_wast_wast_to_binary_module(
  value0 : String,
  filename : String?,
) -> Result[@lib.Module, String] {
  @wast.wast_to_binary_module(value0, filename?)
}

///|
#doc(hidden)
pub fn ffi_wast_wast_to_module(
  value0 : String,
  filename : String?,
) -> Result[@wast.Module, String] {
  @wast.wast_to_module(value0, filename?)
}

///|
#doc(hidden)
pub fn ffi_wast_wast_to_script(
  value0 : String,
  filename : String?,
) -> Result[@wast.WastScript, String] {
  @wast.wast_to_script(value0, filename?)
}

///|
#doc(hidden)
pub fn ffi_wast_KeywordTable_lookup(
  receiver : @wast.KeywordTable,
  value1 : String,
) -> @wast.TokenType? {
  @wast.KeywordTable::lookup(receiver, value1)
}

///|
#doc(hidden)
pub fn ffi_wast_MemoryType_new(
  value0 : UInt64,
  max : UInt64??,
  shared : Bool?,
  memory64 : Bool?,
) -> @wast.MemoryType {
  @wast.MemoryType::new(value0, max?, shared?, memory64?)
}

///|
#doc(hidden)
pub fn ffi_wast_Module_new(
  value0 : Array[@wast.ModuleField],
  id : String??,
) -> @wast.Module {
  @wast.Module::new(value0, id?)
}

///|
#doc(hidden)
pub fn ffi_wast_WastLexer_get_errors(
  receiver : @wast.WastLexer,
) -> Array[@wast.LexerError] {
  @wast.WastLexer::get_errors(receiver)
}

///|
#doc(hidden)
pub fn ffi_wast_WastLexer_get_token(receiver : @wast.WastLexer) -> @wast.Token {
  @wast.WastLexer::get_token(receiver)
}

///|
#doc(hidden)
pub fn ffi_wast_WastLexer_has_errors(receiver : @wast.WastLexer) -> Bool {
  @wast.WastLexer::has_errors(receiver)
}

///|
#doc(hidden)
pub fn ffi_wast_WastLexer_new(
  value0 : Bytes,
  value1 : String,
) -> @wast.WastLexer {
  @wast.WastLexer::new(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_wast_WastParser_get_errors(
  receiver : @wast.WastParser,
) -> Array[@wast.ParseError] {
  @wast.WastParser::get_errors(receiver)
}

///|
#doc(hidden)
pub fn ffi_wast_WastParser_has_errors(receiver : @wast.WastParser) -> Bool {
  @wast.WastParser::has_errors(receiver)
}

///|
#doc(hidden)
pub fn ffi_wast_WastParser_new(value0 : @wast.WastLexer) -> @wast.WastParser {
  @wast.WastParser::new(value0)
}

///|
#doc(hidden)
pub fn ffi_wat_lib_module_to_wat(
  value0 : @lib.Module,
) -> Result[String, String] {
  @wat.lib_module_to_wat(value0)
}

///|
#doc(hidden)
pub fn ffi_wat_lookup_keyword(value0 : String) -> @wast.TokenType? {
  @wat.lookup_keyword(value0)
}

///|
#doc(hidden)
pub fn ffi_wat_module_to_wat(value0 : @wast.Module) -> Result[String, String] {
  @wat.module_to_wat(value0)
}

///|
#doc(hidden)
pub fn ffi_wat_module_to_wat_with_context(
  value0 : @wast.Module,
  value1 : @lib.PrettyPrintContext,
) -> Result[String, String] {
  @wat.module_to_wat_with_context(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_wat_run_wat_roundtrip_fuzz(
  value0 : String,
  value1 : UInt64,
) -> Result[@wat.WatRoundtripFuzzStats, String] {
  @wat.run_wat_roundtrip_fuzz(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_wat_script_to_wat(
  value0 : @wast.WastScript,
) -> Result[String, String] {
  @wat.script_to_wat(value0)
}

///|
#doc(hidden)
pub fn ffi_wat_script_to_wat_with_context(
  value0 : @wast.WastScript,
  value1 : @lib.PrettyPrintContext,
) -> Result[String, String] {
  @wat.script_to_wat_with_context(value0, value1)
}

///|
#doc(hidden)
pub fn ffi_wat_wat_to_module(
  value0 : String,
  filename : String?,
) -> Result[@wast.Module, String] {
  @wat.wat_to_module(value0, filename?)
}

///|
#doc(hidden)
pub fn ffi_wat_wat_to_script(
  value0 : String,
  filename : String?,
) -> Result[@wast.WastScript, String] {
  @wat.wat_to_script(value0, filename?)
}

///|
pub fn __js_bytes_from_array(value : Array[Byte]) -> Bytes {
  Bytes::from_array(value)
}

///|
pub fn __js_bytes_length(value : Bytes) -> Int {
  value.length()
}

///|
pub fn __js_bytes_get(value : Bytes, index : Int) -> Byte {
  value[index]
}

///|
pub fn __js_array_1_new() -> Array[Array[UInt]] {
  Array::new()
}

///|
pub fn __js_array_1_push(
  value : Array[Array[UInt]],
  item : Array[UInt],
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_1_length(value : Array[Array[UInt]]) -> Int {
  value.length()
}

///|
pub fn __js_array_1_get(value : Array[Array[UInt]], index : Int) -> Array[UInt] {
  value[index]
}

///|
pub fn __js_array_2_new() -> Array[UInt] {
  Array::new()
}

///|
pub fn __js_array_2_push(value : Array[UInt], item : UInt) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_2_length(value : Array[UInt]) -> Int {
  value.length()
}

///|
pub fn __js_array_2_get(value : Array[UInt], index : Int) -> UInt {
  value[index]
}

///|
pub fn __js_array_3_new() -> Array[Array[(UInt, @lib.Instruction)]] {
  Array::new()
}

///|
pub fn __js_array_3_push(
  value : Array[Array[(UInt, @lib.Instruction)]],
  item : Array[(UInt, @lib.Instruction)],
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_3_length(
  value : Array[Array[(UInt, @lib.Instruction)]],
) -> Int {
  value.length()
}

///|
pub fn __js_array_3_get(
  value : Array[Array[(UInt, @lib.Instruction)]],
  index : Int,
) -> Array[(UInt, @lib.Instruction)] {
  value[index]
}

///|
pub fn __js_array_4_new() -> Array[(UInt, @lib.Instruction)] {
  Array::new()
}

///|
pub fn __js_array_4_push(
  value : Array[(UInt, @lib.Instruction)],
  item : (UInt, @lib.Instruction),
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_4_length(value : Array[(UInt, @lib.Instruction)]) -> Int {
  value.length()
}

///|
pub fn __js_array_4_get(
  value : Array[(UInt, @lib.Instruction)],
  index : Int,
) -> (UInt, @lib.Instruction) {
  value[index]
}

///|
pub fn __js_array_5_new() -> Array[Bytes] {
  Array::new()
}

///|
pub fn __js_array_5_push(value : Array[Bytes], item : Bytes) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_5_length(value : Array[Bytes]) -> Int {
  value.length()
}

///|
pub fn __js_array_5_get(value : Array[Bytes], index : Int) -> Bytes {
  value[index]
}

///|
pub fn __js_array_6_new() -> Array[String] {
  Array::new()
}

///|
pub fn __js_array_6_push(value : Array[String], item : String) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_6_length(value : Array[String]) -> Int {
  value.length()
}

///|
pub fn __js_array_6_get(value : Array[String], index : Int) -> String {
  value[index]
}

///|
pub fn __js_array_7_new() -> Array[@cli.CliOutputTarget] {
  Array::new()
}

///|
pub fn __js_array_7_push(
  value : Array[@cli.CliOutputTarget],
  item : @cli.CliOutputTarget,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_7_length(value : Array[@cli.CliOutputTarget]) -> Int {
  value.length()
}

///|
pub fn __js_array_7_get(
  value : Array[@cli.CliOutputTarget],
  index : Int,
) -> @cli.CliOutputTarget {
  value[index]
}

///|
pub fn __js_array_8_new() -> Array[@cli.CliOptimizationFlag] {
  Array::new()
}

///|
pub fn __js_array_8_push(
  value : Array[@cli.CliOptimizationFlag],
  item : @cli.CliOptimizationFlag,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_8_length(value : Array[@cli.CliOptimizationFlag]) -> Int {
  value.length()
}

///|
pub fn __js_array_8_get(
  value : Array[@cli.CliOptimizationFlag],
  index : Int,
) -> @cli.CliOptimizationFlag {
  value[index]
}

///|
pub fn __js_array_9_new() -> Array[@lib.ValType] {
  Array::new()
}

///|
pub fn __js_array_9_push(
  value : Array[@lib.ValType],
  item : @lib.ValType,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_9_length(value : Array[@lib.ValType]) -> Int {
  value.length()
}

///|
pub fn __js_array_9_get(
  value : Array[@lib.ValType],
  index : Int,
) -> @lib.ValType {
  value[index]
}

///|
pub fn __js_array_10_new() -> Array[@cmd.BinaryDifferentialAdapterResult] {
  Array::new()
}

///|
pub fn __js_array_10_push(
  value : Array[@cmd.BinaryDifferentialAdapterResult],
  item : @cmd.BinaryDifferentialAdapterResult,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_10_length(
  value : Array[@cmd.BinaryDifferentialAdapterResult],
) -> Int {
  value.length()
}

///|
pub fn __js_array_10_get(
  value : Array[@cmd.BinaryDifferentialAdapterResult],
  index : Int,
) -> @cmd.BinaryDifferentialAdapterResult {
  value[index]
}

///|
pub fn __js_array_11_new() -> Array[@cmd.TextAggregateAdapterResult] {
  Array::new()
}

///|
pub fn __js_array_11_push(
  value : Array[@cmd.TextAggregateAdapterResult],
  item : @cmd.TextAggregateAdapterResult,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_11_length(
  value : Array[@cmd.TextAggregateAdapterResult],
) -> Int {
  value.length()
}

///|
pub fn __js_array_11_get(
  value : Array[@cmd.TextAggregateAdapterResult],
  index : Int,
) -> @cmd.TextAggregateAdapterResult {
  value[index]
}

///|
pub fn __js_array_12_new() -> Array[@cmd.ExportInvocationComparisonReport] {
  Array::new()
}

///|
pub fn __js_array_12_push(
  value : Array[@cmd.ExportInvocationComparisonReport],
  item : @cmd.ExportInvocationComparisonReport,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_12_length(
  value : Array[@cmd.ExportInvocationComparisonReport],
) -> Int {
  value.length()
}

///|
pub fn __js_array_12_get(
  value : Array[@cmd.ExportInvocationComparisonReport],
  index : Int,
) -> @cmd.ExportInvocationComparisonReport {
  value[index]
}

///|
pub fn __js_array_13_new() -> Array[@cmd.BinaryDifferentialSmokeAdapter] {
  Array::new()
}

///|
pub fn __js_array_13_push(
  value : Array[@cmd.BinaryDifferentialSmokeAdapter],
  item : @cmd.BinaryDifferentialSmokeAdapter,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_13_length(
  value : Array[@cmd.BinaryDifferentialSmokeAdapter],
) -> Int {
  value.length()
}

///|
pub fn __js_array_13_get(
  value : Array[@cmd.BinaryDifferentialSmokeAdapter],
  index : Int,
) -> @cmd.BinaryDifferentialSmokeAdapter {
  value[index]
}

///|
pub fn __js_array_14_new() -> Array[@cmd.BinaryCanonicalityClassification] {
  Array::new()
}

///|
pub fn __js_array_14_push(
  value : Array[@cmd.BinaryCanonicalityClassification],
  item : @cmd.BinaryCanonicalityClassification,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_14_length(
  value : Array[@cmd.BinaryCanonicalityClassification],
) -> Int {
  value.length()
}

///|
pub fn __js_array_14_get(
  value : Array[@cmd.BinaryCanonicalityClassification],
  index : Int,
) -> @cmd.BinaryCanonicalityClassification {
  value[index]
}

///|
pub fn __js_array_15_new() -> Array[(String, String)] {
  Array::new()
}

///|
pub fn __js_array_15_push(
  value : Array[(String, String)],
  item : (String, String),
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_15_length(value : Array[(String, String)]) -> Int {
  value.length()
}

///|
pub fn __js_array_15_get(
  value : Array[(String, String)],
  index : Int,
) -> (String, String) {
  value[index]
}

///|
pub fn __js_array_16_new() -> Array[@cmd.FuzzReductionStep] {
  Array::new()
}

///|
pub fn __js_array_16_push(
  value : Array[@cmd.FuzzReductionStep],
  item : @cmd.FuzzReductionStep,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_16_length(value : Array[@cmd.FuzzReductionStep]) -> Int {
  value.length()
}

///|
pub fn __js_array_16_get(
  value : Array[@cmd.FuzzReductionStep],
  index : Int,
) -> @cmd.FuzzReductionStep {
  value[index]
}

///|
pub fn __js_array_17_new() -> Array[@lib.FieldType] {
  Array::new()
}

///|
pub fn __js_array_17_push(
  value : Array[@lib.FieldType],
  item : @lib.FieldType,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_17_length(value : Array[@lib.FieldType]) -> Int {
  value.length()
}

///|
pub fn __js_array_17_get(
  value : Array[@lib.FieldType],
  index : Int,
) -> @lib.FieldType {
  value[index]
}

///|
pub fn __js_array_18_new() -> Array[@lib.SubType] {
  Array::new()
}

///|
pub fn __js_array_18_push(
  value : Array[@lib.SubType],
  item : @lib.SubType,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_18_length(value : Array[@lib.SubType]) -> Int {
  value.length()
}

///|
pub fn __js_array_18_get(
  value : Array[@lib.SubType],
  index : Int,
) -> @lib.SubType {
  value[index]
}

///|
pub fn __js_array_19_new() -> Array[@lib.TypeIdx] {
  Array::new()
}

///|
pub fn __js_array_19_push(
  value : Array[@lib.TypeIdx],
  item : @lib.TypeIdx,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_19_length(value : Array[@lib.TypeIdx]) -> Int {
  value.length()
}

///|
pub fn __js_array_19_get(
  value : Array[@lib.TypeIdx],
  index : Int,
) -> @lib.TypeIdx {
  value[index]
}

///|
pub fn __js_array_20_new() -> Array[@lib.Func] {
  Array::new()
}

///|
pub fn __js_array_20_push(value : Array[@lib.Func], item : @lib.Func) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_20_length(value : Array[@lib.Func]) -> Int {
  value.length()
}

///|
pub fn __js_array_20_get(value : Array[@lib.Func], index : Int) -> @lib.Func {
  value[index]
}

///|
pub fn __js_array_21_new() -> Array[@lib.Data] {
  Array::new()
}

///|
pub fn __js_array_21_push(value : Array[@lib.Data], item : @lib.Data) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_21_length(value : Array[@lib.Data]) -> Int {
  value.length()
}

///|
pub fn __js_array_21_get(value : Array[@lib.Data], index : Int) -> @lib.Data {
  value[index]
}

///|
pub fn __js_array_22_new() -> Array[@lib.Expr] {
  Array::new()
}

///|
pub fn __js_array_22_push(value : Array[@lib.Expr], item : @lib.Expr) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_22_length(value : Array[@lib.Expr]) -> Int {
  value.length()
}

///|
pub fn __js_array_22_get(value : Array[@lib.Expr], index : Int) -> @lib.Expr {
  value[index]
}

///|
pub fn __js_array_23_new() -> Array[@lib.FuncIdx] {
  Array::new()
}

///|
pub fn __js_array_23_push(
  value : Array[@lib.FuncIdx],
  item : @lib.FuncIdx,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_23_length(value : Array[@lib.FuncIdx]) -> Int {
  value.length()
}

///|
pub fn __js_array_23_get(
  value : Array[@lib.FuncIdx],
  index : Int,
) -> @lib.FuncIdx {
  value[index]
}

///|
pub fn __js_array_24_new() -> Array[@lib.Elem] {
  Array::new()
}

///|
pub fn __js_array_24_push(value : Array[@lib.Elem], item : @lib.Elem) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_24_length(value : Array[@lib.Elem]) -> Int {
  value.length()
}

///|
pub fn __js_array_24_get(value : Array[@lib.Elem], index : Int) -> @lib.Elem {
  value[index]
}

///|
pub fn __js_array_25_new() -> Array[@lib.Export] {
  Array::new()
}

///|
pub fn __js_array_25_push(
  value : Array[@lib.Export],
  item : @lib.Export,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_25_length(value : Array[@lib.Export]) -> Int {
  value.length()
}

///|
pub fn __js_array_25_get(
  value : Array[@lib.Export],
  index : Int,
) -> @lib.Export {
  value[index]
}

///|
pub fn __js_array_26_new() -> Array[@lib.Instruction] {
  Array::new()
}

///|
pub fn __js_array_26_push(
  value : Array[@lib.Instruction],
  item : @lib.Instruction,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_26_length(value : Array[@lib.Instruction]) -> Int {
  value.length()
}

///|
pub fn __js_array_26_get(
  value : Array[@lib.Instruction],
  index : Int,
) -> @lib.Instruction {
  value[index]
}

///|
pub fn __js_array_27_new() -> Array[@lib.FuncAnnotation] {
  Array::new()
}

///|
pub fn __js_array_27_push(
  value : Array[@lib.FuncAnnotation],
  item : @lib.FuncAnnotation,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_27_length(value : Array[@lib.FuncAnnotation]) -> Int {
  value.length()
}

///|
pub fn __js_array_27_get(
  value : Array[@lib.FuncAnnotation],
  index : Int,
) -> @lib.FuncAnnotation {
  value[index]
}

///|
pub fn __js_array_28_new() -> Array[@lib.FuncAnnotationAssoc] {
  Array::new()
}

///|
pub fn __js_array_28_push(
  value : Array[@lib.FuncAnnotationAssoc],
  item : @lib.FuncAnnotationAssoc,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_28_length(value : Array[@lib.FuncAnnotationAssoc]) -> Int {
  value.length()
}

///|
pub fn __js_array_28_get(
  value : Array[@lib.FuncAnnotationAssoc],
  index : Int,
) -> @lib.FuncAnnotationAssoc {
  value[index]
}

///|
pub fn __js_array_29_new() -> Array[@lib.Global] {
  Array::new()
}

///|
pub fn __js_array_29_push(
  value : Array[@lib.Global],
  item : @lib.Global,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_29_length(value : Array[@lib.Global]) -> Int {
  value.length()
}

///|
pub fn __js_array_29_get(
  value : Array[@lib.Global],
  index : Int,
) -> @lib.Global {
  value[index]
}

///|
pub fn __js_array_30_new() -> Array[@lib.Import] {
  Array::new()
}

///|
pub fn __js_array_30_push(
  value : Array[@lib.Import],
  item : @lib.Import,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_30_length(value : Array[@lib.Import]) -> Int {
  value.length()
}

///|
pub fn __js_array_30_get(
  value : Array[@lib.Import],
  index : Int,
) -> @lib.Import {
  value[index]
}

///|
pub fn __js_array_31_new() -> Array[@lib.IndirectNameAssoc] {
  Array::new()
}

///|
pub fn __js_array_31_push(
  value : Array[@lib.IndirectNameAssoc],
  item : @lib.IndirectNameAssoc,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_31_length(value : Array[@lib.IndirectNameAssoc]) -> Int {
  value.length()
}

///|
pub fn __js_array_31_get(
  value : Array[@lib.IndirectNameAssoc],
  index : Int,
) -> @lib.IndirectNameAssoc {
  value[index]
}

///|
pub fn __js_array_32_new() -> Array[@lib.LabelIdx] {
  Array::new()
}

///|
pub fn __js_array_32_push(
  value : Array[@lib.LabelIdx],
  item : @lib.LabelIdx,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_32_length(value : Array[@lib.LabelIdx]) -> Int {
  value.length()
}

///|
pub fn __js_array_32_get(
  value : Array[@lib.LabelIdx],
  index : Int,
) -> @lib.LabelIdx {
  value[index]
}

///|
pub fn __js_array_33_new() -> Array[@lib.ResumeHandler] {
  Array::new()
}

///|
pub fn __js_array_33_push(
  value : Array[@lib.ResumeHandler],
  item : @lib.ResumeHandler,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_33_length(value : Array[@lib.ResumeHandler]) -> Int {
  value.length()
}

///|
pub fn __js_array_33_get(
  value : Array[@lib.ResumeHandler],
  index : Int,
) -> @lib.ResumeHandler {
  value[index]
}

///|
pub fn __js_array_34_new() -> Array[@lib.LegacyCatch] {
  Array::new()
}

///|
pub fn __js_array_34_push(
  value : Array[@lib.LegacyCatch],
  item : @lib.LegacyCatch,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_34_length(value : Array[@lib.LegacyCatch]) -> Int {
  value.length()
}

///|
pub fn __js_array_34_get(
  value : Array[@lib.LegacyCatch],
  index : Int,
) -> @lib.LegacyCatch {
  value[index]
}

///|
pub fn __js_array_35_new() -> Array[@lib.Catch] {
  Array::new()
}

///|
pub fn __js_array_35_push(value : Array[@lib.Catch], item : @lib.Catch) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_35_length(value : Array[@lib.Catch]) -> Int {
  value.length()
}

///|
pub fn __js_array_35_get(value : Array[@lib.Catch], index : Int) -> @lib.Catch {
  value[index]
}

///|
pub fn __js_array_36_new() -> Array[@lib.LocalRun] {
  Array::new()
}

///|
pub fn __js_array_36_push(
  value : Array[@lib.LocalRun],
  item : @lib.LocalRun,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_36_length(value : Array[@lib.LocalRun]) -> Int {
  value.length()
}

///|
pub fn __js_array_36_get(
  value : Array[@lib.LocalRun],
  index : Int,
) -> @lib.LocalRun {
  value[index]
}

///|
pub fn __js_array_37_new() -> Array[@lib.MemType] {
  Array::new()
}

///|
pub fn __js_array_37_push(
  value : Array[@lib.MemType],
  item : @lib.MemType,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_37_length(value : Array[@lib.MemType]) -> Int {
  value.length()
}

///|
pub fn __js_array_37_get(
  value : Array[@lib.MemType],
  index : Int,
) -> @lib.MemType {
  value[index]
}

///|
pub fn __js_array_38_new() -> Array[@lib.CustomSec] {
  Array::new()
}

///|
pub fn __js_array_38_push(
  value : Array[@lib.CustomSec],
  item : @lib.CustomSec,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_38_length(value : Array[@lib.CustomSec]) -> Int {
  value.length()
}

///|
pub fn __js_array_38_get(
  value : Array[@lib.CustomSec],
  index : Int,
) -> @lib.CustomSec {
  value[index]
}

///|
pub fn __js_array_39_new() -> Array[@lib.NameAssoc] {
  Array::new()
}

///|
pub fn __js_array_39_push(
  value : Array[@lib.NameAssoc],
  item : @lib.NameAssoc,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_39_length(value : Array[@lib.NameAssoc]) -> Int {
  value.length()
}

///|
pub fn __js_array_39_get(
  value : Array[@lib.NameAssoc],
  index : Int,
) -> @lib.NameAssoc {
  value[index]
}

///|
pub fn __js_array_40_new() -> Array[@lib.Table] {
  Array::new()
}

///|
pub fn __js_array_40_push(value : Array[@lib.Table], item : @lib.Table) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_40_length(value : Array[@lib.Table]) -> Int {
  value.length()
}

///|
pub fn __js_array_40_get(value : Array[@lib.Table], index : Int) -> @lib.Table {
  value[index]
}

///|
pub fn __js_array_41_new() -> Array[@lib.TagType] {
  Array::new()
}

///|
pub fn __js_array_41_push(
  value : Array[@lib.TagType],
  item : @lib.TagType,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_41_length(value : Array[@lib.TagType]) -> Int {
  value.length()
}

///|
pub fn __js_array_41_get(
  value : Array[@lib.TagType],
  index : Int,
) -> @lib.TagType {
  value[index]
}

///|
pub fn __js_array_42_new() -> Array[@lib.RecType] {
  Array::new()
}

///|
pub fn __js_array_42_push(
  value : Array[@lib.RecType],
  item : @lib.RecType,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_42_length(value : Array[@lib.RecType]) -> Int {
  value.length()
}

///|
pub fn __js_array_42_get(
  value : Array[@lib.RecType],
  index : Int,
) -> @lib.RecType {
  value[index]
}

///|
pub fn __js_array_43_new() -> Array[@validate.ValidateValidFeatureFloor] {
  Array::new()
}

///|
pub fn __js_array_43_push(
  value : Array[@validate.ValidateValidFeatureFloor],
  item : @validate.ValidateValidFeatureFloor,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_43_length(
  value : Array[@validate.ValidateValidFeatureFloor],
) -> Int {
  value.length()
}

///|
pub fn __js_array_43_get(
  value : Array[@validate.ValidateValidFeatureFloor],
  index : Int,
) -> @validate.ValidateValidFeatureFloor {
  value[index]
}

///|
pub fn __js_array_44_new() -> Array[@validate.ValidateValidFeatureFloorFailure] {
  Array::new()
}

///|
pub fn __js_array_44_push(
  value : Array[@validate.ValidateValidFeatureFloorFailure],
  item : @validate.ValidateValidFeatureFloorFailure,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_44_length(
  value : Array[@validate.ValidateValidFeatureFloorFailure],
) -> Int {
  value.length()
}

///|
pub fn __js_array_44_get(
  value : Array[@validate.ValidateValidFeatureFloorFailure],
  index : Int,
) -> @validate.ValidateValidFeatureFloorFailure {
  value[index]
}

///|
pub fn __js_array_45_new() -> Array[@validate.ProposalFeature] {
  Array::new()
}

///|
pub fn __js_array_45_push(
  value : Array[@validate.ProposalFeature],
  item : @validate.ProposalFeature,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_45_length(value : Array[@validate.ProposalFeature]) -> Int {
  value.length()
}

///|
pub fn __js_array_45_get(
  value : Array[@validate.ProposalFeature],
  index : Int,
) -> @validate.ProposalFeature {
  value[index]
}

///|
pub fn __js_array_46_new() -> Array[
  @validate.ValidateInvalidAstSeedPrerequisite,
] {
  Array::new()
}

///|
pub fn __js_array_46_push(
  value : Array[@validate.ValidateInvalidAstSeedPrerequisite],
  item : @validate.ValidateInvalidAstSeedPrerequisite,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_46_length(
  value : Array[@validate.ValidateInvalidAstSeedPrerequisite],
) -> Int {
  value.length()
}

///|
pub fn __js_array_46_get(
  value : Array[@validate.ValidateInvalidAstSeedPrerequisite],
  index : Int,
) -> @validate.ValidateInvalidAstSeedPrerequisite {
  value[index]
}

///|
pub fn __js_array_47_new() -> Array[@validate.GenValidConstExprAllowedOps] {
  Array::new()
}

///|
pub fn __js_array_47_push(
  value : Array[@validate.GenValidConstExprAllowedOps],
  item : @validate.GenValidConstExprAllowedOps,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_47_length(
  value : Array[@validate.GenValidConstExprAllowedOps],
) -> Int {
  value.length()
}

///|
pub fn __js_array_47_get(
  value : Array[@validate.GenValidConstExprAllowedOps],
  index : Int,
) -> @validate.GenValidConstExprAllowedOps {
  value[index]
}

///|
pub fn __js_array_48_new() -> Array[@validate.GenValidConstExprObservedOps] {
  Array::new()
}

///|
pub fn __js_array_48_push(
  value : Array[@validate.GenValidConstExprObservedOps],
  item : @validate.GenValidConstExprObservedOps,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_48_length(
  value : Array[@validate.GenValidConstExprObservedOps],
) -> Int {
  value.length()
}

///|
pub fn __js_array_48_get(
  value : Array[@validate.GenValidConstExprObservedOps],
  index : Int,
) -> @validate.GenValidConstExprObservedOps {
  value[index]
}

///|
pub fn __js_array_49_new() -> Array[@lib.Module] {
  Array::new()
}

///|
pub fn __js_array_49_push(
  value : Array[@lib.Module],
  item : @lib.Module,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_49_length(value : Array[@lib.Module]) -> Int {
  value.length()
}

///|
pub fn __js_array_49_get(
  value : Array[@lib.Module],
  index : Int,
) -> @lib.Module {
  value[index]
}

///|
pub fn __js_array_50_new() -> Array[@validate.GenValidProfileMember] {
  Array::new()
}

///|
pub fn __js_array_50_push(
  value : Array[@validate.GenValidProfileMember],
  item : @validate.GenValidProfileMember,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_50_length(
  value : Array[@validate.GenValidProfileMember],
) -> Int {
  value.length()
}

///|
pub fn __js_array_50_get(
  value : Array[@validate.GenValidProfileMember],
  index : Int,
) -> @validate.GenValidProfileMember {
  value[index]
}

///|
pub fn __js_array_51_new() -> Array[@validate.GenValidProfile] {
  Array::new()
}

///|
pub fn __js_array_51_push(
  value : Array[@validate.GenValidProfile],
  item : @validate.GenValidProfile,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_51_length(value : Array[@validate.GenValidProfile]) -> Int {
  value.length()
}

///|
pub fn __js_array_51_get(
  value : Array[@validate.GenValidProfile],
  index : Int,
) -> @validate.GenValidProfile {
  value[index]
}

///|
pub fn __js_array_52_new() -> Array[@validate.GenValidProposalFeatureGateRow] {
  Array::new()
}

///|
pub fn __js_array_52_push(
  value : Array[@validate.GenValidProposalFeatureGateRow],
  item : @validate.GenValidProposalFeatureGateRow,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_52_length(
  value : Array[@validate.GenValidProposalFeatureGateRow],
) -> Int {
  value.length()
}

///|
pub fn __js_array_52_get(
  value : Array[@validate.GenValidProposalFeatureGateRow],
  index : Int,
) -> @validate.GenValidProposalFeatureGateRow {
  value[index]
}

///|
pub fn __js_array_53_new() -> Array[@validate.GenValidProposalFeature] {
  Array::new()
}

///|
pub fn __js_array_53_push(
  value : Array[@validate.GenValidProposalFeature],
  item : @validate.GenValidProposalFeature,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_53_length(
  value : Array[@validate.GenValidProposalFeature],
) -> Int {
  value.length()
}

///|
pub fn __js_array_53_get(
  value : Array[@validate.GenValidProposalFeature],
  index : Int,
) -> @validate.GenValidProposalFeature {
  value[index]
}

///|
pub fn __js_array_54_new() -> Array[@validate.GenValidRandomStreamLabel] {
  Array::new()
}

///|
pub fn __js_array_54_push(
  value : Array[@validate.GenValidRandomStreamLabel],
  item : @validate.GenValidRandomStreamLabel,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_54_length(
  value : Array[@validate.GenValidRandomStreamLabel],
) -> Int {
  value.length()
}

///|
pub fn __js_array_54_get(
  value : Array[@validate.GenValidRandomStreamLabel],
  index : Int,
) -> @validate.GenValidRandomStreamLabel {
  value[index]
}

///|
pub fn __js_array_55_new() -> Array[(@lib.FuncIdx, @lib.Func)] {
  Array::new()
}

///|
pub fn __js_array_55_push(
  value : Array[(@lib.FuncIdx, @lib.Func)],
  item : (@lib.FuncIdx, @lib.Func),
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_55_length(value : Array[(@lib.FuncIdx, @lib.Func)]) -> Int {
  value.length()
}

///|
pub fn __js_array_55_get(
  value : Array[(@lib.FuncIdx, @lib.Func)],
  index : Int,
) -> (@lib.FuncIdx, @lib.Func) {
  value[index]
}

///|
pub fn __js_array_56_new() -> Array[(@lib.FuncIdx, String)] {
  Array::new()
}

///|
pub fn __js_array_56_push(
  value : Array[(@lib.FuncIdx, String)],
  item : (@lib.FuncIdx, String),
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_56_length(value : Array[(@lib.FuncIdx, String)]) -> Int {
  value.length()
}

///|
pub fn __js_array_56_get(
  value : Array[(@lib.FuncIdx, String)],
  index : Int,
) -> (@lib.FuncIdx, String) {
  value[index]
}

///|
pub fn __js_array_57_new() -> Array[@validate.ValidateInvalidAstStrategySpec] {
  Array::new()
}

///|
pub fn __js_array_57_push(
  value : Array[@validate.ValidateInvalidAstStrategySpec],
  item : @validate.ValidateInvalidAstStrategySpec,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_57_length(
  value : Array[@validate.ValidateInvalidAstStrategySpec],
) -> Int {
  value.length()
}

///|
pub fn __js_array_57_get(
  value : Array[@validate.ValidateInvalidAstStrategySpec],
  index : Int,
) -> @validate.ValidateInvalidAstStrategySpec {
  value[index]
}

///|
pub fn __js_array_58_new() -> Array[@validate.ValidateValidFeatureLedgerEntry] {
  Array::new()
}

///|
pub fn __js_array_58_push(
  value : Array[@validate.ValidateValidFeatureLedgerEntry],
  item : @validate.ValidateValidFeatureLedgerEntry,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_58_length(
  value : Array[@validate.ValidateValidFeatureLedgerEntry],
) -> Int {
  value.length()
}

///|
pub fn __js_array_58_get(
  value : Array[@validate.ValidateValidFeatureLedgerEntry],
  index : Int,
) -> @validate.ValidateValidFeatureLedgerEntry {
  value[index]
}

///|
pub fn __js_array_59_new() -> Array[@lib.FuncType] {
  Array::new()
}

///|
pub fn __js_array_59_push(
  value : Array[@lib.FuncType],
  item : @lib.FuncType,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_59_length(value : Array[@lib.FuncType]) -> Int {
  value.length()
}

///|
pub fn __js_array_59_get(
  value : Array[@lib.FuncType],
  index : Int,
) -> @lib.FuncType {
  value[index]
}

///|
pub fn __js_array_60_new() -> Array[@lib.TypeIdx?] {
  Array::new()
}

///|
pub fn __js_array_60_push(
  value : Array[@lib.TypeIdx?],
  item : @lib.TypeIdx?,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_60_length(value : Array[@lib.TypeIdx?]) -> Int {
  value.length()
}

///|
pub fn __js_array_60_get(
  value : Array[@lib.TypeIdx?],
  index : Int,
) -> @lib.TypeIdx? {
  value[index]
}

///|
pub fn __js_array_61_new() -> Array[@lib.GlobalType] {
  Array::new()
}

///|
pub fn __js_array_61_push(
  value : Array[@lib.GlobalType],
  item : @lib.GlobalType,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_61_length(value : Array[@lib.GlobalType]) -> Int {
  value.length()
}

///|
pub fn __js_array_61_get(
  value : Array[@lib.GlobalType],
  index : Int,
) -> @lib.GlobalType {
  value[index]
}

///|
pub fn __js_array_62_new() -> Array[Array[@lib.ValType]] {
  Array::new()
}

///|
pub fn __js_array_62_push(
  value : Array[Array[@lib.ValType]],
  item : Array[@lib.ValType],
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_62_length(value : Array[Array[@lib.ValType]]) -> Int {
  value.length()
}

///|
pub fn __js_array_62_get(
  value : Array[Array[@lib.ValType]],
  index : Int,
) -> Array[@lib.ValType] {
  value[index]
}

///|
pub fn __js_array_63_new() -> Array[@lib.TableType] {
  Array::new()
}

///|
pub fn __js_array_63_push(
  value : Array[@lib.TableType],
  item : @lib.TableType,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_63_length(value : Array[@lib.TableType]) -> Int {
  value.length()
}

///|
pub fn __js_array_63_get(
  value : Array[@lib.TableType],
  index : Int,
) -> @lib.TableType {
  value[index]
}

///|
pub fn __js_array_64_new() -> Array[@wast.ModuleField] {
  Array::new()
}

///|
pub fn __js_array_64_push(
  value : Array[@wast.ModuleField],
  item : @wast.ModuleField,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_64_length(value : Array[@wast.ModuleField]) -> Int {
  value.length()
}

///|
pub fn __js_array_64_get(
  value : Array[@wast.ModuleField],
  index : Int,
) -> @wast.ModuleField {
  value[index]
}

///|
pub fn __js_array_65_new() -> Array[@wast.LexerError] {
  Array::new()
}

///|
pub fn __js_array_65_push(
  value : Array[@wast.LexerError],
  item : @wast.LexerError,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_65_length(value : Array[@wast.LexerError]) -> Int {
  value.length()
}

///|
pub fn __js_array_65_get(
  value : Array[@wast.LexerError],
  index : Int,
) -> @wast.LexerError {
  value[index]
}

///|
pub fn __js_array_66_new() -> Array[@wast.ParseError] {
  Array::new()
}

///|
pub fn __js_array_66_push(
  value : Array[@wast.ParseError],
  item : @wast.ParseError,
) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_66_length(value : Array[@wast.ParseError]) -> Int {
  value.length()
}

///|
pub fn __js_array_66_get(
  value : Array[@wast.ParseError],
  index : Int,
) -> @wast.ParseError {
  value[index]
}

///|
pub fn __js_array_67_new() -> Array[Byte] {
  Array::new()
}

///|
pub fn __js_array_67_push(value : Array[Byte], item : Byte) -> Unit {
  value.push(item)
}

///|
pub fn __js_array_67_length(value : Array[Byte]) -> Int {
  value.length()
}

///|
pub fn __js_array_67_get(value : Array[Byte], index : Int) -> Byte {
  value[index]
}

///|
pub fn __js_option_1_none() -> Array[Bytes]?? {
  None
}

///|
pub fn __js_option_1_some(value : Array[Bytes]?) -> Array[Bytes]?? {
  Some(value)
}

///|
pub fn __js_option_1_is_some(value : Array[Bytes]??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_1_unwrap(value : Array[Bytes]??) -> Array[Bytes]? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_2_none() -> Array[Bytes]? {
  None
}

///|
pub fn __js_option_2_some(value : Array[Bytes]) -> Array[Bytes]? {
  Some(value)
}

///|
pub fn __js_option_2_is_some(value : Array[Bytes]?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_2_unwrap(value : Array[Bytes]?) -> Array[Bytes] {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_3_none() -> Bool? {
  None
}

///|
pub fn __js_option_3_some(value : Bool) -> Bool? {
  Some(value)
}

///|
pub fn __js_option_3_is_some(value : Bool?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_3_unwrap(value : Bool?) -> Bool {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_4_none() -> @cli.CliInputFormat? {
  None
}

///|
pub fn __js_option_4_some(value : @cli.CliInputFormat) -> @cli.CliInputFormat? {
  Some(value)
}

///|
pub fn __js_option_4_is_some(value : @cli.CliInputFormat?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_4_unwrap(
  value : @cli.CliInputFormat?,
) -> @cli.CliInputFormat {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_5_none() -> String?? {
  None
}

///|
pub fn __js_option_5_some(value : String?) -> String?? {
  Some(value)
}

///|
pub fn __js_option_5_is_some(value : String??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_5_unwrap(value : String??) -> String? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_6_none() -> String? {
  None
}

///|
pub fn __js_option_6_some(value : String) -> String? {
  Some(value)
}

///|
pub fn __js_option_6_is_some(value : String?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_6_unwrap(value : String?) -> String {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_7_none() -> Array[String]? {
  None
}

///|
pub fn __js_option_7_some(value : Array[String]) -> Array[String]? {
  Some(value)
}

///|
pub fn __js_option_7_is_some(value : Array[String]?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_7_unwrap(value : Array[String]?) -> Array[String] {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_8_none() -> @cli.CliInputFormat?? {
  None
}

///|
pub fn __js_option_8_some(
  value : @cli.CliInputFormat?,
) -> @cli.CliInputFormat?? {
  Some(value)
}

///|
pub fn __js_option_8_is_some(value : @cli.CliInputFormat??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_8_unwrap(
  value : @cli.CliInputFormat??,
) -> @cli.CliInputFormat? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_9_none() -> Array[@cli.CliOutputTarget]? {
  None
}

///|
pub fn __js_option_9_some(
  value : Array[@cli.CliOutputTarget],
) -> Array[@cli.CliOutputTarget]? {
  Some(value)
}

///|
pub fn __js_option_9_is_some(value : Array[@cli.CliOutputTarget]?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_9_unwrap(
  value : Array[@cli.CliOutputTarget]?,
) -> Array[@cli.CliOutputTarget] {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_10_none() -> Array[@cli.CliOptimizationFlag]? {
  None
}

///|
pub fn __js_option_10_some(
  value : Array[@cli.CliOptimizationFlag],
) -> Array[@cli.CliOptimizationFlag]? {
  Some(value)
}

///|
pub fn __js_option_10_is_some(value : Array[@cli.CliOptimizationFlag]?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_10_unwrap(
  value : Array[@cli.CliOptimizationFlag]?,
) -> Array[@cli.CliOptimizationFlag] {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_11_none() -> @cli.TrapMode?? {
  None
}

///|
pub fn __js_option_11_some(value : @cli.TrapMode?) -> @cli.TrapMode?? {
  Some(value)
}

///|
pub fn __js_option_11_is_some(value : @cli.TrapMode??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_11_unwrap(value : @cli.TrapMode??) -> @cli.TrapMode? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_12_none() -> @cli.TrapMode? {
  None
}

///|
pub fn __js_option_12_some(value : @cli.TrapMode) -> @cli.TrapMode? {
  Some(value)
}

///|
pub fn __js_option_12_is_some(value : @cli.TrapMode?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_12_unwrap(value : @cli.TrapMode?) -> @cli.TrapMode {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_13_none() -> Int?? {
  None
}

///|
pub fn __js_option_13_some(value : Int?) -> Int?? {
  Some(value)
}

///|
pub fn __js_option_13_is_some(value : Int??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_13_unwrap(value : Int??) -> Int? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_14_none() -> Int? {
  None
}

///|
pub fn __js_option_14_some(value : Int) -> Int? {
  Some(value)
}

///|
pub fn __js_option_14_is_some(value : Int?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_14_unwrap(value : Int?) -> Int {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_15_none() -> Bool?? {
  None
}

///|
pub fn __js_option_15_some(value : Bool?) -> Bool?? {
  Some(value)
}

///|
pub fn __js_option_15_is_some(value : Bool??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_15_unwrap(value : Bool??) -> Bool? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_16_none() -> UInt64?? {
  None
}

///|
pub fn __js_option_16_some(value : UInt64?) -> UInt64?? {
  Some(value)
}

///|
pub fn __js_option_16_is_some(value : UInt64??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_16_unwrap(value : UInt64??) -> UInt64? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_17_none() -> UInt64? {
  None
}

///|
pub fn __js_option_17_some(value : UInt64) -> UInt64? {
  Some(value)
}

///|
pub fn __js_option_17_is_some(value : UInt64?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_17_unwrap(value : UInt64?) -> UInt64 {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_18_none() -> @cli.CliTracingLevel?? {
  None
}

///|
pub fn __js_option_18_some(
  value : @cli.CliTracingLevel?,
) -> @cli.CliTracingLevel?? {
  Some(value)
}

///|
pub fn __js_option_18_is_some(value : @cli.CliTracingLevel??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_18_unwrap(
  value : @cli.CliTracingLevel??,
) -> @cli.CliTracingLevel? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_19_none() -> @cli.CliTracingLevel? {
  None
}

///|
pub fn __js_option_19_some(
  value : @cli.CliTracingLevel,
) -> @cli.CliTracingLevel? {
  Some(value)
}

///|
pub fn __js_option_19_is_some(value : @cli.CliTracingLevel?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_19_unwrap(
  value : @cli.CliTracingLevel?,
) -> @cli.CliTracingLevel {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_20_none() -> @cmd.DifferentialAdapters? {
  None
}

///|
pub fn __js_option_20_some(
  value : @cmd.DifferentialAdapters,
) -> @cmd.DifferentialAdapters? {
  Some(value)
}

///|
pub fn __js_option_20_is_some(value : @cmd.DifferentialAdapters?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_20_unwrap(
  value : @cmd.DifferentialAdapters?,
) -> @cmd.DifferentialAdapters {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_21_none() -> Array[@cmd.BinaryDifferentialSmokeAdapter]? {
  None
}

///|
pub fn __js_option_21_some(
  value : Array[@cmd.BinaryDifferentialSmokeAdapter],
) -> Array[@cmd.BinaryDifferentialSmokeAdapter]? {
  Some(value)
}

///|
pub fn __js_option_21_is_some(
  value : Array[@cmd.BinaryDifferentialSmokeAdapter]?,
) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_21_unwrap(
  value : Array[@cmd.BinaryDifferentialSmokeAdapter]?,
) -> Array[@cmd.BinaryDifferentialSmokeAdapter] {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_22_none() -> Bytes?? {
  None
}

///|
pub fn __js_option_22_some(value : Bytes?) -> Bytes?? {
  Some(value)
}

///|
pub fn __js_option_22_is_some(value : Bytes??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_22_unwrap(value : Bytes??) -> Bytes? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_23_none() -> Bytes? {
  None
}

///|
pub fn __js_option_23_some(value : Bytes) -> Bytes? {
  Some(value)
}

///|
pub fn __js_option_23_is_some(value : Bytes?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_23_unwrap(value : Bytes?) -> Bytes {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_24_none() -> Array[@cmd.FuzzReductionStep]? {
  None
}

///|
pub fn __js_option_24_some(
  value : Array[@cmd.FuzzReductionStep],
) -> Array[@cmd.FuzzReductionStep]? {
  Some(value)
}

///|
pub fn __js_option_24_is_some(value : Array[@cmd.FuzzReductionStep]?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_24_unwrap(
  value : Array[@cmd.FuzzReductionStep]?,
) -> Array[@cmd.FuzzReductionStep] {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_25_none() -> @cmd.InliningOptions? {
  None
}

///|
pub fn __js_option_25_some(
  value : @cmd.InliningOptions,
) -> @cmd.InliningOptions? {
  Some(value)
}

///|
pub fn __js_option_25_is_some(value : @cmd.InliningOptions?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_25_unwrap(
  value : @cmd.InliningOptions?,
) -> @cmd.InliningOptions {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_26_none() -> @passes.CompilerFactUsePolicy? {
  None
}

///|
pub fn __js_option_26_some(
  value : @passes.CompilerFactUsePolicy,
) -> @passes.CompilerFactUsePolicy? {
  Some(value)
}

///|
pub fn __js_option_26_is_some(value : @passes.CompilerFactUsePolicy?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_26_unwrap(
  value : @passes.CompilerFactUsePolicy?,
) -> @passes.CompilerFactUsePolicy {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_27_none() -> @cmd.OptimizeValidationPolicy? {
  None
}

///|
pub fn __js_option_27_some(
  value : @cmd.OptimizeValidationPolicy,
) -> @cmd.OptimizeValidationPolicy? {
  Some(value)
}

///|
pub fn __js_option_27_is_some(value : @cmd.OptimizeValidationPolicy?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_27_unwrap(
  value : @cmd.OptimizeValidationPolicy?,
) -> @cmd.OptimizeValidationPolicy {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_28_none() -> @lib.TypeMetadata? {
  None
}

///|
pub fn __js_option_28_some(value : @lib.TypeMetadata) -> @lib.TypeMetadata? {
  Some(value)
}

///|
pub fn __js_option_28_is_some(value : @lib.TypeMetadata?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_28_unwrap(value : @lib.TypeMetadata?) -> @lib.TypeMetadata {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_29_none() -> @lib.SubType? {
  None
}

///|
pub fn __js_option_29_some(value : @lib.SubType) -> @lib.SubType? {
  Some(value)
}

///|
pub fn __js_option_29_is_some(value : @lib.SubType?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_29_unwrap(value : @lib.SubType?) -> @lib.SubType {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_30_none() -> @lib.ValType? {
  None
}

///|
pub fn __js_option_30_some(value : @lib.ValType) -> @lib.ValType? {
  Some(value)
}

///|
pub fn __js_option_30_is_some(value : @lib.ValType?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_30_unwrap(value : @lib.ValType?) -> @lib.ValType {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_31_none() -> @lib.AtomicOrder? {
  None
}

///|
pub fn __js_option_31_some(value : @lib.AtomicOrder) -> @lib.AtomicOrder? {
  Some(value)
}

///|
pub fn __js_option_31_is_some(value : @lib.AtomicOrder?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_31_unwrap(value : @lib.AtomicOrder?) -> @lib.AtomicOrder {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_32_none() -> @lib.MemArg? {
  None
}

///|
pub fn __js_option_32_some(value : @lib.MemArg) -> @lib.MemArg? {
  Some(value)
}

///|
pub fn __js_option_32_is_some(value : @lib.MemArg?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_32_unwrap(value : @lib.MemArg?) -> @lib.MemArg {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_33_none() -> Array[@lib.Instruction]? {
  None
}

///|
pub fn __js_option_33_some(
  value : Array[@lib.Instruction],
) -> Array[@lib.Instruction]? {
  Some(value)
}

///|
pub fn __js_option_33_is_some(value : Array[@lib.Instruction]?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_33_unwrap(
  value : Array[@lib.Instruction]?,
) -> Array[@lib.Instruction] {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_34_none() -> Array[@lib.ValType]?? {
  None
}

///|
pub fn __js_option_34_some(
  value : Array[@lib.ValType]?,
) -> Array[@lib.ValType]?? {
  Some(value)
}

///|
pub fn __js_option_34_is_some(value : Array[@lib.ValType]??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_34_unwrap(
  value : Array[@lib.ValType]??,
) -> Array[@lib.ValType]? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_35_none() -> Array[@lib.ValType]? {
  None
}

///|
pub fn __js_option_35_some(value : Array[@lib.ValType]) -> Array[@lib.ValType]? {
  Some(value)
}

///|
pub fn __js_option_35_is_some(value : Array[@lib.ValType]?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_35_unwrap(
  value : Array[@lib.ValType]?,
) -> Array[@lib.ValType] {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_36_none() -> @lib.LabelIdx?? {
  None
}

///|
pub fn __js_option_36_some(value : @lib.LabelIdx?) -> @lib.LabelIdx?? {
  Some(value)
}

///|
pub fn __js_option_36_is_some(value : @lib.LabelIdx??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_36_unwrap(value : @lib.LabelIdx??) -> @lib.LabelIdx? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_37_none() -> @lib.LabelIdx? {
  None
}

///|
pub fn __js_option_37_some(value : @lib.LabelIdx) -> @lib.LabelIdx? {
  Some(value)
}

///|
pub fn __js_option_37_is_some(value : @lib.LabelIdx?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_37_unwrap(value : @lib.LabelIdx?) -> @lib.LabelIdx {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_38_none() -> @lib.LocalRun? {
  None
}

///|
pub fn __js_option_38_some(value : @lib.LocalRun) -> @lib.LocalRun? {
  Some(value)
}

///|
pub fn __js_option_38_is_some(value : @lib.LocalRun?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_38_unwrap(value : @lib.LocalRun?) -> @lib.LocalRun {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_39_none() -> @lib.MemIdx? {
  None
}

///|
pub fn __js_option_39_some(value : @lib.MemIdx) -> @lib.MemIdx? {
  Some(value)
}

///|
pub fn __js_option_39_is_some(value : @lib.MemIdx?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_39_unwrap(value : @lib.MemIdx?) -> @lib.MemIdx {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_40_none() -> Array[@lib.CustomSec]? {
  None
}

///|
pub fn __js_option_40_some(
  value : Array[@lib.CustomSec],
) -> Array[@lib.CustomSec]? {
  Some(value)
}

///|
pub fn __js_option_40_is_some(value : Array[@lib.CustomSec]?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_40_unwrap(
  value : Array[@lib.CustomSec]?,
) -> Array[@lib.CustomSec] {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_41_none() -> @lib.TypeSec?? {
  None
}

///|
pub fn __js_option_41_some(value : @lib.TypeSec?) -> @lib.TypeSec?? {
  Some(value)
}

///|
pub fn __js_option_41_is_some(value : @lib.TypeSec??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_41_unwrap(value : @lib.TypeSec??) -> @lib.TypeSec? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_42_none() -> @lib.TypeSec? {
  None
}

///|
pub fn __js_option_42_some(value : @lib.TypeSec) -> @lib.TypeSec? {
  Some(value)
}

///|
pub fn __js_option_42_is_some(value : @lib.TypeSec?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_42_unwrap(value : @lib.TypeSec?) -> @lib.TypeSec {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_43_none() -> @lib.ImportSec?? {
  None
}

///|
pub fn __js_option_43_some(value : @lib.ImportSec?) -> @lib.ImportSec?? {
  Some(value)
}

///|
pub fn __js_option_43_is_some(value : @lib.ImportSec??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_43_unwrap(value : @lib.ImportSec??) -> @lib.ImportSec? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_44_none() -> @lib.ImportSec? {
  None
}

///|
pub fn __js_option_44_some(value : @lib.ImportSec) -> @lib.ImportSec? {
  Some(value)
}

///|
pub fn __js_option_44_is_some(value : @lib.ImportSec?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_44_unwrap(value : @lib.ImportSec?) -> @lib.ImportSec {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_45_none() -> @lib.FuncAnnotationSec?? {
  None
}

///|
pub fn __js_option_45_some(
  value : @lib.FuncAnnotationSec?,
) -> @lib.FuncAnnotationSec?? {
  Some(value)
}

///|
pub fn __js_option_45_is_some(value : @lib.FuncAnnotationSec??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_45_unwrap(
  value : @lib.FuncAnnotationSec??,
) -> @lib.FuncAnnotationSec? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_46_none() -> @lib.FuncAnnotationSec? {
  None
}

///|
pub fn __js_option_46_some(
  value : @lib.FuncAnnotationSec,
) -> @lib.FuncAnnotationSec? {
  Some(value)
}

///|
pub fn __js_option_46_is_some(value : @lib.FuncAnnotationSec?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_46_unwrap(
  value : @lib.FuncAnnotationSec?,
) -> @lib.FuncAnnotationSec {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_47_none() -> @lib.FuncSec?? {
  None
}

///|
pub fn __js_option_47_some(value : @lib.FuncSec?) -> @lib.FuncSec?? {
  Some(value)
}

///|
pub fn __js_option_47_is_some(value : @lib.FuncSec??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_47_unwrap(value : @lib.FuncSec??) -> @lib.FuncSec? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_48_none() -> @lib.FuncSec? {
  None
}

///|
pub fn __js_option_48_some(value : @lib.FuncSec) -> @lib.FuncSec? {
  Some(value)
}

///|
pub fn __js_option_48_is_some(value : @lib.FuncSec?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_48_unwrap(value : @lib.FuncSec?) -> @lib.FuncSec {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_49_none() -> @lib.TableSec?? {
  None
}

///|
pub fn __js_option_49_some(value : @lib.TableSec?) -> @lib.TableSec?? {
  Some(value)
}

///|
pub fn __js_option_49_is_some(value : @lib.TableSec??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_49_unwrap(value : @lib.TableSec??) -> @lib.TableSec? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_50_none() -> @lib.TableSec? {
  None
}

///|
pub fn __js_option_50_some(value : @lib.TableSec) -> @lib.TableSec? {
  Some(value)
}

///|
pub fn __js_option_50_is_some(value : @lib.TableSec?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_50_unwrap(value : @lib.TableSec?) -> @lib.TableSec {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_51_none() -> @lib.MemSec?? {
  None
}

///|
pub fn __js_option_51_some(value : @lib.MemSec?) -> @lib.MemSec?? {
  Some(value)
}

///|
pub fn __js_option_51_is_some(value : @lib.MemSec??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_51_unwrap(value : @lib.MemSec??) -> @lib.MemSec? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_52_none() -> @lib.MemSec? {
  None
}

///|
pub fn __js_option_52_some(value : @lib.MemSec) -> @lib.MemSec? {
  Some(value)
}

///|
pub fn __js_option_52_is_some(value : @lib.MemSec?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_52_unwrap(value : @lib.MemSec?) -> @lib.MemSec {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_53_none() -> @lib.TagSec?? {
  None
}

///|
pub fn __js_option_53_some(value : @lib.TagSec?) -> @lib.TagSec?? {
  Some(value)
}

///|
pub fn __js_option_53_is_some(value : @lib.TagSec??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_53_unwrap(value : @lib.TagSec??) -> @lib.TagSec? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_54_none() -> @lib.TagSec? {
  None
}

///|
pub fn __js_option_54_some(value : @lib.TagSec) -> @lib.TagSec? {
  Some(value)
}

///|
pub fn __js_option_54_is_some(value : @lib.TagSec?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_54_unwrap(value : @lib.TagSec?) -> @lib.TagSec {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_55_none() -> @lib.GlobalSec?? {
  None
}

///|
pub fn __js_option_55_some(value : @lib.GlobalSec?) -> @lib.GlobalSec?? {
  Some(value)
}

///|
pub fn __js_option_55_is_some(value : @lib.GlobalSec??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_55_unwrap(value : @lib.GlobalSec??) -> @lib.GlobalSec? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_56_none() -> @lib.GlobalSec? {
  None
}

///|
pub fn __js_option_56_some(value : @lib.GlobalSec) -> @lib.GlobalSec? {
  Some(value)
}

///|
pub fn __js_option_56_is_some(value : @lib.GlobalSec?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_56_unwrap(value : @lib.GlobalSec?) -> @lib.GlobalSec {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_57_none() -> @lib.ExportSec?? {
  None
}

///|
pub fn __js_option_57_some(value : @lib.ExportSec?) -> @lib.ExportSec?? {
  Some(value)
}

///|
pub fn __js_option_57_is_some(value : @lib.ExportSec??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_57_unwrap(value : @lib.ExportSec??) -> @lib.ExportSec? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_58_none() -> @lib.ExportSec? {
  None
}

///|
pub fn __js_option_58_some(value : @lib.ExportSec) -> @lib.ExportSec? {
  Some(value)
}

///|
pub fn __js_option_58_is_some(value : @lib.ExportSec?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_58_unwrap(value : @lib.ExportSec?) -> @lib.ExportSec {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_59_none() -> @lib.StartSec?? {
  None
}

///|
pub fn __js_option_59_some(value : @lib.StartSec?) -> @lib.StartSec?? {
  Some(value)
}

///|
pub fn __js_option_59_is_some(value : @lib.StartSec??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_59_unwrap(value : @lib.StartSec??) -> @lib.StartSec? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_60_none() -> @lib.StartSec? {
  None
}

///|
pub fn __js_option_60_some(value : @lib.StartSec) -> @lib.StartSec? {
  Some(value)
}

///|
pub fn __js_option_60_is_some(value : @lib.StartSec?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_60_unwrap(value : @lib.StartSec?) -> @lib.StartSec {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_61_none() -> @lib.ElemSec?? {
  None
}

///|
pub fn __js_option_61_some(value : @lib.ElemSec?) -> @lib.ElemSec?? {
  Some(value)
}

///|
pub fn __js_option_61_is_some(value : @lib.ElemSec??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_61_unwrap(value : @lib.ElemSec??) -> @lib.ElemSec? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_62_none() -> @lib.ElemSec? {
  None
}

///|
pub fn __js_option_62_some(value : @lib.ElemSec) -> @lib.ElemSec? {
  Some(value)
}

///|
pub fn __js_option_62_is_some(value : @lib.ElemSec?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_62_unwrap(value : @lib.ElemSec?) -> @lib.ElemSec {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_63_none() -> @lib.DataCntSec?? {
  None
}

///|
pub fn __js_option_63_some(value : @lib.DataCntSec?) -> @lib.DataCntSec?? {
  Some(value)
}

///|
pub fn __js_option_63_is_some(value : @lib.DataCntSec??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_63_unwrap(value : @lib.DataCntSec??) -> @lib.DataCntSec? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_64_none() -> @lib.DataCntSec? {
  None
}

///|
pub fn __js_option_64_some(value : @lib.DataCntSec) -> @lib.DataCntSec? {
  Some(value)
}

///|
pub fn __js_option_64_is_some(value : @lib.DataCntSec?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_64_unwrap(value : @lib.DataCntSec?) -> @lib.DataCntSec {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_65_none() -> @lib.CodeSec?? {
  None
}

///|
pub fn __js_option_65_some(value : @lib.CodeSec?) -> @lib.CodeSec?? {
  Some(value)
}

///|
pub fn __js_option_65_is_some(value : @lib.CodeSec??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_65_unwrap(value : @lib.CodeSec??) -> @lib.CodeSec? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_66_none() -> @lib.CodeSec? {
  None
}

///|
pub fn __js_option_66_some(value : @lib.CodeSec) -> @lib.CodeSec? {
  Some(value)
}

///|
pub fn __js_option_66_is_some(value : @lib.CodeSec?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_66_unwrap(value : @lib.CodeSec?) -> @lib.CodeSec {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_67_none() -> @lib.DataSec?? {
  None
}

///|
pub fn __js_option_67_some(value : @lib.DataSec?) -> @lib.DataSec?? {
  Some(value)
}

///|
pub fn __js_option_67_is_some(value : @lib.DataSec??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_67_unwrap(value : @lib.DataSec??) -> @lib.DataSec? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_68_none() -> @lib.DataSec? {
  None
}

///|
pub fn __js_option_68_some(value : @lib.DataSec) -> @lib.DataSec? {
  Some(value)
}

///|
pub fn __js_option_68_is_some(value : @lib.DataSec?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_68_unwrap(value : @lib.DataSec?) -> @lib.DataSec {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_69_none() -> @lib.StringRefsSec?? {
  None
}

///|
pub fn __js_option_69_some(value : @lib.StringRefsSec?) -> @lib.StringRefsSec?? {
  Some(value)
}

///|
pub fn __js_option_69_is_some(value : @lib.StringRefsSec??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_69_unwrap(
  value : @lib.StringRefsSec??,
) -> @lib.StringRefsSec? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_70_none() -> @lib.StringRefsSec? {
  None
}

///|
pub fn __js_option_70_some(value : @lib.StringRefsSec) -> @lib.StringRefsSec? {
  Some(value)
}

///|
pub fn __js_option_70_is_some(value : @lib.StringRefsSec?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_70_unwrap(value : @lib.StringRefsSec?) -> @lib.StringRefsSec {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_71_none() -> @lib.NameSec?? {
  None
}

///|
pub fn __js_option_71_some(value : @lib.NameSec?) -> @lib.NameSec?? {
  Some(value)
}

///|
pub fn __js_option_71_is_some(value : @lib.NameSec??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_71_unwrap(value : @lib.NameSec??) -> @lib.NameSec? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_72_none() -> @lib.NameSec? {
  None
}

///|
pub fn __js_option_72_some(value : @lib.NameSec) -> @lib.NameSec? {
  Some(value)
}

///|
pub fn __js_option_72_is_some(value : @lib.NameSec?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_72_unwrap(value : @lib.NameSec?) -> @lib.NameSec {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_73_none() -> @representation.CompilerFactCustomSection?? {
  None
}

///|
pub fn __js_option_73_some(
  value : @representation.CompilerFactCustomSection?,
) -> @representation.CompilerFactCustomSection?? {
  Some(value)
}

///|
pub fn __js_option_73_is_some(
  value : @representation.CompilerFactCustomSection??,
) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_73_unwrap(
  value : @representation.CompilerFactCustomSection??,
) -> @representation.CompilerFactCustomSection? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_74_none() -> @representation.CompilerFactCustomSection? {
  None
}

///|
pub fn __js_option_74_some(
  value : @representation.CompilerFactCustomSection,
) -> @representation.CompilerFactCustomSection? {
  Some(value)
}

///|
pub fn __js_option_74_is_some(
  value : @representation.CompilerFactCustomSection?,
) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_74_unwrap(
  value : @representation.CompilerFactCustomSection?,
) -> @representation.CompilerFactCustomSection {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_75_none() -> @lib.Name?? {
  None
}

///|
pub fn __js_option_75_some(value : @lib.Name?) -> @lib.Name?? {
  Some(value)
}

///|
pub fn __js_option_75_is_some(value : @lib.Name??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_75_unwrap(value : @lib.Name??) -> @lib.Name? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_76_none() -> @lib.Name? {
  None
}

///|
pub fn __js_option_76_some(value : @lib.Name) -> @lib.Name? {
  Some(value)
}

///|
pub fn __js_option_76_is_some(value : @lib.Name?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_76_unwrap(value : @lib.Name?) -> @lib.Name {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_77_none() -> @lib.NameMap?? {
  None
}

///|
pub fn __js_option_77_some(value : @lib.NameMap?) -> @lib.NameMap?? {
  Some(value)
}

///|
pub fn __js_option_77_is_some(value : @lib.NameMap??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_77_unwrap(value : @lib.NameMap??) -> @lib.NameMap? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_78_none() -> @lib.NameMap? {
  None
}

///|
pub fn __js_option_78_some(value : @lib.NameMap) -> @lib.NameMap? {
  Some(value)
}

///|
pub fn __js_option_78_is_some(value : @lib.NameMap?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_78_unwrap(value : @lib.NameMap?) -> @lib.NameMap {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_79_none() -> @lib.IndirectNameMap?? {
  None
}

///|
pub fn __js_option_79_some(
  value : @lib.IndirectNameMap?,
) -> @lib.IndirectNameMap?? {
  Some(value)
}

///|
pub fn __js_option_79_is_some(value : @lib.IndirectNameMap??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_79_unwrap(
  value : @lib.IndirectNameMap??,
) -> @lib.IndirectNameMap? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_80_none() -> @lib.IndirectNameMap? {
  None
}

///|
pub fn __js_option_80_some(
  value : @lib.IndirectNameMap,
) -> @lib.IndirectNameMap? {
  Some(value)
}

///|
pub fn __js_option_80_is_some(value : @lib.IndirectNameMap?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_80_unwrap(
  value : @lib.IndirectNameMap?,
) -> @lib.IndirectNameMap {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_81_none() -> @lib.TabsOrSpaces? {
  None
}

///|
pub fn __js_option_81_some(value : @lib.TabsOrSpaces) -> @lib.TabsOrSpaces? {
  Some(value)
}

///|
pub fn __js_option_81_is_some(value : @lib.TabsOrSpaces?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_81_unwrap(value : @lib.TabsOrSpaces?) -> @lib.TabsOrSpaces {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_82_none() -> @lib.TypeIdx? {
  None
}

///|
pub fn __js_option_82_some(value : @lib.TypeIdx) -> @lib.TypeIdx? {
  Some(value)
}

///|
pub fn __js_option_82_is_some(value : @lib.TypeIdx?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_82_unwrap(value : @lib.TypeIdx?) -> @lib.TypeIdx {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_83_none() -> @lib.Expr? {
  None
}

///|
pub fn __js_option_83_some(value : @lib.Expr) -> @lib.Expr? {
  Some(value)
}

///|
pub fn __js_option_83_is_some(value : @lib.Expr?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_83_unwrap(value : @lib.Expr?) -> @lib.Expr {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_84_none() -> @lib.TypeIdx?? {
  None
}

///|
pub fn __js_option_84_some(value : @lib.TypeIdx?) -> @lib.TypeIdx?? {
  Some(value)
}

///|
pub fn __js_option_84_is_some(value : @lib.TypeIdx??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_84_unwrap(value : @lib.TypeIdx??) -> @lib.TypeIdx? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_85_none() -> @validate.ProposalFeature? {
  None
}

///|
pub fn __js_option_85_some(
  value : @validate.ProposalFeature,
) -> @validate.ProposalFeature? {
  Some(value)
}

///|
pub fn __js_option_85_is_some(value : @validate.ProposalFeature?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_85_unwrap(
  value : @validate.ProposalFeature?,
) -> @validate.ProposalFeature {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_86_none() -> @validate.ValidateInvalidAstStrategySpec? {
  None
}

///|
pub fn __js_option_86_some(
  value : @validate.ValidateInvalidAstStrategySpec,
) -> @validate.ValidateInvalidAstStrategySpec? {
  Some(value)
}

///|
pub fn __js_option_86_is_some(
  value : @validate.ValidateInvalidAstStrategySpec?,
) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_86_unwrap(
  value : @validate.ValidateInvalidAstStrategySpec?,
) -> @validate.ValidateInvalidAstStrategySpec {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_87_none() -> Array[@validate.ProposalFeature]? {
  None
}

///|
pub fn __js_option_87_some(
  value : Array[@validate.ProposalFeature],
) -> Array[@validate.ProposalFeature]? {
  Some(value)
}

///|
pub fn __js_option_87_is_some(
  value : Array[@validate.ProposalFeature]?,
) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_87_unwrap(
  value : Array[@validate.ProposalFeature]?,
) -> Array[@validate.ProposalFeature] {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_88_none() -> @lib.FuncIdx? {
  None
}

///|
pub fn __js_option_88_some(value : @lib.FuncIdx) -> @lib.FuncIdx? {
  Some(value)
}

///|
pub fn __js_option_88_is_some(value : @lib.FuncIdx?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_88_unwrap(value : @lib.FuncIdx?) -> @lib.FuncIdx {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_89_none() -> @lib.RefType? {
  None
}

///|
pub fn __js_option_89_some(value : @lib.RefType) -> @lib.RefType? {
  Some(value)
}

///|
pub fn __js_option_89_is_some(value : @lib.RefType?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_89_unwrap(value : @lib.RefType?) -> @lib.RefType {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_90_none() -> @lib.Elem? {
  None
}

///|
pub fn __js_option_90_some(value : @lib.Elem) -> @lib.Elem? {
  Some(value)
}

///|
pub fn __js_option_90_is_some(value : @lib.Elem?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_90_unwrap(value : @lib.Elem?) -> @lib.Elem {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_91_none() -> @lib.FuncType? {
  None
}

///|
pub fn __js_option_91_some(value : @lib.FuncType) -> @lib.FuncType? {
  Some(value)
}

///|
pub fn __js_option_91_is_some(value : @lib.FuncType?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_91_unwrap(value : @lib.FuncType?) -> @lib.FuncType {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_92_none() -> @lib.GlobalType? {
  None
}

///|
pub fn __js_option_92_some(value : @lib.GlobalType) -> @lib.GlobalType? {
  Some(value)
}

///|
pub fn __js_option_92_is_some(value : @lib.GlobalType?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_92_unwrap(value : @lib.GlobalType?) -> @lib.GlobalType {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_93_none() -> @lib.MemType? {
  None
}

///|
pub fn __js_option_93_some(value : @lib.MemType) -> @lib.MemType? {
  Some(value)
}

///|
pub fn __js_option_93_is_some(value : @lib.MemType?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_93_unwrap(value : @lib.MemType?) -> @lib.MemType {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_94_none() -> @lib.TableType? {
  None
}

///|
pub fn __js_option_94_some(value : @lib.TableType) -> @lib.TableType? {
  Some(value)
}

///|
pub fn __js_option_94_is_some(value : @lib.TableType?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_94_unwrap(value : @lib.TableType?) -> @lib.TableType {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_95_none() -> @lib.TagType? {
  None
}

///|
pub fn __js_option_95_some(value : @lib.TagType) -> @lib.TagType? {
  Some(value)
}

///|
pub fn __js_option_95_is_some(value : @lib.TagType?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_95_unwrap(value : @lib.TagType?) -> @lib.TagType {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_96_none() -> @lib.CompType? {
  None
}

///|
pub fn __js_option_96_some(value : @lib.CompType) -> @lib.CompType? {
  Some(value)
}

///|
pub fn __js_option_96_is_some(value : @lib.CompType?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_96_unwrap(value : @lib.CompType?) -> @lib.CompType {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_97_none() -> @validate.GenValidConfig? {
  None
}

///|
pub fn __js_option_97_some(
  value : @validate.GenValidConfig,
) -> @validate.GenValidConfig? {
  Some(value)
}

///|
pub fn __js_option_97_is_some(value : @validate.GenValidConfig?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_97_unwrap(
  value : @validate.GenValidConfig?,
) -> @validate.GenValidConfig {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_98_none() -> @validate.GenInvalidSeedMode? {
  None
}

///|
pub fn __js_option_98_some(
  value : @validate.GenInvalidSeedMode,
) -> @validate.GenInvalidSeedMode? {
  Some(value)
}

///|
pub fn __js_option_98_is_some(value : @validate.GenInvalidSeedMode?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_98_unwrap(
  value : @validate.GenInvalidSeedMode?,
) -> @validate.GenInvalidSeedMode {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_99_none() -> @lib.FuncIdx?? {
  None
}

///|
pub fn __js_option_99_some(value : @lib.FuncIdx?) -> @lib.FuncIdx?? {
  Some(value)
}

///|
pub fn __js_option_99_is_some(value : @lib.FuncIdx??) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_99_unwrap(value : @lib.FuncIdx??) -> @lib.FuncIdx? {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_option_100_none() -> @wast.TokenType? {
  None
}

///|
pub fn __js_option_100_some(value : @wast.TokenType) -> @wast.TokenType? {
  Some(value)
}

///|
pub fn __js_option_100_is_some(value : @wast.TokenType?) -> Bool {
  match value {
    Some(_) => true
    None => false
  }
}

///|
pub fn __js_option_100_unwrap(value : @wast.TokenType?) -> @wast.TokenType {
  match value {
    Some(inner) => inner
    None => abort("Attempted to unwrap None inside the Node adapter.")
  }
}

///|
pub fn __js_result_1_is_ok(
  value : Result[Array[Array[UInt]], @binary.BinaryEncodeError],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_1_unwrap_ok(
  value : Result[Array[Array[UInt]], @binary.BinaryEncodeError],
) -> Array[Array[UInt]] {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_1_unwrap_err(
  value : Result[Array[Array[UInt]], @binary.BinaryEncodeError],
) -> @binary.BinaryEncodeError {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_2_is_ok(
  value : Result[
    Array[Array[(UInt, @lib.Instruction)]],
    @binary.BinaryEncodeError,
  ],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_2_unwrap_ok(
  value : Result[
    Array[Array[(UInt, @lib.Instruction)]],
    @binary.BinaryEncodeError,
  ],
) -> Array[Array[(UInt, @lib.Instruction)]] {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_2_unwrap_err(
  value : Result[
    Array[Array[(UInt, @lib.Instruction)]],
    @binary.BinaryEncodeError,
  ],
) -> @binary.BinaryEncodeError {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_3_is_ok(
  value : Result[Array[UInt], @binary.BinaryEncodeError],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_3_unwrap_ok(
  value : Result[Array[UInt], @binary.BinaryEncodeError],
) -> Array[UInt] {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_3_unwrap_err(
  value : Result[Array[UInt], @binary.BinaryEncodeError],
) -> @binary.BinaryEncodeError {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_4_is_ok(
  value : Result[Array[(UInt, @lib.Instruction)], @binary.BinaryEncodeError],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_4_unwrap_ok(
  value : Result[Array[(UInt, @lib.Instruction)], @binary.BinaryEncodeError],
) -> Array[(UInt, @lib.Instruction)] {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_4_unwrap_err(
  value : Result[Array[(UInt, @lib.Instruction)], @binary.BinaryEncodeError],
) -> @binary.BinaryEncodeError {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_5_is_ok(
  value : Result[@lib.Module, @binary.DecodeError],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_5_unwrap_ok(
  value : Result[@lib.Module, @binary.DecodeError],
) -> @lib.Module {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_5_unwrap_err(
  value : Result[@lib.Module, @binary.DecodeError],
) -> @binary.DecodeError {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_6_is_ok(
  value : Result[(@lib.Module, Int), @binary.ModuleDecodeErrorDetail],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_6_unwrap_ok(
  value : Result[(@lib.Module, Int), @binary.ModuleDecodeErrorDetail],
) -> (@lib.Module, Int) {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_6_unwrap_err(
  value : Result[(@lib.Module, Int), @binary.ModuleDecodeErrorDetail],
) -> @binary.ModuleDecodeErrorDetail {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_7_is_ok(value : Result[Bytes, @binary.EncodeError]) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_7_unwrap_ok(
  value : Result[Bytes, @binary.EncodeError],
) -> Bytes {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_7_unwrap_err(
  value : Result[Bytes, @binary.EncodeError],
) -> @binary.EncodeError {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_8_is_ok(
  value : Result[(Int, Int), @binary.EncodeError],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_8_unwrap_ok(
  value : Result[(Int, Int), @binary.EncodeError],
) -> (Int, Int) {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_8_unwrap_err(
  value : Result[(Int, Int), @binary.EncodeError],
) -> @binary.EncodeError {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_9_is_ok(
  value : Result[Int, @binary.BinaryEncodeError],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_9_unwrap_ok(
  value : Result[Int, @binary.BinaryEncodeError],
) -> Int {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_9_unwrap_err(
  value : Result[Int, @binary.BinaryEncodeError],
) -> @binary.BinaryEncodeError {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_10_is_ok(
  value : Result[@cli.CliParseResult, @cli.CliParseError],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_10_unwrap_ok(
  value : Result[@cli.CliParseResult, @cli.CliParseError],
) -> @cli.CliParseResult {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_10_unwrap_err(
  value : Result[@cli.CliParseResult, @cli.CliParseError],
) -> @cli.CliParseError {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_11_is_ok(value : Result[Array[String], String]) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_11_unwrap_ok(
  value : Result[Array[String], String],
) -> Array[String] {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_11_unwrap_err(
  value : Result[Array[String], String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_12_is_ok(
  value : Result[@cmd.CmdFuzzHarnessProfileConfig, String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_12_unwrap_ok(
  value : Result[@cmd.CmdFuzzHarnessProfileConfig, String],
) -> @cmd.CmdFuzzHarnessProfileConfig {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_12_unwrap_err(
  value : Result[@cmd.CmdFuzzHarnessProfileConfig, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_13_is_ok(
  value : Result[@cmd.DifferentialValidationReport, String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_13_unwrap_ok(
  value : Result[@cmd.DifferentialValidationReport, String],
) -> @cmd.DifferentialValidationReport {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_13_unwrap_err(
  value : Result[@cmd.DifferentialValidationReport, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_14_is_ok(value : Result[(String, String?), String]) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_14_unwrap_ok(
  value : Result[(String, String?), String],
) -> (String, String?) {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_14_unwrap_err(
  value : Result[(String, String?), String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_15_is_ok(
  value : Result[@cmd.TextDifferentialArtifactPaths, String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_15_unwrap_ok(
  value : Result[@cmd.TextDifferentialArtifactPaths, String],
) -> @cmd.TextDifferentialArtifactPaths {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_15_unwrap_err(
  value : Result[@cmd.TextDifferentialArtifactPaths, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_16_is_ok(
  value : Result[@cmd.CmdRunSummary, @cmd.CmdError],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_16_unwrap_ok(
  value : Result[@cmd.CmdRunSummary, @cmd.CmdError],
) -> @cmd.CmdRunSummary {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_16_unwrap_err(
  value : Result[@cmd.CmdRunSummary, @cmd.CmdError],
) -> @cmd.CmdError {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_17_is_ok(value : Result[@cmd.CmdFuzzStats, String]) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_17_unwrap_ok(
  value : Result[@cmd.CmdFuzzStats, String],
) -> @cmd.CmdFuzzStats {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_17_unwrap_err(
  value : Result[@cmd.CmdFuzzStats, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_18_is_ok(value : Result[Unit, String]) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_18_unwrap_ok(value : Result[Unit, String]) -> Unit {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_18_unwrap_err(value : Result[Unit, String]) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_19_is_ok(value : Result[@lib.FieldType, String]) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_19_unwrap_ok(
  value : Result[@lib.FieldType, String],
) -> @lib.FieldType {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_19_unwrap_err(
  value : Result[@lib.FieldType, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_20_is_ok(
  value : Result[@lib.FunctionLocals, String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_20_unwrap_ok(
  value : Result[@lib.FunctionLocals, String],
) -> @lib.FunctionLocals {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_20_unwrap_err(
  value : Result[@lib.FunctionLocals, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_21_is_ok(
  value : Result[@validate.ValidateInvalidAstMutation, String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_21_unwrap_ok(
  value : Result[@validate.ValidateInvalidAstMutation, String],
) -> @validate.ValidateInvalidAstMutation {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_21_unwrap_err(
  value : Result[@validate.ValidateInvalidAstMutation, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_22_is_ok(value : Result[@lib.Module, String]) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_22_unwrap_ok(
  value : Result[@lib.Module, String],
) -> @lib.Module {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_22_unwrap_err(value : Result[@lib.Module, String]) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_23_is_ok(value : Result[@lib.RefType, String]) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_23_unwrap_ok(
  value : Result[@lib.RefType, String],
) -> @lib.RefType {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_23_unwrap_err(
  value : Result[@lib.RefType, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_24_is_ok(
  value : Result[@validate.GenInvalidAstGenerated, String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_24_unwrap_ok(
  value : Result[@validate.GenInvalidAstGenerated, String],
) -> @validate.GenInvalidAstGenerated {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_24_unwrap_err(
  value : Result[@validate.GenInvalidAstGenerated, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_25_is_ok(
  value : Result[@validate.GenValidModuleGenerated, @validate.GenValidFailure],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_25_unwrap_ok(
  value : Result[@validate.GenValidModuleGenerated, @validate.GenValidFailure],
) -> @validate.GenValidModuleGenerated {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_25_unwrap_err(
  value : Result[@validate.GenValidModuleGenerated, @validate.GenValidFailure],
) -> @validate.GenValidFailure {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_26_is_ok(
  value : Result[@validate.GenValidGenerated, @validate.GenValidFailure],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_26_unwrap_ok(
  value : Result[@validate.GenValidGenerated, @validate.GenValidFailure],
) -> @validate.GenValidGenerated {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_26_unwrap_err(
  value : Result[@validate.GenValidGenerated, @validate.GenValidFailure],
) -> @validate.GenValidFailure {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_27_is_ok(
  value : Result[@validate.GenValidProfile, String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_27_unwrap_ok(
  value : Result[@validate.GenValidProfile, String],
) -> @validate.GenValidProfile {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_27_unwrap_err(
  value : Result[@validate.GenValidProfile, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_28_is_ok(
  value : Result[@validate.ValidateInvalidAstFuzzStats, String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_28_unwrap_ok(
  value : Result[@validate.ValidateInvalidAstFuzzStats, String],
) -> @validate.ValidateInvalidAstFuzzStats {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_28_unwrap_err(
  value : Result[@validate.ValidateInvalidAstFuzzStats, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_29_is_ok(
  value : Result[@validate.ValidateValidFuzzStats, String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_29_unwrap_ok(
  value : Result[@validate.ValidateValidFuzzStats, String],
) -> @validate.ValidateValidFuzzStats {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_29_unwrap_err(
  value : Result[@validate.ValidateValidFuzzStats, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_30_is_ok(value : Result[@validate.TcState, String]) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_30_unwrap_ok(
  value : Result[@validate.TcState, String],
) -> @validate.TcState {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_30_unwrap_err(
  value : Result[@validate.TcState, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_31_is_ok(
  value : Result[(Bool, @validate.TcEscape), String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_31_unwrap_ok(
  value : Result[(Bool, @validate.TcEscape), String],
) -> (Bool, @validate.TcEscape) {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_31_unwrap_err(
  value : Result[(Bool, @validate.TcEscape), String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_32_is_ok(value : Result[@validate.Env, String]) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_32_unwrap_ok(
  value : Result[@validate.Env, String],
) -> @validate.Env {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_32_unwrap_err(
  value : Result[@validate.Env, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_33_is_ok(
  value : Result[Array[(@lib.FuncIdx, String)], @validate.ValidationError],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_33_unwrap_ok(
  value : Result[Array[(@lib.FuncIdx, String)], @validate.ValidationError],
) -> Array[(@lib.FuncIdx, String)] {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_33_unwrap_err(
  value : Result[Array[(@lib.FuncIdx, String)], @validate.ValidationError],
) -> @validate.ValidationError {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_34_is_ok(
  value : Result[@validate.ValidateInvalidAstRunConfig, String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_34_unwrap_ok(
  value : Result[@validate.ValidateInvalidAstRunConfig, String],
) -> @validate.ValidateInvalidAstRunConfig {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_34_unwrap_err(
  value : Result[@validate.ValidateInvalidAstRunConfig, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_35_is_ok(
  value : Result[Unit, @validate.ValidationError],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_35_unwrap_ok(
  value : Result[Unit, @validate.ValidationError],
) -> Unit {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_35_unwrap_err(
  value : Result[Unit, @validate.ValidationError],
) -> @validate.ValidationError {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_36_is_ok(value : Result[Int, String]) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_36_unwrap_ok(value : Result[Int, String]) -> Int {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_36_unwrap_err(value : Result[Int, String]) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_37_is_ok(
  value : Result[@validate.ValidateValidFeatureFloor, String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_37_unwrap_ok(
  value : Result[@validate.ValidateValidFeatureFloor, String],
) -> @validate.ValidateValidFeatureFloor {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_37_unwrap_err(
  value : Result[@validate.ValidateValidFeatureFloor, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_38_is_ok(
  value : Result[@validate.ValidateValidRunConfig, String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_38_unwrap_ok(
  value : Result[@validate.ValidateValidRunConfig, String],
) -> @validate.ValidateValidRunConfig {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_38_unwrap_err(
  value : Result[@validate.ValidateValidRunConfig, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_39_is_ok(value : Result[@lib.ValType, String]) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_39_unwrap_ok(
  value : Result[@lib.ValType, String],
) -> @lib.ValType {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_39_unwrap_err(
  value : Result[@lib.ValType, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_40_is_ok(
  value : Result[(Array[@lib.ValType], Array[@lib.ValType]), String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_40_unwrap_ok(
  value : Result[(Array[@lib.ValType], Array[@lib.ValType]), String],
) -> (Array[@lib.ValType], Array[@lib.ValType]) {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_40_unwrap_err(
  value : Result[(Array[@lib.ValType], Array[@lib.ValType]), String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_41_is_ok(value : Result[@lib.TypeIdx?, String]) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_41_unwrap_ok(
  value : Result[@lib.TypeIdx?, String],
) -> @lib.TypeIdx? {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_41_unwrap_err(
  value : Result[@lib.TypeIdx?, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_42_is_ok(
  value : Result[Array[@lib.FieldType], String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_42_unwrap_ok(
  value : Result[Array[@lib.FieldType], String],
) -> Array[@lib.FieldType] {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_42_unwrap_err(
  value : Result[Array[@lib.FieldType], String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_43_is_ok(value : Result[@lib.SubType, String]) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_43_unwrap_ok(
  value : Result[@lib.SubType, String],
) -> @lib.SubType {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_43_unwrap_err(
  value : Result[@lib.SubType, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_44_is_ok(
  value : Result[@validate.GenValidConfig, String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_44_unwrap_ok(
  value : Result[@validate.GenValidConfig, String],
) -> @validate.GenValidConfig {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_44_unwrap_err(
  value : Result[@validate.GenValidConfig, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_45_is_ok(
  value : Result[@wast.WastStaticAssertionResult, String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_45_unwrap_ok(
  value : Result[@wast.WastStaticAssertionResult, String],
) -> @wast.WastStaticAssertionResult {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_45_unwrap_err(
  value : Result[@wast.WastStaticAssertionResult, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_46_is_ok(value : Result[String, String]) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_46_unwrap_ok(value : Result[String, String]) -> String {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_46_unwrap_err(value : Result[String, String]) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_47_is_ok(
  value : Result[@wast.WastRoundtripFuzzStats, String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_47_unwrap_ok(
  value : Result[@wast.WastRoundtripFuzzStats, String],
) -> @wast.WastRoundtripFuzzStats {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_47_unwrap_err(
  value : Result[@wast.WastRoundtripFuzzStats, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_48_is_ok(
  value : Result[(String, @lib.Module), String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_48_unwrap_ok(
  value : Result[(String, @lib.Module), String],
) -> (String, @lib.Module) {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_48_unwrap_err(
  value : Result[(String, @lib.Module), String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_49_is_ok(value : Result[@wast.Module, String]) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_49_unwrap_ok(
  value : Result[@wast.Module, String],
) -> @wast.Module {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_49_unwrap_err(
  value : Result[@wast.Module, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_50_is_ok(value : Result[@wast.WastScript, String]) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_50_unwrap_ok(
  value : Result[@wast.WastScript, String],
) -> @wast.WastScript {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_50_unwrap_err(
  value : Result[@wast.WastScript, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_result_51_is_ok(
  value : Result[@wat.WatRoundtripFuzzStats, String],
) -> Bool {
  match value {
    Ok(_) => true
    Err(_) => false
  }
}

///|
pub fn __js_result_51_unwrap_ok(
  value : Result[@wat.WatRoundtripFuzzStats, String],
) -> @wat.WatRoundtripFuzzStats {
  match value {
    Ok(inner) => inner
    Err(_) => abort("Attempted to unwrap Err as Ok inside the Node adapter.")
  }
}

///|
pub fn __js_result_51_unwrap_err(
  value : Result[@wat.WatRoundtripFuzzStats, String],
) -> String {
  match value {
    Ok(_) => abort("Attempted to unwrap Ok as Err inside the Node adapter.")
    Err(inner) => inner
  }
}

///|
pub fn __js_tuple_1_new(
  arg0 : UInt,
  arg1 : @lib.Instruction,
) -> (UInt, @lib.Instruction) {
  (arg0, arg1)
}

///|
pub fn __js_tuple_1_get_0(value : (UInt, @lib.Instruction)) -> UInt {
  let (item0, _) = value
  item0
}

///|
pub fn __js_tuple_1_get_1(value : (UInt, @lib.Instruction)) -> @lib.Instruction {
  let (_, item1) = value
  item1
}

///|
pub fn __js_tuple_2_new(arg0 : @lib.Module, arg1 : Int) -> (@lib.Module, Int) {
  (arg0, arg1)
}

///|
pub fn __js_tuple_2_get_0(value : (@lib.Module, Int)) -> @lib.Module {
  let (item0, _) = value
  item0
}

///|
pub fn __js_tuple_2_get_1(value : (@lib.Module, Int)) -> Int {
  let (_, item1) = value
  item1
}

///|
pub fn __js_tuple_3_new(arg0 : Int, arg1 : Int) -> (Int, Int) {
  (arg0, arg1)
}

///|
pub fn __js_tuple_3_get_0(value : (Int, Int)) -> Int {
  let (item0, _) = value
  item0
}

///|
pub fn __js_tuple_3_get_1(value : (Int, Int)) -> Int {
  let (_, item1) = value
  item1
}

///|
pub fn __js_tuple_4_new(arg0 : Bool, arg1 : Bool) -> (Bool, Bool) {
  (arg0, arg1)
}

///|
pub fn __js_tuple_4_get_0(value : (Bool, Bool)) -> Bool {
  let (item0, _) = value
  item0
}

///|
pub fn __js_tuple_4_get_1(value : (Bool, Bool)) -> Bool {
  let (_, item1) = value
  item1
}

///|
pub fn __js_tuple_5_new(arg0 : String, arg1 : String?) -> (String, String?) {
  (arg0, arg1)
}

///|
pub fn __js_tuple_5_get_0(value : (String, String?)) -> String {
  let (item0, _) = value
  item0
}

///|
pub fn __js_tuple_5_get_1(value : (String, String?)) -> String? {
  let (_, item1) = value
  item1
}

///|
pub fn __js_tuple_6_new(arg0 : String, arg1 : String) -> (String, String) {
  (arg0, arg1)
}

///|
pub fn __js_tuple_6_get_0(value : (String, String)) -> String {
  let (item0, _) = value
  item0
}

///|
pub fn __js_tuple_6_get_1(value : (String, String)) -> String {
  let (_, item1) = value
  item1
}

///|
pub fn __js_tuple_7_new(
  arg0 : Bool,
  arg1 : @validate.TcEscape,
) -> (Bool, @validate.TcEscape) {
  (arg0, arg1)
}

///|
pub fn __js_tuple_7_get_0(value : (Bool, @validate.TcEscape)) -> Bool {
  let (item0, _) = value
  item0
}

///|
pub fn __js_tuple_7_get_1(
  value : (Bool, @validate.TcEscape),
) -> @validate.TcEscape {
  let (_, item1) = value
  item1
}

///|
pub fn __js_tuple_8_new(
  arg0 : @lib.FuncIdx,
  arg1 : @lib.Func,
) -> (@lib.FuncIdx, @lib.Func) {
  (arg0, arg1)
}

///|
pub fn __js_tuple_8_get_0(value : (@lib.FuncIdx, @lib.Func)) -> @lib.FuncIdx {
  let (item0, _) = value
  item0
}

///|
pub fn __js_tuple_8_get_1(value : (@lib.FuncIdx, @lib.Func)) -> @lib.Func {
  let (_, item1) = value
  item1
}

///|
pub fn __js_tuple_9_new(
  arg0 : @lib.FuncIdx,
  arg1 : String,
) -> (@lib.FuncIdx, String) {
  (arg0, arg1)
}

///|
pub fn __js_tuple_9_get_0(value : (@lib.FuncIdx, String)) -> @lib.FuncIdx {
  let (item0, _) = value
  item0
}

///|
pub fn __js_tuple_9_get_1(value : (@lib.FuncIdx, String)) -> String {
  let (_, item1) = value
  item1
}

///|
pub fn __js_tuple_10_new(
  arg0 : Array[@lib.ValType],
  arg1 : Array[@lib.ValType],
) -> (Array[@lib.ValType], Array[@lib.ValType]) {
  (arg0, arg1)
}

///|
pub fn __js_tuple_10_get_0(
  value : (Array[@lib.ValType], Array[@lib.ValType]),
) -> Array[@lib.ValType] {
  let (item0, _) = value
  item0
}

///|
pub fn __js_tuple_10_get_1(
  value : (Array[@lib.ValType], Array[@lib.ValType]),
) -> Array[@lib.ValType] {
  let (_, item1) = value
  item1
}

///|
pub fn __js_tuple_11_new(
  arg0 : String,
  arg1 : @lib.Module,
) -> (String, @lib.Module) {
  (arg0, arg1)
}

///|
pub fn __js_tuple_11_get_0(value : (String, @lib.Module)) -> String {
  let (item0, _) = value
  item0
}

///|
pub fn __js_tuple_11_get_1(value : (String, @lib.Module)) -> @lib.Module {
  let (_, item1) = value
  item1
}

///|
pub fn __js_show_binary_BinaryDecodeError(
  value : @binary.BinaryDecodeError,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_binary_BinaryEncodeError(
  value : @binary.BinaryEncodeError,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_binary_DecodeError(value : @binary.DecodeError) -> String {
  value.to_string()
}

///|
pub fn __js_show_binary_EncodeError(value : @binary.EncodeError) -> String {
  value.to_string()
}

///|
pub fn __js_show_cli_CliInputFormat(value : @cli.CliInputFormat) -> String {
  value.to_string()
}

///|
pub fn __js_show_cli_CliOptimizationFlag(
  value : @cli.CliOptimizationFlag,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_cli_CliOutputTarget(value : @cli.CliOutputTarget) -> String {
  value.to_string()
}

///|
pub fn __js_show_cli_CliParseError(value : @cli.CliParseError) -> String {
  value.to_string()
}

///|
pub fn __js_show_cli_CliParseResult(value : @cli.CliParseResult) -> String {
  value.to_string()
}

///|
pub fn __js_show_cli_CliTracingLevel(value : @cli.CliTracingLevel) -> String {
  value.to_string()
}

///|
pub fn __js_show_cli_TrapMode(value : @cli.TrapMode) -> String {
  value.to_string()
}

///|
pub fn __js_show_cmd_CmdEncodeError(value : @cmd.CmdEncodeError) -> String {
  value.to_string()
}

///|
pub fn __js_show_cmd_CmdError(value : @cmd.CmdError) -> String {
  value.to_string()
}

///|
pub fn __js_show_cmd_CmdFuzzStats(value : @cmd.CmdFuzzStats) -> String {
  value.to_string()
}

///|
pub fn __js_show_cmd_CmdRunSummary(value : @cmd.CmdRunSummary) -> String {
  value.to_string()
}

///|
pub fn __js_show_cmd_DifferentialValidationReport(
  value : @cmd.DifferentialValidationReport,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_cmd_FuzzFailureReport(
  value : @cmd.FuzzFailureReport,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_cmd_InliningOptions(value : @cmd.InliningOptions) -> String {
  value.to_string()
}

///|
pub fn __js_show_cmd_OptimizeOptions(value : @cmd.OptimizeOptions) -> String {
  value.to_string()
}

///|
pub fn __js_show_cmd_OptimizeTracingLevel(
  value : @cmd.OptimizeTracingLevel,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_cmd_OptimizeValidationPolicy(
  value : @cmd.OptimizeValidationPolicy,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_cmd_ReadmeApiVerifyBlock(
  value : @cmd.ReadmeApiVerifyBlock,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_AbsHeapType(value : @lib.AbsHeapType) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_AggregateAtomicRmwOp(
  value : @lib.AggregateAtomicRmwOp,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_AtomicCmpxchgOp(value : @lib.AtomicCmpxchgOp) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_AtomicOrder(value : @lib.AtomicOrder) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_AtomicRmwOp(value : @lib.AtomicRmwOp) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_BinaryOp(value : @lib.BinaryOp) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_BlockType(value : @lib.BlockType) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_CastOp(value : @lib.CastOp) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_Catch(value : @lib.Catch) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_CodeSec(value : @lib.CodeSec) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_CompType(value : @lib.CompType) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_CustomSec(value : @lib.CustomSec) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_Data(value : @lib.Data) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_DataCntSec(value : @lib.DataCntSec) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_DataIdx(value : @lib.DataIdx) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_DataMode(value : @lib.DataMode) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_DataSec(value : @lib.DataSec) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_DefType(value : @lib.DefType) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_Elem(value : @lib.Elem) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_ElemIdx(value : @lib.ElemIdx) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_ElemKind(value : @lib.ElemKind) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_ElemMode(value : @lib.ElemMode) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_ElemSec(value : @lib.ElemSec) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_Export(value : @lib.Export) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_ExportSec(value : @lib.ExportSec) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_Expr(value : @lib.Expr) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_ExternIdx(value : @lib.ExternIdx) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_ExternType(value : @lib.ExternType) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_ExtractLaneOp(value : @lib.ExtractLaneOp) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_F32(value : @lib.F32) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_F64(value : @lib.F64) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_FieldType(value : @lib.FieldType) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_Func(value : @lib.Func) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_FuncAnnotation(value : @lib.FuncAnnotation) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_FuncAnnotationAssoc(
  value : @lib.FuncAnnotationAssoc,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_FuncAnnotationSec(
  value : @lib.FuncAnnotationSec,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_FuncIdx(value : @lib.FuncIdx) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_FuncSec(value : @lib.FuncSec) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_FuncType(value : @lib.FuncType) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_Global(value : @lib.Global) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_GlobalIdx(value : @lib.GlobalIdx) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_GlobalSec(value : @lib.GlobalSec) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_GlobalType(value : @lib.GlobalType) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_HeapType(value : @lib.HeapType) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_I32(value : @lib.I32) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_I64(value : @lib.I64) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_Import(value : @lib.Import) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_ImportSec(value : @lib.ImportSec) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_IndirectNameAssoc(
  value : @lib.IndirectNameAssoc,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_IndirectNameMap(value : @lib.IndirectNameMap) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_Instruction(value : @lib.Instruction) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_LabelIdx(value : @lib.LabelIdx) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_LaneIdx(value : @lib.LaneIdx) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_LegacyCatch(value : @lib.LegacyCatch) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_Limits(value : @lib.Limits) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_LoadOp(value : @lib.LoadOp) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_LocalIdx(value : @lib.LocalIdx) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_LocalRun(value : @lib.LocalRun) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_Locals(value : @lib.Locals) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_MemArg(value : @lib.MemArg) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_MemIdx(value : @lib.MemIdx) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_MemSec(value : @lib.MemSec) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_MemType(value : @lib.MemType) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_Module(value : @lib.Module) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_Mut(value : @lib.Mut) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_Name(value : @lib.Name) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_NameAssoc(value : @lib.NameAssoc) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_NameMap(value : @lib.NameMap) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_NameSec(value : @lib.NameSec) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_NumType(value : @lib.NumType) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_PackType(value : @lib.PackType) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_RecType(value : @lib.RecType) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_RefType(value : @lib.RefType) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_ReplaceLaneOp(value : @lib.ReplaceLaneOp) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_ResumeHandler(value : @lib.ResumeHandler) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_S33(value : @lib.S33) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_StartSec(value : @lib.StartSec) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_StorageType(value : @lib.StorageType) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_StoreOp(value : @lib.StoreOp) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_StringRefsSec(value : @lib.StringRefsSec) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_SubType(value : @lib.SubType) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_Table(value : @lib.Table) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_TableIdx(value : @lib.TableIdx) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_TableSec(value : @lib.TableSec) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_TableType(value : @lib.TableType) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_TagIdx(value : @lib.TagIdx) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_TagSec(value : @lib.TagSec) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_TagType(value : @lib.TagType) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_TypeIdx(value : @lib.TypeIdx) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_TypeSec(value : @lib.TypeSec) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_U32(value : @lib.U32) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_U64(value : @lib.U64) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_UnaryOp(value : @lib.UnaryOp) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_V128LoadLaneOp(value : @lib.V128LoadLaneOp) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_V128ShiftOp(value : @lib.V128ShiftOp) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_V128StoreLaneOp(value : @lib.V128StoreLaneOp) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_V128TernaryOp(value : @lib.V128TernaryOp) -> String {
  value.to_string()
}

///|
pub fn __js_show_lib_ValType(value : @lib.ValType) -> String {
  value.to_string()
}

///|
pub fn __js_show_validate_ValidationError(
  value : @validate.ValidationError,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_validate_Env(value : @validate.Env) -> String {
  value.to_string()
}

///|
pub fn __js_show_validate_GenValidConfig(
  value : @validate.GenValidConfig,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_validate_GenValidExactOpcodeCounts(
  value : @validate.GenValidExactOpcodeCounts,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_validate_GenValidFeatureStats(
  value : @validate.GenValidFeatureStats,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_validate_GenValidFeatureToggles(
  value : @validate.GenValidFeatureToggles,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_validate_GenValidMode(
  value : @validate.GenValidMode,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_validate_GenValidSectionBias(
  value : @validate.GenValidSectionBias,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_validate_LabelStack(value : @validate.LabelStack) -> String {
  value.to_string()
}

///|
pub fn __js_show_validate_TcEscape(value : @validate.TcEscape) -> String {
  value.to_string()
}

///|
pub fn __js_show_validate_TcState(value : @validate.TcState) -> String {
  value.to_string()
}

///|
pub fn __js_show_validate_ValidateValidFeatureFloor(
  value : @validate.ValidateValidFeatureFloor,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_validate_ValidateValidFeatureFloorFailure(
  value : @validate.ValidateValidFeatureFloorFailure,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_validate_ValidateValidFeatureKey(
  value : @validate.ValidateValidFeatureKey,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_validate_ValidateValidFeatureLedgerStatus(
  value : @validate.ValidateValidFeatureLedgerStatus,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_validate_ValidateValidFuzzStats(
  value : @validate.ValidateValidFuzzStats,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_validate_ValidationDiagnostic(
  value : @validate.ValidationDiagnostic,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_validate_ValidationIssue(
  value : @validate.ValidationIssue,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_ParserError(value : @wast.ParserError) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_Annotation(value : @wast.Annotation) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_BlockType(value : @wast.BlockType) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_CatchClause(value : @wast.CatchClause) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_DataSegment(value : @wast.DataSegment) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_ElemInitExpr(value : @wast.ElemInitExpr) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_ElemSegment(value : @wast.ElemSegment) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_ErrorLevel(value : @wast.ErrorLevel) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_Export(value : @wast.Export) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_ExportDesc(value : @wast.ExportDesc) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_FieldStorage(value : @wast.FieldStorage) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_Func(value : @wast.Func) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_FuncType(value : @wast.FuncType) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_Global(value : @wast.Global) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_GlobalType(value : @wast.GlobalType) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_HeapTypeRef(value : @wast.HeapTypeRef) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_Import(value : @wast.Import) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_ImportDesc(value : @wast.ImportDesc) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_Index(value : @wast.Index) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_InlineExport(value : @wast.InlineExport) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_Instruction(value : @wast.Instruction) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_LegacyCatchClause(
  value : @wast.LegacyCatchClause,
) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_LexerError(value : @wast.LexerError) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_Limits(value : @wast.Limits) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_Literal(value : @wast.Literal) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_LiteralType(value : @wast.LiteralType) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_Local(value : @wast.Local) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_Location(value : @wast.Location) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_MemArg(value : @wast.MemArg) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_Memory(value : @wast.Memory) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_MemoryType(value : @wast.MemoryType) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_Module(value : @wast.Module) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_ModuleField(value : @wast.ModuleField) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_Opcode(value : @wast.Opcode) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_ParseError(value : @wast.ParseError) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_ShuffleLanes(value : @wast.ShuffleLanes) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_SimdShape(value : @wast.SimdShape) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_Start(value : @wast.Start) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_StructFieldDef(value : @wast.StructFieldDef) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_Table(value : @wast.Table) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_TableType(value : @wast.TableType) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_Tag(value : @wast.Tag) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_Token(value : @wast.Token) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_TokenType(value : @wast.TokenType) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_TokenValue(value : @wast.TokenValue) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_TypeDef(value : @wast.TypeDef) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_TypeDefBody(value : @wast.TypeDefBody) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_TypeDefMetadata(value : @wast.TypeDefMetadata) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_TypeUse(value : @wast.TypeUse) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_V128Const(value : @wast.V128Const) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_ValueType(value : @wast.ValueType) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_WastAction(value : @wast.WastAction) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_WastActionType(value : @wast.WastActionType) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_WastCommand(value : @wast.WastCommand) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_WastModuleDef(value : @wast.WastModuleDef) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_WastResult(value : @wast.WastResult) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_WastScript(value : @wast.WastScript) -> String {
  value.to_string()
}

///|
pub fn __js_show_wast_WastSpecRunSummary(
  value : @wast.WastSpecRunSummary,
) -> String {
  @debug.Debug::to_repr(value).to_string()
}

///|
pub fn __js_show_wast_WastValue(value : @wast.WastValue) -> String {
  value.to_string()
}

///|
pub fn binary__compiler_fact_module_opcode_offsets(
  arg0 : @lib.Module,
) -> Result[Array[Array[UInt]], @binary.BinaryEncodeError] {
  ffi_binary_compiler_fact_module_opcode_offsets(arg0)
}

///|
pub fn binary__compiler_fact_module_opcode_sites(
  arg0 : @lib.Module,
) -> Result[Array[Array[(UInt, @lib.Instruction)]], @binary.BinaryEncodeError] {
  ffi_binary_compiler_fact_module_opcode_sites(arg0)
}

///|
pub fn binary__compiler_fact_opcode_offsets(
  arg0 : @lib.Expr,
  arg1 : Array[Bytes]??,
) -> Result[Array[UInt], @binary.BinaryEncodeError] {
  ffi_binary_compiler_fact_opcode_offsets(arg0, arg1)
}

///|
pub fn binary__compiler_fact_opcode_sites(
  arg0 : @lib.Expr,
  arg1 : Array[Bytes]??,
) -> Result[Array[(UInt, @lib.Instruction)], @binary.BinaryEncodeError] {
  ffi_binary_compiler_fact_opcode_sites(arg0, arg1)
}

///|
pub fn binary__decode_module(
  arg0 : Bytes,
) -> Result[@lib.Module, @binary.DecodeError] {
  ffi_binary_decode_module(arg0)
}

///|
pub fn binary__decode_module_with_detail(
  arg0 : Bytes,
  arg1 : Int,
) -> Result[(@lib.Module, Int), @binary.ModuleDecodeErrorDetail] {
  ffi_binary_decode_module_with_detail(arg0, arg1)
}

///|
pub fn binary__encode_module(
  arg0 : @lib.Module,
  arg1 : Bool?,
) -> Result[Bytes, @binary.EncodeError] {
  ffi_binary_encode_module(arg0, arg1)
}

///|
pub fn binary__encoded_module_sizes(
  arg0 : @lib.Module,
  arg1 : @lib.Module,
) -> Result[(Int, Int), @binary.EncodeError] {
  ffi_binary_encoded_module_sizes(arg0, arg1)
}

///|
pub fn binary__size_signed(
  arg0 : Int64,
  arg1 : Int,
) -> Result[Int, @binary.BinaryEncodeError] {
  ffi_binary_size_signed(arg0, arg1)
}

///|
pub fn binary__size_unsigned(
  arg0 : UInt64,
  arg1 : Int,
) -> Result[Int, @binary.BinaryEncodeError] {
  ffi_binary_size_unsigned(arg0, arg1)
}

///|
pub fn cli__cli_config_schema_json() -> String {
  ffi_cli_cli_config_schema_json()
}

///|
pub fn cli__expand_globs(
  arg0 : Array[String],
  arg1 : Array[String],
) -> Array[String] {
  ffi_cli_expand_globs(arg0, arg1)
}

///|
pub fn cli__glob_match(arg0 : String, arg1 : String) -> Bool {
  ffi_cli_glob_match(arg0, arg1)
}

///|
pub fn cli__infer_input_format(arg0 : String) -> @cli.CliInputFormat? {
  ffi_cli_infer_input_format(arg0)
}

///|
pub fn cli__normalize_cli_path(arg0 : String) -> String {
  ffi_cli_normalize_cli_path(arg0)
}

///|
pub fn cli__parse_cli_args(
  arg0 : Array[String],
  arg1 : String??,
) -> Result[@cli.CliParseResult, @cli.CliParseError] {
  ffi_cli_parse_cli_args(arg0, arg1)
}

///|
pub fn cli__parse_starshine_input_env(arg0 : String?) -> Array[String] {
  ffi_cli_parse_starshine_input_env(arg0)
}

///|
pub fn cli__resolve_closed_world(
  arg0 : @cli.CliParseResult,
  arg1 : Bool?,
) -> Bool {
  ffi_cli_resolve_closed_world(arg0, arg1)
}

///|
pub fn cli__resolve_ignore_implicit_traps(arg0 : @cli.CliParseResult) -> Bool {
  ffi_cli_resolve_ignore_implicit_traps(arg0)
}

///|
pub fn cli__resolve_pass_flags(arg0 : @cli.CliParseResult) -> Array[String] {
  ffi_cli_resolve_pass_flags(arg0)
}

///|
pub fn cli__resolve_traps_never_happen(
  arg0 : @cli.CliParseResult,
  arg1 : Bool?,
) -> Bool {
  ffi_cli_resolve_traps_never_happen(arg0, arg1)
}

///|
pub fn cli__CliInputFormat__wasm() -> @cli.CliInputFormat {
  ffi_cli_CliInputFormat_wasm()
}

///|
pub fn cli__CliInputFormat__wast() -> @cli.CliInputFormat {
  ffi_cli_CliInputFormat_wast()
}

///|
pub fn cli__CliInputFormat__wat() -> @cli.CliInputFormat {
  ffi_cli_CliInputFormat_wat()
}

///|
pub fn cli__CliOptimizationFlag__olevel(
  arg0 : Int,
  arg1 : Bool,
) -> @cli.CliOptimizationFlag {
  ffi_cli_CliOptimizationFlag_olevel(arg0, arg1)
}

///|
pub fn cli__CliOptimizationFlag__optimize() -> @cli.CliOptimizationFlag {
  ffi_cli_CliOptimizationFlag_optimize()
}

///|
pub fn cli__CliOptimizationFlag__osize() -> @cli.CliOptimizationFlag {
  ffi_cli_CliOptimizationFlag_osize()
}

///|
pub fn cli__CliOptimizationFlag__shrink() -> @cli.CliOptimizationFlag {
  ffi_cli_CliOptimizationFlag_shrink()
}

///|
pub fn cli__CliOutputTarget__dir(arg0 : String) -> @cli.CliOutputTarget {
  ffi_cli_CliOutputTarget_dir(arg0)
}

///|
pub fn cli__CliOutputTarget__file(arg0 : String) -> @cli.CliOutputTarget {
  ffi_cli_CliOutputTarget_file(arg0)
}

///|
pub fn cli__CliOutputTarget__stdout() -> @cli.CliOutputTarget {
  ffi_cli_CliOutputTarget_stdout()
}

///|
pub fn cli__CliParseError__invalid_dump_path(
  arg0 : String,
) -> @cli.CliParseError {
  ffi_cli_CliParseError_invalid_dump_path(arg0)
}

///|
pub fn cli__CliParseError__invalid_function_index_list(
  arg0 : String,
) -> @cli.CliParseError {
  ffi_cli_CliParseError_invalid_function_index_list(arg0)
}

///|
pub fn cli__CliParseError__invalid_input_format(
  arg0 : String,
) -> @cli.CliParseError {
  ffi_cli_CliParseError_invalid_input_format(arg0)
}

///|
pub fn cli__CliParseError__invalid_long_flag(
  arg0 : String,
) -> @cli.CliParseError {
  ffi_cli_CliParseError_invalid_long_flag(arg0)
}

///|
pub fn cli__CliParseError__invalid_optimization_flag(
  arg0 : String,
) -> @cli.CliParseError {
  ffi_cli_CliParseError_invalid_optimization_flag(arg0)
}

///|
pub fn cli__CliParseError__invalid_tracing_level(
  arg0 : String,
) -> @cli.CliParseError {
  ffi_cli_CliParseError_invalid_tracing_level(arg0)
}

///|
pub fn cli__CliParseError__invalid_trap_mode(
  arg0 : String,
) -> @cli.CliParseError {
  ffi_cli_CliParseError_invalid_trap_mode(arg0)
}

///|
pub fn cli__CliParseError__missing_flag_value(
  arg0 : String,
) -> @cli.CliParseError {
  ffi_cli_CliParseError_missing_flag_value(arg0)
}

///|
pub fn cli__CliParseError__stdin_needs_format() -> @cli.CliParseError {
  ffi_cli_CliParseError_stdin_needs_format()
}

///|
pub fn cli__CliParseError__unexpected_flag_value(
  arg0 : String,
) -> @cli.CliParseError {
  ffi_cli_CliParseError_unexpected_flag_value(arg0)
}

///|
pub fn cli__CliParseError__unknown_short_flag(
  arg0 : Char,
) -> @cli.CliParseError {
  ffi_cli_CliParseError_unknown_short_flag(arg0)
}

///|
pub fn cli__CliParseResult__new(
  arg0 : String??,
  arg1 : Array[String]?,
  arg2 : Bool?,
  arg3 : Bool?,
  arg4 : Bool?,
  arg5 : Bool?,
  arg6 : Bool?,
  arg7 : @cli.CliInputFormat??,
  arg8 : Array[@cli.CliOutputTarget]?,
  arg9 : Array[String]?,
  arg10 : Array[@cli.CliOptimizationFlag]?,
  arg11 : @cli.TrapMode??,
  arg13 : Int??,
  arg20 : Bool??,
  arg21 : UInt64??,
  arg24 : @cli.CliTracingLevel??,
  arg12 : Bool?,
  arg14 : Int??,
  arg15 : Int??,
  arg16 : Int??,
  arg17 : Int??,
  arg18 : Bool??,
  arg19 : Int??,
  arg22 : Bool??,
  arg23 : String??,
) -> @cli.CliParseResult {
  ffi_cli_CliParseResult_new(
    arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12,
    arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21, arg22, arg23,
    arg24,
  )
}

///|
pub fn cli__CliTracingLevel__helper() -> @cli.CliTracingLevel {
  ffi_cli_CliTracingLevel_helper()
}

///|
pub fn cli__CliTracingLevel__pass() -> @cli.CliTracingLevel {
  ffi_cli_CliTracingLevel_pass()
}

///|
pub fn cli__CliTracingLevel__phase() -> @cli.CliTracingLevel {
  ffi_cli_CliTracingLevel_phase()
}

///|
pub fn cli__TrapMode__allow() -> @cli.TrapMode {
  ffi_cli_TrapMode_allow()
}

///|
pub fn cli__TrapMode__never() -> @cli.TrapMode {
  ffi_cli_TrapMode_never()
}

///|
pub fn cmd__binary_differential_classification_label(
  arg0 : @cmd.BinaryDifferentialClassification,
) -> String {
  ffi_cmd_binary_differential_classification_label(arg0)
}

///|
pub fn cmd__binary_differential_failed_validation_result(
  arg0 : String,
  arg1 : Bytes,
  arg2 : String,
) -> @cmd.BinaryDifferentialAdapterResult {
  ffi_cmd_binary_differential_failed_validation_result(arg0, arg1, arg2)
}

///|
pub fn cmd__choose_simple_export_invocation_args(
  arg0 : Array[@lib.ValType],
) -> Result[Array[String], String] {
  ffi_cmd_choose_simple_export_invocation_args(arg0)
}

///|
pub fn cmd__classify_binary_canonicality_differential(
  arg0 : @cmd.BinaryCanonicalityInputClass,
  arg1 : Bool,
  arg2 : Bool?,
  arg3 : Bool?,
) -> @cmd.BinaryCanonicalityClassification {
  ffi_cmd_classify_binary_canonicality_differential(arg0, arg1, arg2, arg3)
}

///|
pub fn cmd__classify_binary_differential_results(
  arg0 : Array[@cmd.BinaryDifferentialAdapterResult],
) -> @cmd.BinaryDifferentialClassification {
  ffi_cmd_classify_binary_differential_results(arg0)
}

///|
pub fn cmd__classify_export_invocation_matrix(
  arg0 : @cmd.ExportInvocationMatrixSummary,
) -> @cmd.ExportInvocationMatrixOutcome {
  ffi_cmd_classify_export_invocation_matrix(arg0)
}

///|
pub fn cmd__classify_export_invocation_results(
  arg0 : @cmd.ExportInvocationResult,
  arg1 : @cmd.ExportInvocationResult,
) -> @cmd.ExportInvocationClassification {
  ffi_cmd_classify_export_invocation_results(arg0, arg1)
}

///|
pub fn cmd__classify_n_way_text_aggregate(
  arg0 : Array[@cmd.TextAggregateAdapterResult],
) -> @cmd.TextAggregateClassification {
  ffi_cmd_classify_n_way_text_aggregate(arg0)
}

///|
pub fn cmd__cmd_fuzz_harness_profile_config(
  arg0 : String,
) -> Result[@cmd.CmdFuzzHarnessProfileConfig, String] {
  ffi_cmd_cmd_fuzz_harness_profile_config(arg0)
}

///|
pub fn cmd__cmd_fuzz_harness_profile_config_with_seed(
  arg0 : String,
  arg1 : UInt64,
) -> Result[@cmd.CmdFuzzHarnessProfileConfig, String] {
  ffi_cmd_cmd_fuzz_harness_profile_config_with_seed(arg0, arg1)
}

///|
pub fn cmd__cmd_fuzz_random_pass_sequence(
  arg0 : String,
  arg1 : UInt64,
) -> Array[String] {
  ffi_cmd_cmd_fuzz_random_pass_sequence(arg0, arg1)
}

///|
pub fn cmd__cmd_help_text() -> String {
  ffi_cmd_cmd_help_text()
}

///|
pub fn cmd__cmd_version_text() -> String {
  ffi_cmd_cmd_version_text()
}

///|
pub fn cmd__compare_export_invocation_results(
  arg0 : String,
  arg1 : Array[String],
  arg2 : @cmd.ExportInvocationResult,
  arg3 : @cmd.ExportInvocationResult,
) -> @cmd.ExportInvocationComparisonReport {
  ffi_cmd_compare_export_invocation_results(arg0, arg1, arg2, arg3)
}

///|
pub fn cmd__differential_validate_wasm(
  arg0 : Bytes,
  arg1 : @cmd.DifferentialAdapters?,
) -> Result[@cmd.DifferentialValidationReport, String] {
  ffi_cmd_differential_validate_wasm(arg0, arg1)
}

///|
pub fn cmd__export_invocation_matrix_should_fail(
  arg0 : @cmd.ExportInvocationMatrixSummary,
  arg1 : @cmd.ExportInvocationFailurePolicy,
) -> Bool {
  ffi_cmd_export_invocation_matrix_should_fail(arg0, arg1)
}

///|
pub fn cmd__export_invocation_semantic_mismatch_reports(
  arg0 : Array[@cmd.ExportInvocationComparisonReport],
) -> Array[@cmd.ExportInvocationComparisonReport] {
  ffi_cmd_export_invocation_semantic_mismatch_reports(arg0)
}

///|
pub fn cmd__export_invocation_summary_has_semantic_mismatch(
  arg0 : @cmd.ExportInvocationMatrixSummary,
) -> Bool {
  ffi_cmd_export_invocation_summary_has_semantic_mismatch(arg0)
}

///|
pub fn cmd__format_binary_differential_smoke_report_json(
  arg0 : @cmd.BinaryDifferentialSmokeReport,
) -> String {
  ffi_cmd_format_binary_differential_smoke_report_json(arg0)
}

///|
pub fn cmd__native_differential_tools_available() -> (Bool, Bool) {
  ffi_cmd_native_differential_tools_available()
}

///|
pub fn cmd__persist_fuzz_failure_report(
  arg0 : @cmd.FuzzFailureReport,
  arg1 : @cmd.FuzzFailurePersistIO,
  arg2 : String?,
) -> Result[(String, String?), String] {
  ffi_cmd_persist_fuzz_failure_report(arg0, arg1, arg2)
}

///|
pub fn cmd__persist_text_differential_artifacts(
  arg0 : String,
  arg1 : @cmd.TextParsePrintLowerReport,
  arg2 : Array[@cmd.TextAggregateAdapterResult],
  arg3 : @cmd.TextAggregateClassification,
  arg4 : @cmd.FuzzFailurePersistIO,
  arg5 : String?,
  arg6 : UInt64?,
  arg7 : Int?,
) -> Result[@cmd.TextDifferentialArtifactPaths, String] {
  ffi_cmd_persist_text_differential_artifacts(
    arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7,
  )
}

///|
pub fn cmd__run_binary_differential_smoke(
  arg0 : Array[Bytes],
  arg1 : Array[@cmd.BinaryDifferentialSmokeAdapter]?,
) -> @cmd.BinaryDifferentialSmokeReport {
  ffi_cmd_run_binary_differential_smoke(arg0, arg1)
}

///|
pub fn cmd__run_binaryen_binary_validation_adapter(
  arg0 : Bytes,
) -> @cmd.BinaryDifferentialAdapterResult {
  ffi_cmd_run_binaryen_binary_validation_adapter(arg0)
}

///|
pub fn cmd__run_cmd(
  arg0 : Array[String],
) -> Result[@cmd.CmdRunSummary, @cmd.CmdError] {
  ffi_cmd_run_cmd(arg0)
}

///|
pub fn cmd__run_cmd_exit_code(arg0 : Array[String]) -> Int {
  ffi_cmd_run_cmd_exit_code(arg0)
}

///|
pub fn cmd__run_cmd_exit_code_with_adapter(
  arg0 : Array[String],
  arg1 : @cmd.CmdIO,
  arg2 : String??,
) -> Int {
  ffi_cmd_run_cmd_exit_code_with_adapter(arg0, arg1, arg2)
}

///|
pub fn cmd__run_cmd_fuzz_harness_profile(
  arg0 : String,
  arg1 : UInt64,
) -> Result[@cmd.CmdFuzzStats, String] {
  ffi_cmd_run_cmd_fuzz_harness_profile(arg0, arg1)
}

///|
pub fn cmd__run_cmd_with_adapter(
  arg0 : Array[String],
  arg1 : @cmd.CmdIO,
  arg2 : String??,
) -> Result[@cmd.CmdRunSummary, @cmd.CmdError] {
  ffi_cmd_run_cmd_with_adapter(arg0, arg1, arg2)
}

///|
pub fn cmd__run_local_text_parse_print_lower_matrix(
  arg0 : String,
  arg1 : String?,
) -> @cmd.TextParsePrintLowerReport {
  ffi_cmd_run_local_text_parse_print_lower_matrix(arg0, arg1)
}

///|
pub fn cmd__run_wabt_binary_validation_adapter(
  arg0 : Bytes,
) -> @cmd.BinaryDifferentialAdapterResult {
  ffi_cmd_run_wabt_binary_validation_adapter(arg0)
}

///|
pub fn cmd__run_wasm_tools_binary_validation_adapter(
  arg0 : Bytes,
) -> @cmd.BinaryDifferentialAdapterResult {
  ffi_cmd_run_wasm_tools_binary_validation_adapter(arg0)
}

///|
pub fn cmd__summarize_binary_canonicality_classifications(
  arg0 : Array[@cmd.BinaryCanonicalityClassification],
) -> @cmd.BinaryCanonicalitySummary {
  ffi_cmd_summarize_binary_canonicality_classifications(arg0)
}

///|
pub fn cmd__summarize_export_invocation_matrix(
  arg0 : Array[@cmd.ExportInvocationComparisonReport],
) -> @cmd.ExportInvocationMatrixSummary {
  ffi_cmd_summarize_export_invocation_matrix(arg0)
}

///|
pub fn cmd__text_aggregate_classification_label(
  arg0 : @cmd.TextAggregateClassification,
) -> String {
  ffi_cmd_text_aggregate_classification_label(arg0)
}

///|
pub fn cmd__text_aggregate_local_result(
  arg0 : @cmd.TextParsePrintLowerReport,
  arg1 : Bool??,
) -> @cmd.TextAggregateAdapterResult {
  ffi_cmd_text_aggregate_local_result(arg0, arg1)
}

///|
pub fn cmd__verify_readme_api_signatures(
  arg0 : String,
  arg1 : Array[(String, String)],
) -> Result[Unit, String] {
  ffi_cmd_verify_readme_api_signatures(arg0, arg1)
}

///|
pub fn cmd__verify_readme_api_signatures_with_required_blocks(
  arg0 : String,
  arg1 : Array[(String, String)],
  arg2 : Array[String],
) -> Result[Unit, String] {
  ffi_cmd_verify_readme_api_signatures_with_required_blocks(arg0, arg1, arg2)
}

///|
pub fn cmd__CmdEncodeError__adapter(arg0 : String) -> @cmd.CmdEncodeError {
  ffi_cmd_CmdEncodeError_adapter(arg0)
}

///|
pub fn cmd__CmdEncodeError__encode(
  arg0 : @binary.EncodeError,
) -> @cmd.CmdEncodeError {
  ffi_cmd_CmdEncodeError_encode(arg0)
}

///|
pub fn cmd__BinaryCanonicalityClassification__accepted_noncanonical() -> @cmd.BinaryCanonicalityClassification {
  ffi_cmd_BinaryCanonicalityClassification_accepted_noncanonical()
}

///|
pub fn cmd__BinaryCanonicalityClassification__canonical_accepted() -> @cmd.BinaryCanonicalityClassification {
  ffi_cmd_BinaryCanonicalityClassification_canonical_accepted()
}

///|
pub fn cmd__BinaryCanonicalityClassification__decoder_bug_disagreement() -> @cmd.BinaryCanonicalityClassification {
  ffi_cmd_BinaryCanonicalityClassification_decoder_bug_disagreement()
}

///|
pub fn cmd__BinaryCanonicalityClassification__external_policy_disagreement() -> @cmd.BinaryCanonicalityClassification {
  ffi_cmd_BinaryCanonicalityClassification_external_policy_disagreement()
}

///|
pub fn cmd__BinaryCanonicalityClassification__malformed_rejected() -> @cmd.BinaryCanonicalityClassification {
  ffi_cmd_BinaryCanonicalityClassification_malformed_rejected()
}

///|
pub fn cmd__BinaryCanonicalityInputClass__accepted_noncanonical() -> @cmd.BinaryCanonicalityInputClass {
  ffi_cmd_BinaryCanonicalityInputClass_accepted_noncanonical()
}

///|
pub fn cmd__BinaryCanonicalityInputClass__canonical() -> @cmd.BinaryCanonicalityInputClass {
  ffi_cmd_BinaryCanonicalityInputClass_canonical()
}

///|
pub fn cmd__BinaryCanonicalityInputClass__malformed() -> @cmd.BinaryCanonicalityInputClass {
  ffi_cmd_BinaryCanonicalityInputClass_malformed()
}

///|
pub fn cmd__BinaryDifferentialAdapterResult__adapter_unavailable(
  arg0 : String,
  arg1 : String,
) -> @cmd.BinaryDifferentialAdapterResult {
  ffi_cmd_BinaryDifferentialAdapterResult_adapter_unavailable(arg0, arg1)
}

///|
pub fn cmd__BinaryDifferentialAdapterResult__invalid_decode(
  arg0 : String,
  arg1 : String,
) -> @cmd.BinaryDifferentialAdapterResult {
  ffi_cmd_BinaryDifferentialAdapterResult_invalid_decode(arg0, arg1)
}

///|
pub fn cmd__BinaryDifferentialAdapterResult__invalid_validate(
  arg0 : String,
  arg1 : String,
) -> @cmd.BinaryDifferentialAdapterResult {
  ffi_cmd_BinaryDifferentialAdapterResult_invalid_validate(arg0, arg1)
}

///|
pub fn cmd__BinaryDifferentialAdapterResult__tool_failure(
  arg0 : String,
  arg1 : String,
) -> @cmd.BinaryDifferentialAdapterResult {
  ffi_cmd_BinaryDifferentialAdapterResult_tool_failure(arg0, arg1)
}

///|
pub fn cmd__BinaryDifferentialAdapterResult__unsupported_feature(
  arg0 : String,
  arg1 : String,
) -> @cmd.BinaryDifferentialAdapterResult {
  ffi_cmd_BinaryDifferentialAdapterResult_unsupported_feature(arg0, arg1)
}

///|
pub fn cmd__BinaryDifferentialAdapterResult__valid(
  arg0 : String,
) -> @cmd.BinaryDifferentialAdapterResult {
  ffi_cmd_BinaryDifferentialAdapterResult_valid(arg0)
}

///|
pub fn cmd__BinaryDifferentialClassification__adapter_unavailable() -> @cmd.BinaryDifferentialClassification {
  ffi_cmd_BinaryDifferentialClassification_adapter_unavailable()
}

///|
pub fn cmd__BinaryDifferentialClassification__agree_invalid() -> @cmd.BinaryDifferentialClassification {
  ffi_cmd_BinaryDifferentialClassification_agree_invalid()
}

///|
pub fn cmd__BinaryDifferentialClassification__agree_valid() -> @cmd.BinaryDifferentialClassification {
  ffi_cmd_BinaryDifferentialClassification_agree_valid()
}

///|
pub fn cmd__BinaryDifferentialClassification__decoder_stage_disagreement() -> @cmd.BinaryDifferentialClassification {
  ffi_cmd_BinaryDifferentialClassification_decoder_stage_disagreement()
}

///|
pub fn cmd__BinaryDifferentialClassification__proposal_gap() -> @cmd.BinaryDifferentialClassification {
  ffi_cmd_BinaryDifferentialClassification_proposal_gap()
}

///|
pub fn cmd__BinaryDifferentialClassification__tool_failure() -> @cmd.BinaryDifferentialClassification {
  ffi_cmd_BinaryDifferentialClassification_tool_failure()
}

///|
pub fn cmd__BinaryDifferentialClassification__unsupported_feature() -> @cmd.BinaryDifferentialClassification {
  ffi_cmd_BinaryDifferentialClassification_unsupported_feature()
}

///|
pub fn cmd__BinaryDifferentialClassification__validator_stage_disagreement() -> @cmd.BinaryDifferentialClassification {
  ffi_cmd_BinaryDifferentialClassification_validator_stage_disagreement()
}

///|
pub fn cmd__CmdError__ambiguous_output_file(arg0 : String) -> @cmd.CmdError {
  ffi_cmd_CmdError_ambiguous_output_file(arg0)
}

///|
pub fn cmd__CmdError__unknown_pass_flag(arg0 : String) -> @cmd.CmdError {
  ffi_cmd_CmdError_unknown_pass_flag(arg0)
}

///|
pub fn cmd__CmdFuzzStats__new(
  arg0 : Int?,
  arg1 : Int?,
  arg2 : Int?,
  arg3 : Int?,
  arg4 : Int?,
  arg5 : Int?,
  arg6 : Int?,
  arg7 : Int?,
  arg8 : Int?,
  arg9 : Int?,
  arg10 : String?,
  arg11 : String?,
) -> @cmd.CmdFuzzStats {
  ffi_cmd_CmdFuzzStats_new(
    arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11,
  )
}

///|
pub fn cmd__CmdRunSummary__new(
  arg0 : Array[String]?,
  arg1 : Array[String]?,
  arg2 : Array[String]?,
  arg3 : Int?,
  arg4 : Int?,
  arg5 : Bool?,
  arg6 : Bool?,
  arg7 : Int?,
  arg8 : Bool?,
  arg9 : Bool?,
  arg10 : UInt64?,
) -> @cmd.CmdRunSummary {
  ffi_cmd_CmdRunSummary_new(
    arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10,
  )
}

///|
pub fn cmd__ExportInvocationClassification__equal_result() -> @cmd.ExportInvocationClassification {
  ffi_cmd_ExportInvocationClassification_equal_result()
}

///|
pub fn cmd__ExportInvocationClassification__equal_trap() -> @cmd.ExportInvocationClassification {
  ffi_cmd_ExportInvocationClassification_equal_trap()
}

///|
pub fn cmd__ExportInvocationClassification__nondeterministic_import() -> @cmd.ExportInvocationClassification {
  ffi_cmd_ExportInvocationClassification_nondeterministic_import()
}

///|
pub fn cmd__ExportInvocationClassification__semantic_mismatch(
  arg0 : String,
) -> @cmd.ExportInvocationClassification {
  ffi_cmd_ExportInvocationClassification_semantic_mismatch(arg0)
}

///|
pub fn cmd__ExportInvocationClassification__unsupported_runtime() -> @cmd.ExportInvocationClassification {
  ffi_cmd_ExportInvocationClassification_unsupported_runtime()
}

///|
pub fn cmd__ExportInvocationFailurePolicy__fail_on_semantic_mismatch() -> @cmd.ExportInvocationFailurePolicy {
  ffi_cmd_ExportInvocationFailurePolicy_fail_on_semantic_mismatch()
}

///|
pub fn cmd__ExportInvocationFailurePolicy__informational() -> @cmd.ExportInvocationFailurePolicy {
  ffi_cmd_ExportInvocationFailurePolicy_informational()
}

///|
pub fn cmd__ExportInvocationMatrixOutcome__all_equal() -> @cmd.ExportInvocationMatrixOutcome {
  ffi_cmd_ExportInvocationMatrixOutcome_all_equal()
}

///|
pub fn cmd__ExportInvocationMatrixOutcome__blocked() -> @cmd.ExportInvocationMatrixOutcome {
  ffi_cmd_ExportInvocationMatrixOutcome_blocked()
}

///|
pub fn cmd__ExportInvocationMatrixOutcome__empty() -> @cmd.ExportInvocationMatrixOutcome {
  ffi_cmd_ExportInvocationMatrixOutcome_empty()
}

///|
pub fn cmd__ExportInvocationMatrixOutcome__semantic_mismatch() -> @cmd.ExportInvocationMatrixOutcome {
  ffi_cmd_ExportInvocationMatrixOutcome_semantic_mismatch()
}

///|
pub fn cmd__ExportInvocationResult__nondeterministic_import(
  arg0 : String,
) -> @cmd.ExportInvocationResult {
  ffi_cmd_ExportInvocationResult_nondeterministic_import(arg0)
}

///|
pub fn cmd__ExportInvocationResult__trap(
  arg0 : String,
) -> @cmd.ExportInvocationResult {
  ffi_cmd_ExportInvocationResult_trap(arg0)
}

///|
pub fn cmd__ExportInvocationResult__unsupported_runtime(
  arg0 : String,
) -> @cmd.ExportInvocationResult {
  ffi_cmd_ExportInvocationResult_unsupported_runtime(arg0)
}

///|
pub fn cmd__ExportInvocationResult__value(
  arg0 : String,
) -> @cmd.ExportInvocationResult {
  ffi_cmd_ExportInvocationResult_value(arg0)
}

///|
pub fn cmd__FuzzCorpusDedupIndex__new() -> @cmd.FuzzCorpusDedupIndex {
  ffi_cmd_FuzzCorpusDedupIndex_new()
}

///|
pub fn cmd__FuzzCorpusDedupIndex__record(
  arg0 : @cmd.FuzzCorpusDedupIndex,
  arg1 : Bytes,
  arg2 : @cmd.FuzzCorpusSource,
) -> @cmd.FuzzCorpusDedupDecision {
  ffi_cmd_FuzzCorpusDedupIndex_record(arg0, arg1, arg2)
}

///|
pub fn cmd__FuzzCorpusDedupIndex__to_text(
  arg0 : @cmd.FuzzCorpusDedupIndex,
) -> String {
  ffi_cmd_FuzzCorpusDedupIndex_to_text(arg0)
}

///|
pub fn cmd__FuzzCorpusSource__new(
  arg0 : UInt64,
  arg1 : Int,
  arg2 : String,
  arg3 : String,
  arg4 : String,
) -> @cmd.FuzzCorpusSource {
  ffi_cmd_FuzzCorpusSource_new(arg0, arg1, arg2, arg3, arg4)
}

///|
pub fn cmd__FuzzFailureReport__new(
  arg0 : UInt64,
  arg1 : Int,
  arg2 : Int,
  arg3 : String,
  arg4 : String,
  arg5 : Array[String]?,
  arg6 : Array[String]?,
  arg7 : String?,
  arg8 : String?,
  arg9 : String?,
  arg10 : Int?,
  arg11 : String?,
  arg12 : Bytes??,
  arg13 : Bytes??,
  arg14 : Int??,
  arg15 : Int??,
  arg16 : Int??,
  arg17 : Array[@cmd.FuzzReductionStep]?,
) -> @cmd.FuzzFailureReport {
  ffi_cmd_FuzzFailureReport_new(
    arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12,
    arg13, arg14, arg15, arg16, arg17,
  )
}

///|
pub fn cmd__InliningOptions__new(
  arg0 : Int?,
  arg1 : Int?,
  arg2 : Int?,
  arg3 : Int?,
  arg4 : Bool?,
  arg5 : Int?,
) -> @cmd.InliningOptions {
  ffi_cmd_InliningOptions_new(arg0, arg1, arg2, arg3, arg4, arg5)
}

///|
pub fn cmd__OptimizeOptions__new(
  arg0 : Int?,
  arg1 : Int?,
  arg2 : @cmd.InliningOptions?,
  arg3 : Int?,
  arg4 : Bool?,
  arg5 : Bool?,
  arg6 : Bool?,
  arg7 : Bool?,
  arg8 : UInt64?,
  arg9 : Bool?,
  arg10 : Bool?,
  arg11 : @passes.CompilerFactUsePolicy?,
  arg12 : @cmd.OptimizeValidationPolicy?,
  arg13 : Bool?,
) -> @cmd.OptimizeOptions {
  ffi_cmd_OptimizeOptions_new(
    arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12,
    arg13,
  )
}

///|
pub fn cmd__OptimizeTracingLevel__helper() -> @cmd.OptimizeTracingLevel {
  ffi_cmd_OptimizeTracingLevel_helper()
}

///|
pub fn cmd__OptimizeTracingLevel__pass() -> @cmd.OptimizeTracingLevel {
  ffi_cmd_OptimizeTracingLevel_pass()
}

///|
pub fn cmd__OptimizeTracingLevel__phase() -> @cmd.OptimizeTracingLevel {
  ffi_cmd_OptimizeTracingLevel_phase()
}

///|
pub fn cmd__OptimizeValidationPolicy__after_segment() -> @cmd.OptimizeValidationPolicy {
  ffi_cmd_OptimizeValidationPolicy_after_segment()
}

///|
pub fn cmd__OptimizeValidationPolicy__final_module_only() -> @cmd.OptimizeValidationPolicy {
  ffi_cmd_OptimizeValidationPolicy_final_module_only()
}

///|
pub fn cmd__TextAggregateAdapterResult__external_accepted(
  arg0 : String,
  arg1 : Bool??,
) -> @cmd.TextAggregateAdapterResult {
  ffi_cmd_TextAggregateAdapterResult_external_accepted(arg0, arg1)
}

///|
pub fn cmd__TextAggregateAdapterResult__external_parse_error(
  arg0 : String,
  arg1 : String,
) -> @cmd.TextAggregateAdapterResult {
  ffi_cmd_TextAggregateAdapterResult_external_parse_error(arg0, arg1)
}

///|
pub fn cmd__TextAggregateAdapterResult__external_unavailable(
  arg0 : String,
  arg1 : String,
) -> @cmd.TextAggregateAdapterResult {
  ffi_cmd_TextAggregateAdapterResult_external_unavailable(arg0, arg1)
}

///|
pub fn cmd__TextAggregateAdapterResult__external_unsupported_syntax(
  arg0 : String,
  arg1 : String,
) -> @cmd.TextAggregateAdapterResult {
  ffi_cmd_TextAggregateAdapterResult_external_unsupported_syntax(arg0, arg1)
}

///|
pub fn cmd__TextAggregateClassification__accepted() -> @cmd.TextAggregateClassification {
  ffi_cmd_TextAggregateClassification_accepted()
}

///|
pub fn cmd__TextAggregateClassification__adapter_unavailable() -> @cmd.TextAggregateClassification {
  ffi_cmd_TextAggregateClassification_adapter_unavailable()
}

///|
pub fn cmd__TextAggregateClassification__lower_disagreement() -> @cmd.TextAggregateClassification {
  ffi_cmd_TextAggregateClassification_lower_disagreement()
}

///|
pub fn cmd__TextAggregateClassification__parse_disagreement() -> @cmd.TextAggregateClassification {
  ffi_cmd_TextAggregateClassification_parse_disagreement()
}

///|
pub fn cmd__TextAggregateClassification__print_disagreement() -> @cmd.TextAggregateClassification {
  ffi_cmd_TextAggregateClassification_print_disagreement()
}

///|
pub fn cmd__TextAggregateClassification__semantic_validation_disagreement() -> @cmd.TextAggregateClassification {
  ffi_cmd_TextAggregateClassification_semantic_validation_disagreement()
}

///|
pub fn cmd__TextAggregateClassification__unsupported_syntax() -> @cmd.TextAggregateClassification {
  ffi_cmd_TextAggregateClassification_unsupported_syntax()
}

///|
pub fn lib__apply_pretty_context(
  arg0 : String,
  arg1 : @lib.PrettyPrintContext,
) -> String {
  ffi_lib_apply_pretty_context(arg0, arg1)
}

///|
pub fn lib__array_comp_type(arg0 : @lib.FieldType) -> @lib.CompType {
  ffi_lib_array_comp_type(arg0)
}

///|
pub fn lib__comp_type_sub_type(
  arg0 : @lib.CompType,
  arg1 : @lib.TypeMetadata?,
) -> @lib.SubType {
  ffi_lib_comp_type_sub_type(arg0, arg1)
}

///|
pub fn lib__func_comp_type(
  arg0 : Array[@lib.ValType],
  arg1 : Array[@lib.ValType],
) -> @lib.CompType {
  ffi_lib_func_comp_type(arg0, arg1)
}

///|
pub fn lib__func_extern_idx(arg0 : @lib.FuncIdx) -> @lib.ExternIdx {
  ffi_lib_func_extern_idx(arg0)
}

///|
pub fn lib__func_extern_type(arg0 : @lib.TypeIdx) -> @lib.ExternType {
  ffi_lib_func_extern_type(arg0)
}

///|
pub fn lib__func_idx(arg0 : UInt) -> @lib.FuncIdx {
  ffi_lib_func_idx(arg0)
}

///|
pub fn lib__get_struct_field(
  arg0 : Array[@lib.FieldType],
  arg1 : @lib.U32,
) -> Result[@lib.FieldType, String] {
  ffi_lib_get_struct_field(arg0, arg1)
}

///|
pub fn lib__global_extern_idx(arg0 : @lib.GlobalIdx) -> @lib.ExternIdx {
  ffi_lib_global_extern_idx(arg0)
}

///|
pub fn lib__global_extern_type(arg0 : @lib.GlobalType) -> @lib.ExternType {
  ffi_lib_global_extern_type(arg0)
}

///|
pub fn lib__global_idx(arg0 : UInt) -> @lib.GlobalIdx {
  ffi_lib_global_idx(arg0)
}

///|
pub fn lib__global_type(arg0 : @lib.ValType, arg1 : Bool) -> @lib.GlobalType {
  ffi_lib_global_type(arg0, arg1)
}

///|
pub fn lib__group_rec_type(arg0 : Array[@lib.SubType]) -> @lib.RecType {
  ffi_lib_group_rec_type(arg0)
}

///|
pub fn lib__has_default(arg0 : @lib.ValType) -> Bool {
  ffi_lib_has_default(arg0)
}

///|
pub fn lib__mem_extern_idx(arg0 : @lib.MemIdx) -> @lib.ExternIdx {
  ffi_lib_mem_extern_idx(arg0)
}

///|
pub fn lib__mem_extern_type(arg0 : @lib.MemType) -> @lib.ExternType {
  ffi_lib_mem_extern_type(arg0)
}

///|
pub fn lib__mem_type(arg0 : @lib.Limits, arg1 : Bool?) -> @lib.MemType {
  ffi_lib_mem_type(arg0, arg1)
}

///|
pub fn lib__min_addr(arg0 : @lib.Limits, arg1 : @lib.Limits) -> @lib.Limits {
  ffi_lib_min_addr(arg0, arg1)
}

///|
pub fn lib__min_addr_valtype(
  arg0 : @lib.Limits,
  arg1 : @lib.Limits,
) -> @lib.ValType {
  ffi_lib_min_addr_valtype(arg0, arg1)
}

///|
pub fn lib__module_uses_custom_descriptors(arg0 : @lib.Module) -> Bool {
  ffi_lib_module_uses_custom_descriptors(arg0)
}

///|
pub fn lib__rec_idx(arg0 : UInt) -> @lib.TypeIdx {
  ffi_lib_rec_idx(arg0)
}

///|
pub fn lib__result_type(arg0 : Array[@lib.ValType]) -> Array[@lib.ValType] {
  ffi_lib_result_type(arg0)
}

///|
pub fn lib__single_rec_type(arg0 : @lib.SubType) -> @lib.RecType {
  ffi_lib_single_rec_type(arg0)
}

///|
pub fn lib__struct_comp_type(arg0 : Array[@lib.FieldType]) -> @lib.CompType {
  ffi_lib_struct_comp_type(arg0)
}

///|
pub fn lib__sub_type(
  arg0 : Bool,
  arg1 : Array[@lib.TypeIdx],
  arg2 : @lib.CompType,
  arg3 : @lib.TypeMetadata?,
) -> @lib.SubType {
  ffi_lib_sub_type(arg0, arg1, arg2, arg3)
}

///|
pub fn lib__table_extern_idx(arg0 : @lib.TableIdx) -> @lib.ExternIdx {
  ffi_lib_table_extern_idx(arg0)
}

///|
pub fn lib__table_extern_type(arg0 : @lib.TableType) -> @lib.ExternType {
  ffi_lib_table_extern_type(arg0)
}

///|
pub fn lib__table_idx(arg0 : UInt) -> @lib.TableIdx {
  ffi_lib_table_idx(arg0)
}

///|
pub fn lib__tag_extern_idx(arg0 : @lib.TagIdx) -> @lib.ExternIdx {
  ffi_lib_tag_extern_idx(arg0)
}

///|
pub fn lib__tag_extern_type(arg0 : @lib.TagType) -> @lib.ExternType {
  ffi_lib_tag_extern_type(arg0)
}

///|
pub fn lib__tag_type(arg0 : @lib.TypeIdx) -> @lib.TagType {
  ffi_lib_tag_type(arg0)
}

///|
pub fn lib__trace_delta_us_to_ms(arg0 : UInt64) -> UInt64 {
  ffi_lib_trace_delta_us_to_ms(arg0)
}

///|
pub fn lib__trace_elapsed_ms(arg0 : UInt64) -> UInt64 {
  ffi_lib_trace_elapsed_ms(arg0)
}

///|
pub fn lib__trace_elapsed_us_since(arg0 : UInt64) -> UInt64 {
  ffi_lib_trace_elapsed_us_since(arg0)
}

///|
pub fn lib__trace_now_ms() -> UInt64 {
  ffi_lib_trace_now_ms()
}

///|
pub fn lib__trace_now_us() -> UInt64 {
  ffi_lib_trace_now_us()
}

///|
pub fn lib__AbsHeapType__any() -> @lib.AbsHeapType {
  ffi_lib_AbsHeapType_any()
}

///|
pub fn lib__AbsHeapType__array() -> @lib.AbsHeapType {
  ffi_lib_AbsHeapType_array()
}

///|
pub fn lib__AbsHeapType__cont() -> @lib.AbsHeapType {
  ffi_lib_AbsHeapType_cont()
}

///|
pub fn lib__AbsHeapType__eq() -> @lib.AbsHeapType {
  ffi_lib_AbsHeapType_eq()
}

///|
pub fn lib__AbsHeapType__exn() -> @lib.AbsHeapType {
  ffi_lib_AbsHeapType_exn()
}

///|
pub fn lib__AbsHeapType__extern_() -> @lib.AbsHeapType {
  ffi_lib_AbsHeapType_extern_()
}

///|
pub fn lib__AbsHeapType__func() -> @lib.AbsHeapType {
  ffi_lib_AbsHeapType_func()
}

///|
pub fn lib__AbsHeapType__i31() -> @lib.AbsHeapType {
  ffi_lib_AbsHeapType_i31()
}

///|
pub fn lib__AbsHeapType__no_cont() -> @lib.AbsHeapType {
  ffi_lib_AbsHeapType_no_cont()
}

///|
pub fn lib__AbsHeapType__no_exn() -> @lib.AbsHeapType {
  ffi_lib_AbsHeapType_no_exn()
}

///|
pub fn lib__AbsHeapType__no_extern() -> @lib.AbsHeapType {
  ffi_lib_AbsHeapType_no_extern()
}

///|
pub fn lib__AbsHeapType__no_func() -> @lib.AbsHeapType {
  ffi_lib_AbsHeapType_no_func()
}

///|
pub fn lib__AbsHeapType__no_waitqueue() -> @lib.AbsHeapType {
  ffi_lib_AbsHeapType_no_waitqueue()
}

///|
pub fn lib__AbsHeapType__none() -> @lib.AbsHeapType {
  ffi_lib_AbsHeapType_none()
}

///|
pub fn lib__AbsHeapType__string_() -> @lib.AbsHeapType {
  ffi_lib_AbsHeapType_string_()
}

///|
pub fn lib__AbsHeapType__struct_() -> @lib.AbsHeapType {
  ffi_lib_AbsHeapType_struct_()
}

///|
pub fn lib__AbsHeapType__waitqueue() -> @lib.AbsHeapType {
  ffi_lib_AbsHeapType_waitqueue()
}

///|
pub fn lib__AggregateAtomicRmwOp__add() -> @lib.AggregateAtomicRmwOp {
  ffi_lib_AggregateAtomicRmwOp_add()
}

///|
pub fn lib__AggregateAtomicRmwOp__and_() -> @lib.AggregateAtomicRmwOp {
  ffi_lib_AggregateAtomicRmwOp_and_()
}

///|
pub fn lib__AggregateAtomicRmwOp__or_() -> @lib.AggregateAtomicRmwOp {
  ffi_lib_AggregateAtomicRmwOp_or_()
}

///|
pub fn lib__AggregateAtomicRmwOp__sub() -> @lib.AggregateAtomicRmwOp {
  ffi_lib_AggregateAtomicRmwOp_sub()
}

///|
pub fn lib__AggregateAtomicRmwOp__xchg() -> @lib.AggregateAtomicRmwOp {
  ffi_lib_AggregateAtomicRmwOp_xchg()
}

///|
pub fn lib__AggregateAtomicRmwOp__xor() -> @lib.AggregateAtomicRmwOp {
  ffi_lib_AggregateAtomicRmwOp_xor()
}

///|
pub fn lib__AtomicCmpxchgOp__i32() -> @lib.AtomicCmpxchgOp {
  ffi_lib_AtomicCmpxchgOp_i32()
}

///|
pub fn lib__AtomicCmpxchgOp__i32_16_u() -> @lib.AtomicCmpxchgOp {
  ffi_lib_AtomicCmpxchgOp_i32_16_u()
}

///|
pub fn lib__AtomicCmpxchgOp__i32_8_u() -> @lib.AtomicCmpxchgOp {
  ffi_lib_AtomicCmpxchgOp_i32_8_u()
}

///|
pub fn lib__AtomicCmpxchgOp__i64() -> @lib.AtomicCmpxchgOp {
  ffi_lib_AtomicCmpxchgOp_i64()
}

///|
pub fn lib__AtomicCmpxchgOp__i64_16_u() -> @lib.AtomicCmpxchgOp {
  ffi_lib_AtomicCmpxchgOp_i64_16_u()
}

///|
pub fn lib__AtomicCmpxchgOp__i64_32_u() -> @lib.AtomicCmpxchgOp {
  ffi_lib_AtomicCmpxchgOp_i64_32_u()
}

///|
pub fn lib__AtomicCmpxchgOp__i64_8_u() -> @lib.AtomicCmpxchgOp {
  ffi_lib_AtomicCmpxchgOp_i64_8_u()
}

///|
pub fn lib__AtomicOrder__acq_rel() -> @lib.AtomicOrder {
  ffi_lib_AtomicOrder_acq_rel()
}

///|
pub fn lib__AtomicOrder__relaxed() -> @lib.AtomicOrder {
  ffi_lib_AtomicOrder_relaxed()
}

///|
pub fn lib__AtomicOrder__seq_cst() -> @lib.AtomicOrder {
  ffi_lib_AtomicOrder_seq_cst()
}

///|
pub fn lib__AtomicRmwOp__i32_16_add_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i32_16_add_u()
}

///|
pub fn lib__AtomicRmwOp__i32_16_and_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i32_16_and_u()
}

///|
pub fn lib__AtomicRmwOp__i32_16_or_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i32_16_or_u()
}

///|
pub fn lib__AtomicRmwOp__i32_16_sub_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i32_16_sub_u()
}

///|
pub fn lib__AtomicRmwOp__i32_16_xchg_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i32_16_xchg_u()
}

///|
pub fn lib__AtomicRmwOp__i32_16_xor_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i32_16_xor_u()
}

///|
pub fn lib__AtomicRmwOp__i32_8_add_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i32_8_add_u()
}

///|
pub fn lib__AtomicRmwOp__i32_8_and_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i32_8_and_u()
}

///|
pub fn lib__AtomicRmwOp__i32_8_or_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i32_8_or_u()
}

///|
pub fn lib__AtomicRmwOp__i32_8_sub_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i32_8_sub_u()
}

///|
pub fn lib__AtomicRmwOp__i32_8_xchg_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i32_8_xchg_u()
}

///|
pub fn lib__AtomicRmwOp__i32_8_xor_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i32_8_xor_u()
}

///|
pub fn lib__AtomicRmwOp__i32_add() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i32_add()
}

///|
pub fn lib__AtomicRmwOp__i32_and() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i32_and()
}

///|
pub fn lib__AtomicRmwOp__i32_or() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i32_or()
}

///|
pub fn lib__AtomicRmwOp__i32_sub() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i32_sub()
}

///|
pub fn lib__AtomicRmwOp__i32_xchg() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i32_xchg()
}

///|
pub fn lib__AtomicRmwOp__i32_xor() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i32_xor()
}

///|
pub fn lib__AtomicRmwOp__i64_16_add_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_16_add_u()
}

///|
pub fn lib__AtomicRmwOp__i64_16_and_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_16_and_u()
}

///|
pub fn lib__AtomicRmwOp__i64_16_or_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_16_or_u()
}

///|
pub fn lib__AtomicRmwOp__i64_16_sub_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_16_sub_u()
}

///|
pub fn lib__AtomicRmwOp__i64_16_xchg_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_16_xchg_u()
}

///|
pub fn lib__AtomicRmwOp__i64_16_xor_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_16_xor_u()
}

///|
pub fn lib__AtomicRmwOp__i64_32_add_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_32_add_u()
}

///|
pub fn lib__AtomicRmwOp__i64_32_and_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_32_and_u()
}

///|
pub fn lib__AtomicRmwOp__i64_32_or_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_32_or_u()
}

///|
pub fn lib__AtomicRmwOp__i64_32_sub_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_32_sub_u()
}

///|
pub fn lib__AtomicRmwOp__i64_32_xchg_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_32_xchg_u()
}

///|
pub fn lib__AtomicRmwOp__i64_32_xor_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_32_xor_u()
}

///|
pub fn lib__AtomicRmwOp__i64_8_add_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_8_add_u()
}

///|
pub fn lib__AtomicRmwOp__i64_8_and_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_8_and_u()
}

///|
pub fn lib__AtomicRmwOp__i64_8_or_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_8_or_u()
}

///|
pub fn lib__AtomicRmwOp__i64_8_sub_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_8_sub_u()
}

///|
pub fn lib__AtomicRmwOp__i64_8_xchg_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_8_xchg_u()
}

///|
pub fn lib__AtomicRmwOp__i64_8_xor_u() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_8_xor_u()
}

///|
pub fn lib__AtomicRmwOp__i64_add() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_add()
}

///|
pub fn lib__AtomicRmwOp__i64_and() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_and()
}

///|
pub fn lib__AtomicRmwOp__i64_or() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_or()
}

///|
pub fn lib__AtomicRmwOp__i64_sub() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_sub()
}

///|
pub fn lib__AtomicRmwOp__i64_xchg() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_xchg()
}

///|
pub fn lib__AtomicRmwOp__i64_xor() -> @lib.AtomicRmwOp {
  ffi_lib_AtomicRmwOp_i64_xor()
}

///|
pub fn lib__BinaryOp__f32_add() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32_add()
}

///|
pub fn lib__BinaryOp__f32_copysign() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32_copysign()
}

///|
pub fn lib__BinaryOp__f32_div() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32_div()
}

///|
pub fn lib__BinaryOp__f32_eq() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32_eq()
}

///|
pub fn lib__BinaryOp__f32_ge() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32_ge()
}

///|
pub fn lib__BinaryOp__f32_gt() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32_gt()
}

///|
pub fn lib__BinaryOp__f32_le() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32_le()
}

///|
pub fn lib__BinaryOp__f32_lt() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32_lt()
}

///|
pub fn lib__BinaryOp__f32_max() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32_max()
}

///|
pub fn lib__BinaryOp__f32_min() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32_min()
}

///|
pub fn lib__BinaryOp__f32_mul() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32_mul()
}

///|
pub fn lib__BinaryOp__f32_ne() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32_ne()
}

///|
pub fn lib__BinaryOp__f32_sub() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32_sub()
}

///|
pub fn lib__BinaryOp__f32x4_add() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32x4_add()
}

///|
pub fn lib__BinaryOp__f32x4_div() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32x4_div()
}

///|
pub fn lib__BinaryOp__f32x4_eq() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32x4_eq()
}

///|
pub fn lib__BinaryOp__f32x4_ge() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32x4_ge()
}

///|
pub fn lib__BinaryOp__f32x4_gt() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32x4_gt()
}

///|
pub fn lib__BinaryOp__f32x4_le() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32x4_le()
}

///|
pub fn lib__BinaryOp__f32x4_lt() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32x4_lt()
}

///|
pub fn lib__BinaryOp__f32x4_max() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32x4_max()
}

///|
pub fn lib__BinaryOp__f32x4_min() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32x4_min()
}

///|
pub fn lib__BinaryOp__f32x4_mul() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32x4_mul()
}

///|
pub fn lib__BinaryOp__f32x4_ne() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32x4_ne()
}

///|
pub fn lib__BinaryOp__f32x4_pmax() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32x4_pmax()
}

///|
pub fn lib__BinaryOp__f32x4_pmin() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32x4_pmin()
}

///|
pub fn lib__BinaryOp__f32x4_relaxed_max() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32x4_relaxed_max()
}

///|
pub fn lib__BinaryOp__f32x4_relaxed_min() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32x4_relaxed_min()
}

///|
pub fn lib__BinaryOp__f32x4_sub() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f32x4_sub()
}

///|
pub fn lib__BinaryOp__f64_add() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64_add()
}

///|
pub fn lib__BinaryOp__f64_copysign() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64_copysign()
}

///|
pub fn lib__BinaryOp__f64_div() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64_div()
}

///|
pub fn lib__BinaryOp__f64_eq() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64_eq()
}

///|
pub fn lib__BinaryOp__f64_ge() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64_ge()
}

///|
pub fn lib__BinaryOp__f64_gt() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64_gt()
}

///|
pub fn lib__BinaryOp__f64_le() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64_le()
}

///|
pub fn lib__BinaryOp__f64_lt() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64_lt()
}

///|
pub fn lib__BinaryOp__f64_max() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64_max()
}

///|
pub fn lib__BinaryOp__f64_min() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64_min()
}

///|
pub fn lib__BinaryOp__f64_mul() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64_mul()
}

///|
pub fn lib__BinaryOp__f64_ne() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64_ne()
}

///|
pub fn lib__BinaryOp__f64_sub() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64_sub()
}

///|
pub fn lib__BinaryOp__f64x2_add() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64x2_add()
}

///|
pub fn lib__BinaryOp__f64x2_div() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64x2_div()
}

///|
pub fn lib__BinaryOp__f64x2_eq() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64x2_eq()
}

///|
pub fn lib__BinaryOp__f64x2_ge() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64x2_ge()
}

///|
pub fn lib__BinaryOp__f64x2_gt() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64x2_gt()
}

///|
pub fn lib__BinaryOp__f64x2_le() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64x2_le()
}

///|
pub fn lib__BinaryOp__f64x2_lt() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64x2_lt()
}

///|
pub fn lib__BinaryOp__f64x2_max() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64x2_max()
}

///|
pub fn lib__BinaryOp__f64x2_min() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64x2_min()
}

///|
pub fn lib__BinaryOp__f64x2_mul() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64x2_mul()
}

///|
pub fn lib__BinaryOp__f64x2_ne() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64x2_ne()
}

///|
pub fn lib__BinaryOp__f64x2_pmax() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64x2_pmax()
}

///|
pub fn lib__BinaryOp__f64x2_pmin() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64x2_pmin()
}

///|
pub fn lib__BinaryOp__f64x2_relaxed_max() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64x2_relaxed_max()
}

///|
pub fn lib__BinaryOp__f64x2_relaxed_min() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64x2_relaxed_min()
}

///|
pub fn lib__BinaryOp__f64x2_sub() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_f64x2_sub()
}

///|
pub fn lib__BinaryOp__i16x8_add() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_add()
}

///|
pub fn lib__BinaryOp__i16x8_add_sat_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_add_sat_s()
}

///|
pub fn lib__BinaryOp__i16x8_add_sat_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_add_sat_u()
}

///|
pub fn lib__BinaryOp__i16x8_avgr_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_avgr_u()
}

///|
pub fn lib__BinaryOp__i16x8_eq() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_eq()
}

///|
pub fn lib__BinaryOp__i16x8_extmul_high_i8x16s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_extmul_high_i8x16s()
}

///|
pub fn lib__BinaryOp__i16x8_extmul_high_i8x16u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_extmul_high_i8x16u()
}

///|
pub fn lib__BinaryOp__i16x8_extmul_low_i8x16s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_extmul_low_i8x16s()
}

///|
pub fn lib__BinaryOp__i16x8_extmul_low_i8x16u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_extmul_low_i8x16u()
}

///|
pub fn lib__BinaryOp__i16x8_ge_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_ge_s()
}

///|
pub fn lib__BinaryOp__i16x8_ge_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_ge_u()
}

///|
pub fn lib__BinaryOp__i16x8_gt_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_gt_s()
}

///|
pub fn lib__BinaryOp__i16x8_gt_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_gt_u()
}

///|
pub fn lib__BinaryOp__i16x8_le_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_le_s()
}

///|
pub fn lib__BinaryOp__i16x8_le_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_le_u()
}

///|
pub fn lib__BinaryOp__i16x8_lt_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_lt_s()
}

///|
pub fn lib__BinaryOp__i16x8_lt_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_lt_u()
}

///|
pub fn lib__BinaryOp__i16x8_max_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_max_s()
}

///|
pub fn lib__BinaryOp__i16x8_max_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_max_u()
}

///|
pub fn lib__BinaryOp__i16x8_min_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_min_s()
}

///|
pub fn lib__BinaryOp__i16x8_min_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_min_u()
}

///|
pub fn lib__BinaryOp__i16x8_mul() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_mul()
}

///|
pub fn lib__BinaryOp__i16x8_narrow_i32x4s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_narrow_i32x4s()
}

///|
pub fn lib__BinaryOp__i16x8_narrow_i32x4u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_narrow_i32x4u()
}

///|
pub fn lib__BinaryOp__i16x8_ne() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_ne()
}

///|
pub fn lib__BinaryOp__i16x8_relaxed_dot_i8x16i7x16s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_relaxed_dot_i8x16i7x16s()
}

///|
pub fn lib__BinaryOp__i16x8_relaxed_q15mulr_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_relaxed_q15mulr_s()
}

///|
pub fn lib__BinaryOp__i16x8_sub() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_sub()
}

///|
pub fn lib__BinaryOp__i16x8_sub_sat_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_sub_sat_s()
}

///|
pub fn lib__BinaryOp__i16x8_sub_sat_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8_sub_sat_u()
}

///|
pub fn lib__BinaryOp__i16x8q15mulr_sat_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i16x8q15mulr_sat_s()
}

///|
pub fn lib__BinaryOp__i32_add() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_add()
}

///|
pub fn lib__BinaryOp__i32_and() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_and()
}

///|
pub fn lib__BinaryOp__i32_div_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_div_s()
}

///|
pub fn lib__BinaryOp__i32_div_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_div_u()
}

///|
pub fn lib__BinaryOp__i32_eq() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_eq()
}

///|
pub fn lib__BinaryOp__i32_ge_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_ge_s()
}

///|
pub fn lib__BinaryOp__i32_ge_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_ge_u()
}

///|
pub fn lib__BinaryOp__i32_gt_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_gt_s()
}

///|
pub fn lib__BinaryOp__i32_gt_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_gt_u()
}

///|
pub fn lib__BinaryOp__i32_le_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_le_s()
}

///|
pub fn lib__BinaryOp__i32_le_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_le_u()
}

///|
pub fn lib__BinaryOp__i32_lt_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_lt_s()
}

///|
pub fn lib__BinaryOp__i32_lt_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_lt_u()
}

///|
pub fn lib__BinaryOp__i32_mul() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_mul()
}

///|
pub fn lib__BinaryOp__i32_ne() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_ne()
}

///|
pub fn lib__BinaryOp__i32_or() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_or()
}

///|
pub fn lib__BinaryOp__i32_rem_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_rem_s()
}

///|
pub fn lib__BinaryOp__i32_rem_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_rem_u()
}

///|
pub fn lib__BinaryOp__i32_rotl() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_rotl()
}

///|
pub fn lib__BinaryOp__i32_rotr() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_rotr()
}

///|
pub fn lib__BinaryOp__i32_shl() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_shl()
}

///|
pub fn lib__BinaryOp__i32_shr_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_shr_s()
}

///|
pub fn lib__BinaryOp__i32_shr_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_shr_u()
}

///|
pub fn lib__BinaryOp__i32_sub() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_sub()
}

///|
pub fn lib__BinaryOp__i32_xor() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32_xor()
}

///|
pub fn lib__BinaryOp__i32x4_add() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_add()
}

///|
pub fn lib__BinaryOp__i32x4_dot_i16x8s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_dot_i16x8s()
}

///|
pub fn lib__BinaryOp__i32x4_eq() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_eq()
}

///|
pub fn lib__BinaryOp__i32x4_extmul_high_i16x8s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_extmul_high_i16x8s()
}

///|
pub fn lib__BinaryOp__i32x4_extmul_high_i16x8u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_extmul_high_i16x8u()
}

///|
pub fn lib__BinaryOp__i32x4_extmul_low_i16x8s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_extmul_low_i16x8s()
}

///|
pub fn lib__BinaryOp__i32x4_extmul_low_i16x8u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_extmul_low_i16x8u()
}

///|
pub fn lib__BinaryOp__i32x4_ge_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_ge_s()
}

///|
pub fn lib__BinaryOp__i32x4_ge_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_ge_u()
}

///|
pub fn lib__BinaryOp__i32x4_gt_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_gt_s()
}

///|
pub fn lib__BinaryOp__i32x4_gt_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_gt_u()
}

///|
pub fn lib__BinaryOp__i32x4_le_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_le_s()
}

///|
pub fn lib__BinaryOp__i32x4_le_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_le_u()
}

///|
pub fn lib__BinaryOp__i32x4_lt_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_lt_s()
}

///|
pub fn lib__BinaryOp__i32x4_lt_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_lt_u()
}

///|
pub fn lib__BinaryOp__i32x4_max_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_max_s()
}

///|
pub fn lib__BinaryOp__i32x4_max_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_max_u()
}

///|
pub fn lib__BinaryOp__i32x4_min_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_min_s()
}

///|
pub fn lib__BinaryOp__i32x4_min_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_min_u()
}

///|
pub fn lib__BinaryOp__i32x4_mul() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_mul()
}

///|
pub fn lib__BinaryOp__i32x4_ne() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_ne()
}

///|
pub fn lib__BinaryOp__i32x4_sub() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i32x4_sub()
}

///|
pub fn lib__BinaryOp__i64_add() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_add()
}

///|
pub fn lib__BinaryOp__i64_and() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_and()
}

///|
pub fn lib__BinaryOp__i64_div_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_div_s()
}

///|
pub fn lib__BinaryOp__i64_div_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_div_u()
}

///|
pub fn lib__BinaryOp__i64_eq() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_eq()
}

///|
pub fn lib__BinaryOp__i64_ge_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_ge_s()
}

///|
pub fn lib__BinaryOp__i64_ge_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_ge_u()
}

///|
pub fn lib__BinaryOp__i64_gt_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_gt_s()
}

///|
pub fn lib__BinaryOp__i64_gt_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_gt_u()
}

///|
pub fn lib__BinaryOp__i64_le_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_le_s()
}

///|
pub fn lib__BinaryOp__i64_le_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_le_u()
}

///|
pub fn lib__BinaryOp__i64_lt_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_lt_s()
}

///|
pub fn lib__BinaryOp__i64_lt_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_lt_u()
}

///|
pub fn lib__BinaryOp__i64_mul() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_mul()
}

///|
pub fn lib__BinaryOp__i64_ne() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_ne()
}

///|
pub fn lib__BinaryOp__i64_or() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_or()
}

///|
pub fn lib__BinaryOp__i64_rem_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_rem_s()
}

///|
pub fn lib__BinaryOp__i64_rem_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_rem_u()
}

///|
pub fn lib__BinaryOp__i64_rotl() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_rotl()
}

///|
pub fn lib__BinaryOp__i64_rotr() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_rotr()
}

///|
pub fn lib__BinaryOp__i64_shl() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_shl()
}

///|
pub fn lib__BinaryOp__i64_shr_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_shr_s()
}

///|
pub fn lib__BinaryOp__i64_shr_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_shr_u()
}

///|
pub fn lib__BinaryOp__i64_sub() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_sub()
}

///|
pub fn lib__BinaryOp__i64_xor() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64_xor()
}

///|
pub fn lib__BinaryOp__i64x2_add() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64x2_add()
}

///|
pub fn lib__BinaryOp__i64x2_eq() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64x2_eq()
}

///|
pub fn lib__BinaryOp__i64x2_extmul_high_i32x4s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64x2_extmul_high_i32x4s()
}

///|
pub fn lib__BinaryOp__i64x2_extmul_high_i32x4u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64x2_extmul_high_i32x4u()
}

///|
pub fn lib__BinaryOp__i64x2_extmul_low_i32x4s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64x2_extmul_low_i32x4s()
}

///|
pub fn lib__BinaryOp__i64x2_extmul_low_i32x4u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64x2_extmul_low_i32x4u()
}

///|
pub fn lib__BinaryOp__i64x2_ge_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64x2_ge_s()
}

///|
pub fn lib__BinaryOp__i64x2_gt_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64x2_gt_s()
}

///|
pub fn lib__BinaryOp__i64x2_le_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64x2_le_s()
}

///|
pub fn lib__BinaryOp__i64x2_lt_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64x2_lt_s()
}

///|
pub fn lib__BinaryOp__i64x2_mul() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64x2_mul()
}

///|
pub fn lib__BinaryOp__i64x2_ne() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64x2_ne()
}

///|
pub fn lib__BinaryOp__i64x2_sub() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i64x2_sub()
}

///|
pub fn lib__BinaryOp__i8x16_add() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_add()
}

///|
pub fn lib__BinaryOp__i8x16_add_sat_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_add_sat_s()
}

///|
pub fn lib__BinaryOp__i8x16_add_sat_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_add_sat_u()
}

///|
pub fn lib__BinaryOp__i8x16_avgr_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_avgr_u()
}

///|
pub fn lib__BinaryOp__i8x16_eq() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_eq()
}

///|
pub fn lib__BinaryOp__i8x16_ge_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_ge_s()
}

///|
pub fn lib__BinaryOp__i8x16_ge_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_ge_u()
}

///|
pub fn lib__BinaryOp__i8x16_gt_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_gt_s()
}

///|
pub fn lib__BinaryOp__i8x16_gt_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_gt_u()
}

///|
pub fn lib__BinaryOp__i8x16_le_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_le_s()
}

///|
pub fn lib__BinaryOp__i8x16_le_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_le_u()
}

///|
pub fn lib__BinaryOp__i8x16_lt_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_lt_s()
}

///|
pub fn lib__BinaryOp__i8x16_lt_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_lt_u()
}

///|
pub fn lib__BinaryOp__i8x16_max_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_max_s()
}

///|
pub fn lib__BinaryOp__i8x16_max_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_max_u()
}

///|
pub fn lib__BinaryOp__i8x16_min_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_min_s()
}

///|
pub fn lib__BinaryOp__i8x16_min_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_min_u()
}

///|
pub fn lib__BinaryOp__i8x16_narrow_i16x8s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_narrow_i16x8s()
}

///|
pub fn lib__BinaryOp__i8x16_narrow_i16x8u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_narrow_i16x8u()
}

///|
pub fn lib__BinaryOp__i8x16_ne() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_ne()
}

///|
pub fn lib__BinaryOp__i8x16_sub() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_sub()
}

///|
pub fn lib__BinaryOp__i8x16_sub_sat_s() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_sub_sat_s()
}

///|
pub fn lib__BinaryOp__i8x16_sub_sat_u() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_i8x16_sub_sat_u()
}

///|
pub fn lib__BinaryOp__v128_and() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_v128_and()
}

///|
pub fn lib__BinaryOp__v128_andnot() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_v128_andnot()
}

///|
pub fn lib__BinaryOp__v128_or() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_v128_or()
}

///|
pub fn lib__BinaryOp__v128_xor() -> @lib.BinaryOp {
  ffi_lib_BinaryOp_v128_xor()
}

///|
pub fn lib__BlockType__type_idx(arg0 : @lib.TypeIdx) -> @lib.BlockType {
  ffi_lib_BlockType_type_idx(arg0)
}

///|
pub fn lib__BlockType__val_type(arg0 : @lib.ValType) -> @lib.BlockType {
  ffi_lib_BlockType_val_type(arg0)
}

///|
pub fn lib__BlockType__void_() -> @lib.BlockType {
  ffi_lib_BlockType_void_()
}

///|
pub fn lib__CastOp__new(
  arg0 : Bool,
  arg1 : Bool,
  arg2 : Bool?,
  arg3 : Bool?,
) -> @lib.CastOp {
  ffi_lib_CastOp_new(arg0, arg1, arg2, arg3)
}

///|
pub fn lib__CastOp__source_exact(arg0 : @lib.CastOp) -> Bool {
  ffi_lib_CastOp_source_exact(arg0)
}

///|
pub fn lib__CastOp__source_nullable(arg0 : @lib.CastOp) -> Bool {
  ffi_lib_CastOp_source_nullable(arg0)
}

///|
pub fn lib__CastOp__target_exact(arg0 : @lib.CastOp) -> Bool {
  ffi_lib_CastOp_target_exact(arg0)
}

///|
pub fn lib__CastOp__target_nullable(arg0 : @lib.CastOp) -> Bool {
  ffi_lib_CastOp_target_nullable(arg0)
}

///|
pub fn lib__Catch__all(arg0 : @lib.LabelIdx) -> @lib.Catch {
  ffi_lib_Catch_all(arg0)
}

///|
pub fn lib__Catch__all_ref(arg0 : @lib.LabelIdx) -> @lib.Catch {
  ffi_lib_Catch_all_ref(arg0)
}

///|
pub fn lib__Catch__new(arg0 : @lib.TagIdx, arg1 : @lib.LabelIdx) -> @lib.Catch {
  ffi_lib_Catch_new(arg0, arg1)
}

///|
pub fn lib__Catch__ref_(arg0 : @lib.TagIdx, arg1 : @lib.LabelIdx) -> @lib.Catch {
  ffi_lib_Catch_ref_(arg0, arg1)
}

///|
pub fn lib__CodeSec__new(arg0 : Array[@lib.Func]) -> @lib.CodeSec {
  ffi_lib_CodeSec_new(arg0)
}

///|
pub fn lib__CompType__array(arg0 : @lib.FieldType) -> @lib.CompType {
  ffi_lib_CompType_array(arg0)
}

///|
pub fn lib__CompType__cont(arg0 : @lib.TypeIdx) -> @lib.CompType {
  ffi_lib_CompType_cont(arg0)
}

///|
pub fn lib__CompType__func(
  arg0 : Array[@lib.ValType],
  arg1 : Array[@lib.ValType],
) -> @lib.CompType {
  ffi_lib_CompType_func(arg0, arg1)
}

///|
pub fn lib__CompType__struct_(arg0 : Array[@lib.FieldType]) -> @lib.CompType {
  ffi_lib_CompType_struct_(arg0)
}

///|
pub fn lib__CustomSec__new(arg0 : @lib.Name, arg1 : Bytes) -> @lib.CustomSec {
  ffi_lib_CustomSec_new(arg0, arg1)
}

///|
pub fn lib__Data__new(arg0 : @lib.DataMode, arg1 : Bytes) -> @lib.Data {
  ffi_lib_Data_new(arg0, arg1)
}

///|
pub fn lib__DataCntSec__new(arg0 : @lib.U32) -> @lib.DataCntSec {
  ffi_lib_DataCntSec_new(arg0)
}

///|
pub fn lib__DataIdx__new(arg0 : UInt) -> @lib.DataIdx {
  ffi_lib_DataIdx_new(arg0)
}

///|
pub fn lib__DataMode__active(
  arg0 : @lib.MemIdx,
  arg1 : @lib.Expr,
) -> @lib.DataMode {
  ffi_lib_DataMode_active(arg0, arg1)
}

///|
pub fn lib__DataMode__passive() -> @lib.DataMode {
  ffi_lib_DataMode_passive()
}

///|
pub fn lib__DataSec__new(arg0 : Array[@lib.Data]) -> @lib.DataSec {
  ffi_lib_DataSec_new(arg0)
}

///|
pub fn lib__DefType__new(arg0 : @lib.RecType, arg1 : UInt) -> @lib.DefType {
  ffi_lib_DefType_new(arg0, arg1)
}

///|
pub fn lib__DefType__project(arg0 : @lib.DefType) -> @lib.SubType? {
  ffi_lib_DefType_project(arg0)
}

///|
pub fn lib__Elem__new(arg0 : @lib.ElemMode, arg1 : @lib.ElemKind) -> @lib.Elem {
  ffi_lib_Elem_new(arg0, arg1)
}

///|
pub fn lib__Elem__reftype(arg0 : @lib.Elem) -> @lib.RefType {
  ffi_lib_Elem_reftype(arg0)
}

///|
pub fn lib__ElemIdx__new(arg0 : UInt) -> @lib.ElemIdx {
  ffi_lib_ElemIdx_new(arg0)
}

///|
pub fn lib__ElemKind__func_exprs(arg0 : Array[@lib.Expr]) -> @lib.ElemKind {
  ffi_lib_ElemKind_func_exprs(arg0)
}

///|
pub fn lib__ElemKind__funcs(arg0 : Array[@lib.FuncIdx]) -> @lib.ElemKind {
  ffi_lib_ElemKind_funcs(arg0)
}

///|
pub fn lib__ElemKind__typed_exprs(
  arg0 : @lib.RefType,
  arg1 : Array[@lib.Expr],
) -> @lib.ElemKind {
  ffi_lib_ElemKind_typed_exprs(arg0, arg1)
}

///|
pub fn lib__ElemMode__active(
  arg0 : @lib.TableIdx,
  arg1 : @lib.Expr,
) -> @lib.ElemMode {
  ffi_lib_ElemMode_active(arg0, arg1)
}

///|
pub fn lib__ElemMode__declarative() -> @lib.ElemMode {
  ffi_lib_ElemMode_declarative()
}

///|
pub fn lib__ElemMode__passive() -> @lib.ElemMode {
  ffi_lib_ElemMode_passive()
}

///|
pub fn lib__ElemSec__new(arg0 : Array[@lib.Elem]) -> @lib.ElemSec {
  ffi_lib_ElemSec_new(arg0)
}

///|
pub fn lib__Export__new(arg0 : @lib.Name, arg1 : @lib.ExternIdx) -> @lib.Export {
  ffi_lib_Export_new(arg0, arg1)
}

///|
pub fn lib__ExportSec__new(arg0 : Array[@lib.Export]) -> @lib.ExportSec {
  ffi_lib_ExportSec_new(arg0)
}

///|
pub fn lib__Expr__new(arg0 : Array[@lib.Instruction]) -> @lib.Expr {
  ffi_lib_Expr_new(arg0)
}

///|
pub fn lib__ExternIdx__func(arg0 : @lib.FuncIdx) -> @lib.ExternIdx {
  ffi_lib_ExternIdx_func(arg0)
}

///|
pub fn lib__ExternIdx__global(arg0 : @lib.GlobalIdx) -> @lib.ExternIdx {
  ffi_lib_ExternIdx_global(arg0)
}

///|
pub fn lib__ExternIdx__mem(arg0 : @lib.MemIdx) -> @lib.ExternIdx {
  ffi_lib_ExternIdx_mem(arg0)
}

///|
pub fn lib__ExternIdx__table(arg0 : @lib.TableIdx) -> @lib.ExternIdx {
  ffi_lib_ExternIdx_table(arg0)
}

///|
pub fn lib__ExternIdx__tag(arg0 : @lib.TagIdx) -> @lib.ExternIdx {
  ffi_lib_ExternIdx_tag(arg0)
}

///|
pub fn lib__ExternType__func(arg0 : @lib.TypeIdx) -> @lib.ExternType {
  ffi_lib_ExternType_func(arg0)
}

///|
pub fn lib__ExternType__global(arg0 : @lib.GlobalType) -> @lib.ExternType {
  ffi_lib_ExternType_global(arg0)
}

///|
pub fn lib__ExternType__mem(arg0 : @lib.MemType) -> @lib.ExternType {
  ffi_lib_ExternType_mem(arg0)
}

///|
pub fn lib__ExternType__table(arg0 : @lib.TableType) -> @lib.ExternType {
  ffi_lib_ExternType_table(arg0)
}

///|
pub fn lib__ExternType__tag(arg0 : @lib.TagType) -> @lib.ExternType {
  ffi_lib_ExternType_tag(arg0)
}

///|
pub fn lib__ExtractLaneOp__f32x4_extract_lane() -> @lib.ExtractLaneOp {
  ffi_lib_ExtractLaneOp_f32x4_extract_lane()
}

///|
pub fn lib__ExtractLaneOp__f64x2_extract_lane() -> @lib.ExtractLaneOp {
  ffi_lib_ExtractLaneOp_f64x2_extract_lane()
}

///|
pub fn lib__ExtractLaneOp__i16x8_extract_lane_s() -> @lib.ExtractLaneOp {
  ffi_lib_ExtractLaneOp_i16x8_extract_lane_s()
}

///|
pub fn lib__ExtractLaneOp__i16x8_extract_lane_u() -> @lib.ExtractLaneOp {
  ffi_lib_ExtractLaneOp_i16x8_extract_lane_u()
}

///|
pub fn lib__ExtractLaneOp__i32x4_extract_lane() -> @lib.ExtractLaneOp {
  ffi_lib_ExtractLaneOp_i32x4_extract_lane()
}

///|
pub fn lib__ExtractLaneOp__i64x2_extract_lane() -> @lib.ExtractLaneOp {
  ffi_lib_ExtractLaneOp_i64x2_extract_lane()
}

///|
pub fn lib__ExtractLaneOp__i8x16_extract_lane_s() -> @lib.ExtractLaneOp {
  ffi_lib_ExtractLaneOp_i8x16_extract_lane_s()
}

///|
pub fn lib__ExtractLaneOp__i8x16_extract_lane_u() -> @lib.ExtractLaneOp {
  ffi_lib_ExtractLaneOp_i8x16_extract_lane_u()
}

///|
pub fn lib__F32__new(arg0 : Float) -> @lib.F32 {
  ffi_lib_F32_new(arg0)
}

///|
pub fn lib__F64__new(arg0 : Double) -> @lib.F64 {
  ffi_lib_F64_new(arg0)
}

///|
pub fn lib__FieldType__get_storage_type(
  arg0 : @lib.FieldType,
) -> @lib.StorageType {
  ffi_lib_FieldType_get_storage_type(arg0)
}

///|
pub fn lib__FieldType__is_mutable(arg0 : @lib.FieldType) -> Bool {
  ffi_lib_FieldType_is_mutable(arg0)
}

///|
pub fn lib__FieldType__new(
  arg0 : @lib.StorageType,
  arg1 : @lib.Mut,
) -> @lib.FieldType {
  ffi_lib_FieldType_new(arg0, arg1)
}

///|
pub fn lib__FieldType__unpack(arg0 : @lib.FieldType) -> @lib.ValType {
  ffi_lib_FieldType_unpack(arg0)
}

///|
pub fn lib__Func__new(arg0 : @lib.Locals, arg1 : @lib.Expr) -> @lib.Func {
  ffi_lib_Func_new(arg0, arg1)
}

///|
pub fn lib__FuncAnnotation__new(
  arg0 : String,
  arg1 : Array[String]?,
) -> @lib.FuncAnnotation {
  ffi_lib_FuncAnnotation_new(arg0, arg1)
}

///|
pub fn lib__FuncAnnotationAssoc__new(
  arg0 : UInt,
  arg1 : Array[@lib.FuncAnnotation],
) -> @lib.FuncAnnotationAssoc {
  ffi_lib_FuncAnnotationAssoc_new(arg0, arg1)
}

///|
pub fn lib__FuncAnnotationSec__new(
  arg0 : Array[@lib.FuncAnnotationAssoc],
) -> @lib.FuncAnnotationSec {
  ffi_lib_FuncAnnotationSec_new(arg0)
}

///|
pub fn lib__FuncIdx__new(arg0 : UInt) -> @lib.FuncIdx {
  ffi_lib_FuncIdx_new(arg0)
}

///|
pub fn lib__FuncSec__new(arg0 : Array[@lib.TypeIdx]) -> @lib.FuncSec {
  ffi_lib_FuncSec_new(arg0)
}

///|
pub fn lib__FuncType__new(
  arg0 : Array[@lib.ValType],
  arg1 : Array[@lib.ValType],
) -> @lib.FuncType {
  ffi_lib_FuncType_new(arg0, arg1)
}

///|
pub fn lib__FunctionLocals__all_locals(
  arg0 : @lib.FunctionLocals,
) -> @lib.Locals {
  ffi_lib_FunctionLocals_all_locals(arg0)
}

///|
pub fn lib__FunctionLocals__body_locals(
  arg0 : @lib.FunctionLocals,
) -> @lib.Locals {
  ffi_lib_FunctionLocals_body_locals(arg0)
}

///|
pub fn lib__FunctionLocals__from_local_decls(
  arg0 : Array[@lib.ValType],
  arg1 : @lib.Locals,
) -> Result[@lib.FunctionLocals, String] {
  ffi_lib_FunctionLocals_from_local_decls(arg0, arg1)
}

///|
pub fn lib__FunctionLocals__from_typed_func(
  arg0 : Array[@lib.ValType],
  arg1 : Array[@lib.ValType],
  arg2 : @lib.Locals,
) -> Result[@lib.FunctionLocals, String] {
  ffi_lib_FunctionLocals_from_typed_func(arg0, arg1, arg2)
}

///|
pub fn lib__FunctionLocals__from_typed_func_for_pass(
  arg0 : Array[@lib.ValType],
  arg1 : Array[@lib.ValType],
  arg2 : @lib.Locals,
) -> Result[@lib.FunctionLocals, String] {
  ffi_lib_FunctionLocals_from_typed_func_for_pass(arg0, arg1, arg2)
}

///|
pub fn lib__FunctionLocals__local_type(
  arg0 : @lib.FunctionLocals,
  arg1 : @lib.LocalIdx,
) -> @lib.ValType? {
  ffi_lib_FunctionLocals_local_type(arg0, arg1)
}

///|
pub fn lib__FunctionLocals__new(
  arg0 : Array[@lib.ValType],
  arg1 : @lib.Locals,
) -> @lib.FunctionLocals {
  ffi_lib_FunctionLocals_new(arg0, arg1)
}

///|
pub fn lib__FunctionLocals__param_count(arg0 : @lib.FunctionLocals) -> Int {
  ffi_lib_FunctionLocals_param_count(arg0)
}

///|
pub fn lib__FunctionLocals__params(
  arg0 : @lib.FunctionLocals,
) -> Array[@lib.ValType] {
  ffi_lib_FunctionLocals_params(arg0)
}

///|
pub fn lib__Global__new(
  arg0 : @lib.GlobalType,
  arg1 : @lib.Expr,
) -> @lib.Global {
  ffi_lib_Global_new(arg0, arg1)
}

///|
pub fn lib__GlobalIdx__new(arg0 : UInt) -> @lib.GlobalIdx {
  ffi_lib_GlobalIdx_new(arg0)
}

///|
pub fn lib__GlobalSec__new(arg0 : Array[@lib.Global]) -> @lib.GlobalSec {
  ffi_lib_GlobalSec_new(arg0)
}

///|
pub fn lib__GlobalType__new(
  arg0 : @lib.ValType,
  arg1 : Bool,
) -> @lib.GlobalType {
  ffi_lib_GlobalType_new(arg0, arg1)
}

///|
pub fn lib__HeapType__abs(arg0 : @lib.AbsHeapType) -> @lib.HeapType {
  ffi_lib_HeapType_abs(arg0)
}

///|
pub fn lib__HeapType__bottom() -> @lib.HeapType {
  ffi_lib_HeapType_bottom()
}

///|
pub fn lib__HeapType__def_type(arg0 : @lib.DefType) -> @lib.HeapType {
  ffi_lib_HeapType_def_type(arg0)
}

///|
pub fn lib__HeapType__is_array(arg0 : @lib.HeapType) -> Bool {
  ffi_lib_HeapType_is_array(arg0)
}

///|
pub fn lib__HeapType__is_gc_aggregate(arg0 : @lib.HeapType) -> Bool {
  ffi_lib_HeapType_is_gc_aggregate(arg0)
}

///|
pub fn lib__HeapType__is_shared(arg0 : @lib.HeapType) -> Bool {
  ffi_lib_HeapType_is_shared(arg0)
}

///|
pub fn lib__HeapType__is_struct(arg0 : @lib.HeapType) -> Bool {
  ffi_lib_HeapType_is_struct(arg0)
}

///|
pub fn lib__HeapType__new(arg0 : @lib.TypeIdx) -> @lib.HeapType {
  ffi_lib_HeapType_new(arg0)
}

///|
pub fn lib__HeapType__shared_abs(arg0 : @lib.AbsHeapType) -> @lib.HeapType {
  ffi_lib_HeapType_shared_abs(arg0)
}

///|
pub fn lib__I32__new(arg0 : Int) -> @lib.I32 {
  ffi_lib_I32_new(arg0)
}

///|
pub fn lib__I64__new(arg0 : Int64) -> @lib.I64 {
  ffi_lib_I64_new(arg0)
}

///|
pub fn lib__Import__new(
  arg0 : @lib.Name,
  arg1 : @lib.Name,
  arg2 : @lib.ExternType,
) -> @lib.Import {
  ffi_lib_Import_new(arg0, arg1, arg2)
}

///|
pub fn lib__ImportSec__new(arg0 : Array[@lib.Import]) -> @lib.ImportSec {
  ffi_lib_ImportSec_new(arg0)
}

///|
pub fn lib__IndirectNameAssoc__new(
  arg0 : UInt,
  arg1 : @lib.NameMap,
) -> @lib.IndirectNameAssoc {
  ffi_lib_IndirectNameAssoc_new(arg0, arg1)
}

///|
pub fn lib__IndirectNameMap__new(
  arg0 : Array[@lib.IndirectNameAssoc],
) -> @lib.IndirectNameMap {
  ffi_lib_IndirectNameMap_new(arg0)
}

///|
pub fn lib__Instruction__any_convert_extern() -> @lib.Instruction {
  ffi_lib_Instruction_any_convert_extern()
}

///|
pub fn lib__Instruction__array_atomic_cmpxchg(
  arg0 : @lib.TypeIdx,
  arg1 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_array_atomic_cmpxchg(arg0, arg1)
}

///|
pub fn lib__Instruction__array_atomic_get(
  arg0 : @lib.AtomicOrder,
  arg1 : @lib.TypeIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_array_atomic_get(arg0, arg1)
}

///|
pub fn lib__Instruction__array_atomic_get_s(
  arg0 : @lib.AtomicOrder,
  arg1 : @lib.TypeIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_array_atomic_get_s(arg0, arg1)
}

///|
pub fn lib__Instruction__array_atomic_get_u(
  arg0 : @lib.AtomicOrder,
  arg1 : @lib.TypeIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_array_atomic_get_u(arg0, arg1)
}

///|
pub fn lib__Instruction__array_atomic_rmw(
  arg0 : @lib.AggregateAtomicRmwOp,
  arg1 : @lib.TypeIdx,
  arg2 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_array_atomic_rmw(arg0, arg1, arg2)
}

///|
pub fn lib__Instruction__array_atomic_set(
  arg0 : @lib.AtomicOrder,
  arg1 : @lib.TypeIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_array_atomic_set(arg0, arg1)
}

///|
pub fn lib__Instruction__array_copy(
  arg0 : @lib.TypeIdx,
  arg1 : @lib.TypeIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_array_copy(arg0, arg1)
}

///|
pub fn lib__Instruction__array_fill(arg0 : @lib.TypeIdx) -> @lib.Instruction {
  ffi_lib_Instruction_array_fill(arg0)
}

///|
pub fn lib__Instruction__array_get(arg0 : @lib.TypeIdx) -> @lib.Instruction {
  ffi_lib_Instruction_array_get(arg0)
}

///|
pub fn lib__Instruction__array_get_s(arg0 : @lib.TypeIdx) -> @lib.Instruction {
  ffi_lib_Instruction_array_get_s(arg0)
}

///|
pub fn lib__Instruction__array_get_u(arg0 : @lib.TypeIdx) -> @lib.Instruction {
  ffi_lib_Instruction_array_get_u(arg0)
}

///|
pub fn lib__Instruction__array_init_data(
  arg0 : @lib.TypeIdx,
  arg1 : @lib.DataIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_array_init_data(arg0, arg1)
}

///|
pub fn lib__Instruction__array_init_elem(
  arg0 : @lib.TypeIdx,
  arg1 : @lib.ElemIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_array_init_elem(arg0, arg1)
}

///|
pub fn lib__Instruction__array_len() -> @lib.Instruction {
  ffi_lib_Instruction_array_len()
}

///|
pub fn lib__Instruction__array_load(
  arg0 : @lib.LoadOp,
  arg1 : @lib.TypeIdx,
  arg2 : @lib.MemArg?,
) -> @lib.Instruction {
  ffi_lib_Instruction_array_load(arg0, arg1, arg2)
}

///|
pub fn lib__Instruction__array_new(arg0 : @lib.TypeIdx) -> @lib.Instruction {
  ffi_lib_Instruction_array_new(arg0)
}

///|
pub fn lib__Instruction__array_new_data(
  arg0 : @lib.TypeIdx,
  arg1 : @lib.DataIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_array_new_data(arg0, arg1)
}

///|
pub fn lib__Instruction__array_new_default(
  arg0 : @lib.TypeIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_array_new_default(arg0)
}

///|
pub fn lib__Instruction__array_new_elem(
  arg0 : @lib.TypeIdx,
  arg1 : @lib.ElemIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_array_new_elem(arg0, arg1)
}

///|
pub fn lib__Instruction__array_new_fixed(
  arg0 : @lib.TypeIdx,
  arg1 : @lib.U32,
) -> @lib.Instruction {
  ffi_lib_Instruction_array_new_fixed(arg0, arg1)
}

///|
pub fn lib__Instruction__array_set(arg0 : @lib.TypeIdx) -> @lib.Instruction {
  ffi_lib_Instruction_array_set(arg0)
}

///|
pub fn lib__Instruction__array_store(
  arg0 : @lib.StoreOp,
  arg1 : @lib.TypeIdx,
  arg2 : @lib.MemArg?,
) -> @lib.Instruction {
  ffi_lib_Instruction_array_store(arg0, arg1, arg2)
}

///|
pub fn lib__Instruction__atomic_cmpxchg(
  arg0 : @lib.AtomicCmpxchgOp,
  arg1 : @lib.MemArg,
  arg2 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_atomic_cmpxchg(arg0, arg1, arg2)
}

///|
pub fn lib__Instruction__atomic_fence(
  arg0 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_atomic_fence(arg0)
}

///|
pub fn lib__Instruction__atomic_rmw(
  arg0 : @lib.AtomicRmwOp,
  arg1 : @lib.MemArg,
  arg2 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_atomic_rmw(arg0, arg1, arg2)
}

///|
pub fn lib__Instruction__block(
  arg0 : @lib.BlockType,
  arg1 : @lib.Expr,
) -> @lib.Instruction {
  ffi_lib_Instruction_block(arg0, arg1)
}

///|
pub fn lib__Instruction__br(arg0 : @lib.LabelIdx) -> @lib.Instruction {
  ffi_lib_Instruction_br(arg0)
}

///|
pub fn lib__Instruction__br_if(arg0 : @lib.LabelIdx) -> @lib.Instruction {
  ffi_lib_Instruction_br_if(arg0)
}

///|
pub fn lib__Instruction__br_on_cast(
  arg0 : @lib.LabelIdx,
  arg1 : Bool,
  arg2 : @lib.HeapType,
  arg3 : Bool,
  arg4 : @lib.HeapType,
  arg5 : Bool?,
  arg6 : Bool?,
) -> @lib.Instruction {
  ffi_lib_Instruction_br_on_cast(arg0, arg1, arg2, arg3, arg4, arg5, arg6)
}

///|
pub fn lib__Instruction__br_on_cast_desc_eq(
  arg0 : @lib.LabelIdx,
  arg1 : @lib.RefType,
  arg2 : @lib.RefType,
) -> @lib.Instruction {
  ffi_lib_Instruction_br_on_cast_desc_eq(arg0, arg1, arg2)
}

///|
pub fn lib__Instruction__br_on_cast_desc_eq_fail(
  arg0 : @lib.LabelIdx,
  arg1 : @lib.RefType,
  arg2 : @lib.RefType,
) -> @lib.Instruction {
  ffi_lib_Instruction_br_on_cast_desc_eq_fail(arg0, arg1, arg2)
}

///|
pub fn lib__Instruction__br_on_cast_fail(
  arg0 : @lib.LabelIdx,
  arg1 : Bool,
  arg2 : @lib.HeapType,
  arg3 : Bool,
  arg4 : @lib.HeapType,
  arg5 : Bool?,
  arg6 : Bool?,
) -> @lib.Instruction {
  ffi_lib_Instruction_br_on_cast_fail(arg0, arg1, arg2, arg3, arg4, arg5, arg6)
}

///|
pub fn lib__Instruction__br_on_non_null(
  arg0 : @lib.LabelIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_br_on_non_null(arg0)
}

///|
pub fn lib__Instruction__br_on_null(arg0 : @lib.LabelIdx) -> @lib.Instruction {
  ffi_lib_Instruction_br_on_null(arg0)
}

///|
pub fn lib__Instruction__br_table(
  arg0 : Array[@lib.LabelIdx],
  arg1 : @lib.LabelIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_br_table(arg0, arg1)
}

///|
pub fn lib__Instruction__call(arg0 : @lib.FuncIdx) -> @lib.Instruction {
  ffi_lib_Instruction_call(arg0)
}

///|
pub fn lib__Instruction__call_indirect(
  arg0 : @lib.TypeIdx,
  arg1 : @lib.TableIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_call_indirect(arg0, arg1)
}

///|
pub fn lib__Instruction__call_ref(arg0 : @lib.TypeIdx) -> @lib.Instruction {
  ffi_lib_Instruction_call_ref(arg0)
}

///|
pub fn lib__Instruction__cont_bind(
  arg0 : @lib.TypeIdx,
  arg1 : @lib.TypeIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_cont_bind(arg0, arg1)
}

///|
pub fn lib__Instruction__cont_new(arg0 : @lib.TypeIdx) -> @lib.Instruction {
  ffi_lib_Instruction_cont_new(arg0)
}

///|
pub fn lib__Instruction__data_drop(arg0 : @lib.DataIdx) -> @lib.Instruction {
  ffi_lib_Instruction_data_drop(arg0)
}

///|
pub fn lib__Instruction__drop() -> @lib.Instruction {
  ffi_lib_Instruction_drop()
}

///|
pub fn lib__Instruction__elem_drop(arg0 : @lib.ElemIdx) -> @lib.Instruction {
  ffi_lib_Instruction_elem_drop(arg0)
}

///|
pub fn lib__Instruction__extern_convert_any() -> @lib.Instruction {
  ffi_lib_Instruction_extern_convert_any()
}

///|
pub fn lib__Instruction__f32_abs() -> @lib.Instruction {
  ffi_lib_Instruction_f32_abs()
}

///|
pub fn lib__Instruction__f32_add() -> @lib.Instruction {
  ffi_lib_Instruction_f32_add()
}

///|
pub fn lib__Instruction__f32_ceil() -> @lib.Instruction {
  ffi_lib_Instruction_f32_ceil()
}

///|
pub fn lib__Instruction__f32_const(arg0 : @lib.F32) -> @lib.Instruction {
  ffi_lib_Instruction_f32_const(arg0)
}

///|
pub fn lib__Instruction__f32_convert_i32s() -> @lib.Instruction {
  ffi_lib_Instruction_f32_convert_i32s()
}

///|
pub fn lib__Instruction__f32_convert_i32u() -> @lib.Instruction {
  ffi_lib_Instruction_f32_convert_i32u()
}

///|
pub fn lib__Instruction__f32_convert_i64s() -> @lib.Instruction {
  ffi_lib_Instruction_f32_convert_i64s()
}

///|
pub fn lib__Instruction__f32_convert_i64u() -> @lib.Instruction {
  ffi_lib_Instruction_f32_convert_i64u()
}

///|
pub fn lib__Instruction__f32_copysign() -> @lib.Instruction {
  ffi_lib_Instruction_f32_copysign()
}

///|
pub fn lib__Instruction__f32_demote_f64() -> @lib.Instruction {
  ffi_lib_Instruction_f32_demote_f64()
}

///|
pub fn lib__Instruction__f32_div() -> @lib.Instruction {
  ffi_lib_Instruction_f32_div()
}

///|
pub fn lib__Instruction__f32_eq() -> @lib.Instruction {
  ffi_lib_Instruction_f32_eq()
}

///|
pub fn lib__Instruction__f32_floor() -> @lib.Instruction {
  ffi_lib_Instruction_f32_floor()
}

///|
pub fn lib__Instruction__f32_ge() -> @lib.Instruction {
  ffi_lib_Instruction_f32_ge()
}

///|
pub fn lib__Instruction__f32_gt() -> @lib.Instruction {
  ffi_lib_Instruction_f32_gt()
}

///|
pub fn lib__Instruction__f32_le() -> @lib.Instruction {
  ffi_lib_Instruction_f32_le()
}

///|
pub fn lib__Instruction__f32_load(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_f32_load(arg0)
}

///|
pub fn lib__Instruction__f32_lt() -> @lib.Instruction {
  ffi_lib_Instruction_f32_lt()
}

///|
pub fn lib__Instruction__f32_max() -> @lib.Instruction {
  ffi_lib_Instruction_f32_max()
}

///|
pub fn lib__Instruction__f32_min() -> @lib.Instruction {
  ffi_lib_Instruction_f32_min()
}

///|
pub fn lib__Instruction__f32_mul() -> @lib.Instruction {
  ffi_lib_Instruction_f32_mul()
}

///|
pub fn lib__Instruction__f32_ne() -> @lib.Instruction {
  ffi_lib_Instruction_f32_ne()
}

///|
pub fn lib__Instruction__f32_nearest() -> @lib.Instruction {
  ffi_lib_Instruction_f32_nearest()
}

///|
pub fn lib__Instruction__f32_neg() -> @lib.Instruction {
  ffi_lib_Instruction_f32_neg()
}

///|
pub fn lib__Instruction__f32_reinterpret_i32() -> @lib.Instruction {
  ffi_lib_Instruction_f32_reinterpret_i32()
}

///|
pub fn lib__Instruction__f32_sqrt() -> @lib.Instruction {
  ffi_lib_Instruction_f32_sqrt()
}

///|
pub fn lib__Instruction__f32_store(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_f32_store(arg0)
}

///|
pub fn lib__Instruction__f32_sub() -> @lib.Instruction {
  ffi_lib_Instruction_f32_sub()
}

///|
pub fn lib__Instruction__f32_trunc() -> @lib.Instruction {
  ffi_lib_Instruction_f32_trunc()
}

///|
pub fn lib__Instruction__f32x4_abs() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_abs()
}

///|
pub fn lib__Instruction__f32x4_add() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_add()
}

///|
pub fn lib__Instruction__f32x4_ceil() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_ceil()
}

///|
pub fn lib__Instruction__f32x4_convert_i32x4s() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_convert_i32x4s()
}

///|
pub fn lib__Instruction__f32x4_convert_i32x4u() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_convert_i32x4u()
}

///|
pub fn lib__Instruction__f32x4_demote_f64x2_zero() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_demote_f64x2_zero()
}

///|
pub fn lib__Instruction__f32x4_div() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_div()
}

///|
pub fn lib__Instruction__f32x4_eq() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_eq()
}

///|
pub fn lib__Instruction__f32x4_extract_lane(
  arg0 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_extract_lane(arg0)
}

///|
pub fn lib__Instruction__f32x4_floor() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_floor()
}

///|
pub fn lib__Instruction__f32x4_ge() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_ge()
}

///|
pub fn lib__Instruction__f32x4_gt() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_gt()
}

///|
pub fn lib__Instruction__f32x4_le() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_le()
}

///|
pub fn lib__Instruction__f32x4_lt() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_lt()
}

///|
pub fn lib__Instruction__f32x4_max() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_max()
}

///|
pub fn lib__Instruction__f32x4_min() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_min()
}

///|
pub fn lib__Instruction__f32x4_mul() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_mul()
}

///|
pub fn lib__Instruction__f32x4_ne() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_ne()
}

///|
pub fn lib__Instruction__f32x4_nearest() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_nearest()
}

///|
pub fn lib__Instruction__f32x4_neg() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_neg()
}

///|
pub fn lib__Instruction__f32x4_pmax() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_pmax()
}

///|
pub fn lib__Instruction__f32x4_pmin() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_pmin()
}

///|
pub fn lib__Instruction__f32x4_relaxed_madd() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_relaxed_madd()
}

///|
pub fn lib__Instruction__f32x4_relaxed_max() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_relaxed_max()
}

///|
pub fn lib__Instruction__f32x4_relaxed_min() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_relaxed_min()
}

///|
pub fn lib__Instruction__f32x4_relaxed_nmadd() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_relaxed_nmadd()
}

///|
pub fn lib__Instruction__f32x4_replace_lane(
  arg0 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_replace_lane(arg0)
}

///|
pub fn lib__Instruction__f32x4_splat() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_splat()
}

///|
pub fn lib__Instruction__f32x4_sqrt() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_sqrt()
}

///|
pub fn lib__Instruction__f32x4_sub() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_sub()
}

///|
pub fn lib__Instruction__f32x4_trunc() -> @lib.Instruction {
  ffi_lib_Instruction_f32x4_trunc()
}

///|
pub fn lib__Instruction__f64_abs() -> @lib.Instruction {
  ffi_lib_Instruction_f64_abs()
}

///|
pub fn lib__Instruction__f64_add() -> @lib.Instruction {
  ffi_lib_Instruction_f64_add()
}

///|
pub fn lib__Instruction__f64_ceil() -> @lib.Instruction {
  ffi_lib_Instruction_f64_ceil()
}

///|
pub fn lib__Instruction__f64_const(arg0 : @lib.F64) -> @lib.Instruction {
  ffi_lib_Instruction_f64_const(arg0)
}

///|
pub fn lib__Instruction__f64_convert_i32s() -> @lib.Instruction {
  ffi_lib_Instruction_f64_convert_i32s()
}

///|
pub fn lib__Instruction__f64_convert_i32u() -> @lib.Instruction {
  ffi_lib_Instruction_f64_convert_i32u()
}

///|
pub fn lib__Instruction__f64_convert_i64s() -> @lib.Instruction {
  ffi_lib_Instruction_f64_convert_i64s()
}

///|
pub fn lib__Instruction__f64_convert_i64u() -> @lib.Instruction {
  ffi_lib_Instruction_f64_convert_i64u()
}

///|
pub fn lib__Instruction__f64_copysign() -> @lib.Instruction {
  ffi_lib_Instruction_f64_copysign()
}

///|
pub fn lib__Instruction__f64_div() -> @lib.Instruction {
  ffi_lib_Instruction_f64_div()
}

///|
pub fn lib__Instruction__f64_eq() -> @lib.Instruction {
  ffi_lib_Instruction_f64_eq()
}

///|
pub fn lib__Instruction__f64_floor() -> @lib.Instruction {
  ffi_lib_Instruction_f64_floor()
}

///|
pub fn lib__Instruction__f64_ge() -> @lib.Instruction {
  ffi_lib_Instruction_f64_ge()
}

///|
pub fn lib__Instruction__f64_gt() -> @lib.Instruction {
  ffi_lib_Instruction_f64_gt()
}

///|
pub fn lib__Instruction__f64_le() -> @lib.Instruction {
  ffi_lib_Instruction_f64_le()
}

///|
pub fn lib__Instruction__f64_load(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_f64_load(arg0)
}

///|
pub fn lib__Instruction__f64_lt() -> @lib.Instruction {
  ffi_lib_Instruction_f64_lt()
}

///|
pub fn lib__Instruction__f64_max() -> @lib.Instruction {
  ffi_lib_Instruction_f64_max()
}

///|
pub fn lib__Instruction__f64_min() -> @lib.Instruction {
  ffi_lib_Instruction_f64_min()
}

///|
pub fn lib__Instruction__f64_mul() -> @lib.Instruction {
  ffi_lib_Instruction_f64_mul()
}

///|
pub fn lib__Instruction__f64_ne() -> @lib.Instruction {
  ffi_lib_Instruction_f64_ne()
}

///|
pub fn lib__Instruction__f64_nearest() -> @lib.Instruction {
  ffi_lib_Instruction_f64_nearest()
}

///|
pub fn lib__Instruction__f64_neg() -> @lib.Instruction {
  ffi_lib_Instruction_f64_neg()
}

///|
pub fn lib__Instruction__f64_promote_f32() -> @lib.Instruction {
  ffi_lib_Instruction_f64_promote_f32()
}

///|
pub fn lib__Instruction__f64_reinterpret_i64() -> @lib.Instruction {
  ffi_lib_Instruction_f64_reinterpret_i64()
}

///|
pub fn lib__Instruction__f64_sqrt() -> @lib.Instruction {
  ffi_lib_Instruction_f64_sqrt()
}

///|
pub fn lib__Instruction__f64_store(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_f64_store(arg0)
}

///|
pub fn lib__Instruction__f64_sub() -> @lib.Instruction {
  ffi_lib_Instruction_f64_sub()
}

///|
pub fn lib__Instruction__f64_trunc() -> @lib.Instruction {
  ffi_lib_Instruction_f64_trunc()
}

///|
pub fn lib__Instruction__f64x2_abs() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_abs()
}

///|
pub fn lib__Instruction__f64x2_add() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_add()
}

///|
pub fn lib__Instruction__f64x2_ceil() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_ceil()
}

///|
pub fn lib__Instruction__f64x2_convert_low_i32x4s() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_convert_low_i32x4s()
}

///|
pub fn lib__Instruction__f64x2_convert_low_i32x4u() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_convert_low_i32x4u()
}

///|
pub fn lib__Instruction__f64x2_div() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_div()
}

///|
pub fn lib__Instruction__f64x2_eq() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_eq()
}

///|
pub fn lib__Instruction__f64x2_extract_lane(
  arg0 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_extract_lane(arg0)
}

///|
pub fn lib__Instruction__f64x2_floor() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_floor()
}

///|
pub fn lib__Instruction__f64x2_ge() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_ge()
}

///|
pub fn lib__Instruction__f64x2_gt() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_gt()
}

///|
pub fn lib__Instruction__f64x2_le() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_le()
}

///|
pub fn lib__Instruction__f64x2_lt() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_lt()
}

///|
pub fn lib__Instruction__f64x2_max() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_max()
}

///|
pub fn lib__Instruction__f64x2_min() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_min()
}

///|
pub fn lib__Instruction__f64x2_mul() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_mul()
}

///|
pub fn lib__Instruction__f64x2_ne() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_ne()
}

///|
pub fn lib__Instruction__f64x2_nearest() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_nearest()
}

///|
pub fn lib__Instruction__f64x2_neg() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_neg()
}

///|
pub fn lib__Instruction__f64x2_pmax() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_pmax()
}

///|
pub fn lib__Instruction__f64x2_pmin() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_pmin()
}

///|
pub fn lib__Instruction__f64x2_promote_low_f32x4() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_promote_low_f32x4()
}

///|
pub fn lib__Instruction__f64x2_relaxed_madd() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_relaxed_madd()
}

///|
pub fn lib__Instruction__f64x2_relaxed_max() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_relaxed_max()
}

///|
pub fn lib__Instruction__f64x2_relaxed_min() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_relaxed_min()
}

///|
pub fn lib__Instruction__f64x2_relaxed_nmadd() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_relaxed_nmadd()
}

///|
pub fn lib__Instruction__f64x2_replace_lane(
  arg0 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_replace_lane(arg0)
}

///|
pub fn lib__Instruction__f64x2_splat() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_splat()
}

///|
pub fn lib__Instruction__f64x2_sqrt() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_sqrt()
}

///|
pub fn lib__Instruction__f64x2_sub() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_sub()
}

///|
pub fn lib__Instruction__f64x2_trunc() -> @lib.Instruction {
  ffi_lib_Instruction_f64x2_trunc()
}

///|
pub fn lib__Instruction__global_get(arg0 : @lib.GlobalIdx) -> @lib.Instruction {
  ffi_lib_Instruction_global_get(arg0)
}

///|
pub fn lib__Instruction__global_set(arg0 : @lib.GlobalIdx) -> @lib.Instruction {
  ffi_lib_Instruction_global_set(arg0)
}

///|
pub fn lib__Instruction__i16x8_abs() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_abs()
}

///|
pub fn lib__Instruction__i16x8_add() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_add()
}

///|
pub fn lib__Instruction__i16x8_add_sat_s() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_add_sat_s()
}

///|
pub fn lib__Instruction__i16x8_add_sat_u() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_add_sat_u()
}

///|
pub fn lib__Instruction__i16x8_all_true() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_all_true()
}

///|
pub fn lib__Instruction__i16x8_avgr_u() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_avgr_u()
}

///|
pub fn lib__Instruction__i16x8_bitmask() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_bitmask()
}

///|
pub fn lib__Instruction__i16x8_eq() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_eq()
}

///|
pub fn lib__Instruction__i16x8_extadd_pairwise_i8x16s() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_extadd_pairwise_i8x16s()
}

///|
pub fn lib__Instruction__i16x8_extadd_pairwise_i8x16u() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_extadd_pairwise_i8x16u()
}

///|
pub fn lib__Instruction__i16x8_extend_high_i8x16s() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_extend_high_i8x16s()
}

///|
pub fn lib__Instruction__i16x8_extend_high_i8x16u() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_extend_high_i8x16u()
}

///|
pub fn lib__Instruction__i16x8_extend_low_i8x16s() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_extend_low_i8x16s()
}

///|
pub fn lib__Instruction__i16x8_extend_low_i8x16u() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_extend_low_i8x16u()
}

///|
pub fn lib__Instruction__i16x8_extmul_high_i8x16s() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_extmul_high_i8x16s()
}

///|
pub fn lib__Instruction__i16x8_extmul_high_i8x16u() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_extmul_high_i8x16u()
}

///|
pub fn lib__Instruction__i16x8_extmul_low_i8x16s() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_extmul_low_i8x16s()
}

///|
pub fn lib__Instruction__i16x8_extmul_low_i8x16u() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_extmul_low_i8x16u()
}

///|
pub fn lib__Instruction__i16x8_extract_lane_s(
  arg0 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_extract_lane_s(arg0)
}

///|
pub fn lib__Instruction__i16x8_extract_lane_u(
  arg0 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_extract_lane_u(arg0)
}

///|
pub fn lib__Instruction__i16x8_ge_s() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_ge_s()
}

///|
pub fn lib__Instruction__i16x8_ge_u() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_ge_u()
}

///|
pub fn lib__Instruction__i16x8_gt_s() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_gt_s()
}

///|
pub fn lib__Instruction__i16x8_gt_u() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_gt_u()
}

///|
pub fn lib__Instruction__i16x8_le_s() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_le_s()
}

///|
pub fn lib__Instruction__i16x8_le_u() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_le_u()
}

///|
pub fn lib__Instruction__i16x8_lt_s() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_lt_s()
}

///|
pub fn lib__Instruction__i16x8_lt_u() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_lt_u()
}

///|
pub fn lib__Instruction__i16x8_max_s() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_max_s()
}

///|
pub fn lib__Instruction__i16x8_max_u() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_max_u()
}

///|
pub fn lib__Instruction__i16x8_min_s() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_min_s()
}

///|
pub fn lib__Instruction__i16x8_min_u() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_min_u()
}

///|
pub fn lib__Instruction__i16x8_mul() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_mul()
}

///|
pub fn lib__Instruction__i16x8_narrow_i32x4s() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_narrow_i32x4s()
}

///|
pub fn lib__Instruction__i16x8_narrow_i32x4u() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_narrow_i32x4u()
}

///|
pub fn lib__Instruction__i16x8_ne() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_ne()
}

///|
pub fn lib__Instruction__i16x8_neg() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_neg()
}

///|
pub fn lib__Instruction__i16x8_relaxed_dot_i8x16i7x16s() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_relaxed_dot_i8x16i7x16s()
}

///|
pub fn lib__Instruction__i16x8_relaxed_laneselect() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_relaxed_laneselect()
}

///|
pub fn lib__Instruction__i16x8_relaxed_q15mulr_s() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_relaxed_q15mulr_s()
}

///|
pub fn lib__Instruction__i16x8_replace_lane(
  arg0 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_replace_lane(arg0)
}

///|
pub fn lib__Instruction__i16x8_shl() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_shl()
}

///|
pub fn lib__Instruction__i16x8_shr_s() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_shr_s()
}

///|
pub fn lib__Instruction__i16x8_shr_u() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_shr_u()
}

///|
pub fn lib__Instruction__i16x8_splat() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_splat()
}

///|
pub fn lib__Instruction__i16x8_sub() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_sub()
}

///|
pub fn lib__Instruction__i16x8_sub_sat_s() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_sub_sat_s()
}

///|
pub fn lib__Instruction__i16x8_sub_sat_u() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8_sub_sat_u()
}

///|
pub fn lib__Instruction__i16x8q15mulr_sat_s() -> @lib.Instruction {
  ffi_lib_Instruction_i16x8q15mulr_sat_s()
}

///|
pub fn lib__Instruction__i31_get_s() -> @lib.Instruction {
  ffi_lib_Instruction_i31_get_s()
}

///|
pub fn lib__Instruction__i31_get_u() -> @lib.Instruction {
  ffi_lib_Instruction_i31_get_u()
}

///|
pub fn lib__Instruction__i32_add() -> @lib.Instruction {
  ffi_lib_Instruction_i32_add()
}

///|
pub fn lib__Instruction__i32_and() -> @lib.Instruction {
  ffi_lib_Instruction_i32_and()
}

///|
pub fn lib__Instruction__i32_atomic_load(
  arg0 : @lib.MemArg,
  arg1 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_i32_atomic_load(arg0, arg1)
}

///|
pub fn lib__Instruction__i32_atomic_load16_u(
  arg0 : @lib.MemArg,
  arg1 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_i32_atomic_load16_u(arg0, arg1)
}

///|
pub fn lib__Instruction__i32_atomic_load8_u(
  arg0 : @lib.MemArg,
  arg1 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_i32_atomic_load8_u(arg0, arg1)
}

///|
pub fn lib__Instruction__i32_atomic_store(
  arg0 : @lib.MemArg,
  arg1 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_i32_atomic_store(arg0, arg1)
}

///|
pub fn lib__Instruction__i32_atomic_store16(
  arg0 : @lib.MemArg,
  arg1 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_i32_atomic_store16(arg0, arg1)
}

///|
pub fn lib__Instruction__i32_atomic_store8(
  arg0 : @lib.MemArg,
  arg1 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_i32_atomic_store8(arg0, arg1)
}

///|
pub fn lib__Instruction__i32_clz() -> @lib.Instruction {
  ffi_lib_Instruction_i32_clz()
}

///|
pub fn lib__Instruction__i32_const(arg0 : @lib.I32) -> @lib.Instruction {
  ffi_lib_Instruction_i32_const(arg0)
}

///|
pub fn lib__Instruction__i32_ctz() -> @lib.Instruction {
  ffi_lib_Instruction_i32_ctz()
}

///|
pub fn lib__Instruction__i32_div_s() -> @lib.Instruction {
  ffi_lib_Instruction_i32_div_s()
}

///|
pub fn lib__Instruction__i32_div_u() -> @lib.Instruction {
  ffi_lib_Instruction_i32_div_u()
}

///|
pub fn lib__Instruction__i32_eq() -> @lib.Instruction {
  ffi_lib_Instruction_i32_eq()
}

///|
pub fn lib__Instruction__i32_eqz() -> @lib.Instruction {
  ffi_lib_Instruction_i32_eqz()
}

///|
pub fn lib__Instruction__i32_extend16s() -> @lib.Instruction {
  ffi_lib_Instruction_i32_extend16s()
}

///|
pub fn lib__Instruction__i32_extend8s() -> @lib.Instruction {
  ffi_lib_Instruction_i32_extend8s()
}

///|
pub fn lib__Instruction__i32_ge_s() -> @lib.Instruction {
  ffi_lib_Instruction_i32_ge_s()
}

///|
pub fn lib__Instruction__i32_ge_u() -> @lib.Instruction {
  ffi_lib_Instruction_i32_ge_u()
}

///|
pub fn lib__Instruction__i32_gt_s() -> @lib.Instruction {
  ffi_lib_Instruction_i32_gt_s()
}

///|
pub fn lib__Instruction__i32_gt_u() -> @lib.Instruction {
  ffi_lib_Instruction_i32_gt_u()
}

///|
pub fn lib__Instruction__i32_le_s() -> @lib.Instruction {
  ffi_lib_Instruction_i32_le_s()
}

///|
pub fn lib__Instruction__i32_le_u() -> @lib.Instruction {
  ffi_lib_Instruction_i32_le_u()
}

///|
pub fn lib__Instruction__i32_load(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_i32_load(arg0)
}

///|
pub fn lib__Instruction__i32_load16s(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_i32_load16s(arg0)
}

///|
pub fn lib__Instruction__i32_load16u(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_i32_load16u(arg0)
}

///|
pub fn lib__Instruction__i32_load8s(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_i32_load8s(arg0)
}

///|
pub fn lib__Instruction__i32_load8u(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_i32_load8u(arg0)
}

///|
pub fn lib__Instruction__i32_lt_s() -> @lib.Instruction {
  ffi_lib_Instruction_i32_lt_s()
}

///|
pub fn lib__Instruction__i32_lt_u() -> @lib.Instruction {
  ffi_lib_Instruction_i32_lt_u()
}

///|
pub fn lib__Instruction__i32_mul() -> @lib.Instruction {
  ffi_lib_Instruction_i32_mul()
}

///|
pub fn lib__Instruction__i32_ne() -> @lib.Instruction {
  ffi_lib_Instruction_i32_ne()
}

///|
pub fn lib__Instruction__i32_or() -> @lib.Instruction {
  ffi_lib_Instruction_i32_or()
}

///|
pub fn lib__Instruction__i32_popcnt() -> @lib.Instruction {
  ffi_lib_Instruction_i32_popcnt()
}

///|
pub fn lib__Instruction__i32_reinterpret_f32() -> @lib.Instruction {
  ffi_lib_Instruction_i32_reinterpret_f32()
}

///|
pub fn lib__Instruction__i32_rem_s() -> @lib.Instruction {
  ffi_lib_Instruction_i32_rem_s()
}

///|
pub fn lib__Instruction__i32_rem_u() -> @lib.Instruction {
  ffi_lib_Instruction_i32_rem_u()
}

///|
pub fn lib__Instruction__i32_rotl() -> @lib.Instruction {
  ffi_lib_Instruction_i32_rotl()
}

///|
pub fn lib__Instruction__i32_rotr() -> @lib.Instruction {
  ffi_lib_Instruction_i32_rotr()
}

///|
pub fn lib__Instruction__i32_shl() -> @lib.Instruction {
  ffi_lib_Instruction_i32_shl()
}

///|
pub fn lib__Instruction__i32_shr_s() -> @lib.Instruction {
  ffi_lib_Instruction_i32_shr_s()
}

///|
pub fn lib__Instruction__i32_shr_u() -> @lib.Instruction {
  ffi_lib_Instruction_i32_shr_u()
}

///|
pub fn lib__Instruction__i32_store(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_i32_store(arg0)
}

///|
pub fn lib__Instruction__i32_store16(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_i32_store16(arg0)
}

///|
pub fn lib__Instruction__i32_store8(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_i32_store8(arg0)
}

///|
pub fn lib__Instruction__i32_sub() -> @lib.Instruction {
  ffi_lib_Instruction_i32_sub()
}

///|
pub fn lib__Instruction__i32_trunc_f32s() -> @lib.Instruction {
  ffi_lib_Instruction_i32_trunc_f32s()
}

///|
pub fn lib__Instruction__i32_trunc_f32u() -> @lib.Instruction {
  ffi_lib_Instruction_i32_trunc_f32u()
}

///|
pub fn lib__Instruction__i32_trunc_f64s() -> @lib.Instruction {
  ffi_lib_Instruction_i32_trunc_f64s()
}

///|
pub fn lib__Instruction__i32_trunc_f64u() -> @lib.Instruction {
  ffi_lib_Instruction_i32_trunc_f64u()
}

///|
pub fn lib__Instruction__i32_trunc_sat_f32s() -> @lib.Instruction {
  ffi_lib_Instruction_i32_trunc_sat_f32s()
}

///|
pub fn lib__Instruction__i32_trunc_sat_f32u() -> @lib.Instruction {
  ffi_lib_Instruction_i32_trunc_sat_f32u()
}

///|
pub fn lib__Instruction__i32_trunc_sat_f64s() -> @lib.Instruction {
  ffi_lib_Instruction_i32_trunc_sat_f64s()
}

///|
pub fn lib__Instruction__i32_trunc_sat_f64u() -> @lib.Instruction {
  ffi_lib_Instruction_i32_trunc_sat_f64u()
}

///|
pub fn lib__Instruction__i32_wrap_i64() -> @lib.Instruction {
  ffi_lib_Instruction_i32_wrap_i64()
}

///|
pub fn lib__Instruction__i32_xor() -> @lib.Instruction {
  ffi_lib_Instruction_i32_xor()
}

///|
pub fn lib__Instruction__i32x4_abs() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_abs()
}

///|
pub fn lib__Instruction__i32x4_add() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_add()
}

///|
pub fn lib__Instruction__i32x4_all_true() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_all_true()
}

///|
pub fn lib__Instruction__i32x4_bitmask() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_bitmask()
}

///|
pub fn lib__Instruction__i32x4_dot_i16x8s() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_dot_i16x8s()
}

///|
pub fn lib__Instruction__i32x4_eq() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_eq()
}

///|
pub fn lib__Instruction__i32x4_extadd_pairwise_i16x8s() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_extadd_pairwise_i16x8s()
}

///|
pub fn lib__Instruction__i32x4_extadd_pairwise_i16x8u() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_extadd_pairwise_i16x8u()
}

///|
pub fn lib__Instruction__i32x4_extend_high_i16x8s() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_extend_high_i16x8s()
}

///|
pub fn lib__Instruction__i32x4_extend_high_i16x8u() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_extend_high_i16x8u()
}

///|
pub fn lib__Instruction__i32x4_extend_low_i16x8s() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_extend_low_i16x8s()
}

///|
pub fn lib__Instruction__i32x4_extend_low_i16x8u() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_extend_low_i16x8u()
}

///|
pub fn lib__Instruction__i32x4_extmul_high_i16x8s() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_extmul_high_i16x8s()
}

///|
pub fn lib__Instruction__i32x4_extmul_high_i16x8u() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_extmul_high_i16x8u()
}

///|
pub fn lib__Instruction__i32x4_extmul_low_i16x8s() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_extmul_low_i16x8s()
}

///|
pub fn lib__Instruction__i32x4_extmul_low_i16x8u() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_extmul_low_i16x8u()
}

///|
pub fn lib__Instruction__i32x4_extract_lane(
  arg0 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_extract_lane(arg0)
}

///|
pub fn lib__Instruction__i32x4_ge_s() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_ge_s()
}

///|
pub fn lib__Instruction__i32x4_ge_u() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_ge_u()
}

///|
pub fn lib__Instruction__i32x4_gt_s() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_gt_s()
}

///|
pub fn lib__Instruction__i32x4_gt_u() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_gt_u()
}

///|
pub fn lib__Instruction__i32x4_le_s() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_le_s()
}

///|
pub fn lib__Instruction__i32x4_le_u() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_le_u()
}

///|
pub fn lib__Instruction__i32x4_lt_s() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_lt_s()
}

///|
pub fn lib__Instruction__i32x4_lt_u() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_lt_u()
}

///|
pub fn lib__Instruction__i32x4_max_s() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_max_s()
}

///|
pub fn lib__Instruction__i32x4_max_u() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_max_u()
}

///|
pub fn lib__Instruction__i32x4_min_s() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_min_s()
}

///|
pub fn lib__Instruction__i32x4_min_u() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_min_u()
}

///|
pub fn lib__Instruction__i32x4_mul() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_mul()
}

///|
pub fn lib__Instruction__i32x4_ne() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_ne()
}

///|
pub fn lib__Instruction__i32x4_neg() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_neg()
}

///|
pub fn lib__Instruction__i32x4_relaxed_dot_i8x16i7x16_add_s() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_relaxed_dot_i8x16i7x16_add_s()
}

///|
pub fn lib__Instruction__i32x4_relaxed_laneselect() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_relaxed_laneselect()
}

///|
pub fn lib__Instruction__i32x4_relaxed_trunc_f32x4s() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_relaxed_trunc_f32x4s()
}

///|
pub fn lib__Instruction__i32x4_relaxed_trunc_f32x4u() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_relaxed_trunc_f32x4u()
}

///|
pub fn lib__Instruction__i32x4_relaxed_trunc_zero_f64x2s() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_relaxed_trunc_zero_f64x2s()
}

///|
pub fn lib__Instruction__i32x4_relaxed_trunc_zero_f64x2u() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_relaxed_trunc_zero_f64x2u()
}

///|
pub fn lib__Instruction__i32x4_replace_lane(
  arg0 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_replace_lane(arg0)
}

///|
pub fn lib__Instruction__i32x4_shl() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_shl()
}

///|
pub fn lib__Instruction__i32x4_shr_s() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_shr_s()
}

///|
pub fn lib__Instruction__i32x4_shr_u() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_shr_u()
}

///|
pub fn lib__Instruction__i32x4_splat() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_splat()
}

///|
pub fn lib__Instruction__i32x4_sub() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_sub()
}

///|
pub fn lib__Instruction__i32x4_trunc_sat_f32x4s() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_trunc_sat_f32x4s()
}

///|
pub fn lib__Instruction__i32x4_trunc_sat_f32x4u() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_trunc_sat_f32x4u()
}

///|
pub fn lib__Instruction__i32x4_trunc_sat_f64x2s_zero() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_trunc_sat_f64x2s_zero()
}

///|
pub fn lib__Instruction__i32x4_trunc_sat_f64x2u_zero() -> @lib.Instruction {
  ffi_lib_Instruction_i32x4_trunc_sat_f64x2u_zero()
}

///|
pub fn lib__Instruction__i64_add() -> @lib.Instruction {
  ffi_lib_Instruction_i64_add()
}

///|
pub fn lib__Instruction__i64_and() -> @lib.Instruction {
  ffi_lib_Instruction_i64_and()
}

///|
pub fn lib__Instruction__i64_atomic_load(
  arg0 : @lib.MemArg,
  arg1 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_i64_atomic_load(arg0, arg1)
}

///|
pub fn lib__Instruction__i64_atomic_load16_u(
  arg0 : @lib.MemArg,
  arg1 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_i64_atomic_load16_u(arg0, arg1)
}

///|
pub fn lib__Instruction__i64_atomic_load32_u(
  arg0 : @lib.MemArg,
  arg1 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_i64_atomic_load32_u(arg0, arg1)
}

///|
pub fn lib__Instruction__i64_atomic_load8_u(
  arg0 : @lib.MemArg,
  arg1 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_i64_atomic_load8_u(arg0, arg1)
}

///|
pub fn lib__Instruction__i64_atomic_store(
  arg0 : @lib.MemArg,
  arg1 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_i64_atomic_store(arg0, arg1)
}

///|
pub fn lib__Instruction__i64_atomic_store16(
  arg0 : @lib.MemArg,
  arg1 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_i64_atomic_store16(arg0, arg1)
}

///|
pub fn lib__Instruction__i64_atomic_store32(
  arg0 : @lib.MemArg,
  arg1 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_i64_atomic_store32(arg0, arg1)
}

///|
pub fn lib__Instruction__i64_atomic_store8(
  arg0 : @lib.MemArg,
  arg1 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_i64_atomic_store8(arg0, arg1)
}

///|
pub fn lib__Instruction__i64_clz() -> @lib.Instruction {
  ffi_lib_Instruction_i64_clz()
}

///|
pub fn lib__Instruction__i64_const(arg0 : @lib.I64) -> @lib.Instruction {
  ffi_lib_Instruction_i64_const(arg0)
}

///|
pub fn lib__Instruction__i64_ctz() -> @lib.Instruction {
  ffi_lib_Instruction_i64_ctz()
}

///|
pub fn lib__Instruction__i64_div_s() -> @lib.Instruction {
  ffi_lib_Instruction_i64_div_s()
}

///|
pub fn lib__Instruction__i64_div_u() -> @lib.Instruction {
  ffi_lib_Instruction_i64_div_u()
}

///|
pub fn lib__Instruction__i64_eq() -> @lib.Instruction {
  ffi_lib_Instruction_i64_eq()
}

///|
pub fn lib__Instruction__i64_eqz() -> @lib.Instruction {
  ffi_lib_Instruction_i64_eqz()
}

///|
pub fn lib__Instruction__i64_extend16s() -> @lib.Instruction {
  ffi_lib_Instruction_i64_extend16s()
}

///|
pub fn lib__Instruction__i64_extend32s() -> @lib.Instruction {
  ffi_lib_Instruction_i64_extend32s()
}

///|
pub fn lib__Instruction__i64_extend8s() -> @lib.Instruction {
  ffi_lib_Instruction_i64_extend8s()
}

///|
pub fn lib__Instruction__i64_extend_i32s() -> @lib.Instruction {
  ffi_lib_Instruction_i64_extend_i32s()
}

///|
pub fn lib__Instruction__i64_extend_i32u() -> @lib.Instruction {
  ffi_lib_Instruction_i64_extend_i32u()
}

///|
pub fn lib__Instruction__i64_ge_s() -> @lib.Instruction {
  ffi_lib_Instruction_i64_ge_s()
}

///|
pub fn lib__Instruction__i64_ge_u() -> @lib.Instruction {
  ffi_lib_Instruction_i64_ge_u()
}

///|
pub fn lib__Instruction__i64_gt_s() -> @lib.Instruction {
  ffi_lib_Instruction_i64_gt_s()
}

///|
pub fn lib__Instruction__i64_gt_u() -> @lib.Instruction {
  ffi_lib_Instruction_i64_gt_u()
}

///|
pub fn lib__Instruction__i64_le_s() -> @lib.Instruction {
  ffi_lib_Instruction_i64_le_s()
}

///|
pub fn lib__Instruction__i64_le_u() -> @lib.Instruction {
  ffi_lib_Instruction_i64_le_u()
}

///|
pub fn lib__Instruction__i64_load(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_i64_load(arg0)
}

///|
pub fn lib__Instruction__i64_load16s(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_i64_load16s(arg0)
}

///|
pub fn lib__Instruction__i64_load16u(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_i64_load16u(arg0)
}

///|
pub fn lib__Instruction__i64_load32s(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_i64_load32s(arg0)
}

///|
pub fn lib__Instruction__i64_load32u(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_i64_load32u(arg0)
}

///|
pub fn lib__Instruction__i64_load8s(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_i64_load8s(arg0)
}

///|
pub fn lib__Instruction__i64_load8u(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_i64_load8u(arg0)
}

///|
pub fn lib__Instruction__i64_lt_s() -> @lib.Instruction {
  ffi_lib_Instruction_i64_lt_s()
}

///|
pub fn lib__Instruction__i64_lt_u() -> @lib.Instruction {
  ffi_lib_Instruction_i64_lt_u()
}

///|
pub fn lib__Instruction__i64_mul() -> @lib.Instruction {
  ffi_lib_Instruction_i64_mul()
}

///|
pub fn lib__Instruction__i64_ne() -> @lib.Instruction {
  ffi_lib_Instruction_i64_ne()
}

///|
pub fn lib__Instruction__i64_or() -> @lib.Instruction {
  ffi_lib_Instruction_i64_or()
}

///|
pub fn lib__Instruction__i64_popcnt() -> @lib.Instruction {
  ffi_lib_Instruction_i64_popcnt()
}

///|
pub fn lib__Instruction__i64_reinterpret_f64() -> @lib.Instruction {
  ffi_lib_Instruction_i64_reinterpret_f64()
}

///|
pub fn lib__Instruction__i64_rem_s() -> @lib.Instruction {
  ffi_lib_Instruction_i64_rem_s()
}

///|
pub fn lib__Instruction__i64_rem_u() -> @lib.Instruction {
  ffi_lib_Instruction_i64_rem_u()
}

///|
pub fn lib__Instruction__i64_rotl() -> @lib.Instruction {
  ffi_lib_Instruction_i64_rotl()
}

///|
pub fn lib__Instruction__i64_rotr() -> @lib.Instruction {
  ffi_lib_Instruction_i64_rotr()
}

///|
pub fn lib__Instruction__i64_shl() -> @lib.Instruction {
  ffi_lib_Instruction_i64_shl()
}

///|
pub fn lib__Instruction__i64_shr_s() -> @lib.Instruction {
  ffi_lib_Instruction_i64_shr_s()
}

///|
pub fn lib__Instruction__i64_shr_u() -> @lib.Instruction {
  ffi_lib_Instruction_i64_shr_u()
}

///|
pub fn lib__Instruction__i64_store(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_i64_store(arg0)
}

///|
pub fn lib__Instruction__i64_store16(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_i64_store16(arg0)
}

///|
pub fn lib__Instruction__i64_store32(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_i64_store32(arg0)
}

///|
pub fn lib__Instruction__i64_store8(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_i64_store8(arg0)
}

///|
pub fn lib__Instruction__i64_sub() -> @lib.Instruction {
  ffi_lib_Instruction_i64_sub()
}

///|
pub fn lib__Instruction__i64_trunc_f32s() -> @lib.Instruction {
  ffi_lib_Instruction_i64_trunc_f32s()
}

///|
pub fn lib__Instruction__i64_trunc_f32u() -> @lib.Instruction {
  ffi_lib_Instruction_i64_trunc_f32u()
}

///|
pub fn lib__Instruction__i64_trunc_f64s() -> @lib.Instruction {
  ffi_lib_Instruction_i64_trunc_f64s()
}

///|
pub fn lib__Instruction__i64_trunc_f64u() -> @lib.Instruction {
  ffi_lib_Instruction_i64_trunc_f64u()
}

///|
pub fn lib__Instruction__i64_trunc_sat_f32s() -> @lib.Instruction {
  ffi_lib_Instruction_i64_trunc_sat_f32s()
}

///|
pub fn lib__Instruction__i64_trunc_sat_f32u() -> @lib.Instruction {
  ffi_lib_Instruction_i64_trunc_sat_f32u()
}

///|
pub fn lib__Instruction__i64_trunc_sat_f64s() -> @lib.Instruction {
  ffi_lib_Instruction_i64_trunc_sat_f64s()
}

///|
pub fn lib__Instruction__i64_trunc_sat_f64u() -> @lib.Instruction {
  ffi_lib_Instruction_i64_trunc_sat_f64u()
}

///|
pub fn lib__Instruction__i64_xor() -> @lib.Instruction {
  ffi_lib_Instruction_i64_xor()
}

///|
pub fn lib__Instruction__i64x2_abs() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_abs()
}

///|
pub fn lib__Instruction__i64x2_add() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_add()
}

///|
pub fn lib__Instruction__i64x2_all_true() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_all_true()
}

///|
pub fn lib__Instruction__i64x2_bitmask() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_bitmask()
}

///|
pub fn lib__Instruction__i64x2_eq() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_eq()
}

///|
pub fn lib__Instruction__i64x2_extend_high_i32x4s() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_extend_high_i32x4s()
}

///|
pub fn lib__Instruction__i64x2_extend_high_i32x4u() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_extend_high_i32x4u()
}

///|
pub fn lib__Instruction__i64x2_extend_low_i32x4s() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_extend_low_i32x4s()
}

///|
pub fn lib__Instruction__i64x2_extend_low_i32x4u() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_extend_low_i32x4u()
}

///|
pub fn lib__Instruction__i64x2_extmul_high_i32x4s() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_extmul_high_i32x4s()
}

///|
pub fn lib__Instruction__i64x2_extmul_high_i32x4u() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_extmul_high_i32x4u()
}

///|
pub fn lib__Instruction__i64x2_extmul_low_i32x4s() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_extmul_low_i32x4s()
}

///|
pub fn lib__Instruction__i64x2_extmul_low_i32x4u() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_extmul_low_i32x4u()
}

///|
pub fn lib__Instruction__i64x2_extract_lane(
  arg0 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_extract_lane(arg0)
}

///|
pub fn lib__Instruction__i64x2_ge_s() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_ge_s()
}

///|
pub fn lib__Instruction__i64x2_gt_s() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_gt_s()
}

///|
pub fn lib__Instruction__i64x2_le_s() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_le_s()
}

///|
pub fn lib__Instruction__i64x2_lt_s() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_lt_s()
}

///|
pub fn lib__Instruction__i64x2_mul() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_mul()
}

///|
pub fn lib__Instruction__i64x2_ne() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_ne()
}

///|
pub fn lib__Instruction__i64x2_neg() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_neg()
}

///|
pub fn lib__Instruction__i64x2_relaxed_laneselect() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_relaxed_laneselect()
}

///|
pub fn lib__Instruction__i64x2_replace_lane(
  arg0 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_replace_lane(arg0)
}

///|
pub fn lib__Instruction__i64x2_shl() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_shl()
}

///|
pub fn lib__Instruction__i64x2_shr_s() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_shr_s()
}

///|
pub fn lib__Instruction__i64x2_shr_u() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_shr_u()
}

///|
pub fn lib__Instruction__i64x2_splat() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_splat()
}

///|
pub fn lib__Instruction__i64x2_sub() -> @lib.Instruction {
  ffi_lib_Instruction_i64x2_sub()
}

///|
pub fn lib__Instruction__i8x16_abs() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_abs()
}

///|
pub fn lib__Instruction__i8x16_add() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_add()
}

///|
pub fn lib__Instruction__i8x16_add_sat_s() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_add_sat_s()
}

///|
pub fn lib__Instruction__i8x16_add_sat_u() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_add_sat_u()
}

///|
pub fn lib__Instruction__i8x16_all_true() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_all_true()
}

///|
pub fn lib__Instruction__i8x16_avgr_u() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_avgr_u()
}

///|
pub fn lib__Instruction__i8x16_bitmask() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_bitmask()
}

///|
pub fn lib__Instruction__i8x16_eq() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_eq()
}

///|
pub fn lib__Instruction__i8x16_extract_lane_s(
  arg0 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_extract_lane_s(arg0)
}

///|
pub fn lib__Instruction__i8x16_extract_lane_u(
  arg0 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_extract_lane_u(arg0)
}

///|
pub fn lib__Instruction__i8x16_ge_s() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_ge_s()
}

///|
pub fn lib__Instruction__i8x16_ge_u() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_ge_u()
}

///|
pub fn lib__Instruction__i8x16_gt_s() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_gt_s()
}

///|
pub fn lib__Instruction__i8x16_gt_u() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_gt_u()
}

///|
pub fn lib__Instruction__i8x16_le_s() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_le_s()
}

///|
pub fn lib__Instruction__i8x16_le_u() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_le_u()
}

///|
pub fn lib__Instruction__i8x16_lt_s() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_lt_s()
}

///|
pub fn lib__Instruction__i8x16_lt_u() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_lt_u()
}

///|
pub fn lib__Instruction__i8x16_max_s() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_max_s()
}

///|
pub fn lib__Instruction__i8x16_max_u() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_max_u()
}

///|
pub fn lib__Instruction__i8x16_min_s() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_min_s()
}

///|
pub fn lib__Instruction__i8x16_min_u() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_min_u()
}

///|
pub fn lib__Instruction__i8x16_narrow_i16x8s() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_narrow_i16x8s()
}

///|
pub fn lib__Instruction__i8x16_narrow_i16x8u() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_narrow_i16x8u()
}

///|
pub fn lib__Instruction__i8x16_ne() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_ne()
}

///|
pub fn lib__Instruction__i8x16_neg() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_neg()
}

///|
pub fn lib__Instruction__i8x16_popcnt() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_popcnt()
}

///|
pub fn lib__Instruction__i8x16_relaxed_laneselect() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_relaxed_laneselect()
}

///|
pub fn lib__Instruction__i8x16_relaxed_swizzle() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_relaxed_swizzle()
}

///|
pub fn lib__Instruction__i8x16_replace_lane(
  arg0 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_replace_lane(arg0)
}

///|
pub fn lib__Instruction__i8x16_shl() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_shl()
}

///|
pub fn lib__Instruction__i8x16_shr_s() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_shr_s()
}

///|
pub fn lib__Instruction__i8x16_shr_u() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_shr_u()
}

///|
pub fn lib__Instruction__i8x16_shuffle(
  arg0 : @lib.LaneIdx,
  arg1 : @lib.LaneIdx,
  arg2 : @lib.LaneIdx,
  arg3 : @lib.LaneIdx,
  arg4 : @lib.LaneIdx,
  arg5 : @lib.LaneIdx,
  arg6 : @lib.LaneIdx,
  arg7 : @lib.LaneIdx,
  arg8 : @lib.LaneIdx,
  arg9 : @lib.LaneIdx,
  arg10 : @lib.LaneIdx,
  arg11 : @lib.LaneIdx,
  arg12 : @lib.LaneIdx,
  arg13 : @lib.LaneIdx,
  arg14 : @lib.LaneIdx,
  arg15 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_shuffle(
    arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12,
    arg13, arg14, arg15,
  )
}

///|
pub fn lib__Instruction__i8x16_splat() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_splat()
}

///|
pub fn lib__Instruction__i8x16_sub() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_sub()
}

///|
pub fn lib__Instruction__i8x16_sub_sat_s() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_sub_sat_s()
}

///|
pub fn lib__Instruction__i8x16_sub_sat_u() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_sub_sat_u()
}

///|
pub fn lib__Instruction__i8x16_swizzle() -> @lib.Instruction {
  ffi_lib_Instruction_i8x16_swizzle()
}

///|
pub fn lib__Instruction__if_(
  arg0 : @lib.BlockType,
  arg1 : Array[@lib.Instruction],
  arg2 : Array[@lib.Instruction]?,
) -> @lib.Instruction {
  ffi_lib_Instruction_if_(arg0, arg1, arg2)
}

///|
pub fn lib__Instruction__local_get(arg0 : @lib.LocalIdx) -> @lib.Instruction {
  ffi_lib_Instruction_local_get(arg0)
}

///|
pub fn lib__Instruction__local_set(arg0 : @lib.LocalIdx) -> @lib.Instruction {
  ffi_lib_Instruction_local_set(arg0)
}

///|
pub fn lib__Instruction__local_tee(arg0 : @lib.LocalIdx) -> @lib.Instruction {
  ffi_lib_Instruction_local_tee(arg0)
}

///|
pub fn lib__Instruction__loop_(
  arg0 : @lib.BlockType,
  arg1 : @lib.Expr,
) -> @lib.Instruction {
  ffi_lib_Instruction_loop_(arg0, arg1)
}

///|
pub fn lib__Instruction__memory_atomic_notify(
  arg0 : @lib.MemArg,
) -> @lib.Instruction {
  ffi_lib_Instruction_memory_atomic_notify(arg0)
}

///|
pub fn lib__Instruction__memory_atomic_wait32(
  arg0 : @lib.MemArg,
) -> @lib.Instruction {
  ffi_lib_Instruction_memory_atomic_wait32(arg0)
}

///|
pub fn lib__Instruction__memory_atomic_wait64(
  arg0 : @lib.MemArg,
) -> @lib.Instruction {
  ffi_lib_Instruction_memory_atomic_wait64(arg0)
}

///|
pub fn lib__Instruction__memory_copy(
  arg0 : @lib.MemIdx,
  arg1 : @lib.MemIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_memory_copy(arg0, arg1)
}

///|
pub fn lib__Instruction__memory_fill(arg0 : @lib.MemIdx) -> @lib.Instruction {
  ffi_lib_Instruction_memory_fill(arg0)
}

///|
pub fn lib__Instruction__memory_grow(arg0 : @lib.MemIdx) -> @lib.Instruction {
  ffi_lib_Instruction_memory_grow(arg0)
}

///|
pub fn lib__Instruction__memory_init(
  arg0 : @lib.DataIdx,
  arg1 : @lib.MemIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_memory_init(arg0, arg1)
}

///|
pub fn lib__Instruction__memory_size(arg0 : @lib.MemIdx) -> @lib.Instruction {
  ffi_lib_Instruction_memory_size(arg0)
}

///|
pub fn lib__Instruction__nop() -> @lib.Instruction {
  ffi_lib_Instruction_nop()
}

///|
pub fn lib__Instruction__publish() -> @lib.Instruction {
  ffi_lib_Instruction_publish()
}

///|
pub fn lib__Instruction__ref_as_non_null() -> @lib.Instruction {
  ffi_lib_Instruction_ref_as_non_null()
}

///|
pub fn lib__Instruction__ref_cast(
  arg0 : Bool,
  arg1 : @lib.HeapType,
) -> @lib.Instruction {
  ffi_lib_Instruction_ref_cast(arg0, arg1)
}

///|
pub fn lib__Instruction__ref_cast_desc_eq(
  arg0 : Bool,
  arg1 : @lib.HeapType,
) -> @lib.Instruction {
  ffi_lib_Instruction_ref_cast_desc_eq(arg0, arg1)
}

///|
pub fn lib__Instruction__ref_cast_desc_eq_type(
  arg0 : @lib.RefType,
) -> @lib.Instruction {
  ffi_lib_Instruction_ref_cast_desc_eq_type(arg0)
}

///|
pub fn lib__Instruction__ref_cast_exact(
  arg0 : Bool,
  arg1 : @lib.HeapType,
) -> @lib.Instruction {
  ffi_lib_Instruction_ref_cast_exact(arg0, arg1)
}

///|
pub fn lib__Instruction__ref_cast_type(arg0 : @lib.RefType) -> @lib.Instruction {
  ffi_lib_Instruction_ref_cast_type(arg0)
}

///|
pub fn lib__Instruction__ref_eq() -> @lib.Instruction {
  ffi_lib_Instruction_ref_eq()
}

///|
pub fn lib__Instruction__ref_func(arg0 : @lib.FuncIdx) -> @lib.Instruction {
  ffi_lib_Instruction_ref_func(arg0)
}

///|
pub fn lib__Instruction__ref_get_desc(arg0 : @lib.TypeIdx) -> @lib.Instruction {
  ffi_lib_Instruction_ref_get_desc(arg0)
}

///|
pub fn lib__Instruction__ref_i31() -> @lib.Instruction {
  ffi_lib_Instruction_ref_i31()
}

///|
pub fn lib__Instruction__ref_i31_shared() -> @lib.Instruction {
  ffi_lib_Instruction_ref_i31_shared()
}

///|
pub fn lib__Instruction__ref_is_null() -> @lib.Instruction {
  ffi_lib_Instruction_ref_is_null()
}

///|
pub fn lib__Instruction__ref_null(arg0 : @lib.HeapType) -> @lib.Instruction {
  ffi_lib_Instruction_ref_null(arg0)
}

///|
pub fn lib__Instruction__ref_null_type(arg0 : @lib.RefType) -> @lib.Instruction {
  ffi_lib_Instruction_ref_null_type(arg0)
}

///|
pub fn lib__Instruction__ref_test(
  arg0 : Bool,
  arg1 : @lib.HeapType,
) -> @lib.Instruction {
  ffi_lib_Instruction_ref_test(arg0, arg1)
}

///|
pub fn lib__Instruction__ref_test_desc(
  arg0 : Bool,
  arg1 : @lib.HeapType,
) -> @lib.Instruction {
  ffi_lib_Instruction_ref_test_desc(arg0, arg1)
}

///|
pub fn lib__Instruction__ref_test_exact(
  arg0 : Bool,
  arg1 : @lib.HeapType,
) -> @lib.Instruction {
  ffi_lib_Instruction_ref_test_exact(arg0, arg1)
}

///|
pub fn lib__Instruction__ref_test_type(arg0 : @lib.RefType) -> @lib.Instruction {
  ffi_lib_Instruction_ref_test_type(arg0)
}

///|
pub fn lib__Instruction__resume_(
  arg0 : @lib.TypeIdx,
  arg1 : Array[@lib.ResumeHandler],
) -> @lib.Instruction {
  ffi_lib_Instruction_resume_(arg0, arg1)
}

///|
pub fn lib__Instruction__resume_throw(
  arg0 : @lib.TypeIdx,
  arg1 : @lib.TagIdx,
  arg2 : Array[@lib.ResumeHandler],
) -> @lib.Instruction {
  ffi_lib_Instruction_resume_throw(arg0, arg1, arg2)
}

///|
pub fn lib__Instruction__resume_throw_ref(
  arg0 : @lib.TypeIdx,
  arg1 : Array[@lib.ResumeHandler],
) -> @lib.Instruction {
  ffi_lib_Instruction_resume_throw_ref(arg0, arg1)
}

///|
pub fn lib__Instruction__rethrow(arg0 : @lib.LabelIdx) -> @lib.Instruction {
  ffi_lib_Instruction_rethrow(arg0)
}

///|
pub fn lib__Instruction__return_() -> @lib.Instruction {
  ffi_lib_Instruction_return_()
}

///|
pub fn lib__Instruction__return_call(arg0 : @lib.FuncIdx) -> @lib.Instruction {
  ffi_lib_Instruction_return_call(arg0)
}

///|
pub fn lib__Instruction__return_call_indirect(
  arg0 : @lib.TypeIdx,
  arg1 : @lib.TableIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_return_call_indirect(arg0, arg1)
}

///|
pub fn lib__Instruction__return_call_ref(
  arg0 : @lib.TypeIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_return_call_ref(arg0)
}

///|
pub fn lib__Instruction__select(
  arg0 : Array[@lib.ValType]??,
) -> @lib.Instruction {
  ffi_lib_Instruction_select(arg0)
}

///|
pub fn lib__Instruction__stack_switch(
  arg0 : @lib.TypeIdx,
  arg1 : @lib.TagIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_stack_switch(arg0, arg1)
}

///|
pub fn lib__Instruction__string_as_wtf16() -> @lib.Instruction {
  ffi_lib_Instruction_string_as_wtf16()
}

///|
pub fn lib__Instruction__string_concat() -> @lib.Instruction {
  ffi_lib_Instruction_string_concat()
}

///|
pub fn lib__Instruction__string_const(arg0 : Bytes) -> @lib.Instruction {
  ffi_lib_Instruction_string_const(arg0)
}

///|
pub fn lib__Instruction__string_encode_lossy_utf8_array() -> @lib.Instruction {
  ffi_lib_Instruction_string_encode_lossy_utf8_array()
}

///|
pub fn lib__Instruction__string_encode_utf8_array() -> @lib.Instruction {
  ffi_lib_Instruction_string_encode_utf8_array()
}

///|
pub fn lib__Instruction__string_encode_wtf16_array() -> @lib.Instruction {
  ffi_lib_Instruction_string_encode_wtf16_array()
}

///|
pub fn lib__Instruction__string_encode_wtf8_array() -> @lib.Instruction {
  ffi_lib_Instruction_string_encode_wtf8_array()
}

///|
pub fn lib__Instruction__string_eq() -> @lib.Instruction {
  ffi_lib_Instruction_string_eq()
}

///|
pub fn lib__Instruction__string_measure_wtf16() -> @lib.Instruction {
  ffi_lib_Instruction_string_measure_wtf16()
}

///|
pub fn lib__Instruction__string_new_lossy_utf8_array() -> @lib.Instruction {
  ffi_lib_Instruction_string_new_lossy_utf8_array()
}

///|
pub fn lib__Instruction__string_new_utf8_array() -> @lib.Instruction {
  ffi_lib_Instruction_string_new_utf8_array()
}

///|
pub fn lib__Instruction__string_new_wtf16_array() -> @lib.Instruction {
  ffi_lib_Instruction_string_new_wtf16_array()
}

///|
pub fn lib__Instruction__string_new_wtf8_array() -> @lib.Instruction {
  ffi_lib_Instruction_string_new_wtf8_array()
}

///|
pub fn lib__Instruction__stringview_wtf16_get_codeunit() -> @lib.Instruction {
  ffi_lib_Instruction_stringview_wtf16_get_codeunit()
}

///|
pub fn lib__Instruction__stringview_wtf16_slice() -> @lib.Instruction {
  ffi_lib_Instruction_stringview_wtf16_slice()
}

///|
pub fn lib__Instruction__struct_atomic_cmpxchg(
  arg0 : @lib.TypeIdx,
  arg1 : @lib.U32,
  arg2 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_struct_atomic_cmpxchg(arg0, arg1, arg2)
}

///|
pub fn lib__Instruction__struct_atomic_get(
  arg0 : @lib.AtomicOrder,
  arg1 : @lib.TypeIdx,
  arg2 : @lib.U32,
) -> @lib.Instruction {
  ffi_lib_Instruction_struct_atomic_get(arg0, arg1, arg2)
}

///|
pub fn lib__Instruction__struct_atomic_get_s(
  arg0 : @lib.AtomicOrder,
  arg1 : @lib.TypeIdx,
  arg2 : @lib.U32,
) -> @lib.Instruction {
  ffi_lib_Instruction_struct_atomic_get_s(arg0, arg1, arg2)
}

///|
pub fn lib__Instruction__struct_atomic_get_u(
  arg0 : @lib.AtomicOrder,
  arg1 : @lib.TypeIdx,
  arg2 : @lib.U32,
) -> @lib.Instruction {
  ffi_lib_Instruction_struct_atomic_get_u(arg0, arg1, arg2)
}

///|
pub fn lib__Instruction__struct_atomic_rmw(
  arg0 : @lib.AggregateAtomicRmwOp,
  arg1 : @lib.TypeIdx,
  arg2 : @lib.U32,
  arg3 : @lib.AtomicOrder?,
) -> @lib.Instruction {
  ffi_lib_Instruction_struct_atomic_rmw(arg0, arg1, arg2, arg3)
}

///|
pub fn lib__Instruction__struct_atomic_set(
  arg0 : @lib.AtomicOrder,
  arg1 : @lib.TypeIdx,
  arg2 : @lib.U32,
) -> @lib.Instruction {
  ffi_lib_Instruction_struct_atomic_set(arg0, arg1, arg2)
}

///|
pub fn lib__Instruction__struct_get(
  arg0 : @lib.TypeIdx,
  arg1 : @lib.U32,
) -> @lib.Instruction {
  ffi_lib_Instruction_struct_get(arg0, arg1)
}

///|
pub fn lib__Instruction__struct_get_s(
  arg0 : @lib.TypeIdx,
  arg1 : @lib.U32,
) -> @lib.Instruction {
  ffi_lib_Instruction_struct_get_s(arg0, arg1)
}

///|
pub fn lib__Instruction__struct_get_u(
  arg0 : @lib.TypeIdx,
  arg1 : @lib.U32,
) -> @lib.Instruction {
  ffi_lib_Instruction_struct_get_u(arg0, arg1)
}

///|
pub fn lib__Instruction__struct_new(arg0 : @lib.TypeIdx) -> @lib.Instruction {
  ffi_lib_Instruction_struct_new(arg0)
}

///|
pub fn lib__Instruction__struct_new_default(
  arg0 : @lib.TypeIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_struct_new_default(arg0)
}

///|
pub fn lib__Instruction__struct_new_default_desc(
  arg0 : @lib.TypeIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_struct_new_default_desc(arg0)
}

///|
pub fn lib__Instruction__struct_new_desc(
  arg0 : @lib.TypeIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_struct_new_desc(arg0)
}

///|
pub fn lib__Instruction__struct_set(
  arg0 : @lib.TypeIdx,
  arg1 : @lib.U32,
) -> @lib.Instruction {
  ffi_lib_Instruction_struct_set(arg0, arg1)
}

///|
pub fn lib__Instruction__struct_wait(
  arg0 : @lib.TypeIdx,
  arg1 : @lib.U32,
) -> @lib.Instruction {
  ffi_lib_Instruction_struct_wait(arg0, arg1)
}

///|
pub fn lib__Instruction__suspend(arg0 : @lib.TagIdx) -> @lib.Instruction {
  ffi_lib_Instruction_suspend(arg0)
}

///|
pub fn lib__Instruction__table_copy(
  arg0 : @lib.TableIdx,
  arg1 : @lib.TableIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_table_copy(arg0, arg1)
}

///|
pub fn lib__Instruction__table_fill(arg0 : @lib.TableIdx) -> @lib.Instruction {
  ffi_lib_Instruction_table_fill(arg0)
}

///|
pub fn lib__Instruction__table_get(arg0 : @lib.TableIdx) -> @lib.Instruction {
  ffi_lib_Instruction_table_get(arg0)
}

///|
pub fn lib__Instruction__table_grow(arg0 : @lib.TableIdx) -> @lib.Instruction {
  ffi_lib_Instruction_table_grow(arg0)
}

///|
pub fn lib__Instruction__table_init(
  arg0 : @lib.ElemIdx,
  arg1 : @lib.TableIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_table_init(arg0, arg1)
}

///|
pub fn lib__Instruction__table_set(arg0 : @lib.TableIdx) -> @lib.Instruction {
  ffi_lib_Instruction_table_set(arg0)
}

///|
pub fn lib__Instruction__table_size(arg0 : @lib.TableIdx) -> @lib.Instruction {
  ffi_lib_Instruction_table_size(arg0)
}

///|
pub fn lib__Instruction__throw_(arg0 : @lib.TagIdx) -> @lib.Instruction {
  ffi_lib_Instruction_throw_(arg0)
}

///|
pub fn lib__Instruction__throw_ref() -> @lib.Instruction {
  ffi_lib_Instruction_throw_ref()
}

///|
pub fn lib__Instruction__try_(
  arg0 : @lib.BlockType,
  arg1 : @lib.Expr,
  arg2 : Array[@lib.LegacyCatch],
  arg3 : @lib.LabelIdx??,
) -> @lib.Instruction {
  ffi_lib_Instruction_try_(arg0, arg1, arg2, arg3)
}

///|
pub fn lib__Instruction__try_table(
  arg0 : @lib.BlockType,
  arg1 : Array[@lib.Catch],
  arg2 : @lib.Expr,
) -> @lib.Instruction {
  ffi_lib_Instruction_try_table(arg0, arg1, arg2)
}

///|
pub fn lib__Instruction__unreachable_() -> @lib.Instruction {
  ffi_lib_Instruction_unreachable_()
}

///|
pub fn lib__Instruction__v128_and() -> @lib.Instruction {
  ffi_lib_Instruction_v128_and()
}

///|
pub fn lib__Instruction__v128_andnot() -> @lib.Instruction {
  ffi_lib_Instruction_v128_andnot()
}

///|
pub fn lib__Instruction__v128_any_true() -> @lib.Instruction {
  ffi_lib_Instruction_v128_any_true()
}

///|
pub fn lib__Instruction__v128_bitselect() -> @lib.Instruction {
  ffi_lib_Instruction_v128_bitselect()
}

///|
pub fn lib__Instruction__v128_const(
  arg0 : Byte,
  arg1 : Byte,
  arg2 : Byte,
  arg3 : Byte,
  arg4 : Byte,
  arg5 : Byte,
  arg6 : Byte,
  arg7 : Byte,
  arg8 : Byte,
  arg9 : Byte,
  arg10 : Byte,
  arg11 : Byte,
  arg12 : Byte,
  arg13 : Byte,
  arg14 : Byte,
  arg15 : Byte,
) -> @lib.Instruction {
  ffi_lib_Instruction_v128_const(
    arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12,
    arg13, arg14, arg15,
  )
}

///|
pub fn lib__Instruction__v128_load(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_v128_load(arg0)
}

///|
pub fn lib__Instruction__v128_load16_lane(
  arg0 : @lib.MemArg,
  arg1 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_v128_load16_lane(arg0, arg1)
}

///|
pub fn lib__Instruction__v128_load16_splat(
  arg0 : @lib.MemArg,
) -> @lib.Instruction {
  ffi_lib_Instruction_v128_load16_splat(arg0)
}

///|
pub fn lib__Instruction__v128_load16x4s(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_v128_load16x4s(arg0)
}

///|
pub fn lib__Instruction__v128_load16x4u(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_v128_load16x4u(arg0)
}

///|
pub fn lib__Instruction__v128_load32_lane(
  arg0 : @lib.MemArg,
  arg1 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_v128_load32_lane(arg0, arg1)
}

///|
pub fn lib__Instruction__v128_load32_splat(
  arg0 : @lib.MemArg,
) -> @lib.Instruction {
  ffi_lib_Instruction_v128_load32_splat(arg0)
}

///|
pub fn lib__Instruction__v128_load32_zero(
  arg0 : @lib.MemArg,
) -> @lib.Instruction {
  ffi_lib_Instruction_v128_load32_zero(arg0)
}

///|
pub fn lib__Instruction__v128_load32x2s(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_v128_load32x2s(arg0)
}

///|
pub fn lib__Instruction__v128_load32x2u(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_v128_load32x2u(arg0)
}

///|
pub fn lib__Instruction__v128_load64_lane(
  arg0 : @lib.MemArg,
  arg1 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_v128_load64_lane(arg0, arg1)
}

///|
pub fn lib__Instruction__v128_load64_splat(
  arg0 : @lib.MemArg,
) -> @lib.Instruction {
  ffi_lib_Instruction_v128_load64_splat(arg0)
}

///|
pub fn lib__Instruction__v128_load64_zero(
  arg0 : @lib.MemArg,
) -> @lib.Instruction {
  ffi_lib_Instruction_v128_load64_zero(arg0)
}

///|
pub fn lib__Instruction__v128_load8_lane(
  arg0 : @lib.MemArg,
  arg1 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_v128_load8_lane(arg0, arg1)
}

///|
pub fn lib__Instruction__v128_load8_splat(
  arg0 : @lib.MemArg,
) -> @lib.Instruction {
  ffi_lib_Instruction_v128_load8_splat(arg0)
}

///|
pub fn lib__Instruction__v128_load8x8s(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_v128_load8x8s(arg0)
}

///|
pub fn lib__Instruction__v128_load8x8u(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_v128_load8x8u(arg0)
}

///|
pub fn lib__Instruction__v128_not() -> @lib.Instruction {
  ffi_lib_Instruction_v128_not()
}

///|
pub fn lib__Instruction__v128_or() -> @lib.Instruction {
  ffi_lib_Instruction_v128_or()
}

///|
pub fn lib__Instruction__v128_store(arg0 : @lib.MemArg) -> @lib.Instruction {
  ffi_lib_Instruction_v128_store(arg0)
}

///|
pub fn lib__Instruction__v128_store16_lane(
  arg0 : @lib.MemArg,
  arg1 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_v128_store16_lane(arg0, arg1)
}

///|
pub fn lib__Instruction__v128_store32_lane(
  arg0 : @lib.MemArg,
  arg1 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_v128_store32_lane(arg0, arg1)
}

///|
pub fn lib__Instruction__v128_store64_lane(
  arg0 : @lib.MemArg,
  arg1 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_v128_store64_lane(arg0, arg1)
}

///|
pub fn lib__Instruction__v128_store8_lane(
  arg0 : @lib.MemArg,
  arg1 : @lib.LaneIdx,
) -> @lib.Instruction {
  ffi_lib_Instruction_v128_store8_lane(arg0, arg1)
}

///|
pub fn lib__Instruction__v128_xor() -> @lib.Instruction {
  ffi_lib_Instruction_v128_xor()
}

///|
pub fn lib__Instruction__waitqueue_new() -> @lib.Instruction {
  ffi_lib_Instruction_waitqueue_new()
}

///|
pub fn lib__Instruction__waitqueue_notify() -> @lib.Instruction {
  ffi_lib_Instruction_waitqueue_notify()
}

///|
pub fn lib__LabelIdx__new(arg0 : UInt) -> @lib.LabelIdx {
  ffi_lib_LabelIdx_new(arg0)
}

///|
pub fn lib__LaneIdx__new(arg0 : Byte) -> @lib.LaneIdx {
  ffi_lib_LaneIdx_new(arg0)
}

///|
pub fn lib__LegacyCatch__all(arg0 : @lib.Expr) -> @lib.LegacyCatch {
  ffi_lib_LegacyCatch_all(arg0)
}

///|
pub fn lib__LegacyCatch__tagged(
  arg0 : @lib.TagIdx,
  arg1 : @lib.Expr,
) -> @lib.LegacyCatch {
  ffi_lib_LegacyCatch_tagged(arg0, arg1)
}

///|
pub fn lib__Limits__addr_valtype(arg0 : @lib.Limits) -> @lib.ValType {
  ffi_lib_Limits_addr_valtype(arg0)
}

///|
pub fn lib__Limits__i32(arg0 : UInt, arg1 : UInt?) -> @lib.Limits {
  ffi_lib_Limits_i32(arg0, arg1)
}

///|
pub fn lib__Limits__i64(arg0 : UInt64, arg1 : UInt64?) -> @lib.Limits {
  ffi_lib_Limits_i64(arg0, arg1)
}

///|
pub fn lib__Limits__mem_addr_bits(arg0 : @lib.Limits) -> Int {
  ffi_lib_Limits_mem_addr_bits(arg0)
}

///|
pub fn lib__LoadOp__f32_load() -> @lib.LoadOp {
  ffi_lib_LoadOp_f32_load()
}

///|
pub fn lib__LoadOp__f64_load() -> @lib.LoadOp {
  ffi_lib_LoadOp_f64_load()
}

///|
pub fn lib__LoadOp__i32_atomic_load() -> @lib.LoadOp {
  ffi_lib_LoadOp_i32_atomic_load()
}

///|
pub fn lib__LoadOp__i32_atomic_load16_u() -> @lib.LoadOp {
  ffi_lib_LoadOp_i32_atomic_load16_u()
}

///|
pub fn lib__LoadOp__i32_atomic_load8_u() -> @lib.LoadOp {
  ffi_lib_LoadOp_i32_atomic_load8_u()
}

///|
pub fn lib__LoadOp__i32_load() -> @lib.LoadOp {
  ffi_lib_LoadOp_i32_load()
}

///|
pub fn lib__LoadOp__i32_load16s() -> @lib.LoadOp {
  ffi_lib_LoadOp_i32_load16s()
}

///|
pub fn lib__LoadOp__i32_load16u() -> @lib.LoadOp {
  ffi_lib_LoadOp_i32_load16u()
}

///|
pub fn lib__LoadOp__i32_load8s() -> @lib.LoadOp {
  ffi_lib_LoadOp_i32_load8s()
}

///|
pub fn lib__LoadOp__i32_load8u() -> @lib.LoadOp {
  ffi_lib_LoadOp_i32_load8u()
}

///|
pub fn lib__LoadOp__i64_atomic_load() -> @lib.LoadOp {
  ffi_lib_LoadOp_i64_atomic_load()
}

///|
pub fn lib__LoadOp__i64_atomic_load16_u() -> @lib.LoadOp {
  ffi_lib_LoadOp_i64_atomic_load16_u()
}

///|
pub fn lib__LoadOp__i64_atomic_load32_u() -> @lib.LoadOp {
  ffi_lib_LoadOp_i64_atomic_load32_u()
}

///|
pub fn lib__LoadOp__i64_atomic_load8_u() -> @lib.LoadOp {
  ffi_lib_LoadOp_i64_atomic_load8_u()
}

///|
pub fn lib__LoadOp__i64_load() -> @lib.LoadOp {
  ffi_lib_LoadOp_i64_load()
}

///|
pub fn lib__LoadOp__i64_load16s() -> @lib.LoadOp {
  ffi_lib_LoadOp_i64_load16s()
}

///|
pub fn lib__LoadOp__i64_load16u() -> @lib.LoadOp {
  ffi_lib_LoadOp_i64_load16u()
}

///|
pub fn lib__LoadOp__i64_load32s() -> @lib.LoadOp {
  ffi_lib_LoadOp_i64_load32s()
}

///|
pub fn lib__LoadOp__i64_load32u() -> @lib.LoadOp {
  ffi_lib_LoadOp_i64_load32u()
}

///|
pub fn lib__LoadOp__i64_load8s() -> @lib.LoadOp {
  ffi_lib_LoadOp_i64_load8s()
}

///|
pub fn lib__LoadOp__i64_load8u() -> @lib.LoadOp {
  ffi_lib_LoadOp_i64_load8u()
}

///|
pub fn lib__LoadOp__v128_load() -> @lib.LoadOp {
  ffi_lib_LoadOp_v128_load()
}

///|
pub fn lib__LoadOp__v128_load16_splat() -> @lib.LoadOp {
  ffi_lib_LoadOp_v128_load16_splat()
}

///|
pub fn lib__LoadOp__v128_load16x4s() -> @lib.LoadOp {
  ffi_lib_LoadOp_v128_load16x4s()
}

///|
pub fn lib__LoadOp__v128_load16x4u() -> @lib.LoadOp {
  ffi_lib_LoadOp_v128_load16x4u()
}

///|
pub fn lib__LoadOp__v128_load32_splat() -> @lib.LoadOp {
  ffi_lib_LoadOp_v128_load32_splat()
}

///|
pub fn lib__LoadOp__v128_load32_zero() -> @lib.LoadOp {
  ffi_lib_LoadOp_v128_load32_zero()
}

///|
pub fn lib__LoadOp__v128_load32x2s() -> @lib.LoadOp {
  ffi_lib_LoadOp_v128_load32x2s()
}

///|
pub fn lib__LoadOp__v128_load32x2u() -> @lib.LoadOp {
  ffi_lib_LoadOp_v128_load32x2u()
}

///|
pub fn lib__LoadOp__v128_load64_splat() -> @lib.LoadOp {
  ffi_lib_LoadOp_v128_load64_splat()
}

///|
pub fn lib__LoadOp__v128_load64_zero() -> @lib.LoadOp {
  ffi_lib_LoadOp_v128_load64_zero()
}

///|
pub fn lib__LoadOp__v128_load8_splat() -> @lib.LoadOp {
  ffi_lib_LoadOp_v128_load8_splat()
}

///|
pub fn lib__LoadOp__v128_load8x8s() -> @lib.LoadOp {
  ffi_lib_LoadOp_v128_load8x8s()
}

///|
pub fn lib__LoadOp__v128_load8x8u() -> @lib.LoadOp {
  ffi_lib_LoadOp_v128_load8x8u()
}

///|
pub fn lib__LocalIdx__new(arg0 : UInt) -> @lib.LocalIdx {
  ffi_lib_LocalIdx_new(arg0)
}

///|
pub fn lib__LocalRun__count(arg0 : @lib.LocalRun) -> UInt {
  ffi_lib_LocalRun_count(arg0)
}

///|
pub fn lib__LocalRun__new(arg0 : UInt, arg1 : @lib.ValType) -> @lib.LocalRun {
  ffi_lib_LocalRun_new(arg0, arg1)
}

///|
pub fn lib__LocalRun__val_type(arg0 : @lib.LocalRun) -> @lib.ValType {
  ffi_lib_LocalRun_val_type(arg0)
}

///|
pub fn lib__Locals__append(arg0 : @lib.Locals, arg1 : @lib.Locals) -> Unit {
  ffi_lib_Locals_append(arg0, arg1)
}

///|
pub fn lib__Locals__append_types(
  arg0 : @lib.Locals,
  arg1 : Array[@lib.ValType],
) -> Unit {
  ffi_lib_Locals_append_types(arg0, arg1)
}

///|
pub fn lib__Locals__at(arg0 : @lib.Locals, arg1 : Int) -> @lib.ValType? {
  ffi_lib_Locals_at(arg0, arg1)
}

///|
pub fn lib__Locals__copy(arg0 : @lib.Locals) -> @lib.Locals {
  ffi_lib_Locals_copy(arg0)
}

///|
pub fn lib__Locals__empty() -> @lib.Locals {
  ffi_lib_Locals_empty()
}

///|
pub fn lib__Locals__ensure_index(arg0 : @lib.Locals) -> Array[Int] {
  ffi_lib_Locals_ensure_index(arg0)
}

///|
pub fn lib__Locals__from_decl_runs_preserving_groups(
  arg0 : Array[@lib.LocalRun],
) -> @lib.Locals {
  ffi_lib_Locals_from_decl_runs_preserving_groups(arg0)
}

///|
pub fn lib__Locals__from_types(arg0 : Array[@lib.ValType]) -> @lib.Locals {
  ffi_lib_Locals_from_types(arg0)
}

///|
pub fn lib__Locals__get(arg0 : @lib.Locals, arg1 : Int) -> @lib.ValType {
  ffi_lib_Locals_get(arg0, arg1)
}

///|
pub fn lib__Locals__insert_run(
  arg0 : @lib.Locals,
  arg1 : Int,
  arg2 : @lib.LocalRun,
) -> Unit {
  ffi_lib_Locals_insert_run(arg0, arg1, arg2)
}

///|
pub fn lib__Locals__invalidate_indices(arg0 : @lib.Locals) -> Unit {
  ffi_lib_Locals_invalidate_indices(arg0)
}

///|
pub fn lib__Locals__is_empty(arg0 : @lib.Locals) -> Bool {
  ffi_lib_Locals_is_empty(arg0)
}

///|
pub fn lib__Locals__iter(arg0 : @lib.Locals) -> Iter[@lib.ValType] {
  ffi_lib_Locals_iter(arg0)
}

///|
pub fn lib__Locals__length(arg0 : @lib.Locals) -> Int {
  ffi_lib_Locals_length(arg0)
}

///|
pub fn lib__Locals__merge_adjacent_runs(arg0 : @lib.Locals) -> Unit {
  ffi_lib_Locals_merge_adjacent_runs(arg0)
}

///|
pub fn lib__Locals__new(arg0 : Array[@lib.LocalRun]) -> @lib.Locals {
  ffi_lib_Locals_new(arg0)
}

///|
pub fn lib__Locals__push(arg0 : @lib.Locals, arg1 : @lib.ValType) -> Unit {
  ffi_lib_Locals_push(arg0, arg1)
}

///|
pub fn lib__Locals__push_run(arg0 : @lib.Locals, arg1 : @lib.LocalRun) -> Unit {
  ffi_lib_Locals_push_run(arg0, arg1)
}

///|
pub fn lib__Locals__remove_run(
  arg0 : @lib.Locals,
  arg1 : Int,
) -> @lib.LocalRun? {
  ffi_lib_Locals_remove_run(arg0, arg1)
}

///|
pub fn lib__Locals__run_count(arg0 : @lib.Locals) -> Int {
  ffi_lib_Locals_run_count(arg0)
}

///|
pub fn lib__Locals__runs(arg0 : @lib.Locals) -> Array[@lib.LocalRun] {
  ffi_lib_Locals_runs(arg0)
}

///|
pub fn lib__Locals__set(
  arg0 : @lib.Locals,
  arg1 : Int,
  arg2 : @lib.ValType,
) -> Bool {
  ffi_lib_Locals_set(arg0, arg1, arg2)
}

///|
pub fn lib__Locals__set_run_count(
  arg0 : @lib.Locals,
  arg1 : Int,
  arg2 : UInt,
) -> Bool {
  ffi_lib_Locals_set_run_count(arg0, arg1, arg2)
}

///|
pub fn lib__Locals__single(arg0 : UInt, arg1 : @lib.ValType) -> @lib.Locals {
  ffi_lib_Locals_single(arg0, arg1)
}

///|
pub fn lib__Locals__unsafe_get(arg0 : @lib.Locals, arg1 : Int) -> @lib.ValType {
  ffi_lib_Locals_unsafe_get(arg0, arg1)
}

///|
pub fn lib__Locals__without_prefix(
  arg0 : @lib.Locals,
  arg1 : Int,
) -> @lib.Locals {
  ffi_lib_Locals_without_prefix(arg0, arg1)
}

///|
pub fn lib__MemArg__new(
  arg0 : @lib.U32,
  arg1 : @lib.MemIdx?,
  arg2 : @lib.U64,
) -> @lib.MemArg {
  ffi_lib_MemArg_new(arg0, arg1, arg2)
}

///|
pub fn lib__MemIdx__new(arg0 : UInt) -> @lib.MemIdx {
  ffi_lib_MemIdx_new(arg0)
}

///|
pub fn lib__MemSec__new(arg0 : Array[@lib.MemType]) -> @lib.MemSec {
  ffi_lib_MemSec_new(arg0)
}

///|
pub fn lib__MemType__new(arg0 : @lib.Limits, arg1 : Bool?) -> @lib.MemType {
  ffi_lib_MemType_new(arg0, arg1)
}

///|
pub fn lib__Module__new(
  arg0 : Array[@lib.CustomSec]?,
  arg1 : @lib.TypeSec??,
  arg2 : @lib.ImportSec??,
  arg3 : @lib.FuncAnnotationSec??,
  arg4 : @lib.FuncSec??,
  arg5 : @lib.TableSec??,
  arg6 : @lib.MemSec??,
  arg7 : @lib.TagSec??,
  arg9 : @lib.GlobalSec??,
  arg10 : @lib.ExportSec??,
  arg11 : @lib.StartSec??,
  arg12 : @lib.ElemSec??,
  arg13 : @lib.DataCntSec??,
  arg14 : @lib.CodeSec??,
  arg15 : @lib.DataSec??,
  arg8 : @lib.StringRefsSec??,
  arg16 : @lib.NameSec??,
  arg17 : Bytes??,
  arg18 : @representation.CompilerFactCustomSection??,
) -> @lib.Module {
  ffi_lib_Module_new(
    arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12,
    arg13, arg14, arg15, arg16, arg17, arg18,
  )
}

///|
pub fn lib__Module__pretty_print_defined_func(
  arg0 : @lib.Module,
  arg1 : UInt,
) -> String {
  ffi_lib_Module_pretty_print_defined_func(arg0, arg1)
}

///|
pub fn lib__Module__pretty_print_func(
  arg0 : @lib.Module,
  arg1 : @lib.FuncIdx,
) -> String {
  ffi_lib_Module_pretty_print_func(arg0, arg1)
}

///|
pub fn lib__Module__with_code_sec(
  arg0 : @lib.Module,
  arg1 : @lib.CodeSec,
) -> @lib.Module {
  ffi_lib_Module_with_code_sec(arg0, arg1)
}

///|
pub fn lib__Module__with_compiler_fact_custom_section(
  arg0 : @lib.Module,
  arg1 : @representation.CompilerFactCustomSection,
) -> @lib.Module {
  ffi_lib_Module_with_compiler_fact_custom_section(arg0, arg1)
}

///|
pub fn lib__Module__with_custom_secs(
  arg0 : @lib.Module,
  arg1 : Array[@lib.CustomSec],
) -> @lib.Module {
  ffi_lib_Module_with_custom_secs(arg0, arg1)
}

///|
pub fn lib__Module__with_data_cnt_sec(
  arg0 : @lib.Module,
  arg1 : @lib.DataCntSec,
) -> @lib.Module {
  ffi_lib_Module_with_data_cnt_sec(arg0, arg1)
}

///|
pub fn lib__Module__with_data_sec(
  arg0 : @lib.Module,
  arg1 : @lib.DataSec,
) -> @lib.Module {
  ffi_lib_Module_with_data_sec(arg0, arg1)
}

///|
pub fn lib__Module__with_elem_sec(
  arg0 : @lib.Module,
  arg1 : @lib.ElemSec,
) -> @lib.Module {
  ffi_lib_Module_with_elem_sec(arg0, arg1)
}

///|
pub fn lib__Module__with_export_sec(
  arg0 : @lib.Module,
  arg1 : @lib.ExportSec,
) -> @lib.Module {
  ffi_lib_Module_with_export_sec(arg0, arg1)
}

///|
pub fn lib__Module__with_func_annotation_sec(
  arg0 : @lib.Module,
  arg1 : @lib.FuncAnnotationSec,
) -> @lib.Module {
  ffi_lib_Module_with_func_annotation_sec(arg0, arg1)
}

///|
pub fn lib__Module__with_func_sec(
  arg0 : @lib.Module,
  arg1 : @lib.FuncSec,
) -> @lib.Module {
  ffi_lib_Module_with_func_sec(arg0, arg1)
}

///|
pub fn lib__Module__with_global_sec(
  arg0 : @lib.Module,
  arg1 : @lib.GlobalSec,
) -> @lib.Module {
  ffi_lib_Module_with_global_sec(arg0, arg1)
}

///|
pub fn lib__Module__with_import_sec(
  arg0 : @lib.Module,
  arg1 : @lib.ImportSec,
) -> @lib.Module {
  ffi_lib_Module_with_import_sec(arg0, arg1)
}

///|
pub fn lib__Module__with_mem_sec(
  arg0 : @lib.Module,
  arg1 : @lib.MemSec,
) -> @lib.Module {
  ffi_lib_Module_with_mem_sec(arg0, arg1)
}

///|
pub fn lib__Module__with_name_sec(
  arg0 : @lib.Module,
  arg1 : @lib.NameSec,
) -> @lib.Module {
  ffi_lib_Module_with_name_sec(arg0, arg1)
}

///|
pub fn lib__Module__with_raw_name_sec_payload(
  arg0 : @lib.Module,
  arg1 : Bytes,
) -> @lib.Module {
  ffi_lib_Module_with_raw_name_sec_payload(arg0, arg1)
}

///|
pub fn lib__Module__with_start_sec(
  arg0 : @lib.Module,
  arg1 : @lib.StartSec,
) -> @lib.Module {
  ffi_lib_Module_with_start_sec(arg0, arg1)
}

///|
pub fn lib__Module__with_stringrefs_sec(
  arg0 : @lib.Module,
  arg1 : @lib.StringRefsSec,
) -> @lib.Module {
  ffi_lib_Module_with_stringrefs_sec(arg0, arg1)
}

///|
pub fn lib__Module__with_table_sec(
  arg0 : @lib.Module,
  arg1 : @lib.TableSec,
) -> @lib.Module {
  ffi_lib_Module_with_table_sec(arg0, arg1)
}

///|
pub fn lib__Module__with_tag_sec(
  arg0 : @lib.Module,
  arg1 : @lib.TagSec,
) -> @lib.Module {
  ffi_lib_Module_with_tag_sec(arg0, arg1)
}

///|
pub fn lib__Module__with_type_sec(
  arg0 : @lib.Module,
  arg1 : @lib.TypeSec,
) -> @lib.Module {
  ffi_lib_Module_with_type_sec(arg0, arg1)
}

///|
pub fn lib__Module__without_compiler_fact_custom_section(
  arg0 : @lib.Module,
) -> @lib.Module {
  ffi_lib_Module_without_compiler_fact_custom_section(arg0)
}

///|
pub fn lib__Module__without_name_sec(arg0 : @lib.Module) -> @lib.Module {
  ffi_lib_Module_without_name_sec(arg0)
}

///|
pub fn lib__Mut__const_() -> @lib.Mut {
  ffi_lib_Mut_const_()
}

///|
pub fn lib__Mut__var_() -> @lib.Mut {
  ffi_lib_Mut_var_()
}

///|
pub fn lib__Name__from_string(arg0 : String) -> @lib.Name {
  ffi_lib_Name_from_string(arg0)
}

///|
pub fn lib__NameAssoc__new(arg0 : UInt, arg1 : @lib.Name) -> @lib.NameAssoc {
  ffi_lib_NameAssoc_new(arg0, arg1)
}

///|
pub fn lib__NameMap__new(arg0 : Array[@lib.NameAssoc]) -> @lib.NameMap {
  ffi_lib_NameMap_new(arg0)
}

///|
pub fn lib__NameSec__new(
  arg0 : @lib.Name??,
  arg1 : @lib.NameMap??,
  arg2 : @lib.IndirectNameMap??,
  arg3 : @lib.IndirectNameMap??,
  arg4 : @lib.NameMap??,
  arg5 : @lib.NameMap??,
  arg6 : @lib.NameMap??,
  arg7 : @lib.NameMap??,
  arg8 : @lib.NameMap??,
  arg9 : @lib.NameMap??,
  arg10 : @lib.IndirectNameMap??,
  arg11 : @lib.NameMap??,
) -> @lib.NameSec {
  ffi_lib_NameSec_new(
    arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11,
  )
}

///|
pub fn lib__NumType__f32() -> @lib.NumType {
  ffi_lib_NumType_f32()
}

///|
pub fn lib__NumType__f64() -> @lib.NumType {
  ffi_lib_NumType_f64()
}

///|
pub fn lib__NumType__i32() -> @lib.NumType {
  ffi_lib_NumType_i32()
}

///|
pub fn lib__NumType__i64() -> @lib.NumType {
  ffi_lib_NumType_i64()
}

///|
pub fn lib__PackType__i16() -> @lib.PackType {
  ffi_lib_PackType_i16()
}

///|
pub fn lib__PackType__i8() -> @lib.PackType {
  ffi_lib_PackType_i8()
}

///|
pub fn lib__PrettyPrintContext__indent(
  arg0 : @lib.PrettyPrintContext,
  arg1 : UInt,
) -> String {
  ffi_lib_PrettyPrintContext_indent(arg0, arg1)
}

///|
pub fn lib__PrettyPrintContext__indent_unit(
  arg0 : @lib.PrettyPrintContext,
) -> String {
  ffi_lib_PrettyPrintContext_indent_unit(arg0)
}

///|
pub fn lib__PrettyPrintContext__new(
  arg0 : UInt?,
  arg1 : @lib.TabsOrSpaces?,
  arg2 : UInt?,
  arg3 : UInt?,
  arg4 : UInt?,
) -> @lib.PrettyPrintContext {
  ffi_lib_PrettyPrintContext_new(arg0, arg1, arg2, arg3, arg4)
}

///|
pub fn lib__RecType__get_subtype(
  arg0 : @lib.RecType,
  arg1 : UInt,
) -> @lib.SubType? {
  ffi_lib_RecType_get_subtype(arg0, arg1)
}

///|
pub fn lib__RecType__group(arg0 : Array[@lib.SubType]) -> @lib.RecType {
  ffi_lib_RecType_group(arg0)
}

///|
pub fn lib__RecType__new(arg0 : @lib.SubType) -> @lib.RecType {
  ffi_lib_RecType_new(arg0)
}

///|
pub fn lib__RefType__abs(arg0 : @lib.AbsHeapType) -> @lib.RefType {
  ffi_lib_RefType_abs(arg0)
}

///|
pub fn lib__RefType__get_heap_type(arg0 : @lib.RefType) -> @lib.HeapType {
  ffi_lib_RefType_get_heap_type(arg0)
}

///|
pub fn lib__RefType__is_defaultable(arg0 : @lib.RefType) -> Bool {
  ffi_lib_RefType_is_defaultable(arg0)
}

///|
pub fn lib__RefType__is_exact(arg0 : @lib.RefType) -> Bool {
  ffi_lib_RefType_is_exact(arg0)
}

///|
pub fn lib__RefType__is_non_nullable(arg0 : @lib.RefType) -> Bool {
  ffi_lib_RefType_is_non_nullable(arg0)
}

///|
pub fn lib__RefType__is_nullable(arg0 : @lib.RefType) -> Bool {
  ffi_lib_RefType_is_nullable(arg0)
}

///|
pub fn lib__RefType__make_nullable(arg0 : @lib.RefType) -> @lib.RefType {
  ffi_lib_RefType_make_nullable(arg0)
}

///|
pub fn lib__RefType__new(
  arg0 : Bool,
  arg1 : @lib.HeapType,
  arg2 : Bool?,
) -> @lib.RefType {
  ffi_lib_RefType_new(arg0, arg1, arg2)
}

///|
pub fn lib__ReplaceLaneOp__f32x4_replace_lane() -> @lib.ReplaceLaneOp {
  ffi_lib_ReplaceLaneOp_f32x4_replace_lane()
}

///|
pub fn lib__ReplaceLaneOp__f64x2_replace_lane() -> @lib.ReplaceLaneOp {
  ffi_lib_ReplaceLaneOp_f64x2_replace_lane()
}

///|
pub fn lib__ReplaceLaneOp__i16x8_replace_lane() -> @lib.ReplaceLaneOp {
  ffi_lib_ReplaceLaneOp_i16x8_replace_lane()
}

///|
pub fn lib__ReplaceLaneOp__i32x4_replace_lane() -> @lib.ReplaceLaneOp {
  ffi_lib_ReplaceLaneOp_i32x4_replace_lane()
}

///|
pub fn lib__ReplaceLaneOp__i64x2_replace_lane() -> @lib.ReplaceLaneOp {
  ffi_lib_ReplaceLaneOp_i64x2_replace_lane()
}

///|
pub fn lib__ReplaceLaneOp__i8x16_replace_lane() -> @lib.ReplaceLaneOp {
  ffi_lib_ReplaceLaneOp_i8x16_replace_lane()
}

///|
pub fn lib__ResumeHandler__on_label(
  arg0 : @lib.TagIdx,
  arg1 : @lib.LabelIdx,
) -> @lib.ResumeHandler {
  ffi_lib_ResumeHandler_on_label(arg0, arg1)
}

///|
pub fn lib__ResumeHandler__on_switch(arg0 : @lib.TagIdx) -> @lib.ResumeHandler {
  ffi_lib_ResumeHandler_on_switch(arg0)
}

///|
pub fn lib__S33__new(arg0 : UInt) -> @lib.S33 {
  ffi_lib_S33_new(arg0)
}

///|
pub fn lib__StartSec__new(arg0 : @lib.FuncIdx) -> @lib.StartSec {
  ffi_lib_StartSec_new(arg0)
}

///|
pub fn lib__StorageType__is_packed(arg0 : @lib.StorageType) -> Bool {
  ffi_lib_StorageType_is_packed(arg0)
}

///|
pub fn lib__StorageType__pack_type(arg0 : @lib.PackType) -> @lib.StorageType {
  ffi_lib_StorageType_pack_type(arg0)
}

///|
pub fn lib__StorageType__unpack(arg0 : @lib.StorageType) -> @lib.ValType {
  ffi_lib_StorageType_unpack(arg0)
}

///|
pub fn lib__StorageType__val_type(arg0 : @lib.ValType) -> @lib.StorageType {
  ffi_lib_StorageType_val_type(arg0)
}

///|
pub fn lib__StoreOp__f32_store() -> @lib.StoreOp {
  ffi_lib_StoreOp_f32_store()
}

///|
pub fn lib__StoreOp__f64_store() -> @lib.StoreOp {
  ffi_lib_StoreOp_f64_store()
}

///|
pub fn lib__StoreOp__i32_atomic_store() -> @lib.StoreOp {
  ffi_lib_StoreOp_i32_atomic_store()
}

///|
pub fn lib__StoreOp__i32_atomic_store16() -> @lib.StoreOp {
  ffi_lib_StoreOp_i32_atomic_store16()
}

///|
pub fn lib__StoreOp__i32_atomic_store8() -> @lib.StoreOp {
  ffi_lib_StoreOp_i32_atomic_store8()
}

///|
pub fn lib__StoreOp__i32_store() -> @lib.StoreOp {
  ffi_lib_StoreOp_i32_store()
}

///|
pub fn lib__StoreOp__i32_store16() -> @lib.StoreOp {
  ffi_lib_StoreOp_i32_store16()
}

///|
pub fn lib__StoreOp__i32_store8() -> @lib.StoreOp {
  ffi_lib_StoreOp_i32_store8()
}

///|
pub fn lib__StoreOp__i64_atomic_store() -> @lib.StoreOp {
  ffi_lib_StoreOp_i64_atomic_store()
}

///|
pub fn lib__StoreOp__i64_atomic_store16() -> @lib.StoreOp {
  ffi_lib_StoreOp_i64_atomic_store16()
}

///|
pub fn lib__StoreOp__i64_atomic_store32() -> @lib.StoreOp {
  ffi_lib_StoreOp_i64_atomic_store32()
}

///|
pub fn lib__StoreOp__i64_atomic_store8() -> @lib.StoreOp {
  ffi_lib_StoreOp_i64_atomic_store8()
}

///|
pub fn lib__StoreOp__i64_store() -> @lib.StoreOp {
  ffi_lib_StoreOp_i64_store()
}

///|
pub fn lib__StoreOp__i64_store16() -> @lib.StoreOp {
  ffi_lib_StoreOp_i64_store16()
}

///|
pub fn lib__StoreOp__i64_store32() -> @lib.StoreOp {
  ffi_lib_StoreOp_i64_store32()
}

///|
pub fn lib__StoreOp__i64_store8() -> @lib.StoreOp {
  ffi_lib_StoreOp_i64_store8()
}

///|
pub fn lib__StoreOp__v128_store() -> @lib.StoreOp {
  ffi_lib_StoreOp_v128_store()
}

///|
pub fn lib__StringRefsSec__new(arg0 : Array[Bytes]) -> @lib.StringRefsSec {
  ffi_lib_StringRefsSec_new(arg0)
}

///|
pub fn lib__SubType__comp_type(
  arg0 : @lib.CompType,
  arg1 : @lib.TypeMetadata?,
) -> @lib.SubType {
  ffi_lib_SubType_comp_type(arg0, arg1)
}

///|
pub fn lib__SubType__describes_type(arg0 : @lib.SubType) -> @lib.TypeIdx? {
  ffi_lib_SubType_describes_type(arg0)
}

///|
pub fn lib__SubType__descriptor_type(arg0 : @lib.SubType) -> @lib.TypeIdx? {
  ffi_lib_SubType_descriptor_type(arg0)
}

///|
pub fn lib__SubType__get_comptype(arg0 : @lib.SubType) -> @lib.CompType {
  ffi_lib_SubType_get_comptype(arg0)
}

///|
pub fn lib__SubType__metadata(arg0 : @lib.SubType) -> @lib.TypeMetadata {
  ffi_lib_SubType_metadata(arg0)
}

///|
pub fn lib__SubType__new(
  arg0 : Bool,
  arg1 : Array[@lib.TypeIdx],
  arg2 : @lib.CompType,
  arg3 : @lib.TypeMetadata?,
) -> @lib.SubType {
  ffi_lib_SubType_new(arg0, arg1, arg2, arg3)
}

///|
pub fn lib__SubType__super_types(arg0 : @lib.SubType) -> Array[@lib.TypeIdx] {
  ffi_lib_SubType_super_types(arg0)
}

///|
pub fn lib__Table__new(arg0 : @lib.TableType, arg1 : @lib.Expr?) -> @lib.Table {
  ffi_lib_Table_new(arg0, arg1)
}

///|
pub fn lib__TableIdx__new(arg0 : UInt) -> @lib.TableIdx {
  ffi_lib_TableIdx_new(arg0)
}

///|
pub fn lib__TableSec__new(arg0 : Array[@lib.Table]) -> @lib.TableSec {
  ffi_lib_TableSec_new(arg0)
}

///|
pub fn lib__TableType__new(
  arg0 : @lib.RefType,
  arg1 : @lib.Limits,
) -> @lib.TableType {
  ffi_lib_TableType_new(arg0, arg1)
}

///|
pub fn lib__TabsOrSpaces__spaces() -> @lib.TabsOrSpaces {
  ffi_lib_TabsOrSpaces_spaces()
}

///|
pub fn lib__TabsOrSpaces__tabs() -> @lib.TabsOrSpaces {
  ffi_lib_TabsOrSpaces_tabs()
}

///|
pub fn lib__TagIdx__new(arg0 : UInt) -> @lib.TagIdx {
  ffi_lib_TagIdx_new(arg0)
}

///|
pub fn lib__TagSec__new(arg0 : Array[@lib.TagType]) -> @lib.TagSec {
  ffi_lib_TagSec_new(arg0)
}

///|
pub fn lib__TagType__new(arg0 : @lib.TypeIdx) -> @lib.TagType {
  ffi_lib_TagType_new(arg0)
}

///|
pub fn lib__TypeIdx__new(arg0 : UInt) -> @lib.TypeIdx {
  ffi_lib_TypeIdx_new(arg0)
}

///|
pub fn lib__TypeIdx__rec(arg0 : UInt) -> @lib.TypeIdx {
  ffi_lib_TypeIdx_rec(arg0)
}

///|
pub fn lib__TypeMetadata__is_shared(arg0 : @lib.TypeMetadata) -> Bool {
  ffi_lib_TypeMetadata_is_shared(arg0)
}

///|
pub fn lib__TypeMetadata__new(
  arg0 : @lib.TypeIdx??,
  arg1 : @lib.TypeIdx??,
  arg2 : Bool?,
) -> @lib.TypeMetadata {
  ffi_lib_TypeMetadata_new(arg0, arg1, arg2)
}

///|
pub fn lib__TypeMetadata__with_shared(
  arg0 : @lib.TypeMetadata,
  arg1 : Bool,
) -> @lib.TypeMetadata {
  ffi_lib_TypeMetadata_with_shared(arg0, arg1)
}

///|
pub fn lib__TypeSec__new(arg0 : Array[@lib.RecType]) -> @lib.TypeSec {
  ffi_lib_TypeSec_new(arg0)
}

///|
pub fn lib__U32__new(arg0 : UInt) -> @lib.U32 {
  ffi_lib_U32_new(arg0)
}

///|
pub fn lib__U64__new(arg0 : UInt64) -> @lib.U64 {
  ffi_lib_U64_new(arg0)
}

///|
pub fn lib__UnaryOp__f32_abs() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32_abs()
}

///|
pub fn lib__UnaryOp__f32_ceil() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32_ceil()
}

///|
pub fn lib__UnaryOp__f32_convert_i32s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32_convert_i32s()
}

///|
pub fn lib__UnaryOp__f32_convert_i32u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32_convert_i32u()
}

///|
pub fn lib__UnaryOp__f32_convert_i64s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32_convert_i64s()
}

///|
pub fn lib__UnaryOp__f32_convert_i64u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32_convert_i64u()
}

///|
pub fn lib__UnaryOp__f32_demote_f64() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32_demote_f64()
}

///|
pub fn lib__UnaryOp__f32_floor() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32_floor()
}

///|
pub fn lib__UnaryOp__f32_nearest() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32_nearest()
}

///|
pub fn lib__UnaryOp__f32_neg() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32_neg()
}

///|
pub fn lib__UnaryOp__f32_reinterpret_i32() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32_reinterpret_i32()
}

///|
pub fn lib__UnaryOp__f32_sqrt() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32_sqrt()
}

///|
pub fn lib__UnaryOp__f32_trunc() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32_trunc()
}

///|
pub fn lib__UnaryOp__f32x4_abs() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32x4_abs()
}

///|
pub fn lib__UnaryOp__f32x4_ceil() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32x4_ceil()
}

///|
pub fn lib__UnaryOp__f32x4_convert_i32x4s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32x4_convert_i32x4s()
}

///|
pub fn lib__UnaryOp__f32x4_convert_i32x4u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32x4_convert_i32x4u()
}

///|
pub fn lib__UnaryOp__f32x4_demote_f64x2_zero() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32x4_demote_f64x2_zero()
}

///|
pub fn lib__UnaryOp__f32x4_floor() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32x4_floor()
}

///|
pub fn lib__UnaryOp__f32x4_nearest() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32x4_nearest()
}

///|
pub fn lib__UnaryOp__f32x4_neg() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32x4_neg()
}

///|
pub fn lib__UnaryOp__f32x4_sqrt() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32x4_sqrt()
}

///|
pub fn lib__UnaryOp__f32x4_trunc() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f32x4_trunc()
}

///|
pub fn lib__UnaryOp__f64_abs() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64_abs()
}

///|
pub fn lib__UnaryOp__f64_ceil() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64_ceil()
}

///|
pub fn lib__UnaryOp__f64_convert_i32s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64_convert_i32s()
}

///|
pub fn lib__UnaryOp__f64_convert_i32u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64_convert_i32u()
}

///|
pub fn lib__UnaryOp__f64_convert_i64s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64_convert_i64s()
}

///|
pub fn lib__UnaryOp__f64_convert_i64u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64_convert_i64u()
}

///|
pub fn lib__UnaryOp__f64_floor() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64_floor()
}

///|
pub fn lib__UnaryOp__f64_nearest() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64_nearest()
}

///|
pub fn lib__UnaryOp__f64_neg() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64_neg()
}

///|
pub fn lib__UnaryOp__f64_promote_f32() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64_promote_f32()
}

///|
pub fn lib__UnaryOp__f64_reinterpret_i64() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64_reinterpret_i64()
}

///|
pub fn lib__UnaryOp__f64_sqrt() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64_sqrt()
}

///|
pub fn lib__UnaryOp__f64_trunc() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64_trunc()
}

///|
pub fn lib__UnaryOp__f64x2_abs() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64x2_abs()
}

///|
pub fn lib__UnaryOp__f64x2_ceil() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64x2_ceil()
}

///|
pub fn lib__UnaryOp__f64x2_convert_low_i32x4s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64x2_convert_low_i32x4s()
}

///|
pub fn lib__UnaryOp__f64x2_convert_low_i32x4u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64x2_convert_low_i32x4u()
}

///|
pub fn lib__UnaryOp__f64x2_floor() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64x2_floor()
}

///|
pub fn lib__UnaryOp__f64x2_nearest() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64x2_nearest()
}

///|
pub fn lib__UnaryOp__f64x2_neg() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64x2_neg()
}

///|
pub fn lib__UnaryOp__f64x2_promote_low_f32x4() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64x2_promote_low_f32x4()
}

///|
pub fn lib__UnaryOp__f64x2_sqrt() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64x2_sqrt()
}

///|
pub fn lib__UnaryOp__f64x2_trunc() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_f64x2_trunc()
}

///|
pub fn lib__UnaryOp__i16x8_abs() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i16x8_abs()
}

///|
pub fn lib__UnaryOp__i16x8_all_true() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i16x8_all_true()
}

///|
pub fn lib__UnaryOp__i16x8_bitmask() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i16x8_bitmask()
}

///|
pub fn lib__UnaryOp__i16x8_extadd_pairwise_i8x16s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i16x8_extadd_pairwise_i8x16s()
}

///|
pub fn lib__UnaryOp__i16x8_extadd_pairwise_i8x16u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i16x8_extadd_pairwise_i8x16u()
}

///|
pub fn lib__UnaryOp__i16x8_extend_high_i8x16s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i16x8_extend_high_i8x16s()
}

///|
pub fn lib__UnaryOp__i16x8_extend_high_i8x16u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i16x8_extend_high_i8x16u()
}

///|
pub fn lib__UnaryOp__i16x8_extend_low_i8x16s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i16x8_extend_low_i8x16s()
}

///|
pub fn lib__UnaryOp__i16x8_extend_low_i8x16u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i16x8_extend_low_i8x16u()
}

///|
pub fn lib__UnaryOp__i16x8_neg() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i16x8_neg()
}

///|
pub fn lib__UnaryOp__i32_clz() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32_clz()
}

///|
pub fn lib__UnaryOp__i32_ctz() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32_ctz()
}

///|
pub fn lib__UnaryOp__i32_eqz() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32_eqz()
}

///|
pub fn lib__UnaryOp__i32_extend16s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32_extend16s()
}

///|
pub fn lib__UnaryOp__i32_extend8s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32_extend8s()
}

///|
pub fn lib__UnaryOp__i32_popcnt() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32_popcnt()
}

///|
pub fn lib__UnaryOp__i32_reinterpret_f32() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32_reinterpret_f32()
}

///|
pub fn lib__UnaryOp__i32_trunc_f32s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32_trunc_f32s()
}

///|
pub fn lib__UnaryOp__i32_trunc_f32u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32_trunc_f32u()
}

///|
pub fn lib__UnaryOp__i32_trunc_f64s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32_trunc_f64s()
}

///|
pub fn lib__UnaryOp__i32_trunc_f64u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32_trunc_f64u()
}

///|
pub fn lib__UnaryOp__i32_trunc_sat_f32s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32_trunc_sat_f32s()
}

///|
pub fn lib__UnaryOp__i32_trunc_sat_f32u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32_trunc_sat_f32u()
}

///|
pub fn lib__UnaryOp__i32_trunc_sat_f64s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32_trunc_sat_f64s()
}

///|
pub fn lib__UnaryOp__i32_trunc_sat_f64u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32_trunc_sat_f64u()
}

///|
pub fn lib__UnaryOp__i32_wrap_i64() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32_wrap_i64()
}

///|
pub fn lib__UnaryOp__i32x4_abs() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32x4_abs()
}

///|
pub fn lib__UnaryOp__i32x4_all_true() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32x4_all_true()
}

///|
pub fn lib__UnaryOp__i32x4_bitmask() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32x4_bitmask()
}

///|
pub fn lib__UnaryOp__i32x4_extadd_pairwise_i16x8s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32x4_extadd_pairwise_i16x8s()
}

///|
pub fn lib__UnaryOp__i32x4_extadd_pairwise_i16x8u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32x4_extadd_pairwise_i16x8u()
}

///|
pub fn lib__UnaryOp__i32x4_extend_high_i16x8s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32x4_extend_high_i16x8s()
}

///|
pub fn lib__UnaryOp__i32x4_extend_high_i16x8u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32x4_extend_high_i16x8u()
}

///|
pub fn lib__UnaryOp__i32x4_extend_low_i16x8s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32x4_extend_low_i16x8s()
}

///|
pub fn lib__UnaryOp__i32x4_extend_low_i16x8u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32x4_extend_low_i16x8u()
}

///|
pub fn lib__UnaryOp__i32x4_neg() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32x4_neg()
}

///|
pub fn lib__UnaryOp__i32x4_relaxed_trunc_f32x4s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32x4_relaxed_trunc_f32x4s()
}

///|
pub fn lib__UnaryOp__i32x4_relaxed_trunc_f32x4u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32x4_relaxed_trunc_f32x4u()
}

///|
pub fn lib__UnaryOp__i32x4_relaxed_trunc_zero_f64x2s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32x4_relaxed_trunc_zero_f64x2s()
}

///|
pub fn lib__UnaryOp__i32x4_relaxed_trunc_zero_f64x2u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32x4_relaxed_trunc_zero_f64x2u()
}

///|
pub fn lib__UnaryOp__i32x4_trunc_sat_f32x4s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32x4_trunc_sat_f32x4s()
}

///|
pub fn lib__UnaryOp__i32x4_trunc_sat_f32x4u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32x4_trunc_sat_f32x4u()
}

///|
pub fn lib__UnaryOp__i32x4_trunc_sat_f64x2s_zero() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32x4_trunc_sat_f64x2s_zero()
}

///|
pub fn lib__UnaryOp__i32x4_trunc_sat_f64x2u_zero() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i32x4_trunc_sat_f64x2u_zero()
}

///|
pub fn lib__UnaryOp__i64_clz() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64_clz()
}

///|
pub fn lib__UnaryOp__i64_ctz() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64_ctz()
}

///|
pub fn lib__UnaryOp__i64_eqz() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64_eqz()
}

///|
pub fn lib__UnaryOp__i64_extend16s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64_extend16s()
}

///|
pub fn lib__UnaryOp__i64_extend32s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64_extend32s()
}

///|
pub fn lib__UnaryOp__i64_extend8s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64_extend8s()
}

///|
pub fn lib__UnaryOp__i64_extend_i32s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64_extend_i32s()
}

///|
pub fn lib__UnaryOp__i64_extend_i32u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64_extend_i32u()
}

///|
pub fn lib__UnaryOp__i64_popcnt() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64_popcnt()
}

///|
pub fn lib__UnaryOp__i64_reinterpret_f64() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64_reinterpret_f64()
}

///|
pub fn lib__UnaryOp__i64_trunc_f32s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64_trunc_f32s()
}

///|
pub fn lib__UnaryOp__i64_trunc_f32u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64_trunc_f32u()
}

///|
pub fn lib__UnaryOp__i64_trunc_f64s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64_trunc_f64s()
}

///|
pub fn lib__UnaryOp__i64_trunc_f64u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64_trunc_f64u()
}

///|
pub fn lib__UnaryOp__i64_trunc_sat_f32s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64_trunc_sat_f32s()
}

///|
pub fn lib__UnaryOp__i64_trunc_sat_f32u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64_trunc_sat_f32u()
}

///|
pub fn lib__UnaryOp__i64_trunc_sat_f64s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64_trunc_sat_f64s()
}

///|
pub fn lib__UnaryOp__i64_trunc_sat_f64u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64_trunc_sat_f64u()
}

///|
pub fn lib__UnaryOp__i64x2_abs() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64x2_abs()
}

///|
pub fn lib__UnaryOp__i64x2_all_true() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64x2_all_true()
}

///|
pub fn lib__UnaryOp__i64x2_bitmask() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64x2_bitmask()
}

///|
pub fn lib__UnaryOp__i64x2_extend_high_i32x4s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64x2_extend_high_i32x4s()
}

///|
pub fn lib__UnaryOp__i64x2_extend_high_i32x4u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64x2_extend_high_i32x4u()
}

///|
pub fn lib__UnaryOp__i64x2_extend_low_i32x4s() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64x2_extend_low_i32x4s()
}

///|
pub fn lib__UnaryOp__i64x2_extend_low_i32x4u() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64x2_extend_low_i32x4u()
}

///|
pub fn lib__UnaryOp__i64x2_neg() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i64x2_neg()
}

///|
pub fn lib__UnaryOp__i8x16_abs() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i8x16_abs()
}

///|
pub fn lib__UnaryOp__i8x16_all_true() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i8x16_all_true()
}

///|
pub fn lib__UnaryOp__i8x16_bitmask() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i8x16_bitmask()
}

///|
pub fn lib__UnaryOp__i8x16_neg() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i8x16_neg()
}

///|
pub fn lib__UnaryOp__i8x16_popcnt() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_i8x16_popcnt()
}

///|
pub fn lib__UnaryOp__v128_any_true() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_v128_any_true()
}

///|
pub fn lib__UnaryOp__v128_not() -> @lib.UnaryOp {
  ffi_lib_UnaryOp_v128_not()
}

///|
pub fn lib__V128LoadLaneOp__v128_load16_lane() -> @lib.V128LoadLaneOp {
  ffi_lib_V128LoadLaneOp_v128_load16_lane()
}

///|
pub fn lib__V128LoadLaneOp__v128_load32_lane() -> @lib.V128LoadLaneOp {
  ffi_lib_V128LoadLaneOp_v128_load32_lane()
}

///|
pub fn lib__V128LoadLaneOp__v128_load64_lane() -> @lib.V128LoadLaneOp {
  ffi_lib_V128LoadLaneOp_v128_load64_lane()
}

///|
pub fn lib__V128LoadLaneOp__v128_load8_lane() -> @lib.V128LoadLaneOp {
  ffi_lib_V128LoadLaneOp_v128_load8_lane()
}

///|
pub fn lib__V128ShiftOp__i16x8_shl() -> @lib.V128ShiftOp {
  ffi_lib_V128ShiftOp_i16x8_shl()
}

///|
pub fn lib__V128ShiftOp__i16x8_shr_s() -> @lib.V128ShiftOp {
  ffi_lib_V128ShiftOp_i16x8_shr_s()
}

///|
pub fn lib__V128ShiftOp__i16x8_shr_u() -> @lib.V128ShiftOp {
  ffi_lib_V128ShiftOp_i16x8_shr_u()
}

///|
pub fn lib__V128ShiftOp__i32x4_shl() -> @lib.V128ShiftOp {
  ffi_lib_V128ShiftOp_i32x4_shl()
}

///|
pub fn lib__V128ShiftOp__i32x4_shr_s() -> @lib.V128ShiftOp {
  ffi_lib_V128ShiftOp_i32x4_shr_s()
}

///|
pub fn lib__V128ShiftOp__i32x4_shr_u() -> @lib.V128ShiftOp {
  ffi_lib_V128ShiftOp_i32x4_shr_u()
}

///|
pub fn lib__V128ShiftOp__i64x2_shl() -> @lib.V128ShiftOp {
  ffi_lib_V128ShiftOp_i64x2_shl()
}

///|
pub fn lib__V128ShiftOp__i64x2_shr_s() -> @lib.V128ShiftOp {
  ffi_lib_V128ShiftOp_i64x2_shr_s()
}

///|
pub fn lib__V128ShiftOp__i64x2_shr_u() -> @lib.V128ShiftOp {
  ffi_lib_V128ShiftOp_i64x2_shr_u()
}

///|
pub fn lib__V128ShiftOp__i8x16_shl() -> @lib.V128ShiftOp {
  ffi_lib_V128ShiftOp_i8x16_shl()
}

///|
pub fn lib__V128ShiftOp__i8x16_shr_s() -> @lib.V128ShiftOp {
  ffi_lib_V128ShiftOp_i8x16_shr_s()
}

///|
pub fn lib__V128ShiftOp__i8x16_shr_u() -> @lib.V128ShiftOp {
  ffi_lib_V128ShiftOp_i8x16_shr_u()
}

///|
pub fn lib__V128StoreLaneOp__v128_store16_lane() -> @lib.V128StoreLaneOp {
  ffi_lib_V128StoreLaneOp_v128_store16_lane()
}

///|
pub fn lib__V128StoreLaneOp__v128_store32_lane() -> @lib.V128StoreLaneOp {
  ffi_lib_V128StoreLaneOp_v128_store32_lane()
}

///|
pub fn lib__V128StoreLaneOp__v128_store64_lane() -> @lib.V128StoreLaneOp {
  ffi_lib_V128StoreLaneOp_v128_store64_lane()
}

///|
pub fn lib__V128StoreLaneOp__v128_store8_lane() -> @lib.V128StoreLaneOp {
  ffi_lib_V128StoreLaneOp_v128_store8_lane()
}

///|
pub fn lib__V128TernaryOp__f32x4_relaxed_madd() -> @lib.V128TernaryOp {
  ffi_lib_V128TernaryOp_f32x4_relaxed_madd()
}

///|
pub fn lib__V128TernaryOp__f32x4_relaxed_nmadd() -> @lib.V128TernaryOp {
  ffi_lib_V128TernaryOp_f32x4_relaxed_nmadd()
}

///|
pub fn lib__V128TernaryOp__f64x2_relaxed_madd() -> @lib.V128TernaryOp {
  ffi_lib_V128TernaryOp_f64x2_relaxed_madd()
}

///|
pub fn lib__V128TernaryOp__f64x2_relaxed_nmadd() -> @lib.V128TernaryOp {
  ffi_lib_V128TernaryOp_f64x2_relaxed_nmadd()
}

///|
pub fn lib__V128TernaryOp__i16x8_relaxed_laneselect() -> @lib.V128TernaryOp {
  ffi_lib_V128TernaryOp_i16x8_relaxed_laneselect()
}

///|
pub fn lib__V128TernaryOp__i32x4_relaxed_dot_i8x16i7x16_add_s() -> @lib.V128TernaryOp {
  ffi_lib_V128TernaryOp_i32x4_relaxed_dot_i8x16i7x16_add_s()
}

///|
pub fn lib__V128TernaryOp__i32x4_relaxed_laneselect() -> @lib.V128TernaryOp {
  ffi_lib_V128TernaryOp_i32x4_relaxed_laneselect()
}

///|
pub fn lib__V128TernaryOp__i64x2_relaxed_laneselect() -> @lib.V128TernaryOp {
  ffi_lib_V128TernaryOp_i64x2_relaxed_laneselect()
}

///|
pub fn lib__V128TernaryOp__i8x16_relaxed_laneselect() -> @lib.V128TernaryOp {
  ffi_lib_V128TernaryOp_i8x16_relaxed_laneselect()
}

///|
pub fn lib__V128TernaryOp__v128_bitselect() -> @lib.V128TernaryOp {
  ffi_lib_V128TernaryOp_v128_bitselect()
}

///|
pub fn lib__ValType__anyref() -> @lib.ValType {
  ffi_lib_ValType_anyref()
}

///|
pub fn lib__ValType__bottom() -> @lib.ValType {
  ffi_lib_ValType_bottom()
}

///|
pub fn lib__ValType__eqref_null() -> @lib.ValType {
  ffi_lib_ValType_eqref_null()
}

///|
pub fn lib__ValType__externref() -> @lib.ValType {
  ffi_lib_ValType_externref()
}

///|
pub fn lib__ValType__f32() -> @lib.ValType {
  ffi_lib_ValType_f32()
}

///|
pub fn lib__ValType__f64() -> @lib.ValType {
  ffi_lib_ValType_f64()
}

///|
pub fn lib__ValType__funcref() -> @lib.ValType {
  ffi_lib_ValType_funcref()
}

///|
pub fn lib__ValType__i31ref() -> @lib.ValType {
  ffi_lib_ValType_i31ref()
}

///|
pub fn lib__ValType__i31ref_nullable() -> @lib.ValType {
  ffi_lib_ValType_i31ref_nullable()
}

///|
pub fn lib__ValType__i32() -> @lib.ValType {
  ffi_lib_ValType_i32()
}

///|
pub fn lib__ValType__i64() -> @lib.ValType {
  ffi_lib_ValType_i64()
}

///|
pub fn lib__ValType__is_ref_type(arg0 : @lib.ValType) -> Bool {
  ffi_lib_ValType_is_ref_type(arg0)
}

///|
pub fn lib__ValType__num_type(arg0 : @lib.NumType) -> @lib.ValType {
  ffi_lib_ValType_num_type(arg0)
}

///|
pub fn lib__ValType__ref_array_nonnull(arg0 : @lib.TypeIdx) -> @lib.ValType {
  ffi_lib_ValType_ref_array_nonnull(arg0)
}

///|
pub fn lib__ValType__ref_array_nullable(arg0 : @lib.TypeIdx) -> @lib.ValType {
  ffi_lib_ValType_ref_array_nullable(arg0)
}

///|
pub fn lib__ValType__ref_null(arg0 : @lib.HeapType) -> @lib.ValType {
  ffi_lib_ValType_ref_null(arg0)
}

///|
pub fn lib__ValType__ref_null_array_of(arg0 : @lib.TypeIdx) -> @lib.ValType {
  ffi_lib_ValType_ref_null_array_of(arg0)
}

///|
pub fn lib__ValType__ref_null_exn() -> @lib.ValType {
  ffi_lib_ValType_ref_null_exn()
}

///|
pub fn lib__ValType__ref_null_type(arg0 : @lib.RefType) -> @lib.ValType {
  ffi_lib_ValType_ref_null_type(arg0)
}

///|
pub fn lib__ValType__ref_type(arg0 : @lib.RefType) -> @lib.ValType {
  ffi_lib_ValType_ref_type(arg0)
}

///|
pub fn lib__ValType__stringref() -> @lib.ValType {
  ffi_lib_ValType_stringref()
}

///|
pub fn lib__ValType__v128() -> @lib.ValType {
  ffi_lib_ValType_v128()
}

///|
pub fn validate__apply_validate_invalid_ast_strategy(
  arg0 : @validate.ValidateInvalidAstStrategyId,
  arg1 : @lib.Module,
) -> Result[@validate.ValidateInvalidAstMutation, String] {
  ffi_validate_apply_validate_invalid_ast_strategy(arg0, arg1)
}

///|
pub fn validate__build_validate_invalid_ast_minimal_repro(
  arg0 : @validate.ValidateInvalidAstStrategyId,
) -> Result[@lib.Module, String] {
  ffi_validate_build_validate_invalid_ast_minimal_repro(arg0)
}

///|
pub fn validate__build_validate_invalid_ast_minimal_repro_by_stable_id(
  arg0 : String,
) -> Result[@lib.Module, String] {
  ffi_validate_build_validate_invalid_ast_minimal_repro_by_stable_id(arg0)
}

///|
pub fn validate__check_validate_valid_feature_floors(
  arg0 : @validate.GenValidFeatureStats,
  arg1 : Array[@validate.ValidateValidFeatureFloor],
) -> Array[@validate.ValidateValidFeatureFloorFailure] {
  ffi_validate_check_validate_valid_feature_floors(arg0, arg1)
}

///|
pub fn validate__controlled_proposal_features() -> Array[
  @validate.ProposalFeature,
] {
  ffi_validate_controlled_proposal_features()
}

///|
pub fn validate__default_gen_valid_config() -> @validate.GenValidConfig {
  ffi_validate_default_gen_valid_config()
}

///|
pub fn validate__descriptor_compatible(
  arg0 : @lib.RefType,
  arg1 : @lib.RefType,
  arg2 : @validate.Env,
) -> Bool {
  ffi_validate_descriptor_compatible(arg0, arg1, arg2)
}

///|
pub fn validate__diff(
  arg0 : @lib.RefType,
  arg1 : @lib.RefType,
) -> Result[@lib.RefType, String] {
  ffi_validate_diff(arg0, arg1)
}

///|
pub fn validate__empty_env() -> @validate.Env {
  ffi_validate_empty_env()
}

///|
pub fn validate__gen_invalid_ast_generate(
  arg0 : @splitmix.RandomState,
  arg1 : @validate.GenInvalidAstParams,
) -> Result[@validate.GenInvalidAstGenerated, String] {
  ffi_validate_gen_invalid_ast_generate(arg0, arg1)
}

///|
pub fn validate__gen_invalid_ast_generate_from_seed(
  arg0 : UInt64,
  arg1 : @validate.GenInvalidAstParams,
) -> Result[@validate.GenInvalidAstGenerated, String] {
  ffi_validate_gen_invalid_ast_generate_from_seed(arg0, arg1)
}

///|
pub fn validate__gen_invalid_ast_params_profile_name(
  arg0 : @validate.GenInvalidAstParams,
) -> String {
  ffi_validate_gen_invalid_ast_params_profile_name(arg0)
}

///|
pub fn validate__gen_invalid_ast_seed_config(
  arg0 : @validate.GenInvalidAstParams,
) -> @validate.GenValidConfig {
  ffi_validate_gen_invalid_ast_seed_config(arg0)
}

///|
pub fn validate__gen_invalid_ast_seed_module(
  arg0 : @splitmix.RandomState,
  arg1 : @validate.GenInvalidAstParams,
) -> Result[@lib.Module, String] {
  ffi_validate_gen_invalid_ast_seed_module(arg0, arg1)
}

///|
pub fn validate__gen_invalid_ast_strategy_seed_prerequisites(
  arg0 : @validate.ValidateInvalidAstStrategyId,
) -> Array[@validate.ValidateInvalidAstSeedPrerequisite] {
  ffi_validate_gen_invalid_ast_strategy_seed_prerequisites(arg0)
}

///|
pub fn validate__gen_invalid_coverage_seed_generator_config() -> @validate.GenValidConfig {
  ffi_validate_gen_invalid_coverage_seed_generator_config()
}

///|
pub fn validate__gen_invalid_named_seed_profile_name(
  arg0 : @validate.GenInvalidNamedSeedProfile,
) -> String {
  ffi_validate_gen_invalid_named_seed_profile_name(arg0)
}

///|
pub fn validate__gen_invalid_require_defined_func_gen_valid_config(
  arg0 : @validate.GenValidConfig,
) -> @validate.GenValidConfig {
  ffi_validate_gen_invalid_require_defined_func_gen_valid_config(arg0)
}

///|
pub fn validate__gen_invalid_require_memory_data_gen_valid_config(
  arg0 : @validate.GenValidConfig,
) -> @validate.GenValidConfig {
  ffi_validate_gen_invalid_require_memory_data_gen_valid_config(arg0)
}

///|
pub fn validate__gen_invalid_seed_mode_name(
  arg0 : @validate.GenInvalidSeedMode,
) -> String {
  ffi_validate_gen_invalid_seed_mode_name(arg0)
}

///|
pub fn validate__gen_invalid_small_gen_valid_config(
  arg0 : @validate.GenValidConfig,
) -> @validate.GenValidConfig {
  ffi_validate_gen_invalid_small_gen_valid_config(arg0)
}

///|
pub fn validate__gen_valid_case_seed(arg0 : UInt64, arg1 : Int) -> UInt64 {
  ffi_validate_gen_valid_case_seed(arg0, arg1)
}

///|
pub fn validate__gen_valid_code_folding_profile_case_label(
  arg0 : @validate.GenValidProfile,
  arg1 : UInt64,
) -> String? {
  ffi_validate_gen_valid_code_folding_profile_case_label(arg0, arg1)
}

///|
pub fn validate__gen_valid_config_label(
  arg0 : @validate.GenValidConfig,
) -> String {
  ffi_validate_gen_valid_config_label(arg0)
}

///|
pub fn validate__gen_valid_const_expr_allowed_op_matrix() -> Array[
  @validate.GenValidConstExprAllowedOps,
] {
  ffi_validate_gen_valid_const_expr_allowed_op_matrix()
}

///|
pub fn validate__gen_valid_const_expr_observed_op_matrix(
  arg0 : @lib.Module,
) -> Array[@validate.GenValidConstExprObservedOps] {
  ffi_validate_gen_valid_const_expr_observed_op_matrix(arg0)
}

///|
pub fn validate__gen_valid_coverage_template_signature(
  arg0 : @lib.Module,
) -> String {
  ffi_validate_gen_valid_coverage_template_signature(arg0)
}

///|
pub fn validate__gen_valid_dae_optimizing_profile_case_label(
  arg0 : @validate.GenValidProfile,
  arg1 : UInt64,
) -> String? {
  ffi_validate_gen_valid_dae_optimizing_profile_case_label(arg0, arg1)
}

///|
pub fn validate__gen_valid_dead_argument_elimination_profile_config(
  arg0 : @validate.GenValidProfile,
) -> @validate.GenValidConfig {
  ffi_validate_gen_valid_dead_argument_elimination_profile_config(arg0)
}

///|
pub fn validate__gen_valid_derive_stream_seed(
  arg0 : UInt64,
  arg1 : @validate.GenValidRandomStreamLabel,
) -> UInt64 {
  ffi_validate_gen_valid_derive_stream_seed(arg0, arg1)
}

///|
pub fn validate__gen_valid_directize_profile_case_label(
  arg0 : @validate.GenValidProfile,
  arg1 : UInt64,
) -> String? {
  ffi_validate_gen_valid_directize_profile_case_label(arg0, arg1)
}

///|
pub fn validate__gen_valid_duplicate_import_elimination_profile_case_label(
  arg0 : @validate.GenValidProfile,
  arg1 : UInt64,
) -> String? {
  ffi_validate_gen_valid_duplicate_import_elimination_profile_case_label(
    arg0, arg1,
  )
}

///|
pub fn validate__gen_valid_engine_state_cross_instance_support_module(
  arg0 : UInt64,
) -> @lib.Module {
  ffi_validate_gen_valid_engine_state_cross_instance_support_module(arg0)
}

///|
pub fn validate__gen_valid_engine_state_failure_family(
  arg0 : @validate.GenValidProfile,
  arg1 : UInt64,
) -> String {
  ffi_validate_gen_valid_engine_state_failure_family(arg0, arg1)
}

///|
pub fn validate__gen_valid_engine_state_indirect_trap_family(
  arg0 : UInt64,
) -> String {
  ffi_validate_gen_valid_engine_state_indirect_trap_family(arg0)
}

///|
pub fn validate__gen_valid_engine_state_instantiation_failure_family(
  arg0 : UInt64,
) -> String {
  ffi_validate_gen_valid_engine_state_instantiation_failure_family(arg0)
}

///|
pub fn validate__gen_valid_engine_state_invalid_module_family(
  arg0 : UInt64,
) -> String {
  ffi_validate_gen_valid_engine_state_invalid_module_family(arg0)
}

///|
pub fn validate__gen_valid_engine_state_link_graph_support_modules(
  arg0 : UInt64,
) -> Array[@lib.Module] {
  ffi_validate_gen_valid_engine_state_link_graph_support_modules(arg0)
}

///|
pub fn validate__gen_valid_engine_state_metamorphic_comparison_module(
  arg0 : UInt64,
) -> @lib.Module {
  ffi_validate_gen_valid_engine_state_metamorphic_comparison_module(arg0)
}

///|
pub fn validate__gen_valid_engine_state_outcome(
  arg0 : @validate.GenValidProfile,
) -> String {
  ffi_validate_gen_valid_engine_state_outcome(arg0)
}

///|
pub fn validate__gen_valid_engine_state_profile() -> @validate.GenValidProfile {
  ffi_validate_gen_valid_engine_state_profile()
}

///|
pub fn validate__gen_valid_engine_state_static_instruction_count(
  arg0 : @lib.Module,
) -> Int {
  ffi_validate_gen_valid_engine_state_static_instruction_count(arg0)
}

///|
pub fn validate__gen_valid_engine_state_trap_commit_family(
  arg0 : UInt64,
) -> String {
  ffi_validate_gen_valid_engine_state_trap_commit_family(arg0)
}

///|
pub fn validate__gen_valid_engine_state_trap_family(arg0 : UInt64) -> String {
  ffi_validate_gen_valid_engine_state_trap_family(arg0)
}

///|
pub fn validate__gen_valid_engine_tiering_profile_case_label(
  arg0 : @validate.GenValidProfile,
  arg1 : UInt64,
) -> String? {
  ffi_validate_gen_valid_engine_tiering_profile_case_label(arg0, arg1)
}

///|
pub fn validate__gen_valid_feature_facts(
  arg0 : @lib.Module,
  arg1 : @validate.GenValidMode,
) -> @validate.GenValidFeatureFacts {
  ffi_validate_gen_valid_feature_facts(arg0, arg1)
}

///|
pub fn validate__gen_valid_flatten_profile_case_label(
  arg0 : @validate.GenValidProfile,
  arg1 : UInt64,
) -> String? {
  ffi_validate_gen_valid_flatten_profile_case_label(arg0, arg1)
}

///|
pub fn validate__gen_valid_heap_store_optimization_profile_case_label(
  arg0 : @validate.GenValidProfile,
) -> String? {
  ffi_validate_gen_valid_heap_store_optimization_profile_case_label(arg0)
}

///|
pub fn validate__gen_valid_inlining_optimizing_profile_case_label(
  arg0 : @validate.GenValidProfile,
  arg1 : UInt64,
) -> String? {
  ffi_validate_gen_valid_inlining_optimizing_profile_case_label(arg0, arg1)
}

///|
pub fn validate__gen_valid_memory_packing_profile_case_label(
  arg0 : @validate.GenValidProfile,
) -> String? {
  ffi_validate_gen_valid_memory_packing_profile_case_label(arg0)
}

///|
pub fn validate__gen_valid_merge_blocks_profile_case_label(
  arg0 : @validate.GenValidProfile,
  arg1 : UInt64,
) -> String? {
  ffi_validate_gen_valid_merge_blocks_profile_case_label(arg0, arg1)
}

///|
pub fn validate__gen_valid_merge_locals_profile_case_label(
  arg0 : @validate.GenValidProfile,
  arg1 : UInt64,
) -> String? {
  ffi_validate_gen_valid_merge_locals_profile_case_label(arg0, arg1)
}

///|
pub fn validate__gen_valid_merge_ssa_func_facts(
  arg0 : @validate.GenValidSsaFuncFacts,
  arg1 : @validate.GenValidSsaFuncFacts,
) -> @validate.GenValidSsaFuncFacts {
  ffi_validate_gen_valid_merge_ssa_func_facts(arg0, arg1)
}

///|
pub fn validate__gen_valid_module(arg0 : @splitmix.RandomState) -> @lib.Module {
  ffi_validate_gen_valid_module(arg0)
}

///|
pub fn validate__gen_valid_module_from_seed(
  arg0 : UInt64,
  arg1 : @validate.GenValidConfig,
) -> Result[@validate.GenValidModuleGenerated, @validate.GenValidFailure] {
  ffi_validate_gen_valid_module_from_seed(arg0, arg1)
}

///|
pub fn validate__gen_valid_module_result(
  arg0 : @splitmix.RandomState,
  arg1 : @validate.GenValidConfig,
) -> Result[@validate.GenValidGenerated, @validate.GenValidFailure] {
  ffi_validate_gen_valid_module_result(arg0, arg1)
}

///|
pub fn validate__gen_valid_module_result_from_seed(
  arg0 : UInt64,
  arg1 : @validate.GenValidConfig,
) -> Result[@validate.GenValidGenerated, @validate.GenValidFailure] {
  ffi_validate_gen_valid_module_result_from_seed(arg0, arg1)
}

///|
pub fn validate__gen_valid_module_with_config(
  arg0 : @splitmix.RandomState,
  arg1 : @validate.GenValidConfig,
) -> @lib.Module {
  ffi_validate_gen_valid_module_with_config(arg0, arg1)
}

///|
pub fn validate__gen_valid_msf_profile_case_label(
  arg0 : @validate.GenValidProfile,
  arg1 : UInt64,
) -> String? {
  ffi_validate_gen_valid_msf_profile_case_label(arg0, arg1)
}

///|
pub fn validate__gen_valid_oi_trigger_profile_case_for_seed(
  arg0 : UInt64,
) -> Int {
  ffi_validate_gen_valid_oi_trigger_profile_case_for_seed(arg0)
}

///|
pub fn validate__gen_valid_oi_trigger_profile_case_label(
  arg0 : @validate.GenValidProfile,
  arg1 : UInt64,
) -> String? {
  ffi_validate_gen_valid_oi_trigger_profile_case_label(arg0, arg1)
}

///|
pub fn validate__gen_valid_profile_by_name(
  arg0 : String,
) -> Result[@validate.GenValidProfile, String] {
  ffi_validate_gen_valid_profile_by_name(arg0)
}

///|
pub fn validate__gen_valid_profile_is_composite(
  arg0 : @validate.GenValidProfile,
) -> Bool {
  ffi_validate_gen_valid_profile_is_composite(arg0)
}

///|
pub fn validate__gen_valid_profile_leaf_for_case(
  arg0 : @validate.GenValidProfile,
  arg1 : UInt64,
  arg2 : Int,
) -> @validate.GenValidProfile {
  ffi_validate_gen_valid_profile_leaf_for_case(arg0, arg1, arg2)
}

///|
pub fn validate__gen_valid_profile_members(
  arg0 : @validate.GenValidProfile,
) -> Array[@validate.GenValidProfileMember] {
  ffi_validate_gen_valid_profile_members(arg0)
}

///|
pub fn validate__gen_valid_profile_name(
  arg0 : @validate.GenValidProfile,
) -> String {
  ffi_validate_gen_valid_profile_name(arg0)
}

///|
pub fn validate__gen_valid_profile_names() -> Array[String] {
  ffi_validate_gen_valid_profile_names()
}

///|
pub fn validate__gen_valid_profiles() -> Array[@validate.GenValidProfile] {
  ffi_validate_gen_valid_profiles()
}

///|
pub fn validate__gen_valid_proposal_feature_enabled(
  arg0 : @validate.GenValidFeatureToggles,
  arg1 : @validate.GenValidProposalFeature,
) -> Bool {
  ffi_validate_gen_valid_proposal_feature_enabled(arg0, arg1)
}

///|
pub fn validate__gen_valid_proposal_feature_gate_matrix() -> Array[
  @validate.GenValidProposalFeatureGateRow,
] {
  ffi_validate_gen_valid_proposal_feature_gate_matrix()
}

///|
pub fn validate__gen_valid_proposal_feature_label(
  arg0 : @validate.GenValidProposalFeature,
) -> String {
  ffi_validate_gen_valid_proposal_feature_label(arg0)
}

///|
pub fn validate__gen_valid_proposal_features() -> Array[
  @validate.GenValidProposalFeature,
] {
  ffi_validate_gen_valid_proposal_features()
}

///|
pub fn validate__gen_valid_random_stream_label_name(
  arg0 : @validate.GenValidRandomStreamLabel,
) -> String {
  ffi_validate_gen_valid_random_stream_label_name(arg0)
}

///|
pub fn validate__gen_valid_random_stream_labels() -> Array[
  @validate.GenValidRandomStreamLabel,
] {
  ffi_validate_gen_valid_random_stream_labels()
}

///|
pub fn validate__gen_valid_reorder_globals_profile_case_label(
  arg0 : @validate.GenValidProfile,
  arg1 : UInt64,
) -> String? {
  ffi_validate_gen_valid_reorder_globals_profile_case_label(arg0, arg1)
}

///|
pub fn validate__gen_valid_rume_profile_case_label(
  arg0 : @validate.GenValidProfile,
  arg1 : UInt64,
) -> String? {
  ffi_validate_gen_valid_rume_profile_case_label(arg0, arg1)
}

///|
pub fn validate__gen_valid_scan_func_ssa_facts(
  arg0 : Int,
  arg1 : @lib.Locals,
  arg2 : @lib.Expr,
) -> @validate.GenValidSsaFuncFacts {
  ffi_validate_gen_valid_scan_func_ssa_facts(arg0, arg1, arg2)
}

///|
pub fn validate__gen_valid_ssa_full_profile_case_label(
  arg0 : @validate.GenValidProfile,
) -> String? {
  ffi_validate_gen_valid_ssa_full_profile_case_label(arg0)
}

///|
pub fn validate__gen_valid_stream_random_state(
  arg0 : UInt64,
  arg1 : @validate.GenValidRandomStreamLabel,
) -> @splitmix.RandomState {
  ffi_validate_gen_valid_stream_random_state(arg0, arg1)
}

///|
pub fn validate__gen_valid_tuple_optimization_trigger_profile_case_label(
  arg0 : @validate.GenValidProfile,
  arg1 : UInt64,
) -> String? {
  ffi_validate_gen_valid_tuple_optimization_trigger_profile_case_label(
    arg0, arg1,
  )
}

///|
pub fn validate__gen_valid_undersampled_pass_profile_case_label(
  arg0 : @validate.GenValidProfile,
  arg1 : UInt64,
) -> String? {
  ffi_validate_gen_valid_undersampled_pass_profile_case_label(arg0, arg1)
}

///|
pub fn validate__make_state(
  arg0 : @validate.Env,
  arg1 : Array[@lib.ValType],
) -> @validate.TcState {
  ffi_validate_make_state(arg0, arg1)
}

///|
pub fn validate__make_state_owned(
  arg0 : @validate.Env,
  arg1 : Array[@lib.ValType],
) -> @validate.TcState {
  ffi_validate_make_state_owned(arg0, arg1)
}

///|
pub fn validate__module_proposal_features(
  arg0 : @lib.Module,
) -> Array[@validate.ProposalFeature] {
  ffi_validate_module_proposal_features(arg0)
}

///|
pub fn validate__proposal_feature_by_name(
  arg0 : String,
) -> @validate.ProposalFeature? {
  ffi_validate_proposal_feature_by_name(arg0)
}

///|
pub fn validate__proposal_feature_name(
  arg0 : @validate.ProposalFeature,
) -> String {
  ffi_validate_proposal_feature_name(arg0)
}

///|
pub fn validate__run_validate_invalid_ast_fuzz(
  arg0 : String,
  arg1 : UInt64,
) -> Result[@validate.ValidateInvalidAstFuzzStats, String] {
  ffi_validate_run_validate_invalid_ast_fuzz(arg0, arg1)
}

///|
pub fn validate__run_validate_valid_fuzz(
  arg0 : String,
  arg1 : UInt64,
) -> Result[@validate.ValidateValidFuzzStats, String] {
  ffi_validate_run_validate_valid_fuzz(arg0, arg1)
}

///|
pub fn validate__tc_escape_none() -> @validate.TcEscape {
  ffi_validate_tc_escape_none()
}

///|
pub fn validate__tc_escape_terminal() -> @validate.TcEscape {
  ffi_validate_tc_escape_terminal()
}

///|
pub fn validate__tc_state_clone(arg0 : @validate.TcState) -> @validate.TcState {
  ffi_validate_tc_state_clone(arg0)
}

///|
pub fn validate__tc_state_finish_block(
  arg0 : @validate.TcState,
  arg1 : @validate.TcState,
  arg2 : @validate.TcState,
  arg3 : Array[@lib.ValType],
) -> Result[@validate.TcState, String] {
  ffi_validate_tc_state_finish_block(arg0, arg1, arg2, arg3)
}

///|
pub fn validate__tc_state_finish_if(
  arg0 : @validate.TcState,
  arg1 : @validate.TcState,
  arg2 : @validate.TcState,
  arg3 : @validate.TcState,
  arg4 : Array[@lib.ValType],
) -> Result[@validate.TcState, String] {
  ffi_validate_tc_state_finish_if(arg0, arg1, arg2, arg3, arg4)
}

///|
pub fn validate__tc_state_finish_loop(
  arg0 : @validate.TcState,
  arg1 : @validate.TcState,
  arg2 : @validate.TcState,
  arg3 : Array[@lib.ValType],
) -> Result[@validate.TcState, String] {
  ffi_validate_tc_state_finish_loop(arg0, arg1, arg2, arg3)
}

///|
pub fn validate__tc_state_finish_try_table(
  arg0 : @validate.TcState,
  arg1 : @validate.TcState,
  arg2 : @validate.TcState,
  arg3 : Array[@lib.ValType],
  arg4 : Array[@lib.Catch],
) -> Result[@validate.TcState, String] {
  ffi_validate_tc_state_finish_try_table(arg0, arg1, arg2, arg3, arg4)
}

///|
pub fn validate__tc_state_fork_body(
  arg0 : @validate.TcState,
  arg1 : @validate.Env,
  arg2 : Array[@lib.ValType],
) -> @validate.TcState {
  ffi_validate_tc_state_fork_body(arg0, arg1, arg2)
}

///|
pub fn validate__tc_state_merge_nonfallthrough_if_exits(
  arg0 : @validate.TcEscape,
  arg1 : @validate.TcEscape,
) -> @validate.TcEscape {
  ffi_validate_tc_state_merge_nonfallthrough_if_exits(arg0, arg1)
}

///|
pub fn validate__tc_state_new(
  arg0 : @validate.Env,
  arg1 : Array[@lib.ValType],
  arg2 : Bool,
  arg3 : @validate.TcEscape,
) -> @validate.TcState {
  ffi_validate_tc_state_new(arg0, arg1, arg2, arg3)
}

///|
pub fn validate__tc_state_normalize_untyped_block_exit(
  arg0 : @validate.TcState,
  arg1 : Array[@lib.ValType],
) -> Result[(Bool, @validate.TcEscape), String] {
  ffi_validate_tc_state_normalize_untyped_block_exit(arg0, arg1)
}

///|
pub fn validate__tc_state_normalize_untyped_if_branch_exit(
  arg0 : @validate.TcState,
  arg1 : Array[@lib.ValType],
) -> Result[(Bool, @validate.TcEscape), String] {
  ffi_validate_tc_state_normalize_untyped_if_branch_exit(arg0, arg1)
}

///|
pub fn validate__tc_state_pop_expect(
  arg0 : @validate.TcState,
  arg1 : @lib.ValType,
) -> Result[@validate.TcState, String] {
  ffi_validate_tc_state_pop_expect(arg0, arg1)
}

///|
pub fn validate__tc_state_pop_types(
  arg0 : @validate.TcState,
  arg1 : Array[@lib.ValType],
) -> Result[@validate.TcState, String] {
  ffi_validate_tc_state_pop_types(arg0, arg1)
}

///|
pub fn validate__tc_state_push_types(
  arg0 : @validate.TcState,
  arg1 : Array[@lib.ValType],
) -> @validate.TcState {
  ffi_validate_tc_state_push_types(arg0, arg1)
}

///|
pub fn validate__tc_state_typecheck_catch_clause(
  arg0 : @validate.TcState,
  arg1 : @lib.Catch,
) -> Result[Unit, String] {
  ffi_validate_tc_state_typecheck_catch_clause(arg0, arg1)
}

///|
pub fn validate__tc_state_validate_end_stack(
  arg0 : @validate.TcState,
  arg1 : Array[@lib.ValType],
) -> Result[Unit, String] {
  ffi_validate_tc_state_validate_end_stack(arg0, arg1)
}

///|
pub fn validate__tc_state_with_owned_stack(
  arg0 : @validate.TcState,
  arg1 : Array[@lib.ValType],
) -> @validate.TcState {
  ffi_validate_tc_state_with_owned_stack(arg0, arg1)
}

///|
pub fn validate__tc_state_with_stack(
  arg0 : @validate.TcState,
  arg1 : Array[@lib.ValType],
) -> @validate.TcState {
  ffi_validate_tc_state_with_stack(arg0, arg1)
}

///|
pub fn validate__typecheck_expr_for_probe(
  arg0 : @lib.Expr,
  arg1 : @validate.TcState,
) -> Result[@validate.TcState, String] {
  ffi_validate_typecheck_expr_for_probe(arg0, arg1)
}

///|
pub fn validate__validate_codesec(
  arg0 : @lib.CodeSec?,
  arg1 : @lib.FuncSec?,
  arg2 : @validate.Env,
) -> Result[Unit, String] {
  ffi_validate_validate_codesec(arg0, arg1, arg2)
}

///|
pub fn validate__validate_datacnt(
  arg0 : @lib.DataCntSec?,
  arg1 : @lib.DataSec?,
) -> Result[Unit, String] {
  ffi_validate_validate_datacnt(arg0, arg1)
}

///|
pub fn validate__validate_datasec(
  arg0 : @lib.DataSec?,
  arg1 : @validate.Env,
) -> Result[@validate.Env, String] {
  ffi_validate_validate_datasec(arg0, arg1)
}

///|
pub fn validate__validate_defined_func_against_module(
  arg0 : @lib.Module,
  arg1 : @lib.FuncIdx,
  arg2 : @lib.Func,
) -> Result[Unit, String] {
  ffi_validate_validate_defined_func_against_module(arg0, arg1, arg2)
}

///|
pub fn validate__validate_defined_funcs_against_module(
  arg0 : @lib.Module,
  arg1 : Array[(@lib.FuncIdx, @lib.Func)],
) -> Result[Array[(@lib.FuncIdx, String)], @validate.ValidationError] {
  ffi_validate_validate_defined_funcs_against_module(arg0, arg1)
}

///|
pub fn validate__validate_elemsec(
  arg0 : @lib.ElemSec?,
  arg1 : @validate.Env,
) -> Result[@validate.Env, String] {
  ffi_validate_validate_elemsec(arg0, arg1)
}

///|
pub fn validate__validate_exportsec(
  arg0 : @lib.ExportSec?,
  arg1 : @validate.Env,
) -> Result[Unit, String] {
  ffi_validate_validate_exportsec(arg0, arg1)
}

///|
pub fn validate__validate_func_body_against_functype(
  arg0 : @validate.Env,
  arg1 : @lib.FuncType,
  arg2 : @lib.Func,
) -> Result[Unit, String] {
  ffi_validate_validate_func_body_against_functype(arg0, arg1, arg2)
}

///|
pub fn validate__validate_funcsec(
  arg0 : @lib.FuncSec?,
  arg1 : @validate.Env,
) -> Result[@validate.Env, String] {
  ffi_validate_validate_funcsec(arg0, arg1)
}

///|
pub fn validate__validate_globalsec(
  arg0 : @lib.GlobalSec?,
  arg1 : @validate.Env,
) -> Result[@validate.Env, String] {
  ffi_validate_validate_globalsec(arg0, arg1)
}

///|
pub fn validate__validate_importsec(
  arg0 : @lib.ImportSec?,
  arg1 : @validate.Env,
) -> Result[@validate.Env, String] {
  ffi_validate_validate_importsec(arg0, arg1)
}

///|
pub fn validate__validate_invalid_ast_attempt_seed_for_profile(
  arg0 : UInt64,
  arg1 : String,
  arg2 : String,
) -> UInt64 {
  ffi_validate_validate_invalid_ast_attempt_seed_for_profile(arg0, arg1, arg2)
}

///|
pub fn validate__validate_invalid_ast_registry() -> Array[
  @validate.ValidateInvalidAstStrategySpec,
] {
  ffi_validate_validate_invalid_ast_registry()
}

///|
pub fn validate__validate_invalid_ast_run_config(
  arg0 : String,
) -> Result[@validate.ValidateInvalidAstRunConfig, String] {
  ffi_validate_validate_invalid_ast_run_config(arg0)
}

///|
pub fn validate__validate_invalid_ast_strategy_by_stable_id(
  arg0 : String,
) -> @validate.ValidateInvalidAstStrategySpec? {
  ffi_validate_validate_invalid_ast_strategy_by_stable_id(arg0)
}

///|
pub fn validate__validate_invalid_ast_strategy_spec_by_id(
  arg0 : @validate.ValidateInvalidAstStrategyId,
) -> @validate.ValidateInvalidAstStrategySpec? {
  ffi_validate_validate_invalid_ast_strategy_spec_by_id(arg0)
}

///|
pub fn validate__validate_memsec(
  arg0 : @lib.MemSec?,
  arg1 : @validate.Env,
) -> Result[@validate.Env, String] {
  ffi_validate_validate_memsec(arg0, arg1)
}

///|
pub fn validate__validate_module(
  arg0 : @lib.Module,
  arg1 : Array[@validate.ProposalFeature]?,
) -> Result[Unit, @validate.ValidationError] {
  ffi_validate_validate_module(arg0, arg1)
}

///|
pub fn validate__validate_startsec(
  arg0 : @lib.StartSec?,
  arg1 : @validate.Env,
) -> Result[Unit, String] {
  ffi_validate_validate_startsec(arg0, arg1)
}

///|
pub fn validate__validate_tablesec(
  arg0 : @lib.TableSec?,
  arg1 : @validate.Env,
) -> Result[@validate.Env, String] {
  ffi_validate_validate_tablesec(arg0, arg1)
}

///|
pub fn validate__validate_tagsec(
  arg0 : @lib.TagSec?,
  arg1 : @validate.Env,
) -> Result[@validate.Env, String] {
  ffi_validate_validate_tagsec(arg0, arg1)
}

///|
pub fn validate__validate_typesec(
  arg0 : @lib.TypeSec?,
  arg1 : @validate.Env,
) -> Result[@validate.Env, String] {
  ffi_validate_validate_typesec(arg0, arg1)
}

///|
pub fn validate__validate_valid_feature_actual_count(
  arg0 : @validate.GenValidFeatureStats,
  arg1 : @validate.ValidateValidFeatureKey,
) -> Int {
  ffi_validate_validate_valid_feature_actual_count(arg0, arg1)
}

///|
pub fn validate__validate_valid_feature_actual_count_by_label(
  arg0 : @validate.GenValidFeatureStats,
  arg1 : String,
) -> Result[Int, String] {
  ffi_validate_validate_valid_feature_actual_count_by_label(arg0, arg1)
}

///|
pub fn validate__validate_valid_feature_floor(
  arg0 : @validate.ValidateValidFeatureKey,
  arg1 : Int,
) -> @validate.ValidateValidFeatureFloor {
  ffi_validate_validate_valid_feature_floor(arg0, arg1)
}

///|
pub fn validate__validate_valid_feature_floor_by_label(
  arg0 : String,
  arg1 : Int,
) -> Result[@validate.ValidateValidFeatureFloor, String] {
  ffi_validate_validate_valid_feature_floor_by_label(arg0, arg1)
}

///|
pub fn validate__validate_valid_feature_ledger(
  arg0 : @validate.GenValidFeatureStats,
  arg1 : Array[@validate.ValidateValidFeatureFloor],
) -> Array[@validate.ValidateValidFeatureLedgerEntry] {
  ffi_validate_validate_valid_feature_ledger(arg0, arg1)
}

///|
pub fn validate__validate_valid_run_config(
  arg0 : String,
) -> Result[@validate.ValidateValidRunConfig, String] {
  ffi_validate_validate_valid_run_config(arg0)
}

///|
pub fn validate__validation_error_diagnostic(
  arg0 : @validate.ValidationError,
) -> @validate.ValidationDiagnostic {
  ffi_validate_validation_error_diagnostic(arg0)
}

///|
pub fn validate__validation_error_func_idx(
  arg0 : @validate.ValidationError,
) -> @lib.FuncIdx? {
  ffi_validate_validation_error_func_idx(arg0)
}

///|
pub fn validate__validation_error_message(
  arg0 : @validate.ValidationError,
) -> String {
  ffi_validate_validation_error_message(arg0)
}

///|
pub fn validate__validation_issue_family(
  arg0 : @validate.ValidationIssue,
) -> @validate.ValidationIssueFamily {
  ffi_validate_validation_issue_family(arg0)
}

///|
pub fn validate__validation_issue_message(
  arg0 : @validate.ValidationIssue,
) -> String {
  ffi_validate_validation_issue_message(arg0)
}

///|
pub fn validate__Env__append_rectype_types(
  arg0 : @validate.Env,
  arg1 : @lib.RecType,
) -> @validate.Env {
  ffi_validate_Env_append_rectype_types(arg0, arg1)
}

///|
pub fn validate__Env__descriptor_result_type(
  arg0 : @validate.Env,
  arg1 : @lib.TypeIdx,
  arg2 : @lib.RefType?,
) -> Result[@lib.ValType, String] {
  ffi_validate_Env_descriptor_result_type(arg0, arg1, arg2)
}

///|
pub fn validate__Env__expand_blocktype(
  arg0 : @validate.Env,
  arg1 : @lib.BlockType,
) -> Result[(Array[@lib.ValType], Array[@lib.ValType]), String] {
  ffi_validate_Env_expand_blocktype(arg0, arg1)
}

///|
pub fn validate__Env__get_catch_label_types(
  arg0 : @validate.Env,
  arg1 : @lib.LabelIdx,
) -> Array[@lib.ValType]? {
  ffi_validate_Env_get_catch_label_types(arg0, arg1)
}

///|
pub fn validate__Env__get_elem(
  arg0 : @validate.Env,
  arg1 : @lib.ElemIdx,
) -> @lib.Elem? {
  ffi_validate_Env_get_elem(arg0, arg1)
}

///|
pub fn validate__Env__get_functype_by_funcidx(
  arg0 : @validate.Env,
  arg1 : @lib.FuncIdx,
) -> @lib.FuncType? {
  ffi_validate_Env_get_functype_by_funcidx(arg0, arg1)
}

///|
pub fn validate__Env__get_functypeidx_by_funcidx(
  arg0 : @validate.Env,
  arg1 : @lib.FuncIdx,
) -> @lib.TypeIdx? {
  ffi_validate_Env_get_functypeidx_by_funcidx(arg0, arg1)
}

///|
pub fn validate__Env__get_global_type(
  arg0 : @validate.Env,
  arg1 : @lib.GlobalIdx,
) -> @lib.GlobalType? {
  ffi_validate_Env_get_global_type(arg0, arg1)
}

///|
pub fn validate__Env__get_label(
  arg0 : @validate.Env,
  arg1 : @lib.LabelIdx,
) -> Array[@lib.ValType]? {
  ffi_validate_Env_get_label(arg0, arg1)
}

///|
pub fn validate__Env__get_label_types(
  arg0 : @validate.Env,
  arg1 : @lib.LabelIdx,
) -> Array[@lib.ValType]? {
  ffi_validate_Env_get_label_types(arg0, arg1)
}

///|
pub fn validate__Env__get_local_type(
  arg0 : @validate.Env,
  arg1 : @lib.LocalIdx,
) -> @lib.ValType? {
  ffi_validate_Env_get_local_type(arg0, arg1)
}

///|
pub fn validate__Env__get_memtype(
  arg0 : @validate.Env,
  arg1 : @lib.MemIdx,
) -> @lib.MemType? {
  ffi_validate_Env_get_memtype(arg0, arg1)
}

///|
pub fn validate__Env__get_table_type(
  arg0 : @validate.Env,
  arg1 : @lib.TableIdx,
) -> @lib.TableType? {
  ffi_validate_Env_get_table_type(arg0, arg1)
}

///|
pub fn validate__Env__get_tag(
  arg0 : @validate.Env,
  arg1 : @lib.TagIdx,
) -> @lib.TagType? {
  ffi_validate_Env_get_tag(arg0, arg1)
}

///|
pub fn validate__Env__has_data(
  arg0 : @validate.Env,
  arg1 : @lib.DataIdx,
) -> Bool {
  ffi_validate_Env_has_data(arg0, arg1)
}

///|
pub fn validate__Env__has_func(
  arg0 : @validate.Env,
  arg1 : @lib.FuncIdx,
) -> Bool {
  ffi_validate_Env_has_func(arg0, arg1)
}

///|
pub fn validate__Env__legacy_rethrow_catch_ordinal(
  arg0 : @validate.Env,
  arg1 : UInt,
) -> Int? {
  ffi_validate_Env_legacy_rethrow_catch_ordinal(arg0, arg1)
}

///|
pub fn validate__Env__new() -> @validate.Env {
  ffi_validate_Env_new()
}

///|
pub fn validate__Env__push_data(
  arg0 : @validate.Env,
  arg1 : @lib.Data,
) -> @validate.Env {
  ffi_validate_Env_push_data(arg0, arg1)
}

///|
pub fn validate__Env__push_elem(
  arg0 : @validate.Env,
  arg1 : @lib.Elem,
) -> @validate.Env {
  ffi_validate_Env_push_elem(arg0, arg1)
}

///|
pub fn validate__Env__push_func(
  arg0 : @validate.Env,
  arg1 : @lib.FuncType,
) -> @validate.Env {
  ffi_validate_Env_push_func(arg0, arg1)
}

///|
pub fn validate__Env__push_func_with_typeidx(
  arg0 : @validate.Env,
  arg1 : @lib.FuncType,
  arg2 : @lib.TypeIdx?,
) -> @validate.Env {
  ffi_validate_Env_push_func_with_typeidx(arg0, arg1, arg2)
}

///|
pub fn validate__Env__push_global(
  arg0 : @validate.Env,
  arg1 : @lib.GlobalType,
) -> @validate.Env {
  ffi_validate_Env_push_global(arg0, arg1)
}

///|
pub fn validate__Env__push_mem(
  arg0 : @validate.Env,
  arg1 : @lib.MemType,
) -> @validate.Env {
  ffi_validate_Env_push_mem(arg0, arg1)
}

///|
pub fn validate__Env__push_table(
  arg0 : @validate.Env,
  arg1 : @lib.TableType,
) -> @validate.Env {
  ffi_validate_Env_push_table(arg0, arg1)
}

///|
pub fn validate__Env__push_tag(
  arg0 : @validate.Env,
  arg1 : @lib.TagType,
) -> @validate.Env {
  ffi_validate_Env_push_tag(arg0, arg1)
}

///|
pub fn validate__Env__resolve_array_field(
  arg0 : @validate.Env,
  arg1 : @lib.TypeIdx,
) -> Result[@lib.FieldType, String] {
  ffi_validate_Env_resolve_array_field(arg0, arg1)
}

///|
pub fn validate__Env__resolve_comptype(
  arg0 : @validate.Env,
  arg1 : @lib.TypeIdx,
) -> @lib.CompType? {
  ffi_validate_Env_resolve_comptype(arg0, arg1)
}

///|
pub fn validate__Env__resolve_cont_functype(
  arg0 : @validate.Env,
  arg1 : @lib.TypeIdx,
) -> @lib.FuncType? {
  ffi_validate_Env_resolve_cont_functype(arg0, arg1)
}

///|
pub fn validate__Env__resolve_descriptor_target_ref_type(
  arg0 : @validate.Env,
  arg1 : Bool,
  arg2 : @lib.HeapType,
) -> Result[@lib.RefType, String] {
  ffi_validate_Env_resolve_descriptor_target_ref_type(arg0, arg1, arg2)
}

///|
pub fn validate__Env__resolve_functype(
  arg0 : @validate.Env,
  arg1 : @lib.TypeIdx,
) -> @lib.FuncType? {
  ffi_validate_Env_resolve_functype(arg0, arg1)
}

///|
pub fn validate__Env__resolve_heaptype_subtype(
  arg0 : @validate.Env,
  arg1 : @lib.HeapType,
) -> @lib.SubType? {
  ffi_validate_Env_resolve_heaptype_subtype(arg0, arg1)
}

///|
pub fn validate__Env__resolve_struct_descriptor_type(
  arg0 : @validate.Env,
  arg1 : @lib.TypeIdx,
) -> Result[@lib.TypeIdx?, String] {
  ffi_validate_Env_resolve_struct_descriptor_type(arg0, arg1)
}

///|
pub fn validate__Env__resolve_struct_fields(
  arg0 : @validate.Env,
  arg1 : @lib.TypeIdx,
) -> Result[Array[@lib.FieldType], String] {
  ffi_validate_Env_resolve_struct_fields(arg0, arg1)
}

///|
pub fn validate__Env__resolve_struct_subtype(
  arg0 : @validate.Env,
  arg1 : @lib.TypeIdx,
) -> Result[@lib.SubType, String] {
  ffi_validate_Env_resolve_struct_subtype(arg0, arg1)
}

///|
pub fn validate__Env__resolve_subtype(
  arg0 : @validate.Env,
  arg1 : @lib.TypeIdx,
) -> @lib.SubType? {
  ffi_validate_Env_resolve_subtype(arg0, arg1)
}

///|
pub fn validate__Env__resolve_tag_functype(
  arg0 : @validate.Env,
  arg1 : @lib.TagIdx,
) -> @lib.FuncType? {
  ffi_validate_Env_resolve_tag_functype(arg0, arg1)
}

///|
pub fn validate__Env__resolve_typeidx_subtype(
  arg0 : @validate.Env,
  arg1 : @lib.TypeIdx,
) -> @lib.SubType? {
  ffi_validate_Env_resolve_typeidx_subtype(arg0, arg1)
}

///|
pub fn validate__Env__with_datas(
  arg0 : @validate.Env,
  arg1 : Array[@lib.Data],
) -> @validate.Env {
  ffi_validate_Env_with_datas(arg0, arg1)
}

///|
pub fn validate__Env__with_elems(
  arg0 : @validate.Env,
  arg1 : Array[@lib.Elem],
) -> @validate.Env {
  ffi_validate_Env_with_elems(arg0, arg1)
}

///|
pub fn validate__Env__with_exact_reference_inference(
  arg0 : @validate.Env,
  arg1 : Bool,
) -> @validate.Env {
  ffi_validate_Env_with_exact_reference_inference(arg0, arg1)
}

///|
pub fn validate__Env__with_funcs(
  arg0 : @validate.Env,
  arg1 : Array[@lib.FuncType],
) -> @validate.Env {
  ffi_validate_Env_with_funcs(arg0, arg1)
}

///|
pub fn validate__Env__with_funcs_and_type_idxs(
  arg0 : @validate.Env,
  arg1 : Array[@lib.FuncType],
  arg2 : Array[@lib.TypeIdx?],
) -> @validate.Env {
  ffi_validate_Env_with_funcs_and_type_idxs(arg0, arg1, arg2)
}

///|
pub fn validate__Env__with_globals(
  arg0 : @validate.Env,
  arg1 : Array[@lib.GlobalType],
) -> @validate.Env {
  ffi_validate_Env_with_globals(arg0, arg1)
}

///|
pub fn validate__Env__with_label(
  arg0 : @validate.Env,
  arg1 : Array[@lib.ValType],
) -> @validate.Env {
  ffi_validate_Env_with_label(arg0, arg1)
}

///|
pub fn validate__Env__with_labels(
  arg0 : @validate.Env,
  arg1 : Array[Array[@lib.ValType]],
) -> @validate.Env {
  ffi_validate_Env_with_labels(arg0, arg1)
}

///|
pub fn validate__Env__with_legacy_catch_depth(
  arg0 : @validate.Env,
  arg1 : Int,
) -> @validate.Env {
  ffi_validate_Env_with_legacy_catch_depth(arg0, arg1)
}

///|
pub fn validate__Env__with_locals(
  arg0 : @validate.Env,
  arg1 : @lib.Locals,
) -> @validate.Env {
  ffi_validate_Env_with_locals(arg0, arg1)
}

///|
pub fn validate__Env__with_mems(
  arg0 : @validate.Env,
  arg1 : Array[@lib.MemType],
) -> @validate.Env {
  ffi_validate_Env_with_mems(arg0, arg1)
}

///|
pub fn validate__Env__with_module(
  arg0 : @validate.Env,
  arg1 : @lib.Module,
) -> @validate.Env {
  ffi_validate_Env_with_module(arg0, arg1)
}

///|
pub fn validate__Env__with_rectype(
  arg0 : @validate.Env,
  arg1 : @lib.RecType,
) -> @validate.Env {
  ffi_validate_Env_with_rectype(arg0, arg1)
}

///|
pub fn validate__Env__with_return_type(
  arg0 : @validate.Env,
  arg1 : Array[@lib.ValType]?,
) -> @validate.Env {
  ffi_validate_Env_with_return_type(arg0, arg1)
}

///|
pub fn validate__Env__with_tables(
  arg0 : @validate.Env,
  arg1 : Array[@lib.TableType],
) -> @validate.Env {
  ffi_validate_Env_with_tables(arg0, arg1)
}

///|
pub fn validate__Env__with_tags(
  arg0 : @validate.Env,
  arg1 : Array[@lib.TagType],
) -> @validate.Env {
  ffi_validate_Env_with_tags(arg0, arg1)
}

///|
pub fn validate__Env__with_types(
  arg0 : @validate.Env,
  arg1 : Array[@lib.SubType],
) -> @validate.Env {
  ffi_validate_Env_with_types(arg0, arg1)
}

///|
pub fn validate__GenInvalidAstParams__coverage_forced_seed(
  arg0 : @validate.ValidateInvalidAstStrategyId,
  arg1 : @validate.GenValidConfig?,
  arg2 : Bool?,
) -> @validate.GenInvalidAstParams {
  ffi_validate_GenInvalidAstParams_coverage_forced_seed(arg0, arg1, arg2)
}

///|
pub fn validate__GenInvalidAstParams__minimal_seed(
  arg0 : @validate.ValidateInvalidAstStrategyId,
  arg1 : @validate.GenValidConfig?,
  arg2 : Bool?,
) -> @validate.GenInvalidAstParams {
  ffi_validate_GenInvalidAstParams_minimal_seed(arg0, arg1, arg2)
}

///|
pub fn validate__GenInvalidAstParams__natural_seed(
  arg0 : @validate.ValidateInvalidAstStrategyId,
  arg1 : @validate.GenValidConfig?,
  arg2 : Bool?,
) -> @validate.GenInvalidAstParams {
  ffi_validate_GenInvalidAstParams_natural_seed(arg0, arg1, arg2)
}

///|
pub fn validate__GenInvalidAstParams__new(
  arg0 : @validate.ValidateInvalidAstStrategyId,
  arg1 : @validate.GenInvalidSeedMode?,
  arg2 : @validate.GenValidConfig?,
  arg3 : Bool?,
) -> @validate.GenInvalidAstParams {
  ffi_validate_GenInvalidAstParams_new(arg0, arg1, arg2, arg3)
}

///|
pub fn validate__GenInvalidAstParams__repro_seed(
  arg0 : @validate.ValidateInvalidAstStrategyId,
  arg1 : @validate.GenValidConfig?,
  arg2 : Bool?,
) -> @validate.GenInvalidAstParams {
  ffi_validate_GenInvalidAstParams_repro_seed(arg0, arg1, arg2)
}

///|
pub fn validate__GenInvalidAstParams__rich_seed(
  arg0 : @validate.ValidateInvalidAstStrategyId,
  arg1 : @validate.GenValidConfig?,
  arg2 : Bool?,
) -> @validate.GenInvalidAstParams {
  ffi_validate_GenInvalidAstParams_rich_seed(arg0, arg1, arg2)
}

///|
pub fn validate__GenInvalidAstParams__small_coverage_forced_seed(
  arg0 : @validate.ValidateInvalidAstStrategyId,
  arg1 : @validate.GenValidConfig?,
  arg2 : Bool?,
) -> @validate.GenInvalidAstParams {
  ffi_validate_GenInvalidAstParams_small_coverage_forced_seed(arg0, arg1, arg2)
}

///|
pub fn validate__GenInvalidAstParams__small_natural_seed(
  arg0 : @validate.ValidateInvalidAstStrategyId,
  arg1 : @validate.GenValidConfig?,
  arg2 : Bool?,
) -> @validate.GenInvalidAstParams {
  ffi_validate_GenInvalidAstParams_small_natural_seed(arg0, arg1, arg2)
}

///|
pub fn validate__GenValidConfig__binaryen_oracle_coverage_forced_default() -> @validate.GenValidConfig {
  ffi_validate_GenValidConfig_binaryen_oracle_coverage_forced_default()
}

///|
pub fn validate__GenValidConfig__coverage_forced_default() -> @validate.GenValidConfig {
  ffi_validate_GenValidConfig_coverage_forced_default()
}

///|
pub fn validate__GenValidConfig__for_profile(
  arg0 : @validate.GenValidProfile,
) -> @validate.GenValidConfig {
  ffi_validate_GenValidConfig_for_profile(arg0)
}

///|
pub fn validate__GenValidConfig__natural_default() -> @validate.GenValidConfig {
  ffi_validate_GenValidConfig_natural_default()
}

///|
pub fn validate__GenValidConfig__portable_coverage_forced_default() -> @validate.GenValidConfig {
  ffi_validate_GenValidConfig_portable_coverage_forced_default()
}

///|
pub fn validate__GenValidConfig__profile(
  arg0 : String,
) -> Result[@validate.GenValidConfig, String] {
  ffi_validate_GenValidConfig_profile(arg0)
}

///|
pub fn validate__GenValidConfig__wat_text_roundtrip_default() -> @validate.GenValidConfig {
  ffi_validate_GenValidConfig_wat_text_roundtrip_default()
}

///|
pub fn validate__GenValidExactOpcodeCounts__add(
  arg0 : @validate.GenValidExactOpcodeCounts,
  arg1 : @validate.GenValidExactOpcodeCounts,
) -> @validate.GenValidExactOpcodeCounts {
  ffi_validate_GenValidExactOpcodeCounts_add(arg0, arg1)
}

///|
pub fn validate__GenValidExactOpcodeCounts__empty() -> @validate.GenValidExactOpcodeCounts {
  ffi_validate_GenValidExactOpcodeCounts_empty()
}

///|
pub fn validate__GenValidFeatureStats__empty(
  arg0 : @validate.GenValidMode,
) -> @validate.GenValidFeatureStats {
  ffi_validate_GenValidFeatureStats_empty(arg0)
}

///|
pub fn validate__GenValidFeatureStats__record(
  arg0 : @validate.GenValidFeatureStats,
  arg1 : @validate.GenValidFeatureFacts,
) -> @validate.GenValidFeatureStats {
  ffi_validate_GenValidFeatureStats_record(arg0, arg1)
}

///|
pub fn validate__GenValidFeatureToggles__coverage_forced_default() -> @validate.GenValidFeatureToggles {
  ffi_validate_GenValidFeatureToggles_coverage_forced_default()
}

///|
pub fn validate__GenValidFeatureToggles__natural_default() -> @validate.GenValidFeatureToggles {
  ffi_validate_GenValidFeatureToggles_natural_default()
}

///|
pub fn validate__GenValidProfileMember__new(
  arg0 : @validate.GenValidProfile,
  arg1 : Int,
) -> @validate.GenValidProfileMember {
  ffi_validate_GenValidProfileMember_new(arg0, arg1)
}

///|
pub fn validate__GenValidSectionBias__coverage_forced_default() -> @validate.GenValidSectionBias {
  ffi_validate_GenValidSectionBias_coverage_forced_default()
}

///|
pub fn validate__GenValidSectionBias__natural_default() -> @validate.GenValidSectionBias {
  ffi_validate_GenValidSectionBias_natural_default()
}

///|
pub fn validate__GenValidSsaFuncFacts__empty() -> @validate.GenValidSsaFuncFacts {
  ffi_validate_GenValidSsaFuncFacts_empty()
}

///|
pub fn validate__LabelStack__copy(
  arg0 : @validate.LabelStack,
) -> @validate.LabelStack {
  ffi_validate_LabelStack_copy(arg0)
}

///|
pub fn validate__LabelStack__from_labels(
  arg0 : Array[Array[@lib.ValType]],
) -> @validate.LabelStack {
  ffi_validate_LabelStack_from_labels(arg0)
}

///|
pub fn validate__LabelStack__get(
  arg0 : @validate.LabelStack,
  arg1 : Int,
) -> Array[@lib.ValType]? {
  ffi_validate_LabelStack_get(arg0, arg1)
}

///|
pub fn validate__LabelStack__length(arg0 : @validate.LabelStack) -> Int {
  ffi_validate_LabelStack_length(arg0)
}

///|
pub fn validate__LabelStack__new() -> @validate.LabelStack {
  ffi_validate_LabelStack_new()
}

///|
pub fn validate__LabelStack__push(
  arg0 : @validate.LabelStack,
  arg1 : Array[@lib.ValType],
) -> Unit {
  ffi_validate_LabelStack_push(arg0, arg1)
}

///|
pub fn validate__ValidationDiagnostic__new(
  arg0 : @validate.ValidationIssue,
  arg1 : @lib.FuncIdx??,
) -> @validate.ValidationDiagnostic {
  ffi_validate_ValidationDiagnostic_new(arg0, arg1)
}

///|
pub fn wast__evaluate_wast_static_assertion(
  arg0 : @wast.WastCommand,
  arg1 : String,
) -> Result[@wast.WastStaticAssertionResult, String] {
  ffi_wast_evaluate_wast_static_assertion(arg0, arg1)
}

///|
pub fn wast__lookup_keyword(arg0 : String) -> @wast.TokenType? {
  ffi_wast_lookup_keyword(arg0)
}

///|
pub fn wast__module_to_wast(arg0 : @wast.Module) -> Result[String, String] {
  ffi_wast_module_to_wast(arg0)
}

///|
pub fn wast__module_to_wast_with_context(
  arg0 : @wast.Module,
  arg1 : @lib.PrettyPrintContext,
) -> Result[String, String] {
  ffi_wast_module_to_wast_with_context(arg0, arg1)
}

///|
pub fn wast__run_wast_roundtrip_fuzz(
  arg0 : String,
  arg1 : UInt64,
) -> Result[@wast.WastRoundtripFuzzStats, String] {
  ffi_wast_run_wast_roundtrip_fuzz(arg0, arg1)
}

///|
pub fn wast__run_wast_spec_file(
  arg0 : String,
  arg1 : String,
) -> @wast.WastSpecFileReport {
  ffi_wast_run_wast_spec_file(arg0, arg1)
}

///|
pub fn wast__run_wast_spec_suite(
  arg0 : Array[(String, String)],
) -> @wast.WastSpecRunSummary {
  ffi_wast_run_wast_spec_suite(arg0)
}

///|
pub fn wast__script_to_wast(arg0 : @wast.WastScript) -> Result[String, String] {
  ffi_wast_script_to_wast(arg0)
}

///|
pub fn wast__script_to_wast_with_context(
  arg0 : @wast.WastScript,
  arg1 : @lib.PrettyPrintContext,
) -> Result[String, String] {
  ffi_wast_script_to_wast_with_context(arg0, arg1)
}

///|
pub fn wast__wast_arbitrary_feature_stats(
  arg0 : @wast.Module,
) -> @wast.WastArbitraryFeatureStats {
  ffi_wast_wast_arbitrary_feature_stats(arg0)
}

///|
pub fn wast__wast_ast_to_binary_module(
  arg0 : @wast.Module,
) -> Result[@lib.Module, String] {
  ffi_wast_wast_ast_to_binary_module(arg0)
}

///|
pub fn wast__wast_text_binary_roundtrip(
  arg0 : String,
  arg1 : String?,
) -> Result[(String, @lib.Module), String] {
  ffi_wast_wast_text_binary_roundtrip(arg0, arg1)
}

///|
pub fn wast__wast_to_binary_module(
  arg0 : String,
  arg1 : String?,
) -> Result[@lib.Module, String] {
  ffi_wast_wast_to_binary_module(arg0, arg1)
}

///|
pub fn wast__wast_to_module(
  arg0 : String,
  arg1 : String?,
) -> Result[@wast.Module, String] {
  ffi_wast_wast_to_module(arg0, arg1)
}

///|
pub fn wast__wast_to_script(
  arg0 : String,
  arg1 : String?,
) -> Result[@wast.WastScript, String] {
  ffi_wast_wast_to_script(arg0, arg1)
}

///|
pub fn wast__KeywordTable__lookup(
  arg0 : @wast.KeywordTable,
  arg1 : String,
) -> @wast.TokenType? {
  ffi_wast_KeywordTable_lookup(arg0, arg1)
}

///|
pub fn wast__MemoryType__new(
  arg0 : UInt64,
  arg1 : UInt64??,
  arg2 : Bool?,
  arg3 : Bool?,
) -> @wast.MemoryType {
  ffi_wast_MemoryType_new(arg0, arg1, arg2, arg3)
}

///|
pub fn wast__Module__new(
  arg0 : Array[@wast.ModuleField],
  arg1 : String??,
) -> @wast.Module {
  ffi_wast_Module_new(arg0, arg1)
}

///|
pub fn wast__WastLexer__get_errors(
  arg0 : @wast.WastLexer,
) -> Array[@wast.LexerError] {
  ffi_wast_WastLexer_get_errors(arg0)
}

///|
pub fn wast__WastLexer__get_token(arg0 : @wast.WastLexer) -> @wast.Token {
  ffi_wast_WastLexer_get_token(arg0)
}

///|
pub fn wast__WastLexer__has_errors(arg0 : @wast.WastLexer) -> Bool {
  ffi_wast_WastLexer_has_errors(arg0)
}

///|
pub fn wast__WastLexer__new(arg0 : Bytes, arg1 : String) -> @wast.WastLexer {
  ffi_wast_WastLexer_new(arg0, arg1)
}

///|
pub fn wast__WastParser__get_errors(
  arg0 : @wast.WastParser,
) -> Array[@wast.ParseError] {
  ffi_wast_WastParser_get_errors(arg0)
}

///|
pub fn wast__WastParser__has_errors(arg0 : @wast.WastParser) -> Bool {
  ffi_wast_WastParser_has_errors(arg0)
}

///|
pub fn wast__WastParser__new(arg0 : @wast.WastLexer) -> @wast.WastParser {
  ffi_wast_WastParser_new(arg0)
}

///|
pub fn wat__lib_module_to_wat(arg0 : @lib.Module) -> Result[String, String] {
  ffi_wat_lib_module_to_wat(arg0)
}

///|
pub fn wat__lookup_keyword(arg0 : String) -> @wast.TokenType? {
  ffi_wat_lookup_keyword(arg0)
}

///|
pub fn wat__module_to_wat(arg0 : @wast.Module) -> Result[String, String] {
  ffi_wat_module_to_wat(arg0)
}

///|
pub fn wat__module_to_wat_with_context(
  arg0 : @wast.Module,
  arg1 : @lib.PrettyPrintContext,
) -> Result[String, String] {
  ffi_wat_module_to_wat_with_context(arg0, arg1)
}

///|
pub fn wat__run_wat_roundtrip_fuzz(
  arg0 : String,
  arg1 : UInt64,
) -> Result[@wat.WatRoundtripFuzzStats, String] {
  ffi_wat_run_wat_roundtrip_fuzz(arg0, arg1)
}

///|
pub fn wat__script_to_wat(arg0 : @wast.WastScript) -> Result[String, String] {
  ffi_wat_script_to_wat(arg0)
}

///|
pub fn wat__script_to_wat_with_context(
  arg0 : @wast.WastScript,
  arg1 : @lib.PrettyPrintContext,
) -> Result[String, String] {
  ffi_wat_script_to_wat_with_context(arg0, arg1)
}

///|
pub fn wat__wat_to_module(
  arg0 : String,
  arg1 : String?,
) -> Result[@wast.Module, String] {
  ffi_wat_wat_to_module(arg0, arg1)
}

///|
pub fn wat__wat_to_script(
  arg0 : String,
  arg1 : String?,
) -> Result[@wast.WastScript, String] {
  ffi_wat_wat_to_script(arg0, arg1)
}

///|
pub fn ffi_bridge__optimize_module(
  arg0 : @lib.Module,
  arg1 : Array[String],
  arg2 : Int?,
  arg3 : Int?,
) -> Result[@lib.Module, String] {
  ffi_ffi_bridge_optimize_module(arg0, arg1, arg2, arg3)
}
