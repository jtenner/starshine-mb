///|
fn gsi_test_run(input : String, closed_world : Bool) -> @lib.Module raise {
  let options = if closed_world {
    HotPipelineOptions::new(closed_world=true)
  } else {
    HotPipelineOptions::new()
  }
  match pass_test_run_pipeline(input, ["global-struct-inference"], options~) {
    Ok(mod_) => mod_
    Err(err) => fail("expected global-struct-inference success, got \{err}")
  }
}

///|
fn gsi_test_pretty(input : String, closed_world : Bool) -> String raise {
  gsi_test_run(input, closed_world).pretty_print_func(@lib.FuncIdx::new(0U))
}

///|
fn gsi_test_defined_global_count(mod_ : @lib.Module) -> Int raise {
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => globals.length()
    None => fail("expected global section")
  }
}

///|
fn gsi_test_global_init_contains(
  mod_ : @lib.Module,
  defined_idx : Int,
  needle : @lib.Instruction,
) -> Bool raise {
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      match globals.get(defined_idx) {
        Some(@lib.Global(_, @lib.Expr(instrs))) => instrs.contains(needle)
        None => fail("missing global \{defined_idx}")
      }
    None => fail("expected global section")
  }
}

///|
fn gsi_test_any_global_init_contains(
  mod_ : @lib.Module,
  needle : @lib.Instruction,
) -> Bool raise {
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) => {
      for global_ in globals {
        let @lib.Global(_, @lib.Expr(instrs)) = global_
        if instrs.contains(needle) {
          return true
        }
      }
      false
    }
    None => fail("expected global section")
  }
}

///|
fn gsi_assert_folded_i32(input : String, expected : String) -> Unit raise {
  let pretty = gsi_test_pretty(input, false)
  assert_false(pretty.contains("struct.get"), msg=pretty)
  assert_true(pretty.contains(expected), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
}

///|
test "global-struct-inference folds direct immutable global atomic fields in open world" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i32.const 7)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.atomic.get acq_rel $box 0))
    #|
  let pretty = gsi_test_pretty(input, false)
  assert_false(pretty.contains("struct.atomic.get"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
}

///|
test "global-struct-inference repairs packed direct immutable global atomic fields" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i8) (field i16))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i32.const 255)
    #|       (i32.const 258)))
    #|   (func (export "read-s") (result i32)
    #|     global.get $g
    #|     struct.atomic.get_s acq_rel $box 0)
    #|   (func (export "read-u") (result i32)
    #|     global.get $g
    #|     struct.atomic.get_u acq_rel $box 1))
    #|
  let mod_ = gsi_test_run(input, false)
  let pretty_s = mod_.pretty_print_func(@lib.FuncIdx::new(0U))
  let pretty_u = mod_.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty_s.contains("struct.atomic.get"), msg=pretty_s)
  assert_true(pretty_s.contains("I32(-1)"), msg=pretty_s)
  assert_false(pretty_u.contains("struct.atomic.get"), msg=pretty_u)
  assert_true(pretty_u.contains("I32(258)"), msg=pretty_u)
}

///|
test "global-struct-inference leaves mutable global atomic fields unchanged" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field (mut i32)))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i32.const 7)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.atomic.get acq_rel $box 0))
    #|
  let pretty = gsi_test_pretty(input, false)
  assert_true(pretty.contains("struct.atomic.get"), msg=pretty)
  assert_false(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "global-struct-inference folds closed-world atomic local two-value reads" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $a (ref $box) (struct.new $box (i32.const 42)))
    #|   (global $b (ref $box) (struct.new $box (i32.const 1337)))
    #|   (func (export "read") (param $x (ref $box)) (result i32)
    #|     local.get $x
    #|     struct.atomic.get acq_rel $box 0))
    #|
  let pretty = gsi_test_pretty(input, true)
  assert_false(pretty.contains("struct.atomic.get"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
  assert_true(pretty.contains("ref.eq"), msg=pretty)
  assert_true(pretty.contains("I32(42)"), msg=pretty)
  assert_true(pretty.contains("I32(1337)"), msg=pretty)
}

///|
test "global-struct-inference folds direct immutable global fields in open world" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i32.const 7)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  gsi_assert_folded_i32(input, "I32(7)")

  let exported =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (export "g") (ref $box)
    #|     (struct.new $box
    #|       (i32.const 11)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  gsi_assert_folded_i32(exported, "I32(11)")
}

///|
test "global-struct-inference preserves nullable direct-global traps" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref null $box)
    #|     (struct.new $box
    #|       (i32.const 8)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let pretty = gsi_test_pretty(input, false)
  assert_false(pretty.contains("struct.get"), msg=pretty)
  assert_true(pretty.contains("ref.as_non_null"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("I32(8)"), msg=pretty)
}

///|
test "global-struct-inference repairs packed i8 and i16 reads by signedness" {
  let signed8 =
    #| (module
    #|   (type $box (sub (struct (field i8))))
    #|   (global $g (ref $box) (struct.new $box (i32.const 255)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get_s $box 0))
    #|
  gsi_assert_folded_i32(signed8, "I32(-1)")

  let unsigned8 =
    #| (module
    #|   (type $box (sub (struct (field i8))))
    #|   (global $g (ref $box) (struct.new $box (i32.const 257)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get_u $box 0))
    #|
  gsi_assert_folded_i32(unsigned8, "I32(1)")

  let signed16 =
    #| (module
    #|   (type $box (sub (struct (field i16))))
    #|   (global $g (ref $box) (struct.new $box (i32.const 65535)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get_s $box 0))
    #|
  gsi_assert_folded_i32(signed16, "I32(-1)")

  let unsigned16 =
    #| (module
    #|   (type $box (sub (struct (field i16))))
    #|   (global $g (ref $box) (struct.new $box (i32.const 65537)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get_u $box 0))
    #|
  gsi_assert_folded_i32(unsigned16, "I32(1)")
}

