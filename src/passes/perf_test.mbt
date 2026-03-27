///|
fn perf_test_join_lines(lines : Array[String]) -> String {
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
fn perf_test_count_occurrences(text : String, needle : String) -> Int {
  if needle == "" {
    return 0
  }
  let mut count = 0
  let mut start = 0
  while start <= text.length() - needle.length() {
    let mut found : Int? = None
    let mut i = start
    while i <= text.length() - needle.length() {
      if text.sub(start=i, end=i + needle.length()).to_string() == needle {
        found = Some(i)
        break
      }
      i += 1
    }
    match found {
      Some(idx) => {
        count += 1
        start = idx + needle.length()
      }
      None => break
    }
  }
  count
}

///|
test "perf session records hot allocation deltas dumps and checkpoints" {
  let lines : Array[String] = []
  let perf = HotPerfSession::new(
    trace=fn(line) { lines.push(line) },
    dump_options=HotPerfDumpOptions::new(hot_func=true, cfg=true),
  )
  let func = @ir.HotFunc::new()
  let before = perf_snapshot_hot_func(func)
  let const_ = @ir.hot_build_const_i32(func, @lib.I32(9))
  @ir.hot_root_append(func, const_)
  let after = perf_snapshot_hot_func(func)

  perf_count_hot_alloc_delta(perf, before, after)
  let cfg = @ir.cfg_build(func)
  perf_count_cfg_build(perf)
  perf_count_traversal_visit(perf, count=@ir.cfg_block_count(cfg))
  perf_dump_hot_func(perf, func, "after-build")
  perf_dump_cfg(perf, cfg, "after-build")
  perf_validation_checkpoint(perf, "after-build")

  let counters = perf_counters(perf)
  assert_eq(counters.node_allocs, 1)
  assert_eq(counters.child_span_allocs, 0)
  assert_eq(counters.side_table_allocs, 1)
  assert_eq(counters.cfg_builds, 1)
  assert_eq(counters.traversal_visits, @ir.cfg_block_count(cfg))

  let text = perf_test_join_lines(lines)
  assert_true(text.contains("perf:dump hot-func label=after-build"))
  assert_true(text.contains("perf:dump cfg label=after-build"))
  assert_true(text.contains("perf:checkpoint name=after-build"))
}

///|
test "pass require cfg records a single cfg build and optional cfg dump" {
  let lines : Array[String] = []
  let perf = HotPerfSession::new(
    trace=fn(line) { lines.push(line) },
    dump_options=HotPerfDumpOptions::new(cfg=true),
  )
  let func = pass_test_lift_first_func(
    "(module (func (result i32) i32.const 9))",
  )
  let ctx = HotPassContext::new(
    @ir.HotPassDescriptor::new("test"),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    perf=Some(perf),
  )

  ignore(pass_require_cfg(ctx, func))
  ignore(pass_require_cfg(ctx, func))

  let counters = perf_counters(perf)
  assert_eq(counters.cfg_builds, 1)
  let text = perf_test_join_lines(lines)
  assert_true(text.contains("perf:timer name=analysis:cfg"))
  assert_true(text.contains("perf:dump cfg label=analysis:cfg"))
}

///|
test "run hot pipeline emits perf timing and checkpoint lines while dumps stay opt in" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let options = HotPipelineOptions::new(
    verify_policy=HotPipelineVerifyPolicy::after_each_pass(),
    trace=Some(trace),
    perf=Some(perf),
  )

  match
    pass_test_run_pipeline(
      "(module (func (result i32) nop i32.const 9))",
      ["vacuum"],
      options~,
    ) {
    Ok(_) => ()
    Err(err) => fail("expected perf pipeline success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(text.contains("perf:timer name=lift"))
  assert_true(text.contains("perf:timer name=pass:vacuum"))
  assert_true(text.contains("perf:timer name=lower"))
  assert_true(text.contains("perf:timer name=validate:final-module"))
  assert_true(text.contains("perf:checkpoint name=verify after lift"))
  assert_true(text.contains("perf:counters label=pipeline:done"))
  assert_false(text.contains("perf:dump"))
}

///|
test "run hot pipeline omits hot verify checkpoints under final-module-only policy" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) nop i32.const 9))",
      ["vacuum"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected final-module-only perf pipeline success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_false(text.contains("perf:checkpoint name=verify after lift"))
  assert_false(text.contains("perf:timer name=verify:after-lift"))
  assert_false(text.contains("perf:checkpoint name=verify before lower"))
  assert_false(text.contains("perf:timer name=verify:before-lower"))
  assert_true(text.contains("perf:timer name=validate:final-module"))
}

