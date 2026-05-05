///|
test "simplify-locals-nostructure sinks straight-line single-use sets" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-nostructure success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure accepts O4z spelling" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-notee-nostructure success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure does not create tees for multi-use locals" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0 local.get 0 i32.add))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-notee-nostructure success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.tee (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure preserves Binaryen const-nop loop shape" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result f64) loop (result f64) f64.const 1.0 nop end))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-notee-nostructure success, got \{err}")
  }

  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [@lib.Func(locals, @lib.Expr([@lib.Loop(_, @lib.Expr(body))]))]
      )
    ) => {
      assert_eq(locals, @lib.Locals::from_types([@lib.ValType::f64()]))
      assert_eq(body.length(), 3)
      assert_eq(body[0], @lib.Instruction::nop())
      assert_eq(body[1], @lib.Instruction::nop())
      match body[2] {
        @lib.F64Const(_) => ()
        other => fail("expected trailing f64 const after nops, got \{other}")
      }
    }
    other =>
      fail(
        "expected one loop body after no-tee no-structure pass, got \{other}",
      )
  }
}

///|
test "simplify-locals-nostructure does not synthesize if results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 1 local.set 1 else i32.const 2 local.set 1 end local.get 1))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-nostructure success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if I32"), msg=pretty)
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}
