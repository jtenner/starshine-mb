///|
test "control slot metadata stays explicit for current control families" {
  let block_slots = hot_control_region_slot_info(HotOp::Block)
  let loop_slots = hot_control_region_slot_info(HotOp::Loop)
  let if_slots = hot_control_region_slot_info(HotOp::If)
  let try_slots = hot_control_region_slot_info(HotOp::Try)
  let try_table_slots = hot_control_region_slot_info(HotOp::TryTable)

  @debug.assert_eq(block_slots.length(), 1)
  @debug.assert_eq(block_slots[0].slot, 0)
  match block_slots[0].role {
    BodyRegion => ()
    _ => fail("expected block body slot")
  }
  assert_true(block_slots[0].required)

  @debug.assert_eq(loop_slots.length(), 1)
  @debug.assert_eq(loop_slots[0].slot, 0)
  match loop_slots[0].role {
    BodyRegion => ()
    _ => fail("expected loop body slot")
  }
  assert_true(loop_slots[0].required)

  @debug.assert_eq(if_slots.length(), 2)
  @debug.assert_eq(if_slots[0].slot, 1)
  match if_slots[0].role {
    ThenRegion => ()
    _ => fail("expected then slot")
  }
  assert_true(if_slots[0].required)
  @debug.assert_eq(if_slots[1].slot, 2)
  match if_slots[1].role {
    ElseRegion => ()
    _ => fail("expected else slot")
  }
  assert_false(if_slots[1].required)

  @debug.assert_eq(try_slots.length(), 2)
  match try_slots[0].role {
    BodyRegion => ()
    _ => fail("expected try body slot")
  }
  match try_slots[1].role {
    CatchRegion => ()
    _ => fail("expected try catch slot")
  }

  @debug.assert_eq(try_table_slots.length(), 2)
  match try_table_slots[0].role {
    BodyRegion => ()
    _ => fail("expected try_table body slot")
  }
  match try_table_slots[1].role {
    CatchListRegion => ()
    _ => fail("expected try_table catch-list slot")
  }
}
