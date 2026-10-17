///|
fn raw_structured_replay_perf_run(
  it : @bench.T,
  calls : Int32,
  reference : Bool,
) -> Unit raise {
  let body = Array::make(
    calls, "local.get 0 local.get 1 i32.const 3 i32.add local.get 2 i64.const 9 call $h local.set 3",
  ).join(" ")
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i32 i64) (result i32) local.get 0 local.get 2 i32.add) (func (export \"run\") (param i32 i32 i32) (result i32) (local i32) loop $again \{body} local.get 0 br_if $again end local.get 3))",
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
test "bench recursive scalar replay calls=1 HOT" (it : @bench.T) {
  raw_structured_replay_perf_run(it, 1, true)
}

///|
test "bench recursive scalar replay calls=1 raw" (it : @bench.T) {
  raw_structured_replay_perf_run(it, 1, false)
}

///|
test "bench recursive scalar replay calls=32 HOT" (it : @bench.T) {
  raw_structured_replay_perf_run(it, 32, true)
}

///|
test "bench recursive scalar replay calls=32 raw" (it : @bench.T) {
  raw_structured_replay_perf_run(it, 32, false)
}

///|
test "bench recursive scalar replay calls=256 HOT" (it : @bench.T) {
  raw_structured_replay_perf_run(it, 256, true)
}

///|
test "bench recursive scalar replay calls=256 raw" (it : @bench.T) {
  raw_structured_replay_perf_run(it, 256, false)
}
