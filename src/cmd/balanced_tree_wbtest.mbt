///|
test "balanced tree cleanup command preserves nested effects and input ownership" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (import \"env\" \"tick\" (func $tick)) (func (export \"run\") (local i32) block call $tick end block call $produce local.set 0 call $tick local.get 0 call $consume end block call $tick end))",
  ).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for pass_name in ["simplify-locals", "dae2-optimizing"] {
    let output = optimize_module_with_pass_flags(
      input,
      [pass_name],
      OptimizeOptions::new(),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    let calls = []
    balanced_range_command_calls(body, calls)
    assert_eq(calls, [2U, 0U, 2U, 1U, 2U])
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
