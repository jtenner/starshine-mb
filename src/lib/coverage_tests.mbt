///|
test "locals at lookup uses run indices across grouped declarations" {
  let locals = Locals::new([
    LocalRun::new(2U, ValType::i32()),
    LocalRun::new(1U, ValType::i64()),
    LocalRun::new(3U, ValType::f32()),
  ])
  assert_eq(locals.at(0), Some(ValType::i32()))
  assert_eq(locals.at(1), Some(ValType::i32()))
  assert_eq(locals.at(2), Some(ValType::i64()))
  assert_eq(locals.at(3), Some(ValType::f32()))
  assert_eq(locals.at(5), Some(ValType::f32()))
  assert_eq(locals.at(6), None)
}

///|
test "locals ensure_index caches run starts and rebuilds after mutation" {
  let locals = Locals::new([
    LocalRun::new(2U, ValType::i32()),
    LocalRun::new(2U, ValType::i64()),
    LocalRun::new(1U, ValType::i32()),
  ])
  assert_eq(locals.ensure_index(), [0, 2, 4])
  locals.push(ValType::i32())
  assert_eq(locals.ensure_index(), [0, 2, 4])
  assert_true(locals.set(2, ValType::f32()))
  assert_eq(locals.ensure_index(), [0, 2, 3, 4])
}

///|
test "locals insert remove and without_prefix keep indices aligned" {
  let locals = Locals::new([
    LocalRun::new(2U, ValType::i32()),
    LocalRun::new(1U, ValType::i64()),
  ])
  locals.insert_run(1, LocalRun::new(3U, ValType::f32()))
  assert_eq(locals.ensure_index(), [0, 2, 5])
  ignore(locals.remove_run(0))
  assert_eq(locals.ensure_index(), [0, 3])
  let suffix = locals.without_prefix(1)
  assert_eq(suffix.ensure_index(), [0, 2])
  assert_eq(suffix.at(0), Some(ValType::f32()))
  assert_eq(suffix.at(2), Some(ValType::i64()))
}

///|
test "typed_instrs_to_expr preserves stack order for local.set" {
  let body = [
    TypedInstr::local_set(LocalIdx::new(0), TypedInstr::i32_const(I32(7))),
  ]
  let Expr(instrs) = typed_instrs_to_expr(body)
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
