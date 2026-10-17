///|
fn raw_loop_perf_module(width : Int32, indexed : Bool) -> @lib.Module {
  let locals = Array::make(width, "i32").join(" ")
  let initial = Array::makei(width, fn(i) { "local.get 1 local.set \{i + 4}" }).join(
    " ",
  )
  let writes = Array::makei(width, fn(i) {
    "local.get \{i + 4} i32.const 1 i32.sub local.set \{i + 4}"
  }).join(" ")
  let header = if indexed {
    "local.get 0 loop $again (type $one) drop"
  } else {
    "loop $again"
  }
  let backedge = if indexed {
    "local.get 0 local.get 0 br_if $again drop"
  } else {
    "local.get 0 br_if $again"
  }
  let sum = Array::makei(width, fn(i) {
    if i == 0 {
      "local.get 4"
    } else {
      "local.get \{i + 4} i32.add"
    }
  }).join(" ")
  pass_test_module_from_wat(
    "(module (type $one (func (param i32))) (func $h (param i32 i32 i32 i64) (result i32) (local \{locals}) \{initial} \{header} \{writes} \{backedge} end \{sum}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
  )
}

///|
fn raw_loop_perf_run(
  it : @bench.T,
  wide : Bool,
  indexed : Bool,
  reference : Bool,
) -> Unit raise {
  let input = raw_loop_perf_module(if wide { 128 } else { 4 }, indexed)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let hot = dae2_run_module_pass(input, false, raw_conditionals=false).unwrap()
  let lifts = [0]
  let raw = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
  assert_eq(lifts[0], 0)
  @validate.validate_module(raw).unwrap()
  assert_eq(
    @binary.encode_module(raw).unwrap(),
    @binary.encode_module(hot).unwrap(),
  )
  it.bench(fn() {
    it.keep(
      dae2_run_module_pass(input, false, raw_conditionals=!reference).unwrap(),
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench raw loops locals=4 plain HOT" (it : @bench.T) {
  raw_loop_perf_run(it, false, false, true)
}

///|
test "bench raw loops locals=4 plain raw" (it : @bench.T) {
  raw_loop_perf_run(it, false, false, false)
}

///|
test "bench raw loops locals=128 plain HOT" (it : @bench.T) {
  raw_loop_perf_run(it, true, false, true)
}

///|
test "bench raw loops locals=128 plain raw" (it : @bench.T) {
  raw_loop_perf_run(it, true, false, false)
}

///|
test "bench raw loops locals=4 indexed HOT" (it : @bench.T) {
  raw_loop_perf_run(it, false, true, true)
}

///|
test "bench raw loops locals=4 indexed raw" (it : @bench.T) {
  raw_loop_perf_run(it, false, true, false)
}

///|
test "bench raw loops locals=128 indexed HOT" (it : @bench.T) {
  raw_loop_perf_run(it, true, true, true)
}

///|
test "bench raw loops locals=128 indexed raw" (it : @bench.T) {
  raw_loop_perf_run(it, true, true, false)
}
