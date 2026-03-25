///|
test "optimize-instructions folds i32.eqz on constant zero" {
  let optimized = match
    pass_test_run_pipeline("(module (func (result i32) i32.const 0 i32.eqz))", [
      "optimize-instructions",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected optimize-instructions success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(1)"))
  assert_false(pretty.contains("I32Eqz"))
}

///|
test "optimize-instructions folds i64.eqz on non-zero constants" {
  let optimized = match
    pass_test_run_pipeline("(module (func (result i32) i64.const 9 i64.eqz))", [
      "optimize-instructions",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected optimize-instructions success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(0)"))
  assert_false(pretty.contains("I64Eqz"))
}
