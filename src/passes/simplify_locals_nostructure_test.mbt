///|
fn simplify_locals_nostructure_test_many_i32_locals(count : Int) -> String {
  let out = StringBuilder::new()
  for i = 0; i < count; i = i + 1 {
    out.write_string(" (local i32)")
  }
  out.to_string()
}

///|
fn slns_test_block_type_is_nonvoid(block_type : @lib.BlockType) -> Bool {
  match block_type {
    @lib.VoidBlockType => false
    _ => true
  }
}

///|
fn slns_test_instrs_end_without_normal_value(
  instrs : Array[@lib.Instruction],
) -> Bool {
  if instrs.is_empty() {
    return false
  }
  match instrs[instrs.length() - 1] {
    @lib.Unreachable | @lib.Throw(_) | @lib.ThrowRef | @lib.Br(_) => true
    _ => false
  }
}

///|
fn slns_test_instr_has_nonvoid_no_normal_try_table(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.TryTable(block_type, _, @lib.Expr(body)) =>
      (
        slns_test_block_type_is_nonvoid(block_type) &&
        slns_test_instrs_end_without_normal_value(body)
      ) ||
      slns_test_instrs_have_nonvoid_no_normal_try_table(body)
    @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
      slns_test_instrs_have_nonvoid_no_normal_try_table(body)
    @lib.If(_, then_body, else_body) => {
      if slns_test_instrs_have_nonvoid_no_normal_try_table(then_body) {
        return true
      }
      match else_body {
        Some(body) => slns_test_instrs_have_nonvoid_no_normal_try_table(body)
        None => false
      }
    }
    _ => false
  }
}

///|
fn slns_test_instrs_have_nonvoid_no_normal_try_table(
  instrs : Array[@lib.Instruction],
) -> Bool {
  instrs.any(slns_test_instr_has_nonvoid_no_normal_try_table)
}

///|
fn slns_test_module_has_nonvoid_no_normal_try_table(mod_ : @lib.Module) -> Bool {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      funcs.any(fn(func) {
        let @lib.Func(_, @lib.Expr(body)) = func
        slns_test_instrs_have_nonvoid_no_normal_try_table(body)
      })
    None => false
  }
}

///|
test "simplify-locals-nostructure skips redundant second main cycle without deferred writes" {
  // Performance invariant from the SLNS v130 timing audit: a function with no
  // first-cycle-deferred multi-use local.set work should not rescan the root
  // region a second time after a no-change first main/dead-cleanup pass.
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  match
    pass_test_run_pipeline(
      "(module (func (param i32) (local i32) local.get 0 if i32.const 1 local.set 1 end local.get 1 drop))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure no-deferred perf fixture success, got \{err}",
      )
  }
  let main_cycles = lines.filter(fn(line) {
    line.contains("perf:timer name=detail:simplify-locals:main-cycle")
  })
  @debug.assert_eq(main_cycles.length(), 1)
}

///|
test "simplify-locals-nostructure skips changed first-cycle follow-up without deferred writes" {
  // Binaryen's second main cycle exists for deferred multi-use tee work. A
  // straight-line single-use sink mutates the function but has no deferred
  // multi-use local.set, so the pass should not pay for a second full root scan.
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure changed no-deferred perf fixture success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
  let main_cycles = lines.filter(fn(line) {
    line.contains("perf:timer name=detail:simplify-locals:main-cycle")
  })
  @debug.assert_eq(main_cycles.length(), 1)
}

///|
test "simplify-locals-nostructure stops after deferred multi-use follow-up stabilizes" {
  // Performance invariant from the SLNS v130 timing audit: Binaryen's forced
  // follow-up cycle for first-cycle-deferred multi-use sets should be enough for
  // the straight-line tee/drop cleanup family. A third full main/dead scan is a
  // no-op confirmation pass on these generated hot fixtures.
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (local i32) i32.const 1 local.set 0 local.get 0 drop i32.const 2 local.set 0 local.get 0 drop))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure deferred multi-use perf fixture success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
  let main_cycles = lines.filter(fn(line) {
    line.contains("perf:timer name=detail:simplify-locals:main-cycle")
  })
  @debug.assert_eq(main_cycles.length(), 2)
}

///|
test "simplify-locals-nostructure keeps high-frequency subphase timers off the trace hot path" {
  // Performance invariant from the SLNS v130 timing audit: the outer pass timer
  // includes trace emission overhead, so per-cycle subphase timer lines distort
  // pass-local timings on tiny generated functions. Keep the cycle-count timer
  // visible for loop-shape invariants, but avoid emitting the high-frequency
  // inner scan/dead/delete timer lines on each cycle.
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  match
    pass_test_run_pipeline(
      "(module (func (local i32) i32.const 1 local.set 0 local.get 0 drop i32.const 2 local.set 0 local.get 0 drop))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure subphase timer overhead fixture success, got \{err}",
      )
  }
  assert_false(
    lines.any(fn(line) {
      line.contains("perf:timer name=detail:simplify-locals:scan-root-region") ||
      line.contains("perf:timer name=detail:simplify-locals:count-local-gets") ||
      line.contains(
        "perf:timer name=detail:simplify-locals:delete-main-detached",
      ) ||
      line.contains("perf:timer name=detail:simplify-locals:dead-cleanup") ||
      line.contains(
        "perf:timer name=detail:simplify-locals:delete-dead-detached",
      )
    }),
    msg=lines.join("\n"),
  )
}

///|
test "simplify-locals-nostructure sinks straight-line single-use sets" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-nostructure success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure optimizes unrelated locals when an existing tee is present" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32 i32) i32.const 1 local.tee 0 drop i32.const 7 local.set 1 local.get 1))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure existing-tee success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-nostructure optimizes root existing tee with later control" {
  // Binaryen version_130 keeps the control boundary but still removes the
  // dropped root tee and sinks the unrelated local. The remaining Starshine
  // structured-control tee guard must stay narrow enough to allow this shape.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) i32.const 1 local.tee 1 drop local.get 0 if nop end i32.const 7 local.set 2 local.get 2))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure root-tee/control success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
}

