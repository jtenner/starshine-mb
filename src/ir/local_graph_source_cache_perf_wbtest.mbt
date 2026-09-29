///|
fn local_graph_source_cache_bench(it : @bench.T, count : Int) -> Unit {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let reads : Array[NodeId] = []
  for _ in 0..<count {
    let read = hot_build_local_get(func, 0)
    reads.push(read)
    hot_root_append(func, hot_build_drop(func, read))
  }
  let cfg = cfg_build(func)
  let graph = local_graph_build_full_flow(func, cfg)
  for read in reads {
    if local_graph_reaching_sources_for_get(graph, read) != [EntrySource(0)] {
      abort("cached-source control lost its entry value")
    }
  }
  it.bench(fn() { it.keep(local_graph_build_full_flow(func, cfg)) })
}

///|
test "bench local graph repeated entry sources reads=128" (it : @bench.T) {
  local_graph_source_cache_bench(it, 128)
}

///|
test "bench local graph repeated entry sources reads=512" (it : @bench.T) {
  local_graph_source_cache_bench(it, 512)
}

///|
test "bench local graph repeated entry sources reads=2048" (it : @bench.T) {
  local_graph_source_cache_bench(it, 2048)
}
