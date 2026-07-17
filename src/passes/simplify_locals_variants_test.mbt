///|
test "simplify-locals-notee sinks single-use locals" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0))",
      ["simplify-locals-notee"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-notee success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee does not create a sink tee for multi-use locals" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 i32.const 1 i32.add local.set 1 local.get 1 drop local.get 1))",
      ["simplify-locals-notee"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-notee success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-notee still synthesizes if results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 7 local.set 1 else i32.const 9 local.set 1 end local.get 1))",
      ["simplify-locals-notee"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-notee success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if I32"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-no-tee aliases the canonical no-tee pass" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0))",
      ["simplify-locals-no-tee"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-no-tee alias success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nonesting retargets flat local copies" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 local.set 1 local.get 1))",
      ["simplify-locals-nonesting"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-nonesting success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-nonesting sinks computed values only into local sets" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) local.get 0 i32.const 1 i32.add local.set 1 local.get 1 local.set 2 local.get 2))",
      ["simplify-locals-nonesting"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-nonesting success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.add"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 2)"), msg=pretty)
}

///|
test "simplify-locals-nonesting does not push computed values under drop" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (local i32) local.get 0 i32.const 1 i32.add local.set 1 local.get 1 drop))",
      ["simplify-locals-nonesting"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-nonesting success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-nonesting does not push computed values into calls" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $use (param i32)) (func (param i32) (local i32) local.get 0 i32.const 1 i32.add local.set 1 local.get 1 call $use))",
      ["simplify-locals-nonesting"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-nonesting success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-nonesting does not synthesize if results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 7 local.set 1 else i32.const 9 local.set 1 end local.get 1))",
      ["simplify-locals-nonesting"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-nonesting success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-no-nesting aliases the canonical flat pass" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 local.set 1 local.get 1))",
      ["simplify-locals-no-nesting"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-no-nesting alias success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
}
