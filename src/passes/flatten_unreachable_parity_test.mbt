///|
test "flatten parity removes dead root continuation and unused trap-only locals" {
  let input = pass_test_module_from_wat(
    "(module (func (export \"run\") (block (result i32) unreachable) drop i32.const 0 if (result i32) unreachable else i32.const 30 end drop (loop (result i32) unreachable) drop))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["flatten"]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body, [@lib.Instruction::unreachable_()])
  @debug.assert_eq(locals.length(), 0)
}

///|
test "flatten parity preserves effects before an unconditional root trap" {
  let input = pass_test_module_from_wat(
    "(module (global (mut i32) (i32.const 0)) (func (export \"run\") i32.const 7 global.set 0 (block (result i32) unreachable) drop i32.const 9 global.set 0))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["flatten"]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body.filter(fn(i) { i is @lib.GlobalSet(_) }).length(), 1)
  @debug.assert_eq(body.last(), Some(@lib.Instruction::unreachable_()))
}

///|
test "flatten parity preserves continuation after a conditional trap" {
  let input = pass_test_module_from_wat(
    "(module (global (mut i32) (i32.const 0)) (func (export \"run\") (param i32) local.get 0 if unreachable end i32.const 9 global.set 0))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["flatten"]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body.filter(fn(i) { i is @lib.GlobalSet(_) }).length(), 1)
}
