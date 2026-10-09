///|
test "batched control rewrite checks labels before changing child spans" {
  let func = HotFunc::new()
  let old_child = hot_build_nop(func)
  let replacement = hot_build_nop(func)
  let block = hot_build_block(func, @lib.BlockType::void_(), [old_child])
  let node = hot_node_get(func, block)
  func.nodes[block] = { ..node, imm0: -1, }
  let rewrites = [HotChildSpanRewrite::new(block, [replacement])]
  assert_false(hot_mutate_child_spans_control_preflight(func, block, rewrites))
  assert_eq(hot_child_get(func, block, 0), old_child)
}
