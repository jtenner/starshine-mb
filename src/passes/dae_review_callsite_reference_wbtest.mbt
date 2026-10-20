///|
/// Pre-review whole-array reconstruction control.
fn dae_review_callsite_reference(
  instrs : Array[@lib.Instruction],
  scope : Int32,
  selection : DaeStableRewriteSelection,
  callee_abs : Int32,
  remove : Array[Bool],
  entry_stack_values : Int32,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
  localization : DaeCallsiteLocalizationContext,
  traps_never_happen : Bool,
  allow_stack_carried_void_effects : Bool,
  stats~ : DaeStableRewriteStats? = None,
) -> DaeRewriteResult {
  match stats {
    Some(value) => value.scopes += 1
    None => ()
  }
  let mut current = instrs.copy()
  let mut calls_rewritten = 0
  let mut instr_idx = instrs.length()
  while instr_idx > 0 {
    instr_idx -= 1
    let instr_node = match
      dae_stable_rewrite_selected_child(selection, scope, instr_idx) {
      Some(node) => node
      None => continue
    }
    if selection.workspace.call_stamps[instr_node] == selection.generation {
      match
        dae_target_callsite_evidence(
          current[instr_idx],
          callee_abs,
          DaeTargetDirectOrReturnCall,
        ) {
        Some(_) => ()
        None => return { instrs: [], calls_rewritten, ok: false, }
      }
      let evidence = match
        dae_rewrite_callsite_with_localization_at(
          current,
          instr_idx,
          remove,
          localization.param_types,
          entry_stack_values,
          localization.first_scratch_local,
          mod_,
          func_type_indices,
          existing_scratch_local_types=localization.scratch_local_types,
          allow_stack_carried_void_effects~,
          traps_never_happen~,
        ) {
        Some(value) => value
        None => return { instrs: [], calls_rewritten, ok: false, }
      }
      localization.scratch_local_types.clear()
      localization.scratch_local_types.append(evidence.scratch_local_types)
      let mut param_idx = 0
      while param_idx < evidence.localized_params.length() &&
            param_idx < localization.localized_params.length() {
        localization.localized_params[param_idx] = localization.localized_params[param_idx] ||
          evidence.localized_params[param_idx]
        param_idx += 1
      }
      current = evidence.instrs
      calls_rewritten += 1
      match stats {
        Some(value) => value.calls += 1
        None => ()
      }
      continue
    }
    let children = match
      dae_nested_control_children_evidence(current[instr_idx], mod_) {
      Some(value) => value
      None => return { instrs: [], calls_rewritten, ok: false, }
    }
    let primary_kind = match current[instr_idx] {
      @lib.Block(_, _) => 0
      @lib.Loop(_, _) => 1
      @lib.If(_, _, _) => 2
      @lib.TryTable(_, _, _) => 4
      _ => return { instrs: [], calls_rewritten, ok: false, }
    }
    let primary_node = dae_stable_rewrite_selected_child(
      selection, instr_node, primary_kind,
    )
    let secondary_node = dae_stable_rewrite_selected_child(
      selection, instr_node, 3,
    )
    if primary_node is None && secondary_node is None {
      return { instrs: [], calls_rewritten, ok: false, }
    }
    let secondary = match secondary_node {
      Some(node) => {
        let body = match children.secondary_body {
          Some(body) => body
          None => return { instrs: [], calls_rewritten, ok: false, }
        }
        let result = dae_review_callsite_reference(
          body,
          node,
          selection,
          callee_abs,
          remove,
          children.entry_stack_values,
          mod_,
          func_type_indices,
          localization,
          traps_never_happen,
          allow_stack_carried_void_effects,
          stats~,
        )
        if !result.ok {
          return {
            instrs: [],
            calls_rewritten: calls_rewritten + result.calls_rewritten,
            ok: false,
          }
        }
        calls_rewritten += result.calls_rewritten
        Some(result.instrs)
      }
      None => children.secondary_body
    }
    let primary = match primary_node {
      Some(node) => {
        let result = dae_review_callsite_reference(
          children.primary_body,
          node,
          selection,
          callee_abs,
          remove,
          children.entry_stack_values,
          mod_,
          func_type_indices,
          localization,
          traps_never_happen,
          allow_stack_carried_void_effects,
          stats~,
        )
        if !result.ok {
          return {
            instrs: [],
            calls_rewritten: calls_rewritten + result.calls_rewritten,
            ok: false,
          }
        }
        calls_rewritten += result.calls_rewritten
        result.instrs
      }
      None => children.primary_body
    }
    current[instr_idx] = match
      dae_rebuild_nested_control_children(
        current[instr_idx],
        children,
        primary,
        secondary,
      ) {
      Some(value) => value
      None => return { instrs: [], calls_rewritten, ok: false, }
    }
    match stats {
      Some(value) => value.structured_rebuilds += 1
      None => ()
    }
  }
  { instrs: current, calls_rewritten, ok: true, }
}
