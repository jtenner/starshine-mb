///|
test "DAE reference equality stack effect consumes two references" {
  let input = pass_test_module_from_wat("(module)")
  assert_eq(
    dae_instr_stack_effect(@lib.Instruction::ref_eq(), input, []),
    Some((2, 1)),
  )
}

///|
test "DAE2 balanced captures preserve earlier stack operands across binary reference equality" {
  let input = pass_test_module_from_wat(
    "(module (type $s (struct (field i32))) (import \"env\" \"base\" (func $base (result (ref null eq)))) (import \"env\" \"produce\" (func $produce (result (ref null eq)))) (import \"env\" \"observe\" (func $observe (param i32))) (func (export \"make\") (result (ref $s)) i32.const 7 struct.new $s) (func (export \"run\") (result (ref null eq)) (local (ref null eq)) call $base call $produce local.set 0 ref.null eq ref.eq call $observe local.get 0))",
  )
  @validate.validate_module(input).unwrap()
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_eq(locals.length(), 1)
  assert_eq(
    body.last(),
    Some(@lib.Instruction::local_get(@lib.LocalIdx::new(0U))),
  )
  assert_eq(body.filter(fn(i) { i is @lib.RefEq }).length(), 1)
  assert_eq(body.filter(fn(i) { i is @lib.Call(_) }).length(), 3)
}
