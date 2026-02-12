// ============================================================================
// dataflow/graph_visitors.mbt - Expression visitors
// ============================================================================

///|
pub fn Graph::do_visit_block(
  self : Graph,
  block : BlockExpr,
  expr_id : ExprId,
) -> NodeId {
  let old_parent = self.parent
  match old_parent {
    Some(p) => self.expression_parent_map[expr_id] = p
    None => ()
  }
  self.parent = Some(expr_id)
  // Visit all children
  for child in block.list {
    let _ = self.visit(child)
  }
  // Merge the outputs
  match block.name {
    Some(name) =>
      match self.break_states.get(name) {
        Some(states) => {
          // Add the state flowing out
          if not(self.is_in_unreachable()) {
            states.push(self.locals.copy())
          }
          self.merge_block(states)
        }
        None => ()
      }
    None => ()
  }
  self.parent = old_parent
  self.bad()
}

///|
pub fn Graph::do_visit_if(
  self : Graph,
  iff : IfExpr,
  expr_id : ExprId,
) -> NodeId {
  let old_parent = self.parent
  match old_parent {
    Some(p) => self.expression_parent_map[expr_id] = p
    None => ()
  }
  self.parent = Some(expr_id)
  // Set up the condition
  let condition = self.visit(iff.condition)
  // Handle the contents
  let initial_state = self.locals.copy()
  let _ = self.visit(iff.if_true)
  let after_if_true_state = self.locals.copy()
  match iff.if_false {
    Some(if_false_id) => {
      self.locals = initial_state.copy()
      let _ = self.visit(if_false_id)
      let after_if_false_state = self.locals.copy()
      self.merge_if(
        after_if_true_state, after_if_false_state, condition, expr_id,
      )
    }
    None =>
      self.merge_if(initial_state, after_if_true_state, condition, expr_id)
  }
  self.parent = old_parent
  self.bad()
}

///|
pub fn Graph::do_visit_loop(
  self : Graph,
  loop_ : LoopExpr,
  expr_id : ExprId,
) -> NodeId {
  let old_parent = self.parent
  let func = match self.func {
    Some(f) => f
    None => return self.bad()
  }
  match old_parent {
    Some(p) => self.expression_parent_map[expr_id] = p
    None => ()
  }
  self.parent = Some(expr_id)
  if self.is_in_unreachable() {
    return self.bad()
  }
  match loop_.name {
    None => {
      let _ = self.visit(loop_.body)
      self.parent = old_parent
      return self.bad()
    }
    Some(name) => {
      let previous = self.locals.copy()
      let num_locals = func.get_num_locals()
      // Replace locals with Vars
      for i = 0; i < num_locals; i = i + 1 {
        self.locals[i] = self.make_var(func.get_local_type(i))
      }
      let vars = self.locals.copy()
      let first_node_from_loop = self.node_store.len()
      // Process the loop body
      let _ = self.visit(loop_.body)
      // Find all incoming paths
      let breaks = match self.break_states.get(name) {
        Some(b) => b
        None => []
      }
      // Check for phis
      for i = 0; i < num_locals; i = i + 1 {
        if not(self.is_relevant_type(func.get_local_type(i))) {
          continue
        }
        let mut need_phi = false
        let vi = vars[i]
        let proper = previous[i]
        for other in breaks {
          if not(self.is_locals_unreachable(other)) {
            let curr = other[i]
            if curr != vi && curr != proper {
              need_phi = true
              break
            }
          }
        }
        if not(need_phi) {
          // Undo the Var for this local
          for j = first_node_from_loop; j < self.node_store.len(); j = j + 1 {
            match self.node_store.get_mut(NodeId(j)) {
              Some(node) =>
                for k = 0; k < node.values.length(); k = k + 1 {
                  if node.values[k] == vi {
                    node.values[k] = proper
                  }
                }
              None => ()
            }
          }
          for k = 0; k < self.locals.length(); k = k + 1 {
            if self.locals[k] == vi {
              self.locals[k] = proper
            }
          }
        }
      }
      self.parent = old_parent
      self.bad()
    }
  }
}

