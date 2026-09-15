///|
test "heap2local type parity removes dead recursive groups after scalarization" {
  let input = pass_test_module_from_wat(
    "(module (type (func)) (rec (type (struct)) (type (sub (struct))) (type (sub 2 (struct)))) (type (sub 3 (struct))) (type (struct (field (ref null 4)))) (type (struct (field (mut i32)) (field eqref))) (type (struct (field i8) (field i16))) (type (array (mut i32))) (type (array (mut i8))) (func (type 0) (local i32 (ref null 0) (ref null 6) (ref null 8)) struct.new_default 6 local.set 2 local.get 2 ref.as_non_null struct.get 6 0 drop struct.new_default 6 ref.null eq ref.eq drop))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["heap2local"]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 3)
  assert_true(
    @binary.encode_module(output).unwrap().length() <
    @binary.encode_module(input).unwrap().length(),
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_false(body.any(fn(i) { i is @lib.StructNewDefault(_) }))
}

///|
test "heap2local type parity removes unused signatures without allocation candidates" {
  let input = pass_test_module_from_wat(
    "(module (type (func)) (type (func)) (type (func)) (type (func)) (func (type 0) nop))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["heap2local"]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 1)
  @debug.assert_eq(output.func_sec.unwrap().0[0], @lib.TypeIdx::new(0U))
}
