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
