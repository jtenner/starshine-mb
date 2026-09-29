///|
// Frozen V6 child-query contract: check the node, check the slot, then read.
fn hot_field_query_header_child(
  func : HotFunc,
  id : NodeId,
  index : Int,
) -> NodeId {
  let data = hot_node_get(func, id)
  hot_mutate_require_child_index(data, index)
  func.children[data.child_base + index]
}

///|
fn hot_field_queries_bench(
  it : @bench.T,
  width : Int,
  deleted : Int,
  field : Int,
  reference : Bool,
) -> Unit {
  let func = HotFunc::new()
  let left = hot_build_const_i32(func, @lib.I32(7))
  let right = hot_build_const_i32(func, @lib.I32(11))
  for _ in 0..<width {
    ignore(hot_build_binary(func, @lib.ValType::i32(), left, right))
  }
  for id in 2..<(deleted + 2) {
    hot_delete_node(func, id)
  }
  let revision = hot_revision_current(func)
  for id in (deleted + 2)..<(width + 2) {
    if hot_node_op(func, id) != hot_node_get(func, id).op ||
      hot_node_type(func, id) != hot_node_get(func, id).ty ||
      hot_child_count(func, id) != 2 ||
      hot_child_get(func, id, 0) != left ||
      hot_child_get(func, id, 1) != right {
      abort("scalar field queries changed node or child fields")
    }
  }
  it.bench(fn() {
    for step in 0..<4096 {
      let id = deleted + 2 + step * 73 % (width - deleted)
      if field == 0 {
        it.keep(
          if reference {
            hot_node_get(func, id).op
          } else {
            hot_node_op(func, id)
          },
        )
      } else if field == 1 {
        it.keep(
          if reference {
            hot_node_get(func, id).ty
          } else {
            hot_node_type(func, id)
          },
        )
      } else {
        it.keep(
          if reference {
            hot_field_query_header_child(func, id, step % 2)
          } else {
            hot_child_get(func, id, step % 2)
          },
        )
      }
    }
  })
  if hot_revision_current(func) != revision {
    abort("scalar field queries mutated their reusable arena")
  }
}

///|
test "bench HOT opcode width=16 deleted=0 header" (it : @bench.T) {
  hot_field_queries_bench(it, 16, 0, 0, true)
}

///|
test "bench HOT opcode width=16 deleted=0 scalar" (it : @bench.T) {
  hot_field_queries_bench(it, 16, 0, 0, false)
}

///|
test "bench HOT type width=16 deleted=0 header" (it : @bench.T) {
  hot_field_queries_bench(it, 16, 0, 1, true)
}

///|
test "bench HOT type width=16 deleted=0 scalar" (it : @bench.T) {
  hot_field_queries_bench(it, 16, 0, 1, false)
}

///|
test "bench HOT child width=16 deleted=0 header" (it : @bench.T) {
  hot_field_queries_bench(it, 16, 0, 2, true)
}

///|
test "bench HOT child width=16 deleted=0 scalar" (it : @bench.T) {
  hot_field_queries_bench(it, 16, 0, 2, false)
}

///|
test "bench HOT opcode width=4096 deleted=128 header" (it : @bench.T) {
  hot_field_queries_bench(it, 4096, 128, 0, true)
}

///|
test "bench HOT opcode width=4096 deleted=128 scalar" (it : @bench.T) {
  hot_field_queries_bench(it, 4096, 128, 0, false)
}

///|
test "bench HOT type width=4096 deleted=128 header" (it : @bench.T) {
  hot_field_queries_bench(it, 4096, 128, 1, true)
}

///|
test "bench HOT type width=4096 deleted=128 scalar" (it : @bench.T) {
  hot_field_queries_bench(it, 4096, 128, 1, false)
}

///|
test "bench HOT child width=4096 deleted=128 header" (it : @bench.T) {
  hot_field_queries_bench(it, 4096, 128, 2, true)
}

///|
test "bench HOT child width=4096 deleted=128 scalar" (it : @bench.T) {
  hot_field_queries_bench(it, 4096, 128, 2, false)
}
