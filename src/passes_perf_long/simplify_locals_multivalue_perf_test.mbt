///|
fn perf_long_join_lines(lines : Array[String]) -> String {
  let out = StringBuilder::new()
  for i = 0; i < lines.length(); i = i + 1 {
    if i > 0 {
      out.write_string("\n")
    }
    out.write_string(lines[i])
  }
  out.to_string()
}

///|
fn perf_long_make_optimize_instructions_nested_block_module(
  depth : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (export \"main\") (param i32) (result i32)\n")
  let mut i = 0
  while i < depth {
    out.write_string("    (block (result i32)\n")
    i = i + 1
  }
  out.write_string("      (local.get 0)\n")
  i = 0
  while i < depth {
    out.write_string("      (i32.const 1)\n")
    out.write_string("      (i32.add)\n")
    out.write_string("    )\n")
    i = i + 1
  }
  out.write_string("  )\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_long_make_optimize_instructions_large_flat_module(
  repetitions : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (export \"main\") (param i32) (result i32)\n")
  let mut i = 0
  while i < repetitions {
    out.write_string("    local.get 0\n")
    out.write_string("    i32.const ")
    out.write_string((i % 17 + 1).to_string())
    out.write_string("\n    i32.add\n    drop\n")
    i = i + 1
  }
  out.write_string("    local.get 0)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_long_make_simplify_locals_multivalue_tail_ladder_module(
  repetitions : Int,
) -> String {
  let expr = StringBuilder::new()
  expr.write_string("(i32.const 0) (local.get 0)")
  let mut i = repetitions - 1
  while i >= 0 {
    let set_local = i + 2
    let next = StringBuilder::new()
    next.write_string("(if (result i32 i32) (i32.eq (local.get 1) (i32.const ")
    next.write_string(i.to_string())
    next.write_string(")) (then (local.get 0) (call 0) (local.set ")
    next.write_string(set_local.to_string())
    next.write_string(") (i32.const 1) (local.get ")
    next.write_string(set_local.to_string())
    next.write_string(")) (else ")
    next.write_string(expr.to_string())
    next.write_string("))")
    expr.reset()
    expr.write_string(next.to_string())
    i = i - 1
  }

  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"id\" (func (param i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32 i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < repetitions + 64 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n    ")
  out.write_string(expr.to_string())
  out.write_string(")\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_long_make_simplify_locals_multivalue_status_tail_ladder_module(
  repetitions : Int,
) -> String {
  let expr = StringBuilder::new()
  expr.write_string("(i32.const 0) (local.get 0)")
  let mut i = repetitions - 1
  while i >= 0 {
    let set_local = i + 2
    let status = if i % 2 == 0 { 0 } else { 1 }
    let next = StringBuilder::new()
    next.write_string("(if (result i32 i32) (i32.eq (local.get 1) (i32.const ")
    next.write_string(i.to_string())
    next.write_string(")) (then (local.get 0) (call 0) (local.set ")
    next.write_string(set_local.to_string())
    next.write_string(") (i32.const ")
    next.write_string(status.to_string())
    next.write_string(") (local.get ")
    next.write_string(set_local.to_string())
    next.write_string(") return) (else ")
    next.write_string(expr.to_string())
    next.write_string("))")
    expr.reset()
    expr.write_string(next.to_string())
    i = i - 1
  }

  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"id\" (func (param i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32 i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < repetitions + 64 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n    ")
  out.write_string(expr.to_string())
  out.write_string(")\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_long_make_simplify_locals_multivalue_call_ladder_module(
  repetitions : Int,
) -> String {
  let expr = StringBuilder::new()
  expr.write_string("(i32.const 0) (local.get 0)")
  let mut i = repetitions - 1
  while i >= 0 {
    let touched_local = i * 3 + 2
    let merged_local = i * 3 + 3
    let spilled_local = i * 3 + 4
    let next = StringBuilder::new()
    next.write_string("(if (result i32 i32) (i32.eq (local.get 1) (i32.const ")
    next.write_string(i.to_string())
    next.write_string(")) (then ")
    next.write_string("(local.get 0) (call 0) (local.set ")
    next.write_string(touched_local.to_string())
    next.write_string(") (local.get ")
    next.write_string(touched_local.to_string())
    next.write_string(") (local.get 1) (call 1) (local.set ")
    next.write_string(merged_local.to_string())
    next.write_string(") (local.get ")
    next.write_string(merged_local.to_string())
    next.write_string(") (local.get 0) (local.get 1) (call 2) (local.set ")
    next.write_string(spilled_local.to_string())
    next.write_string(") (local.get ")
    next.write_string(spilled_local.to_string())
    next.write_string(") drop (i32.const 1) (local.get ")
    next.write_string(spilled_local.to_string())
    next.write_string(")) (else ")
    next.write_string(expr.to_string())
    next.write_string("))")
    expr.reset()
    expr.write_string(next.to_string())
    i = i - 1
  }

  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"merge\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"sink3\" (func (param i32 i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32 i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < repetitions * 3 + 64 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n    ")
  out.write_string(expr.to_string())
  out.write_string(")\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_long_make_simplify_locals_flat_dense_multivalue_call_ladder_module(
  repetitions : Int,
) -> String {
  let expr = StringBuilder::new()
  expr.write_string("(i32.const 0) (local.get 0)")
  let mut i = repetitions - 1
  while i >= 0 {
    let touched_local = i * 4 + 2
    let merged_local = i * 4 + 3
    let spilled_local = i * 4 + 4
    let scratch_local = i * 4 + 5
    let next = StringBuilder::new()
    next.write_string("(if (result i32 i32) (i32.eq (local.get 1) (i32.const ")
    next.write_string(i.to_string())
    next.write_string(")) (then ")
    next.write_string("(local.get 0) (call 0) (local.set ")
    next.write_string(touched_local.to_string())
    next.write_string(") (local.get ")
    next.write_string(touched_local.to_string())
    next.write_string(") (local.get 1) (call 1) (local.set ")
    next.write_string(merged_local.to_string())
    next.write_string(") (local.get ")
    next.write_string(merged_local.to_string())
    next.write_string(") (local.get 0) (local.get 1) (call 2) (local.set ")
    next.write_string(spilled_local.to_string())
    next.write_string(") (local.get ")
    next.write_string(spilled_local.to_string())
    next.write_string(") drop (local.get 0) (local.set ")
    next.write_string(scratch_local.to_string())
    next.write_string(") (local.get ")
    next.write_string(scratch_local.to_string())
    next.write_string(") drop (i32.const 1) (local.get ")
    next.write_string(spilled_local.to_string())
    next.write_string(")) (else ")
    next.write_string(expr.to_string())
    next.write_string("))")
    expr.reset()
    expr.write_string(next.to_string())
    i = i - 1
  }

  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string(
    "  (import \"env\" \"touch\" (func (param i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"merge\" (func (param i32 i32) (result i32)))\n",
  )
  out.write_string(
    "  (import \"env\" \"sink3\" (func (param i32 i32 i32) (result i32)))\n",
  )
  out.write_string("  (func (param i32 i32) (result i32 i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < repetitions * 4 + 64 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n    ")
  out.write_string(expr.to_string())
  out.write_string(")\n")
  out.write_string(")\n")
  out.to_string()
}

///|
test "optimize-instructions long perf lane scans nested blocks without exponential local write marking" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = @passes.HotPerfSession::new(
    trace~,
    dump_options=@passes.HotPerfDumpOptions::new(),
  )
  let input = perf_long_make_optimize_instructions_nested_block_module(50)
  let start_us = @lib.trace_now_us()
  match
    @passes.pass_test_run_pipeline(
      input,
      ["optimize-instructions"],
      options=@passes.HotPipelineOptions::new(
        trace=Some(trace),
        perf=Some(perf),
      ),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected nested block optimize-instructions success, got \{err}")
  }
  let elapsed_us = @lib.trace_elapsed_us_since(start_us)
  let text = perf_long_join_lines(lines)
  assert_true(
    elapsed_us < 2000000UL,
    msg="expected optimize-instructions nested-block scan to stay under 2s, got \{elapsed_us}us\n\{text}",
  )
}

///|
test "optimize-instructions long perf lane records the large flat scanner baseline" {
  let input = perf_long_make_optimize_instructions_large_flat_module(1200)
  let start_us = @lib.trace_now_us()
  match @passes.pass_test_run_pipeline(input, ["optimize-instructions"]) {
    Ok(_) => ()
    Err(err) =>
      fail("expected large flat optimize-instructions success, got \{err}")
  }
  let elapsed_us = @lib.trace_elapsed_us_since(start_us)
  assert_true(
    elapsed_us < 5000000UL,
    msg="expected optimize-instructions large flat baseline to stay under 5s, got \{elapsed_us}us",
  )
}

///|
test "simplify-locals long perf lane rewrites large multivalue tail ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = @passes.HotPerfSession::new(
    trace~,
    dump_options=@passes.HotPerfDumpOptions::new(),
  )
  let input = perf_long_make_simplify_locals_multivalue_tail_ladder_module(72)
  let optimized = match
    @passes.pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=@passes.HotPipelineOptions::new(
        trace=Some(trace),
        perf=Some(perf),
      ),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected large multivalue tail ladder simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let text = perf_long_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=multivalue-tail-local-get-ladder",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
  assert_false(
    pretty.contains(
      "(local.set (Local 2))(i32.const I32(1))(local.get (Local 2))",
    ),
    msg=pretty,
  )
}

