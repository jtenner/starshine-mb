///|
fn local_graph_query_bench(it : @bench.T, count : Int) -> Unit {
  let (func, writes, reads) = local_graph_query_fixture(count, count * 4)
  let cfg = cfg_build(func)
  let graph = local_graph_build_full_flow(func, cfg)
  for local in 0..<count {
    if local_graph_reaching_sources_for_get(graph, reads[local]) !=
      [SetSource(writes[local])] {
      abort("cross-block query benchmark lost its reaching write")
    }
  }
  it.bench(fn() { it.keep(local_graph_build_full_flow(func, cfg)) })
}

///|
test "bench local-flow cross-block queries locals=128" (it : @bench.T) {
  local_graph_query_bench(it, 128)
}

///|
test "bench local-flow cross-block queries locals=256" (it : @bench.T) {
  local_graph_query_bench(it, 256)
}
