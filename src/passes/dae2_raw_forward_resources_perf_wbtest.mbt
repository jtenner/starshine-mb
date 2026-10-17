///|
fn raw_forward_resource_perf_run(
  it : @bench.T,
  shape : Int32,
  wide : Bool,
  reference : Bool,
) -> Unit raise {
  let input = match shape {
    0 =>
      raw_forward_repeated_function_targets(
        if wide {
          64
        } else {
          8
        },
        if wide {
          256
        } else {
          32
        },
      )
    1 =>
      raw_forward_identical_exits(
        if wide {
          32
        } else {
          8
        },
        if wide {
          128
        } else {
          16
        },
      )
    _ =>
      raw_forward_nested_target_locals(
        if wide {
          64
        } else {
          2
        },
        if wide {
          64
        } else {
          2
        },
      )
  }
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let old = dae2_run_module_pass(input, false, raw_conditionals=false).unwrap()
  let output = dae2_run_module_pass(input, false).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(old).unwrap(),
  )
  let (_, _, candidate) = raw_forward_resource_plan(input)
  assert_eq(candidate is None, shape == 2 && wide)
  it.bench(fn() {
    it.keep(
      dae2_run_module_pass(input, false, raw_conditionals=!reference).unwrap(),
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench raw forward repeated targets payload=8 targets=32 HOT" (
  it : @bench.T,
) {
  raw_forward_resource_perf_run(it, 0, false, true)
}

///|
test "bench raw forward repeated targets payload=8 targets=32 raw" (
  it : @bench.T,
) {
  raw_forward_resource_perf_run(it, 0, false, false)
}

///|
test "bench raw forward repeated targets payload=64 targets=256 HOT" (
  it : @bench.T,
) {
  raw_forward_resource_perf_run(it, 0, true, true)
}

///|
test "bench raw forward repeated targets payload=64 targets=256 raw" (
  it : @bench.T,
) {
  raw_forward_resource_perf_run(it, 0, true, false)
}

///|
test "bench raw forward identical exits locals=8 branches=16 HOT" (
  it : @bench.T,
) {
  raw_forward_resource_perf_run(it, 1, false, true)
}

///|
test "bench raw forward identical exits locals=8 branches=16 raw" (
  it : @bench.T,
) {
  raw_forward_resource_perf_run(it, 1, false, false)
}

///|
test "bench raw forward identical exits locals=32 branches=128 HOT" (
  it : @bench.T,
) {
  raw_forward_resource_perf_run(it, 1, true, true)
}

///|
test "bench raw forward identical exits locals=32 branches=128 raw" (
  it : @bench.T,
) {
  raw_forward_resource_perf_run(it, 1, true, false)
}

///|
test "bench raw forward nested targets depth=2 locals=2 HOT" (it : @bench.T) {
  raw_forward_resource_perf_run(it, 2, false, true)
}

///|
test "bench raw forward nested targets depth=2 locals=2 raw" (it : @bench.T) {
  raw_forward_resource_perf_run(it, 2, false, false)
}

///|
test "bench raw forward nested targets depth=64 locals=64 HOT" (it : @bench.T) {
  raw_forward_resource_perf_run(it, 2, true, true)
}

///|
test "bench raw forward nested targets depth=64 locals=64 raw" (it : @bench.T) {
  raw_forward_resource_perf_run(it, 2, true, false)
}
