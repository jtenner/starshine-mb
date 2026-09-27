///|
fn oi_raw_module_env_bench(it : @bench.T, count : Int, shared : Bool) -> Unit {
  let input = oi_raw_module_env_fixture(count)
  let ctx = @ir.hot_module_context_from_module(input)
  let options = HotPipelineOptions::new()
  let descriptor = optimize_instructions_descriptor()
  let funcs = input.code_sec.unwrap().0
  let check_state = HotPipelineModuleState::new()
  let check_provider = fn() {
    run_hot_pipeline_require_validation_module_env(input, check_state, options)
  }
  for index in 0..<count {
    let before = run_hot_pipeline_optimize_instructions_cleanup_tuple_wrappers(
      funcs[index],
      Some(funcs[index]),
      input,
      module_ctx=Some(ctx),
    )
    let after = run_hot_pipeline_optimize_instructions_cleanup_tuple_wrappers(
      funcs[index],
      Some(funcs[index]),
      input,
      module_ctx=Some(ctx),
      module_env_provider=Some(check_provider),
    )
    if before != after || !after.1 {
      abort("raw tuple cleanup changed output")
    }
  }
  it.bench(fn() {
    let state = HotPipelineModuleState::new()
    let provider = fn() {
      run_hot_pipeline_require_validation_module_env(input, state, options)
    }
    for index in 0..<count {
      let result = run_hot_pipeline_raw_optimize_instructions_skip(
        input,
        @lib.FuncIdx::new(index.to_uint()),
        state,
        descriptor,
        options,
      ).unwrap()
      let output = run_hot_pipeline_optimize_instructions_cleanup_tuple_wrappers(
        result.func,
        Some(funcs[index]),
        input,
        module_ctx=Some(ctx),
        module_env_provider=if shared { Some(provider) } else { None },
      )
      it.keep(output)
    }
  })
}

///|
test "bench OI raw tuple return separate environments functions=128" (
  it : @bench.T,
) {
  oi_raw_module_env_bench(it, 128, false)
}

///|
test "bench OI raw tuple return shared environment functions=128" (
  it : @bench.T,
) {
  oi_raw_module_env_bench(it, 128, true)
}

///|
test "bench OI raw tuple return separate environments functions=512" (
  it : @bench.T,
) {
  oi_raw_module_env_bench(it, 512, false)
}

///|
test "bench OI raw tuple return shared environment functions=512" (
  it : @bench.T,
) {
  oi_raw_module_env_bench(it, 512, true)
}