///|
test "global-struct-inference folds default and descriptor constructors" {
  let default_ctor =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref $box) (struct.new_default $box))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  gsi_assert_folded_i32(default_ctor, "I32(0)")

  let nullable_ref_default =
    #| (module
    #|   (type $box (sub (struct (field (ref null $box)))))
    #|   (global $g (ref $box) (struct.new_default $box))
    #|   (func (export "read") (result (ref null $box))
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let nullable_ref_pretty = gsi_test_pretty(nullable_ref_default, false)
  assert_false(
    nullable_ref_pretty.contains("struct.get"),
    msg=nullable_ref_pretty,
  )
  assert_true(nullable_ref_pretty.contains("ref.null"), msg=nullable_ref_pretty)

  let desc_ctor =
    #| (module
    #|   (rec
    #|     (type $box
    #|       (descriptor $box_desc)
    #|       (struct (field i32)))
    #|     (type $box_desc
    #|       (describes $box)
    #|       (struct)))
    #|   (global $desc (ref (exact $box_desc)) (struct.new $box_desc))
    #|   (global $g (ref $box)
    #|     (struct.new_desc $box
    #|       (i32.const 9)
    #|       (global.get $desc)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  gsi_assert_folded_i32(desc_ctor, "I32(9)")

  let default_desc_ctor =
    #| (module
    #|   (rec
    #|     (type $box
    #|       (descriptor $box_desc)
    #|       (struct (field i32)))
    #|     (type $box_desc
    #|       (describes $box)
    #|       (struct)))
    #|   (global $desc (ref (exact $box_desc)) (struct.new $box_desc))
    #|   (global $g (ref $box)
    #|     (struct.new_default_desc $box
    #|       (global.get $desc)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  gsi_assert_folded_i32(default_desc_ctor, "I32(0)")
}

///|
test "global-struct-inference leaves unsafe globals and mutable fields unchanged" {
  let mutable_field =
    #| (module
    #|   (type $box (sub (struct (field (mut i32)))))
    #|   (global $g (ref $box) (struct.new $box (i32.const 7)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let mutable_field_pretty = gsi_test_pretty(mutable_field, false)
  assert_true(
    mutable_field_pretty.contains("struct.get"),
    msg=mutable_field_pretty,
  )

  let mutable_global =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (mut (ref $box)) (struct.new $box (i32.const 7)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let mutable_global_pretty = gsi_test_pretty(mutable_global, false)
  assert_true(
    mutable_global_pretty.contains("struct.get"),
    msg=mutable_global_pretty,
  )

  let imported_global =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (import "env" "g" (global $g (ref $box)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let imported_global_pretty = gsi_test_pretty(imported_global, false)
  assert_true(
    imported_global_pretty.contains("struct.get"),
    msg=imported_global_pretty,
  )
}

///|
test "global-struct-inference leaves non-global ref producers unchanged in open world" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i32.const 7)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let optimized = gsi_test_run(input, false)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))

  assert_true(pretty.contains("struct.get"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "global-struct-inference un-nests nonconstant direct-global fields" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i32.add (i32.const 41) (i32.const 1))))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let optimized = gsi_test_run(input, false)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("struct.get"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(optimized), 2)
  assert_true(
    try! gsi_test_global_init_contains(
      optimized,
      0,
      @lib.Instruction::i32_add(),
    ),
  )
  assert_true(
    try! gsi_test_global_init_contains(
      optimized,
      1,
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    ),
  )
}

///|
test "global-struct-inference un-nests pure bitwise direct-global fields" {
  let i32_input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i32.and (i32.const 43) (i32.const 42))))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let i32_optimized = gsi_test_run(i32_input, false)
  let i32_pretty = i32_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(i32_pretty.contains("struct.get"), msg=i32_pretty)
  assert_true(i32_pretty.contains("global.get"), msg=i32_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(i32_optimized), 2)
  assert_true(
    try! gsi_test_global_init_contains(
      i32_optimized,
      0,
      @lib.Instruction::i32_and(),
    ),
  )

  let i64_input =
    #| (module
    #|   (type $box (sub (struct (field i64))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i64.xor (i64.const 255) (i64.const 15))))
    #|   (func (export "read") (result i64)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let i64_optimized = gsi_test_run(i64_input, false)
  let i64_pretty = i64_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(i64_pretty.contains("struct.get"), msg=i64_pretty)
  assert_true(i64_pretty.contains("global.get"), msg=i64_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(i64_optimized), 2)
  assert_true(
    try! gsi_test_global_init_contains(
      i64_optimized,
      0,
      @lib.Instruction::i64_xor(),
    ),
  )
}

///|
test "global-struct-inference un-nests packed direct-global fields with signedness repair" {
  let signed8 =
    #| (module
    #|   (type $box (sub (struct (field i8))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i32.and (i32.const 255) (i32.const 255))))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get_s $box 0))
    #|
  let signed8_optimized = gsi_test_run(signed8, false)
  let signed8_pretty = signed8_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_false(signed8_pretty.contains("struct.get"), msg=signed8_pretty)
  assert_true(signed8_pretty.contains("i32.extend8s"), msg=signed8_pretty)
  assert_true(signed8_pretty.contains("global.get"), msg=signed8_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(signed8_optimized), 2)
  assert_true(
    try! gsi_test_global_init_contains(
      signed8_optimized,
      0,
      @lib.Instruction::i32_and(),
    ),
  )
  assert_true(
    try! gsi_test_global_init_contains(
      signed8_optimized,
      1,
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    ),
  )

  let unsigned16 =
    #| (module
    #|   (type $box (sub (struct (field i16))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i32.popcnt (i32.const 65535))))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get_u $box 0))
    #|
  let unsigned16_optimized = gsi_test_run(unsigned16, false)
  let unsigned16_pretty = unsigned16_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_false(unsigned16_pretty.contains("struct.get"), msg=unsigned16_pretty)
  assert_true(unsigned16_pretty.contains("i32.and"), msg=unsigned16_pretty)
  assert_true(unsigned16_pretty.contains("I32(65535)"), msg=unsigned16_pretty)
  assert_true(unsigned16_pretty.contains("global.get"), msg=unsigned16_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(unsigned16_optimized), 2)
  assert_true(
    try! gsi_test_global_init_contains(
      unsigned16_optimized,
      0,
      @lib.Instruction::i32_popcnt(),
    ),
  )
}

