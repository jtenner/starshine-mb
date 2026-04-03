///|
test "run_hot_pipeline applies optimize preset through the hot pass manager" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) nop i32.const 7))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize"]) {
    Ok(mod) => mod
    Err(err) => fail("expected optimize pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected optimized module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("nop"))
  assert_true(pretty.contains("i32.const"))
  assert_true(pretty.contains("I32(7)"))
}

///|
test "run_hot_pipeline emits trace markers for hot passes" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) nop i32.const 9))",
  )
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["vacuum"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected traced hot pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected traced module to validate, got \{err}")
  }
  assert_true(trace.any(fn(line) { line.contains("pass[vacuum]:start") }))
  assert_true(trace.any(fn(line) { line.contains("pass[vacuum]:done") }))
}

///|
test "run_hot_pipeline accepts remove-unused-names as an active hot pass" {
  let input = pass_test_module_from_wat(
    "(module (func block block nop end end))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["remove-unused-names"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected remove-unused-names pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected remove-unused-names module to validate, got \{err}")
  }
}

///|
test "optimize preset replays remove-unused-names in all RUN slots" {
  let trace : Array[String] = []
  let input = pass_test_module_from_wat("(module (func loop br 0 end))")
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["optimize"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected optimize pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected optimized module to validate, got \{err}")
  }
  let run_starts = trace.filter(fn(line) {
    line.contains("pass[remove-unused-names]:start")
  })
  assert_eq(run_starts.length(), 3)
}

///|
test "optimize preset replays remove-unused-brs in all RUB slots" {
  let trace : Array[String] = []
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (block $exit (if (local.get 0) (then (br $exit))))))",
  )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["optimize"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected optimize pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected optimized module to validate, got \{err}")
  }
  let rub_starts = trace.filter(fn(line) {
    line.contains("pass[remove-unused-brs]:start")
  })
  assert_eq(rub_starts.length(), 3)
}

///|
test "shrink preset replays remove-unused-brs in all RUB slots" {
  let trace : Array[String] = []
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (block $exit (if (local.get 0) (then (br $exit))))))",
  )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["shrink"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected shrink pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected shrink module to validate, got \{err}")
  }
  let rub_starts = trace.filter(fn(line) {
    line.contains("pass[remove-unused-brs]:start")
  })
  assert_eq(rub_starts.length(), 3)
}

///|
test "optimize preset replays precompute in both PC slots" {
  let trace : Array[String] = []
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 1 i32.const 2 i32.add))",
  )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["optimize"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected optimize pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected optimized module to validate, got \{err}")
  }
  let pc_starts = trace.filter(fn(line) {
    line.contains("pass[precompute]:start")
  })
  assert_eq(pc_starts.length(), 2)
}

///|
test "shrink preset replays precompute in both PC slots" {
  let trace : Array[String] = []
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 1 i32.const 2 i32.add))",
  )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["shrink"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected shrink pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected shrink module to validate, got \{err}")
  }
  let pc_starts = trace.filter(fn(line) {
    line.contains("pass[precompute]:start")
  })
  assert_eq(pc_starts.length(), 2)
}

///|
test "optimize and shrink presets do not schedule reorder-locals before its neighboring local passes land" {
  let optimize = optimize_preset_passes(HotPipelineOptions::new())
  let shrink = shrink_preset_passes(HotPipelineOptions::new())
  assert_false(optimize.contains("reorder-locals"))
  assert_false(shrink.contains("reorder-locals"))
}

///|
test "remove-unused-names can clean up stale labels exposed by remove-unused-brs" {
  let optimized = match
    run_hot_pipeline(
      pass_test_module_from_wat("(module (func block block br 1 end end))"),
      HotPipelineOptions::new(),
      ["remove-unused-names", "remove-unused-brs", "remove-unused-names"],
    ) {
    Ok(mod) => mod
    Err(err) =>
      fail(
        "expected remove-unused-names/remove-unused-brs replay success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("Block("), msg=pretty)
}
