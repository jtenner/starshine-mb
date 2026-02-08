// ============================================================================
// dataflow/tests.mbt - Unit tests
// ============================================================================

///|
test "basic node creation" {
  let store = NodeStore::new()
  assert_true(store.is_bad(store.bad()))
  let var_id = store.add_node(Node::make_var(NodeId(1), I32))
  assert_false(store.is_bad(var_id))
  match store.get(var_id) {
    Some(node) => {
      assert_true(node.is_var())
      assert_eq(node.wasm_type, I32)
    }
    None => fail("Node not found")
  }
}

///|
test "constant deduplication" {
  let graph = Graph::new()
  let c1 = graph.make_const(LitI32(42))
  let c2 = graph.make_const(LitI32(42))
  let c3 = graph.make_const(LitI32(100))
  assert_eq(c1, c2)
  assert_not_eq(c1, c3)
}

///|
test "zero creation" {
  let graph = Graph::new()
  let z32 = graph.make_zero(I32)
  let z64 = graph.make_zero(I64)
  assert_eq(graph.node_store.get_wasm_type(z32), I32)
  assert_eq(graph.node_store.get_wasm_type(z64), I64)
}

///|
test "phi creation" {
  let store = NodeStore::new()
  let block_id = store.add_node(Node::make_block(NodeId(1)))
  let phi_id = store.add_node(Node::make_phi(NodeId(2), block_id, 0))
  match store.get(phi_id) {
    Some(node) => {
      assert_true(node.is_phi())
      assert_eq(node.index, 0)
      assert_eq(node.values.length(), 1) // Contains block reference
    }
    None => fail("Phi not found")
  }
}

///|
test "wasm type relevance" {
  let graph = Graph::new()
  assert_true(graph.is_relevant_type(I32))
  assert_true(graph.is_relevant_type(I64))
  assert_false(graph.is_relevant_type(F32))
  assert_false(graph.is_relevant_type(F64))
  assert_false(graph.is_relevant_type(Unreachable))
}

///|
test "binary op classification" {
  assert_true(EqInt32.is_relational())
  assert_true(LtSInt64.is_relational())
  assert_false(AddInt32.is_relational())
  assert_false(MulInt64.is_relational())
}

///|
test "binary op flip" {
  assert_eq(GtSInt32.get_opposite(), Some(LtSInt32))
  assert_eq(GeUInt64.get_opposite(), Some(LeUInt64))
  assert_eq(AddInt32.get_opposite(), None)
}

///|
test "Graph.make_use returns synthetic call for Var nodes" {
  let graph = Graph::new()
  let var_node = graph.make_var(I32)
  match graph.make_use(var_node) {
    Some(Call(call)) => {
      assert_eq(call.target, "fake$dfo$call")
      assert_eq(call.operands.length(), 0)
      assert_eq(call.result_type, I32)
    }
    _ => fail("expected synthetic call expression for Var node")
  }
}

///|
test "Graph get_set helpers resolve LocalSet parent chain" {
  let graph = Graph::new()
  let func = Function::new("test")
  let value_expr = func.expressions.add(
    Expression::const_(ConstExpr::new(Literal::i32(1))),
    I32,
  )
  let set_expr = func.expressions.add(
    Expression::local_set(LocalSetExpr::new(3, value_expr, false)),
    WasmType::none(),
  )
  graph.func = Some(func)
  let expr_node_id = graph.add_node(
    Node::make_expr(
      NodeId(graph.node_store.len()),
      Expression::generic(GenericExpr::new([], I32)),
      Some(value_expr),
    ),
  )
  graph.node_parent_map[expr_node_id] = set_expr
  graph.expression_parent_map[value_expr] = set_expr
  assert_eq(graph.get_set_for_expr(value_expr), Some(set_expr))
  assert_eq(graph.get_set_for_node(expr_node_id), Some(set_expr))
  match graph.make_use(expr_node_id) {
    Some(LocalGet(get_expr)) => assert_eq(get_expr.index, 3)
    _ => fail("expected local.get reconstructed from LocalSet parent")
  }
}

///|
test "Graph.make_use collapses zext to child use" {
  let graph = Graph::new()
  let const_id = graph.make_const(Literal::i32(9))
  let zext_id = graph.add_node(
    Node::make_zext(NodeId(graph.node_store.len()), const_id, None),
  )
  match graph.make_use(zext_id) {
    Some(Const(c)) =>
      match c.value {
        LitI32(v) => assert_eq(v, 9)
        _ => fail("expected i32 const from zext child")
      }
    _ => fail("expected zext use to resolve to child const expression")
  }
}
