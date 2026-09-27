///|
fn local_graph_tuple_state_bench(
  it : @bench.T,
  blocks : Int,
  expanded : Bool,
) -> Unit {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let write = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  hot_root_append(func, write)
  let reads : Array[NodeId] = []
  for _ in 0..<blocks {
    let roots : Array[NodeId] = []
    for _ in 0..<64 {
      roots.push(hot_build_drop(func, hot_build_const_i32(func, @lib.I32(3))))
    }
    let read = hot_build_local_get(func, 0)
    reads.push(read)
    roots.push(hot_build_drop(func, read))
    hot_root_append(func, hot_build_block(func, @lib.BlockType::void_(), roots))
  }
  let cfg = cfg_build(func, expand_operand_control=expanded)
  let graph = local_graph_build_with_exceptional_policy(func, cfg, true)
  for read in reads {
    if local_graph_reaching_sources_for_get(graph, read) != [SetSource(write)] {
      abort("tuple-state benchmark lost a reaching write")
    }
  }
  it.bench(fn() {
    it.keep(local_graph_build_with_exceptional_policy(func, cfg, true))
  })
}

///|
test "bench local-flow tuple flags expanded blocks=64" (it : @bench.T) {
  local_graph_tuple_state_bench(it, 64, true)
}

///|
test "bench local-flow tuple flags expanded blocks=256" (it : @bench.T) {
  local_graph_tuple_state_bench(it, 256, true)
}

///|
test "bench local-flow tuple flags unexpanded blocks=64" (it : @bench.T) {
  local_graph_tuple_state_bench(it, 64, false)
}
