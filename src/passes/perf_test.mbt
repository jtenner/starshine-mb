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
fn perf_test_make_large_void_if_return_ladder_module(
  repetitions : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    local.get 0)\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 800 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  let mut i = 0
  while i < repetitions {
    let tee_local = i % 200 + 1
    let set_local = i % 200 + 201
    out.write_string("    local.get 0\n")
    out.write_string("    if\n")
    out.write_string("      local.get 0\n")
    out.write_string("      call 0\n")
    out.write_string("      local.tee ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("      local.set ")
    out.write_string(set_local.to_string())
    out.write_string("\n")
    out.write_string("      i32.const 1\n")
    out.write_string("      return\n")
    out.write_string("    end\n")
    i = i + 1
  }
  out.write_string("    i32.const 0)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_single_root_value_if_ladder_module(
  repetitions : Int,
) -> String {
  let expr = StringBuilder::new()
  expr.write_string("(i32.const 0)")
  let mut i = 0
  while i < repetitions {
    let tee_local = i % 200 + 1
    let set_local = i % 200 + 301
    let next = StringBuilder::new()
    next.write_string("(block (result i32) (drop ")
    next.write_string(expr.to_string())
    next.write_string(
      ") (if (result i32) (local.get 0) (then (local.get 0) (call 0) (local.tee ",
    )
    next.write_string(tee_local.to_string())
    next.write_string(") (local.set ")
    next.write_string(set_local.to_string())
    next.write_string(
      ") (i32.const 1)) (else (local.get 0) (call 0) (local.tee ",
    )
    next.write_string(tee_local.to_string())
    next.write_string(") (local.set ")
    next.write_string(set_local.to_string())
    next.write_string(") (i32.const 2))))")
    expr.write_string("")
    expr.reset()
    expr.write_string(next.to_string())
    i = i + 1
  }
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    local.get 0)\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 800 {
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
fn perf_test_make_structured_return_ladder_module(repetitions : Int) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    local.get 0)\n")
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 56 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    i32.const 0\n")
  out.write_string("    local.set 0\n")
  out.write_string("    block (result i32)\n")
  out.write_string("      loop\n")
  let mut i = 0
  while i < repetitions {
    let read_local = i % 8
    let tee_local = i + 8
    let set_local = i + 20
    let spill_local = i + 32
    out.write_string("        local.get 0\n")
    out.write_string("        call 0\n")
    out.write_string("        local.tee ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(set_local.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(read_local.to_string())
    out.write_string("\n")
    out.write_string("        if\n")
    out.write_string("          local.get ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("          call 0\n")
    out.write_string("          local.tee ")
    out.write_string((tee_local + 1).to_string())
    out.write_string("\n")
    out.write_string("          local.set ")
    out.write_string(spill_local.to_string())
    out.write_string("\n")
    if i < 3 {
      out.write_string("          local.get ")
      out.write_string((tee_local + 1).to_string())
      out.write_string("\n")
      out.write_string("          return\n")
    } else {
      out.write_string("          local.get ")
      out.write_string((tee_local + 1).to_string())
      out.write_string("\n")
      out.write_string("          drop\n")
    }
    out.write_string("        end\n")
    i = i + 1
  }
  out.write_string("        local.get 0\n")
  out.write_string("        br_if 0\n")
  out.write_string("        local.get 1\n")
  out.write_string("        call 0\n")
  out.write_string("        local.tee 48\n")
  out.write_string("        local.set 49\n")
  out.write_string("        local.get 48\n")
  out.write_string("        local.get 1\n")
  out.write_string("        local.get 0\n")
  out.write_string("        select\n")
  out.write_string("        br 1\n")
  out.write_string("      end\n")
  out.write_string("      i32.const 0\n")
  out.write_string("    end)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_unique_loop_select_return_ladder_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32)\n")
  out.write_string("    local.get 0)\n")
  out.write_string("  (func (param i32 i32) (result i32)\n")
  out.write_string("    (local")
  let mut local_idx = 0
  while local_idx < 56 {
    out.write_string(" i32")
    local_idx = local_idx + 1
  }
  out.write_string(")\n")
  out.write_string("    i32.const 0\n")
  out.write_string("    local.set 0\n")
  out.write_string("    block (result i32)\n")
  out.write_string("      loop\n")
  let mut i = 0
  while i < 4 {
    let tee_local = i + 8
    let set_local = i + 20
    let spill_local = i + 32
    out.write_string("        local.get 0\n")
    out.write_string("        call 0\n")
    out.write_string("        local.tee ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(set_local.to_string())
    out.write_string("\n")
    out.write_string("        local.get ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("        if\n")
    out.write_string("          local.get ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("          call 0\n")
    out.write_string("          local.tee ")
    out.write_string((tee_local + 1).to_string())
    out.write_string("\n")
    out.write_string("          local.set ")
    out.write_string(spill_local.to_string())
    out.write_string("\n")
    if i < 3 {
      out.write_string("          local.get ")
      out.write_string((tee_local + 1).to_string())
      out.write_string("\n")
      out.write_string("          return\n")
    } else {
      out.write_string("          local.get ")
      out.write_string((tee_local + 1).to_string())
      out.write_string("\n")
      out.write_string("          drop\n")
    }
    out.write_string("        end\n")
    i = i + 1
  }
  let mut j = 0
  while j < 28 {
    let tee_local = j % 6 + 40
    let set_local = j % 6 + 46
    out.write_string("        local.get 1\n")
    out.write_string("        call 0\n")
    out.write_string("        local.tee ")
    out.write_string(tee_local.to_string())
    out.write_string("\n")
    out.write_string("        local.set ")
    out.write_string(set_local.to_string())
    out.write_string("\n")
    j = j + 1
  }
  out.write_string("        local.get 0\n")
  out.write_string("        br_if 0\n")
  out.write_string("        local.get 1\n")
  out.write_string("        call 0\n")
  out.write_string("        local.tee 52\n")
  out.write_string("        local.set 53\n")
  out.write_string("        local.get 52\n")
  out.write_string("        local.get 1\n")
  out.write_string("        local.get 0\n")
  out.write_string("        select\n")
  out.write_string("        br 1\n")
  out.write_string("      end\n")
  out.write_string("      i32.const 0\n")
  out.write_string("    end)\n")
  out.write_string(")\n")
  out.to_string()
}

///|
fn perf_test_make_nested_constructor_hot_skip_module() -> String {
  (
    #| (module
    #|   (func (param i32) (result i32)
    #|     local.get 0)
    #|   (func (param i32) (result i32)
    #|     local.get 0)
    #|   (func (param i32) (result i32)
    #|     local.get 0)
    #|   (func (param i32) (result i32)
    #|     local.get 0)
    #|   (func (param i32) (result i32)
    #|     local.get 0)
    #|   (func (param i32 i32) (result i32)
    #|     local.get 0
    #|     local.get 1
    #|     i32.add)
    #|   (func (param i32 i32) (result i32)
    #|     (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|     block
    #|       block
    #|         local.get 0
    #|         call 0
    #|         local.tee 3
    #|         i32.const 1
    #|         i32.eq
    #|         if
    #|           local.get 0
    #|           call 1
    #|           local.tee 4
    #|           i32.const 0
    #|           i32.gt_s
    #|           if
    #|             local.get 4
    #|             local.get 1
    #|             call 5
    #|             local.set 5
    #|           else
    #|             local.get 4
    #|             i32.const 1
    #|             i32.eq
    #|             if
    #|               local.get 4
    #|               call 2
    #|               local.set 5
    #|             end
    #|           end
    #|           local.get 4
    #|           call 3
    #|           local.tee 6
    #|           local.set 7
    #|           br 1
    #|         else
    #|           local.get 0
    #|           call 1
    #|           local.tee 6
    #|           local.set 7
    #|           br 0
    #|         end
    #|         unreachable
    #|       end
    #|       local.get 6
    #|       call 3
    #|       local.set 8
    #|       local.get 7
    #|       local.get 8
    #|       call 5
    #|       local.tee 9
    #|       local.set 10
    #|       return
    #|     end
    #|     local.get 7))
    #|
  )
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
test "remove-unused-brs skips raw lift when the original function has no candidate control flow" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 9))",
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected raw-skip remove-unused-brs success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(text.contains("pass[remove-unused-brs]:skip-raw"))
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:remove-unused-brs"))
}

///|
test "remove-unused-brs rewrites decision ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input =
    #| (module
    #|   (func (param i32 i32) (result i32)
    #|     (block (result i32)
    #|       (block
    #|         (block
    #|           local.get 0
    #|           br_table 0 1
    #|         )
    #|         local.get 1
    #|         i32.const 0
    #|         i32.eq
    #|         if (result i32)
    #|           i32.const 1
    #|         else
    #|           i32.const 0
    #|         end
    #|         br 1
    #|         )
    #|       local.get 1
    #|       i32.const 1
    #|       i32.eq
    #|       if (result i32)
    #|         i32.const 1
    #|       else
    #|         i32.const 0
    #|       end
    #|     )))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected raw decision-ladder remove-unused-brs success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-raw reason=decision-ladder-selects",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:remove-unused-brs"))
}

///|
test "remove-unused-brs skips large void-if return ladders after lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_large_void_if_return_ladder_module(1000)

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected large void-if return ladder raw remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-hot reason=large-void-if-return-ladder-noop",
    ),
  )
  assert_true(text.contains("perf:timer name=lift"))
  assert_true(text.contains("perf:timer name=pass:remove-unused-brs"))
}

