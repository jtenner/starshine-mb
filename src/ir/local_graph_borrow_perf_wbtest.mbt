///|
fn local_graph_borrow_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit {
  let (_, cfg) = local_graph_borrow_fixture()
  let state = local_graph_entry_state(width)
  let states = [state, local_graph_empty_state(width), state]
  if local_graph_merge_predecessors(cfg, cfg.exit_block, width, states, false) !=
    local_graph_borrow_reference_merge(
      cfg,
      cfg.exit_block,
      width,
      states,
      false,
    ) {
    abort("predecessor state mismatch")
  }
  it.bench(fn() {
    for _ in 0..<128 {
      it.keep(
        if reference {
          local_graph_borrow_reference_merge(
            cfg,
            cfg.exit_block,
            width,
            states,
            false,
          )
        } else {
          local_graph_merge_predecessors(
            cfg,
            cfg.exit_block,
            width,
            states,
            false,
          )
        },
      )
    }
  })
}

///|
test "bench local-flow copied predecessor locals=128" (it : @bench.T) {
  local_graph_borrow_bench(it, 128, true)
}

///|
test "bench local-flow borrowed predecessor locals=128" (it : @bench.T) {
  local_graph_borrow_bench(it, 128, false)
}

///|
test "bench local-flow copied predecessor locals=4096" (it : @bench.T) {
  local_graph_borrow_bench(it, 4096, true)
}

///|
test "bench local-flow borrowed predecessor locals=4096" (it : @bench.T) {
  local_graph_borrow_bench(it, 4096, false)
}
