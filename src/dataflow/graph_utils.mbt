// ============================================================================
// dataflow/graph_utils.mbt - Utility functions
// ============================================================================

///|
/// Get the LocalSet for a node
pub fn Graph::get_set_for_node(self : Graph, node : NodeId) -> ExprId? {
  self.node_parent_map.get(node)
}

///|
/// Get the parent expression
pub fn Graph::get_parent(self : Graph, expr : ExprId) -> ExprId? {
  self.expression_parent_map.get(expr)
}

///|
/// Get the set for an expression if it exists
pub fn Graph::get_set_for_expr(self : Graph, expr : ExprId) -> ExprId? {
  match self.get_parent(expr) {
    Some(parent) => {
      let func = match self.func {
        Some(f) => f
        None => return None
      }
      match func.expressions.get(parent) {
        Some(LocalSet(_)) => Some(parent)
        _ => None
      }
    }
    None => None
  }
}

///|
/// Create an expression that uses a node (for code generation)
pub fn Graph::make_use(self : Graph, node_id : NodeId) -> Expression? {
  match self.node_store.get(node_id) {
    Some(node) =>
      match node.node_type {
        Phi =>
          // Get from the phi's associated local
          Some(LocalGet({ index: node.index }))
        Expr =>
          match node.expr {
            Some(Const(c)) => Some(Const(c))
            Some(_) =>
              // Find the set we are a value of
              match self.get_set_for_node(node_id) {
                Some(set_id) => {
                  let func = match self.func {
                    Some(f) => f
                    None => return None
                  }
                  match func.expressions.get(set_id) {
                    Some(LocalSet(s)) => Some(LocalGet({ index: s.index }))
                    _ => None
                  }
                }
                None => None
              }
            None => None
          }
        Zext =>
          // i1 zexts are a no-op for wasm
          match node.get_value(0) {
            Some(child) => self.make_use(child)
            None => None
          }
        Var =>
          // Unknown value - could emit a call to represent it
          Some(
            Call({
              target: "fake$dfo$call",
              operands: [],
              result_type: node.wasm_type,
            }),
          )
        _ => None
      }
    None => None
  }
}

///|
/// Get all sets in the graph
pub fn Graph::get_sets(self : Graph) -> Array[ExprId] {
  self.sets.copy()
}

///|
/// Get the node for a set
pub fn Graph::get_node_for_set(self : Graph, set_id : ExprId) -> NodeId? {
  self.set_node_map.get(set_id)
}

///|
/// Get conditions for an expression
pub fn Graph::get_conditions(self : Graph, expr : ExprId) -> Array[NodeId] {
  match self.expression_condition_map.get(expr) {
    Some(conds) => conds.copy()
    None => []
  }
}

///|
/// Debug: print the graph
pub fn Graph::debug_print(self : Graph) -> String {
  let mut result = "DataFlow Graph:\n"
  result = result + "  Nodes: \{self.node_store.len()}\n"
  result = result + "  Sets: \{self.sets.length()}\n"
  for i = 0; i < self.node_store.len(); i = i + 1 {
    match self.node_store.get(NodeId(i)) {
      Some(node) => {
        let type_str = match node.node_type {
          Var => "Var"
          Expr => "Expr"
          Phi => "Phi"
          Cond => "Cond"
          Block => "Block"
          Zext => "Zext"
          Bad => "Bad"
          MemoryDef => "MemoryDef"
          MemoryPhi => "MemoryPhi"
        }
        result = result + "  [\{i}] \{type_str}"
        if node.values.length() > 0 {
          result = result + " values: "
          for j = 0; j < node.values.length(); j = j + 1 {
            let NodeId(v) = node.values[j]
            result = result + "\{v}"
            if j < node.values.length() - 1 {
              result = result + ", "
            }
          }
        }
        result = result + "\n"
      }
      None => ()
    }
  }
  result
}
