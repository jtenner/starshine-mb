///|
fn raw_retained_control_perf_run(
  it : @bench.T,
  controls : Int32,
  reference : Bool,
) -> Unit raise {
  let body = Array::make(
    controls, "local.get 0 if (result i32) local.get 0 local.get 1 i32.const 3 i32.add call $h else local.get 1 local.get 0 i32.const 2 i32.add call $h end global.set $g",
  ).join(" ")
  let input = pass_test_module_from_wat(
    "(module (global $g (mut i32) (i32.const 0)) (func $h (param i32 i32) (result i32) local.get 0) (func (export \"run\") (param i32 i32) (result i32) \{body} global.get $g))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let analysis = [0]
  let rewrite = [0]
  let actual = dae2_run_module_pass(
    input,
    false,
    stack_suffix_rewrite=false,
    analysis_lifts=Some(analysis),
    rewrite_lifts=Some(rewrite),
  ).unwrap()
  let expected = dae2_run_module_pass(
    input,
    false,
    raw_analysis=false,
    raw_rewrite=false,
  ).unwrap()
  @validate.validate_module(actual).unwrap()
  assert_eq(analysis[0], 0)
  assert_eq(rewrite[0], 0)
  assert_eq(
    @binary.encode_module(actual).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  it.bench(fn() {
    it.keep(
      dae2_run_module_pass(
        input,
        false,
        stack_suffix_rewrite=false,
        raw_analysis=!reference,
        raw_rewrite=!reference,
      ).unwrap(),
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench retained scalar controls=1 HOT" (it : @bench.T) {
  raw_retained_control_perf_run(it, 1, true)
}

///|
test "bench retained scalar controls=1 raw" (it : @bench.T) {
  raw_retained_control_perf_run(it, 1, false)
}

///|
test "bench retained scalar controls=32 HOT" (it : @bench.T) {
  raw_retained_control_perf_run(it, 32, true)
}

///|
test "bench retained scalar controls=32 raw" (it : @bench.T) {
  raw_retained_control_perf_run(it, 32, false)
}

///|
test "bench retained scalar controls=256 HOT" (it : @bench.T) {
  raw_retained_control_perf_run(it, 256, true)
}

///|
test "bench retained scalar controls=256 raw" (it : @bench.T) {
  raw_retained_control_perf_run(it, 256, false)
}
