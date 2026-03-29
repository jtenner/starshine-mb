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

///|
test "precompute folds constant false void ifs to nops" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func i32.const 0 if nop else nop end i64.const 3 drop))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected precompute if-fold success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("i64.const I64(3)"), msg=pretty)
}

///|
test "precompute folds constant true result ifs to the chosen arm" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 1 if (result i32) i32.const 7 else i32.const 9 end))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected precompute result-if fold success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "precompute falls back to the original function when lowered output would be invalid" {
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      pass_test_module_from_wat(
        "(module (func (param i32) (result i32) (local i32 i32) i32.const 0 i32.const 2 i32.shl drop (block $outer i32.const 0 drop (block $mid (local.get 0) (if (result i32) (then (i32.const 7) (local.set 1) (br $mid)) (else (i32.const 9) (local.set 2) (br $outer))) return) (local.get 1) (local.set 2)) (i32.const 0)))",
      ),
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected guarded precompute success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.shl"), msg=pretty)
  assert_true(
    trace.any(fn(line) { line.contains("pass[precompute]:skip-invalid-lower") }),
    msg=trace.to_string(),
  )
}
