///|
test "types constructors and accessors keep heap reference shape" {
  let typed_heap = HeapType::new(TypeIdx::new(7))
  let ref_type = RefType::new(false, typed_heap)
  assert_true(ref_type.is_non_nullable())
  assert_eq(ref_type.get_heap_type(), typed_heap)

  let nullable_ref = ref_type.make_nullable()
  assert_true(nullable_ref.is_nullable())
  match nullable_ref {
    HeapTypeRefType(nullable, HeapType(TypeIdx(i))) => {
      assert_true(nullable)
      assert_eq(i, 7U)
    }
    _ => fail("expected nullable ref over concrete TypeIdx")
  }

  let comp = CompType::func([ValType::i32()], [ValType::externref()])
  let sub = SubType::new(true, [TypeIdx::new(1), TypeIdx::rec(0)], comp)
  assert_eq(sub.super_types().length(), 2)
  assert_eq(sub.get_comptype(), comp)
}

///|
test "rectype get_subtype handles in-range and out-of-range indexes" {
  let first = SubType::comp_type(CompType::func([], []))
  let second = SubType::comp_type(CompType::func([ValType::i64()], []))
  let group = RecType::group([first, second])

  assert_eq(group.get_subtype(0), Some(first))
  assert_eq(group.get_subtype(1), Some(second))
  assert_eq(group.get_subtype(2), None)
}

///|
test "tlocals_to_locals and expand_locals roundtrip valtypes" {
  let original = [
    ValType::i32(),
    ValType::i32(),
    ValType::funcref(),
    ValType::funcref(),
    ValType::i64(),
  ]
  let grouped = tlocals_to_locals(original.copy())
  let expanded = match expand_locals(grouped) {
    Ok(vts) => vts
    Err(e) => fail("unexpected expand_locals error: \{e}")
  }
  assert_eq(expanded, original)
}

///|
test "TExpr.to_expr lowers nested if with explicit operand order" {
  let texpr = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([TInstr::i32_const(I32(1))]),
      Some(TExpr::new([TInstr::i32_const(I32(0))])),
    ),
  ])
  let Expr(instrs) = texpr.to_expr()
  assert_eq(instrs.length(), 2)

  match instrs[0] {
    LocalGet(LocalIdx(i)) => assert_eq(i, 0U)
    _ => fail("expected condition local.get before if")
  }
  match instrs[1] {
    If(VoidBlockType, [I32Const(I32(then_v))], Some([I32Const(I32(else_v))])) => {
      assert_eq(then_v, 1)
      assert_eq(else_v, 0)
    }
    _ => fail("expected lowered if instruction with both branches")
  }
}
