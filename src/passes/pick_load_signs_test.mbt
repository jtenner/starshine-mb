///|
test "pick-load-signs rewrites to signed when all reads are signed extension" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) (local $x i32) i32.const 0 i32.load8_u local.set $x local.get $x i32.extend8_s))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load8s"), msg=pretty)
  assert_false(pretty.contains("i32.load8u"))
}

///|
test "pick-load-signs signed usage ties over unsigned usage" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) (local $x i32) i32.const 0 i32.load8_u local.set $x local.get $x i32.extend8_s drop local.get $x i32.const 255 i32.and))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load8s"))
  assert_false(pretty.contains("i32.load8u"))
}

///|
test "pick-load-signs keeps load unsigned when usage is not recognized" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) (local $x i32) i32.const 0 i32.load8_u local.set $x local.get $x i32.const 1 i32.eq))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load8u"))
  assert_false(pretty.contains("i32.load8s"))
}

///|
test "pick-load-signs skips rewrite on mixed signed-width evidence" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) (local $x i32) i32.const 0 i32.load8_u local.set $x local.get $x i32.extend8_s drop local.get $x i32.extend16_s))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load8u"))
}

///|
test "pick-load-signs detects zero-extension by i32.and mask" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) (local $x i32) i32.const 0 i32.load8_s local.set $x local.get $x i32.const 255 i32.and))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load8u"))
  assert_false(pretty.contains("i32.load8s"))
}

///|
test "pick-load-signs detects zero-extension by shift pair" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) (local $x i32) i32.const 0 i32.load16_s local.set $x local.get $x i32.const 16 i32.shl i32.const 16 i32.shr_u))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load16u"))
  assert_false(pretty.contains("i32.load16s"))
}

///|
test "pick-load-signs excludes local.tee producers" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (local $x i32) i32.const 0 i32.load8_u local.tee $x local.get $x i32.extend8_s drop drop))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load8u"))
}

///|
test "pick-load-signs rewrites all matching candidates for one local" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) (local $x i32) i32.const 0 i32.load8_u local.set $x local.get $x i32.extend8_s drop i32.const 4 i32.load8_u local.set $x local.get $x i32.extend8_s))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load8s"))
  assert_false(pretty.contains("i32.load8u"))
}

///|
test "pick-load-signs is idempotent" {
  let once = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) (local $x i32) i32.const 0 i32.load8_u local.set $x local.get $x i32.extend8_s))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs first pass success, got \{err}")
  }
  let twice = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) (local $x i32) i32.const 0 i32.load8_u local.set $x local.get $x i32.extend8_s))",
      ["pick-load-signs", "pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs second pass success, got \{err}")
  }

  let once_pretty = once.pretty_print_func(@lib.FuncIdx::new(0U))
  let twice_pretty = twice.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_eq(once_pretty, twice_pretty)
}

///|
test "pick-load-signs skips when no memories exist" {
  let trace = match
    pass_test_capture_trace(
      "(module (func (result i32) (local $x i32) i32.const 1 local.set $x local.get $x))",
      ["pick-load-signs"],
    ) {
    Ok(trace) => trace
    Err(err) =>
      fail("expected pick-load-signs trace capture success, got \{err}")
  }

  assert_true(
    trace.any(fn(line) { line.contains("pass[pick-load-signs]:skip-no-memory") }),
  )
}

///|
test "pick-load-signs runs when imported memory is present" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) (local $x i32) i32.const 0 i32.load8_s local.set $x local.get $x i32.const 255 i32.and))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load8u"))
}
