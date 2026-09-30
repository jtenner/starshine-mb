///|
test "terminal-copy cleanup command preserves return type and observable call" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (result i32) (local i32) block (result i32) i32.const 7 local.set 0 local.get 0 call $consume local.get 0 end))",
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
    assert_eq(calls, [0U])
    let type_index = match output.func_sec.unwrap().0[0] {
      @lib.TypeIdx(raw) => raw.to_int()
      _ => abort("expected absolute function signature")
    }
    match
      output.type_sec.unwrap().0[type_index]
      .get_subtype(0U)
      .unwrap()
      .get_comptype() {
      @lib.FuncCompType(params, results) => {
        assert_eq(params, [])
        assert_eq(results, [@lib.ValType::i32()])
      }
      _ => abort("expected function signature")
    }
  }
}
