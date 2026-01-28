
///|
/// Dominator-based GVN for more precise results
/// This version respects control flow and only replaces when the leader dominates
struct DominatorGVN {
  gvn : GVN
  /// Stack of scopes for handling control flow
  scope_stack : Array[Map[GVNKey, NodeId]]
}

///|
pub fn DominatorGVN::new() -> DominatorGVN {
  { gvn: GVN::new(), scope_stack: [Map::new()] }
}

///|
fn DominatorGVN::current_scope(self : DominatorGVN) -> Map[GVNKey, NodeId] {
  self.scope_stack[self.scope_stack.length() - 1]
}

///|
fn DominatorGVN::push_scope(self : DominatorGVN) -> Unit {
  // Create new scope that inherits from current
  self.scope_stack.push(Map::new())
}

///|
fn DominatorGVN::pop_scope(self : DominatorGVN) -> Unit {
  if self.scope_stack.length() > 1 {
    let _ = self.scope_stack.pop()
  }
}

///|
/// Look up a key in all scopes (innermost to outermost)
fn DominatorGVN::lookup(self : DominatorGVN, key : GVNKey) -> NodeId? {
  // Search from innermost to outermost scope
  for i = self.scope_stack.length() - 1; i >= 0; i = i - 1 {
    match self.scope_stack[i].get(key) {
      Some(leader) => return Some(leader)
      None => continue
    }
  }
  None
}

///|
/// Insert a key into the current scope
fn DominatorGVN::insert(self : DominatorGVN, key : GVNKey, leader : NodeId) -> Unit {
  self.current_scope().set(key, leader)
}

///|
/// Process a node with dominator-aware scoping
pub fn DominatorGVN::process_node(
  self : DominatorGVN,
  graph : Graph,
  node : Node,
) -> NodeId? {
  // Ensure operands are processed first
  for v in node.values {
    if not(self.gvn.value_number.contains(v)) {
      match graph.node_store.get(v) {
        Some(operand_node) => {
          let _ = self.process_node(graph, operand_node)
        }
        None => ()
      }
    }
  }

  match self.gvn.make_key(graph, node) {
    Some(key) => {
      match self.lookup(key) {
        Some(leader) => {
          self.gvn.set_value_number(node.id, leader)
          Some(leader)
        }
        None => {
          self.insert(key, node.id)
          self.gvn.set_value_number(node.id, node.id)
          None
        }
      }
    }
    None => {
      self.gvn.set_value_number(node.id, node.id)
      None
    }
  }
}

///|
/// Process a block expression with proper scoping
pub fn DominatorGVN::process_block(
  self : DominatorGVN,
  graph : Graph,
  block_node : Node,
  _users : NodeUsers,
  replacements : Array[(NodeId, NodeId)],
) -> Unit {
  match block_node.expr {
    Some(Block(block)) => {
      for expr_id in block.list {
        // Find node for this expression
        match graph.get_node_for_set(expr_id) {
          Some(node_id) =>
            match graph.node_store.get(node_id) {
              Some(node) =>
                match self.process_node(graph, node) {
                  Some(leader) => replacements.push((node.id, leader))
                  None => ()
                }
              None => ()
            }
          None => ()
        }
      }
    }
    _ => ()
  }
}

///|
/// Process an if expression with proper scoping
pub fn DominatorGVN::process_if(
  self : DominatorGVN,
  graph : Graph,
  if_expr : IfExpr,
  users : NodeUsers,
  replacements : Array[(NodeId, NodeId)],
) -> Unit {
  // Process condition in current scope
  match graph.get_node_for_set(if_expr.condition) {
    Some(cond_node_id) =>
      match graph.node_store.get(cond_node_id) {
        Some(cond_node) =>
          match self.process_node(graph, cond_node) {
            Some(leader) => replacements.push((cond_node.id, leader))
            None => ()
          }
        None => ()
      }
    None => ()
  }

  // Process true branch in new scope
  self.push_scope()
  match graph.get_node_for_set(if_expr.if_true) {
    Some(true_node_id) =>
      match graph.node_store.get(true_node_id) {
        Some(true_node) => {
          match true_node.expr {
            Some(Block(_)) =>
              self.process_block(graph, true_node, users, replacements)
            _ =>
              match self.process_node(graph, true_node) {
                Some(leader) => replacements.push((true_node.id, leader))
                None => ()
              }
          }
        }
        None => ()
      }
    None => ()
  }
  self.pop_scope()

  // Process false branch in new scope
  match if_expr.if_false {
    Some(false_expr) => {
      self.push_scope()
      match graph.get_node_for_set(false_expr) {
        Some(false_node_id) =>
          match graph.node_store.get(false_node_id) {
            Some(false_node) => {
              match false_node.expr {
                Some(Block(_)) =>
                  self.process_block(graph, false_node, users, replacements)
                _ =>
                  match self.process_node(graph, false_node) {
                    Some(leader) => replacements.push((false_node.id, leader))
                    None => ()
                  }
              }
            }
            None => ()
          }
        None => ()
      }
      self.pop_scope()
    }
    None => ()
  }
}


