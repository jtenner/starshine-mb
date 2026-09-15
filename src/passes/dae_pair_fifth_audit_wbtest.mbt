///|
test "fifth audit DAE pair carrier retains assignments 0 local.get 6 drop local.get 5" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32 i32 i32 i32 i32 i32) call 1 local.set 5 if (result i32) local.get 5 else i32.const 9 end local.set 6 local.get 6 drop local.get 5) (func (result i32 i32) i32.const 0 i32.const 7))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let rewritten = dae_try_rewrite_func408_pair_if_carrier_body_once(body).unwrap_or(
    body,
  )
  assert_true(rewritten.any(fn(i) { i is @lib.LocalSet(@lib.LocalIdx(5U)) }))
  assert_true(rewritten.any(fn(i) { i is @lib.LocalSet(@lib.LocalIdx(6U)) }))
}

///|
test "fifth audit DAE pair carrier retains assignments 0 local.get 6 drop local.get 6" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32 i32 i32 i32 i32 i32) call 1 local.set 5 if (result i32) local.get 5 else i32.const 9 end local.set 6 local.get 6 drop local.get 6) (func (result i32 i32) i32.const 0 i32.const 7))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let rewritten = dae_try_rewrite_func408_pair_if_carrier_body_once(body).unwrap_or(
    body,
  )
  assert_true(rewritten.any(fn(i) { i is @lib.LocalSet(@lib.LocalIdx(5U)) }))
  assert_true(rewritten.any(fn(i) { i is @lib.LocalSet(@lib.LocalIdx(6U)) }))
}

///|
test "fifth audit DAE pair carrier retains assignments 1 local.get 6 drop local.get 5" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32 i32 i32 i32 i32 i32) call 1 local.set 5 if (result i32) local.get 5 else i32.const 9 end local.set 6 local.get 6 drop local.get 5) (func (result i32 i32) i32.const 1 i32.const 7))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let rewritten = dae_try_rewrite_func408_pair_if_carrier_body_once(body).unwrap_or(
    body,
  )
  assert_true(rewritten.any(fn(i) { i is @lib.LocalSet(@lib.LocalIdx(5U)) }))
  assert_true(rewritten.any(fn(i) { i is @lib.LocalSet(@lib.LocalIdx(6U)) }))
}

///|
test "fifth audit DAE pair carrier retains assignments 1 local.get 6 drop local.get 6" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32 i32 i32 i32 i32 i32) call 1 local.set 5 if (result i32) local.get 5 else i32.const 9 end local.set 6 local.get 6 drop local.get 6) (func (result i32 i32) i32.const 1 i32.const 7))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let rewritten = dae_try_rewrite_func408_pair_if_carrier_body_once(body).unwrap_or(
    body,
  )
  assert_true(rewritten.any(fn(i) { i is @lib.LocalSet(@lib.LocalIdx(5U)) }))
  assert_true(rewritten.any(fn(i) { i is @lib.LocalSet(@lib.LocalIdx(6U)) }))
}
