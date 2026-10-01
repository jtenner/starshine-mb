///|
test "constant pending storage preserves sparse reads and barrier reactivation" {
  for high in [7, 4096] {
    let locals = Array::make(high + 1, "i32").join(" ")
    let input = pass_test_module_from_wat(
      "(module (import \"env\" \"effect\" (func $effect)) (func (result i32) (local \{locals}) i32.const 5 local.set 0 i32.const 7 local.set \{high} call $effect local.get 0 drop i32.const 9 local.set 0 local.get \{high} drop local.get 0 drop i32.const 11 local.set \{high} i32.const 13 local.set \{high} local.get \{high} local.tee 0 local.get 0 i32.add))",
    )
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let @lib.Func(local_types, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let expected = sl_constant_sink_map_reference(body)
    let actual = sl_sink_constant_stores_flat(body)
    assert_eq(actual, expected)
    assert_eq(actual.1, 2)
    assert_true(
      actual.0.contains(@lib.Instruction::local_set(@lib.LocalIdx::new(0U))),
    )
    assert_true(
      actual.0.contains(
        @lib.Instruction::local_set(@lib.LocalIdx::new(high.to_uint())),
      ),
    )
    @validate.validate_module(
      input.with_code_sec(
        @lib.CodeSec::new([
          @lib.Func::new(local_types, @lib.Expr::new(actual.0)),
        ]),
      ),
    ).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "constant pending storage leaves no-candidate arithmetic untouched" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32 i32) (result i32) local.get 0 local.get 1 i32.add local.tee 0 i32.const 3 i32.mul))",
  )
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let actual = sl_sink_constant_stores_flat(body)
  assert_eq(actual, sl_constant_sink_map_reference(body))
  assert_eq(actual.1, 0)
  assert_true(physical_equal(actual.0, body))
}