///|
pub fn Graph::do_visit_break(self : Graph, brk : BreakExpr) -> NodeId {
  if not(self.is_in_unreachable()) {
    match self.break_states.get(brk.name) {
      Some(states) => states.push(self.locals.copy())
      None => self.break_states[brk.name] = [self.locals.copy()]
    }
  }
  match brk.condition {
    None => self.set_in_unreachable()
    Some(cond) => {
      let _ = self.visit(cond)
    }
  }
  self.bad()
}

///|
pub fn Graph::do_visit_switch(self : Graph, sw : SwitchExpr) -> NodeId {
  let _ = self.visit(sw.condition)
  if not(self.is_in_unreachable()) {
    let targets : Map[String, Unit] = {}
    for target in sw.targets {
      targets[target] = ()
    }
    targets[sw.default] = ()
    for entry in targets {
      let target = entry.0
      match self.break_states.get(target) {
        Some(states) => states.push(self.locals.copy())
        None => self.break_states[target] = [self.locals.copy()]
      }
    }
  }
  self.set_in_unreachable()
  self.bad()
}

///|
pub fn Graph::do_visit_local_get(self : Graph, get : LocalGetExpr) -> NodeId {
  if not(self.is_relevant_local(get.index)) || self.is_in_unreachable() {
    return self.bad()
  }
  self.locals[get.index]
}

///|
pub fn Graph::do_visit_local_set(
  self : Graph,
  set : LocalSetExpr,
  expr_id : ExprId,
) -> NodeId {
  if not(self.is_relevant_local(set.index)) || self.is_in_unreachable() {
    return self.bad()
  }
  self.sets.push(expr_id)
  match self.parent {
    Some(p) => self.expression_parent_map[expr_id] = p
    None => ()
  }
  self.expression_parent_map[set.value] = expr_id
  // Set the current node in the local state
  let node = self.visit(set.value)
  self.locals[set.index] = node
  self.set_node_map[expr_id] = node
  // Mark node's parent if it's new
  if not(self.node_parent_map.contains(node)) {
    self.node_parent_map[node] = expr_id
  }
  self.bad()
}

///|
pub fn Graph::do_visit_const(self : Graph, c : ConstExpr) -> NodeId {
  self.make_const(c.value)
}

///|
pub fn Graph::do_visit_unary(
  self : Graph,
  unary : UnaryExpr,
  expr_id : ExprId,
) -> NodeId {
  match unary.op {
    ClzInt32 | ClzInt64 | CtzInt32 | CtzInt64 | PopcntInt32 | PopcntInt64 => {
      let value = self.expand_from_i1(self.visit(unary.value), Some(expr_id))
      if self.node_store.is_bad(value) {
        return value
      }
      let ret_id = NodeId(self.node_store.len())
      let ret = Node::make_expr(ret_id, Unary(unary), Some(expr_id))
      ret.add_value(value)
      self.add_node(ret)
    }
    EqZInt32 | EqZInt64 => {
      let value = self.expand_from_i1(self.visit(unary.value), Some(expr_id))
      if self.node_store.is_bad(value) {
        return value
      }
      self.make_zero_comp(value, true, Some(expr_id))
    }
    _ => self.make_var(unary.result_type)
  }
}

