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
using @optimization {
  add_pass_to_pipeline,
  default_optimize_pipeline,
  type OptimizePass,
  type PassGroup,
  type PassKind,
  type PipelineEntry,
  type PipelineFeatures,
  type PipelineGlobal,
  type PipelineScratch,
  type ValidationKind,
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
