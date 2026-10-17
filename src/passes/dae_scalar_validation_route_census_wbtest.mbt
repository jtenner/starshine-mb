///|
/// Diagnostic route checks do not run a core that the command would bypass.
#skip("manual frozen-input scalar certificate dispatcher route census")
test "DAE scalar frozen inputs report actual dispatcher gates" {
  for
    (path, label) in [
      (".tmp/dae-speed-20261016/inputs/small.wasm", "small"),
      (".tmp/dae-speed-20261016/inputs/large.wasm", "large"),
    ] {
    let bytes = @sfs.read_file_bytes(path).unwrap()
    let input = @binary.decode_module(bytes).unwrap()
    let defined = dae_defined_func_count(input)
    let typed_loop = defined >= 32 &&
      run_hot_pipeline_module_has_typeidx_loop(input)
    let bulk_memory = run_hot_pipeline_should_defer_call_bulk_memory_module(
      input, 1000,
    )
    let metadata = pass_module_has_offset_sensitive_metadata(input)
    let emscripten = o4z_size_candidate_has_unsafe_emscripten_main_runtime(
      input,
    )
    let assemblyscript = run_hot_pipeline_module_has_assemblyscript_startup_exported_memory(
        input,
      ) ||
      run_hot_pipeline_module_has_assemblyscript_json_exported_memory_runtime(
        input,
      ) ||
      run_hot_pipeline_module_has_assemblyscript_run_exported_memory_runtime(
        input,
      )
    println(
      "scalar-route input=\{label} defined=\{defined} typed_loop=\{typed_loop} bulk_memory=\{bulk_memory} metadata=\{metadata} emscripten=\{emscripten} assemblyscript=\{assemblyscript}",
    )
  }
}
