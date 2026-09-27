///|
fn oi_module_env_bench(it : @bench.T, count : Int, shared : Bool) -> Unit {
  let input = oi_module_env_fixture(count)
  let ctx = @ir.hot_module_context_from_module(input)
  let options = HotPipelineOptions::new()
  let funcs = input.code_sec.unwrap().0
  let check_state = HotPipelineModuleState::new()
  let provider = fn() {
    run_hot_pipeline_require_validation_module_env(input, check_state, options)
  }
  for index in 0..<count {
    let original = funcs[index]
    let before = run_hot_pipeline_optimize_instructions_cleanup_tuple_wrappers(
      original,
      Some(original),
      input,
      module_ctx=Some(ctx),
    )
    let after = run_hot_pipeline_optimize_instructions_cleanup_tuple_wrappers(
      original,
      Some(original),
      input,
      module_ctx=Some(ctx),
      module_env_provider=Some(provider),
    )
    if before != after || !after.1 {
      abort("tuple cleanup environment changed output")
    }
  }
  it.bench(fn() {
    let state = HotPipelineModuleState::new()
    let provider = fn() {
      run_hot_pipeline_require_validation_module_env(input, state, options)
    }
    for index in 0..<count {
      let original = funcs[index]
      it.keep(
        run_hot_pipeline_optimize_instructions_cleanup_tuple_wrappers(
          original,
          Some(original),
          input,
          module_ctx=Some(ctx),
          module_env_provider=if shared { Some(provider) } else { None },
        ),
      )
    }
  })
}

///|
test "bench OI tuple cleanup separate environments functions=128" (
  it : @bench.T,
) {
  oi_module_env_bench(it, 128, false)
}

///|
test "bench OI tuple cleanup shared environment functions=128" (it : @bench.T) {
  oi_module_env_bench(it, 128, true)
}

///|
test "bench OI tuple cleanup separate environments functions=512" (
  it : @bench.T,
) {
  oi_module_env_bench(it, 512, false)
}

///|
test "bench OI tuple cleanup shared environment functions=512" (it : @bench.T) {
  oi_module_env_bench(it, 512, true)
}
