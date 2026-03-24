///|
fn optimization_hot_collect_locals(locals : @lib.Locals) -> Array[@lib.ValType] {
  let out : Array[@lib.ValType] = []
  for i = 0; i < locals.length(); i = i + 1 {
    out.push(locals.get(i))
  }
  out
}

///|
fn optimization_hot_locals(
  param_count : Int,
  locals : @lib.Locals,
) -> HotLocals {
  HotLocals::new(
    param_count~,
    locals=optimization_hot_collect_locals(locals),
  )
}

///|
fn optimization_hot_all_locals(
  params : Array[@lib.ValType],
  locals : @lib.Locals,
) -> @lib.Locals {
  let out = @lib.Locals::from_types(params)
  for i = 0; i < locals.length(); i = i + 1 {
    out.push(locals.get(i))
  }
  out
}

///|
fn optimization_hot_rewrite_func(
  func : @lib.Func,
  func_idx : @lib.FuncIdx,
  env : @validate.Env,
  rewrite : (HotFunc) -> Bool,
) -> (@lib.Func, Bool) {
  match func {
    @lib.Func(locals, body) =>
      match env.get_functype_by_funcidx(func_idx) {
        Some(@lib.FuncType(params, results)) =>
          match @validate.to_texpr(
            body,
            env
            .with_locals(optimization_hot_all_locals(params, locals))
            .with_labels([results])
            .with_return_type(Some(results)),
          ) {
            Ok(typed_body) => {
              let hot = hot_lift_body(
                typed_body,
                optimization_hot_locals(params.length(), locals),
              )
              let changed = rewrite(hot)
              if changed {
                (@lib.Func::new(locals, @lib.tinstrs_to_expr(hot_lower_body(hot))), true)
              } else {
                (func, false)
              }
            }
            Err(_) => (func, false)
          }
        None => (func, false)
      }
  }
}

///|
fn optimization_hot_remove_unused_names_func(
  func : @lib.Func,
  func_idx : @lib.FuncIdx,
  env : @validate.Env,
) -> (@lib.Func, Bool) {
  optimization_hot_rewrite_func(func, func_idx, env, fn(hot) {
    if !optimization_hot_remove_unused_names_has_candidate_hot(hot) {
      return false
    }
    let mut changed = false
    for i = 0; i < hot_root_count(hot); i = i + 1 {
      if optimization_hot_remove_unused_names_visit(hot, hot_root_get(hot, i)) {
        changed = true
      }
    }
    changed
  })
}

///|
fn optimization_hot_rewrite_string_consts(
  func : HotFunc,
  id : NodeId,
  canonicals : Array[(Bytes, @lib.GlobalIdx)],
) -> Bool {
  let mut changed = false
  let node = hot_node_get(func, id)
  if hot_node_is_const(node) {
      match func.consts[node.imm0] {
        @ir.StringConst(bytes) =>
          match optimization_string_gathering_lookup_global(canonicals, bytes) {
            Some(@lib.GlobalIdx(raw)) => {
              hot_replace_node(
                func,
                id,
                hot_node_as_global_get(node, raw.reinterpret_as_int()),
              )
              changed = true
            }
            None => ()
          }
        _ => ()
      }
  }
  let next_node = hot_node_get(func, id)
  for i = 0; i < next_node.child_count; i = i + 1 {
    let child = hot_child_get(func, id, i)
    if child >= 0 && optimization_hot_rewrite_string_consts(func, child, canonicals) {
      changed = true
    }
  }
  changed
}

///|
fn optimization_hot_string_gathering_rewrite_func(
  func : @lib.Func,
  func_idx : @lib.FuncIdx,
  env : @validate.Env,
  canonicals : Array[(Bytes, @lib.GlobalIdx)],
) -> (@lib.Func, Bool) {
  optimization_hot_rewrite_func(func, func_idx, env, fn(hot) {
    let mut changed = false
    for i = 0; i < hot_root_count(hot); i = i + 1 {
      if optimization_hot_rewrite_string_consts(hot, hot_root_get(hot, i), canonicals) {
        changed = true
      }
    }
    changed
  })
}

