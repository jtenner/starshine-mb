///|
fn local_graph_write_scan_reference(
  func : HotFunc,
  actions : Array[NodeId],
  end : Int,
  local_id : LocalId,
) -> NodeId? {
  let mut idx = if end < actions.length() { end } else { actions.length() }
  while idx > 0 {
    idx -= 1
    let node_id = actions[idx]
    let node = hot_node_get(func, node_id)
    match node.op {
      HotOp::LocalSet | HotOp::LocalTee =>
        if node.imm0 == local_id {
          return Some(node_id)
        }
      _ => ()
    }
  }
  None
}

///|
fn local_graph_write_index_bench(it : @bench.T, reference : Bool) -> Unit {
  let (func, actions) = local_graph_write_index_fixture()
  let write_local_ids = local_graph_build_write_local_ids(func)
  for local in 0..<4 {
    if local_graph_reverse_find_last_write(write_local_ids, actions, 4, local) !=
      local_graph_write_scan_reference(func, actions, 4, local) {
      abort("write lookup changed the reaching definition")
    }
  }
  it.bench(fn() {
    for index in 0..<512 {
      it.keep(
        if reference {
          local_graph_write_scan_reference(func, actions, 4, index % 4)
        } else {
          local_graph_reverse_find_last_write(
            write_local_ids,
            actions,
            4,
            index % 4,
          )
        },
      )
    }
  })
}

///|
test "bench reverse write node scan queries=512" (it : @bench.T) {
  local_graph_write_index_bench(it, true)
}

///|
test "bench reverse write local index queries=512" (it : @bench.T) {
  local_graph_write_index_bench(it, false)
}
