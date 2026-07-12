///|
fn sgo_test_run(text : String) -> @lib.Module {
  match pass_test_run_pipeline(text, ["simplify-globals-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) =>
      abort("expected simplify-globals-optimizing success, got \{err}")
  }
}

///|
fn sgo_test_run_twice(text : String) -> @lib.Module {
  match
    pass_test_run_pipeline(text, [
      "simplify-globals-optimizing", "simplify-globals-optimizing",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      abort("expected two simplify-globals-optimizing runs success, got \{err}")
  }
}

///|
fn sgo_test_run_with_trace(text : String) -> (@lib.Module, Array[String]) {
  let trace : Array[String] = []
  let mod_ = match
    run_hot_pipeline(
      pass_test_module_from_wat(text),
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["simplify-globals-optimizing"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      abort("expected traced simplify-globals-optimizing success, got \{err}")
  }
  (mod_, trace)
}

///|
fn sgo_test_run_with_perf_trace(text : String) -> (@lib.Module, Array[String]) {
  let trace : Array[String] = []
  let trace_fn = fn(line) { trace.push(line) }
  let perf = HotPerfSession::new(
    trace=trace_fn,
    dump_options=HotPerfDumpOptions::new(),
  )
  let mod_ = match
    run_hot_pipeline(
      pass_test_module_from_wat(text),
      HotPipelineOptions::new(trace=Some(trace_fn), perf=Some(perf)),
      ["simplify-globals-optimizing"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      abort(
        "expected perf-traced simplify-globals-optimizing success, got \{err}",
      )
  }
  (mod_, trace)
}

///|
fn sgo_test_make_touched_cleanup_fixture(
  touched_count : Int,
  extra_untouched_count? : Int = 0,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (global $g (mut i32) (i32.const 7))\n")
  for idx = 0; idx < touched_count; idx = idx + 1 {
    out.write_string("  (func $t\{idx}\n    global.get $g\n    drop)\n")
  }
  for idx = 0; idx < extra_untouched_count; idx = idx + 1 {
    out.write_string("  (func $u\{idx}\n    i32.const 99\n    drop)\n")
  }
  out.write_string(")")
  out.to_string()
}

///|
fn sgo_test_make_large_touched_function_fixture(
  local_count : Int,
  extra_untouched_count? : Int = 0,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (global $g (mut i32) (i32.const 7))\n")
  out.write_string("  (func $large")
  for _idx = 0; _idx < local_count; _idx = _idx + 1 {
    out.write_string(" (local i32)")
  }
  out.write_string("\n    global.get $g\n    drop)\n")
  for idx = 0; idx < extra_untouched_count; idx = idx + 1 {
    out.write_string("  (func $u\{idx}\n    i32.const 99\n    drop)\n")
  }
  out.write_string(")")
  out.to_string()
}

///|
fn sgo_test_make_mixed_large_and_small_touched_fixture(
  local_count : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (global $g (mut i32) (i32.const 7))\n")
  out.write_string("  (func $large")
  for _idx = 0; _idx < local_count; _idx = _idx + 1 {
    out.write_string(" (local i32)")
  }
  out.write_string("\n    global.get $g\n    drop)\n")
  out.write_string("  (func $small\n    global.get $g\n    drop)\n")
  out.write_string(")")
  out.to_string()
}

///|
fn sgo_test_make_large_touched_body_fixture(nop_count : Int) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (global $g (mut i32) (i32.const 7))\n")
  out.write_string("  (func $large\n")
  for _idx = 0; _idx < nop_count; _idx = _idx + 1 {
    out.write_string("    nop\n")
  }
  out.write_string("    global.get $g\n    drop)\n")
  out.write_string(")")
  out.to_string()
}

///|
fn sgo_test_run_module(mod_ : @lib.Module) -> @lib.Module {
  match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), [
      "simplify-globals-optimizing",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      abort("expected simplify-globals-optimizing module success, got \{err}")
  }
}

///|
fn sgo_test_defined_global_type(
  mod_ : @lib.Module,
  defined_idx : Int,
) -> @lib.GlobalType raise {
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      match globals.get(defined_idx) {
        Some(@lib.Global(global_type, _)) => global_type
        None => fail("expected defined global \{defined_idx}")
      }
    None => fail("expected global section")
  }
}

///|
fn sgo_test_first_data_offset_instr(
  mod_ : @lib.Module,
) -> @lib.Instruction raise {
  match mod_.data_sec {
    Some(@lib.DataSec([@lib.Data(@lib.Active(_, @lib.Expr([instr])), _)])) =>
      instr
    other =>
      fail("expected one active data offset, got \{@debug.to_string(other)}")
  }
}

///|
fn sgo_test_first_defined_func_instrs(
  mod_ : @lib.Module,
) -> Array[@lib.Instruction] raise {
  match mod_.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs)), ..])) => instrs
    other =>
      fail(
        "expected at least one defined function, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn sgo_test_first_defined_func_local_count(mod_ : @lib.Module) -> Int raise {
  match mod_.code_sec {
    Some(@lib.CodeSec([@lib.Func(locals, _), ..])) => locals.length()
    other =>
      fail(
        "expected at least one defined function, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn sgo_test_count_instr(
  instrs : Array[@lib.Instruction],
  needle : @lib.Instruction,
) -> Int {
  let mut count = 0
  for instr in instrs {
    if instr == needle {
      count += 1
    }
    match instr {
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        count += sgo_test_count_instr(body, needle)
      @lib.If(_, then_body, else_body) => {
        count += sgo_test_count_instr(then_body, needle)
        match else_body {
          Some(else_body) => count += sgo_test_count_instr(else_body, needle)
          None => ()
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        count += sgo_test_count_instr(body, needle)
      _ => ()
    }
  }
  count
}

///|
fn sgo_test_defined_global_init_instrs(
  mod_ : @lib.Module,
  defined_idx : Int,
) -> Array[@lib.Instruction] raise {
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      match globals.get(defined_idx) {
        Some(@lib.Global(_, @lib.Expr(instrs))) => instrs
        None => fail("expected defined global \{defined_idx}")
      }
    None => fail("expected global section")
  }
}

///|
fn sgo_test_first_typed_elem_expr_instr(
  mod_ : @lib.Module,
) -> @lib.Instruction raise {
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      match elems.get(0) {
        Some(@lib.Elem(_, @lib.TypedExprsElemKind(_, exprs))) =>
          match exprs.get(0) {
            Some(@lib.Expr([instr])) => instr
            other =>
              fail(
                "expected first single-instruction elem expr, got \{@debug.to_string(other)}",
              )
          }
        other =>
          fail("expected typed elem segment, got \{@debug.to_string(other)}")
      }
    None => fail("expected elem section")
  }
}

///|
test "simplify-globals-optimizing registers as an active module pass" {
  match pass_registry_lookup("simplify-globals-optimizing") {
    Some(entry) => {
      @debug.assert_eq(entry.category, HotPassRegistryCategory::module_pass())
      @debug.assert_eq(entry.descriptor, None)
    }
    None => fail("expected simplify-globals-optimizing registry entry")
  }
}

///|
test "simplify-globals-optimizing perf trace breaks down core phases" {
  let (_, trace) = sgo_test_run_with_perf_trace(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 41))
      #|  (func (result i32)
      #|    global.get $g
      #|    i32.const 1
      #|    i32.add))
      #|
    ),
  )
  let text = trace.to_string()
  assert_true(
    text.contains("perf:timer name=detail:sgo:collect-global-infos"),
    msg=text,
  )
  assert_true(
    text.contains("perf:timer name=detail:sgo:rewrite-code"),
    msg=text,
  )
  assert_true(
    text.contains("perf:timer name=detail:sgo:nested-total"),
    msg=text,
  )
  assert_true(
    text.contains("perf:timer name=detail:sgo:nested:optimize-instructions"),
    msg=text,
  )
  assert_true(
    text.contains("nested-pass-skip name=vacuum reason=no-touched-candidates"),
    msg=text,
  )
}

///|
test "simplify-globals-optimizing promotes private never-written globals and reruns default cleanup" {
  let (optimized, trace) = sgo_test_run_with_trace(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 41))
      #|  (func (export "run") (result i32)
      #|    global.get $g
      #|    i32.const 1
      #|    i32.add))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(42)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
  assert_true(
    trace.contains(
      "pass[simplify-globals-optimizing]:nested-cleanup touched=1 prefix=default",
    ),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) { line.contains("precompute-propagate") }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-globals-optimizing only reruns cleanup on touched functions" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 7))
      #|  (func $touched
      #|    global.get $g
      #|    drop)
      #|  (func $untouched
      #|    i32.const 99
      #|    drop))
      #|,
    ),
  )

  let touched = optimized.pretty_print_defined_func(0U)
  let untouched = optimized.pretty_print_defined_func(1U)
  assert_false(touched.contains("global.get"), msg=touched)
  assert_false(touched.contains("drop"), msg=touched)
  assert_true(untouched.contains("drop"), msg=untouched)
  assert_true(untouched.contains("I32(99)"), msg=untouched)
}

///|
fn sgo_test_make_large_dead_tail_after_unreachable_fixture(
  nop_count : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (global $g (mut i32) (i32.const 7))\n")
  out.write_string("  (func $f\n")
  out.write_string("    i32.const 0\n    drop\n")
  out.write_string("    block\n      unreachable\n    end\n")
  out.write_string("    global.get $g\n    drop\n")
  out.write_string("    call $side\n")
  for _idx = 0; _idx < nop_count; _idx = _idx + 1 {
    out.write_string("    nop\n")
  }
  out.write_string("  )\n")
  out.write_string("  (func $side))")
  out.to_string()
}

///|
fn sgo_test_make_large_safe_trunc_prefix_before_unreachable_fixture(
  trunc_source : String,
  nop_count : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (global $g (mut i32) (i32.const 7))\n")
  out.write_string("  (func $f\n")
  out.write_string("    ")
  out.write_string(trunc_source)
  out.write_string("\n    i32.trunc_f32_s\n    drop\n")
  out.write_string(
    "    block\n      i32.const 1\n      br_table 0 0\n    end\n",
  )
  out.write_string("    unreachable\n")
  out.write_string("    global.get $g\n    drop\n")
  for _idx = 0; _idx < nop_count; _idx = _idx + 1 {
    out.write_string("    nop\n")
  }
  out.write_string("  ))")
  out.to_string()
}

///|
test "simplify-globals-optimizing cleans large touched dead tail after unreachable" {
  let optimized = sgo_test_run(
    sgo_test_make_large_dead_tail_after_unreachable_fixture(1100),
  )
  let instrs = try! sgo_test_first_defined_func_instrs(optimized)
  @debug.assert_eq(instrs, [@lib.Instruction::unreachable_()])
}

///|
test "simplify-globals-optimizing cleans safe trunc prefix before guaranteed unreachable tail" {
  let optimized = sgo_test_run(
    sgo_test_make_large_safe_trunc_prefix_before_unreachable_fixture(
      "f32.const 12", 1100,
    ),
  )
  let instrs = try! sgo_test_first_defined_func_instrs(optimized)
  @debug.assert_eq(instrs, [@lib.Instruction::unreachable_()])
}

///|
fn sgo_test_make_large_safe_trunc_batch_before_unreachable_fixture(
  nop_count : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (global $g (mut i32) (i32.const 7))\n")
  out.write_string("  (func $f (local i64 f32)\n")
  out.write_string("    f32.const 12\n    i32.trunc_f32_s\n    drop\n")
  out.write_string("    f32.const 12\n    i32.trunc_f32_u\n    drop\n")
  out.write_string("    f64.const 12\n    i32.trunc_f64_s\n    drop\n")
  out.write_string("    f64.const 12\n    i32.trunc_f64_u\n    drop\n")
  out.write_string("    f32.const 12\n    i64.trunc_f32_s\n    drop\n")
  out.write_string("    f32.const 12\n    i64.trunc_f32_u\n    drop\n")
  out.write_string("    f64.const 12\n    i64.trunc_f64_s\n    drop\n")
  out.write_string("    f64.const 12\n    i64.trunc_f64_u\n    drop\n")
  out.write_string(
    "    block\n      i32.const 1\n      br_table 0 0\n    end\n",
  )
  out.write_string("    block\n      unreachable\n    end\n")
  out.write_string("    global.get $g\n    drop\n")
  for _idx = 0; _idx < nop_count; _idx = _idx + 1 {
    out.write_string("    nop\n")
  }
  out.write_string("  ))")
  out.to_string()
}

///|
test "simplify-globals-optimizing cleans generated safe trunc prefix batch before unreachable tail" {
  let optimized = sgo_test_run(
    sgo_test_make_large_safe_trunc_batch_before_unreachable_fixture(1100),
  )
  let instrs = try! sgo_test_first_defined_func_instrs(optimized)
  @debug.assert_eq(instrs, [@lib.Instruction::unreachable_()])
  @debug.assert_eq(try! sgo_test_first_defined_func_local_count(optimized), 0)
}

///|
test "simplify-globals-optimizing keeps potentially trapping trunc prefix before unreachable tail" {
  let optimized = sgo_test_run(
    sgo_test_make_large_safe_trunc_prefix_before_unreachable_fixture(
      "f32.const nan", 1100,
    ),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("trunc_f32s"), msg=pretty)
  assert_true(pretty.contains("F32(NaN)"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes no-global unreachable drop debris" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (func (result i32)
      #|    (drop (memory.size))
      #|    (block (result i32)
      #|      i32.const 7
      #|      unreachable)
      #|    unreachable))
      #|,
    ),
  )
  let instrs = try! sgo_test_first_defined_func_instrs(optimized)
  @debug.assert_eq(
    sgo_test_count_instr(instrs, @lib.Instruction::unreachable_()),
    1,
  )
  @debug.assert_eq(sgo_test_count_instr(instrs, @lib.Instruction::drop()), 2)
}

///|
test "simplify-globals-optimizing traces artifact-tuned nested cleanup pass order" {
  let (_, trace) = sgo_test_run_with_trace(
    sgo_test_make_touched_cleanup_fixture(1),
  )
  let nested_passes : Array[String] = []
  for line in trace {
    if line.contains("pass[simplify-globals-optimizing]:nested-pass") {
      nested_passes.push(line)
    }
  }
  @debug.assert_eq(nested_passes, [
    "pass[simplify-globals-optimizing]:nested-pass name=optimize-instructions", "pass[simplify-globals-optimizing]:nested-pass-skip name=local-cse reason=no-touched-candidates",
    "pass[simplify-globals-optimizing]:nested-pass-skip name=pick-load-signs reason=no-touched-candidates",
    "pass[simplify-globals-optimizing]:nested-pass-skip name=merge-blocks reason=no-touched-candidates",
    "pass[simplify-globals-optimizing]:nested-pass name=remove-unused-names", "pass[simplify-globals-optimizing]:nested-pass-skip name=merge-blocks reason=no-touched-candidates",
    "pass[simplify-globals-optimizing]:nested-pass-skip name=coalesce-locals reason=no-touched-candidates",
    "pass[simplify-globals-optimizing]:nested-pass-skip name=reorder-locals reason=no-touched-candidates",
    "pass[simplify-globals-optimizing]:nested-pass-skip name=redundant-set-elimination reason=no-touched-candidates",
    "pass[simplify-globals-optimizing]:nested-pass name=vacuum",
  ])
  assert_false(
    trace.any(fn(line) { line.contains("precompute-propagate") }),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) { line.contains("nested-pass name=simplify-locals") }),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) { line.contains("nested-pass name=remove-unused-brs") }),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) { line.contains("nested-pass name=precompute") }),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) { line.contains("nested-pass name=heap2local") }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-globals-optimizing nested cleanup runs at eight touched functions" {
  let (optimized, trace) = sgo_test_run_with_trace(
    sgo_test_make_touched_cleanup_fixture(8),
  )

  assert_true(
    trace.contains(
      "pass[simplify-globals-optimizing]:nested-cleanup touched=8 prefix=default",
    ),
    msg=trace.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-globals-optimizing]:nested-pass-skip name=local-cse reason=no-touched-candidates",
      )
    }),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) { line.contains("nested-cleanup-skip") }),
    msg=trace.to_string(),
  )
  for idx = 0; idx < 8; idx = idx + 1 {
    let pretty = optimized.pretty_print_defined_func(idx.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("drop"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing nested cleanup runs above eight touched functions" {
  let (optimized, trace) = sgo_test_run_with_trace(
    sgo_test_make_touched_cleanup_fixture(9),
  )

  assert_true(
    trace.contains(
      "pass[simplify-globals-optimizing]:nested-cleanup touched=9 prefix=default",
    ),
    msg=trace.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-globals-optimizing]:nested-pass-skip name=local-cse reason=no-touched-candidates",
      )
    }),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) { line.contains("nested-cleanup-skip") }),
    msg=trace.to_string(),
  )
  for idx = 0; idx < 9; idx = idx + 1 {
    let pretty = optimized.pretty_print_defined_func(idx.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("drop"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing nested cleanup runs above eight touched functions in large modules" {
  let (optimized, trace) = sgo_test_run_with_trace(
    sgo_test_make_touched_cleanup_fixture(9, extra_untouched_count=100),
  )

  assert_true(
    trace.contains(
      "pass[simplify-globals-optimizing]:nested-cleanup touched=9 prefix=default",
    ),
    msg=trace.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-globals-optimizing]:nested-pass-skip name=local-cse reason=no-touched-candidates",
      )
    }),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) { line.contains("nested-cleanup-skip") }),
    msg=trace.to_string(),
  )
  for idx = 0; idx < 9; idx = idx + 1 {
    let pretty = optimized.pretty_print_defined_func(idx.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("drop"), msg=pretty)
  }
  let untouched = optimized.pretty_print_defined_func(9U)
  assert_true(untouched.contains("I32(99)"), msg=untouched)
  assert_true(untouched.contains("drop"), msg=untouched)
}

///|
test "simplify-globals-optimizing nested cleanup runs at module function-count threshold" {
  let (optimized, trace) = sgo_test_run_with_trace(
    sgo_test_make_touched_cleanup_fixture(1, extra_untouched_count=99),
  )

  assert_true(
    trace.contains(
      "pass[simplify-globals-optimizing]:nested-cleanup touched=1 prefix=default",
    ),
    msg=trace.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-globals-optimizing]:nested-pass-skip name=local-cse reason=no-touched-candidates",
      )
    }),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) { line.contains("nested-cleanup-skip") }),
    msg=trace.to_string(),
  )
  let touched = optimized.pretty_print_defined_func(0U)
  assert_false(touched.contains("global.get"), msg=touched)
  assert_false(touched.contains("drop"), msg=touched)
  let untouched = optimized.pretty_print_defined_func(1U)
  assert_true(untouched.contains("I32(99)"), msg=untouched)
  assert_true(untouched.contains("drop"), msg=untouched)
}

///|
test "simplify-globals-optimizing nested cleanup runs in modules with more than one hundred functions" {
  let (optimized, trace) = sgo_test_run_with_trace(
    sgo_test_make_touched_cleanup_fixture(1, extra_untouched_count=100),
  )

  assert_true(
    trace.contains(
      "pass[simplify-globals-optimizing]:nested-cleanup touched=1 prefix=default",
    ),
    msg=trace.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-globals-optimizing]:nested-pass-skip name=local-cse reason=no-touched-candidates",
      )
    }),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) { line.contains("nested-cleanup-skip") }),
    msg=trace.to_string(),
  )
  let touched = optimized.pretty_print_defined_func(0U)
  assert_false(touched.contains("global.get"), msg=touched)
  assert_false(touched.contains("drop"), msg=touched)
  let untouched = optimized.pretty_print_defined_func(1U)
  assert_true(untouched.contains("I32(99)"), msg=untouched)
  assert_true(untouched.contains("drop"), msg=untouched)
}

///|
test "simplify-globals-optimizing reports large touched function in large modules" {
  let (_, trace) = sgo_test_run_with_trace(
    sgo_test_make_large_touched_function_fixture(193, extra_untouched_count=100),
  )

  assert_true(
    trace.contains(
      "pass[simplify-globals-optimizing]:nested-cleanup touched=1 prefix=default",
    ),
    msg=trace.to_string(),
  )
  assert_true(
    trace.contains(
      "pass[simplify-globals-optimizing]:nested-cleanup-skip reason=large-touched-function touched=1",
    ),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) { line.contains("reason=large-module") }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-globals-optimizing nested cleanup runs at touched function local threshold" {
  let (optimized, trace) = sgo_test_run_with_trace(
    sgo_test_make_large_touched_function_fixture(192),
  )

  assert_true(
    trace.contains(
      "pass[simplify-globals-optimizing]:nested-cleanup touched=1 prefix=default",
    ),
    msg=trace.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-globals-optimizing]:nested-pass-skip name=local-cse reason=no-touched-candidates",
      )
    }),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) { line.contains("nested-cleanup-skip") }),
    msg=trace.to_string(),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
}

///|
test "simplify-globals-optimizing nested cleanup skips touched functions above local threshold" {
  let (optimized, trace) = sgo_test_run_with_trace(
    sgo_test_make_large_touched_function_fixture(193),
  )

  assert_true(
    trace.contains(
      "pass[simplify-globals-optimizing]:nested-cleanup touched=1 prefix=default",
    ),
    msg=trace.to_string(),
  )
  assert_true(
    trace.contains(
      "pass[simplify-globals-optimizing]:nested-cleanup-skip reason=large-touched-function touched=1",
    ),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) {
      line.contains("pass[simplify-globals-optimizing]:nested-pass")
    }),
    msg=trace.to_string(),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
}

///|
test "simplify-globals-optimizing nested cleanup filters large touched functions" {
  let (optimized, trace) = sgo_test_run_with_trace(
    sgo_test_make_mixed_large_and_small_touched_fixture(193),
  )

  assert_true(
    trace.contains(
      "pass[simplify-globals-optimizing]:nested-cleanup touched=2 prefix=default",
    ),
    msg=trace.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("nested-cleanup") &&
      line.contains("cleaned=1") &&
      line.contains("filtered-large=1")
    }),
    msg=trace.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-globals-optimizing]:nested-pass-skip name=local-cse reason=no-touched-candidates",
      )
    }),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) { line.contains("nested-cleanup-skip") }),
    msg=trace.to_string(),
  )
  let large = optimized.pretty_print_defined_func(0U)
  assert_false(large.contains("global.get"), msg=large)
  assert_true(large.contains("I32(7)"), msg=large)
  assert_true(large.contains("drop"), msg=large)
  let small = optimized.pretty_print_defined_func(1U)
  assert_false(small.contains("global.get"), msg=small)
  assert_false(small.contains("drop"), msg=small)
}

///|
test "simplify-globals-optimizing nested cleanup runs at touched function instruction threshold" {
  let (optimized, trace) = sgo_test_run_with_trace(
    sgo_test_make_large_touched_body_fixture(998),
  )

  assert_true(
    trace.contains(
      "pass[simplify-globals-optimizing]:nested-cleanup touched=1 prefix=default",
    ),
    msg=trace.to_string(),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-globals-optimizing]:nested-pass-skip name=local-cse reason=no-touched-candidates",
      )
    }),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) { line.contains("nested-cleanup-skip") }),
    msg=trace.to_string(),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
}

///|
test "simplify-globals-optimizing nested cleanup skips touched functions above instruction threshold" {
  let (optimized, trace) = sgo_test_run_with_trace(
    sgo_test_make_large_touched_body_fixture(999),
  )

  assert_true(
    trace.contains(
      "pass[simplify-globals-optimizing]:nested-cleanup touched=1 prefix=default",
    ),
    msg=trace.to_string(),
  )
  assert_true(
    trace.contains(
      "pass[simplify-globals-optimizing]:nested-cleanup-skip reason=large-touched-function touched=1",
    ),
    msg=trace.to_string(),
  )
  assert_false(
    trace.any(fn(line) {
      line.contains("pass[simplify-globals-optimizing]:nested-pass")
    }),
    msg=trace.to_string(),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
}

///|
test "simplify-globals-optimizing propagates startup globals into data offsets without cleaning untouched functions" {
  let (optimized, trace) = sgo_test_run_with_trace(
    (
      #|(module
      #|  (global $offset i32 (i32.const 4))
      #|  (memory 1)
      #|  (data (global.get $offset) "x")
      #|  (func $untouched
      #|    i32.const 12
      #|    drop))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_first_data_offset_instr(optimized),
    @lib.Instruction::i32_const(@lib.I32(4)),
  )
  assert_false(
    trace.any(fn(line) { line.contains("nested-cleanup") }),
    msg=trace.to_string(),
  )
  let untouched = optimized.pretty_print_defined_func(0U)
  assert_true(untouched.contains("drop"), msg=untouched)
  assert_true(untouched.contains("I32(12)"), msg=untouched)
}

///|
test "simplify-globals-optimizing canonicalizes immutable global copy chains" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "m" "g" (global $root i32))
      #|  (global $copy i32 (global.get $root))
      #|  (global $copy2 i32 (global.get $copy))
      #|  (func (export "run") (result i32)
      #|    global.get $copy2))
      #|,
    ),
  )

  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 1), [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
  ])
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get (Global 0)"), msg=pretty)
  assert_false(pretty.contains("global.get (Global 2)"), msg=pretty)
}

