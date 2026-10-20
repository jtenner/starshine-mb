///|
fn inl_private_cycle_marks_reference(
  imports : Int32,
  graph : Array[Array[Int32]],
  reachability : InlGraphReachability,
  used : Array[Bool],
  reachable_from_root : Array[Bool],
  signatures : Array[String],
) -> (Array[Bool], Array[Int32]) {
  let total = graph.length()
  let mut idx = 0
  let mark = Array::make(total, false)
  let public_scc_representative = Array::make(total, -1)
  idx = imports
  while idx < total {
    if reachable_from_root[idx] &&
      inl_reachability_reaches(reachability, idx, idx) {
      let mut reaches_root = false
      let mut root = 0
      while root < total {
        if used[root] && inl_reachability_reaches(reachability, idx, root) {
          reaches_root = true
          break
        }
        root += 1
      }
      let scc_members = inl_reachability_scc_members(reachability, idx)
      let scc_size = scc_members.length()
      if idx < used.length() && !used[idx] {
        let mut representative = -1
        for other in scc_members {
          if other >= imports && other < used.length() && !used[other] {
            representative = other
            break
          }
        }
        public_scc_representative[idx] = representative
      }
      let mut has_self_loop = false
      for other in scc_members {
        if other >= imports && !(other < used.length() && used[other]) {
          for next in graph[other] {
            if next == other {
              has_self_loop = true
              break
            }
          }
        }
        if has_self_loop {
          break
        }
      }
      let mut root_edges_to_scc = 0
      root = 0
      while root < total {
        if used[root] {
          for next in graph[root] {
            if next != root &&
              next >= 0 &&
              next < total &&
              inl_reachability_same_scc(reachability, idx, next) {
              root_edges_to_scc += 1
            }
          }
        }
        root += 1
      }
      let sig = signatures[idx]
      let mut scc_same_signature = true
      let scc_signatures : @set.Set[String] = @set.Set([])
      for other in scc_members {
        if other >= imports {
          scc_signatures.add(signatures[other])
        }
        if other >= imports && signatures[other] != sig {
          scc_same_signature = false
        }
      }
      let mut has_orphan_self_loop_same_signature = false
      let mut has_orphan_self_loop_scc_signature = false
      let mut other = imports
      while other < total {
        if !inl_reachability_same_scc(reachability, idx, other) &&
          !(other < used.length() && used[other]) &&
          !reachable_from_root[other] {
          let other_sig = signatures[other]
          let matches_scc_signature = scc_signatures.contains(other_sig)
          for next in graph[other] {
            if next == other {
              if other_sig == sig {
                has_orphan_self_loop_same_signature = true
              }
              if matches_scc_signature {
                has_orphan_self_loop_scc_signature = true
              }
              break
            }
          }
        }
        if has_orphan_self_loop_same_signature &&
          has_orphan_self_loop_scc_signature {
          break
        }
        other += 1
      }
      let base_mark = (!reaches_root && scc_size <= 2 && root_edges_to_scc > 0) ||
        (scc_size == 3 && (has_self_loop || root_edges_to_scc > 1))
      mark[idx] = base_mark &&
        !(scc_same_signature && !has_orphan_self_loop_same_signature) &&
        !(reaches_root &&
        scc_size == 3 &&
        root_edges_to_scc > 1 &&
        !has_orphan_self_loop_same_signature) &&
        !(!reaches_root && scc_size <= 3 && !has_orphan_self_loop_scc_signature)
    }
    idx += 1
  }
  (mark, public_scc_representative)
}

///|
test "inlining cycle summaries preserve per-function cycle and retention decisions" {
  // Bounded exhaustive graph families include disconnected roots, root-free
  // cycles, downstream roots, orphan self-loops, imports, and mixed signatures.
  for pattern in 0..<32 {
    let count = 8
    let graph : Array[Array[Int32]] = Array::makei(count, fn(node) {
      let edges : Array[Int32] = []
      for target in 0..<count {
        if (node * 17 + target * 11 + pattern * 7) % 13 < 2 {
          edges.push(target)
        }
      }
      edges
    })
    graph[0] = []
    let roots = Array::makei(count, fn(i) { (i + pattern) % 3 == 0 })
    let signatures = Array::makei(count, fn(i) {
      "signature:\{(i + pattern) % 3}"
    })
    let reachability = inl_build_graph_reachability(graph)
    let reachable = inl_graph_reachable_from_roots(graph, roots)
    assert_eq(
      inl_private_cycle_marks(
        1, graph, reachability, roots, reachable, signatures,
      ),
      inl_private_cycle_marks_reference(
        1, graph, reachability, roots, reachable, signatures,
      ),
    )
  }
}

///|
fn inl_cycle_marks_review_bench(
  it : @bench.T,
  count : Int32,
  reference : Bool,
) -> Unit {
  let graph : Array[Array[Int32]] = Array::makei(count, fn(i) {
    [if i % 2 == 0 { i + 1 } else { i - 1 }]
  })
  let roots = Array::makei(count, fn(i) { i % 2 == 0 })
  let signatures = Array::makei(count, fn(i) { "signature:\{i % 3}" })
  let reachability = inl_build_graph_reachability(graph)
  let reachable = inl_graph_reachable_from_roots(graph, roots)
  if inl_private_cycle_marks(
      0, graph, reachability, roots, reachable, signatures,
    ) !=
    inl_private_cycle_marks_reference(
      0, graph, reachability, roots, reachable, signatures,
    ) {
    abort("private cycle decisions changed")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        inl_private_cycle_marks_reference(
          0, graph, reachability, roots, reachable, signatures,
        )
      } else {
        inl_private_cycle_marks(
          0, graph, reachability, roots, reachable, signatures,
        )
      },
    )
  })
}

///|
test "bench inlining private cycle repeated 16" (it : @bench.T) {
  inl_cycle_marks_review_bench(it, 16, true)
}

///|
test "bench inlining private cycle summarized 16" (it : @bench.T) {
  inl_cycle_marks_review_bench(it, 16, false)
}

///|
test "bench inlining private cycle repeated 1024" (it : @bench.T) {
  inl_cycle_marks_review_bench(it, 1024, true)
}

///|
test "bench inlining private cycle summarized 1024" (it : @bench.T) {
  inl_cycle_marks_review_bench(it, 1024, false)
}
