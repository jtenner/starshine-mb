///|
test "DAE all-used transition in first Func preserves all later NaN bodies" {
  let text = StringBuilder()
  text.write_string("(module (type (func)) (type (func)) ")
  text.write_string("(func (type 0) block (type 1) nop end) ")
  for _ in 0..<31 {
    text.write_string("(func (type 0) f64.const nan:0x123 drop) ")
  }
  text.write_string(")")
  let input = pass_test_module_from_wat(text.to_string())
  let saved = @binary.encode_module(input).unwrap()
  let old = dae_prune_max_ref_prune_unused_simple_func_types(input)
  let output = dae_prune_unused_simple_func_types(input)
  @validate.validate_module(output).unwrap()
  assert_true(physical_equal(output, input))
  assert_eq(output.type_sec.unwrap().0.length(), 2)
  assert_eq(output.code_sec.unwrap().0.length(), 32)
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(old).unwrap(),
  )
  for index in 1..<32 {
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[index]
    match body[0] {
      @lib.F64Const(@lib.F64(value)) =>
        assert_eq(value.reinterpret_as_int64(), 0x7ff0000000000123L)
      _ => fail("expected retained NaN after all-used transition")
    }
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE all-used witness ends before a later productive source invocation" {
  let input = pass_test_module_from_wat(
    "(module (type (func)) (type (func (param i64))) (type (func)) (func (type 0) i64.const 1 block (type 1) drop end) (func (type 2) nop))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let retained = dae_prune_unused_simple_func_types(input)
  assert_true(physical_equal(retained, input))
  @validate.validate_module(retained).unwrap()
  let rows = input.code_sec.unwrap().0.copy()
  let @lib.Func(locals, _) = rows[0]
  rows[0] = @lib.Func::new(locals, @lib.Expr::new([@lib.Instruction::nop()]))
  let changed = input.with_code_sec(@lib.CodeSec::new(rows))
  let changed_saved = @binary.encode_module(changed).unwrap()
  let old = dae_prune_max_ref_prune_unused_simple_func_types(changed)
  let output = dae_prune_unused_simple_func_types(changed)
  @validate.validate_module(output).unwrap()
  assert_eq(output.type_sec.unwrap().0.length(), 2)
  assert_eq(output.func_sec.unwrap().0, [
    @lib.TypeIdx::new(0U),
    @lib.TypeIdx::new(1U),
  ])
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(old).unwrap(),
  )
  assert_eq(@binary.encode_module(changed).unwrap(), changed_saved)
  assert_eq(@binary.encode_module(retained).unwrap(), saved)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
