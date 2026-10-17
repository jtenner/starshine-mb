///|
fn dae_signature_plan_metadata_reference(
  original : DaeOriginalBoundarySnapshot,
  current : @lib.Module,
  graph : DaeCurrentBoundaryGraph,
  target_def : Int32,
  candidate : DaePassResult,
  effects : DaeCommitEffects,
) -> DaeRewritePlan? {
  if target_def < 0 ||
    target_def >= graph.snapshot.defined ||
    candidate.primary_def != target_def ||
    !candidate.changed ||
    dae_snapshot_module_unchanged(candidate.mod_out, current) ||
    candidate.touched.length() != graph.snapshot.defined ||
    target_def >= candidate.touched.length() ||
    !candidate.touched[target_def] {
    return None
  }
  let target_abs = graph.snapshot.imported + target_def
  let old_signature = match graph.snapshot.function_types[target_abs] {
    Some(signature) => signature
    None => return None
  }
  let next_type_indices = dae_collect_func_type_indices(candidate.mod_out)
  let replacement_signature = match
    dae_resolve_func_type(candidate.mod_out, next_type_indices, target_abs) {
    Some(signature) => signature
    None => return None
  }
  let @lib.FuncType(old_params, old_results) = old_signature
  let @lib.FuncType(next_params, next_results) = replacement_signature
  if next_params.length() > old_params.length() ||
    next_results.length() > old_results.length() {
    return None
  }
  let shared_facts : DaeBoundaryFacts = {
    original,
    graph,
    incoming_param_live_by_def: [],
    incoming_param_live_body_epochs: [],
  }
  if !dae_can_change_family_signature(shared_facts, target_abs) {
    return None
  }
  let parameter_actions : Array[DaeParameterAction] = []
  let mut parameter_changed = false
  let mut parameter_refined = false
  let mut old_parameter_idx = 0
  let mut next_parameter_idx = 0
  while old_parameter_idx < old_params.length() {
    let remaining_old = old_params.length() - old_parameter_idx
    let remaining_next = next_params.length() - next_parameter_idx
    let maps_to_next = next_parameter_idx < next_params.length() &&
      (
        old_params[old_parameter_idx] == next_params[next_parameter_idx] ||
        remaining_old == remaining_next
      )
    if maps_to_next {
      if old_params[old_parameter_idx] == next_params[next_parameter_idx] {
        parameter_actions.push(DaeKeepParameter)
      } else {
        parameter_actions.push(
          DaeRefineParameterType(next_params[next_parameter_idx]),
        )
        parameter_changed = true
        parameter_refined = true
      }
      next_parameter_idx += 1
    } else {
      parameter_actions.push(DaeRemoveParameterReplayEffects)
      parameter_changed = true
    }
    old_parameter_idx += 1
  }
  if next_parameter_idx != next_params.length() {
    return None
  }
  let result_actions = match
    dae_build_result_projection_actions(old_results, next_results) {
    Some(actions) => actions
    None => return None
  }
  let mut result_changed = false
  let mut result_removed = false
  for action in result_actions {
    match action {
      DaeKeepResult => ()
      DaeRefineResult(_) => result_changed = true
      DaeRemoveResult => {
        result_changed = true
        result_removed = true
      }
    }
  }
  if !parameter_changed && !result_changed {
    return None
  }
  let (expected_type_sec, expected_type_idxs, expected_funcs) = match
    (current.type_sec, current.func_sec, current.code_sec) {
    (Some(type_sec), Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs))) =>
      (type_sec, type_idxs, funcs)
    _ => return None
  }
  let (replacement_type_sec, replacement_type_idxs, rewritten_funcs) = match
    (
      candidate.mod_out.type_sec,
      candidate.mod_out.func_sec,
      candidate.mod_out.code_sec,
    ) {
    (Some(type_sec), Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs))) =>
      (type_sec, type_idxs, funcs)
    _ => return None
  }
  if expected_type_idxs.length() != replacement_type_idxs.length() ||
    expected_funcs.length() != rewritten_funcs.length() ||
    target_def >= replacement_type_idxs.length() ||
    target_def >= rewritten_funcs.length() {
    return None
  }
  let expected_call_identities = dae_collect_target_call_identities(
    graph.snapshot,
    target_abs,
  )
  let caller_defs : Array[Int32] = []
  for identity in expected_call_identities {
    if !caller_defs.contains(identity.caller_def) {
      caller_defs.push(identity.caller_def)
    }
  }
  let expected_callers : Array[DaeCallerEpochExpectation] = []
  let caller_rewrites : Array[DaeCallerRewritePlan] = []
  let mut expected_direct_call_count = 0
  let mut expected_return_call_count = 0
  for caller_def in caller_defs {
    if caller_def < 0 ||
      caller_def >= graph.snapshot.funcs.length() ||
      caller_def >= graph.function_epochs.length() {
      return None
    }
    let @lib.Func(_, @lib.Expr(body)) = graph.snapshot.funcs[caller_def]
    let (direct_calls, return_calls) = dae_count_active_target_call_kinds_instrs(
      body, target_abs,
    )
    let epochs = graph.function_epochs[caller_def]
    expected_callers.push({
      def_idx: caller_def,
      signature_epoch: epochs.signature_epoch,
      body_epoch: epochs.body_epoch,
      direct_calls,
      return_calls,
    })
    expected_direct_call_count += direct_calls
    expected_return_call_count += return_calls
    if expected_funcs[caller_def] != rewritten_funcs[caller_def] {
      caller_rewrites.push({
        def_idx: caller_def,
        func: rewritten_funcs[caller_def],
        calls_rewritten: direct_calls + return_calls,
        return_calls_rewritten: return_calls,
      })
    }
  }
  let @lib.Func(old_locals, _) = expected_funcs[target_def]
  let local_map : Array[Int32] = []
  let mut local_idx = 0
  while local_idx < old_params.length() + old_locals.length() {
    local_map.push(local_idx)
    local_idx += 1
  }
  if parameter_changed {
    effects.parameter_changed[target_def] = true
    effects.local_projection_changed[target_def] = true
  }
  if parameter_refined {
    effects.parameter_type_refined[target_def] = true
  }
  if result_changed {
    effects.result_changed[target_def] = true
    effects.control_refinalization_required[target_def] = true
  }
  if result_removed {
    effects.result_removed[target_def] = true
  }
  let invalidation_domains = effects.invalidation_domains.copy()
  if parameter_changed && !invalidation_domains.contains(DaeInvalidateLocals) {
    invalidation_domains.push(DaeInvalidateLocals)
  }
  let plan_effects = {
    ..effects,
    type_section_changed: expected_type_sec != replacement_type_sec,
    metadata_changed: current.name_sec != candidate.mod_out.name_sec,
    invalidation_domains,
  }
  let before_dependencies = dae_boundary_dependency_graph_new(graph)
  let candidate_graph = dae_current_boundary_graph_new(candidate.mod_out)
  let after_dependencies = dae_boundary_dependency_graph_new(candidate_graph)
  let invalidated_dependencies = dae_boundary_dependency_invalidations(
    before_dependencies,
    after_dependencies,
    plan_effects.structurally_touched,
    target_def,
    plan_effects,
  )
  let target_epochs = graph.function_epochs[target_def]
  Some({
    effects: plan_effects,
    target_def,
    target_abs,
    expected_module_epoch: graph.module_epoch,
    expected_call_epoch: graph.call_epoch,
    expected_type_epoch: graph.type_epoch,
    expected_target_signature_epoch: target_epochs.signature_epoch,
    expected_target_body_epoch: target_epochs.body_epoch,
    expected_callers,
    expected_call_identities,
    expected_direct_call_count,
    expected_return_call_count,
    parameter_actions,
    result_actions,
    old_signature,
    replacement_signature,
    caller_rewrites,
    callee_rewrite: rewritten_funcs[target_def],
    local_projection: {
      local_map,
      preserved_removed_params: Array::make(old_params.length(), false),
    },
    type_section_rewrite: {
      expected: expected_type_sec,
      replacement: replacement_type_sec,
      replacement_type_idx: replacement_type_idxs[target_def],
    },
    function_section_rewrite: {
      expected: expected_type_idxs,
      replacement: replacement_type_idxs,
    },
    touched_functions: candidate.touched,
    invalidated_dependencies,
    rewritten_funcs,
    candidate: candidate.mod_out,
    decision_reason: DaeCandidateProduced,
  })
}

