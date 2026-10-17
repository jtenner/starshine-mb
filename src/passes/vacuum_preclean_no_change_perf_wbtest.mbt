///|
fn vacuum_preclean_no_change_bench_fixture(
  width : Int32,
  mode : Int32,
) -> @lib.Module {
  let loops = Array::makei(width, fn(index) {
    let debris = if mode == 1 || (mode == 2 && index + 1 == width) {
      "nop"
    } else {
      ""
    }
    "loop \{debris} local.get 0 i32.load local.set 1 local.get 1 call 0 end"
  }).join(" ")
  pass_test_module_from_wat(
    "(module (import \"env\" \"effect\" (func (param i32))) (memory 1) (func (export \"run\") (param i32) (result i32) (local i32) \{loops} local.get 1))",
  )
}

///|
// Use this exact test source in both frozen-before and candidate native builds.
// The paired external harness must record each executable/source identity.
fn vacuum_preclean_no_change_bench(
  it : @bench.T,
  width : Int32,
  mode : Int32,
) -> Unit raise {
  let input = vacuum_preclean_no_change_bench_fixture(width, mode)
  let expected = vacuum_preclean_no_change_bench_fixture(width, 0)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let body = vacuum_preclean_no_change_body(input)
  let (actual, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    body,
    None,
  )
  assert_eq(changed, mode != 0)
  assert_eq(actual, vacuum_preclean_no_change_body(expected))
  let output = vacuum_preclean_no_change_output(input, actual)
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  it.bench(fn() {
    it.keep(run_hot_pipeline_raw_vacuum_preclean_instrs(body, None))
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("paired native vacuum preclean cold control")
test "bench vacuum preclean cold32" (it : @bench.T) {
  vacuum_preclean_no_change_bench(it, 32, 0)
}

///|
#skip("paired native vacuum preclean active control")
test "bench vacuum preclean active32" (it : @bench.T) {
  vacuum_preclean_no_change_bench(it, 32, 1)
}

///|
#skip("paired native vacuum preclean mixed control")
test "bench vacuum preclean mixed32" (it : @bench.T) {
  vacuum_preclean_no_change_bench(it, 32, 2)
}

///|
#skip("paired native vacuum preclean cold control")
test "bench vacuum preclean cold256" (it : @bench.T) {
  vacuum_preclean_no_change_bench(it, 256, 0)
}

///|
#skip("paired native vacuum preclean active control")
test "bench vacuum preclean active256" (it : @bench.T) {
  vacuum_preclean_no_change_bench(it, 256, 1)
}

///|
#skip("paired native vacuum preclean mixed control")
test "bench vacuum preclean mixed256" (it : @bench.T) {
  vacuum_preclean_no_change_bench(it, 256, 2)
}
