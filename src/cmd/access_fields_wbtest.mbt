///|
test "DAE2 checked source-order fields preserve repeated effectful local consumers" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (local i32 i32 i32 i32) call $produce local.set 3 local.get 3 call $consume local.get 3 call $consume local.get 3 local.set 0 block local.get 0 call $consume local.get 0 call $consume end))",
  ).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for pass_name in ["dae2", "dae2-optimizing"] {
    let output = optimize_module_with_pass_flags(
      input,
      [pass_name],
      OptimizeOptions::new(),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    let calls : Array[@lib.Instruction] = []
    profitable_alias_test_calls(body, calls)
    assert_eq(
      calls,
      [0U, 1U, 1U, 1U, 1U].map(fn(index) {
        @lib.Instruction::call(@lib.FuncIdx::new(index))
      }),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