///|
test "global-struct-inference un-nests pure unary numeric direct-global fields" {
  let i32_input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i32.popcnt (i32.const 43))))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let i32_optimized = gsi_test_run(i32_input, false)
  let i32_pretty = i32_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(i32_pretty.contains("struct.get"), msg=i32_pretty)
  assert_true(i32_pretty.contains("global.get"), msg=i32_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(i32_optimized), 2)
  assert_true(
    try! gsi_test_global_init_contains(
      i32_optimized,
      0,
      @lib.Instruction::i32_popcnt(),
    ),
  )

  let i64_eqz_input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i64.eqz (i64.const 0))))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let i64_eqz_optimized = gsi_test_run(i64_eqz_input, false)
  let i64_eqz_pretty = i64_eqz_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_false(i64_eqz_pretty.contains("struct.get"), msg=i64_eqz_pretty)
  assert_true(i64_eqz_pretty.contains("global.get"), msg=i64_eqz_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(i64_eqz_optimized), 2)
  assert_true(
    try! gsi_test_global_init_contains(
      i64_eqz_optimized,
      0,
      @lib.Instruction::i64_eqz(),
    ),
  )

  let f64_input =
    #| (module
    #|   (type $box (sub (struct (field f64))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (f64.neg (f64.const 1.5))))
    #|   (func (export "read") (result f64)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let f64_optimized = gsi_test_run(f64_input, false)
  let f64_pretty = f64_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(f64_pretty.contains("struct.get"), msg=f64_pretty)
  assert_true(f64_pretty.contains("global.get"), msg=f64_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(f64_optimized), 2)
  assert_true(
    try! gsi_test_global_init_contains(
      f64_optimized,
      0,
      @lib.Instruction::f64_neg(),
    ),
  )
}

///|
test "global-struct-inference un-nests pure float sqrt direct-global fields" {
  let f32_input =
    #| (module
    #|   (type $box (sub (struct (field f32))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (f32.sqrt (f32.const 9))))
    #|   (func (export "read") (result f32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let f32_optimized = gsi_test_run(f32_input, false)
  let f32_pretty = f32_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(f32_pretty.contains("struct.get"), msg=f32_pretty)
  assert_true(f32_pretty.contains("global.get"), msg=f32_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(f32_optimized), 2)
  assert_true(
    try! gsi_test_global_init_contains(
      f32_optimized,
      0,
      @lib.Instruction::f32_sqrt(),
    ),
  )

  let f64_input =
    #| (module
    #|   (type $box (sub (struct (field f64))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (f64.sqrt (f64.const 16))))
    #|   (func (export "read") (result f64)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let f64_optimized = gsi_test_run(f64_input, false)
  let f64_pretty = f64_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(f64_pretty.contains("struct.get"), msg=f64_pretty)
  assert_true(f64_pretty.contains("global.get"), msg=f64_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(f64_optimized), 2)
  assert_true(
    try! gsi_test_global_init_contains(
      f64_optimized,
      0,
      @lib.Instruction::f64_sqrt(),
    ),
  )
}

///|
test "global-struct-inference un-nests pure float rounding direct-global fields" {
  let f32_input =
    #| (module
    #|   (type $box (sub (struct (field f32))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (f32.ceil (f32.const 1.5))))
    #|   (func (export "read") (result f32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let f32_optimized = gsi_test_run(f32_input, false)
  let f32_pretty = f32_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(f32_pretty.contains("struct.get"), msg=f32_pretty)
  assert_true(f32_pretty.contains("global.get"), msg=f32_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(f32_optimized), 2)
  assert_true(
    try! gsi_test_global_init_contains(
      f32_optimized,
      0,
      @lib.Instruction::f32_ceil(),
    ),
  )

  let f64_input =
    #| (module
    #|   (type $box (sub (struct (field f64))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (f64.nearest (f64.const 2.5))))
    #|   (func (export "read") (result f64)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let f64_optimized = gsi_test_run(f64_input, false)
  let f64_pretty = f64_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(f64_pretty.contains("struct.get"), msg=f64_pretty)
  assert_true(f64_pretty.contains("global.get"), msg=f64_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(f64_optimized), 2)
  assert_true(
    try! gsi_test_global_init_contains(
      f64_optimized,
      0,
      @lib.Instruction::f64_nearest(),
    ),
  )
}

///|
test "global-struct-inference un-nests pure integer sign-extension direct-global fields" {
  let i32_input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i32.extend8_s (i32.const 255))))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let i32_optimized = gsi_test_run(i32_input, false)
  let i32_pretty = i32_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(i32_pretty.contains("struct.get"), msg=i32_pretty)
  assert_true(i32_pretty.contains("global.get"), msg=i32_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(i32_optimized), 2)
  assert_true(
    try! gsi_test_global_init_contains(
      i32_optimized,
      0,
      @lib.Instruction::i32_extend8s(),
    ),
  )

  let i64_input =
    #| (module
    #|   (type $box (sub (struct (field i64))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i64.extend32_s (i64.const 4294967295))))
    #|   (func (export "read") (result i64)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let i64_optimized = gsi_test_run(i64_input, false)
  let i64_pretty = i64_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(i64_pretty.contains("struct.get"), msg=i64_pretty)
  assert_true(i64_pretty.contains("global.get"), msg=i64_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(i64_optimized), 2)
  assert_true(
    try! gsi_test_global_init_contains(
      i64_optimized,
      0,
      @lib.Instruction::i64_extend32s(),
    ),
  )
}