///|
test "simplify-globals-optimizing folds single-use multi-instruction global initializers without nested cleanup" {
  let (optimized, trace) = sgo_test_run_with_trace(
    (
      #|(module
      #|  (global $source i32
      #|    i32.const 4
      #|    i32.const 5
      #|    i32.add)
      #|  (global $copy i32
      #|    global.get $source))
      #|,
    ),
  )

  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 1), [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::i32_add(),
  ])
  assert_false(
    trace.any(fn(line) { line.contains("nested-cleanup") }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-globals-optimizing keeps reference global gets in typed element item expressions" {
  let null_rt = @lib.RefType::abs(@lib.AbsHeapType::none())
  let array_rt = @lib.RefType::abs(@lib.AbsHeapType::array())
  let optimized = sgo_test_run_module(
    @lib.Module::new()
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::ref_null_type(null_rt), false),
          @lib.Expr::new([@lib.Instruction::ref_null_type(null_rt)]),
        ),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::typed_exprs(array_rt, [
            @lib.Expr::new([
              @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
            ]),
            @lib.Expr::new([@lib.Instruction::ref_null_type(array_rt)]),
          ]),
        ),
      ]),
    ),
  )

  @debug.assert_eq(
    try! sgo_test_first_typed_elem_expr_instr(optimized),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
  )
}

///|
test "simplify-globals-optimizing keeps ref-func typed element item expressions conservative" {
  let fn_type = @lib.TypeIdx::new(0U)
  let run_type = @lib.TypeIdx::new(1U)
  let fn_rt = @lib.RefType::new(true, @lib.HeapType::new(fn_type))
  let optimized = sgo_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::ref_type(fn_rt)]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([fn_type, run_type]))
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::ref_type(fn_rt), false),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0U))]),
        ),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::typed_exprs(fn_rt, [
            @lib.Expr::new([
              @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
            ]),
          ]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))]),
        ),
      ]),
    ),
  )

  @debug.assert_eq(
    try! sgo_test_first_typed_elem_expr_instr(optimized),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
  )
  let pretty = optimized.pretty_print_defined_func(1U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("ref.func"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps ref-func typed element aliases conservative" {
  let fn_type = @lib.TypeIdx::new(0U)
  let run_type = @lib.TypeIdx::new(1U)
  let fn_rt = @lib.RefType::new(true, @lib.HeapType::new(fn_type))
  let optimized = sgo_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::ref_type(fn_rt)]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([fn_type, run_type]))
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::ref_type(fn_rt), false),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0U))]),
        ),
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::ref_type(fn_rt), false),
          @lib.Expr::new([@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))]),
        ),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::typed_exprs(fn_rt, [
            @lib.Expr::new([
              @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
            ]),
          ]),
        ),
      ]),
    )
    .with_export_sec(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::global_get(@lib.GlobalIdx::new(1U))]),
        ),
      ]),
    ),
  )

  @debug.assert_eq(
    try! sgo_test_first_typed_elem_expr_instr(optimized),
    @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
  )
  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 1), [
    @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
  ])
  let pretty = optimized.pretty_print_defined_func(1U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("ref.func"), msg=pretty)
}

///|
test "simplify-globals-optimizing rewrites typed ref-func function body reads" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (type $t (func (result i32)))
      #|  (func $f (type $t) (i32.const 0))
      #|  (elem declare func $f)
      #|  (global $g (ref null $t) (ref.func $f))
      #|  (func (export "run") (result (ref null $t))
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(1U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("ref.func"), msg=pretty)
}

///|
test "simplify-globals-optimizing rewrites typed ref-func aliases in function bodies" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (type $t (func (result i32)))
      #|  (func $f (type $t) (i32.const 0))
      #|  (elem declare func $f)
      #|  (global $direct (ref null $t) (ref.func $f))
      #|  (global $alias (ref null $t) (global.get $direct))
      #|  (func (export "run") (result (ref null $t))
      #|    global.get $alias))
      #|,
    ),
  )

  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 1), [
    @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
  ])
  let pretty = optimized.pretty_print_defined_func(1U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("ref.func"), msg=pretty)
}

///|
test "simplify-globals-optimizing rewrites typed ref-func reads inside block results" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (type $t (func (result i32)))
      #|  (func $f (type $t) (i32.const 0))
      #|  (elem declare func $f)
      #|  (global $g (ref null $t) (ref.func $f))
      #|  (func (export "run") (result (ref null $t))
      #|    block (result (ref null $t))
      #|      global.get $g
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(1U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("ref.func"), msg=pretty)
}

///|
test "simplify-globals-optimizing rewrites typed externref null function body reads" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (ref null extern) (ref.null extern))
      #|  (func (export "run") (result (ref null extern))
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("ref.null"), msg=pretty)
}

///|
test "simplify-globals-optimizing rewrites typed externref null aliases in function bodies" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $direct (ref null extern) (ref.null extern))
      #|  (global $alias (ref null extern) (global.get $direct))
      #|  (func (export "run") (result (ref null extern))
      #|    global.get $alias))
      #|,
    ),
  )

  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 1), [
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::extern_())),
  ])
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("ref.null"), msg=pretty)
}

///|
test "simplify-globals-optimizing rewrites typed externref null reads inside block results" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (ref null extern) (ref.null extern))
      #|  (func (export "run") (result (ref null extern))
      #|    block (result (ref null extern))
      #|      global.get $g
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("ref.null"), msg=pretty)
}

///|
test "simplify-globals-optimizing rewrites typed ref-null function body reads through nullable supertypes" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (type $base (sub (struct)))
      #|  (type $child (sub $base (struct)))
      #|  (global $g (ref null $base) (ref.null $child))
      #|  (func (export "run") (result (ref null $base))
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("ref.null"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes same-as-init writes before reads" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 7))
      #|  (func (export "run") (result i32)
      #|    i32.const 7
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes ref-null same-as-init writes before reads" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut externref) (ref.null extern))
      #|  (func (export "run") (result externref)
      #|    ref.null extern
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_null_type(
        @lib.RefType::abs(@lib.AbsHeapType::extern_()),
      ),
      false,
    ),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("ref.null"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes ref-func same-as-init writes before reads" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (func $f)
      #|  (elem declare func $f)
      #|  (global $g (mut funcref) (ref.func $f))
      #|  (func (export "run") (result funcref)
      #|    ref.func $f
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 0), [
    @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
  ])
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::funcref(), false),
  )
  let pretty = optimized.pretty_print_defined_func(1U)
  assert_false(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("ref.func"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps non-init ref-func writes before reads" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (func $f)
      #|  (func $h)
      #|  (elem declare func $f $h)
      #|  (global $g (mut funcref) (ref.func $f))
      #|  (func (export "run") (result funcref)
      #|    ref.func $h
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::funcref(), true),
  )
  let pretty = optimized.pretty_print_defined_func(2U)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("ref.func"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps exported ref-func same-as-init writes" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (func $f)
      #|  (elem declare func $f)
      #|  (global $g (export "g") (mut funcref) (ref.func $f))
      #|  (func (export "run") (result funcref)
      #|    ref.func $f
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::funcref(), true),
  )
  let pretty = optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("ref.func"), msg=pretty)
}

///|
test "simplify-globals-optimizing canonicalizes defined global-get init before same-as-init removal" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $a i32 (i32.const 7))
      #|  (global $g (mut i32) (global.get $a))
      #|  (func (export "run") (result i32)
      #|    global.get $a
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 1), [
    @lib.Instruction::i32_const(@lib.I32(7)),
  ])
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "simplify-globals-optimizing second run removes canonicalized global-get init write" {
  let optimized = sgo_test_run_twice(
    (
      #|(module
      #|  (global $a i32 (i32.const 7))
      #|  (global $g (mut i32) (global.get $a))
      #|  (func (export "run") (result i32)
      #|    global.get $a
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 1), [
    @lib.Instruction::i32_const(@lib.I32(7)),
  ])
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps imported global-get init same-as-init writes" {
  let optimized = sgo_test_run_twice(
    (
      #|(module
      #|  (import "m" "a" (global $a i32))
      #|  (global $g (mut i32) (global.get $a))
      #|  (func (export "run") (result i32)
      #|    global.get $a
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 0), [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
  ])
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing canonicalizes defined alias-chain init before same-as-init removal" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $a i32 (i32.const 7))
      #|  (global $alias i32 (global.get $a))
      #|  (global $g (mut i32) (global.get $alias))
      #|  (func (export "run") (result i32)
      #|    global.get $alias
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 1), [
    @lib.Instruction::i32_const(@lib.I32(7)),
  ])
  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 2), [
    @lib.Instruction::i32_const(@lib.I32(7)),
  ])
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "simplify-globals-optimizing second run removes canonicalized alias-chain init write" {
  let optimized = sgo_test_run_twice(
    (
      #|(module
      #|  (global $a i32 (i32.const 7))
      #|  (global $alias i32 (global.get $a))
      #|  (global $g (mut i32) (global.get $alias))
      #|  (func (export "run") (result i32)
      #|    global.get $alias
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 2), [
    @lib.Instruction::i32_const(@lib.I32(7)),
  ])
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps imported alias-chain same-as-init writes" {
  let optimized = sgo_test_run_twice(
    (
      #|(module
      #|  (import "m" "a" (global $a i32))
      #|  (global $alias i32 (global.get $a))
      #|  (global $g (mut i32) (global.get $alias))
      #|  (func (export "run") (result i32)
      #|    global.get $alias
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 0), [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
  ])
  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 1), [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
  ])
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps exported alias-chain same-as-init writes" {
  let optimized = sgo_test_run_twice(
    (
      #|(module
      #|  (global $a i32 (i32.const 7))
      #|  (global $alias i32 (global.get $a))
      #|  (global $g (export "g") (mut i32) (global.get $alias))
      #|  (func (export "run") (result i32)
      #|    global.get $alias
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 2), [
    @lib.Instruction::i32_const(@lib.I32(7)),
  ])
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "simplify-globals-optimizing canonicalizes defined reference alias-chain init before same-as-init removal" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (func $f)
      #|  (elem declare func $f)
      #|  (global $a funcref (ref.func $f))
      #|  (global $alias funcref (global.get $a))
      #|  (global $g (mut funcref) (global.get $alias))
      #|  (func (export "run") (result funcref)
      #|    global.get $alias
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 1), [
    @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
  ])
  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 2), [
    @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
  ])
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(@lib.ValType::funcref(), true),
  )
  let pretty = optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("ref.func"), msg=pretty)
}

///|
test "simplify-globals-optimizing second run removes canonicalized reference alias-chain init write" {
  let optimized = sgo_test_run_twice(
    (
      #|(module
      #|  (func $f)
      #|  (elem declare func $f)
      #|  (global $a funcref (ref.func $f))
      #|  (global $alias funcref (global.get $a))
      #|  (global $g (mut funcref) (global.get $alias))
      #|  (func (export "run") (result funcref)
      #|    global.get $alias
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(@lib.ValType::funcref(), false),
  )
  let pretty = optimized.pretty_print_defined_func(1U)
  assert_false(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("ref.func"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps imported reference alias-chain same-as-init writes" {
  let optimized = sgo_test_run_twice(
    (
      #|(module
      #|  (import "m" "a" (global $a funcref))
      #|  (global $alias funcref (global.get $a))
      #|  (global $g (mut funcref) (global.get $alias))
      #|  (func (export "run") (result funcref)
      #|    global.get $alias
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 0), [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
  ])
  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 1), [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
  ])
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(@lib.ValType::funcref(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps exported reference alias-chain same-as-init writes" {
  let optimized = sgo_test_run_twice(
    (
      #|(module
      #|  (func $f)
      #|  (elem declare func $f)
      #|  (global $a funcref (ref.func $f))
      #|  (global $alias funcref (global.get $a))
      #|  (global $g (export "g") (mut funcref) (global.get $alias))
      #|  (func (export "run") (result funcref)
      #|    global.get $alias
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 2), [
    @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
  ])
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(@lib.ValType::funcref(), true),
  )
  let pretty = optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("ref.func"), msg=pretty)
}

///|
test "simplify-globals-optimizing canonicalizes defined externref alias-chain init before same-as-init removal" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $a externref (ref.null extern))
      #|  (global $alias externref (global.get $a))
      #|  (global $g (mut externref) (global.get $alias))
      #|  (func (export "run") (result externref)
      #|    global.get $alias
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 1), [
    @lib.Instruction::ref_null_type(
      @lib.RefType::abs(@lib.AbsHeapType::extern_()),
    ),
  ])
  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 2), [
    @lib.Instruction::ref_null_type(
      @lib.RefType::abs(@lib.AbsHeapType::extern_()),
    ),
  ])
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(
      @lib.ValType::ref_null_type(
        @lib.RefType::abs(@lib.AbsHeapType::extern_()),
      ),
      true,
    ),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("ref.null"), msg=pretty)
}

///|
test "simplify-globals-optimizing second run removes canonicalized externref alias-chain init write" {
  let optimized = sgo_test_run_twice(
    (
      #|(module
      #|  (global $a externref (ref.null extern))
      #|  (global $alias externref (global.get $a))
      #|  (global $g (mut externref) (global.get $alias))
      #|  (func (export "run") (result externref)
      #|    global.get $alias
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(
      @lib.ValType::ref_null_type(
        @lib.RefType::abs(@lib.AbsHeapType::extern_()),
      ),
      false,
    ),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("ref.null"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps imported externref alias-chain same-as-init writes" {
  let optimized = sgo_test_run_twice(
    (
      #|(module
      #|  (import "m" "a" (global $a externref))
      #|  (global $alias externref (global.get $a))
      #|  (global $g (mut externref) (global.get $alias))
      #|  (func (export "run") (result externref)
      #|    global.get $alias
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 0), [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
  ])
  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 1), [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
  ])
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(
      @lib.ValType::ref_null_type(
        @lib.RefType::abs(@lib.AbsHeapType::extern_()),
      ),
      true,
    ),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps exported externref alias-chain same-as-init writes" {
  let optimized = sgo_test_run_twice(
    (
      #|(module
      #|  (global $a externref (ref.null extern))
      #|  (global $alias externref (global.get $a))
      #|  (global $g (export "g") (mut externref) (global.get $alias))
      #|  (func (export "run") (result externref)
      #|    global.get $alias
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(try! sgo_test_defined_global_init_instrs(optimized, 2), [
    @lib.Instruction::ref_null_type(
      @lib.RefType::abs(@lib.AbsHeapType::extern_()),
    ),
  ])
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(
      @lib.ValType::ref_null_type(
        @lib.RefType::abs(@lib.AbsHeapType::extern_()),
      ),
      true,
    ),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("ref.null"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps non-folded expression same-as-init writes" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 3))
      #|  (func (export "run") (result i32)
      #|    i32.const 1
      #|    i32.const 2
      #|    i32.add
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps result-block same-as-init writes" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 7))
      #|  (func (export "run") (result i32)
      #|    block (result i32)
      #|      i32.const 7
      #|    end
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes void-block direct-literal same-as-init writes" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 7))
      #|  (func (export "run") (result i32)
      #|    block
      #|      i32.const 7
      #|      global.set $g
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "simplify-globals-optimizing does not remove non-init writes before reads" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 7))
      #|  (func (export "run") (result i32)
      #|    i32.const 8
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("I32(8)"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes narrow read-only-to-write self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $once
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes reverse compare-const read-only-to-write self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    global.get $once
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes compare-const read-only-to-write self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $once
      #|    i32.const 0
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes eqz read-only-to-write self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $once
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes pure-condition read-only-to-write self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $once
      #|    i32.const 17
      #|    i32.add
      #|    i32.const 20
      #|    i32.lt_s
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes bitwise pure-condition read-only-to-write self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $and (mut i32) (i32.const 0))
      #|  (global $or (mut i32) (i32.const 0))
      #|  (global $xor (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $and
      #|    i32.const 3
      #|    i32.and
      #|    if
      #|      i32.const 1
      #|      global.set $and
      #|    end
      #|    global.get $or
      #|    i32.const 3
      #|    i32.or
      #|    if
      #|      i32.const 1
      #|      global.set $or
      #|    end
      #|    global.get $xor
      #|    i32.const 3
      #|    i32.xor
      #|    if
      #|      i32.const 1
      #|      global.set $xor
      #|    end))
      #|,
    ),
  )

  for global_idx = 0; global_idx < 3; global_idx = global_idx + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, global_idx),
      @lib.GlobalType::new(@lib.ValType::i32(), false),
    )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes shift-rotate pure-condition read-only-to-write self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $shl (mut i32) (i32.const 1))
      #|  (global $shr_s (mut i32) (i32.const 1))
      #|  (global $shr_u (mut i32) (i32.const 1))
      #|  (global $rotl (mut i32) (i32.const 1))
      #|  (global $rotr (mut i32) (i32.const 1))
      #|  (func (export "run")
      #|    global.get $shl
      #|    i32.const 1
      #|    i32.shl
      #|    if
      #|      i32.const 2
      #|      global.set $shl
      #|    end
      #|    global.get $shr_s
      #|    i32.const 1
      #|    i32.shr_s
      #|    if
      #|      i32.const 2
      #|      global.set $shr_s
      #|    end
      #|    global.get $shr_u
      #|    i32.const 1
      #|    i32.shr_u
      #|    if
      #|      i32.const 2
      #|      global.set $shr_u
      #|    end
      #|    global.get $rotl
      #|    i32.const 1
      #|    i32.rotl
      #|    if
      #|      i32.const 2
      #|      global.set $rotl
      #|    end
      #|    global.get $rotr
      #|    i32.const 1
      #|    i32.rotr
      #|    if
      #|      i32.const 2
      #|      global.set $rotr
      #|    end))
      #|,
    ),
  )

  for global_idx = 0; global_idx < 5; global_idx = global_idx + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, global_idx),
      @lib.GlobalType::new(@lib.ValType::i32(), false),
    )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes unary pure-condition read-only-to-write self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $clz (mut i32) (i32.const 1))
      #|  (global $ctz (mut i32) (i32.const 1))
      #|  (global $popcnt (mut i32) (i32.const 1))
      #|  (func (export "run")
      #|    global.get $clz
      #|    i32.clz
      #|    if
      #|      i32.const 2
      #|      global.set $clz
      #|    end
      #|    global.get $ctz
      #|    i32.ctz
      #|    if
      #|      i32.const 2
      #|      global.set $ctz
      #|    end
      #|    global.get $popcnt
      #|    i32.popcnt
      #|    if
      #|      i32.const 2
      #|      global.set $popcnt
      #|    end))
      #|,
    ),
  )

  for global_idx = 0; global_idx < 3; global_idx = global_idx + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, global_idx),
      @lib.GlobalType::new(@lib.ValType::i32(), false),
    )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes i64 compare pure-condition read-only-to-write self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $eqz (mut i64) (i64.const 1))
      #|  (global $eq (mut i64) (i64.const 1))
      #|  (global $ne (mut i64) (i64.const 1))
      #|  (global $lt_s (mut i64) (i64.const 1))
      #|  (global $lt_u (mut i64) (i64.const 1))
      #|  (global $gt_s (mut i64) (i64.const 1))
      #|  (global $gt_u (mut i64) (i64.const 1))
      #|  (global $le_s (mut i64) (i64.const 1))
      #|  (global $le_u (mut i64) (i64.const 1))
      #|  (global $ge_s (mut i64) (i64.const 1))
      #|  (global $ge_u (mut i64) (i64.const 1))
      #|  (func (export "run")
      #|    global.get $eqz
      #|    i64.eqz
      #|    if
      #|      i64.const 2
      #|      global.set $eqz
      #|    end
      #|    global.get $eq
      #|    i64.const 2
      #|    i64.eq
      #|    if
      #|      i64.const 2
      #|      global.set $eq
      #|    end
      #|    global.get $ne
      #|    i64.const 2
      #|    i64.ne
      #|    if
      #|      i64.const 2
      #|      global.set $ne
      #|    end
      #|    global.get $lt_s
      #|    i64.const 2
      #|    i64.lt_s
      #|    if
      #|      i64.const 2
      #|      global.set $lt_s
      #|    end
      #|    global.get $lt_u
      #|    i64.const 2
      #|    i64.lt_u
      #|    if
      #|      i64.const 2
      #|      global.set $lt_u
      #|    end
      #|    global.get $gt_s
      #|    i64.const 2
      #|    i64.gt_s
      #|    if
      #|      i64.const 2
      #|      global.set $gt_s
      #|    end
      #|    global.get $gt_u
      #|    i64.const 2
      #|    i64.gt_u
      #|    if
      #|      i64.const 2
      #|      global.set $gt_u
      #|    end
      #|    global.get $le_s
      #|    i64.const 2
      #|    i64.le_s
      #|    if
      #|      i64.const 2
      #|      global.set $le_s
      #|    end
      #|    global.get $le_u
      #|    i64.const 2
      #|    i64.le_u
      #|    if
      #|      i64.const 2
      #|      global.set $le_u
      #|    end
      #|    global.get $ge_s
      #|    i64.const 2
      #|    i64.ge_s
      #|    if
      #|      i64.const 2
      #|      global.set $ge_s
      #|    end
      #|    global.get $ge_u
      #|    i64.const 2
      #|    i64.ge_u
      #|    if
      #|      i64.const 2
      #|      global.set $ge_u
      #|    end))
      #|,
    ),
  )

  for global_idx = 0; global_idx < 11; global_idx = global_idx + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, global_idx),
      @lib.GlobalType::new(@lib.ValType::i64(), false),
    )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes i64 value pure-condition read-only-to-write self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $clz (mut i64) (i64.const 1))
      #|  (global $ctz (mut i64) (i64.const 1))
      #|  (global $popcnt (mut i64) (i64.const 1))
      #|  (global $add (mut i64) (i64.const 1))
      #|  (global $sub (mut i64) (i64.const 1))
      #|  (global $mul (mut i64) (i64.const 1))
      #|  (global $and (mut i64) (i64.const 1))
      #|  (global $or (mut i64) (i64.const 1))
      #|  (global $xor (mut i64) (i64.const 1))
      #|  (global $shl (mut i64) (i64.const 1))
      #|  (global $shr_s (mut i64) (i64.const 1))
      #|  (global $shr_u (mut i64) (i64.const 1))
      #|  (global $rotl (mut i64) (i64.const 1))
      #|  (global $rotr (mut i64) (i64.const 1))
      #|  (func (export "run")
      #|    global.get $clz
      #|    i64.clz
      #|    i64.eqz
      #|    if
      #|      i64.const 2
      #|      global.set $clz
      #|    end
      #|    global.get $ctz
      #|    i64.ctz
      #|    i64.eqz
      #|    if
      #|      i64.const 2
      #|      global.set $ctz
      #|    end
      #|    global.get $popcnt
      #|    i64.popcnt
      #|    i64.eqz
      #|    if
      #|      i64.const 2
      #|      global.set $popcnt
      #|    end
      #|    global.get $add
      #|    i64.const 1
      #|    i64.add
      #|    i64.eqz
      #|    if
      #|      i64.const 2
      #|      global.set $add
      #|    end
      #|    global.get $sub
      #|    i64.const 1
      #|    i64.sub
      #|    i64.eqz
      #|    if
      #|      i64.const 2
      #|      global.set $sub
      #|    end
      #|    global.get $mul
      #|    i64.const 1
      #|    i64.mul
      #|    i64.eqz
      #|    if
      #|      i64.const 2
      #|      global.set $mul
      #|    end
      #|    global.get $and
      #|    i64.const 1
      #|    i64.and
      #|    i64.eqz
      #|    if
      #|      i64.const 2
      #|      global.set $and
      #|    end
      #|    global.get $or
      #|    i64.const 1
      #|    i64.or
      #|    i64.eqz
      #|    if
      #|      i64.const 2
      #|      global.set $or
      #|    end
      #|    global.get $xor
      #|    i64.const 1
      #|    i64.xor
      #|    i64.eqz
      #|    if
      #|      i64.const 2
      #|      global.set $xor
      #|    end
      #|    global.get $shl
      #|    i64.const 1
      #|    i64.shl
      #|    i64.eqz
      #|    if
      #|      i64.const 2
      #|      global.set $shl
      #|    end
      #|    global.get $shr_s
      #|    i64.const 1
      #|    i64.shr_s
      #|    i64.eqz
      #|    if
      #|      i64.const 2
      #|      global.set $shr_s
      #|    end
      #|    global.get $shr_u
      #|    i64.const 1
      #|    i64.shr_u
      #|    i64.eqz
      #|    if
      #|      i64.const 2
      #|      global.set $shr_u
      #|    end
      #|    global.get $rotl
      #|    i64.const 1
      #|    i64.rotl
      #|    i64.eqz
      #|    if
      #|      i64.const 2
      #|      global.set $rotl
      #|    end
      #|    global.get $rotr
      #|    i64.const 1
      #|    i64.rotr
      #|    i64.eqz
      #|    if
      #|      i64.const 2
      #|      global.set $rotr
      #|    end))
      #|,
    ),
  )

  for global_idx = 0; global_idx < 14; global_idx = global_idx + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, global_idx),
      @lib.GlobalType::new(@lib.ValType::i64(), false),
    )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes float compare pure-condition read-only-to-write self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $f32eq (mut f32) (f32.const 1))
      #|  (global $f32ne (mut f32) (f32.const 1))
      #|  (global $f32lt (mut f32) (f32.const 1))
      #|  (global $f32gt (mut f32) (f32.const 1))
      #|  (global $f32le (mut f32) (f32.const 1))
      #|  (global $f32ge (mut f32) (f32.const 1))
      #|  (global $f64eq (mut f64) (f64.const 1))
      #|  (global $f64ne (mut f64) (f64.const 1))
      #|  (global $f64lt (mut f64) (f64.const 1))
      #|  (global $f64gt (mut f64) (f64.const 1))
      #|  (global $f64le (mut f64) (f64.const 1))
      #|  (global $f64ge (mut f64) (f64.const 1))
      #|  (func (export "run")
      #|    global.get $f32eq
      #|    f32.const 2
      #|    f32.eq
      #|    if
      #|      f32.const 2
      #|      global.set $f32eq
      #|    end
      #|    global.get $f32ne
      #|    f32.const 2
      #|    f32.ne
      #|    if
      #|      f32.const 2
      #|      global.set $f32ne
      #|    end
      #|    global.get $f32lt
      #|    f32.const 2
      #|    f32.lt
      #|    if
      #|      f32.const 2
      #|      global.set $f32lt
      #|    end
      #|    global.get $f32gt
      #|    f32.const 2
      #|    f32.gt
      #|    if
      #|      f32.const 2
      #|      global.set $f32gt
      #|    end
      #|    global.get $f32le
      #|    f32.const 2
      #|    f32.le
      #|    if
      #|      f32.const 2
      #|      global.set $f32le
      #|    end
      #|    global.get $f32ge
      #|    f32.const 2
      #|    f32.ge
      #|    if
      #|      f32.const 2
      #|      global.set $f32ge
      #|    end
      #|    global.get $f64eq
      #|    f64.const 2
      #|    f64.eq
      #|    if
      #|      f64.const 2
      #|      global.set $f64eq
      #|    end
      #|    global.get $f64ne
      #|    f64.const 2
      #|    f64.ne
      #|    if
      #|      f64.const 2
      #|      global.set $f64ne
      #|    end
      #|    global.get $f64lt
      #|    f64.const 2
      #|    f64.lt
      #|    if
      #|      f64.const 2
      #|      global.set $f64lt
      #|    end
      #|    global.get $f64gt
      #|    f64.const 2
      #|    f64.gt
      #|    if
      #|      f64.const 2
      #|      global.set $f64gt
      #|    end
      #|    global.get $f64le
      #|    f64.const 2
      #|    f64.le
      #|    if
      #|      f64.const 2
      #|      global.set $f64le
      #|    end
      #|    global.get $f64ge
      #|    f64.const 2
      #|    f64.ge
      #|    if
      #|      f64.const 2
      #|      global.set $f64ge
      #|    end))
      #|,
    ),
  )

  for global_idx = 0; global_idx < 6; global_idx = global_idx + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, global_idx),
      @lib.GlobalType::new(@lib.ValType::f32(), false),
    )
  }
  for global_idx = 6; global_idx < 12; global_idx = global_idx + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, global_idx),
      @lib.GlobalType::new(@lib.ValType::f64(), false),
    )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes float value pure-condition read-only-to-write self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $f32 (mut f32) (f32.const 1))
      #|  (global $f64 (mut f64) (f64.const 1))
      #|  (func (export "run")
      #|    global.get $f32
      #|    f32.const 2
      #|    f32.add
      #|    f32.abs
      #|    f32.const 3
      #|    f32.gt
      #|    if
      #|      f32.const 4
      #|      global.set $f32
      #|    end
      #|    global.get $f64
      #|    f64.const 2
      #|    f64.div
      #|    f64.sqrt
      #|    f64.const 3
      #|    f64.ne
      #|    if
      #|      f64.const 4
      #|      global.set $f64
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(@lib.ValType::f64(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes float value pure-condition if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $f32 (mut f32) (f32.const 1))
      #|  (global $f64 (mut f64) (f64.const 1))
      #|  (func (export "f32")
      #|    global.get $f32
      #|    f32.const 2
      #|    f32.mul
      #|    f32.ceil
      #|    f32.const 3
      #|    f32.lt
      #|    if
      #|      return
      #|    end
      #|    f32.const 4
      #|    global.set $f32)
      #|  (func (export "f64")
      #|    global.get $f64
      #|    f64.const 2
      #|    f64.min
      #|    f64.floor
      #|    f64.const 3
      #|    f64.ge
      #|    if
      #|      return
      #|    end
      #|    f64.const 4
      #|    global.set $f64))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(@lib.ValType::f64(), false),
  )
  let f32_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let f64_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(f32_pretty.contains("global.get"), msg=f32_pretty)
  assert_false(f32_pretty.contains("global.set"), msg=f32_pretty)
  assert_false(f64_pretty.contains("global.get"), msg=f64_pretty)
  assert_false(f64_pretty.contains("global.set"), msg=f64_pretty)
}

