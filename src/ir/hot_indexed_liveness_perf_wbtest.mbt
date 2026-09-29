///|
fn hot_node_is_live_reference(func : HotFunc, node_id : NodeId) -> Bool {
  if node_id < 0 || node_id >= func.nodes.length() {
    return false
  }
  if func.free_nodes.is_empty() {
    return true
  }
  if func.free_nodes.length() <= 32 {
    for free_id in func.free_nodes {
      if free_id == node_id {
        return false
      }
    }
    return true
  }
  if node_id >= func.deleted_nodes.length() {
    return true
  }
  !func.deleted_nodes[node_id]
}

///|
fn hot_require_live_node_reference(
  func : HotFunc,
  node_id : NodeId,
  context : String,
) -> Unit {
  if !hot_node_is_live_reference(func, node_id) {
    abort("\{context} must reference a live NodeId")
  }
}

///|
fn hot_node_get_reference(func : HotFunc, node_id : NodeId) -> HotNode {
  hot_require_live_node_reference(func, node_id, "hot node_get")
  func.nodes[node_id]
}

///|
fn hot_indexed_liveness_fixture(width : Int, deleted : Int) -> HotFunc {
  let func = HotFunc::new()
  for _ in 0..<width {
    ignore(hot_build_nop(func))
  }
  for node in 0..<deleted {
    hot_delete_node(func, node)
  }
  for node in 0..<width {
    if hot_node_is_live(func, node) != (node >= deleted) ||
      hot_node_is_live_reference(func, node) != (node >= deleted) {
      abort("tombstone membership mismatch")
    }
  }
  func
}

///|
fn hot_indexed_liveness_bench(
  it : @bench.T,
  width : Int,
  deleted : Int,
  reference : Bool,
  getter : Bool,
) -> Unit {
  let func = hot_indexed_liveness_fixture(width, deleted)
  let revision = hot_revision_current(func)
  let free = func.free_nodes.copy()
  let before = hot_lower_func_unverified(func)
  if hot_revision_current(func) != revision || func.free_nodes != free {
    abort("liveness query mutated its function")
  }
  let @lib.Func(_, @lib.Expr(body)) = before
  if !body.is_empty() {
    abort("liveness fixture acquired observable instructions")
  }
  it.bench(fn() {
    for step in 0..<4096 {
      let node = step * 73 % width
      if getter {
        if node >= deleted {
          it.keep(
            if reference {
              hot_node_get_reference(func, node)
            } else {
              hot_node_get(func, node)
            },
          )
        }
      } else {
        it.keep(
          if reference {
            hot_node_is_live_reference(func, node)
          } else {
            hot_node_is_live(func, node)
          },
        )
      }
    }
  })
}

///|
test "bench HOT liveness nodes=16 deleted=0 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 16, 0, true, false)
}

///|
test "bench HOT liveness nodes=16 deleted=0 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 16, 0, false, false)
}

///|
test "bench HOT liveness nodes=16 deleted=1 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 16, 1, true, false)
}

///|
test "bench HOT liveness nodes=16 deleted=1 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 16, 1, false, false)
}

///|
test "bench HOT liveness nodes=16 deleted=8 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 16, 8, true, false)
}

///|
test "bench HOT liveness nodes=16 deleted=8 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 16, 8, false, false)
}

///|
test "bench HOT liveness nodes=128 deleted=0 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 128, 0, true, false)
}

///|
test "bench HOT liveness nodes=128 deleted=0 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 128, 0, false, false)
}

///|
test "bench HOT liveness nodes=128 deleted=1 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 128, 1, true, false)
}

///|
test "bench HOT liveness nodes=128 deleted=1 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 128, 1, false, false)
}

///|
test "bench HOT liveness nodes=128 deleted=8 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 128, 8, true, false)
}

///|
test "bench HOT liveness nodes=128 deleted=8 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 128, 8, false, false)
}

///|
test "bench HOT liveness nodes=128 deleted=16 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 128, 16, true, false)
}

///|
test "bench HOT liveness nodes=128 deleted=16 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 128, 16, false, false)
}

///|
test "bench HOT liveness nodes=128 deleted=32 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 128, 32, true, false)
}

///|
test "bench HOT liveness nodes=128 deleted=32 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 128, 32, false, false)
}

///|
test "bench HOT liveness nodes=128 deleted=64 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 128, 64, true, false)
}

///|
test "bench HOT liveness nodes=128 deleted=64 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 128, 64, false, false)
}

///|
test "bench HOT liveness nodes=4096 deleted=0 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 4096, 0, true, false)
}

///|
test "bench HOT liveness nodes=4096 deleted=0 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 4096, 0, false, false)
}

///|
test "bench HOT liveness nodes=4096 deleted=1 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 4096, 1, true, false)
}

///|
test "bench HOT liveness nodes=4096 deleted=1 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 4096, 1, false, false)
}

///|
test "bench HOT liveness nodes=4096 deleted=8 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 4096, 8, true, false)
}

///|
test "bench HOT liveness nodes=4096 deleted=8 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 4096, 8, false, false)
}

///|
test "bench HOT liveness nodes=4096 deleted=16 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 4096, 16, true, false)
}

///|
test "bench HOT liveness nodes=4096 deleted=16 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 4096, 16, false, false)
}

///|
test "bench HOT liveness nodes=4096 deleted=32 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 4096, 32, true, false)
}

///|
test "bench HOT liveness nodes=4096 deleted=32 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 4096, 32, false, false)
}

///|
test "bench HOT liveness nodes=4096 deleted=64 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 4096, 64, true, false)
}

///|
test "bench HOT liveness nodes=4096 deleted=64 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 4096, 64, false, false)
}

///|
test "bench HOT getter nodes=128 deleted=1 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 128, 1, true, true)
}

///|
test "bench HOT getter nodes=128 deleted=1 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 128, 1, false, true)
}

///|
test "bench HOT getter nodes=128 deleted=16 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 128, 16, true, true)
}

///|
test "bench HOT getter nodes=128 deleted=16 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 128, 16, false, true)
}

///|
test "bench HOT getter nodes=128 deleted=64 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 128, 64, true, true)
}

///|
test "bench HOT getter nodes=128 deleted=64 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 128, 64, false, true)
}

///|
test "bench HOT getter nodes=4096 deleted=1 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 4096, 1, true, true)
}

///|
test "bench HOT getter nodes=4096 deleted=1 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 4096, 1, false, true)
}

///|
test "bench HOT getter nodes=4096 deleted=16 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 4096, 16, true, true)
}

///|
test "bench HOT getter nodes=4096 deleted=16 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 4096, 16, false, true)
}

///|
test "bench HOT getter nodes=4096 deleted=64 reference" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 4096, 64, true, true)
}

///|
test "bench HOT getter nodes=4096 deleted=64 indexed" (it : @bench.T) {
  hot_indexed_liveness_bench(it, 4096, 64, false, true)
}