///|
test "simplify-locals-nostructure optimizes unrelated root locals with embedded control tee" {
  // Binaryen version_130 can clean unrelated root-level local traffic even when
  // a dropped `local.tee` appears inside a structured-control child. Starshine
  // must not skip the whole function for the embedded tee. This test only
  // requires the unrelated root cleanup; separate safety fixtures keep used
  // structured-control tees from being deleted.
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) local.get 0 if i32.const 7 local.tee 1 drop end i32.const 42 local.set 2 local.get 2))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure embedded tee root cleanup success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_true(pretty.contains("I32(42)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals-nostructure]:skip-hot reason=control-local-tee-hazard-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure removes dead result-if set with embedded tee" {
  // The protected embedded-tee path must still do safe child-local dead-set
  // cleanup for a dropped result `if`: Binaryen removes the unused Local 2 write
  // while preserving the sibling Local 3 write and the later embedded tee hazard.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (local i32 i32 i32) local.get 0 if (result i32) i32.const 20 local.set 2 i32.const 2 else i32.const 30 local.set 3 i32.const 3 end drop local.get 3 if i32.const 120 local.tee 3 drop end local.get 3 drop))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure embedded tee dead result-if cleanup success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if I32"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 3)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 3)"), msg=pretty)
}

///|
test "simplify-locals-nostructure lowers embedded dropped tee to set" {
  // Binaryen version_130 lowers `drop(local.tee)` inside structured control to
  // a plain `local.set`, preserving the write for a later root read without
  // requiring the unsafe broader child deletion that the protected path still
  // forbids.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (local i32) local.get 0 if i32.const 120 local.tee 1 drop end local.get 1 drop))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure embedded dropped-tee success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.tee (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-nostructure optimizes deferred root locals with embedded control tee" {
  // The protected embedded-control-tee path still needs Binaryen's later-cycle
  // root cleanup for deferred multi-use locals. This is safe root traffic: the
  // structured-control child containing the tee remains protected.
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (local i32 i32) i32.const 1 local.set 1 local.get 1 drop i32.const 2 local.set 1 local.get 1 drop local.get 0 if i32.const 7 local.tee 2 drop end))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure embedded tee deferred-root cleanup success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals-nostructure]:skip-hot reason=control-local-tee-hazard-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure optimizes pure local traffic before root calls" {
  // Binaryen version_130 optimizes the local carrier before the structured
  // control and root call. The root stack/local-set hazard guard must stay
  // narrow enough to protect call-valued local writes without blocking this
  // pure pre-call local traffic.
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $side) (func (param i32) (local i32) i32.const 50 local.set 1 local.get 1 drop local.get 0 if nop end call $side))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure pre-call local cleanup success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("I32(50)"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals-nostructure]:skip-hot reason=root-local-set-stack-hazard-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure carries pure tee candidate across value block call argument" {
  // Binaryen version_130 treats a branch-free value block in an earlier call
  // argument as a linear expression boundary for pure pending locals: the later
  // multi-use `local.get` becomes the first `local.tee` use rather than forcing
  // the original `local.set` / `local.get` carrier to remain.
  let optimized = match
    pass_test_run_pipeline(
      "(module (import \"env\" \"f\" (func $f (param i31ref i32))) (func (local i32) i32.const 50 local.set 0 block (result i31ref) ref.null i31 end local.get 0 call $f local.get 0 drop))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure value-block call-arg success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("local.tee (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure skips root stack/local-set call hazards" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      "(module (func $alloc (param i32 i32) (result i32) (local.get 0)) (func (param i32 i32) (local i32) local.get 0 i32.const 2 call $alloc local.set 2 local.get 2 local.get 1 call $alloc drop))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure stack/local-set hazard success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals-nostructure]:skip-hot reason=root-local-set-stack-hazard-noop",
      )
    }),
  )
}

///|
test "simplify-locals-notee-nostructure skips root stack/local-set call hazards" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      "(module (func $alloc (param i32 i32) (result i32) (local.get 0)) (func (param i32 i32) (local i32) local.get 0 i32.const 2 call $alloc local.set 2 local.get 2 local.get 1 call $alloc drop))",
      ["simplify-locals-notee-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure stack/local-set hazard success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals-notee-nostructure]:skip-hot reason=root-local-set-stack-hazard-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-notee-nostructure accepts O4z spelling" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-notee-nostructure success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure drops overwritten pending load set" {
  // Binaryen version_130 converts the first overwritten set into
  // `drop(i32.load ...)` to preserve trap timing and sinks the final load into
  // the single use. This specifically covers the overwritten-pending-set family
  // without using the currently guarded root call/stack-effect hazard surface.
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) (local i32) i32.const 0 i32.load local.set 0 i32.const 4 i32.load local.set 0 local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure overwritten-load success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("load"), msg=pretty)
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure drops overwritten pending load set" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) (local i32) i32.const 0 i32.load local.set 0 i32.const 4 i32.load local.set 0 local.get 0))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure overwritten-load success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("load"), msg=pretty)
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure removes pure zero-read sets" {
  // Binaryen version_130 final dead-set cleanup erases a zero-read pure set in
  // both canonical and no-tee no-structure variants, leaving only inert debris.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (local i32) i32.const 7 local.set 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure pure dead-set success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure removes pure zero-read sets" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (local i32) i32.const 7 local.set 0))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure pure dead-set success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure removes zero-read stack set after unreachable" {
  // Binaryen version_130 removes a zero-read local.set after an unreachable
  // stack producer. This is a focused bottom/unreachable cleanup shape: the set
  // has no material child value in HOT, but the preceding nonfallthrough root
  // makes removing the stack-style consumer safe and keeps the optimized module
  // valid.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) unreachable local.set 0 i32.const 1))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure unreachable dead-set success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure removes zero-read stack set after unreachable" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) unreachable local.set 0 i32.const 1))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure unreachable dead-set success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure flattens no-normal result block before tail unreachable" {
  // Binaryen version_130 rewrites a result block that cannot complete normally
  // before a tail unreachable into flat dropped side-effect/value debris. The
  // flattened raw shape then canonicalizes without the extra `drop(unreachable)`
  // seen in wasm-smith case-009332.
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) memory.size block (result i32) f64.const 1 unreachable end unreachable))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure no-normal result-block flattening success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("F64(1)"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("block I32"), msg=pretty)
}

///|
test "simplify-locals-nostructure reorders const nop in nested result loops" {
  // wasm-smith case-003694 has no local writes, but Binaryen version_130 still
  // runs enough SLNS cleanup to move a pure const after inert `nop` debris in a
  // nested result-loop body. Leaving the input unchanged makes the compare
  // harness canonicalization synthesize a local.set/local.get carrier instead.
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (type $t (func (result f64))) (func (type $t) loop (type $t) loop (type $t) f64.const 1 nop end end))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure result-loop const/nop reorder success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(
    pretty.contains("nopnop(f64.const F64(1))"),
    msg="\{pretty}\ntrace=\{trace}",
  )
}

