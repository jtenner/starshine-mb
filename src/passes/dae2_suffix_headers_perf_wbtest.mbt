///|
fn dae2_suffix_headers_perf_fixture(
  count : Int32,
  width : Int32,
  typed : Bool,
) -> @lib.Module {
  let definitions = Array::makei(count, fn(index) {
    if typed {
      let calls = Array::make(width, "local.get 0 i32.const 9 call $sink").join(
        " ",
      )
      "(func (export \"run\{index}\") (type $entry) local.get 0 i32.const 3 i32.and loop (type $entry) local.set 0 \{calls} local.get 0 i32.const 1 i32.sub local.tee 0 i32.const 0 i32.gt_s if local.get 0 br 1 end end)"
    } else {
      let reads = Array::make(
        width, "local.get 0 global.set $g local.get 1 global.set $wide",
      ).join(" ")
      "(func $h\{index} (param i32 i64 f32 f64) i32.const 7 local.set 0 i64.const 8 local.set 1 loop \{reads} end) (func (export \"run\{index}\") i32.const 9 i64.const 10 f32.const 11 f64.const 12 call $h\{index})"
    }
  }).join(" ")
  pass_test_module_from_wat(
    "(module (type $entry (func (param i32))) (global $g (mut i32) (i32.const 0)) (global $wide (mut i64) (i64.const 0)) (func $sink (param i32 i32) local.get 0 global.set $g) \{definitions})",
  )
}

///|
fn dae2_suffix_headers_bench(
  it : @bench.T,
  count : Int32,
  width : Int32,
  typed : Bool,
  direct : Bool,
) -> Unit raise {
  let input = dae2_suffix_headers_perf_fixture(count, width, typed)
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_run_module_pass(input, false, raw_analysis=false).unwrap()
  let reference = dae2_run_module_pass(
    input,
    false,
    raw_analysis=false,
    stack_suffix_rewrite=false,
  ).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
  // Both lanes include the entire analysis, solve, rewrite and validation.
  // The direct lane also pays for the newly admitted lift provenance rows.
  it.bench(fn() {
    it.keep(
      dae2_run_module_pass(
        input,
        false,
        raw_analysis=false,
        stack_suffix_rewrite=direct,
      ),
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench DAE2 typed suffix functions=1 calls=1 HOT" (it : @bench.T) {
  dae2_suffix_headers_bench(it, 1, 1, true, false)
}

///|
test "bench DAE2 typed suffix functions=1 calls=1 raw" (it : @bench.T) {
  dae2_suffix_headers_bench(it, 1, 1, true, true)
}

///|
test "bench DAE2 typed suffix functions=16 calls=32 HOT" (it : @bench.T) {
  dae2_suffix_headers_bench(it, 16, 32, true, false)
}

///|
test "bench DAE2 typed suffix functions=16 calls=32 raw" (it : @bench.T) {
  dae2_suffix_headers_bench(it, 16, 32, true, true)
}

///|
test "bench DAE2 numeric local replay functions=1 reads=1 HOT" (it : @bench.T) {
  dae2_suffix_headers_bench(it, 1, 1, false, false)
}

///|
test "bench DAE2 numeric local replay functions=1 reads=1 raw" (it : @bench.T) {
  dae2_suffix_headers_bench(it, 1, 1, false, true)
}

///|
test "bench DAE2 numeric local replay functions=16 reads=32 HOT" (it : @bench.T) {
  dae2_suffix_headers_bench(it, 16, 32, false, false)
}

///|
test "bench DAE2 numeric local replay functions=16 reads=32 raw" (it : @bench.T) {
  dae2_suffix_headers_bench(it, 16, 32, false, true)
}
