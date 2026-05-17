///|
fn sgo_test_run(text : String) -> @lib.Module {
  match pass_test_run_pipeline(text, ["simplify-globals-optimizing"]) {
    Ok(mod_) => mod_
    Err(err) =>
      abort("expected simplify-globals-optimizing success, got \{err}")
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
test "simplify-globals-optimizing propagates startup globals into data offsets without cleaning untouched functions" {
  let optimized = sgo_test_run(
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
test "simplify-globals-optimizing folds single-use multi-instruction global initializers into later globals" {
  let optimized = sgo_test_run(
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
