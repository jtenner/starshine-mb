///|
pub fn __node_cli_parse_result_has_config_path(
  value : @cli.CliParseResult,
) -> Bool {
  match value.config_path {
    Some(_) => true
    None => false
  }
}

///|
pub fn __node_cli_parse_result_get_config_path(
  value : @cli.CliParseResult,
) -> String {
  match value.config_path {
    Some(path) => path
    None => abort("CliParseResult.config_path is None")
  }
}

///|
pub fn __node_cli_parse_result_input_globs_length(
  value : @cli.CliParseResult,
) -> Int {
  value.input_globs.length()
}

///|
pub fn __node_cli_parse_result_input_globs_get(
  value : @cli.CliParseResult,
  index : Int,
) -> String {
  value.input_globs[index]
}

///|
pub fn __node_cli_parse_result_glob_enabled(
  value : @cli.CliParseResult,
) -> Bool {
  value.glob_enabled
}

///|
pub fn __node_cli_parse_result_help_requested(
  value : @cli.CliParseResult,
) -> Bool {
  value.help_requested
}

///|
pub fn __node_cli_parse_result_version_requested(
  value : @cli.CliParseResult,
) -> Bool {
  value.version_requested
}

///|
pub fn __node_cli_parse_result_read_stdin(value : @cli.CliParseResult) -> Bool {
  value.read_stdin
}

///|
pub fn __node_cli_parse_result_has_input_format(
  value : @cli.CliParseResult,
) -> Bool {
  match value.input_format {
    Some(_) => true
    None => false
  }
}

///|
pub fn __node_cli_parse_result_get_input_format(
  value : @cli.CliParseResult,
) -> @cli.CliInputFormat {
  match value.input_format {
    Some(format) => format
    None => abort("CliParseResult.input_format is None")
  }
}

///|
pub fn __node_cli_parse_result_output_targets_length(
  value : @cli.CliParseResult,
) -> Int {
  value.output_targets.length()
}

///|
pub fn __node_cli_parse_result_output_targets_get(
  value : @cli.CliParseResult,
  index : Int,
) -> @cli.CliOutputTarget {
  value.output_targets[index]
}

///|
pub fn __node_cli_parse_result_pass_flags_length(
  value : @cli.CliParseResult,
) -> Int {
  value.pass_flags.length()
}

///|
pub fn __node_cli_parse_result_pass_flags_get(
  value : @cli.CliParseResult,
  index : Int,
) -> String {
  value.pass_flags[index]
}

///|
pub fn __node_cli_parse_result_optimize_flags_length(
  value : @cli.CliParseResult,
) -> Int {
  value.optimize_flags.length()
}

///|
pub fn __node_cli_parse_result_optimize_flags_get(
  value : @cli.CliParseResult,
  index : Int,
) -> @cli.CliOptimizationFlag {
  value.optimize_flags[index]
}

///|
pub fn __node_cli_parse_result_has_trap_mode(
  value : @cli.CliParseResult,
) -> Bool {
  match value.trap_mode {
    Some(_) => true
    None => false
  }
}

///|
pub fn __node_cli_parse_result_get_trap_mode(
  value : @cli.CliParseResult,
) -> @cli.TrapMode {
  match value.trap_mode {
    Some(mode) => mode
    None => abort("CliParseResult.trap_mode is None")
  }
}

///|
pub fn __node_cli_parse_result_has_monomorphize_min_benefit(
  value : @cli.CliParseResult,
) -> Bool {
  match value.monomorphize_min_benefit {
    Some(_) => true
    None => false
  }
}

///|
pub fn __node_cli_parse_result_get_monomorphize_min_benefit(
  value : @cli.CliParseResult,
) -> Int {
  match value.monomorphize_min_benefit {
    Some(parsed_value) => parsed_value
    None => abort("CliParseResult.monomorphize_min_benefit is None")
  }
}

///|
pub fn __node_cli_parse_result_has_low_memory_unused(
  value : @cli.CliParseResult,
) -> Bool {
  match value.low_memory_unused {
    Some(_) => true
    None => false
  }
}

///|
pub fn __node_cli_parse_result_get_low_memory_unused(
  value : @cli.CliParseResult,
) -> Bool {
  match value.low_memory_unused {
    Some(parsed_value) => parsed_value
    None => abort("CliParseResult.low_memory_unused is None")
  }
}

///|
pub fn __node_cli_parse_result_has_low_memory_bound(
  value : @cli.CliParseResult,
) -> Bool {
  match value.low_memory_bound {
    Some(_) => true
    None => false
  }
}

