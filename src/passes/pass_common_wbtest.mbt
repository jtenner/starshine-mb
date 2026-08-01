///|
test "pass effect reordering preserves the order of potentially trapping expressions" {
  let trap = @ir.EFFECT_MASK_TRAP
  assert_false(
    pass_effect_masks_can_reorder(@ir.EFFECT_MASK_MEMORY_READ | trap, trap),
  )
  assert_false(pass_effect_masks_can_reorder(trap, trap))
  assert_false(
    pass_effect_masks_can_reorder(@ir.EFFECT_MASK_TABLE_READ | trap, trap),
  )
  assert_false(
    pass_effect_masks_can_reorder(
      @ir.EFFECT_MASK_MEMORY_READ | @ir.EFFECT_MASK_MEMORY_WRITE | trap,
      trap,
    ),
  )
  assert_true(
    pass_effect_masks_can_reorder(
      @ir.EFFECT_MASK_MEMORY_READ,
      @ir.EFFECT_MASK_TABLE_READ,
    ),
  )
  assert_true(pass_effect_masks_can_reorder(0U, trap))
}