///|
fn optimization_hot_node_targets_label(
  func : HotFunc,
  id : NodeId,
  label_id : LabelId,
) -> Bool {
  let node = hot_node_get(func, id)
  if hot_node_is_try_table(node) {
    for catch_ in func.catches[node.imm1].catches {
      match catch_ {
        @ir.CatchArm(_, target)
        | @ir.CatchRefArm(_, target)
        | @ir.CatchAllArm(target)
        | @ir.CatchAllRefArm(target) => if target == label_id { return true }
      }
    }
    false
  } else if hot_node_is_branch_targeting(node) {
    if node.op.to_string() == "BrTable" {
      let table = func.branch_tables[node.imm1]
      if table.default_target == label_id {
        return true
      }
      for target in table.targets {
        if target == label_id {
          return true
        }
      }
      false
    } else {
      node.imm0 == label_id
    }
  } else {
    false
  }
}

///|
fn optimization_hot_subtree_targets_label(
  func : HotFunc,
  id : NodeId,
  label_id : LabelId,
) -> Bool {
  if optimization_hot_node_targets_label(func, id, label_id) {
    return true
  }
  let node = hot_node_get(func, id)
  for i = 0; i < node.child_count; i = i + 1 {
    let child = hot_child_get(func, id, i)
    if child != -1 && optimization_hot_subtree_targets_label(func, child, label_id) {
      return true
    }
  }
  false
}

///|
fn optimization_hot_block_merge_candidate(func : HotFunc, id : NodeId) -> Bool {
  let node = hot_node_get(func, id)
  if !hot_node_is_block(node) || node.child_count != 1 {
    return false
  }
  let child = hot_child_get(func, id, 0)
  if child < 0 {
    return false
  }
  let child_node = hot_node_get(func, child)
  hot_node_is_block(child_node) && child_node.ty == node.ty
}

///|
fn optimization_hot_remove_unused_names_has_candidate_hot(func : HotFunc) -> Bool {
  for i = 0; i < hot_root_count(func); i = i + 1 {
    if optimization_hot_remove_unused_names_has_candidate_node(
      func,
      hot_root_get(func, i),
    ) {
      return true
    }
  }
  false
}

///|
fn optimization_hot_remove_unused_names_has_candidate_node(
  func : HotFunc,
  id : NodeId,
) -> Bool {
  let node = hot_node_get(func, id)
  if hot_node_is_loop(node) || optimization_hot_block_merge_candidate(func, id) {
    return true
  }
  for i = 0; i < node.child_count; i = i + 1 {
    let child = hot_child_get(func, id, i)
    if child >= 0 && optimization_hot_remove_unused_names_has_candidate_node(func, child) {
      return true
    }
  }
  false
}

///|
fn optimization_hot_copy_children(func : HotFunc, id : NodeId) -> Array[NodeId] {
  let out : Array[NodeId] = []
  for i = 0; i < hot_child_count(func, id); i = i + 1 {
    out.push(hot_child_get(func, id, i))
  }
  out
}

///|
fn optimization_hot_remove_unused_names_visit(func : HotFunc, id : NodeId) -> Bool {
  let mut changed = false
  let mut node = hot_node_get(func, id)
  for i = 0; i < node.child_count; i = i + 1 {
    let child = hot_child_get(func, id, i)
    if child >= 0 && optimization_hot_remove_unused_names_visit(func, child) {
      changed = true
    }
  }

  node = hot_node_get(func, id)
  if hot_node_is_block(node) {
      while optimization_hot_block_merge_candidate(func, id) {
        let child = hot_child_get(func, id, 0)
        let child_node = hot_node_get(func, child)
        if optimization_hot_subtree_targets_label(func, child, child_node.imm0) {
          break
        }
        hot_replace_children(func, id, optimization_hot_copy_children(func, child))
        changed = true
      }
  } else if hot_node_is_loop(node) {
      if !optimization_hot_subtree_targets_label(func, id, node.imm0) {
        hot_replace_node(func, id, hot_node_as_block(node))
        hot_set_label_block(func, node.imm0)
        changed = true
      }
  }
  changed
}

///|
