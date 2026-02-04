// ============================================================================
// dataflow/node.mbt - DataFlow Node
// ============================================================================

///|
/// Unique identifier for nodes
pub struct NodeId(Int) derive(Eq, Hash, Show, Compare)

///|
/// Node type in the DataFlow IR
pub enum NodeType {
  /// An unknown variable value
  Var
  /// A value represented by a Binaryen Expression
  Expr
  /// A phi from converging control flow
  Phi
  /// A blockpc, representing one of the branches for a Block
  Cond
  /// A source of phis
  Block
  /// Zero-extend an i1
  Zext
  /// Something we can't handle and should ignore
  Bad
  // defines memory state
  MemoryDef
  // merges memory states
  MemoryPhi
} derive(Eq, Show)

///|
/// Core Node representation in DataFlow IR
pub struct Node {
  mut id : NodeId
  node_type : NodeType
  /// For Var: the wasm type; For Expr: stored separately
  mut wasm_type : WasmType
  /// For Expr: the expression
  expr : Expression?
  /// For Phi and Cond: local index for phi, block index for cond
  mut index : Int
  /// The wasm expression that we originate from
  mut origin : ExprId?
  /// Related nodes (children/inputs)
  /// For Expr: inputs to the expression
  /// For Phi: block and then list of values
  /// For Cond: block and node
  /// For Block: list of Conds
  /// For Zext: the value we extend
  values : Array[NodeId]
} derive(Show)

///|
pub fn Node::new(id : NodeId, node_type : NodeType) -> Node {
  {
    id,
    node_type,
    wasm_type: Unreachable,
    expr: None,
    index: 0,
    origin: None,
    values: [],
  }
}

///|
pub fn NodeId::new(id : Int) -> NodeId {
  NodeId(id)
}

///|
pub fn Node::make_var(id : NodeId, wasm_type : WasmType) -> Node {
  { ..Node::new(id, Var), wasm_type, }
}

///|
pub fn Node::make_expr(
  id : NodeId,
  expr : Expression,
  origin : ExprId?,
) -> Node {
  { ..Node::new(id, Expr), expr: Some(expr), origin }
}

///|
pub fn Node::make_phi(id : NodeId, block : NodeId, index : Int) -> Node {
  let node = Node::new(id, Phi)
  node.index = index
  node.values.push(block)
  node
}

///|
pub fn Node::make_cond(
  id : NodeId,
  block : NodeId,
  index : Int,
  condition : NodeId,
) -> Node {
  let node = Node::new(id, Cond)
  node.index = index
  node.values.push(block)
  node.values.push(condition)
  node
}

///|
pub fn Node::make_block(id : NodeId) -> Node {
  Node::new(id, Block)
}

///|
pub fn Node::make_zext(id : NodeId, child : NodeId, origin : ExprId?) -> Node {
  let node = Node::new(id, Zext)
  node.origin = origin
  node.values.push(child)
  node
}

///|
pub fn Node::make_memory_def(id : NodeId, clobbers : NodeId?) -> Self {
  let node = Node::new(id, MemoryDef)
  match clobbers {
    Some(c) => node.values.push(c)
    None => ()
  }
  node
}

///|
pub fn Node::make_memory_phi(id : NodeId, incoming : Array[NodeId]) -> Self {
  let node = Node::new(id, MemoryPhi)
  for inc in incoming {
    node.values.push(inc)
  }
  node
}

///|
pub fn Node::make_bad(id : NodeId) -> Node {
  Node::new(id, Bad)
}

///|
pub fn Node::is_var(self : Node) -> Bool {
  self.node_type == Var
}

///|
pub fn Node::is_expr(self : Node) -> Bool {
  self.node_type == Expr
}

///|
pub fn Node::is_phi(self : Node) -> Bool {
  self.node_type == Phi
}

///|
pub fn Node::is_cond(self : Node) -> Bool {
  self.node_type == Cond
}

///|
pub fn Node::is_block(self : Node) -> Bool {
  self.node_type == Block
}

///|
pub fn Node::is_zext(self : Node) -> Bool {
  self.node_type == Zext
}

///|
pub fn Node::is_bad(self : Node) -> Bool {
  self.node_type == Bad
}

///|
pub fn Node::is_memory_def(self : Node) -> Bool {
  self.node_type == MemoryDef
}

///|
pub fn Node::is_memory_phi(self : Node) -> Bool {
  self.node_type == MemoryPhi
}

///|
pub fn Node::is_const(self : Node) -> Bool {
  match self.expr {
    Some(Const(_)) => true
    _ => false
  }
}

///|
pub fn Node::add_value(self : Node, value : NodeId) -> Unit {
  self.values.push(value)
}

///|
pub fn Node::get_value(self : Node, i : Int) -> NodeId? {
  if i >= 0 && i < self.values.length() {
    Some(self.values[i])
  } else {
    None
  }
}

///|
/// Check if this node returns an i1 (boolean result from comparison)
pub fn Node::returns_i1(self : Node) -> Bool {
  match self.expr {
    Some(Binary(b)) => b.op.is_relational()
    Some(Unary(u)) => u.op.is_relational()
    _ => false
  }
}

///|
/// Check if this node is a root (must be preserved regardless of uses)
pub fn Node::is_root(self : Node) -> Bool {
  match self.node_type {
    // Block nodes are structural roots
    Block => true
    // Bad nodes should be preserved (we can't analyze them)
    Bad => true
    Expr =>
      match self.expr {
        // Return statements are roots
        Some(Return(_)) => true
        // Unreachable is a root (control flow terminator)
        Some(Unreachable) => true
        _ => false
      }
    _ => false
  }
}

///|
/// Check if this node has side effects (must be preserved even if unused)
pub fn Node::has_side_effects(self : Node) -> Bool {
  match self.node_type {
    Bad => true
    Expr =>
      match self.expr {
        Some(Store(_)) => true
        Some(Call(_)) => true // Assume calls have side effects
        Some(MemoryGrow(_)) => true
        Some(LocalSet(_)) => true
        Some(Drop(_)) => false // Drop itself has no side effect
        Some(Return(_)) => true // Control flow effect
        Some(Break(_)) => true // Control flow effect
        Some(Unreachable) => true // Control flow effect
        _ => false
      }
    _ => false
  }
}
