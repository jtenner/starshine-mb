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
  assert_true(pretty.contains("nop"), msg=pretty)
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("I64(3)"), msg=pretty)
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
test "precompute retargets split local.set wrappers with void-if forwarders" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) (local.set 1 (block $outer (result i32) (block $exit (br $outer (block $mid (result i32) (block $cont (if (local.get 0) (then (local.set 2 (i32.const 7)) (br $cont)) (else (local.set 2 (i32.const 9)) (br $exit))) unreachable) (local.get 2)))) (local.get 1))) (local.get 1)))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected precompute split-wrapper success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(block $outer (result i32)"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "precompute rewrites dropped pure constants to a single nop in void bodies" {
  let optimized = match
    pass_test_run_pipeline("(module (func i64.const 360 drop))", ["precompute"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected precompute pure-drop success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("nop"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("I64(360)"), msg=pretty)
}

///|
test "precompute removes pure root nop prefixes before a final const result" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (global i64 (i64.const 486)) (func (result i32) i32.const 1 if nop else nop end f64.const 45 drop global.get 0 drop nop nop nop i32.const 655))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected precompute nop-residue cleanup success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("nop"), msg=pretty)
  assert_true(pretty.contains("I32(655)"), msg=pretty)
}

///|
test "precompute removes a leading nop before a final const result" {
  let optimized = match
    pass_test_run_pipeline("(module (func (result i32) nop i32.const 363))", [
      "precompute",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected precompute leading-nop const success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("nop"), msg=pretty)
  assert_true(pretty.contains("I32(363)"), msg=pretty)
}

///|
test "precompute preserves explicit nops before a trailing local.get result" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result f32) (local i32 f32) nop nop local.get 1))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected precompute trailing-local-get nop parity, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("nop"), msg=pretty)
  assert_true(pretty.contains("(local.get (Local 1))"), msg=pretty)
}

///|
test "precompute preserves root nops after simplifying dead pure prefixes before a trailing const" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (global i32 (i32.const 212)) (func (param f32 i64) (result i32) nop global.get 0 drop f32.const 78 drop i64.const 756 local.set 1 nop nop i32.const 700))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected precompute dead-prefix nop parity success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("nop"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("(local.set (Local 1))"), msg=pretty)
  assert_true(pretty.contains("I32(700)"), msg=pretty)
}

///|
test "precompute lowers empty root blocks to nops before surviving roots" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param f32) (result f32) (local f32) i64.const 942 drop f32.const 80 local.tee 0 drop block nop end f32.const 5 local.set 1 block nop end local.get 0))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected precompute root-block nop parity success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(block"), msg=pretty)
  assert_true(pretty.contains("nop"), msg=pretty)
  assert_true(pretty.contains("(local.set (Local 1))"), msg=pretty)
  assert_true(pretty.contains("(local.get (Local 0))"), msg=pretty)
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

///|
test "precompute folds nested exact i32 bit-arithmetic to a single const" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 177248 i32.const 15 i32.add i32.const -16 i32.and))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested exact i32 bit-arithmetic fold success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(177248)"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
  assert_false(pretty.contains("i32.and"), msg=pretty)
}

///|
test "precompute folds exact i32 shift expressions to constants" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32 i32) i32.const 8 i32.const 2 i32.shr_u i32.const 3 i32.const 30 i32.shl))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected exact i32 shift fold success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(2)"), msg=pretty)
  assert_true(pretty.contains("I32(-1073741824)"), msg=pretty)
  assert_false(pretty.contains("i32.shr_u"), msg=pretty)
  assert_false(pretty.contains("i32.shl"), msg=pretty)
}

///|
test "precompute folds immutable global.get uses into constants" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (global i32 (i32.const 169776)) (func (result i32) global.get 0))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected immutable global.get fold success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(169776)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "precompute folds defined immutable globals even after imported globals" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (import \"env\" \"g\" (global i32)) (global i32 (i32.const 169776)) (func (result i32) global.get 1))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected defined immutable global.get after imports to fold, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(169776)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "precompute validates rewritten functions against full module call targets" {
  let input = "(module (import \"env\" \"sink\" (func (param i32))) (global i32 (i32.const 169776)) (global i32 (i32.const 169472)) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) global.get 0 local.set 9 i32.const 0 local.set 0 i32.const 0 local.set 1 i32.const 0 local.set 2 i32.const 0 local.set 3 i32.const 0 local.set 4 i32.const 0 local.set 5 i32.const 0 local.set 6 global.get 1 call 0 global.get 1 local.set 7 i32.const 0 local.set 8 local.get 0 local.get 1 local.get 2 local.get 3 local.get 4 local.get 5 local.get 6 local.get 7 local.get 8 call 2) (func (param i32 i32 i32 i32 i32 i32 i32 i32 i32) (result i32) local.get 0))"
  let trace = match pass_test_capture_trace(input, ["precompute"]) {
    Ok(lines) => lines
    Err(err) =>
      fail(
        "expected precompute call-target validation repro success, got \{err}",
      )
  }
  let optimized = match pass_test_run_pipeline(input, ["precompute"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected precompute full-module validation regression success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("I32(169776)"), msg=pretty)
  assert_true(pretty.contains("I32(169472)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(
    trace.any(fn(line) { line.contains("pass[precompute]:skip-invalid-lower") }),
    msg=trace.to_string(),
  )
}
