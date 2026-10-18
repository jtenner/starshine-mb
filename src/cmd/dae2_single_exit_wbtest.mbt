///|
test "DAE2 command variants preserve locals crossing single-exit blocks and outer branches" {
  let input = @wast.wast_to_binary_module(
    "(module (func $h (param i32 i32 i64) (result i32) (local i32) block $out local.get 0 br_if $out block block local.get 1 local.set 3 end end end local.get 3) (func (export \"run\") (param i32 i32) (result i32) local.get 0 local.get 1 i64.const 9 call $h))",
  ).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for name in ["dae2", "dae2-optimizing"] {
    let output = optimize_module_with_pass_flags(
      input,
      [name],
      OptimizeOptions::new(),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    let env = @validate.Env::new().with_module(output)
    assert_eq(
      env.get_functype_by_funcidx(@lib.FuncIdx::new(0U)),
      Some(
        @lib.FuncType::new([@lib.ValType::i32(), @lib.ValType::i32()], [
          @lib.ValType::i32(),
        ]),
      ),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
