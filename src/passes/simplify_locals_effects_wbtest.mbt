///|
test "simplify-locals classifies array load and store memory effects" {
  let func = @ir.HotFunc::new()
  let ty = @lib.TypeIdx::new(0U)
  let load = @ir.hot_build_heap(
    func,
    [@lib.ValType::i32()],
    @lib.Instruction::array_load(@lib.LoadOp::i32_load(), ty),
    [],
  )
  let store = @ir.hot_build_heap(
    func,
    [],
    @lib.Instruction::array_store(@lib.StoreOp::i32_store(), ty),
    [],
  )
  let read_mask = simplify_locals_effects_mask_for_exact_node(func, load)
  let write_mask = simplify_locals_effects_mask_for_exact_node(func, store)
  assert_true((read_mask & @ir.EFFECT_MASK_MEMORY_READ) != 0U)
  assert_true((write_mask & @ir.EFFECT_MASK_MEMORY_WRITE) != 0U)
}

///|
test "simplify-locals retains a synthesized null-check trap" {
  let func = @ir.HotFunc::new()
  let nullable = @lib.RefType::abs(@lib.AbsHeapType::extern_())
  let nonnull = @lib.RefType::new(
    false,
    @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
  )
  let checked = @ir.hot_build_unary(
    func,
    @lib.ValType::ref_type(nonnull),
    @ir.hot_build_ref_null(func, nullable),
  )
  @ir.hot_node_exact_instr_set(
    func,
    checked,
    @lib.Instruction::ref_as_non_null(),
  )
  assert_true(
    (
      simplify_locals_effects_mask_for_exact_node(func, checked) &
      @ir.EFFECT_MASK_TRAP
    ) !=
    0U,
  )
}
