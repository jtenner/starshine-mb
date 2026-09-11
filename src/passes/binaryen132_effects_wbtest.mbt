///|
test "Binaryen 132 forbids atomic load before store reversal across heap classes" {
  for
    read_order in [
      @lib.AtomicOrder::relaxed(),
      @lib.AtomicOrder::acq_rel(),
      @lib.AtomicOrder::seq_cst(),
    ] {
    for
      write_order in [
        @lib.AtomicOrder::relaxed(),
        @lib.AtomicOrder::acq_rel(),
        @lib.AtomicOrder::seq_cst(),
      ] {
      let earlier = hso_new_order_effects()
      let later = hso_new_order_effects()
      earlier.shared_memory_read = true
      later.shared_struct_write = true
      hso_order_effects_note_read_order(earlier, read_order)
      hso_order_effects_note_write_order(later, write_order)
      assert_true(hso_order_effects_ordered_before(earlier, later))
    }
  }
}

///|
test "Binaryen 132 relaxed order remains directional" {
  let earlier = hso_new_order_effects()
  let later = hso_new_order_effects()
  earlier.shared_memory_write = true
  later.shared_struct_read = true
  hso_order_effects_note_write_order(earlier, @lib.AtomicOrder::relaxed())
  hso_order_effects_note_read_order(later, @lib.AtomicOrder::relaxed())
  assert_false(hso_order_effects_ordered_before(earlier, later))
}

///|
test "Binaryen 132 directional order composes with plain accesses fences and traps" {
  let orders : Array[@lib.AtomicOrder?] = [
    None,
    Some(@lib.AtomicOrder::relaxed()),
    Some(@lib.AtomicOrder::acq_rel()),
    Some(@lib.AtomicOrder::seq_cst()),
  ]
  for first_idx, first in orders {
    for second_idx, second in orders {
      let read = hso_new_order_effects()
      let write = hso_new_order_effects()
      read.shared_array_read = true
      write.shared_memory_write = true
      if first is Some(order) {
        hso_order_effects_note_read_order(read, order)
      }
      if second is Some(order) {
        hso_order_effects_note_write_order(write, order)
      }
      let forward = (first_idx > 0 && second_idx > 0) ||
        first_idx >= 2 ||
        second_idx >= 2
      assert_eq(hso_order_effects_ordered_before(read, write), forward)
      // Acquire-read and release-write do not constrain the reverse direction.
      assert_eq(
        hso_order_effects_ordered_before(write, read),
        first_idx == 3 || second_idx == 3,
      )
      let merged = hso_new_order_effects()
      hso_order_effects_merge(merged, read)
      assert_eq(hso_order_effects_ordered_before(merged, write), forward)
    }
  }
  let fence = hso_new_order_effects()
  hso_order_effects_note_exact_instr(
    fence,
    None,
    @lib.Instruction::atomic_fence(),
  )
  let access = hso_new_order_effects()
  access.shared_struct_read = true
  assert_true(hso_order_effects_ordered_before(fence, access))
  assert_true(hso_order_effects_ordered_before(access, fence))
  assert_false(
    pass_effect_masks_can_reorder(
      @ir.EFFECT_MASK_TRAP,
      @ir.EFFECT_MASK_MEMORY_WRITE,
    ),
  )
  assert_false(
    pass_effect_masks_can_reorder(
      @ir.EFFECT_MASK_MEMORY_WRITE,
      @ir.EFFECT_MASK_TRAP,
    ),
  )
  assert_false(
    pass_effect_masks_can_reorder(@ir.EFFECT_MASK_TRAP, @ir.EFFECT_MASK_TRAP),
  )
}

///|
test "Binaryen 132 waitqueue synchronization blocks both directions of shared motion" {
  for
    instruction in [
      @lib.Instruction::waitqueue_notify(),
      @lib.Instruction::struct_wait(@lib.TypeIdx::new(0U), @lib.U32(0U)),
    ] {
    let queue = hso_new_order_effects()
    hso_order_effects_note_exact_instr(queue, None, instruction)
    let access = hso_new_order_effects()
    access.shared_array_read = true
    assert_true(hso_order_effects_ordered_before(queue, access))
    assert_true(hso_order_effects_ordered_before(access, queue))
  }
}
