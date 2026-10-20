///|
test "review vacuum removes all drops for a pure tuple self branch" {
  let input = pass_test_module_from_wat(
    "(module (func block (result i32 i32) i32.const 1 i32.const 2 br 0 end drop drop))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs_owned(
    body,
    Some(@ir.hot_module_context_from_module(input)),
  )
  let output = input.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(rewritten))]),
  )
  match @validate.validate_module(output) {
    Ok(_) => ()
    Err(err) => fail("invalid vacuum output: \{err}")
  }
  assert_true(changed)
  @debug.assert_eq(rewritten, [])
}

///|
test "review vacuum consumes pure self branch parameters and retains their effects" {
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"effect\" (func $effect (result i32))) (func call $effect block (param i32) (result i32) br 0 end drop))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs_owned(
    body,
    Some(@ir.hot_module_context_from_module(input)),
  )
  let output = input.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(rewritten))]),
  )
  match @validate.validate_module(output) {
    Ok(_) => ()
    Err(err) => fail("invalid vacuum output: \{err}")
  }
  assert_true(changed)
  @debug.assert_eq(rewritten, [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::drop(),
  ])
}

///|
test "review vacuum retains a live tuple lane when only one result is dropped" {
  // Whole-block removal is invalid while a result lane remains live.
  let input = pass_test_module_from_wat(
    "(module (func (result i32) block (result i32 i32) i32.const 1 i32.const 2 br 0 end drop))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let (rewritten, _) = run_hot_pipeline_raw_vacuum_preclean_instrs_owned(
    body,
    Some(@ir.hot_module_context_from_module(input)),
  )
  let output = input.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(rewritten))]),
  )
  match @validate.validate_module(output) {
    Ok(_) => ()
    Err(err) => fail("invalid vacuum output: \{err}")
  }
  assert_true(rewritten.any(fn(instr) { instr is @lib.Block(_, _) }))
}
