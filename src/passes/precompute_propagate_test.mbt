///|
test "precompute-propagate preserves call-local-tee ownership lifetimes" {
  let source =
    #|(module
    #|  (func $make (result i32) i32.const 1)
    #|  (func $consume (param i32) (result i32) local.get 0)
    #|  (func $release (param i32)
    #|    local.get 0
    #|    i32.eqz
    #|    if unreachable end)
    #|  (func (export "run") (result i32) (local i32 i32 i32)
    #|    call $make
    #|    local.tee 0
    #|    call $consume
    #|    local.get 0
    #|    call $release
    #|    local.tee 1
    #|    call $consume
    #|    local.get 1
    #|    call $release
    #|    local.set 2
    #|    local.get 2))
  let original = pass_test_module_from_wat(source)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ownership lifetime preservation, got \{err}")
  }
  @debug.assert_eq(optimized, original)
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=call-local-tee-lifetime-precompute-propagate-noop")
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves structured call-result lifetimes" {
  let source =
    #|(module
    #|  (func $make (result i32) i32.const 1)
    #|  (func $convert (param i32) (result i32) local.get 0)
    #|  (func $release (param i32))
    #|  (func (result i32) (local i32 i32)
    #|    call $make
    #|    local.set 0
    #|    local.get 0
    #|    call $convert
    #|    local.get 0
    #|    if
    #|      local.get 0
    #|      call $release
    #|    end
    #|    local.set 1
    #|    local.get 1))
  let original = pass_test_module_from_wat(source)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected structured lifetime preservation, got \{err}")
  }
  @debug.assert_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(3U)),
    original.pretty_print_func(@lib.FuncIdx::new(3U)),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=call-result-structured-lifetime-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves effect-bracketed multivalue spills" {
  let source =
    #|(module
    #|  (func $side)
    #|  (func $make (result i32 i32 i32)
    #|    i32.const 1
    #|    i32.const 2
    #|    i32.const 3)
    #|  (func $consume (param i32 i32 i32) (result i32)
    #|    local.get 0)
    #|  (func $release (param i32))
    #|  (func (result i32) (local i32 i32 i32)
    #|    call $side
    #|    call $make
    #|    local.set 2
    #|    local.set 1
    #|    local.tee 0
    #|    local.get 1
    #|    local.get 2
    #|    call $consume
    #|    drop
    #|    local.get 0
    #|    call $release
    #|    local.get 1))
  let original = pass_test_module_from_wat(source)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected multivalue spill preservation, got \{err}")
  }
  @debug.assert_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(4U)),
    original.pretty_print_func(@lib.FuncIdx::new(4U)),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=effect-bracketed-multivalue-call-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves call arguments until structured release" {
  let source =
    #|(module
    #|  (func $use (param i32 i32 i32))
    #|  (func $release (param i32))
    #|  (func (param i32) (local i32 i32 i32)
    #|    local.get 0
    #|    local.tee 2
    #|    local.set 3
    #|    i32.const 0
    #|    local.set 1
    #|    i32.const 70608
    #|    local.get 1
    #|    local.get 3
    #|    call $use
    #|    local.get 1
    #|    if
    #|      local.get 1
    #|      call $release
    #|    end
    #|    local.get 3
    #|    if
    #|      local.get 3
    #|      call $release
    #|    end))
  let original = pass_test_module_from_wat(source)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected call argument lifetime preservation, got \{err}")
  }
  @debug.assert_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
    original.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=call-argument-structured-release-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves call arguments until direct release" {
  let source =
    #|(module
    #|  (func $use (param i32 i32 i32))
    #|  (func $release (param i32))
    #|  (func (param i32 i32)
    #|    i32.const 70032
    #|    local.get 0
    #|    local.get 1
    #|    call $use
    #|    local.get 0
    #|    call $release
    #|    local.get 1
    #|    call $release))
  let original = pass_test_module_from_wat(source)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected direct release lifetime preservation, got \{err}")
  }
  @debug.assert_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
    original.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=call-argument-direct-release-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves parameters read before later writes" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    i32.load
    #|    drop
    #|    local.get 0
    #|    i32.const 0
    #|    i32.gt_s
    #|    local.set 1
    #|    i32.const 7
    #|    local.set 0
    #|    local.get 1))
  let original = pass_test_module_from_wat(source)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected parameter lifetime preservation, got \{err}")
  }
  @debug.assert_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(0U)),
    original.pretty_print_func(@lib.FuncIdx::new(0U)),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=parameter-read-before-write-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate folds local-carried constants that plain precompute leaves" {
  let source = "(module (func (result i32) (local i32) i32.const 10 local.set 0 local.get 0 local.get 0 i32.add))"
  let plain = match pass_test_run_pipeline(source, ["precompute"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected plain precompute success, got \{err}")
  }
  assert_true(plain.contains("local.get"), msg=plain)

  let propagated = match
    pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected precompute-propagate success, got \{err}")
  }
  assert_true(propagated.contains("I32(20)"), msg=propagated)
  assert_false(propagated.contains("i32.add"), msg=propagated)
}

