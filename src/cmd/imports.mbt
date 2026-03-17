///|
using @binary {
  trait Encode,
  decode_module,
  encode_module,
  type DecodeError,
  type EncodeError,
}

///|
using @cli {
  normalize_cli_path,
  parse_cli_args,
  resolve_pass_flags,
  resolve_traps_never_happen,
  infer_input_format,
  expand_globs_with_adapter,
  type CliInputFormat,
  type CliOptimizationFlag,
  type CliOutputTarget,
  type CliParseError,
  type CliParseResult,
  type TrapMode,
  type CliTracingLevel,
}

///|
using @lib {type Module}

///|
using @passes {
  optimize_find_post_encode_failure_segment_with_probe,
  optimize_module_with_options,
  optimize_module_with_options_trace,
  default_function_optimization_passes,
  default_global_optimization_pre_passes,
  default_global_optimization_post_passes,
  type ModulePass,
  type AbstractTypeRefiningPassProps,
  type InliningOptions,
  type MemoryPackingPassProps,
  type OptimizeOptions,
  type OptimizeTracingLevel,
}

///|
using @diff {render_line_diff}

///|
using @validate {
  type ValidationError,
  gen_valid_module,
  validate_module,
  validation_error_func_idx,
  validation_error_message,
}

///|
using @json {parse}
