///|
fn sl_producer_range_bench(
  it : @bench.T,
  width : Int,
  shape : Int,
  reference : Bool,
) -> Unit raise {
  let fragment = match shape {
    0 => "i32.const 7 local.set 0 nop local.get 0 call $consume"
    1 =>
      "i32.const 3 i32.const 4 i32.add local.set 0 nop local.get 0 call $consume"
    2 => "call $produce local.set 0 nop local.get 0 call $consume"
    3 => "call $produce local.set 0 call $tick local.get 0 call $consume"
    _ => "call $produce call $consume nop"
  }
  let (input, env, instrs) = sl_balanced_range_fixture(
    Array::make(width, fragment).join(" "),
    "i32",
  )
  let saved = @binary.encode_module(input).unwrap()
  let pure = shape < 2 || shape == 5
  let actual = if pure {
    run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_flat(
      instrs, env,
    )
  } else {
    run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets_flat(
      instrs, env,
    )
  }
  let expected = if pure {
    sl_producer_reference_pure_suffix_local_sets_flat(instrs, env)
  } else {
    sl_producer_reference_effectful_suffix_local_gets_flat(instrs, env)
  }
  assert_eq(actual, expected)
  let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual.0))]),
    ),
  ).unwrap()
  it.bench(fn() {
    it.keep(
      if reference {
        if pure {
          sl_producer_reference_pure_suffix_local_sets_flat(instrs, env)
        } else {
          sl_producer_reference_effectful_suffix_local_gets_flat(instrs, env)
        }
      } else if pure {
        run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_flat(
          instrs, env,
        )
      } else {
        run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets_flat(
          instrs, env,
        )
      },
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench producer ranges 8 constant copies original" (it : @bench.T) {
  sl_producer_range_bench(it, 8, 0, true)
}

///|
test "bench producer ranges 8 constant copies ranged" (it : @bench.T) {
  sl_producer_range_bench(it, 8, 0, false)
}

///|
test "bench producer ranges 8 pure expressions original" (it : @bench.T) {
  sl_producer_range_bench(it, 8, 1, true)
}

///|
test "bench producer ranges 8 pure expressions ranged" (it : @bench.T) {
  sl_producer_range_bench(it, 8, 1, false)
}

///|
test "bench producer ranges 8 active effects original" (it : @bench.T) {
  sl_producer_range_bench(it, 8, 2, true)
}

///|
test "bench producer ranges 8 active effects ranged" (it : @bench.T) {
  sl_producer_range_bench(it, 8, 2, false)
}

///|
test "bench producer ranges 8 blocked effects original" (it : @bench.T) {
  sl_producer_range_bench(it, 8, 3, true)
}

///|
test "bench producer ranges 8 blocked effects ranged" (it : @bench.T) {
  sl_producer_range_bench(it, 8, 3, false)
}

///|
test "bench producer ranges 8 no effectful candidates original" (it : @bench.T) {
  sl_producer_range_bench(it, 8, 4, true)
}

///|
test "bench producer ranges 8 no effectful candidates ranged" (it : @bench.T) {
  sl_producer_range_bench(it, 8, 4, false)
}

///|
test "bench producer ranges 8 no pure candidates original" (it : @bench.T) {
  sl_producer_range_bench(it, 8, 5, true)
}

///|
test "bench producer ranges 8 no pure candidates ranged" (it : @bench.T) {
  sl_producer_range_bench(it, 8, 5, false)
}

///|
test "bench producer ranges 512 constant copies original" (it : @bench.T) {
  sl_producer_range_bench(it, 512, 0, true)
}

///|
test "bench producer ranges 512 constant copies ranged" (it : @bench.T) {
  sl_producer_range_bench(it, 512, 0, false)
}

///|
test "bench producer ranges 512 pure expressions original" (it : @bench.T) {
  sl_producer_range_bench(it, 512, 1, true)
}

///|
test "bench producer ranges 512 pure expressions ranged" (it : @bench.T) {
  sl_producer_range_bench(it, 512, 1, false)
}

///|
test "bench producer ranges 512 active effects original" (it : @bench.T) {
  sl_producer_range_bench(it, 512, 2, true)
}

///|
test "bench producer ranges 512 active effects ranged" (it : @bench.T) {
  sl_producer_range_bench(it, 512, 2, false)
}

///|
test "bench producer ranges 512 blocked effects original" (it : @bench.T) {
  sl_producer_range_bench(it, 512, 3, true)
}

///|
test "bench producer ranges 512 blocked effects ranged" (it : @bench.T) {
  sl_producer_range_bench(it, 512, 3, false)
}

///|
test "bench producer ranges 512 no effectful candidates original" (
  it : @bench.T,
) {
  sl_producer_range_bench(it, 512, 4, true)
}

///|
test "bench producer ranges 512 no effectful candidates ranged" (it : @bench.T) {
  sl_producer_range_bench(it, 512, 4, false)
}

///|
test "bench producer ranges 512 no pure candidates original" (it : @bench.T) {
  sl_producer_range_bench(it, 512, 5, true)
}

///|
test "bench producer ranges 512 no pure candidates ranged" (it : @bench.T) {
  sl_producer_range_bench(it, 512, 5, false)
}
