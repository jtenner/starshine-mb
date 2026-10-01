///|
fn release_cleanup_scaled_fixture(width : Int) -> String {
  let body = Array::makei(width, fn(i) {
    "local.get 0 i32.load offset=4 local.set \{i + 3} local.get 1 local.get \{i + 3} i32.ge_s drop"
  }).join(" ")
  let locals = Array::make(width, "i32").join(" ")
  "(module (import \"env\" \"combine\" (func $combine (param i32 i32))) (import \"env\" \"release\" (func $release (param i32))) (memory 1) (func (export \"run\") (param i32 i32 i32) (local \{locals}) \{body} local.get 0 local.get 1 call $combine local.get 2 if local.get 0 call $release local.get 1 call $release end))"
}

///|
fn release_cleanup_scaled_bench(it : @bench.T, width : Int) -> Unit raise {
  let input = pass_test_module_from_wat(release_cleanup_scaled_fixture(width))
  let saved = @binary.encode_module(input).unwrap()
  let options = HotPipelineOptions::new()
  let output = run_hot_pipeline(input, options, ["simplify-locals"]).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(release_cleanup_count_sets(body), 0)
  it.bench(fn() {
    it.keep(run_hot_pipeline(input, options, ["simplify-locals"]).unwrap())
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench structured release raw cleanup width=1" (it : @bench.T) {
  release_cleanup_scaled_bench(it, 1)
}

///|
test "bench structured release raw cleanup width=32" (it : @bench.T) {
  release_cleanup_scaled_bench(it, 32)
}

///|
test "bench structured release raw cleanup width=256" (it : @bench.T) {
  release_cleanup_scaled_bench(it, 256)
}
