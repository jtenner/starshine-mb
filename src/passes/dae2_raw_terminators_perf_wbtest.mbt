///|
fn raw_terminator_perf_run(
  it : @bench.T,
  width : Int32,
  trap : Bool,
  reference : Bool,
) -> Unit raise {
  let item = if trap {
    "local.get 0 if unreachable end"
  } else {
    "local.get 0 if local.get 1 return end"
  }
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i32 i64) (result i32) \{Array::make(width, item).join(" ")} local.get 2) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let old_lifts = [0]
  let new_lifts = [0]
  let old = dae2_run_module_pass(
    input,
    false,
    raw_conditionals=false,
    analysis_lifts=Some(old_lifts),
  ).unwrap()
  let output = dae2_run_module_pass(
    input,
    false,
    analysis_lifts=Some(new_lifts),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(old).unwrap(),
  )
  assert_eq(old_lifts[0], 1)
  assert_eq(new_lifts[0], 0)
  it.bench(fn() {
    it.keep(
      dae2_run_module_pass(input, false, raw_conditionals=!reference).unwrap(),
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench raw terminators return width=4 HOT" (it : @bench.T) {
  raw_terminator_perf_run(it, 4, false, true)
}

///|
test "bench raw terminators return width=4 raw" (it : @bench.T) {
  raw_terminator_perf_run(it, 4, false, false)
}

///|
test "bench raw terminators return width=64 HOT" (it : @bench.T) {
  raw_terminator_perf_run(it, 64, false, true)
}

///|
test "bench raw terminators return width=64 raw" (it : @bench.T) {
  raw_terminator_perf_run(it, 64, false, false)
}

///|
test "bench raw terminators trap width=4 HOT" (it : @bench.T) {
  raw_terminator_perf_run(it, 4, true, true)
}

///|
test "bench raw terminators trap width=4 raw" (it : @bench.T) {
  raw_terminator_perf_run(it, 4, true, false)
}

///|
test "bench raw terminators trap width=64 HOT" (it : @bench.T) {
  raw_terminator_perf_run(it, 64, true, true)
}

///|
test "bench raw terminators trap width=64 raw" (it : @bench.T) {
  raw_terminator_perf_run(it, 64, true, false)
}
