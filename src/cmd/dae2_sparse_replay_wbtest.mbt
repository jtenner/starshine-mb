///|
test "DAE2 sparse HOT replay dispatcher preserves indirect arm inputs while pruning a parameter" {
  let input = @wast.wast_to_binary_module(
    "(module (type $sig (func (param i32 i32) (result i32))) (table 1 funcref) (func $pair (type $sig) local.get 1) (elem (i32.const 0) $pair) (func $h (param i32 i32 i64) (result i32) local.get 0 if (result i32) i32.const 7 local.get 1 i32.const 0 call_indirect (type $sig) else i32.const 9 local.get 1 i32.const 0 call_indirect (type $sig) end) (func (export \"run\") (param i32 i32) (result i32) local.get 0 local.get 1 i64.const 9 call $h))",
  ).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for pass_name in ["dae2", "dae2-optimizing"] {
    let output = optimize_module_with_pass_flags(
      input,
      [pass_name],
      OptimizeOptions::new(),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(
      @validate.empty_env()
      .with_module(output)
      .resolve_functype(output.func_sec.unwrap().0[1])
      .unwrap(),
      @lib.FuncType::new([@lib.ValType::i32(), @lib.ValType::i32()], [
        @lib.ValType::i32(),
      ]),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