///|
fn dae_signature_plan_metadata_bench(
  it : @bench.T,
  siblings : Int32,
  reference : Bool,
) -> Unit raise {
  let (input, output) = dae_signature_plan_metadata_fixture(siblings)
  let original = dae_collect_original_boundary_snapshot(input)
  let graph = dae_current_boundary_graph_new(input)
  let effects = dae_signature_plan_metadata_effects(siblings + 2)
  let candidate : DaePassResult = {
    mod_out: output,
    touched: effects.structurally_touched.copy(),
    changed: true,
    primary_def: 0,
  }
  let old_plan = dae_signature_plan_metadata_reference(
    original, input, graph, 0, candidate, effects,
  ).unwrap()
  let new_plan = dae_build_signature_rewrite_plan_from_candidate(
    original, input, graph, 0, candidate, effects,
  ).unwrap()
  assert_eq(new_plan.parameter_actions, old_plan.parameter_actions)
  assert_eq(new_plan.result_actions, old_plan.result_actions)
  assert_true(
    dae_direct_call_identities_equal(
      new_plan.expected_call_identities,
      old_plan.expected_call_identities,
    ),
  )
  let old_result = dae_apply_rewrite_plan(input, graph, old_plan)
  let new_result = dae_apply_rewrite_plan(input, graph, new_plan)
  assert_true(old_result.applied && new_result.applied)
  assert_eq(
    @binary.encode_module(new_result.result.mod_out).unwrap(),
    @binary.encode_module(old_result.result.mod_out).unwrap(),
  )
  it.bench(fn() {
    it.keep(
      if reference {
        dae_signature_plan_metadata_reference(
          original, input, graph, 0, candidate, effects,
        )
      } else {
        dae_build_signature_rewrite_plan_from_candidate(
          original, input, graph, 0, candidate, effects,
        )
      },
    )
  })
}

///|
#skip("paired native signature plan cost; dedicated performance lane")
test "bench DAE signature plan siblings=0 reference" (it : @bench.T) {
  dae_signature_plan_metadata_bench(it, 0, true)
}

///|
#skip("paired native signature plan cost; dedicated performance lane")
test "bench DAE signature plan siblings=0 bounded" (it : @bench.T) {
  dae_signature_plan_metadata_bench(it, 0, false)
}

///|
#skip("paired native signature plan cost; dedicated performance lane")
test "bench DAE signature plan siblings=32 reference" (it : @bench.T) {
  dae_signature_plan_metadata_bench(it, 32, true)
}

///|
#skip("paired native signature plan cost; dedicated performance lane")
test "bench DAE signature plan siblings=32 bounded" (it : @bench.T) {
  dae_signature_plan_metadata_bench(it, 32, false)
}
