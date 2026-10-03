///|
test "CFG edge storage keeps every kind and held value through growth" {
  // Storage-only records: these block ids do not claim a connected valid CFG.
  let kinds = [
    CfgEdgeKind::FallthroughEdge,
    CfgEdgeKind::BranchEdge,
    CfgEdgeKind::ReturnEdge,
    CfgEdgeKind::ExceptionalEdge,
    CfgEdgeKind::UnreachableExitEdge,
  ]
  for kind in kinds {
    let edge : CfgEdge = { kind, block: 3, }
    let rows : Array[CfgEdge] = [edge]
    let snapshot = rows.copy()
    for block in 0..<16 {
      rows.push({ kind, block, })
    }
    rows[0] = { kind, block: 7, }
    assert_eq(edge.kind, kind)
    assert_eq(edge.block, 3)
    assert_eq(snapshot[0], edge)
    assert_eq(rows[0].block, 7)
    for block in 0..<16 {
      assert_eq(rows[block + 1].kind, kind)
      assert_eq(rows[block + 1].block, block)
    }
  }
}

///|
test "CFG edge public arrays remain independently writable and reciprocal" {
  let func = HotFunc::new()
  let cfg = cfg_build(func)
  let entry = cfg.entry_block
  let successors = cfg_successors(cfg, entry)
  assert_true(successors.length() > 0)
  let held = successors[0]
  let predecessors = cfg_predecessors(cfg, held.block)
  assert_true(
    predecessors.any(fn(edge) { edge.block == entry && edge.kind == held.kind }),
  )
  successors[0] = { kind: CfgEdgeKind::ExceptionalEdge, block: entry, }
  successors.push(held)
  predecessors.clear()
  assert_eq(cfg_successor_edges(cfg, entry)[0], held)
  assert_true(
    cfg_predecessor_edges(cfg, held.block).any(fn(edge) {
      edge.block == entry && edge.kind == held.kind
    }),
  )
  // The explicit edge-row queries retain their borrowed storage contract.
  let borrowed = cfg_successor_edges(cfg, entry)
  let count = borrowed.length()
  borrowed.push(held)
  assert_eq(cfg_successor_edges(cfg, entry).length(), count + 1)
  assert_eq(borrowed.pop(), Some(held))
  cfg_verify(cfg)
}
