///|
using @binary {decode_module, encode_module, run_binary_roundtrip_fuzz}

///|
using @lib {trace_elapsed_ms, trace_now_ms, trace_now_us}

///|
using @validate {
  type GenValidConfig,
  gen_valid_module,
  gen_valid_module_with_config,
  run_validate_invalid_ast_fuzz,
  run_validate_valid_fuzz,
  validate_valid_run_config,
  validate_module,
  validation_error_message,
}

///|
using @fs {create_dir, read_file_sync, write_file_bytes}

///|
using @wast {
  type WastCommand,
  type WastStaticAssertionResult,
  type WastStaticAssertionStage,
  evaluate_wast_static_assertion,
  run_wast_roundtrip_fuzz,
  wast_to_script,
}

///|
using @wat {run_wat_roundtrip_fuzz}
