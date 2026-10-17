///|
fn dae2_raw_local_group_bench(
  it : @bench.T,
  count : Int32,
  raw : Bool,
) -> Unit raise {
  let input = dae2_raw_mixed_tail_fixture("call $value", body_locals=count)
  let saved = @binary.encode_module(input).unwrap()
  let actual = dae2_run_module_pass(input, false, raw_rewrite=raw).unwrap()
  let reference = dae2_run_module_pass(input, false, raw_rewrite=false).unwrap()
  @validate.validate_module(actual).unwrap()
  assert_true(
    @binary.encode_module(actual).unwrap().length() <=
    @binary.encode_module(reference).unwrap().length(),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  it.bench(fn() {
    it.keep(dae2_run_module_pass(input, false, raw_rewrite=raw).unwrap())
  })
}

///|
#skip
test "bench raw mixed local grouping locals=5 HOT" (it : @bench.T) {
  dae2_raw_local_group_bench(it, 5, false)
}

///|
#skip
test "bench raw mixed local grouping locals=5 raw" (it : @bench.T) {
  dae2_raw_local_group_bench(it, 5, true)
}

///|
#skip
test "bench raw mixed local grouping locals=32 HOT" (it : @bench.T) {
  dae2_raw_local_group_bench(it, 32, false)
}

///|
#skip
test "bench raw mixed local grouping locals=32 raw" (it : @bench.T) {
  dae2_raw_local_group_bench(it, 32, true)
}

///|
#skip
test "bench raw mixed local grouping total=128 HOT" (it : @bench.T) {
  dae2_raw_local_group_bench(it, 127, false)
}

///|
#skip
test "bench raw mixed local grouping total=128 raw" (it : @bench.T) {
  dae2_raw_local_group_bench(it, 127, true)
}

///|
#skip
test "bench raw mixed local grouping total=129 HOT" (it : @bench.T) {
  dae2_raw_local_group_bench(it, 128, false)
}

///|
#skip
test "bench raw mixed local grouping total=129 fallback" (it : @bench.T) {
  dae2_raw_local_group_bench(it, 128, true)
}
