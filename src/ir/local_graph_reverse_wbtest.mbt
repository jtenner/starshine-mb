///|
test "reverse local graph keeps the nearest write at each read" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let before = hot_build_local_get(func, 0)
  hot_root_append(func, hot_build_drop(func, before))
  let first = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(1)),
  )
  hot_root_append(func, first)
  let between = hot_build_local_get(func, 0)
  hot_root_append(func, hot_build_drop(func, between))
  let last = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(2)),
  )
  hot_root_append(func, last)
  let after = hot_build_local_get(func, 0)
  hot_root_append(func, hot_build_drop(func, after))
  let graph = local_graph_build_reverse_flow(func, cfg_build(func), true)
  assert_eq(local_graph_reaching_sources_for_get(graph, before), [
    EntrySource(0),
  ])
  assert_eq(local_graph_reaching_sources_for_get(graph, between), [
    SetSource(first),
  ])
  assert_eq(local_graph_reaching_sources_for_get(graph, after), [
    SetSource(last),
  ])
}

///|
test "reverse local graph does not carry a sibling block write into a read" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let write = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let sibling_read = hot_build_local_get(func, 0)
  hot_root_append(
    func,
    hot_build_if(
      func,
      @lib.BlockType::void_(),
      hot_build_const_i32(func, @lib.I32(1)),
      [write],
      else_body=Some([hot_build_drop(func, sibling_read)]),
    ),
  )
  let joined_read = hot_build_local_get(func, 0)
  hot_root_append(func, hot_build_drop(func, joined_read))
  let graph = local_graph_build_reverse_flow(func, cfg_build(func), true)
  assert_eq(local_graph_reaching_sources_for_get(graph, sibling_read), [
    EntrySource(0),
  ])
  let joined = local_graph_reaching_sources_for_get(graph, joined_read)
  assert_eq(joined.length(), 2)
  assert_true(joined.contains(EntrySource(0)))
  assert_true(joined.contains(SetSource(write)))
}
