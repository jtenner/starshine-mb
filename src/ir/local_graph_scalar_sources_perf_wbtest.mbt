///|
fn local_graph_scalar_sources_bench(
  it : @bench.T,
  writes : Int,
  reads : Int,
  scalar : Bool,
) -> Unit {
  let wat = ["(module (func (param i32) (local i32)"]
  for index in 0..<writes {
    wat.push("local.get 0 if i32.const \{index} local.set 1 end")
  }
  for _ in 0..<reads {
    wat.push("local.get 1 drop")
  }
  wat.push("))")
  let input = @wast.wast_to_binary_module(wat.join(" ")).unwrap()
  let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
  let graph = local_graph_build_full_flow(
    func,
    cfg_build(func, expand_operand_control=true),
  )
  let queries : Array[NodeId] = []
  for node in 0..<hot_node_count(func) {
    let data = hot_node_get(func, node)
    if data.op is LocalGet && data.imm0 == 1 {
      queries.push(node)
      if local_graph_reaching_source_count_for_get(graph, node) != writes + 1 {
        abort(
          "source query benchmark lost a conditional write or default entry",
        )
      }
    }
  }
  if queries.length() != reads {
    abort("source query benchmark lost repeated reads")
  }
  let query = fn(scalar) {
    let mut checksum = 0
    for node in queries {
      if scalar {
        let count = local_graph_reaching_source_count_for_get(graph, node)
        for index in 0..<count {
          let source = local_graph_reaching_source_value_for_get(
            graph, node, index,
          )
          checksum += source.index +
            (if source.is_entry { 0 } else { hot_local_count(func) })
        }
      } else {
        let count = local_graph_reaching_source_count_for_get(graph, node)
        for index in 0..<count {
          checksum += match
            local_graph_reaching_source_for_get(graph, node, index) {
            EntrySource(local) => local
            SetSource(write) => write + hot_local_count(func)
          }
        }
      }
    }
    checksum
  }
  if query(true) != query(false) {
    abort("indexed query changed source payloads or order")
  }
  it.bench(fn() { it.keep(query(scalar)) })
}

///|
test "bench local source query writes=0 reads=1 enum" (it : @bench.T) {
  local_graph_scalar_sources_bench(it, 0, 1, false)
}

///|
test "bench local source query writes=0 reads=1 scalar" (it : @bench.T) {
  local_graph_scalar_sources_bench(it, 0, 1, true)
}

///|
test "bench local source query writes=0 reads=128 enum" (it : @bench.T) {
  local_graph_scalar_sources_bench(it, 0, 128, false)
}

///|
test "bench local source query writes=0 reads=128 scalar" (it : @bench.T) {
  local_graph_scalar_sources_bench(it, 0, 128, true)
}

///|
test "bench local source query writes=1 reads=1 enum" (it : @bench.T) {
  local_graph_scalar_sources_bench(it, 1, 1, false)
}

///|
test "bench local source query writes=1 reads=1 scalar" (it : @bench.T) {
  local_graph_scalar_sources_bench(it, 1, 1, true)
}

///|
test "bench local source query writes=1 reads=128 enum" (it : @bench.T) {
  local_graph_scalar_sources_bench(it, 1, 128, false)
}

///|
test "bench local source query writes=1 reads=128 scalar" (it : @bench.T) {
  local_graph_scalar_sources_bench(it, 1, 128, true)
}

///|
test "bench local source query writes=16 reads=1 enum" (it : @bench.T) {
  local_graph_scalar_sources_bench(it, 16, 1, false)
}

///|
test "bench local source query writes=16 reads=1 scalar" (it : @bench.T) {
  local_graph_scalar_sources_bench(it, 16, 1, true)
}

///|
test "bench local source query writes=16 reads=128 enum" (it : @bench.T) {
  local_graph_scalar_sources_bench(it, 16, 128, false)
}

///|
test "bench local source query writes=16 reads=128 scalar" (it : @bench.T) {
  local_graph_scalar_sources_bench(it, 16, 128, true)
}

///|
test "bench local source query writes=128 reads=1 enum" (it : @bench.T) {
  local_graph_scalar_sources_bench(it, 128, 1, false)
}

///|
test "bench local source query writes=128 reads=1 scalar" (it : @bench.T) {
  local_graph_scalar_sources_bench(it, 128, 1, true)
}

///|
test "bench local source query writes=128 reads=128 enum" (it : @bench.T) {
  local_graph_scalar_sources_bench(it, 128, 128, false)
}

///|
test "bench local source query writes=128 reads=128 scalar" (it : @bench.T) {
  local_graph_scalar_sources_bench(it, 128, 128, true)
}
