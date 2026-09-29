///|
fn hot_node_get_before_direct(func : HotFunc, id : NodeId) -> HotNode {
  hot_mutate_require_live_node(func, id, "hot node_get")
  func.nodes[id]
}

///|
fn hot_node_get_direct_bench(
  it : @bench.T,
  width : Int,
  deleted : Int,
  incomplete : Bool,
  reference : Bool,
) -> Unit {
  let func = HotFunc::new()
  for _ in 0..<width {
    ignore(hot_build_nop(func))
  }
  for id in 0..<deleted {
    hot_delete_node(func, id)
  }
  if incomplete {
    func.deleted_nodes.clear()
  }
  for id in deleted..<width {
    if hot_node_get(func, id) != hot_node_get_before_direct(func, id) {
      abort("getter changed the live node")
    }
  }
  let revision = hot_revision_current(func)
  let free = func.free_nodes.copy()
  it.bench(fn() {
    for step in 0..<4096 {
      let id = deleted + step * 73 % (width - deleted)
      it.keep(
        if reference {
          hot_node_get_before_direct(func, id)
        } else {
          hot_node_get(func, id)
        },
      )
    }
  })
  if hot_revision_current(func) != revision || func.free_nodes != free {
    abort("getter mutated the arena")
  }
}

///|
test "bench HOT direct getter nodes=16 deleted=0 maintained reference" (
  it : @bench.T,
) {
  hot_node_get_direct_bench(it, 16, 0, false, true)
}

///|
test "bench HOT direct getter nodes=16 deleted=0 maintained direct" (
  it : @bench.T,
) {
  hot_node_get_direct_bench(it, 16, 0, false, false)
}

///|
test "bench HOT direct getter nodes=128 deleted=16 maintained reference" (
  it : @bench.T,
) {
  hot_node_get_direct_bench(it, 128, 16, false, true)
}

///|
test "bench HOT direct getter nodes=128 deleted=16 maintained direct" (
  it : @bench.T,
) {
  hot_node_get_direct_bench(it, 128, 16, false, false)
}

///|
test "bench HOT direct getter nodes=4096 deleted=0 maintained reference" (
  it : @bench.T,
) {
  hot_node_get_direct_bench(it, 4096, 0, false, true)
}

///|
test "bench HOT direct getter nodes=4096 deleted=0 maintained direct" (
  it : @bench.T,
) {
  hot_node_get_direct_bench(it, 4096, 0, false, false)
}

///|
test "bench HOT direct getter nodes=4096 deleted=16 maintained reference" (
  it : @bench.T,
) {
  hot_node_get_direct_bench(it, 4096, 16, false, true)
}

///|
test "bench HOT direct getter nodes=4096 deleted=16 maintained direct" (
  it : @bench.T,
) {
  hot_node_get_direct_bench(it, 4096, 16, false, false)
}

///|
test "bench HOT direct getter nodes=4096 deleted=2048 maintained reference" (
  it : @bench.T,
) {
  hot_node_get_direct_bench(it, 4096, 2048, false, true)
}

///|
test "bench HOT direct getter nodes=4096 deleted=2048 maintained direct" (
  it : @bench.T,
) {
  hot_node_get_direct_bench(it, 4096, 2048, false, false)
}

///|
test "bench HOT direct getter nodes=128 deleted=16 incomplete reference" (
  it : @bench.T,
) {
  hot_node_get_direct_bench(it, 128, 16, true, true)
}

///|
test "bench HOT direct getter nodes=128 deleted=16 incomplete direct" (
  it : @bench.T,
) {
  hot_node_get_direct_bench(it, 128, 16, true, false)
}