///|
test "precompute-propagate folds identical reaching-set constants" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 10
    #|      local.set 1
    #|    else
    #|      i32.const 10
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    local.get 1
    #|    i32.add))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected identical-merge propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(20)"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute-propagate preserves differing reaching-set values" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 10
    #|      local.set 1
    #|    else
    #|      i32.const 20
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    local.get 1
    #|    i32.add))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected differing-merge propagation success, got \{err}")
  }
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute-propagate merges defaultable local entry zero with explicit zero" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 0
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    local.get 1
    #|    i32.add))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected default-entry propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(0)"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute-propagate reasons through tee and block fallthrough values" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    block (result i32)
    #|      nop
    #|      i32.const 7
    #|      local.tee 1
    #|    end
    #|    local.set 0
    #|    local.get 0
    #|    local.get 1
    #|    i32.add))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected fallthrough propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(14)"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute-propagate preserves branch-written local after nested result if" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32) (local i32 i32)
    #|    local.get 0
    #|    if (result i32)
    #|      local.get 1
    #|      local.set 2
    #|      i32.const 0
    #|    else
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.set 2
    #|      i32.const 1
    #|    end
    #|    local.set 3
    #|    local.get 2))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected nested-result-if boundary success, got \{err}")
  }
  assert_true(pretty.contains("(local.get (Local 2))"), msg=pretty)
  assert_false(pretty.contains("I32(0))(end)"), msg=pretty)
}

///|
test "precompute-propagate preserves prior fact across branch writes in nested result if" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32) (local i32 i32)
    #|    i32.const 42
    #|    local.set 2
    #|    local.get 0
    #|    if (result i32)
    #|      local.get 1
    #|      local.set 2
    #|      i32.const 0
    #|    else
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.set 2
    #|      i32.const 1
    #|    end
    #|    local.set 3
    #|    local.get 2))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected stale-prior-fact boundary success, got \{err}")
  }
  assert_true(pretty.contains("(local.get (Local 2))"), msg=pretty)
  assert_false(pretty.contains("I32(42))(end)"), msg=pretty)
}

///|
test "precompute-propagate folds constants in high-local large lowered functions" {
  let source = StringBuilder::new()
  source.write_string("(module (func (result i32) (local")
  for _idx = 0; _idx < 65; _idx = _idx + 1 {
    source.write_string(" i32")
  }
  source.write_string(") i32.const 10 local.set 0")
  for _idx = 0; _idx < 501; _idx = _idx + 1 {
    source.write_string(" nop")
  }
  source.write_string(" local.get 0 local.get 0 i32.add))")
  let pretty = match
    pass_test_run_pipeline(source.to_string(), ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected large-function propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(20)"), msg=pretty)
  assert_false(pretty.contains("local.get"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute-propagate performs one propagation solve and one evaluator rerun" {
  let source =
    #|(module
    #|  (func (param i32 i32 i32) (result i32) (local i32)
    #|    local.get 3
    #|    if
    #|      i32.const 24
    #|      local.set 3
    #|    end
    #|    local.get 3
    #|    if
    #|      i32.const 0
    #|      local.set 2
    #|    end
    #|    local.get 2))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected bounded propagation success, got \{err}")
  }
  assert_true(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("(local.get (Local 3))"), msg=pretty)
}

///|
test "precompute-propagate merges agreeing writes from result if arms" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 1
    #|      i32.const 0
    #|    else
    #|      i32.const 7
    #|      local.set 1
    #|      i32.const 1
    #|    end
    #|    drop
    #|    local.get 1))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected result-if merge propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("(local.get (Local 1))"), msg=pretty)
}

///|
test "precompute-propagate carries tee constants into selected result if arms" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    local.get 0
    #|    local.tee 1
    #|    i32.const 5
    #|    local.tee 2
    #|    i32.lt_s
    #|    if (result i32)
    #|      local.get 2
    #|      local.get 1
    #|      i32.sub
    #|    else
    #|      i32.const 0
    #|    end))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected tee fact propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(5)"), msg=pretty)
  assert_false(pretty.contains("(local.get (Local 2))"), msg=pretty)
}

