///|
pub enum MemoryNodeType {
  MemoryDef // Store, call, memory.grow - defines new memory state
  MemoryUse // Load - uses memory state
  MemoryPhi // Merge point for memory states
}

///|
pub fn MemoryNodeType::memory_def() -> MemoryNodeType {
  MemoryDef
}

///|
pub fn MemoryNodeType::memory_use() -> MemoryNodeType {
  MemoryUse
}

///|
pub fn MemoryNodeType::memory_phi() -> MemoryNodeType {
  MemoryPhi
}

///|
pub struct MemoryState {
  current : NodeId // Current memory version node
}

///|
pub fn MemoryState::new(current : NodeId) -> MemoryState {
  MemoryState::{ current, }
}

///|
pub struct MemoryNode {
  id : NodeId
  node_type : MemoryNodeType
  defining_access : NodeId? // Which memory state this uses/clobbers
  expr_id : ExprId? // The original expression (load/store/call)
}

///|
pub fn MemoryNode::new(
  id : NodeId,
  node_type : MemoryNodeType,
  defining_access : NodeId?,
  expr_id : ExprId?,
) -> MemoryNode {
  { id, node_type, defining_access, expr_id }
}

///|
struct MemorySSA {
  // Maps each memory-accessing node to its MemoryNode
  memory_nodes : Map[NodeId, MemoryNode]
  // The entry memory state (represents initial memory)
  entry_state : NodeId
  // Current memory state during graph building
  mut current_state : NodeId
  // Memory phi nodes at block merges
  memory_phis : Map[ExprId, NodeId]
}

///|
pub fn MemorySSA::new(graph : Graph) -> Self {
  // Create the entry memory state (LiveOnEntry)
  let entry = graph.add_node(Node::make_memory_def(NodeId::new(0), None))
  {
    memory_nodes: Map::new(),
    entry_state: entry,
    current_state: entry,
    memory_phis: Map::new(),
  }
}

///|
pub fn MemorySSA::record_store(
  self : Self,
  _graph : Graph,
  store_node : NodeId,
  expr_id : ExprId,
) -> Unit {
  // Store creates a new memory version that clobbers the previous one
  let mem_node = MemoryNode::{
    id: store_node,
    node_type: MemoryDef,
    defining_access: Some(self.current_state),
    expr_id: Some(expr_id),
  }
  self.memory_nodes.set(store_node, mem_node)
  self.current_state = store_node
}

///|
pub fn MemorySSA::record_load(
  self : Self,
  _graph : Graph,
  load_node : NodeId,
  expr_id : ExprId,
) -> Unit {
  // Load uses the current memory state
  let mem_node = MemoryNode::{
    id: load_node,
    node_type: MemoryUse,
    defining_access: Some(self.current_state),
    expr_id: Some(expr_id),
  }
  self.memory_nodes.set(load_node, mem_node)
  // Loads don't change memory state
}

///|
pub fn MemorySSA::record_call(
  self : Self,
  _graph : Graph,
  call_node : NodeId,
  expr_id : ExprId,
) -> Unit {
  // Calls conservatively clobber all memory
  let mem_node = MemoryNode::{
    id: call_node,
    node_type: MemoryDef,
    defining_access: Some(self.current_state),
    expr_id: Some(expr_id),
  }
  self.memory_nodes.set(call_node, mem_node)
  self.current_state = call_node
}

///|
pub fn MemorySSA::record_memory_grow(
  self : Self,
  _graph : Graph,
  grow_node : NodeId,
  expr_id : ExprId,
) -> Unit {
  // memory.grow modifies memory state
  let mem_node = MemoryNode::{
    id: grow_node,
    node_type: MemoryDef,
    defining_access: Some(self.current_state),
    expr_id: Some(expr_id),
  }
  self.memory_nodes.set(grow_node, mem_node)
  self.current_state = grow_node
}

///|
pub fn MemorySSA::merge_states(
  self : Self,
  graph : Graph,
  incoming_states : Array[NodeId],
  block_id : ExprId,
) -> Unit {
  if incoming_states.length() == 0 {
    return
  }
  if incoming_states.length() == 1 {
    self.current_state = incoming_states[0]
    return
  }
  // Check if all incoming states are the same
  let first = incoming_states[0]
  let all_same = incoming_states.iter().all(fn(s) { s == first })
  if all_same {
    self.current_state = first
    return
  }
  // Create a memory phi node
  let phi_node = graph.add_node(
    Node::make_memory_phi(NodeId::new(0), incoming_states),
  )
  self.memory_phis.set(block_id, phi_node)
  self.current_state = phi_node
}

///|
pub fn MemorySSA::get_defining_access(self : Self, node_id : NodeId) -> NodeId? {
  match self.memory_nodes.get(node_id) {
    Some(mem_node) => mem_node.defining_access
    None => None
  }
}

///|
pub fn MemorySSA::get_current_state(self : Self) -> NodeId {
  self.current_state
}

///|
pub fn MemorySSA::set_current_state(self : Self, state : NodeId) -> Unit {
  self.current_state = state
}