///|
test "simplify-locals-nostructure drops trapping zero-read sets" {
  // Binaryen version_130 removes the dead local carrier while preserving the
  // load as a drop so its possible trap remains in place.
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (local i32) i32.const 0 i32.load local.set 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure trapping dead-set success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("load"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure drops trapping zero-read sets" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (local i32) i32.const 0 i32.load local.set 0))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure trapping dead-set success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("load"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure drops call-valued zero-read sets" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $side (result i32) i32.const 42) (func (local i32) call $side local.set 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure call dead-set success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure drops call-valued zero-read sets" {
  // The no-tee sibling keeps tee creation disabled but still runs final dead-set
  // cleanup, preserving the call side effect as a drop.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $side (result i32) i32.const 42) (func (local i32) call $side local.set 0))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure call dead-set success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure removes dead copy after equivalent-get cleanup" {
  // Binaryen version_130 canonical SLNS rewrites the surviving copied-local use
  // back to the source param, then final dead-set cleanup removes both copy
  // carriers.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) local.get 0 local.set 1 local.get 1 local.set 2 local.get 1))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure dead-copy cleanup success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure removes dead copy without creating tees" {
  // Binaryen version_130 no-tee SLNS removes the zero-read copy to Local 2 but
  // leaves the Local 1 copy carrier. Starshine performs the same final dead-set
  // cleanup and additionally canonicalizes the pure Local 1 copy back to the
  // source param without creating a tee or synthesizing structure. That is a
  // narrow no-tee Starshine win: fewer local ops for an effect-free copy chain.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) local.get 0 local.set 1 local.get 1 local.set 2 local.get 1))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure dead-copy cleanup success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.tee"), msg=pretty)
}

///|
test "simplify-locals-nostructure drops overwritten pending call set" {
  // Binaryen version_130 preserves the overwritten call's side effect as
  // `drop(call $a)`, erases the dead first write, and sinks the final call to
  // the result. This is the call-valued overwritten-set surface that used to be
  // hidden behind the root stack/local-set hazard guard.
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $a (result i32) i32.const 1) (func $b (result i32) i32.const 2) (func (result i32) (local i32) call $a local.set 0 call $b local.set 0 local.get 0))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure overwritten-call success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals-nostructure]:skip-hot reason=root-local-set-stack-hazard-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-notee-nostructure drops overwritten pending call set" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $a (result i32) i32.const 1) (func $b (result i32) i32.const 2) (func (result i32) (local i32) call $a local.set 0 call $b local.set 0 local.get 0))",
      ["simplify-locals-notee-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure overwritten-call success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals-notee-nostructure]:skip-hot reason=root-local-set-stack-hazard-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure sinks nonthrowing set into try_table body" {
  // `try_table` has the same throwing-value barrier as `try`: pure values may
  // sink into the body, but throwing values must not move inside the handler.
  let optimized = match
    pass_test_run_pipeline(
      "(module (tag $e (param i32)) (func (result i32) (local i32) i32.const 7 local.set 0 (block $h (result i32) (try_table (result i32) (catch $e $h) local.get 0))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure try_table sink success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("try_table I32"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure sinks global.get across unrelated global.set" {
  // Binaryen version_130 treats distinct globals independently for SLNS motion:
  // a pending read of `$g` may sink across a write to `$h`, but not across a
  // write to `$g`. This locks the safe positive half of the effect/order row.
  let optimized = match
    pass_test_run_pipeline(
      "(module (global $g (mut i32) (i32.const 1)) (global $h (mut i32) (i32.const 2)) (func (result i32) (local i32) global.get $g local.set 0 i32.const 9 global.set $h local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure distinct-global success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure keeps global.get before same-global set" {
  // The same Binaryen probe keeps the local when the intervening global.set
  // writes the global that the pending value reads.
  let optimized = match
    pass_test_run_pipeline(
      "(module (global $g (mut i32) (i32.const 1)) (func (result i32) (local i32) global.get $g local.set 0 i32.const 9 global.set $g local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure same-global success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure sinks dynamic read-only loads" {
  // Binaryen version_130 allows two dynamic read-only trapping loads to commute:
  // the dropped later load stays as a drop, while the earlier pending load can
  // sink to the final use. This failed before Starshine allowed narrow one-use
  // Load movement for parameter-address read-only loads.
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (param i32 i32) (result i32) (local i32) local.get 0 i32.load local.set 2 local.get 1 i32.load drop local.get 2))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-nostructure load/load success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("load"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
}

///|
test "simplify-locals-nostructure keeps table.get before same table.set" {
  // Binaryen version_130 keeps the local carrier for table.get across a table
  // write to the same table; table write barriers are still conservative.
  let optimized = match
    pass_test_run_pipeline(
      "(module (table $t0 10 funcref) (func (result funcref) (local funcref) i32.const 0 table.get $t0 local.set 0 i32.const 0 ref.null func table.set $t0 local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure same-table success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.get"), msg=pretty)
  assert_true(pretty.contains("table.set"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure keeps table.get before distinct table.set" {
  // A current Binaryen version_130 probe also keeps the carrier across a write
  // to a different table. Record that as a Binaryen-stationary boundary, not an
  // exact-table positive to implement.
  let optimized = match
    pass_test_run_pipeline(
      "(module (table $t0 10 funcref) (table $t1 10 funcref) (func (result funcref) (local funcref) i32.const 0 table.get $t0 local.set 0 i32.const 0 ref.null func table.set $t1 local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure distinct-table success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.get"), msg=pretty)
  assert_true(pretty.contains("table.set"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure keeps local before direct call barrier" {
  // Binaryen version_130 keeps even a pure const carrier before a direct call to
  // a locally-defined no-arg/no-side-effect callee. This is a refreshed
  // calls/nonthrowing-call precision boundary, not a red-first Starshine gap.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $callee (result i32) i32.const 99) (func (result i32) (local i32) i32.const 7 local.set 0 call $callee drop local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure direct-call barrier success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure sinks ref.as_non_null across read-only load" {
  // Binaryen version_130 sinks a nullable-local ref.as_non_null carrier across a
  // dropped read-only dynamic load. This covers the null-trap ordering positive
  // without using nondefaultable locals, which remain a separate fixup row.
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (param externref i32) (result (ref extern)) (local externref) local.get 0 ref.as_non_null local.set 2 local.get 1 i32.load drop local.get 2 ref.as_non_null))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure ref.as_non_null sink success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("ref.as_non_null"), msg=pretty)
  assert_true(pretty.contains("load"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
}

///|
test "simplify-locals-nostructure canonicalizes no-normal try_table result" {
  // Binaryen version_130 removes the result annotation from a try_table whose
  // body cannot produce a normal value, then leaves explicit unreachable debris
  // when the enclosing result-typed context still needs stack polymorphism. This
  // is the reduced 1000-lane EH size-losing residual family.
  let optimized = match
    pass_test_run_pipeline(
      "(module (tag $e) (elem declare func $dummy) (func $dummy) (func (local funcref) ref.func $dummy local.set 0 local.get 0 drop (drop (block $h (result exnref) (try_table (result exnref) (catch_ref $e $h) unreachable)))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure no-normal try_table success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "simplify-locals-nostructure canonicalizes no-normal if-arm try_table result" {
  // Binaryen version_130 also removes the result annotation when the no-normal
  // try_table is the non-fallthrough arm of a result-typed if feeding an outer
  // value context. The arm must leave explicit unreachable so the if remains
  // stack-polymorphic and the opposite arm can provide the result.
  let optimized = match
    pass_test_run_pipeline(
      "(module (tag $e) (global $g (mut exnref) ref.null noexn) (elem declare func $dummy) (func $dummy) (func $use (param exnref)) (func (local funcref) ref.func $dummy local.set 0 local.get 0 drop (call $use (block $h (result exnref) (if (result exnref) (i32.const 0) (then (try_table (result exnref) (catch_ref $e $h) throw $e)) (else global.get $g))))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure no-normal if-arm try_table success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "simplify-locals-nostructure keeps dead else catch_ref if without local refinalization trigger" {
  // Partial 10000 residual case-001895 exposed this direction: Binaryen
  // version_130 does not void a dead `else` catch_ref try_table without a
  // same-function ref.func local simplification trigger. The no-normal
  // tag-payload if-arm cleanup must stay tied to that trigger.
  let optimized = match
    pass_test_run_pipeline(
      "(module (type $t (func (param i31ref exnref) (result externref))) (import \"env\" \"f\" (func $f (type $t))) (tag $e) (func $use (param i31ref exnref) (result externref) local.get 0 (block $h (result exnref) i32.const 1 (if (result exnref) (then ref.null exn) (else (try_table (result exnref) (catch_ref $e $h) throw $e)))) call $f drop ref.null extern))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure dead else catch_ref success, got \{err}",
      )
  }

  assert_true(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure keeps dead else catch_ref if only local cleanup happens" {
  // Fresh reduction of partial 10000 residual case-001895. Binaryen
  // version_130 still keeps the constant-dead `else` catch_ref try_table
  // result-typed when the function merely performs ordinary local cleanup; a
  // broad dead-arm catch_ref canonicalizer over-voided this shape in Starshine.
  let optimized = match
    pass_test_run_pipeline(
      "(module (type $t (func (param i31ref exnref) (result externref))) (import \"env\" \"f\" (func $f (type $t))) (tag $e) (func $use (param i31ref exnref) (result externref) (local i32) i32.const 50 local.set 2 local.get 2 drop local.get 0 (block $h (result exnref) i32.const 1 (if (result exnref) (then ref.null exn) (else (try_table (result exnref) (catch_ref $e $h) throw $e)))) call $f drop ref.null extern))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure local-cleanup dead else catch_ref success, got \{err}",
      )
  }

  assert_true(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure keeps dead else catch_ref if only later direct call_ref is refinalized" {
  // Direct-lib reduction of partial 10000 residual case-001895. The WAT parser
  // path is blocked on the generated call_ref spelling, so build the small
  // module directly: a dead `else` catch_ref try_table feeds an imported call,
  // and a later block/ref.func/call_ref causes Starshine-only refinalization.
  // Binaryen version_130 keeps the catch_ref try_table result-typed here.
  let trace : Array[String] = []
  let callee_type = @lib.TypeIdx::new(0U)
  let use_type = @lib.TypeIdx::new(1U)
  let import_func = @lib.FuncIdx::new(0U)
  let dummy_func = @lib.FuncIdx::new(1U)
  let tag_idx = @lib.TagIdx::new(0U)
  let exnref_block = @lib.BlockType::val_type(@lib.ValType::ref_null_exn())
  let nullable_callee_block = @lib.BlockType::val_type(
    @lib.ValType::ref_type(
      @lib.RefType::new(true, @lib.HeapType::new(callee_type)),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i31ref(), @lib.ValType::ref_null_exn()],
              [
                @lib.ValType::ref_null(
                  @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
                ),
              ],
            ),
          ),
        ),
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("f"),
          @lib.ExternType::func(use_type),
        ),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(callee_type)]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([dummy_func]),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([callee_type, use_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::block(
              exnref_block,
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32(1)),
                @lib.Instruction::if_(
                  exnref_block,
                  [
                    @lib.Instruction::ref_null(
                      @lib.HeapType::abs(@lib.AbsHeapType::exn()),
                    ),
                  ],
                  Some([
                    @lib.Instruction::try_table(
                      exnref_block,
                      [@lib.Catch::ref_(tag_idx, @lib.LabelIdx::new(0U))],
                      @lib.Expr::new([@lib.Instruction::throw_(tag_idx)]),
                    ),
                  ]),
                ),
              ]),
            ),
            @lib.Instruction::call(import_func),
            @lib.Instruction::drop(),
            @lib.Instruction::block(
              nullable_callee_block,
              @lib.Expr::new([@lib.Instruction::ref_func(dummy_func)]),
            ),
            @lib.Instruction::call_ref(callee_type),
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure dead else direct-call_ref success, got \{err}",
      )
  }
  let trace_text = "\{trace}"
  assert_false(trace_text.contains("skip-invalid-lower"), msg=trace_text)
  assert_true(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure canonicalizes live const-then catch_ref if after refinalization trigger" {
  // Partial 10000 residual case-005987 is the catch_ref sibling of the
  // refinalization-triggered live single-arm catch_all_ref bucket: Binaryen
  // version_130 voids the live no-normal catch_ref try_table when the opposite
  // constant-dead arm supplies the result and the same function also simplifies
  // a ref.func local set/get pair.
  let optimized = match
    pass_test_run_pipeline(
      "(module (elem declare func $dummy) (tag $e) (func $dummy) (func (result exnref) (local funcref) ref.func $dummy local.set 0 local.get 0 drop (block $h (result exnref) (if (result exnref) (i32.const 1) (then (try_table (result exnref) (catch_ref $e $h) throw $e)) (else ref.null exn)))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure refinalized live const-then catch_ref success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure canonicalizes live const-then catch_all_ref if after refinalization trigger" {
  // Fresh partial 10000 residual case-001740 shows a single live `then` arm
  // with a no-normal catch_all_ref try_table under a constant condition.
  // Binaryen version_130 voids that live try_table only in a same-function
  // ref.func local simplification / ReFinalize context while the opposite arm
  // supplies the fallthrough result type.
  let optimized = match
    pass_test_run_pipeline(
      "(module (elem declare func $dummy) (tag $e) (func $dummy) (func (result exnref) (local funcref) ref.func $dummy local.set 0 local.get 0 drop (block $h (result exnref) (if (result exnref) (i32.const 1) (then (try_table (result exnref) (catch_all_ref $h) throw $e)) (else ref.null exn)))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure refinalized live const-then catch_all_ref success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure keeps both-arm catch_all_ref if without refinalization trigger" {
  // Binaryen version_130 keeps both arms result-typed when no same-function
  // local simplification asks ReFinalize. This guards against broad
  // catch_all_ref if-arm rewriting while fixing the case-000251 direction.
  let optimized = match
    pass_test_run_pipeline(
      "(module (tag $e) (func (result exnref) (block $h (result exnref) (if (result exnref) (i32.const 0) (then (try_table (result exnref) (catch_all_ref $h) throw $e)) (else (try_table (result exnref) (catch_all_ref $h) throw $e))))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure both-arm catch_all_ref boundary success, got \{err}",
      )
  }

  assert_true(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(0U)),
  )
}

///|
test "simplify-locals-nostructure canonicalizes both-arm catch_all_ref if after refinalization trigger" {
  // The remaining post-refinalized-live-catchall2 non-annotation residual,
  // case-000251, has both arms as no-normal catch_all_ref try_tables. Binaryen
  // version_130 voids those try_tables only when a same-function ref.func
  // set/get simplification triggers ReFinalize.
  let optimized = match
    pass_test_run_pipeline(
      "(module (elem declare func $dummy) (tag $e) (func $dummy) (func (result exnref) (local funcref) ref.func $dummy local.set 0 local.get 0 drop (block $h (result exnref) (if (result exnref) (i32.const 0) (then (try_table (result exnref) (catch_all_ref $h) throw $e)) (else (try_table (result exnref) (catch_all_ref $h) throw $e))))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure refinalized both-arm catch_all_ref success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure canonicalizes mixed catch_all_ref catch_ref if after refinalization trigger" {
  // Partial 10000 residual case-007981 has a generated call_ref operand block
  // whose constant-condition if has both no-normal EH arms: catch_all_ref in
  // one arm and catch_ref in the other. Binaryen version_130 voids both arms
  // after a same-function ref.func local simplification triggers ReFinalize.
  // This public fixture avoids the generated call_ref spelling while preserving
  // the imported-call operand and mixed EH arm shape.
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (type $ft (func)) (import \"env\" \"f\" (func $f (param f64 exnref))) (elem declare func $dummy) (tag $e) (func $dummy (type $ft)) (func (local funcref) ref.func $dummy local.set 0 local.get 0 drop (call $f (f64.const 1) (block $h (result exnref) (if (result exnref) (i32.const 0) (then (try_table (result exnref) (catch_all_ref $h) throw $e)) (else (try_table (result exnref) (catch_ref $e $h) throw $e)))))))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure refinalized mixed EH arms success, got \{err}",
      )
  }

  let trace_text = "\{trace}"
  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg="\{optimized.pretty_print_func(@lib.FuncIdx::new(2U))}\ntrace=\{trace_text}",
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "simplify-locals-nostructure canonicalizes reverse mixed catch_ref catch_all_ref if after refinalization trigger" {
  // Partial 10000 residual case-009315 is the reverse-arm sibling of
  // case-007981: the constant-dead then arm catches with `catch_ref`, while
  // the live else arm catches with `catch_all_ref`. Binaryen version_130 wraps
  // the operand if in a non-null exn block, voids the if, and leaves explicit
  // unreachable debris after same-function ref.func local cleanup triggers
  // ReFinalize. The initial reduced probe kept a nullable/result-typed wrapper.
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (type $ft (func)) (import \"env\" \"f\" (func $f (param exnref anyref) (result i31ref))) (elem declare func $dummy) (tag $e) (func $dummy (type $ft)) (func (param anyref) (result i31ref) (local funcref) ref.func $dummy local.set 1 local.get 1 drop (call $f (block $h (result exnref) (if (result exnref) (i32.const 0) (then (try_table (result exnref) (catch_ref $e $h) throw $e)) (else (try_table (result exnref) (catch_all_ref $h) throw $e)))) (local.get 0))))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure reverse mixed EH arms success, got \{err}",
      )
  }

  let trace_text = "\{trace}"
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg="\{pretty}\ntrace=\{trace_text}",
  )
  assert_false(
    pretty.contains("if (RefType"),
    msg="expected Binaryen-shaped void if after EH canonicalization\n\{pretty}\ntrace=\{trace_text}",
  )
  assert_false(
    pretty.contains("block (RefType Null (HeapType (AbsHeapType Exn)))"),
    msg="expected non-null exn wrapper after EH canonicalization\n\{pretty}\ntrace=\{trace_text}",
  )
}

///|
test "simplify-locals-nostructure keeps exact table-set if validating while directizing later call_ref local" {
  // Generated case-000251 combines a `funcref` if that feeds `table.set`, a
  // later `ref.func; local.set; local.get; call_ref` wrapper, and the
  // catch_all_ref refinalization trigger. Starshine must rewrite the
  // `ref.null func` arm when narrowing the if result to an exact func type so
  // the exact table-set value validates instead of rolling back the whole
  // lowered cleanup. Use the direct-lib fixture because the public WAT path is
  // still parser-blocked for the required generated `call_ref` spelling.
  let trace : Array[String] = []
  let func_type = @lib.TypeIdx::new(0U)
  let run_type = @lib.TypeIdx::new(1U)
  let callee_idx = @lib.FuncIdx::new(0U)
  let target_local = @lib.LocalIdx::new(1U)
  let tag_idx = @lib.TagIdx::new(0U)
  let imported_table = @lib.TableIdx::new(0U)
  let funcref_block = @lib.BlockType::val_type(@lib.ValType::funcref())
  let exnref_block = @lib.BlockType::val_type(@lib.ValType::ref_null_exn())
  let no_normal_try = fn() {
    @lib.Instruction::try_table(
      exnref_block,
      [@lib.Catch::all_ref(@lib.LabelIdx::new(0U))],
      @lib.Expr::new([@lib.Instruction::throw_(tag_idx)]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::ref_null_exn()]),
          ),
        ),
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("imported_table_0"),
          @lib.ExternType::table(
            @lib.TableType::new(
              @lib.RefType::new(
                true,
                @lib.HeapType::abs(@lib.AbsHeapType::func()),
              ),
              @lib.Limits::i32(1U, Some(3U)),
            ),
          ),
        ),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(func_type)]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([callee_idx]),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type, run_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::from_types([
            @lib.ValType::i32(),
            @lib.ValType::ref_type(
              @lib.RefType::new(true, @lib.HeapType::new(func_type)),
            ),
          ]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::if_(
              funcref_block,
              [@lib.Instruction::ref_func(callee_idx)],
              Some([
                @lib.Instruction::ref_null(
                  @lib.HeapType::abs(@lib.AbsHeapType::func()),
                ),
              ]),
            ),
            @lib.Instruction::table_set(imported_table),
            @lib.Instruction::ref_func(callee_idx),
            @lib.Instruction::local_set(target_local),
            @lib.Instruction::local_get(target_local),
            @lib.Instruction::call_ref(func_type),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::if_(
              exnref_block,
              [no_normal_try()],
              Some([no_normal_try()]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure table-set/refinalization success, got \{err}",
      )
  }
  let trace_text = "\{trace}"
  assert_false(trace_text.contains("skip-invalid-lower"), msg=trace_text)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("Exact (HeapType Idx 0)"), msg=pretty)
  assert_true(
    pretty.contains("ref.null (RefType Null Exact (HeapType Idx 0))"),
    msg=pretty,
  )
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_true(pretty.contains("call_ref"), msg=pretty)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected exact table-set/call_ref cleanup to validate, got \{@validate.validation_error_message(err)}: \{pretty}",
      )
  }
}

