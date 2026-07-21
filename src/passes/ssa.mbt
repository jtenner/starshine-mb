///|
pub fn ssa_full_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("ssa", invalidates=[
    @ir.HotAnalysis::cfg(),
    @ir.HotAnalysis::dominance(),
    @ir.HotAnalysis::liveness(),
    @ir.HotAnalysis::use_def(),
    @ir.HotAnalysis::effects(),
    @ir.HotAnalysis::loop_info(),
    @ir.HotAnalysis::ssa(),
  ])
}

///|
pub fn ssa_full_summary() -> String {
  "SSA-ify local traffic, including simple explicit-write merge locals; entry/default merge materialization remains fail-closed."
}

///|
/// Planned incoming source action for a future Binaryen-style full-SSA merge local.
pub(all) enum SsaFullMergeInput {
  ExplicitWrite(@ir.NodeId)
  ParamEntry(@ir.LocalId)
  DefaultEntry(@ir.LocalId)
} derive(Eq, Debug)

///|
/// Planned rewrite for one multi-source `local.get` in the full-SSA sibling.
pub(all) struct SsaFullMergeGetRewrite {
  get_id : @ir.NodeId
  original_local : @ir.LocalId
  merge_local : @ir.LocalId
  inputs : Array[SsaFullMergeInput]
} derive(Eq, Debug)

///|
/// Analysis-only full-SSA rewrite plan. This does not mutate the function.
pub(all) struct SsaFullRewritePlan {
  merge_gets : Array[SsaFullMergeGetRewrite]
} derive(Eq, Debug)

///|
fn ssa_full_source_to_merge_input(
  graph : @ir.HotLocalGraph,
  source : @ir.HotLocalGraphSource,
) -> SsaFullMergeInput? {
  match source {
    @ir.HotLocalGraphSource::SetSource(node_id) =>
      Some(SsaFullMergeInput::ExplicitWrite(node_id))
    @ir.HotLocalGraphSource::EntrySource(local_id) =>
      if @ir.local_graph_entry_source_is_param(graph, local_id) {
        Some(SsaFullMergeInput::ParamEntry(local_id))
      } else if @ir.local_graph_entry_source_has_legal_default(graph, local_id) {
        Some(SsaFullMergeInput::DefaultEntry(local_id))
      } else {
        None
      }
  }
}

///|
fn ssa_full_build_inputs_for_merge_get(
  graph : @ir.HotLocalGraph,
  get_id : @ir.NodeId,
) -> Array[SsaFullMergeInput]? {
  let inputs : Array[SsaFullMergeInput] = []
  for source in @ir.local_graph_reaching_sources_for_get(graph, get_id) {
    match ssa_full_source_to_merge_input(graph, source) {
      Some(input) => inputs.push(input)
      None => return None
    }
  }
  Some(inputs)
}

///|
/// Build the analysis-only full-SSA merge-local plan from LocalGraph facts.
pub fn ssa_full_build_merge_rewrite_plan(
  func : @ir.HotFunc,
  graph : @ir.HotLocalGraph,
) -> SsaFullRewritePlan {
  let merge_gets : Array[SsaFullMergeGetRewrite] = []
  let mut next_merge_local = @ir.hot_local_count(func)
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::LocalGet =>
        if @ir.local_graph_get_is_merge(graph, node_id) {
          match ssa_full_build_inputs_for_merge_get(graph, node_id) {
            Some(inputs) => {
              merge_gets.push({
                get_id: node_id,
                original_local: node.imm0,
                merge_local: next_merge_local,
                inputs,
              })
              next_merge_local = next_merge_local + 1
            }
            None => ()
          }
        }
      _ => ()
    }
  }
  { merge_gets, }
}

///|
fn ssa_full_graph_has_merge_get(
  func : @ir.HotFunc,
  graph : @ir.HotLocalGraph,
) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::LocalGet =>
        if @ir.local_graph_get_is_merge(graph, node_id) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_full_rewrite_has_only_explicit_writes(
  rewrite : SsaFullMergeGetRewrite,
) -> Bool {
  if rewrite.inputs.length() < 2 {
    return false
  }
  for input in rewrite.inputs {
    match input {
      SsaFullMergeInput::ExplicitWrite(_) => ()
      _ => return false
    }
  }
  true
}

