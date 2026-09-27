///|
fn local_join_reference(lhs : Array[Int], rhs : Array[Int]) -> Array[Int] {
  if physical_equal(lhs, rhs) || rhs.is_empty() {
    return lhs
  }
  if lhs.is_empty() {
    return rhs
  }
  if rhs.all(fn(source) { local_graph_array_contains(lhs, source) }) {
    return lhs
  }
  let merged = lhs.copy()
  ignore(local_graph_union_into(merged, rhs))
  merged
}

///|
fn local_join_bench(
  it : @bench.T,
  width : Int,
  subset : Bool,
  reference : Bool,
) -> Unit {
  let lhs = Array::makei(width, fn(index) { index })
  let rhs = Array::makei(width, fn(index) {
    index + (if subset { 0 } else { width / 2 })
  })
  if local_join_reference(lhs, rhs) != local_graph_join_sources(lhs, rhs) {
    abort("join order changed")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        local_join_reference(lhs, rhs)
      } else {
        local_graph_join_sources(lhs, rhs)
      },
    )
  })
}

///|
test "bench reuse-campaign local join width=8 reference" (it : @bench.T) {
  local_join_bench(it, 8, false, true)
}

///|
test "bench reuse-campaign local join width=8 candidate" (it : @bench.T) {
  local_join_bench(it, 8, false, false)
}

///|
test "bench reuse-campaign local join width=512 reference" (it : @bench.T) {
  local_join_bench(it, 512, false, true)
}

///|
test "bench reuse-campaign local join width=512 candidate" (it : @bench.T) {
  local_join_bench(it, 512, false, false)
}

///|
test "bench reuse-campaign local join subset width=512 reference" (
  it : @bench.T,
) {
  local_join_bench(it, 512, true, true)
}

///|
test "bench reuse-campaign local join subset width=512 candidate" (
  it : @bench.T,
) {
  local_join_bench(it, 512, true, false)
}

///|
test "bench reuse-campaign local join width=32 reference" (it : @bench.T) {
  local_join_bench(it, 32, false, true)
}

///|
test "bench reuse-campaign local join width=32 candidate" (it : @bench.T) {
  local_join_bench(it, 32, false, false)
}

///|
test "bench reuse-campaign local join subset width=32 reference" (it : @bench.T) {
  local_join_bench(it, 32, true, true)
}

///|
test "bench reuse-campaign local join subset width=32 candidate" (it : @bench.T) {
  local_join_bench(it, 32, true, false)
}

///|
test "bench reuse-campaign local join width=128 reference" (it : @bench.T) {
  local_join_bench(it, 128, false, true)
}

///|
test "bench reuse-campaign local join width=128 candidate" (it : @bench.T) {
  local_join_bench(it, 128, false, false)
}

///|
test "bench reuse-campaign local join subset width=128 reference" (
  it : @bench.T,
) {
  local_join_bench(it, 128, true, true)
}

///|
test "bench reuse-campaign local join subset width=128 candidate" (
  it : @bench.T,
) {
  local_join_bench(it, 128, true, false)
}

///|
test "bench reuse-campaign local join width=256 reference" (it : @bench.T) {
  local_join_bench(it, 256, false, true)
}

///|
test "bench reuse-campaign local join width=256 candidate" (it : @bench.T) {
  local_join_bench(it, 256, false, false)
}

///|
test "bench reuse-campaign local join subset width=256 reference" (
  it : @bench.T,
) {
  local_join_bench(it, 256, true, true)
}

///|
test "bench reuse-campaign local join subset width=256 candidate" (
  it : @bench.T,
) {
  local_join_bench(it, 256, true, false)
}

///|
fn local_join_asymmetric_bench(
  it : @bench.T,
  reverse : Bool,
  reference : Bool,
) -> Unit {
  let lhs = Array::makei(4096, fn(index) { index })
  let rhs = Array::makei(256, fn(index) {
    if reverse {
      255 - index
    } else {
      1024 + index
    }
  })
  if local_graph_join_sources(lhs, rhs) != lhs {
    abort("subset changed")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        local_join_reference(lhs, rhs)
      } else {
        local_graph_join_sources(lhs, rhs)
      },
    )
  })
}

///|
test "bench reuse-campaign local join asymmetric contiguous reference" (
  it : @bench.T,
) {
  local_join_asymmetric_bench(it, false, true)
}

///|
test "bench reuse-campaign local join asymmetric contiguous candidate" (
  it : @bench.T,
) {
  local_join_asymmetric_bench(it, false, false)
}

///|
test "bench reuse-campaign local join asymmetric reverse reference" (
  it : @bench.T,
) {
  local_join_asymmetric_bench(it, true, true)
}

///|
test "bench reuse-campaign local join asymmetric reverse candidate" (
  it : @bench.T,
) {
  local_join_asymmetric_bench(it, true, false)
}
