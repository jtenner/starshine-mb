///|
fn local_graph_query_fixture(
  count : Int,
  declared : Int,
) -> (HotFunc, Array[NodeId], Array[NodeId]) {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=Array::make(declared, @lib.ValType::i32())),
  )
  let writes : Array[NodeId] = []
  let reads : Array[NodeId] = []
  for local in 0..<count {
    let write = hot_build_local_set(
      func,
      local,
      hot_build_const_i32(func, @lib.I32(local)),
    )
    writes.push(write)
    hot_root_append(func, write)
  }
  for local in 0..<count {
    let read = hot_build_local_get(func, local)
    reads.push(read)
    hot_root_append(
      func,
      hot_build_block(func, @lib.BlockType::void_(), [
        hot_build_drop(func, read),
      ]),
    )
  }
  (func, writes, reads)
}

///|
test "reverse local-flow queries retain cross-block writes with sparse cache storage" {
  let (func, writes, reads) = local_graph_query_fixture(8, 64)
  let cfg = cfg_build(func)
  let slots = [0]
  let graph = local_graph_build_reverse_flow(
    func,
    cfg,
    true,
    cache_slots=Some(slots),
  )
  for local in 0..<8 {
    assert_eq(local_graph_reaching_sources_for_get(graph, reads[local]), [
      SetSource(writes[local]),
    ])
  }
  assert_true(slots[0] <= cfg_block_count(cfg) + reads.length())
}

///|
test "sparse local-flow queries isolate reused traversal state" {
  let (func, writes, reads) = local_graph_query_fixture(8, 64)
  let builds = [0]
  let graph = local_graph_build_sparse_flow(
    func,
    cfg_build(func),
    true,
    query_builds=Some(builds),
  )
  for local in 0..<8 {
    assert_eq(local_graph_reaching_sources_for_get(graph, reads[local]), [
      SetSource(writes[local]),
    ])
  }
  assert_eq(builds[0], 1)
}
