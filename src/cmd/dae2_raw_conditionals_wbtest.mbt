///|
test "DAE2 conditional analysis command preserves arm inputs while pruning a dead parameter" {
  let input = @wast.wast_to_binary_module(
    "(module (func $h (param i32 i32 i32 i64) (result i32) local.get 0 if (result i32) local.get 1 else local.get 2 end) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
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
      @lib.FuncType::new(
        [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
        [@lib.ValType::i32()],
      ),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