///|
test "run hot pipeline skips lower when a hot pass leaves the function unchanged" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 9))",
      ["vacuum"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected unchanged hot pipeline success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(text.contains("perf:timer name=lift"))
  assert_true(text.contains("perf:timer name=pass:vacuum"))
  assert_false(text.contains("perf:timer name=lower"))
}

///|
test "ssa-nomerge skips ssa analysis when there are no local writes" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 9))",
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected no-write ssa-nomerge success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_false(text.contains("perf:timer name=analysis:ssa"))
}

///|
test "ssa-nomerge skips raw lift when the original function has no local writes" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 9))",
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected raw-skip ssa-nomerge success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(text.contains("pass[ssa-nomerge]:skip-raw"))
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:ssa-nomerge"))
}

///|
test "ssa-nomerge rewrites straight-line local traffic without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 5 local.set 0 local.get 0))",
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected straight-line raw ssa-nomerge success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[ssa-nomerge]:skip-raw reason=straight-line-local-writes",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=analysis:ssa"))
}

///|
test "dead-code-elimination skips raw lift for straight-line value-returning functions" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 9))",
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected raw-skip dead-code-elimination success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[dead-code-elimination]:skip-raw reason=no-dce-candidates",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:dead-code-elimination"))
}

///|
test "dead-code-elimination skips raw lift for straight-line void direct calls" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (type (func)) (import \"env\" \"ping\" (func (type 0))) (func call 0))",
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected raw-skip dead-code-elimination direct-call success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[dead-code-elimination]:skip-raw reason=no-dce-candidates",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:dead-code-elimination"))
}

///|
test "dead-code-elimination skips raw lift for branchless void structured control" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (param i32) local.get 0 if nop else nop end))",
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected structured raw-skip dead-code-elimination success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[dead-code-elimination]:skip-raw reason=no-dce-candidates",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:dead-code-elimination"))
}

///|
test "dead-code-elimination does not skip raw lift for straight-line dead drops" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 1 drop i32.const 7))",
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-drop dead-code-elimination success without raw skip, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_false(
    text.contains(
      "pass[dead-code-elimination]:skip-raw reason=no-dce-candidates",
    ),
  )
  assert_true(text.contains("perf:timer name=lift"))
  assert_true(text.contains("perf:timer name=pass:dead-code-elimination"))
}

///|
test "ssa-nomerge rewrites structured early-return locals without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     local.get 0
    #|     if
    #|       i32.const 7
    #|       local.set 1
    #|       local.get 1
    #|       return
    #|     else
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected structured raw ssa-nomerge success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes"),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=analysis:ssa"))
}

///|
test "ssa-nomerge rewrites block-target branches without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     i32.const 0
    #|     local.set 1
    #|     block
    #|       local.get 0
    #|       if
    #|         i32.const 7
    #|         local.set 1
    #|         br 1
    #|       end
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected block-branch raw ssa-nomerge success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes"),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=analysis:ssa"))
}

///|
test "heap-store-optimization skips raw lift when the original function has no HSO candidates" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 9))",
      ["heap-store-optimization"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected raw-skip HSO success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(text.contains("pass[heap-store-optimization]:skip-raw"))
  assert_false(text.contains("pass[heap-store-optimization]:func"))
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=analysis:effects"))
  assert_false(text.contains("perf:timer name=analysis:module-context"))
  assert_false(text.contains("perf:timer name=pass:heap-store-optimization"))
}

///|
test "heap-store-optimization skips raw lift when struct allocations cannot feed struct.set" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (type (struct (field (mut i32)))) (func (result i32) (local (ref null 0)) (local.set 0 (struct.new_default 0)) i32.const 7))",
      ["heap-store-optimization"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected allocation-only raw-skip HSO success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[heap-store-optimization]:skip-raw reason=no-heap-store-candidates",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=analysis:module-context"))
  assert_false(text.contains("perf:timer name=analysis:effects"))
}

///|
test "heap-store-optimization aggregates identical raw-skip trace lines across functions" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let input =
    #| (module
    #|   (func (result i32) i32.const 1)
    #|   (func (result i32) i32.const 2))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["heap-store-optimization"],
      options=HotPipelineOptions::new(trace=Some(trace)),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected aggregated HSO raw-skip success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_eq(
    perf_test_count_occurrences(
      text, "pass[heap-store-optimization]:skip-raw reason=no-heap-store-candidates",
    ),
    1,
  )
  assert_false(text.contains("pass[heap-store-optimization]:func"))
}
