///|
test "host roots remove trailing debug code while preserving retained function indices" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (func (result i32) i32.const 9)
      #|   (func (export "run") (export "alias") (result i32) i32.const 42)
      #|   (func (result i32) i32.const 123456)
      #|   (func (export "debug") (result i32) call 2))
    ),
  )
  let output = rume_run_host_roots_module_pass(input, ["run", "alias"]).unwrap()
  @debug.assert_eq(output.code_sec.unwrap().0.length(), 2)
  @debug.assert_eq(output.export_sec.unwrap().0, [
    @lib.Export::new(
      @lib.Name::from_string("run"),
      @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
    ),
    @lib.Export::new(
      @lib.Name::from_string("alias"),
      @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
    ),
  ])
  @debug.assert_eq(@validate.validate_module(output), Ok(()))
  let (before, after) = @binary.encoded_module_sizes(input, output).unwrap()
  assert_true(after < before)
}

///|
test "host roots reject unknown exact export names before changing the module" {
  let input = pass_test_module_from_wat(
    (
      #| (module (func (export "run") (result i32) i32.const 42))
    ),
  )
  let saved = @binary.encode_module(input).unwrap()
  assert_true(rume_run_host_roots_module_pass(input, ["missing"]) is Err(_))
  @debug.assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "host roots preserve high returned references and all preceding function slots" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (func (export "run") (result funcref) ref.func 4)
      #|   (func (result i32) i32.const 11)
      #|   (func (result i32) i32.const 12)
      #|   (func (result i32) i32.const 13)
      #|   (func (result i32) i32.const 44)
      #|   (elem declare func 4)
      #|   (func (export "debug") (result i32) i32.const 99))
    ),
  )
  let output = rume_run_host_roots_module_pass(input, ["run"]).unwrap()
  @debug.assert_eq(output.code_sec.unwrap().0.length(), 5)
  @debug.assert_eq(output.export_sec.unwrap().0.length(), 1)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body, [@lib.Instruction::ref_func(@lib.FuncIdx::new(4U))])
  @debug.assert_eq(@validate.validate_module(output), Ok(()))
}

///|
test "host roots explicit empty contract preserves start effects and imported memory initialization" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (import "host" "tick" (func))
      #|   (import "host" "memory" (memory 1))
      #|   (data (i32.const 0) "init")
      #|   (func call 0)
      #|   (start 1)
      #|   (func (export "debug") (result i32) i32.const 99))
    ),
  )
  let output = rume_run_host_roots_module_pass(input, []).unwrap()
  @debug.assert_eq(output.export_sec.unwrap().0.length(), 0)
  @debug.assert_eq(output.import_sec, input.import_sec)
  @debug.assert_eq(output.data_sec, input.data_sec)
  @debug.assert_eq(output.start_sec, input.start_sec)
  @debug.assert_eq(output.code_sec.unwrap().0.length(), 1)
  @debug.assert_eq(@validate.validate_module(output), Ok(()))
}

///|
test "host roots preserve callback table resource exports and ordered initialization" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (type (func (result i32)))
      #|   (import "host" "tick" (func))
      #|   (memory (export "memory") 1)
      #|   (table (export "callbacks") 1 funcref)
      #|   (global (export "state") (mut i32) (i32.const 0))
      #|   (data (i32.const 0) "init")
      #|   (func (type 0) i32.const 43)
      #|   (elem (i32.const 0) func 1)
      #|   (func i32.const 7 global.set 0 call 0)
      #|   (start 2)
      #|   (func (export "run") (result i32)
      #|     i32.const 0 call_indirect (type 0) global.get 0 i32.add)
      #|   (func (result i32) i32.const 123456)
      #|   (func (export "debug") (result i32) call 4))
    ),
  )
  let output = rume_run_host_roots_module_pass(input, [
    "run", "memory", "callbacks", "state",
  ]).unwrap()
  @debug.assert_eq(output.code_sec.unwrap().0.length(), 3)
  @debug.assert_eq(output.import_sec, input.import_sec)
  @debug.assert_eq(output.start_sec, input.start_sec)
  @debug.assert_eq(output.elem_sec, input.elem_sec)
  @debug.assert_eq(output.data_sec, input.data_sec)
  @debug.assert_eq(
    output.code_sec.unwrap().0,
    input.code_sec.unwrap().0[:3].to_array(),
  )
  @debug.assert_eq(output.export_sec.unwrap().0.length(), 4)
  @debug.assert_eq(
    output.export_sec.unwrap().0[3],
    @lib.Export::new(
      @lib.Name::from_string("run"),
      @lib.ExternIdx::func(@lib.FuncIdx::new(3U)),
    ),
  )
  @debug.assert_eq(@validate.validate_module(output), Ok(()))
}

///|
test "host roots use exact Unicode names and duplicate roots have set semantics" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (func (export "λ, 7") (export "alias") (result i32) i32.const 42)
      #|   (func (export "debug") (result i32) i32.const 99))
    ),
  )
  let output = rume_run_host_roots_module_pass(input, [
    "alias", "λ, 7", "alias",
  ]).unwrap()
  @debug.assert_eq(
    output.export_sec.unwrap().0,
    input.export_sec.unwrap().0[:2].to_array(),
  )
  @debug.assert_eq(output.code_sec.unwrap().0.length(), 1)
  assert_true(rume_run_host_roots_module_pass(input, ["λ"]) is Err(_))
}

///|
test "host roots intentionally reject opaque offset metadata without altering input" {
  let base = pass_test_module_from_wat(
    (
      #| (module (func (export "run")) (func (export "debug")))
    ),
  )
  for name in ["reloc.CODE", "sourceMappingURL", "metadata.code.branch_hint"] {
    let input = base.with_custom_secs([
      @lib.CustomSec::new(@lib.Name::from_string(name), b"opaque"),
    ])
    let saved = @binary.encode_module(input).unwrap()
    assert_true(rume_run_host_roots_module_pass(input, ["run"]) is Err(_))
    @debug.assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "host roots retain public GC constructors and accessors while pruning a debug tail" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (type (struct (field f64)))
      #|   (type (struct (field i32)))
      #|   (func (export "make") (result (ref 1)) i32.const 7 struct.new 1)
      #|   (func (export "read") (param (ref 1)) (result i32) local.get 0 struct.get 1 0)
      #|   (func (export "debug") (result i32) i32.const 99))
    ),
  )
  let output = rume_run_host_roots_module_pass(input, ["make", "read"]).unwrap()
  @debug.assert_eq(output.code_sec.unwrap().0.length(), 2)
  @debug.assert_eq(
    output.export_sec.unwrap().0,
    input.export_sec.unwrap().0[:2].to_array(),
  )
  @debug.assert_eq(@validate.validate_module(output), Ok(()))
  let (before, after) = @binary.encoded_module_sizes(input, output).unwrap()
  assert_true(after < before)
}

///|
test "host roots preserve an absent export section on an already empty module" {
  let input = @lib.Module::new()
  let output = rume_run_host_roots_module_pass(input, []).unwrap()
  @debug.assert_eq(
    @binary.encode_module(output).unwrap(),
    b"\x00\x61\x73\x6d\x01\x00\x00\x00",
  )
}
