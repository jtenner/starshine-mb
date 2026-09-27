///|
test "command DAE modes keep nonconstant arguments and specialize uniform literals" {
  for pass in ["dae", "dae-optimizing"] {
    let dynamic = cmd_deep_audit_run(
      "(module (func $id (param i32) (result i32) local.get 0) (func (export \"run\") (param i32) (result i32) local.get 0 call $id))",
      pass,
    )
    @validate.validate_module(dynamic).unwrap()
    let dynamic_type = match dynamic.func_sec.unwrap().0[0] {
      @lib.TypeIdx(raw) => raw
      _ => abort("expected absolute fixture signature")
    }
    match
      dynamic.type_sec.unwrap().0[dynamic_type.to_int()]
      .get_subtype(0U)
      .unwrap()
      .get_comptype() {
      @lib.FuncCompType(params, results) => {
        assert_eq(params, [@lib.ValType::i32()])
        assert_eq(results, [@lib.ValType::i32()])
      }
      _ => abort("expected dynamic callee signature")
    }
    let literal = cmd_deep_audit_run(
      "(module (func $id (param i32) (result i32) local.get 0) (func (export \"run\") (result i32) i32.const 7 call $id))",
      pass,
    )
    @validate.validate_module(literal).unwrap()
    let literal_type = match literal.func_sec.unwrap().0[0] {
      @lib.TypeIdx(raw) => raw
      _ => abort("expected absolute fixture signature")
    }
    match
      literal.type_sec.unwrap().0[literal_type.to_int()]
      .get_subtype(0U)
      .unwrap()
      .get_comptype() {
      @lib.FuncCompType(params, results) => {
        assert_eq(params.length(), 0)
        assert_eq(results, [@lib.ValType::i32()])
      }
      _ => abort("expected specialized callee signature")
    }
    let @lib.Func(_, @lib.Expr(body)) = literal.code_sec.unwrap().0[0]
    assert_true(body.contains(@lib.Instruction::i32_const(7)))
  }
}
