///|
fn cfg_legacy_regression_find_op(func : HotFunc, op : HotOp) -> NodeId {
  for node in 0..<hot_node_count(func) {
    if hot_node_is_live(func, node) && hot_node_get(func, node).op == op {
      return node
    }
  }
  abort("expected HOT opcode")
}

///|
fn cfg_legacy_regression_has_exceptional_edge(
  cfg : HotCfg,
  from : BlockId,
  to : BlockId,
) -> Bool {
  cfg_successors(cfg, from).any(fn(edge) {
    edge.block == to && edge.kind is CfgEdgeKind::ExceptionalEdge
  })
}

///|
test "cfg propagates a nonmatching legacy catch to the exceptional exit" {
  let module_ = @wast.wast_to_binary_module(
    "(module (tag $a) (tag $b) (func (try (do (throw $a)) (catch $b nop))))",
  ).unwrap()
  let func = hot_lift_func(module_, @lib.FuncIdx::new(0U))
  let try_id = hot_root_get(func, 0)
  let throw_id = cfg_legacy_regression_find_op(func, HotOp::Throw)
  let catch_ref = hot_region_catch_ref(func, try_id).unwrap()
  let cfg = cfg_build(func, conservative_exception_entries=false)
  let throw_block = cfg_block_for_node(cfg, throw_id).unwrap()
  let catch_block = cfg_block_for_region_root(cfg, catch_ref, 0).unwrap()
  let exceptional_exit = match cfg_exceptional_exit_block(cfg) {
    Some(block) => block
    None => fail("a nonmatching catch must preserve outward exception flow")
  }

  assert_true(
    cfg_legacy_regression_has_exceptional_edge(
      cfg, throw_block, exceptional_exit,
    ),
  )
  assert_false(
    cfg_legacy_regression_has_exceptional_edge(cfg, throw_block, catch_block),
  )
}

///|
test "cfg routes a legacy delegate to the enclosing catch" {
  let module_ = @wast.wast_to_binary_module(
    (
      #|(module
      #|  (tag $e)
      #|  (func
      #|    (try
      #|      (do
      #|        (try
      #|          (do (throw $e))
      #|          (delegate 0)))
      #|      (catch $e nop))
      #|    nop))
    ),
  ).unwrap()
  let func = hot_lift_func(module_, @lib.FuncIdx::new(0U))
  let outer_try = hot_root_get(func, 0)
  let delegate = cfg_legacy_regression_find_op(func, HotOp::Delegate)
  let after = hot_root_get(func, 1)
  let catch_ref = hot_region_catch_ref(func, outer_try).unwrap()
  let cfg = cfg_build(func, conservative_exception_entries=false)
  let delegate_block = cfg_block_for_node(cfg, delegate).unwrap()
  let catch_block = cfg_block_for_region_root(cfg, catch_ref, 0).unwrap()
  let after_block = cfg_block_for_node(cfg, after).unwrap()

  assert_true(
    cfg_legacy_regression_has_exceptional_edge(cfg, delegate_block, catch_block),
  )
  assert_false(
    cfg_legacy_regression_has_exceptional_edge(cfg, delegate_block, after_block),
  )
}
