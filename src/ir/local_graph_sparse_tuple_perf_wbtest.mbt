///|
fn local_graph_sparse_tuple_benchmark(
  it : @bench.T,
  count : Int,
  reference : Bool,
) -> Unit {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let write = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  hot_root_append(func, write)
  for _ in 0..<count {
    let body : Array[NodeId] = []
    for _ in 0..<64 {
      body.push(hot_build_drop(func, hot_build_const_i32(func, @lib.I32(3))))
    }
    body.push(hot_build_drop(func, hot_build_local_get(func, 0)))
    hot_root_append(func, hot_build_block(func, @lib.BlockType::void_(), body))
  }
  let cfg = cfg_build(func)
  let state = local_graph_entry_state(1)
  for block in 0..<cfg_block_count(cfg) {
    if local_graph_transfer_block(func, cfg, block, state, None, None) !=
      local_graph_tuple_reference_block(func, cfg, block, state, None, None) {
      abort("sparse tuple benchmark changed transfer state")
    }
  }
  it.bench(fn() {
    for block in 0..<cfg_block_count(cfg) {
      if reference {
        it.keep(
          local_graph_tuple_reference_block(func, cfg, block, state, None, None),
        )
      } else {
        it.keep(local_graph_transfer_block(func, cfg, block, state, None, None))
      }
    }
  })
}

///|
test "bench local-flow dense tuple flags blocks=64" (it : @bench.T) {
  local_graph_sparse_tuple_benchmark(it, 64, true)
}

///|
test "bench local-flow sparse tuple state blocks=64" (it : @bench.T) {
  local_graph_sparse_tuple_benchmark(it, 64, false)
}

///|
test "bench local-flow dense tuple flags blocks=256" (it : @bench.T) {
  local_graph_sparse_tuple_benchmark(it, 256, true)
}

///|
test "bench local-flow sparse tuple state blocks=256" (it : @bench.T) {
  local_graph_sparse_tuple_benchmark(it, 256, false)
}
