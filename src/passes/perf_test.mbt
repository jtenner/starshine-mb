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
  let options = HotPipelineOptions::new(trace=Some(trace), perf=Some(perf))

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
