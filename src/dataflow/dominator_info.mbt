///|
/// Dominator information for the graph
struct DominatorInfo {
  // Maps each expression to its immediate dominator expression
  idom : Map[ExprId, ExprId]
  // Maps each expression to its depth in the dominator tree
  dom_depth : Map[ExprId, Int]
  // Entry expression
  mut entry : ExprId?
} derive(Show)

///|
fn DominatorInfo::new() -> DominatorInfo {
  { idom: Map::new(), dom_depth: Map::new(), entry: None }
}

///|
/// Compute dominator information for the graph
fn compute_dominators(graph : Graph) -> DominatorInfo {
  let info = DominatorInfo::new()

  // Find the entry point (function body)
  let entry = match graph.func {
    Some(f) => f.body
    None => None
  }
  match entry {
    Some(entry_id) => {
      info.entry = Some(entry_id)
      info.dom_depth.set(entry_id, 0)
      compute_dom_recursive(graph, info, entry_id, 0)
    }
    None => ()
  }
  info
}

///|
fn compute_dom_recursive(
  graph : Graph,
  info : DominatorInfo,
  expr_id : ExprId,
  depth : Int,
) -> Unit {
  let func = match graph.func {
    Some(f) => f
    None => return
  }
  match func.expressions.get(expr_id) {
    Some(Block(block)) =>
      // Each expression in the block is dominated by the block
      for child_id in block.list {
        info.idom.set(child_id, expr_id)
        info.dom_depth.set(child_id, depth + 1)
        compute_dom_recursive(graph, info, child_id, depth + 1)
      }
    Some(If(if_expr)) => {
      // Condition is dominated by the if
      info.idom.set(if_expr.condition, expr_id)
      info.dom_depth.set(if_expr.condition, depth + 1)
      compute_dom_recursive(graph, info, if_expr.condition, depth + 1)

      // True branch is dominated by the if
      info.idom.set(if_expr.if_true, expr_id)
      info.dom_depth.set(if_expr.if_true, depth + 1)
      compute_dom_recursive(graph, info, if_expr.if_true, depth + 1)

      // False branch is dominated by the if
      match if_expr.if_false {
        Some(false_id) => {
          info.idom.set(false_id, expr_id)
          info.dom_depth.set(false_id, depth + 1)
          compute_dom_recursive(graph, info, false_id, depth + 1)
        }
        None => ()
      }
    }
    Some(Loop(loop_expr)) => {
      // Loop body is dominated by the loop
      info.idom.set(loop_expr.body, expr_id)
      info.dom_depth.set(loop_expr.body, depth + 1)
      compute_dom_recursive(graph, info, loop_expr.body, depth + 1)
    }
    Some(Binary(bin)) => {
      info.idom.set(bin.left.0, expr_id)
      info.dom_depth.set(bin.left.0, depth + 1)
      info.idom.set(bin.right.0, expr_id)
      info.dom_depth.set(bin.right.0, depth + 1)
    }
    Some(Unary(un)) => {
      info.idom.set(un.value.0, expr_id)
      info.dom_depth.set(un.value.0, depth + 1)
    }
    Some(Select(sel)) => {
      info.idom.set(sel.condition.0, expr_id)
      info.dom_depth.set(sel.condition.0, depth + 1)
      info.idom.set(sel.if_true.0, expr_id)
      info.dom_depth.set(sel.if_true.0, depth + 1)
      info.idom.set(sel.if_false.0, expr_id)
      info.dom_depth.set(sel.if_false.0, depth + 1)
    }
    _ => ()
  }
}

///|
/// Check if expression a dominates expression b
fn expr_dominates(info : DominatorInfo, a : ExprId, b : ExprId) -> Bool {
  if a == b {
    return true
  }

  // Walk up the dominator tree from b to see if we reach a
  let mut current = b
  loop () {
    _ => {
      match info.idom.get(current) {
        Some(parent) => {
          if parent == a {
            return true
          }
          // Check for reaching root or cycle
          if parent == current {
            return false
          }
          current = parent
        }
        None => return false
      }
      continue ()
    }
  }
}
