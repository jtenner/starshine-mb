///|
fn local_graph_influence_rows_before_sharing(
  func : HotFunc,
) -> Array[Array[NodeId]] {
  let rows : Array[Array[NodeId]] = []
  for _ in 0..<hot_node_count(func) {
    rows.push([])
  }
  rows
}

///|
fn local_graph_influence_rows_bench(
  it : @bench.T,
  nodes : Int,
  density : Int,
  observations : Int,
  reference : Bool,
) -> Unit {
  let writes_count = if density == 0 {
    0
  } else if density == 1 {
    1
  } else {
    nodes / (2 + 2 * observations)
  }
  let func = HotFunc::new(
    locals=HotLocals::new(locals=Array::make(writes_count, @lib.ValType::i32())),
  )
  let writes : Array[NodeId] = []
  let reads : Array[Array[NodeId]] = []
  let sources : Array[Array[Int]] = []
  for local in 0..<writes_count {
    let write = hot_build_local_set(
      func,
      local,
      hot_build_const_i32(func, @lib.I32(local)),
    )
    hot_root_append(func, write)
    writes.push(write)
    sources.push([writes_count + write])
    let observers : Array[NodeId] = []
    for _ in 0..<observations {
      let read = hot_build_local_get(func, local)
      observers.push(read)
      hot_root_append(func, hot_build_drop(func, read))
    }
    reads.push(observers)
  }
  while hot_node_count(func) < nodes {
    hot_root_append(func, hot_build_nop(func))
  }
  hot_verify_core(func).unwrap()
  let build = fn() {
    let rows = if reference {
      local_graph_influence_rows_before_sharing(func)
    } else {
      local_graph_empty_influences(func)
    }
    for index in 0..<writes.length() {
      for read in reads[index] {
        if reference {
          local_graph_record_sources_before_borrow(
            writes_count,
            read,
            sources[index],
            None,
            Some(rows),
          )
        } else {
          local_graph_record_get_sources(
            writes_count,
            read,
            sources[index],
            None,
            Some(rows),
          )
        }
      }
    }
    rows
  }
  let result = build()
  for index in 0..<writes.length() {
    if result[writes[index]] != reads[index] {
      abort("influence observer order changed")
    }
  }
  for node in 0..<hot_node_count(func) {
    if !(hot_node_get(func, node).op is HotOp::LocalSet) &&
      !result[node].is_empty() {
      abort("recording changed an unobserved node row")
    }
  }
  it.bench(fn() { it.keep(build()) })
}

///|
test "bench local influence rows eager nodes=32 empty reads=1" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 32, 0, 1, true)
}

///|
test "bench local influence rows lazy nodes=32 empty reads=1" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 32, 0, 1, false)
}

///|
test "bench local influence rows eager nodes=32 sparse reads=1" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 32, 1, 1, true)
}

///|
test "bench local influence rows lazy nodes=32 sparse reads=1" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 32, 1, 1, false)
}

///|
test "bench local influence rows eager nodes=32 sparse reads=4" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 32, 1, 4, true)
}

///|
test "bench local influence rows lazy nodes=32 sparse reads=4" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 32, 1, 4, false)
}

///|
test "bench local influence rows eager nodes=32 dense reads=1" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 32, 2, 1, true)
}

///|
test "bench local influence rows lazy nodes=32 dense reads=1" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 32, 2, 1, false)
}

///|
test "bench local influence rows eager nodes=32 dense reads=4" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 32, 2, 4, true)
}

///|
test "bench local influence rows lazy nodes=32 dense reads=4" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 32, 2, 4, false)
}

///|
test "bench local influence rows eager nodes=2048 empty reads=1" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 2048, 0, 1, true)
}

///|
test "bench local influence rows lazy nodes=2048 empty reads=1" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 2048, 0, 1, false)
}

///|
test "bench local influence rows eager nodes=2048 sparse reads=1" (
  it : @bench.T,
) {
  local_graph_influence_rows_bench(it, 2048, 1, 1, true)
}

///|
test "bench local influence rows lazy nodes=2048 sparse reads=1" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 2048, 1, 1, false)
}

///|
test "bench local influence rows eager nodes=2048 sparse reads=4" (
  it : @bench.T,
) {
  local_graph_influence_rows_bench(it, 2048, 1, 4, true)
}

///|
test "bench local influence rows lazy nodes=2048 sparse reads=4" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 2048, 1, 4, false)
}

///|
test "bench local influence rows eager nodes=2048 dense reads=1" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 2048, 2, 1, true)
}

///|
test "bench local influence rows lazy nodes=2048 dense reads=1" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 2048, 2, 1, false)
}

///|
test "bench local influence rows eager nodes=2048 dense reads=4" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 2048, 2, 4, true)
}

///|
test "bench local influence rows lazy nodes=2048 dense reads=4" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 2048, 2, 4, false)
}

///|
test "bench local influence rows eager nodes=32768 empty reads=1" (
  it : @bench.T,
) {
  local_graph_influence_rows_bench(it, 32768, 0, 1, true)
}

///|
test "bench local influence rows lazy nodes=32768 empty reads=1" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 32768, 0, 1, false)
}

///|
test "bench local influence rows eager nodes=32768 sparse reads=1" (
  it : @bench.T,
) {
  local_graph_influence_rows_bench(it, 32768, 1, 1, true)
}

///|
test "bench local influence rows lazy nodes=32768 sparse reads=1" (
  it : @bench.T,
) {
  local_graph_influence_rows_bench(it, 32768, 1, 1, false)
}

///|
test "bench local influence rows eager nodes=32768 sparse reads=4" (
  it : @bench.T,
) {
  local_graph_influence_rows_bench(it, 32768, 1, 4, true)
}

///|
test "bench local influence rows lazy nodes=32768 sparse reads=4" (
  it : @bench.T,
) {
  local_graph_influence_rows_bench(it, 32768, 1, 4, false)
}

///|
test "bench local influence rows eager nodes=32768 dense reads=1" (
  it : @bench.T,
) {
  local_graph_influence_rows_bench(it, 32768, 2, 1, true)
}

///|
test "bench local influence rows lazy nodes=32768 dense reads=1" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 32768, 2, 1, false)
}

///|
test "bench local influence rows eager nodes=32768 dense reads=4" (
  it : @bench.T,
) {
  local_graph_influence_rows_bench(it, 32768, 2, 4, true)
}

///|
test "bench local influence rows lazy nodes=32768 dense reads=4" (it : @bench.T) {
  local_graph_influence_rows_bench(it, 32768, 2, 4, false)
}
