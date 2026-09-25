///|
fn dae2_repeated_solve_perf_run(count : Int) -> Dae2Graph {
  let graph = Dae2Graph::new()
  for _ in 0..<count {
    ignore(graph.location())
  }
  for idx in 0..<count {
    graph.observe(idx)
    graph.solve()
  }
  graph
}

///|
fn dae2_repeated_solve_perf_bench(it : @bench.T, count : Int) -> Unit {
  let preflight = dae2_repeated_solve_perf_run(count)
  if preflight.work.length() != count || !preflight.used.all(fn(used) { used }) {
    abort("DAE2 repeated-solve fixture did not observe every location")
  }
  it.bench(fn() { it.keep(dae2_repeated_solve_perf_run(count)) })
}

///|
test "DAE2 repeated solve propagates newly observed dependencies" {
  let graph = Dae2Graph::new()
  for _ in 0..<4 {
    ignore(graph.location())
  }
  graph.edge(0, 1)
  graph.edge(2, 3)
  graph.observe(0)
  graph.solve()
  assert_eq(graph.used, [true, true, false, false])
  graph.observe(2)
  graph.solve()
  assert_eq(graph.used, [true, true, true, true])
  assert_eq(graph.cursor, 4)
}

///|
test "bench DAE2 repeated solves count=128" (it : @bench.T) {
  dae2_repeated_solve_perf_bench(it, 128)
}

///|
test "bench DAE2 repeated solves count=256" (it : @bench.T) {
  dae2_repeated_solve_perf_bench(it, 256)
}
