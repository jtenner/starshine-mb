// ============================================================================
// dataflow/graph.mbt - Main DataFlow Graph
// ============================================================================

///|
/// Local state: mapping from local index to the node containing its value
pub type Locals = Array[NodeId]

///|
/// Flow state includes locals and an optional condition
pub struct FlowState {
  locals : Locals
  condition : NodeId
}

///|
pub fn FlowState::new(locals : Locals, condition : NodeId) -> FlowState {
  { locals, condition }
}

///|
/// The main DataFlow Graph
pub struct Graph {
  /// Node storage
  node_store : NodeStore
  /// Maps a LocalSet expression to its data node
  set_node_map : Map[ExprId, NodeId]
  /// Maps control-flow expression to conditions for its arms
  expression_condition_map : Map[ExprId, Array[NodeId]]
  /// Maps each expression to its control-flow parent
  expression_parent_map : Map[ExprId, ExprId]
  /// Maps nodes to their parent expression
  node_parent_map : Map[NodeId, ExprId]
  /// All the sets, in order of appearance
  sets : Array[ExprId]
  /// Constant nodes cache
  constant_nodes : Map[Literal, NodeId]
  /// Break states for each label
  break_states : Map[String, Array[Locals]]
  /// Current local state
  mut locals : Locals
  /// Current parent expression
  mut parent : ExprId?
  /// The function being processed
  mut func : Function?
  /// The module being processed
  mut mod : Module?
}

///|
pub fn Graph::new() -> Graph {
  {
    node_store: NodeStore::new(),
    set_node_map: {},
    expression_condition_map: {},
    expression_parent_map: {},
    node_parent_map: {},
    sets: [],
    constant_nodes: {},
    break_states: {},
    locals: [],
    parent: None,
    func: None,
    mod: None,
  }
}

///|
/// Check if we're in unreachable code
pub fn Graph::is_in_unreachable(self : Graph) -> Bool {
  self.locals.length() == 0
}

///|
pub fn Graph::is_locals_unreachable(_ : Graph, state : Locals) -> Bool {
  state.length() == 0
}

///|
pub fn Graph::is_flow_state_unreachable(_ : Graph, state : FlowState) -> Bool {
  state.locals.length() == 0
}

///|
/// Set state to unreachable
pub fn Graph::set_in_unreachable(self : Graph) -> Unit {
  self.locals.clear()
}

///|
/// Set state to reachable with proper size
pub fn Graph::set_in_reachable(self : Graph) -> Unit {
  match self.func {
    Some(f) => {
      let num_locals = f.get_num_locals()
      self.locals = Array::make(num_locals, self.node_store.bad())
    }
    None => ()
  }
}

///|
/// Check if a type is relevant for dataflow analysis
pub fn Graph::is_relevant_type(_ : Graph, wasm_type : WasmType) -> Bool {
  wasm_type.is_integer()
}

///|
/// Check if a local is relevant
pub fn Graph::is_relevant_local(self : Graph, index : Int) -> Bool {
  match self.func {
    Some(f) => self.is_relevant_type(f.get_local_type(index))
    None => false
  }
}

///|
/// Get the bad node
pub fn Graph::bad(self : Graph) -> NodeId {
  self.node_store.bad()
}

///|
/// Add a node to the graph
pub fn Graph::add_node(self : Graph, node : Node) -> NodeId {
  self.node_store.add_node(node)
}

///|
/// Make a Var node representing an unknown value
pub fn Graph::make_var(self : Graph, wasm_type : WasmType) -> NodeId {
  if self.is_relevant_type(wasm_type) {
    let id = NodeId(self.node_store.len())
    self.add_node(Node::make_var(id, wasm_type))
  } else {
    self.bad()
  }
}

///|
/// Make a constant node
pub fn Graph::make_const(self : Graph, value : Literal) -> NodeId {
  match self.constant_nodes.get(value) {
    Some(id) => id
    None => {
      let id = NodeId(self.node_store.len())
      let expr = Const({ value, })
      let node = Node::make_expr(id, expr, None)
      let node_id = self.add_node(node)
      self.constant_nodes[value] = node_id
      node_id
    }
  }
}

///|
/// Make a zero constant
pub fn Graph::make_zero(self : Graph, wasm_type : WasmType) -> NodeId {
  self.make_const(Literal::make_zero(wasm_type))
}

///|
/// Create a zero comparison node
pub fn Graph::make_zero_comp(
  self : Graph,
  node : NodeId,
  equal : Bool,
  origin : ExprId?,
) -> NodeId {
  if self.node_store.is_bad(node) {
    return self.bad()
  }
  let wasm_type = self.node_store.get_wasm_type(node)
  if not(wasm_type.is_concrete()) {
    return self.bad()
  }
  let zero = self.make_zero(wasm_type)
  let op : BinaryOp = match (wasm_type, equal) {
    (I32, true) => EqInt32
    (I64, true) => EqInt64
    (I32, false) => NeInt32
    (I64, false) => NeInt64
    _ => return self.bad()
  }
  let check_id = NodeId(self.node_store.len())
  let expanded = self.expand_from_i1(node, origin)
  let expr = Binary({ op, left: ExprId(0), right: ExprId(0), result_type: I32 })
  let check_node = Node::make_expr(check_id, expr, origin)
  check_node.add_value(expanded)
  check_node.add_value(zero)
  self.add_node(check_node)
}

///|
/// Expand an i1 result to full width if needed
pub fn Graph::expand_from_i1(
  self : Graph,
  node : NodeId,
  origin : ExprId?,
) -> NodeId {
  if self.node_store.is_bad(node) {
    return node
  }
  match self.node_store.get(node) {
    Some(n) =>
      if n.returns_i1() {
        let zext_id = NodeId(self.node_store.len())
        self.add_node(Node::make_zext(zext_id, node, origin))
      } else {
        node
      }
    None => node
  }
}

///|
/// Ensure a node returns i1
pub fn Graph::ensure_i1(
  self : Graph,
  node : NodeId,
  origin : ExprId?,
) -> NodeId {
  if self.node_store.is_bad(node) {
    return node
  }
  match self.node_store.get(node) {
    Some(n) =>
      if n.returns_i1() {
        node
      } else {
        self.make_zero_comp(node, false, origin)
      }
    None => node
  }
}
