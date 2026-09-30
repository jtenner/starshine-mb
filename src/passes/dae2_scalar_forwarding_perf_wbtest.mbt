///|
fn dae2_scalar_forwarding_perf_run(
  it : @bench.T,
  count : Int,
  original : Bool,
) -> Unit {
  let body = Array::makei(count, fn(i) {
    "block (result i32) call $produce end local.set \{i + 1} local.get 0 call $consume block (result i32) block (result i32) local.get \{i + 1} end end drop"
  }).join(" ")
  let locals = Array::make(count, "i32").join(" ")
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (param i32) (local \{locals}) \{body}))",
  )
  it.bench(fn() {
    it.keep(
      if original {
        dae2_scalar_forwarding_reference_cleanup(input)
      } else {
        dae2_cleanup_captures(input)
      },
    )
  })
}

///|
test "bench scalar forwarding 8 original" (it : @bench.T) {
  dae2_scalar_forwarding_perf_run(it, 8, true)
}

///|
test "bench scalar forwarding 8 flatten" (it : @bench.T) {
  dae2_scalar_forwarding_perf_run(it, 8, false)
}

///|
test "bench scalar forwarding 64 original" (it : @bench.T) {
  dae2_scalar_forwarding_perf_run(it, 64, true)
}

///|
test "bench scalar forwarding 64 flatten" (it : @bench.T) {
  dae2_scalar_forwarding_perf_run(it, 64, false)
}

///|
test "bench scalar forwarding 512 original" (it : @bench.T) {
  dae2_scalar_forwarding_perf_run(it, 512, true)
}

///|
test "bench scalar forwarding 512 flatten" (it : @bench.T) {
  dae2_scalar_forwarding_perf_run(it, 512, false)
}
