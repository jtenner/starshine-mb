///|
fn input_header_perf_run(it : @bench.T, roots : Int, original : Bool) -> Unit {
  let func = cfg_segment_storage_fixture(roots)
  let live : Array[NodeId] = []
  for node in 0..<hot_node_count(func) {
    if hot_node_is_live(func, node) {
      live.push(node)
    }
  }
  it.bench(fn() {
    for node in live {
      it.keep(
        if original {
          input_header_reference_info(func, node)
        } else {
          hot_lower_impl_input_info(func, node)
        },
      )
    }
  })
}

///|
test "bench input header groups=8 public" (it : @bench.T) {
  input_header_perf_run(it, 8, true)
}

///|
test "bench input header groups=8 inline" (it : @bench.T) {
  input_header_perf_run(it, 8, false)
}

///|
test "bench input header groups=64 public" (it : @bench.T) {
  input_header_perf_run(it, 64, true)
}

///|
test "bench input header groups=64 inline" (it : @bench.T) {
  input_header_perf_run(it, 64, false)
}

///|
test "bench input header groups=512 public" (it : @bench.T) {
  input_header_perf_run(it, 512, true)
}

///|
test "bench input header groups=512 inline" (it : @bench.T) {
  input_header_perf_run(it, 512, false)
}
