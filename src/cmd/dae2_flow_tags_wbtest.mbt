///|
test "DAE2 flow source tags prune overwritten and unused parameters through a loop" {
  for
    (defs, ty, arg) in [
      ("", "i32", "i32.const 17"),
      ("(type $s (struct (field i32)))", "(ref null $s)", "ref.null $s"),
    ] {
    let input = @wast.wast_to_binary_module(
      "(module \{defs} (import \"env\" \"tick\" (func $tick (param i32))) (func $callee (param i32 \{ty}) (result i32) i32.const 2 local.set 0 loop local.get 0 call $tick local.get 0 i32.const 1 i32.sub local.tee 0 br_if 0 end local.get 0) (func (export \"run\") (param i32) (result i32) local.get 0 \{arg} call $callee))",
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
        @lib.FuncType::new([], [@lib.ValType::i32()]),
      )
      assert_eq(@binary.encode_module(input).unwrap(), saved)
    }
  }
}
