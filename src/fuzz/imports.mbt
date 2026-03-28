///|
using @binary {decode_module, encode_module, run_binary_roundtrip_fuzz}

///|
using @cmd {run_wasm_smith_fuzz_harness_profile}

///|
using @lib {trace_elapsed_ms, trace_now_ms, trace_now_us}

///|
using @validate {gen_valid_module, validate_module, validation_error_message}

///|
using @fs {write_file_bytes}

///|
using @wast {run_wast_roundtrip_fuzz}

///|
using @wat {run_wat_roundtrip_fuzz}