///|
test "simplify-globals-optimizing removes local get pure-condition self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $x i32)
      #|    global.get $g
      #|    local.get $x
      #|    i32.add
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nontrapping ref pure-condition self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $nullcheck (mut funcref) (ref.null func))
      #|  (global $refeq (mut eqref) (ref.null eq))
      #|  (func $f)
      #|  (elem declare func $f)
      #|  (func (export "run")
      #|    global.get $nullcheck
      #|    ref.is_null
      #|    if
      #|      ref.func $f
      #|      global.set $nullcheck
      #|    end
      #|    global.get $refeq
      #|    ref.null eq
      #|    ref.eq
      #|    if
      #|      ref.null i31
      #|      global.set $refeq
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nontrapping ref pure-condition if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $nullcheck (mut funcref) (ref.null func))
      #|  (global $refeq (mut eqref) (ref.null eq))
      #|  (func $f)
      #|  (elem declare func $f)
      #|  (func (export "nullcheck")
      #|    global.get $nullcheck
      #|    ref.is_null
      #|    if
      #|      return
      #|    end
      #|    ref.func $f
      #|    global.set $nullcheck)
      #|  (func (export "refeq")
      #|    global.get $refeq
      #|    ref.null eq
      #|    ref.eq
      #|    if
      #|      return
      #|    end
      #|    ref.null i31
      #|    global.set $refeq))
      #|,
    ),
  )

  let nullcheck = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(nullcheck.contains("global.get"), msg=nullcheck)
  assert_false(nullcheck.contains("global.set"), msg=nullcheck)
  let refeq = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(refeq.contains("global.get"), msg=refeq)
  assert_false(refeq.contains("global.set"), msg=refeq)
}

///|
test "simplify-globals-optimizing keeps ref condition values flowing into local tee" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut funcref) (ref.null func))
      #|  (func $f)
      #|  (elem declare func $f)
      #|  (func (export "run") (local $tmp funcref)
      #|    global.get $g
      #|    local.tee $tmp
      #|    ref.is_null
      #|    if
      #|      ref.func $f
      #|      global.set $g
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nontrapping conversion pure-condition self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $wrap (mut i64) (i64.const 0))
      #|  (global $extend (mut i32) (i32.const 0))
      #|  (global $convert (mut i32) (i32.const 0))
      #|  (global $promote (mut f32) (f32.const 0))
      #|  (global $demote (mut f64) (f64.const 0))
      #|  (global $reinterpret_f32 (mut f32) (f32.const 0))
      #|  (global $reinterpret_i64 (mut i64) (i64.const 0))
      #|  (global $extend8 (mut i32) (i32.const 0))
      #|  (global $trunc_sat (mut f32) (f32.const 0))
      #|  (func (export "run")
      #|    global.get $wrap
      #|    i32.wrap_i64
      #|    i32.eqz
      #|    if
      #|      i64.const 1
      #|      global.set $wrap
      #|    end
      #|    global.get $extend
      #|    i64.extend_i32_s
      #|    i64.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $extend
      #|    end
      #|    global.get $convert
      #|    f64.convert_i32_s
      #|    f64.const 3
      #|    f64.lt
      #|    if
      #|      i32.const 1
      #|      global.set $convert
      #|    end
      #|    global.get $promote
      #|    f64.promote_f32
      #|    f64.const 3
      #|    f64.gt
      #|    if
      #|      f32.const 1
      #|      global.set $promote
      #|    end
      #|    global.get $demote
      #|    f32.demote_f64
      #|    f32.const 3
      #|    f32.ne
      #|    if
      #|      f64.const 1
      #|      global.set $demote
      #|    end
      #|    global.get $reinterpret_f32
      #|    i32.reinterpret_f32
      #|    i32.eqz
      #|    if
      #|      f32.const 1
      #|      global.set $reinterpret_f32
      #|    end
      #|    global.get $reinterpret_i64
      #|    f64.reinterpret_i64
      #|    f64.const 0
      #|    f64.eq
      #|    if
      #|      i64.const 1
      #|      global.set $reinterpret_i64
      #|    end
      #|    global.get $extend8
      #|    i32.extend8_s
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $extend8
      #|    end
      #|    global.get $trunc_sat
      #|    i32.trunc_sat_f32_s
      #|    i32.eqz
      #|    if
      #|      f32.const 1
      #|      global.set $trunc_sat
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i64(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 3),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 4),
    @lib.GlobalType::new(@lib.ValType::f64(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 5),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 6),
    @lib.GlobalType::new(@lib.ValType::i64(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 7),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 8),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nontrapping conversion pure-condition if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $i32 (mut i32) (i32.const 0))
      #|  (global $i64 (mut i64) (i64.const 0))
      #|  (global $f64 (mut f64) (f64.const 0))
      #|  (func (export "i32")
      #|    global.get $i32
      #|    i64.extend_i32_u
      #|    i64.eqz
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $i32)
      #|  (func (export "i64")
      #|    global.get $i64
      #|    f32.convert_i64_s
      #|    f32.const 3
      #|    f32.le
      #|    if
      #|      return
      #|    end
      #|    i64.const 1
      #|    global.set $i64)
      #|  (func (export "f64")
      #|    global.get $f64
      #|    i64.trunc_sat_f64_s
      #|    i64.eqz
      #|    if
      #|      return
      #|    end
      #|    f64.const 1
      #|    global.set $f64))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(@lib.ValType::i64(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(@lib.ValType::f64(), false),
  )
  for func_idx = 0; func_idx < 3; func_idx = func_idx + 1 {
    let pretty = optimized.pretty_print_func(
      @lib.FuncIdx::new(func_idx.reinterpret_as_uint()),
    )
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing keeps trapping conversion pure-condition guardrails" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $trap (mut f32) (f32.const 0))
      #|  (func (export "run")
      #|    global.get $trap
      #|    i32.trunc_f32_s
      #|    i32.eqz
      #|    if
      #|      f32.const 1
      #|      global.set $trap
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::f32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps conversion condition values flowing into side effects" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $i32 (mut i32) (i32.const 1))
      #|  (func (export "run") (local $tmp i64)
      #|    global.get $i32
      #|    i64.extend_i32_s
      #|    local.tee $tmp
      #|    i64.eqz
      #|    if
      #|      i32.const 2
      #|      global.set $i32
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps float condition values flowing into side effects" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $f32 (mut f32) (f32.const 1))
      #|  (func (export "run") (local $tmp f32)
      #|    global.get $f32
      #|    f32.neg
      #|    local.tee $tmp
      #|    f32.const 0
      #|    f32.ne
      #|    if
      #|      f32.const 2
      #|      global.set $f32
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::f32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps condition values flowing into side effects" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    global.get $once
      #|    local.tee $tmp
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes safe-side-effect if-arm read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (if (result i32)
      #|      (call $foo)
      #|      (then
      #|        i32.const 1)
      #|      (else
      #|        global.get $once))
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing drops effectful result-if after removing guarded write" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32)
      #|    local.get $p
      #|    if (result i32)
      #|      call $foo
      #|    else
      #|      global.get $once
      #|    end
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let instrs = try! sgo_test_first_defined_func_instrs(optimized)
  match instrs {
    [
      @lib.LocalGet(_),
      @lib.If(
        @lib.ValTypeBlockType(@lib.NumTypeValType(@lib.I32NumType)),
        _,
        Some(_)
      ),
      @lib.Drop,
    ] => ()
    other =>
      fail(
        "expected effectful result-if followed by drop, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "simplify-globals-optimizing removes nested safe-side-effect if-arm read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (import "env" "bar" (func $bar (result i32)))
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (if (result i32)
      #|      (call $foo)
      #|      (then
      #|        i32.const 1)
      #|      (else
      #|        (if (result i32)
      #|          (call $bar)
      #|          (then
      #|            i32.const 2)
      #|          (else
      #|            global.get $once))))
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested if-arm values through pure operators" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (import "env" "bar" (func $bar (result i32)))
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (if (result i32)
      #|      (call $foo)
      #|      (then
      #|        i32.const 1)
      #|      (else
      #|        (if (result i32)
      #|          (call $bar)
      #|          (then
      #|            global.get $once)
      #|          (else
      #|            i32.const 2))
      #|        i32.const 4
      #|        i32.add))
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes safe-side-effect if-arm pure read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (if (result i32)
      #|      (call $foo)
      #|      (then
      #|        i32.const 1)
      #|      (else
      #|        global.get $once
      #|        i32.const 2
      #|        i32.add))
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes safe-side-effect if-arm through post pure operators" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (if (result i32)
      #|      (call $foo)
      #|      (then
      #|        i32.const 1)
      #|      (else
      #|        global.get $once))
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes safe-side-effect if-arm if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (if (result i32)
      #|      (call $foo)
      #|      (then
      #|        i32.const 1)
      #|      (else
      #|        global.get $once))
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $once))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps if-arm if-return values flowing into side effects" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    (if (result i32)
      #|      (call $foo)
      #|      (then
      #|        i32.const 1)
      #|      (else
      #|        global.get $once))
      #|    local.tee $tmp
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $once))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("local.tee"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps if-arm post values flowing into side effects" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    (if (result i32)
      #|      (call $foo)
      #|      (then
      #|        i32.const 1)
      #|      (else
      #|        global.get $once))
      #|    local.tee $tmp
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("local.tee"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block prefix independent call read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (block (result i32)
      #|      call $foo
      #|      drop
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("block"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block prefix independent void call guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo))
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (block (result i32)
      #|      call $foo
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("block"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block prefix independent memory guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1 1)
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "size")
      #|    (block (result i32)
      #|      memory.size
      #|      drop
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end)
      #|  (func (export "grow")
      #|    (block (result i32)
      #|      i32.const 0
      #|      memory.grow
      #|      drop
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let size_pretty = optimized.pretty_print_defined_func(0U)
  assert_false(size_pretty.contains("global.get"), msg=size_pretty)
  assert_false(size_pretty.contains("global.set"), msg=size_pretty)
  assert_false(size_pretty.contains("memory.size"), msg=size_pretty)
  let grow_pretty = optimized.pretty_print_defined_func(1U)
  assert_true(grow_pretty.contains("memory.grow"), msg=grow_pretty)
  assert_true(grow_pretty.contains("drop"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.get"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.set"), msg=grow_pretty)
}

///|
test "simplify-globals-optimizing removes block prefix independent table guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 2 funcref)
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "size")
      #|    (block (result i32)
      #|      table.size 0
      #|      drop
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end)
      #|  (func (export "grow")
      #|    (block (result i32)
      #|      ref.null func
      #|      i32.const 0
      #|      table.grow 0
      #|      drop
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let size_pretty = optimized.pretty_print_defined_func(0U)
  assert_false(size_pretty.contains("global.get"), msg=size_pretty)
  assert_false(size_pretty.contains("global.set"), msg=size_pretty)
  assert_false(size_pretty.contains("table.size"), msg=size_pretty)
  let grow_pretty = optimized.pretty_print_defined_func(1U)
  assert_true(grow_pretty.contains("table.grow"), msg=grow_pretty)
  assert_true(grow_pretty.contains("drop"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.get"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.set"), msg=grow_pretty)
}

///|
test "simplify-globals-optimizing removes block prefix independent table fill and copy guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table 10 funcref)
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "fill")
      #|    (block (result i32)
      #|      i32.const 0
      #|      ref.null func
      #|      i32.const 1
      #|      table.fill 0
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end)
      #|  (func (export "copy")
      #|    (block (result i32)
      #|      i32.const 0
      #|      i32.const 1
      #|      i32.const 2
      #|      table.copy 0 0
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let fill_pretty = optimized.pretty_print_defined_func(0U)
  assert_true(fill_pretty.contains("table.fill"), msg=fill_pretty)
  assert_false(fill_pretty.contains("global.get"), msg=fill_pretty)
  assert_false(fill_pretty.contains("global.set"), msg=fill_pretty)
  let copy_pretty = optimized.pretty_print_defined_func(1U)
  assert_true(copy_pretty.contains("table.copy"), msg=copy_pretty)
  assert_false(copy_pretty.contains("global.get"), msg=copy_pretty)
  assert_false(copy_pretty.contains("global.set"), msg=copy_pretty)
}

///|
test "simplify-globals-optimizing removes if-return block prefix independent table fill and copy guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table 10 funcref)
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "fill")
      #|    block (result i32)
      #|      i32.const 0
      #|      ref.null func
      #|      i32.const 1
      #|      table.fill 0
      #|      global.get $once
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $once)
      #|  (func (export "copy")
      #|    block (result i32)
      #|      i32.const 0
      #|      i32.const 1
      #|      i32.const 2
      #|      table.copy 0 0
      #|      global.get $once
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $once))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let fill_pretty = optimized.pretty_print_defined_func(0U)
  assert_true(fill_pretty.contains("table.fill"), msg=fill_pretty)
  assert_false(fill_pretty.contains("if"), msg=fill_pretty)
  assert_false(fill_pretty.contains("return"), msg=fill_pretty)
  assert_false(fill_pretty.contains("global.get"), msg=fill_pretty)
  assert_false(fill_pretty.contains("global.set"), msg=fill_pretty)
  let copy_pretty = optimized.pretty_print_defined_func(1U)
  assert_true(copy_pretty.contains("table.copy"), msg=copy_pretty)
  assert_false(copy_pretty.contains("if"), msg=copy_pretty)
  assert_false(copy_pretty.contains("return"), msg=copy_pretty)
  assert_false(copy_pretty.contains("global.get"), msg=copy_pretty)
  assert_false(copy_pretty.contains("global.set"), msg=copy_pretty)
}

///|
test "simplify-globals-optimizing removes block prefix independent table.set guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table 10 funcref)
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "set")
      #|    (block (result i32)
      #|      i32.const 0
      #|      ref.null func
      #|      table.set 0
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("table.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes if-return block prefix independent table.set guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table 10 funcref)
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "set")
      #|    block (result i32)
      #|      i32.const 0
      #|      ref.null func
      #|      table.set 0
      #|      global.get $once
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $once))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("table.set"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("return"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block prefix independent table.init and elem.drop guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (func $target)
      #|  (table 10 funcref)
      #|  (elem func $target)
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "init")
      #|    (block (result i32)
      #|      i32.const 0
      #|      i32.const 0
      #|      i32.const 1
      #|      table.init 0 0
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end)
      #|  (func (export "drop")
      #|    (block (result i32)
      #|      elem.drop 0
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let init_pretty = optimized.pretty_print_defined_func(1U)
  assert_true(init_pretty.contains("table.init"), msg=init_pretty)
  assert_false(init_pretty.contains("global.get"), msg=init_pretty)
  assert_false(init_pretty.contains("global.set"), msg=init_pretty)
  let drop_pretty = optimized.pretty_print_defined_func(2U)
  assert_true(drop_pretty.contains("elem.drop"), msg=drop_pretty)
  assert_false(drop_pretty.contains("global.get"), msg=drop_pretty)
  assert_false(drop_pretty.contains("global.set"), msg=drop_pretty)
}

///|
test "simplify-globals-optimizing removes if-return block prefix independent table.init and elem.drop guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (func $target)
      #|  (table 10 funcref)
      #|  (elem func $target)
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "init")
      #|    block (result i32)
      #|      i32.const 0
      #|      i32.const 0
      #|      i32.const 1
      #|      table.init 0 0
      #|      global.get $once
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $once)
      #|  (func (export "drop")
      #|    block (result i32)
      #|      elem.drop 0
      #|      global.get $once
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $once))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let init_pretty = optimized.pretty_print_defined_func(1U)
  assert_true(init_pretty.contains("table.init"), msg=init_pretty)
  assert_false(init_pretty.contains("if"), msg=init_pretty)
  assert_false(init_pretty.contains("return"), msg=init_pretty)
  assert_false(init_pretty.contains("global.get"), msg=init_pretty)
  assert_false(init_pretty.contains("global.set"), msg=init_pretty)
  let drop_pretty = optimized.pretty_print_defined_func(2U)
  assert_true(drop_pretty.contains("elem.drop"), msg=drop_pretty)
  assert_false(drop_pretty.contains("if"), msg=drop_pretty)
  assert_false(drop_pretty.contains("return"), msg=drop_pretty)
  assert_false(drop_pretty.contains("global.get"), msg=drop_pretty)
  assert_false(drop_pretty.contains("global.set"), msg=drop_pretty)
}

///|
test "simplify-globals-optimizing keeps block prefix values flowing into table.init" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (func $target)
      #|  (table 10 funcref)
      #|  (elem func $target)
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (block (result i32)
      #|      global.get $once
      #|      i32.const 0
      #|      i32.const 1
      #|      table.init 0 0
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("table.init"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps block prefix values flowing into table.set" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table 10 funcref)
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (block (result i32)
      #|      i32.const 0
      #|      ref.null func
      #|      table.set 0
      #|      global.get $once
      #|      ref.null func
      #|      table.set 0
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("table.set"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps block prefix values flowing into table.fill" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table 10 funcref)
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (block (result i32)
      #|      global.get $once
      #|      ref.null func
      #|      i32.const 1
      #|      table.fill 0
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("table.fill"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes if-return block prefix independent table guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 2 funcref)
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      ref.null func
      #|      i32.const 0
      #|      table.grow 0
      #|      drop
      #|      global.get $once
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $once))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("return"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps block prefix values flowing into table.grow" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 2 funcref)
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (block (result i32)
      #|      ref.null func
      #|      global.get $once
      #|      table.grow 0
      #|      drop
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes if-return block prefix independent memory guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1 1)
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      i32.const 0
      #|      memory.grow
      #|      drop
      #|      global.get $once
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $once))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("return"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes if-return block prefix independent call guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      call $foo
      #|      drop
      #|      global.get $once
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $once))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("return"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes if-return block prefix independent void call guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo))
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      call $foo
      #|      global.get $once
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $once))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("return"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps if-return block prefix values flowing into calls" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (param i32) (result i32)))
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      global.get $once
      #|      call $foo
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $once))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block prefix independent local writes" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32) (local $tmp i32)
      #|    (block (result i32)
      #|      i32.const 42
      #|      local.set $tmp
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end
      #|    local.get $tmp)
      #|  (func (export "tee") (local $tmp i32)
      #|    (block (result i32)
      #|      i32.const 7
      #|      local.tee $tmp
      #|      drop
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end
      #|    local.get $tmp
      #|    drop))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.const"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
  let tee_pretty = optimized.pretty_print_defined_func(1U)
  assert_false(tee_pretty.contains("if"), msg=tee_pretty)
  assert_false(tee_pretty.contains("local.tee"), msg=tee_pretty)
  assert_false(tee_pretty.contains("global.get"), msg=tee_pretty)
  assert_false(tee_pretty.contains("global.set"), msg=tee_pretty)
}

