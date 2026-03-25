///|
test "simplify-locals rewrites dead local.set roots" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.set 0 i32.const 7))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set"))
  assert_true(pretty.contains("drop"))
  assert_true(pretty.contains("I32(7)"))
}

///|
test "simplify-locals rewrites dead local.tee roots" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.tee 0 drop i32.const 7))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.tee"))
  assert_true(pretty.contains("drop"))
  assert_true(pretty.contains("I32(7)"))
}
