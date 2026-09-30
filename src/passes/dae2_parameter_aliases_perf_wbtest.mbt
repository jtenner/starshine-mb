///|
fn dae2_parameter_aliases_perf_run(
  it : @bench.T,
  count : Int,
  original : Bool,
  tee? : Bool = false,
) -> Unit {
  let body = Array::makei(count, fn(i) {
    if tee {
      "local.get 0 local.tee \{i + 1} call $consume local.get \{i + 1} call $consume"
    } else {
      "local.get 0 local.set \{i + 1} local.get \{i + 1} call $consume local.get \{i + 1} call $consume"
    }
  }).join(" ")
  let locals = Array::make(count, "i32").join(" ")
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (param i32) (local \{locals}) \{body}))",
  )
  it.bench(fn() {
    it.keep(
      if original {
        dae2_parameter_aliases_reference_cleanup(input)
      } else {
        dae2_cleanup_captures(input)
      },
    )
  })
}

///|
test "bench parameter aliases 8 original" (it : @bench.T) {
  dae2_parameter_aliases_perf_run(it, 8, true)
}

///|
test "bench parameter aliases 8 propagate" (it : @bench.T) {
  dae2_parameter_aliases_perf_run(it, 8, false)
}

///|
test "bench parameter aliases 64 original" (it : @bench.T) {
  dae2_parameter_aliases_perf_run(it, 64, true)
}

///|
test "bench parameter aliases 64 propagate" (it : @bench.T) {
  dae2_parameter_aliases_perf_run(it, 64, false)
}

///|
test "bench parameter aliases 512 original" (it : @bench.T) {
  dae2_parameter_aliases_perf_run(it, 512, true)
}

///|
test "bench parameter aliases 512 propagate" (it : @bench.T) {
  dae2_parameter_aliases_perf_run(it, 512, false)
}

///|
fn dae2_parameter_aliases_no_work_perf(
  it : @bench.T,
  count : Int,
  original : Bool,
) -> Unit {
  let body = Array::makei(count, fn(i) {
    "i32.const 7 local.set \{i + 1} local.get \{i + 1} call $consume local.get \{i + 1} call $consume"
  }).join(" ")
  let locals = Array::make(count, "i32").join(" ")
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (param i32) (local \{locals}) \{body}))",
  )
  it.bench(fn() {
    it.keep(
      if original {
        dae2_parameter_aliases_reference_cleanup(input)
      } else {
        dae2_cleanup_captures(input)
      },
    )
  })
}

///|
test "bench parameter aliases 8 no-work original" (it : @bench.T) {
  dae2_parameter_aliases_no_work_perf(it, 8, true)
}

///|
test "bench parameter aliases 8 no-work guarded" (it : @bench.T) {
  dae2_parameter_aliases_no_work_perf(it, 8, false)
}

///|
test "bench parameter aliases 512 no-work original" (it : @bench.T) {
  dae2_parameter_aliases_no_work_perf(it, 512, true)
}

///|
test "bench parameter aliases 512 no-work guarded" (it : @bench.T) {
  dae2_parameter_aliases_no_work_perf(it, 512, false)
}

///|
test "bench parameter aliases 8 tee original" (it : @bench.T) {
  dae2_parameter_aliases_perf_run(it, 8, true, tee=true)
}

///|
test "bench parameter aliases 8 tee propagate" (it : @bench.T) {
  dae2_parameter_aliases_perf_run(it, 8, false, tee=true)
}

///|
test "bench parameter aliases 64 tee original" (it : @bench.T) {
  dae2_parameter_aliases_perf_run(it, 64, true, tee=true)
}

///|
test "bench parameter aliases 64 tee propagate" (it : @bench.T) {
  dae2_parameter_aliases_perf_run(it, 64, false, tee=true)
}

///|
test "bench parameter aliases 512 tee original" (it : @bench.T) {
  dae2_parameter_aliases_perf_run(it, 512, true, tee=true)
}

///|
test "bench parameter aliases 512 tee propagate" (it : @bench.T) {
  dae2_parameter_aliases_perf_run(it, 512, false, tee=true)
}
