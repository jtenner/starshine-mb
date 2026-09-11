///|
priv struct HotLocalScopeScan {
  initialized : Array[Bool]
  writes : Array[Int]
  needs_default : Array[Bool]
  visited_frame : Array[Int]
  mut next_frame : Int
}

///|
fn hot_local_scope_visit(
  func : HotFunc,
  node_id : NodeId,
  frame : Int,
  scan : HotLocalScopeScan,
) -> Unit {
  if node_id < 0 ||
    !hot_node_is_live(func, node_id) ||
    scan.visited_frame[node_id] == frame {
    return
  }
  scan.visited_frame[node_id] = frame
  let node = hot_node_get(func, node_id)
  match node.op {
    HotOp::Block | HotOp::Loop => {
      // Loop arguments execute in the enclosing scope. Its body, like a
      // block body, cannot export local initialization to that scope.
      let base = hot_region_body_base(func, node_id)
      for slot = 0; slot < base; slot = slot + 1 {
        hot_local_scope_visit(
          func,
          hot_child_get(func, node_id, slot),
          frame,
          scan,
        )
      }
      let saved = scan.writes.length()
      scan.next_frame += 1
      let child_frame = scan.next_frame
      for slot = base; slot < node.child_count; slot = slot + 1 {
        hot_local_scope_visit(
          func,
          hot_child_get(func, node_id, slot),
          child_frame,
          scan,
        )
      }
      while scan.writes.length() > saved {
        scan.initialized[scan.writes.pop().unwrap()] = false
      }
      return
    }
    _ => ()
  }
  // If and exception arm holders are Block regions, so each arm restores
  // its entry state. Conditions and ordinary operands share the current frame.
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    hot_local_scope_visit(func, hot_child_get(func, node_id, slot), frame, scan)
  }
  match node.op {
    HotOp::LocalGet =>
      if !scan.initialized[node.imm0] {
        scan.needs_default[node.imm0] = true
      }
    HotOp::LocalSet | HotOp::LocalTee =>
      if !scan.initialized[node.imm0] {
        scan.initialized[node.imm0] = true
        scan.writes.push(node.imm0)
      }
    _ => ()
  }
}

///|
/// Preserve result types when code motion moves a local read outside the
/// control scope that initialized its non-defaultable reference storage.
/// Call only after a semantics-preserving transform on a valid input.
pub fn hot_repair_nondefaultable_local_scopes(func : HotFunc) -> Bool {
  let initialized = Array::make(hot_local_count(func), true)
  let mut has_nondefaultable = false
  for local_id = hot_local_param_count(func)
      local_id < hot_local_count(func)
      local_id = local_id + 1 {
    match hot_local_type(func, local_id) {
      Some(RefTypeValType(ref_type)) if ref_type.is_non_nullable() => {
        initialized[local_id] = false
        has_nondefaultable = true
      }
      _ => ()
    }
  }
  if !has_nondefaultable {
    return false
  }
  let node_count = hot_node_count(func)
  let scan : HotLocalScopeScan = {
    initialized,
    writes: [],
    needs_default: Array::make(hot_local_count(func), false),
    visited_frame: Array::make(node_count, -1),
    next_frame: 0,
  }
  for slot = 0; slot < hot_root_count(func); slot = slot + 1 {
    hot_local_scope_visit(func, hot_root_get(func, slot), 0, scan)
  }
  let mut changed = false
  for local_id, needs_default in scan.needs_default {
    if needs_default {
      if !hot_weaken_body_local_to_nullable_ref(func, local_id) {
        abort("local scope repair requires a non-defaultable body local")
      }
      changed = true
    }
  }
  if !changed {
    return false
  }
  for node_id = 0; node_id < node_count; node_id = node_id + 1 {
    if !hot_node_is_live(func, node_id) {
      continue
    }
    let node = hot_node_get(func, node_id)
    match node.op {
      HotOp::LocalGet | HotOp::LocalTee if scan.needs_default[node.imm0] => {
        match hot_type_results(func, node.ty) {
          [RefTypeValType(ref_type)] if ref_type.is_non_nullable() => ()
          _ =>
            abort(
              "local scope repair expected one non-null reference result at node \{node_id}",
            )
        }
        let storage_type = hot_local_type(func, node.imm0).unwrap()
        let nullable_type = hot_type_intern_value(func, storage_type)
        let copy = hot_alloc_node(func, { ..node, ty: nullable_type, })
        // This is the same read/write at its old execution point, not a new
        // effect after later roots. Preserve the source position on both nodes.
        func.nodes[copy] = { ..func.nodes[copy], order: node.order, }
        ignore(hot_replace_child_span(func, node_id, [copy]))
        hot_node_set(func, node_id, {
          ..hot_node_get(func, node_id),
          op: HotOp::Unary,
          flags: hot_default_flags_for_op(HotOp::Unary),
          imm0: 0,
          imm1: 0,
        })
        hot_node_exact_instr_set(func, node_id, Instruction::ref_as_non_null())
      }
      _ => ()
    }
  }
  true
}