///|
pub fn __node_cli_parse_result_get_low_memory_bound(
  value : @cli.CliParseResult,
) -> UInt64 {
  match value.low_memory_bound {
    Some(parsed_value) => parsed_value
    None => abort("CliParseResult.low_memory_bound is None")
  }
}

///|
pub fn __node_cli_input_format_name(value : @cli.CliInputFormat) -> String {
  match value {
    @cli.CliInputFormat::Wasm => "wasm"
    @cli.CliInputFormat::Wat => "wat"
    @cli.CliInputFormat::Wast => "wast"
  }
}

///|
pub fn __node_cli_output_target_kind(value : @cli.CliOutputTarget) -> String {
  match value {
    @cli.CliOutputTarget::StdoutOutput => "stdout"
    @cli.CliOutputTarget::FileOutput(_) => "file"
    @cli.CliOutputTarget::DirOutput(_) => "dir"
  }
}

///|
pub fn __node_cli_output_target_path(value : @cli.CliOutputTarget) -> String {
  match value {
    @cli.CliOutputTarget::StdoutOutput =>
      abort("CliOutputTarget.stdout has no path")
    @cli.CliOutputTarget::FileOutput(path) => path
    @cli.CliOutputTarget::DirOutput(path) => path
  }
}

///|
pub fn __node_cli_optimization_flag_kind(
  value : @cli.CliOptimizationFlag,
) -> String {
  match value {
    @cli.CliOptimizationFlag::OptimizePreset => "optimize"
    @cli.CliOptimizationFlag::ShrinkPreset => "shrink"
    @cli.CliOptimizationFlag::OLevel(_, _) => "olevel"
  }
}

///|
pub fn __node_cli_optimization_flag_level(
  value : @cli.CliOptimizationFlag,
) -> Int {
  match value {
    @cli.CliOptimizationFlag::OLevel(level, _) => level
    _ => abort("CliOptimizationFlag is not an OLevel variant")
  }
}

///|
pub fn __node_cli_optimization_flag_size_bias(
  value : @cli.CliOptimizationFlag,
) -> Bool {
  match value {
    @cli.CliOptimizationFlag::OLevel(_, size_bias) => size_bias
    _ => false
  }
}

///|
pub fn __node_cli_trap_mode_name(value : @cli.TrapMode) -> String {
  match value {
    @cli.TrapMode::Allow => "allow"
    @cli.TrapMode::Never => "never"
  }
}

///|
pub fn __node_wast_spec_run_summary_total_files(
  value : @wast.WastSpecRunSummary,
) -> Int {
  value.total_files
}

///|
pub fn __node_wast_spec_run_summary_passed_files(
  value : @wast.WastSpecRunSummary,
) -> Int {
  value.passed_files
}

///|
pub fn __node_wast_spec_run_summary_skipped_files(
  value : @wast.WastSpecRunSummary,
) -> Int {
  value.skipped_files
}

///|
pub fn __node_wast_spec_run_summary_failed_files(
  value : @wast.WastSpecRunSummary,
) -> Int {
  value.failed_files
}

///|
pub fn __node_wast_spec_run_summary_files_length(
  value : @wast.WastSpecRunSummary,
) -> Int {
  value.files.length()
}

///|
pub fn __node_wast_spec_run_summary_files_get(
  value : @wast.WastSpecRunSummary,
  index : Int,
) -> @wast.WastSpecFileReport {
  value.files[index]
}

///|
pub fn __node_wast_spec_file_report_path(
  value : @wast.WastSpecFileReport,
) -> String {
  value.path
}

///|
pub fn __node_wast_spec_file_report_status(
  value : @wast.WastSpecFileReport,
) -> @wast.WastSpecFileStatus {
  value.status
}

///|
pub fn __node_wast_spec_file_status_kind(
  value : @wast.WastSpecFileStatus,
) -> String {
  match value {
    @wast.WastSpecFileStatus::Passed => "passed"
    @wast.WastSpecFileStatus::Skipped(_) => "skipped"
    @wast.WastSpecFileStatus::Failed(_) => "failed"
  }
}

///|
pub fn __node_wast_spec_file_status_message(
  value : @wast.WastSpecFileStatus,
) -> String {
  match value {
    @wast.WastSpecFileStatus::Passed => ""
    @wast.WastSpecFileStatus::Skipped(msg) => msg
    @wast.WastSpecFileStatus::Failed(msg) => msg
  }
}

///|
pub fn __node_splitmix_new(seed : UInt64) -> @splitmix.RandomState {
  @splitmix.new(seed~)
}
