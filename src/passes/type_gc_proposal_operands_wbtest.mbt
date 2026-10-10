///|
test "DFE remaps GC proposal operands and records every aggregate type use" {
  let old = @lib.TypeIdx::new(3U)
  let next = @lib.TypeIdx::new(1U)
  let field = @lib.U32::new(7U)
  let order = @lib.AtomicOrder::acq_rel()
  let ma = @lib.MemArg::new(@lib.U32::new(3U), Some(@lib.MemIdx::new(2U)), @lib.U64::new(17UL))
  let pairs = [
    (@lib.Instruction::struct_wait(old, field), @lib.Instruction::struct_wait(next, field)),
    (@lib.Instruction::array_load(@lib.LoadOp::i32_load(), old, memarg=ma), @lib.Instruction::array_load(@lib.LoadOp::i32_load(), next, memarg=ma)),
    (@lib.Instruction::array_store(@lib.StoreOp::i32_store(), old, memarg=ma), @lib.Instruction::array_store(@lib.StoreOp::i32_store(), next, memarg=ma)),
    (@lib.Instruction::struct_atomic_set(order, old, field), @lib.Instruction::struct_atomic_set(order, next, field)),
    (@lib.Instruction::struct_atomic_rmw(@lib.AggregateAtomicRmwOp::add(), old, field, order~), @lib.Instruction::struct_atomic_rmw(@lib.AggregateAtomicRmwOp::add(), next, field, order~)),
    (@lib.Instruction::struct_atomic_cmpxchg(old, field, order~), @lib.Instruction::struct_atomic_cmpxchg(next, field, order~)),
    (@lib.Instruction::array_atomic_get(order, old), @lib.Instruction::array_atomic_get(order, next)),
    (@lib.Instruction::array_atomic_get_s(order, old), @lib.Instruction::array_atomic_get_s(order, next)),
    (@lib.Instruction::array_atomic_get_u(order, old), @lib.Instruction::array_atomic_get_u(order, next)),
    (@lib.Instruction::array_atomic_set(order, old), @lib.Instruction::array_atomic_set(order, next)),
    (@lib.Instruction::array_atomic_rmw(@lib.AggregateAtomicRmwOp::add(), old, order~), @lib.Instruction::array_atomic_rmw(@lib.AggregateAtomicRmwOp::add(), next, order~)),
    (@lib.Instruction::array_atomic_cmpxchg(old, order~), @lib.Instruction::array_atomic_cmpxchg(next, order~)),
  ]
  for (input, expected) in pairs {
    assert_true(dfe_instruction_mentions_type_idxs(input))
    @debug.assert_eq(dfe_rewrite_instruction_type_idxs(input, { 3U: 1U }), expected)
    @debug.assert_eq(dfe_try_rewrite_instruction_type_idxs(input, { 3U: 1U }), Some(expected))
    let scan = dfe_scan_rewrite_instruction_type_idxs(input, { 3U: 1U })
    assert_true(scan.mentions_type_idxs)
    @debug.assert_eq(scan.rewritten, Some(expected))
    assert_true(dfe_scan_rewrite_instruction_type_idxs(input, {}).mentions_type_idxs)
    @debug.assert_eq(dfe_try_rewrite_instruction_type_idxs(input, { 7U: 1U }), None)
  }
}
