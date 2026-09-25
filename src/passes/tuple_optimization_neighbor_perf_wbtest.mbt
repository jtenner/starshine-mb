///|
fn tuple_optimization_neighbor_perf_bench(it : @bench.T, count : Int) -> Unit {
  let preflight : Array[Int] = []
  for neighbor in 0..<count {
    tuple_optimization_add_neighbor(preflight, neighbor)
  }
  tuple_optimization_add_neighbor(preflight, count - 1)
  if preflight.length() != count ||
    preflight[0] != 0 ||
    preflight[count - 1] != count - 1 {
    abort("tuple neighbor fixture lost insertion order or deduplication")
  }
  it.bench(fn() {
    let neighbors : Array[Int] = []
    for neighbor in 0..<count {
      tuple_optimization_add_neighbor(neighbors, neighbor)
    }
    it.keep(neighbors)
  })
}

///|
test "bench tuple neighbor ascending count=1024" (it : @bench.T) {
  tuple_optimization_neighbor_perf_bench(it, 1024)
}

///|
test "bench tuple neighbor ascending count=2048" (it : @bench.T) {
  tuple_optimization_neighbor_perf_bench(it, 2048)
}

///|
test "tuple neighbor append fast path keeps order and deduplicates" {
  let neighbors : Array[Int] = []
  for neighbor in [2, 5, 5, 3, 7, 2, 9] {
    tuple_optimization_add_neighbor(neighbors, neighbor)
  }
  @debug.assert_eq(neighbors, [2, 5, 3, 7, 9])
}
