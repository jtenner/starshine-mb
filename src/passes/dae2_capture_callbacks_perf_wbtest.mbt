///|
fn dae2_capture_callbacks_perf_run(
  it : @bench.T,
  count : Int,
  original : Bool,
  flatten : Bool,
) -> Unit {
  let body = Array::makei(count, fn(i) {
    "call $produce local.set \{i + 1} local.get 0 call $consume local.get \{i + 1} drop"
  }).join(" ")
  let locals = Array::make(count, "i32").join(" ")
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (param i32) (local \{locals}) \{body}))",
  )
  let func = input.code_sec.unwrap().0[0]
  let @lib.Func(_, @lib.Expr(instrs)) = func
  let context = @ir.hot_module_context_from_module(input)
  let effects = Some(fn(instr) {
    dae2_capture_stack_effect(instr, input, context)
  })
  let empty = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
  let env = @validate.Env::new().with_module(input)
  let params = [@lib.ValType::i32()]
  it.bench(fn() {
    if flatten {
      it.keep(
        if original {
          callback_reference_pass_lower_flatten_branchless_blocks(instrs, env)
        } else {
          pass_lower_flatten_branchless_blocks(instrs, env)
        },
      )
    } else {
      it.keep(
        if original {
          callback_reference_pass_lower_compact_captures_with_map(
            func,
            empty,
            params,
            stack_effects=effects,
          )
        } else {
          pass_lower_compact_captures_with_map(
            func,
            empty,
            params,
            stack_effects=effects,
          )
        },
      )
    }
  })
}

///|
test "bench capture callbacks 8 original captures" (it : @bench.T) {
  dae2_capture_callbacks_perf_run(it, 8, true, false)
}

///|
test "bench capture callbacks 8 original branchless" (it : @bench.T) {
  dae2_capture_callbacks_perf_run(it, 8, true, true)
}

///|
test "bench capture callbacks 8 reuse captures" (it : @bench.T) {
  dae2_capture_callbacks_perf_run(it, 8, false, false)
}

///|
test "bench capture callbacks 8 reuse branchless" (it : @bench.T) {
  dae2_capture_callbacks_perf_run(it, 8, false, true)
}

///|
test "bench capture callbacks 64 original captures" (it : @bench.T) {
  dae2_capture_callbacks_perf_run(it, 64, true, false)
}

///|
test "bench capture callbacks 64 original branchless" (it : @bench.T) {
  dae2_capture_callbacks_perf_run(it, 64, true, true)
}

///|
test "bench capture callbacks 64 reuse captures" (it : @bench.T) {
  dae2_capture_callbacks_perf_run(it, 64, false, false)
}

///|
test "bench capture callbacks 64 reuse branchless" (it : @bench.T) {
  dae2_capture_callbacks_perf_run(it, 64, false, true)
}

///|
test "bench capture callbacks 512 original captures" (it : @bench.T) {
  dae2_capture_callbacks_perf_run(it, 512, true, false)
}

///|
test "bench capture callbacks 512 original branchless" (it : @bench.T) {
  dae2_capture_callbacks_perf_run(it, 512, true, true)
}

///|
test "bench capture callbacks 512 reuse captures" (it : @bench.T) {
  dae2_capture_callbacks_perf_run(it, 512, false, false)
}

///|
test "bench capture callbacks 512 reuse branchless" (it : @bench.T) {
  dae2_capture_callbacks_perf_run(it, 512, false, true)
}
