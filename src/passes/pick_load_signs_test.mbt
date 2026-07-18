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
test "pick-load-signs removes a commuted i32 mask after selecting an unsigned load" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) (local $x i32) i32.const 0 i32.load8_s local.set $x i32.const 255 local.get $x i32.and))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load8u"), msg=pretty)
  assert_false(pretty.contains("i32.load8s"))
  assert_false(pretty.contains("i32.and"), msg=pretty)
}

///|
test "pick-load-signs makes i32.load8 unsigned and removes its zero-extension shift" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) (local $x i32) i32.const 0 i32.load8_s local.set $x local.get $x i32.const 24 i32.shl i32.const 24 i32.shr_u))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load8u"), msg=pretty)
  assert_false(pretty.contains("i32.load8s"))
  assert_false(pretty.contains("i32.shl"), msg=pretty)
  assert_false(pretty.contains("i32.shr_u"), msg=pretty)
}

///|
test "pick-load-signs makes i32.load16 unsigned and removes its zero-extension shift" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) (local $x i32) i32.const 0 i32.load16_s local.set $x local.get $x i32.const 16 i32.shl i32.const 16 i32.shr_u))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load16u"), msg=pretty)
  assert_false(pretty.contains("i32.load16s"))
  assert_false(pretty.contains("i32.shl"), msg=pretty)
  assert_false(pretty.contains("i32.shr_u"), msg=pretty)
}

///|
test "pick-load-signs keeps an i32 zero-extension shift when another local write is not a matching load" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (param $flag i32) (result i32) (local $x i32) i32.const 1 local.set $x local.get $flag if i32.const 0 i32.load8_s local.set $x end local.get $x i32.const 24 i32.shl i32.const 24 i32.shr_u))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load8u"), msg=pretty)
  assert_true(pretty.contains("i32.shl"), msg=pretty)
  assert_true(pretty.contains("i32.shr_u"), msg=pretty)
}

///|
test "pick-load-signs keeps an i32 zero-extension shift when a parameter value can reach the read" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (param $x i32) (param $flag i32) (result i32) local.get $flag if i32.const 0 i32.load8_s local.set $x end local.get $x i32.const 24 i32.shl i32.const 24 i32.shr_u))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load8u"), msg=pretty)
  assert_true(pretty.contains("i32.shl"), msg=pretty)
  assert_true(pretty.contains("i32.shr_u"), msg=pretty)
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
test "pick-load-signs rewrites i64 load32 to signed and removes extend32 use" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i64) (local $x i64) i32.const 0 i64.load32_u local.set $x local.get $x i64.extend32_s))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i64.load32s"), msg=pretty)
  assert_false(pretty.contains("i64.load32u"))
  assert_false(pretty.contains("i64.extend32_s"), msg=pretty)
}

///|
test "pick-load-signs detects i64 zero-extension by mask" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i64) (local $x i64) i32.const 0 i64.load16_s local.set $x local.get $x i64.const 65535 i64.and))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i64.load16u"), msg=pretty)
  assert_false(pretty.contains("i64.load16s"))
  assert_false(pretty.contains("i64.and"), msg=pretty)
}

///|
test "pick-load-signs makes i64.load8 signed and removes its sign-extension shift" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i64) (local $x i64) i32.const 0 i64.load8_u local.set $x local.get $x i64.const 56 i64.shl i64.const 56 i64.shr_s))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i64.load8s"), msg=pretty)
  assert_false(pretty.contains("i64.load8u"))
  assert_false(pretty.contains("i64.shl"), msg=pretty)
  assert_false(pretty.contains("i64.shr_s"), msg=pretty)
}

///|
test "pick-load-signs makes i64.load16 signed and removes its sign-extension shift" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i64) (local $x i64) i32.const 0 i64.load16_u local.set $x local.get $x i64.const 48 i64.shl i64.const 48 i64.shr_s))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i64.load16s"), msg=pretty)
  assert_false(pretty.contains("i64.load16u"))
  assert_false(pretty.contains("i64.shl"), msg=pretty)
  assert_false(pretty.contains("i64.shr_s"), msg=pretty)
}

///|
test "pick-load-signs makes i64.load32 signed and removes its sign-extension shift" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i64) (local $x i64) i32.const 0 i64.load32_u local.set $x local.get $x i64.const 32 i64.shl i64.const 32 i64.shr_s))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i64.load32s"), msg=pretty)
  assert_false(pretty.contains("i64.load32u"))
  assert_false(pretty.contains("i64.shl"), msg=pretty)
  assert_false(pretty.contains("i64.shr_s"), msg=pretty)
}

///|
test "pick-load-signs makes i64.load8 unsigned and removes its zero-extension shift" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i64) (local $x i64) i32.const 0 i64.load8_s local.set $x local.get $x i64.const 56 i64.shl i64.const 56 i64.shr_u))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i64.load8u"), msg=pretty)
  assert_false(pretty.contains("i64.load8s"))
  assert_false(pretty.contains("i64.shl"), msg=pretty)
  assert_false(pretty.contains("i64.shr_u"), msg=pretty)
}

///|
test "pick-load-signs makes i64.load16 unsigned and removes its zero-extension shift" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i64) (local $x i64) i32.const 0 i64.load16_s local.set $x local.get $x i64.const 48 i64.shl i64.const 48 i64.shr_u))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i64.load16u"), msg=pretty)
  assert_false(pretty.contains("i64.load16s"))
  assert_false(pretty.contains("i64.shl"), msg=pretty)
  assert_false(pretty.contains("i64.shr_u"), msg=pretty)
}

///|
test "pick-load-signs makes i64.load32 unsigned and removes its zero-extension shift" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i64) (local $x i64) i32.const 0 i64.load32_s local.set $x local.get $x i64.const 32 i64.shl i64.const 32 i64.shr_u))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i64.load32u"), msg=pretty)
  assert_false(pretty.contains("i64.load32s"))
  assert_false(pretty.contains("i64.shl"), msg=pretty)
  assert_false(pretty.contains("i64.shr_u"), msg=pretty)
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
  @debug.assert_eq(once_pretty, twice_pretty)
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
      "(module (import \"env\" \"mem\" (memory 1)) (func (result i32) (local $x i32) i32.const 0 i32.load8_s local.set $x local.get $x i32.const 255 i32.and))",
      ["pick-load-signs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pick-load-signs success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load8u"), msg=pretty)
}
