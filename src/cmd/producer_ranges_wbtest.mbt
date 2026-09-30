///|
test "producer range cleanup command preserves pure arguments and effect order" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (import \"env\" \"tick\" (func $tick)) (func (export \"run\") (local i32 i32) block i32.const 7 local.set 0 call $produce local.set 1 call $tick local.get 0 call $consume local.get 1 call $consume end))",
  ).unwrap()
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
    assert_eq(calls, [0U, 2U, 1U, 1U])
  }
}
