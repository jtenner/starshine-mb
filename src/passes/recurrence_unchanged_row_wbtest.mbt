///|
test "flat recurrence helpers return their unchanged input row when no rewrite occurs" {
  for width in [0, 1, 19, 20, 128] {
    let body = Array::make(width, @lib.Instruction::nop())
    for
      rewrite in [
        run_hot_pipeline_raw_simplify_locals_rewrite_three_local_additive_recurrences_flat,
        run_hot_pipeline_raw_simplify_locals_rewrite_alternating_bitselect_recurrences_flat,
      ] {
      let (unchanged, count) = rewrite(body)
      assert_eq(count, 0)
      assert_eq(unchanged, body)
      assert_true(physical_equal(unchanged, body))
    }
  }
}

///|
test "active additive recurrences keep owned output and the complete recurrence rewrite" {
  let step = "local.get 0 local.get 2 i32.add local.tee 1 local.get 3 i32.add local.tee 2 local.get 1 i32.add local.set 3"
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32 i32 i32) \{step} \{step} \{step} local.get 3))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (result, count) = run_hot_pipeline_raw_simplify_locals_rewrite_three_local_additive_recurrences_flat(
    body,
  )
  assert_eq(count, 3)
  assert_eq(result.length(), body.length() - 2)
  assert_false(physical_equal(result, body))
  assert_eq(result[0], @lib.Instruction::local_get(@lib.LocalIdx::new(3U)))
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(result))]),
    ),
  ).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "active bitselect recurrences retain masks and owned output without mutating source" {
  let step = "local.get 0 local.get 1 v128.const i32x4 1 2 3 4 v128.bitselect local.set 0 local.get 1 local.get 0 v128.const i32x4 1 2 3 4 v128.bitselect local.set 1"
  let input = pass_test_module_from_wat(
    "(module (func (param v128 v128) (result v128) \{step} \{step} \{step} local.get 1))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (result, count) = run_hot_pipeline_raw_simplify_locals_rewrite_alternating_bitselect_recurrences_flat(
    body,
  )
  assert_eq(count, 3)
  assert_eq(result.length(), body.length() - 5)
  assert_false(physical_equal(result, body))
  assert_eq(result[0], @lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(result))]),
    ),
  ).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
