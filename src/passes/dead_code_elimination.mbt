///|
pub fn dead_code_elimination_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    "dead-code-elimination",
    requires=[@ir.HotAnalysis::use_def(), @ir.HotAnalysis::effects()],
    invalidates=[
      @ir.HotAnalysis::cfg(),
      @ir.HotAnalysis::dominance(),
      @ir.HotAnalysis::liveness(),
      @ir.HotAnalysis::use_def(),
      @ir.HotAnalysis::effects(),
      @ir.HotAnalysis::loop_info(),
      @ir.HotAnalysis::ssa(),
    ],
  )
}

///|
pub fn dead_code_elimination_summary() -> String {
  "Prune unreachable tail roots and remove pure dropped values from hot IR regions."
}

///|
fn dead_code_elimination_has_fallthrough(op : @ir.HotOp) -> Bool {
  let edge_kinds = @ir.cfg_terminator_edge_kinds(op)
  if edge_kinds.length() == 0 {
    return true
  }
  for edge_kind in edge_kinds {
    match edge_kind {
      @ir.CfgEdgeKind::FallthroughEdge => return true
      _ => ()
    }
  }
  false
}

///|
fn dead_code_elimination_live_children(
  func : @ir.HotFunc,
  node_id : Int,
) -> Array[Int] {
  let children : Array[Int] = []
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      continue
    }
    children.push(child_id)
  }
  children
}

///|
fn dead_code_elimination_collect_detached_nodes(
  func : @ir.HotFunc,
  node_id : Int,
  out : Array[Int],
) -> Unit {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return
  }
  out.push(node_id)
  for child_id in dead_code_elimination_live_children(func, node_id) {
    dead_code_elimination_collect_detached_nodes(func, child_id, out)
  }
}

///|
fn dead_code_elimination_drop_is_dead(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Drop =>
      if @ir.hot_child_count(func, node_id) != 1 {
        return false
      }
    _ => return false
  }
  let child_id = @ir.hot_child_get(func, node_id, 0)
  child_id >= 0 &&
  @ir.hot_node_is_live(func, child_id) &&
  @ir.effects_is_pure(@ir.effects_for_node(func, child_id))
}

///|
fn dead_code_elimination_remove_roots(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  remove_count : Int,
) -> Bool {
  if remove_count <= 0 {
    return false
  }
  let removed_roots = pass_splice_region(
    ctx,
    func,
    region_ref,
    idx,
    remove_count,
    [],
  )
  let detached : Array[Int] = []
  for node_id in removed_roots {
    dead_code_elimination_collect_detached_nodes(func, node_id, detached)
  }
  pass_delete_detached_nodes(ctx, func, detached)
  true
}

///|
fn dead_code_elimination_visit_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let mut changed = false
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      idx += 1
      continue
    }

    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        changed = dead_code_elimination_visit_region(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) ||
          changed
      @ir.HotOp::If => {
        changed = dead_code_elimination_visit_region(
            ctx,
            func,
            @ir.hot_region_then_ref(func, node_id),
          ) ||
          changed
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_region) =>
            changed = dead_code_elimination_visit_region(ctx, func, else_region) ||
              changed
          None => ()
        }
      }
      @ir.HotOp::Try => {
        changed = dead_code_elimination_visit_region(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) ||
          changed
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_region) =>
            changed = dead_code_elimination_visit_region(
                ctx, func, catch_region,
              ) ||
              changed
          None => ()
        }
      }
      @ir.HotOp::TryTable => {
        changed = dead_code_elimination_visit_region(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) ||
          changed
        changed = dead_code_elimination_visit_region(
            ctx,
            func,
            @ir.hot_region_catch_list_ref(func, node_id),
          ) ||
          changed
      }
      _ => ()
    }

    if dead_code_elimination_drop_is_dead(func, node_id) {
      ignore(dead_code_elimination_remove_roots(ctx, func, region_ref, idx, 1))
      changed = true
      continue
    }

    if !dead_code_elimination_has_fallthrough(node.op) &&
      idx + 1 < @ir.hot_region_root_count(func, region_ref) {
      ignore(
        dead_code_elimination_remove_roots(
          ctx,
          func,
          region_ref,
          idx + 1,
          @ir.hot_region_root_count(func, region_ref) - (idx + 1),
        ),
      )
      changed = true
    }
    idx += 1
  }
  changed
}

///|
fn dead_code_elimination_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  if dead_code_elimination_visit_region(ctx, func, @ir.HotRegionRef::root()) {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
