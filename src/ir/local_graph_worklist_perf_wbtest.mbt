///|
fn local_graph_worklist_benchmark(
  it : @bench.T,
  reads : Int,
  locals : Int,
  expanded : Bool,
  reference : Bool,
) -> Unit {
  let (func, writes, _) = local_graph_query_fixture(reads, locals)
  let cfg = cfg_build(func, expand_operand_control=expanded)
  let expected = local_graph_rounds_reference(func, cfg, true)
  let actual = local_graph_build_in_states(func, cfg, true)
  if actual != expected ||
    actual[cfg.exit_block][reads - 1] !=
    [local_graph_set_source_id(locals, writes[reads - 1])] {
    abort("worklist benchmark changed reaching definitions")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        local_graph_rounds_reference(func, cfg, true)
      } else {
        local_graph_build_in_states(func, cfg, true)
      },
    )
  })
}

///|
test "bench local-flow rounds reads=32 locals=128 expanded=true" (it : @bench.T) {
  local_graph_worklist_benchmark(it, 32, 128, true, true)
}

///|
test "bench local-flow worklist reads=32 locals=128 expanded=true" (
  it : @bench.T,
) {
  local_graph_worklist_benchmark(it, 32, 128, true, false)
}

///|
test "bench local-flow rounds reads=128 locals=512 expanded=true" (
  it : @bench.T,
) {
  local_graph_worklist_benchmark(it, 128, 512, true, true)
}

///|
test "bench local-flow worklist reads=128 locals=512 expanded=true" (
  it : @bench.T,
) {
  local_graph_worklist_benchmark(it, 128, 512, true, false)
}

///|
test "bench local-flow rounds reads=32 locals=128 expanded=false" (
  it : @bench.T,
) {
  local_graph_worklist_benchmark(it, 32, 128, false, true)
}

///|
test "bench local-flow worklist reads=32 locals=128 expanded=false" (
  it : @bench.T,
) {
  local_graph_worklist_benchmark(it, 32, 128, false, false)
}
