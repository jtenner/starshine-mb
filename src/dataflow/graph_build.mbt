// ============================================================================
// dataflow/graph_build.mbt - Graph building from function
// ============================================================================

///|
/// Build the dataflow graph from a function
pub fn Graph::build(self : Graph, func : Function, mod : Module) -> Unit {
  self.func = Some(func)
  self.mod = Some(mod)
  let num_locals = func.get_num_locals()
  if num_locals == 0 {
    return
  }
  // Set up initial local state
  self.set_in_reachable()
  for i = 0; i < num_locals; i = i + 1 {
    let local_type = func.get_local_type(i)
    if not(self.is_relevant_type(local_type)) {
      continue
    }
    let node = if func.is_param(i) {
      self.make_var(local_type)
    } else {
      self.make_zero(local_type)
    }
    self.locals[i] = node
  }
  // Process the function body
  match func.body {
    Some(body) => ignore(self.visit(body))
    None => ()
  }
}

///|
/// Main visitor dispatch
pub fn Graph::visit(self : Graph, expr_id : ExprId) -> NodeId {
  let func = match self.func {
    Some(f) => f
    None => return self.bad()
  }
  match func.expressions.get(expr_id) {
    Some(expr) => self.visit_expression(expr, expr_id)
    None => self.bad()
  }
}

///|
/// Visit an expression and return its node
pub fn Graph::visit_expression(
  self : Graph,
  expr : Expression,
  expr_id : ExprId,
) -> NodeId {
  match expr {
    Block(b) => self.do_visit_block(b, expr_id)
    If(i) => self.do_visit_if(i, expr_id)
    Loop(l) => self.do_visit_loop(l, expr_id)
    LocalGet(g) => self.do_visit_local_get(g)
    LocalSet(s) => self.do_visit_local_set(s, expr_id)
    Break(b) => self.do_visit_break(b)
    Switch(s) => self.do_visit_switch(s)
    Const(c) => self.do_visit_const(c)
    Unary(u) => self.do_visit_unary(u, expr_id)
    Binary(b) => self.do_visit_binary(b, expr_id)
    Select(s) => self.do_visit_select(s, expr_id)
    Unreachable => self.do_visit_unreachable()
    Drop(d) => self.do_visit_drop(d, expr_id)
    _ => self.do_visit_generic(expr, expr_id)
  }
}
