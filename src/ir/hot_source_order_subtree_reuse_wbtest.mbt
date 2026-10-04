///|
test "source-order cached subtrees preserve first-visit access order and dead tails" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let read0 = hot_build_local_get(func, 0)
  let read1 = hot_build_local_get(func, 1)
  let write = hot_build_local_tee(func, 0, read1)
  let inner = hot_build_binary(func, @lib.ValType::i32(), read0, write)
  hot_node_exact_instr_set(func, inner, @lib.Instruction::i32_add())
  let outer = hot_build_binary(func, @lib.ValType::i32(), inner, read1)
  hot_node_exact_instr_set(func, outer, @lib.Instruction::i32_add())
  let reversed = hot_build_binary(func, @lib.ValType::i32(), read1, outer)
  hot_node_exact_instr_set(func, reversed, @lib.Instruction::i32_add())
  hot_root_append(func, hot_build_drop(func, reversed))
  hot_verify_all(func).unwrap()
  let facts = HotSourceOrderFacts::new(func)
  let held = hot_source_order_local_access_nodes(func, inner, facts)
  assert_eq(held, [read0, write, read1])
  assert_eq(hot_source_order_local_access_nodes(func, outer, facts), held)
  assert_eq(hot_source_order_local_access_nodes(func, reversed, facts), [
    read1, read0, write,
  ])
  assert_eq(held, [read0, write, read1])
  let dead = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let block = hot_build_block(func, @lib.BlockType::void_(), [
    hot_build_drop(func, reversed),
    hot_build_unreachable(func),
    dead,
  ])
  // Appending changes the arena: create a fresh snapshot, as callers require.
  let fresh = HotSourceOrderFacts::new(func)
  ignore(hot_source_order_local_access_nodes(func, inner, fresh))
  assert_eq(hot_source_order_local_access_nodes(func, block, fresh), [
    read1, read0, write,
  ])
}