///|
test "global-struct-inference un-nests pure shift and rotate direct-global fields" {
  let i32_input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i32.shl (i32.const 1) (i32.const 5))))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let i32_optimized = gsi_test_run(i32_input, false)
  let i32_pretty = i32_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(i32_pretty.contains("struct.get"), msg=i32_pretty)
  assert_true(i32_pretty.contains("global.get"), msg=i32_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(i32_optimized), 2)
  assert_true(
    try! gsi_test_global_init_contains(
      i32_optimized,
      0,
      @lib.Instruction::i32_shl(),
    ),
  )

  let i64_input =
    #| (module
    #|   (type $box (sub (struct (field i64))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i64.rotl (i64.const 255) (i64.const 8))))
    #|   (func (export "read") (result i64)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let i64_optimized = gsi_test_run(i64_input, false)
  let i64_pretty = i64_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(i64_pretty.contains("struct.get"), msg=i64_pretty)
  assert_true(i64_pretty.contains("global.get"), msg=i64_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(i64_optimized), 2)
  assert_true(
    try! gsi_test_global_init_contains(
      i64_optimized,
      0,
      @lib.Instruction::i64_rotl(),
    ),
  )
}

///|
test "global-struct-inference un-nests closed-world select values" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $a (ref $box)
    #|     (struct.new $box
    #|       (i32.add (i32.const 40) (i32.const 2))))
    #|   (global $b (ref $box) (struct.new $box (i32.const 1337)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let optimized = gsi_test_run(input, true)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("struct.get"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
  assert_true(pretty.contains("ref.eq"), msg=pretty)
  assert_true(pretty.contains("I32(1337)"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(optimized), 3)
}

///|
test "global-struct-inference un-nests float sqrt and rounding closed-world select values" {
  let sqrt_input =
    #| (module
    #|   (type $box (sub (struct (field f32))))
    #|   (global $a (ref $box)
    #|     (struct.new $box
    #|       (f32.sqrt (f32.const 9))))
    #|   (global $b (ref $box) (struct.new $box (f32.const 1)))
    #|   (func (export "read") (param (ref null $box)) (result f32)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let sqrt_optimized = gsi_test_run(sqrt_input, true)
  let sqrt_pretty = sqrt_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(sqrt_pretty.contains("struct.get"), msg=sqrt_pretty)
  assert_true(sqrt_pretty.contains("select"), msg=sqrt_pretty)
  assert_true(sqrt_pretty.contains("ref.eq"), msg=sqrt_pretty)
  assert_true(sqrt_pretty.contains("global.get"), msg=sqrt_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(sqrt_optimized), 3)
  assert_true(
    try! gsi_test_any_global_init_contains(
      sqrt_optimized,
      @lib.Instruction::f32_sqrt(),
    ),
    msg=sqrt_pretty,
  )

  let rounding_input =
    #| (module
    #|   (type $box (sub (struct (field f64))))
    #|   (global $a (ref $box)
    #|     (struct.new $box
    #|       (f64.nearest (f64.const 2.5))))
    #|   (global $b (ref $box) (struct.new $box (f64.const 4)))
    #|   (func (export "read") (param (ref null $box)) (result f64)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let rounding_optimized = gsi_test_run(rounding_input, true)
  let rounding_pretty = rounding_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_false(rounding_pretty.contains("struct.get"), msg=rounding_pretty)
  assert_true(rounding_pretty.contains("select"), msg=rounding_pretty)
  assert_true(rounding_pretty.contains("ref.eq"), msg=rounding_pretty)
  assert_true(rounding_pretty.contains("global.get"), msg=rounding_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(rounding_optimized), 3)
  assert_true(
    try! gsi_test_any_global_init_contains(
      rounding_optimized,
      @lib.Instruction::f64_nearest(),
    ),
    msg=rounding_pretty,
  )
}

///|
test "global-struct-inference un-nests integer sign-extension closed-world select values" {
  let i32_input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $a (ref $box)
    #|     (struct.new $box
    #|       (i32.extend16_s (i32.const 65535))))
    #|   (global $b (ref $box) (struct.new $box (i32.const 7)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let i32_optimized = gsi_test_run(i32_input, true)
  let i32_pretty = i32_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(i32_pretty.contains("struct.get"), msg=i32_pretty)
  assert_true(i32_pretty.contains("select"), msg=i32_pretty)
  assert_true(i32_pretty.contains("ref.eq"), msg=i32_pretty)
  assert_true(i32_pretty.contains("global.get"), msg=i32_pretty)
  assert_true(i32_pretty.contains("I32(7)"), msg=i32_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(i32_optimized), 3)
  assert_true(
    try! gsi_test_any_global_init_contains(
      i32_optimized,
      @lib.Instruction::i32_extend16s(),
    ),
    msg=i32_pretty,
  )

  let i64_input =
    #| (module
    #|   (type $box (sub (struct (field i64))))
    #|   (global $a (ref $box)
    #|     (struct.new $box
    #|       (i64.extend32_s (i64.const 4294967295))))
    #|   (global $b (ref $box) (struct.new $box (i64.const 9)))
    #|   (func (export "read") (param (ref null $box)) (result i64)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let i64_optimized = gsi_test_run(i64_input, true)
  let i64_pretty = i64_optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(i64_pretty.contains("struct.get"), msg=i64_pretty)
  assert_true(i64_pretty.contains("select"), msg=i64_pretty)
  assert_true(i64_pretty.contains("ref.eq"), msg=i64_pretty)
  assert_true(i64_pretty.contains("global.get"), msg=i64_pretty)
  assert_true(i64_pretty.contains("I64(9)"), msg=i64_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(i64_optimized), 3)
  assert_true(
    try! gsi_test_any_global_init_contains(
      i64_optimized,
      @lib.Instruction::i64_extend32s(),
    ),
    msg=i64_pretty,
  )
}

