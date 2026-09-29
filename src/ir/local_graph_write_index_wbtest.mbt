///|
fn local_graph_write_index_fixture() -> (HotFunc, Array[NodeId]) {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=Array::make(4, @lib.ValType::i32())),
  )
  let first = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let read = hot_build_local_get(func, 0)
  let tee = hot_build_local_tee(func, 1, hot_build_const_i32(func, @lib.I32(8)))
  let last = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(9)),
  )
  (func, [first, read, tee, last])
}

///|
test "reverse write lookup ignores reads and retains last set or tee" {
  let (func, actions) = local_graph_write_index_fixture()
  let write_local_ids = local_graph_build_write_local_ids(func)
  assert_eq(
    local_graph_reverse_find_last_write(write_local_ids, actions, 4, 0),
    Some(actions[3]),
  )
  assert_eq(
    local_graph_reverse_find_last_write(write_local_ids, actions, 2, 0),
    Some(actions[0]),
  )
  assert_eq(
    local_graph_reverse_find_last_write(write_local_ids, actions, 4, 1),
    Some(actions[2]),
  )
  assert_eq(
    local_graph_reverse_find_last_write(write_local_ids, actions, 4, 2),
    None,
  )
  assert_eq(
    local_graph_reverse_find_last_write(write_local_ids, actions, 0, 0),
    None,
  )
}
