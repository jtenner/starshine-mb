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
    text.contains("perf:timer name=detail:sgo:nested:vacuum"),
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
    "pass[simplify-globals-optimizing]:nested-pass name=optimize-instructions", "pass[simplify-globals-optimizing]:nested-pass name=local-cse",
    "pass[simplify-globals-optimizing]:nested-pass name=pick-load-signs", "pass[simplify-globals-optimizing]:nested-pass name=merge-blocks",
    "pass[simplify-globals-optimizing]:nested-pass name=remove-unused-names", "pass[simplify-globals-optimizing]:nested-pass name=merge-blocks",
    "pass[simplify-globals-optimizing]:nested-pass name=coalesce-locals", "pass[simplify-globals-optimizing]:nested-pass name=reorder-locals",
    "pass[simplify-globals-optimizing]:nested-pass name=redundant-set-elimination",
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
        "pass[simplify-globals-optimizing]:nested-pass name=local-cse",
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
        "pass[simplify-globals-optimizing]:nested-pass name=local-cse",
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
        "pass[simplify-globals-optimizing]:nested-pass name=local-cse",
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
        "pass[simplify-globals-optimizing]:nested-pass name=local-cse",
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
        "pass[simplify-globals-optimizing]:nested-pass name=local-cse",
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
        "pass[simplify-globals-optimizing]:nested-pass name=local-cse",
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
        "pass[simplify-globals-optimizing]:nested-pass name=local-cse",
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
        "pass[simplify-globals-optimizing]:nested-pass name=local-cse",
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
test "simplify-globals-optimizing removes pure select condition self guards" {
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes pure select first-value self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i32.const 1
      #|    i32.const 0
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes pure select second-value self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
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
test "simplify-globals-optimizing removes side-effecting safe condition self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    i32.const 1
      #|    local.tee $tmp
      #|    i32.const 2
      #|    i32.load
      #|    global.get $guard
      #|    i32.const 1337
      #|    i32.add
      #|    select
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes side-effecting safe select value self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    global.get $guard
      #|    i32.const 1337
      #|    i32.add
      #|    i32.const 1
      #|    local.tee $tmp
      #|    i32.const 2
      #|    i32.load
      #|    select
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes side-effecting safe second select value self guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    i32.const 1
      #|    local.tee $tmp
      #|    global.get $guard
      #|    i32.const 1337
      #|    i32.add
      #|    i32.const 2
      #|    i32.load
      #|    select
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes side-effecting safe select chains through extra pure ops" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    i32.const 1
      #|    local.tee $tmp
      #|    i32.const 2
      #|    i32.load
      #|    global.get $guard
      #|    i32.const 1337
      #|    i32.add
      #|    i32.const 7
      #|    i32.xor
      #|    select
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes side-effecting safe second-value select chains through extra pure ops" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    i32.const 1
      #|    local.tee $tmp
      #|    global.get $guard
      #|    i32.const 1337
      #|    i32.add
      #|    i32.const 7
      #|    i32.xor
      #|    i32.const 2
      #|    i32.load
      #|    select
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps conditions with multiple same-global reads" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
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
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps global-derived local tees after pure flow" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    global.get $guard
      #|    i32.const 1
      #|    i32.add
      #|    local.tee $tmp
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm value flow with independent call condition" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $foo
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm value flow with pure call condition" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $foo
      #|    i32.eqz
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm value flow with local tee condition" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    i32.const 0
      #|    local.tee $tmp
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with independent arm effect" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (import "env" "tick" (func $tick))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result i32)
      #|      call $tick
      #|      global.get $guard
      #|    else
      #|      i32.const 1
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with independent call-result arm" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (import "env" "val" (func $val (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result i32)
      #|      call $val
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with independent call-result pure arm" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (import "env" "val" (func $val (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result i32)
      #|      call $val
      #|      i32.eqz
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with independent call operand" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (param i32) (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 42
      #|    call $cond
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with independent call_indirect condition" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (type $t (func (param i32) (result i32)))
      #|  (table 1 funcref)
      #|  (elem (i32.const 0) $cond)
      #|  (func $cond (param i32) (result i32)
      #|    local.get 0)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 42
      #|    i32.const 0
      #|    call_indirect (type $t)
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("call_indirect"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with independent call_ref condition" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (type $t (func (result i32)))
      #|  (func $cond (type $t)
      #|    i32.const 1)
      #|  (elem declare func $cond)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    ref.func $cond
      #|    call_ref $t
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(1U)
  assert_true(
    pretty.contains("call_ref") || pretty.contains("call"),
    msg=pretty,
  )
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps call_ref operands derived from the global" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (type $t (func (param i32) (result i32)))
      #|  (func $id (type $t)
      #|    local.get 0)
      #|  (elem declare func $id)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    ref.func $id
      #|    call_ref $t
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
  let pretty = optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("call_ref"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps call_indirect operands derived from the global" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (type $nullary (func (result i32)))
      #|  (type $unary (func (param i32) (result i32)))
      #|  (table 2 funcref)
      #|  (elem (i32.const 0) $one $zero)
      #|  (func $one (result i32)
      #|    i32.const 1)
      #|  (func $zero (result i32)
      #|    i32.const 0)
      #|  (func $id (param i32) (result i32)
      #|    local.get 0)
      #|  (global $index (mut i32) (i32.const 0))
      #|  (global $param (mut i32) (i32.const 0))
      #|  (func (export "index")
      #|    global.get $index
      #|    call_indirect (type $nullary)
      #|    if
      #|      i32.const 1
      #|      global.set $index
      #|    end)
      #|  (func (export "param")
      #|    global.get $param
      #|    i32.const 0
      #|    call_indirect (type $unary)
      #|    if
      #|      i32.const 1
      #|      global.set $param
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 2; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), true),
    )
  }
  let pretty = optimized.pretty_print_defined_func(3U) +
    optimized.pretty_print_defined_func(4U)
  assert_true(pretty.contains("call_indirect"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through post-if pure consumer" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      global.get $guard
      #|    end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps nested-if arm flow into post-if call operand" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (import "env" "use" (func $use (param i32) (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      global.get $guard
      #|    end
      #|    call $use
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean exported global set" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (global $other (export "other") (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 7
      #|    global.set $other
      #|    global.get $other
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_false(pretty.contains("global.get $guard"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted exported global set flow" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (global $other (export "other") (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    global.set $other
      #|    global.get $other
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
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean table set" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table (export "t") 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    ref.null func
      #|    table.set 0
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("table.set"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted table set index flow" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table (export "t") 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    ref.null func
      #|    table.set 0
      #|    i32.const 1
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("table.set"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean i32 store" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    i32.const 7
      #|    i32.store
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted i32 store operands" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $addr (mut i32) (i32.const 0))
      #|  (global $value (mut i32) (i32.const 0))
      #|  (func (export "addr")
      #|    global.get $addr
      #|    i32.const 7
      #|    i32.store
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $addr
      #|    end)
      #|  (func (export "value")
      #|    i32.const 0
      #|    global.get $value
      #|    i32.store
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $value
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 2; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), true),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean i64 store" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    i64.const 7
      #|    i64.store
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i64.store"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted i64 store operands" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $addr (mut i32) (i32.const 0))
      #|  (global $value (mut i32) (i32.const 0))
      #|  (func (export "addr")
      #|    global.get $addr
      #|    i64.const 7
      #|    i64.store
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $addr
      #|    end)
      #|  (func (export "value")
      #|    i32.const 0
      #|    global.get $value
      #|    i64.extend_i32_u
      #|    i64.store
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $value
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 2; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), true),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("i64.store"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean i32 store8" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    i32.const 7
      #|    i32.store8
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.store8"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted i32 store8 operands" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $addr (mut i32) (i32.const 0))
      #|  (global $value (mut i32) (i32.const 0))
      #|  (func (export "addr")
      #|    global.get $addr
      #|    i32.const 7
      #|    i32.store8
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $addr
      #|    end)
      #|  (func (export "value")
      #|    i32.const 0
      #|    global.get $value
      #|    i32.store8
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $value
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 2; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), true),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("i32.store8"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean i32 store16" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    i32.const 7
      #|    i32.store16
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.store16"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted i32 store16 operands" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $addr (mut i32) (i32.const 0))
      #|  (global $value (mut i32) (i32.const 0))
      #|  (func (export "addr")
      #|    global.get $addr
      #|    i32.const 7
      #|    i32.store16
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $addr
      #|    end)
      #|  (func (export "value")
      #|    i32.const 0
      #|    global.get $value
      #|    i32.store16
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $value
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 2; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), true),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("i32.store16"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean i64 store8" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    i64.const 7
      #|    i64.store8
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i64.store8"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted i64 store8 operands" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $addr (mut i32) (i32.const 0))
      #|  (global $value (mut i32) (i32.const 0))
      #|  (func (export "addr")
      #|    global.get $addr
      #|    i64.const 7
      #|    i64.store8
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $addr
      #|    end)
      #|  (func (export "value")
      #|    i32.const 0
      #|    global.get $value
      #|    i64.extend_i32_u
      #|    i64.store8
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $value
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 2; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), true),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("i64.store8"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean i64 store16" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    i64.const 7
      #|    i64.store16
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i64.store16"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted i64 store16 operands" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $addr (mut i32) (i32.const 0))
      #|  (global $value (mut i32) (i32.const 0))
      #|  (func (export "addr")
      #|    global.get $addr
      #|    i64.const 7
      #|    i64.store16
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $addr
      #|    end)
      #|  (func (export "value")
      #|    i32.const 0
      #|    global.get $value
      #|    i64.extend_i32_u
      #|    i64.store16
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $value
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 2; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), true),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("i64.store16"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean i64 store32" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    i64.const 7
      #|    i64.store32
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i64.store32"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted i64 store32 operands" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $addr (mut i32) (i32.const 0))
      #|  (global $value (mut i32) (i32.const 0))
      #|  (func (export "addr")
      #|    global.get $addr
      #|    i64.const 7
      #|    i64.store32
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $addr
      #|    end)
      #|  (func (export "value")
      #|    i32.const 0
      #|    global.get $value
      #|    i64.extend_i32_u
      #|    i64.store32
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $value
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 2; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), true),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("i64.store32"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean f32 store" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    f32.const 7
      #|    f32.store
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("f32.store"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted f32 store operands" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $addr (mut i32) (i32.const 0))
      #|  (global $value (mut i32) (i32.const 0))
      #|  (func (export "addr")
      #|    global.get $addr
      #|    f32.const 7
      #|    f32.store
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $addr
      #|    end)
      #|  (func (export "value")
      #|    i32.const 0
      #|    global.get $value
      #|    f32.convert_i32_u
      #|    f32.store
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $value
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 2; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), true),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("f32.store"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean f64 store" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    f64.const 7
      #|    f64.store
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("f64.store"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted f64 store operands" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $addr (mut i32) (i32.const 0))
      #|  (global $value (mut i32) (i32.const 0))
      #|  (func (export "addr")
      #|    global.get $addr
      #|    f64.const 7
      #|    f64.store
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $addr
      #|    end)
      #|  (func (export "value")
      #|    i32.const 0
      #|    global.get $value
      #|    f64.convert_i32_u
      #|    f64.store
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $value
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 2; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), true),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("f64.store"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean memory fill" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    i32.const 7
      #|    i32.const 4
      #|    memory.fill
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("memory.fill"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted memory fill operands" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $dest (mut i32) (i32.const 0))
      #|  (global $value (mut i32) (i32.const 0))
      #|  (global $size (mut i32) (i32.const 0))
      #|  (func (export "dest")
      #|    global.get $dest
      #|    i32.const 7
      #|    i32.const 4
      #|    memory.fill
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $dest
      #|    end)
      #|  (func (export "value")
      #|    i32.const 0
      #|    global.get $value
      #|    i32.const 4
      #|    memory.fill
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $value
      #|    end)
      #|  (func (export "size")
      #|    i32.const 0
      #|    i32.const 7
      #|    global.get $size
      #|    memory.fill
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $size
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 3; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), true),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U) +
    optimized.pretty_print_defined_func(2U)
  assert_true(pretty.contains("memory.fill"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean memory copy" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 8
      #|    i32.const 0
      #|    i32.const 4
      #|    memory.copy
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("memory.copy"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted memory copy operands" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (global $dest (mut i32) (i32.const 0))
      #|  (global $src (mut i32) (i32.const 0))
      #|  (global $size (mut i32) (i32.const 0))
      #|  (func (export "dest")
      #|    global.get $dest
      #|    i32.const 0
      #|    i32.const 4
      #|    memory.copy
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $dest
      #|    end)
      #|  (func (export "src")
      #|    i32.const 8
      #|    global.get $src
      #|    i32.const 4
      #|    memory.copy
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $src
      #|    end)
      #|  (func (export "size")
      #|    i32.const 8
      #|    i32.const 0
      #|    global.get $size
      #|    memory.copy
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $size
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 3; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), true),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U) +
    optimized.pretty_print_defined_func(2U)
  assert_true(pretty.contains("memory.copy"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean memory init" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (data $d "abcd")
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    i32.const 0
      #|    i32.const 4
      #|    memory.init $d
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("memory.init"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted memory init operands" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (data $d "abcd")
      #|  (global $dest (mut i32) (i32.const 0))
      #|  (global $src (mut i32) (i32.const 0))
      #|  (global $size (mut i32) (i32.const 4))
      #|  (func (export "dest")
      #|    global.get $dest
      #|    i32.const 0
      #|    i32.const 4
      #|    memory.init $d
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $dest
      #|    end)
      #|  (func (export "src")
      #|    i32.const 0
      #|    global.get $src
      #|    i32.const 4
      #|    memory.init $d
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $src
      #|    end)
      #|  (func (export "size")
      #|    i32.const 0
      #|    i32.const 0
      #|    global.get $size
      #|    memory.init $d
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $size
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 3; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), true),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U) +
    optimized.pretty_print_defined_func(2U)
  assert_true(pretty.contains("memory.init"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean table fill" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table (export "t") 10 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    ref.null func
      #|    i32.const 2
      #|    table.fill
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("table.fill"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted table fill operands" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "value" (global $value (mut funcref)))
      #|  (table (export "t") 10 funcref)
      #|  (global $dest (mut i32) (i32.const 0))
      #|  (global $size (mut i32) (i32.const 0))
      #|  (func (export "dest")
      #|    global.get $dest
      #|    ref.null func
      #|    i32.const 2
      #|    table.fill
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $dest
      #|    end)
      #|  (func (export "value")
      #|    i32.const 0
      #|    global.get $value
      #|    i32.const 2
      #|    table.fill
      #|    i32.const 1
      #|    if
      #|      ref.null func
      #|      global.set $value
      #|    end)
      #|  (func (export "size")
      #|    i32.const 0
      #|    ref.null func
      #|    global.get $size
      #|    table.fill
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $size
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 2; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), true),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U) +
    optimized.pretty_print_defined_func(2U)
  assert_true(pretty.contains("table.fill"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean table init" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table (export "t") 10 funcref)
      #|  (elem $e funcref (ref.null func) (ref.null func))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    i32.const 0
      #|    i32.const 2
      #|    table.init $e
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("table.init"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted table init operands" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table (export "t") 10 funcref)
      #|  (elem $e funcref (ref.null func) (ref.null func))
      #|  (global $dest (mut i32) (i32.const 0))
      #|  (global $src (mut i32) (i32.const 0))
      #|  (global $size (mut i32) (i32.const 2))
      #|  (func (export "dest")
      #|    global.get $dest
      #|    i32.const 0
      #|    i32.const 2
      #|    table.init $e
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $dest
      #|    end)
      #|  (func (export "src")
      #|    i32.const 0
      #|    global.get $src
      #|    i32.const 2
      #|    table.init $e
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $src
      #|    end)
      #|  (func (export "size")
      #|    i32.const 0
      #|    i32.const 0
      #|    global.get $size
      #|    table.init $e
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $size
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 3; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), true),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U) +
    optimized.pretty_print_defined_func(2U)
  assert_true(pretty.contains("table.init"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean nop" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    nop
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("nop"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps global-steered nop" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    if
      #|      nop
      #|    end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("nop"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean void block" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block
      #|      nop
      #|    end
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("nop"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted void block flow" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block
      #|      global.get $guard
      #|      drop
      #|    end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean void loop" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    loop
      #|      nop
      #|    end
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("nop"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted void loop flow" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    loop
      #|      global.get $guard
      #|      drop
      #|    end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean result block drop" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      i32.const 7
      #|    end
      #|    drop
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted result block drop flow" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      global.get $guard
      #|    end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean result loop drop" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    loop (result i32)
      #|      i32.const 7
      #|    end
      #|    drop
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted result loop drop flow" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    loop (result i32)
      #|      global.get $guard
      #|    end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean elem drop" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table (export "t") 10 funcref)
      #|  (elem $e funcref (ref.null func) (ref.null func))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    elem.drop $e
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("elem.drop"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps global-steered elem drop" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table (export "t") 10 funcref)
      #|  (elem $e funcref (ref.null func) (ref.null func))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    if
      #|      elem.drop $e
      #|    end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("elem.drop"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean data drop" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (data $d "abcd")
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    data.drop $d
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("data.drop"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps global-steered data drop" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory (export "m") 1)
      #|  (data $d "abcd")
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    if
      #|      data.drop $d
      #|    end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("data.drop"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean table copy" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table (export "t") 10 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 4
      #|    i32.const 0
      #|    i32.const 2
      #|    table.copy
      #|    i32.const 1
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("table.copy"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted table copy operands" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table (export "t") 10 funcref)
      #|  (global $dest (mut i32) (i32.const 0))
      #|  (global $src (mut i32) (i32.const 0))
      #|  (global $size (mut i32) (i32.const 2))
      #|  (func (export "dest")
      #|    global.get $dest
      #|    i32.const 0
      #|    i32.const 2
      #|    table.copy
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $dest
      #|    end)
      #|  (func (export "src")
      #|    i32.const 4
      #|    global.get $src
      #|    i32.const 2
      #|    table.copy
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $src
      #|    end)
      #|  (func (export "size")
      #|    i32.const 4
      #|    i32.const 0
      #|    global.get $size
      #|    table.copy
      #|    i32.const 1
      #|    if
      #|      i32.const 1
      #|      global.set $size
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 3; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), true),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U) +
    optimized.pretty_print_defined_func(2U)
  assert_true(pretty.contains("table.copy"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean local set" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    i32.const 1
      #|    local.set $tmp
      #|    local.get $tmp
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps tainted local set flow" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    global.get $guard
      #|    local.set $tmp
      #|    local.get $tmp
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow with clean arm local tee and load" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    call $cond
      #|    if (result i32)
      #|      i32.const 4
      #|      i32.load
      #|    else
      #|      i32.const 7
      #|      local.tee $tmp
      #|      drop
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("local"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps nested-if arm flow through tainted local tee" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run") (local $tmp i32)
      #|    call $cond
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      global.get $guard
      #|      local.tee $tmp
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through transparent value block" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      block (result i32)
      #|        global.get $guard
      #|      end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps nested-if arm block with tainted load" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      block (result i32)
      #|        global.get $guard
      #|        i32.load
      #|      end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through post-if select value" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      global.get $guard
      #|    end
      #|    i32.const 1
      #|    i32.const 0
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps nested-if arm flow through post-if tainted load" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 1
      #|    i32.const 0
      #|    call $cond
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      global.get $guard
      #|    end
      #|    select
      #|    i32.load
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through block-wrapped post-if pure consumer" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      call $cond
      #|      if (result i32)
      #|        i32.const 0
      #|      else
      #|        global.get $guard
      #|      end
      #|      i32.eqz
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through block-wrapped post-if select value" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      call $cond
      #|      if (result i32)
      #|        i32.const 0
      #|      else
      #|        global.get $guard
      #|      end
      #|      i32.const 1
      #|      i32.const 0
      #|      select
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps block-wrapped nested-if arm flow through tainted post-if load" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      call $cond
      #|      if (result i32)
      #|        i32.const 0
      #|      else
      #|        global.get $guard
      #|      end
      #|      i32.load
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through deep block-wrapped post-if pure consumer" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      block (result i32)
      #|        call $cond
      #|        if (result i32)
      #|          i32.const 0
      #|        else
      #|          global.get $guard
      #|        end
      #|        i32.eqz
      #|      end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through deep block-wrapped post-if select value" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      block (result i32)
      #|        call $cond
      #|        if (result i32)
      #|          i32.const 0
      #|        else
      #|          global.get $guard
      #|        end
      #|        i32.const 1
      #|        i32.const 0
      #|        select
      #|      end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps deep block-wrapped nested-if arm flow through tainted post-if load" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      block (result i32)
      #|        call $cond
      #|        if (result i32)
      #|          i32.const 0
      #|        else
      #|          global.get $guard
      #|        end
      #|        i32.load
      #|      end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through clean if-wrapper pure consumer" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result i32)
      #|      call $cond
      #|      if (result i32)
      #|        i32.const 0
      #|      else
      #|        global.get $guard
      #|      end
      #|    else
      #|      i32.const 0
      #|    end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through clean if-wrapper select value" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      call $cond
      #|      if (result i32)
      #|        i32.const 0
      #|      else
      #|        global.get $guard
      #|      end
      #|    end
      #|    i32.const 1
      #|    i32.const 0
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps nested-if arm flow through clean if-wrapper tainted load" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result i32)
      #|      call $cond
      #|      if (result i32)
      #|        i32.const 0
      #|      else
      #|        global.get $guard
      #|      end
      #|    else
      #|      i32.const 0
      #|    end
      #|    i32.load
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps nested-if arm flow through global-steered if-wrapper" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result i32)
      #|      global.get $guard
      #|      if (result i32)
      #|        i32.const 1
      #|      else
      #|        i32.const 0
      #|      end
      #|    else
      #|      i32.const 0
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through ref-is-null post-consumer" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (func $target)
      #|  (elem declare func $target)
      #|  (global $guard (mut funcref) (ref.null func))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result funcref)
      #|      ref.null func
      #|    else
      #|      global.get $guard
      #|    end
      #|    ref.is_null
      #|    if
      #|      ref.func $target
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::funcref(), false),
  )
  let pretty = optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block-wrapped nested-if arm flow through ref-is-null" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (func $target)
      #|  (elem declare func $target)
      #|  (global $guard (mut funcref) (ref.null func))
      #|  (func (export "run")
      #|    block (result i32)
      #|      call $cond
      #|      if (result funcref)
      #|        ref.null func
      #|      else
      #|        global.get $guard
      #|      end
      #|      ref.is_null
      #|    end
      #|    if
      #|      ref.func $target
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::funcref(), false),
  )
  let pretty = optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps ref-is-null arm flow into post-consumer call" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (import "env" "use" (func $use (param i32) (result i32)))
      #|  (func $target)
      #|  (elem declare func $target)
      #|  (global $guard (mut funcref) (ref.null func))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result funcref)
      #|      ref.null func
      #|    else
      #|      global.get $guard
      #|    end
      #|    ref.is_null
      #|    call $use
      #|    if
      #|      ref.func $target
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::funcref(), true),
  )
  let pretty = optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through ref-eq post-consumer" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut eqref) (ref.i31 (i32.const 0)))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result eqref)
      #|      ref.null eq
      #|    else
      #|      global.get $guard
      #|    end
      #|    ref.null eq
      #|    ref.eq
      #|    if
      #|      ref.null eq
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
      ),
      false,
    ),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block-wrapped nested-if arm flow through ref-eq" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut eqref) (ref.i31 (i32.const 0)))
      #|  (func (export "run")
      #|    block (result i32)
      #|      call $cond
      #|      if (result eqref)
      #|        ref.null eq
      #|      else
      #|        global.get $guard
      #|      end
      #|      ref.null eq
      #|      ref.eq
      #|    end
      #|    if
      #|      ref.null eq
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
      ),
      false,
    ),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps ref-eq arm flow into post-consumer call" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (import "env" "use" (func $use (param i32) (result i32)))
      #|  (global $guard (mut eqref) (ref.i31 (i32.const 0)))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result eqref)
      #|      ref.null eq
      #|    else
      #|      global.get $guard
      #|    end
      #|    ref.null eq
      #|    ref.eq
      #|    call $use
      #|    if
      #|      ref.null eq
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
      ),
      true,
    ),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through ref-i31 and ref-eq" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      global.get $guard
      #|    end
      #|    ref.i31
      #|    ref.null eq
      #|    ref.eq
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through any-extern conversions" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut anyref) (ref.i31 (i32.const 0)))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result anyref)
      #|      ref.null any
      #|    else
      #|      global.get $guard
      #|    end
      #|    extern.convert_any
      #|    any.convert_extern
      #|    ref.is_null
      #|    if
      #|      ref.null any
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::any())),
      ),
      false,
    ),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block-wrapped nested-if arm flow through any-extern conversions" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut anyref) (ref.i31 (i32.const 0)))
      #|  (func (export "run")
      #|    block (result i32)
      #|      call $cond
      #|      if (result anyref)
      #|        ref.null any
      #|      else
      #|        global.get $guard
      #|      end
      #|      extern.convert_any
      #|      any.convert_extern
      #|      ref.is_null
      #|    end
      #|    if
      #|      ref.null any
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::any())),
      ),
      false,
    ),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps any-extern conversion arm flow into post-consumer call" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (import "env" "use" (func $use (param i32) (result i32)))
      #|  (global $guard (mut anyref) (ref.i31 (i32.const 0)))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result anyref)
      #|      ref.null any
      #|    else
      #|      global.get $guard
      #|    end
      #|    extern.convert_any
      #|    any.convert_extern
      #|    ref.is_null
      #|    call $use
      #|    if
      #|      ref.null any
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::any())),
      ),
      true,
    ),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps nullable i31-get arm flow conservative" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut i31ref) (ref.null i31))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result i31ref)
      #|      ref.null i31
      #|    else
      #|      global.get $guard
      #|    end
      #|    i31.get_s
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      ref.i31
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::i31())),
      ),
      true,
    ),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through int-to-float conversion" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      global.get $guard
      #|    end
      #|    f64.convert_i32_s
      #|    f64.const 0
      #|    f64.ne
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through demote and float div" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut f64) (f64.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      call $cond
      #|      if (result f64)
      #|        f64.const 0
      #|      else
      #|        global.get $guard
      #|      end
      #|      f32.demote_f64
      #|      f32.const 2
      #|      f32.div
      #|      f32.const 0
      #|      f32.ne
      #|    end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through saturating float truncation" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut f32) (f32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result f32)
      #|      f32.const 0
      #|    else
      #|      global.get $guard
      #|    end
      #|    i32.trunc_sat_f32_s
      #|    i32.eqz
      #|    if
      #|      f32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps trapping float truncation arm flow conservative" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut f32) (f32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result f32)
      #|      f32.const 0
      #|    else
      #|      global.get $guard
      #|    end
      #|    i32.trunc_f32_s
      #|    i32.eqz
      #|    if
      #|      f32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::f32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes read-only-to-write guards through memory size" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    memory.size
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through table size" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      global.get $guard
      #|    end
      #|    table.size 0
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through clean i64 load" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    i64.load
      #|    i64.eqz
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i64.load"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through clean table get" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 funcref)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    i32.const 0
      #|    table.get 0
      #|    ref.is_null
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      global.get $guard
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("table.get"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps global-derived load and table get" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (table 1 funcref)
      #|  (global $load (mut i32) (i32.const 0))
      #|  (global $table (mut i32) (i32.const 0))
      #|  (func (export "load")
      #|    global.get $load
      #|    i64.load
      #|    i64.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $load
      #|    end)
      #|  (func (export "table")
      #|    global.get $table
      #|    table.get 0
      #|    ref.is_null
      #|    if
      #|      i32.const 1
      #|      global.set $table
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
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("i64.load"), msg=pretty)
  assert_true(pretty.contains("table.get"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps memory grow fed by the global" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1 10)
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps table grow fed by the global" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (table 1 10 funcref)
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes read-only-to-write guards through simd splat all-true" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i32x4.splat
      #|    i32x4.all_true
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes read-only-to-write guards through simd binary op" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i32x4.splat
      #|    v128.const i32x4 1 1 1 1
      #|    i32x4.add
      #|    i32x4.all_true
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes read-only-to-write guards through simd extract lane" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i32x4.splat
      #|    i32x4.extract_lane 0
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes v128 read-only-to-write guards through simd unary op" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut v128) (v128.const i32x4 0 0 0 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i32x4.neg
      #|    i32x4.all_true
      #|    if
      #|      v128.const i32x4 1 1 1 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::v128(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes read-only-to-write guards through i8x16 popcnt bitmask" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i8x16.splat
      #|    i8x16.popcnt
      #|    i8x16.bitmask
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes read-only-to-write guards through i16x8 all-true" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i16x8.splat
      #|    i16x8.neg
      #|    i16x8.all_true
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes read-only-to-write guards through i64x2 bitmask" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i64) (i64.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i64x2.splat
      #|    i64x2.neg
      #|    i64x2.bitmask
      #|    i32.eqz
      #|    if
      #|      i64.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i64(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes read-only-to-write guards through float simd compares" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $f32 (mut f32) (f32.const 0))
      #|  (global $f64 (mut f64) (f64.const 0))
      #|  (func (export "run_f32")
      #|    global.get $f32
      #|    f32x4.splat
      #|    f32x4.abs
      #|    v128.const f32x4 0 0 0 0
      #|    f32x4.ne
      #|    i32x4.all_true
      #|    if
      #|      f32.const 1
      #|      global.set $f32
      #|    end)
      #|  (func (export "run_f64")
      #|    global.get $f64
      #|    f64x2.splat
      #|    f64x2.neg
      #|    v128.const f64x2 0 0
      #|    f64x2.ne
      #|    i64x2.all_true
      #|    if
      #|      f64.const 1
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
  let pretty_f32 = optimized.pretty_print_defined_func(0U)
  assert_false(pretty_f32.contains("global.get"), msg=pretty_f32)
  assert_false(pretty_f32.contains("global.set"), msg=pretty_f32)
  let pretty_f64 = optimized.pretty_print_defined_func(1U)
  assert_false(pretty_f64.contains("global.get"), msg=pretty_f64)
  assert_false(pretty_f64.contains("global.set"), msg=pretty_f64)
}

///|
test "simplify-globals-optimizing removes broader simd unary read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $i8 (mut i32) (i32.const 0))
      #|  (global $i16_abs (mut i32) (i32.const 0))
      #|  (global $i16_bits (mut i32) (i32.const 0))
      #|  (global $i32_bits (mut i32) (i32.const 0))
      #|  (global $f32_neg (mut f32) (f32.const 0))
      #|  (global $f32_sqrt (mut f32) (f32.const 0))
      #|  (global $f64_abs (mut f64) (f64.const 0))
      #|  (func (export "i8")
      #|    global.get $i8
      #|    i8x16.splat
      #|    i8x16.all_true
      #|    if
      #|      i32.const 1
      #|      global.set $i8
      #|    end)
      #|  (func (export "i16_abs")
      #|    global.get $i16_abs
      #|    i16x8.splat
      #|    i16x8.abs
      #|    i16x8.all_true
      #|    if
      #|      i32.const 1
      #|      global.set $i16_abs
      #|    end)
      #|  (func (export "i16_bits")
      #|    global.get $i16_bits
      #|    i16x8.splat
      #|    i16x8.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $i16_bits
      #|    end)
      #|  (func (export "i32_bits")
      #|    global.get $i32_bits
      #|    i32x4.splat
      #|    i32x4.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $i32_bits
      #|    end)
      #|  (func (export "f32_neg")
      #|    global.get $f32_neg
      #|    f32x4.splat
      #|    f32x4.neg
      #|    v128.const f32x4 0 0 0 0
      #|    f32x4.ne
      #|    i32x4.all_true
      #|    if
      #|      f32.const 1
      #|      global.set $f32_neg
      #|    end)
      #|  (func (export "f32_sqrt")
      #|    global.get $f32_sqrt
      #|    f32x4.splat
      #|    f32x4.sqrt
      #|    v128.const f32x4 0 0 0 0
      #|    f32x4.ne
      #|    i32x4.all_true
      #|    if
      #|      f32.const 1
      #|      global.set $f32_sqrt
      #|    end)
      #|  (func (export "f64_abs")
      #|    global.get $f64_abs
      #|    f64x2.splat
      #|    f64x2.abs
      #|    v128.const f64x2 0 0
      #|    f64x2.ne
      #|    i64x2.all_true
      #|    if
      #|      f64.const 1
      #|      global.set $f64_abs
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
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 3),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 4),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 5),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 6),
    @lib.GlobalType::new(@lib.ValType::f64(), false),
  )
  let pretty = optimized.to_string()
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes broader simd binary read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $i8 (mut i32) (i32.const 0))
      #|  (global $i16 (mut i32) (i32.const 0))
      #|  (global $i32 (mut i32) (i32.const 0))
      #|  (global $i64 (mut i64) (i64.const 0))
      #|  (global $f32 (mut f32) (f32.const 1))
      #|  (global $f64 (mut f64) (f64.const 1))
      #|  (func (export "i8")
      #|    global.get $i8
      #|    i8x16.splat
      #|    v128.const i32x4 1 1 1 1
      #|    i8x16.add
      #|    i8x16.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $i8
      #|    end)
      #|  (func (export "i16")
      #|    global.get $i16
      #|    i16x8.splat
      #|    v128.const i32x4 0 0 0 0
      #|    i16x8.eq
      #|    i16x8.all_true
      #|    if
      #|      i32.const 1
      #|      global.set $i16
      #|    end)
      #|  (func (export "i32")
      #|    global.get $i32
      #|    i32x4.splat
      #|    v128.const i32x4 0 0 0 0
      #|    i32x4.eq
      #|    i32x4.all_true
      #|    if
      #|      i32.const 1
      #|      global.set $i32
      #|    end)
      #|  (func (export "i64")
      #|    global.get $i64
      #|    i64x2.splat
      #|    v128.const i64x2 0 0
      #|    i64x2.eq
      #|    i64x2.all_true
      #|    if
      #|      i64.const 1
      #|      global.set $i64
      #|    end)
      #|  (func (export "f32")
      #|    global.get $f32
      #|    f32x4.splat
      #|    v128.const f32x4 1 1 1 1
      #|    f32x4.div
      #|    v128.const f32x4 0 0 0 0
      #|    f32x4.ne
      #|    i32x4.all_true
      #|    if
      #|      f32.const 2
      #|      global.set $f32
      #|    end)
      #|  (func (export "f64")
      #|    global.get $f64
      #|    f64x2.splat
      #|    v128.const f64x2 1 1
      #|    f64x2.add
      #|    v128.const f64x2 0 0
      #|    f64x2.ne
      #|    i64x2.all_true
      #|    if
      #|      f64.const 2
      #|      global.set $f64
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
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 3),
    @lib.GlobalType::new(@lib.ValType::i64(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 4),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 5),
    @lib.GlobalType::new(@lib.ValType::f64(), false),
  )
  let pretty = optimized.to_string()
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block-wrapped simd binary if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut f32) (f32.const 1))
      #|  (func (export "run")
      #|    block (result i32)
      #|      global.get $guard
      #|      f32x4.splat
      #|      v128.const f32x4 1 1 1 1
      #|      f32x4.div
      #|      v128.const f32x4 0 0 0 0
      #|      f32x4.ne
      #|      i32x4.all_true
      #|    end
      #|    if
      #|      return
      #|    end
      #|    f32.const 2
      #|    global.set $guard))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes clean if-wrapper simd binary guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut i64) (i64.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      call $cond
      #|      if (result i32)
      #|        global.get $guard
      #|        i64x2.splat
      #|        v128.const i64x2 0 0
      #|        i64x2.eq
      #|        i64x2.all_true
      #|      else
      #|        i32.const 0
      #|      end
      #|    end
      #|    if
      #|      i64.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i64(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes simd lane read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $i8 (mut i32) (i32.const 0))
      #|  (global $i16 (mut i32) (i32.const 0))
      #|  (global $i64 (mut i64) (i64.const 0))
      #|  (global $f32 (mut f32) (f32.const 0))
      #|  (global $f64 (mut f64) (f64.const 0))
      #|  (func (export "i8")
      #|    global.get $i8
      #|    i8x16.splat
      #|    i8x16.extract_lane_s 0
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $i8
      #|    end)
      #|  (func (export "i16")
      #|    global.get $i16
      #|    i16x8.splat
      #|    i16x8.extract_lane_u 1
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $i16
      #|    end)
      #|  (func (export "i64")
      #|    global.get $i64
      #|    i64x2.splat
      #|    i64x2.extract_lane 1
      #|    i64.eqz
      #|    if
      #|      i64.const 1
      #|      global.set $i64
      #|    end)
      #|  (func (export "f32")
      #|    global.get $f32
      #|    f32x4.splat
      #|    f32x4.extract_lane 2
      #|    f32.const 0
      #|    f32.eq
      #|    if
      #|      f32.const 1
      #|      global.set $f32
      #|    end)
      #|  (func (export "f64")
      #|    global.get $f64
      #|    f64x2.splat
      #|    f64x2.extract_lane 1
      #|    f64.const 0
      #|    f64.eq
      #|    if
      #|      f64.const 1
      #|      global.set $f64
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
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(@lib.ValType::i64(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 3),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 4),
    @lib.GlobalType::new(@lib.ValType::f64(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U) +
    optimized.pretty_print_defined_func(2U) +
    optimized.pretty_print_defined_func(3U) +
    optimized.pretty_print_defined_func(4U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes simd replace-lane read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $i8 (mut i32) (i32.const 0))
      #|  (global $i32 (mut i32) (i32.const 0))
      #|  (global $f32 (mut f32) (f32.const 0))
      #|  (global $f64 (mut f64) (f64.const 0))
      #|  (func (export "i8")
      #|    v128.const i32x4 0 0 0 0
      #|    global.get $i8
      #|    i8x16.replace_lane 0
      #|    i8x16.bitmask
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $i8
      #|    end)
      #|  (func (export "i32")
      #|    v128.const i32x4 0 0 0 0
      #|    global.get $i32
      #|    i32x4.replace_lane 2
      #|    i32x4.bitmask
      #|    i32.eqz
      #|    if
      #|      i32.const 1
      #|      global.set $i32
      #|    end)
      #|  (func (export "f32")
      #|    v128.const f32x4 0 0 0 0
      #|    global.get $f32
      #|    f32x4.replace_lane 3
      #|    v128.const f32x4 0 0 0 0
      #|    f32x4.ne
      #|    i32x4.all_true
      #|    if
      #|      f32.const 1
      #|      global.set $f32
      #|    end)
      #|  (func (export "f64")
      #|    v128.const f64x2 0 0
      #|    global.get $f64
      #|    f64x2.replace_lane 1
      #|    v128.const f64x2 0 0
      #|    f64x2.ne
      #|    i64x2.all_true
      #|    if
      #|      f64.const 1
      #|      global.set $f64
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
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 3),
    @lib.GlobalType::new(@lib.ValType::f64(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U) +
    optimized.pretty_print_defined_func(2U) +
    optimized.pretty_print_defined_func(3U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes simd shift read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $i8 (mut i32) (i32.const 0))
      #|  (global $i16 (mut i32) (i32.const 0))
      #|  (global $i32 (mut i32) (i32.const 0))
      #|  (global $i64 (mut i64) (i64.const 0))
      #|  (func (export "i8")
      #|    global.get $i8
      #|    i8x16.splat
      #|    i32.const 1
      #|    i8x16.shl
      #|    i8x16.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $i8
      #|    end)
      #|  (func (export "i16")
      #|    global.get $i16
      #|    i16x8.splat
      #|    i32.const 2
      #|    i16x8.shr_s
      #|    i16x8.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $i16
      #|    end)
      #|  (func (export "i32")
      #|    global.get $i32
      #|    i32x4.splat
      #|    i32.const 3
      #|    i32x4.shr_u
      #|    i32x4.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $i32
      #|    end)
      #|  (func (export "i64")
      #|    global.get $i64
      #|    i64x2.splat
      #|    i32.const 4
      #|    i64x2.shl
      #|    i64x2.bitmask
      #|    if
      #|      i64.const 1
      #|      global.set $i64
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
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 3),
    @lib.GlobalType::new(@lib.ValType::i64(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U) +
    optimized.pretty_print_defined_func(2U) +
    optimized.pretty_print_defined_func(3U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block-wrapped simd shift if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      global.get $guard
      #|      i16x8.splat
      #|      i32.const 2
      #|      i16x8.shr_u
      #|      i16x8.bitmask
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes clean if-wrapper simd replace-lane guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut f64) (f64.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      call $cond
      #|      if (result i32)
      #|        v128.const f64x2 0 0
      #|        global.get $guard
      #|        f64x2.replace_lane 1
      #|        v128.const f64x2 0 0
      #|        f64x2.ne
      #|        i64x2.all_true
      #|      else
      #|        i32.const 0
      #|      end
      #|    end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes broader simd integer compare read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $i8_ne (mut i32) (i32.const 0))
      #|  (global $i8_lt_u (mut i32) (i32.const 0))
      #|  (global $i8_ge_s (mut i32) (i32.const 0))
      #|  (global $i16_ne (mut i32) (i32.const 0))
      #|  (global $i16_gt_u (mut i32) (i32.const 0))
      #|  (global $i32_le_s (mut i32) (i32.const 0))
      #|  (global $i32_ge_u (mut i32) (i32.const 0))
      #|  (global $i64_ne (mut i64) (i64.const 0))
      #|  (global $i64_lt_s (mut i64) (i64.const 0))
      #|  (global $i64_ge_s (mut i64) (i64.const 0))
      #|  (func (export "i8_ne")
      #|    global.get $i8_ne
      #|    i8x16.splat
      #|    v128.const i32x4 0 0 0 0
      #|    i8x16.ne
      #|    i8x16.all_true
      #|    if
      #|      i32.const 1
      #|      global.set $i8_ne
      #|    end)
      #|  (func (export "i8_lt_u")
      #|    global.get $i8_lt_u
      #|    i8x16.splat
      #|    v128.const i32x4 0 0 0 0
      #|    i8x16.lt_u
      #|    i8x16.all_true
      #|    if
      #|      i32.const 1
      #|      global.set $i8_lt_u
      #|    end)
      #|  (func (export "i8_ge_s")
      #|    global.get $i8_ge_s
      #|    i8x16.splat
      #|    v128.const i32x4 0 0 0 0
      #|    i8x16.ge_s
      #|    i8x16.all_true
      #|    if
      #|      i32.const 1
      #|      global.set $i8_ge_s
      #|    end)
      #|  (func (export "i16_ne")
      #|    global.get $i16_ne
      #|    i16x8.splat
      #|    v128.const i32x4 0 0 0 0
      #|    i16x8.ne
      #|    i16x8.all_true
      #|    if
      #|      i32.const 1
      #|      global.set $i16_ne
      #|    end)
      #|  (func (export "i16_gt_u")
      #|    global.get $i16_gt_u
      #|    i16x8.splat
      #|    v128.const i32x4 0 0 0 0
      #|    i16x8.gt_u
      #|    i16x8.all_true
      #|    if
      #|      i32.const 1
      #|      global.set $i16_gt_u
      #|    end)
      #|  (func (export "i32_le_s")
      #|    global.get $i32_le_s
      #|    i32x4.splat
      #|    v128.const i32x4 0 0 0 0
      #|    i32x4.le_s
      #|    i32x4.all_true
      #|    if
      #|      i32.const 1
      #|      global.set $i32_le_s
      #|    end)
      #|  (func (export "i32_ge_u")
      #|    global.get $i32_ge_u
      #|    i32x4.splat
      #|    v128.const i32x4 0 0 0 0
      #|    i32x4.ge_u
      #|    i32x4.all_true
      #|    if
      #|      i32.const 1
      #|      global.set $i32_ge_u
      #|    end)
      #|  (func (export "i64_ne")
      #|    global.get $i64_ne
      #|    i64x2.splat
      #|    v128.const i64x2 0 0
      #|    i64x2.ne
      #|    i64x2.all_true
      #|    if
      #|      i64.const 1
      #|      global.set $i64_ne
      #|    end)
      #|  (func (export "i64_lt_s")
      #|    global.get $i64_lt_s
      #|    i64x2.splat
      #|    v128.const i64x2 0 0
      #|    i64x2.lt_s
      #|    i64x2.all_true
      #|    if
      #|      i64.const 1
      #|      global.set $i64_lt_s
      #|    end)
      #|  (func (export "i64_ge_s")
      #|    global.get $i64_ge_s
      #|    i64x2.splat
      #|    v128.const i64x2 0 0
      #|    i64x2.ge_s
      #|    i64x2.all_true
      #|    if
      #|      i64.const 1
      #|      global.set $i64_ge_s
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 7; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), false),
    )
  }
  for i = 7; i < 10; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i64(), false),
    )
  }
  let pretty = optimized.to_string()
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes broader simd float compare read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $f32_eq (mut f32) (f32.const 0))
      #|  (global $f32_lt (mut f32) (f32.const 0))
      #|  (global $f32_ge (mut f32) (f32.const 0))
      #|  (global $f64_eq (mut f64) (f64.const 0))
      #|  (global $f64_gt (mut f64) (f64.const 0))
      #|  (global $f64_le (mut f64) (f64.const 0))
      #|  (func (export "f32_eq")
      #|    global.get $f32_eq
      #|    f32x4.splat
      #|    v128.const f32x4 0 0 0 0
      #|    f32x4.eq
      #|    i32x4.all_true
      #|    if
      #|      f32.const 1
      #|      global.set $f32_eq
      #|    end)
      #|  (func (export "f32_lt")
      #|    global.get $f32_lt
      #|    f32x4.splat
      #|    v128.const f32x4 0 0 0 0
      #|    f32x4.lt
      #|    i32x4.all_true
      #|    if
      #|      f32.const 1
      #|      global.set $f32_lt
      #|    end)
      #|  (func (export "f32_ge")
      #|    global.get $f32_ge
      #|    f32x4.splat
      #|    v128.const f32x4 0 0 0 0
      #|    f32x4.ge
      #|    i32x4.all_true
      #|    if
      #|      f32.const 1
      #|      global.set $f32_ge
      #|    end)
      #|  (func (export "f64_eq")
      #|    global.get $f64_eq
      #|    f64x2.splat
      #|    v128.const f64x2 0 0
      #|    f64x2.eq
      #|    i64x2.all_true
      #|    if
      #|      f64.const 1
      #|      global.set $f64_eq
      #|    end)
      #|  (func (export "f64_gt")
      #|    global.get $f64_gt
      #|    f64x2.splat
      #|    v128.const f64x2 0 0
      #|    f64x2.gt
      #|    i64x2.all_true
      #|    if
      #|      f64.const 1
      #|      global.set $f64_gt
      #|    end)
      #|  (func (export "f64_le")
      #|    global.get $f64_le
      #|    f64x2.splat
      #|    v128.const f64x2 0 0
      #|    f64x2.le
      #|    i64x2.all_true
      #|    if
      #|      f64.const 1
      #|      global.set $f64_le
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 3; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::f32(), false),
    )
  }
  for i = 3; i < 6; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::f64(), false),
    )
  }
  let pretty = optimized.to_string()
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes wrapped simd compare guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $i8 (mut i32) (i32.const 0))
      #|  (global $f64 (mut f64) (f64.const 0))
      #|  (func (export "block_return")
      #|    block (result i32)
      #|      global.get $i8
      #|      i8x16.splat
      #|      v128.const i32x4 0 0 0 0
      #|      i8x16.ge_u
      #|      i8x16.all_true
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $i8)
      #|  (func (export "if_wrapper")
      #|    block (result i32)
      #|      call $cond
      #|      if (result i32)
      #|        global.get $f64
      #|        f64x2.splat
      #|        v128.const f64x2 0 0
      #|        f64x2.le
      #|        i64x2.all_true
      #|      else
      #|        i32.const 0
      #|      end
      #|    end
      #|    if
      #|      f64.const 1
      #|      global.set $f64
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
    @lib.GlobalType::new(@lib.ValType::f64(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps simd compare flow into post-consumer call" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "use" (func $use (param i32) (result i32)))
      #|  (global $i32 (mut i32) (i32.const 0))
      #|  (global $f64 (mut f64) (f64.const 0))
      #|  (func (export "i32")
      #|    global.get $i32
      #|    i32x4.splat
      #|    v128.const i32x4 0 0 0 0
      #|    i32x4.ge_u
      #|    i32x4.all_true
      #|    call $use
      #|    if
      #|      i32.const 1
      #|      global.set $i32
      #|    end)
      #|  (func (export "f64")
      #|    global.get $f64
      #|    f64x2.splat
      #|    v128.const f64x2 0 0
      #|    f64x2.le
      #|    i64x2.all_true
      #|    call $use
      #|    if
      #|      f64.const 1
      #|      global.set $f64
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
    @lib.GlobalType::new(@lib.ValType::f64(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes broader simd unary arithmetic read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $i8_abs (mut i32) (i32.const 0))
      #|  (global $i8_neg (mut i32) (i32.const 0))
      #|  (global $i32_abs (mut i32) (i32.const 0))
      #|  (global $i64_abs (mut i64) (i64.const 0))
      #|  (global $f32_ceil (mut f32) (f32.const 1))
      #|  (global $f64_sqrt (mut f64) (f64.const 1))
      #|  (global $f64_nearest (mut f64) (f64.const 1))
      #|  (func (export "i8_abs")
      #|    global.get $i8_abs
      #|    i8x16.splat
      #|    i8x16.abs
      #|    i8x16.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $i8_abs
      #|    end)
      #|  (func (export "i8_neg")
      #|    global.get $i8_neg
      #|    i8x16.splat
      #|    i8x16.neg
      #|    i8x16.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $i8_neg
      #|    end)
      #|  (func (export "i32_abs")
      #|    global.get $i32_abs
      #|    i32x4.splat
      #|    i32x4.abs
      #|    i32x4.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $i32_abs
      #|    end)
      #|  (func (export "i64_abs")
      #|    global.get $i64_abs
      #|    i64x2.splat
      #|    i64x2.abs
      #|    i64x2.bitmask
      #|    if
      #|      i64.const 1
      #|      global.set $i64_abs
      #|    end)
      #|  (func (export "f32_ceil")
      #|    global.get $f32_ceil
      #|    f32x4.splat
      #|    f32x4.ceil
      #|    v128.const f32x4 0 0 0 0
      #|    f32x4.ne
      #|    i32x4.all_true
      #|    if
      #|      f32.const 2
      #|      global.set $f32_ceil
      #|    end)
      #|  (func (export "f64_sqrt")
      #|    global.get $f64_sqrt
      #|    f64x2.splat
      #|    f64x2.sqrt
      #|    v128.const f64x2 0 0
      #|    f64x2.ne
      #|    i64x2.all_true
      #|    if
      #|      f64.const 2
      #|      global.set $f64_sqrt
      #|    end)
      #|  (func (export "f64_nearest")
      #|    global.get $f64_nearest
      #|    f64x2.splat
      #|    f64x2.nearest
      #|    v128.const f64x2 0 0
      #|    f64x2.ne
      #|    i64x2.all_true
      #|    if
      #|      f64.const 2
      #|      global.set $f64_nearest
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
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 3),
    @lib.GlobalType::new(@lib.ValType::i64(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 4),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  for i = 5; i < 7; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::f64(), false),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U) +
    optimized.pretty_print_defined_func(2U) +
    optimized.pretty_print_defined_func(3U) +
    optimized.pretty_print_defined_func(4U) +
    optimized.pretty_print_defined_func(5U) +
    optimized.pretty_print_defined_func(6U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes broader simd integer arithmetic read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $i8_sat (mut i32) (i32.const 0))
      #|  (global $i8_avgr (mut i32) (i32.const 0))
      #|  (global $i16_sat (mut i32) (i32.const 0))
      #|  (global $i16_mul (mut i32) (i32.const 0))
      #|  (global $i32_min (mut i32) (i32.const 0))
      #|  (global $i32_max (mut i32) (i32.const 0))
      #|  (global $i64_add (mut i64) (i64.const 0))
      #|  (global $i64_mul (mut i64) (i64.const 0))
      #|  (func (export "i8_sat")
      #|    global.get $i8_sat
      #|    i8x16.splat
      #|    v128.const i32x4 1 1 1 1
      #|    i8x16.sub_sat_s
      #|    i8x16.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $i8_sat
      #|    end)
      #|  (func (export "i8_avgr")
      #|    global.get $i8_avgr
      #|    i8x16.splat
      #|    v128.const i32x4 1 1 1 1
      #|    i8x16.avgr_u
      #|    i8x16.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $i8_avgr
      #|    end)
      #|  (func (export "i16_sat")
      #|    global.get $i16_sat
      #|    i16x8.splat
      #|    v128.const i32x4 1 1 1 1
      #|    i16x8.add_sat_u
      #|    i16x8.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $i16_sat
      #|    end)
      #|  (func (export "i16_mul")
      #|    global.get $i16_mul
      #|    i16x8.splat
      #|    v128.const i32x4 1 1 1 1
      #|    i16x8.mul
      #|    i16x8.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $i16_mul
      #|    end)
      #|  (func (export "i32_min")
      #|    global.get $i32_min
      #|    i32x4.splat
      #|    v128.const i32x4 1 1 1 1
      #|    i32x4.min_u
      #|    i32x4.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $i32_min
      #|    end)
      #|  (func (export "i32_max")
      #|    global.get $i32_max
      #|    i32x4.splat
      #|    v128.const i32x4 1 1 1 1
      #|    i32x4.max_s
      #|    i32x4.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $i32_max
      #|    end)
      #|  (func (export "i64_add")
      #|    global.get $i64_add
      #|    i64x2.splat
      #|    v128.const i64x2 1 1
      #|    i64x2.add
      #|    i64x2.bitmask
      #|    if
      #|      i64.const 1
      #|      global.set $i64_add
      #|    end)
      #|  (func (export "i64_mul")
      #|    global.get $i64_mul
      #|    i64x2.splat
      #|    v128.const i64x2 1 1
      #|    i64x2.mul
      #|    i64x2.bitmask
      #|    if
      #|      i64.const 1
      #|      global.set $i64_mul
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 6; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), false),
    )
  }
  for i = 6; i < 8; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i64(), false),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U) +
    optimized.pretty_print_defined_func(2U) +
    optimized.pretty_print_defined_func(3U) +
    optimized.pretty_print_defined_func(4U) +
    optimized.pretty_print_defined_func(5U) +
    optimized.pretty_print_defined_func(6U) +
    optimized.pretty_print_defined_func(7U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes broader simd float arithmetic read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $f32_add (mut f32) (f32.const 1))
      #|  (global $f32_max (mut f32) (f32.const 1))
      #|  (global $f32_pmin (mut f32) (f32.const 1))
      #|  (global $f64_sub (mut f64) (f64.const 1))
      #|  (global $f64_div (mut f64) (f64.const 1))
      #|  (global $f64_pmax (mut f64) (f64.const 1))
      #|  (func (export "f32_add")
      #|    global.get $f32_add
      #|    f32x4.splat
      #|    v128.const f32x4 1 1 1 1
      #|    f32x4.add
      #|    v128.const f32x4 0 0 0 0
      #|    f32x4.ne
      #|    i32x4.all_true
      #|    if
      #|      f32.const 2
      #|      global.set $f32_add
      #|    end)
      #|  (func (export "f32_max")
      #|    global.get $f32_max
      #|    f32x4.splat
      #|    v128.const f32x4 1 1 1 1
      #|    f32x4.max
      #|    v128.const f32x4 0 0 0 0
      #|    f32x4.ne
      #|    i32x4.all_true
      #|    if
      #|      f32.const 2
      #|      global.set $f32_max
      #|    end)
      #|  (func (export "f32_pmin")
      #|    global.get $f32_pmin
      #|    f32x4.splat
      #|    v128.const f32x4 1 1 1 1
      #|    f32x4.pmin
      #|    v128.const f32x4 0 0 0 0
      #|    f32x4.ne
      #|    i32x4.all_true
      #|    if
      #|      f32.const 2
      #|      global.set $f32_pmin
      #|    end)
      #|  (func (export "f64_sub")
      #|    global.get $f64_sub
      #|    f64x2.splat
      #|    v128.const f64x2 1 1
      #|    f64x2.sub
      #|    v128.const f64x2 0 0
      #|    f64x2.ne
      #|    i64x2.all_true
      #|    if
      #|      f64.const 2
      #|      global.set $f64_sub
      #|    end)
      #|  (func (export "f64_div")
      #|    global.get $f64_div
      #|    f64x2.splat
      #|    v128.const f64x2 1 1
      #|    f64x2.div
      #|    v128.const f64x2 0 0
      #|    f64x2.ne
      #|    i64x2.all_true
      #|    if
      #|      f64.const 2
      #|      global.set $f64_div
      #|    end)
      #|  (func (export "f64_pmax")
      #|    global.get $f64_pmax
      #|    f64x2.splat
      #|    v128.const f64x2 1 1
      #|    f64x2.pmax
      #|    v128.const f64x2 0 0
      #|    f64x2.ne
      #|    i64x2.all_true
      #|    if
      #|      f64.const 2
      #|      global.set $f64_pmax
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 3; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::f32(), false),
    )
  }
  for i = 3; i < 6; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::f64(), false),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U) +
    optimized.pretty_print_defined_func(2U) +
    optimized.pretty_print_defined_func(3U) +
    optimized.pretty_print_defined_func(4U) +
    optimized.pretty_print_defined_func(5U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes wrapped simd arithmetic guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $i8 (mut i32) (i32.const 0))
      #|  (global $f64 (mut f64) (f64.const 1))
      #|  (func (export "block_return")
      #|    block (result i32)
      #|      global.get $f64
      #|      f64x2.splat
      #|      f64x2.sqrt
      #|      v128.const f64x2 1 1
      #|      f64x2.div
      #|      v128.const f64x2 0 0
      #|      f64x2.ne
      #|      i64x2.all_true
      #|    end
      #|    if
      #|      return
      #|    end
      #|    f64.const 2
      #|    global.set $f64)
      #|  (func (export "if_wrapper")
      #|    block (result i32)
      #|      call $cond
      #|      if (result i32)
      #|        global.get $i8
      #|        i8x16.splat
      #|        v128.const i32x4 1 1 1 1
      #|        i8x16.avgr_u
      #|        i8x16.bitmask
      #|      else
      #|        i32.const 0
      #|      end
      #|    end
      #|    if
      #|      i32.const 1
      #|      global.set $i8
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
    @lib.GlobalType::new(@lib.ValType::f64(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps simd arithmetic flow into post-consumer call" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "use" (func $use (param i32) (result i32)))
      #|  (global $i8 (mut i32) (i32.const 0))
      #|  (global $f64 (mut f64) (f64.const 1))
      #|  (func (export "i8")
      #|    global.get $i8
      #|    i8x16.splat
      #|    v128.const i32x4 1 1 1 1
      #|    i8x16.sub_sat_s
      #|    i8x16.bitmask
      #|    call $use
      #|    if
      #|      i32.const 1
      #|      global.set $i8
      #|    end)
      #|  (func (export "f64")
      #|    global.get $f64
      #|    f64x2.splat
      #|    f64x2.sqrt
      #|    v128.const f64x2 1 1
      #|    f64x2.div
      #|    v128.const f64x2 0 0
      #|    f64x2.ne
      #|    i64x2.all_true
      #|    call $use
      #|    if
      #|      f64.const 2
      #|      global.set $f64
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
    @lib.GlobalType::new(@lib.ValType::f64(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes simd extension and conversion read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $extend (mut i32) (i32.const 0))
      #|  (global $demote (mut f64) (f64.const 1))
      #|  (global $promote (mut f32) (f32.const 1))
      #|  (global $convert (mut i32) (i32.const 0))
      #|  (global $trunc (mut f32) (f32.const 1))
      #|  (func (export "extend")
      #|    global.get $extend
      #|    i8x16.splat
      #|    i16x8.extend_low_i8x16_s
      #|    i16x8.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $extend
      #|    end)
      #|  (func (export "demote")
      #|    global.get $demote
      #|    f64x2.splat
      #|    f32x4.demote_f64x2_zero
      #|    v128.const f32x4 0 0 0 0
      #|    f32x4.ne
      #|    i32x4.all_true
      #|    if
      #|      f64.const 2
      #|      global.set $demote
      #|    end)
      #|  (func (export "promote")
      #|    global.get $promote
      #|    f32x4.splat
      #|    f64x2.promote_low_f32x4
      #|    v128.const f64x2 0 0
      #|    f64x2.ne
      #|    i64x2.all_true
      #|    if
      #|      f32.const 2
      #|      global.set $promote
      #|    end)
      #|  (func (export "convert")
      #|    global.get $convert
      #|    i32x4.splat
      #|    f64x2.convert_low_i32x4_s
      #|    v128.const f64x2 0 0
      #|    f64x2.ne
      #|    i64x2.all_true
      #|    if
      #|      i32.const 1
      #|      global.set $convert
      #|    end)
      #|  (func (export "trunc")
      #|    global.get $trunc
      #|    f32x4.splat
      #|    i32x4.trunc_sat_f32x4_u
      #|    i32x4.bitmask
      #|    if
      #|      f32.const 2
      #|      global.set $trunc
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
    @lib.GlobalType::new(@lib.ValType::f64(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 3),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 4),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U) +
    optimized.pretty_print_defined_func(2U) +
    optimized.pretty_print_defined_func(3U) +
    optimized.pretty_print_defined_func(4U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes simd narrow extmul and dot read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $narrow8 (mut i32) (i32.const 0))
      #|  (global $narrow16 (mut i32) (i32.const 0))
      #|  (global $extmul16 (mut i32) (i32.const 0))
      #|  (global $extmul64 (mut i64) (i64.const 0))
      #|  (global $dot (mut i32) (i32.const 0))
      #|  (func (export "narrow8")
      #|    global.get $narrow8
      #|    i16x8.splat
      #|    v128.const i32x4 1 1 1 1
      #|    i8x16.narrow_i16x8_s
      #|    i8x16.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $narrow8
      #|    end)
      #|  (func (export "narrow16")
      #|    global.get $narrow16
      #|    i32x4.splat
      #|    v128.const i32x4 1 1 1 1
      #|    i16x8.narrow_i32x4_u
      #|    i16x8.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $narrow16
      #|    end)
      #|  (func (export "extmul16")
      #|    global.get $extmul16
      #|    i8x16.splat
      #|    v128.const i32x4 1 1 1 1
      #|    i16x8.extmul_high_i8x16_u
      #|    i16x8.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $extmul16
      #|    end)
      #|  (func (export "extmul64")
      #|    global.get $extmul64
      #|    i64x2.splat
      #|    v128.const i32x4 1 1 1 1
      #|    i64x2.extmul_low_i32x4_s
      #|    i64x2.bitmask
      #|    if
      #|      i64.const 1
      #|      global.set $extmul64
      #|    end)
      #|  (func (export "dot")
      #|    global.get $dot
      #|    i16x8.splat
      #|    v128.const i32x4 1 1 1 1
      #|    i32x4.dot_i16x8_s
      #|    i32x4.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $dot
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
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 3),
    @lib.GlobalType::new(@lib.ValType::i64(), false),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 4),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U) +
    optimized.pretty_print_defined_func(2U) +
    optimized.pretty_print_defined_func(3U) +
    optimized.pretty_print_defined_func(4U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes simd extadd pairwise read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $i16s (mut i32) (i32.const 0))
      #|  (global $i16u (mut i32) (i32.const 0))
      #|  (global $i32s (mut i32) (i32.const 0))
      #|  (global $i32u (mut i32) (i32.const 0))
      #|  (func (export "i16s")
      #|    global.get $i16s
      #|    i8x16.splat
      #|    i16x8.extadd_pairwise_i8x16_s
      #|    i16x8.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $i16s
      #|    end)
      #|  (func (export "i16u")
      #|    global.get $i16u
      #|    i8x16.splat
      #|    i16x8.extadd_pairwise_i8x16_u
      #|    i16x8.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $i16u
      #|    end)
      #|  (func (export "i32s")
      #|    global.get $i32s
      #|    i16x8.splat
      #|    i32x4.extadd_pairwise_i16x8_s
      #|    i32x4.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $i32s
      #|    end)
      #|  (func (export "i32u")
      #|    global.get $i32u
      #|    i16x8.splat
      #|    i32x4.extadd_pairwise_i16x8_u
      #|    i32x4.bitmask
      #|    if
      #|      i32.const 1
      #|      global.set $i32u
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 4; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), false),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U) +
    optimized.pretty_print_defined_func(2U) +
    optimized.pretty_print_defined_func(3U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps simd extadd pairwise flow into post-consumer call" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "use" (func $use (param i32) (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i8x16.splat
      #|    i16x8.extadd_pairwise_i8x16_s
      #|    i16x8.bitmask
      #|    call $use
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes ref.test read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $direct (mut eqref) (ref.i31 (i32.const 0)))
      #|  (global $wrapped (mut eqref) (ref.i31 (i32.const 1)))
      #|  (func (export "direct")
      #|    global.get $direct
      #|    ref.test (ref i31)
      #|    if
      #|      ref.null eq
      #|      global.set $direct
      #|    end)
      #|  (func (export "wrapped")
      #|    block (result i32)
      #|      global.get $wrapped
      #|      ref.test (ref i31)
      #|    end
      #|    if
      #|      return
      #|    end
      #|    ref.null eq
      #|    global.set $wrapped))
      #|,
    ),
  )

  let eqref_type = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
  )
  for i = 0; i < 2; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(eqref_type, false),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps ref.test flow into post-consumers or trapping operands" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "use" (func $use (param i32) (result i32)))
      #|  (global $call (mut eqref) (ref.i31 (i32.const 0)))
      #|  (global $nonnull (mut eqref) (ref.i31 (i32.const 1)))
      #|  (func (export "call")
      #|    global.get $call
      #|    ref.test (ref i31)
      #|    call $use
      #|    if
      #|      ref.null eq
      #|      global.set $call
      #|    end)
      #|  (func (export "nonnull")
      #|    global.get $nonnull
      #|    ref.as_non_null
      #|    ref.test (ref i31)
      #|    if
      #|      ref.null eq
      #|      global.set $nonnull
      #|    end))
      #|,
    ),
  )

  let eqref_type = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
  )
  for i = 0; i < 2; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(eqref_type, true),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("ref.test"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("ref.as_non_null"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes ref.i31-fed i31.get read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $signed (mut i32) (i32.const 0))
      #|  (global $unsigned (mut i32) (i32.const 0))
      #|  (global $nonnull (mut i32) (i32.const 0))
      #|  (global $select (mut i32) (i32.const 0))
      #|  (func (export "signed")
      #|    global.get $signed
      #|    ref.i31
      #|    i31.get_s
      #|    if
      #|      i32.const 1
      #|      global.set $signed
      #|    end)
      #|  (func (export "unsigned")
      #|    global.get $unsigned
      #|    ref.i31
      #|    i31.get_u
      #|    if
      #|      i32.const 1
      #|      global.set $unsigned
      #|    end)
      #|  (func (export "nonnull")
      #|    global.get $nonnull
      #|    ref.i31
      #|    ref.as_non_null
      #|    i31.get_s
      #|    if
      #|      i32.const 1
      #|      global.set $nonnull
      #|    end)
      #|  (func (export "select")
      #|    global.get $select
      #|    ref.i31
      #|    i32.const 7
      #|    ref.i31
      #|    i32.const 1
      #|    select (result i31ref)
      #|    i31.get_s
      #|    if
      #|      i32.const 1
      #|      global.set $select
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 4; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), false),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U) +
    optimized.pretty_print_defined_func(2U) +
    optimized.pretty_print_defined_func(3U)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps nullable or post-consumer i31.get guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "use" (func $use (param i32) (result i32)))
      #|  (global $nullable (mut i31ref) (ref.null i31))
      #|  (global $call (mut i32) (i32.const 0))
      #|  (global $mixed (mut i32) (i32.const 0))
      #|  (func (export "nullable")
      #|    global.get $nullable
      #|    i31.get_s
      #|    if
      #|      i32.const 1
      #|      ref.i31
      #|      global.set $nullable
      #|    end)
      #|  (func (export "call")
      #|    global.get $call
      #|    ref.i31
      #|    i31.get_s
      #|    call $use
      #|    if
      #|      i32.const 1
      #|      global.set $call
      #|    end)
      #|  (func (export "mixed")
      #|    global.get $mixed
      #|    ref.i31
      #|    ref.null i31
      #|    i32.const 0
      #|    select (result i31ref)
      #|    i31.get_s
      #|    if
      #|      i32.const 1
      #|      global.set $mixed
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::i31())),
      ),
      true,
    ),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U) +
    optimized.pretty_print_defined_func(2U)
  assert_true(pretty.contains("i31.get_s"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes wrapped simd extension guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $block (mut i32) (i32.const 0))
      #|  (func (export "block")
      #|    block (result i32)
      #|      global.get $block
      #|      i8x16.splat
      #|      i16x8.extend_high_i8x16_u
      #|      i16x8.bitmask
      #|    end
      #|    if
      #|      return
      #|    end
      #|    i32.const 1
      #|    global.set $block))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::i32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("return"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps simd extension and conversion flow into post-consumer call" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "use" (func $use (param i32) (result i32)))
      #|  (global $extend (mut i32) (i32.const 0))
      #|  (global $convert (mut f32) (f32.const 1))
      #|  (func (export "extend")
      #|    global.get $extend
      #|    i8x16.splat
      #|    i16x8.extend_low_i8x16_s
      #|    i16x8.bitmask
      #|    call $use
      #|    if
      #|      i32.const 1
      #|      global.set $extend
      #|    end)
      #|  (func (export "convert")
      #|    global.get $convert
      #|    f32x4.splat
      #|    i32x4.trunc_sat_f32x4_s
      #|    i32x4.bitmask
      #|    call $use
      #|    if
      #|      f32.const 2
      #|      global.set $convert
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
    @lib.GlobalType::new(@lib.ValType::f32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps simd lane shift and replace-lane flow into post-consumer call" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "use" (func $use (param i32) (result i32)))
      #|  (global $lane (mut i32) (i32.const 0))
      #|  (global $shift (mut i32) (i32.const 0))
      #|  (global $replace (mut i32) (i32.const 0))
      #|  (func (export "lane")
      #|    global.get $lane
      #|    i8x16.splat
      #|    i8x16.extract_lane_s 0
      #|    call $use
      #|    if
      #|      i32.const 1
      #|      global.set $lane
      #|    end)
      #|  (func (export "shift")
      #|    global.get $shift
      #|    i16x8.splat
      #|    i32.const 2
      #|    i16x8.shr_u
      #|    i16x8.bitmask
      #|    call $use
      #|    if
      #|      i32.const 1
      #|      global.set $shift
      #|    end)
      #|  (func (export "replace")
      #|    v128.const i32x4 0 0 0 0
      #|    global.get $replace
      #|    i8x16.replace_lane 0
      #|    i8x16.bitmask
      #|    call $use
      #|    if
      #|      i32.const 1
      #|      global.set $replace
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
  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U) +
    optimized.pretty_print_defined_func(2U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps simd binary value flow into post-consumer call" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "use" (func $use (param i32) (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i8x16.splat
      #|    v128.const i32x4 1 1 1 1
      #|    i8x16.add
      #|    i8x16.bitmask
      #|    call $use
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes simd core bitwise shuffle and bitselect read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $not (mut i32) (i32.const 0))
      #|  (global $and (mut i32) (i32.const 0))
      #|  (global $or (mut i32) (i32.const 0))
      #|  (global $xor (mut i32) (i32.const 0))
      #|  (global $shuffle (mut i32) (i32.const 0))
      #|  (global $swizzle (mut i32) (i32.const 0))
      #|  (global $bitselect (mut i32) (i32.const 0))
      #|  (func (export "not")
      #|    global.get $not
      #|    i32x4.splat
      #|    v128.not
      #|    v128.any_true
      #|    if
      #|      i32.const 1
      #|      global.set $not
      #|    end)
      #|  (func (export "and")
      #|    global.get $and
      #|    i32x4.splat
      #|    v128.const i32x4 1 1 1 1
      #|    v128.andnot
      #|    v128.any_true
      #|    if
      #|      i32.const 1
      #|      global.set $and
      #|    end)
      #|  (func (export "or")
      #|    global.get $or
      #|    i32x4.splat
      #|    v128.const i32x4 1 1 1 1
      #|    v128.or
      #|    v128.any_true
      #|    if
      #|      i32.const 1
      #|      global.set $or
      #|    end)
      #|  (func (export "xor")
      #|    global.get $xor
      #|    i32x4.splat
      #|    v128.const i32x4 1 1 1 1
      #|    v128.xor
      #|    v128.any_true
      #|    if
      #|      i32.const 1
      #|      global.set $xor
      #|    end)
      #|  (func (export "shuffle")
      #|    global.get $shuffle
      #|    i32x4.splat
      #|    v128.const i32x4 0 0 0 0
      #|    i8x16.shuffle 0 1 2 3 16 17 18 19 4 5 6 7 20 21 22 23
      #|    v128.any_true
      #|    if
      #|      i32.const 1
      #|      global.set $shuffle
      #|    end)
      #|  (func (export "swizzle")
      #|    global.get $swizzle
      #|    i32x4.splat
      #|    v128.const i32x4 0 1 2 3
      #|    i8x16.swizzle
      #|    v128.any_true
      #|    if
      #|      i32.const 1
      #|      global.set $swizzle
      #|    end)
      #|  (func (export "bitselect")
      #|    global.get $bitselect
      #|    i32x4.splat
      #|    v128.const i32x4 1 1 1 1
      #|    v128.const i32x4 -1 -1 -1 -1
      #|    v128.bitselect
      #|    v128.any_true
      #|    if
      #|      i32.const 1
      #|      global.set $bitselect
      #|    end))
      #|,
    ),
  )

  for i = 0; i < 7; i = i + 1 {
    @debug.assert_eq(
      try! sgo_test_defined_global_type(optimized, i),
      @lib.GlobalType::new(@lib.ValType::i32(), false),
    )
  }
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U) +
    optimized.pretty_print_defined_func(2U) +
    optimized.pretty_print_defined_func(3U) +
    optimized.pretty_print_defined_func(4U) +
    optimized.pretty_print_defined_func(5U) +
    optimized.pretty_print_defined_func(6U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes wrapped simd core bitselect guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      global.get $guard
      #|      i32x4.splat
      #|      v128.const i32x4 1 1 1 1
      #|      v128.const i32x4 -1 -1 -1 -1
      #|      v128.bitselect
      #|      v128.any_true
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("return"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps simd core bitwise flow into post-consumer call" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "use" (func $use (param i32) (result i32)))
      #|  (global $core (mut i32) (i32.const 0))
      #|  (global $bitselect (mut i32) (i32.const 0))
      #|  (func (export "core")
      #|    global.get $core
      #|    i32x4.splat
      #|    v128.not
      #|    v128.any_true
      #|    call $use
      #|    if
      #|      i32.const 1
      #|      global.set $core
      #|    end)
      #|  (func (export "bitselect")
      #|    global.get $bitselect
      #|    i32x4.splat
      #|    v128.const i32x4 1 1 1 1
      #|    v128.const i32x4 -1 -1 -1 -1
      #|    v128.bitselect
      #|    v128.any_true
      #|    call $use
      #|    if
      #|      i32.const 1
      #|      global.set $bitselect
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
  let pretty = optimized.pretty_print_defined_func(0U) +
    optimized.pretty_print_defined_func(1U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps simd core bitwise guards with trapping load side effects" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i32x4.splat
      #|    v128.const i32x4 1 1 1 1
      #|    v128.and
      #|    i32.const 0
      #|    v128.load
      #|    v128.or
      #|    v128.any_true
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("v128.load"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block-wrapped simd bitmask if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      global.get $guard
      #|      i16x8.splat
      #|      i16x8.bitmask
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes clean if-wrapper simd sqrt guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut f32) (f32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      call $cond
      #|      if (result i32)
      #|        global.get $guard
      #|        f32x4.splat
      #|        f32x4.sqrt
      #|        v128.const f32x4 0 0 0 0
      #|        f32x4.ne
      #|        i32x4.all_true
      #|      else
      #|        i32.const 0
      #|      end
      #|    end
      #|    if
      #|      f32.const 1
      #|      global.set $guard
      #|    end))
      #|,
    ),
  )

  @debug.assert_eq(
    try! sgo_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(@lib.ValType::f32(), false),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps broader simd value flow into post-consumer call" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "use" (func $use (param i32) (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i16x8.splat
      #|    i16x8.bitmask
      #|    call $use
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block-wrapped simd read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      global.get $guard
      #|      i8x16.splat
      #|      i8x16.bitmask
      #|      i32.eqz
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block-wrapped size-query read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      global.get $guard
      #|      memory.size
      #|      i32.add
      #|      i32.eqz
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested block-wrapped size-query read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      block (result i32)
      #|        global.get $guard
      #|        memory.size
      #|        i32.add
      #|        i32.eqz
      #|      end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested block-wrapped simd read-only-to-write guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      block (result i32)
      #|        global.get $guard
      #|        i16x8.splat
      #|        i16x8.all_true
      #|      end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through memory size" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      global.get $guard
      #|    end
      #|    memory.size
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested-if arm flow through simd post-consumer" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      global.get $guard
      #|    end
      #|    i32x4.splat
      #|    i32x4.all_true
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps nested block-wrapped tainted load guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      block (result i32)
      #|        global.get $guard
      #|        i32.load
      #|        i32.eqz
      #|      end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block-wrapped size-query if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      global.get $guard
      #|      memory.size
      #|      i32.add
      #|      i32.eqz
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested block-wrapped simd if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      block (result i32)
      #|        global.get $guard
      #|        i8x16.splat
      #|        i8x16.bitmask
      #|        i32.eqz
      #|      end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block-yielded size-query external-eqz if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      global.get $guard
      #|      memory.size
      #|      i32.add
      #|    end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes block-yielded simd if-return guards with block-wrapped set" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      global.get $guard
      #|      i16x8.splat
      #|      i16x8.all_true
      #|    end
      #|    i32.eqz
      #|    if
      #|      return
      #|    end
      #|    block
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps block-wrapped tainted-load if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      global.get $guard
      #|      i32.load
      #|      i32.eqz
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
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes clean if-wrapper size-query guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      call $cond
      #|      if (result i32)
      #|        global.get $guard
      #|        memory.size
      #|        i32.add
      #|      else
      #|        i32.const 0
      #|      end
      #|      i32.eqz
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes nested block clean if-wrapper simd guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      block (result i32)
      #|        call $cond
      #|        if (result i32)
      #|          global.get $guard
      #|          i16x8.splat
      #|          i16x8.all_true
      #|        else
      #|          i32.const 0
      #|        end
      #|      end
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes clean if-wrapper size-query if-return guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      call $cond
      #|      if (result i32)
      #|        global.get $guard
      #|        memory.size
      #|        i32.add
      #|      else
      #|        i32.const 0
      #|      end
      #|      i32.eqz
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes clean if-wrapper simd if-return block sets" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      call $cond
      #|      if (result i32)
      #|        global.get $guard
      #|        i8x16.splat
      #|        i8x16.bitmask
      #|      else
      #|        i32.const 0
      #|      end
      #|      i32.eqz
      #|    end
      #|    if
      #|      return
      #|    end
      #|    block
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps clean if-wrapper tainted-load guards" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    block (result i32)
      #|      call $cond
      #|      if (result i32)
      #|        global.get $guard
      #|        i32.load
      #|      else
      #|        i32.const 0
      #|      end
      #|      i32.eqz
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps simd value flow into post-consumer call" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "use" (func $use (param i32) (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i32x4.splat
      #|    i32x4.all_true
      #|    call $use
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps simd load fed by the global" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    v128.load
      #|    i32x4.all_true
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("v128.load"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps numeric conversion arm flow into post-consumer call" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (result i32)))
      #|  (import "env" "use" (func $use (param i32) (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    call $cond
      #|    if (result i32)
      #|      i32.const 0
      #|    else
      #|      global.get $guard
      #|    end
      #|    f64.convert_i32_s
      #|    f64.const 0
      #|    f64.ne
      #|    call $use
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps nested-if call operands derived from the global" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "cond" (func $cond (param i32) (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    call $cond
      #|    if (result i32)
      #|      i32.const 1
      #|    else
      #|      i32.const 0
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing keeps nested-if conditions steered by the global" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (import "env" "foo" (func $foo (result i32)))
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    if (result i32)
      #|      call $foo
      #|    else
      #|      i32.const 1
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
}

///|
test "simplify-globals-optimizing removes recursive nested read-only-to-write pattern" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (if
      #|      (block (result i32)
      #|        (if
      #|          (i32.eqz (global.get $once))
      #|          (then (global.set $once (i32.const 1))))
      #|        (i32.eq (global.get $once) (i32.const 0)))
      #|      (then (global.set $once (i32.const 1))))))
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
test "simplify-globals-optimizing removes recursive nested read-only-to-write pattern thrice" {
  let (optimized, trace) = sgo_test_run_with_trace(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (if
      #|      (block (result i32)
      #|        (if
      #|          (i32.eqz
      #|            (block (result i32)
      #|              (if
      #|                (global.get $once)
      #|                (then (global.set $once (i32.const 1))))
      #|              (global.get $once)))
      #|          (then (global.set $once (i32.const 1))))
      #|        (i32.eq (global.get $once) (i32.const 0)))
      #|      (then (global.set $once (i32.const 1))))))
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
  let trace_text = trace.to_string()
  assert_true(trace_text.contains("filtered-structural=1"), msg=trace_text)
  assert_true(trace_text.contains("reason=value-block-control"), msg=trace_text)
}

///|
test "simplify-globals-optimizing keeps almost recursive nested pattern with else" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (if
      #|      (block (result i32)
      #|        (if
      #|          (i32.eqz (global.get $once))
      #|          (then (global.set $once (i32.const 1)))
      #|          (else (nop)))
      #|        (i32.eq (global.get $once) (i32.const 0)))
      #|      (then (global.set $once (i32.const 1))))))
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
test "simplify-globals-optimizing keeps recursive nested pattern with extra dropped read" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (global $once (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    (if
      #|      (block (result i32)
      #|        (drop (global.get $once))
      #|        (if
      #|          (i32.eqz (global.get $once))
      #|          (then (global.set $once (i32.const 1))))
      #|        (i32.eq (global.get $once) (i32.const 0)))
      #|      (then (global.set $once (i32.const 1))))))
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
test "simplify-globals-optimizing keeps side-effecting conditions steered by the global" {
  let optimized = sgo_test_run(
    (
      #|(module
      #|  (memory 1)
      #|  (global $guard (mut i32) (i32.const 0))
      #|  (func (export "run")
      #|    global.get $guard
      #|    i32.load
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
  let pretty = optimized.pretty_print_defined_func(0U)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
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
