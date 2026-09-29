///|
fn local_graph_predecessor_cache_bench(
  it : @bench.T,
  count : Int,
  overwrite : Bool,
  reference : Bool,
) -> Unit {
  let (func, cfg, blocks, _) = local_graph_predecessor_cache_fixture(
    count,
    overwrite~,
  )
  let expected = local_graph_predecessor_cache_queries(
    func, cfg, blocks, 0, true,
  )
  let actual = local_graph_predecessor_cache_queries(
    func, cfg, blocks, 0, false,
  )
  if actual != expected {
    abort("predecessor cache changed source ordering")
  }
  let actions = local_graph_reverse_action_sequences(func, cfg)
  let writes = local_graph_build_write_local_ids(func)
  let transparent = local_graph_reverse_transparent_predecessors(
    writes, cfg, actions, true,
  )
  // Include cold cache, index and scratch allocation, querying each read
  // block once. Facts/CFG construction is excluded equally from both paths.
  it.bench(fn() {
    let cache : Array[@hashmap.HashMap[Int, Array[Int]]?] = Array::make(
      cfg_block_count(cfg),
      None,
    )
    let last_writes : Array[@hashmap.HashMap[Int, NodeId]?] = Array::make(
      cfg_block_count(cfg),
      None,
    )
    let seen = Array::make(cfg_block_count(cfg), false)
    let visited : Array[BlockId] = []
    let work : Array[BlockId] = []
    for block in blocks {
      it.keep(
        if reference {
          local_graph_predecessor_cache_reference_sources(
            writes, cfg, actions, transparent, block, 0, true, cache, last_writes,
            seen, visited, work, 2,
          )
        } else {
          local_graph_predecessor_cache_candidate_sources(
            writes, cfg, actions, transparent, block, 0, true, cache, last_writes,
            seen, visited, work, 2,
          )
        },
      )
    }
  })
}

///|
test "bench reverse predecessor cache reads=64 reference" (it : @bench.T) {
  local_graph_predecessor_cache_bench(it, 64, false, true)
}

///|
test "bench reverse predecessor cache reads=64 candidate" (it : @bench.T) {
  local_graph_predecessor_cache_bench(it, 64, false, false)
}

///|
test "bench reverse predecessor cache reads=512 reference" (it : @bench.T) {
  local_graph_predecessor_cache_bench(it, 512, false, true)
}

///|
test "bench reverse predecessor cache reads=512 candidate" (it : @bench.T) {
  local_graph_predecessor_cache_bench(it, 512, false, false)
}

///|
test "bench reverse predecessor cache overwrites=64 reference" (it : @bench.T) {
  local_graph_predecessor_cache_bench(it, 64, true, true)
}

///|
test "bench reverse predecessor cache overwrites=64 candidate" (it : @bench.T) {
  local_graph_predecessor_cache_bench(it, 64, true, false)
}

///|
test "bench reverse predecessor cache overwrites=512 reference" (it : @bench.T) {
  local_graph_predecessor_cache_bench(it, 512, true, true)
}

///|
test "bench reverse predecessor cache overwrites=512 candidate" (it : @bench.T) {
  local_graph_predecessor_cache_bench(it, 512, true, false)
}
