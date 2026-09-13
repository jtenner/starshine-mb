///|
test "audit raw precompute preserves valid typed loop arity" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) (local i32 i32) i32.const 7 loop (param i32) (result i32) i32.const 0 local.set 0 local.tee 1 nop end))",
  )
  let original = input.code_sec.unwrap().0[0]
  let @lib.Func(locals, @lib.Expr(body)) = original
  let (rewritten, _) = precompute_raw_rewrite_instrs(
    body,
    Some(@ir.hot_module_context_from_module(input)),
  )
  let output = @lib.Func::new(locals, @lib.Expr::new(rewritten))
  let output = input.with_code_sec(@lib.CodeSec::new([output]))
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "audit raw precompute preserves explicit resetting loop writes" {
  let input = pass_test_module_from_wat(
    "(module (func (local i32) loop i32.const 0 local.tee 0 i32.const 16 i32.lt_u if br 1 end end))",
  )
  let original = input.code_sec.unwrap().0[0]
  let @lib.Func(locals, @lib.Expr(body)) = original
  let (rewritten, _) = precompute_raw_rewrite_instrs(
    body,
    Some(@ir.hot_module_context_from_module(input)),
  )
  let output = @lib.Func::new(locals, @lib.Expr::new(rewritten))
  let @lib.Func(_, @lib.Expr(body)) = output
  match body[0] {
    @lib.Loop(_, @lib.Expr(loop_body)) =>
      assert_true(
        loop_body.length() >= 2 &&
        loop_body[0] == @lib.Instruction::i32_const(0) &&
        (
          loop_body[1] is @lib.LocalTee(@lib.LocalIdx(0U)) ||
          loop_body[1] is @lib.LocalSet(@lib.LocalIdx(0U))
        ),
      )
    other => fail("expected reset loop: \{other}")
  }
}

///|
test "audit raw precompute does not invent memory prologue local writes" {
  let input = pass_test_module_from_wat(
    "(module (memory 8) (func (param i32 i32) (result i32) (local i32) memory.size i32.const 177248 local.tee 2 i32.const 67107 i32.add i32.const -65536 i32.and i32.const 16 i32.shr_u i32.lt_s if local.get 0 local.get 1 i32.sub memory.grow drop end local.get 0))",
  )
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (body, _) = precompute_raw_rewrite_instrs(
    body,
    Some(@ir.hot_module_context_from_module(input)),
  )
  assert_false(
    body.contains(@lib.Instruction::local_tee(@lib.LocalIdx::new(0U))),
  )
  assert_false(
    body.contains(@lib.Instruction::local_tee(@lib.LocalIdx::new(1U))),
  )
}
