///|
test "expand_locals expands grouped declarations in order" {
  let expanded = match
    expand_locals([
      Locals::new(2U, ValType::i32()),
      Locals::new(1U, ValType::i64()),
    ]) {
    Ok(v) => v
    Err(e) => fail("unexpected expand_locals error: \{e}")
  }
  assert_eq(expanded, [ValType::i32(), ValType::i32(), ValType::i64()])
}

///|
test "tlocals_to_locals compresses consecutive equal valtypes" {
  let grouped = tlocals_to_locals([
    ValType::i32(),
    ValType::i32(),
    ValType::i64(),
    ValType::i64(),
    ValType::i32(),
  ])
  assert_eq(grouped.length(), 3)
  let Locals(c0, t0) = grouped[0]
  let Locals(c1, t1) = grouped[1]
  let Locals(c2, t2) = grouped[2]
  assert_eq(c0, 2U)
  assert_eq(t0, ValType::i32())
  assert_eq(c1, 2U)
  assert_eq(t1, ValType::i64())
  assert_eq(c2, 1U)
  assert_eq(t2, ValType::i32())
}

///|
test "TExpr.to_expr preserves stack order for local.set" {
  let texpr = TExpr::new([
    TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(7))),
  ])
  let Expr(instrs) = texpr.to_expr()
  assert_eq(instrs.length(), 2)
  match instrs[0] {
    I32Const(I32(v)) => assert_eq(v, 7)
    _ => fail("expected i32.const before local.set")
  }
  match instrs[1] {
    LocalSet(LocalIdx(i)) => assert_eq(i, 0U)
    _ => fail("expected local.set after pushed value")
  }
}
