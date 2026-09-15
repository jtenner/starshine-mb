///|
test "fifth audit DAE intentionally ineligible read before assignment 1" {
  let input = pass_test_module_from_wat(
    "(module (global (mut i32) (i32.const 0)) (func (local i32) local.get 0 global.set 0 i32.const 1 local.set 0))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  assert_true(dae_try_inline_i32_const_local_set_flat_once(body, 0).is_none())
}

///|
test "fifth audit DAE intentionally ineligible read before assignment 7" {
  let input = pass_test_module_from_wat(
    "(module (global (mut i32) (i32.const 0)) (func (local i32) local.get 0 global.set 0 i32.const 7 local.set 0))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  assert_true(dae_try_inline_i32_const_local_set_flat_once(body, 0).is_none())
}

///|
test "fifth audit DAE intentionally ineligible read before assignment 42" {
  let input = pass_test_module_from_wat(
    "(module (global (mut i32) (i32.const 0)) (func (local i32) local.get 0 global.set 0 i32.const 42 local.set 0))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  assert_true(dae_try_inline_i32_const_local_set_flat_once(body, 0).is_none())
}

///|
test "fifth audit DAE retains nested assignment used after block" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) (local i32) block i32.const 7 local.set 0 local.get 0 drop end local.get 0))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let rewritten = dae_try_inline_i32_const_local_set_instrs_once(body, 0).unwrap_or(
    body,
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(rewritten))]),
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "precompute-propagate",
  ]).unwrap()
  let @lib.Func(_, @lib.Expr(result)) = output.code_sec.unwrap().0[0]
  assert_true(result != [@lib.Instruction::i32_const(@lib.I32(0))])
}