///|
test "global-struct-inference un-nests packed closed-world select values" {
  let signed8 =
    #| (module
    #|   (type $box (sub (struct (field i8))))
    #|   (global $a (ref $box)
    #|     (struct.new $box
    #|       (i32.and (i32.const 255) (i32.const 255))))
    #|   (global $b (ref $box) (struct.new $box (i32.const 1)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     local.get 0
    #|     struct.get_s $box 0))
    #|
  let signed8_optimized = gsi_test_run(signed8, true)
  let signed8_pretty = signed8_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_false(signed8_pretty.contains("struct.get"), msg=signed8_pretty)
  assert_true(signed8_pretty.contains("select"), msg=signed8_pretty)
  assert_true(signed8_pretty.contains("ref.eq"), msg=signed8_pretty)
  assert_true(signed8_pretty.contains("i32.extend8s"), msg=signed8_pretty)
  assert_true(signed8_pretty.contains("I32(1)"), msg=signed8_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(signed8_optimized), 3)

  let unsigned16 =
    #| (module
    #|   (type $box (sub (struct (field i16))))
    #|   (global $a (ref $box)
    #|     (struct.new $box
    #|       (i32.popcnt (i32.const 65535))))
    #|   (global $b (ref $box) (struct.new $box (i32.const 65537)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     local.get 0
    #|     struct.get_u $box 0))
    #|
  let unsigned16_optimized = gsi_test_run(unsigned16, true)
  let unsigned16_pretty = unsigned16_optimized.pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_false(unsigned16_pretty.contains("struct.get"), msg=unsigned16_pretty)
  assert_true(unsigned16_pretty.contains("select"), msg=unsigned16_pretty)
  assert_true(unsigned16_pretty.contains("ref.eq"), msg=unsigned16_pretty)
  assert_true(unsigned16_pretty.contains("i32.and"), msg=unsigned16_pretty)
  assert_true(unsigned16_pretty.contains("I32(65535)"), msg=unsigned16_pretty)
  assert_true(unsigned16_pretty.contains("I32(1)"), msg=unsigned16_pretty)
  @debug.assert_eq(try! gsi_test_defined_global_count(unsigned16_optimized), 3)
}

