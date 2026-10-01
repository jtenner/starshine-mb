///|
test "DAE2 sorting fast path preserves producer barrier consumer call order" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"effect\" (func $effect)) (import \"env\" \"consume\" (func $consume (param i32))) (func $unused (param i32) loop nop end) (func (export \"run\") (local i32) call $produce call $effect local.set 0 local.get 0 call $consume local.get 0 call $unused))",
  ).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for pass_name in ["dae2", "dae2-optimizing"] {
    let output = optimize_module_with_pass_flags(
      input,
      [pass_name],
      OptimizeOptions::new(),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
    let calls : Array[@lib.Instruction] = []
    profitable_alias_test_calls(body, calls)
    assert_eq(
      calls,
      [0U, 1U, 2U, 3U].map(fn(index) {
        @lib.Instruction::call(@lib.FuncIdx::new(index))
      }),
    )
    assert_eq(
      @validate.empty_env()
      .with_module(output)
      .resolve_functype(output.func_sec.unwrap().0[0])
      .unwrap(),
      @lib.FuncType::new([], []),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
