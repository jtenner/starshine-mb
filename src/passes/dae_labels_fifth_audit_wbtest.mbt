///|
test "fifth audit DAE folded null preserves br 0" {
  let input = pass_test_module_from_wat("(module (func (result i32) ref.null func ref.is_null if (result i32) i32.const 7 br 0 else i32.const 0 end drop i32.const 9))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, _) = dae_fold_ref_null_is_null_if_instrs(body)
  assert_true(rewritten.any(fn(i) { i is @lib.Block(_, _) || i is @lib.If(_, _, _) }))
}

///|
test "fifth audit DAE folded null preserves i32.const 1 br_if 0" {
  let input = pass_test_module_from_wat("(module (func (result i32) ref.null func ref.is_null if (result i32) i32.const 7 i32.const 1 br_if 0 else i32.const 0 end drop i32.const 9))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, _) = dae_fold_ref_null_is_null_if_instrs(body)
  assert_true(rewritten.any(fn(i) { i is @lib.Block(_, _) || i is @lib.If(_, _, _) }))
}

///|
test "fifth audit DAE folded null preserves i32.const 0 br_table 0 0" {
  let input = pass_test_module_from_wat("(module (func (result i32) ref.null func ref.is_null if (result i32) i32.const 7 i32.const 0 br_table 0 0 else i32.const 0 end drop i32.const 9))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, _) = dae_fold_ref_null_is_null_if_instrs(body)
  assert_true(rewritten.any(fn(i) { i is @lib.Block(_, _) || i is @lib.If(_, _, _) }))
}

///|
test "fifth audit DAE folded equal preserves br 0" {
  let input = pass_test_module_from_wat("(module (func (result i32) i32.const 1 i32.const 1 i32.eq if (result i32) i32.const 7 br 0 else i32.const 0 end drop i32.const 9))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, _) = dae_fold_const_i32_eq_if_instrs_once(body)
  assert_true(rewritten.any(fn(i) { i is @lib.Block(_, _) || i is @lib.If(_, _, _) }))
}

///|
test "fifth audit DAE folded equal preserves i32.const 1 br_if 0" {
  let input = pass_test_module_from_wat("(module (func (result i32) i32.const 1 i32.const 1 i32.eq if (result i32) i32.const 7 i32.const 1 br_if 0 else i32.const 0 end drop i32.const 9))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, _) = dae_fold_const_i32_eq_if_instrs_once(body)
  assert_true(rewritten.any(fn(i) { i is @lib.Block(_, _) || i is @lib.If(_, _, _) }))
}

///|
test "fifth audit DAE folded equal preserves i32.const 0 br_table 0 0" {
  let input = pass_test_module_from_wat("(module (func (result i32) i32.const 1 i32.const 1 i32.eq if (result i32) i32.const 7 i32.const 0 br_table 0 0 else i32.const 0 end drop i32.const 9))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, _) = dae_fold_const_i32_eq_if_instrs_once(body)
  assert_true(rewritten.any(fn(i) { i is @lib.Block(_, _) || i is @lib.If(_, _, _) }))
}

