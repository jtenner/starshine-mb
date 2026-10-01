///|
// Entry writes resolve all selector reads for DAE2, while the final read crosses
// conditional writers. Include the cold selection mask and all solver scratch;
// retain complete write/action/CFG work in both alternatives.
fn selected_read_bench(
  it : @bench.T,
  width : Int,
  all : Bool,
  selected : Bool,
) -> Unit raise {
  let (func, cfg, reads, final_read) = entry_read_fixture(width)
  let write = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  cfg.blocks[cfg_entry_block(cfg)].nodes.push(write)
  cfg_verify(cfg)
  let mask = Array::make(hot_node_count(func), all)
  mask[final_read] = true
  let complete = local_graph_build_read_sources(func, cfg)
  let partial = local_graph_build_read_sources(
    func,
    cfg,
    selected_gets=Some(mask),
  )
  assert_eq(
    partial.get_source_ids[final_read],
    complete.get_source_ids[final_read],
  )
  for read in reads {
    assert_eq(
      partial.get_source_ids[read],
      if all {
        complete.get_source_ids[read]
      } else {
        []
      },
    )
  }
  it.bench(fn() {
    it.keep(
      if selected {
        let mask = Array::make(hot_node_count(func), all)
        mask[final_read] = true
        local_graph_build_read_sources(func, cfg, selected_gets=Some(mask))
      } else {
        local_graph_build_read_sources(func, cfg)
      },
    )
  })
}

///|
test "bench selected read sources selectors=1 complete" (it : @bench.T) {
  selected_read_bench(it, 1, false, false)
}

///|
test "bench selected read sources selectors=1 partial" (it : @bench.T) {
  selected_read_bench(it, 1, false, true)
}

///|
test "bench selected read sources selectors=32 complete" (it : @bench.T) {
  selected_read_bench(it, 32, false, false)
}

///|
test "bench selected read sources selectors=32 partial" (it : @bench.T) {
  selected_read_bench(it, 32, false, true)
}

///|
test "bench selected read sources selectors=256 complete" (it : @bench.T) {
  selected_read_bench(it, 256, false, false)
}

///|
test "bench selected read sources selectors=256 partial" (it : @bench.T) {
  selected_read_bench(it, 256, false, true)
}

///|
test "bench selected read sources selectors=32 all complete" (it : @bench.T) {
  selected_read_bench(it, 32, true, false)
}

///|
test "bench selected read sources selectors=32 all selected" (it : @bench.T) {
  selected_read_bench(it, 32, true, true)
}
