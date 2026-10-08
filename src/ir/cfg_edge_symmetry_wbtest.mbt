///|
test "indexed CFG edge checks preserve duplicate kinds and mixed-degree destinations" {
  let builder = cfg_builder_new(HotFunc::new(), false, false)
  let target = cfg_builder_add_block(builder, [], true)
  let second_target = cfg_builder_add_block(builder, [], true)
  let source = cfg_builder_add_block(builder, [], true)
  for
    kind in [
      CfgEdgeKind::FallthroughEdge,
      CfgEdgeKind::BranchEdge,
      CfgEdgeKind::ReturnEdge,
      CfgEdgeKind::ExceptionalEdge,
      CfgEdgeKind::UnreachableExitEdge,
    ] {
    cfg_builder_add_edge(builder, source, target, kind)
    cfg_builder_add_edge(builder, source, target, kind)
    cfg_builder_add_edge(builder, source, second_target, kind)
    cfg_builder_add_edge(builder, source, second_target, kind)
  }
  let low_source = cfg_builder_add_block(builder, [], true)
  let low_target = cfg_builder_add_block(builder, [], true)
  cfg_builder_add_edge(builder, low_source, low_target, CfgEdgeKind::BranchEdge)
  cfg_builder_add_edge(
    builder,
    low_source,
    target,
    CfgEdgeKind::FallthroughEdge,
  )
  assert_eq(cfg_indexed_edge_symmetry_error(builder.cfg), None)
  cfg_verify(builder.cfg)
  cfg_membership_reference(builder.cfg)
}

///|
test "indexed CFG edge checks reject intentionally invalid stale destination masks" {
  let builder = cfg_builder_new(HotFunc::new(), false, false)
  let first = cfg_builder_add_block(builder, [], true)
  let second = cfg_builder_add_block(builder, [], true)
  let source = cfg_builder_add_block(builder, [], true)
  for _ in 0..<10 {
    cfg_builder_add_edge(builder, source, first, CfgEdgeKind::BranchEdge)
  }
  // This predecessor intentionally has no matching successor to second.
  builder.cfg.blocks[second].preds.push({
    block: source,
    kind: CfgEdgeKind::BranchEdge,
  })
  assert_eq(
    cfg_indexed_edge_symmetry_error(builder.cfg),
    Some("cfg predecessors and successors must stay symmetric"),
  )
}

///|
test "indexed CFG edge checks reject intentionally invalid asymmetric successors" {
  let builder = cfg_builder_new(HotFunc::new(), false, false)
  let target = cfg_builder_add_block(builder, [], true)
  let source = cfg_builder_add_block(builder, [], true)
  cfg_builder_add_edge(builder, source, target, CfgEdgeKind::ExceptionalEdge)
  builder.cfg.blocks[target].preds.clear()
  assert_eq(
    cfg_indexed_edge_symmetry_error(builder.cfg),
    Some("cfg successors and predecessors must stay symmetric"),
  )
}

///|
test "indexed CFG edge checks reject intentionally invalid asymmetric predecessors" {
  let builder = cfg_builder_new(HotFunc::new(), false, false)
  let target = cfg_builder_add_block(builder, [], true)
  let source = cfg_builder_add_block(builder, [], true)
  cfg_builder_add_edge(builder, source, target, CfgEdgeKind::ExceptionalEdge)
  builder.cfg.blocks[source].succs.clear()
  assert_eq(
    cfg_indexed_edge_symmetry_error(builder.cfg),
    Some("cfg predecessors and successors must stay symmetric"),
  )
}