///|
test "precompute-propagate raw-cleans supported values around unsupported atomic fences" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::atomic_fence(),
            @lib.Instruction::i32_const(@lib.I32(84)),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::i32_div_s(),
            @lib.Instruction::drop(),
            @lib.Instruction::f64_const(@lib.F64(1.5)),
            @lib.Instruction::f64_const(@lib.F64(2.25)),
            @lib.Instruction::f64_add(),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let pretty = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected atomic raw cleanup success, got \{err}")
  }
  assert_true(pretty.contains("atomic.fence"), msg=pretty)
  assert_false(pretty.contains("i32.div_s"), msg=pretty)
  assert_false(pretty.contains("f64.add"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
}

///|
test "precompute-propagate preserves legacy catch-all try flow" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::try_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
              [
                @lib.LegacyCatch::all(
                  @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(2))]),
                ),
              ],
            ),
          ]),
        ),
      ]),
    )
  let pretty = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected legacy try preservation success, got \{err}")
  }
  assert_true(pretty.contains("(try"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I32(2)"), msg=pretty)
}

///|
test "precompute-propagate keeps condition tee facts despite unrelated result-if arm writes" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32 i32 i32)
    #|    local.get 0
    #|    i32.const 5
    #|    local.tee 2
    #|    i32.lt_s
    #|    if (result i32)
    #|      local.get 2
    #|    else
    #|      i32.const 0
    #|    end
    #|    local.set 3
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 2
    #|      i32.const 0
    #|    else
    #|      i32.const 9
    #|      local.set 2
    #|      i32.const 1
    #|    end
    #|    local.set 1
    #|    local.get 3))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected condition tee propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(5)"), msg=pretty)
  assert_false(pretty.contains("(local.get (Local 2))"), msg=pretty)
}

///|
test "precompute-propagate raw control propagation keeps loop invariants" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $sink (param i32))
    #|  (func (param i32) (local i32 i32)
    #|    i32.const 290192
    #|    local.set 1
    #|    memory.size
    #|    drop
    #|    loop
    #|      local.get 1
    #|      drop
    #|      local.get 0
    #|      br_if 0
    #|    end
    #|    local.get 1
    #|    call $sink))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(1U))
    Err(err) =>
      fail("expected raw loop-invariant propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(290192)"), msg=pretty)
  assert_false(pretty.contains("(local.get (Local 1))"), msg=pretty)
}

///|
test "precompute-propagate preserves typed loop-carried local tees" {
  let source =
    #|(module
    #|  (func (param $limit i32) (local $i i32)
    #|    i32.const 0
    #|    loop (param i32)
    #|      local.tee $i
    #|      local.get $limit
    #|      i32.lt_s
    #|      if
    #|        local.get $i
    #|        i32.const 1
    #|        i32.add
    #|        br 1
    #|      end
    #|    end))
    #|
  let trace = match pass_test_capture_trace(source, ["precompute-propagate"]) {
    Ok(trace) => trace
    Err(err) => fail("expected typed-loop propagation boundary, got \{err}")
  }
  assert_true(
    trace.any(fn(line) { line.contains("reason=typed-loop-param-control") }),
    msg=trace.to_string(),
  )
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected typed-loop local preservation, got \{err}")
  }
  assert_true(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
}

///|
test "precompute-propagate raw control propagation does not fold loop-carried locals" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $sink)
    #|  (func (local i32)
    #|    i32.const 0
    #|    local.set 0
    #|    loop
    #|      local.get 0
    #|      i32.const 1
    #|      i32.add
    #|      local.set 0
    #|      local.get 0
    #|      i32.const 3
    #|      i32.lt_s
    #|      br_if 0
    #|    end
    #|    i32.const 0
    #|    i32.load
    #|    drop
    #|    call $sink))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(1U))
    Err(err) => fail("expected loop-carried local preservation, got \{err}")
  }
  assert_true(pretty.contains("i32.lt_s"), msg=pretty)
  assert_true(pretty.contains("(local.get (Local 0))"), msg=pretty)
}
