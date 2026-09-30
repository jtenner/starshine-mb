///|
fn signature_lookup_bench(
  it : @bench.T,
  count : Int,
  cold : Bool,
  reference : Bool,
) -> Unit {
  let module_ = signature_lookup_fixture(count)
  @validate.validate_module(module_).unwrap()
  let context = @ir.hot_module_context_from_module(module_)
  let state = HotPipelineModuleState::new()
  ignore(
    run_hot_pipeline_require_module_ctx(
      module_,
      state,
      HotPipelineOptions::new(),
    ),
  )
  let ids = Array::makei(count, fn(i) {
    @lib.FuncIdx::new(i.reinterpret_as_uint())
  })
  for id in ids {
    let expected = signature_lookup_reference_params(module_, id).unwrap()
    if run_hot_pipeline_required_raw_func_params(module_, context, id, state) !=
      expected {
      abort("signature lookup changed parameter types")
    }
  }
  it.bench(fn() {
    let snapshot = if cold { HotPipelineModuleState::new() } else { state }
    for id in ids {
      it.keep(
        if reference {
          signature_lookup_reference_params(module_, id).unwrap()
        } else {
          run_hot_pipeline_required_raw_func_params(
            module_, context, id, snapshot,
          )
        },
      )
    }
  })
}

///|
test "bench raw signatures functions=8 warm reference" (it : @bench.T) {
  signature_lookup_bench(it, 8, false, true)
}

///|
test "bench raw signatures functions=8 warm selected" (it : @bench.T) {
  signature_lookup_bench(it, 8, false, false)
}

///|
test "bench raw signatures functions=8 cold reference" (it : @bench.T) {
  signature_lookup_bench(it, 8, true, true)
}

///|
test "bench raw signatures functions=8 cold selected" (it : @bench.T) {
  signature_lookup_bench(it, 8, true, false)
}

///|
test "bench raw signatures functions=128 warm reference" (it : @bench.T) {
  signature_lookup_bench(it, 128, false, true)
}

///|
test "bench raw signatures functions=128 warm selected" (it : @bench.T) {
  signature_lookup_bench(it, 128, false, false)
}

///|
test "bench raw signatures functions=128 cold reference" (it : @bench.T) {
  signature_lookup_bench(it, 128, true, true)
}

///|
test "bench raw signatures functions=128 cold selected" (it : @bench.T) {
  signature_lookup_bench(it, 128, true, false)
}

///|
test "bench raw signatures functions=1024 warm reference" (it : @bench.T) {
  signature_lookup_bench(it, 1024, false, true)
}

///|
test "bench raw signatures functions=1024 warm selected" (it : @bench.T) {
  signature_lookup_bench(it, 1024, false, false)
}

///|
test "bench raw signatures functions=1024 cold reference" (it : @bench.T) {
  signature_lookup_bench(it, 1024, true, true)
}

///|
test "bench raw signatures functions=1024 cold selected" (it : @bench.T) {
  signature_lookup_bench(it, 1024, true, false)
}
