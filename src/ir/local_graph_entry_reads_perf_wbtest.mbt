///|
fn entry_read_perf_run(it : @bench.T, count : Int, original : Bool) -> Unit {
  let (func, cfg, _, _) = entry_read_fixture(count)
  it.bench(fn() {
    let graph = if original {
      entry_read_reference_build_reverse_flow(func, cfg, true)
    } else {
      local_graph_build_reverse_flow(func, cfg, true)
    }
    it.keep(graph)
  })
}

///|
test "bench immutable selector reads conditional writes=8 original" (
  it : @bench.T,
) {
  entry_read_perf_run(it, 8, true)
}

///|
test "bench immutable selector reads conditional writes=8 entry" (it : @bench.T) {
  entry_read_perf_run(it, 8, false)
}

///|
test "bench immutable selector reads conditional writes=64 original" (
  it : @bench.T,
) {
  entry_read_perf_run(it, 64, true)
}

///|
test "bench immutable selector reads conditional writes=64 entry" (
  it : @bench.T,
) {
  entry_read_perf_run(it, 64, false)
}

///|
test "bench immutable selector reads conditional writes=512 original" (
  it : @bench.T,
) {
  entry_read_perf_run(it, 512, true)
}

///|
test "bench immutable selector reads conditional writes=512 entry" (
  it : @bench.T,
) {
  entry_read_perf_run(it, 512, false)
}