///|
test "simplify-locals-nostructure refinalizes table-set if after direct call_ref local" {
  // Partial 10000 residual case-008144 shows that Binaryen version_130 narrows
  // an earlier `funcref` if feeding `table.set` after a same-function
  // `ref.func; local.set; local.get; call_ref` cleanup, even without the EH
  // catch_all_ref trigger covered by case-000251. Keep this direct-lib fixture
  // because the public WAT path is still parser-blocked for the generated
  // call_ref spelling used by the reducer.
  let trace : Array[String] = []
  let func_type = @lib.TypeIdx::new(0U)
  let import_type = @lib.TypeIdx::new(1U)
  let run_type = @lib.TypeIdx::new(0U)
  let callee_idx = @lib.FuncIdx::new(1U)
  let table_idx = @lib.TableIdx::new(0U)
  let target_local = @lib.LocalIdx::new(1U)
  let funcref_block = @lib.BlockType::val_type(@lib.ValType::funcref())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::eqref_null()]),
          ),
        ),
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("imported_func_0"),
          @lib.ExternType::func(import_type),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Limits::i32(1U, Some(3U)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([callee_idx]),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type, run_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::from_types([
            @lib.ValType::i32(),
            @lib.ValType::ref_type(
              @lib.RefType::new(true, @lib.HeapType::new(func_type)),
            ),
          ]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::if_(
              funcref_block,
              [@lib.Instruction::ref_func(callee_idx)],
              Some([
                @lib.Instruction::ref_null(
                  @lib.HeapType::abs(@lib.AbsHeapType::func()),
                ),
              ]),
            ),
            @lib.Instruction::table_set(table_idx),
            @lib.Instruction::ref_func(callee_idx),
            @lib.Instruction::local_set(target_local),
            @lib.Instruction::local_get(target_local),
            @lib.Instruction::call_ref(func_type),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure non-EH table-set/refinalization success, got \{err}",
      )
  }
  let trace_text = "\{trace}"
  assert_false(trace_text.contains("skip-invalid-lower"), msg=trace_text)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("Exact (HeapType Idx 0)"), msg=pretty)
  assert_true(
    pretty.contains("ref.null (RefType Null Exact (HeapType Idx 0))"),
    msg=pretty,
  )
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_true(pretty.contains("call_ref"), msg=pretty)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected non-EH exact table-set/call_ref cleanup to validate, got \{@validate.validation_error_message(err)}: \{pretty}",
      )
  }
}