///|
test "remove-unused-brs skips single-root value-if ladders after lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_single_root_value_if_ladder_module(320)

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected single-root value-if remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-hot reason=large-void-if-return-ladder-noop",
    ),
  )
  assert_true(text.contains("perf:timer name=lift"))
  assert_true(text.contains("perf:timer name=pass:remove-unused-brs"))
}

///|
test "remove-unused-brs skips structured return ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_structured_return_ladder_module(6)

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected structured return ladder remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-raw reason=structured-return-ladder-noop",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:remove-unused-brs"))
}

///|
test "remove-unused-brs skips unique loop-select return ladders without hot lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_unique_loop_select_return_ladder_module()

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected unique loop-select return ladder remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-raw reason=unique-loop-select-return-ladder-noop",
    ),
  )
  assert_false(text.contains("perf:timer name=lift"))
  assert_false(text.contains("perf:timer name=pass:remove-unused-brs"))
}

///|
test "remove-unused-brs skips nested constructor ladders after lift" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input = perf_test_make_nested_constructor_hot_skip_module()

  match
    pass_test_run_pipeline(
      input,
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected nested constructor ladder remove-unused-brs success, got \{err}",
      )
  }

  let text = perf_test_join_lines(lines)
  assert_true(
    text.contains(
      "pass[remove-unused-brs]:skip-hot reason=nested-constructor-return-ladder-noop",
    ),
  )
  assert_true(text.contains("perf:timer name=lift"))
  assert_true(text.contains("perf:timer name=pass:remove-unused-brs"))
}

