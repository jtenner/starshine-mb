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
