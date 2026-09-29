///|
fn local_graph_write_journal_bench(
  it : @bench.T,
  width : Int,
  count : Int,
  reference : Bool,
) -> Unit {
  let (func, cfg, _, _) = local_graph_write_journal_fixture(width)
  let roots = cfg.blocks[0].nodes
  for _ in 1..<count {
    roots.push(roots[0])
  }
  let incoming = local_graph_entry_state(width)
  let expected = local_graph_tuple_reference_block(
    func,
    cfg,
    cfg.entry_block,
    incoming,
    None,
    None,
  )
  if local_graph_transfer_block(
      func,
      cfg,
      cfg.entry_block,
      incoming,
      None,
      None,
    ) !=
    expected {
    abort("write journal changed reaching definitions")
  }
  it.bench(fn() {
    let result = if reference {
      let state = local_graph_state_clone(incoming)
      let tuples = LocalGraphTupleState::new(None)
      for root in roots {
        local_graph_transfer_node(
          func,
          width,
          root,
          state,
          None,
          None,
          false,
          tuples,
        )
      }
      state
    } else {
      local_graph_transfer_block(
        func,
        cfg,
        cfg.entry_block,
        incoming,
        None,
        None,
      )
    }
    it.keep(result)
  })
}

///|
test "bench local-flow joins width=4 branches=1 full" (it : @bench.T) {
  local_graph_write_journal_bench(it, 4, 1, true)
}

///|
test "bench local-flow joins width=4 branches=1 journal" (it : @bench.T) {
  local_graph_write_journal_bench(it, 4, 1, false)
}

///|
test "bench local-flow joins width=4 branches=32 full" (it : @bench.T) {
  local_graph_write_journal_bench(it, 4, 32, true)
}

///|
test "bench local-flow joins width=4 branches=32 journal" (it : @bench.T) {
  local_graph_write_journal_bench(it, 4, 32, false)
}

///|
test "bench local-flow joins width=128 branches=1 full" (it : @bench.T) {
  local_graph_write_journal_bench(it, 128, 1, true)
}

///|
test "bench local-flow joins width=128 branches=1 journal" (it : @bench.T) {
  local_graph_write_journal_bench(it, 128, 1, false)
}

///|
test "bench local-flow joins width=128 branches=32 full" (it : @bench.T) {
  local_graph_write_journal_bench(it, 128, 32, true)
}

///|
test "bench local-flow joins width=128 branches=32 journal" (it : @bench.T) {
  local_graph_write_journal_bench(it, 128, 32, false)
}

///|
test "bench local-flow joins width=1024 branches=1 full" (it : @bench.T) {
  local_graph_write_journal_bench(it, 1024, 1, true)
}

///|
test "bench local-flow joins width=1024 branches=1 journal" (it : @bench.T) {
  local_graph_write_journal_bench(it, 1024, 1, false)
}

///|
test "bench local-flow joins width=1024 branches=32 full" (it : @bench.T) {
  local_graph_write_journal_bench(it, 1024, 32, true)
}

///|
test "bench local-flow joins width=1024 branches=32 journal" (it : @bench.T) {
  local_graph_write_journal_bench(it, 1024, 32, false)
}

///|
test "bench local-flow joins width=4096 branches=1 full" (it : @bench.T) {
  local_graph_write_journal_bench(it, 4096, 1, true)
}

///|
test "bench local-flow joins width=4096 branches=1 journal" (it : @bench.T) {
  local_graph_write_journal_bench(it, 4096, 1, false)
}

///|
test "bench local-flow joins width=4096 branches=32 full" (it : @bench.T) {
  local_graph_write_journal_bench(it, 4096, 32, true)
}

///|
test "bench local-flow joins width=4096 branches=32 journal" (it : @bench.T) {
  local_graph_write_journal_bench(it, 4096, 32, false)
}