///|
test "simplify-globals-optimizing removes if-return block prefix independent local writes" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    block (result i32)
      #|      i32.const 42
      #|      local.set $tmp
      #|      global.get $once
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $once))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("return"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block prefix independent global writes" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (global $other (export "other") (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (block (result i32)
      #|      i32.const 7
      #|      global.set $other
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("i32.const"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes if-return block prefix independent global writes" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (global $other (export "other") (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      i32.const 7
      #|      global.set $other
      #|      global.get $once
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $once))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("return"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps block prefix values flowing into global writes" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (global $other (export "other") (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (block (result i32)
      #|      global.get $once
      #|      global.set $other
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps block prefix values flowing into local writes" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    (block (result i32)
      #|      global.get $once
      #|      local.set $tmp
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps block prefix values flowing into memory.grow" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (block (result i32)
      #|      global.get $once
      #|      memory.grow
      #|      drop
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps block prefix values flowing into calls" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "sink" (func $sink (param i32) (result i32)))
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (block (result i32)
      #|      global.get $once
      #|      call $sink
      #|      drop
      #|      global.get $once)
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps if-arm condition values flowing into side effects" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    (if (result i32)
      #|      (call $foo)
      #|      (then
      #|        i32.const 1)
      #|      (else
      #|        global.get $once
      #|        local.tee $tmp))
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("local.tee"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps self guards that set another global" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "next" (func $next (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (global $other (export "other") (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $next
      #|    global.set $guard
      #|    global.get $guard
      #|    if
      #|      i32.const 1
      #|      global.set $other
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps self guards with non-constant set operands" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "next" (func $next (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    if
      #|      call $next
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps self guards with else arms" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "tick" (func $tick))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    else
      #|      call $tick
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes self guards through select condition flow" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    i32.const 1
      #|    global.get $guard
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes official side-effecting select read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    i32.const 0
      #|    i32.load
      #|    i32.const 0
      #|    local.tee $tmp
      #|    global.get $guard
      #|    i32.const 1
      #|    i32.add
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end
      #|    local.get $tmp
      #|    drop))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes side-effecting select eqz read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    i32.const 2
      #|    i32.load
      #|    i32.const 0
      #|    local.tee $tmp
      #|    global.get $guard
      #|    i32.const 1337
      #|    i32.add
      #|    select
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end
      #|    local.get $tmp
      #|    drop))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes side-effecting select if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $x i32)
      #|    i32.const 2
      #|    i32.load
      #|    i32.const 1
      #|    local.tee $x
      #|    global.get $guard
      #|    i32.const 1337
      #|    i32.add
      #|    select
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes side-effecting select eqz if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    i32.const 2
      #|    i32.load
      #|    i32.const 0
      #|    local.tee $tmp
      #|    global.get $guard
      #|    i32.const 1337
      #|    i32.add
      #|    select
      #|    i32.eqz
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes select operand read with independent local tee" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    global.get $guard
      #|    i32.const 7
      #|    local.tee $tmp
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)

  let reverse = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    i32.const 7
      #|    local.tee $tmp
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(reverse_pretty.contains("local.tee"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("select"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)
}

///|
test "simplify-globals-optimizing removes select operand if-return read with independent local tee" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    global.get $guard
      #|    i32.const 7
      #|    local.tee $tmp
      #|    i32.const 1
      #|    select
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)

  let reverse = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    i32.const 7
      #|    local.tee $tmp
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(reverse_pretty.contains("local.tee"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("select"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)
}

///|
test "simplify-globals-optimizing keeps values flowing into local tee select guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    i32.const 7
      #|    global.get $guard
      #|    i32.add
      #|    local.tee $tmp
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps extra reads after local tee select guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    global.get $guard
      #|    i32.const 7
      #|    local.tee $tmp
      #|    i32.const 1
      #|    select
      #|    drop
      #|    global.get $guard
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes select operand read with independent call" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $foo
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes select operand if-return read with independent call" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $foo
      #|    i32.const 1
      #|    select
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes compare operand read with independent local tee" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    global.get $guard
      #|    i32.const 7
      #|    local.tee $tmp
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("i32.eq"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)

  let reverse = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    i32.const 7
      #|    local.tee $tmp
      #|    global.get $guard
      #|    i32.ne
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(reverse_pretty.contains("local.tee"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("i32.ne"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)
}

///|
test "simplify-globals-optimizing removes compare operand if-return read with independent local tee" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    i32.const 7
      #|    local.tee $tmp
      #|    global.get $guard
      #|    i32.eq
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("i32.eq"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes compare operand read with local-fed local tee" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $v i32) (local $tmp i32)
      #|    global.get $guard
      #|    local.get $v
      #|    local.tee $tmp
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("i32.eq"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)

  let reverse = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $v i32) (local $tmp i32)
      #|    local.get $v
      #|    local.tee $tmp
      #|    global.get $guard
      #|    i32.ne
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(reverse_pretty.contains("local.tee"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("i32.ne"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)
}

///|
test "simplify-globals-optimizing removes compare operand if-return read with local-fed local tee" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $v i32) (local $tmp i32)
      #|    local.get $v
      #|    local.tee $tmp
      #|    global.get $guard
      #|    i32.eq
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("i32.eq"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes compare operand read with independent local set" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    block (result i32)
      #|      i32.const 7
      #|      local.set $tmp
      #|      global.get $guard
      #|      local.get $tmp
      #|      i32.eq
      #|    end
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("i32.eq"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)

  let reverse = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    block (result i32)
      #|      i32.const 7
      #|      local.set $tmp
      #|      local.get $tmp
      #|      global.get $guard
      #|      i32.ne
      #|    end
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(reverse_pretty.contains("i32.ne"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)
}

///|
test "simplify-globals-optimizing removes compare operand if-return read with independent local set" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    block (result i32)
      #|      i32.const 7
      #|      local.set $tmp
      #|      local.get $tmp
      #|      global.get $guard
      #|      i32.ne
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("i32.ne"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes compare operand read with local-fed local set" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $v i32) (local $tmp i32)
      #|    block (result i32)
      #|      local.get $v
      #|      local.set $tmp
      #|      global.get $guard
      #|      local.get $tmp
      #|      i32.eq
      #|    end
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set"), msg=pretty)
  assert_false(pretty.contains("i32.eq"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)

  let reverse = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $v i32) (local $tmp i32)
      #|    block (result i32)
      #|      local.get $v
      #|      local.set $tmp
      #|      local.get $tmp
      #|      global.get $guard
      #|      i32.ne
      #|    end
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(reverse_pretty.contains("local.set"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("i32.ne"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)
}

///|
test "simplify-globals-optimizing removes compare operand if-return read with local-fed local set" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $v i32) (local $tmp i32)
      #|    block (result i32)
      #|      local.get $v
      #|      local.set $tmp
      #|      local.get $tmp
      #|      global.get $guard
      #|      i32.ne
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set"), msg=pretty)
  assert_false(pretty.contains("i32.ne"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps values flowing into local set compare guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    block (result i32)
      #|      global.get $guard
      #|      local.set $tmp
      #|      local.get $tmp
      #|      i32.const 0
      #|      i32.eq
      #|    end
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes compare operand read with independent global set" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (global $other (export "other") (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    block (result i32)
      #|      i32.const 7
      #|      global.set $other
      #|      i32.const 0
      #|    end
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("i32.eq"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)

  let reverse = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (global $other (export "other") (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      i32.const 7
      #|      global.set $other
      #|      i32.const 0
      #|    end
      #|    global.get $guard
      #|    i32.ne
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(reverse_pretty.contains("global.set"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("i32.ne"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
}

///|
test "simplify-globals-optimizing removes compare operand if-return read with independent global set" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (global $other (export "other") (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    block (result i32)
      #|      i32.const 7
      #|      global.set $other
      #|      i32.const 0
      #|    end
      #|    i32.eq
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("i32.eq"), msg=pretty)
  assert_false(pretty.contains("return"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes compare operand read with local-fed global set" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (global $other (export "other") (mut i32) (i32.const 0))
      #|  (func (export "run") (param $value i32)
      #|    global.get $guard
      #|    block (result i32)
      #|      local.get $value
      #|      global.set $other
      #|      i32.const 0
      #|    end
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("i32.eq"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)

  let reverse = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (global $other (export "other") (mut i32) (i32.const 0))
      #|  (func (export "run") (param $value i32)
      #|    block (result i32)
      #|      local.get $value
      #|      global.set $other
      #|      i32.const 0
      #|    end
      #|    global.get $guard
      #|    i32.ne
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(reverse_pretty.contains("local.get"), msg=reverse_pretty)
  assert_true(reverse_pretty.contains("global.set"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("i32.ne"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
}

///|
test "simplify-globals-optimizing removes compare operand if-return read with local-fed global set" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (global $other (export "other") (mut i32) (i32.const 0))
      #|  (func (export "run") (param $value i32)
      #|    global.get $guard
      #|    block (result i32)
      #|      local.get $value
      #|      global.set $other
      #|      i32.const 0
      #|    end
      #|    i32.eq
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("i32.eq"), msg=pretty)
  assert_false(pretty.contains("return"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes compare operand read with independent memory store" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    block (result i32)
      #|      i32.const 0
      #|      i32.const 7
      #|      i32.store
      #|      i32.const 0
      #|    end
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_false(pretty.contains("i32.eq"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)

  let reverse = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      i32.const 0
      #|      i32.const 7
      #|      i32.store
      #|      i32.const 0
      #|    end
      #|    global.get $guard
      #|    i32.ne
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(reverse_pretty.contains("i32.store"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("i32.ne"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)
}

///|
test "simplify-globals-optimizing removes compare operand if-return read with independent memory store" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    block (result i32)
      #|      i32.const 0
      #|      i32.const 7
      #|      i32.store
      #|      i32.const 0
      #|    end
      #|    i32.eq
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_false(pretty.contains("i32.eq"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes compare operand read with local-fed memory store" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $addr i32) (param $val i32)
      #|    global.get $guard
      #|    block (result i32)
      #|      local.get $addr
      #|      local.get $val
      #|      i32.store
      #|      i32.const 0
      #|    end
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_false(pretty.contains("i32.eq"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)

  let reverse = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $addr i32) (param $val i32)
      #|    block (result i32)
      #|      local.get $addr
      #|      local.get $val
      #|      i32.store
      #|      i32.const 0
      #|    end
      #|    global.get $guard
      #|    i32.ne
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(reverse_pretty.contains("i32.store"), msg=reverse_pretty)
  assert_true(reverse_pretty.contains("local.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("i32.ne"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)
}

///|
test "simplify-globals-optimizing removes compare operand if-return read with local-fed memory store" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $addr i32) (param $val i32)
      #|    global.get $guard
      #|    block (result i32)
      #|      local.get $addr
      #|      local.get $val
      #|      i32.store
      #|      i32.const 0
      #|    end
      #|    i32.eq
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_false(pretty.contains("i32.eq"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps values flowing into memory store compare guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      i32.const 0
      #|      global.get $guard
      #|      i32.store
      #|      i32.const 0
      #|    end
      #|    i32.const 0
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps values flowing into global set compare guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (global $other (export "other") (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      global.get $guard
      #|      global.set $other
      #|      i32.const 0
      #|    end
      #|    global.get $guard
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps values flowing into local tee compare guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    global.get $guard
      #|    local.tee $tmp
      #|    i32.const 0
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes independent call compare read-only-to-write guards" {
  let direct_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $foo
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(direct_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let direct_pretty = direct_optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(direct_pretty.contains("call"), msg=direct_pretty)
  assert_true(direct_pretty.contains("drop"), msg=direct_pretty)
  assert_false(direct_pretty.contains("if"), msg=direct_pretty)
  assert_false(direct_pretty.contains("global.get"), msg=direct_pretty)
  assert_false(direct_pretty.contains("global.set"), msg=direct_pretty)

  let reverse_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $foo
      #|    global.get $guard
      #|    i32.ne
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(reverse_pretty.contains("call"), msg=reverse_pretty)
  assert_true(reverse_pretty.contains("drop"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)
}

///|
test "simplify-globals-optimizing removes independent call compare if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $foo
      #|    i32.ne
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps values flowing into call compare guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (param i32) (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $foo
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes independent table compare read-only-to-write guards" {
  let size_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    table.size 0
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(size_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let size_pretty = size_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(size_pretty.contains("table.size"), msg=size_pretty)
  assert_false(size_pretty.contains("if"), msg=size_pretty)
  assert_false(size_pretty.contains("global.get"), msg=size_pretty)
  assert_false(size_pretty.contains("global.set"), msg=size_pretty)

  let grow_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    ref.null func
      #|    i32.const 0
      #|    table.grow 0
      #|    i32.ne
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(grow_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let grow_pretty = grow_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(grow_pretty.contains("table.grow"), msg=grow_pretty)
  assert_true(grow_pretty.contains("drop"), msg=grow_pretty)
  assert_false(grow_pretty.contains("if"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.get"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.set"), msg=grow_pretty)

  let reverse_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    table.size 0
      #|    global.get $guard
      #|    i32.ne
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_false(reverse_pretty.contains("table.size"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)

  let grow_reverse_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    ref.null func
      #|    i32.const 0
      #|    table.grow 0
      #|    global.get $guard
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(grow_reverse_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let grow_reverse_pretty = grow_reverse_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(
    grow_reverse_pretty.contains("table.grow"),
    msg=grow_reverse_pretty,
  )
  assert_true(grow_reverse_pretty.contains("drop"), msg=grow_reverse_pretty)
  assert_false(grow_reverse_pretty.contains("if"), msg=grow_reverse_pretty)
  assert_false(
    grow_reverse_pretty.contains("global.get"),
    msg=grow_reverse_pretty,
  )
  assert_false(
    grow_reverse_pretty.contains("global.set"),
    msg=grow_reverse_pretty,
  )
}

///|
test "simplify-globals-optimizing removes independent table compare if-return guards" {
  let grow_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    ref.null func
      #|    i32.const 0
      #|    table.grow 0
      #|    i32.ne
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(grow_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let grow_pretty = grow_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(grow_pretty.contains("table.grow"), msg=grow_pretty)
  assert_true(grow_pretty.contains("drop"), msg=grow_pretty)
  assert_false(grow_pretty.contains("if"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.get"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.set"), msg=grow_pretty)

  let reverse_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    table.size 0
      #|    global.get $guard
      #|    i32.eq
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_false(reverse_pretty.contains("table.size"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)

  let grow_reverse_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    ref.null func
      #|    i32.const 0
      #|    table.grow 0
      #|    global.get $guard
      #|    i32.ne
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(grow_reverse_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let grow_reverse_pretty = grow_reverse_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(
    grow_reverse_pretty.contains("table.grow"),
    msg=grow_reverse_pretty,
  )
  assert_true(grow_reverse_pretty.contains("drop"), msg=grow_reverse_pretty)
  assert_false(grow_reverse_pretty.contains("if"), msg=grow_reverse_pretty)
  assert_false(
    grow_reverse_pretty.contains("global.get"),
    msg=grow_reverse_pretty,
  )
  assert_false(
    grow_reverse_pretty.contains("global.set"),
    msg=grow_reverse_pretty,
  )
}

///|
test "simplify-globals-optimizing removes local-fed table grow compare read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $r funcref) (param $n i32)
      #|    global.get $guard
      #|    local.get $r
      #|    local.get $n
      #|    table.grow 0
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)

  let reverse_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $r funcref) (param $n i32)
      #|    local.get $r
      #|    local.get $n
      #|    table.grow 0
      #|    global.get $guard
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(reverse_pretty.contains("local.get"), msg=reverse_pretty)
  assert_true(reverse_pretty.contains("table.grow"), msg=reverse_pretty)
  assert_true(reverse_pretty.contains("drop"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)
}

///|
test "simplify-globals-optimizing removes local-fed table grow compare if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $r funcref) (param $n i32)
      #|    global.get $guard
      #|    local.get $r
      #|    local.get $n
      #|    table.grow 0
      #|    i32.ne
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps values flowing into table grow compare guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    ref.null func
      #|    global.get $guard
      #|    table.grow 0
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes independent table select read-only-to-write guards" {
  let size_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    table.size 0
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(size_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let size_pretty = size_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(size_pretty.contains("table.size"), msg=size_pretty)
  assert_false(size_pretty.contains("select"), msg=size_pretty)
  assert_false(size_pretty.contains("if"), msg=size_pretty)
  assert_false(size_pretty.contains("global.get"), msg=size_pretty)
  assert_false(size_pretty.contains("global.set"), msg=size_pretty)

  let grow_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    ref.null func
      #|    i32.const 0
      #|    table.grow 0
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(grow_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let grow_pretty = grow_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(grow_pretty.contains("table.grow"), msg=grow_pretty)
  assert_true(grow_pretty.contains("drop"), msg=grow_pretty)
  assert_false(grow_pretty.contains("select"), msg=grow_pretty)
  assert_false(grow_pretty.contains("if"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.get"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.set"), msg=grow_pretty)

  let reverse_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    table.size 0
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_false(reverse_pretty.contains("table.size"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("select"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)

  let grow_reverse_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    ref.null func
      #|    i32.const 0
      #|    table.grow 0
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(grow_reverse_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let grow_reverse_pretty = grow_reverse_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(
    grow_reverse_pretty.contains("table.grow"),
    msg=grow_reverse_pretty,
  )
  assert_true(grow_reverse_pretty.contains("drop"), msg=grow_reverse_pretty)
  assert_false(grow_reverse_pretty.contains("select"), msg=grow_reverse_pretty)
  assert_false(grow_reverse_pretty.contains("if"), msg=grow_reverse_pretty)
  assert_false(
    grow_reverse_pretty.contains("global.get"),
    msg=grow_reverse_pretty,
  )
  assert_false(
    grow_reverse_pretty.contains("global.set"),
    msg=grow_reverse_pretty,
  )
}

///|
test "simplify-globals-optimizing removes independent table select if-return guards" {
  let grow_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    ref.null func
      #|    i32.const 0
      #|    table.grow 0
      #|    i32.const 1
      #|    select
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(grow_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let grow_pretty = grow_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(grow_pretty.contains("table.grow"), msg=grow_pretty)
  assert_true(grow_pretty.contains("drop"), msg=grow_pretty)
  assert_false(grow_pretty.contains("select"), msg=grow_pretty)
  assert_false(grow_pretty.contains("if"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.get"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.set"), msg=grow_pretty)

  let reverse_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    table.size 0
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_false(reverse_pretty.contains("table.size"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("select"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)

  let grow_reverse_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    ref.null func
      #|    i32.const 0
      #|    table.grow 0
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(grow_reverse_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let grow_reverse_pretty = grow_reverse_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(
    grow_reverse_pretty.contains("table.grow"),
    msg=grow_reverse_pretty,
  )
  assert_true(grow_reverse_pretty.contains("drop"), msg=grow_reverse_pretty)
  assert_false(grow_reverse_pretty.contains("select"), msg=grow_reverse_pretty)
  assert_false(grow_reverse_pretty.contains("if"), msg=grow_reverse_pretty)
  assert_false(
    grow_reverse_pretty.contains("global.get"),
    msg=grow_reverse_pretty,
  )
  assert_false(
    grow_reverse_pretty.contains("global.set"),
    msg=grow_reverse_pretty,
  )
}

///|
test "simplify-globals-optimizing removes local-fed table grow select guards" {
  let direct_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $r funcref) (param $n i32)
      #|    global.get $guard
      #|    local.get $r
      #|    local.get $n
      #|    table.grow 0
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(direct_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let direct_pretty = direct_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(direct_pretty.contains("local.get"), msg=direct_pretty)
  assert_true(direct_pretty.contains("table.grow"), msg=direct_pretty)
  assert_true(direct_pretty.contains("drop"), msg=direct_pretty)
  assert_false(direct_pretty.contains("select"), msg=direct_pretty)
  assert_false(direct_pretty.contains("if"), msg=direct_pretty)
  assert_false(direct_pretty.contains("global.get"), msg=direct_pretty)
  assert_false(direct_pretty.contains("global.set"), msg=direct_pretty)

  let second_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $r funcref) (param $n i32)
      #|    local.get $r
      #|    local.get $n
      #|    table.grow 0
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(second_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let second_pretty = second_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(second_pretty.contains("local.get"), msg=second_pretty)
  assert_true(second_pretty.contains("table.grow"), msg=second_pretty)
  assert_true(second_pretty.contains("drop"), msg=second_pretty)
  assert_false(second_pretty.contains("select"), msg=second_pretty)
  assert_false(second_pretty.contains("if"), msg=second_pretty)
  assert_false(second_pretty.contains("global.get"), msg=second_pretty)
  assert_false(second_pretty.contains("global.set"), msg=second_pretty)
}

///|
test "simplify-globals-optimizing removes pure-add grow select guards" {
  let memory_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $n i32)
      #|    global.get $guard
      #|    local.get $n
      #|    i32.const 1
      #|    i32.add
      #|    memory.grow
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(memory_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let memory_pretty = memory_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(memory_pretty.contains("local.get"), msg=memory_pretty)
  assert_true(memory_pretty.contains("i32.add"), msg=memory_pretty)
  assert_true(memory_pretty.contains("memory.grow"), msg=memory_pretty)
  assert_true(memory_pretty.contains("drop"), msg=memory_pretty)
  assert_false(memory_pretty.contains("select"), msg=memory_pretty)
  assert_false(memory_pretty.contains("if"), msg=memory_pretty)
  assert_false(memory_pretty.contains("global.get"), msg=memory_pretty)
  assert_false(memory_pretty.contains("global.set"), msg=memory_pretty)

  let table_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $r funcref) (param $n i32)
      #|    global.get $guard
      #|    local.get $r
      #|    local.get $n
      #|    i32.const 1
      #|    i32.add
      #|    table.grow 0
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(table_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let table_pretty = table_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(table_pretty.contains("local.get"), msg=table_pretty)
  assert_true(table_pretty.contains("i32.add"), msg=table_pretty)
  assert_true(table_pretty.contains("table.grow"), msg=table_pretty)
  assert_true(table_pretty.contains("drop"), msg=table_pretty)
  assert_false(table_pretty.contains("select"), msg=table_pretty)
  assert_false(table_pretty.contains("if"), msg=table_pretty)
  assert_false(table_pretty.contains("global.get"), msg=table_pretty)
  assert_false(table_pretty.contains("global.set"), msg=table_pretty)
}

///|
test "simplify-globals-optimizing removes reverse pure-add grow select guards" {
  let memory_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $n i32)
      #|    local.get $n
      #|    i32.const 1
      #|    i32.add
      #|    memory.grow
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(memory_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let memory_pretty = memory_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(memory_pretty.contains("local.get"), msg=memory_pretty)
  assert_true(memory_pretty.contains("i32.add"), msg=memory_pretty)
  assert_true(memory_pretty.contains("memory.grow"), msg=memory_pretty)
  assert_true(memory_pretty.contains("drop"), msg=memory_pretty)
  assert_false(memory_pretty.contains("select"), msg=memory_pretty)
  assert_false(memory_pretty.contains("if"), msg=memory_pretty)
  assert_false(memory_pretty.contains("global.get"), msg=memory_pretty)
  assert_false(memory_pretty.contains("global.set"), msg=memory_pretty)

  let memory_return_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $n i32)
      #|    local.get $n
      #|    i32.const 1
      #|    i32.add
      #|    memory.grow
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(memory_return_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let memory_return_pretty = memory_return_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(
    memory_return_pretty.contains("memory.grow"),
    msg=memory_return_pretty,
  )
  assert_true(
    memory_return_pretty.contains("i32.add"),
    msg=memory_return_pretty,
  )
  assert_true(memory_return_pretty.contains("drop"), msg=memory_return_pretty)
  assert_false(
    memory_return_pretty.contains("select"),
    msg=memory_return_pretty,
  )
  assert_false(memory_return_pretty.contains("if"), msg=memory_return_pretty)
  assert_false(
    memory_return_pretty.contains("global.get"),
    msg=memory_return_pretty,
  )
  assert_false(
    memory_return_pretty.contains("global.set"),
    msg=memory_return_pretty,
  )

  let table_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $r funcref) (param $n i32)
      #|    local.get $r
      #|    local.get $n
      #|    i32.const 1
      #|    i32.add
      #|    table.grow 0
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(table_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let table_pretty = table_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(table_pretty.contains("local.get"), msg=table_pretty)
  assert_true(table_pretty.contains("i32.add"), msg=table_pretty)
  assert_true(table_pretty.contains("table.grow"), msg=table_pretty)
  assert_true(table_pretty.contains("drop"), msg=table_pretty)
  assert_false(table_pretty.contains("select"), msg=table_pretty)
  assert_false(table_pretty.contains("if"), msg=table_pretty)
  assert_false(table_pretty.contains("global.get"), msg=table_pretty)
  assert_false(table_pretty.contains("global.set"), msg=table_pretty)

  let table_return_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $r funcref) (param $n i32)
      #|    local.get $r
      #|    local.get $n
      #|    i32.const 1
      #|    i32.add
      #|    table.grow 0
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(table_return_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let table_return_pretty = table_return_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(
    table_return_pretty.contains("table.grow"),
    msg=table_return_pretty,
  )
  assert_true(table_return_pretty.contains("i32.add"), msg=table_return_pretty)
  assert_true(table_return_pretty.contains("drop"), msg=table_return_pretty)
  assert_false(table_return_pretty.contains("select"), msg=table_return_pretty)
  assert_false(table_return_pretty.contains("if"), msg=table_return_pretty)
  assert_false(
    table_return_pretty.contains("global.get"),
    msg=table_return_pretty,
  )
  assert_false(
    table_return_pretty.contains("global.set"),
    msg=table_return_pretty,
  )
}

///|
test "simplify-globals-optimizing removes pure-add grow compare guards" {
  let memory_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $n i32)
      #|    global.get $guard
      #|    local.get $n
      #|    i32.const 1
      #|    i32.add
      #|    memory.grow
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(memory_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let memory_pretty = memory_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(memory_pretty.contains("local.get"), msg=memory_pretty)
  assert_true(memory_pretty.contains("i32.add"), msg=memory_pretty)
  assert_true(memory_pretty.contains("memory.grow"), msg=memory_pretty)
  assert_true(memory_pretty.contains("drop"), msg=memory_pretty)
  assert_false(memory_pretty.contains("i32.eq"), msg=memory_pretty)
  assert_false(memory_pretty.contains("if"), msg=memory_pretty)
  assert_false(memory_pretty.contains("global.get"), msg=memory_pretty)
  assert_false(memory_pretty.contains("global.set"), msg=memory_pretty)

  let memory_return_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $n i32)
      #|    global.get $guard
      #|    local.get $n
      #|    i32.const 1
      #|    i32.add
      #|    memory.grow
      #|    i32.eq
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(memory_return_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let memory_return_pretty = memory_return_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(
    memory_return_pretty.contains("local.get"),
    msg=memory_return_pretty,
  )
  assert_true(
    memory_return_pretty.contains("i32.add"),
    msg=memory_return_pretty,
  )
  assert_true(
    memory_return_pretty.contains("memory.grow"),
    msg=memory_return_pretty,
  )
  assert_true(memory_return_pretty.contains("drop"), msg=memory_return_pretty)
  assert_false(
    memory_return_pretty.contains("i32.eq"),
    msg=memory_return_pretty,
  )
  assert_false(memory_return_pretty.contains("if"), msg=memory_return_pretty)
  assert_false(
    memory_return_pretty.contains("global.get"),
    msg=memory_return_pretty,
  )
  assert_false(
    memory_return_pretty.contains("global.set"),
    msg=memory_return_pretty,
  )

  let table_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $r funcref) (param $n i32)
      #|    global.get $guard
      #|    local.get $r
      #|    local.get $n
      #|    i32.const 1
      #|    i32.add
      #|    table.grow 0
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(table_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let table_pretty = table_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(table_pretty.contains("local.get"), msg=table_pretty)
  assert_true(table_pretty.contains("i32.add"), msg=table_pretty)
  assert_true(table_pretty.contains("table.grow"), msg=table_pretty)
  assert_true(table_pretty.contains("drop"), msg=table_pretty)
  assert_false(table_pretty.contains("i32.eq"), msg=table_pretty)
  assert_false(table_pretty.contains("if"), msg=table_pretty)
  assert_false(table_pretty.contains("global.get"), msg=table_pretty)
  assert_false(table_pretty.contains("global.set"), msg=table_pretty)

  let table_return_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $r funcref) (param $n i32)
      #|    global.get $guard
      #|    local.get $r
      #|    local.get $n
      #|    i32.const 1
      #|    i32.add
      #|    table.grow 0
      #|    i32.eq
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(table_return_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let table_return_pretty = table_return_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(
    table_return_pretty.contains("local.get"),
    msg=table_return_pretty,
  )
  assert_true(table_return_pretty.contains("i32.add"), msg=table_return_pretty)
  assert_true(
    table_return_pretty.contains("table.grow"),
    msg=table_return_pretty,
  )
  assert_true(table_return_pretty.contains("drop"), msg=table_return_pretty)
  assert_false(table_return_pretty.contains("i32.eq"), msg=table_return_pretty)
  assert_false(table_return_pretty.contains("if"), msg=table_return_pretty)
  assert_false(
    table_return_pretty.contains("global.get"),
    msg=table_return_pretty,
  )
  assert_false(
    table_return_pretty.contains("global.set"),
    msg=table_return_pretty,
  )
}

///|
test "simplify-globals-optimizing removes local-fed table grow select if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $r funcref) (param $n i32)
      #|    global.get $guard
      #|    local.get $r
      #|    local.get $n
      #|    table.grow 0
      #|    i32.const 1
      #|    select
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps values flowing into table grow select guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    ref.null func
      #|    global.get $guard
      #|    table.grow 0
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes independent memory compare read-only-to-write guards" {
  let size_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    memory.size
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(size_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let size_pretty = size_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(size_pretty.contains("memory.size"), msg=size_pretty)
  assert_false(size_pretty.contains("if"), msg=size_pretty)
  assert_false(size_pretty.contains("global.get"), msg=size_pretty)
  assert_false(size_pretty.contains("global.set"), msg=size_pretty)

  let grow_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i32.const 0
      #|    memory.grow
      #|    i32.ne
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(grow_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let grow_pretty = grow_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(grow_pretty.contains("memory.grow"), msg=grow_pretty)
  assert_true(grow_pretty.contains("drop"), msg=grow_pretty)
  assert_false(grow_pretty.contains("if"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.get"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.set"), msg=grow_pretty)

  let reverse_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    memory.size
      #|    global.get $guard
      #|    i32.ne
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_false(reverse_pretty.contains("memory.size"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)

  let grow_reverse_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    memory.grow
      #|    global.get $guard
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(grow_reverse_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let grow_reverse_pretty = grow_reverse_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(
    grow_reverse_pretty.contains("memory.grow"),
    msg=grow_reverse_pretty,
  )
  assert_true(grow_reverse_pretty.contains("drop"), msg=grow_reverse_pretty)
  assert_false(grow_reverse_pretty.contains("if"), msg=grow_reverse_pretty)
  assert_false(
    grow_reverse_pretty.contains("global.get"),
    msg=grow_reverse_pretty,
  )
  assert_false(
    grow_reverse_pretty.contains("global.set"),
    msg=grow_reverse_pretty,
  )
}

///|
test "simplify-globals-optimizing removes independent memory compare if-return guards" {
  let grow_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i32.const 0
      #|    memory.grow
      #|    i32.ne
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(grow_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let grow_pretty = grow_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(grow_pretty.contains("memory.grow"), msg=grow_pretty)
  assert_true(grow_pretty.contains("drop"), msg=grow_pretty)
  assert_false(grow_pretty.contains("if"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.get"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.set"), msg=grow_pretty)

  let reverse_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    memory.size
      #|    global.get $guard
      #|    i32.eq
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_false(reverse_pretty.contains("memory.size"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)

  let grow_reverse_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    memory.grow
      #|    global.get $guard
      #|    i32.ne
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(grow_reverse_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let grow_reverse_pretty = grow_reverse_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(
    grow_reverse_pretty.contains("memory.grow"),
    msg=grow_reverse_pretty,
  )
  assert_true(grow_reverse_pretty.contains("drop"), msg=grow_reverse_pretty)
  assert_false(grow_reverse_pretty.contains("if"), msg=grow_reverse_pretty)
  assert_false(
    grow_reverse_pretty.contains("global.get"),
    msg=grow_reverse_pretty,
  )
  assert_false(
    grow_reverse_pretty.contains("global.set"),
    msg=grow_reverse_pretty,
  )
}

///|
test "simplify-globals-optimizing removes local-fed memory grow compare read-only-to-write guards" {
  let direct_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $n i32)
      #|    global.get $guard
      #|    local.get $n
      #|    memory.grow
      #|    i32.ne
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(direct_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let direct_pretty = direct_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(direct_pretty.contains("memory.grow"), msg=direct_pretty)
  assert_true(direct_pretty.contains("drop"), msg=direct_pretty)
  assert_true(direct_pretty.contains("local.get"), msg=direct_pretty)
  assert_false(direct_pretty.contains("if"), msg=direct_pretty)
  assert_false(direct_pretty.contains("global.get"), msg=direct_pretty)
  assert_false(direct_pretty.contains("global.set"), msg=direct_pretty)

  let reverse_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $n i32)
      #|    local.get $n
      #|    memory.grow
      #|    global.get $guard
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(reverse_pretty.contains("memory.grow"), msg=reverse_pretty)
  assert_true(reverse_pretty.contains("drop"), msg=reverse_pretty)
  assert_true(reverse_pretty.contains("local.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)
}

///|
test "simplify-globals-optimizing removes local-fed memory grow compare if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $n i32)
      #|    global.get $guard
      #|    local.get $n
      #|    memory.grow
      #|    i32.ne
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps values flowing into memory grow compare guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    memory.grow
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes select second operand read with independent call" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $foo
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes select operand read with independent memory ops" {
  let size_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    memory.size
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(size_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let size_pretty = size_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(size_pretty.contains("memory.size"), msg=size_pretty)
  assert_false(size_pretty.contains("select"), msg=size_pretty)
  assert_false(size_pretty.contains("global.get"), msg=size_pretty)
  assert_false(size_pretty.contains("global.set"), msg=size_pretty)

  let grow_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i32.const 0
      #|    memory.grow
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(grow_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let grow_pretty = grow_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(grow_pretty.contains("memory.grow"), msg=grow_pretty)
  assert_true(grow_pretty.contains("drop"), msg=grow_pretty)
  assert_false(grow_pretty.contains("select"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.get"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.set"), msg=grow_pretty)
}

///|
test "simplify-globals-optimizing removes select second operand read with independent memory ops" {
  let size_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    memory.size
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(size_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let size_pretty = size_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(size_pretty.contains("memory.size"), msg=size_pretty)
  assert_false(size_pretty.contains("select"), msg=size_pretty)
  assert_false(size_pretty.contains("global.get"), msg=size_pretty)
  assert_false(size_pretty.contains("global.set"), msg=size_pretty)

  let grow_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    memory.grow
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(grow_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let grow_pretty = grow_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(grow_pretty.contains("memory.grow"), msg=grow_pretty)
  assert_true(grow_pretty.contains("drop"), msg=grow_pretty)
  assert_false(grow_pretty.contains("select"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.get"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.set"), msg=grow_pretty)
}

///|
test "simplify-globals-optimizing removes select operand if-return read with independent memory ops" {
  let size_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    memory.size
      #|    i32.const 1
      #|    select
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(size_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let size_pretty = size_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(size_pretty.contains("memory.size"), msg=size_pretty)
  assert_false(size_pretty.contains("select"), msg=size_pretty)
  assert_false(size_pretty.contains("if"), msg=size_pretty)
  assert_false(size_pretty.contains("global.get"), msg=size_pretty)
  assert_false(size_pretty.contains("global.set"), msg=size_pretty)

  let grow_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i32.const 0
      #|    memory.grow
      #|    i32.const 1
      #|    select
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(grow_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let grow_pretty = grow_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(grow_pretty.contains("memory.grow"), msg=grow_pretty)
  assert_true(grow_pretty.contains("drop"), msg=grow_pretty)
  assert_false(grow_pretty.contains("select"), msg=grow_pretty)
  assert_false(grow_pretty.contains("if"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.get"), msg=grow_pretty)
  assert_false(grow_pretty.contains("global.set"), msg=grow_pretty)

  let size_second_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    memory.size
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(size_second_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let size_second_pretty = size_second_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_false(
    size_second_pretty.contains("memory.size"),
    msg=size_second_pretty,
  )
  assert_false(size_second_pretty.contains("select"), msg=size_second_pretty)
  assert_false(size_second_pretty.contains("if"), msg=size_second_pretty)
  assert_false(
    size_second_pretty.contains("global.get"),
    msg=size_second_pretty,
  )
  assert_false(
    size_second_pretty.contains("global.set"),
    msg=size_second_pretty,
  )

  let grow_second_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    memory.grow
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(grow_second_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let grow_second_pretty = grow_second_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(
    grow_second_pretty.contains("memory.grow"),
    msg=grow_second_pretty,
  )
  assert_true(grow_second_pretty.contains("drop"), msg=grow_second_pretty)
  assert_false(grow_second_pretty.contains("select"), msg=grow_second_pretty)
  assert_false(grow_second_pretty.contains("if"), msg=grow_second_pretty)
  assert_false(
    grow_second_pretty.contains("global.get"),
    msg=grow_second_pretty,
  )
  assert_false(
    grow_second_pretty.contains("global.set"),
    msg=grow_second_pretty,
  )
}

///|
test "simplify-globals-optimizing removes local-fed memory grow select guards" {
  let direct_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $n i32)
      #|    global.get $guard
      #|    local.get $n
      #|    memory.grow
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(direct_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let direct_pretty = direct_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(direct_pretty.contains("memory.grow"), msg=direct_pretty)
  assert_true(direct_pretty.contains("drop"), msg=direct_pretty)
  assert_true(direct_pretty.contains("local.get"), msg=direct_pretty)
  assert_false(direct_pretty.contains("select"), msg=direct_pretty)
  assert_false(direct_pretty.contains("if"), msg=direct_pretty)
  assert_false(direct_pretty.contains("global.get"), msg=direct_pretty)
  assert_false(direct_pretty.contains("global.set"), msg=direct_pretty)

  let second_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $n i32)
      #|    local.get $n
      #|    memory.grow
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(second_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let second_pretty = second_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(second_pretty.contains("memory.grow"), msg=second_pretty)
  assert_true(second_pretty.contains("drop"), msg=second_pretty)
  assert_true(second_pretty.contains("local.get"), msg=second_pretty)
  assert_false(second_pretty.contains("select"), msg=second_pretty)
  assert_false(second_pretty.contains("if"), msg=second_pretty)
  assert_false(second_pretty.contains("global.get"), msg=second_pretty)
  assert_false(second_pretty.contains("global.set"), msg=second_pretty)
}

///|
test "simplify-globals-optimizing removes local-fed memory grow select if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $n i32)
      #|    global.get $guard
      #|    local.get $n
      #|    memory.grow
      #|    i32.const 1
      #|    select
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_false(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes reverse local-fed memory and table select if-return guards" {
  let memsize_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    memory.size
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(memsize_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let memsize_pretty = memsize_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_false(memsize_pretty.contains("select"), msg=memsize_pretty)
  assert_false(memsize_pretty.contains("if"), msg=memsize_pretty)
  assert_false(memsize_pretty.contains("global.get"), msg=memsize_pretty)
  assert_false(memsize_pretty.contains("global.set"), msg=memsize_pretty)

  let memgrow_optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $n i32)
      #|    local.get $n
      #|    memory.grow
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(memgrow_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let memgrow_pretty = memgrow_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(memgrow_pretty.contains("local.get"), msg=memgrow_pretty)
  assert_true(memgrow_pretty.contains("memory.grow"), msg=memgrow_pretty)
  assert_true(memgrow_pretty.contains("drop"), msg=memgrow_pretty)
  assert_false(memgrow_pretty.contains("select"), msg=memgrow_pretty)
  assert_false(memgrow_pretty.contains("if"), msg=memgrow_pretty)
  assert_false(memgrow_pretty.contains("global.get"), msg=memgrow_pretty)
  assert_false(memgrow_pretty.contains("global.set"), msg=memgrow_pretty)

  let tablesize_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    table.size 0
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(tablesize_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let tablesize_pretty = tablesize_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_false(tablesize_pretty.contains("select"), msg=tablesize_pretty)
  assert_false(tablesize_pretty.contains("if"), msg=tablesize_pretty)
  assert_false(tablesize_pretty.contains("global.get"), msg=tablesize_pretty)
  assert_false(tablesize_pretty.contains("global.set"), msg=tablesize_pretty)

  let tablegrow_optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $r funcref) (param $n i32)
      #|    local.get $r
      #|    local.get $n
      #|    table.grow 0
      #|    global.get $guard
      #|    i32.const 1
      #|    select
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(tablegrow_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let tablegrow_pretty = tablegrow_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(tablegrow_pretty.contains("local.get"), msg=tablegrow_pretty)
  assert_true(tablegrow_pretty.contains("table.grow"), msg=tablegrow_pretty)
  assert_true(tablegrow_pretty.contains("drop"), msg=tablegrow_pretty)
  assert_false(tablegrow_pretty.contains("select"), msg=tablegrow_pretty)
  assert_false(tablegrow_pretty.contains("if"), msg=tablegrow_pretty)
  assert_false(tablegrow_pretty.contains("global.get"), msg=tablegrow_pretty)
  assert_false(tablegrow_pretty.contains("global.set"), msg=tablegrow_pretty)
}

///|
test "simplify-globals-optimizing keeps select operand values flowing into memory.grow" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    memory.grow
      #|    i32.const 0
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
fn sgo_assert_independent_call_binary_removed(mod_ : @lib.Module) -> Unit raise {
  @debug.assert_eq(
    try! sgo_test_defined_global_type(mod_, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = mod_.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
fn sgo_assert_independent_i64_call_binary_removed(
  mod_ : @lib.Module,
) -> Unit raise {
  @debug.assert_eq(
    try! sgo_test_defined_global_type(mod_, 0),
    @lib.GlobalType::new(@lib.ValType::i64(), false),
  )
  let pretty = mod_.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes independent call nontrapping i32 binary guards" {
  let mul_direct_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    i32.mul
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  try! sgo_assert_independent_call_binary_removed(mul_direct_optimized)
  let mul_direct_pretty = mul_direct_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_false(mul_direct_pretty.contains("i32.mul"), msg=mul_direct_pretty)

  let and_reverse_if_return_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $imp
      #|    global.get $guard
      #|    i32.and
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )
  try! sgo_assert_independent_call_binary_removed(
    and_reverse_if_return_optimized,
  )
  let and_reverse_if_return_pretty = and_reverse_if_return_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_false(
    and_reverse_if_return_pretty.contains("i32.and"),
    msg=and_reverse_if_return_pretty,
  )

  let rotl_direct_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    i32.rotl
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  try! sgo_assert_independent_call_binary_removed(rotl_direct_optimized)
  let rotl_direct_pretty = rotl_direct_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_false(rotl_direct_pretty.contains("i32.rotl"), msg=rotl_direct_pretty)

  let div_trap_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    i32.div_s
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(div_trap_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let div_trap_pretty = div_trap_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(div_trap_pretty.contains("global.get"), msg=div_trap_pretty)
  assert_true(div_trap_pretty.contains("global.set"), msg=div_trap_pretty)
}

///|
test "simplify-globals-optimizing removes independent call binary pure suffix guards" {
  let eqz_direct_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    i32.mul
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  try! sgo_assert_independent_call_binary_removed(eqz_direct_optimized)
  let eqz_direct_pretty = eqz_direct_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_false(eqz_direct_pretty.contains("i32.eqz"), msg=eqz_direct_pretty)
  assert_false(eqz_direct_pretty.contains("i32.mul"), msg=eqz_direct_pretty)

  let reverse_if_return_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $imp
      #|    global.get $guard
      #|    i32.xor
      #|    i32.eqz
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )
  try! sgo_assert_independent_call_binary_removed(reverse_if_return_optimized)
  let reverse_if_return_pretty = reverse_if_return_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_false(
    reverse_if_return_pretty.contains("i32.xor"),
    msg=reverse_if_return_pretty,
  )
  assert_false(
    reverse_if_return_pretty.contains("i32.eqz"),
    msg=reverse_if_return_pretty,
  )

  let clz_direct_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    i32.mul
      #|    i32.clz
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  try! sgo_assert_independent_call_binary_removed(clz_direct_optimized)
  let clz_direct_pretty = clz_direct_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_false(clz_direct_pretty.contains("i32.clz"), msg=clz_direct_pretty)
  assert_false(clz_direct_pretty.contains("i32.mul"), msg=clz_direct_pretty)

  let ctz_reverse_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $imp
      #|    global.get $guard
      #|    i32.mul
      #|    i32.ctz
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  try! sgo_assert_independent_call_binary_removed(ctz_reverse_optimized)
  let ctz_reverse_pretty = ctz_reverse_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_false(ctz_reverse_pretty.contains("i32.ctz"), msg=ctz_reverse_pretty)
  assert_false(ctz_reverse_pretty.contains("i32.mul"), msg=ctz_reverse_pretty)

  let popcnt_if_return_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $imp
      #|    global.get $guard
      #|    i32.xor
      #|    i32.popcnt
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )
  try! sgo_assert_independent_call_binary_removed(popcnt_if_return_optimized)
  let popcnt_if_return_pretty = popcnt_if_return_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_false(
    popcnt_if_return_pretty.contains("i32.popcnt"),
    msg=popcnt_if_return_pretty,
  )
  assert_false(
    popcnt_if_return_pretty.contains("i32.xor"),
    msg=popcnt_if_return_pretty,
  )

  let compare_const_direct_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    i32.mul
      #|    i32.const 0
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  try! sgo_assert_independent_call_binary_removed(
    compare_const_direct_optimized,
  )
  let compare_const_direct_pretty = compare_const_direct_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_false(
    compare_const_direct_pretty.contains("i32.eq"),
    msg=compare_const_direct_pretty,
  )
  assert_false(
    compare_const_direct_pretty.contains("i32.mul"),
    msg=compare_const_direct_pretty,
  )

  let compare_const_first_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    call $imp
      #|    global.get $guard
      #|    i32.mul
      #|    i32.ne
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  try! sgo_assert_independent_call_binary_removed(compare_const_first_optimized)
  let compare_const_first_pretty = compare_const_first_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_false(
    compare_const_first_pretty.contains("i32.ne"),
    msg=compare_const_first_pretty,
  )
  assert_false(
    compare_const_first_pretty.contains("i32.mul"),
    msg=compare_const_first_pretty,
  )

  let compare_const_if_return_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $imp
      #|    global.get $guard
      #|    i32.xor
      #|    i32.const 1
      #|    i32.eq
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )
  try! sgo_assert_independent_call_binary_removed(
    compare_const_if_return_optimized,
  )
  let compare_const_if_return_pretty = compare_const_if_return_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_false(
    compare_const_if_return_pretty.contains("i32.eq"),
    msg=compare_const_if_return_pretty,
  )
  assert_false(
    compare_const_if_return_pretty.contains("i32.xor"),
    msg=compare_const_if_return_pretty,
  )

  let div_compare_const_trap_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    i32.div_s
      #|    i32.const 0
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(div_compare_const_trap_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let div_compare_const_trap_pretty = div_compare_const_trap_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(
    div_compare_const_trap_pretty.contains("global.get"),
    msg=div_compare_const_trap_pretty,
  )
  assert_true(
    div_compare_const_trap_pretty.contains("global.set"),
    msg=div_compare_const_trap_pretty,
  )

  let div_trap_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    i32.div_s
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(div_trap_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let div_trap_pretty = div_trap_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(div_trap_pretty.contains("global.get"), msg=div_trap_pretty)
  assert_true(div_trap_pretty.contains("global.set"), msg=div_trap_pretty)

  let div_clz_trap_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    i32.div_s
      #|    i32.clz
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(div_clz_trap_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let div_clz_trap_pretty = div_clz_trap_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(
    div_clz_trap_pretty.contains("global.get"),
    msg=div_clz_trap_pretty,
  )
  assert_true(
    div_clz_trap_pretty.contains("global.set"),
    msg=div_clz_trap_pretty,
  )
}

///|
test "simplify-globals-optimizing removes independent i64 call binary suffix guards" {
  let eqz_direct_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i64)))
      #|  (global $guard (mut i64) (i64.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    i64.add
      #|    i64.eqz
      #|    if
      #|      i64.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  try! sgo_assert_independent_i64_call_binary_removed(eqz_direct_optimized)
  let eqz_direct_pretty = eqz_direct_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_false(eqz_direct_pretty.contains("i64.add"), msg=eqz_direct_pretty)
  assert_false(eqz_direct_pretty.contains("i64.eqz"), msg=eqz_direct_pretty)

  let compare_const_first_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i64)))
      #|  (global $guard (mut i64) (i64.const 0))
      #|  (func (export "run")
      #|    i64.const 0
      #|    call $imp
      #|    global.get $guard
      #|    i64.mul
      #|    i64.eq
      #|    if
      #|      i64.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  try! sgo_assert_independent_i64_call_binary_removed(
    compare_const_first_optimized,
  )
  let compare_const_first_pretty = compare_const_first_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_false(
    compare_const_first_pretty.contains("i64.mul"),
    msg=compare_const_first_pretty,
  )
  assert_false(
    compare_const_first_pretty.contains("i64.eq"),
    msg=compare_const_first_pretty,
  )

  let eqz_if_return_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i64)))
      #|  (global $guard (mut i64) (i64.const 0))
      #|  (func (export "run")
      #|    call $imp
      #|    global.get $guard
      #|    i64.xor
      #|    i64.eqz
      #|    if
      #|      return
      #|    end
      #|    i64.const 1
      #|    global.set $guard))
      #|,
    ),
  )
  try! sgo_assert_independent_i64_call_binary_removed(eqz_if_return_optimized)
  let eqz_if_return_pretty = eqz_if_return_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_false(
    eqz_if_return_pretty.contains("i64.xor"),
    msg=eqz_if_return_pretty,
  )
  assert_false(
    eqz_if_return_pretty.contains("i64.eqz"),
    msg=eqz_if_return_pretty,
  )

  let div_trap_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i64)))
      #|  (global $guard (mut i64) (i64.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    i64.div_s
      #|    i64.eqz
      #|    if
      #|      i64.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(div_trap_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i64(), true),
  )
  let div_trap_pretty = div_trap_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(div_trap_pretty.contains("global.get"), msg=div_trap_pretty)
  assert_true(div_trap_pretty.contains("global.set"), msg=div_trap_pretty)
}

///|
test "simplify-globals-optimizing removes independent float call binary comparison guards" {
  let f32_direct_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result f32)))
      #|  (global $guard (mut f32) (f32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    f32.add
      #|    f32.const 0
      #|    f32.lt
      #|    if
      #|      f32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(f32_direct_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  let f32_direct_pretty = f32_direct_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(f32_direct_pretty.contains("call"), msg=f32_direct_pretty)
  assert_true(f32_direct_pretty.contains("drop"), msg=f32_direct_pretty)
  assert_false(f32_direct_pretty.contains("f32.add"), msg=f32_direct_pretty)
  assert_false(f32_direct_pretty.contains("f32.lt"), msg=f32_direct_pretty)
  assert_false(f32_direct_pretty.contains("if"), msg=f32_direct_pretty)
  assert_false(f32_direct_pretty.contains("global.get"), msg=f32_direct_pretty)
  assert_false(f32_direct_pretty.contains("global.set"), msg=f32_direct_pretty)

  let f64_const_first_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result f64)))
      #|  (global $guard (mut f64) (f64.const 0))
      #|  (func (export "run")
      #|    f64.const 0
      #|    call $imp
      #|    global.get $guard
      #|    f64.mul
      #|    f64.ne
      #|    if
      #|      f64.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(f64_const_first_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::f64(), false),
  )
  let f64_const_first_pretty = f64_const_first_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(
    f64_const_first_pretty.contains("call"),
    msg=f64_const_first_pretty,
  )
  assert_true(
    f64_const_first_pretty.contains("drop"),
    msg=f64_const_first_pretty,
  )
  assert_false(
    f64_const_first_pretty.contains("f64.mul"),
    msg=f64_const_first_pretty,
  )
  assert_false(
    f64_const_first_pretty.contains("f64.ne"),
    msg=f64_const_first_pretty,
  )
  assert_false(
    f64_const_first_pretty.contains("if"),
    msg=f64_const_first_pretty,
  )
  assert_false(
    f64_const_first_pretty.contains("global.get"),
    msg=f64_const_first_pretty,
  )
  assert_false(
    f64_const_first_pretty.contains("global.set"),
    msg=f64_const_first_pretty,
  )

  let f32_if_return_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result f32)))
      #|  (global $guard (mut f32) (f32.const 0))
      #|  (func (export "run")
      #|    f32.const 0
      #|    call $imp
      #|    global.get $guard
      #|    f32.div
      #|    f32.ge
      #|    if
      #|      return
      #|    end
      #|    f32.const 1
      #|    global.set $guard))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(f32_if_return_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  let f32_if_return_pretty = f32_if_return_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(f32_if_return_pretty.contains("call"), msg=f32_if_return_pretty)
  assert_true(f32_if_return_pretty.contains("drop"), msg=f32_if_return_pretty)
  assert_false(
    f32_if_return_pretty.contains("f32.div"),
    msg=f32_if_return_pretty,
  )
  assert_false(
    f32_if_return_pretty.contains("f32.ge"),
    msg=f32_if_return_pretty,
  )
  assert_false(f32_if_return_pretty.contains("if"), msg=f32_if_return_pretty)
  assert_false(
    f32_if_return_pretty.contains("global.get"),
    msg=f32_if_return_pretty,
  )
  assert_false(
    f32_if_return_pretty.contains("global.set"),
    msg=f32_if_return_pretty,
  )

  let f32_nan_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result f32)))
      #|  (global $guard (mut f32) (f32.const nan))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    f32.min
      #|    f32.const nan
      #|    f32.eq
      #|    if
      #|      f32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(f32_nan_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  let f32_nan_pretty = f32_nan_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(f32_nan_pretty.contains("call"), msg=f32_nan_pretty)
  assert_true(f32_nan_pretty.contains("drop"), msg=f32_nan_pretty)
  assert_false(f32_nan_pretty.contains("f32.min"), msg=f32_nan_pretty)
  assert_false(f32_nan_pretty.contains("f32.eq"), msg=f32_nan_pretty)

  let f64_result_first_reverse_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result f64)))
      #|  (global $guard (mut f64) (f64.const 0))
      #|  (func (export "run")
      #|    call $imp
      #|    global.get $guard
      #|    f64.copysign
      #|    f64.const 0
      #|    f64.le
      #|    if
      #|      f64.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(f64_result_first_reverse_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::f64(), false),
  )
  let f64_result_first_reverse_pretty = f64_result_first_reverse_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(
    f64_result_first_reverse_pretty.contains("call"),
    msg=f64_result_first_reverse_pretty,
  )
  assert_true(
    f64_result_first_reverse_pretty.contains("drop"),
    msg=f64_result_first_reverse_pretty,
  )
  assert_false(
    f64_result_first_reverse_pretty.contains("f64.copysign"),
    msg=f64_result_first_reverse_pretty,
  )
  assert_false(
    f64_result_first_reverse_pretty.contains("f64.le"),
    msg=f64_result_first_reverse_pretty,
  )

  let f64_const_first_direct_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result f64)))
      #|  (global $guard (mut f64) (f64.const 0))
      #|  (func (export "run")
      #|    f64.const 0
      #|    global.get $guard
      #|    call $imp
      #|    f64.add
      #|    f64.gt
      #|    if
      #|      f64.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(f64_const_first_direct_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::f64(), false),
  )
  let f64_const_first_direct_pretty = f64_const_first_direct_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(
    f64_const_first_direct_pretty.contains("call"),
    msg=f64_const_first_direct_pretty,
  )
  assert_true(
    f64_const_first_direct_pretty.contains("drop"),
    msg=f64_const_first_direct_pretty,
  )
  assert_false(
    f64_const_first_direct_pretty.contains("f64.add"),
    msg=f64_const_first_direct_pretty,
  )
  assert_false(
    f64_const_first_direct_pretty.contains("f64.gt"),
    msg=f64_const_first_direct_pretty,
  )

  let flow_into_call_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (param f32) (result f32)))
      #|  (global $guard (mut f32) (f32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    f32.const 0
      #|    f32.lt
      #|    if
      #|      f32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(flow_into_call_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::f32(), true),
  )

  let extra_read_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result f64)))
      #|  (global $guard (mut f64) (f64.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    f64.mul
      #|    global.get $guard
      #|    f64.ne
      #|    if
      #|      f64.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(extra_read_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::f64(), true),
  )
}

///|
test "simplify-globals-optimizing removes independent call add guards" {
  let direct_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    i32.add
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(direct_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let direct_pretty = direct_optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(direct_pretty.contains("call"), msg=direct_pretty)
  assert_true(direct_pretty.contains("drop"), msg=direct_pretty)
  assert_false(direct_pretty.contains("i32.add"), msg=direct_pretty)
  assert_false(direct_pretty.contains("if"), msg=direct_pretty)
  assert_false(direct_pretty.contains("global.get"), msg=direct_pretty)
  assert_false(direct_pretty.contains("global.set"), msg=direct_pretty)

  let if_return_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    i32.add
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(if_return_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let if_return_pretty = if_return_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(if_return_pretty.contains("call"), msg=if_return_pretty)
  assert_true(if_return_pretty.contains("drop"), msg=if_return_pretty)
  assert_false(if_return_pretty.contains("i32.add"), msg=if_return_pretty)
  assert_false(if_return_pretty.contains("if"), msg=if_return_pretty)
  assert_false(if_return_pretty.contains("global.get"), msg=if_return_pretty)
  assert_false(if_return_pretty.contains("global.set"), msg=if_return_pretty)

  let reverse_direct_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $imp
      #|    global.get $guard
      #|    i32.add
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse_direct_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_direct_pretty = reverse_direct_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(reverse_direct_pretty.contains("call"), msg=reverse_direct_pretty)
  assert_true(reverse_direct_pretty.contains("drop"), msg=reverse_direct_pretty)
  assert_false(
    reverse_direct_pretty.contains("i32.add"),
    msg=reverse_direct_pretty,
  )
  assert_false(reverse_direct_pretty.contains("if"), msg=reverse_direct_pretty)
  assert_false(
    reverse_direct_pretty.contains("global.get"),
    msg=reverse_direct_pretty,
  )
  assert_false(
    reverse_direct_pretty.contains("global.set"),
    msg=reverse_direct_pretty,
  )

  let reverse_if_return_optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $imp
      #|    global.get $guard
      #|    i32.add
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse_if_return_optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_if_return_pretty = reverse_if_return_optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(
    reverse_if_return_pretty.contains("call"),
    msg=reverse_if_return_pretty,
  )
  assert_true(
    reverse_if_return_pretty.contains("drop"),
    msg=reverse_if_return_pretty,
  )
  assert_false(
    reverse_if_return_pretty.contains("i32.add"),
    msg=reverse_if_return_pretty,
  )
  assert_false(
    reverse_if_return_pretty.contains("if"),
    msg=reverse_if_return_pretty,
  )
  assert_false(
    reverse_if_return_pretty.contains("global.get"),
    msg=reverse_if_return_pretty,
  )
  assert_false(
    reverse_if_return_pretty.contains("global.set"),
    msg=reverse_if_return_pretty,
  )
}

///|
test "simplify-globals-optimizing keeps select operand values flowing into calls" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "sink" (func $sink (param i32) (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $sink
      #|    i32.const 1
      #|    i32.const 1
      #|    select
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps self guards through trapping memory loads" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $addr (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $addr
      #|    i32.load
      #|    if
      #|      i32.const 4
      #|      global.set $addr
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes read-only-to-write self guards through transparent blocks" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $once
      #|    if
      #|      block
      #|        nop
      #|        i32.const 1
      #|        global.set $once
      #|      end
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes self guards with no-op const drops before the write" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $once
      #|    if
      #|      i32.const 2
      #|      drop
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block-wrapped read-only-to-write self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      global.get $once
      #|    end
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block-wrapped eqz read-only-to-write self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      global.get $once
      #|      i32.eqz
      #|    end
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block-wrapped pure-condition read-only-to-write self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $i32 (mut i32) (i32.const 0))
      #|  (global $i64 (mut i64) (i64.const 0))
      #|  (func $i32_run
      #|    block (result i32)
      #|      global.get $i32
      #|      i32.const 1
      #|      i32.add
      #|      i32.const 2
      #|      i32.lt_s
      #|    end
      #|    if
      #|      i32.const 1
      #|      global.set $i32
      #|    end)
      #|  (func $i64_run
      #|    block (result i32)
      #|      global.get $i64
      #|      i64.const 1
      #|      i64.add
      #|      i64.eqz
      #|    end
      #|    if
      #|      i64.const 1
      #|      global.set $i64
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 2; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      match i {
        0 => @lib.GlobalType::new(@lib.ValType::i32(), false)
        _ => @lib.GlobalType::new(@lib.ValType::i64(), false)
      },
    )
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing removes block-wrapped self guards with no-op condition prefixes" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      i32.const 2
      #|      drop
      #|      global.get $once
      #|    end
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested read-only-to-write self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      global.get $once
      #|      i32.eqz
      #|      if
      #|        i32.const 1
      #|        global.set $once
      #|      end
      #|      global.get $once
      #|      i32.const 0
      #|      i32.eq
      #|    end
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes official multi-global nested read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $a (mut i32) (i32.const 0))
      #|  (global $b (mut i32) (i32.const 0))
      #|  (global $c (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $a
      #|    if
      #|      block
      #|        i32.const 1
      #|        global.set $a
      #|        global.get $b
      #|        if
      #|          block
      #|            global.get $c
      #|            if
      #|              block
      #|                i32.const 2
      #|                global.set $c
      #|              end
      #|            end
      #|            i32.const 3
      #|            global.set $b
      #|          end
      #|        end
      #|      end
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 3; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), false),
    )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps mutual nested read-only-to-write body guardrail" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $a (mut i32) (i32.const 0))
      #|  (global $b (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $a
      #|    if
      #|      block
      #|        i32.const 1
      #|        global.set $a
      #|        global.get $b
      #|        if
      #|          block
      #|            global.get $a
      #|            if
      #|              i32.const 2
      #|              global.set $a
      #|            end
      #|            i32.const 3
      #|            global.set $b
      #|          end
      #|        end
      #|      end
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes official nested-thrice read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1 1)
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      block (result i32)
      #|        global.get $once
      #|        if
      #|          i32.const 1
      #|          global.set $once
      #|        end
      #|        global.get $once
      #|      end
      #|      i32.eqz
      #|      if
      #|        i32.const 1
      #|        global.set $once
      #|      end
      #|      global.get $once
      #|      i32.const 0
      #|      i32.eq
      #|    end
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block-yielded self-guard condition operators" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $eqz (mut i32) (i32.const 0))
      #|  (global $forward (mut i32) (i32.const 0))
      #|  (global $reverse (mut i32) (i32.const 0))
      #|  (func $eqz_run
      #|    block (result i32)
      #|      global.get $eqz
      #|    end
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $eqz
      #|    end)
      #|  (func $forward_run
      #|    block (result i32)
      #|      global.get $forward
      #|    end
      #|    i32.const 0
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $forward
      #|    end)
      #|  (func $reverse_run
      #|    i32.const 0
      #|    block (result i32)
      #|      global.get $reverse
      #|    end
      #|    i32.ne
      #|    if
      #|      i32.const 1
      #|      global.set $reverse
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 3; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), false),
    )
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing removes block-yielded self-guard operators after pure block conditions" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $eqz (mut i32) (i32.const 0))
      #|  (global $forward (mut i32) (i32.const 0))
      #|  (global $reverse (mut i32) (i32.const 0))
      #|  (func $eqz_run
      #|    block (result i32)
      #|      global.get $eqz
      #|      i32.const 1
      #|      i32.add
      #|    end
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $eqz
      #|    end)
      #|  (func $forward_run
      #|    block (result i32)
      #|      global.get $forward
      #|      i32.const 1
      #|      i32.add
      #|    end
      #|    i32.const 2
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $forward
      #|    end)
      #|  (func $reverse_run
      #|    i32.const 2
      #|    block (result i32)
      #|      global.get $reverse
      #|      i32.const 1
      #|      i32.add
      #|    end
      #|    i32.ne
      #|    if
      #|      i32.const 1
      #|      global.set $reverse
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 3; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), false),
    )
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing removes block-yielded external pure-condition self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $i32 (mut i32) (i32.const 0))
      #|  (global $i64 (mut i64) (i64.const 0))
      #|  (func $i32_run
      #|    block (result i32)
      #|      global.get $i32
      #|    end
      #|    i32.const 1
      #|    i32.add
      #|    i32.const 2
      #|    i32.lt_s
      #|    if
      #|      i32.const 1
      #|      global.set $i32
      #|    end)
      #|  (func $i64_run
      #|    block (result i64)
      #|      global.get $i64
      #|    end
      #|    i64.const 1
      #|    i64.add
      #|    i64.eqz
      #|    if
      #|      i64.const 1
      #|      global.set $i64
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 2; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      match i {
        0 => @lib.GlobalType::new(@lib.ValType::i32(), false)
        _ => @lib.GlobalType::new(@lib.ValType::i64(), false)
      },
    )
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing removes block-yielded external short pure-condition self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $unary (mut i32) (i32.const 0))
      #|  (global $rel (mut i32) (i32.const 0))
      #|  (global $body_rel (mut i32) (i32.const 0))
      #|  (global $i64eqz (mut i64) (i64.const 0))
      #|  (func $unary_run
      #|    block (result i32)
      #|      global.get $unary
      #|    end
      #|    i32.clz
      #|    if
      #|      i32.const 1
      #|      global.set $unary
      #|    end)
      #|  (func $rel_run
      #|    block (result i32)
      #|      global.get $rel
      #|    end
      #|    i32.const 2
      #|    i32.lt_s
      #|    if
      #|      i32.const 1
      #|      global.set $rel
      #|    end)
      #|  (func $body_rel_run
      #|    block (result i32)
      #|      global.get $body_rel
      #|      i32.const 1
      #|      i32.add
      #|    end
      #|    i32.const 2
      #|    i32.lt_s
      #|    if
      #|      i32.const 1
      #|      global.set $body_rel
      #|    end)
      #|  (func $i64eqz_run
      #|    block (result i64)
      #|      global.get $i64eqz
      #|    end
      #|    i64.eqz
      #|    if
      #|      i64.const 1
      #|      global.set $i64eqz
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 4; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      match i {
        3 => @lib.GlobalType::new(@lib.ValType::i64(), false)
        _ => @lib.GlobalType::new(@lib.ValType::i32(), false)
      },
    )
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing removes block-yielded reverse external pure-condition self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $i32 (mut i32) (i32.const 0))
      #|  (global $i64 (mut i64) (i64.const 0))
      #|  (func $i32_run
      #|    i32.const 2
      #|    block (result i32)
      #|      global.get $i32
      #|    end
      #|    i32.lt_s
      #|    if
      #|      i32.const 1
      #|      global.set $i32
      #|    end)
      #|  (func $i64_run
      #|    i64.const 2
      #|    block (result i64)
      #|      global.get $i64
      #|    end
      #|    i64.eq
      #|    if
      #|      i64.const 1
      #|      global.set $i64
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 2; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      match i {
        0 => @lib.GlobalType::new(@lib.ValType::i32(), false)
        _ => @lib.GlobalType::new(@lib.ValType::i64(), false)
      },
    )
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing keeps unsupported block-yielded external pure-condition self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "next" (func $next (result i32)))
      #|  (import "env" "tick" (func $tick))
      #|  (global $wrong (mut i32) (i32.const 0))
      #|  (global $other (export "other") (mut i32) (i32.const 0))
      #|  (global $nonconst (mut i32) (i32.const 0))
      #|  (global $else (mut i32) (i32.const 0))
      #|  (global $trap (mut i32) (i32.const 0))
      #|  (global $stack (mut i32) (i32.const 0))
      #|  (func $wrong_target_run
      #|    call $next
      #|    global.set $wrong
      #|    block (result i32)
      #|      global.get $wrong
      #|    end
      #|    i32.const 1
      #|    i32.add
      #|    if
      #|      i32.const 1
      #|      global.set $other
      #|    end)
      #|  (func $nonconst_run
      #|    call $next
      #|    global.set $nonconst
      #|    block (result i32)
      #|      global.get $nonconst
      #|    end
      #|    i32.const 1
      #|    i32.add
      #|    if
      #|      call $next
      #|      global.set $nonconst
      #|    end)
      #|  (func $else_run
      #|    call $next
      #|    global.set $else
      #|    block (result i32)
      #|      global.get $else
      #|    end
      #|    i32.const 1
      #|    i32.add
      #|    if
      #|      i32.const 1
      #|      global.set $else
      #|    else
      #|      call $tick
      #|    end)
      #|  (func $trapping_run
      #|    call $next
      #|    global.set $trap
      #|    block (result i32)
      #|      global.get $trap
      #|    end
      #|    i32.const 1
      #|    i32.div_s
      #|    if
      #|      i32.const 1
      #|      global.set $trap
      #|    end)
      #|  (func $stack_depth_run
      #|    call $next
      #|    global.set $stack
      #|    block (result i32)
      #|      global.get $stack
      #|    end
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $stack
      #|    end
      #|    drop))
      #|,
    ),
  )

  for i in [0, 2, 3, 4, 5] {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), true),
    )
  }
  for i = 0; i < 5; i = i + 1 {
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_true(pretty.contains("global.get"), msg=pretty)
    assert_true(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing removes exact if-return read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block
      #|      global.get $once
      #|      if
      #|        return
      #|      end
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes eqz if-return read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block
      #|      global.get $once
      #|      i32.eqz
      #|      if
      #|        return
      #|      end
      #|      i32.const 1
      #|      global.set $once
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes compare if-return read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $forward (mut i32) (i32.const 0))
      #|  (global $reverse (mut i32) (i32.const 0))
      #|  (func $forward_run
      #|    global.get $forward
      #|    i32.const 0
      #|    i32.eq
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $forward)
      #|  (func $reverse_run
      #|    i32.const 0
      #|    global.get $reverse
      #|    i32.ne
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $reverse))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let forward = optimized.pretty_print_defined_func(0U)
  assert_false(forward.contains("global.get"), msg=forward)
  assert_false(forward.contains("global.set"), msg=forward)
  let reverse = optimized.pretty_print_defined_func(1U)
  assert_false(reverse.contains("global.get"), msg=reverse)
  assert_false(reverse.contains("global.set"), msg=reverse)
}