///|
test "simplify-locals-nostructure refinalizes table-set if across intervening imported call" {
  // Fresh case-008144 still has a non-annotation residual after the simpler
  // non-EH table-set/call_ref local fixture was fixed: Binaryen version_130
  // narrows the earlier funcref if feeding table.set even when both arms are
  // wrapped in transparent funcref blocks and an imported call sits between
  // that table write and the later ref.func local set/get/call_ref cleanup.
  // Keep this direct-lib reduction because public call_ref WAT remains
  // parser-blocked for the generated spelling.
  let trace : Array[String] = []
  let func_type = @lib.TypeIdx::new(0U)
  let import_type = @lib.TypeIdx::new(1U)
  let run_type = @lib.TypeIdx::new(0U)
  let import_func = @lib.FuncIdx::new(0U)
  let callee_idx = @lib.FuncIdx::new(1U)
  let table_idx = @lib.TableIdx::new(0U)
  let target_local = @lib.LocalIdx::new(1U)
  let funcref_block = @lib.BlockType::val_type(@lib.ValType::funcref())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::eqref_null()]),
          ),
        ),
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("imported_func_0"),
          @lib.ExternType::func(import_type),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Limits::i32(1U, Some(3U)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([callee_idx]),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type, run_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::from_types([
            @lib.ValType::i32(),
            @lib.ValType::ref_type(
              @lib.RefType::new(true, @lib.HeapType::new(func_type)),
            ),
          ]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::if_(
              funcref_block,
              [
                @lib.Instruction::block(
                  funcref_block,
                  @lib.Expr::new([
                    @lib.Instruction::block(
                      funcref_block,
                      @lib.Expr::new([@lib.Instruction::ref_func(callee_idx)]),
                    ),
                  ]),
                ),
              ],
              Some([
                @lib.Instruction::block(
                  funcref_block,
                  @lib.Expr::new([
                    @lib.Instruction::ref_null(
                      @lib.HeapType::abs(@lib.AbsHeapType::func()),
                    ),
                  ]),
                ),
              ]),
            ),
            @lib.Instruction::table_set(table_idx),
            @lib.Instruction::call(import_func),
            @lib.Instruction::drop(),
            @lib.Instruction::ref_func(callee_idx),
            @lib.Instruction::local_set(target_local),
            @lib.Instruction::local_get(target_local),
            @lib.Instruction::call_ref(func_type),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure intervening-call table-set/refinalization success, got \{err}",
      )
  }
  let trace_text = "\{trace}"
  assert_false(trace_text.contains("skip-invalid-lower"), msg=trace_text)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("Exact (HeapType Idx 0)"), msg=pretty)
  assert_true(
    pretty.contains("ref.null (RefType Null Exact (HeapType Idx 0))"),
    msg=pretty,
  )
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_true(pretty.contains("call_ref"), msg=pretty)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected intervening-call exact table-set/call_ref cleanup to validate, got \{@validate.validation_error_message(err)}: \{pretty}",
      )
  }
}

