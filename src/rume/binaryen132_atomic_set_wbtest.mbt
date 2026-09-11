///|
test "Binaryen 132 aggregate atomics remap every type annotation and preserve order" {
  let remap = Map([(2U, 1U)])
  for
    order in [
      @lib.AtomicOrder::seq_cst(),
      @lib.AtomicOrder::acq_rel(),
      @lib.AtomicOrder::relaxed(),
    ] {
    for kind = 0; kind < 8; kind = kind + 1 {
      let make = fn(index : UInt) {
        let ty = @lib.TypeIdx::new(index)
        match kind {
          0 => @lib.Instruction::struct_atomic_set(order, ty, 3U)
          1 => @lib.Instruction::array_atomic_set(order, ty)
          2 => @lib.Instruction::array_atomic_get(order, ty)
          3 => @lib.Instruction::array_atomic_get_s(order, ty)
          4 => @lib.Instruction::array_atomic_get_u(order, ty)
          5 =>
            @lib.Instruction::array_atomic_rmw(
              @lib.AggregateAtomicRmwOp::add(),
              ty,
              order~,
            )
          6 => @lib.Instruction::array_atomic_cmpxchg(ty, order~)
          _ =>
            @lib.Instruction::struct_atomic_rmw(
              @lib.AggregateAtomicRmwOp::xchg(),
              ty,
              3U,
              order~,
            )
        }
      }
      @debug.assert_eq(
        dfe_rewrite_instruction_type_idxs(make(2U), remap),
        make(1U),
      )
      @debug.assert_eq(
        dfe_try_rewrite_instruction_type_idxs(make(2U), remap),
        Some(make(1U)),
      )
      let used = @bitset.BitSet::new(3)
      rume_mark_instruction_direct_types(used, make(2U))
      assert_true(used[2])
    }
  }
}