///|
test "simplify-globals-optimizing removes pure-condition if-return read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $i32 (mut i32) (i32.const 0))
      #|  (global $i64 (mut i64) (i64.const 0))
      #|  (func $i32_run
      #|    global.get $i32
      #|    i32.const 1
      #|    i32.add
      #|    i32.const 2
      #|    i32.lt_s
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $i32)
      #|  (func $i64_run
      #|    global.get $i64
      #|    i64.const 1
      #|    i64.add
      #|    i64.eqz
      #|    if
      #|      return
      #|    end
      #|    i64.const 1
      #|    global.set $i64))
      #|,
    ),
  )

  for i = 0; i < 2; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      match i {
        0 => @lib.GlobalType::new(@lib.ValType::i32(), false)
        _ => @lib.GlobalType::new(@lib.ValType::i64(), false)
      },
    )
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing keeps pure-condition if-return guards with trailing code" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $once
      #|    i32.const 1
      #|    i32.add
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $once
      #|    nop))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block-wrapped set if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $direct (mut i32) (i32.const 0))
      #|  (global $eqz (mut i32) (i32.const 0))
      #|  (global $compare (mut i32) (i32.const 0))
      #|  (func $direct_run
      #|    global.get $direct
      #|    if
      #|      return
      #|    end
      #|    block
      #|      i32.const 1
      #|      global.set $direct
      #|    end)
      #|  (func $eqz_run
      #|    global.get $eqz
      #|    i32.eqz
      #|    if
      #|      return
      #|    end
      #|    block
      #|      i32.const 2
      #|      drop
      #|      i32.const 1
      #|      global.set $eqz
      #|    end)
      #|  (func $compare_run
      #|    global.get $compare
      #|    i32.const 0
      #|    i32.eq
      #|    if
      #|      return
      #|    end
      #|    block
      #|      i32.const 1
      #|      global.set $compare
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 3; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), false),
    )
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing removes block-wrapped if-return read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $direct (mut i32) (i32.const 0))
      #|  (global $eqz (mut i32) (i32.const 0))
      #|  (global $compare (mut i32) (i32.const 0))
      #|  (func $direct_run
      #|    block (result i32)
      #|      global.get $direct
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $direct)
      #|  (func $eqz_run
      #|    block (result i32)
      #|      global.get $eqz
      #|      i32.eqz
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $eqz)
      #|  (func $compare_run
      #|    block (result i32)
      #|      global.get $compare
      #|      i32.const 0
      #|      i32.eq
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $compare))
      #|,
    ),
  )

  for i = 0; i < 3; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), false),
    )
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing removes block-wrapped pure-condition if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $i32 (mut i32) (i32.const 0))
      #|  (global $i64 (mut i64) (i64.const 0))
      #|  (func $i32_run
      #|    block (result i32)
      #|      global.get $i32
      #|      i32.const 1
      #|      i32.add
      #|      i32.const 2
      #|      i32.lt_s
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $i32)
      #|  (func $i64_run
      #|    block (result i32)
      #|      global.get $i64
      #|      i64.const 1
      #|      i64.add
      #|      i64.eqz
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i64.const 1
      #|    global.set $i64))
      #|,
    ),
  )

  for i = 0; i < 2; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      match i {
        0 => @lib.GlobalType::new(@lib.ValType::i32(), false)
        _ => @lib.GlobalType::new(@lib.ValType::i64(), false)
      },
    )
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing keeps block-wrapped pure-condition if-return guards with trailing code" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      global.get $once
      #|      i32.const 1
      #|      i32.add
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $once
      #|    nop))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested block-wrapped if-return conditions" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $direct (mut i32) (i32.const 0))
      #|  (global $eqz (mut i32) (i32.const 0))
      #|  (global $compare (mut i32) (i32.const 0))
      #|  (func $direct_run
      #|    block (result i32)
      #|      block (result i32)
      #|        global.get $direct
      #|      end
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $direct)
      #|  (func $eqz_run
      #|    block (result i32)
      #|      block (result i32)
      #|        global.get $eqz
      #|        i32.eqz
      #|      end
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $eqz)
      #|  (func $compare_run
      #|    block (result i32)
      #|      block (result i32)
      #|        global.get $compare
      #|        i32.const 0
      #|        i32.eq
      #|      end
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $compare))
      #|,
    ),
  )

  for i = 0; i < 3; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), false),
    )
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing removes block-wrapped condition and set if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $direct (mut i32) (i32.const 0))
      #|  (global $eqz (mut i32) (i32.const 0))
      #|  (global $compare (mut i32) (i32.const 0))
      #|  (func $direct_run
      #|    block (result i32)
      #|      global.get $direct
      #|    end
      #|    if
      #|      return
      #|    end
      #|    block
      #|      i32.const 1
      #|      global.set $direct
      #|    end)
      #|  (func $eqz_run
      #|    block (result i32)
      #|      global.get $eqz
      #|      i32.eqz
      #|    end
      #|    if
      #|      return
      #|    end
      #|    block
      #|      i32.const 1
      #|      global.set $eqz
      #|    end)
      #|  (func $compare_run
      #|    block (result i32)
      #|      global.get $compare
      #|      i32.const 0
      #|      i32.eq
      #|    end
      #|    if
      #|      return
      #|    end
      #|    block
      #|      i32.const 1
      #|      global.set $compare
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 3; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), false),
    )
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing removes block-yielded if-return condition operators" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $eqz (mut i32) (i32.const 0))
      #|  (global $forward (mut i32) (i32.const 0))
      #|  (global $reverse (mut i32) (i32.const 0))
      #|  (func $eqz_run
      #|    block (result i32)
      #|      global.get $eqz
      #|    end
      #|    i32.eqz
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $eqz)
      #|  (func $forward_run
      #|    block (result i32)
      #|      global.get $forward
      #|    end
      #|    i32.const 0
      #|    i32.eq
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $forward)
      #|  (func $reverse_run
      #|    i32.const 0
      #|    block (result i32)
      #|      global.get $reverse
      #|    end
      #|    i32.ne
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $reverse))
      #|,
    ),
  )

  for i = 0; i < 3; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), false),
    )
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing removes block-yielded if-return operators after pure block conditions" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $eqz (mut i32) (i32.const 0))
      #|  (global $forward (mut i32) (i32.const 0))
      #|  (global $reverse (mut i32) (i32.const 0))
      #|  (global $block_set (mut i32) (i32.const 0))
      #|  (func $eqz_run
      #|    block (result i32)
      #|      global.get $eqz
      #|      i32.const 1
      #|      i32.add
      #|    end
      #|    i32.eqz
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $eqz)
      #|  (func $forward_run
      #|    block (result i32)
      #|      global.get $forward
      #|      i32.const 1
      #|      i32.add
      #|    end
      #|    i32.const 2
      #|    i32.eq
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $forward)
      #|  (func $reverse_run
      #|    i32.const 2
      #|    block (result i32)
      #|      global.get $reverse
      #|      i32.const 1
      #|      i32.add
      #|    end
      #|    i32.ne
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $reverse)
      #|  (func $block_set_run
      #|    block (result i32)
      #|      global.get $block_set
      #|      i32.const 1
      #|      i32.add
      #|    end
      #|    i32.eqz
      #|    if
      #|      return
      #|    end
      #|    block
      #|      i32.const 1
      #|      global.set $block_set
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 4; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), false),
    )
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing removes block-yielded external pure-condition if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $i32 (mut i32) (i32.const 0))
      #|  (global $i64 (mut i64) (i64.const 0))
      #|  (global $block_set (mut i32) (i32.const 0))
      #|  (func $i32_run
      #|    block (result i32)
      #|      global.get $i32
      #|    end
      #|    i32.const 1
      #|    i32.add
      #|    i32.const 2
      #|    i32.lt_s
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $i32)
      #|  (func $i64_run
      #|    block (result i64)
      #|      global.get $i64
      #|    end
      #|    i64.const 1
      #|    i64.add
      #|    i64.eqz
      #|    if
      #|      return
      #|    end
      #|    i64.const 1
      #|    global.set $i64)
      #|  (func $block_set_run
      #|    block (result i32)
      #|      global.get $block_set
      #|    end
      #|    i32.const 1
      #|    i32.add
      #|    i32.const 2
      #|    i32.lt_s
      #|    if
      #|      return
      #|    end
      #|    block
      #|      i32.const 1
      #|      global.set $block_set
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 3; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      match i {
        1 => @lib.GlobalType::new(@lib.ValType::i64(), false)
        _ => @lib.GlobalType::new(@lib.ValType::i32(), false)
      },
    )
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing removes block-yielded external short pure-condition if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $unary (mut i32) (i32.const 0))
      #|  (global $rel (mut i32) (i32.const 0))
      #|  (global $body_rel (mut i32) (i32.const 0))
      #|  (global $i64eqz (mut i64) (i64.const 0))
      #|  (func $unary_run
      #|    block (result i32)
      #|      global.get $unary
      #|    end
      #|    i32.clz
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $unary)
      #|  (func $rel_run
      #|    block (result i32)
      #|      global.get $rel
      #|    end
      #|    i32.const 2
      #|    i32.lt_s
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $rel)
      #|  (func $body_rel_run
      #|    block (result i32)
      #|      global.get $body_rel
      #|      i32.const 1
      #|      i32.add
      #|    end
      #|    i32.const 2
      #|    i32.lt_s
      #|    if
      #|      return
      #|    end
      #|    block
      #|      i32.const 1
      #|      global.set $body_rel
      #|    end)
      #|  (func $i64eqz_run
      #|    block (result i64)
      #|      global.get $i64eqz
      #|    end
      #|    i64.eqz
      #|    if
      #|      return
      #|    end
      #|    i64.const 1
      #|    global.set $i64eqz))
      #|,
    ),
  )

  for i = 0; i < 4; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      match i {
        3 => @lib.GlobalType::new(@lib.ValType::i64(), false)
        _ => @lib.GlobalType::new(@lib.ValType::i32(), false)
      },
    )
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing removes block-yielded reverse external pure-condition if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $i32 (mut i32) (i32.const 0))
      #|  (global $i64 (mut i64) (i64.const 0))
      #|  (global $block_set (mut i32) (i32.const 0))
      #|  (func $i32_run
      #|    i32.const 2
      #|    block (result i32)
      #|      global.get $i32
      #|    end
      #|    i32.lt_s
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $i32)
      #|  (func $i64_run
      #|    i64.const 2
      #|    block (result i64)
      #|      global.get $i64
      #|    end
      #|    i64.eq
      #|    if
      #|      return
      #|    end
      #|    i64.const 1
      #|    global.set $i64)
      #|  (func $block_set_run
      #|    i32.const 2
      #|    block (result i32)
      #|      global.get $block_set
      #|      i32.const 1
      #|      i32.add
      #|    end
      #|    i32.lt_s
      #|    if
      #|      return
      #|    end
      #|    block
      #|      i32.const 1
      #|      global.set $block_set
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 3; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      match i {
        1 => @lib.GlobalType::new(@lib.ValType::i64(), false)
        _ => @lib.GlobalType::new(@lib.ValType::i32(), false)
      },
    )
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing keeps unsupported block-yielded external pure-condition if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "next" (func $next (result i32)))
      #|  (global $tail (mut i32) (i32.const 0))
      #|  (global $nonconst (mut i32) (i32.const 0))
      #|  (global $stack (mut i32) (i32.const 0))
      #|  (func $tail_run
      #|    block (result i32)
      #|      global.get $tail
      #|    end
      #|    i32.const 1
      #|    i32.add
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $tail
      #|    nop)
      #|  (func $nonconst_run
      #|    block (result i32)
      #|      global.get $nonconst
      #|    end
      #|    i32.const 1
      #|    i32.add
      #|    if
      #|      return
      #|    end
      #|    call $next
      #|    global.set $nonconst)
      #|  (func $stack_depth_run
      #|    block (result i32)
      #|      global.get $stack
      #|    end
      #|    i32.const 1
      #|    if
      #|      return
      #|    end
      #|    drop
      #|    i32.const 1
      #|    global.set $stack))
      #|,
    ),
  )

  for i = 0; i < 3; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), true),
    )
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_true(pretty.contains("global.get"), msg=pretty)
    assert_true(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing removes block-yielded condition operators with block-wrapped if-return sets" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $eqz (mut i32) (i32.const 0))
      #|  (global $forward (mut i32) (i32.const 0))
      #|  (global $reverse (mut i32) (i32.const 0))
      #|  (func $eqz_run
      #|    block (result i32)
      #|      global.get $eqz
      #|    end
      #|    i32.eqz
      #|    if
      #|      return
      #|    end
      #|    block
      #|      i32.const 1
      #|      global.set $eqz
      #|    end)
      #|  (func $forward_run
      #|    block (result i32)
      #|      global.get $forward
      #|    end
      #|    i32.const 0
      #|    i32.eq
      #|    if
      #|      return
      #|    end
      #|    block
      #|      i32.const 1
      #|      global.set $forward
      #|    end)
      #|  (func $reverse_run
      #|    i32.const 0
      #|    block (result i32)
      #|      global.get $reverse
      #|    end
      #|    i32.ne
      #|    if
      #|      return
      #|    end
      #|    block
      #|      i32.const 2
      #|      drop
      #|      i32.const 1
      #|      global.set $reverse
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 3; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), false),
    )
    let pretty = optimized.pretty_print_defined_func(i.reinterpret_as_uint())
    assert_false(pretty.contains("global.get"), msg=pretty)
    assert_false(pretty.contains("global.set"), msg=pretty)
  }
}