///|
test "simplify-locals long perf lane rewrites large multivalue status tail ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = @passes.HotPerfSession::new(
    trace~,
    dump_options=@passes.HotPerfDumpOptions::new(),
  )
  let input = perf_long_make_simplify_locals_multivalue_status_tail_ladder_module(
    48,
  )
  let optimized = match
    @passes.pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=@passes.HotPipelineOptions::new(
        trace=Some(trace),
        perf=Some(perf),
      ),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected large multivalue status tail ladder simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let text = perf_long_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=multivalue-tail-local-get-ladder",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
  assert_false(
    pretty.contains(
      "(local.set (Local 2))(i32.const I32(0))(local.get (Local 2))",
    ),
    msg=pretty,
  )
}

///|
test "simplify-locals long perf lane skips multivalue call-heavy ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = @passes.HotPerfSession::new(
    trace~,
    dump_options=@passes.HotPerfDumpOptions::new(),
  )
  let input = perf_long_make_simplify_locals_multivalue_call_ladder_module(16)

  match
    @passes.pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=@passes.HotPipelineOptions::new(
        trace=Some(trace),
        perf=Some(perf),
      ),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected large multivalue call-heavy ladder simplify-locals success, got \{err}",
      )
  }

  let text = perf_long_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=multivalue-call-heavy-ladder",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}

///|
test "simplify-locals long perf lane skips flat dense multivalue call-heavy ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = @passes.HotPerfSession::new(
    trace~,
    dump_options=@passes.HotPerfDumpOptions::new(),
  )
  let input = perf_long_make_simplify_locals_flat_dense_multivalue_call_ladder_module(
    32,
  )

  match
    @passes.pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=@passes.HotPipelineOptions::new(
        trace=Some(trace),
        perf=Some(perf),
      ),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected flat dense multivalue call-heavy ladder simplify-locals success, got \{err}",
      )
  }

  let text = perf_long_join_lines(lines)
  assert_true(
    text.contains(
      "pass[simplify-locals]:skip-raw reason=multivalue-call-heavy-ladder",
    ),
    msg=text,
  )
  assert_false(text.contains("perf:timer name=lift"), msg=text)
  assert_false(text.contains("perf:timer name=pass:simplify-locals"), msg=text)
}