///|
test "simplify-locals-nostructure keeps live no-normal catch_all_ref block without refinalization trigger" {
  // Binaryen version_130 keeps this live call-argument block result-typed when
  // the same function has no local simplification that asks Binaryen to
  // ReFinalize. This is the case-000305 boundary that rejected broad live-block
  // rewriting.
  let optimized = match
    pass_test_run_pipeline(
      "(module (import \"env\" \"f\" (func $f (param exnref i64))) (func (block $h (result exnref) (try_table (result exnref) (catch_all_ref $h) unreachable)) i64.const 0 call $f))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure live catch_all_ref boundary success, got \{err}",
      )
  }

  assert_true(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure canonicalizes live no-normal catch_all_ref block after refinalization trigger" {
  // Adding only a same-function ref.func local set/get pair makes Binaryen
  // version_130 simplify that local traffic and then ReFinalize the live
  // call-argument block to a void try_table plus explicit unreachable. This is
  // the narrowed case-000692 direction; it must not become a general live-block
  // rewrite.
  let optimized = match
    pass_test_run_pipeline(
      "(module (import \"env\" \"f\" (func $f (param exnref i64))) (elem declare func $dummy) (func $dummy) (func (local funcref) ref.func $dummy local.set 0 local.get 0 drop (block $h (result exnref) (try_table (result exnref) (catch_all_ref $h) unreachable)) i64.const 0 call $f))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure refinalized live catch_all_ref success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "simplify-locals-nostructure canonicalizes refinalized tail catch_all_ref block" {
  // Partial 10000 residual case-004556 shows the same Binaryen ReFinalize
  // discriminator as case-000692, but with prefix statements before a tail
  // no-normal catch_all_ref try_table inside the result block. Binaryen
  // version_130 voids the tail try_table and narrows the block under the
  // same-function ref.func local simplification trigger.
  let optimized = match
    pass_test_run_pipeline(
      "(module (elem declare func $dummy) (tag $e) (func $dummy) (func (result exnref) (local funcref) ref.func $dummy local.set 0 local.get 0 drop (block $h (result exnref) nop (try_table (result exnref) (catch_all_ref $h) throw $e))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure refinalized tail catch_all_ref success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure canonicalizes refinalized function-tail catch_all_ref" {
  // Partial 10000 residuals case-004933, case-007606, and case-007797 are
  // generated function-tail catch_all_ref siblings of the function-tail
  // catch_ref case-005508: Binaryen version_130 wraps the function result in a
  // non-null exn block, voids the no-normal tail try_table, and leaves explicit
  // unreachable only under the same-function ref.func local simplification /
  // ReFinalize discriminator.
  let optimized = match
    pass_test_run_pipeline(
      "(module (elem declare func $dummy) (tag $e) (func $dummy) (func (result exnref) (local funcref) ref.func $dummy local.set 0 local.get 0 drop nop (try_table (result exnref) (catch_all_ref 0) throw $e)))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure refinalized function-tail catch_all_ref success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure canonicalizes refinalized function-tail catch_ref" {
  // Partial 10000 residual case-005508 is the catch_ref sibling of the
  // function-tail catch_all_ref bucket: Binaryen version_130 wraps the
  // function result in a non-null exn block and voids the no-normal tail
  // try_table only under the same-function ref.func local simplification
  // / ReFinalize discriminator.
  let optimized = match
    pass_test_run_pipeline(
      "(module (elem declare func $dummy) (tag $e) (func $dummy) (func (result exnref) (local funcref) ref.func $dummy local.set 0 local.get 0 drop nop (try_table (result exnref) (catch_ref $e 0) throw $e)))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure refinalized function-tail catch_ref success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure canonicalizes dead then catch_all_ref if after refinalization trigger" {
  // Partial 10000 residual case-009494 has the catch_all_ref try_table in the
  // constant-dead then arm of an imported-call operand block, with the opposite
  // arm supplying `ref.null exn`. Binaryen version_130 still voids that
  // no-normal arm after a same-function ref.func local simplification triggers
  // ReFinalize. This public fixture avoids the generated call_ref spelling that
  // remains parser-blocked in the full residual.
  let optimized = match
    pass_test_run_pipeline(
      "(module (type $ft (func)) (import \"env\" \"f\" (func $f (param i31ref exnref))) (elem declare func $dummy) (tag $e) (func $dummy (type $ft)) (func (local funcref) ref.func $dummy local.set 0 local.get 0 drop (call $f (ref.null i31) (block $h (result exnref) (if (result exnref) (i32.const 0) (then (try_table (result exnref) (catch_all_ref $h) throw $e)) (else ref.null exn))))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure refinalized dead-then catch_all_ref success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "simplify-locals-nostructure keeps throwing set before try_table body" {
  // Calls may throw, so Binaryen drops the pending sinkable before entering
  // the try_table. Sinking this call into the body could make the handler catch
  // an exception that was previously outside the handler.
  let optimized = match
    pass_test_run_pipeline(
      "(module (import \"env\" \"maybe\" (func $maybe (result i32))) (tag $e (param i32)) (func (result i32) (local i32) call $maybe local.set 0 (block $h (result i32) (try_table (result i32) (catch $e $h) local.get 0))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure throwing try_table barrier success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure optimizes unrelated locals when an existing tee is present" {
  // `notee` disables creating new tees, but Binaryen version_130 still cleans
  // existing dropped tees and sinks unrelated single-use local traffic.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32 i32) i32.const 1 local.tee 0 drop i32.const 7 local.set 1 local.get 1))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure existing-tee success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
fn simplify_locals_nostructure_test_large_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  let mut idx = 0
  while idx < 101 {
    out.write_string("  (func $f")
    out.write_string(idx.to_string())
    out.write_string(" (result i32) (local i32) i32.const ")
    out.write_string((idx & 1).to_string())
    out.write_string(" local.set 0 local.get 0)\n")
    idx += 1
  }
  out.write_string(")")
  out.to_string()
}

///|
test "simplify-locals-notee-nostructure runs safe large modules" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      simplify_locals_nostructure_test_large_module(),
      ["simplify-locals-notee-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure large module success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains("pass[simplify-locals-notee-nostructure]:skip-large-module")
    }),
    msg=trace.to_string(),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(100U))
  assert_true(pretty.contains("I32(0)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure folds dead exact-slot set-copy local" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) (local.set 2 (block $block (result i32) (if (local.get 0) (then (i32.const 7) (br $block))) (i32.const 9))) (local.set 1 (local.get 2)) (i32.add (local.get 1) (local.get 1))))",
      ["simplify-locals-nostructure", "reorder-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure set-copy fold success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("Local 1"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
}

///|
test "simplify-locals-nostructure folds exact-slot set-copy across cleanup nop" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) loop $l block $block (result i32) (if (local.get 0) (then (return (i32.const 0)))) (i32.const 9) end local.set 2 nop local.get 2 local.set 1 (br_if $l (local.get 0)) end (i32.add (local.get 1) (local.get 1))))",
      ["simplify-locals-nostructure", "vacuum", "reorder-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure nop-separated set-copy fold success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("Local 1"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
}

///|
test "simplify-locals-nostructure keeps tee before dependent loads" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (param i32) (result i32) (local i32 i32 i32 i32 i32 i32) local.get 0 local.tee 5 i32.load offset=20 align=1 local.get 5 i32.load offset=12 align=1 local.get 5 i32.load offset=16 align=1 local.set 4 local.set 3 local.set 2 local.get 2 local.get 3 local.get 4 i32.add i32.add))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure dependent-load success, got \{err}",
      )
  }

  let instrs = match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs.get(0) {
        Some(@lib.Func(_, @lib.Expr(instrs))) => instrs
        None => fail("expected first function body")
      }
    None => fail("expected code section")
  }
  match instrs[0] {
    @lib.LocalGet(@lib.LocalIdx(local_id)) => @debug.assert_eq(local_id, 0U)
    _ => fail("expected source pointer local.get to remain first")
  }
  match instrs[1] {
    @lib.LocalTee(@lib.LocalIdx(local_id)) => @debug.assert_eq(local_id, 5U)
    _ => fail("expected dependent-load local.tee to remain before loads")
  }
}