///|
test "simplify-globals-optimizing keeps if-return guards with trailing code" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block
      #|      global.get $once
      #|      if
      #|        return
      #|      end
      #|      i32.const 1
      #|      global.set $once
      #|      nop
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps self guards with extra reads" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $once
      #|    if
      #|      i32.const 1
      #|      global.set $once
      #|    end
      #|    global.get $once
      #|    drop))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing propagates private global values along a linear runtime trace" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32)
      #|    i32.const 5
      #|    global.set $g
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(5)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing stops runtime global propagation at calls" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func $bar)
      #|  (func (export "run") (result i32)
      #|    i32.const 5
      #|    global.set $g
      #|    call $bar
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing propagates private global values into adjacent runtime blocks" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32)
      #|    i32.const 10
      #|    global.set $g
      #|    block (result i32)
      #|      global.get $g
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(10)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps adjacent runtime block reads after calls" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "tick" (func $tick))
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32)
      #|    i32.const 10
      #|    global.set $g
      #|    call $tick
      #|    block (result i32)
      #|      global.get $g
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing carries private global values out of adjacent runtime blocks" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32)
      #|    block
      #|      i32.const 10
      #|      global.set $g
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(10)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing does not carry runtime block values through early exits" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32) (result i32)
      #|    block
      #|      local.get $p
      #|      br_if 0
      #|      i32.const 10
      #|      global.set $g
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing does not carry non-constant runtime block writes" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32) (result i32)
      #|    i32.const 7
      #|    global.set $g
      #|    block
      #|      local.get $p
      #|      global.set $g
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps block runtime facts private across calls" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "tick" (func $tick))
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32)
      #|    block
      #|      i32.const 10
      #|      global.set $g
      #|      call $tick
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps nested branch block runtime facts conservative" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32) (result i32)
      #|    block
      #|      block
      #|        local.get $p
      #|        br_if 0
      #|        i32.const 10
      #|        global.set $g
      #|      end
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing clears pre-block runtime facts across nested calls" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "tick" (func $tick))
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32)
      #|    i32.const 10
      #|    global.set $g
      #|    block
      #|      block
      #|        call $tick
      #|      end
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing clears pre-block runtime facts across nested branches" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32) (result i32)
      #|    i32.const 10
      #|    global.set $g
      #|    block
      #|      block
      #|        local.get $p
      #|        br_if 0
      #|      end
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing clears only same-global non-constant block writes" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (global $h (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32) (result i32)
      #|    i32.const 10
      #|    global.set $g
      #|    i32.const 20
      #|    global.set $h
      #|    block
      #|      local.get $p
      #|      global.set $g
      #|    end
      #|    global.get $g
      #|    global.get $h
      #|    i32.add))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get (Global 0)"), msg=pretty)
  assert_false(pretty.contains("global.get (Global 1)"), msg=pretty)
  assert_true(pretty.contains("I32(20)"), msg=pretty)
}

