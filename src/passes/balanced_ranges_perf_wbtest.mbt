///|
fn sl_balanced_range_bench(
  it : @bench.T,
  width : Int,
  shape : Int,
  reference : Bool,
) -> Unit raise {
  let body = match shape {
    0 =>
      Array::make(
        width, "call $produce local.set 0 nop local.get 0 call $consume",
      ).join(" ")
    1 =>
      "call $produce local.set 0 " +
      Array::make(width, "nop").join(" ") +
      " local.get 0 call $consume"
    2 => Array::make(width, "call $produce call $consume nop").join(" ")
    _ =>
      Array::make(
        width, "call $produce local.set 0 nop local.get 0 call $consume local.get 0 call $consume",
      ).join(" ")
  }
  let (input, env, instrs) = sl_balanced_range_fixture(body, "i32")
  let saved = @binary.encode_module(input).unwrap()
  let actual = run_hot_pipeline_raw_simplify_locals_rewrite_balanced_statement_local_gets_flat(
    instrs, env,
  )
  let expected = sl_balanced_range_reference(instrs, env)
  assert_eq(actual, expected)
  assert_eq(
    actual.1,
    if shape == 0 {
      width
    } else if shape == 1 {
      1
    } else {
      0
    },
  )
  let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual.0))]),
    ),
  ).unwrap()
  it.bench(fn() {
    it.keep(
      if reference {
        sl_balanced_range_reference(instrs, env)
      } else {
        run_hot_pipeline_raw_simplify_locals_rewrite_balanced_statement_local_gets_flat(
          instrs, env,
        )
      },
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench balanced ranges 8 repeated captures original" (it : @bench.T) {
  sl_balanced_range_bench(it, 8, 0, true)
}

///|
test "bench balanced ranges 8 repeated captures ranged" (it : @bench.T) {
  sl_balanced_range_bench(it, 8, 0, false)
}

///|
test "bench balanced ranges 8 intervening statements original" (it : @bench.T) {
  sl_balanced_range_bench(it, 8, 1, true)
}

///|
test "bench balanced ranges 8 intervening statements ranged" (it : @bench.T) {
  sl_balanced_range_bench(it, 8, 1, false)
}

///|
test "bench balanced ranges 8 no candidates original" (it : @bench.T) {
  sl_balanced_range_bench(it, 8, 2, true)
}

///|
test "bench balanced ranges 8 no candidates ranged" (it : @bench.T) {
  sl_balanced_range_bench(it, 8, 2, false)
}

///|
test "bench balanced ranges 8 blocked reads original" (it : @bench.T) {
  sl_balanced_range_bench(it, 8, 3, true)
}

///|
test "bench balanced ranges 8 blocked reads ranged" (it : @bench.T) {
  sl_balanced_range_bench(it, 8, 3, false)
}

///|
test "bench balanced ranges 512 repeated captures original" (it : @bench.T) {
  sl_balanced_range_bench(it, 512, 0, true)
}

///|
test "bench balanced ranges 512 repeated captures ranged" (it : @bench.T) {
  sl_balanced_range_bench(it, 512, 0, false)
}

///|
test "bench balanced ranges 512 intervening statements original" (it : @bench.T) {
  sl_balanced_range_bench(it, 512, 1, true)
}

///|
test "bench balanced ranges 512 intervening statements ranged" (it : @bench.T) {
  sl_balanced_range_bench(it, 512, 1, false)
}

///|
test "bench balanced ranges 512 no candidates original" (it : @bench.T) {
  sl_balanced_range_bench(it, 512, 2, true)
}

///|
test "bench balanced ranges 512 no candidates ranged" (it : @bench.T) {
  sl_balanced_range_bench(it, 512, 2, false)
}

///|
test "bench balanced ranges 512 blocked reads original" (it : @bench.T) {
  sl_balanced_range_bench(it, 512, 3, true)
}

///|
test "bench balanced ranges 512 blocked reads ranged" (it : @bench.T) {
  sl_balanced_range_bench(it, 512, 3, false)
}

///|
fn sl_balanced_range_suffix_bench(
  it : @bench.T,
  width : Int,
  present : Bool,
  reference : Bool,
) -> Unit raise {
  let body = Array::make(width, @lib.Instruction::nop())
  if present {
    body.push(@lib.Instruction::i32_const(@lib.I32(7)))
  }
  let saved = body.copy()
  let env = @validate.Env::new()
  let _ = @validate.Typecheck::typecheck(
    @lib.Expr::new(body),
    @validate.make_state(env, []),
  ).unwrap()
  let expected = sl_balanced_range_reference_suffix(body, 1, env)
  assert_eq(
    run_hot_pipeline_raw_simplify_locals_take_value_suffix(body, 1, env),
    expected,
  )
  it.bench(fn() {
    it.keep(
      if reference {
        sl_balanced_range_reference_suffix(body, 1, env)
      } else {
        run_hot_pipeline_raw_simplify_locals_take_value_suffix(body, 1, env)
      },
    )
  })
  assert_eq(body, saved)
}

///|
test "bench suffix wrapper 0 present original" (it : @bench.T) {
  sl_balanced_range_suffix_bench(it, 0, true, true)
}

///|
test "bench suffix wrapper 0 present ranged" (it : @bench.T) {
  sl_balanced_range_suffix_bench(it, 0, true, false)
}

///|
test "bench suffix wrapper 0 absent original" (it : @bench.T) {
  sl_balanced_range_suffix_bench(it, 0, false, true)
}

///|
test "bench suffix wrapper 0 absent ranged" (it : @bench.T) {
  sl_balanced_range_suffix_bench(it, 0, false, false)
}

///|
test "bench suffix wrapper 8 present original" (it : @bench.T) {
  sl_balanced_range_suffix_bench(it, 8, true, true)
}

///|
test "bench suffix wrapper 8 present ranged" (it : @bench.T) {
  sl_balanced_range_suffix_bench(it, 8, true, false)
}

///|
test "bench suffix wrapper 8 absent original" (it : @bench.T) {
  sl_balanced_range_suffix_bench(it, 8, false, true)
}

///|
test "bench suffix wrapper 8 absent ranged" (it : @bench.T) {
  sl_balanced_range_suffix_bench(it, 8, false, false)
}

///|
test "bench suffix wrapper 512 present original" (it : @bench.T) {
  sl_balanced_range_suffix_bench(it, 512, true, true)
}

///|
test "bench suffix wrapper 512 present ranged" (it : @bench.T) {
  sl_balanced_range_suffix_bench(it, 512, true, false)
}

///|
test "bench suffix wrapper 512 absent original" (it : @bench.T) {
  sl_balanced_range_suffix_bench(it, 512, false, true)
}

///|
test "bench suffix wrapper 512 absent ranged" (it : @bench.T) {
  sl_balanced_range_suffix_bench(it, 512, false, false)
}
