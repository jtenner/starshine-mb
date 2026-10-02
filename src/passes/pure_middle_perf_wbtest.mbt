///|
fn sl_pure_middle_bench(
  it : @bench.T,
  width : Int,
  repeated_uses : Bool,
  reference : Bool,
) -> Unit raise {
  let stores = Array::makei(width, fn(i) { "i32.const \{i + 7} local.set \{i}" }).join(
    " ",
  )
  let reads = Array::makei(width, fn(i) { "local.get \{i} call $consume" }).join(
    " ",
  )
  let uses = if repeated_uses { reads + " " + reads } else { reads }
  let local_types = Array::make(width, "i32").join(" ")
  let input = pass_test_module_from_wat(
    "(module (import \"host\" \"consume\" (func $consume (param i32))) (func (local \{local_types}) \{stores} \{uses}))",
  )
  @validate.validate_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let env = @validate.Env::new()
    .with_module(input)
    .with_locals(locals)
    .with_return_type(Some([]))
  let saved = @binary.encode_module(input).unwrap()
  let actual = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_flat(
    body, env,
  )
  assert_eq(actual, sl_pure_middle_reference_flat(body, env))
  if repeated_uses {
    assert_eq(actual.1, 0)
  } else {
    assert_true(actual.1 > 0)
  }
  it.bench(fn() {
    it.keep(
      if reference {
        sl_pure_middle_reference_flat(body, env)
      } else {
        run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_flat(
          body, env,
        )
      },
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench pure middle blocked-multiple-use width=8 original" (it : @bench.T) {
  sl_pure_middle_bench(it, 8, true, true)
}

///|
test "bench pure middle blocked-multiple-use width=8 bounded" (it : @bench.T) {
  sl_pure_middle_bench(it, 8, true, false)
}

///|
test "bench pure middle blocked-multiple-use width=64 original" (it : @bench.T) {
  sl_pure_middle_bench(it, 64, true, true)
}

///|
test "bench pure middle blocked-multiple-use width=64 bounded" (it : @bench.T) {
  sl_pure_middle_bench(it, 64, true, false)
}

///|
test "bench pure middle blocked-multiple-use width=256 original" (it : @bench.T) {
  sl_pure_middle_bench(it, 256, true, true)
}

///|
test "bench pure middle blocked-multiple-use width=256 bounded" (it : @bench.T) {
  sl_pure_middle_bench(it, 256, true, false)
}

///|
test "bench pure middle active width=1 original" (it : @bench.T) {
  sl_pure_middle_bench(it, 1, false, true)
}

///|
test "bench pure middle active width=1 bounded" (it : @bench.T) {
  sl_pure_middle_bench(it, 1, false, false)
}

///|
test "bench pure middle active width=8 original" (it : @bench.T) {
  sl_pure_middle_bench(it, 8, false, true)
}

///|
test "bench pure middle active width=8 bounded" (it : @bench.T) {
  sl_pure_middle_bench(it, 8, false, false)
}

///|
test "bench pure middle active width=64 original" (it : @bench.T) {
  sl_pure_middle_bench(it, 64, false, true)
}

///|
test "bench pure middle active width=64 bounded" (it : @bench.T) {
  sl_pure_middle_bench(it, 64, false, false)
}
