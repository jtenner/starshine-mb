// ============================================================================
// dataflow/graph_merge.mbt - Merging control flow
// ============================================================================

/// Merge local state for an if, creating conditions
pub fn Graph::merge_if(
  self : Graph,
  a_state : Locals,
  b_state : Locals,
  condition : NodeId,
  expr_id : ExprId
) -> Unit {
  let (if_true, if_false) = if not(self.node_store.is_bad(condition)) {
    // Generate boolean conditions for the two branches
    let if_true = self.ensure_i1(condition, None)
    let if_false = self.make_zero_comp(condition, true, None)
    // Store conditions in map
    self.expression_condition_map[expr_id] = [if_true, if_false]
    (if_true, if_false)
  } else {
    (self.bad(), self.bad())
  }
  // Merge the states
  let states : Array[FlowState] = []
  if not(self.is_locals_unreachable(a_state)) {
    states.push(FlowState::new(a_state, if_true))
  }
  if not(self.is_locals_unreachable(b_state)) {
    states.push(FlowState::new(b_state, if_false))
  }
  self.merge(states)
}

/// Merge local state for a block
pub fn Graph::merge_block(self : Graph, localses : Array[Locals]) -> Unit {
  let states : Array[FlowState] = []
  for locals in localses {
    states.push(FlowState::new(locals, self.bad()))
  }
  self.merge(states)
}

/// Merge multiple control flow paths, creating phis as needed
pub fn Graph::merge(self : Graph, states : Array[FlowState]) -> Unit {
  let func = match self.func {
    Some(f) => f
    None => return
  }
  let num_states = states.length()
  if num_states == 0 {
    // Still unreachable
    return
  }
  // May have just become reachable
  self.set_in_reachable()
  // Just one thing to merge is trivial
  if num_states == 1 {
    self.locals = states[0].locals.copy()
    return
  }
  // Create a block if we need one
  let num_locals = func.get_num_locals()
  let mut block : NodeId? = None
  for i = 0; i < num_locals; i = i + 1 {
    if not(self.is_relevant_type(func.get_local_type(i))) {
      continue
    }
    // Check if any input is bad
    let mut is_bad = false
    for state in states {
      let node = state.locals[i]
      if self.node_store.is_bad(node) {
        is_bad = true
        self.locals[i] = node
        break
      }
    }
    if is_bad {
      continue
    }
    // Check if we need a phi
    let mut first : NodeId? = None
    let mut needs_phi = false
    for state in states {
      match first {
        None => {
          first = Some(state.locals[i])
          self.locals[i] = state.locals[i]
        }
        Some(f) =>
          if state.locals[i] != f {
            needs_phi = true
            break
          }
      }
    }
    if needs_phi {
      // Create block if needed
      let block_id = match block {
        Some(b) => b
        None => {
          let block_id = NodeId(self.node_store.len())
          let block_node = Node::make_block(block_id)
          let b = self.add_node(block_node)
          // Add conditions to the block
          for idx = 0; idx < num_states; idx = idx + 1 {
            let condition = states[idx].condition
            if not(self.node_store.is_bad(condition)) {
              let cond_id = NodeId(self.node_store.len())
              let cond_node = Node::make_cond(cond_id, b, idx, condition)
              let cond = self.add_node(cond_node)
              match self.node_store.get_mut(b) {
                Some(block_node) => block_node.add_value(cond)
                None => ()
              }
            } else {
              match self.node_store.get_mut(b) {
                Some(block_node) => block_node.add_value(condition)
                None => ()
              }
            }
          }
          block = Some(b)
          b
        }
      }
      // Create the phi
      let phi_id = NodeId(self.node_store.len())
      let phi = Node::make_phi(phi_id, block_id, i)
      for state in states {
        let value = self.expand_from_i1(state.locals[i], None)
        phi.add_value(value)
      }
      self.locals[i] = self.add_node(phi)
    }
  }
}
