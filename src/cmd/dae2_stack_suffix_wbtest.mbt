///|
test "dae2 command prunes mixed scalar reference suffixes inside a loop" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func $h (param i32 i64 externref) local.get 0 call $consume) (func (export \"run\") loop call $produce i64.const 9 ref.null extern call $h end))",
  ).unwrap()
  for pass_ in ["dae2", "dae2-optimizing"] {
    let output = optimize_module_with_pass_flags(
      input,
      [pass_],
      OptimizeOptions::new(),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    let type_index = match output.func_sec.unwrap().0[0] {
      @lib.TypeIdx(raw) => raw.to_int()
      _ => fail("expected absolute helper signature")
    }
    match
      output.type_sec.unwrap().0[type_index]
      .get_subtype(0U)
      .unwrap()
      .get_comptype() {
      @lib.FuncCompType(params, results) => {
        assert_eq(params, [@lib.ValType::i32()])
        assert_eq(results, [])
      }
      _ => fail("expected helper function signature")
    }
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
    assert_eq(locals.length(), 0)
    let loop_body = match body[0] {
      @lib.Loop(_, @lib.Expr(body)) => body
      _ => fail("missing loop")
    }
    assert_eq(loop_body, [
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(2U)),
    ])
  }
}