///|
pub fn Graph::do_visit_binary(
  self : Graph,
  binary : BinaryExpr,
  expr_id : ExprId,
) -> NodeId {
  match binary.op {
    AddInt32
    | AddInt64
    | SubInt32
    | SubInt64
    | MulInt32
    | MulInt64
    | DivSInt32
    | DivSInt64
    | DivUInt32
    | DivUInt64
    | RemSInt32
    | RemSInt64
    | RemUInt32
    | RemUInt64
    | AndInt32
    | AndInt64
    | OrInt32
    | OrInt64
    | XorInt32
    | XorInt64
    | ShlInt32
    | ShlInt64
    | ShrUInt32
    | ShrUInt64
    | ShrSInt32
    | ShrSInt64
    | RotLInt32
    | RotLInt64
    | RotRInt32
    | RotRInt64
    | EqInt32
    | EqInt64
    | NeInt32
    | NeInt64
    | LtSInt32
    | LtSInt64
    | LtUInt32
    | LtUInt64
    | LeSInt32
    | LeSInt64
    | LeUInt32
    | LeUInt64 => {
      let left = self.expand_from_i1(self.visit(binary.left), Some(expr_id))
      if self.node_store.is_bad(left) {
        return left
      }
      let right = self.expand_from_i1(self.visit(binary.right), Some(expr_id))
      if self.node_store.is_bad(right) {
        return right
      }
      let ret_id = NodeId(self.node_store.len())
      let ret = Node::make_expr(ret_id, Binary(binary), Some(expr_id))
      ret.add_value(left)
      ret.add_value(right)
      self.add_node(ret)
    }
    GtSInt32
    | GtSInt64
    | GeSInt32
    | GeSInt64
    | GtUInt32
    | GtUInt64
    | GeUInt32
    | GeUInt64 =>
      // Flip operands and use the opposite comparison
      match binary.op.get_opposite() {
        Some(opposite) => {
          let flipped = BinaryExpr::{
            op: opposite,
            left: binary.right,
            right: binary.left,
            result_type: binary.result_type,
          }
          let left = self.expand_from_i1(
            self.visit(flipped.left),
            Some(expr_id),
          )
          if self.node_store.is_bad(left) {
            return left
          }
          let right = self.expand_from_i1(
            self.visit(flipped.right),
            Some(expr_id),
          )
          if self.node_store.is_bad(right) {
            return right
          }
          let ret_id = NodeId(self.node_store.len())
          let ret = Node::make_expr(ret_id, Binary(flipped), Some(expr_id))
          ret.origin = Some(expr_id)
          ret.add_value(left)
          ret.add_value(right)
          self.add_node(ret)
        }
        None => self.make_var(binary.result_type)
      }
    _ => self.make_var(binary.result_type)
  }
}

///|
pub fn Graph::do_visit_select(
  self : Graph,
  select : SelectExpr,
  expr_id : ExprId,
) -> NodeId {
  let if_true = self.expand_from_i1(self.visit(select.if_true), Some(expr_id))
  if self.node_store.is_bad(if_true) {
    return if_true
  }
  let if_false = self.expand_from_i1(self.visit(select.if_false), Some(expr_id))
  if self.node_store.is_bad(if_false) {
    return if_false
  }
  let condition = self.ensure_i1(self.visit(select.condition), Some(expr_id))
  if self.node_store.is_bad(condition) {
    return condition
  }
  let ret_id = NodeId(self.node_store.len())
  let ret = Node::make_expr(ret_id, Select(select), Some(expr_id))
  ret.add_value(condition)
  ret.add_value(if_true)
  ret.add_value(if_false)
  self.add_node(ret)
}

///|
pub fn Graph::do_visit_unreachable(self : Graph) -> NodeId {
  self.set_in_unreachable()
  self.bad()
}

///|
pub fn Graph::do_visit_drop(
  self : Graph,
  drop : DropExpr,
  expr_id : ExprId,
) -> NodeId {
  let _ = self.visit(drop.value)
  self.expression_parent_map[drop.value] = expr_id
  self.bad()
}

///|
pub fn Graph::do_visit_generic(
  self : Graph,
  expr : Expression,
  _expr_id : ExprId,
) -> NodeId {
  // Visit children to note gets
  let children = match expr {
    Call(c) => c.operands
    Generic(g) => g.children
    Return(r) =>
      match r.value {
        Some(v) => [v]
        None => []
      }
    _ => []
  }
  for child in children {
    let _ = self.visit(child)
  }
  self.make_var(expr.get_type())
}

///|
pub fn Graph::do_visit_load(
  self : Graph,
  load : LoadExpr,
  expr_id : ExprId,
) -> NodeId {
  // Visit pointer operand
  let ptr = self.expand_from_i1(self.visit(load.ptr), Some(expr_id))
  if self.node_store.is_bad(ptr) {
    return self.bad()
  }

  // Create the load expression
  let expr = Expression::load(
    LoadExpr::new(load.op, load.ptr, load.offset, load.align, load.result_type),
  )

  // Create the node
  let node_id = self.add_node(
    Node::make_expr(NodeId::new(0), expr, Some(expr_id)),
  )

  // Add operands to the node
  match self.node_store.get_mut(node_id) {
    Some(n) => {
      n.values.push(ptr)
      n.wasm_type = load.result_type
    }
    None => ()
  }

  // Record in Memory SSA
  match self.mssa {
    Some(mssa) => mssa.record_load(self, node_id, expr_id)
    None => ()
  }
  node_id
}

