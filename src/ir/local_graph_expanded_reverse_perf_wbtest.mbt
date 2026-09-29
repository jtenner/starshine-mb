///|
fn local_graph_expanded_reverse_bench(
  it : @bench.T,
  count : Int,
  dense : Bool,
) -> Unit {
  let (func, writes, reads) = local_graph_query_fixture(count, count * 4)
  let cfg = cfg_build(func, expand_operand_control=true)
  let expected = local_graph_build_with_exceptional_policy(func, cfg, true)
  let actual = local_graph_build_full_flow(func, cfg)
  for local in 0..<count {
    let sources = local_graph_reaching_sources_for_get(actual, reads[local])
    if sources != [SetSource(writes[local])] ||
      sources != local_graph_reaching_sources_for_get(expected, reads[local]) {
      abort("expanded flow changed cross-block reaching writes")
    }
  }
  it.bench(fn() {
    it.keep(
      if dense {
        local_graph_build_with_exceptional_policy(func, cfg, true)
      } else {
        local_graph_build_full_flow(func, cfg)
      },
    )
  })
}

///|
test "bench expanded flow dense reads=32 locals=128" (it : @bench.T) {
  local_graph_expanded_reverse_bench(it, 32, true)
}

///|
test "bench expanded flow selected reads=32 locals=128" (it : @bench.T) {
  local_graph_expanded_reverse_bench(it, 32, false)
}

///|
test "bench expanded flow dense reads=128 locals=512" (it : @bench.T) {
  local_graph_expanded_reverse_bench(it, 128, true)
}

///|
test "bench expanded flow selected reads=128 locals=512" (it : @bench.T) {
  local_graph_expanded_reverse_bench(it, 128, false)
}

///|
test "bench expanded flow dense reads=256 locals=1024" (it : @bench.T) {
  local_graph_expanded_reverse_bench(it, 256, true)
}

///|
test "bench expanded flow selected reads=256 locals=1024" (it : @bench.T) {
  local_graph_expanded_reverse_bench(it, 256, false)
}
