///|
fn dae2_balanced_capture_perf_run(
  it : @bench.T,
  count : Int,
  original : Bool,
) -> Unit {
  let captures = Array::makei(count, fn(i) {
    "call $produce local.set \{i + 1} local.get 0 call $consume local.get \{i + 1} drop"
  }).join(" ")
  let locals = Array::make(count, "i32").join(" ")
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (param i32) (local \{locals}) \{captures}))",
  )
  it.bench(fn() {
    it.keep(
      if original {
        dae2_balanced_capture_reference_cleanup(input)
      } else {
        dae2_cleanup_captures(input)
      },
    )
  })
}

///|
test "bench balanced call captures 8 original" (it : @bench.T) {
  dae2_balanced_capture_perf_run(it, 8, true)
}

///|
test "bench balanced call captures 8 effects" (it : @bench.T) {
  dae2_balanced_capture_perf_run(it, 8, false)
}

///|
test "bench balanced call captures 64 original" (it : @bench.T) {
  dae2_balanced_capture_perf_run(it, 64, true)
}

///|
test "bench balanced call captures 64 effects" (it : @bench.T) {
  dae2_balanced_capture_perf_run(it, 64, false)
}

///|
test "bench balanced call captures 512 original" (it : @bench.T) {
  dae2_balanced_capture_perf_run(it, 512, true)
}

///|
test "bench balanced call captures 512 effects" (it : @bench.T) {
  dae2_balanced_capture_perf_run(it, 512, false)
}
