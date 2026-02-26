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
}

///|
using @lib {type Module}

///|
using @passes {
  optimize_module_with_options,
  optimize_module_with_options_trace,
  default_function_optimization_passes,
  default_global_optimization_pre_passes,
  default_global_optimization_post_passes,
  type ModulePass,
  type InliningOptions,
  type OptimizeOptions,
}

///|
using @validate {gen_valid_module, validate_module}

///|
using @json {parse}
