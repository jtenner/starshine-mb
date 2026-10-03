///|
// Faithful historical storage: an immutable scalar record allocated separately
// from each pointer-array slot. This reference exists only in the perf lane.
priv struct CfgBoxedEdgeReference {
  kind : CfgEdgeKind
  block : BlockId
} derive(Eq)

///|
fn cfg_edge_value_construct_bench(
  it : @bench.T,
  width : Int,
  before : Bool,
) -> Unit {
  let kind = CfgEdgeKind::BranchEdge
  it.bench(fn() {
    if before {
      let successors : Array[CfgBoxedEdgeReference] = []
      let predecessors : Array[CfgBoxedEdgeReference] = []
      for block in 0..<width {
        successors.push({ kind, block, })
        predecessors.push({ kind, block: block + 1, })
      }
      it.keep(successors)
      it.keep(predecessors)
    } else {
      let successors : Array[CfgEdge] = []
      let predecessors : Array[CfgEdge] = []
      for block in 0..<width {
        successors.push({ kind, block, })
        predecessors.push({ kind, block: block + 1, })
      }
      it.keep(successors)
      it.keep(predecessors)
    }
  })
}

///|
fn cfg_edge_value_read_bench(it : @bench.T, before : Bool) -> Unit raise {
  let boxed : Array[CfgBoxedEdgeReference] = []
  let values : Array[CfgEdge] = []
  for block in 0..<512 {
    boxed.push({ kind: CfgEdgeKind::BranchEdge, block, })
    values.push({ kind: CfgEdgeKind::BranchEdge, block, })
  }
  // Identical setup/answers outside timing; both rows stay alive in both lanes.
  for block in 0..<512 {
    assert_eq(boxed[block].kind, values[block].kind)
    assert_eq(boxed[block].block, values[block].block)
  }
  it.bench(fn() {
    let mut total = 0
    if before {
      for edge in boxed {
        total += edge.block
      }
    } else {
      for edge in values {
        total += edge.block
      }
    }
    it.keep(total)
  })
}

///|
test "bench CFG edge construction 0 before" (it : @bench.T) {
  cfg_edge_value_construct_bench(it, 0, true)
}

///|
test "bench CFG edge construction 0 current" (it : @bench.T) {
  cfg_edge_value_construct_bench(it, 0, false)
}

///|
test "bench CFG edge construction 1 before" (it : @bench.T) {
  cfg_edge_value_construct_bench(it, 1, true)
}

///|
test "bench CFG edge construction 1 current" (it : @bench.T) {
  cfg_edge_value_construct_bench(it, 1, false)
}

///|
test "bench CFG edge construction 32 before" (it : @bench.T) {
  cfg_edge_value_construct_bench(it, 32, true)
}

///|
test "bench CFG edge construction 32 current" (it : @bench.T) {
  cfg_edge_value_construct_bench(it, 32, false)
}

///|
test "bench CFG edge construction 512 before" (it : @bench.T) {
  cfg_edge_value_construct_bench(it, 512, true)
}

///|
test "bench CFG edge construction 512 current" (it : @bench.T) {
  cfg_edge_value_construct_bench(it, 512, false)
}

///|
test "bench CFG edge reads512 before" (it : @bench.T) {
  cfg_edge_value_read_bench(it, true)
}

///|
test "bench CFG edge reads512 current" (it : @bench.T) {
  cfg_edge_value_read_bench(it, false)
}