///|
test "global-struct-inference folds direct ref.get_desc from descriptor globals" {
  let input =
    #| (module
    #|   (rec
    #|     (type $box
    #|       (descriptor $box_desc)
    #|       (struct (field i32)))
    #|     (type $box_desc
    #|       (describes $box)
    #|       (struct)))
    #|   (global $desc (ref (exact $box_desc)) (struct.new $box_desc))
    #|   (global $g (ref null $box)
    #|     (struct.new_desc $box
    #|       (i32.const 9)
    #|       (global.get $desc)))
    #|   (func (export "read") (result (ref $box_desc))
    #|     global.get $g
    #|     ref.get_desc $box))
    #|
  let pretty = gsi_test_pretty(input, false)
  assert_false(pretty.contains("ref.get_desc"), msg=pretty)
  assert_true(pretty.contains("global.get (Global 0)"), msg=pretty)
  assert_true(pretty.contains("ref.as_non_null"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
}

///|
test "global-struct-inference folds closed-world ref.get_desc local reads" {
  let input =
    #| (module
    #|   (rec
    #|     (type $box
    #|       (descriptor $box_desc)
    #|       (struct (field i32)))
    #|     (type $box_desc
    #|       (describes $box)
    #|       (struct)))
    #|   (global $desc (ref (exact $box_desc)) (struct.new $box_desc))
    #|   (global $a (ref $box)
    #|     (struct.new_desc $box
    #|       (i32.const 1)
    #|       (global.get $desc)))
    #|   (global $b (ref $box)
    #|     (struct.new_desc $box
    #|       (i32.const 2)
    #|       (global.get $desc)))
    #|   (func (export "read") (param (ref null $box)) (result (ref $box_desc))
    #|     local.get 0
    #|     ref.get_desc $box))
    #|
  let pretty = gsi_test_pretty(input, true)
  assert_false(pretty.contains("ref.get_desc"), msg=pretty)
  assert_true(pretty.contains("global.get (Global 0)"), msg=pretty)
  assert_true(pretty.contains("ref.as_non_null"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
}

///|
test "global-struct-inference rewrites exact single-candidate param origins in closed world" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i32.const 7)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let pretty = gsi_test_pretty(input, true)
  assert_true(pretty.contains("struct.get"), msg=pretty)
  assert_true(pretty.contains("global.get (Global 0)"), msg=pretty)
  assert_true(pretty.contains("ref.as_non_null"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
}

///|
test "global-struct-inference rewrites exact single-candidate body locals in closed world" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i32.const 13)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     (local (ref null $box))
    #|     local.get 0
    #|     local.set 1
    #|     local.get 1
    #|     struct.get $box 0))
    #|
  let pretty = gsi_test_pretty(input, true)
  assert_true(pretty.contains("struct.get"), msg=pretty)
  assert_true(pretty.contains("global.get (Global 0)"), msg=pretty)
  assert_true(pretty.contains("ref.as_non_null"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
}

///|
test "global-struct-inference synthesizes two-value singleton selects in closed world" {
  let two_globals =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $a (ref $box) (struct.new $box (i32.const 7)))
    #|   (global $b (ref $box) (struct.new $box (i32.const 8)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let two_pretty = gsi_test_pretty(two_globals, true)
  assert_false(two_pretty.contains("struct.get"), msg=two_pretty)
  assert_true(two_pretty.contains("select"), msg=two_pretty)
  assert_true(two_pretty.contains("ref.eq"), msg=two_pretty)
  assert_true(two_pretty.contains("global.get (Global 0)"), msg=two_pretty)
  assert_true(two_pretty.contains("ref.as_non_null"), msg=two_pretty)
  assert_true(two_pretty.contains("I32(7)"), msg=two_pretty)
  assert_true(two_pretty.contains("I32(8)"), msg=two_pretty)

  let singleton_group =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $a (ref $box) (struct.new $box (i32.const 42)))
    #|   (global $b (ref $box) (struct.new $box (i32.const 1337)))
    #|   (global $c (ref $box) (struct.new $box (i32.const 1337)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let singleton_pretty = gsi_test_pretty(singleton_group, true)
  assert_false(singleton_pretty.contains("struct.get"), msg=singleton_pretty)
  assert_true(singleton_pretty.contains("select"), msg=singleton_pretty)
  assert_true(singleton_pretty.contains("ref.eq"), msg=singleton_pretty)
  assert_true(
    singleton_pretty.contains("global.get (Global 0)"),
    msg=singleton_pretty,
  )
  assert_true(singleton_pretty.contains("I32(42)"), msg=singleton_pretty)
  assert_true(singleton_pretty.contains("I32(1337)"), msg=singleton_pretty)
}

///|
test "global-struct-inference rewrites subtype-propagated single-candidate parent origins" {
  let input =
    #| (module
    #|   (global $denom i32 (i32.const 1))
    #|   (type $parent (sub (struct (field i32))))
    #|   (type $child (sub $parent (struct (field i32))))
    #|   (global $child_g (ref $child)
    #|     (struct.new $child
    #|       (i32.div_s (i32.const 7) (global.get $denom))))
    #|   (func (export "read") (param (ref null $parent)) (result i32)
    #|     local.get 0
    #|     struct.get $parent 0))
    #|
  let pretty = gsi_test_pretty(input, true)
  assert_true(pretty.contains("struct.get"), msg=pretty)
  assert_true(pretty.contains("global.get (Global 1)"), msg=pretty)
  assert_true(pretty.contains("ref.as_non_null"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
}

///|
test "global-struct-inference avoids invalid broad-global propagated origins" {
  let input =
    #| (module
    #|   (global $denom i32 (i32.const 1))
    #|   (type $parent (sub (struct (field i32))))
    #|   (type $child (sub $parent (struct (field i32))))
    #|   (global $child_g eqref
    #|     (struct.new $child
    #|       (i32.div_s (i32.const 7) (global.get $denom))))
    #|   (func (export "read") (param (ref null $parent)) (result i32)
    #|     local.get 0
    #|     struct.get $parent 0))
    #|
  let pretty = gsi_test_pretty(input, true)
  assert_true(pretty.contains("struct.get"), msg=pretty)
  assert_false(pretty.contains("global.get (Global 1)"), msg=pretty)
  assert_false(pretty.contains("ref.as_non_null"), msg=pretty)
}

///|
test "global-struct-inference folds subtype-propagated one-value parent reads" {
  let child_only =
    #| (module
    #|   (type $parent (sub (struct (field i32))))
    #|   (type $child (sub $parent (struct (field i32))))
    #|   (global $child_a (ref $child) (struct.new $child (i32.const 7)))
    #|   (global $child_b (ref $child) (struct.new $child (i32.const 7)))
    #|   (func (export "read") (param (ref null $parent)) (result i32)
    #|     local.get 0
    #|     struct.get $parent 0))
    #|
  let child_pretty = gsi_test_pretty(child_only, true)
  assert_false(child_pretty.contains("struct.get"), msg=child_pretty)
  assert_true(child_pretty.contains("I32(7)"), msg=child_pretty)
  assert_true(child_pretty.contains("ref.as_non_null"), msg=child_pretty)
  assert_true(child_pretty.contains("drop"), msg=child_pretty)
  assert_false(child_pretty.contains("global.get"), msg=child_pretty)

  let mixed_parent_child =
    #| (module
    #|   (type $parent (sub (struct (field i32))))
    #|   (type $child (sub $parent (struct (field i32))))
    #|   (global $child_g (ref $child) (struct.new $child (i32.const 11)))
    #|   (global $parent_g (ref $parent) (struct.new $parent (i32.const 11)))
    #|   (func (export "read") (param (ref null $parent)) (result i32)
    #|     local.get 0
    #|     struct.get $parent 0))
    #|
  let mixed_pretty = gsi_test_pretty(mixed_parent_child, true)
  assert_false(mixed_pretty.contains("struct.get"), msg=mixed_pretty)
  assert_true(mixed_pretty.contains("I32(11)"), msg=mixed_pretty)
  assert_true(mixed_pretty.contains("drop"), msg=mixed_pretty)
}

///|
test "global-struct-inference synthesizes subtype-propagated two-value parent selects" {
  let child_only =
    #| (module
    #|   (type $parent (sub (struct (field i32))))
    #|   (type $child_a (sub $parent (struct (field i32))))
    #|   (type $child_b (sub $parent (struct (field i32))))
    #|   (global $a (ref $child_a) (struct.new $child_a (i32.const 42)))
    #|   (global $b (ref $child_b) (struct.new $child_b (i32.const 1337)))
    #|   (global $c (ref $child_b) (struct.new $child_b (i32.const 1337)))
    #|   (func (export "read") (param (ref null $parent)) (result i32)
    #|     local.get 0
    #|     struct.get $parent 0))
    #|
  let child_pretty = gsi_test_pretty(child_only, true)
  assert_false(child_pretty.contains("struct.get"), msg=child_pretty)
  assert_true(child_pretty.contains("select"), msg=child_pretty)
  assert_true(child_pretty.contains("ref.eq"), msg=child_pretty)
  assert_true(child_pretty.contains("global.get (Global 0)"), msg=child_pretty)
  assert_true(child_pretty.contains("I32(42)"), msg=child_pretty)
  assert_true(child_pretty.contains("I32(1337)"), msg=child_pretty)
  assert_true(child_pretty.contains("ref.as_non_null"), msg=child_pretty)

  let mixed_order =
    #| (module
    #|   (type $parent (sub (struct (field i32))))
    #|   (type $child (sub $parent (struct (field i32))))
    #|   (global $child_g (ref $child) (struct.new $child (i32.const 5)))
    #|   (global $parent_a (ref $parent) (struct.new $parent (i32.const 9)))
    #|   (global $parent_b (ref $parent) (struct.new $parent (i32.const 9)))
    #|   (func (export "read") (param (ref null $parent)) (result i32)
    #|     local.get 0
    #|     struct.get $parent 0))
    #|
  let mixed_pretty = gsi_test_pretty(mixed_order, true)
  assert_false(mixed_pretty.contains("struct.get"), msg=mixed_pretty)
  assert_true(mixed_pretty.contains("select"), msg=mixed_pretty)
  assert_true(mixed_pretty.contains("ref.eq"), msg=mixed_pretty)
  assert_true(mixed_pretty.contains("global.get (Global 0)"), msg=mixed_pretty)
  assert_true(mixed_pretty.contains("I32(5)"), msg=mixed_pretty)
  assert_true(mixed_pretty.contains("I32(9)"), msg=mixed_pretty)
}

///|
test "global-struct-inference folds multi-candidate one-value local origins in closed world" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $a (ref $box) (struct.new $box (i32.const 7)))
    #|   (global $b (ref $box) (struct.new $box (i32.const 7)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let pretty = gsi_test_pretty(input, true)
  assert_false(pretty.contains("struct.get"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("ref.as_non_null"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)

  let body_local =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $a (ref $box) (struct.new $box (i32.const 13)))
    #|   (global $b (ref $box) (struct.new $box (i32.const 13)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     (local (ref null $box))
    #|     local.get 0
    #|     local.set 1
    #|     local.get 1
    #|     struct.get $box 0))
    #|
  let body_pretty = gsi_test_pretty(body_local, true)
  assert_false(body_pretty.contains("struct.get"), msg=body_pretty)
  assert_true(body_pretty.contains("I32(13)"), msg=body_pretty)
  assert_true(body_pretty.contains("ref.as_non_null"), msg=body_pretty)
  assert_true(body_pretty.contains("drop"), msg=body_pretty)
}

///|
test "global-struct-inference folds multi-candidate equal global-get and packed values" {
  let scalar_global =
    #| (module
    #|   (global $value i32 (i32.const 21))
    #|   (type $box (sub (struct (field i32))))
    #|   (global $a (ref $box) (struct.new $box (global.get $value)))
    #|   (global $b (ref $box) (struct.new $box (global.get $value)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let scalar_pretty = gsi_test_pretty(scalar_global, true)
  assert_false(scalar_pretty.contains("struct.get"), msg=scalar_pretty)
  assert_true(
    scalar_pretty.contains("global.get (Global 0)"),
    msg=scalar_pretty,
  )
  assert_true(scalar_pretty.contains("drop"), msg=scalar_pretty)

  let packed =
    #| (module
    #|   (type $box (sub (struct (field i8))))
    #|   (global $a (ref $box) (struct.new $box (i32.const 255)))
    #|   (global $b (ref $box) (struct.new $box (i32.const 255)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     local.get 0
    #|     struct.get_s $box 0))
    #|
  let packed_pretty = gsi_test_pretty(packed, true)
  assert_false(packed_pretty.contains("struct.get"), msg=packed_pretty)
  assert_true(packed_pretty.contains("I32(-1)"), msg=packed_pretty)
}

///|
test "global-struct-inference leaves multi-candidate select ambiguities unchanged" {
  let more_than_two_values =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $a (ref $box) (struct.new $box (i32.const 7)))
    #|   (global $b (ref $box) (struct.new $box (i32.const 8)))
    #|   (global $c (ref $box) (struct.new $box (i32.const 9)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let more_pretty = gsi_test_pretty(more_than_two_values, true)
  assert_true(more_pretty.contains("struct.get"), msg=more_pretty)
  assert_false(more_pretty.contains("select"), msg=more_pretty)
  assert_false(more_pretty.contains("ref.eq"), msg=more_pretty)

  let two_equal_pairs =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $a (ref $box) (struct.new $box (i32.const 7)))
    #|   (global $b (ref $box) (struct.new $box (i32.const 7)))
    #|   (global $c (ref $box) (struct.new $box (i32.const 8)))
    #|   (global $d (ref $box) (struct.new $box (i32.const 8)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let pairs_pretty = gsi_test_pretty(two_equal_pairs, true)
  assert_true(pairs_pretty.contains("struct.get"), msg=pairs_pretty)
  assert_false(pairs_pretty.contains("select"), msg=pairs_pretty)
  assert_false(pairs_pretty.contains("ref.eq"), msg=pairs_pretty)
}

///|
test "global-struct-inference leaves unsafe multi-candidate one-value locals unchanged" {
  let open_world =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $a (ref $box) (struct.new $box (i32.const 7)))
    #|   (global $b (ref $box) (struct.new $box (i32.const 7)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let open_pretty = gsi_test_pretty(open_world, false)
  assert_true(open_pretty.contains("struct.get"), msg=open_pretty)
  assert_false(open_pretty.contains("global.get"), msg=open_pretty)

  let non_materializable =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $denom i32 (i32.const 1))
    #|   (global $a (ref $box)
    #|     (struct.new $box
    #|       (i32.div_s (i32.const 7) (global.get $denom))))
    #|   (global $b (ref $box)
    #|     (struct.new $box
    #|       (i32.div_s (i32.const 7) (global.get $denom))))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let non_materializable_pretty = gsi_test_pretty(non_materializable, true)
  assert_true(
    non_materializable_pretty.contains("struct.get"),
    msg=non_materializable_pretty,
  )

  let subtype_three_values =
    #| (module
    #|   (type $parent (sub (struct (field i32))))
    #|   (type $child (sub $parent (struct (field i32))))
    #|   (global $parent_a (ref $parent) (struct.new $parent (i32.const 7)))
    #|   (global $parent_b (ref $parent) (struct.new $parent (i32.const 8)))
    #|   (global $child_g (ref $child) (struct.new $child (i32.const 13)))
    #|   (func (export "read") (param (ref null $parent)) (result i32)
    #|     local.get 0
    #|     struct.get $parent 0))
    #|
  let subtype_three_pretty = gsi_test_pretty(subtype_three_values, true)
  assert_true(
    subtype_three_pretty.contains("struct.get"),
    msg=subtype_three_pretty,
  )
  assert_false(
    subtype_three_pretty.contains("select"),
    msg=subtype_three_pretty,
  )

  let subtype_two_equal_pairs =
    #| (module
    #|   (type $parent (sub (struct (field i32))))
    #|   (type $child (sub $parent (struct (field i32))))
    #|   (global $parent_a (ref $parent) (struct.new $parent (i32.const 7)))
    #|   (global $parent_b (ref $parent) (struct.new $parent (i32.const 7)))
    #|   (global $child_a (ref $child) (struct.new $child (i32.const 13)))
    #|   (global $child_b (ref $child) (struct.new $child (i32.const 13)))
    #|   (func (export "read") (param (ref null $parent)) (result i32)
    #|     local.get 0
    #|     struct.get $parent 0))
    #|
  let subtype_pairs_pretty = gsi_test_pretty(subtype_two_equal_pairs, true)
  assert_true(
    subtype_pairs_pretty.contains("struct.get"),
    msg=subtype_pairs_pretty,
  )
  assert_false(
    subtype_pairs_pretty.contains("select"),
    msg=subtype_pairs_pretty,
  )
}

