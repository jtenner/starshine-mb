///|
fn local_graph_unique_reads_bench(it : @bench.T, count : Int) -> Unit {
  let (func, write, reads) = local_graph_unique_reads_fixture(count)
  let cfg = cfg_build(func, expand_operand_control=true)
  let graph = local_graph_build_full_flow(func, cfg)
  if local_graph_influenced_gets_for_write(graph, write) != reads {
    abort("shared-write benchmark lost or duplicated a reader")
  }
  it.bench(fn() { it.keep(local_graph_build_full_flow(func, cfg)) })
}

///|
test "bench reverse graph shared-write readers=128" (it : @bench.T) {
  local_graph_unique_reads_bench(it, 128)
}

///|
test "bench reverse graph shared-write readers=512" (it : @bench.T) {
  local_graph_unique_reads_bench(it, 512)
}

///|
test "bench reverse graph shared-write readers=2048" (it : @bench.T) {
  local_graph_unique_reads_bench(it, 2048)
}
