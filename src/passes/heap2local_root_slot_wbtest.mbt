///|
test "heap2local root-slot index matches structured subtree lookup" {
  let fixture = pass_test_module_from_wat(
    "(module (func (local i32) (block (local.set 0 (i32.const 1))) (drop (local.get 0))))",
  )
  let hot = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(0U))
  let slots = h2l_build_root_slot_index(hot)
  for node_id = 0; node_id < @ir.hot_node_count(hot); node_id = node_id + 1 {
    let expected = match h2l_root_slot_containing_node(hot, node_id) {
      Some(slot) => slot
      None => -1
    }
    @debug.assert_eq(slots[node_id], expected)
  }
}
