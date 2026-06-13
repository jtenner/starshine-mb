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
  "SSA-ify local traffic for non-merge families; merge-local materialization remains fail-closed."
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
  if ssa_full_graph_has_merge_get(func, graph) {
    return HotPassResult::unchanged()
  }
  ssa_nomerge_run(ctx, func)
}
