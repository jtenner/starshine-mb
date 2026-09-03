///|
fn pgg_test_run(text : String) -> @lib.Module {
  match
    run_hot_pipeline(
      pass_test_module_from_wat(text),
      HotPipelineOptions::new(),
      ["propagate-globals-globally"],
    ) {
    Ok(mod_) => mod_
    Err(err) => abort("expected propagate-globals-globally success, got \{err}")
  }
}

///|
fn pgg_test_defined_global_init(
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
fn pgg_test_first_data_offset(
  mod_ : @lib.Module,
) -> Array[@lib.Instruction] raise {
  match mod_.data_sec {
    Some(@lib.DataSec([@lib.Data(@lib.Active(_, @lib.Expr(instrs)), _)])) =>
      instrs
    other =>
      fail("expected one active data segment, got \{@debug.to_string(other)}")
  }
}

///|
fn pgg_test_first_elem_offset(
  mod_ : @lib.Module,
) -> Array[@lib.Instruction] raise {
  match mod_.elem_sec {
    Some(@lib.ElemSec([@lib.Elem(@lib.Active(_, @lib.Expr(instrs)), _)])) =>
      instrs
    other =>
      fail(
        "expected one active element segment, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pgg_test_first_function_body(
  mod_ : @lib.Module,
) -> Array[@lib.Instruction] raise {
  match mod_.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs)), ..])) => instrs
    other =>
      fail("expected one defined function, got \{@debug.to_string(other)}")
  }
}

///|
test "propagate-globals-globally registers as an active module pass" {
  match pass_registry_lookup("propagate-globals-globally") {
    Some(entry) => {
      @debug.assert_eq(entry.category, HotPassRegistryCategory::module_pass())
      @debug.assert_eq(entry.descriptor, None)
    }
    None => fail("expected propagate-globals-globally registry entry")
  }
}

///|
test "propagate-globals-globally rewrites direct and compound global initializers only" {
  let optimized = pgg_test_run(
    (
      #|(module
      #|  (global $a i32 (i32.const 42))
      #|  (global $b i32 (global.get $a))
      #|  (global $c i32
      #|    i32.const 1
      #|    global.get $b
      #|    i32.add)
      #|  (func (result i32)
      #|    global.get $b))
      #|,
    ),
  )

  @debug.assert_eq(try! pgg_test_defined_global_init(optimized, 1), [
    @lib.Instruction::i32_const(@lib.I32(42)),
  ])
  @debug.assert_eq(try! pgg_test_defined_global_init(optimized, 2), [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_const(@lib.I32(42)),
    @lib.Instruction::i32_add(),
  ])
  @debug.assert_eq(try! pgg_test_first_function_body(optimized), [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
  ])
}

///|
test "propagate-globals-globally intentionally does not promote arithmetic compound initializers to literal facts" {
  let optimized = pgg_test_run(
    (
      #|(module
      #|  (global $base i32 (i32.const 40))
      #|  (global $sum i32
      #|    global.get $base
      #|    i32.const 2
      #|    i32.add)
      #|  (global $copy i32 (global.get $sum)))
      #|,
    ),
  )

  @debug.assert_eq(try! pgg_test_defined_global_init(optimized, 1), [
    @lib.Instruction::i32_const(@lib.I32(40)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
  ])
  @debug.assert_eq(try! pgg_test_defined_global_init(optimized, 2), [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(1U)),
  ])
}

///|
test "propagate-globals-globally rewrites string globals inside GC constant expressions" {
  let optimized = pgg_test_run(
    (
      #|(module
      #|  (type $pair (struct (field stringref) (field stringref)))
      #|  (global $left stringref (string.const "left"))
      #|  (global $right stringref (string.const "right"))
      #|  (global $pair-global (ref $pair)
      #|    global.get $left
      #|    global.get $right
      #|    struct.new $pair))
      #|,
    ),
  )

  match (try! pgg_test_defined_global_init(optimized, 2)) {
    [@lib.StringConst(left), @lib.StringConst(right), @lib.StructNew(_)] => {
      @debug.assert_eq(left, b"left")
      @debug.assert_eq(right, b"right")
    }
    other =>
      fail("expected string constants in struct initializer, got \{other}")
  }
}

///|
test "propagate-globals-globally rewrites active data offsets" {
  let optimized = pgg_test_run(
    (
      #|(module
      #|  (global $offset i32 (i32.const 8))
      #|  (memory 1)
      #|  (data (global.get $offset) "abc"))
      #|,
    ),
  )

  @debug.assert_eq(try! pgg_test_first_data_offset(optimized), [
    @lib.Instruction::i32_const(@lib.I32(8)),
  ])
}

///|
test "propagate-globals-globally rewrites active element offsets" {
  let optimized = pgg_test_run(
    (
      #|(module
      #|  (type $void (func))
      #|  (func $target)
      #|  (global $offset i32 (i32.const 1))
      #|  (table 4 funcref)
      #|  (elem (global.get $offset) func $target))
      #|,
    ),
  )

  @debug.assert_eq(try! pgg_test_first_elem_offset(optimized), [
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "propagate-globals-globally preserves unknown imported globals and passive segments" {
  let optimized = pgg_test_run(
    (
      #|(module
      #|  (import "env" "offset" (global $offset i32))
      #|  (global $copy i32 (global.get $offset))
      #|  (memory 1)
      #|  (data "abc"))
      #|,
    ),
  )

  @debug.assert_eq(try! pgg_test_defined_global_init(optimized, 0), [
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
  ])
  match optimized.data_sec {
    Some(@lib.DataSec([@lib.Data(@lib.Passive, bytes)])) =>
      @debug.assert_eq(bytes, b"abc")
    other =>
      fail("expected passive data segment, got \{@debug.to_string(other)}")
  }
}
