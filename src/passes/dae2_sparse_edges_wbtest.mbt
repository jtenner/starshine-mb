///|
test "dae2 sparse locations allocate edge storage only for actual dependencies" {
  let graph = Dae2Graph::new()
  for _ in 0..<64 {
    ignore(graph.location())
  }
  assert_eq(graph.edges.length(), 0)
  graph.edge(3, 1)
  graph.edge(1, 0)
  graph.edge(1, 0)
  graph.edge(4, 5)
  graph.edge(5, 4)
  graph.edge(-1, 0)
  graph.edge(0, -1)
  assert_eq(graph.edges.length(), 5)
  graph.observe(3)
  graph.solve()
  assert_eq(graph.work, [3, 1, 0])
  assert_eq(
    graph.used,
    Array::makei(64, fn(index) { index == 0 || index == 1 || index == 3 }),
  )
  graph.observe(4)
  graph.solve()
  assert_eq(graph.work, [3, 1, 0, 4, 5])
  assert_true(graph.used[4] && graph.used[5])
}

///|
test "dae2 dependency insertion order and repeated observations stay stable" {
  let graph = Dae2Graph::new()
  for _ in 0..<5 {
    ignore(graph.location())
  }
  graph.edge(0, 3)
  graph.edge(0, 1)
  graph.edge(0, 2)
  graph.edge(1, 4)
  graph.edge(2, 4)
  graph.observe(0)
  graph.observe(0)
  graph.solve()
  graph.solve()
  assert_eq(graph.work, [0, 3, 1, 2, 4])
  assert_true(graph.used.all(fn(value) { value }))
}

///|
fn dae2_test_dependencies(graph : Dae2Graph, consumer : Int) -> Array[Int] {
  let out : Array[Int] = []
  let mut edge = graph.first_edge[consumer]
  while edge >= 0 {
    out.push(graph.edges[edge])
    edge = graph.next_edge[edge]
  }
  out
}
