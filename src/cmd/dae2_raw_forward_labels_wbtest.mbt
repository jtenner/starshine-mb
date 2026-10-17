///|
test "DAE2 forward-label command preserves branch inputs while pruning" {
  let input = @wast.wast_to_binary_module(
    "(module (func $h (param i32 i32 i64) (result i32) block $out (result i32) local.get 0 if local.get 1 br $out end local.get 1 end) (func (export \"run\") (param i32 i32) (result i32) local.get 0 local.get 1 i64.const 9 call $h))",
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
      .resolve_functype(output.func_sec.unwrap().0[0])
      .unwrap(),
      @lib.FuncType::new([@lib.ValType::i32(), @lib.ValType::i32()], [
        @lib.ValType::i32(),
      ]),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
