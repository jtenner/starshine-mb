///|
fn dae2_sparse_edges_reference(
  count : Int,
  dense? : Bool = false,
) -> Array[Bool] {
  let edges : Array[Array[Int]] = []
  let used : Array[Bool] = []
  for _ in 0..<count {
    edges.push([])
    used.push(false)
  }
  for index in 1..<count {
    if dense {
      edges[index].push(index - 1)
      if index >= 2 {
        edges[index].push(index - 2)
      }
      if index >= 8 {
        edges[index].push(index - 8)
      }
    } else if index % 8 == 0 {
      edges[index].push(index - 8)
    }
  }
  let start = if dense { count - 1 } else { count - 8 }
  let work = [start]
  used[start] = true
  let mut cursor = 0
  while cursor < work.length() {
    let consumer = work[cursor]
    cursor += 1
    for source in edges[consumer] {
      if !used[source] {
        used[source] = true
        work.push(source)
      }
    }
  }
  used
}

///|
fn dae2_sparse_edges_current(count : Int, dense? : Bool = false) -> Array[Bool] {
  let graph = Dae2Graph::new()
  for _ in 0..<count {
    ignore(graph.location())
  }
  for index in 1..<count {
    if dense {
      graph.edge(index, index - 1)
      if index >= 2 {
        graph.edge(index, index - 2)
      }
      if index >= 8 {
        graph.edge(index, index - 8)
      }
    } else if index % 8 == 0 {
      graph.edge(index, index - 8)
    }
  }
  graph.observe(if dense { count - 1 } else { count - 8 })
  graph.solve()
  graph.used
}

///|
fn dae2_sparse_edges_bench(
  it : @bench.T,
  count : Int,
  reference : Bool,
  dense? : Bool = false,
) -> Unit {
  if dae2_sparse_edges_current(count, dense~) !=
    dae2_sparse_edges_reference(count, dense~) {
    abort("sparse dependency graph changed liveness")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        dae2_sparse_edges_reference(count, dense~)
      } else {
        dae2_sparse_edges_current(count, dense~)
      },
    )
  })
}

///|
test "bench dae2 sparse graph locations=8192 reference" (it : @bench.T) {
  dae2_sparse_edges_bench(it, 8192, true)
}

///|
test "bench dae2 sparse graph locations=8192 flat" (it : @bench.T) {
  dae2_sparse_edges_bench(it, 8192, false)
}

///|
test "bench dae2 sparse graph locations=32768 reference" (it : @bench.T) {
  dae2_sparse_edges_bench(it, 32768, true)
}

///|
test "bench dae2 sparse graph locations=32768 flat" (it : @bench.T) {
  dae2_sparse_edges_bench(it, 32768, false)
}

///|
test "bench dae2 dense graph locations=4096 reference" (it : @bench.T) {
  dae2_sparse_edges_bench(it, 4096, true, dense=true)
}

///|
test "bench dae2 dense graph locations=4096 flat" (it : @bench.T) {
  dae2_sparse_edges_bench(it, 4096, false, dense=true)
}
