///|
fn local_graph_join_before_prefix(
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
  let merged : Array[Int] = Array(capacity=lhs.length() + rhs.length())
  merged.append(lhs)
  ignore(local_graph_union_into(merged, rhs))
  merged
}

///|
fn local_graph_join_prefix_bench(
  it : @bench.T,
  width : Int,
  mode : Int,
  reference : Bool,
) -> Unit {
  let lhs = Array::makei(width, fn(index) { index })
  let rhs = Array::makei(width, fn(index) {
    if mode == 0 {
      index + width
    } else if mode == 1 && index == width - 1 {
      width
    } else {
      index
    }
  })
  let expected = if mode == 2 {
    lhs
  } else if mode == 1 {
    Array::makei(width + 1, fn(index) { index })
  } else {
    Array::makei(width * 2, fn(index) { index })
  }
  if local_graph_join_sources(lhs, rhs) != expected ||
    local_graph_join_before_prefix(lhs, rhs) != expected {
    abort("ordered union changed")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        local_graph_join_before_prefix(lhs, rhs)
      } else {
        local_graph_join_sources(lhs, rhs)
      },
    )
  })
  if lhs != Array::makei(width, fn(index) { index }) {
    abort("left source mutated")
  }
}

///|
test "bench local join prefix width=1 early reference" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 1, 0, true)
}

///|
test "bench local join prefix width=1 early once" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 1, 0, false)
}

///|
test "bench local join prefix width=1 late reference" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 1, 1, true)
}

///|
test "bench local join prefix width=1 late once" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 1, 1, false)
}

///|
test "bench local join prefix width=1 subset reference" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 1, 2, true)
}

///|
test "bench local join prefix width=1 subset once" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 1, 2, false)
}

///|
test "bench local join prefix width=32 early reference" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 32, 0, true)
}

///|
test "bench local join prefix width=32 early once" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 32, 0, false)
}

///|
test "bench local join prefix width=32 late reference" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 32, 1, true)
}

///|
test "bench local join prefix width=32 late once" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 32, 1, false)
}

///|
test "bench local join prefix width=32 subset reference" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 32, 2, true)
}

///|
test "bench local join prefix width=32 subset once" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 32, 2, false)
}

///|
test "bench local join prefix width=128 early reference" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 128, 0, true)
}

///|
test "bench local join prefix width=128 early once" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 128, 0, false)
}

///|
test "bench local join prefix width=128 late reference" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 128, 1, true)
}

///|
test "bench local join prefix width=128 late once" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 128, 1, false)
}

///|
test "bench local join prefix width=128 subset reference" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 128, 2, true)
}

///|
test "bench local join prefix width=128 subset once" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 128, 2, false)
}

///|
test "bench local join prefix width=512 early reference" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 512, 0, true)
}

///|
test "bench local join prefix width=512 early once" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 512, 0, false)
}

///|
test "bench local join prefix width=512 late reference" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 512, 1, true)
}

///|
test "bench local join prefix width=512 late once" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 512, 1, false)
}

///|
test "bench local join prefix width=512 subset reference" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 512, 2, true)
}

///|
test "bench local join prefix width=512 subset once" (it : @bench.T) {
  local_graph_join_prefix_bench(it, 512, 2, false)
}
