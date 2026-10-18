///|
test "capture compaction borrows unchanged intermediate bodies and preserves owned default output" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32) block local.get 0 drop end local.get 0))",
  )
  @validate.validate_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let saved = @binary.encode_module(input).unwrap()
  let expected = pass_lower_remove_balanced_captures(body, 1, [2, 0], [0, 0])
  let gets = [2, 0]
  let writes = [0, 0]
  let actual = pass_lower_remove_balanced_captures_impl(
    body,
    1,
    gets,
    writes,
    true,
    None,
  )
  assert_eq(actual, expected)
  assert_eq(gets, [2, 0])
  assert_eq(writes, [0, 0])
  assert_false(physical_equal(expected, body))
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_true(physical_equal(actual, body))
}

///|
test "borrowed capture cleanup retains exact removals counters and source ownership" {
  for
    text in [
      "(module (func (param i32) (result i32) (local i32) local.get 0 local.set 1 local.get 1))",
      "(module (func (param i32) (result i32) (local i32 i32) block local.get 0 local.set 1 i32.const 7 drop local.get 1 drop end local.get 0 local.set 2 local.get 2))",
      "(module (func (param i32) (result i32) (local i32) local.get 0 if local.get 0 local.set 1 local.get 1 drop else nop end local.get 0))",
    ] {
    let input = pass_test_module_from_wat(text)
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let gets = Array::make(locals.length() + 1, 0)
    let writes = Array::make(locals.length() + 1, 0)
    pass_lower_count_locals(body, gets, writes)
    let reference_gets = gets.copy()
    let reference_writes = writes.copy()
    let expected = pass_lower_remove_balanced_captures(
      body, 1, reference_gets, reference_writes,
    )
    let actual = pass_lower_remove_balanced_captures_impl(
      body,
      1,
      gets,
      writes,
      true,
      None,
    )
    assert_eq(actual, expected)
    assert_eq(gets, reference_gets)
    assert_eq(writes, reference_writes)
    @validate.validate_module(
      input.with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual))]),
      ),
    ).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
