///|
test "command DAE modes prune repeated uniform-literal helpers while retaining import effects" {
  let source = [
    "(module (type $heap (struct (field i32))) (import \"m\" \"value\" (func $value (result i32)))",
  ]
  for index in 0..<4 {
    source.push(
      "(func $h\{index} (param i32) (result i32) local.get 0 i32.const 1 i32.add)",
    )
    source.push(
      "(func (export \"run\{index}\") (param i32) (result i32) call $value drop i32.const 7 call $h\{index})",
    )
  }
  source.push(")")
  for pass in ["dae", "dae-optimizing"] {
    let output = cmd_deep_audit_run(source.join(" "), pass)
    @validate.validate_module(output).unwrap()
    let env = @validate.Env::new().with_module(output)
    for index in 0..<4 {
      assert_eq(
        env.get_functype_by_funcidx(
          @lib.FuncIdx::new((index * 2 + 1).to_uint()),
        ),
        Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
      )
      let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[index * 2 +
        1]
      assert_eq(body[0], @lib.Instruction::call(@lib.FuncIdx::new(0U)))
      assert_eq(body[1], @lib.Instruction::drop())
    }
  }
}
