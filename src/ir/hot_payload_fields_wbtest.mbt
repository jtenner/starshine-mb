///|
test "exact payload reads preserve both immediate lanes across all families" {
  let func = HotFunc::new()
  let first = hot_alloc_instr_payload(
    func,
    HotInstrPayload::new(@lib.Instruction::i32_add()),
  )
  let last = hot_alloc_instr_payload(
    func,
    HotInstrPayload::new(@lib.Instruction::i64_add()),
  )
  let id = hot_build_nop(func)
  let imm1_ops = [
    HotOp::Load,
    HotOp::Store,
    HotOp::RefTest,
    HotOp::RefCast,
    HotOp::RefTestDesc,
    HotOp::RefCastDescEq,
    HotOp::BrOnCast,
    HotOp::BrOnCastFail,
    HotOp::Atomic,
  ]
  let imm0_ops = [
    HotOp::Select,
    HotOp::Heap,
    HotOp::Continuation,
    HotOp::Unary,
    HotOp::Binary,
    HotOp::Compare,
    HotOp::Convert,
    HotOp::StringOp,
    HotOp::Simd,
  ]
  // These isolated records exercise the payload query contract, not opcode
  // operand typing. No complete-function validity is claimed for this fixture.
  for op in imm1_ops {
    hot_node_set(func, id, {
      ..hot_node_get(func, id),
      op,
      imm0: first,
      imm1: last,
    })
    assert_eq(hot_node_exact_instr_payload_id(func, id), Some(last))
    assert_eq(hot_node_exact_instr(func, id), Some(@lib.Instruction::i64_add()))
    assert_true(hot_verify_node_exact_instr_payload(func, id))
  }
  for op in imm0_ops {
    hot_node_set(func, id, {
      ..hot_node_get(func, id),
      op,
      imm0: first,
      imm1: last,
    })
    assert_eq(hot_node_exact_instr_payload_id(func, id), Some(first))
    assert_eq(hot_node_exact_instr(func, id), Some(@lib.Instruction::i32_add()))
    assert_true(hot_verify_node_exact_instr_payload(func, id))
  }
  for
    op in [
      HotOp::Nop,
      HotOp::Const,
      HotOp::LocalGet,
      HotOp::LocalSet,
      HotOp::Call,
    ] {
    hot_node_set(func, id, { ..hot_node_get(func, id), op, imm0: -1, imm1: -1, })
    assert_eq(hot_node_exact_instr_payload_id(func, id), None)
    assert_eq(hot_node_exact_instr(func, id), None)
    assert_true(hot_verify_node_exact_instr_payload(func, id))
  }
}

///|
test "exact payload reads reject intentionally invalid payload bounds" {
  let func = HotFunc::new()
  ignore(
    hot_alloc_instr_payload(
      func,
      HotInstrPayload::new(@lib.Instruction::i32_add()),
    ),
  )
  let id = hot_build_nop(func)
  for op in [HotOp::Binary, HotOp::Load] {
    for invalid in [-1, func.instr_payloads.length()] {
      hot_node_set(func, id, {
        ..hot_node_get(func, id),
        op,
        imm0: invalid,
        imm1: invalid,
      })
      assert_eq(hot_node_exact_instr_payload_id(func, id), Some(invalid))
      assert_false(hot_verify_node_exact_instr_payload(func, id))
    }
  }
}

///|
test "exact payload reads remain fresh after mutation and incomplete deletion indexes" {
  let func = HotFunc::new()
  let first = hot_alloc_instr_payload(
    func,
    HotInstrPayload::new(@lib.Instruction::i32_add()),
  )
  let last = hot_alloc_instr_payload(
    func,
    HotInstrPayload::new(@lib.Instruction::i64_add()),
  )
  let dead = hot_build_nop(func)
  let lhs = hot_build_const_i32(func, @lib.I32(1))
  let rhs = hot_build_const_i32(func, @lib.I32(2))
  let id = hot_build_node(
    func,
    HotOp::Binary,
    hot_type_intern_value(func, @lib.ValType::i32()),
    imm0=first,
    children=[lhs, rhs],
  )
  hot_delete_node(func, dead)
  // Intentionally incomplete deletion metadata must use the existing fallback.
  func.deleted_nodes.clear()
  let revision = hot_revision_current(func)
  assert_eq(hot_node_exact_instr(func, id), Some(@lib.Instruction::i32_add()))
  assert_true(hot_verify_node_exact_instr_payload(func, id))
  assert_eq(hot_revision_current(func), revision)
  assert_eq(func.free_nodes, [dead])
  hot_node_exact_instr_set(func, id, @lib.Instruction::i32_sub())
  assert_eq(hot_node_exact_instr(func, id), Some(@lib.Instruction::i32_sub()))
  hot_node_set(func, id, {
    ..hot_node_get(func, id),
    op: HotOp::Load,
    imm0: first,
    imm1: last,
  })
  assert_eq(hot_node_exact_instr_payload_id(func, id), Some(last))
  assert_eq(hot_node_exact_instr(func, id), Some(@lib.Instruction::i64_add()))
  hot_node_set(func, id, { ..hot_node_get(func, id), op: HotOp::Nop, })
  assert_eq(hot_node_exact_instr(func, id), None)
}
