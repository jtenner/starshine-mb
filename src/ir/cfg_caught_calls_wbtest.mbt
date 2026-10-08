///|
test "expanded CFG splits caught calls between argument writes and result writes" {
  for
    call in [
      "(call 0 (local.tee 0 (i32.const 77)))", "(call_indirect (type 0) (local.tee 0 (i32.const 77)) (i32.const 0))",
      "(call_ref 0 (local.tee 0 (i32.const 77)) (ref.func 0))",
    ] {
    let module_ = @wast.wast_to_binary_module(
      "(module (type (func (param i32) (result i32))) (table 1 funcref) (elem declare func 0) (func (type 0) local.get 0) (func (result i32) (local i32) (block $h (try_table (catch_all $h) i32.const 55 local.set 0 (local.set 0 " +
      call +
      "))) local.get 0))",
    ).unwrap()
    @validate.validate_module(module_).unwrap()
    let func = hot_lift_func(module_, @lib.FuncIdx::new(1U))
    let mut call_id = -1
    let mut argument_write = -1
    let mut result_write = -1
    for id in 0..<hot_node_count(func) {
      match hot_node_get(func, id).op {
        HotOp::Call | HotOp::CallIndirect | HotOp::CallRef => call_id = id
        HotOp::LocalTee => argument_write = id
        _ => ()
      }
    }
    for id in 0..<hot_node_count(func) {
      if hot_query_op(func, id) is HotOp::LocalSet &&
        hot_child_get(func, id, 0) == call_id {
        result_write = id
      }
    }
    assert_true(call_id >= 0 && argument_write >= 0 && result_write >= 0)
    let cfg = cfg_build(
      func,
      conservative_exception_entries=false,
      expand_operand_control=true,
    )
    let call_block = cfg_block_for_node(cfg, call_id).unwrap()
    let result_block = cfg_block_for_node(cfg, result_write).unwrap()
    assert_true(call_block != result_block)
    assert_eq(cfg_block_for_node(cfg, argument_write), Some(call_block))
    let successors = cfg_successors(cfg, call_block)
    assert_true(
      successors.any(fn(edge) {
        edge.kind is CfgEdgeKind::FallthroughEdge && edge.block == result_block
      }),
    )
    assert_eq(
      successors
      .filter(fn(edge) { edge.kind is CfgEdgeKind::ExceptionalEdge })
      .length(),
      1,
    )
    let graph = local_graph_build_full_flow(func, cfg)
    let read = hot_root_get(func, hot_root_count(func) - 1)
    assert_true(local_graph_get_is_merge(graph, read))
    let sources = local_graph_reaching_sources_for_get(graph, read)
    assert_true(
      sources.contains(HotLocalGraphSource::SetSource(argument_write)),
    )
    assert_true(sources.contains(HotLocalGraphSource::SetSource(result_write)))
  }
}
