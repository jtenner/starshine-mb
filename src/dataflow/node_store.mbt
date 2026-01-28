// ============================================================================
// dataflow/node_store.mbt - Node storage and management
// ============================================================================

///|
/// Storage for all nodes with ID-based access
pub struct NodeStore {
  mut nodes : Array[Node]
  mut bad_node_id : NodeId
}

///|
pub fn NodeStore::new() -> NodeStore {
  let store : NodeStore = { nodes: [], bad_node_id: NodeId(0) }
  // Create the canonical bad node
  store.bad_node_id = store.add_node_internal(Node::make_bad(NodeId(0)))
  store
}

///|
fn NodeStore::add_node_internal(self : NodeStore, node : Node) -> NodeId {
  let id = NodeId(self.nodes.length())
  let node_with_id = node
  node_with_id.id = id
  self.nodes.push(node_with_id)
  id
}

///|
pub fn NodeStore::add_node(self : NodeStore, node : Node) -> NodeId {
  self.add_node_internal(node)
}

///|
pub fn NodeStore::get(self : NodeStore, id : NodeId) -> Node? {
  let NodeId(idx) = id
  if idx >= 0 && idx < self.nodes.length() {
    Some(self.nodes[idx])
  } else {
    None
  }
}

///|
pub fn NodeStore::get_mut(self : NodeStore, id : NodeId) -> Node? {
  let NodeId(idx) = id
  if idx >= 0 && idx < self.nodes.length() {
    Some(self.nodes[idx])
  } else {
    None
  }
}

///|
pub fn NodeStore::bad(self : NodeStore) -> NodeId {
  self.bad_node_id
}

///|
pub fn NodeStore::is_bad(self : NodeStore, id : NodeId) -> Bool {
  match self.get(id) {
    Some(node) => node.is_bad()
    None => true
  }
}

///|
pub fn NodeStore::len(self : NodeStore) -> Int {
  self.nodes.length()
}

///|
/// Get the wasm type of a node
pub fn NodeStore::get_wasm_type(self : NodeStore, id : NodeId) -> WasmType {
  match self.get(id) {
    Some(node) =>
      match node.node_type {
        Var => node.wasm_type
        Expr =>
          match node.expr {
            Some(expr) => expr.get_type()
            None => Unreachable
          }
        Phi =>
          match node.get_value(1) {
            Some(value_id) => self.get_wasm_type(value_id)
            None => Unreachable
          }
        Zext =>
          match node.get_value(0) {
            Some(value_id) => self.get_wasm_type(value_id)
            None => Unreachable
          }
        Bad => Unreachable
        _ => Unreachable
      }
    None => Unreachable
  }
}

pub fn NodeStore::remove(self : NodeStore, id : NodeId) -> Unit {
  self.nodes = self.nodes.filter(fn(n) { n.id != id })
  
}
