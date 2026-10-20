///|
fn inl_root_reachability_reference(
  reachability : InlGraphReachability,
  roots : Array[Bool],
) -> Array[Bool] {
  let total = reachability.graph.length()
  let reachable = Array::make(total, false)
  for source in 0..<total {
    if source < roots.length() && roots[source] {
      reachable[source] = true
      for target in 0..<total {
        if inl_reachability_reaches(reachability, source, target) {
          reachable[target] = true
        }
      }
    }
  }
  reachable
}

///|
test "inlining root closure preserves imports cycles duplicate and invalid edges" {
  let graph : Array[Array[Int32]] = [[1, 1, -1], [2], [1], [4], [], [99]]
  for
    roots in [
      [],
      [true],
      [false, true],
      [false, false, false, true, false, true],
      Array::make(7, true),
    ] {
    assert_eq(
      inl_graph_reachable_from_roots(graph, roots),
      inl_root_reachability_reference(
        inl_build_graph_reachability(graph),
        roots,
      ),
    )
  }
  assert_eq(inl_graph_reachable_from_roots(graph, [true]), [
    true, true, true, false, false, false,
  ])
}

///|
fn inl_root_reachability_review_bench(
  it : @bench.T,
  count : Int32,
  chain : Bool,
  reference : Bool,
) -> Unit {
  let graph : Array[Array[Int32]] = Array::makei(count, fn(idx) {
    if chain && idx + 1 < count {
      [idx + 1]
    } else {
      []
    }
  })
  let roots = Array::make(count, true)
  let reachability = inl_build_graph_reachability(graph)
  if inl_graph_reachable_from_roots(graph, roots) !=
    inl_root_reachability_reference(reachability, roots) {
    abort("root closure changed")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        inl_root_reachability_reference(reachability, roots)
      } else {
        inl_graph_reachable_from_roots(graph, roots)
      },
    )
  })
}

///|
test "bench inlining root closure repeated 16" (it : @bench.T) {
  inl_root_reachability_review_bench(it, 16, true, true)
}

///|
test "bench inlining root closure shared 16" (it : @bench.T) {
  inl_root_reachability_review_bench(it, 16, true, false)
}

///|
test "bench inlining root closure repeated 1024" (it : @bench.T) {
  inl_root_reachability_review_bench(it, 1024, true, true)
}

///|
test "bench inlining root closure shared 1024" (it : @bench.T) {
  inl_root_reachability_review_bench(it, 1024, true, false)
}
