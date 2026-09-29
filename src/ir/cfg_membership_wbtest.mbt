///|
test "CFG membership validation visits flat block nodes once" {
  let func = HotFunc::new()
  for _ in 0..<32 {
    hot_root_append(func, hot_build_nop(func))
  }
  let cfg = cfg_build(func)
  let visits = [0]
  cfg_verify(cfg, node_membership_visits=Some(visits))
  for node = 0; node < hot_node_count(func); node = node + 1 {
    let block = cfg.node_to_block[node]
    assert_true(block >= 0)
    assert_true(cfg.blocks[block].nodes.contains(node))
  }
  assert_true(visits[0] <= hot_node_count(func))
}
