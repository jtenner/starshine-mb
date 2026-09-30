///|
// Compare only conditional admission; both controls retain established flat raw
// analysis and rewrite. Setup, validation, ownership and byte checks stay out
// of the timed loop.
fn raw_conditional_perf_run(
  it : @bench.T,
  helpers : Int,
  width : Int,
  local_count : Int,
  shape : Int,
  reference : Bool,
) -> Unit raise {
  let locals = Array::make(local_count, "i32").join(" ")
  let item = match shape {
    0 => "local.get 0 if (result i32) local.get 1 else local.get 2 end i32.add"
    1 =>
      "local.get 0 if local.get 1 local.set 4 else local.get 2 local.set 4 end local.get 4 i32.add"
    _ => "local.get 1 local.get 2 i32.add i32.add"
  }
  let prefix = if shape == 3 { "loop nop end" } else { "" }
  let bodies = Array::makei(helpers, fn(i) {
    "(func $h\{i} (param i32 i32 i32 i64) (result i32) (local \{locals}) \{prefix} i32.const 0 \{Array::make(width, item).join(" ")})"
  }).join(" ")
  let calls = Array::makei(helpers, fn(i) {
    "local.get 0 local.get 1 local.get 2 i64.const 9 call $h\{i} i32.add"
  }).join(" ")
  let input = pass_test_module_from_wat(
    "(module \{bodies} (func (export \"run\") (param i32 i32 i32) (result i32) i32.const 0 \{calls}))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let old_lifts = [0]
  let new_lifts = [0]
  let old = dae2_run_module_pass(
    input,
    false,
    raw_conditionals=false,
    analysis_lifts=Some(old_lifts),
  ).unwrap()
  let output = dae2_run_module_pass(
    input,
    false,
    analysis_lifts=Some(new_lifts),
  ).unwrap()
  @validate.validate_module(old).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(old).unwrap(),
  )
  assert_eq(new_lifts[0], if shape == 3 { helpers } else { 0 })
  assert_eq(old_lifts[0], if shape == 2 { 0 } else { helpers })
  let context = @ir.hot_module_context_from_module(output)
  let @lib.FuncType(params, _) = @ir.hot_module_resolve_func_type(
    context,
    @lib.FuncIdx::new(0U),
  ).unwrap()
  assert_eq(params.length(), if shape < 2 { 3 } else { 2 })
  it.bench(fn() {
    it.keep(
      dae2_run_module_pass(input, false, raw_conditionals=!reference).unwrap(),
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench raw conditional tiny results original" (it : @bench.T) {
  raw_conditional_perf_run(it, 1, 8, 8, 0, true)
}

///|
test "bench raw conditional tiny results ranged" (it : @bench.T) {
  raw_conditional_perf_run(it, 1, 8, 8, 0, false)
}

///|
test "bench raw conditional tiny writes original" (it : @bench.T) {
  raw_conditional_perf_run(it, 1, 8, 8, 1, true)
}

///|
test "bench raw conditional tiny writes ranged" (it : @bench.T) {
  raw_conditional_perf_run(it, 1, 8, 8, 1, false)
}

///|
test "bench raw conditional tiny flat original" (it : @bench.T) {
  raw_conditional_perf_run(it, 1, 8, 8, 2, true)
}

///|
test "bench raw conditional tiny flat ranged" (it : @bench.T) {
  raw_conditional_perf_run(it, 1, 8, 8, 2, false)
}

///|
test "bench raw conditional tiny loop original" (it : @bench.T) {
  raw_conditional_perf_run(it, 1, 8, 8, 3, true)
}

///|
test "bench raw conditional tiny loop ranged" (it : @bench.T) {
  raw_conditional_perf_run(it, 1, 8, 8, 3, false)
}

///|
test "bench raw conditional wide results original" (it : @bench.T) {
  raw_conditional_perf_run(it, 32, 128, 8, 0, true)
}

///|
test "bench raw conditional wide results ranged" (it : @bench.T) {
  raw_conditional_perf_run(it, 32, 128, 8, 0, false)
}

///|
test "bench raw conditional wide writes original" (it : @bench.T) {
  raw_conditional_perf_run(it, 32, 128, 8, 1, true)
}

///|
test "bench raw conditional wide writes ranged" (it : @bench.T) {
  raw_conditional_perf_run(it, 32, 128, 8, 1, false)
}

///|
test "bench raw conditional wide flat original" (it : @bench.T) {
  raw_conditional_perf_run(it, 32, 128, 8, 2, true)
}

///|
test "bench raw conditional wide flat ranged" (it : @bench.T) {
  raw_conditional_perf_run(it, 32, 128, 8, 2, false)
}

///|
test "bench raw conditional wide loop original" (it : @bench.T) {
  raw_conditional_perf_run(it, 32, 128, 8, 3, true)
}

///|
test "bench raw conditional wide loop ranged" (it : @bench.T) {
  raw_conditional_perf_run(it, 32, 128, 8, 3, false)
}

///|
test "bench raw conditional sparse results original" (it : @bench.T) {
  raw_conditional_perf_run(it, 1, 128, 4096, 0, true)
}

///|
test "bench raw conditional sparse results ranged" (it : @bench.T) {
  raw_conditional_perf_run(it, 1, 128, 4096, 0, false)
}

///|
test "bench raw conditional sparse writes original" (it : @bench.T) {
  raw_conditional_perf_run(it, 1, 128, 4096, 1, true)
}

///|
test "bench raw conditional sparse writes ranged" (it : @bench.T) {
  raw_conditional_perf_run(it, 1, 128, 4096, 1, false)
}

///|
test "bench raw conditional sparse flat original" (it : @bench.T) {
  raw_conditional_perf_run(it, 1, 128, 4096, 2, true)
}

///|
test "bench raw conditional sparse flat ranged" (it : @bench.T) {
  raw_conditional_perf_run(it, 1, 128, 4096, 2, false)
}

///|
test "bench raw conditional sparse loop original" (it : @bench.T) {
  raw_conditional_perf_run(it, 1, 128, 4096, 3, true)
}

///|
test "bench raw conditional sparse loop ranged" (it : @bench.T) {
  raw_conditional_perf_run(it, 1, 128, 4096, 3, false)
}
