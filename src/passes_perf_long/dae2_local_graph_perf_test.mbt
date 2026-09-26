///|
fn perf_long_dae2_local_graph_bench(it : @bench.T, count : Int) -> Unit {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=Array::make(count, @lib.ValType::i32())),
  )
  let writes : Array[Int] = []
  let reads : Array[Int] = []
  for local_id = 0; local_id < count; local_id = local_id + 1 {
    let write = @ir.hot_build_local_set(
      func,
      local_id,
      @ir.hot_build_const_i32(func, @lib.I32(local_id)),
    )
    writes.push(write)
    @ir.hot_root_append(func, write)
  }
  for local_id = 0; local_id < count; local_id = local_id + 1 {
    let read = @ir.hot_build_local_get(func, local_id)
    reads.push(read)
    @ir.hot_root_append(func, @ir.hot_build_drop(func, read))
  }
  let cfg = @ir.cfg_build(func)
  let graph = @ir.local_graph_build_full_flow(func, cfg)
  for local_id = 0; local_id < count; local_id = local_id + 1 {
    match @ir.local_graph_reaching_sources_for_get(graph, reads[local_id]) {
      [@ir.HotLocalGraphSource::SetSource(write)] if write == writes[local_id] =>
        ()
      _ => abort("local graph benchmark lost the nearest write")
    }
  }
  it.bench(fn() { it.keep(@ir.local_graph_build_full_flow(func, cfg)) })
}

///|
test "bench DAE2 local graph distant reads locals=1024" (it : @bench.T) {
  perf_long_dae2_local_graph_bench(it, 1024)
}

///|
test "bench DAE2 local graph distant reads locals=2048" (it : @bench.T) {
  perf_long_dae2_local_graph_bench(it, 2048)
}
