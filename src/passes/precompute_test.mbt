///|
test "precompute folds exact i32 constant arithmetic" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 4 i32.const 5 i32.add))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected precompute success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(9)"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute folds chained exact constants in one pass" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 1 i32.const 2 i32.const 3 i32.add i32.add))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected chained precompute success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(6)"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute folds exact i64 unsigned comparisons to i32 constants" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i64.const -1 i64.const 0 i64.gt_u))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected precompute unsigned compare success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("i64.gt_u"), msg=pretty)
}

///|
test "precompute preserves trapping exact operators it does not fold" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 1 i32.const 0 i32.div_s))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected precompute div_s success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.div_s"), msg=pretty)
}
