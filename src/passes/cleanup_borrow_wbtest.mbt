///|
test "continuation cleanup borrows unchanged scalar and structured bodies" {
  let fixtures = [
    "(module (func (param i32) local.get 0 drop))", "(module (type $t (struct (field i32))) (func (param (ref $t)) local.get 0 drop))",
    "(module (func (param i32) block local.get 0 drop end loop local.get 0 drop end local.get 0 if local.get 0 drop else local.get 0 drop end try_table local.get 0 drop end))",
    "(module (func (param i32) block i32.const 7 local.set 0 local.get 0 drop end local.get 0 drop))",
  ]
  for wat in fixtures {
    let input = pass_test_module_from_wat(wat)
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let actual = sl_cleanup_drop_dead_pairs_with_reads(
      body,
      SlCleanupReadSet::new([]),
    )
    assert_eq(
      actual,
      sl_cleanup_borrow_reference(body, SlCleanupReadSet::new([])),
    )
    assert_eq(actual, body)
    assert_true(
      physical_equal(actual, body),
      msg="unchanged continuation cleanup copied its body",
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "continuation cleanup replaces only changed children and owns changed output" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) block local.get 0 drop end block i32.const 7 local.set 0 local.get 0 drop end))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let actual = sl_cleanup_drop_dead_pairs_with_reads(
    body,
    SlCleanupReadSet::new([]),
  )
  assert_eq(
    actual,
    sl_cleanup_borrow_reference(body, SlCleanupReadSet::new([])),
  )
  assert_false(physical_equal(actual, body))
  assert_true(
    physical_equal(actual[0], body[0]),
    msg="unchanged sibling control was rebuilt",
  )
  guard actual[1] is @lib.Block(_, @lib.Expr(changed)) else {
    fail("expected changed continuation block")
  }
  assert_eq(changed, [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::drop(),
  ])
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual))]),
    ),
  ).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "continuation cleanup preserves unchanged NaN payloads and signed zero by borrowing" {
  let input = pass_test_module_from_wat(
    "(module (func block f64.const nan:0x12345 drop f32.const -0 drop end))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let actual = sl_cleanup_drop_dead_pairs_with_reads(
    body,
    SlCleanupReadSet::new([]),
  )
  assert_true(physical_equal(actual, body))
  assert_eq(
    @binary.encode_module(
      input.with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual))]),
      ),
    ).unwrap(),
    saved,
  )
}
