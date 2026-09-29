///|
fn local_graph_transfer_block_reference(
  func : HotFunc,
  cfg : HotCfg,
  block_id : BlockId,
  in_state : Array[Array[Int]],
  get_sources : LocalGraphSourceRecorder?,
  write_influences : Array[Array[NodeId]]?,
  tuple_slots? : Array[Int]? = None,
) -> Array[Array[Int]] {
  if cfg_block_get(cfg, block_id).nodes.is_empty() {
    return in_state
  }
  let state = local_graph_state_clone(in_state)
  // Expanded CFGs already visit each producer at its execution position.
  // Recursive traversal records only tuple producers actually encountered.
  let evaluated_tuples = LocalGraphTupleState::new(tuple_slots)
  for node_id in cfg_block_get(cfg, block_id).nodes {
    if cfg.operands_expanded {
      // The CFG already lists each operand at its execution position.
      // Descending again invents extra reads and writes across control edges.
      let node = hot_node_get(func, node_id)
      match node.op {
        HotOp::LocalGet =>
          local_graph_record_get_sources(
            hot_local_count(func),
            node_id,
            state[node.imm0],
            get_sources,
            write_influences,
          )
        HotOp::LocalSet | HotOp::LocalTee =>
          state[node.imm0] = [
            local_graph_set_source_id(hot_local_count(func), node_id),
          ]
        _ => ()
      }
      continue
    }
    local_graph_transfer_node(
      func,
      hot_local_count(func),
      node_id,
      state,
      get_sources,
      write_influences,
      false,
      evaluated_tuples,
    )
  }
  state
}

///|
fn local_graph_transfer_borrow_reference(
  func : HotFunc,
  cfg : HotCfg,
  incoming : Array[Array[Int]],
) -> Array[Array[Int]] {
  local_graph_transfer_block_reference(
    func,
    cfg,
    cfg.entry_block,
    incoming,
    None,
    None,
  )
}

///|
fn local_graph_transfer_borrow_bench(
  it : @bench.T,
  count : Int,
  writes : Int,
  reference : Bool,
) -> Unit {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=Array::make(count, @lib.ValType::i32())),
  )
  let nodes : Array[NodeId] = []
  for local = 0; local < writes; local = local + 1 {
    nodes.push(
      hot_build_local_set(
        func,
        local,
        hot_build_const_i32(func, @lib.I32(local)),
      ),
    )
  }
  for local = 0; local < 16; local = local + 1 {
    nodes.push(hot_build_local_get(func, local))
  }
  let cfg = local_graph_transfer_borrow_fixture(func, nodes, true)
  let incoming = local_graph_entry_state(count)
  let expected = local_graph_transfer_borrow_reference(func, cfg, incoming)
  let actual = local_graph_transfer_block(
    func,
    cfg,
    cfg.entry_block,
    incoming,
    None,
    None,
  )
  if actual != expected || incoming != local_graph_entry_state(count) {
    abort("transfer benchmark changed reaching sources or input ownership")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        local_graph_transfer_borrow_reference(func, cfg, incoming)
      } else {
        local_graph_transfer_block(
          func,
          cfg,
          cfg.entry_block,
          incoming,
          None,
          None,
        )
      },
    )
  })
}

///|
test "bench expanded transfer read-only locals=16 reference" (it : @bench.T) {
  local_graph_transfer_borrow_bench(it, 16, 0, true)
}

///|
test "bench expanded transfer read-only locals=16 borrowed" (it : @bench.T) {
  local_graph_transfer_borrow_bench(it, 16, 0, false)
}

///|
test "bench expanded transfer first-write locals=16 reference" (it : @bench.T) {
  local_graph_transfer_borrow_bench(it, 16, 1, true)
}

///|
test "bench expanded transfer first-write locals=16 borrowed" (it : @bench.T) {
  local_graph_transfer_borrow_bench(it, 16, 1, false)
}

///|
test "bench expanded transfer all-write locals=16 reference" (it : @bench.T) {
  local_graph_transfer_borrow_bench(it, 16, 16, true)
}

///|
test "bench expanded transfer all-write locals=16 borrowed" (it : @bench.T) {
  local_graph_transfer_borrow_bench(it, 16, 16, false)
}

///|
test "bench expanded transfer read-only locals=128 reference" (it : @bench.T) {
  local_graph_transfer_borrow_bench(it, 128, 0, true)
}

///|
test "bench expanded transfer read-only locals=128 borrowed" (it : @bench.T) {
  local_graph_transfer_borrow_bench(it, 128, 0, false)
}

///|
test "bench expanded transfer first-write locals=128 reference" (it : @bench.T) {
  local_graph_transfer_borrow_bench(it, 128, 1, true)
}

///|
test "bench expanded transfer first-write locals=128 borrowed" (it : @bench.T) {
  local_graph_transfer_borrow_bench(it, 128, 1, false)
}

///|
test "bench expanded transfer all-write locals=128 reference" (it : @bench.T) {
  local_graph_transfer_borrow_bench(it, 128, 128, true)
}

///|
test "bench expanded transfer all-write locals=128 borrowed" (it : @bench.T) {
  local_graph_transfer_borrow_bench(it, 128, 128, false)
}

///|
test "bench expanded transfer read-only locals=4096 reference" (it : @bench.T) {
  local_graph_transfer_borrow_bench(it, 4096, 0, true)
}

///|
test "bench expanded transfer read-only locals=4096 borrowed" (it : @bench.T) {
  local_graph_transfer_borrow_bench(it, 4096, 0, false)
}

///|
test "bench expanded transfer first-write locals=4096 reference" (it : @bench.T) {
  local_graph_transfer_borrow_bench(it, 4096, 1, true)
}

///|
test "bench expanded transfer first-write locals=4096 borrowed" (it : @bench.T) {
  local_graph_transfer_borrow_bench(it, 4096, 1, false)
}

///|
test "bench expanded transfer all-write locals=4096 reference" (it : @bench.T) {
  local_graph_transfer_borrow_bench(it, 4096, 4096, true)
}

///|
test "bench expanded transfer all-write locals=4096 borrowed" (it : @bench.T) {
  local_graph_transfer_borrow_bench(it, 4096, 4096, false)
}
