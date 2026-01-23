// ============================================================================
// dataflow/tests.mbt - Unit tests
// ============================================================================

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
    None => fail!("Node not found")
  }
}

test "constant deduplication" {
  let graph = Graph::new()
  let c1 = graph.make_const(LitI32(42))
  let c2 = graph.make_const(LitI32(42))
  let c3 = graph.make_const(LitI32(100))
  assert_eq(c1, c2)
  assert_not_eq(c1, c3)
}

test "zero creation" {
  let graph = Graph::new()
  let z32 = graph.make_zero(I32)
  let z64 = graph.make_zero(I64)
  assert_eq(graph.node_store.get_wasm_type(z32), I32)
  assert_eq(graph.node_store.get_wasm_type(z64), I64)
}

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
    None => fail!("Phi not found")
  }
}

test "wasm type relevance" {
  let graph = Graph::new()
  assert_true(graph.is_relevant_type(I32))
  assert_true(graph.is_relevant_type(I64))
  assert_false(graph.is_relevant_type(F32))
  assert_false(graph.is_relevant_type(F64))
  assert_false(graph.is_relevant_type(Unreachable))
}

test "binary op classification" {
  assert_true(EqInt32.is_relational())
  assert_true(LtSInt64.is_relational())
  assert_false(AddInt32.is_relational())
  assert_false(MulInt64.is_relational())
}

test "binary op flip" {
  assert_eq(GtSInt32.get_opposite(), Some(LtSInt32))
  assert_eq(GeUInt64.get_opposite(), Some(LeUInt64))
  assert_eq(AddInt32.get_opposite(), None)
}