///|
test "simplify-locals-nostructure preserves used condition load tee" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func $incref (param i32)) (func $decref (param i32)) (func $free (param i32)) (func (param $io i32) (result i32) (local $field i32)" +
      simplify_locals_nostructure_test_many_i32_locals(110) +
      " (local $cnt i32) (block $block (if (i32.const 0) (then (return (i32.const 0))) (else (br $block))) (unreachable)) (local.set $field (i32.load offset=32 align=1 (local.get $io))) (if (i32.gt_s (local.tee $cnt (i32.load align=1 (local.get $io))) (i32.const 1)) (then nop (i32.store align=1 (local.get $io) (i32.sub (local.get $cnt) (i32.const 1))) (call $incref (local.get $field))) (else (if (i32.eq (local.get $cnt) (i32.const 1)) (then (call $decref (i32.load offset=40 align=1 (local.get $io))) (call $free (local.get $io)))))) (call $decref (local.get $field)) (i32.const 1)))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure condition tee preservation success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 112)"), msg=pretty)
}

///|
test "simplify-locals-nostructure creates tees for later-cycle multi-use locals" {
  // Binaryen version_130's first cycle refuses multi-use tee creation, then the
  // forced later cycle sinks the value through a fresh tee. This is the
  // tee-enabled half of the no-structure template identity.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0 local.get 0 i32.add))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-nostructure tee success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.tee (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure avoids tees when the first use is dropped" {
  // A dropped first use can be cleaned without a tee; Binaryen version_130 emits
  // only the final constant carrier after replacing the drop(get) pair.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0 drop local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure dropped-first-use success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.tee (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure does not create tees for multi-use locals" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0 local.get 0 i32.add))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-notee-nostructure success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.tee (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure preserves Binaryen const-nop loop shape" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result f64) loop (result f64) f64.const 1.0 nop end))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-notee-nostructure success, got \{err}")
  }

  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [@lib.Func(locals, @lib.Expr([@lib.Loop(_, @lib.Expr(body))]))]
      )
    ) => {
      @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::f64()]))
      @debug.assert_eq(body.length(), 3)
      @debug.assert_eq(body[0], @lib.Instruction::nop())
      @debug.assert_eq(body[1], @lib.Instruction::nop())
      match body[2] {
        @lib.F64Const(_) => ()
        other => fail("expected trailing f64 const after nops, got \{other}")
      }
    }
    other =>
      fail(
        "expected one loop body after no-tee no-structure pass, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "simplify-locals-nostructure canonicalizes late equivalent gets" {
  // Binaryen version_130 keeps the no-structure late equivalent-local phase:
  // it rewrites both uses of the copied local back to the original param and
  // the final dead-set cleanup removes the now-unused copy set.
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (param i32) (result f32) (local i32) local.get 0 local.set 1 local.get 1 i32.const 1 i32.store local.get 1 f32.load))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure equivalent-get success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("store"), msg=pretty)
  assert_true(pretty.contains("load"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-nostructure does not synthesize if results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 1 local.set 1 else i32.const 2 local.set 1 end local.get 1))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-nostructure success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if I32"), msg=pretty)
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-nostructure sinks across fallthrough block without block result" {
  // Binaryen version_130 sinks this simple fallthrough block carrier but keeps
  // the block itself void; this is not the disabled structure-synthesis family.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) block i32.const 7 local.set 0 end local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure fallthrough-block success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("block (Void)"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("block I32"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure does not synthesize loop results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) loop i32.const 7 local.set 0 end local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure loop-no-structure success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("loop I32"), msg=pretty)
  assert_true(pretty.contains("loop (Void)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure does not synthesize one-armed if results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 7 local.set 1 end local.get 1))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure one-armed-if success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if I32"), msg=pretty)
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-nostructure does not synthesize branch-created block results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) block $b i32.const 7 local.set 0 br $b end local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure branch-block success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("block I32"), msg=pretty)
  assert_true(pretty.contains("block (Void)"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure exact slot replays code-pushing and tuple cleanup before vacuum and reorder-locals" {
  let trace : Array[String] = []
  let input = pass_test_module_from_wat(
    "(module (func (result i32) (local i32 i32 i32) block (result i32 i32 i32) i32.const 10 i32.const 20 i32.const 30 end local.set 2 local.set 1 local.set 0 local.get 0))",
  )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      simplify_locals_nostructure_exact_slot_passes(),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure exact slot replay success, got \{err}",
      )
  }

  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected exact slot replay module to validate, got \{err}")
  }

  let starts = trace.filter(fn(line) {
    line.contains("pass[") && line.contains(":start")
  })
  assert_true(starts.length() >= 4, msg=starts.to_string())
  assert_true(
    starts[0].contains("pass[code-pushing]:start"),
    msg=starts.to_string(),
  )
  assert_true(
    starts[1].contains("pass[tuple-optimization]:start"),
    msg=starts.to_string(),
  )
  assert_true(
    starts[2].contains("pass[simplify-locals-nostructure]:start"),
    msg=starts.to_string(),
  )
  assert_true(
    trace.any(fn(line) { line.contains("pass[vacuum]:funcs") }),
    msg=trace.to_string(),
  )
  assert_true(
    starts[3].contains("pass[reorder-locals]:start"),
    msg=starts.to_string(),
  )

  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(locals, _)])) =>
      @debug.assert_eq(locals, @lib.Locals::empty())
    other =>
      fail(
        "expected exact slot replay single-function output, got \{@debug.to_string(other)}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(10)"), msg=pretty)
  assert_false(pretty.contains("local.set"), msg=pretty)
  assert_false(pretty.contains("local.get"), msg=pretty)
}

///|
test "simplify-locals-nostructure exact slot keeps the no-structure if boundary" {
  let trace : Array[String] = []
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 1 local.set 1 else i32.const 2 local.set 1 end local.get 1))",
  )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      simplify_locals_nostructure_exact_slot_passes(),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure exact slot no-structure replay success, got \{err}",
      )
  }

  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected exact slot no-structure replay module to validate, got \{err}",
      )
  }

  let starts = trace.filter(fn(line) {
    line.contains("pass[") && line.contains(":start")
  })
  assert_true(starts.length() >= 5, msg=starts.to_string())
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if I32"), msg=pretty)
  assert_true(pretty.contains("if (Void)"), msg=pretty)
}