///|
test "simplify-globals-optimizing tracks exported global runtime block facts" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (export "g") (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32)
      #|    block
      #|      i32.const 10
      #|      global.set $g
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(10)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps if-contained block runtime facts conservative" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32) (result i32)
      #|    block
      #|      local.get $p
      #|      if
      #|        i32.const 10
      #|        global.set $g
      #|      end
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing carries runtime facts through nested plain blocks" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32)
      #|    block
      #|      block
      #|        i32.const 10
      #|        global.set $g
      #|      end
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(10)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing uses latest runtime block write facts" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32)
      #|    block
      #|      i32.const 1
      #|      global.set $g
      #|      i32.const 2
      #|      global.set $g
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(2)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps independent runtime block facts" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (global $h (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32)
      #|    i32.const 10
      #|    global.set $g
      #|    block
      #|      i32.const 20
      #|      global.set $h
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(10)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing preserves scalar facts across independent reference block writes" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "r" (global $r (mut externref)))
      #|  (global $i (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32)
      #|    i32.const 7
      #|    global.set $i
      #|    block
      #|      ref.null extern
      #|      global.set $r
      #|    end
      #|    global.get $i))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing preserves reference facts across independent scalar block writes" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "r" (global $r (mut funcref)))
      #|  (func $f)
      #|  (elem declare func $f)
      #|  (global $i (mut i32) (i32.const 0))
      #|  (func (export "run") (result funcref)
      #|    ref.func $f
      #|    global.set $r
      #|    block
      #|      i32.const 9
      #|      global.set $i
      #|    end
      #|    global.get $r))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("ref.func"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing preserves reference facts across independent scalar non-constant writes" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "r" (global $r (mut funcref)))
      #|  (func $f)
      #|  (elem declare func $f)
      #|  (global $i (mut i32) (i32.const 0))
      #|  (func (export "run") (param $x i32) (result funcref)
      #|    ref.func $f
      #|    global.set $r
      #|    local.get $x
      #|    global.set $i
      #|    global.get $r))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("ref.func"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing preserves scalar facts across independent reference non-constant writes" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "r" (global $r (mut externref)))
      #|  (global $i (mut i32) (i32.const 0))
      #|  (func (export "run") (param $x externref) (result i32)
      #|    i32.const 11
      #|    global.set $i
      #|    local.get $x
      #|    global.set $r
      #|    global.get $i))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("I32(11)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing tracks imported global runtime block facts" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "g" (global $g (mut i32)))
      #|  (func (export "run") (result i32)
      #|    block
      #|      i32.const 10
      #|      global.set $g
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(10)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing clears imported and exported runtime facts across calls" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (global $imp (mut i32)))
      #|  (global $exp (export "exp") (mut i32) (i32.const 0))
      #|  (func $unknown)
      #|  (func $read_import (export "read_import") (result i32)
      #|    i32.const 7
      #|    global.set $imp
      #|    call $unknown
      #|    global.get $imp)
      #|  (func $read_export (export "read_export") (result i32)
      #|    i32.const 8
      #|    global.set $exp
      #|    call $unknown
      #|    global.get $exp))
      #|,
    ),
  )

  let import_pretty = optimized.pretty_print_defined_func(1U)
  assert_true(import_pretty.contains("global.get"), msg=import_pretty)
  let export_pretty = optimized.pretty_print_defined_func(2U)
  assert_true(export_pretty.contains("global.get"), msg=export_pretty)
}

///|
test "simplify-globals-optimizing clears imported and exported runtime facts after non-constant writes" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (global $imp (mut i32)))
      #|  (global $exp (export "exp") (mut i32) (i32.const 0))
      #|  (func $read_import (export "read_import") (param $x i32) (result i32)
      #|    i32.const 7
      #|    global.set $imp
      #|    local.get $x
      #|    global.set $imp
      #|    global.get $imp)
      #|  (func $read_export (export "read_export") (param $x i32) (result i32)
      #|    i32.const 8
      #|    global.set $exp
      #|    local.get $x
      #|    global.set $exp
      #|    global.get $exp))
      #|,
    ),
  )

  let import_pretty = optimized.pretty_print_defined_func(0U)
  assert_true(import_pretty.contains("global.get"), msg=import_pretty)
  let export_pretty = optimized.pretty_print_defined_func(1U)
  assert_true(export_pretty.contains("global.get"), msg=export_pretty)
}

///|
test "simplify-globals-optimizing keeps independent imported and exported runtime facts" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (global $imp (mut i32)))
      #|  (global $exp (export "exp") (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32)
      #|    i32.const 11
      #|    global.set $imp
      #|    i32.const 12
      #|    global.set $exp
      #|    global.get $imp))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(11)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps imported and exported post-if runtime joins conservative" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (global $imp (mut i32)))
      #|  (global $exp (export "exp") (mut i32) (i32.const 0))
      #|  (func $read_import (export "read_import") (param $p i32) (result i32)
      #|    local.get $p
      #|    if
      #|      i32.const 13
      #|      global.set $imp
      #|    end
      #|    global.get $imp)
      #|  (func $read_export (export "read_export") (param $p i32) (result i32)
      #|    local.get $p
      #|    if
      #|      i32.const 14
      #|      global.set $exp
      #|    else
      #|      i32.const 14
      #|      global.set $exp
      #|    end
      #|    global.get $exp))
      #|,
    ),
  )

  let import_pretty = optimized.pretty_print_defined_func(0U)
  assert_true(import_pretty.contains("global.get"), msg=import_pretty)
  let export_pretty = optimized.pretty_print_defined_func(1U)
  assert_true(export_pretty.contains("global.get"), msg=export_pretty)
}

///|
test "simplify-globals-optimizing tracks imported ref-func runtime block facts" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "g" (global $g (mut funcref)))
      #|  (func $f)
      #|  (elem declare func $f)
      #|  (func (export "run") (result funcref)
      #|    ref.func $f
      #|    global.set $g
      #|    block (result funcref)
      #|      global.get $g
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("ref.func"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing propagates exported ref-func facts into then bodies" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (func $f)
      #|  (elem declare func $f)
      #|  (global $g (export "g") (mut funcref) (ref.null func))
      #|  (func (export "run") (param $p i32) (result funcref)
      #|    ref.func $f
      #|    global.set $g
      #|    local.get $p
      #|    if (result funcref)
      #|      global.get $g
      #|    else
      #|      ref.null func
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("ref.func"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing propagates imported externref null facts into then bodies" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "g" (global $g (mut externref)))
      #|  (func (export "run") (param $p i32) (result externref)
      #|    ref.null extern
      #|    global.set $g
      #|    local.get $p
      #|    if (result externref)
      #|      global.get $g
      #|    else
      #|      ref.null extern
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("ref.null"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps reference runtime facts behind barriers" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "tick" (func $tick))
      #|  (import "env" "imp" (global $imp (mut funcref)))
      #|  (func $f)
      #|  (elem declare func $f)
      #|  (global $exp (export "exp") (mut funcref) (ref.null func))
      #|  (func (export "call_barrier") (result funcref)
      #|    ref.func $f
      #|    global.set $imp
      #|    call $tick
      #|    global.get $imp)
      #|  (func (export "nonconst_barrier") (param $x funcref) (result funcref)
      #|    ref.func $f
      #|    global.set $exp
      #|    local.get $x
      #|    global.set $exp
      #|    global.get $exp))
      #|,
    ),
  )

  let call_pretty = optimized.pretty_print_defined_func(1U)
  assert_true(call_pretty.contains("global.get"), msg=call_pretty)
  let nonconst_pretty = optimized.pretty_print_defined_func(2U)
  assert_true(nonconst_pretty.contains("global.get"), msg=nonconst_pretty)
}

