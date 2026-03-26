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