///|
test "remove-unused-brs does not build use-def when rewriting tail returns" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 9 return))",
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tail-return remove-unused-brs success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  assert_true(text.contains("perf:timer name=lift"))
  assert_true(text.contains("perf:timer name=pass:remove-unused-brs"))
  assert_false(text.contains("perf:timer name=analysis:use-def"))
}

///|
test "remove-unused-brs trims one mutation step from tail branch payload if cleanup" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())

  match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (block (result i32) (br 0 (if (result i32) (local.get 0) (then (i32.const 1)) (else (i32.const 0)))))))",
      ["remove-unused-brs"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tail-branch-payload remove-unused-brs success, got \{err}")
  }

  let text = perf_test_join_lines(lines)
  let mutations = perf_test_count_occurrences(
    text, "pass[remove-unused-brs]:mutated revision=",
  )
  assert_true(
    mutations <= 3,
    msg="unexpected mutation churn: \{mutations}\n\{text}",
  )
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
test "dead-code-elimination skips raw lift for branchless typed final if" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     local.get 0
    #|     if (result i32)
    #|       i32.const 7
    #|     else
    #|       i32.const 9
    #|     end))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected typed raw-skip dead-code-elimination success, got \{err}")
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
test "dead-code-elimination skips raw lift for branchless typed final if after impure dropped call" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input =
    #| (module
    #|   (type (func (result i32)))
    #|   (import "env" "next" (func (type 0)))
    #|   (func (param i32) (result i32)
    #|     call 0
    #|     drop
    #|     local.get 0
    #|     if (result i32)
    #|       i32.const 7
    #|     else
    #|       i32.const 9
    #|     end))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected impure-drop typed raw-skip dead-code-elimination success, got \{err}",
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
test "dead-code-elimination skips raw lift for branchy typed final control with only live typed results" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     local.get 0
    #|     if (result i32)
    #|       block (result i32)
    #|         i32.const 7
    #|         br 0
    #|       end
    #|     else
    #|       block (result i32)
    #|         i32.const 9
    #|         br 0
    #|       end
    #|     end))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected branchy typed raw-skip dead-code-elimination success, got \{err}",
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
test "dead-code-elimination does not skip raw lift for nonfallthrough typed final if" {
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     local.get 0
    #|     if (result i32)
    #|       i32.const 7
    #|       return
    #|     else
    #|       i32.const 9
    #|       return
    #|     end
    #|     unreachable))
    #|

  match
    pass_test_run_pipeline(
      input,
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected nonfallthrough typed dead-code-elimination success without raw skip, got \{err}",
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