///|
test "simplify-globals-optimizing carries ref-func facts through nested plain blocks" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "g" (global $g (mut funcref)))
      #|  (func $f)
      #|  (elem declare func $f)
      #|  (func (export "run") (result funcref)
      #|    ref.func $f
      #|    global.set $g
      #|    block (result funcref)
      #|      block (result funcref)
      #|        global.get $g
      #|      end
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("ref.func"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing carries externref null facts through nested plain blocks" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "g" (global $g (mut externref)))
      #|  (func (export "run") (result externref)
      #|    ref.null extern
      #|    global.set $g
      #|    block (result externref)
      #|      block (result externref)
      #|        global.get $g
      #|      end
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("ref.null"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps externref then-body reads after calls" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "tick" (func $tick))
      #|  (import "env" "g" (global $g (mut externref)))
      #|  (func (export "run") (param $p i32) (result externref)
      #|    ref.null extern
      #|    global.set $g
      #|    local.get $p
      #|    if (result externref)
      #|      call $tick
      #|      global.get $g
      #|    else
      #|      ref.null extern
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps externref loop runtime facts conservative after calls" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "tick" (func $tick))
      #|  (import "env" "g" (global $g (mut externref)))
      #|  (func (export "run") (result externref)
      #|    ref.null extern
      #|    global.set $g
      #|    loop
      #|      call $tick
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps externref try_table runtime facts conservative" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "g" (global $g (mut externref)))
      #|  (tag $e)
      #|  (func (export "run") (result externref)
      #|    ref.null extern
      #|    global.set $g
      #|    block $exit
      #|      try_table (catch $e $exit)
      #|        ref.null extern
      #|        global.set $g
      #|      end
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps externref post-if runtime joins conservative" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "g" (global $g (mut externref)))
      #|  (func (export "run") (param $p i32) (result externref)
      #|    local.get $p
      #|    if
      #|      ref.null extern
      #|      global.set $g
      #|    else
      #|      ref.null extern
      #|      global.set $g
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps reference then-body reads after calls" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "tick" (func $tick))
      #|  (func $f)
      #|  (elem declare func $f)
      #|  (global $g (export "g") (mut funcref) (ref.null func))
      #|  (func (export "run") (param $p i32) (result funcref)
      #|    ref.func $f
      #|    global.set $g
      #|    local.get $p
      #|    if (result funcref)
      #|      call $tick
      #|      global.get $g
      #|    else
      #|      ref.null func
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps reference loop runtime facts conservative after calls and branches" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "tick" (func $tick))
      #|  (import "env" "g" (global $g (mut funcref)))
      #|  (func $f)
      #|  (elem declare func $f)
      #|  (func (export "call_loop") (result funcref)
      #|    ref.func $f
      #|    global.set $g
      #|    loop
      #|      call $tick
      #|    end
      #|    global.get $g)
      #|  (func (export "branch_loop") (param $p i32) (result funcref)
      #|    ref.func $f
      #|    global.set $g
      #|    loop $again
      #|      local.get $p
      #|      br_if $again
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let call_pretty = optimized.pretty_print_defined_func(1U)
  assert_true(call_pretty.contains("global.get"), msg=call_pretty)
  let branch_pretty = optimized.pretty_print_defined_func(2U)
  assert_true(branch_pretty.contains("global.get"), msg=branch_pretty)
}

///|
test "simplify-globals-optimizing keeps reference try_table runtime facts conservative" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "g" (global $g (mut funcref)))
      #|  (tag $e)
      #|  (func $f)
      #|  (elem declare func $f)
      #|  (func (export "run") (result funcref)
      #|    ref.func $f
      #|    global.set $g
      #|    block $exit
      #|      try_table (catch $e $exit)
      #|        ref.func $f
      #|        global.set $g
      #|      end
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps reference post-if runtime joins conservative" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "g" (global $g (mut funcref)))
      #|  (func $f)
      #|  (elem declare func $f)
      #|  (func (export "run") (param $p i32) (result funcref)
      #|    local.get $p
      #|    if
      #|      ref.func $f
      #|      global.set $g
      #|    else
      #|      ref.func $f
      #|      global.set $g
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps loop-contained block runtime facts conservative" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32)
      #|    block
      #|      loop
      #|        i32.const 10
      #|        global.set $g
      #|      end
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps nested try_table block runtime facts conservative" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (tag $e)
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32)
      #|    block $exit
      #|      try_table (catch $e $exit)
      #|        i32.const 10
      #|        global.set $g
      #|      end
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing propagates runtime block facts past drop noise" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32)
      #|    i32.const 10
      #|    global.set $g
      #|    block (result i32)
      #|      i32.const 0
      #|      drop
      #|      global.get $g
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(10)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing propagates runtime block facts past pure instruction noise" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32)
      #|    block
      #|      i32.const 12
      #|      global.set $g
      #|      i32.const 1
      #|      i32.const 2
      #|      i32.add
      #|      drop
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(12)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing propagates runtime facts into no-else if bodies" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32)
      #|    i32.const 10
      #|    global.set $g
      #|    local.get $p
      #|    if
      #|      global.get $g
      #|      drop
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(10)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing propagates runtime facts into nested blocks inside no-else if bodies" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32)
      #|    i32.const 11
      #|    global.set $g
      #|    local.get $p
      #|    if
      #|      block
      #|        global.get $g
      #|        drop
      #|      end
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(11)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing stops no-else if body runtime propagation at calls" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "tick" (func $tick))
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32)
      #|    i32.const 12
      #|    global.set $g
      #|    local.get $p
      #|    if
      #|      call $tick
      #|      global.get $g
      #|      drop
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps else-arm runtime reads conservative" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32) (result i32)
      #|    i32.const 13
      #|    global.set $g
      #|    local.get $p
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      global.get $g
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing propagates runtime facts into then bodies with else arms" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32) (result i32)
      #|    i32.const 21
      #|    global.set $g
      #|    local.get $p
      #|    if (result i32)
      #|      global.get $g
      #|    else
      #|      i32.const 0
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(21)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing propagates runtime facts into nested then blocks with else arms" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32)
      #|    i32.const 22
      #|    global.set $g
      #|    local.get $p
      #|    if
      #|      block
      #|        global.get $g
      #|        drop
      #|      end
      #|    else
      #|      nop
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(22)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing stops then-body runtime propagation at calls with else arms" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "tick" (func $tick))
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32)
      #|    i32.const 23
      #|    global.set $g
      #|    local.get $p
      #|    if
      #|      call $tick
      #|      global.get $g
      #|      drop
      #|    else
      #|      nop
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing does not carry then-body writes after if" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32) (result i32)
      #|    local.get $p
      #|    if
      #|      i32.const 40
      #|      global.set $g
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing does not infer post-if facts when both arms write the same constant" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32) (result i32)
      #|    local.get $p
      #|    if
      #|      i32.const 41
      #|      global.set $g
      #|    else
      #|      i32.const 41
      #|      global.set $g
      #|    end
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps branchy then-body runtime reads conservative" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32) (param $q i32)
      #|    i32.const 42
      #|    global.set $g
      #|    local.get $p
      #|    if
      #|      local.get $q
      #|      br_if 0
      #|      global.get $g
      #|      drop
      #|    else
      #|      nop
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing tracks exported globals in then bodies" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (export "g") (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32)
      #|    i32.const 43
      #|    global.set $g
      #|    local.get $p
      #|    if
      #|      global.get $g
      #|      drop
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(43)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing tracks imported globals in then bodies" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "g" (global $g (mut i32)))
      #|  (func (export "run") (param $p i32)
      #|    i32.const 44
      #|    global.set $g
      #|    local.get $p
      #|    if
      #|      global.get $g
      #|      drop
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(44)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps then rewrites local when else bodies call" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "tick" (func $tick (result i32)))
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32) (result i32)
      #|    i32.const 45
      #|    global.set $g
      #|    local.get $p
      #|    if (result i32)
      #|      global.get $g
      #|    else
      #|      call $tick
      #|    end))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("I32(45)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing propagates top-level runtime facts past no-op noise" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32)
      #|    i32.const 30
      #|    global.set $g
      #|    nop
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(30)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing propagates top-level runtime facts past drop noise" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32)
      #|    i32.const 31
      #|    global.set $g
      #|    i32.const 0
      #|    drop
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(31)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing propagates top-level runtime facts past pure instruction noise" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32)
      #|    i32.const 32
      #|    global.set $g
      #|    i32.const 1
      #|    i32.const 2
      #|    i32.add
      #|    drop
      #|    global.get $g))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(32)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "simplify-globals-optimizing rewrites dead global.set to cleanup-visible drops" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 1
      #|    global.set $g))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("I32(1)"), msg=pretty)
}

///|
test "simplify-globals-optimizing preserves side effects from dead global.set operands" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $dead (mut i32) (i32.const 0))
      #|  (global $side (mut i32) (i32.const 0))
      #|  (func $effect (result i32)
      #|    i32.const 5
      #|    global.set $side
      #|    i32.const 9)
      #|  (func (export "run")
      #|    call $effect
      #|    global.set $dead))
      #|,
    ),
  )

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("global.set (Global 0)"), msg=pretty)
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes generic scalar call parent chains" {
  let deep_i32 = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    i32.add
      #|    i32.clz
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(deep_i32, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let deep_i32_pretty = deep_i32.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(deep_i32_pretty.contains("call"), msg=deep_i32_pretty)
  assert_true(deep_i32_pretty.contains("drop"), msg=deep_i32_pretty)
  assert_false(deep_i32_pretty.contains("i32.clz"), msg=deep_i32_pretty)
  assert_false(deep_i32_pretty.contains("if"), msg=deep_i32_pretty)

  let relational_i32 = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    i32.add
      #|    i32.const 7
      #|    i32.lt_s
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(relational_i32, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let relational_i32_pretty = relational_i32.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(relational_i32_pretty.contains("call"), msg=relational_i32_pretty)
  assert_true(relational_i32_pretty.contains("drop"), msg=relational_i32_pretty)
  assert_false(
    relational_i32_pretty.contains("i32.lt_s"),
    msg=relational_i32_pretty,
  )

  let sibling_unary_i32 = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    i32.clz
      #|    i32.add
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(sibling_unary_i32, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )

  let float_unary = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result f32)))
      #|  (global $guard (mut f32) (f32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    f32.add
      #|    f32.abs
      #|    f32.const 0
      #|    f32.lt
      #|    if
      #|      f32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(float_unary, 0),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  let float_unary_pretty = float_unary.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(float_unary_pretty.contains("call"), msg=float_unary_pretty)
  assert_true(float_unary_pretty.contains("drop"), msg=float_unary_pretty)
  assert_false(float_unary_pretty.contains("f32.abs"), msg=float_unary_pretty)

  let float_promote_if_return = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result f32)))
      #|  (global $guard (mut f32) (f32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $imp
      #|    f32.add
      #|    f64.promote_f32
      #|    f64.const 0
      #|    f64.ge
      #|    if
      #|      return
      #|    end
      #|    f32.const 1
      #|    global.set $guard))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(float_promote_if_return, 0),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  let float_promote_pretty = float_promote_if_return.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(float_promote_pretty.contains("call"), msg=float_promote_pretty)
  assert_true(float_promote_pretty.contains("drop"), msg=float_promote_pretty)
  assert_false(
    float_promote_pretty.contains("f64.promote_f32"),
    msg=float_promote_pretty,
  )

  let trapping_suffix = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (param $d i32)
      #|    global.get $guard
      #|    call $imp
      #|    i32.add
      #|    local.get $d
      #|    i32.div_s
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(trapping_suffix, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let trapping_pretty = trapping_suffix.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(trapping_pretty.contains("i32.div_s"), msg=trapping_pretty)
  assert_true(trapping_pretty.contains("global.get"), msg=trapping_pretty)
  assert_true(trapping_pretty.contains("global.set"), msg=trapping_pretty)
}

///|
test "simplify-globals-optimizing removes multiple constant-first scalar call parents" {
  let direct = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 9
      #|    i32.const 7
      #|    global.get $guard
      #|    call $imp
      #|    i32.add
      #|    i32.mul
      #|    i32.lt_s
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(direct, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let direct_pretty = direct.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(direct_pretty.contains("call"), msg=direct_pretty)
  assert_true(direct_pretty.contains("drop"), msg=direct_pretty)
  assert_false(direct_pretty.contains("i32.mul"), msg=direct_pretty)
  assert_false(direct_pretty.contains("i32.lt_s"), msg=direct_pretty)
  assert_false(direct_pretty.contains("if"), msg=direct_pretty)

  let reverse = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 9
      #|    i32.const 7
      #|    call $imp
      #|    global.get $guard
      #|    i32.add
      #|    i32.mul
      #|    i32.lt_s
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(reverse_pretty.contains("call"), msg=reverse_pretty)
  assert_true(reverse_pretty.contains("drop"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("i32.mul"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("i32.lt_s"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("if"), msg=reverse_pretty)
}

///|
test "simplify-globals-optimizing removes reverse call pre-parent same-type unary" {
  let same_type = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $imp
      #|    i32.clz
      #|    global.get $guard
      #|    i32.add
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(same_type, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let same_type_pretty = same_type.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(same_type_pretty.contains("call"), msg=same_type_pretty)
  assert_true(same_type_pretty.contains("drop"), msg=same_type_pretty)
  assert_false(same_type_pretty.contains("i32.clz"), msg=same_type_pretty)
  assert_false(same_type_pretty.contains("i32.add"), msg=same_type_pretty)
  assert_false(same_type_pretty.contains("i32.eqz"), msg=same_type_pretty)
  assert_false(same_type_pretty.contains("if"), msg=same_type_pretty)
}

///|
test "simplify-globals-optimizing removes reverse call pre-parent conversion" {
  let conversion = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result i32)))
      #|  (global $guard (mut f64) (f64.const 0))
      #|  (func (export "run")
      #|    call $imp
      #|    f64.convert_i32_s
      #|    global.get $guard
      #|    f64.add
      #|    f64.const 0
      #|    f64.gt
      #|    if
      #|      f64.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(conversion, 0),
    @lib.GlobalType::new(@lib.ValType::f64(), false),
  )
  let conversion_pretty = conversion.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(conversion_pretty.contains("call"), msg=conversion_pretty)
  assert_true(conversion_pretty.contains("drop"), msg=conversion_pretty)
  assert_false(
    conversion_pretty.contains("f64.convert_i32_s"),
    msg=conversion_pretty,
  )
  assert_false(conversion_pretty.contains("f64.add"), msg=conversion_pretty)
  assert_false(conversion_pretty.contains("f64.gt"), msg=conversion_pretty)
  assert_false(conversion_pretty.contains("if"), msg=conversion_pretty)
}

///|
test "simplify-globals-optimizing preserves reverse call pre-parent trap" {
  let trapping = sgo_test_run(
    (
      #|(module
      #|  (import "env" "imp" (func $imp (result f32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $imp
      #|    i32.trunc_f32_s
      #|    global.get $guard
      #|    i32.add
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(trapping, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let trapping_pretty = trapping.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(trapping_pretty.contains("call"), msg=trapping_pretty)
  assert_true(trapping_pretty.contains("i32.trunc_f32s"), msg=trapping_pretty)
  assert_true(trapping_pretty.contains("drop"), msg=trapping_pretty)
  assert_false(trapping_pretty.contains("i32.add"), msg=trapping_pretty)
  assert_false(trapping_pretty.contains("i32.eqz"), msg=trapping_pretty)
  assert_false(trapping_pretty.contains("if"), msg=trapping_pretty)
}

///|
test "simplify-globals-optimizing removes direct memory-size pre-parent unary" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    memory.size
      #|    i32.clz
      #|    i32.add
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("memory.size"), msg=pretty)
  assert_false(pretty.contains("i32.clz"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
  assert_false(pretty.contains("i32.eqz"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes reverse memory-size pre-parent conversion" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut f64) (f64.const 0))
      #|  (func (export "run")
      #|    memory.size
      #|    f64.convert_i32_s
      #|    global.get $guard
      #|    f64.add
      #|    f64.const 0
      #|    f64.gt
      #|    if
      #|      f64.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::f64(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("memory.size"), msg=pretty)
  assert_false(pretty.contains("f64.convert_i32_s"), msg=pretty)
  assert_false(pretty.contains("f64.add"), msg=pretty)
  assert_false(pretty.contains("f64.gt"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
}

///|
test "simplify-globals-optimizing preserves independent load pre-parent trap" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i32.const 65536
      #|    i32.load
      #|    i32.add
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
  assert_false(pretty.contains("i32.eqz"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps guarded load addresses dependent" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i32.load
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes direct pure result-block producer" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $g
      #|    block (result i32)
      #|      i32.const 7
      #|      i32.eqz
      #|    end
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("block"), msg=pretty)
}

///|
test "simplify-globals-optimizing preserves direct result-block independent memory grow" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $g
      #|    block (result i32)
      #|      i32.const 0
      #|      memory.grow
      #|      drop
      #|      i32.const 7
      #|    end
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("block"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
}

///|
test "simplify-globals-optimizing preserves direct result-block pure-add memory grow" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $n i32)
      #|    global.get $g
      #|    block (result i32)
      #|      local.get $n
      #|      i32.const 1
      #|      i32.add
      #|      memory.grow
      #|      drop
      #|      i32.const 7
      #|    end
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("i32.add"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("block"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps guarded result-block memory grow deltas dependent" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      global.get $g
      #|      memory.grow
      #|      drop
      #|      i32.const 7
      #|    end
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing promotes guarded values produced inside result loops" {
  let direct = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    loop (result i32)
      #|      global.get $g
      #|    end
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(direct, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let direct_pretty = direct.pretty_print_defined_func(0U)
  assert_false(direct_pretty.contains("global.get"), msg=direct_pretty)
  assert_false(direct_pretty.contains("global.set"), msg=direct_pretty)

  let reverse = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    loop (result i32)
      #|      global.get $g
      #|    end
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse.pretty_print_defined_func(0U)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)
}

///|
test "simplify-globals-optimizing promotes guarded values through pure result-loop parents" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    loop (result i32)
      #|      global.get $g
      #|      i32.const 7
      #|      i32.add
      #|      i32.eqz
      #|    end
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing promotes guarded values through nested pure structured parents" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    loop (result i32)
      #|      block (result i32)
      #|        global.get $g
      #|        i32.const 7
      #|        i32.add
      #|      end
      #|      i32.eqz
      #|    end
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing promotes guarded values through pure try-table parents" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (tag $e (param i32))
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block $exit (result i32)
      #|      try_table (result i32) (catch $e $exit)
      #|        global.get $g
      #|        i32.const 7
      #|        i32.add
      #|        i32.eqz
      #|      end
      #|    end
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing promotes guarded values produced inside branchful result blocks" {
  let guarded_set = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32)
      #|    block $exit (result i32)
      #|      global.get $g
      #|      local.get $p
      #|      br_if $exit
      #|      drop
      #|      i32.const 8
      #|    end
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(guarded_set, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let guarded_set_pretty = guarded_set.pretty_print_defined_func(0U)
  assert_false(
    guarded_set_pretty.contains("global.get"),
    msg=guarded_set_pretty,
  )
  assert_false(
    guarded_set_pretty.contains("global.set"),
    msg=guarded_set_pretty,
  )

  let if_return = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32)
      #|    block $exit (result i32)
      #|      global.get $g
      #|      local.get $p
      #|      br_if $exit
      #|      drop
      #|      i32.const 8
      #|    end
      #|    i32.eqz
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $g))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(if_return, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let if_return_pretty = if_return.pretty_print_defined_func(0U)
  assert_false(if_return_pretty.contains("global.get"), msg=if_return_pretty)
  assert_false(if_return_pretty.contains("global.set"), msg=if_return_pretty)
}

///|
test "simplify-globals-optimizing keeps dangerous structured guard flow mutable" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (type $side (func (result i32)))
      #|  (import "env" "side" (func $side (type $side)))
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      global.get $g
      #|      if (result i32)
      #|        call $side
      #|      else
      #|        i32.const 1
      #|      end
      #|    end
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)

  let dangerous_loop = sgo_test_run(
    (
      #|(module
      #|  (import "env" "side" (func $side))
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    loop (result i32)
      #|      global.get $g
      #|      if (result i32)
      #|        call $side
      #|        i32.const 1
      #|      else
      #|        i32.const 0
      #|      end
      #|    end
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(dangerous_loop, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let dangerous_loop_pretty = dangerous_loop.pretty_print_defined_func(0U)
  assert_true(
    dangerous_loop_pretty.contains("global.get"),
    msg=dangerous_loop_pretty,
  )
  assert_true(
    dangerous_loop_pretty.contains("global.set"),
    msg=dangerous_loop_pretty,
  )
  assert_true(dangerous_loop_pretty.contains("call"), msg=dangerous_loop_pretty)
}

///|
test "simplify-globals-optimizing removes independent scalar result loop producer" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $g
      #|    loop (result i32)
      #|      i32.const 7
      #|    end
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes independent branchful result-block producer" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32)
      #|    global.get $g
      #|    block $exit (result i32)
      #|      i32.const 7
      #|      local.get $p
      #|      br_if $exit
      #|      drop
      #|      i32.const 8
      #|    end
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing folds observable result-block local set" {
  let direct = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32) (local $tmp i32)
      #|    global.get $g
      #|    block (result i32)
      #|      i32.const 42
      #|      local.set $tmp
      #|      i32.const 7
      #|    end
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end
      #|    local.get $tmp))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(direct, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(try! sgo_test_first_defined_func_local_count(direct), 0)
  let direct_pretty = direct.pretty_print_defined_func(0U)
  assert_true(direct_pretty.contains("I32(42)"), msg=direct_pretty)
  assert_false(direct_pretty.contains("local.set"), msg=direct_pretty)
  assert_false(direct_pretty.contains("local.get"), msg=direct_pretty)
  assert_false(direct_pretty.contains("global.get"), msg=direct_pretty)
  assert_false(direct_pretty.contains("global.set"), msg=direct_pretty)
  let reverse = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32) (local $tmp i32)
      #|    block (result i32)
      #|      i32.const 42
      #|      local.set $tmp
      #|      i32.const 7
      #|    end
      #|    global.get $g
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end
      #|    local.get $tmp))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(try! sgo_test_first_defined_func_local_count(reverse), 0)
  let reverse_pretty = reverse.pretty_print_defined_func(0U)
  assert_true(reverse_pretty.contains("I32(42)"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("local.set"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("local.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)
}

///|
test "simplify-globals-optimizing folds local-fed observable result-block local set" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $v i32) (result i32) (local $tmp i32)
      #|    global.get $g
      #|    block (result i32)
      #|      local.get $v
      #|      local.set $tmp
      #|      i32.const 7
      #|    end
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end
      #|    local.get $tmp))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_false(pretty.contains("local.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing folds observable result-block local tee" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32) (local $tmp i32)
      #|    global.get $g
      #|    block (result i32)
      #|      i32.const 42
      #|      local.tee $tmp
      #|      drop
      #|      i32.const 7
      #|    end
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end
      #|    local.get $tmp))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("I32(42)"), msg=pretty)
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("local.set"), msg=pretty)
  assert_false(pretty.contains("local.get"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing folds repeated constant result-block local reads" {
  let direct = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32) (local $tmp i32)
      #|    global.get $g
      #|    block (result i32)
      #|      i32.const 42
      #|      local.set $tmp
      #|      i32.const 7
      #|    end
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end
      #|    local.get $tmp
      #|    local.get $tmp
      #|    i32.add))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(direct, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let direct_pretty = direct.pretty_print_defined_func(0U)
  assert_true(direct_pretty.contains("I32(84)"), msg=direct_pretty)
  assert_false(direct_pretty.contains("local.set"), msg=direct_pretty)
  assert_false(direct_pretty.contains("local.tee"), msg=direct_pretty)
  assert_false(direct_pretty.contains("local.get"), msg=direct_pretty)
  assert_false(direct_pretty.contains("i32.add"), msg=direct_pretty)
  assert_false(direct_pretty.contains("global.get"), msg=direct_pretty)
  assert_false(direct_pretty.contains("global.set"), msg=direct_pretty)
  let reverse = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32) (local $tmp i32)
      #|    block (result i32)
      #|      i32.const 42
      #|      local.tee $tmp
      #|      drop
      #|      i32.const 7
      #|    end
      #|    global.get $g
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end
      #|    local.get $tmp
      #|    local.get $tmp
      #|    i32.add))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(reverse, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let reverse_pretty = reverse.pretty_print_defined_func(0U)
  assert_true(reverse_pretty.contains("I32(84)"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("local.set"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("local.tee"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("local.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("i32.add"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.get"), msg=reverse_pretty)
  assert_false(reverse_pretty.contains("global.set"), msg=reverse_pretty)
}

///|
test "simplify-globals-optimizing keeps guarded result-block local writes dependent" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (result i32) (local $tmp i32)
      #|    block (result i32)
      #|      global.get $g
      #|      local.set $tmp
      #|      i32.const 7
      #|    end
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end
      #|    local.get $tmp))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing preserves direct result-block table grow" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $g
      #|    block (result i32)
      #|      ref.null func
      #|      i32.const 0
      #|      table.grow 0
      #|      drop
      #|      i32.const 7
      #|    end
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("block"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps guarded result-block table grow deltas dependent" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      ref.null func
      #|      global.get $g
      #|      table.grow 0
      #|      drop
      #|      i32.const 7
      #|    end
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing preserves reverse result-block load trap" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      i32.const 0
      #|      i32.load
      #|    end
      #|    global.get $g
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes reverse pure result-if producer" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run") (param $p i32)
      #|    local.get $p
      #|    if (result i32)
      #|      i32.const 7
      #|    else
      #|      i32.const 8
      #|    end
      #|    global.get $g
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("if"), msg=pretty)
}

///|
test "simplify-globals-optimizing preserves direct result-if condition call" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "m" "cond" (func $cond (result i32)))
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $g
      #|    call $cond
      #|    if (result i32)
      #|      i32.const 7
      #|    else
      #|      i32.const 8
      #|    end
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps guarded result-if conditions dependent" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "m" "side" (func $side))
      #|  (global $g (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 7
      #|    global.get $g
      #|    if (result i32)
      #|      call $side
      #|      i32.const 1
      #|    else
      #|      i32.const 2
      #|    end
      #|    i32.eq
      #|    if
      #|      i32.const 1
      #|      global.set $g
      #|    end))
      #|,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps exported mutable globals observable" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $g (export "g") (mut i32) (i32.const 7))
      #|  (func (export "run") (result i32)
      #|    global.get $g))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("I32(7)"), msg=pretty)
}
