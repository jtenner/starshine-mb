///|
fn oi_tee_test_body(text : String) -> Array[@lib.Instruction] {
  let output = pass_test_run_pipeline(text, ["optimize-instructions"]).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.CodeSec(codes) = output.code_sec.unwrap()
  let @lib.Func(_, @lib.Expr(body)) = codes[0]
  body
}

///|
test "optimize-instructions retains observed tee and removes idempotent integer reuse" {
  for
    (width, op) in [
      ("i32", "and"),
      ("i32", "or"),
      ("i64", "and"),
      ("i64", "or"),
    ] {
    let body = oi_tee_test_body(
      "(module (func (param \{width}) (result \{width} \{width}) (local \{width}) local.get 0 local.tee 1 local.get 1 \{width}.\{op} local.get 1))",
    )
    assert_true(
      body.contains(@lib.Instruction::local_tee(@lib.LocalIdx::new(1U))),
    )
    let eliminated = match (width, op) {
      ("i32", "and") => @lib.Instruction::i32_and()
      ("i32", _) => @lib.Instruction::i32_or()
      ("i64", "and") => @lib.Instruction::i64_and()
      _ => @lib.Instruction::i64_or()
    }
    assert_false(body.contains(eliminated))
  }
}

///|
test "optimize-instructions tee identity retains trapping dividend" {
  let body = oi_tee_test_body(
    "(module (func (param i32 i32) (result i32) (local i32) local.get 0 local.get 1 i32.div_s local.tee 2 local.get 2 i32.or))",
  )
  assert_true(body.contains(@lib.Instruction::i32_div_s()))
  assert_false(body.contains(@lib.Instruction::i32_or()))
}

///|
test "optimize-instructions tee identity rejects a changed rhs local" {
  let output = pass_test_run_pipeline(
    "(module (func (param i32 i32) (result i32) (local i32) (i32.or (local.tee 2 (local.get 0)) (block (result i32) (local.set 2 (local.get 1)) (local.get 2)))))",
    ["optimize-instructions"],
  ).unwrap()
  let func = @ir.hot_lift_func(output, @lib.FuncIdx::new(0U))
  let mut count = 0
  for id = 0; id < @ir.hot_node_count(func); id = id + 1 {
    if @ir.hot_node_is_live(func, id) &&
      @ir.hot_node_exact_instr(func, id) == Some(@lib.Instruction::i32_or()) {
      count += 1
    }
  }
  @debug.assert_eq(count, 1)
  @validate.validate_module(output).unwrap()
}
