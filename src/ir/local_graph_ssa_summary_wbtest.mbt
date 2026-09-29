///|
fn local_graph_ssa_summary_fixture(count : Int) -> (HotFunc, Array[Array[Int]]) {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let pairs : Array[(NodeId, NodeId)] = []
  for index in 0..<count {
    let write = hot_build_local_set(
      func,
      1,
      hot_build_const_i32(func, @lib.I32(index)),
    )
    let read = hot_build_local_get(func, 1)
    hot_root_append(func, write)
    hot_root_append(func, hot_build_drop(func, read))
    pairs.push((write, read))
  }
  let entry = hot_build_local_get(func, 0)
  hot_root_append(func, hot_build_drop(func, entry))
  let sources = Array::make(hot_node_count(func), [])
  for (write, read) in pairs {
    sources[read] = [local_graph_set_source_id(2, write)]
  }
  sources[entry] = [local_graph_entry_source_id(0)]
  (func, sources)
}

///|
test "SSA summary distinguishes entry, singleton write, and multiple writes" {
  for count in [0, 1, 2, 8] {
    let (func, sources) = local_graph_ssa_summary_fixture(count)
    assert_eq(local_graph_build_local_already_ssa(func, 2, sources), [
      true,
      count == 1,
    ])
  }
}

///|
test "SSA summary rejects unread writes that disagree with the observed source" {
  let (func, sources) = local_graph_ssa_summary_fixture(1)
  assert_eq(local_graph_build_local_already_ssa(func, 2, sources), [true, true])
  hot_root_append(
    func,
    hot_build_local_set(func, 1, hot_build_const_i32(func, @lib.I32(8))),
  )
  sources.resize(hot_node_count(func), [])
  assert_eq(local_graph_build_local_already_ssa(func, 2, sources), [true, false])
  hot_root_append(
    func,
    hot_build_local_set(func, 0, hot_build_const_i32(func, @lib.I32(9))),
  )
  sources.resize(hot_node_count(func), [])
  assert_eq(local_graph_build_local_already_ssa(func, 2, sources), [
    false, false,
  ])
}
