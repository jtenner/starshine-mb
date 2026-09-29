///|
fn local_graph_ssa_union_reference(
  func : HotFunc,
  local_count : Int,
  get_sources : Array[Array[Int]],
) -> Array[Bool] {
  let index_sources : Array[Array[Int]] = []
  for _ in 0..<local_count {
    index_sources.push([])
  }
  for node_id = 0; node_id < hot_node_count(func); node_id = node_id + 1 {
    if !hot_node_is_live(func, node_id) {
      continue
    }
    let node = hot_node_get(func, node_id)
    match node.op {
      HotOp::LocalGet =>
        ignore(
          local_graph_union_into(index_sources[node.imm0], get_sources[node_id]),
        )
      _ => ()
    }
  }
  for node_id = 0; node_id < hot_node_count(func); node_id = node_id + 1 {
    if !hot_node_is_live(func, node_id) {
      continue
    }
    let node = hot_node_get(func, node_id)
    match node.op {
      HotOp::LocalSet | HotOp::LocalTee => {
        let sources = index_sources[node.imm0]
        if sources.length() == 1 &&
          sources[0] != local_graph_set_source_id(local_count, node_id) {
          sources.clear()
        }
      }
      _ => ()
    }
  }
  let out : Array[Bool] = []
  for sources in index_sources {
    out.push(sources.length() == 1)
  }
  out
}

///|
fn local_graph_ssa_summary_bench(
  it : @bench.T,
  count : Int,
  reference : Bool,
) -> Unit {
  let (func, sources) = local_graph_ssa_summary_fixture(count)
  if local_graph_ssa_union_reference(func, 2, sources) !=
    local_graph_build_local_already_ssa(func, 2, sources) {
    abort("SSA source summary differs from union reference")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        local_graph_ssa_union_reference(func, 2, sources)
      } else {
        local_graph_build_local_already_ssa(func, 2, sources)
      },
    )
  })
}

///|
test "bench SSA source union writes=16" (it : @bench.T) {
  local_graph_ssa_summary_bench(it, 16, true)
}

///|
test "bench SSA source summary writes=16" (it : @bench.T) {
  local_graph_ssa_summary_bench(it, 16, false)
}

///|
test "bench SSA source union writes=128" (it : @bench.T) {
  local_graph_ssa_summary_bench(it, 128, true)
}

///|
test "bench SSA source summary writes=128" (it : @bench.T) {
  local_graph_ssa_summary_bench(it, 128, false)
}

///|
test "bench SSA source union writes=512" (it : @bench.T) {
  local_graph_ssa_summary_bench(it, 512, true)
}

///|
test "bench SSA source summary writes=512" (it : @bench.T) {
  local_graph_ssa_summary_bench(it, 512, false)
}
