///|
test "DAE2 entry-source finalization preserves root writes across effectful control" {
  let input = @wast.wast_to_binary_module(
    (
      #|(module
      #| (import "host" "f" (func (param i32) (result i32)))
      #| (func $callee (param i32 i64) (result i32) (local i32 i32)
      #|  local.get 0 local.set 2
      #|  local.get 0 i32.const 1 i32.add local.set 3
      #|  loop local.get 2 call 0 drop end
      #|  local.get 0 if local.get 3 call 0 drop
      #|  else local.get 2 call 0 drop end
      #|  local.get 2 local.get 3 i32.add local.get 0 i32.div_s)
      #| (func (export "run") (param i32) (result i32)
      #|  local.get 0 i64.const 99 call $callee))
    ),
  ).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for pass in ["dae2", "dae2-optimizing"] {
    let output = optimize_module_with_pass_flags(
      input,
      [pass],
      OptimizeOptions::new(),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(
      @validate.Env::new()
      .with_module(output)
      .get_functype_by_funcidx(@lib.FuncIdx::new(1U)),
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
    )
    assert_eq(output.import_sec, input.import_sec)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
