///|
// The baseline has only ordinary RUME. This test adapter exposes its behavior
// under the proposed explicit application contract before the API is added.
fn host_roots_test_run(
  mod_ : @lib.Module,
  _roots : Array[String],
) -> Result[@lib.Module, String] {
  Ok(rume_run_module_pass(mod_))
}

///|
test "host roots remove trailing debug code while preserving retained function indices" {
  let input = pass_test_module_from_wat(
    #| (module
    #|   (func (result i32) i32.const 9)
    #|   (func (export "run") (export "alias") (result i32) i32.const 42)
    #|   (func (result i32) i32.const 123456)
    #|   (func (export "debug") (result i32) call 2))
  )
  let output = host_roots_test_run(input, ["run", "alias"]).unwrap()
  @debug.assert_eq(output.code_sec.unwrap().0.length(), 2)
  @debug.assert_eq(output.export_sec.unwrap().0, [
    @lib.Export::new(@lib.Name::from_string("run"), @lib.ExternIdx::func(@lib.FuncIdx::new(1U))),
    @lib.Export::new(@lib.Name::from_string("alias"), @lib.ExternIdx::func(@lib.FuncIdx::new(1U))),
  ])
  @debug.assert_eq(@validate.validate_module(output), Ok(()))
  let (before, after) = @binary.encoded_module_sizes(input, output).unwrap()
  assert_true(after < before)
}

///|
test "host roots reject unknown exact export names before changing the module" {
  let input = pass_test_module_from_wat(
    #| (module (func (export "run") (result i32) i32.const 42))
  )
  let saved = @binary.encode_module(input).unwrap()
  assert_true(host_roots_test_run(input, ["missing"]) is Err(_))
  @debug.assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "host roots preserve high returned references and all preceding function slots" {
  let input = pass_test_module_from_wat(
    #| (module
    #|   (func (export "run") (result funcref) ref.func 4)
    #|   (func (result i32) i32.const 11)
    #|   (func (result i32) i32.const 12)
    #|   (func (result i32) i32.const 13)
    #|   (func (result i32) i32.const 44)
    #|   (elem declare func 4)
    #|   (func (export "debug") (result i32) i32.const 99))
  )
  let output = host_roots_test_run(input, ["run"]).unwrap()
  @debug.assert_eq(output.code_sec.unwrap().0.length(), 5)
  @debug.assert_eq(output.export_sec.unwrap().0.length(), 1)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body, [@lib.Instruction::ref_func(@lib.FuncIdx::new(4U))])
  @debug.assert_eq(@validate.validate_module(output), Ok(()))
}

///|
test "host roots explicit empty contract preserves start effects and imported memory initialization" {
  let input = pass_test_module_from_wat(
    #| (module
    #|   (import "host" "tick" (func))
    #|   (import "host" "memory" (memory 1))
    #|   (data (i32.const 0) "init")
    #|   (func call 0)
    #|   (start 1)
    #|   (func (export "debug") (result i32) i32.const 99))
  )
  let output = host_roots_test_run(input, []).unwrap()
  @debug.assert_eq(output.export_sec.unwrap().0.length(), 0)
  @debug.assert_eq(output.import_sec, input.import_sec)
  @debug.assert_eq(output.data_sec, input.data_sec)
  @debug.assert_eq(output.start_sec, input.start_sec)
  @debug.assert_eq(output.code_sec.unwrap().0.length(), 1)
  @debug.assert_eq(@validate.validate_module(output), Ok(()))
}