///|
fn ssa_full_plan_has_only_simple_explicit_writes(
  plan : SsaFullRewritePlan,
) -> Bool {
  if plan.merge_gets.is_empty() {
    return false
  }
  for rewrite in plan.merge_gets {
    if !ssa_full_rewrite_has_only_explicit_writes(rewrite) {
      return false
    }
  }
  true
}

///|
fn ssa_full_apply_simple_explicit_merge_rewrite(
  func : @ir.HotFunc,
  rewrite : SsaFullMergeGetRewrite,
) -> Bool {
  let merge_ty = match @ir.hot_local_type(func, rewrite.original_local) {
    Some(ty) => ty
    None => return false
  }
  if rewrite.merge_local != @ir.hot_local_count(func) ||
    rewrite.get_id < 0 ||
    !@ir.hot_node_is_live(func, rewrite.get_id) {
    return false
  }
  match @ir.hot_node_get(func, rewrite.get_id).op {
    @ir.HotOp::LocalGet => ()
    _ => return false
  }
  let write_ids : Array[@ir.NodeId] = []
  for input in rewrite.inputs {
    let write_id = match input {
      SsaFullMergeInput::ExplicitWrite(write_id) => write_id
      _ => return false
    }
    if write_id < 0 ||
      !@ir.hot_node_is_live(func, write_id) ||
      @ir.hot_child_count(func, write_id) != 1 {
      return false
    }
    let write_node = @ir.hot_node_get(func, write_id)
    match write_node.op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
        if write_node.imm0 != rewrite.original_local {
          return false
        }
      _ => return false
    }
    write_ids.push(write_id)
  }

  let appended = @ir.hot_append_body_local(func, merge_ty)
  if appended != rewrite.merge_local {
    abort("full ssa merge-local append violated the prevalidated local id")
  }
  let replacement_id = @ir.hot_build_local_get(func, rewrite.merge_local)
  @ir.hot_replace_node(
    func,
    rewrite.get_id,
    @ir.hot_node_get(func, replacement_id),
  )
  @ir.hot_delete_node(func, replacement_id)
  for write_id in write_ids {
    let value_id = @ir.hot_child_get(func, write_id, 0)
    let tee_id = @ir.hot_build_local_tee(func, rewrite.merge_local, value_id)
    @ir.hot_child_set(func, write_id, 0, tee_id)
  }
  true
}

///|
fn ssa_full_try_apply_simple_explicit_merge_plan(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  plan : SsaFullRewritePlan,
) -> HotPassResult {
  if !ssa_full_plan_has_only_simple_explicit_writes(plan) {
    return HotPassResult::unchanged()
  }
  let before_revision = @ir.hot_revision_current(func)
  for rewrite in plan.merge_gets {
    if !ssa_full_apply_simple_explicit_merge_rewrite(func, rewrite) {
      return HotPassResult::unchanged()
    }
  }
  if @ir.hot_revision_current(func) == before_revision {
    return HotPassResult::unchanged()
  }
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}

///|
fn ssa_full_run(ctx : HotPassContext, func : @ir.HotFunc) -> HotPassResult {
  if !ssa_nomerge_has_local_writes(func) {
    return HotPassResult::unchanged()
  }
  if ssa_nomerge_has_exceptional_flow(func) ||
    ssa_nomerge_has_loop_param_control(func) ||
    ssa_nomerge_has_branch_heavy_void_loop_exit_mesh(func) ||
    ssa_nomerge_has_nested_cfg_sensitive_control(func) {
    return HotPassResult::unchanged()
  }
  let cfg = pass_require_cfg(ctx, func)
  let graph = @ir.local_graph_build(func, cfg)
  if !ssa_full_graph_has_merge_get(func, graph) {
    return ssa_nomerge_run(ctx, func)
  }
  let plan = ssa_full_build_merge_rewrite_plan(func, graph)
  ssa_full_try_apply_simple_explicit_merge_plan(ctx, func, plan)
}