///|
pub fn Graph::do_visit_store(
  self : Graph,
  store : StoreExpr,
  expr_id : ExprId,
) -> NodeId {
  // Visit pointer and value operands
  let ptr = self.expand_from_i1(self.visit(store.ptr), Some(expr_id))
  if self.node_store.is_bad(ptr) {
    return self.bad()
  }
  let value = self.expand_from_i1(self.visit(store.value), Some(expr_id))
  if self.node_store.is_bad(value) {
    return self.bad()
  }

  // Create the store expression
  let expr = Expression::store(
    StoreExpr::new(store.op, store.ptr, store.value, store.offset, store.align),
  )

  // Create the node - stores don't produce a value
  let node_id = self.add_node(
    Node::make_expr(NodeId::new(0), expr, Some(expr_id)),
  )

  // Add operands to the node
  match self.node_store.get_mut(node_id) {
    Some(n) => {
      n.values.push(ptr)
      n.values.push(value)
      n.wasm_type = WasmType::none()
    }
    None => ()
  }

  // Record in Memory SSA
  match self.mssa {
    Some(mssa) => mssa.record_store(self, node_id, expr_id)
    None => ()
  }
  node_id
}

///|
pub fn Graph::do_visit_memory_size(
  self : Graph,
  mem_size : MemorySizeExpr,
  expr_id : ExprId,
) -> NodeId {
  // Create the memory.size expression - no operands
  let expr = Expression::memory_size(MemorySizeExpr::new(mem_size.memory_index))

  // Create the node - memory.size returns i32
  let node_id = self.add_node(
    Node::make_expr(NodeId::new(0), expr, Some(expr_id)),
  )
  match self.node_store.get_mut(node_id) {
    Some(n) => n.wasm_type = WasmType::i32()
    None => ()
  }

  // memory.size is a read of memory state but doesn't modify it
  // We could track it as a MemoryUse if we want to optimize it

  node_id
}

///|
pub fn Graph::do_visit_memory_grow(
  self : Graph,
  mem_grow : MemoryGrowExpr,
  expr_id : ExprId,
) -> NodeId {
  // Visit delta operand
  let delta = self.expand_from_i1(self.visit(mem_grow.delta), Some(expr_id))
  if self.node_store.is_bad(delta) {
    return self.bad()
  }

  // Create the memory.grow expression
  let expr = Expression::memory_grow(
    MemoryGrowExpr::new(mem_grow.memory_index, mem_grow.delta),
  )

  // Create the node - memory.grow returns i32 (previous size or -1)
  let node_id = self.add_node(
    Node::make_expr(NodeId::new(0), expr, Some(expr_id)),
  )
  match self.node_store.get_mut(node_id) {
    Some(n) => {
      n.values.push(delta)
      n.wasm_type = WasmType::i32()
    }
    None => ()
  }

  // Record in Memory SSA - memory.grow clobbers memory state
  match self.mssa {
    Some(mssa) => mssa.record_memory_grow(self, node_id, expr_id)
    None => ()
  }
  node_id
}

///|
pub fn Graph::do_visit_call(
  self : Graph,
  call : CallExpr,
  expr_id : ExprId,
) -> NodeId {
  // Visit all operands
  let operand_nodes : Array[NodeId] = []
  for operand in call.operands {
    let op_node = self.expand_from_i1(self.visit(operand), Some(expr_id))
    if self.node_store.is_bad(op_node) {
      return self.bad()
    }
    operand_nodes.push(op_node)
  }

  // Create the call expression
  let expr = Expression::call(
    CallExpr::new(call.target, call.operands, call.result_type),
  )

  // Create the node
  let node_id = self.add_node(
    Node::make_expr(NodeId::new(0), expr, Some(expr_id)),
  )
  match self.node_store.get_mut(node_id) {
    Some(n) => {
      for op in operand_nodes {
        n.values.push(op)
      }
      n.wasm_type = call.result_type
    }
    None => ()
  }

  // Record in Memory SSA - calls conservatively clobber all memory
  match self.mssa {
    Some(mssa) => mssa.record_call(self, node_id, expr_id)
    None => ()
  }
  node_id
}
