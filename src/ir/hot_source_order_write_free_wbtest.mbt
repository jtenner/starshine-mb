///|
fn source_order_write_free_fixture(
  count : Int,
  write : Bool,
) -> (HotFunc, Array[NodeId], NodeId) {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let roots : Array[NodeId] = []
  let mut value = hot_build_local_get(func, 0)
  roots.push(value)
  for _ in 0..<count {
    value = hot_build_binary(
      func,
      @lib.ValType::i32(),
      value,
      hot_build_local_get(func, 0),
    )
    hot_node_exact_instr_set(func, value, @lib.Instruction::i32_add())
    roots.push(value)
  }
  if write {
    roots.push(hot_build_local_tee(func, 0, value))
  }
  let current = hot_build_local_get(func, 0)
  (func, roots, current)
}

///|
test "source-order write admission preserves read-only and nested tee conflicts" {
  for write in [false, true] {
    let (func, roots, current) = source_order_write_free_fixture(4, write)
    let facts = HotSourceOrderFacts::new(func)
    for index in 0..<roots.length() {
      assert_eq(
        hot_lower_impl_carried_local_write_conflicts(
          func,
          roots[index],
          current,
          facts,
        ),
        write && index == roots.length() - 1,
      )
    }
  }
}

///|
test "source-order write admission ignores terminated tails but retains reachable writes" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let dead_write = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(9)),
  )
  let dead = hot_build_block(func, @lib.BlockType::void_(), [
    hot_build_unreachable(func),
    dead_write,
  ])
  let live_write = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let live = hot_build_block(func, @lib.BlockType::void_(), [
    live_write,
    hot_build_unreachable(func),
  ])
  let current = hot_build_local_get(func, 0)
  let facts = HotSourceOrderFacts::new(func)
  assert_false(
    hot_lower_impl_carried_local_write_conflicts(func, dead, current, facts),
  )
  assert_true(
    hot_lower_impl_carried_local_write_conflicts(func, live, current, facts),
  )
}