///|
test "global-struct-inference leaves poisoned exact and parent local origins unchanged" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref $box) (struct.new $box (i32.const 7)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     local.get 0
    #|     struct.get $box 0)
    #|   (func
    #|     i32.const 9
    #|     struct.new $box
    #|     drop))
    #|
  let pretty = gsi_test_pretty(input, true)
  assert_true(pretty.contains("struct.get"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)

  let function_local_child =
    #| (module
    #|   (type $parent (sub (struct (field i32))))
    #|   (type $child (sub $parent (struct (field i32))))
    #|   (global $child_g (ref $child) (struct.new $child (i32.const 7)))
    #|   (func (export "read") (param (ref null $parent)) (result i32)
    #|     local.get 0
    #|     struct.get $parent 0)
    #|   (func
    #|     i32.const 9
    #|     struct.new $child
    #|     drop))
    #|
  let function_local_pretty = gsi_test_pretty(function_local_child, true)
  assert_true(
    function_local_pretty.contains("struct.get"),
    msg=function_local_pretty,
  )
  assert_false(
    function_local_pretty.contains("select"),
    msg=function_local_pretty,
  )

  let nested_global_child =
    #| (module
    #|   (type $parent (sub (struct (field i32))))
    #|   (type $child (sub $parent (struct (field i32))))
    #|   (type $outer (sub (struct (field (ref $child)))))
    #|   (global $outer_g (ref $outer)
    #|     (struct.new $outer
    #|       (struct.new $child (i32.const 7))))
    #|   (func (export "read") (param (ref null $parent)) (result i32)
    #|     local.get 0
    #|     struct.get $parent 0))
    #|
  let nested_global_pretty = gsi_test_pretty(nested_global_child, true)
  assert_true(
    nested_global_pretty.contains("struct.get"),
    msg=nested_global_pretty,
  )
  assert_false(
    nested_global_pretty.contains("select"),
    msg=nested_global_pretty,
  )
}

///|
test "global-struct-inference leaves unsafe local origins unchanged in closed world" {
  let mutable_field =
    #| (module
    #|   (type $box (sub (struct (field (mut i32)))))
    #|   (global $g (ref $box) (struct.new $box (i32.const 7)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let mutable_field_pretty = gsi_test_pretty(mutable_field, true)
  assert_true(
    mutable_field_pretty.contains("struct.get"),
    msg=mutable_field_pretty,
  )
  assert_false(
    mutable_field_pretty.contains("global.get"),
    msg=mutable_field_pretty,
  )

  let mutable_global =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (mut (ref $box)) (struct.new $box (i32.const 7)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let mutable_global_pretty = gsi_test_pretty(mutable_global, true)
  assert_true(
    mutable_global_pretty.contains("struct.get"),
    msg=mutable_global_pretty,
  )
  assert_false(
    mutable_global_pretty.contains("global.get"),
    msg=mutable_global_pretty,
  )

  let broad_global =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g anyref (struct.new $box (i32.const 7)))
    #|   (func (export "read") (param (ref null $box)) (result i32)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let broad_global_pretty = gsi_test_pretty(broad_global, true)
  assert_true(
    broad_global_pretty.contains("struct.get"),
    msg=broad_global_pretty,
  )
  assert_false(
    broad_global_pretty.contains("global.get"),
    msg=broad_global_pretty,
  )
}
