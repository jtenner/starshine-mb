///|
test "command DAE indexed signature lookup preserves kept and discarded call order" {
  let output = cmd_deep_audit_run(
    "(module (import \"env\" \"keep\" (func $keep (result i32))) (import \"env\" \"discard\" (func $discard (result i32))) (func $helper (param i32 i32) (result i32) local.get 0) (func (export \"run\") (result i32) call $keep call $discard call $helper))",
    "dae",
  )
  @validate.validate_module(output).unwrap()
  let type_index = match output.func_sec.unwrap().0[0] {
    @lib.TypeIdx(raw) => raw.to_int()
    _ => abort("expected absolute helper signature")
  }
  match
    output.type_sec.unwrap().0[type_index]
    .get_subtype(0U)
    .unwrap()
    .get_comptype() {
    @lib.FuncCompType(params, results) => {
      assert_eq(params, [@lib.ValType::i32()])
      assert_eq(results, [@lib.ValType::i32()])
    }
    _ => abort("expected helper function signature")
  }
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  let calls : Array[UInt] = []
  for instr in body {
    match instr {
      @lib.Call(@lib.FuncIdx(raw)) => calls.push(raw)
      _ => ()
    }
  }
  assert_eq(calls, [0U, 1U, 2U])
}
