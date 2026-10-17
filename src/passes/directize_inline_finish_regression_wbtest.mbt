///|
fn dif_test_exported_run_body(mod_ : @lib.Module) -> Array[@lib.Instruction] {
  let @lib.ExportSec(exports) = mod_.export_sec.unwrap()
  let @lib.CodeSec(funcs) = mod_.code_sec.unwrap()
  for export_ in exports {
    match export_ {
      @lib.Export(@lib.Name("run"), @lib.FuncExternIdx(@lib.FuncIdx(index))) => {
        let @lib.Func(_, @lib.Expr(body)) = funcs[index.to_int()]
        return body
      }
      _ => ()
    }
  }
  abort("expected run export")
}

///|
fn dif_test_instruction_events(
  body : Array[@lib.Instruction],
  events : Array[String],
) -> Unit {
  for instr in body {
    match instr {
      @lib.Call(_) => events.push("call")
      @lib.CallIndirect(_, _) => events.push("call_indirect")
      @lib.GlobalSet(_) => events.push("global.set")
      @lib.Unreachable => events.push("unreachable")
      _ => ()
    }
    ignore(
      pass_lower_map_children(instr, fn(child) {
        dif_test_instruction_events(child, events)
        child
      }),
    )
  }
}

///|
fn dif_test_events(mod_ : @lib.Module) -> Array[String] {
  let events : Array[String] = []
  dif_test_instruction_events(dif_test_exported_run_body(mod_), events)
  events
}

///|
fn dif_test_tiny_target() -> @lib.Module {
  pass_test_module_from_wat(
    (
      #|(module
      #|  (type $sig (func (result i32)))
      #|  (table 1 funcref)
      #|  (func $target (type $sig) (result i32) i32.const 42)
      #|  (elem (i32.const 0) $target)
      #|  (func (export "run") (result i32)
      #|    i32.const 0 call_indirect (type $sig)))
    ),
  )
}

///|
test "O4z finishes inlining a newly direct immutable table target" {
  let options = HotPipelineOptions::new(optimize_level=4, shrink_level=4)
  let optimized = run_hot_pipeline(dif_test_tiny_target(), options, ["optimize"]).unwrap()
  let finished = run_hot_pipeline(optimized, options, [
    "directize", "inlining-optimizing", "remove-unused-module-elements", "vacuum",
  ]).unwrap()
  assert_true(@validate.validate_module(optimized).is_ok())
  assert_true(@validate.validate_module(finished).is_ok())
  // The existing explicit finish is a concrete output-size control. The full
  // library preset must not retain a call that this bounded finish removes.
  let optimized_bytes = @binary.encode_module(optimized).unwrap()
  let finished_bytes = @binary.encode_module(finished).unwrap()
  assert_true(
    optimized_bytes.length() <= finished_bytes.length(),
    msg="full preset retains bytes removed by directize then inline cleanup",
  )
  @debug.assert_eq(dif_test_exported_run_body(optimized), [
    @lib.Instruction::i32_const(@lib.I32(42)),
  ])
}

///|
test "short public preset retains its existing indirect-call policy" {
  let input = dif_test_tiny_target()
  let options = HotPipelineOptions::new(optimize_level=4, shrink_level=0)
  let names = pass_registry_expanded_names_for_module(input, options, [
    "optimize",
  ]).unwrap()
  assert_false(names.contains("directize"))
  assert_false(names.contains("inlining-optimizing"))
  let optimized = run_hot_pipeline(input, options, ["optimize"]).unwrap()
  assert_true(@validate.validate_module(optimized).is_ok())
  @debug.assert_eq(dif_test_events(optimized), ["call_indirect"])
}

///|
test "O4z inline finish preserves side-effectful target arguments" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $sig (func (param i32) (result i32)))
      #|  (global $observed (export "observed") (mut i32) (i32.const 0))
      #|  (table 1 funcref)
      #|  (func $target (type $sig) (param i32) (result i32) local.get 0)
      #|  (elem (i32.const 0) $target)
      #|  (func (export "run") (result i32)
      #|    i32.const 37 global.set $observed
      #|    i32.const 41 i32.const 0 call_indirect (type $sig)))
    ),
  )
  let optimized = run_hot_pipeline(
    input,
    HotPipelineOptions::new(optimize_level=4, shrink_level=4),
    ["optimize"],
  ).unwrap()
  assert_true(@validate.validate_module(optimized).is_ok())
  @debug.assert_eq(dif_test_events(optimized), ["global.set"])
  @debug.assert_eq(dif_test_exported_run_body(optimized), [
    @lib.Instruction::i32_const(@lib.I32(37)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(41)),
    @lib.Instruction::return_(),
  ])
  let finished = run_hot_pipeline(
    optimized,
    HotPipelineOptions::new(optimize_level=4, shrink_level=4),
    [
      "directize", "inlining-optimizing", "remove-unused-module-elements", "vacuum",
    ],
  ).unwrap()
  assert_true(@validate.validate_module(finished).is_ok())
  assert_true(
    @binary.encode_module(optimized).unwrap().length() <=
    @binary.encode_module(finished).unwrap().length(),
    msg="side-effectful finish retains bytes removed by explicit cleanup",
  )
}

///|
test "O4z inline finish keeps mutable table calls indirect" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $sig (func (result i32)))
      #|  (table 1 funcref)
      #|  (func $target (type $sig) (result i32) i32.const 42)
      #|  (elem (i32.const 0) $target)
      #|  (func (export "set") (param funcref)
      #|    i32.const 0 local.get 0 table.set 0)
      #|  (func (export "run") (result i32)
      #|    i32.const 0 call_indirect (type $sig)))
    ),
  )
  let optimized = run_hot_pipeline(
    input,
    HotPipelineOptions::new(optimize_level=4, shrink_level=4),
    ["optimize"],
  ).unwrap()
  assert_true(@validate.validate_module(optimized).is_ok())
  @debug.assert_eq(dif_test_events(optimized), ["call_indirect"])
}

///|
test "O4z inline finish preserves argument effects before an out-of-bounds target trap" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $sig (func (param i32) (result i32)))
      #|  (global $observed (export "observed") (mut i32) (i32.const 0))
      #|  (table 1 funcref)
      #|  (func $target (type $sig) (param i32) (result i32) local.get 0)
      #|  (elem (i32.const 0) $target)
      #|  (func (export "run") (result i32)
      #|    i32.const 37 global.set $observed
      #|    i32.const 41 i32.const 1 call_indirect (type $sig)))
    ),
  )
  let optimized = run_hot_pipeline(
    input,
    HotPipelineOptions::new(optimize_level=4, shrink_level=4),
    ["optimize"],
  ).unwrap()
  assert_true(@validate.validate_module(optimized).is_ok())
  @debug.assert_eq(dif_test_events(optimized), ["global.set", "unreachable"])
}

///|
test "Directize module identity distinguishes a rewrite from a no-op" {
  let input = dif_test_tiny_target()
  let direct = directize_run_module_pass(input)
  assert_false(physical_equal(input, direct))
  @debug.assert_eq(dif_test_events(direct), ["call"])
  assert_true(physical_equal(direct, directize_run_module_pass(direct)))
  let plain = pass_test_module_from_wat(
    "(module (func (export \"run\") (result i32) i32.const 42))",
  )
  assert_true(physical_equal(plain, directize_run_module_pass(plain)))
}
