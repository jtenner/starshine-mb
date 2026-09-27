///|
fn dae_literal_replay_reference(
  mod_ : @lib.Module,
  original_param_counts : Array[Int],
  original_call_counts : Array[Int],
  original_active_nonself_call_counts : Array[Int],
  original_active_parameterized_nonself_call_counts : Array[Int],
  original_nonself_undropped_call_counts : Array[Int],
  original_self_call_counts : Array[Int],
  original_private_result_dead_suffix_calls_from_escaped_operand_callees : Array[
    Int,
  ],
  original_escaped_dead_suffix_call_counts : Array[Int],
  original_dead_suffix_undropped_self_calls : Array[Bool],
  original_dead_suffix_dropped_self_calls : Array[Bool],
  original_dead_suffix_block_undropped_self_calls : Array[Bool],
  original_dead_suffix_result_calls_from_undropped_self_callers : Array[Int],
  original_dead_suffix_result_calls_from_no_param_undropped_self_callers : Array[
    Int,
  ],
  original_dead_suffix_same_self_result_operand_calls : Array[Bool],
  original_dead_suffix_undropped_self_call_param_operands : Array[Bool],
  original_dead_suffix_result_other_calls : Array[Bool],
  original_dead_suffix_escaped_result_call_facts : DaeOriginalDeadSuffixEscapedResultCallFacts,
  original_dead_suffix_mutual_calls : Array[Bool],
  original_dead_suffix_calls_from_param_operand_self_result_callers : Array[Int],
  original_dead_suffix_escaped_result_operand_call_counts : Array[Int],
  original_dead_suffix_dropped_calls_from_parameterized_self_callers : Array[
    Int,
  ],
  reverse? : Bool = true,
  max_def_exclusive? : Int = -1,
) -> DaePassResult {
  let original_dead_suffix_undropped_escaped_result_calls = original_dead_suffix_escaped_result_call_facts.undropped_calls
  let original_dead_suffix_dropped_escaped_result_calls = original_dead_suffix_escaped_result_call_facts.dropped_calls
  let rewrite_original = dae_collect_original_boundary_snapshot(mod_)
  let rewrite_graph = dae_current_boundary_graph_new(mod_)
  let boundary_snapshot = rewrite_graph.snapshot
  let imported = boundary_snapshot.imported
  let defined = boundary_snapshot.defined
  let boundary_facts = boundary_snapshot.boundary_facts
  let type_indices = boundary_snapshot.type_indices
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let original_result_preservation_context = dae_original_result_preservation_context(
    original_param_counts, original_call_counts, original_active_nonself_call_counts,
    original_active_parameterized_nonself_call_counts, original_nonself_undropped_call_counts,
    original_self_call_counts, original_private_result_dead_suffix_calls_from_escaped_operand_callees,
    original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
    original_dead_suffix_dropped_self_calls, original_dead_suffix_block_undropped_self_calls,
    original_dead_suffix_result_calls_from_undropped_self_callers, original_dead_suffix_result_calls_from_no_param_undropped_self_callers,
    original_dead_suffix_same_self_result_operand_calls, original_dead_suffix_undropped_self_call_param_operands,
    original_dead_suffix_result_other_calls, original_dead_suffix_dropped_escaped_result_calls,
    original_dead_suffix_mutual_calls, original_dead_suffix_calls_from_param_operand_self_result_callers,
    original_dead_suffix_escaped_result_operand_call_counts, original_dead_suffix_dropped_calls_from_parameterized_self_callers,
  )
  let scan_limit = if max_def_exclusive >= 0 && max_def_exclusive < defined {
    max_def_exclusive
  } else {
    defined
  }
  let mut def_idx = if reverse { scan_limit - 1 } else { 0 }
  while (if reverse { def_idx >= 0 } else { def_idx < scan_limit }) {
    let callee_abs = imported + def_idx
    let boundary_candidate = match
      dae_call_boundary_candidate(boundary_facts, callee_abs) {
      Some(candidate) => candidate
      None => {
        if reverse {
          def_idx -= 1
        } else {
          def_idx += 1
        }
        continue
      }
    }
    if !boundary_candidate.owned {
      if reverse {
        def_idx -= 1
      } else {
        def_idx += 1
      }
      continue
    }
    let self_calls_anywhere = dae_count_self_calls_anywhere(
      funcs[def_idx],
      callee_abs,
    )
    if self_calls_anywhere > 0 {
      if reverse {
        def_idx -= 1
      } else {
        def_idx += 1
      }
      continue
    }
    let func_type = match
      dae_resolve_func_type(mod_, type_indices, callee_abs) {
      Some(ft) => ft
      None => {
        if reverse {
          def_idx -= 1
        } else {
          def_idx += 1
        }
        continue
      }
    }
    let @lib.FuncType(params, _) = func_type
    if params.length() == 0 || boundary_candidate.direct_call_count == 0 {
      if reverse {
        def_idx -= 1
      } else {
        def_idx += 1
      }
      continue
    }
    let @lib.Func(locals, _) = funcs[def_idx]
    let local_use = dae_local_use_for_callee(
      funcs[def_idx],
      params.length() + locals.length(),
      callee_abs,
      params.length(),
    )
    let uniform_const_params = dae_collect_uniform_const_actuals_from_current_call_facts(
      mod_,
      callee_abs,
      params.length(),
      type_indices,
      boundary_facts,
      boundary_snapshot.function_infos,
    )
    let remove = Array::make(params.length(), false)
    let const_params : Array[@lib.Instruction?] = Array::make(
      params.length(),
      None,
    )
    let mut any_const = false
    let mut has_dead_param = false
    let mut p = 0
    while p < params.length() {
      if !local_use.gets[p] {
        has_dead_param = true
      } else if !local_use.writes[p] {
        match uniform_const_params {
          Some(values) =>
            match values[p] {
              Some(value) => {
                remove[p] = true
                const_params[p] = Some(value)
                any_const = true
              }
              None => ()
            }
          None => ()
        }
      }
      p += 1
    }
    let preserve_current_result = dae_original_result_preservation_evidence_from_context(
      def_idx, original_result_preservation_context,
    )
    if any_const &&
      !has_dead_param &&
      !dae_original_result_preservation_blocks_argument_side_result_repair(
        preserve_current_result, false,
      ) &&
      def_idx <
      original_dead_suffix_calls_from_param_operand_self_result_callers.length() &&
      original_dead_suffix_calls_from_param_operand_self_result_callers[def_idx] ==
      0 &&
      def_idx < original_dead_suffix_undropped_escaped_result_calls.length() &&
      !original_dead_suffix_undropped_escaped_result_calls[def_idx] {
      let result = dae_try_rewrite_candidate(
        mod_,
        callee_abs,
        remove,
        const_params,
        local_use,
        boundary_candidate.direct_call_count,
        boundary_candidate.direct_callers,
        original=Some(rewrite_original),
        graph=Some(rewrite_graph),
      )
      if result.changed {
        return result
      }
    }
    if reverse {
      def_idx -= 1
    } else {
      def_idx += 1
    }
  }
  { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
}
