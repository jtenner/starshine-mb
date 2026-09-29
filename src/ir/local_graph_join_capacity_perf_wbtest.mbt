///|
fn local_graph_join_before_capacity(
  lhs : Array[Int],
  rhs : Array[Int],
) -> Array[Int] {
  if physical_equal(lhs, rhs) || rhs.is_empty() {
    return lhs
  }
  if lhs.is_empty() {
    return rhs
  }
  if lhs.length() >= 256 && rhs.length() >= 256 {
    return local_graph_join_indexed_sources(lhs, rhs)
  }
  if rhs.all(fn(source) { local_graph_array_contains(lhs, source) }) {
    return lhs
  }
  let merged = lhs.copy()
  ignore(local_graph_union_into(merged, rhs))
  merged
}

///|
fn local_graph_join_capacity_bench(
  it : @bench.T,
  width : Int,
  subset : Bool,
  reference : Bool,
) -> Unit {
  let lhs = Array::makei(width, fn(i) { i })
  let rhs = Array::makei(width, fn(i) {
    i + (if subset { 0 } else { width / 2 + 1 })
  })
  let expected = local_graph_join_before_capacity(lhs, rhs)
  if local_graph_join_sources(lhs, rhs) != expected {
    abort("source encounter order changed")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        local_graph_join_before_capacity(lhs, rhs)
      } else {
        local_graph_join_sources(lhs, rhs)
      },
    )
  })
  if lhs != Array::makei(width, fn(i) { i }) {
    abort("join mutated its left input")
  }
}

///|
test "bench local join capacity width=1 overlap reference" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 1, false, true)
}

///|
test "bench local join capacity width=1 overlap reserved" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 1, false, false)
}

///|
test "bench local join capacity width=1 subset reference" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 1, true, true)
}

///|
test "bench local join capacity width=1 subset reserved" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 1, true, false)
}

///|
test "bench local join capacity width=4 overlap reference" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 4, false, true)
}

///|
test "bench local join capacity width=4 overlap reserved" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 4, false, false)
}

///|
test "bench local join capacity width=4 subset reference" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 4, true, true)
}

///|
test "bench local join capacity width=4 subset reserved" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 4, true, false)
}

///|
test "bench local join capacity width=32 overlap reference" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 32, false, true)
}

///|
test "bench local join capacity width=32 overlap reserved" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 32, false, false)
}

///|
test "bench local join capacity width=32 subset reference" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 32, true, true)
}

///|
test "bench local join capacity width=32 subset reserved" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 32, true, false)
}

///|
test "bench local join capacity width=128 overlap reference" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 128, false, true)
}

///|
test "bench local join capacity width=128 overlap reserved" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 128, false, false)
}

///|
test "bench local join capacity width=128 subset reference" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 128, true, true)
}

///|
test "bench local join capacity width=128 subset reserved" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 128, true, false)
}

///|
test "bench local join capacity width=512 overlap reference" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 512, false, true)
}

///|
test "bench local join capacity width=512 overlap reserved" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 512, false, false)
}

///|
test "bench local join capacity width=512 subset reference" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 512, true, true)
}

///|
test "bench local join capacity width=512 subset reserved" (it : @bench.T) {
  local_graph_join_capacity_bench(it, 512, true, false)
}
