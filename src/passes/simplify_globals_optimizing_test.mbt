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
test "simplify-globals-optimizing keeps self guards through select value flow" {
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
    @lib.GlobalType::new(@lib.ValType::i32(), true),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
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
