///|
test "DAE2 loop command preserves indexed entry payloads and prunes unused parameters" {
  for
    body in [
      "local.get 1 local.set 3 loop $again local.get 3 i32.const 1 i32.sub local.set 3 local.get 0 br_if $again end local.get 3",
      "local.get 1 loop $again (type $one) local.set 3 local.get 3 i32.const 1 i32.sub local.get 0 br_if $again drop end local.get 3",
    ] {
    let input = @wast.wast_to_binary_module(
      "(module (type $one (func (param i32))) (func $h (param i32 i32 i64) (result i32) (local i32) \{body}) (func (export \"run\") (param i32 i32) (result i32) local.get 0 local.get 1 i64.const 9 call $h))",
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
}
