// Frozen c474 helper closure. Exact source bodies; global function names only are changed.

///|
fn dae_boundary_syntax_frozen_function_exposure_empty() -> DaeFunctionExposure {
  {
    imported: false,
    exported: false,
    start: false,
    ref_func_body: false,
    ref_func_module: false,
    active_element: false,
    passive_element: false,
    declarative_element: false,
  }
}

///|
fn dae_boundary_syntax_frozen_function_exposure_blocks_boundary(
  exposure : DaeFunctionExposure,
) -> Bool {
  exposure.imported ||
  exposure.exported ||
  exposure.start ||
  exposure.ref_func_body ||
  exposure.ref_func_module ||
  exposure.active_element ||
  exposure.passive_element ||
  exposure.declarative_element
}

///|
fn dae_boundary_syntax_frozen_boundary_facts_new(
  mod_ : @lib.Module,
) -> DaeBoundaryFacts {
  let original = dae_boundary_syntax_frozen_collect_original_boundary_snapshot(
    mod_,
  )
  let graph = dae_current_boundary_graph_new(mod_)
  {
    original,
    graph,
    incoming_param_live_by_def: dae_collect_incoming_param_live_for_module(
      mod_,
      graph.snapshot,
    ),
    incoming_param_live_body_epochs: dae_collect_incoming_param_live_body_epochs(
      graph,
    ),
  }
}

///|
fn dae_boundary_syntax_frozen_process_work_item(
  original : DaeOriginalBoundarySnapshot,
  current : @lib.Module,
  touched : Array[Bool],
  changed : Bool,
  graph : DaeCurrentBoundaryGraph,
  dependencies : DaeBoundaryDependencyGraph,
  item : DaeWorkItem,
  diagnostics : DaeDiagnostics,
  rewrite_validation_counts~ : Array[Int32]? = None,
  numeric_result_validation_chain~ : DaeScalarValidationChain? = None,
  numeric_result_validation_work~ : DaeScalarValidationWork? = None,
) -> DaeWorkOutcome {
  diagnostics.boundaries_analyzed += 1
  if !dae_work_item_epoch_is_current(graph, item) {
    dae_diagnostics_record_reason(diagnostics, DaeStaleCandidateFacts)
    if item.target_def < 0 || item.target_def >= graph.snapshot.defined {
      return DaeWorkNoChange(DaeStaleCandidateFacts)
    }
    diagnostics.candidate_stale_retries += 1
    diagnostics.candidate_requeues += 1
    return DaeWorkRequeue([
      {
        ..dae_work_item_new(graph, dependencies, item.target_def, item.family),
        allow_immutable_global_get: item.allow_immutable_global_get,
        allow_immediate_i32_suffix_fallback: item.allow_immediate_i32_suffix_fallback,
      },
    ])
  }
  if item.family == DaeForwardingWork {
    match
      dae_boundary_syntax_frozen_run_forwarded_param_component_transaction_with_graph(
        original,
        current,
        touched,
        item.component_members,
        graph,
        dependencies,
      ) {
      Some(commit) => {
        dae_diagnostics_record_commit_effects(diagnostics, commit.effects)
        dae_diagnostics_record_applied_effects(diagnostics, commit.effects)
        return DaeWorkCommitted({
          mod_out: commit.candidate.mod_out,
          touched: dae_merge_touched(touched, commit.candidate.touched),
          changed: true,
          applied: true,
          primary_def: item.target_def,
          effects: commit.effects,
        })
      }
      None => {
        let component_touched = Array::make(graph.snapshot.defined, false)
        for def_idx in item.component_members {
          if def_idx >= 0 && def_idx < component_touched.length() {
            component_touched[def_idx] = true
          }
        }
        match
          dae_run_forwarded_param_scc_transaction(current, component_touched) {
          Some(candidate) => {
            let result : DaePassResult = {
              mod_out: candidate.mod_out,
              touched: candidate.touched,
              changed: true,
              primary_def: item.target_def,
            }
            let mut effects = dae_commit_effects_empty(graph.snapshot.defined)
            for def_idx in candidate.defs {
              effects = dae_commit_effects_merge(
                effects,
                dae_work_item_candidate_effects(
                  current,
                  graph,
                  dae_work_item_new(
                    graph,
                    dependencies,
                    def_idx,
                    DaeUnusedParameterWork,
                  ),
                  result,
                ),
              )
            }
            dae_diagnostics_record_commit_effects(diagnostics, effects)
            dae_diagnostics_record_applied_effects(diagnostics, effects)
            return DaeWorkCommitted({
              mod_out: candidate.mod_out,
              touched: dae_merge_touched(touched, candidate.touched),
              changed: true,
              applied: true,
              primary_def: item.target_def,
              effects,
            })
          }
          None => {
            dae_diagnostics_record_reason(diagnostics, DaeNoStrictImprovement)
            return DaeWorkNoChange(DaeNoStrictImprovement)
          }
        }
      }
    }
  }
  let producer_effects_report : Array[DaeCommitEffects] = []
  let mut checked_candidate : (@lib.Module, @lib.Module)? = None
  let produced : (DaePassResult, DaeCommitEffects)? = match item.family {
    DaeUnusedParameterWork
    | DaeLocalizationRetryWork
    | DaePostCleanupBoundaryRevisitWork => {
      let candidate = dae_boundary_syntax_frozen_try_rewrite_unread_params_for_def_with_facts(
        current,
        item.target_def,
        graph.snapshot.call_facts,
        allow_stack_carried_void_effects=true,
        require_localization_retry=item.family == DaeLocalizationRetryWork,
        type_indices_override=Some(graph.snapshot.type_indices),
        original=Some(original),
        graph=Some(graph),
        producer_effects_report~,
      )
      match producer_effects_report.get(0) {
        Some(producer_effects) => Some((candidate, producer_effects))
        None if !candidate.changed =>
          Some((candidate, dae_commit_effects_empty(graph.snapshot.defined)))
        None => None
      }
    }
    DaeUniformActualWork => {
      let candidate = if item.uniform_values.length() > 0 {
        let report : Array[(@lib.Module, @lib.Module)] = []
        let candidate = dae_try_rewrite_uniform_values_def_with_facts_once(
          current,
          original,
          graph,
          item.target_def,
          item.uniform_values,
          checked_candidate_report=Some(report),
        )
        checked_candidate = report.get(0)
        candidate
      } else {
        let report : Array[(@lib.Module, @lib.Module)] = []
        let candidate = dae_boundary_syntax_frozen_try_rewrite_exact_literal_def_with_facts_once(
          current,
          item.target_def,
          graph.snapshot.call_facts,
          allow_immutable_global_get=item.allow_immutable_global_get,
          allow_immediate_i32_suffix_fallback=item.allow_immediate_i32_suffix_fallback,
          original=Some(original),
          graph=Some(graph),
          checked_candidate_report=Some(report),
          rewrite_validation_counts~,
        )
        checked_candidate = report.get(0)
        candidate
      }
      Some(
        (
          candidate,
          dae_work_item_candidate_effects(current, graph, item, candidate),
        ),
      )
    }
    DaeGcParameterRefinementWork => {
      let candidate = dae_try_refine_direct_gc_types_for_def_with_facts(
        current,
        item.target_def,
        graph.snapshot.call_facts,
        true,
        true,
      )
      Some(
        (
          candidate,
          dae_work_item_candidate_effects(current, graph, item, candidate),
        ),
      )
    }
    DaeGcResultRefinementWork => {
      let candidate = dae_try_refine_direct_gc_types_for_def_with_facts(
        current,
        item.target_def,
        graph.snapshot.call_facts,
        false,
        true,
      )
      Some(
        (
          candidate,
          dae_work_item_candidate_effects(current, graph, item, candidate),
        ),
      )
    }
    DaeDroppedResultWork => {
      let candidate = dae_boundary_syntax_frozen_try_remove_dropped_result_def_with_facts(
        current,
        item.target_def,
        graph.snapshot.call_facts,
        boundary_facts=Some({
          original,
          graph,
          incoming_param_live_by_def: [],
          incoming_param_live_body_epochs: [],
        }),
      )
      Some(
        (
          candidate,
          dae_work_item_candidate_effects(current, graph, item, candidate),
        ),
      )
    }
    DaeControlReconstructionWork | DaeTypeRepairRetryWork => {
      let candidate = dae_try_refine_direct_gc_types_for_def_with_facts(
        current,
        item.target_def,
        graph.snapshot.call_facts,
        false,
        true,
      )
      Some(
        (
          candidate,
          dae_work_item_candidate_effects(current, graph, item, candidate),
        ),
      )
    }
    DaeForwardingWork | DaeBodyCleanupWork => None
  }
  match produced {
    None => {
      dae_diagnostics_record_reason(diagnostics, DaeNoStrictImprovement)
      DaeWorkDeferred(DaeNoStrictImprovement)
    }
    Some((candidate, _)) if !dae_should_scan_work_item_candidate_effects(
        candidate,
      ) => {
      dae_diagnostics_record_reason(diagnostics, DaeNoStrictImprovement)
      DaeWorkNoChange(DaeNoStrictImprovement)
    }
    Some((candidate, producer_effects)) => {
      let allows_family_fallback = item.family == DaeControlReconstructionWork ||
        item.family == DaeTypeRepairRetryWork
      let signature_plan = dae_build_signature_rewrite_plan_from_candidate(
        original,
        current,
        graph,
        item.target_def,
        candidate,
        producer_effects,
      )
      let plan_application = match signature_plan {
        Some(plan) =>
          dae_apply_rewrite_plan(
            current,
            graph,
            plan,
            checked_candidate~,
            rewrite_validation_counts~,
            numeric_result_validation_chain=if item.family ==
              DaeDroppedResultWork {
              numeric_result_validation_chain
            } else {
              None
            },
            numeric_result_validation_work~,
          )
        None => {
          if !allows_family_fallback {
            dae_diagnostics_record_reason(diagnostics, DaeNoStrictImprovement)
            return DaeWorkNoChange(DaeNoStrictImprovement)
          }
          if !dae_family_fallback_candidate_is_body_only(
              graph,
              candidate.mod_out,
            ) {
            dae_diagnostics_record_reason(
              diagnostics,
              DaeTypeReconstructionUnavailable,
            )
            return DaeWorkNoChange(DaeTypeReconstructionUnavailable)
          }
          let plan = match
            dae_build_family_rewrite_plan(
              original,
              current,
              graph,
              item.target_def,
              candidate,
              effects=Some(producer_effects),
            ) {
            Some(plan) => plan
            None => {
              dae_diagnostics_record_reason(diagnostics, DaeNoStrictImprovement)
              return DaeWorkNoChange(DaeNoStrictImprovement)
            }
          }
          dae_apply_family_rewrite_plan(current, graph, plan)
        }
      }
      if plan_application.applied {
        dae_diagnostics_record_commit_effects(
          diagnostics,
          plan_application.effects,
        )
        dae_diagnostics_record_applied_effects(
          diagnostics,
          plan_application.effects,
        )
        DaeWorkCommitted({
          mod_out: plan_application.result.mod_out,
          touched: dae_merge_touched(touched, plan_application.result.touched),
          changed: changed || plan_application.result.changed,
          applied: true,
          primary_def: plan_application.result.primary_def,
          effects: plan_application.effects,
        })
      } else {
        if plan_application.reason == DaeValidationRollback {
          diagnostics.validation_rollbacks += 1
        }
        dae_diagnostics_record_reason(diagnostics, plan_application.reason)
        DaeWorkNoChange(plan_application.reason)
      }
    }
  }
}

///|
fn dae_boundary_syntax_frozen_apply_commit_followups(
  original : DaeOriginalBoundarySnapshot,
  application : DaeCoreResultApplication,
  committed_item : DaeWorkItem,
  diagnostics : DaeDiagnostics,
) -> DaeCoreResultApplication {
  let mut current = application.mod_out
  let mut touched = application.touched
  let mut changed = application.changed
  let mut effects = application.effects
  let graph = dae_current_boundary_graph_new(current)
  let mut dependencies = dae_boundary_dependency_graph_new(graph)
  let queue = dae_followup_work_items_for_commit(
    graph,
    dependencies,
    committed_item,
    application.effects,
  )
  let mut cursor = 0
  while cursor < queue.length() {
    let item = queue[cursor]
    cursor += 1
    match
      dae_boundary_syntax_frozen_process_work_item(
        original, current, touched, changed, graph, dependencies, item, diagnostics,
      ) {
      DaeWorkCommitted(repair) => {
        current = repair.mod_out
        touched = repair.touched
        changed = repair.changed
        effects = dae_commit_effects_merge(effects, repair.effects)
        dae_current_boundary_graph_refresh(graph, current)
        dependencies = dae_boundary_dependency_graph_new(graph)
      }
      DaeWorkRequeue(items) =>
        for refreshed in items {
          queue.push(refreshed)
        }
      DaeWorkNoChange(_) | DaeWorkDeferred(_) => ()
    }
  }
  {
    mod_out: current,
    touched,
    changed,
    applied: application.applied,
    primary_def: application.primary_def,
    effects,
  }
}

///|
fn dae_boundary_syntax_frozen_imported_func_count(mod_ : @lib.Module) -> Int32 {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn dae_boundary_syntax_frozen_defined_func_count(mod_ : @lib.Module) -> Int32 {
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs.length()
    None => 0
  }
}

///|
fn dae_boundary_syntax_frozen_func_idx_slot(idx : @lib.FuncIdx) -> Int32 {
  let @lib.FuncIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn dae_boundary_syntax_frozen_local_idx_slot(idx : @lib.LocalIdx) -> Int32 {
  let @lib.LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn dae_boundary_syntax_frozen_collect_func_type_indices(
  mod_ : @lib.Module,
) -> Array[@lib.TypeIdx] {
  let out : Array[@lib.TypeIdx] = []
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(type_idx)) => out.push(type_idx)
          _ => ()
        }
      }
    None => ()
  }
  match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => out.append(type_idxs)
    None => ()
  }
  out
}

///|
fn dae_boundary_syntax_frozen_type_sec_subtype(
  type_sec : @lib.TypeSec,
  type_idx : @lib.TypeIdx,
  type_visits~ : Array[Int32]? = None,
) -> @lib.SubType? {
  let target = match type_idx {
    @lib.TypeIdx(raw) => raw.reinterpret_as_int()
    @lib.RecIdx(_) => return None
  }
  if target < 0 {
    return None
  }
  let @lib.TypeSec(rec_types) = type_sec
  let mut flat_idx = 0
  for rec_type in rec_types {
    match type_visits {
      Some(count) => count[0] += 1
      None => ()
    }
    match rec_type {
      @lib.SingleRecType(subtype) => {
        if flat_idx == target {
          return Some(subtype)
        }
        flat_idx += 1
      }
      @lib.GroupRecType(group) => {
        let group_end = flat_idx + group.length()
        if target >= flat_idx && target < group_end {
          return Some(group[target - flat_idx])
        }
        flat_idx = group_end
      }
    }
  }
  None
}

///|
fn dae_boundary_syntax_frozen_type_sec_func_type(
  type_sec : @lib.TypeSec,
  type_idx : @lib.TypeIdx,
  type_visits~ : Array[Int32]? = None,
) -> @lib.FuncType? {
  match
    dae_boundary_syntax_frozen_type_sec_subtype(
      type_sec,
      type_idx,
      type_visits~,
    ) {
    Some(subtype) =>
      match subtype.get_comptype() {
        @lib.FuncCompType(params, results) =>
          Some(@lib.FuncType::new(params, results))
        _ => None
      }
    None => None
  }
}

///|
fn dae_boundary_syntax_frozen_control_block_type_signature_evidence_from_type_sec(
  block_type : @lib.BlockType,
  type_sec : @lib.TypeSec?,
) -> DaeControlBlockTypeSignatureEvidence? {
  match block_type {
    @lib.VoidBlockType =>
      Some({
        params: [],
        results: [],
        input_count: 0,
        output_count: 0,
        type_idx: None,
      })
    @lib.ValTypeBlockType(result) =>
      Some({
        params: [],
        results: [result],
        input_count: 0,
        output_count: 1,
        type_idx: None,
      })
    @lib.TypeIdxBlockType(type_idx) =>
      match type_sec {
        Some(type_sec) =>
          match
            dae_boundary_syntax_frozen_type_sec_func_type(type_sec, type_idx) {
            Some(@lib.FuncType(params, results)) =>
              Some({
                params,
                results,
                input_count: params.length(),
                output_count: results.length(),
                type_idx: Some(type_idx),
              })
            None => None
          }
        None => None
      }
  }
}

///|
fn dae_boundary_syntax_frozen_control_block_type_signature_evidence(
  block_type : @lib.BlockType,
  mod_ : @lib.Module,
) -> DaeControlBlockTypeSignatureEvidence? {
  dae_boundary_syntax_frozen_control_block_type_signature_evidence_from_type_sec(
    block_type,
    mod_.type_sec,
  )
}

///|
fn dae_boundary_syntax_frozen_resolve_func_type(
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
  func_abs : Int32,
) -> @lib.FuncType? {
  if func_abs < 0 || func_abs >= func_type_indices.length() {
    return None
  }
  match mod_.type_sec {
    Some(type_sec) =>
      dae_boundary_syntax_frozen_type_sec_func_type(
        type_sec,
        func_type_indices[func_abs],
      )
    None => None
  }
}

///|
fn dae_boundary_syntax_frozen_mark_ref_func_exposure_instrs(
  instrs : Array[@lib.Instruction],
  exposure : Array[DaeFunctionExposure],
  from_module_code : Bool,
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.RefFunc(func_idx) => {
        let slot = dae_boundary_syntax_frozen_func_idx_slot(func_idx)
        if slot >= 0 && slot < exposure.length() {
          if from_module_code {
            exposure[slot].ref_func_module = true
          } else {
            exposure[slot].ref_func_body = true
          }
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        dae_boundary_syntax_frozen_mark_ref_func_exposure_instrs(
          body, exposure, from_module_code,
        )
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        dae_boundary_syntax_frozen_mark_ref_func_exposure_instrs(
          body, exposure, from_module_code,
        )
        for catch_ in catches {
          match catch_ {
            @lib.LegacyCatch(_, @lib.Expr(catch_body))
            | @lib.LegacyCatchAll(@lib.Expr(catch_body)) =>
              dae_boundary_syntax_frozen_mark_ref_func_exposure_instrs(
                catch_body, exposure, from_module_code,
              )
          }
        }
      }
      @lib.If(_, then_body, Some(else_body)) => {
        dae_boundary_syntax_frozen_mark_ref_func_exposure_instrs(
          then_body, exposure, from_module_code,
        )
        dae_boundary_syntax_frozen_mark_ref_func_exposure_instrs(
          else_body, exposure, from_module_code,
        )
      }
      @lib.If(_, then_body, None) =>
        dae_boundary_syntax_frozen_mark_ref_func_exposure_instrs(
          then_body, exposure, from_module_code,
        )
      _ => ()
    }
  }
}

///|
fn dae_boundary_syntax_frozen_mark_elem_exposure(
  mode : @lib.ElemMode,
  kind : @lib.ElemKind,
  exposure : Array[DaeFunctionExposure],
) -> Unit {
  let mark_slot = fn(slot : Int32) {
    if slot < 0 || slot >= exposure.length() {
      return
    }
    match mode {
      @lib.Active(_, _) => exposure[slot].active_element = true
      @lib.Passive => exposure[slot].passive_element = true
      @lib.Declarative => exposure[slot].declarative_element = true
    }
  }
  match kind {
    @lib.FuncsElemKind(funcs) =>
      for func_idx in funcs {
        mark_slot(dae_boundary_syntax_frozen_func_idx_slot(func_idx))
      }
    @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
      for expr in exprs {
        let @lib.Expr(instrs) = expr
        for instr in instrs {
          match instr {
            @lib.RefFunc(func_idx) =>
              mark_slot(dae_boundary_syntax_frozen_func_idx_slot(func_idx))
            _ => ()
          }
        }
        dae_boundary_syntax_frozen_mark_ref_func_exposure_instrs(
          instrs, exposure, true,
        )
      }
  }
}

///|
fn dae_boundary_syntax_frozen_collect_original_exposure(
  mod_ : @lib.Module,
  total_funcs : Int32,
  type_indices : Array[@lib.TypeIdx],
) -> Array[DaeFunctionExposure] {
  let exposure : Array[DaeFunctionExposure] = []
  let mut idx = 0
  while idx < total_funcs {
    exposure.push(dae_boundary_syntax_frozen_function_exposure_empty())
    idx += 1
  }
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let mut import_idx = 0
  while import_idx < imported && import_idx < exposure.length() {
    exposure[import_idx].imported = true
    import_idx += 1
  }
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for export_ in exports {
        match export_ {
          @lib.Export(_, @lib.FuncExternIdx(func_idx)) => {
            let slot = dae_boundary_syntax_frozen_func_idx_slot(func_idx)
            if slot >= 0 && slot < exposure.length() {
              exposure[slot].exported = true
            }
          }
          _ => ()
        }
      }
    None => ()
  }
  match mod_.start_sec {
    Some(@lib.StartSec(func_idx)) => {
      let slot = dae_boundary_syntax_frozen_func_idx_slot(func_idx)
      if slot >= 0 && slot < exposure.length() {
        exposure[slot].start = true
      }
    }
    None => ()
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, @lib.Expr(body)) = func
        dae_boundary_syntax_frozen_mark_ref_func_exposure_instrs(
          body, exposure, false,
        )
      }
    None => ()
  }
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      for global_ in globals {
        let @lib.Global(_, @lib.Expr(init)) = global_
        dae_boundary_syntax_frozen_mark_ref_func_exposure_instrs(
          init, exposure, true,
        )
      }
    None => ()
  }
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) =>
      for table in tables {
        match table {
          @lib.Table(_, Some(@lib.Expr(init))) =>
            dae_boundary_syntax_frozen_mark_ref_func_exposure_instrs(
              init, exposure, true,
            )
          _ => ()
        }
      }
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      for elem in elems {
        let @lib.Elem(mode, kind) = elem
        dae_boundary_syntax_frozen_mark_elem_exposure(mode, kind, exposure)
      }
    None => ()
  }
  ignore(type_indices)
  exposure
}

///|
fn dae_boundary_syntax_frozen_exposure_to_escaped(
  exposure : Array[DaeFunctionExposure],
) -> Array[Bool] {
  let escaped = Array::make(exposure.length(), false)
  let mut idx = 0
  while idx < exposure.length() {
    escaped[idx] = dae_boundary_syntax_frozen_function_exposure_blocks_boundary(
      exposure[idx],
    )
    idx += 1
  }
  escaped
}

///|
fn dae_boundary_syntax_frozen_adjacent_param_forward_evidence(
  instrs : Array[@lib.Instruction],
  call_idx : Int32,
  param_count : Int32,
) -> DaeAdjacentParamForwardEvidence? {
  if call_idx < 0 || call_idx > instrs.length() || param_count < 0 {
    return None
  }
  let start = call_idx - param_count
  if start < 0 {
    return None
  }
  let mut p = 0
  while p < param_count {
    match instrs[start + p] {
      @lib.LocalGet(local_idx) if dae_boundary_syntax_frozen_local_idx_slot(
          local_idx,
        ) ==
        p => ()
      _ => return None
    }
    p += 1
  }
  Some({ start, end: call_idx, param_count, })
}

///|
fn dae_boundary_syntax_frozen_instr_result_arity_from_block_type(
  block_type : @lib.BlockType,
) -> Int32? {
  match block_type {
    @lib.VoidBlockType => Some(0)
    @lib.ValTypeBlockType(_) => Some(1)
    @lib.TypeIdxBlockType(_) => None
  }
}

///|
fn dae_boundary_syntax_frozen_instr_stack_effect_from_block_type(
  block_type : @lib.BlockType,
  mod_ : @lib.Module,
) -> (Int32, Int32)? {
  match
    dae_boundary_syntax_frozen_control_block_type_signature_evidence(
      block_type, mod_,
    ) {
    Some(evidence) => Some((evidence.input_count, evidence.output_count))
    None => None
  }
}

///|
fn dae_boundary_syntax_frozen_instr_stack_effect(
  instr : @lib.Instruction,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> (Int32, Int32)? {
  match instr {
    @lib.Unreachable | @lib.Nop => Some((0, 0))
    @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_)
    | @lib.V128Const(_)
    | @lib.RefNull(_)
    | @lib.RefFunc(_)
    | @lib.StringConst(_)
    | @lib.StructNewDefault(_)
    | @lib.GlobalGet(_)
    | @lib.LocalGet(_)
    | @lib.TableSize(_)
    | @lib.MemorySize(_) => Some((0, 1))
    @lib.StructNew(type_idx)
    | @lib.StructNewDesc(type_idx) as allocation_instr =>
      match mod_.type_sec {
        Some(type_sec) =>
          match
            dae_boundary_syntax_frozen_type_sec_subtype(type_sec, type_idx) {
            Some(subtype) =>
              match subtype.get_comptype() {
                @lib.StructCompType(fields) => {
                  let descriptor_count = match allocation_instr {
                    @lib.StructNewDesc(_) => 1
                    _ => 0
                  }
                  Some((fields.length() + descriptor_count, 1))
                }
                _ => None
              }
            None => None
          }
        None => None
      }
    @lib.StructNewDefaultDesc(_) => Some((1, 1))
    @lib.ArrayNew(_) => Some((2, 1))
    @lib.ArrayNewDefault(_) => Some((1, 1))
    @lib.ArrayNewFixed(_, @lib.U32(raw_len)) =>
      Some((raw_len.reinterpret_as_int(), 1))
    @lib.LocalSet(_) | @lib.GlobalSet(_) => Some((1, 0))
    @lib.LocalTee(_) => Some((1, 1))
    @lib.Drop => Some((1, 0))
    @lib.Select(_)
    | @lib.StringViewWtf16Slice
    | @lib.StringNewUtf8Array
    | @lib.StringNewWtf16Array
    | @lib.StringNewLossyUtf8Array
    | @lib.StringNewWtf8Array => Some((3, 1))
    @lib.I32Eqz
    | @lib.I64Eqz
    | @lib.RefIsNull
    | @lib.RefAsNonNull
    | @lib.RefGetDesc(_)
    | @lib.RefCast(_, _, _)
    | @lib.StringAsWtf16
    | @lib.I32Clz
    | @lib.I32Ctz
    | @lib.I32Popcnt
    | @lib.I64Clz
    | @lib.I64Ctz
    | @lib.I64Popcnt
    | @lib.F32Abs
    | @lib.F32Neg
    | @lib.F32Ceil
    | @lib.F32Floor
    | @lib.F32Trunc
    | @lib.F32Nearest
    | @lib.F32Sqrt
    | @lib.F64Abs
    | @lib.F64Neg
    | @lib.F64Ceil
    | @lib.F64Floor
    | @lib.F64Trunc
    | @lib.F64Nearest
    | @lib.F64Sqrt
    | @lib.I32WrapI64
    | @lib.I64ExtendI32S
    | @lib.I64ExtendI32U
    | @lib.F32ConvertI32S
    | @lib.F32ConvertI32U
    | @lib.F32ConvertI64S
    | @lib.F32ConvertI64U
    | @lib.F32DemoteF64
    | @lib.F64ConvertI32S
    | @lib.F64ConvertI32U
    | @lib.F64ConvertI64S
    | @lib.F64ConvertI64U
    | @lib.F64PromoteF32
    | @lib.I32ReinterpretF32
    | @lib.I64ReinterpretF64
    | @lib.F32ReinterpretI32
    | @lib.F64ReinterpretI64
    | @lib.I32Extend8S
    | @lib.I32Extend16S
    | @lib.I64Extend8S
    | @lib.I64Extend16S
    | @lib.I64Extend32S
    | @lib.AnyConvertExtern
    | @lib.ExternConvertAny
    | @lib.RefI31
    | @lib.I31GetS
    | @lib.I31GetU
    | @lib.I32TruncSatF32S
    | @lib.I32TruncSatF32U
    | @lib.I32TruncSatF64S
    | @lib.I32TruncSatF64U
    | @lib.I64TruncSatF32S
    | @lib.I64TruncSatF32U
    | @lib.I64TruncSatF64S
    | @lib.I64TruncSatF64U
    | @lib.I32Load(_)
    | @lib.I64Load(_)
    | @lib.F32Load(_)
    | @lib.F64Load(_)
    | @lib.I32Load8S(_)
    | @lib.I32Load8U(_)
    | @lib.I32Load16S(_)
    | @lib.I32Load16U(_)
    | @lib.I64Load8S(_)
    | @lib.I64Load8U(_)
    | @lib.I64Load16S(_)
    | @lib.I64Load16U(_)
    | @lib.I64Load32S(_)
    | @lib.I64Load32U(_)
    | @lib.StructGet(_, _)
    | @lib.StructGetS(_, _)
    | @lib.StructGetU(_, _)
    | @lib.StructAtomicGet(_, _, _)
    | @lib.StructAtomicGetS(_, _, _)
    | @lib.StructAtomicGetU(_, _, _)
    | @lib.MemoryGrow(_)
    | @lib.TableGet(_) => Some((1, 1))
    @lib.RefEq
    | @lib.I32Eq
    | @lib.I32Ne
    | @lib.I32LtS
    | @lib.I32LtU
    | @lib.I32GtS
    | @lib.I32GtU
    | @lib.I32LeS
    | @lib.I32LeU
    | @lib.I32GeS
    | @lib.I32GeU
    | @lib.I64Eq
    | @lib.I64Ne
    | @lib.I64LtS
    | @lib.I64LtU
    | @lib.I64GtS
    | @lib.I64GtU
    | @lib.I64LeS
    | @lib.I64LeU
    | @lib.I64GeS
    | @lib.I64GeU
    | @lib.F32Eq
    | @lib.F32Ne
    | @lib.F32Lt
    | @lib.F32Gt
    | @lib.F32Le
    | @lib.F32Ge
    | @lib.F64Eq
    | @lib.F64Ne
    | @lib.F64Lt
    | @lib.F64Gt
    | @lib.F64Le
    | @lib.F64Ge
    | @lib.I32Add
    | @lib.I32Sub
    | @lib.I32Mul
    | @lib.I32DivS
    | @lib.I32DivU
    | @lib.I32RemS
    | @lib.I32RemU
    | @lib.I32And
    | @lib.I32Or
    | @lib.I32Xor
    | @lib.I32Shl
    | @lib.I32ShrS
    | @lib.I32ShrU
    | @lib.I32Rotl
    | @lib.I32Rotr
    | @lib.I64Add
    | @lib.I64Sub
    | @lib.I64Mul
    | @lib.I64DivS
    | @lib.I64DivU
    | @lib.I64RemS
    | @lib.I64RemU
    | @lib.I64And
    | @lib.I64Or
    | @lib.I64Xor
    | @lib.I64Shl
    | @lib.I64ShrS
    | @lib.I64ShrU
    | @lib.I64Rotl
    | @lib.I64Rotr
    | @lib.F32Add
    | @lib.F32Sub
    | @lib.F32Mul
    | @lib.F32Div
    | @lib.F32Min
    | @lib.F32Max
    | @lib.F32Copysign
    | @lib.F64Add
    | @lib.F64Sub
    | @lib.F64Mul
    | @lib.F64Div
    | @lib.F64Min
    | @lib.F64Max
    | @lib.F64Copysign
    | @lib.ArrayGet(_)
    | @lib.ArrayGetS(_)
    | @lib.ArrayGetU(_)
    | @lib.ArrayAtomicGet(_, _)
    | @lib.ArrayAtomicGetS(_, _)
    | @lib.ArrayAtomicGetU(_, _)
    | @lib.RefCastDescEq(_, _, _)
    | @lib.StringConcat
    | @lib.TableGrow(_) => Some((2, 1))
    @lib.Call(func_idx) | @lib.ReturnCall(func_idx) => {
      let slot = dae_boundary_syntax_frozen_func_idx_slot(func_idx)
      match
        dae_boundary_syntax_frozen_resolve_func_type(
          mod_, func_type_indices, slot,
        ) {
        Some(@lib.FuncType(params, results)) =>
          Some((params.length(), results.length()))
        None => None
      }
    }
    @lib.CallIndirect(type_idx, _) | @lib.ReturnCallIndirect(type_idx, _) =>
      match mod_.type_sec {
        Some(type_sec) =>
          match
            dae_boundary_syntax_frozen_type_sec_func_type(type_sec, type_idx) {
            Some(@lib.FuncType(params, results)) =>
              Some((params.length() + 1, results.length()))
            None => None
          }
        None => None
      }
    @lib.CallRef(type_idx) | @lib.ReturnCallRef(type_idx) =>
      match mod_.type_sec {
        Some(type_sec) =>
          match
            dae_boundary_syntax_frozen_type_sec_func_type(type_sec, type_idx) {
            Some(@lib.FuncType(params, results)) =>
              Some((params.length() + 1, results.length()))
            None => None
          }
        None => None
      }
    @lib.Block(block_type, _)
    | @lib.Loop(block_type, _)
    | @lib.TryTable(block_type, _, _)
    | @lib.Try(block_type, _, _, _) =>
      dae_boundary_syntax_frozen_instr_stack_effect_from_block_type(
        block_type, mod_,
      )
    @lib.If(block_type, _, _) =>
      match
        dae_boundary_syntax_frozen_instr_stack_effect_from_block_type(
          block_type, mod_,
        ) {
        Some((inputs, outputs)) => Some((inputs + 1, outputs))
        None => None
      }
    _ => None
  }
}

///|
fn dae_boundary_syntax_frozen_try_rewrite_verified_materialized_const_suffix_candidate(
  mod_ : @lib.Module,
  callee_abs : Int32,
  params : Array[@lib.ValType],
  expected_suffix : Array[@lib.Instruction],
  local_use : DaeLocalUse,
  verified_calls : Int32,
  verified_callers : Array[Int32],
) -> DaePassResult {
  if verified_calls <= 0 ||
    expected_suffix.length() <= 0 ||
    expected_suffix.length() > params.length() ||
    expected_suffix.any(fn(instr) { !dae_instr_is_materializable_const(instr) }) {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let graph = dae_current_boundary_graph_new(mod_)
  if callee_abs < 0 || callee_abs >= graph.snapshot.function_types.length() {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let current_params = match graph.snapshot.function_types[callee_abs] {
    Some(@lib.FuncType(current_params, _)) => current_params
    _ => return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  if current_params != params {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let suffix_start = params.length() - expected_suffix.length()
  let remove = Array::make(params.length(), false)
  let const_params : Array[@lib.Instruction?] = Array::make(
    params.length(),
    None,
  )
  let mut suffix_idx = 0
  while suffix_idx < expected_suffix.length() {
    remove[suffix_start + suffix_idx] = true
    const_params[suffix_start + suffix_idx] = Some(expected_suffix[suffix_idx])
    suffix_idx += 1
  }
  match
    dae_build_scalar_unused_param_rewrite_plan(
      mod_,
      dae_boundary_syntax_frozen_collect_original_boundary_snapshot(mod_),
      graph,
      callee_abs,
      remove,
      local_use,
      verified_calls,
      verified_callers,
      materialized_params=Some(const_params),
      verified_materialized_suffix=Some(expected_suffix),
    ) {
    Some(plan) => {
      let application = dae_apply_rewrite_plan(mod_, graph, plan)
      if application.applied {
        application.result
      } else {
        { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
      }
    }
    None => { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
}

///|
fn dae_boundary_syntax_frozen_try_rewrite_candidate(
  mod_ : @lib.Module,
  callee_abs : Int32,
  remove : Array[Bool],
  const_params : Array[@lib.Instruction?],
  local_use : DaeLocalUse,
  direct_call_count : Int32,
  direct_caller_defs : Array[Int32],
  allow_stack_carried_void_effects~ : Bool = false,
  original~ : DaeOriginalBoundarySnapshot? = None,
  graph~ : DaeCurrentBoundaryGraph? = None,
  entry_live~ : Array[Bool]? = None,
  checked_candidate_report~ : Array[(@lib.Module, @lib.Module)]? = None,
  rewrite_validation_counts~ : Array[Int32]? = None,
  scalar_validation_chain~ : DaeScalarValidationChain? = None,
  scalar_validation_work~ : DaeScalarValidationWork? = None,
) -> DaePassResult {
  let active_original = match original {
    Some(original) => original
    None => dae_boundary_syntax_frozen_collect_original_boundary_snapshot(mod_)
  }
  let active_graph = match graph {
    Some(graph) => graph
    None => dae_current_boundary_graph_new(mod_)
  }
  match
    dae_build_scalar_unused_param_rewrite_plan(
      mod_,
      active_original,
      active_graph,
      callee_abs,
      remove,
      local_use,
      direct_call_count,
      direct_caller_defs,
      entry_live~,
      materialized_params=Some(const_params),
      allow_stack_carried_void_effects~,
    ) {
    Some(plan) => {
      let application = dae_apply_rewrite_plan(
        mod_,
        active_graph,
        plan,
        rewrite_validation_counts~,
        scalar_validation_chain~,
        scalar_validation_work~,
      )
      if application.applied {
        match checked_candidate_report {
          Some(report) => report.push((mod_, application.result.mod_out))
          None => ()
        }
      }
      application.result
    }
    None => { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
}

///|
fn dae_boundary_syntax_frozen_try_rewrite_uniform_ref_null_callee_from_selected_callers_with_facts(
  mod_ : @lib.Module,
  caller_defs : Array[Int32],
  imported : Int32,
  defined : Int32,
  total : Int32,
  type_indices : Array[@lib.TypeIdx],
  boundary_facts : DaeCallBoundaryFacts,
  original~ : DaeOriginalBoundarySnapshot? = None,
  graph~ : DaeCurrentBoundaryGraph? = None,
) -> DaePassResult {
  if caller_defs.length() == 0 {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let candidates = Array::make(defined, false)
  for caller_def in caller_defs {
    if caller_def < 0 || caller_def >= funcs.length() {
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
    }
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    let callees : Array[Int32] = []
    dae_collect_direct_call_targets_anywhere(body, imported, defined, callees)
    for callee_def in callees {
      if callee_def >= 0 && callee_def < candidates.length() {
        candidates[callee_def] = true
      }
    }
  }
  for callee_def = 0
      callee_def < candidates.length()
      callee_def = callee_def + 1 {
    if !candidates[callee_def] {
      continue
    }
    let callee_abs = imported + callee_def
    if callee_abs < 0 ||
      callee_abs >= total ||
      boundary_facts.escaped[callee_abs] ||
      boundary_facts.tail_calls[callee_abs] ||
      boundary_facts.direct_calls[callee_abs] <= 0 {
      continue
    }
    let func_type = match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, callee_abs,
      ) {
      Some(func_type) => func_type
      None => continue
    }
    let @lib.FuncType(params, _) = func_type
    if params.length() == 0 {
      continue
    }
    let @lib.Func(locals, _) = funcs[callee_def]
    let local_use = dae_local_use_for_callee(
      funcs[callee_def],
      params.length() + locals.length(),
      callee_abs,
      params.length(),
    )
    let uniform = match
      dae_collect_uniform_const_actuals_from_boundary_facts(
        mod_,
        callee_abs,
        params.length(),
        type_indices,
        boundary_facts,
      ) {
      Some(values) => values
      None => continue
    }
    let final_param = params.length() - 1
    if local_use.writes[final_param] {
      continue
    }
    let expected = match uniform[final_param] {
      Some(@lib.RefNull(_) as value) => value
      _ => continue
    }
    let remove = Array::make(params.length(), false)
    remove[final_param] = true
    let const_params : Array[@lib.Instruction?] = Array::make(
      params.length(),
      None,
    )
    const_params[final_param] = Some(expected)
    let (plan_original, plan_graph) = match (original, graph) {
      (Some(original), Some(graph)) => (original, graph)
      _ =>
        (
          dae_boundary_syntax_frozen_collect_original_boundary_snapshot(mod_),
          dae_current_boundary_graph_new(mod_),
        )
    }
    let result = match
      dae_build_scalar_unused_param_rewrite_plan(
        mod_,
        plan_original,
        plan_graph,
        callee_abs,
        remove,
        local_use,
        boundary_facts.direct_calls[callee_abs],
        boundary_facts.direct_callers[callee_abs],
        materialized_params=Some(const_params),
        verified_materialized_suffix=Some([expected]),
      ) {
      Some(plan) => {
        let plan_application = dae_apply_rewrite_plan(mod_, plan_graph, plan)
        if plan_application.applied {
          plan_application.result
        } else {
          { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
        }
      }
      None => { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
    }
    if result.changed {
      if result.primary_def < 0 || result.primary_def >= result.touched.length() {
        return result
      }
      let cleanup_defs = Array::make(result.touched.length(), false)
      cleanup_defs[result.primary_def] = true
      let folded = dae_try_fold_selected_ref_null_is_null_ifs_once(
        result.mod_out,
        cleanup_defs,
      )
      if !folded.changed {
        return result
      }
      let combined_touched = result.touched.copy()
      for def_idx = 0; def_idx < folded.touched.length(); def_idx = def_idx + 1 {
        if folded.touched[def_idx] && def_idx < combined_touched.length() {
          combined_touched[def_idx] = true
        }
      }
      let sentinel_folded = dae_try_fold_selected_i64_sentinel_wrap_ifs_once(
        folded.mod_out,
        cleanup_defs,
      )
      if !sentinel_folded.changed {
        return {
          mod_out: folded.mod_out,
          touched: combined_touched,
          changed: true,
          primary_def: result.primary_def,
        }
      }
      for def_idx = 0
          def_idx < sentinel_folded.touched.length()
          def_idx = def_idx + 1 {
        if sentinel_folded.touched[def_idx] &&
          def_idx < combined_touched.length() {
          combined_touched[def_idx] = true
        }
      }
      return {
        mod_out: sentinel_folded.mod_out,
        touched: combined_touched,
        changed: true,
        primary_def: result.primary_def,
      }
    }
  }
  { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
}

///|
fn dae_boundary_syntax_frozen_instr_is_unreachable_root(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Unreachable => true
    @lib.Block(_, @lib.Expr(body)) =>
      body.length() == 1 &&
      dae_boundary_syntax_frozen_instr_is_unreachable_root(body[0])
    _ => false
  }
}

///|
fn dae_boundary_syntax_frozen_dead_suffix_evidence(
  instrs : Array[@lib.Instruction],
) -> DaeDeadSuffixEvidence? {
  let mut idx = 0
  while idx < instrs.length() {
    if dae_boundary_syntax_frozen_instr_is_unreachable_root(instrs[idx]) {
      // Borrow this immutable source body; every consumer starts at the explicit
      // suffix boundary, including stack-origin queries with empty entry state.
      return Some({ root_idx: idx, suffix_start: idx + 1, body: instrs, })
    }
    idx += 1
  }
  None
}

///|
fn dae_boundary_syntax_frozen_dropped_result_module_context(
  mod_ : @lib.Module,
  callee_abs : Int32,
  caller_defs~ : Array[Int32]? = None,
  perf~ : HotPerfSession? = None,
  timer_prefix~ : String = "",
  boundary_facts~ : DaeBoundaryFacts? = None,
  cached_precheck~ : DaeDroppedResultCachedPrecheck? = None,
) -> DaeDroppedResultModuleContext? {
  let imported = match boundary_facts {
    Some(facts) => facts.graph.snapshot.imported
    None => dae_boundary_syntax_frozen_imported_func_count(mod_)
  }
  let def_idx = callee_abs - imported
  let type_indices_timer_name = "\{timer_prefix}:type-indices"
  let type_indices_start_us = if timer_prefix.length() > 0 {
    perf_start_timer_opt(perf, type_indices_timer_name)
  } else {
    0UL
  }
  let type_indices = match boundary_facts {
    Some(facts) => facts.graph.snapshot.type_indices
    None => dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  }
  if timer_prefix.length() > 0 {
    perf_stop_timer_opt(perf, type_indices_timer_name, type_indices_start_us)
  }
  let func_type = match
    dae_boundary_syntax_frozen_resolve_func_type(mod_, type_indices, callee_abs) {
    Some(ft) => ft
    None => return None
  }
  let @lib.FuncType(params, results) = func_type
  let section_copy_timer_name = "\{timer_prefix}:section-copy"
  let section_copy_start_us = if timer_prefix.length() > 0 {
    perf_start_timer_opt(perf, section_copy_timer_name)
  } else {
    0UL
  }
  let signature = match
    dae_module_signature_context(mod_, def_idx, copy_funcs=true) {
    Some(signature) => {
      if timer_prefix.length() > 0 {
        perf_stop_timer_opt(
          perf, section_copy_timer_name, section_copy_start_us,
        )
      }
      signature
    }
    None => {
      if timer_prefix.length() > 0 {
        perf_stop_timer_opt(
          perf, section_copy_timer_name, section_copy_start_us,
        )
      }
      return None
    }
  }
  let scope = dae_dropped_result_scope_from_optional(
    signature.funcs.length(),
    caller_defs,
  )
  let undropped_scan_timer_name = "\{timer_prefix}:undropped-scan"
  let undropped_scan_start_us = if timer_prefix.length() > 0 {
    perf_start_timer_opt(perf, undropped_scan_timer_name)
  } else {
    0UL
  }
  let result_removal_legality = match cached_precheck {
    Some(precheck) => precheck.result_removal_legality
    None => {
      let scoped = dae_dropped_result_removal_legality_evidence(
        signature.funcs,
        scope,
        callee_abs,
        def_idx,
        results,
      )
      let original = match boundary_facts {
        Some(facts) => facts.original
        None =>
          dae_boundary_syntax_frozen_collect_original_boundary_snapshot(mod_)
      }
      let original_exposure_blocks = callee_abs < 0 ||
        callee_abs >= original.exposure.length() ||
        dae_boundary_syntax_frozen_function_exposure_blocks_boundary(
          original.exposure[callee_abs],
        )
      if results.length() > 0 && original_exposure_blocks {
        { ..scoped, blocks_result_removal: true, }
      } else {
        scoped
      }
    }
  }
  if timer_prefix.length() > 0 {
    perf_stop_timer_opt(
      perf, undropped_scan_timer_name, undropped_scan_start_us,
    )
  }
  Some({
    signature,
    imported,
    type_indices,
    params,
    results,
    scope,
    result_removal_legality,
  })
}

///|
fn dae_boundary_syntax_frozen_specialized_result_facts_new(
  original : DaeOriginalBoundarySnapshot,
  graph : DaeCurrentBoundaryGraph,
  callee_abs : Int32,
  caller_defs~ : Array[Int32]? = None,
) -> DaeSpecializedResultFacts? {
  let context = match
    dae_boundary_syntax_frozen_dropped_result_module_context(
      graph.mod_,
      callee_abs,
      caller_defs~,
    ) {
    Some(context) => context
    None => return None
  }
  let target_def = context.signature.def_idx
  if target_def < 0 ||
    target_def >= graph.snapshot.defined ||
    target_def >= graph.function_epochs.length() ||
    callee_abs < 0 ||
    callee_abs >= context.type_indices.length() {
    return None
  }
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let topology = graph.topology
  let epochs = graph.function_epochs[target_def]
  let original_owned = callee_abs >= 0 &&
    callee_abs < original.exposure.length() &&
    !dae_boundary_syntax_frozen_function_exposure_blocks_boundary(
      original.exposure[callee_abs],
    )
  let result_observers = if target_def <
    dependencies.result_observers_by_def.length() {
    dependencies.result_observers_by_def[target_def].copy()
  } else {
    []
  }
  let direct_tail_callers = if target_def <
    dependencies.tail_result_dependencies_by_def.length() {
    dependencies.tail_result_dependencies_by_def[target_def].copy()
  } else {
    []
  }
  let has_outgoing_tail = (
      callee_abs < topology.has_outgoing_return_call.length() &&
      topology.has_outgoing_return_call[callee_abs]
    ) ||
    (
      callee_abs < topology.has_outgoing_return_call_indirect.length() &&
      topology.has_outgoing_return_call_indirect[callee_abs]
    ) ||
    (
      callee_abs < topology.has_outgoing_return_call_ref.length() &&
      topology.has_outgoing_return_call_ref[callee_abs]
    )
  let direct_tail_callee = direct_tail_callers.length() > 0 ||
    (
      callee_abs < graph.snapshot.call_facts.tail_calls.length() &&
      graph.snapshot.call_facts.tail_calls[callee_abs]
    )
  Some({
    original,
    graph,
    context,
    target_abs: callee_abs,
    target_def,
    original_owned,
    expected_type_idx: context.type_indices[callee_abs],
    expected_results: context.results.copy(),
    expected_module_epoch: graph.module_epoch,
    expected_call_epoch: graph.call_epoch,
    expected_type_epoch: graph.type_epoch,
    expected_signature_epoch: epochs.signature_epoch,
    expected_body_epoch: epochs.body_epoch,
    result_epoch: epochs.signature_epoch,
    active_call_identities: dae_collect_target_call_identities(
      graph.snapshot,
      callee_abs,
    ),
    result_observers,
    direct_tail_callers,
    has_outgoing_tail,
    direct_tail_callee,
  })
}

///|
fn dae_boundary_syntax_frozen_try_remove_dropped_results(
  mod_ : @lib.Module,
  callee_abs : Int32,
  direct_call_count : Int32,
  dropped_call_count : Int32,
  perf~ : HotPerfSession? = None,
  caller_defs~ : Array[Int32]? = None,
  boundary_facts~ : DaeBoundaryFacts? = None,
  cached_precheck~ : DaeDroppedResultCachedPrecheck? = None,
) -> DaePassResult {
  if direct_call_count == 0 || dropped_call_count != direct_call_count {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let context = match
    dae_boundary_syntax_frozen_dropped_result_module_context(
      mod_,
      callee_abs,
      caller_defs~,
      perf~,
      timer_prefix="detail:dae:core:selected-lanes:dropped-results:selected-defs:helper",
      boundary_facts~,
      cached_precheck~,
    ) {
    Some(context) => context
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let imported = context.imported
  let def_idx = context.signature.def_idx
  let type_indices = context.type_indices
  let params = context.params
  let results = context.results
  if results.length() != 1 {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let funcs = context.signature.funcs
  let rewrite_scope = context.scope
  if dae_dropped_result_removal_legality_blocks(context.result_removal_legality) {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let self_call_count_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:selected-lanes:dropped-results:selected-defs:helper:self-call-count",
  )
  let self_call_count = match cached_precheck {
    Some(precheck) => precheck.self_call_count
    None => dae_count_self_calls(funcs[def_idx], callee_abs)
  }
  perf_stop_timer_opt(
    perf, "detail:dae:core:selected-lanes:dropped-results:selected-defs:helper:self-call-count",
    self_call_count_start_us,
  )
  if direct_call_count == self_call_count {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let rewritten_funcs = funcs.copy()
  let rewrite_calls_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:selected-lanes:dropped-results:selected-defs:helper:rewrite-calls",
  )
  let preserve_uninhabitable_control = dae_result_type_is_uninhabitable(
    results[0],
  )
  let rewritten_call_count = dae_rewrite_dropped_result_calls_in_scope_with_policy(
    rewritten_funcs,
    rewrite_scope,
    callee_abs,
    stop_at_unreachable_root=true,
    preserve_uninhabitable_control~,
  )
  perf_stop_timer_opt(
    perf, "detail:dae:core:selected-lanes:dropped-results:selected-defs:helper:rewrite-calls",
    rewrite_calls_start_us,
  )
  if rewritten_call_count != direct_call_count {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let repair_plan = dae_dropped_result_repair_plan(
    rewrite_scope,
    callee_abs,
    def_idx,
    DaeRepairDeadSuffixNoParamCallers,
    remove_dropped_call_drops=true,
    remove_dropped_call_drops_before_repair=true,
  )
  let @lib.Func(callee_locals, @lib.Expr(callee_body)) = rewritten_funcs[def_idx]
  let next_callee_body = callee_body.copy()
  next_callee_body.push(@lib.Instruction::drop())
  let callee_rewrite_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:selected-lanes:dropped-results:selected-defs:helper:callee-rewrite",
  )
  let rewritten_callee = dae_simplify_to_unreachable_when_prefix_unobservable(
    @lib.Func::new(callee_locals, @lib.Expr::new(next_callee_body)),
  )
  perf_stop_timer_opt(
    perf, "detail:dae:core:selected-lanes:dropped-results:selected-defs:helper:callee-rewrite",
    callee_rewrite_start_us,
  )
  let finalization_plan = dae_module_code_finalization_plan(
    params,
    [],
    DaeTouchModuleCodeChangedFuncs,
  )
  dae_apply_dropped_result_callee_rewrite(
    mod_,
    context.signature,
    type_indices,
    imported,
    rewritten_funcs,
    rewritten_callee,
    repair_plan,
    finalization_plan,
    perf~,
    repair_timer_name="detail:dae:core:selected-lanes:dropped-results:selected-defs:helper:repair-plan",
    type_update_timer_name="detail:dae:core:selected-lanes:dropped-results:selected-defs:helper:type-update",
  )
}

///|
fn dae_boundary_syntax_frozen_collect_original_large_unreachable_prefixes(
  mod_ : @lib.Module,
) -> Array[Bool] {
  Array::make(dae_boundary_syntax_frozen_defined_func_count(mod_), false)
}

///|
fn dae_boundary_syntax_frozen_empty_direct_call_target_evidence() -> DaeDirectCallTargetEvidence {
  {
    direct_call_count: 0,
    dropped_direct_call_count: 0,
    has_direct_call: false,
    has_undropped_direct_call: false,
    has_live_undropped_direct_call: false,
  }
}

///|
fn dae_boundary_syntax_frozen_merge_direct_call_target_evidence(
  dst : DaeDirectCallTargetEvidence,
  src : DaeDirectCallTargetEvidence,
  include_live : Bool,
) -> DaeDirectCallTargetEvidence {
  {
    direct_call_count: dst.direct_call_count + src.direct_call_count,
    dropped_direct_call_count: dst.dropped_direct_call_count +
    src.dropped_direct_call_count,
    has_direct_call: dst.has_direct_call || src.has_direct_call,
    has_undropped_direct_call: dst.has_undropped_direct_call ||
    src.has_undropped_direct_call,
    has_live_undropped_direct_call: dst.has_live_undropped_direct_call ||
    (include_live && src.has_live_undropped_direct_call),
  }
}

///|
fn dae_boundary_syntax_frozen_direct_call_target_evidence(
  instrs : Array[@lib.Instruction],
  callee_abs : Int32,
  start_idx~ : Int32 = 0,
) -> DaeDirectCallTargetEvidence {
  let mut evidence = dae_boundary_syntax_frozen_empty_direct_call_target_evidence()
  let mut live_prefix = true
  let mut idx = start_idx
  while idx < instrs.length() {
    if live_prefix &&
      dae_boundary_syntax_frozen_instr_is_unreachable_root(instrs[idx]) {
      live_prefix = false
    }
    let instr_evidence : DaeDirectCallTargetEvidence = match instrs[idx] {
      @lib.Call(func_idx) if dae_boundary_syntax_frozen_func_idx_slot(func_idx) ==
        callee_abs => {
        let dropped = idx + 1 < instrs.length() &&
          instrs[idx + 1] == @lib.Instruction::drop()
        {
          direct_call_count: 1,
          dropped_direct_call_count: if dropped {
            1
          } else {
            0
          },
          has_direct_call: true,
          has_undropped_direct_call: !dropped,
          has_live_undropped_direct_call: live_prefix && !dropped,
        }
      }
      @lib.ReturnCall(func_idx) if dae_boundary_syntax_frozen_func_idx_slot(
          func_idx,
        ) ==
        callee_abs =>
        {
          direct_call_count: 0,
          dropped_direct_call_count: 0,
          has_direct_call: false,
          has_undropped_direct_call: true,
          has_live_undropped_direct_call: live_prefix,
        }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        dae_boundary_syntax_frozen_direct_call_target_evidence(body, callee_abs)
      @lib.If(_, then_body, Some(else_body)) =>
        dae_boundary_syntax_frozen_merge_direct_call_target_evidence(
          dae_boundary_syntax_frozen_direct_call_target_evidence(
            then_body, callee_abs,
          ),
          dae_boundary_syntax_frozen_direct_call_target_evidence(
            else_body, callee_abs,
          ),
          true,
        )
      @lib.If(_, then_body, None) =>
        dae_boundary_syntax_frozen_direct_call_target_evidence(
          then_body, callee_abs,
        )
      _ => dae_boundary_syntax_frozen_empty_direct_call_target_evidence()
    }
    evidence = dae_boundary_syntax_frozen_merge_direct_call_target_evidence(
      evidence, instr_evidence, live_prefix,
    )
    idx += 1
  }
  evidence
}

///|
fn dae_boundary_syntax_frozen_count_direct_call_anywhere_to(
  instrs : Array[@lib.Instruction],
  callee_abs : Int32,
  start_idx~ : Int32 = 0,
) -> Int32 {
  dae_boundary_syntax_frozen_direct_call_target_evidence(
    instrs,
    callee_abs,
    start_idx~,
  ).direct_call_count
}

///|
fn dae_boundary_syntax_frozen_count_self_calls_anywhere(
  func : @lib.Func,
  callee_abs : Int32,
) -> Int32 {
  let @lib.Func(_, @lib.Expr(body)) = func
  dae_boundary_syntax_frozen_count_direct_call_anywhere_to(body, callee_abs)
}

///|
fn dae_boundary_syntax_frozen_has_undropped_direct_call_to(
  instrs : Array[@lib.Instruction],
  callee_abs : Int32,
) -> Bool {
  dae_boundary_syntax_frozen_direct_call_target_evidence(instrs, callee_abs).has_undropped_direct_call
}

///|
fn dae_boundary_syntax_frozen_control_result_undropped_direct_call_evidence_from_parts(
  block_type : @lib.BlockType,
  primary_body : Array[@lib.Instruction],
  secondary_body : Array[@lib.Instruction]?,
  callee_abs : Int32,
) -> DaeControlResultUndroppedDirectCallEvidence {
  let arity = dae_boundary_syntax_frozen_instr_result_arity_from_block_type(
    block_type,
  )
  let result_arity_known = arity is Some(_)
  let result_arity = match arity {
    Some(count) => count
    None => 0
  }
  let has_result = match arity {
    Some(count) => count > 0
    None => true
  }
  let primary_has_undropped_direct_call = dae_boundary_syntax_frozen_has_undropped_direct_call_to(
    primary_body, callee_abs,
  )
  let secondary_has_undropped_direct_call = match secondary_body {
    Some(body) =>
      dae_boundary_syntax_frozen_has_undropped_direct_call_to(body, callee_abs)
    None => false
  }
  let has_undropped_direct_call = primary_has_undropped_direct_call ||
    secondary_has_undropped_direct_call
  {
    result_arity_known,
    result_arity,
    has_result,
    primary_has_undropped_direct_call,
    secondary_has_undropped_direct_call,
    has_undropped_direct_call,
    blocks_result_removal: has_result && has_undropped_direct_call,
  }
}

///|
fn dae_boundary_syntax_frozen_control_result_undropped_direct_call_evidence(
  instr : @lib.Instruction,
  callee_abs : Int32,
) -> DaeControlResultUndroppedDirectCallEvidence? {
  match instr {
    @lib.Block(block_type, @lib.Expr(body))
    | @lib.Loop(block_type, @lib.Expr(body))
    | @lib.TryTable(block_type, _, @lib.Expr(body)) =>
      Some(
        dae_boundary_syntax_frozen_control_result_undropped_direct_call_evidence_from_parts(
          block_type,
          body,
          None,
          callee_abs,
        ),
      )
    @lib.If(block_type, then_body, else_body) =>
      Some(
        dae_boundary_syntax_frozen_control_result_undropped_direct_call_evidence_from_parts(
          block_type, then_body, else_body, callee_abs,
        ),
      )
    _ => None
  }
}

///|
fn dae_boundary_syntax_frozen_control_result_undropped_direct_call_evidence_is_consistent(
  evidence : DaeControlResultUndroppedDirectCallEvidence,
) -> Bool {
  evidence.result_arity >= 0 &&
  evidence.has_result ==
  (!evidence.result_arity_known || evidence.result_arity > 0) &&
  evidence.has_undropped_direct_call ==
  (
    evidence.primary_has_undropped_direct_call ||
    evidence.secondary_has_undropped_direct_call
  ) &&
  evidence.blocks_result_removal ==
  (evidence.has_result && evidence.has_undropped_direct_call)
}

///|
fn dae_boundary_syntax_frozen_suffix_has_top_level_dropped_direct_call_to(
  suffix : Array[@lib.Instruction],
  callee_abs : Int32,
  start_idx~ : Int32 = 0,
) -> Bool {
  let mut suffix_idx = start_idx
  while suffix_idx + 1 < suffix.length() {
    match (suffix[suffix_idx], suffix[suffix_idx + 1]) {
      (@lib.Call(func_idx), @lib.Drop) if dae_boundary_syntax_frozen_func_idx_slot(
          func_idx,
        ) ==
        callee_abs => return true
      _ => ()
    }
    suffix_idx += 1
  }
  false
}

///|
fn dae_boundary_syntax_frozen_dead_suffix_direct_call_evidence(
  instrs : Array[@lib.Instruction],
  callee_abs : Int32,
) -> DaeDeadSuffixDirectCallEvidence? {
  match dae_boundary_syntax_frozen_dead_suffix_evidence(instrs) {
    Some(dead_suffix) => {
      let target = dae_boundary_syntax_frozen_direct_call_target_evidence(
        dead_suffix.body,
        callee_abs,
        start_idx=dead_suffix.suffix_start,
      )
      Some({
        has_dropped_direct_call: dae_boundary_syntax_frozen_suffix_has_top_level_dropped_direct_call_to(
          dead_suffix.body,
          callee_abs,
          start_idx=dead_suffix.suffix_start,
        ),
        has_undropped_direct_call: target.has_undropped_direct_call,
      })
    }
    None => None
  }
}

///|
fn dae_boundary_syntax_frozen_dead_suffix_has_other_call(
  instrs : Array[@lib.Instruction],
  callee_abs : Int32,
) -> Bool {
  match dae_boundary_syntax_frozen_dead_suffix_evidence(instrs) {
    Some(evidence) => {
      let mut suffix_idx = evidence.suffix_start
      while suffix_idx < evidence.body.length() {
        match evidence.body[suffix_idx] {
          @lib.Call(func_idx) if dae_boundary_syntax_frozen_func_idx_slot(
              func_idx,
            ) !=
            callee_abs => return true
          _ => ()
        }
        suffix_idx += 1
      }
      false
    }
    None => false
  }
}

///|
fn dae_boundary_syntax_frozen_dead_suffix_has_dropped_direct_call_to(
  instrs : Array[@lib.Instruction],
  callee_abs : Int32,
) -> Bool {
  match
    dae_boundary_syntax_frozen_dead_suffix_direct_call_evidence(
      instrs, callee_abs,
    ) {
    Some(evidence) => evidence.has_dropped_direct_call
    None => false
  }
}

///|
fn dae_boundary_syntax_frozen_dead_suffix_has_undropped_direct_call_to(
  instrs : Array[@lib.Instruction],
  callee_abs : Int32,
) -> Bool {
  match
    dae_boundary_syntax_frozen_dead_suffix_direct_call_evidence(
      instrs, callee_abs,
    ) {
    Some(evidence) => evidence.has_undropped_direct_call
    None => false
  }
}

///|
fn dae_boundary_syntax_frozen_append_targets(
  dst : Array[Int32],
  src : Array[Int32],
) -> Unit {
  for target in src {
    dst.push(target)
  }
}

///|
fn dae_boundary_syntax_frozen_defined_direct_target(
  func_idx : @lib.FuncIdx,
  imported : Int32,
  defined : Int32,
) -> Int32? {
  let slot = dae_boundary_syntax_frozen_func_idx_slot(func_idx)
  let def_idx = slot - imported
  if slot >= imported && def_idx >= 0 && def_idx < defined {
    Some(def_idx)
  } else {
    None
  }
}

///|
fn dae_boundary_syntax_frozen_collect_dead_suffix_direct_target_lists(
  instrs : Array[@lib.Instruction],
  imported : Int32,
  defined : Int32,
  collect_top_level_dropped : Bool,
  direct_targets : Array[Int32],
  dropped_direct_targets : Array[Int32],
  undropped_direct_targets : Array[Int32],
  start_idx~ : Int32 = 0,
) -> Unit {
  let mut idx = start_idx
  while idx < instrs.length() {
    match instrs[idx] {
      @lib.Call(func_idx) =>
        match
          dae_boundary_syntax_frozen_defined_direct_target(
            func_idx, imported, defined,
          ) {
          Some(def_idx) => {
            direct_targets.push(def_idx)
            let dropped = idx + 1 < instrs.length() &&
              instrs[idx + 1] == @lib.Instruction::drop()
            if dropped {
              if collect_top_level_dropped {
                dropped_direct_targets.push(def_idx)
              }
            } else {
              undropped_direct_targets.push(def_idx)
            }
          }
          None => ()
        }
      @lib.ReturnCall(func_idx) =>
        match
          dae_boundary_syntax_frozen_defined_direct_target(
            func_idx, imported, defined,
          ) {
          Some(def_idx) => undropped_direct_targets.push(def_idx)
          None => ()
        }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        dae_boundary_syntax_frozen_collect_dead_suffix_direct_target_lists(
          body, imported, defined, false, direct_targets, dropped_direct_targets,
          undropped_direct_targets,
        )
      @lib.If(_, then_body, Some(else_body)) => {
        dae_boundary_syntax_frozen_collect_dead_suffix_direct_target_lists(
          then_body, imported, defined, false, direct_targets, dropped_direct_targets,
          undropped_direct_targets,
        )
        dae_boundary_syntax_frozen_collect_dead_suffix_direct_target_lists(
          else_body, imported, defined, false, direct_targets, dropped_direct_targets,
          undropped_direct_targets,
        )
      }
      @lib.If(_, then_body, None) =>
        dae_boundary_syntax_frozen_collect_dead_suffix_direct_target_lists(
          then_body, imported, defined, false, direct_targets, dropped_direct_targets,
          undropped_direct_targets,
        )
      _ => ()
    }
    idx += 1
  }
}

///|
fn dae_boundary_syntax_frozen_dead_suffix_direct_target_evidence(
  instrs : Array[@lib.Instruction],
  imported : Int32,
  defined : Int32,
) -> DaeDeadSuffixDirectTargetEvidence? {
  match dae_boundary_syntax_frozen_dead_suffix_evidence(instrs) {
    Some(evidence) => {
      let direct_targets : Array[Int32] = []
      let dropped_direct_targets : Array[Int32] = []
      let undropped_direct_targets : Array[Int32] = []
      dae_boundary_syntax_frozen_collect_dead_suffix_direct_target_lists(
        evidence.body,
        imported,
        defined,
        true,
        direct_targets,
        dropped_direct_targets,
        undropped_direct_targets,
        start_idx=evidence.suffix_start,
      )
      Some({ direct_targets, dropped_direct_targets, undropped_direct_targets, })
    }
    None => None
  }
}

///|
fn dae_boundary_syntax_frozen_collect_dead_suffix_undropped_direct_targets(
  instrs : Array[@lib.Instruction],
  imported : Int32,
  defined : Int32,
  targets : Array[Int32],
) -> Unit {
  match
    dae_boundary_syntax_frozen_dead_suffix_direct_target_evidence(
      instrs, imported, defined,
    ) {
    Some(evidence) =>
      dae_boundary_syntax_frozen_append_targets(
        targets,
        evidence.undropped_direct_targets,
      )
    None => ()
  }
}

///|
fn dae_boundary_syntax_frozen_collect_dead_suffix_dropped_direct_targets(
  instrs : Array[@lib.Instruction],
  imported : Int32,
  defined : Int32,
  targets : Array[Int32],
) -> Unit {
  match
    dae_boundary_syntax_frozen_dead_suffix_direct_target_evidence(
      instrs, imported, defined,
    ) {
    Some(evidence) =>
      dae_boundary_syntax_frozen_append_targets(
        targets,
        evidence.dropped_direct_targets,
      )
    None => ()
  }
}

///|
fn dae_boundary_syntax_frozen_stack_operand_window_evidence_is_consistent(
  evidence : DaeStackOperandWindowEvidence,
  stack_length : Int32,
) -> Bool {
  evidence.start >= 0 &&
  evidence.end == stack_length &&
  evidence.start <= evidence.end &&
  evidence.available_operands == evidence.end - evidence.start &&
  evidence.available_operands >= 0 &&
  (
    evidence.requested_operands >= evidence.available_operands ||
    evidence.requested_operands < 0
  )
}

///|
fn dae_boundary_syntax_frozen_stack_operand_window_evidence(
  stack_length : Int32,
  arg_count : Int32,
) -> DaeStackOperandWindowEvidence? {
  if stack_length < 0 {
    return None
  }
  let requested = if arg_count < 0 { 0 } else { arg_count }
  let start = if stack_length > requested {
    stack_length - requested
  } else {
    0
  }
  let evidence = {
    start,
    end: stack_length,
    requested_operands: arg_count,
    available_operands: stack_length - start,
  }
  if dae_boundary_syntax_frozen_stack_operand_window_evidence_is_consistent(
      evidence, stack_length,
    ) {
    Some(evidence)
  } else {
    None
  }
}

///|
fn dae_boundary_syntax_frozen_stack_bool_has_true_operand(
  stack : Array[Bool],
  arg_count : Int32,
) -> Bool {
  let window = match
    dae_boundary_syntax_frozen_stack_operand_window_evidence(
      stack.length(),
      arg_count,
    ) {
    Some(window) => window
    None => return false
  }
  let mut idx = window.start
  while idx < window.end {
    if idx >= 0 && idx < stack.length() && stack[idx] {
      return true
    }
    idx += 1
  }
  false
}

///|
fn dae_boundary_syntax_frozen_stack_bool_apply_effect(
  stack : Array[Bool],
  inputs : Int32,
  outputs : Int32,
  pushed_value : Bool,
) -> Unit {
  let mut pop = 0
  while pop < inputs && stack.length() > 0 {
    ignore(stack.pop())
    pop += 1
  }
  let mut push = 0
  while push < outputs {
    stack.push(pushed_value)
    push += 1
  }
}

///|
fn dae_boundary_syntax_frozen_stack_effect_evidence_is_consistent(
  evidence : DaeStackEffectEvidence,
) -> Bool {
  evidence.inputs >= 0 && evidence.outputs >= 0
}

///|
fn dae_boundary_syntax_frozen_stack_effect_evidence(
  instr : @lib.Instruction,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> DaeStackEffectEvidence? {
  match
    dae_boundary_syntax_frozen_instr_stack_effect(
      instr, mod_, func_type_indices,
    ) {
    Some((inputs, outputs)) => {
      let evidence = { inputs, outputs, }
      if dae_boundary_syntax_frozen_stack_effect_evidence_is_consistent(
          evidence,
        ) {
        Some(evidence)
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn dae_boundary_syntax_frozen_stack_bool_apply_instr_effect(
  stack : Array[Bool],
  instr : @lib.Instruction,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
  pushed_value : Bool,
) -> Bool {
  match
    dae_boundary_syntax_frozen_stack_effect_evidence(
      instr, mod_, func_type_indices,
    ) {
    Some(evidence) => {
      dae_boundary_syntax_frozen_stack_bool_apply_effect(
        stack,
        evidence.inputs,
        evidence.outputs,
        pushed_value,
      )
      true
    }
    None => false
  }
}

///|
fn dae_boundary_syntax_frozen_stack_int_has_operand_value(
  stack : Array[Int32],
  arg_count : Int32,
  value : Int32,
) -> Bool {
  let window = match
    dae_boundary_syntax_frozen_stack_operand_window_evidence(
      stack.length(),
      arg_count,
    ) {
    Some(window) => window
    None => return false
  }
  let mut idx = window.start
  while idx < window.end {
    if idx >= 0 && idx < stack.length() && stack[idx] == value {
      return true
    }
    idx += 1
  }
  false
}

///|
fn dae_boundary_syntax_frozen_stack_int_has_known_operand(
  stack : Array[Int32],
  arg_count : Int32,
) -> Bool {
  let window = match
    dae_boundary_syntax_frozen_stack_operand_window_evidence(
      stack.length(),
      arg_count,
    ) {
    Some(window) => window
    None => return false
  }
  let mut idx = window.start
  while idx < window.end {
    if idx >= 0 && idx < stack.length() && stack[idx] >= 0 {
      return true
    }
    idx += 1
  }
  false
}

///|
fn dae_boundary_syntax_frozen_stack_int_apply_effect(
  stack : Array[Int32],
  inputs : Int32,
  outputs : Int32,
  pushed_value : Int32,
) -> Unit {
  let mut pop = 0
  while pop < inputs && stack.length() > 0 {
    ignore(stack.pop())
    pop += 1
  }
  let mut push = 0
  while push < outputs {
    stack.push(pushed_value)
    push += 1
  }
}

///|
fn dae_boundary_syntax_frozen_stack_int_apply_instr_effect(
  stack : Array[Int32],
  instr : @lib.Instruction,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
  pushed_value : Int32,
) -> Bool {
  match
    dae_boundary_syntax_frozen_stack_effect_evidence(
      instr, mod_, func_type_indices,
    ) {
    Some(evidence) => {
      dae_boundary_syntax_frozen_stack_int_apply_effect(
        stack,
        evidence.inputs,
        evidence.outputs,
        pushed_value,
      )
      true
    }
    None => false
  }
}

///|
fn dae_boundary_syntax_frozen_scan_original_call_summary_instrs(
  instrs : Array[@lib.Instruction],
  imported : Int32,
  defined : Int32,
  targets : Array[Int32],
  undropped_targets : Array[Int32],
) -> Unit {
  let mut idx = 0
  while idx < instrs.length() {
    match instrs[idx] {
      @lib.Call(func_idx) => {
        let slot = dae_boundary_syntax_frozen_func_idx_slot(func_idx)
        let def_idx = slot - imported
        if slot >= imported && def_idx >= 0 && def_idx < defined {
          targets.push(def_idx)
          if idx + 1 >= instrs.length() ||
            instrs[idx + 1] != @lib.Instruction::drop() {
            undropped_targets.push(def_idx)
          }
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        dae_boundary_syntax_frozen_scan_original_call_summary_instrs(
          body, imported, defined, targets, undropped_targets,
        )
      @lib.If(_, then_body, Some(else_body)) => {
        dae_boundary_syntax_frozen_scan_original_call_summary_instrs(
          then_body, imported, defined, targets, undropped_targets,
        )
        dae_boundary_syntax_frozen_scan_original_call_summary_instrs(
          else_body, imported, defined, targets, undropped_targets,
        )
      }
      @lib.If(_, then_body, None) =>
        dae_boundary_syntax_frozen_scan_original_call_summary_instrs(
          then_body, imported, defined, targets, undropped_targets,
        )
      _ => ()
    }
    idx += 1
  }
}

///|
fn dae_boundary_syntax_frozen_collect_original_call_summary_with_context(
  mod_ : @lib.Module,
  imported : Int32,
  defined : Int32,
  type_indices : Array[@lib.TypeIdx],
  escaped : Array[Bool],
) -> DaeOriginalCallSummary {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => {
      let empty = Array::make(defined, 0)
      return {
        call_counts: empty.copy(),
        prior_call_counts: empty.copy(),
        nonself_undropped_call_counts: empty.copy(),
        active_nonself_call_counts: empty.copy(),
        active_parameterized_nonself_call_counts: empty.copy(),
        active_parameterized_result_nonself_call_counts: empty.copy(),
        prior_undropped_call_counts: empty.copy(),
        self_call_counts: empty.copy(),
      }
    }
  }
  let call_targets_by_caller : Array[Array[Int32]] = []
  let call_counts = Array::make(defined, 0)
  let prior_call_counts = Array::make(defined, 0)
  let nonself_undropped_call_counts = Array::make(defined, 0)
  let prior_undropped_call_counts = Array::make(defined, 0)
  let self_call_counts = Array::make(defined, 0)
  let seen_undropped_stamp = Array::make(defined, -1)
  let mut caller_def = 0
  while caller_def < funcs.length() && caller_def < defined {
    let targets : Array[Int32] = []
    let undropped_targets : Array[Int32] = []
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    dae_boundary_syntax_frozen_scan_original_call_summary_instrs(
      body, imported, defined, targets, undropped_targets,
    )
    call_targets_by_caller.push(targets)
    for target in targets {
      call_counts[target] = call_counts[target] + 1
      if target == caller_def {
        self_call_counts[target] = self_call_counts[target] + 1
      }
      if target > caller_def {
        prior_call_counts[target] = prior_call_counts[target] + 1
      }
    }
    for target in undropped_targets {
      if seen_undropped_stamp[target] != caller_def {
        seen_undropped_stamp[target] = caller_def
        if target != caller_def {
          nonself_undropped_call_counts[target] = nonself_undropped_call_counts[target] +
            1
        }
        if target > caller_def {
          prior_undropped_call_counts[target] = prior_undropped_call_counts[target] +
            1
        }
      }
    }
    caller_def += 1
  }
  while call_targets_by_caller.length() < defined {
    call_targets_by_caller.push([])
  }
  let active_nonself_call_counts = Array::make(defined, 0)
  let active_parameterized_nonself_call_counts = Array::make(defined, 0)
  let active_parameterized_result_nonself_call_counts = Array::make(defined, 0)
  caller_def = 0
  while caller_def < defined {
    let caller_abs = imported + caller_def
    let caller_is_active = (
        caller_abs < escaped.length() && escaped[caller_abs]
      ) ||
      call_counts[caller_def] > 0
    let (caller_has_params, caller_has_params_and_result) = match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, caller_abs,
      ) {
      Some(@lib.FuncType(params, results)) =>
        (params.length() > 0, params.length() > 0 && results.length() > 0)
      None => (false, false)
    }
    if caller_is_active {
      for target in call_targets_by_caller[caller_def] {
        if target != caller_def {
          active_nonself_call_counts[target] = active_nonself_call_counts[target] +
            1
          if caller_has_params {
            active_parameterized_nonself_call_counts[target] = active_parameterized_nonself_call_counts[target] +
              1
          }
          if caller_has_params_and_result {
            active_parameterized_result_nonself_call_counts[target] = active_parameterized_result_nonself_call_counts[target] +
              1
          }
        }
      }
    }
    caller_def += 1
  }
  {
    call_counts,
    prior_call_counts,
    nonself_undropped_call_counts,
    active_nonself_call_counts,
    active_parameterized_nonself_call_counts,
    active_parameterized_result_nonself_call_counts,
    prior_undropped_call_counts,
    self_call_counts,
  }
}

///|
fn dae_boundary_syntax_frozen_collect_original_param_counts_with_type_indices(
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
) -> Array[Int32] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let counts : Array[Int32] = []
  let mut def_idx = 0
  while def_idx < defined {
    match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_,
        type_indices,
        imported + def_idx,
      ) {
      Some(@lib.FuncType(params, _)) => counts.push(params.length())
      None => counts.push(0)
    }
    def_idx += 1
  }
  counts
}

///|
fn dae_boundary_syntax_frozen_collect_original_boundary_snapshot(
  mod_ : @lib.Module,
) -> DaeOriginalBoundarySnapshot {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let total = imported + defined
  let type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  let exposure = dae_boundary_syntax_frozen_collect_original_exposure(
    mod_, total, type_indices,
  )
  let escaped = dae_boundary_syntax_frozen_exposure_to_escaped(exposure)
  let param_counts = dae_boundary_syntax_frozen_collect_original_param_counts_with_type_indices(
    mod_, type_indices,
  )
  let call_summary = dae_boundary_syntax_frozen_collect_original_call_summary_with_context(
    mod_, imported, defined, type_indices, escaped,
  )
  let private_result_dead_suffix_call_counts = dae_boundary_syntax_frozen_collect_original_private_result_dead_suffix_call_counts_with_escaped(
    mod_,
    call_summary.call_counts,
    escaped,
  )
  let private_result_same_operand_call_counts = dae_boundary_syntax_frozen_collect_original_private_result_same_operand_call_counts_with_escaped(
    mod_, escaped,
  )
  let dead_suffix_escaped_result_call_facts = dae_boundary_syntax_frozen_collect_original_dead_suffix_escaped_result_call_facts_with_escaped(
    mod_, escaped,
  )
  let escaped_result_operand_call_facts = dae_boundary_syntax_frozen_collect_original_escaped_result_operand_call_facts_with_escaped(
    mod_, escaped, dead_suffix_escaped_result_call_facts,
  )
  let private_result_dead_suffix_calls_from_escaped_operand_callees = dae_boundary_syntax_frozen_collect_original_private_result_dead_suffix_calls_from_escaped_operand_callees(
    mod_,
    escaped_result_operand_call_facts.dead_suffix_escaped_result_operand_call_counts,
  )
  let escaped_dead_suffix_call_counts = dae_boundary_syntax_frozen_collect_original_escaped_dead_suffix_call_counts_with_escaped(
    mod_, escaped,
  )
  let escaped_undropped_dead_suffix_call_counts = dae_boundary_syntax_frozen_collect_original_escaped_undropped_dead_suffix_call_counts_with_escaped(
    mod_, escaped,
  )
  let dead_suffix_other_calls = dae_boundary_syntax_frozen_collect_original_dead_suffix_other_calls(
    mod_,
  )
  let dead_suffix_undropped_self_calls = dae_boundary_syntax_frozen_collect_original_dead_suffix_undropped_self_calls(
    mod_,
  )
  let dead_suffix_dropped_self_calls = dae_boundary_syntax_frozen_collect_original_dead_suffix_dropped_self_calls(
    mod_,
  )
  let dead_suffix_block_undropped_self_calls = dae_boundary_syntax_frozen_collect_original_dead_suffix_block_undropped_self_calls(
    mod_,
  )
  let dead_suffix_dropped_self_call_full_param_forwards = dae_boundary_syntax_frozen_collect_original_dead_suffix_dropped_self_call_full_param_forwards(
    mod_,
  )
  let dead_suffix_result_calls_from_undropped_self_callers = dae_boundary_syntax_frozen_collect_original_dead_suffix_result_calls_from_undropped_self_callers_with_escaped(
    mod_,
    call_summary.nonself_undropped_call_counts,
    escaped,
  )
  let dead_suffix_result_calls_from_no_param_undropped_self_callers = dae_boundary_syntax_frozen_collect_original_dead_suffix_result_calls_from_no_param_undropped_self_callers(
    mod_,
  )
  let dead_suffix_undropped_calls_from_parameterized_dropped_self_callers = dae_boundary_syntax_frozen_collect_original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers(
    mod_,
  )
  let dead_suffix_dropped_calls_from_parameterized_self_callers = dae_boundary_syntax_frozen_collect_original_dead_suffix_dropped_calls_from_parameterized_self_callers(
    mod_,
  )
  let dead_suffix_dropped_calls_from_no_param_result_callers = dae_boundary_syntax_frozen_collect_original_dead_suffix_dropped_calls_from_no_param_result_callers(
    mod_,
  )
  let dead_suffix_mixed_dropped_undropped_call_counts = dae_boundary_syntax_frozen_collect_original_dead_suffix_mixed_dropped_undropped_call_counts_with_escaped(
    mod_, escaped,
  )
  let dead_suffix_dropped_earlier_result_calls = dae_boundary_syntax_frozen_collect_original_dead_suffix_dropped_earlier_result_calls(
    mod_,
  )
  let later_dead_suffix_dropped_call_counts = dae_boundary_syntax_frozen_collect_original_later_dead_suffix_dropped_call_counts(
    mod_,
  )
  let dead_suffix_same_self_result_operand_calls = dae_boundary_syntax_frozen_collect_original_dead_suffix_same_self_result_operand_calls(
    mod_,
  )
  let dead_suffix_undropped_self_call_param_operands = dae_boundary_syntax_frozen_collect_original_dead_suffix_undropped_self_call_param_operands(
    mod_,
  )
  let dead_suffix_result_other_calls = dae_boundary_syntax_frozen_collect_original_dead_suffix_result_other_calls_with_escaped(
    mod_, escaped,
  )
  let dead_suffix_self_recursive_void_side_calls = dae_boundary_syntax_frozen_collect_original_dead_suffix_self_recursive_void_side_calls(
    mod_,
  )
  let dead_suffix_self_recursive_result_side_calls = dae_boundary_syntax_frozen_collect_original_dead_suffix_self_recursive_result_side_calls(
    mod_,
  )
  let dead_suffix_mutual_calls = dae_boundary_syntax_frozen_collect_original_dead_suffix_mutual_calls(
    mod_,
  )
  let dead_suffix_calls_from_param_operand_self_result_callers = dae_boundary_syntax_frozen_collect_original_dead_suffix_calls_from_param_operand_self_result_callers(
    mod_,
    param_counts,
    call_summary.call_counts,
    call_summary.active_nonself_call_counts,
    call_summary.active_parameterized_nonself_call_counts,
    call_summary.nonself_undropped_call_counts,
    call_summary.self_call_counts,
    escaped_dead_suffix_call_counts,
    dead_suffix_undropped_self_calls,
    dead_suffix_undropped_self_call_param_operands,
    dead_suffix_result_other_calls,
    dead_suffix_mutual_calls,
  )
  {
    imported,
    defined,
    total,
    type_indices,
    escaped,
    exposure,
    param_counts,
    large_unreachable_prefixes: dae_boundary_syntax_frozen_collect_original_large_unreachable_prefixes(
      mod_,
    ),
    call_summary,
    private_result_dead_suffix_call_counts,
    private_result_same_operand_call_counts,
    escaped_result_operand_call_facts,
    private_result_dead_suffix_calls_from_escaped_operand_callees,
    escaped_dead_suffix_call_counts,
    escaped_undropped_dead_suffix_call_counts,
    dead_suffix_other_calls,
    dead_suffix_undropped_self_calls,
    dead_suffix_dropped_self_calls,
    dead_suffix_block_undropped_self_calls,
    dead_suffix_dropped_self_call_full_param_forwards,
    dead_suffix_result_calls_from_undropped_self_callers,
    dead_suffix_result_calls_from_no_param_undropped_self_callers,
    dead_suffix_undropped_calls_from_parameterized_dropped_self_callers,
    dead_suffix_dropped_calls_from_parameterized_self_callers,
    dead_suffix_dropped_calls_from_no_param_result_callers,
    dead_suffix_mixed_dropped_undropped_call_counts,
    dead_suffix_dropped_earlier_result_calls,
    later_dead_suffix_dropped_call_counts,
    dead_suffix_same_self_result_operand_calls,
    dead_suffix_undropped_self_call_param_operands,
    dead_suffix_calls_from_param_operand_self_result_callers,
    dead_suffix_result_other_calls,
    dead_suffix_self_recursive_void_side_calls,
    dead_suffix_self_recursive_result_side_calls,
    dead_suffix_escaped_result_call_facts,
    dead_suffix_mutual_calls,
  }
}

///|
fn dae_boundary_syntax_frozen_collect_original_self_call_counts(
  mod_ : @lib.Module,
) -> Array[Int32] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return []
  }
  let counts : Array[Int32] = []
  let mut def_idx = 0
  while def_idx < funcs.length() {
    counts.push(
      dae_boundary_syntax_frozen_count_self_calls_anywhere(
        funcs[def_idx],
        imported + def_idx,
      ),
    )
    def_idx += 1
  }
  counts
}

///|
fn dae_boundary_syntax_frozen_collect_dead_suffix_direct_targets(
  instrs : Array[@lib.Instruction],
  imported : Int32,
  defined : Int32,
  targets : Array[Int32],
) -> Unit {
  match
    dae_boundary_syntax_frozen_dead_suffix_direct_target_evidence(
      instrs, imported, defined,
    ) {
    Some(evidence) =>
      dae_boundary_syntax_frozen_append_targets(
        targets,
        evidence.direct_targets,
      )
    None => ()
  }
}

///|
fn dae_boundary_syntax_frozen_count_dead_suffix_direct_call_to(
  instrs : Array[@lib.Instruction],
  callee_abs : Int32,
) -> Int32 {
  match dae_boundary_syntax_frozen_dead_suffix_evidence(instrs) {
    Some(evidence) =>
      dae_boundary_syntax_frozen_count_direct_call_anywhere_to(
        evidence.body,
        callee_abs,
        start_idx=evidence.suffix_start,
      )
    None => 0
  }
}

///|
fn dae_boundary_syntax_frozen_empty_escaped_result_direct_call_evidence() -> DaeEscapedResultDirectCallEvidence {
  {
    has_dropped_escaped_result_call: false,
    has_undropped_escaped_result_call: false,
  }
}

///|
fn dae_boundary_syntax_frozen_merge_escaped_result_direct_call_evidence(
  left : DaeEscapedResultDirectCallEvidence,
  right : DaeEscapedResultDirectCallEvidence,
) -> DaeEscapedResultDirectCallEvidence {
  {
    has_dropped_escaped_result_call: left.has_dropped_escaped_result_call ||
    right.has_dropped_escaped_result_call,
    has_undropped_escaped_result_call: left.has_undropped_escaped_result_call ||
    right.has_undropped_escaped_result_call,
  }
}

///|
fn dae_boundary_syntax_frozen_call_escaped_result_direct_call_evidence(
  func_idx : @lib.FuncIdx,
  dropped : Bool,
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  escaped : Array[Bool],
) -> DaeEscapedResultDirectCallEvidence {
  let slot = dae_boundary_syntax_frozen_func_idx_slot(func_idx)
  if slot >= 0 && slot < escaped.length() && escaped[slot] {
    match
      dae_boundary_syntax_frozen_resolve_func_type(mod_, type_indices, slot) {
      Some(@lib.FuncType(_, results)) if results.length() > 0 =>
        return {
          has_dropped_escaped_result_call: dropped,
          has_undropped_escaped_result_call: !dropped,
        }
      _ => ()
    }
  }
  dae_boundary_syntax_frozen_empty_escaped_result_direct_call_evidence()
}

///|
fn dae_boundary_syntax_frozen_escaped_result_direct_call_evidence(
  instrs : Array[@lib.Instruction],
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  escaped : Array[Bool],
  start_idx~ : Int32 = 0,
) -> DaeEscapedResultDirectCallEvidence {
  let mut evidence = dae_boundary_syntax_frozen_empty_escaped_result_direct_call_evidence()
  let mut idx = start_idx
  while idx < instrs.length() {
    let instr_evidence = match instrs[idx] {
      @lib.Call(func_idx) =>
        dae_boundary_syntax_frozen_call_escaped_result_direct_call_evidence(
          func_idx,
          idx + 1 < instrs.length() &&
          instrs[idx + 1] == @lib.Instruction::drop(),
          mod_,
          type_indices,
          escaped,
        )
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        dae_boundary_syntax_frozen_escaped_result_direct_call_evidence(
          body, mod_, type_indices, escaped,
        )
      @lib.If(_, then_body, Some(else_body)) =>
        dae_boundary_syntax_frozen_merge_escaped_result_direct_call_evidence(
          dae_boundary_syntax_frozen_escaped_result_direct_call_evidence(
            then_body, mod_, type_indices, escaped,
          ),
          dae_boundary_syntax_frozen_escaped_result_direct_call_evidence(
            else_body, mod_, type_indices, escaped,
          ),
        )
      @lib.If(_, then_body, None) =>
        dae_boundary_syntax_frozen_escaped_result_direct_call_evidence(
          then_body, mod_, type_indices, escaped,
        )
      _ =>
        dae_boundary_syntax_frozen_empty_escaped_result_direct_call_evidence()
    }
    evidence = dae_boundary_syntax_frozen_merge_escaped_result_direct_call_evidence(
      evidence, instr_evidence,
    )
    idx += 1
  }
  evidence
}

///|
fn dae_boundary_syntax_frozen_dead_suffix_escaped_result_direct_call_evidence(
  instrs : Array[@lib.Instruction],
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  escaped : Array[Bool],
) -> DaeEscapedResultDirectCallEvidence? {
  match dae_boundary_syntax_frozen_dead_suffix_evidence(instrs) {
    Some(evidence) =>
      Some(
        dae_boundary_syntax_frozen_escaped_result_direct_call_evidence(
          evidence.body,
          mod_,
          type_indices,
          escaped,
          start_idx=evidence.suffix_start,
        ),
      )
    None => None
  }
}

///|
fn dae_boundary_syntax_frozen_dead_suffix_has_dropped_escaped_result_call(
  instrs : Array[@lib.Instruction],
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  escaped : Array[Bool],
) -> Bool {
  match
    dae_boundary_syntax_frozen_dead_suffix_escaped_result_direct_call_evidence(
      instrs, mod_, type_indices, escaped,
    ) {
    Some(evidence) => evidence.has_dropped_escaped_result_call
    None => false
  }
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_escaped_result_call_facts_with_escaped(
  mod_ : @lib.Module,
  escaped : Array[Bool],
) -> DaeOriginalDeadSuffixEscapedResultCallFacts {
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let dropped_calls = Array::make(defined, false)
  let undropped_calls = Array::make(defined, false)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return { dropped_calls, undropped_calls, }
  }
  let type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  let mut def_idx = 0
  while def_idx < defined {
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    match
      dae_boundary_syntax_frozen_dead_suffix_escaped_result_direct_call_evidence(
        body, mod_, type_indices, escaped,
      ) {
      Some(evidence) => {
        dropped_calls[def_idx] = evidence.has_dropped_escaped_result_call
        undropped_calls[def_idx] = evidence.has_undropped_escaped_result_call
      }
      None => ()
    }
    def_idx += 1
  }
  { dropped_calls, undropped_calls, }
}

///|
fn dae_boundary_syntax_frozen_mark_dead_suffix_escaped_result_operand_targets(
  instrs : Array[@lib.Instruction],
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  escaped : Array[Bool],
  imported : Int32,
  defined : Int32,
  flags : Array[Bool],
) -> Unit {
  let stack_from_escaped_call : Array[Bool] = []
  let mut in_suffix = false
  let mut idx = 0
  while idx < instrs.length() {
    let instr = instrs[idx]
    if !in_suffix {
      if dae_boundary_syntax_frozen_instr_is_unreachable_root(instr) {
        in_suffix = true
      }
      idx += 1
      continue
    }
    match instr {
      @lib.Call(func_idx) => {
        let slot = dae_boundary_syntax_frozen_func_idx_slot(func_idx)
        let def_idx = slot - imported
        if def_idx >= 0 && def_idx < defined && def_idx < flags.length() {
          match
            dae_boundary_syntax_frozen_resolve_func_type(
              mod_, type_indices, slot,
            ) {
            Some(@lib.FuncType(params, _)) =>
              if dae_boundary_syntax_frozen_stack_bool_has_true_operand(
                  stack_from_escaped_call,
                  params.length(),
                ) {
                flags[def_idx] = true
              }
            None => ()
          }
        }
        let from_escaped = slot >= 0 && slot < escaped.length() && escaped[slot]
        ignore(
          dae_boundary_syntax_frozen_stack_bool_apply_instr_effect(
            stack_from_escaped_call, instr, mod_, type_indices, from_escaped,
          ),
        )
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) => {
        dae_boundary_syntax_frozen_mark_dead_suffix_escaped_result_operand_targets(
          body, mod_, type_indices, escaped, imported, defined, flags,
        )
        ignore(
          dae_boundary_syntax_frozen_stack_bool_apply_instr_effect(
            stack_from_escaped_call, instr, mod_, type_indices, false,
          ),
        )
      }
      @lib.If(_, then_body, Some(else_body)) => {
        dae_boundary_syntax_frozen_mark_dead_suffix_escaped_result_operand_targets(
          then_body, mod_, type_indices, escaped, imported, defined, flags,
        )
        dae_boundary_syntax_frozen_mark_dead_suffix_escaped_result_operand_targets(
          else_body, mod_, type_indices, escaped, imported, defined, flags,
        )
        ignore(
          dae_boundary_syntax_frozen_stack_bool_apply_instr_effect(
            stack_from_escaped_call, instr, mod_, type_indices, false,
          ),
        )
      }
      @lib.If(_, then_body, None) => {
        dae_boundary_syntax_frozen_mark_dead_suffix_escaped_result_operand_targets(
          then_body, mod_, type_indices, escaped, imported, defined, flags,
        )
        ignore(
          dae_boundary_syntax_frozen_stack_bool_apply_instr_effect(
            stack_from_escaped_call, instr, mod_, type_indices, false,
          ),
        )
      }
      _ =>
        ignore(
          dae_boundary_syntax_frozen_stack_bool_apply_instr_effect(
            stack_from_escaped_call, instr, mod_, type_indices, false,
          ),
        )
    }
    idx += 1
  }
}

///|
fn dae_boundary_syntax_frozen_mark_dead_suffix_same_result_operand_targets(
  instrs : Array[@lib.Instruction],
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  imported : Int32,
  defined : Int32,
  flags : Array[Bool],
) -> Unit {
  let stack_sources : Array[Int32] = []
  let mut in_suffix = false
  let mut idx = 0
  while idx < instrs.length() {
    let instr = instrs[idx]
    if !in_suffix {
      if dae_boundary_syntax_frozen_instr_is_unreachable_root(instr) {
        in_suffix = true
      }
      idx += 1
      continue
    }
    match instr {
      @lib.Call(func_idx) => {
        let slot = dae_boundary_syntax_frozen_func_idx_slot(func_idx)
        let def_idx = slot - imported
        let source = if slot >= imported && def_idx >= 0 && def_idx < defined {
          def_idx
        } else {
          -1
        }
        if source >= 0 && source < flags.length() {
          match
            dae_boundary_syntax_frozen_resolve_func_type(
              mod_, type_indices, slot,
            ) {
            Some(@lib.FuncType(params, _)) =>
              if dae_boundary_syntax_frozen_stack_int_has_operand_value(
                  stack_sources,
                  params.length(),
                  source,
                ) {
                flags[source] = true
              }
            None => ()
          }
        }
        ignore(
          dae_boundary_syntax_frozen_stack_int_apply_instr_effect(
            stack_sources, instr, mod_, type_indices, source,
          ),
        )
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) => {
        dae_boundary_syntax_frozen_mark_dead_suffix_same_result_operand_targets(
          body, mod_, type_indices, imported, defined, flags,
        )
        ignore(
          dae_boundary_syntax_frozen_stack_int_apply_instr_effect(
            stack_sources, instr, mod_, type_indices, -1,
          ),
        )
      }
      @lib.If(_, then_body, Some(else_body)) => {
        dae_boundary_syntax_frozen_mark_dead_suffix_same_result_operand_targets(
          then_body, mod_, type_indices, imported, defined, flags,
        )
        dae_boundary_syntax_frozen_mark_dead_suffix_same_result_operand_targets(
          else_body, mod_, type_indices, imported, defined, flags,
        )
        ignore(
          dae_boundary_syntax_frozen_stack_int_apply_instr_effect(
            stack_sources, instr, mod_, type_indices, -1,
          ),
        )
      }
      @lib.If(_, then_body, None) => {
        dae_boundary_syntax_frozen_mark_dead_suffix_same_result_operand_targets(
          then_body, mod_, type_indices, imported, defined, flags,
        )
        ignore(
          dae_boundary_syntax_frozen_stack_int_apply_instr_effect(
            stack_sources, instr, mod_, type_indices, -1,
          ),
        )
      }
      _ =>
        ignore(
          dae_boundary_syntax_frozen_stack_int_apply_instr_effect(
            stack_sources, instr, mod_, type_indices, -1,
          ),
        )
    }
    idx += 1
  }
}

///|
fn dae_boundary_syntax_frozen_dead_suffix_call_to_has_same_result_operand(
  instrs : Array[@lib.Instruction],
  callee_abs : Int32,
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
) -> Bool {
  let (param_count, result_count) = match
    dae_boundary_syntax_frozen_resolve_func_type(mod_, type_indices, callee_abs) {
    Some(@lib.FuncType(params, results)) => (params.length(), results.length())
    None => return false
  }
  let stack_from_target_call : Array[Bool] = []
  let mut in_suffix = false
  let mut idx = 0
  while idx < instrs.length() {
    let instr = instrs[idx]
    if !in_suffix {
      if dae_boundary_syntax_frozen_instr_is_unreachable_root(instr) {
        in_suffix = true
      }
      idx += 1
      continue
    }
    match instr {
      @lib.Call(func_idx) if dae_boundary_syntax_frozen_func_idx_slot(func_idx) ==
        callee_abs => {
        if dae_boundary_syntax_frozen_stack_bool_has_true_operand(
            stack_from_target_call, param_count,
          ) {
          return true
        }
        dae_boundary_syntax_frozen_stack_bool_apply_effect(
          stack_from_target_call, param_count, result_count, true,
        )
      }
      @lib.Call(_) =>
        ignore(
          dae_boundary_syntax_frozen_stack_bool_apply_instr_effect(
            stack_from_target_call, instr, mod_, type_indices, false,
          ),
        )
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) => {
        if dae_boundary_syntax_frozen_dead_suffix_call_to_has_same_result_operand(
            body, callee_abs, mod_, type_indices,
          ) {
          return true
        }
        ignore(
          dae_boundary_syntax_frozen_stack_bool_apply_instr_effect(
            stack_from_target_call, instr, mod_, type_indices, false,
          ),
        )
      }
      @lib.If(_, then_body, Some(else_body)) => {
        if dae_boundary_syntax_frozen_dead_suffix_call_to_has_same_result_operand(
            then_body, callee_abs, mod_, type_indices,
          ) ||
          dae_boundary_syntax_frozen_dead_suffix_call_to_has_same_result_operand(
            else_body, callee_abs, mod_, type_indices,
          ) {
          return true
        }
        ignore(
          dae_boundary_syntax_frozen_stack_bool_apply_instr_effect(
            stack_from_target_call, instr, mod_, type_indices, false,
          ),
        )
      }
      @lib.If(_, then_body, None) => {
        if dae_boundary_syntax_frozen_dead_suffix_call_to_has_same_result_operand(
            then_body, callee_abs, mod_, type_indices,
          ) {
          return true
        }
        ignore(
          dae_boundary_syntax_frozen_stack_bool_apply_instr_effect(
            stack_from_target_call, instr, mod_, type_indices, false,
          ),
        )
      }
      _ =>
        ignore(
          dae_boundary_syntax_frozen_stack_bool_apply_instr_effect(
            stack_from_target_call, instr, mod_, type_indices, false,
          ),
        )
    }
    idx += 1
  }
  false
}

///|
fn dae_boundary_syntax_frozen_collect_original_private_result_same_operand_call_counts_with_escaped(
  mod_ : @lib.Module,
  escaped : Array[Bool],
) -> Array[Int32] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_is_private_result = match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, caller_abs,
      ) {
      Some(@lib.FuncType(_, results)) => results.length() > 0
      None => false
    }
    if caller_is_private_result && !escaped[caller_abs] {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let flags = Array::make(defined, false)
      dae_boundary_syntax_frozen_mark_dead_suffix_same_result_operand_targets(
        body, mod_, type_indices, imported, defined, flags,
      )
      let mut callee_def = 0
      while callee_def < defined {
        if callee_def != caller_def && flags[callee_def] {
          counts[callee_def] = counts[callee_def] + 1
        }
        callee_def += 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_result_calls_from_undropped_self_callers_with_escaped(
  mod_ : @lib.Module,
  original_nonself_undropped_call_counts : Array[Int32],
  escaped : Array[Bool],
) -> Array[Int32] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_has_params_and_result = match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, caller_abs,
      ) {
      Some(@lib.FuncType(params, results)) =>
        params.length() > 0 && results.length() > 0
      None => false
    }
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    let caller_has_undropped_self_suffix = dae_boundary_syntax_frozen_dead_suffix_has_undropped_direct_call_to(
      body, caller_abs,
    )
    let caller_has_dropped_escaped_result_suffix = dae_boundary_syntax_frozen_dead_suffix_has_dropped_escaped_result_call(
      body, mod_, type_indices, escaped,
    )
    let caller_has_undropped_nonself_caller = caller_def <
      original_nonself_undropped_call_counts.length() &&
      original_nonself_undropped_call_counts[caller_def] > 0
    if caller_has_params_and_result &&
      caller_has_undropped_self_suffix &&
      caller_has_undropped_nonself_caller &&
      !caller_has_dropped_escaped_result_suffix &&
      !escaped[caller_abs] {
      let targets : Array[Int32] = []
      dae_boundary_syntax_frozen_collect_dead_suffix_direct_targets(
        body, imported, defined, targets,
      )
      for target in targets {
        if target != caller_def {
          counts[target] = counts[target] + 1
        }
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_result_calls_from_no_param_undropped_self_callers(
  mod_ : @lib.Module,
) -> Array[Int32] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_is_no_param_result = match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, caller_abs,
      ) {
      Some(@lib.FuncType(params, results)) =>
        params.length() == 0 && results.length() > 0
      None => false
    }
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    if caller_is_no_param_result &&
      dae_boundary_syntax_frozen_dead_suffix_has_undropped_direct_call_to(
        body, caller_abs,
      ) {
      let targets : Array[Int32] = []
      dae_boundary_syntax_frozen_collect_dead_suffix_direct_targets(
        body, imported, defined, targets,
      )
      for target in targets {
        if target != caller_def {
          counts[target] = counts[target] + 1
        }
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers(
  mod_ : @lib.Module,
) -> Array[Int32] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let counted_stamp = Array::make(defined, -1)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_has_params_and_result = match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, caller_abs,
      ) {
      Some(@lib.FuncType(params, results)) =>
        params.length() > 0 && results.length() > 0
      None => false
    }
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    if caller_has_params_and_result &&
      dae_boundary_syntax_frozen_dead_suffix_has_dropped_direct_call_to(
        body, caller_abs,
      ) {
      let targets : Array[Int32] = []
      dae_boundary_syntax_frozen_collect_dead_suffix_undropped_direct_targets(
        body, imported, defined, targets,
      )
      for target in targets {
        if target != caller_def && counted_stamp[target] != caller_def {
          counts[target] = counts[target] + 1
          counted_stamp[target] = caller_def
        }
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_mixed_dropped_undropped_call_counts_with_escaped(
  mod_ : @lib.Module,
  escaped : Array[Bool],
) -> Array[Int32] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let counts = Array::make(defined, 0)
  let dropped_stamp = Array::make(defined, -1)
  let counted_stamp = Array::make(defined, -1)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    if escaped[caller_abs] {
      caller_def += 1
      continue
    }
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    let dropped_targets : Array[Int32] = []
    dae_boundary_syntax_frozen_collect_dead_suffix_dropped_direct_targets(
      body, imported, defined, dropped_targets,
    )
    for target in dropped_targets {
      dropped_stamp[target] = caller_def
    }
    let undropped_targets : Array[Int32] = []
    dae_boundary_syntax_frozen_collect_dead_suffix_undropped_direct_targets(
      body, imported, defined, undropped_targets,
    )
    for target in undropped_targets {
      if target != caller_def &&
        dropped_stamp[target] == caller_def &&
        counted_stamp[target] != caller_def {
        counts[target] = counts[target] + 1
        counted_stamp[target] = caller_def
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_dropped_earlier_result_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, false)
  }
  let result_flags = Array::make(defined, false)
  let mut callee_def = 0
  while callee_def < defined {
    let callee_abs = imported + callee_def
    result_flags[callee_def] = match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, callee_abs,
      ) {
      Some(@lib.FuncType(_, results)) => results.length() > 0
      None => false
    }
    callee_def += 1
  }
  let flags = Array::make(defined, false)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    let dropped_targets : Array[Int32] = []
    dae_boundary_syntax_frozen_collect_dead_suffix_dropped_direct_targets(
      body, imported, defined, dropped_targets,
    )
    for target in dropped_targets {
      if target < caller_def && result_flags[target] {
        flags[caller_def] = true
      }
    }
    caller_def += 1
  }
  flags
}

///|
fn dae_boundary_syntax_frozen_collect_original_later_dead_suffix_dropped_call_counts(
  mod_ : @lib.Module,
) -> Array[Int32] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let counts = Array::make(defined, 0)
  let counted_stamp = Array::make(defined, -1)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    let dropped_targets : Array[Int32] = []
    dae_boundary_syntax_frozen_collect_dead_suffix_dropped_direct_targets(
      body, imported, defined, dropped_targets,
    )
    for target in dropped_targets {
      if target < caller_def && counted_stamp[target] != caller_def {
        counts[target] = counts[target] + 1
        counted_stamp[target] = caller_def
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_dropped_calls_from_parameterized_self_callers(
  mod_ : @lib.Module,
) -> Array[Int32] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let counted_stamp = Array::make(defined, -1)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_has_params_and_result = match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, caller_abs,
      ) {
      Some(@lib.FuncType(params, results)) =>
        params.length() > 0 && results.length() > 0
      None => false
    }
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    if caller_has_params_and_result &&
      dae_boundary_syntax_frozen_dead_suffix_has_undropped_direct_call_to(
        body, caller_abs,
      ) {
      let targets : Array[Int32] = []
      dae_boundary_syntax_frozen_collect_dead_suffix_dropped_direct_targets(
        body, imported, defined, targets,
      )
      for target in targets {
        if target != caller_def && counted_stamp[target] != caller_def {
          counts[target] = counts[target] + 1
          counted_stamp[target] = caller_def
        }
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_dropped_calls_from_no_param_result_callers(
  mod_ : @lib.Module,
) -> Array[Int32] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let counted_stamp = Array::make(defined, -1)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_has_no_params_and_result = match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, caller_abs,
      ) {
      Some(@lib.FuncType(params, results)) =>
        params.length() == 0 && results.length() > 0
      None => false
    }
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    if caller_has_no_params_and_result {
      let targets : Array[Int32] = []
      dae_boundary_syntax_frozen_collect_dead_suffix_dropped_direct_targets(
        body, imported, defined, targets,
      )
      for target in targets {
        if target != caller_def && counted_stamp[target] != caller_def {
          counts[target] = counts[target] + 1
          counted_stamp[target] = caller_def
        }
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_boundary_syntax_frozen_collect_original_escaped_result_operand_call_facts_with_escaped(
  mod_ : @lib.Module,
  escaped : Array[Bool],
  dead_suffix_escaped_result_calls : DaeOriginalDeadSuffixEscapedResultCallFacts,
) -> DaeOriginalEscapedResultOperandCallFacts {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let dead_suffix_escaped_result_operand_call_counts = Array::make(defined, 0)
  let private_result_escaped_operand_call_counts = Array::make(defined, 0)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None =>
      return {
        dead_suffix_escaped_result_operand_call_counts,
        private_result_escaped_operand_call_counts,
      }
  }
  let type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_is_escaped = escaped[caller_abs]
    let caller_has_result = match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, caller_abs,
      ) {
      Some(@lib.FuncType(_, results)) => results.length() > 0
      None => false
    }
    let caller_is_private_result = !caller_is_escaped && caller_has_result
    if caller_is_escaped || caller_is_private_result {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let flags = Array::make(defined, false)
      dae_boundary_syntax_frozen_mark_dead_suffix_escaped_result_operand_targets(
        body, mod_, type_indices, escaped, imported, defined, flags,
      )
      let mut callee_def = 0
      while callee_def < defined {
        if callee_def != caller_def && flags[callee_def] {
          if caller_is_escaped {
            dead_suffix_escaped_result_operand_call_counts[callee_def] = dead_suffix_escaped_result_operand_call_counts[callee_def] +
              1
          }
          if caller_is_private_result &&
            callee_def < dead_suffix_escaped_result_calls.dropped_calls.length() &&
            dead_suffix_escaped_result_calls.dropped_calls[callee_def] {
            private_result_escaped_operand_call_counts[callee_def] = private_result_escaped_operand_call_counts[callee_def] +
              1
          }
        }
        callee_def += 1
      }
    }
    caller_def += 1
  }
  {
    dead_suffix_escaped_result_operand_call_counts,
    private_result_escaped_operand_call_counts,
  }
}

///|
fn dae_boundary_syntax_frozen_collect_original_private_result_dead_suffix_calls_from_escaped_operand_callees(
  mod_ : @lib.Module,
  escaped_operand_counts : Array[Int32],
) -> Array[Int32] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_has_params_and_result = match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, caller_abs,
      ) {
      Some(@lib.FuncType(params, results)) =>
        params.length() > 0 && results.length() > 0
      None => false
    }
    if caller_has_params_and_result &&
      caller_def < escaped_operand_counts.length() &&
      escaped_operand_counts[caller_def] > 0 {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let targets : Array[Int32] = []
      dae_boundary_syntax_frozen_collect_dead_suffix_direct_targets(
        body, imported, defined, targets,
      )
      for target in targets {
        if target != caller_def {
          counts[target] = counts[target] + 1
        }
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_same_self_result_operand_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, false)
  }
  let flags = Array::make(defined, false)
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let callee_abs = imported + def_idx
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    flags[def_idx] = dae_boundary_syntax_frozen_dead_suffix_call_to_has_same_result_operand(
      body, callee_abs, mod_, type_indices,
    )
    def_idx += 1
  }
  flags
}

///|
fn dae_boundary_syntax_frozen_collect_original_private_result_dead_suffix_call_counts_with_escaped(
  mod_ : @lib.Module,
  original_call_counts : Array[Int32],
  escaped : Array[Bool],
) -> Array[Int32] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    let caller_has_params_and_result = match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, caller_abs,
      ) {
      Some(@lib.FuncType(params, results)) =>
        params.length() > 0 && results.length() > 0
      None => false
    }
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    let caller_has_undropped_self_suffix = dae_boundary_syntax_frozen_dead_suffix_has_undropped_direct_call_to(
      body, caller_abs,
    )
    let caller_has_dropped_escaped_result_suffix = dae_boundary_syntax_frozen_dead_suffix_has_dropped_escaped_result_call(
      body, mod_, type_indices, escaped,
    )
    if caller_has_params_and_result &&
      !caller_has_undropped_self_suffix &&
      !caller_has_dropped_escaped_result_suffix &&
      !escaped[caller_abs] &&
      caller_def < original_call_counts.length() &&
      original_call_counts[caller_def] > 0 {
      let targets : Array[Int32] = []
      dae_boundary_syntax_frozen_collect_dead_suffix_direct_targets(
        body, imported, defined, targets,
      )
      for target in targets {
        counts[target] = counts[target] + 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_boundary_syntax_frozen_collect_original_escaped_dead_suffix_call_counts_with_escaped(
  mod_ : @lib.Module,
  escaped : Array[Bool],
) -> Array[Int32] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    if escaped[caller_abs] {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let targets : Array[Int32] = []
      dae_boundary_syntax_frozen_collect_dead_suffix_direct_targets(
        body, imported, defined, targets,
      )
      for target in targets {
        counts[target] = counts[target] + 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_boundary_syntax_frozen_collect_original_escaped_undropped_dead_suffix_call_counts_with_escaped(
  mod_ : @lib.Module,
  escaped : Array[Bool],
) -> Array[Int32] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let counts = Array::make(defined, 0)
  let counted_stamp = Array::make(defined, -1)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let caller_abs = imported + caller_def
    if escaped[caller_abs] {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let targets : Array[Int32] = []
      dae_boundary_syntax_frozen_collect_dead_suffix_undropped_direct_targets(
        body, imported, defined, targets,
      )
      for target in targets {
        if counted_stamp[target] != caller_def {
          counts[target] = counts[target] + 1
          counted_stamp[target] = caller_def
        }
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_other_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return []
  }
  let flags : Array[Bool] = []
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    flags.push(
      dae_boundary_syntax_frozen_dead_suffix_has_other_call(
        body,
        imported + def_idx,
      ),
    )
    def_idx += 1
  }
  flags
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_undropped_self_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return []
  }
  let flags : Array[Bool] = []
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    flags.push(
      dae_boundary_syntax_frozen_dead_suffix_has_undropped_direct_call_to(
        body,
        imported + def_idx,
      ),
    )
    def_idx += 1
  }
  flags
}

///|
fn dae_boundary_syntax_frozen_instrs_have_undropped_call_to_with_param_operand(
  instrs : Array[@lib.Instruction],
  callee_abs : Int32,
  param_count : Int32,
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  start_idx~ : Int32 = 0,
) -> Bool {
  let stack : Array[Int32] = []
  let mut idx = start_idx
  while idx < instrs.length() {
    match instrs[idx] {
      @lib.LocalGet(local_idx) => {
        let slot = dae_boundary_syntax_frozen_local_idx_slot(local_idx)
        if slot >= 0 && slot < param_count {
          stack.push(slot)
        } else {
          stack.push(-1)
        }
      }
      @lib.Call(func_idx) if dae_boundary_syntax_frozen_func_idx_slot(func_idx) ==
        callee_abs => {
        if dae_boundary_syntax_frozen_stack_int_has_known_operand(
            stack, param_count,
          ) &&
          !(idx + 1 < instrs.length() &&
          instrs[idx + 1] == @lib.Instruction::drop()) {
          return true
        }
        let result_count = match
          dae_boundary_syntax_frozen_resolve_func_type(
            mod_, type_indices, callee_abs,
          ) {
          Some(@lib.FuncType(_, results)) => results.length()
          None => 0
        }
        dae_boundary_syntax_frozen_stack_int_apply_effect(
          stack, param_count, result_count, -1,
        )
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) => {
        if dae_boundary_syntax_frozen_instrs_have_undropped_call_to_with_param_operand(
            body, callee_abs, param_count, mod_, type_indices,
          ) {
          return true
        }
        ignore(
          dae_boundary_syntax_frozen_stack_int_apply_instr_effect(
            stack,
            instrs[idx],
            mod_,
            type_indices,
            -1,
          ),
        )
      }
      @lib.If(_, then_body, Some(else_body)) => {
        if dae_boundary_syntax_frozen_instrs_have_undropped_call_to_with_param_operand(
            then_body, callee_abs, param_count, mod_, type_indices,
          ) ||
          dae_boundary_syntax_frozen_instrs_have_undropped_call_to_with_param_operand(
            else_body, callee_abs, param_count, mod_, type_indices,
          ) {
          return true
        }
        ignore(
          dae_boundary_syntax_frozen_stack_int_apply_instr_effect(
            stack,
            instrs[idx],
            mod_,
            type_indices,
            -1,
          ),
        )
      }
      @lib.If(_, then_body, None) => {
        if dae_boundary_syntax_frozen_instrs_have_undropped_call_to_with_param_operand(
            then_body, callee_abs, param_count, mod_, type_indices,
          ) {
          return true
        }
        ignore(
          dae_boundary_syntax_frozen_stack_int_apply_instr_effect(
            stack,
            instrs[idx],
            mod_,
            type_indices,
            -1,
          ),
        )
      }
      _ =>
        ignore(
          dae_boundary_syntax_frozen_stack_int_apply_instr_effect(
            stack,
            instrs[idx],
            mod_,
            type_indices,
            -1,
          ),
        )
    }
    idx += 1
  }
  false
}

///|
fn dae_boundary_syntax_frozen_dead_suffix_has_undropped_self_call_param_operand(
  instrs : Array[@lib.Instruction],
  callee_abs : Int32,
  param_count : Int32,
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
) -> Bool {
  match dae_boundary_syntax_frozen_dead_suffix_evidence(instrs) {
    Some(evidence) =>
      dae_boundary_syntax_frozen_instrs_have_undropped_call_to_with_param_operand(
        evidence.body,
        callee_abs,
        param_count,
        mod_,
        type_indices,
        start_idx=evidence.suffix_start,
      )
    None => false
  }
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_undropped_self_call_param_operands(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return []
  }
  let flags : Array[Bool] = []
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let callee_abs = imported + def_idx
    let param_count = match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, callee_abs,
      ) {
      Some(@lib.FuncType(params, _)) => params.length()
      None => 0
    }
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    flags.push(
      param_count > 0 &&
      dae_boundary_syntax_frozen_dead_suffix_has_undropped_self_call_param_operand(
        body, callee_abs, param_count, mod_, type_indices,
      ),
    )
    def_idx += 1
  }
  flags
}

///|
fn dae_boundary_syntax_frozen_dead_suffix_has_block_undropped_direct_call_to(
  instrs : Array[@lib.Instruction],
  callee_abs : Int32,
) -> Bool {
  let mut idx = 0
  while idx < instrs.length() {
    if dae_boundary_syntax_frozen_instr_is_unreachable_root(instrs[idx]) {
      let mut suffix_idx = idx + 1
      while suffix_idx < instrs.length() {
        match
          dae_boundary_syntax_frozen_control_result_undropped_direct_call_evidence(
            instrs[suffix_idx],
            callee_abs,
          ) {
          Some(evidence) if dae_boundary_syntax_frozen_control_result_undropped_direct_call_evidence_is_consistent(
              evidence,
            ) &&
            evidence.blocks_result_removal => return true
          _ => ()
        }
        suffix_idx += 1
      }
      return false
    }
    idx += 1
  }
  false
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_block_undropped_self_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return []
  }
  let flags : Array[Bool] = []
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    flags.push(
      dae_boundary_syntax_frozen_dead_suffix_has_block_undropped_direct_call_to(
        body,
        imported + def_idx,
      ),
    )
    def_idx += 1
  }
  flags
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_dropped_self_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return []
  }
  let flags : Array[Bool] = []
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    flags.push(
      dae_boundary_syntax_frozen_dead_suffix_has_dropped_direct_call_to(
        body,
        imported + def_idx,
      ),
    )
    def_idx += 1
  }
  flags
}

///|
fn dae_boundary_syntax_frozen_dead_suffix_has_dropped_self_call_full_param_forward(
  instrs : Array[@lib.Instruction],
  callee_abs : Int32,
  param_count : Int32,
) -> Bool {
  if param_count == 0 {
    return false
  }
  let mut idx = 0
  while idx < instrs.length() {
    if dae_boundary_syntax_frozen_instr_is_unreachable_root(instrs[idx]) {
      let mut suffix_idx = idx + 1
      while suffix_idx + 1 < instrs.length() {
        match (instrs[suffix_idx], instrs[suffix_idx + 1]) {
          (@lib.Call(func_idx), @lib.Drop) if dae_boundary_syntax_frozen_func_idx_slot(
              func_idx,
            ) ==
            callee_abs =>
            match
              dae_boundary_syntax_frozen_adjacent_param_forward_evidence(
                instrs, suffix_idx, param_count,
              ) {
              Some(evidence) if evidence.start >= idx + 1 &&
                evidence.end == suffix_idx => return true
              _ => ()
            }
          _ => ()
        }
        suffix_idx += 1
      }
      return false
    }
    idx += 1
  }
  false
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_dropped_self_call_full_param_forwards(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return []
  }
  let flags : Array[Bool] = []
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let callee_abs = imported + def_idx
    let param_count = match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, callee_abs,
      ) {
      Some(@lib.FuncType(params, _)) => params.length()
      None => 0
    }
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    flags.push(
      dae_boundary_syntax_frozen_dead_suffix_has_dropped_self_call_full_param_forward(
        body, callee_abs, param_count,
      ),
    )
    def_idx += 1
  }
  flags
}

///|
fn dae_boundary_syntax_frozen_instrs_have_private_result_direct_call_other_than(
  instrs : Array[@lib.Instruction],
  callee_abs : Int32,
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  escaped : Array[Bool],
  start_idx~ : Int32 = 0,
) -> Bool {
  for index = start_idx; index < instrs.length(); index = index + 1 {
    let instr = instrs[index]
    match instr {
      @lib.Call(func_idx) => {
        let slot = dae_boundary_syntax_frozen_func_idx_slot(func_idx)
        if slot != callee_abs &&
          slot >= 0 &&
          slot < escaped.length() &&
          !escaped[slot] {
          match
            dae_boundary_syntax_frozen_resolve_func_type(
              mod_, type_indices, slot,
            ) {
            Some(@lib.FuncType(_, results)) if results.length() > 0 =>
              return true
            _ => ()
          }
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if dae_boundary_syntax_frozen_instrs_have_private_result_direct_call_other_than(
            body, callee_abs, mod_, type_indices, escaped,
          ) {
          return true
        }
      @lib.If(_, then_body, Some(else_body)) =>
        if dae_boundary_syntax_frozen_instrs_have_private_result_direct_call_other_than(
            then_body, callee_abs, mod_, type_indices, escaped,
          ) ||
          dae_boundary_syntax_frozen_instrs_have_private_result_direct_call_other_than(
            else_body, callee_abs, mod_, type_indices, escaped,
          ) {
          return true
        }
      @lib.If(_, then_body, None) =>
        if dae_boundary_syntax_frozen_instrs_have_private_result_direct_call_other_than(
            then_body, callee_abs, mod_, type_indices, escaped,
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn dae_boundary_syntax_frozen_dead_suffix_has_private_result_call_other_than(
  instrs : Array[@lib.Instruction],
  callee_abs : Int32,
  mod_ : @lib.Module,
  type_indices : Array[@lib.TypeIdx],
  escaped : Array[Bool],
) -> Bool {
  match dae_boundary_syntax_frozen_dead_suffix_evidence(instrs) {
    Some(evidence) =>
      dae_boundary_syntax_frozen_instrs_have_private_result_direct_call_other_than(
        evidence.body,
        callee_abs,
        mod_,
        type_indices,
        escaped,
        start_idx=evidence.suffix_start,
      )
    None => false
  }
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_self_recursive_result_side_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, false)
  }
  let undropped_result_self_suffix = Array::make(defined, false)
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let callee_abs = imported + def_idx
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    let has_result = match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, callee_abs,
      ) {
      Some(@lib.FuncType(_, results)) => results.length() > 0
      None => false
    }
    undropped_result_self_suffix[def_idx] = has_result &&
      dae_boundary_syntax_frozen_dead_suffix_has_undropped_direct_call_to(
        body, callee_abs,
      )
    def_idx += 1
  }
  let flags = Array::make(defined, false)
  def_idx = 0
  while def_idx < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    let targets : Array[Int32] = []
    dae_boundary_syntax_frozen_collect_dead_suffix_direct_targets(
      body, imported, defined, targets,
    )
    for target in targets {
      if target != def_idx &&
        target < def_idx &&
        undropped_result_self_suffix[target] {
        flags[def_idx] = true
      }
    }
    def_idx += 1
  }
  flags
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_self_recursive_void_side_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, false)
  }
  let original_self_calls = dae_boundary_syntax_frozen_collect_original_self_call_counts(
    mod_,
  )
  let self_recursive_void = Array::make(defined, false)
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let callee_abs = imported + def_idx
    let is_void = match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, callee_abs,
      ) {
      Some(@lib.FuncType(_, results)) => results.length() == 0
      None => false
    }
    self_recursive_void[def_idx] = is_void &&
      def_idx < original_self_calls.length() &&
      original_self_calls[def_idx] > 0
    def_idx += 1
  }
  let flags = Array::make(defined, false)
  def_idx = 0
  while def_idx < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    let targets : Array[Int32] = []
    dae_boundary_syntax_frozen_collect_dead_suffix_direct_targets(
      body, imported, defined, targets,
    )
    for target in targets {
      if target != def_idx && self_recursive_void[target] {
        flags[def_idx] = true
      }
    }
    def_idx += 1
  }
  flags
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_result_other_calls_with_escaped(
  mod_ : @lib.Module,
  escaped : Array[Bool],
) -> Array[Bool] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return []
  }
  let flags : Array[Bool] = []
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    flags.push(
      dae_boundary_syntax_frozen_dead_suffix_has_private_result_call_other_than(
        body,
        imported + def_idx,
        mod_,
        type_indices,
        escaped,
      ),
    )
    def_idx += 1
  }
  flags
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_mutual_calls(
  mod_ : @lib.Module,
) -> Array[Bool] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, false)
  }
  let flags = Array::make(defined, false)
  let counted_stamp = Array::make(defined, -1)
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let callee_abs = imported + def_idx
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    let targets : Array[Int32] = []
    dae_boundary_syntax_frozen_collect_dead_suffix_direct_targets(
      body, imported, defined, targets,
    )
    for target in targets {
      if target != def_idx && counted_stamp[target] != def_idx {
        counted_stamp[target] = def_idx
        if target >= 0 && target < funcs.length() {
          let @lib.Func(_, @lib.Expr(other_body)) = funcs[target]
          if dae_boundary_syntax_frozen_count_direct_call_anywhere_to(
              other_body, callee_abs,
            ) >
            0 {
            flags[def_idx] = true
          }
        }
      }
    }
    def_idx += 1
  }
  flags
}

///|
fn dae_boundary_syntax_frozen_original_int_fact_at(
  values : Array[Int32],
  idx : Int32,
) -> Int32 {
  if idx >= 0 && idx < values.length() {
    values[idx]
  } else {
    0
  }
}

///|
fn dae_boundary_syntax_frozen_original_bool_fact_at(
  values : Array[Bool],
  idx : Int32,
) -> Bool {
  if idx >= 0 && idx < values.length() {
    values[idx]
  } else {
    false
  }
}

///|
fn dae_boundary_syntax_frozen_original_no_param_dropped_caller_guard_evidence(
  def_idx : Int32,
  original_param_counts : Array[Int32],
  original_call_counts : Array[Int32],
  original_active_nonself_call_counts : Array[Int32],
  original_active_parameterized_nonself_call_counts : Array[Int32],
  original_nonself_undropped_call_counts : Array[Int32],
  original_self_call_counts : Array[Int32],
  original_escaped_dead_suffix_call_counts : Array[Int32],
  original_dead_suffix_undropped_self_calls : Array[Bool],
  original_dead_suffix_undropped_self_call_param_operands : Array[Bool],
  original_dead_suffix_result_other_calls : Array[Bool],
  original_dead_suffix_mutual_calls : Array[Bool],
) -> DaeOriginalNoParamDroppedCallerGuardEvidence {
  {
    param_count: dae_boundary_syntax_frozen_original_int_fact_at(
      original_param_counts, def_idx,
    ),
    call_count: dae_boundary_syntax_frozen_original_int_fact_at(
      original_call_counts, def_idx,
    ),
    active_nonself_call_count: dae_boundary_syntax_frozen_original_int_fact_at(
      original_active_nonself_call_counts, def_idx,
    ),
    active_parameterized_nonself_call_count: dae_boundary_syntax_frozen_original_int_fact_at(
      original_active_parameterized_nonself_call_counts, def_idx,
    ),
    nonself_undropped_call_count: dae_boundary_syntax_frozen_original_int_fact_at(
      original_nonself_undropped_call_counts, def_idx,
    ),
    self_call_count: dae_boundary_syntax_frozen_original_int_fact_at(
      original_self_call_counts, def_idx,
    ),
    escaped_dead_suffix_call_count: dae_boundary_syntax_frozen_original_int_fact_at(
      original_escaped_dead_suffix_call_counts, def_idx,
    ),
    dead_suffix_undropped_self_call: dae_boundary_syntax_frozen_original_bool_fact_at(
      original_dead_suffix_undropped_self_calls, def_idx,
    ),
    dead_suffix_undropped_self_call_param_operand: dae_boundary_syntax_frozen_original_bool_fact_at(
      original_dead_suffix_undropped_self_call_param_operands, def_idx,
    ),
    dead_suffix_result_other_call: dae_boundary_syntax_frozen_original_bool_fact_at(
      original_dead_suffix_result_other_calls, def_idx,
    ),
    dead_suffix_mutual_call: dae_boundary_syntax_frozen_original_bool_fact_at(
      original_dead_suffix_mutual_calls, def_idx,
    ),
  }
}

///|
fn dae_boundary_syntax_frozen_should_preserve_undropped_self_result_from_no_param_dropped_caller_evidence(
  evidence : DaeOriginalNoParamDroppedCallerGuardEvidence,
) -> Bool {
  evidence.param_count > 0 &&
  evidence.self_call_count > 0 &&
  evidence.call_count > evidence.self_call_count &&
  evidence.dead_suffix_undropped_self_call &&
  evidence.dead_suffix_undropped_self_call_param_operand &&
  evidence.dead_suffix_result_other_call &&
  evidence.active_nonself_call_count > 0 &&
  evidence.active_parameterized_nonself_call_count == 0 &&
  evidence.nonself_undropped_call_count == 0 &&
  evidence.escaped_dead_suffix_call_count == 0 &&
  !evidence.dead_suffix_mutual_call
}

///|
fn dae_boundary_syntax_frozen_should_preserve_undropped_self_result_from_no_param_dropped_caller(
  def_idx : Int32,
  original_param_counts : Array[Int32],
  original_call_counts : Array[Int32],
  original_active_nonself_call_counts : Array[Int32],
  original_active_parameterized_nonself_call_counts : Array[Int32],
  original_nonself_undropped_call_counts : Array[Int32],
  original_self_call_counts : Array[Int32],
  original_escaped_dead_suffix_call_counts : Array[Int32],
  original_dead_suffix_undropped_self_calls : Array[Bool],
  original_dead_suffix_undropped_self_call_param_operands : Array[Bool],
  original_dead_suffix_result_other_calls : Array[Bool],
  original_dead_suffix_mutual_calls : Array[Bool],
) -> Bool {
  dae_boundary_syntax_frozen_should_preserve_undropped_self_result_from_no_param_dropped_caller_evidence(
    dae_boundary_syntax_frozen_original_no_param_dropped_caller_guard_evidence(
      def_idx, original_param_counts, original_call_counts, original_active_nonself_call_counts,
      original_active_parameterized_nonself_call_counts, original_nonself_undropped_call_counts,
      original_self_call_counts, original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
      original_dead_suffix_undropped_self_call_param_operands, original_dead_suffix_result_other_calls,
      original_dead_suffix_mutual_calls,
    ),
  )
}

///|
fn dae_boundary_syntax_frozen_collect_original_dead_suffix_calls_from_param_operand_self_result_callers(
  mod_ : @lib.Module,
  original_param_counts : Array[Int32],
  original_call_counts : Array[Int32],
  original_active_nonself_call_counts : Array[Int32],
  original_active_parameterized_nonself_call_counts : Array[Int32],
  original_nonself_undropped_call_counts : Array[Int32],
  original_self_call_counts : Array[Int32],
  original_escaped_dead_suffix_call_counts : Array[Int32],
  original_dead_suffix_undropped_self_calls : Array[Bool],
  original_dead_suffix_undropped_self_call_param_operands : Array[Bool],
  original_dead_suffix_result_other_calls : Array[Bool],
  original_dead_suffix_mutual_calls : Array[Bool],
) -> Array[Int32] {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Array::make(defined, 0)
  }
  let counts = Array::make(defined, 0)
  let mut caller_def = 0
  while caller_def < funcs.length() {
    if dae_boundary_syntax_frozen_should_preserve_undropped_self_result_from_no_param_dropped_caller(
        caller_def, original_param_counts, original_call_counts, original_active_nonself_call_counts,
        original_active_parameterized_nonself_call_counts, original_nonself_undropped_call_counts,
        original_self_call_counts, original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
        original_dead_suffix_undropped_self_call_param_operands, original_dead_suffix_result_other_calls,
        original_dead_suffix_mutual_calls,
      ) {
      let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
      let mut callee_def = 0
      while callee_def < defined {
        if callee_def != caller_def {
          counts[callee_def] = counts[callee_def] +
            dae_boundary_syntax_frozen_count_dead_suffix_direct_call_to(
              body,
              imported + callee_def,
            )
        }
        callee_def += 1
      }
    }
    caller_def += 1
  }
  counts
}

///|
fn dae_boundary_syntax_frozen_try_process_core_work_item(
  original : DaeOriginalBoundarySnapshot,
  current : @lib.Module,
  graph : DaeCurrentBoundaryGraph,
  target_def : Int32,
  family : DaeWorkFamily,
  dependencies~ : DaeBoundaryDependencyGraph? = None,
  apply_followups~ : Bool = true,
  numeric_result_validation_chain~ : DaeScalarValidationChain? = None,
  numeric_result_validation_work~ : DaeScalarValidationWork? = None,
) -> DaeCoreResultApplication? {
  let active_dependencies = if family == DaeForwardingWork {
    match dependencies {
      Some(dependencies) => dependencies
      None => dae_boundary_dependency_graph_new(graph)
    }
  } else {
    dae_boundary_dependency_graph_empty()
  }
  let item = if family == DaeForwardingWork {
    dae_work_item_new(graph, active_dependencies, target_def, family)
  } else {
    dae_nonforwarding_work_item_new(graph, target_def, family)
  }
  let diagnostics = dae_diagnostics_new()
  match
    dae_boundary_syntax_frozen_process_work_item(
      original,
      current,
      [],
      false,
      graph,
      active_dependencies,
      item,
      diagnostics,
      numeric_result_validation_chain~,
      numeric_result_validation_work~,
    ) {
    DaeWorkCommitted(application) =>
      Some(
        if apply_followups {
          dae_boundary_syntax_frozen_apply_commit_followups(
            original, application, item, diagnostics,
          )
        } else {
          application
        },
      )
    _ => None
  }
}

///|
fn dae_boundary_syntax_frozen_run_core_once(
  mod_ : @lib.Module,
  already_rewritten_defs : Array[Bool],
  current_call_counts_anywhere : Array[Int32],
  optimize : Bool,
  skip_param_removal : Bool,
  original : DaeOriginalBoundarySnapshot,
  current_graph : DaeCurrentBoundaryGraph,
  expected_call_epoch~ : Int32 = -1,
  max_def_exclusive~ : Int32 = -1,
  start_def_inclusive~ : Int32 = 0,
  boundary_facts_override~ : DaeCallBoundaryFacts? = None,
  dependencies~ : DaeBoundaryDependencyGraph? = None,
  producer_effects_report~ : Array[DaeCommitEffects] = [],
  committed_application_report~ : Array[DaeCoreResultApplication] = [],
  checked_candidate_report~ : Array[(@lib.Module, @lib.Module)]? = None,
  scalar_validation_chain~ : DaeScalarValidationChain? = None,
  scalar_validation_work~ : DaeScalarValidationWork? = None,
  numeric_result_validation_work~ : DaeScalarValidationWork? = None,
  scalar_plan_code_snapshot_current~ : Bool = true,
  has_current_dropped_result_candidate~ : Bool = true,
  traps_never_happen~ : Bool = false,
) -> DaePassResult {
  let original_param_counts = original.param_counts
  let original_large_unreachable_prefixes = original.large_unreachable_prefixes
  let original_call_counts = original.call_summary.call_counts
  let original_prior_call_counts = original.call_summary.prior_call_counts
  let original_prior_undropped_call_counts = original.call_summary.prior_undropped_call_counts
  let original_active_nonself_call_counts = original.call_summary.active_nonself_call_counts
  let original_active_parameterized_nonself_call_counts = original.call_summary.active_parameterized_nonself_call_counts
  let original_active_parameterized_result_nonself_call_counts = original.call_summary.active_parameterized_result_nonself_call_counts
  let original_nonself_undropped_call_counts = original.call_summary.nonself_undropped_call_counts
  let original_self_call_counts = original.call_summary.self_call_counts
  let original_private_result_dead_suffix_call_counts = original.private_result_dead_suffix_call_counts
  let original_private_result_same_operand_call_counts = original.private_result_same_operand_call_counts
  let original_escaped_result_operand_call_facts = original.escaped_result_operand_call_facts
  let original_private_result_escaped_operand_call_counts = original_escaped_result_operand_call_facts.private_result_escaped_operand_call_counts
  let original_dead_suffix_escaped_result_operand_call_counts = original_escaped_result_operand_call_facts.dead_suffix_escaped_result_operand_call_counts
  let original_private_result_dead_suffix_calls_from_escaped_operand_callees = original.private_result_dead_suffix_calls_from_escaped_operand_callees
  let original_escaped_dead_suffix_call_counts = original.escaped_dead_suffix_call_counts
  let original_escaped_undropped_dead_suffix_call_counts = original.escaped_undropped_dead_suffix_call_counts
  let original_dead_suffix_other_calls = original.dead_suffix_other_calls
  let original_dead_suffix_undropped_self_calls = original.dead_suffix_undropped_self_calls
  let original_dead_suffix_dropped_self_calls = original.dead_suffix_dropped_self_calls
  let original_dead_suffix_block_undropped_self_calls = original.dead_suffix_block_undropped_self_calls
  let original_dead_suffix_dropped_self_call_full_param_forwards = original.dead_suffix_dropped_self_call_full_param_forwards
  let original_dead_suffix_result_calls_from_undropped_self_callers = original.dead_suffix_result_calls_from_undropped_self_callers
  let original_dead_suffix_result_calls_from_no_param_undropped_self_callers = original.dead_suffix_result_calls_from_no_param_undropped_self_callers
  let original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers = original.dead_suffix_undropped_calls_from_parameterized_dropped_self_callers
  let original_dead_suffix_dropped_calls_from_parameterized_self_callers = original.dead_suffix_dropped_calls_from_parameterized_self_callers
  let original_dead_suffix_dropped_calls_from_no_param_result_callers = original.dead_suffix_dropped_calls_from_no_param_result_callers
  let original_dead_suffix_mixed_dropped_undropped_call_counts = original.dead_suffix_mixed_dropped_undropped_call_counts
  let original_dead_suffix_dropped_earlier_result_calls = original.dead_suffix_dropped_earlier_result_calls
  let original_later_dead_suffix_dropped_call_counts = original.later_dead_suffix_dropped_call_counts
  let original_dead_suffix_same_self_result_operand_calls = original.dead_suffix_same_self_result_operand_calls
  let original_dead_suffix_undropped_self_call_param_operands = original.dead_suffix_undropped_self_call_param_operands
  let original_dead_suffix_calls_from_param_operand_self_result_callers = original.dead_suffix_calls_from_param_operand_self_result_callers
  let original_dead_suffix_result_other_calls = original.dead_suffix_result_other_calls
  let original_dead_suffix_self_recursive_void_side_calls = original.dead_suffix_self_recursive_void_side_calls
  let original_dead_suffix_self_recursive_result_side_calls = original.dead_suffix_self_recursive_result_side_calls
  let original_dead_suffix_escaped_result_call_facts = original.dead_suffix_escaped_result_call_facts
  let original_dead_suffix_undropped_escaped_result_calls = original_dead_suffix_escaped_result_call_facts.undropped_calls
  let original_dead_suffix_dropped_escaped_result_calls = original_dead_suffix_escaped_result_call_facts.dropped_calls
  let original_dead_suffix_mutual_calls = original.dead_suffix_mutual_calls
  let boundary_snapshot = current_graph.snapshot
  let imported = boundary_snapshot.imported
  let defined = boundary_snapshot.defined
  let boundary_facts = dae_boundary_facts_for_epoch(
    current_graph, expected_call_epoch, boundary_facts_override,
  )
  let active_dependencies = match dependencies {
    Some(dependencies) => dependencies
    None => dae_boundary_dependency_graph_new(current_graph)
  }
  let shared_boundary_facts : DaeBoundaryFacts = {
    original,
    graph: current_graph,
    incoming_param_live_by_def: [],
    incoming_param_live_body_epochs: [],
  }
  let function_infos = boundary_snapshot.function_infos
  let direct_calls = boundary_facts.direct_calls
  let direct_callers = boundary_facts.direct_callers
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
  let original_result_boundary_context = dae_original_result_boundary_context(
    original_result_preservation_context, original_private_result_escaped_operand_call_counts,
    original_dead_suffix_undropped_escaped_result_calls, original_dead_suffix_other_calls,
    original_dead_suffix_self_recursive_void_side_calls, original_dead_suffix_self_recursive_result_side_calls,
    original_active_parameterized_result_nonself_call_counts, original_dead_suffix_dropped_self_call_full_param_forwards,
    original_dead_suffix_dropped_earlier_result_calls, original_later_dead_suffix_dropped_call_counts,
    original_private_result_dead_suffix_call_counts, original_dead_suffix_dropped_calls_from_no_param_result_callers,
    original_dead_suffix_mixed_dropped_undropped_call_counts,
  )
  let scan_limit = if max_def_exclusive >= 0 && max_def_exclusive < defined {
    max_def_exclusive
  } else {
    defined
  }
  let mut def_idx = if start_def_inclusive > 0 {
    start_def_inclusive
  } else {
    0
  }
  while def_idx < scan_limit {
    let callee_abs = imported + def_idx
    let candidate_epoch = dae_boundary_candidate_epoch(current_graph, def_idx)
    if !dae_candidate_epoch_is_current(current_graph, candidate_epoch) {
      def_idx += 1
      continue
    }
    if def_idx < already_rewritten_defs.length() &&
      already_rewritten_defs[def_idx] {
      def_idx += 1
      continue
    }
    let boundary_candidate = match
      dae_call_boundary_candidate(boundary_facts, callee_abs) {
      Some(candidate) => candidate
      None => {
        def_idx += 1
        continue
      }
    }
    if !boundary_candidate.owned ||
      !dae_can_change_function_boundary(shared_boundary_facts, callee_abs) {
      def_idx += 1
      continue
    }
    let (self_calls, self_calls_anywhere) = if callee_abs >= 0 &&
      callee_abs < function_infos.length() {
      dae_self_call_counts_from_function_info(
        function_infos[callee_abs],
        def_idx,
      )
    } else {
      (
        dae_count_self_calls(funcs[def_idx], callee_abs),
        dae_boundary_syntax_frozen_count_self_calls_anywhere(
          funcs[def_idx],
          callee_abs,
        ),
      )
    }
    let skip_original_large_result_cleanup = dae_should_skip_original_large_result_unreachable_cleanup(
      original_large_unreachable_prefixes, def_idx, mod_, type_indices, callee_abs,
    )
    let original_result_boundary_row = dae_original_result_boundary_row_from_context(
      def_idx, original_result_boundary_context,
    )
    let original_result_boundary_for_def = dae_original_result_boundary_evidence_from_row(
      original_result_boundary_row,
    )
    let original_result_preservation_row = original_result_boundary_row.preservation
    let original_result_removal_prune_row = original_result_boundary_row.prune
    let original_result_preservation_for_def = original_result_boundary_for_def.preservation
    let original_result_cleanup_preservation_for_def = original_result_boundary_for_def.cleanup_preservation
    let original_result_removal_prune_for_def = original_result_boundary_for_def.prune
    let original_result_escape_row = original_result_boundary_row.escape
    let original_escaped_block_self_result_for_unobserved = original_result_preservation_for_def.escaped_block_self_result
    let original_same_self_result_operand_for_unobserved = dae_should_preserve_same_self_result_operand_from_row(
      original_result_removal_prune_row,
    )
    let (current_param_count, current_result_count) = match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, callee_abs,
      ) {
      Some(@lib.FuncType(current_params, current_results)) =>
        (current_params.length(), current_results.length())
      None => (0, 0)
    }
    let @lib.Func(_, @lib.Expr(current_body)) = funcs[def_idx]
    let current_calls_anywhere = dae_boundary_syntax_frozen_original_int_fact_at(
      current_call_counts_anywhere, def_idx,
    )
    let unobserved_shape_candidate = if dae_should_scan_unobserved_shape(
        current_param_count, current_result_count, current_calls_anywhere,
      ) {
      dae_func_is_unreachable_only(
        dae_simplify_to_unreachable_when_prefix_unobservable(funcs[def_idx]),
      ) &&
      (
        current_result_count == 0 ||
        dae_boundary_syntax_frozen_dead_suffix_has_undropped_direct_call_to(
          current_body, callee_abs,
        )
      )
    } else {
      false
    }
    if unobserved_shape_candidate &&
      boundary_candidate.direct_call_count == self_calls &&
      !skip_original_large_result_cleanup &&
      !dae_original_result_cleanup_preservation_any(
        original_result_cleanup_preservation_for_def,
      ) &&
      !original_escaped_block_self_result_for_unobserved &&
      !original_same_self_result_operand_for_unobserved &&
      (
        original_result_escape_row.dead_suffix_result_calls_from_undropped_self_caller ==
        0 ||
        original_result_escape_row.dead_suffix_result_calls_from_no_param_undropped_self_caller >
        0
      ) &&
      original_result_escape_row.dead_suffix_calls_from_param_operand_self_result_caller ==
      0 &&
      original_result_escape_row.dead_suffix_escaped_result_operand_call_count ==
      0 &&
      original_result_escape_row.private_result_dead_suffix_calls_from_escaped_operand_callees ==
      0 &&
      original_result_escape_row.private_result_escaped_operand_call_count == 0 &&
      !(original_result_escape_row.dead_suffix_undropped_escaped_result_call &&
      original_result_escape_row.escaped_dead_suffix_call_count == 0) {
      match
        dae_boundary_syntax_frozen_specialized_result_facts_new(
          original, current_graph, callee_abs,
        ) {
        Some(specialized_facts) => {
          dae_scalar_validation_barrier_opt(scalar_validation_chain)
          let unobserved = dae_try_remove_unobserved_unreachable_function_with_facts(
            mod_, specialized_facts,
          )
          if unobserved.changed {
            dae_record_producer_effects(
              producer_effects_report,
              dae_specialized_result_commit_effects(
                specialized_facts, unobserved,
              ),
            )
            return unobserved
          }
        }
        None => ()
      }
    }
    if boundary_candidate.direct_call_count == 0 {
      let original_result_side_call_row = original_result_boundary_row.side_call
      let original_self_calls = original_result_preservation_row.self_call_count
      let originally_had_params = original_result_preservation_row.param_count >
        0
      let original_call_count = original_result_preservation_row.call_count
      let original_prior_calls = if def_idx <
        original_prior_call_counts.length() {
        original_prior_call_counts[def_idx]
      } else {
        0
      }
      let original_prior_undropped_calls = if def_idx <
        original_prior_undropped_call_counts.length() {
        original_prior_undropped_call_counts[def_idx]
      } else {
        0
      }
      let original_active_nonself_calls = original_result_preservation_row.active_nonself_call_count
      let original_active_parameterized_nonself_calls = original_result_preservation_row.active_parameterized_nonself_call_count
      let original_active_parameterized_result_nonself_calls = original_result_removal_prune_row.active_parameterized_result_nonself_call_count
      let original_nonself_undropped_calls = original_result_preservation_row.nonself_undropped_call_count
      let original_private_result_dead_suffix_calls = original_result_removal_prune_row.private_result_dead_suffix_call_count
      let original_private_result_same_operand_calls = if def_idx <
        original_private_result_same_operand_call_counts.length() {
        original_private_result_same_operand_call_counts[def_idx]
      } else {
        0
      }
      let original_escaped_undropped_dead_suffix_calls = if def_idx <
        original_escaped_undropped_dead_suffix_call_counts.length() {
        original_escaped_undropped_dead_suffix_call_counts[def_idx]
      } else {
        0
      }
      let original_dead_suffix_other_call = original_result_side_call_row.dead_suffix_other_call
      let original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers = if def_idx <
        original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers.length() {
        original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers[def_idx]
      } else {
        0
      }
      let original_dead_suffix_result_other_call = original_result_side_call_row.dead_suffix_result_other_call
      let original_dropped_only_result_side_caller_prune = original_result_removal_prune_for_def.dropped_only_no_param_result_side_caller
      let original_escaped_block_self_result = dae_should_preserve_escaped_block_self_result_from_row(
        original_result_removal_prune_row, true,
      )
      let original_dead_suffix_side_call_evidence = dae_original_dead_suffix_side_call_evidence(
        original_result_removal_prune_row, original_result_side_call_row,
      )
      let original_dead_suffix_undropped_self_call = original_dead_suffix_side_call_evidence.dead_suffix_undropped_self_call
      let original_dead_suffix_mutual_call = original_dead_suffix_side_call_evidence.dead_suffix_mutual_call
      let original_parameterized_undropped_self_side_chain = dae_should_preserve_parameterized_undropped_self_side_chain_evidence(
        dae_original_parameterized_undropped_self_side_chain_evidence_from_row(
          original_result_preservation_row,
        ),
      )
      let allow_unreachable_only_param_cleanup = (
          original_result_escape_row.dead_suffix_undropped_escaped_result_call &&
          original_result_escape_row.escaped_dead_suffix_call_count == 0
        ) ||
        original_dead_suffix_side_call_evidence.void_side_cleanup_preservation ||
        original_dead_suffix_side_call_evidence.result_side_chain_preservation ||
        original_dead_suffix_side_call_evidence.same_self_result_operand_preservation ||
        original_result_cleanup_preservation_for_def.result_side_chain_cleanup_preservation ||
        original_escaped_block_self_result ||
        original_dropped_only_result_side_caller_prune
      dae_scalar_validation_barrier_opt(scalar_validation_chain)
      let dead_suffix_params = dae_try_remove_dead_suffix_only_unreachable_params(
        mod_,
        callee_abs,
        original_call_count,
        allow_unreachable_only_param_cleanup,
        current_calls_anywhere=dae_boundary_syntax_frozen_original_int_fact_at(
          current_call_counts_anywhere, def_idx,
        ),
      )
      if dead_suffix_params.changed {
        dae_record_dead_suffix_parameter_candidate_effects(
          mod_, current_graph, def_idx, dead_suffix_params, producer_effects_report,
        )
        return dead_suffix_params
      }
      let @lib.Func(_, @lib.Expr(current_body)) = funcs[def_idx]
      let has_undropped_self_suffix = self_calls_anywhere > 0 &&
        dae_boundary_syntax_frozen_dead_suffix_has_undropped_direct_call_to(
          current_body, callee_abs,
        )
      let no_self_nonmutual_side_call = original_prior_calls == 0 &&
        original_self_calls == 0 &&
        original_dead_suffix_other_call &&
        !original_dead_suffix_mutual_call
      let prune_private_result_side_chain = originally_had_params &&
        original_self_calls == 0 &&
        original_private_result_dead_suffix_calls > 0 &&
        original_dead_suffix_other_call &&
        original_private_result_same_operand_calls > 0 &&
        original_active_nonself_calls > original_nonself_undropped_calls &&
        original_nonself_undropped_calls > 0
      let skip_uncalled_after_param_cleanup = !prune_private_result_side_chain &&
        !dae_should_block_uncalled_after_param_cleanup_from_prune_evidence(
          original_result_removal_prune_for_def,
        ) &&
        dae_func_is_unreachable_only(
          dae_simplify_to_unreachable_when_prefix_unobservable(funcs[def_idx]),
        ) &&
        (
          has_undropped_self_suffix ||
          dae_original_result_cleanup_preservation_any(
            original_result_cleanup_preservation_for_def,
          ) ||
          original_dead_suffix_side_call_evidence.same_self_result_operand_preservation ||
          original_escaped_block_self_result ||
          original_dead_suffix_side_call_evidence.result_side_chain_preservation ||
          (
            originally_had_params &&
            original_self_calls == 0 &&
            original_private_result_dead_suffix_calls > 0 &&
            original_result_escape_row.dead_suffix_result_calls_from_no_param_undropped_self_caller ==
            0 &&
            original_result_escape_row.escaped_dead_suffix_call_count == 0
          ) ||
          (
            originally_had_params &&
            original_self_calls == 0 &&
            original_result_escape_row.dead_suffix_escaped_result_operand_call_count >
            0
          ) ||
          (
            !originally_had_params &&
            original_result_escape_row.private_result_dead_suffix_calls_from_escaped_operand_callees >
            0
          ) ||
          (
            originally_had_params &&
            original_self_calls == 0 &&
            original_result_escape_row.dead_suffix_result_calls_from_undropped_self_caller >
            0 &&
            original_result_escape_row.dead_suffix_result_calls_from_no_param_undropped_self_caller ==
            0 &&
            original_result_escape_row.escaped_dead_suffix_call_count == 0 &&
            original_active_nonself_calls > 0
          ) ||
          original_result_escape_row.dead_suffix_calls_from_param_operand_self_result_caller >
          0 ||
          (
            originally_had_params &&
            original_self_calls == 0 &&
            original_result_escape_row.private_result_escaped_operand_call_count >
            0
          ) ||
          (
            originally_had_params &&
            original_self_calls == 0 &&
            original_result_escape_row.dead_suffix_undropped_escaped_result_call &&
            original_result_escape_row.escaped_dead_suffix_call_count == 0 &&
            original_call_count > 0 &&
            original_nonself_undropped_calls == 0
          ) ||
          (
            originally_had_params &&
            original_self_calls > 0 &&
            original_result_preservation_row.dead_suffix_dropped_self_call &&
            !original_dead_suffix_undropped_self_call &&
            original_call_count > original_self_calls &&
            original_active_nonself_calls > 0 &&
            original_active_parameterized_result_nonself_calls > 0 &&
            original_result_escape_row.escaped_dead_suffix_call_count == 0 &&
            !original_dead_suffix_mutual_call
          ) ||
          (
            originally_had_params &&
            original_self_calls == 0 &&
            original_dead_suffix_result_other_call &&
            original_result_escape_row.escaped_dead_suffix_call_count == 0 &&
            !original_dead_suffix_mutual_call &&
            (
              original_active_nonself_calls > 0 ||
              original_nonself_undropped_calls > 0
            )
          ) ||
          original_dead_suffix_side_call_evidence.void_side_cleanup_preservation ||
          (
            originally_had_params &&
            original_result_escape_row.dead_suffix_result_calls_from_no_param_undropped_self_caller ==
            0 &&
            (
              original_call_count == original_self_calls ||
              original_active_nonself_calls > 0 ||
              original_nonself_undropped_calls > 0
            ) &&
            (original_prior_calls == 0 || original_prior_undropped_calls > 0) &&
            !no_self_nonmutual_side_call &&
            !(original_self_calls > 0 &&
            original_call_count > original_self_calls &&
            original_active_parameterized_nonself_calls == 0 &&
            original_nonself_undropped_calls == 0)
          ) ||
          (
            !originally_had_params &&
            original_prior_undropped_calls > 0 &&
            (
              original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers ==
              0 ||
              original_escaped_undropped_dead_suffix_calls > 0
            )
          ) ||
          (
            !originally_had_params &&
            original_nonself_undropped_calls > 0 &&
            original_result_escape_row.escaped_dead_suffix_call_count == 0 &&
            original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers ==
            0
          ) ||
          (
            !originally_had_params &&
            original_dead_suffix_undropped_self_call &&
            original_call_count >= original_self_calls
          )
        )
      let skip_self_suffix_result = original_self_calls > 0 &&
        skip_uncalled_after_param_cleanup
      let dead_self_suffix_shape_candidate = current_param_count == 0 &&
        current_result_count == 1 &&
        !dae_func_is_unreachable_only(funcs[def_idx]) &&
        dae_boundary_syntax_frozen_dead_suffix_has_dropped_direct_call_to(
          current_body, callee_abs,
        )
      if dead_self_suffix_shape_candidate &&
        self_calls_anywhere > 0 &&
        !skip_self_suffix_result &&
        !skip_original_large_result_cleanup &&
        original_call_count == original_self_calls {
        match
          dae_boundary_syntax_frozen_specialized_result_facts_new(
            original, current_graph, callee_abs,
          ) {
          Some(specialized_facts) => {
            dae_scalar_validation_barrier_opt(scalar_validation_chain)
            let self_suffix = dae_try_remove_dead_self_suffix_result_with_facts(
              mod_, specialized_facts,
            )
            if self_suffix.changed {
              dae_record_producer_effects(
                producer_effects_report,
                dae_specialized_result_commit_effects(
                  specialized_facts, self_suffix,
                ),
              )
              return self_suffix
            }
          }
          None => ()
        }
      }
      let uncalled_result_shape_candidate = match
        dae_boundary_syntax_frozen_resolve_func_type(
          mod_, type_indices, callee_abs,
        ) {
        Some(@lib.FuncType(current_params, current_results)) =>
          current_params.length() == 0 &&
          current_results.length() > 0 &&
          dae_func_is_unreachable_only(
            dae_simplify_to_unreachable_when_prefix_unobservable(funcs[def_idx]),
          )
        None => false
      }
      if uncalled_result_shape_candidate &&
        !skip_uncalled_after_param_cleanup &&
        !skip_original_large_result_cleanup &&
        original_call_count > 0 &&
        (
          self_calls_anywhere == 0 ||
          dae_boundary_syntax_frozen_original_int_fact_at(
            current_call_counts_anywhere, def_idx,
          ) !=
          self_calls_anywhere
        ) {
        match
          dae_boundary_syntax_frozen_specialized_result_facts_new(
            original, current_graph, callee_abs,
          ) {
          Some(specialized_facts) => {
            dae_scalar_validation_barrier_opt(scalar_validation_chain)
            let result = dae_try_remove_uncalled_results_with_facts(
              mod_, specialized_facts,
            )
            if result.changed {
              dae_record_producer_effects(
                producer_effects_report,
                dae_specialized_result_commit_effects(specialized_facts, result),
              )
              return result
            }
          }
          None => ()
        }
      }
      if self_calls_anywhere == 0 {
        let func_type = match
          dae_boundary_syntax_frozen_resolve_func_type(
            mod_, type_indices, callee_abs,
          ) {
          Some(ft) => ft
          None => {
            def_idx += 1
            continue
          }
        }
        let @lib.FuncType(params, _) = func_type
        if params.length() > 0 &&
          original_parameterized_undropped_self_side_chain &&
          dae_func_is_unreachable_only(funcs[def_idx]) {
          let @lib.Func(locals, _) = funcs[def_idx]
          let local_use = dae_local_use_for_callee(
            funcs[def_idx],
            params.length() + locals.length(),
            callee_abs,
            params.length(),
          )
          let remove = Array::make(params.length(), false)
          let const_params : Array[@lib.Instruction?] = Array::make(
            params.length(),
            None,
          )
          let collect_const_params = Array::make(params.length(), false)
          let mut has_collect_const_param = false
          let mut collect_p = 0
          while collect_p < params.length() {
            if local_use.gets[collect_p] && !local_use.writes[collect_p] {
              collect_const_params[collect_p] = true
              has_collect_const_param = true
            }
            collect_p += 1
          }
          let has_direct_caller_cycle = dae_boundary_has_direct_caller_cycle(
            boundary_facts, imported, callee_abs,
          )
          let uniform_const_params = if dae_should_collect_phase_local_uniform_constants(
              defined,
              optimize~,
              allow_written_uniform_const=false,
              self_calls_anywhere~,
              has_collect_const_param~,
              has_direct_caller_cycle~,
            ) {
            dae_collect_uniform_const_actuals_from_current_call_facts(
              mod_,
              callee_abs,
              params.length(),
              type_indices,
              boundary_facts,
              function_infos,
              collect_params=Some(collect_const_params),
            )
          } else {
            None
          }
          let mut any = false
          let mut p = 0
          while p < params.length() {
            if !local_use.gets[p] {
              remove[p] = true
              any = true
            } else if !local_use.writes[p] {
              match uniform_const_params {
                Some(values) =>
                  match values[p] {
                    Some(value) if dae_batchable_uniform_literal(value) => {
                      remove[p] = true
                      const_params[p] = Some(value)
                      any = true
                    }
                    _ => ()
                  }
                None => ()
              }
            }
            p += 1
          }
          if any && !skip_param_removal {
            dae_scalar_validation_barrier_opt(scalar_validation_chain)
            let result = dae_boundary_syntax_frozen_try_rewrite_candidate(
              mod_,
              callee_abs,
              remove,
              const_params,
              local_use,
              boundary_candidate.direct_call_count,
              boundary_candidate.direct_callers,
            )
            if result.changed {
              dae_record_work_family_candidate_effects(
                mod_,
                current_graph,
                def_idx,
                if const_params.any(fn(value) { value is Some(_) }) {
                  DaeUniformActualWork
                } else {
                  DaeUnusedParameterWork
                },
                result,
                producer_effects_report,
              )
              return result
            }
          }
        }
        // Binaryen admits the zero-call family in both variants only for a
        // private root-terminal unreachable target. Ordinary returning bodies
        // stay outside this specialized boundary scan.
        if original_result_preservation_row.dead_suffix_dropped_self_call ||
          current_body.length() == 0 ||
          current_body[current_body.length() - 1] !=
          @lib.Instruction::unreachable_() {
          def_idx += 1
          continue
        }
      }
    }
    let func_type = match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, callee_abs,
      ) {
      Some(ft) => ft
      None => {
        def_idx += 1
        continue
      }
    }
    let @lib.FuncType(params, results) = func_type
    if self_calls_anywhere == 0 &&
      boundary_candidate.direct_call_count > 0 &&
      dae_signature_has_heap_ref(params, results) {
      dae_scalar_validation_barrier_opt(scalar_validation_chain)
      match
        dae_boundary_syntax_frozen_try_process_core_work_item(
          original,
          mod_,
          current_graph,
          def_idx,
          DaeGcParameterRefinementWork,
          dependencies=Some(active_dependencies),
          apply_followups=false,
        ) {
        Some(application) =>
          return dae_core_pass_result_from_work_application(
            application,
            producer_effects_report,
            committed_application_report~,
          )
        None => ()
      }
    }
    if self_calls_anywhere > 0 &&
      boundary_candidate.direct_call_count > 0 &&
      dae_signature_has_heap_ref([], results) {
      dae_scalar_validation_barrier_opt(scalar_validation_chain)
      match
        dae_boundary_syntax_frozen_try_process_core_work_item(
          original,
          mod_,
          current_graph,
          def_idx,
          DaeGcResultRefinementWork,
          dependencies=Some(active_dependencies),
          apply_followups=false,
        ) {
        Some(application) =>
          return dae_core_pass_result_from_work_application(
            application,
            producer_effects_report,
            committed_application_report~,
          )
        None => ()
      }
    }
    if params.length() > 0 &&
      dae_should_skip_stale_scalar_result_tail(
        scalar_plan_code_snapshot_current, has_current_dropped_result_candidate,
      ) {
      def_idx += 1
      continue
    }
    if params.length() == 0 {
      // The dropped-result producer rejects a zero-result signature before
      // any IR write. Keep the checked source across this empty boundary.
      if results.is_empty() {
        def_idx += 1
        continue
      }
      let preserve_original_result = original_result_preservation_for_def
      if original_result_removal_prune_for_def.dropped_self_result_with_void_side_callers &&
        !skip_original_large_result_cleanup {
        dae_numeric_result_validation_before_producer(
          scalar_validation_chain, current_graph, def_idx,
        )
        match
          dae_boundary_syntax_frozen_try_process_core_work_item(
            original,
            mod_,
            current_graph,
            def_idx,
            DaeDroppedResultWork,
            dependencies=Some(active_dependencies),
            apply_followups=false,
            numeric_result_validation_chain=scalar_validation_chain,
            numeric_result_validation_work~,
          ) {
          Some(application) =>
            return dae_core_pass_result_from_work_application(
              application,
              producer_effects_report,
              committed_application_report~,
            )
          None => ()
        }
      }
      if !skip_original_large_result_cleanup &&
        dae_should_prune_params_absent_result_cleanup(
          original_result_removal_prune_for_def,
        ) {
        dae_numeric_result_validation_before_producer(
          scalar_validation_chain, current_graph, def_idx,
        )
        match
          dae_boundary_syntax_frozen_try_process_core_work_item(
            original,
            mod_,
            current_graph,
            def_idx,
            DaeDroppedResultWork,
            dependencies=Some(active_dependencies),
            apply_followups=false,
            numeric_result_validation_chain=scalar_validation_chain,
            numeric_result_validation_work~,
          ) {
          Some(application) =>
            return dae_core_pass_result_from_work_application(
              application,
              producer_effects_report,
              committed_application_report~,
            )
          None => ()
        }
      }
      if !skip_original_large_result_cleanup &&
        !dae_original_result_preservation_any(preserve_original_result) {
        dae_numeric_result_validation_before_producer(
          scalar_validation_chain, current_graph, def_idx,
        )
        match
          dae_boundary_syntax_frozen_try_process_core_work_item(
            original,
            mod_,
            current_graph,
            def_idx,
            DaeDroppedResultWork,
            dependencies=Some(active_dependencies),
            apply_followups=false,
            numeric_result_validation_chain=scalar_validation_chain,
            numeric_result_validation_work~,
          ) {
          Some(application) =>
            return dae_core_pass_result_from_work_application(
              application,
              producer_effects_report,
              committed_application_report~,
            )
          None => ()
        }
      }
      def_idx += 1
      continue
    }
    let @lib.Func(locals, @lib.Expr(candidate_body)) = funcs[def_idx]
    let local_use = dae_local_use_for_callee(
      funcs[def_idx],
      params.length() + locals.length(),
      callee_abs,
      params.length(),
    )
    let mut rewrite_mod = mod_
    let mut has_rewrite_mod = false
    // Shared incoming-parameter live-in analysis ([O4Z-DAE-BOUNDARY]001).
    // Syntactic local.get scanning remains only for write/repair facts.
    let entry_live = dae_incoming_parameter_liveness(
      mod_,
      callee_abs,
      params.length(),
    )
    if params.length() > 0 {
      let mut found_entry_dead_param = false
      let mut param_idx = 0
      while param_idx < params.length() {
        if !entry_live[param_idx] {
          local_use.gets[param_idx] = false
          if !optimize || local_use.writes[param_idx] {
            found_entry_dead_param = true
          }
        } else {
          local_use.gets[param_idx] = true
        }
        param_idx += 1
      }
      if found_entry_dead_param {
        dae_scalar_validation_barrier_opt(scalar_validation_chain)
        rewrite_mod = dae_strip_function_terminal_suffix_for_def(mod_, def_idx)
        has_rewrite_mod = true
      }
    }
    let unused_params = dae_function_info_refresh_unused_params(
      function_infos,
      callee_abs,
      local_use,
      params.length(),
    )
    let remove = Array::make(params.length(), false)
    let const_params : Array[@lib.Instruction?] = Array::make(
      params.length(),
      None,
    )
    let has_direct_caller_cycle = dae_boundary_has_direct_caller_cycle(
      boundary_facts, imported, callee_abs,
    )
    let run_scalar_parameter_candidate = dae_should_run_scalar_parameter_candidate(
      defined,
      has_direct_caller_cycle~,
    )
    let allow_written_uniform_const = params.length() > 0 &&
      (
        dae_instrs_support_param_entry_liveness(candidate_body) ||
        (optimize && pass_raw_instrs_have_legacy_try(candidate_body))
      )
    let collect_const_params = Array::make(params.length(), false)
    let mut has_collect_const_param = false
    let mut collect_p = 0
    while collect_p < params.length() {
      if local_use.gets[collect_p] &&
        (!local_use.writes[collect_p] || allow_written_uniform_const) {
        collect_const_params[collect_p] = true
        has_collect_const_param = true
      }
      collect_p += 1
    }
    let uniform_const_params = if dae_should_collect_phase_local_uniform_constants(
        defined,
        optimize~,
        allow_written_uniform_const~,
        self_calls_anywhere~,
        has_collect_const_param~,
        has_direct_caller_cycle=!run_scalar_parameter_candidate,
      ) {
      dae_collect_uniform_const_actuals_from_current_call_facts(
        mod_,
        callee_abs,
        params.length(),
        type_indices,
        boundary_facts,
        function_infos,
        allow_immutable_global_get=allow_written_uniform_const,
        collect_params=Some(collect_const_params),
      )
    } else {
      None
    }
    let mut any = false
    let mut p = 0
    while p < params.length() {
      if run_scalar_parameter_candidate && unused_params[p] {
        remove[p] = true
        any = true
      } else if run_scalar_parameter_candidate &&
        (!local_use.writes[p] || allow_written_uniform_const) {
        match uniform_const_params {
          Some(values) =>
            match values[p] {
              Some(value) if dae_batchable_uniform_literal(value) ||
                (
                  allow_written_uniform_const &&
                  dae_instr_is_materializable_const_with_immutable_global(
                    mod_, value,
                  )
                ) => {
                remove[p] = true
                const_params[p] = Some(value)
                any = true
              }
              _ => ()
            }
          None => ()
        }
      }
      p += 1
    }
    let preserve_current_result = original_result_preservation_for_def
    if any && !skip_param_removal {
      if !scalar_plan_code_snapshot_current {
        def_idx += 1
        continue
      }
      let scalar_unused_only = const_params.all(fn(value) { value is None })
      if scalar_unused_only {
        let callee_source = if !has_rewrite_mod {
          None
        } else {
          match rewrite_mod.code_sec {
            Some(@lib.CodeSec(rewrite_funcs)) if def_idx >= 0 &&
              def_idx < rewrite_funcs.length() => Some(rewrite_funcs[def_idx])
            _ => None
          }
        }
        dae_scalar_validation_barrier_opt(scalar_validation_chain)
        let planned = dae_try_rewrite_scalar_unused_param_candidate(
          mod_,
          original,
          current_graph,
          callee_abs,
          remove,
          local_use,
          direct_calls[callee_abs],
          direct_callers[callee_abs],
          callee_source~,
          entry_live=Some(entry_live),
          traps_never_happen~,
        )
        if planned.applied {
          dae_record_producer_effects(producer_effects_report, planned.effects)
          return planned.result
        }
        if planned.reason != DaeActualValueSliceUnavailable {
          def_idx += 1
          continue
        }
      }
      if !dae_scalar_numeric_materialization(const_params) {
        dae_scalar_validation_barrier_opt(scalar_validation_chain)
      }
      let result = dae_boundary_syntax_frozen_try_rewrite_candidate(
        rewrite_mod,
        callee_abs,
        remove,
        const_params,
        local_use,
        direct_calls[callee_abs],
        direct_callers[callee_abs],
        original=Some(original),
        graph=Some(current_graph),
        entry_live=Some(entry_live),
        checked_candidate_report~,
        scalar_validation_chain~,
        scalar_validation_work~,
      )
      if result.changed {
        dae_record_work_family_candidate_effects(
          mod_,
          current_graph,
          def_idx,
          if const_params.any(fn(value) { value is Some(_) }) {
            DaeUniformActualWork
          } else {
            DaeUnusedParameterWork
          },
          result,
          producer_effects_report,
        )
        return result
      }
    } else if !skip_original_large_result_cleanup &&
      !dae_original_result_preservation_blocks_argument_side_result_repair(
        preserve_current_result, true,
      ) {
      // Use the exact graph facts passed to the dropped-result producer, not
      // the optional boundary-facts override. Its first gate rejects zero
      // direct calls and any undropped call before a candidate can be written.
      let producer_call_facts = current_graph.snapshot.call_facts
      let producer_direct_calls = dae_call_boundary_count_at(
        producer_call_facts.direct_calls,
        callee_abs,
      )
      if producer_direct_calls == 0 ||
        dae_call_boundary_count_at(
          producer_call_facts.dropped_calls,
          callee_abs,
        ) !=
        producer_direct_calls {
        def_idx += 1
        continue
      }
      dae_numeric_result_validation_before_producer(
        scalar_validation_chain, current_graph, def_idx,
      )
      match
        dae_boundary_syntax_frozen_try_process_core_work_item(
          original,
          mod_,
          current_graph,
          def_idx,
          DaeDroppedResultWork,
          dependencies=Some(active_dependencies),
          apply_followups=false,
          numeric_result_validation_chain=scalar_validation_chain,
          numeric_result_validation_work~,
        ) {
        Some(application) =>
          return dae_core_pass_result_from_work_application(
            application,
            producer_effects_report,
            committed_application_report~,
          )
        None => ()
      }
    }
    def_idx += 1
  }
  { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
}

///|
fn dae_boundary_syntax_frozen_try_rewrite_reverse_exact_literal_once(
  mod_ : @lib.Module,
  original_param_counts : Array[Int32],
  original_call_counts : Array[Int32],
  original_active_nonself_call_counts : Array[Int32],
  original_active_parameterized_nonself_call_counts : Array[Int32],
  original_nonself_undropped_call_counts : Array[Int32],
  original_self_call_counts : Array[Int32],
  original_private_result_dead_suffix_calls_from_escaped_operand_callees : Array[
    Int32,
  ],
  original_escaped_dead_suffix_call_counts : Array[Int32],
  original_dead_suffix_undropped_self_calls : Array[Bool],
  original_dead_suffix_dropped_self_calls : Array[Bool],
  original_dead_suffix_block_undropped_self_calls : Array[Bool],
  original_dead_suffix_result_calls_from_undropped_self_callers : Array[Int32],
  original_dead_suffix_result_calls_from_no_param_undropped_self_callers : Array[
    Int32,
  ],
  original_dead_suffix_same_self_result_operand_calls : Array[Bool],
  original_dead_suffix_undropped_self_call_param_operands : Array[Bool],
  original_dead_suffix_result_other_calls : Array[Bool],
  original_dead_suffix_escaped_result_call_facts : DaeOriginalDeadSuffixEscapedResultCallFacts,
  original_dead_suffix_mutual_calls : Array[Bool],
  original_dead_suffix_calls_from_param_operand_self_result_callers : Array[
    Int32,
  ],
  original_dead_suffix_escaped_result_operand_call_counts : Array[Int32],
  original_dead_suffix_dropped_calls_from_parameterized_self_callers : Array[
    Int32,
  ],
  supplied_graph~ : DaeCurrentBoundaryGraph? = None,
  graph_builds~ : Array[Int32]? = None,
  original_snapshot_builds~ : Array[Int32]? = None,
  type_resolutions~ : Array[Int32]? = None,
  reuse_function_types~ : Bool = true,
  reverse~ : Bool = true,
  max_def_exclusive~ : Int32 = -1,
) -> DaePassResult {
  let original_dead_suffix_undropped_escaped_result_calls = original_dead_suffix_escaped_result_call_facts.undropped_calls
  let original_dead_suffix_dropped_escaped_result_calls = original_dead_suffix_escaped_result_call_facts.dropped_calls
  // Replay facts remain fixed for this candidate scan. Build them
  // only when the first candidate reaches the rewrite planner.
  let mut rewrite_original : DaeOriginalBoundarySnapshot? = None
  let rewrite_graph = match supplied_graph {
    // The scan and its surrounding commit planning share exactly this owner.
    // A graph from another module, including a changed body/type owner, rebuilds.
    Some(graph) if physical_equal(graph.mod_, mod_) => graph
    _ => {
      match graph_builds {
        Some(count) => count[0] += 1
        None => ()
      }
      dae_current_boundary_graph_new(mod_)
    }
  }
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
    let self_calls_anywhere = dae_boundary_syntax_frozen_count_self_calls_anywhere(
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
    // The candidate graph already owns a signature snapshot for this exact
    // module. Read it directly instead of walking the type section per callee.
    let resolved_type = if reuse_function_types {
      boundary_snapshot.function_types[callee_abs]
    } else {
      match type_resolutions {
        Some(count) => count[0] += 1
        None => ()
      }
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, callee_abs,
      )
    }
    let func_type = match resolved_type {
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
      let active_original = match rewrite_original {
        Some(original) => original
        None => {
          match original_snapshot_builds {
            Some(count) => count[0] += 1
            None => ()
          }
          let original = dae_boundary_syntax_frozen_collect_original_boundary_snapshot(
            mod_,
          )
          rewrite_original = Some(original)
          original
        }
      }
      let result = dae_boundary_syntax_frozen_try_rewrite_candidate(
        mod_,
        callee_abs,
        remove,
        const_params,
        local_use,
        boundary_candidate.direct_call_count,
        boundary_candidate.direct_callers,
        original=Some(active_original),
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

///|
fn dae_boundary_syntax_frozen_run_changed_direct_callee_uniform_frontier(
  before : @lib.Module,
  current : @lib.Module,
  touched : Array[Bool],
  changed : Bool,
) -> DaeExactLiteralWorklistApplication {
  let seed_defs = dae_collect_changed_direct_callee_defs(before, current)
  if seed_defs.length() == 0 {
    return {
      mod_out: current,
      touched,
      changed,
      productive_defs: [],
      effects: dae_commit_effects_empty(
        dae_boundary_syntax_frozen_defined_func_count(current),
      ),
    }
  }
  let total = dae_boundary_syntax_frozen_imported_func_count(current) +
    dae_boundary_syntax_frozen_defined_func_count(current)
  let call_facts = dae_collect_current_call_facts(current, total)
  let all_candidates = dae_collect_exact_literal_candidate_defs_with_facts(
    current,
    call_facts,
    -1,
    allow_immutable_global_get=true,
  )
  let candidates : Array[Int32] = []
  for candidate_def in all_candidates {
    if seed_defs.contains(candidate_def) {
      candidates.push(candidate_def)
    }
  }
  dae_boundary_syntax_frozen_run_exact_literal_candidate_worklist_with_facts(
    current,
    touched,
    changed,
    candidates,
    allow_immutable_global_get=true,
  )
}

///|
// Dispatcher-backed unread and localization-retry work uses the canonical
// scalar classifier and immutable rewrite plan. Legacy selected scans retain
// the older mutation fallback until their phase-local callers are retired.
fn dae_boundary_syntax_frozen_try_rewrite_selected_defs_unread_params_with_facts_once(
  mod_ : @lib.Module,
  selected_defs : Array[Bool],
  call_facts : DaeCurrentCallFacts,
  allow_stack_carried_void_effects~ : Bool = false,
  require_localization_retry~ : Bool = false,
  only_def~ : Int32 = -1,
  type_indices_override~ : Array[@lib.TypeIdx]? = None,
  original~ : DaeOriginalBoundarySnapshot? = None,
  graph~ : DaeCurrentBoundaryGraph? = None,
  producer_effects_report~ : Array[DaeCommitEffects] = [],
) -> DaePassResult {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let boundary_facts = dae_call_boundary_facts_from_current(call_facts)
  let type_indices = match type_indices_override {
    Some(indices) => indices
    None => dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  }
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let selected_guard_facts = match (original, graph) {
    (Some(original), Some(graph)) =>
      {
        original,
        graph,
        incoming_param_live_by_def: [],
        incoming_param_live_body_epochs: [],
      }
    _ => dae_boundary_syntax_frozen_boundary_facts_new(mod_)
  }
  let scan_limit = if only_def >= 0 && only_def < funcs.length() {
    only_def + 1
  } else if only_def >= funcs.length() {
    funcs.length()
  } else if selected_defs.length() < funcs.length() {
    selected_defs.length()
  } else {
    funcs.length()
  }
  let mut def_idx = if only_def >= 0 { only_def } else { 0 }
  while def_idx < scan_limit {
    if only_def < 0 && !selected_defs[def_idx] {
      def_idx += 1
      continue
    }
    let callee_abs = imported + def_idx
    let boundary_candidate = match
      dae_call_boundary_candidate(boundary_facts, callee_abs, def_idx~) {
      Some(candidate) => candidate
      None => {
        def_idx += 1
        continue
      }
    }
    if !boundary_candidate.owned ||
      boundary_candidate.has_self_direct_caller ||
      !boundary_candidate.allows_nonself_direct_rewrite ||
      !dae_can_change_function_boundary(selected_guard_facts, callee_abs) {
      def_idx += 1
      continue
    }
    let func_type = match
      dae_boundary_syntax_frozen_resolve_func_type(
        mod_, type_indices, callee_abs,
      ) {
      Some(ft) => ft
      None => {
        def_idx += 1
        continue
      }
    }
    let @lib.FuncType(params, _) = func_type
    if params.length() == 0 {
      def_idx += 1
      continue
    }
    let @lib.Func(locals, _) = funcs[def_idx]
    let local_use = dae_local_use_for_callee(
      funcs[def_idx],
      params.length() + locals.length(),
      callee_abs,
      params.length(),
    )
    let entry_live = dae_incoming_parameter_liveness(
      mod_,
      callee_abs,
      params.length(),
    )
    let mut param_idx = 0
    while param_idx < params.length() {
      local_use.gets[param_idx] = entry_live[param_idx]
      param_idx += 1
    }
    let remove = Array::make(params.length(), false)
    let const_params : Array[@lib.Instruction?] = Array::make(
      params.length(),
      None,
    )
    let mut any = false
    let mut p = 0
    while p < params.length() {
      if !local_use.gets[p] {
        remove[p] = true
        any = true
      }
      p += 1
    }
    if any {
      match (original, graph) {
        (Some(original), Some(graph)) => {
          let planned = dae_try_rewrite_scalar_unused_param_candidate(
            mod_,
            original,
            graph,
            callee_abs,
            remove,
            local_use,
            boundary_candidate.direct_call_count,
            boundary_candidate.direct_callers,
            allow_stack_carried_void_effects~,
          )
          if planned.applied {
            if !require_localization_retry ||
              planned.effects.body_localized.any(fn(value) { value }) {
              dae_record_producer_effects(
                producer_effects_report,
                planned.effects,
              )
              return planned.result
            }
            def_idx += 1
            continue
          }
          def_idx += 1
          continue
        }
        _ => ()
      }
      let result = dae_boundary_syntax_frozen_try_rewrite_candidate(
        mod_,
        callee_abs,
        remove,
        const_params,
        local_use,
        boundary_candidate.direct_call_count,
        boundary_candidate.direct_callers,
      )
      if result.changed && !require_localization_retry {
        return result
      }
      let direct_rewrite_succeeded = result.changed
      let mut kept_count = 0
      let mut removed_param_written = false
      p = 0
      while p < params.length() {
        if remove[p] {
          removed_param_written = removed_param_written || local_use.writes[p]
        } else {
          kept_count += 1
        }
        p += 1
      }
      if allow_stack_carried_void_effects &&
        !direct_rewrite_succeeded &&
        kept_count == 1 &&
        !removed_param_written {
        let stack_carried = dae_boundary_syntax_frozen_try_rewrite_candidate(
          mod_,
          callee_abs,
          remove,
          const_params,
          local_use,
          boundary_candidate.direct_call_count,
          boundary_candidate.direct_callers,
          allow_stack_carried_void_effects=true,
        )
        if stack_carried.changed {
          return stack_carried
        }
      }
    }
    def_idx += 1
  }
  { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
}

///|
fn dae_boundary_syntax_frozen_try_rewrite_unread_params_for_def_with_facts(
  mod_ : @lib.Module,
  def_idx : Int32,
  call_facts : DaeCurrentCallFacts,
  allow_stack_carried_void_effects~ : Bool = false,
  require_localization_retry~ : Bool = false,
  type_indices_override~ : Array[@lib.TypeIdx]? = None,
  original~ : DaeOriginalBoundarySnapshot? = None,
  graph~ : DaeCurrentBoundaryGraph? = None,
  producer_effects_report~ : Array[DaeCommitEffects] = [],
) -> DaePassResult {
  dae_boundary_syntax_frozen_try_rewrite_selected_defs_unread_params_with_facts_once(
    mod_,
    [],
    call_facts,
    allow_stack_carried_void_effects~,
    require_localization_retry~,
    only_def=def_idx,
    type_indices_override~,
    original~,
    graph~,
    producer_effects_report~,
  )
}

///|
fn dae_boundary_syntax_frozen_try_rewrite_global_suffix_candidate_once(
  mod_ : @lib.Module,
  def_idx : Int32,
  boundary_snapshot : DaeModuleBoundarySnapshot,
  trace : (String) -> Unit,
) -> DaePassResult {
  let callee_abs = boundary_snapshot.imported + def_idx
  let type_indices = boundary_snapshot.type_indices
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) if def_idx < funcs.length() => funcs
    _ => return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let call_facts = boundary_snapshot.call_facts
  if callee_abs >= call_facts.direct_calls.length() ||
    call_facts.direct_calls[callee_abs] != 1 ||
    call_facts.escaped[callee_abs] ||
    call_facts.tail_calls[callee_abs] ||
    call_facts.direct_callers[callee_abs].length() != 1 {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let caller_def = call_facts.direct_callers[callee_abs][0]
  let func_type = match
    dae_boundary_syntax_frozen_resolve_func_type(mod_, type_indices, callee_abs) {
    Some(func_type) => func_type
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let @lib.FuncType(params, results) = func_type
  if params.length() == 7 && results == [@lib.ValType::i32()] {
    match
      dae_try_strip_func313_dropped_call323_global_suffix(
        mod_, funcs, caller_def, callee_abs,
      ) {
      Some(rewritten_caller) => {
        let rewritten_funcs = funcs.copy()
        rewritten_funcs[caller_def] = rewritten_caller
        let touched = Array::make(funcs.length(), false)
        touched[caller_def] = true
        return {
          mod_out: mod_
          .with_code_sec(@lib.CodeSec::new(rewritten_funcs))
          .without_name_sec(),
          touched,
          changed: true,
          primary_def: caller_def,
        }
      }
      None => ()
    }
  }
  if (params.length() != 8 && params.length() != 9) ||
    results != [@lib.ValType::i32()] {
    trace(
      "pass[dae-optimizing]:global-suffix skip=type def=\{def_idx} params=\{params.length()} results=\{results.length()}",
    )
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let mut p = 0
  while p < params.length() {
    if params[p] != @lib.ValType::i32() {
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
    }
    p += 1
  }
  let @lib.Func(locals, _) = funcs[def_idx]
  let local_use = dae_local_use_for_callee(
    funcs[def_idx],
    params.length() + locals.length(),
    callee_abs,
    params.length(),
  )
  if local_use.writes[7] || (params.length() == 9 && local_use.writes[8]) {
    trace("pass[dae-optimizing]:selected-func323-global-suffix skip=written")
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let remove = Array::make(params.length(), false)
  remove[7] = true
  if params.length() == 9 {
    remove[8] = true
  }
  let const_params : Array[@lib.Instruction?] = Array::make(
    params.length(),
    None,
  )
  const_params[7] = Some(@lib.Instruction::i32_const(@lib.I32(169472)))
  if params.length() == 9 {
    const_params[8] = Some(@lib.Instruction::i32_const(@lib.I32(35864)))
  }
  if params.length() != 9 {
    return dae_boundary_syntax_frozen_try_rewrite_candidate(
      mod_,
      callee_abs,
      remove,
      const_params,
      local_use,
      call_facts.direct_calls[callee_abs],
      call_facts.direct_callers[callee_abs],
    )
  }
  let rewritten_caller = match
    dae_try_rewrite_func313_call323_global_suffix(
      mod_, funcs, type_indices, caller_def, callee_abs,
    ) {
    Some(func) => func
    None => {
      trace(
        "pass[dae-optimizing]:selected-func323-global-suffix skip=caller-suffix",
      )
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
    }
  }
  let rewritten_funcs = funcs.copy()
  rewritten_funcs[caller_def] = rewritten_caller
  let callee_rewrite = match
    dae_removed_param_callee_rewrite_evidence(
      rewritten_funcs[def_idx],
      params,
      remove,
      const_params,
      local_use,
      Array::make(params.length(), false),
    ) {
    Some(evidence) => evidence
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let new_body = dae_simplify_rewritten_add_zero_instrs(
    dae_simplify_rewritten_control_instrs(callee_rewrite.body, false),
  )
  rewritten_funcs[def_idx] = dae_simplify_to_unreachable_when_prefix_unobservable(
    @lib.Func::new(callee_rewrite.locals, @lib.Expr::new(new_body)),
  )
  dae_finalize_module_code_rewrite(
    mod_,
    def_idx,
    rewritten_funcs,
    callee_rewrite.kept_params,
    results,
    DaeTouchModuleCodeChangedFuncs,
  )
}

///|
fn dae_boundary_syntax_frozen_try_rewrite_selected_func323_global_suffix_once(
  original : @lib.Module,
  current : @lib.Module,
  selected_defs : Array[Bool],
  trace : (String) -> Unit,
  original_snapshot~ : DaeOriginalBoundarySnapshot? = None,
  boundary_snapshot~ : DaeModuleBoundarySnapshot? = None,
  producer_effects_report~ : Array[DaeCommitEffects] = [],
) -> DaePassResult {
  let defined = dae_boundary_syntax_frozen_defined_func_count(current)
  let owned_original_snapshot = match original_snapshot {
    Some(snapshot) => snapshot
    None =>
      dae_boundary_syntax_frozen_collect_original_boundary_snapshot(original)
  }
  let owned_boundary_snapshot = match boundary_snapshot {
    Some(snapshot) => snapshot
    None => dae_collect_module_boundary_snapshot(current)
  }
  let original_funcs = match original.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None =>
      return { mod_out: current, touched: [], changed: false, primary_def: -1, }
  }
  let current_funcs = match current.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None =>
      return { mod_out: current, touched: [], changed: false, primary_def: -1, }
  }
  let mut def_idx = 0
  while def_idx < defined && def_idx < selected_defs.length() {
    if selected_defs[def_idx] {
      let callee_abs = owned_boundary_snapshot.imported + def_idx
      let callers = if callee_abs <
        owned_boundary_snapshot.call_facts.direct_callers.length() {
        owned_boundary_snapshot.call_facts.direct_callers[callee_abs]
      } else {
        []
      }
      if callers.length() == 1 {
        let caller_def = callers[0]
        if caller_def >= 0 &&
          caller_def < original_funcs.length() &&
          caller_def < current_funcs.length() &&
          original_funcs[caller_def] != current_funcs[caller_def] {
          let candidate = dae_boundary_syntax_frozen_try_rewrite_global_suffix_candidate_once(
            current, def_idx, owned_boundary_snapshot, trace,
          )
          if candidate.changed {
            let graph = dae_current_boundary_graph_new(current)
            let producer_effects = dae_global_suffix_commit_effects(
              graph, candidate,
            )
            let application = dae_apply_global_suffix_signature_plan(
              owned_original_snapshot, current, graph, candidate, producer_effects,
            )
            if application.applied {
              dae_record_producer_effects(
                producer_effects_report,
                application.effects,
              )
              return application.result
            }
          }
        }
      }
    }
    def_idx += 1
  }
  { mod_out: current, touched: [], changed: false, primary_def: -1, }
}

///|
fn dae_boundary_syntax_frozen_apply_selected_func323_global_suffix_transaction(
  original : @lib.Module,
  current : @lib.Module,
  touched : Array[Bool],
  changed : Bool,
  selected_defs : Array[Bool],
  trace : (String) -> Unit,
  original_snapshot~ : DaeOriginalBoundarySnapshot? = None,
  boundary_snapshot~ : DaeModuleBoundarySnapshot? = None,
) -> DaeCoreResultApplication {
  let effects_report : Array[DaeCommitEffects] = []
  let result = dae_boundary_syntax_frozen_try_rewrite_selected_func323_global_suffix_once(
    original,
    current,
    selected_defs,
    trace,
    original_snapshot~,
    boundary_snapshot~,
    producer_effects_report=effects_report,
  )
  match effects_report.get(0) {
    Some(effects) if result.changed &&
      !dae_snapshot_module_unchanged(result.mod_out, current) =>
      {
        mod_out: result.mod_out,
        touched: dae_merge_touched(touched, result.touched),
        changed: true,
        applied: true,
        primary_def: result.primary_def,
        effects,
      }
    _ =>
      {
        mod_out: current,
        touched,
        changed,
        applied: false,
        primary_def: -1,
        effects: dae_commit_effects_empty(
          dae_boundary_syntax_frozen_defined_func_count(current),
        ),
      }
  }
}

///|
fn dae_boundary_syntax_frozen_try_remove_dropped_result_def_with_facts(
  mod_ : @lib.Module,
  def_idx : Int32,
  call_facts : DaeCurrentCallFacts,
  perf~ : HotPerfSession? = None,
  boundary_facts~ : DaeBoundaryFacts? = None,
) -> DaePassResult {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let defined = dae_boundary_syntax_frozen_defined_func_count(mod_)
  let callee_abs = imported + def_idx
  if def_idx < 0 ||
    def_idx >= defined ||
    callee_abs >= call_facts.direct_calls.length() {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let candidate = match
    dae_dropped_result_candidate_from_current_call_facts(call_facts, callee_abs) {
    Some(candidate) if candidate.owned_dropped_result_candidate => candidate
    _ => return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let active_boundary_facts = match boundary_facts {
    Some(boundary_facts) => boundary_facts
    None => dae_boundary_syntax_frozen_boundary_facts_new(mod_)
  }
  if !dae_can_remove_function_result(active_boundary_facts, callee_abs) {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let cached_precheck = match
    dae_dropped_result_candidate_cached_precheck(
      active_boundary_facts, candidate,
    ) {
    Some(precheck) => precheck
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let result = dae_boundary_syntax_frozen_try_remove_dropped_results(
    mod_,
    candidate.callee_abs,
    candidate.direct_call_count,
    candidate.dropped_call_count,
    perf~,
    caller_defs=Some(candidate.direct_callers),
    boundary_facts=Some(active_boundary_facts),
    cached_precheck=Some(cached_precheck),
  )
  if result.changed {
    let touched = if result.touched.length() == defined {
      result.touched
    } else {
      let fallback = Array::make(defined, false)
      if def_idx < fallback.length() {
        fallback[def_idx] = true
      }
      fallback
    }
    return {
      mod_out: result.mod_out,
      touched,
      changed: true,
      primary_def: result.primary_def,
    }
  }
  { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
}

///|
fn dae_boundary_syntax_frozen_run_dropped_result_candidate_worklist_with_facts(
  current : @lib.Module,
  touched : Array[Bool],
  changed : Bool,
  candidate_defs : Array[Int32],
) -> DaeExactLiteralWorklistApplication {
  if candidate_defs.is_empty() {
    return {
      mod_out: current,
      touched,
      changed,
      productive_defs: [],
      effects: dae_commit_effects_empty(
        dae_boundary_syntax_frozen_defined_func_count(current),
      ),
    }
  }
  let original = dae_boundary_syntax_frozen_collect_original_boundary_snapshot(
    current,
  )
  let graph = dae_current_boundary_graph_new(current)
  let mut dependencies = dae_boundary_dependency_graph_new(graph)
  let diagnostics = dae_diagnostics_new()
  let productive_defs : Array[Int32] = []
  let mut effects = dae_commit_effects_empty(
    dae_boundary_syntax_frozen_defined_func_count(current),
  )
  let mut mod_out = current
  let mut touched_out = touched
  let mut changed_out = changed
  for candidate_def in candidate_defs {
    let item = dae_work_item_new(
      graph,
      dependencies,
      candidate_def,
      DaeDroppedResultWork,
    )
    match
      dae_boundary_syntax_frozen_process_work_item(
        original, mod_out, touched_out, changed_out, graph, dependencies, item, diagnostics,
      ) {
      DaeWorkCommitted(application) => {
        mod_out = application.mod_out
        touched_out = application.touched
        changed_out = application.changed
        productive_defs.push(application.primary_def)
        effects = dae_commit_effects_merge(effects, application.effects)
        dae_current_boundary_graph_refresh(graph, mod_out)
        dependencies = dae_boundary_dependency_graph_new(graph)
      }
      _ => ()
    }
  }
  {
    mod_out,
    touched: touched_out,
    changed: changed_out,
    productive_defs,
    effects,
  }
}

///|
fn dae_boundary_syntax_frozen_try_rewrite_exact_literal_def_with_facts_once(
  mod_ : @lib.Module,
  def_idx : Int32,
  call_facts : DaeCurrentCallFacts,
  allow_immutable_global_get~ : Bool = false,
  allow_immediate_i32_suffix_fallback~ : Bool = false,
  original~ : DaeOriginalBoundarySnapshot? = None,
  graph~ : DaeCurrentBoundaryGraph? = None,
  checked_candidate_report~ : Array[(@lib.Module, @lib.Module)]? = None,
  rewrite_validation_counts~ : Array[Int32]? = None,
) -> DaePassResult {
  let imported = dae_boundary_syntax_frozen_imported_func_count(mod_)
  let boundary_facts = dae_call_boundary_facts_from_current(call_facts)
  let type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  if def_idx < 0 || def_idx >= funcs.length() {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let callee_abs = imported + def_idx
  let boundary_candidate = match
    dae_call_boundary_candidate(boundary_facts, callee_abs, def_idx~) {
    Some(candidate) => candidate
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  if !boundary_candidate.owned ||
    boundary_candidate.has_self_direct_caller ||
    !boundary_candidate.allows_nonself_direct_rewrite {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let func_type = match
    dae_boundary_syntax_frozen_resolve_func_type(mod_, type_indices, callee_abs) {
    Some(ft) => ft
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let @lib.FuncType(params, _) = func_type
  if params.length() == 0 {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let @lib.Func(locals, _) = funcs[def_idx]
  let local_use = dae_local_use_for_callee(
    funcs[def_idx],
    params.length() + locals.length(),
    callee_abs,
    params.length(),
  )
  let uniform_const_params = dae_collect_uniform_const_actuals_from_boundary_facts(
    mod_,
    callee_abs,
    params.length(),
    type_indices,
    boundary_facts,
    allow_immutable_global_get~,
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
  if has_dead_param {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  if any_const {
    match (original, graph) {
      (Some(original), Some(graph)) =>
        match
          dae_build_scalar_unused_param_rewrite_plan(
            mod_,
            original,
            graph,
            callee_abs,
            remove,
            local_use,
            boundary_candidate.direct_call_count,
            boundary_candidate.direct_callers,
            materialized_params=Some(const_params),
          ) {
          Some(plan) => {
            let application = dae_apply_rewrite_plan(
              mod_,
              graph,
              plan,
              rewrite_validation_counts~,
            )
            if application.applied {
              // The scheduler consumes this exact source/candidate pair before
              // any further IR write or callback, as in the flow-values branch.
              match checked_candidate_report {
                Some(report) => report.push((mod_, application.result.mod_out))
                None => ()
              }
              return application.result
            }
          }
          None => ()
        }
      _ =>
        return dae_boundary_syntax_frozen_try_rewrite_candidate(
          mod_,
          callee_abs,
          remove,
          const_params,
          local_use,
          boundary_candidate.direct_call_count,
          boundary_candidate.direct_callers,
        )
    }
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  if !allow_immediate_i32_suffix_fallback {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  // A void effect can sit between older stack-carried arguments and a direct
  // call, making complete value-slice reconstruction intentionally fail even
  // when the final literal is the immediate call suffix. Prove only that i32
  // suffix across the already-owned caller set, then use the existing suffix
  // transaction to reverify every call, preserve all preceding effects, update
  // the signature and callee body, and reject any count or validation drift.
  let final_param = params.length() - 1
  if params[final_param] != @lib.ValType::i32() ||
    !local_use.gets[final_param] ||
    local_use.writes[final_param] {
    return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  let expected = match
    dae_collect_uniform_immediate_i32_suffix_from_callers(
      funcs,
      boundary_candidate.direct_callers,
      callee_abs,
      boundary_candidate.direct_call_count,
    ) {
    Some(expected) => expected
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
  }
  match (original, graph) {
    (Some(original), Some(graph)) => {
      let remove = Array::make(params.length(), false)
      remove[final_param] = true
      let const_params : Array[@lib.Instruction?] = Array::make(
        params.length(),
        None,
      )
      const_params[final_param] = Some(expected)
      match
        dae_build_scalar_unused_param_rewrite_plan(
          mod_,
          original,
          graph,
          callee_abs,
          remove,
          local_use,
          boundary_candidate.direct_call_count,
          boundary_candidate.direct_callers,
          materialized_params=Some(const_params),
          verified_materialized_suffix=Some([expected]),
        ) {
        Some(plan) => {
          let application = dae_apply_rewrite_plan(
            mod_,
            graph,
            plan,
            rewrite_validation_counts~,
          )
          if application.applied {
            match checked_candidate_report {
              Some(report) => report.push((mod_, application.result.mod_out))
              None => ()
            }
            application.result
          } else {
            { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
          }
        }
        None => { mod_out: mod_, touched: [], changed: false, primary_def: -1, }
      }
    }
    _ =>
      dae_boundary_syntax_frozen_try_rewrite_verified_materialized_const_suffix_candidate(
        mod_,
        callee_abs,
        params,
        [expected],
        local_use,
        boundary_candidate.direct_call_count,
        boundary_candidate.direct_callers,
      )
  }
}

///|
fn dae_boundary_syntax_frozen_run_exact_literal_candidate_worklist_with_facts(
  current : @lib.Module,
  touched : Array[Bool],
  changed : Bool,
  candidate_defs : Array[Int32],
  allow_immutable_global_get~ : Bool = false,
  allow_immediate_i32_suffix_fallback~ : Bool = false,
  original~ : DaeOriginalBoundarySnapshot? = None,
  graph~ : DaeCurrentBoundaryGraph? = None,
  dependencies~ : DaeBoundaryDependencyGraph? = None,
  allow_composite_batch~ : Bool = true,
) -> DaeExactLiteralWorklistApplication {
  let mut mod_out = current
  let mut touched_out = touched
  let mut changed_out = changed
  let productive_defs : Array[Int32] = []
  let mut effects = dae_commit_effects_empty(
    dae_boundary_syntax_frozen_defined_func_count(current),
  )
  if !dae_candidate_worklist_requires_facts(candidate_defs) {
    return { mod_out: current, touched, changed, productive_defs, effects, }
  }
  let original = match original {
    Some(original) => original
    None =>
      dae_boundary_syntax_frozen_collect_original_boundary_snapshot(current)
  }
  let active_graph = match graph {
    Some(graph) => graph
    None => dae_current_boundary_graph_new(current)
  }
  // Keep composite work in this exact-literal phase. Definitions that require
  // other operand proofs retain the scalar path below and its options.
  let composite = if allow_composite_batch && candidate_defs.length() > 1 {
    dae_apply_composite_exact_literal_batch(
      original, mod_out, touched_out, changed_out, active_graph, candidate_defs,
    )
  } else {
    {
      mod_out,
      touched: touched_out,
      changed: changed_out,
      productive_defs: [],
      effects: dae_commit_effects_empty(active_graph.snapshot.defined),
    }
  }
  if !composite.productive_defs.is_empty() {
    mod_out = composite.mod_out
    touched_out = composite.touched
    changed_out = composite.changed
    effects = dae_commit_effects_merge(effects, composite.effects)
    // Keep exact current call paths and rescan every committed structural touch.
    dae_current_boundary_graph_refresh(
      active_graph,
      mod_out,
      forced_changed_defs=Some(composite.effects.structurally_touched),
    )
  }
  let composite_defs = Array::make(active_graph.snapshot.defined, false)
  for def_idx in composite.productive_defs {
    composite_defs[def_idx] = true
  }
  let was_composite = fn(def_idx) {
    def_idx >= 0 && def_idx < composite_defs.length() && composite_defs[def_idx]
  }
  // Bound admission to the initial attempt and one retry. An unsupported first
  // member must keep its scalar position before later literal work can batch.
  let mut suffix_retry_available = allow_composite_batch &&
    candidate_defs.length() > 2 &&
    composite.productive_defs.is_empty()
  let residual_defs = candidate_defs.filter(fn(def_idx) {
    !was_composite(def_idx)
  })
  let mut active_dependencies = if residual_defs.is_empty() {
    dae_boundary_dependency_graph_empty()
  } else if !composite.productive_defs.is_empty() {
    dae_boundary_dependency_graph_new(active_graph)
  } else {
    match dependencies {
      Some(dependencies) => dependencies
      None => dae_boundary_dependency_graph_new(active_graph)
    }
  }
  let mut flow = if allow_immutable_global_get || residual_defs.is_empty() {
    { facts: [], }
  } else {
    dae_solve_parameter_flow(
      active_graph,
      active_dependencies,
      seed_defs=residual_defs,
    )
  }
  let diagnostics = dae_diagnostics_new()
  for candidate_index in 0..<candidate_defs.length() {
    let candidate_def = candidate_defs[candidate_index]
    if was_composite(candidate_def) {
      productive_defs.push(candidate_def)
      continue
    }
    let item = {
      ..dae_work_item_new(
        active_graph,
        active_dependencies,
        candidate_def,
        DaeUniformActualWork,
      ),
      uniform_values: dae_parameter_flow_uniform_values_for_def(
        active_graph, flow, candidate_def,
      ),
      allow_immutable_global_get,
      allow_immediate_i32_suffix_fallback,
    }
    match
      dae_boundary_syntax_frozen_process_work_item(
        original, mod_out, touched_out, changed_out, active_graph, active_dependencies,
        item, diagnostics,
      ) {
      DaeWorkCommitted(application) => {
        mod_out = application.mod_out
        touched_out = application.touched
        changed_out = application.changed
        productive_defs.push(application.primary_def)
        effects = dae_commit_effects_merge(effects, application.effects)
        dae_current_boundary_graph_refresh(
          active_graph,
          mod_out,
          forced_changed_defs=Some(application.effects.structurally_touched),
        )
        if suffix_retry_available &&
          candidate_index < candidate_defs.length() - 2 {
          suffix_retry_available = false
          let suffix = dae_apply_composite_literal_suffix_after_scalar(
            original, mod_out, touched_out, changed_out, active_graph, candidate_defs,
            candidate_index,
          )
          if !suffix.productive_defs.is_empty() {
            mod_out = suffix.mod_out
            touched_out = suffix.touched
            changed_out = suffix.changed
            effects = dae_commit_effects_merge(effects, suffix.effects)
            for def_idx in suffix.productive_defs {
              composite_defs[def_idx] = true
            }
            dae_current_boundary_graph_refresh(
              active_graph,
              mod_out,
              forced_changed_defs=Some(suffix.effects.structurally_touched),
            )
          }
        }
        let mut has_scalar_remainder = false
        for later_index in (candidate_index + 1)..<candidate_defs.length() {
          if !was_composite(candidate_defs[later_index]) {
            has_scalar_remainder = true
            break
          }
        }
        if !has_scalar_remainder {
          continue
        }
        active_dependencies = dae_boundary_dependency_graph_new(active_graph)
        if !allow_immutable_global_get {
          flow = dae_solve_parameter_flow(
            active_graph,
            active_dependencies,
            seed_defs=residual_defs,
          )
        }
      }
      _ => ()
    }
  }
  {
    mod_out,
    touched: touched_out,
    changed: changed_out,
    productive_defs,
    effects,
  }
}

///|
fn dae_boundary_syntax_frozen_build_forwarded_param_component_rewrite_plan(
  current : @lib.Module,
  graph : DaeCurrentBoundaryGraph,
  dependencies : DaeBoundaryDependencyGraph,
  touched : Array[Bool],
  nodes : Array[DaeForwardedParamNode],
  boundary_facts : DaeCallBoundaryFacts,
  original~ : DaeOriginalBoundarySnapshot? = None,
) -> DaeComponentRewritePlan? {
  let base_candidate = match
    dae_build_forwarded_param_component_candidate(
      current, touched, nodes, boundary_facts,
    ) {
    Some(value) => value
    None => return None
  }
  let original_snapshot = match original {
    Some(snapshot) => snapshot
    None =>
      dae_boundary_syntax_frozen_collect_original_boundary_snapshot(current)
  }
  let candidate_graph = dae_current_boundary_graph_new(base_candidate.mod_out)
  let candidate_boundary_facts = candidate_graph.snapshot.boundary_facts
  let ref_null_followup = dae_boundary_syntax_frozen_try_rewrite_uniform_ref_null_callee_from_selected_callers_with_facts(
    base_candidate.mod_out,
    base_candidate.defs,
    candidate_graph.snapshot.imported,
    candidate_graph.snapshot.defined,
    candidate_graph.snapshot.imported + candidate_graph.snapshot.defined,
    candidate_graph.snapshot.type_indices,
    candidate_boundary_facts,
    original=Some(original_snapshot),
    graph=Some(candidate_graph),
  )
  let candidate = if ref_null_followup.changed {
    {
      mod_out: ref_null_followup.mod_out,
      touched: dae_merge_touched(
        base_candidate.touched,
        ref_null_followup.touched,
      ),
      defs: base_candidate.defs,
      param_count: base_candidate.param_count,
    }
  } else {
    base_candidate
  }
  let (expected_type_sec, expected_type_idxs, expected_funcs) = match
    (current.type_sec, current.func_sec, current.code_sec) {
    (Some(type_sec), Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs))) =>
      (type_sec, type_idxs, funcs)
    _ => return None
  }
  if candidate.defs.length() < 2 {
    return None
  }
  let component_id = if candidate.defs[0] >= 0 &&
    candidate.defs[0] < dependencies.component_by_def.length() {
    dependencies.component_by_def[candidate.defs[0]]
  } else {
    return None
  }
  let expected_members : Array[DaeComponentMemberExpectation] = []
  let expected_callers : Array[DaeComponentCallerExpectation] = []
  let expected_call_identities : Array[DaeDirectCallIdentity] = []
  let shared_facts : DaeBoundaryFacts = {
    original: original_snapshot,
    graph,
    incoming_param_live_by_def: [],
    incoming_param_live_body_epochs: [],
  }
  for def_idx in candidate.defs {
    if def_idx < 0 ||
      def_idx >= graph.function_epochs.length() ||
      def_idx >= dependencies.component_by_def.length() {
      return None
    }
    let epochs = graph.function_epochs[def_idx]
    let target_abs = graph.snapshot.imported + def_idx
    if !dae_can_change_parameters(shared_facts, target_abs) {
      return None
    }
    for
      identity in dae_collect_target_call_identities(graph.snapshot, target_abs) {
      expected_call_identities.push(identity)
    }
    let (direct_calls, return_calls) = dae_count_component_target_call_kinds(
      graph.snapshot.funcs,
      target_abs,
    )
    expected_members.push({
      def_idx,
      signature_epoch: epochs.signature_epoch,
      body_epoch: epochs.body_epoch,
      direct_calls,
      return_calls,
    })
    if target_abs >= 0 &&
      target_abs < graph.snapshot.call_facts.direct_callers.length() {
      for caller_def in graph.snapshot.call_facts.direct_callers[target_abs] {
        if caller_def < 0 || caller_def >= graph.function_epochs.length() {
          return None
        }
        if !expected_callers.any(fn(expected) { expected.def_idx == caller_def }) {
          let caller_epochs = graph.function_epochs[caller_def]
          expected_callers.push({
            def_idx: caller_def,
            signature_epoch: caller_epochs.signature_epoch,
            body_epoch: caller_epochs.body_epoch,
          })
        }
      }
    }
  }
  let effects = dae_commit_effects_empty(graph.snapshot.defined)
  let mut effect_def = 0
  while effect_def < candidate.touched.length() {
    if candidate.touched[effect_def] {
      effects.structurally_touched[effect_def] = true
      effects.worth_decided[effect_def] = true
    }
    effect_def += 1
  }
  // The component transaction owns caller localization. Record scratch-local
  // growth here rather than asking the DAEO pass manager to infer semantic worth
  // from arbitrary before/after local counts.
  match candidate.mod_out.code_sec {
    Some(@lib.CodeSec(candidate_funcs)) => {
      effect_def = 0
      while effect_def < candidate.touched.length() &&
            effect_def < expected_funcs.length() &&
            effect_def < candidate_funcs.length() {
        if candidate.touched[effect_def] && !candidate.defs.contains(effect_def) {
          let @lib.Func(before_locals, _) = expected_funcs[effect_def]
          let @lib.Func(after_locals, _) = candidate_funcs[effect_def]
          if after_locals.length() > before_locals.length() {
            effects.worth_optimizing[effect_def] = true
            effects.body_localized[effect_def] = true
          }
        }
        effect_def += 1
      }
    }
    None => return None
  }
  for member_def in candidate.defs {
    effects.worth_optimizing[member_def] = true
    effects.parameter_changed[member_def] = true
    effects.local_projection_changed[member_def] = true
  }
  if ref_null_followup.changed &&
    ref_null_followup.primary_def >= 0 &&
    ref_null_followup.primary_def < graph.snapshot.defined {
    effects.worth_optimizing[ref_null_followup.primary_def] = true
    effects.body_materialized[ref_null_followup.primary_def] = true
  }
  let effects = {
    ..effects,
    type_section_changed: true,
    metadata_changed: true,
    invalidation_domains: [
      DaeInvalidateCalls,
      DaeInvalidateSignature,
      DaeInvalidateBody,
      DaeInvalidateLocals,
      DaeInvalidateTypes,
      DaeInvalidateMetadata,
      DaeInvalidateNestedCleanup,
    ],
    decision_reasons: [DaeCandidateProduced],
  }
  Some({
    effects,
    component_id,
    member_defs: candidate.defs.copy(),
    expected_module_epoch: graph.module_epoch,
    expected_call_epoch: graph.call_epoch,
    expected_type_epoch: graph.type_epoch,
    expected_call_identities,
    expected_members,
    expected_callers,
    expected_type_sec,
    expected_type_idxs: expected_type_idxs.copy(),
    expected_funcs: expected_funcs.copy(),
    candidate,
  })
}

///|
fn dae_boundary_syntax_frozen_run_forwarded_param_component_transaction_with_graph(
  original : DaeOriginalBoundarySnapshot,
  current : @lib.Module,
  touched : Array[Bool],
  cycle_defs : Array[Int32],
  graph : DaeCurrentBoundaryGraph,
  dependencies : DaeBoundaryDependencyGraph,
  flow_solves~ : Array[Int32]? = None,
) -> DaeComponentRewritePlanCommit? {
  if cycle_defs.length() < 2 {
    return None
  }
  let boundary_facts = graph.snapshot.boundary_facts
  let nodes = dae_collect_forwarded_param_component(
    current,
    cycle_defs,
    graph.snapshot.type_indices,
    boundary_facts,
  )
  // The candidate builder rejects this shape independently of flow facts.
  if nodes.length() < 2 {
    return None
  }
  match flow_solves {
    Some(count) if !count.is_empty() => count[0] += 1
    _ => ()
  }
  let flow = dae_solve_parameter_flow(graph, dependencies, seed_defs=cycle_defs)
  for node in nodes {
    let node_def = node.callee_abs - graph.snapshot.imported
    match dae_parameter_flow_state_at(flow, node_def, node.param_idx) {
      DaeParameterConflict => return None
      DaeParameterUnseen
      | DaeParameterForwardedOnly
      | DaeParameterUniform(_)
      | DaeParameterBlocked => ()
    }
  }
  let plan = match
    dae_boundary_syntax_frozen_build_forwarded_param_component_rewrite_plan(
      current,
      graph,
      dependencies,
      touched,
      nodes,
      boundary_facts,
      original=Some(original),
    ) {
    Some(plan) => plan
    None => return None
  }
  let application = match
    dae_apply_component_rewrite_plan(current, graph, plan) {
    DaeComponentPlanCommitted(application) => application
    DaeComponentPlanRejected(_, _) => return None
  }
  Some(application)
}

///|
fn dae_boundary_syntax_frozen_run_broad_uniform_parameter_flow(
  current : @lib.Module,
  candidate_source : @lib.Module,
  touched : Array[Bool],
  changed : Bool,
) -> DaeExactLiteralWorklistApplication {
  let candidates = dae_collect_broad_uniform_candidate_defs(candidate_source)
  dae_boundary_syntax_frozen_run_exact_literal_candidate_worklist_with_facts(
    current, touched, changed, candidates,
  )
}

///|
fn dae_boundary_syntax_frozen_run_direct_gc_result_refinement_dependency_closure(
  current : @lib.Module,
  touched : Array[Bool],
  changed : Bool,
  seed_defs : Array[Int32],
) -> DaeExactLiteralWorklistApplication {
  let defined = dae_boundary_syntax_frozen_defined_func_count(current)
  let productive_defs : Array[Int32] = []
  let mut effects = dae_commit_effects_empty(defined)
  let mut mod_out = current
  let mut touched_out = touched
  let mut changed_out = changed
  if !dae_candidate_worklist_requires_facts(seed_defs) {
    return { mod_out: current, touched, changed, productive_defs, effects, }
  }
  let original = dae_boundary_syntax_frozen_collect_original_boundary_snapshot(
    current,
  )
  let graph = dae_current_boundary_graph_new(current)
  let mut dependencies = dae_boundary_dependency_graph_new(graph)
  let queue : Array[Int32] = []
  let queued = Array::make(defined, false)
  for seed_def in seed_defs {
    dae_append_result_dependency_postorder(
      dependencies, seed_def, queued, queue,
    )
  }
  let seen = Array::make(defined, false)
  let diagnostics = dae_diagnostics_new()
  let mut queue_idx = 0
  while queue_idx < queue.length() {
    let def_idx = queue[queue_idx]
    queue_idx += 1
    if def_idx < 0 || def_idx >= defined || seen[def_idx] {
      continue
    }
    seen[def_idx] = true
    let before_forwarders = if def_idx <
      dependencies.result_forwarders_by_def.length() {
      dependencies.result_forwarders_by_def[def_idx].copy()
    } else {
      []
    }
    let item = dae_work_item_new(
      graph,
      dependencies,
      def_idx,
      DaeGcResultRefinementWork,
    )
    match
      dae_boundary_syntax_frozen_process_work_item(
        original, mod_out, touched_out, changed_out, graph, dependencies, item, diagnostics,
      ) {
      DaeWorkCommitted(application) => {
        let settled = dae_boundary_syntax_frozen_apply_commit_followups(
          original, application, item, diagnostics,
        )
        mod_out = settled.mod_out
        touched_out = settled.touched
        changed_out = settled.changed
        productive_defs.push(settled.primary_def)
        effects = dae_commit_effects_merge(effects, settled.effects)
        dae_current_boundary_graph_refresh(graph, mod_out)
        dependencies = dae_boundary_dependency_graph_new(graph)
        let forwarders = before_forwarders
        if def_idx < dependencies.result_forwarders_by_def.length() {
          for forwarder_def in dependencies.result_forwarders_by_def[def_idx] {
            if !forwarders.contains(forwarder_def) {
              forwarders.push(forwarder_def)
            }
          }
        }
        for forwarder_def in forwarders {
          if forwarder_def >= 0 &&
            forwarder_def < defined &&
            !seen[forwarder_def] {
            queue.push(forwarder_def)
          }
        }
      }
      _ => ()
    }
  }
  {
    mod_out,
    touched: touched_out,
    changed: changed_out,
    productive_defs,
    effects,
  }
}

///|
fn dae_boundary_syntax_frozen_apply_dead_suffix_self_operand_restore_transaction(
  original_source : @lib.Module,
  current : @lib.Module,
  touched : Array[Bool],
  changed : Bool,
  candidate_defs~ : Array[Bool]? = None,
) -> DaeCoreResultApplication {
  let candidate = dae_restore_dead_suffix_self_operand_params(
    original_source,
    current,
    candidate_defs~,
  )
  if !candidate.changed {
    return {
      mod_out: current,
      touched,
      changed,
      applied: false,
      primary_def: -1,
      effects: dae_commit_effects_empty(
        dae_boundary_syntax_frozen_defined_func_count(current),
      ),
    }
  }
  let original = dae_boundary_syntax_frozen_collect_original_boundary_snapshot(
    original_source,
  )
  let graph = dae_current_boundary_graph_new(current)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let mut producer_effects = dae_commit_effects_empty(graph.snapshot.defined)
  let mut def_idx = 0
  while def_idx < candidate.touched.length() {
    if candidate.touched[def_idx] {
      producer_effects = dae_commit_effects_merge(
        producer_effects,
        dae_work_item_candidate_effects(
          current,
          graph,
          dae_work_item_new(
            graph,
            dependencies,
            def_idx,
            DaeUnusedParameterWork,
          ),
          candidate,
        ),
      )
    }
    def_idx += 1
  }
  let mut target_def = -1
  def_idx = 0
  while def_idx < candidate.touched.length() {
    if candidate.touched[def_idx] {
      target_def = def_idx
      break
    }
    def_idx += 1
  }
  match
    dae_process_precomputed_signature_work_item(
      original,
      current,
      touched,
      changed,
      graph,
      dae_work_item_new(graph, dependencies, target_def, DaeUnusedParameterWork),
      candidate,
      producer_effects,
      allow_signature_restoration=true,
    ) {
    DaeWorkCommitted(application) => application
    DaeWorkNoChange(_) | DaeWorkDeferred(_) | DaeWorkRequeue(_) =>
      {
        mod_out: current,
        touched,
        changed,
        applied: false,
        primary_def: -1,
        effects: dae_commit_effects_empty(graph.snapshot.defined),
      }
  }
}

///|
fn dae_boundary_syntax_frozen_run_computed_unread_param_dependency_worklist(
  original : DaeOriginalBoundarySnapshot,
  current_in : @lib.Module,
  touched_in : Array[Bool],
  changed_in : Bool,
  require_localization_retry : Bool,
  trace : (String) -> Unit,
) -> DaeCoreResultApplication {
  let mut current = current_in
  let mut touched = touched_in
  let mut changed = changed_in
  let graph = dae_current_boundary_graph_new(current)
  let family = if require_localization_retry {
    DaeLocalizationRetryWork
  } else {
    DaeUnusedParameterWork
  }
  let mut dependencies = dae_boundary_dependency_graph_new(graph)
  let worklist = dae_boundary_worklist_families(graph, dependencies, [family])
  let diagnostics = dae_diagnostics_new()
  let mut iteration = 0
  let mut applied = false
  let mut effects = dae_commit_effects_empty(
    dae_boundary_syntax_frozen_defined_func_count(current),
  )
  while true {
    let item = match dae_boundary_worklist_take_item(worklist) {
      Some(value) => value
      None => break
    }
    let before_dependencies = dependencies
    match
      dae_boundary_syntax_frozen_process_work_item(
        original, current, touched, changed, graph, dependencies, item, diagnostics,
      ) {
      DaeWorkRequeue(items) =>
        diagnostics.candidate_requeues += dae_boundary_worklist_requeue_items(
          worklist, items,
        )
      DaeWorkCommitted(application) => {
        dae_current_boundary_graph_refresh(graph, application.mod_out)
        let after_dependencies = dae_boundary_dependency_graph_new(graph)
        let invalidated = dae_boundary_dependency_invalidations(
          before_dependencies,
          after_dependencies,
          application.effects.structurally_touched,
          application.primary_def,
          application.effects,
        )
        dependencies = after_dependencies
        current = application.mod_out
        touched = application.touched
        changed = application.changed
        applied = true
        effects = dae_commit_effects_merge(effects, application.effects)
        let requeued = dae_work_items_for_defs(
          graph, dependencies, invalidated, family,
        )
        diagnostics.candidate_requeues += dae_boundary_worklist_requeue_items(
          worklist, requeued,
        )
        trace(
          "pass[dae-optimizing]:computed-unread-param iter=\{iteration} component=\{item.component_id} family=\{dae_work_family_slot(item.family)} primary_def=\{application.primary_def}",
        )
        iteration += 1
      }
      DaeWorkNoChange(_) | DaeWorkDeferred(_) => ()
    }
  }
  { mod_out: current, touched, changed, applied, primary_def: -1, effects, }
}

///|
fn dae_boundary_syntax_frozen_run_core(
  mod_ : @lib.Module,
  trace : (String) -> Unit,
  optimize~ : Bool = false,
  perf~ : HotPerfSession? = None,
  single_caller_throttle_consumed~ : Bool = false,
  traps_never_happen~ : Bool = false,
  results_only~ : Bool = false,
  no_callback_trace~ : DaeNoCallbackTrace? = None,
  scalar_validation_work~ : DaeScalarValidationWork? = None,
  numeric_result_validation_work~ : DaeScalarValidationWork? = None,
) -> DaeCoreRunResult {
  let no_callback_trace = match no_callback_trace {
    Some(proof) if perf is None && physical_equal(trace, proof.callback) =>
      Some(proof)
    _ => None
  }
  let mut current = mod_
  let mut touched : Array[Bool] = []
  let mut changed = false
  let setup_start_us = perf_start_timer_opt(perf, "detail:dae:core:setup")
  let original_boundary_snapshot = dae_boundary_syntax_frozen_collect_original_boundary_snapshot(
    mod_,
  )
  let original_imported = original_boundary_snapshot.imported
  let original_defined = original_boundary_snapshot.defined
  let mut effects = dae_commit_effects_empty(original_defined)
  let diagnostics = dae_diagnostics_new()
  let original_total = original_boundary_snapshot.total
  let original_param_counts = original_boundary_snapshot.param_counts
  let original_call_summary = original_boundary_snapshot.call_summary
  let original_call_counts = original_call_summary.call_counts
  let original_active_nonself_call_counts = original_call_summary.active_nonself_call_counts
  let original_active_parameterized_nonself_call_counts = original_call_summary.active_parameterized_nonself_call_counts
  let original_nonself_undropped_call_counts = original_call_summary.nonself_undropped_call_counts
  let original_self_call_counts = original_call_summary.self_call_counts
  let original_dead_suffix_escaped_result_call_facts = original_boundary_snapshot.dead_suffix_escaped_result_call_facts
  let original_escaped_result_operand_call_facts = original_boundary_snapshot.escaped_result_operand_call_facts
  let original_dead_suffix_escaped_result_operand_call_counts = original_escaped_result_operand_call_facts.dead_suffix_escaped_result_operand_call_counts
  let original_private_result_dead_suffix_calls_from_escaped_operand_callees = original_boundary_snapshot.private_result_dead_suffix_calls_from_escaped_operand_callees
  let original_escaped_dead_suffix_call_counts = original_boundary_snapshot.escaped_dead_suffix_call_counts
  let original_dead_suffix_undropped_self_calls = original_boundary_snapshot.dead_suffix_undropped_self_calls
  let original_dead_suffix_dropped_self_calls = original_boundary_snapshot.dead_suffix_dropped_self_calls
  let original_dead_suffix_block_undropped_self_calls = original_boundary_snapshot.dead_suffix_block_undropped_self_calls
  let original_dead_suffix_result_calls_from_undropped_self_callers = original_boundary_snapshot.dead_suffix_result_calls_from_undropped_self_callers
  let original_dead_suffix_result_calls_from_no_param_undropped_self_callers = original_boundary_snapshot.dead_suffix_result_calls_from_no_param_undropped_self_callers
  let original_dead_suffix_dropped_calls_from_parameterized_self_callers = original_boundary_snapshot.dead_suffix_dropped_calls_from_parameterized_self_callers
  let original_dead_suffix_same_self_result_operand_calls = original_boundary_snapshot.dead_suffix_same_self_result_operand_calls
  let original_dead_suffix_undropped_self_call_param_operands = original_boundary_snapshot.dead_suffix_undropped_self_call_param_operands
  let original_dead_suffix_result_other_calls = original_boundary_snapshot.dead_suffix_result_other_calls
  let original_dead_suffix_mutual_calls = original_boundary_snapshot.dead_suffix_mutual_calls
  let original_dead_suffix_calls_from_param_operand_self_result_callers = original_boundary_snapshot.dead_suffix_calls_from_param_operand_self_result_callers
  perf_stop_timer_opt(perf, "detail:dae:core:setup", setup_start_us)
  let mut dropped_result_post_graph : DaeCurrentBoundaryGraph? = None
  if !optimize && original_defined >= 1024 {
    let mut dropped_result_batch_wave = 0
    while true {
      let application = dae_apply_dropped_result_batch_transaction(
        original_boundary_snapshot,
        current,
        touched,
        changed,
        retain_post_graph=true,
      )
      if !application.applied {
        break
      }
      current = application.mod_out
      touched = application.touched
      changed = application.changed
      dropped_result_post_graph = application.post_graph
      effects = dae_commit_effects_merge(effects, application.effects)
      dae_diagnostics_record_commit_effects(diagnostics, application.effects)
      dae_diagnostics_record_applied_effects(diagnostics, application.effects)
      trace(
        "pass[dae]:dropped-result-batch wave=\{dropped_result_batch_wave} first_def=\{application.primary_def}",
      )
      dropped_result_batch_wave += 1
    }
  }
  if optimize {
    let unread_batch_start_us = perf_start_timer_opt(
      perf, "detail:dae:core:unread-param-batch",
    )
    let mut unread_batch_wave = 0
    if original_defined >= 1024 && !single_caller_throttle_consumed {
      while true {
        let application = dae_apply_unread_param_batch_transaction(
          original_boundary_snapshot, current, touched, changed,
        )
        if !application.applied {
          break
        }
        current = application.mod_out
        touched = application.touched
        changed = application.changed
        effects = dae_commit_effects_merge(effects, application.effects)
        dae_diagnostics_record_commit_effects(diagnostics, application.effects)
        dae_diagnostics_record_applied_effects(diagnostics, application.effects)
        trace(
          "pass[dae-optimizing]:unread-param-batch wave=\{unread_batch_wave} first_def=\{application.primary_def}",
        )
        unread_batch_wave += 1
      }
    } else if single_caller_throttle_consumed {
      trace(
        "pass[dae-optimizing]:unread-param-batch skip=single-caller-throttle-consumed",
      )
    } else {
      trace(
        "pass[dae-optimizing]:unread-param-batch skip=small-module-acceleration optional=true defined=\{original_defined}",
      )
    }
    perf_stop_timer_opt(
      perf, "detail:dae:core:unread-param-batch", unread_batch_start_us,
    )
    let dropped_result_batch_start_us = perf_start_timer_opt(
      perf, "detail:dae:core:dropped-result-batch",
    )
    let mut dropped_result_batch_wave = 0
    if original_defined >= 1024 {
      while true {
        let application = dae_apply_dropped_result_batch_transaction(
          original_boundary_snapshot, current, touched, changed,
        )
        if !application.applied {
          break
        }
        current = application.mod_out
        touched = application.touched
        changed = application.changed
        effects = dae_commit_effects_merge(effects, application.effects)
        dae_diagnostics_record_commit_effects(diagnostics, application.effects)
        dae_diagnostics_record_applied_effects(diagnostics, application.effects)
        trace(
          "pass[dae-optimizing]:dropped-result-batch wave=\{dropped_result_batch_wave} first_def=\{application.primary_def}",
        )
        dropped_result_batch_wave += 1
      }
    } else {
      trace(
        "pass[dae-optimizing]:dropped-result-batch skip=small-module-acceleration optional=true defined=\{original_defined}",
      )
    }
    perf_stop_timer_opt(
      perf, "detail:dae:core:dropped-result-batch", dropped_result_batch_start_us,
    )
    let direct_gc_batch_start_us = perf_start_timer_opt(
      perf, "detail:dae:core:direct-gc-batch",
    )
    let mut direct_gc_batch_wave = 0
    let mut direct_gc_active_defs : Array[Bool]? = None
    while true {
      let application = dae_apply_direct_gc_batch_transaction(
        original_boundary_snapshot,
        current,
        touched,
        changed,
        active_defs=direct_gc_active_defs,
      )
      let batch_touched = application.effects.structurally_touched
      if !application.applied {
        break
      }
      current = application.mod_out
      touched = application.touched
      changed = application.changed
      effects = dae_commit_effects_merge(effects, application.effects)
      dae_diagnostics_record_commit_effects(diagnostics, application.effects)
      dae_diagnostics_record_applied_effects(diagnostics, application.effects)
      trace(
        "pass[dae-optimizing]:direct-gc-batch wave=\{direct_gc_batch_wave} first_def=\{application.primary_def}",
      )
      let next_active = Array::make(original_defined, false)
      let current_call_facts = dae_collect_current_call_facts(
        current, original_total,
      )
      match current.code_sec {
        Some(@lib.CodeSec(funcs)) => {
          let mut changed_def = 0
          while changed_def < batch_touched.length() &&
                changed_def < funcs.length() {
            if batch_touched[changed_def] {
              next_active[changed_def] = true
              let changed_abs = original_imported + changed_def
              if changed_abs >= 0 &&
                changed_abs < current_call_facts.direct_callers.length() {
                for caller_def in current_call_facts.direct_callers[changed_abs] {
                  if caller_def >= 0 && caller_def < next_active.length() {
                    next_active[caller_def] = true
                  }
                }
              }
              let @lib.Func(_, @lib.Expr(body)) = funcs[changed_def]
              let outgoing : Array[Int32] = []
              dae_collect_direct_call_targets_anywhere(
                body, original_imported, original_defined, outgoing,
              )
              for callee_def in outgoing {
                if callee_def >= 0 && callee_def < next_active.length() {
                  next_active[callee_def] = true
                }
              }
            }
            changed_def += 1
          }
        }
        None => ()
      }
      direct_gc_active_defs = Some(next_active)
      direct_gc_batch_wave += 1
    }
    perf_stop_timer_opt(
      perf, "detail:dae:core:direct-gc-batch", direct_gc_batch_start_us,
    )
  }
  let current_boundary_graph = match dropped_result_post_graph {
    Some(graph) => graph
    None => dae_current_boundary_graph_new(current)
  }
  let fixed_loop_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:fixed-loop",
  )
  let scalar_validation_chain = match
    (no_callback_trace, scalar_validation_work, numeric_result_validation_work) {
    (None, None, None) => None
    _ => Some(dae_scalar_validation_chain_new(trace, perf, no_callback_trace))
  }
  let mut iter = 0
  // Boundary availability is monotonic under the core's signature/result
  // reductions, but it is not definition-order local: rewriting one boundary
  // can expose work in its callers, callees, or itself. Seed every definition
  // once, then requeue only the dependency neighborhood invalidated by a
  // committed transaction. Queue membership prevents duplicate pending work;
  // termination follows from an empty queue rather than an iteration budget.
  let no_already_rewritten_defs : Array[Bool] = []
  let core_worklist = dae_boundary_worklist_all(original_defined)
  let mut current_dependencies = dae_boundary_dependency_graph_empty()
  let mut scalar_plan_code_snapshot_current = dae_scalar_plan_code_snapshot_is_current(
    current, current_boundary_graph,
  )
  let mut has_current_dropped_result_candidate = dae_current_graph_has_dropped_result_candidate(
    original_boundary_snapshot, current_boundary_graph,
  )
  let mut current_call_counts_anywhere = match current.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      dae_collect_module_call_counts_anywhere(
        funcs, original_imported, original_defined,
      )
    None => Array::make(original_defined, 0)
  }
  let mut unprofitable_removal_iters = if single_caller_throttle_consumed {
    1
  } else {
    0
  }
  while core_worklist.cursor < core_worklist.queue.length() {
    // Keep Binaryen's one-wave profitability boundary while making discovery
    // dependency-driven: work enqueued by this frontier is processed in the
    // next frontier, after the source-backed single-caller stop is classified.
    let wave_end = core_worklist.queue.length()
    let mut wave_param_removals = 0
    let mut wave_single_caller_param_removals = 0
    while core_worklist.cursor < wave_end {
      let def_idx = match dae_boundary_worklist_take(core_worklist) {
        Some(value) => value
        None => break
      }
      diagnostics.boundaries_analyzed += 1
      // A fresh frontier is usually a contiguous definition range. Analyze that
      // range with one core setup instead of rebuilding the same boundary
      // contexts once per definition. Stop at the first committed candidate;
      // dependency invalidation can then requeue any earlier definitions whose
      // facts changed.
      let mut batch_end_exclusive = def_idx + 1
      let mut batch_queue_end = core_worklist.cursor
      while batch_queue_end < wave_end &&
            core_worklist.queue[batch_queue_end] == batch_end_exclusive {
        batch_end_exclusive += 1
        batch_queue_end += 1
      }
      let before_call_facts = current_boundary_graph.snapshot.call_facts
      let call_epoch = current_boundary_graph.call_epoch
      let boundary_facts = current_boundary_graph.snapshot.boundary_facts
      let producer_effects_report : Array[DaeCommitEffects] = []
      let committed_application_report : Array[DaeCoreResultApplication] = []
      let checked_candidate_report : Array[(@lib.Module, @lib.Module)]? = match
        no_callback_trace {
        Some(_) => Some([])
        None => None
      }
      let result = dae_boundary_syntax_frozen_run_core_once(
        current,
        no_already_rewritten_defs,
        current_call_counts_anywhere,
        optimize,
        unprofitable_removal_iters > 0,
        original_boundary_snapshot,
        current_boundary_graph,
        expected_call_epoch=call_epoch,
        max_def_exclusive=batch_end_exclusive,
        start_def_inclusive=def_idx,
        boundary_facts_override=Some(boundary_facts),
        dependencies=Some(current_dependencies),
        producer_effects_report~,
        committed_application_report~,
        checked_candidate_report~,
        scalar_validation_chain~,
        scalar_validation_work~,
        numeric_result_validation_work~,
        scalar_plan_code_snapshot_current~,
        has_current_dropped_result_candidate~,
        traps_never_happen~,
      )
      dae_scalar_validation_retain_exact(
        scalar_validation_chain,
        result.mod_out,
      )
      if !committed_application_report.is_empty() {
        dae_numeric_result_validation_retain_report(
          scalar_validation_chain,
          result,
          committed_application_report[0],
        )
      }
      let consumed_end_exclusive = if result.changed &&
        result.primary_def >= def_idx &&
        result.primary_def < batch_end_exclusive {
        result.primary_def + 1
      } else {
        batch_end_exclusive
      }
      while core_worklist.cursor < batch_queue_end &&
            core_worklist.queue[core_worklist.cursor] < consumed_end_exclusive {
        ignore(dae_boundary_worklist_take(core_worklist))
        diagnostics.boundaries_analyzed += 1
      }
      let scanned = consumed_end_exclusive - def_idx
      if scanned > 1 {
        trace(
          "pass[dae]:core-worklist-batch start=\{def_idx} primary_def=\{result.primary_def} scanned=\{scanned}",
        )
        for _i = 1; _i < scanned; _i = _i + 1 {
          dae_diagnostics_record_reason(diagnostics, DaeNoStrictImprovement)
        }
      }
      let before_primary_param_count = if result.primary_def >= 0 {
        let before_type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(
          current,
        )
        match
          dae_boundary_syntax_frozen_resolve_func_type(
            current,
            before_type_indices,
            original_imported + result.primary_def,
          ) {
          Some(@lib.FuncType(params, _)) => params.length()
          None => -1
        }
      } else {
        -1
      }
      if !result.changed {
        dae_diagnostics_record_reason(diagnostics, DaeNoStrictImprovement)
        continue
      }
      let producer_effects = match producer_effects_report.get(0) {
        Some(value) => value
        None => {
          dae_diagnostics_record_reason(diagnostics, DaeNoStrictImprovement)
          continue
        }
      }
      let family = dae_work_family_for_commit_effects(
        producer_effects,
        result.primary_def,
      )
      let item = dae_work_item_new(
        current_boundary_graph,
        current_dependencies,
        result.primary_def,
        family,
      )
      let application = match committed_application_report.get(0) {
        Some(application) => application
        None => {
          let outcome = match checked_candidate_report {
            Some(report) =>
              dae_process_core_precomputed_signature_with_report(
                original_boundary_snapshot, current, touched, changed, current_boundary_graph,
                item, result, producer_effects, trace, no_callback_trace, report,
              )
            None =>
              dae_process_precomputed_signature_work_item(
                original_boundary_snapshot, current, touched, changed, current_boundary_graph,
                item, result, producer_effects,
              )
          }
          match outcome {
            DaeWorkCommitted(value) => value
            DaeWorkNoChange(_) | DaeWorkDeferred(_) | DaeWorkRequeue(_) => {
              dae_scalar_validation_barrier_opt(scalar_validation_chain)
              dae_diagnostics_record_reason(diagnostics, DaeNoStrictImprovement)
              continue
            }
          }
        }
      }
      dae_scalar_validation_retain_exact(
        scalar_validation_chain,
        application.mod_out,
      )
      dae_diagnostics_record_commit_effects(diagnostics, application.effects)
      dae_diagnostics_record_applied_effects(diagnostics, application.effects)
      if application.primary_def >= 0 && before_primary_param_count >= 0 {
        let after_type_indices = dae_boundary_syntax_frozen_collect_func_type_indices(
          application.mod_out,
        )
        let after_param_count = match
          dae_boundary_syntax_frozen_resolve_func_type(
            application.mod_out,
            after_type_indices,
            original_imported + application.primary_def,
          ) {
          Some(@lib.FuncType(params, _)) => params.length()
          None => before_primary_param_count
        }
        if after_param_count < before_primary_param_count {
          wave_param_removals += 1
          let callee_abs = original_imported + application.primary_def
          if callee_abs >= 0 &&
            callee_abs < before_call_facts.direct_calls.length() &&
            before_call_facts.direct_calls[callee_abs] == 1 {
            wave_single_caller_param_removals += 1
          }
        }
      }
      let before_dependencies = dae_boundary_dependency_graph_new(
        current_boundary_graph,
      )
      dae_current_boundary_graph_refresh(
        current_boundary_graph,
        application.mod_out,
        forced_changed_defs=Some(application.effects.structurally_touched),
      )
      scalar_plan_code_snapshot_current = dae_scalar_plan_code_snapshot_is_current(
        application.mod_out,
        current_boundary_graph,
      )
      has_current_dropped_result_candidate = dae_current_graph_has_dropped_result_candidate(
        original_boundary_snapshot, current_boundary_graph,
      )
      let after_dependencies = dae_boundary_dependency_graph_new(
        current_boundary_graph,
      )
      let invalidated = dae_boundary_dependency_invalidations(
        before_dependencies,
        after_dependencies,
        application.touched,
        application.primary_def,
        application.effects,
      )
      current_dependencies = after_dependencies
      current = application.mod_out
      touched = application.touched
      changed = application.changed
      effects = dae_commit_effects_merge(effects, application.effects)
      current_call_counts_anywhere = match current.code_sec {
        Some(@lib.CodeSec(funcs)) =>
          dae_collect_module_call_counts_anywhere(
            funcs, original_imported, original_defined,
          )
        None => Array::make(original_defined, 0)
      }
      diagnostics.candidate_requeues += dae_boundary_worklist_requeue(
        core_worklist, invalidated,
      )
      trace(
        "pass[dae-optimizing]:core-worklist iter=\{iter} primary_def=\{application.primary_def}",
      )
      iter += 1
    }
    let unprofitable_param_wave = wave_param_removals == 1 &&
      wave_single_caller_param_removals == 1
    if unprofitable_param_wave && unprofitable_removal_iters == 0 {
      unprofitable_removal_iters += 1
      trace(
        "pass[dae-optimizing]:core-worklist skip=further-param-removal unprofitable_iters=\{unprofitable_removal_iters} removals=1 single_callers=1",
      )
    }
  }
  dae_scalar_validation_barrier_opt(scalar_validation_chain)
  perf_stop_timer_opt(perf, "detail:dae:core:fixed-loop", fixed_loop_start_us)
  if results_only {
    trace("pass[dae]:results-only-fallback stop=after-core-worklist")
    return {
      mod_out: current,
      touched: if changed {
        touched
      } else {
        []
      },
      changed,
      primary_def: -1,
      effects,
      diagnostics,
      single_caller_throttle_consumed: unprofitable_removal_iters > 0,
    }
  }
  let mut current_boundary_graph_stale = false
  if dae_should_run_computed_unread_dependency_worklist(
      original_defined,
      optimize~,
    ) {
    let computed_application = dae_boundary_syntax_frozen_run_computed_unread_param_dependency_worklist(
      original_boundary_snapshot,
      current,
      touched,
      changed,
      unprofitable_removal_iters > 0,
      trace,
    )
    current = computed_application.mod_out
    if computed_application.effects.candidates_applied > 0 {
      current_boundary_graph_stale = true
    }
    touched = computed_application.touched
    changed = computed_application.changed
    effects = dae_commit_effects_merge(effects, computed_application.effects)
  }
  let selected_lanes_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:selected-lanes",
  )
  let reverse_exact_literal_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:selected-lanes:reverse-exact-literal",
  )
  let restored_application = dae_boundary_syntax_frozen_apply_dead_suffix_self_operand_restore_transaction(
    mod_,
    current,
    touched,
    changed,
    candidate_defs=if touched.length() == original_defined {
      Some(touched)
    } else {
      None
    },
  )
  if restored_application.applied {
    current = restored_application.mod_out
    current_boundary_graph_stale = true
    touched = restored_application.touched
    changed = restored_application.changed
    effects = dae_commit_effects_merge(effects, restored_application.effects)
  }
  // Reuse one selected-def singleton scratch across the artifact-specific lanes
  // that set at most one bit at a time. Each call clears the bit immediately
  // after use, so later lanes observe the same all-false starting state they had
  // with separate freshly allocated bitmaps.
  let selected_scratch_defs = Array::make(original_defined, false)
  let mut reverse_iter = 0
  if dae_should_run_broad_uniform_parameter_flow(original_defined, optimize~) {
    let broad_uniform = dae_boundary_syntax_frozen_run_broad_uniform_parameter_flow(
      current, mod_, touched, changed,
    )
    current = broad_uniform.mod_out
    if broad_uniform.productive_defs.length() > 0 {
      current_boundary_graph_stale = true
    }
    touched = broad_uniform.touched
    changed = broad_uniform.changed
    effects = dae_commit_effects_merge(effects, broad_uniform.effects)
    for primary_def in broad_uniform.productive_defs {
      trace("pass[dae]:broad-exact-uniform primary_def=\{primary_def}")
    }
  }
  if dae_should_run_reverse_exact_literal_phase(original_defined, optimize~) {
    while true {
      let reverse_graph = dae_current_boundary_graph_new(current)
      let reverse_result = dae_boundary_syntax_frozen_try_rewrite_reverse_exact_literal_once(
        current,
        original_param_counts,
        original_call_counts,
        original_active_nonself_call_counts,
        original_active_parameterized_nonself_call_counts,
        original_nonself_undropped_call_counts,
        original_self_call_counts,
        original_private_result_dead_suffix_calls_from_escaped_operand_callees,
        original_escaped_dead_suffix_call_counts,
        original_dead_suffix_undropped_self_calls,
        original_dead_suffix_dropped_self_calls,
        original_dead_suffix_block_undropped_self_calls,
        original_dead_suffix_result_calls_from_undropped_self_callers,
        original_dead_suffix_result_calls_from_no_param_undropped_self_callers,
        original_dead_suffix_same_self_result_operand_calls,
        original_dead_suffix_undropped_self_call_param_operands,
        original_dead_suffix_result_other_calls,
        original_dead_suffix_escaped_result_call_facts,
        original_dead_suffix_mutual_calls,
        original_dead_suffix_calls_from_param_operand_self_result_callers,
        original_dead_suffix_escaped_result_operand_call_counts,
        original_dead_suffix_dropped_calls_from_parameterized_self_callers,
        supplied_graph=Some(reverse_graph),
      )
      if !reverse_result.changed || reverse_result.primary_def < 0 {
        break
      }
      let reverse_effects = if reverse_result.changed &&
        reverse_result.primary_def >= 0 {
        Some(
          dae_work_item_candidate_effects(
            current,
            reverse_graph,
            dae_work_item_new(
              reverse_graph,
              dae_boundary_dependency_graph_new(reverse_graph),
              reverse_result.primary_def,
              DaeUniformActualWork,
            ),
            reverse_result,
          ),
        )
      } else {
        None
      }
      let reverse_application = match reverse_effects {
        Some(producer_effects) =>
          match
            dae_process_precomputed_signature_work_item(
              original_boundary_snapshot,
              current,
              touched,
              changed,
              reverse_graph,
              dae_work_item_new(
                reverse_graph,
                dae_boundary_dependency_graph_new(reverse_graph),
                reverse_result.primary_def,
                DaeUniformActualWork,
              ),
              reverse_result,
              producer_effects,
            ) {
            DaeWorkCommitted(value) => value
            _ => break
          }
        None => break
      }
      current = reverse_application.mod_out
      current_boundary_graph_stale = true
      touched = reverse_application.touched
      changed = reverse_application.changed
      effects = dae_commit_effects_merge(effects, reverse_application.effects)
      trace(
        "pass[dae-optimizing]:reverse-exact-literal iter=\{reverse_iter} primary_def=\{reverse_application.primary_def}",
      )
      reverse_iter += 1
    }
  }
  // Phase-local profitability replay uses semantic candidate evidence rather
  // than a module-size admission threshold. Each wave still commits at most one
  // validated candidate, preserving the existing source-order frontier.
  let mut low_revisit_iter = 0
  while dae_should_run_forwarded_constant_revisit(original_defined, optimize~) {
    let low_revisit_graph = dae_current_boundary_graph_new(current)
    let low_revisit_result = dae_boundary_syntax_frozen_try_rewrite_reverse_exact_literal_once(
      current,
      original_param_counts,
      original_call_counts,
      original_active_nonself_call_counts,
      original_active_parameterized_nonself_call_counts,
      original_nonself_undropped_call_counts,
      original_self_call_counts,
      original_private_result_dead_suffix_calls_from_escaped_operand_callees,
      original_escaped_dead_suffix_call_counts,
      original_dead_suffix_undropped_self_calls,
      original_dead_suffix_dropped_self_calls,
      original_dead_suffix_block_undropped_self_calls,
      original_dead_suffix_result_calls_from_undropped_self_callers,
      original_dead_suffix_result_calls_from_no_param_undropped_self_callers,
      original_dead_suffix_same_self_result_operand_calls,
      original_dead_suffix_undropped_self_call_param_operands,
      original_dead_suffix_result_other_calls,
      original_dead_suffix_escaped_result_call_facts,
      original_dead_suffix_mutual_calls,
      original_dead_suffix_calls_from_param_operand_self_result_callers,
      original_dead_suffix_escaped_result_operand_call_counts,
      original_dead_suffix_dropped_calls_from_parameterized_self_callers,
      supplied_graph=Some(low_revisit_graph),
      reverse=false,
      max_def_exclusive=original_defined,
    )
    if !low_revisit_result.changed || low_revisit_result.primary_def < 0 {
      break
    }
    let low_revisit_effects = if low_revisit_result.changed &&
      low_revisit_result.primary_def >= 0 {
      Some(
        dae_work_item_candidate_effects(
          current,
          low_revisit_graph,
          dae_work_item_new(
            low_revisit_graph,
            dae_boundary_dependency_graph_new(low_revisit_graph),
            low_revisit_result.primary_def,
            DaeUniformActualWork,
          ),
          low_revisit_result,
        ),
      )
    } else {
      None
    }
    let low_revisit_application = match low_revisit_effects {
      Some(producer_effects) =>
        match
          dae_process_precomputed_signature_work_item(
            original_boundary_snapshot,
            current,
            touched,
            changed,
            low_revisit_graph,
            dae_work_item_new(
              low_revisit_graph,
              dae_boundary_dependency_graph_new(low_revisit_graph),
              low_revisit_result.primary_def,
              DaeUniformActualWork,
            ),
            low_revisit_result,
            producer_effects,
          ) {
          DaeWorkCommitted(value) => value
          _ => break
        }
      None => break
    }
    current = low_revisit_application.mod_out
    current_boundary_graph_stale = true
    touched = low_revisit_application.touched
    changed = low_revisit_application.changed
    effects = dae_commit_effects_merge(effects, low_revisit_application.effects)
    trace(
      "pass[dae-optimizing]:low-forwarded-const-revisit iter=\{low_revisit_iter} primary_def=\{low_revisit_application.primary_def}",
    )
    low_revisit_iter += 1
  }
  // Exact type/call-fact admission is independent of parameter count and shape.
  // Run it after the ordinary reverse phase so it cannot preempt that proof.
  // Modules can contain profitable exact/default candidates that the fixed
  // eight-iteration core never reaches. Build the ordered worklist
  // once from one current caller-fact snapshot, then revalidate and apply each
  // candidate against the evolving module. Signature and operand rewrites do
  // not change direct-call edges, so the snapshot remains valid for this batch.
  let low_exact_literal_candidates = if dae_should_collect_low_exact_literal_candidates(
      optimize,
      restored_application.applied,
      scalar_plan_code_snapshot_current,
    ) {
    let low_exact_literal_call_facts = dae_collect_current_call_facts(
      current, original_total,
    )
    dae_collect_post_revisit_exact_literal_candidates(
      current, low_exact_literal_call_facts, original_defined,
    )
  } else {
    []
  }
  let low_exact_literal_application = if !optimize &&
    !restored_application.applied {
    dae_boundary_syntax_frozen_run_exact_literal_candidate_worklist_with_facts(
      current,
      touched,
      changed,
      low_exact_literal_candidates,
      original=if low_exact_literal_candidates.is_empty() {
        None
      } else {
        Some(
          dae_boundary_syntax_frozen_collect_original_boundary_snapshot(current),
        )
      },
      graph=Some(current_boundary_graph),
      dependencies=Some(current_dependencies),
    )
  } else {
    dae_boundary_syntax_frozen_run_exact_literal_candidate_worklist_with_facts(
      current, touched, changed, low_exact_literal_candidates,
    )
  }
  current = low_exact_literal_application.mod_out
  if low_exact_literal_application.productive_defs.length() > 0 {
    current_boundary_graph_stale = true
  }
  touched = low_exact_literal_application.touched
  changed = low_exact_literal_application.changed
  effects = dae_commit_effects_merge(
    effects,
    low_exact_literal_application.effects,
  )
  for iter, primary_def in low_exact_literal_application.productive_defs {
    trace(
      "pass[dae-optimizing]:low-exact-literal-worklist iter=\{iter} primary_def=\{primary_def}",
    )
  }
  let low_exact_cleanup_defs = Array::make(original_defined, false)
  for productive_def in low_exact_literal_application.productive_defs {
    if productive_def >= 0 && productive_def < low_exact_cleanup_defs.length() {
      low_exact_cleanup_defs[productive_def] = true
    }
  }
  let low_exact_null_if_cleanup = dae_try_fold_selected_ref_null_is_null_ifs_once(
    current, low_exact_cleanup_defs,
  )
  let low_exact_null_if_application = dae_apply_body_only_family_result_transaction(
    original_boundary_snapshot, current, touched, changed, low_exact_null_if_cleanup,
    diagnostics,
  )
  if low_exact_null_if_application.applied {
    current = low_exact_null_if_application.mod_out
    current_boundary_graph_stale = true
    touched = low_exact_null_if_application.touched
    changed = low_exact_null_if_application.changed
    effects = dae_commit_effects_merge(
      effects,
      low_exact_null_if_application.effects,
    )
    trace(
      "pass[dae-optimizing]:low-exact-null-if-cleanup primary_def=\{low_exact_null_if_application.primary_def}",
    )
  }
  let low_exact_terminal_locals = dae_try_inline_selected_terminal_call_local_sets_once(
    current, low_exact_cleanup_defs,
  )
  let low_exact_terminal_application = dae_apply_body_only_family_result_transaction(
    original_boundary_snapshot, current, touched, changed, low_exact_terminal_locals,
    diagnostics,
  )
  if low_exact_terminal_application.applied {
    current = low_exact_terminal_application.mod_out
    current_boundary_graph_stale = true
    touched = low_exact_terminal_application.touched
    changed = low_exact_terminal_application.changed
    effects = dae_commit_effects_merge(
      effects,
      low_exact_terminal_application.effects,
    )
    trace(
      "pass[dae-optimizing]:low-exact-terminal-call-locals primary_def=\{low_exact_terminal_application.primary_def}",
    )
  }
  let low_exact_result_application = dae_boundary_syntax_frozen_run_direct_gc_result_refinement_dependency_closure(
    current,
    touched,
    changed,
    low_exact_literal_application.productive_defs,
  )
  current = low_exact_result_application.mod_out
  if low_exact_result_application.productive_defs.length() > 0 {
    current_boundary_graph_stale = true
  }
  touched = low_exact_result_application.touched
  changed = low_exact_result_application.changed
  effects = dae_commit_effects_merge(
    effects,
    low_exact_result_application.effects,
  )
  for iter, primary_def in low_exact_result_application.productive_defs {
    trace(
      "pass[dae-optimizing]:low-exact-result-worklist iter=\{iter} primary_def=\{primary_def}",
    )
  }
  if optimize {
    // Discover only direct call targets whose final immediate actual
    // is already a materializable literal, null/string constant, or immutable
    // global, then reuse the complete value-slice, ownership, escape, write,
    // and call-count proof in the existing rewrite.
    let large_global_defs = dae_collect_large_uniform_const_revisit_defs(
      current,
    )
    let all_large_defs = Array::make(original_defined, true)
    // Each candidate enters the common epoch-bearing uniform-value work item.
    // The current graph refreshes after every commit, so newly exposed direct
    // callees can join the same deterministic frontier without a selected-only
    // scan-and-mutate path.
    for candidate_def = 0
        candidate_def < large_global_defs.length()
        candidate_def = candidate_def + 1 {
      if !large_global_defs[candidate_def] {
        continue
      }
      trace(
        "pass[dae-optimizing]:large-uniform-const-candidate primary_def=\{candidate_def}",
      )
      let global_application = dae_boundary_syntax_frozen_run_exact_literal_candidate_worklist_with_facts(
        current,
        touched,
        changed,
        [candidate_def],
        allow_immutable_global_get=true,
        allow_immediate_i32_suffix_fallback=true,
        original=Some(original_boundary_snapshot),
      )
      if global_application.productive_defs.length() > 0 {
        current = global_application.mod_out
        current_boundary_graph_stale = true
        touched = global_application.touched
        changed = global_application.changed
        effects = dae_commit_effects_merge(effects, global_application.effects)
        trace(
          "pass[dae-optimizing]:large-uniform-const-revisit primary_def=\{global_application.productive_defs[0]}",
        )
        // Materializing this boundary can expose an immediate literal in a
        // forwarded direct callee. Admit only those newly visible call targets;
        // the same exact call-slice/ownership transaction remains authoritative.
        match current.code_sec {
          Some(@lib.CodeSec(funcs)) => {
            let primary_def = global_application.productive_defs[0]
            if primary_def >= 0 && primary_def < funcs.length() {
              let @lib.Func(_, @lib.Expr(body)) = funcs[primary_def]
              dae_collect_immediate_materializable_call_targets_instrs(
                current,
                body,
                dae_boundary_syntax_frozen_imported_func_count(current),
                all_large_defs,
                large_global_defs,
              )
            }
          }
          None => ()
        }
      } else {
        trace(
          "pass[dae-optimizing]:large-uniform-const-rejected primary_def=\{candidate_def}",
        )
      }
    }
  }
  perf_stop_timer_opt(
    perf, "detail:dae:core:selected-lanes:reverse-exact-literal", reverse_exact_literal_start_us,
  )
  let low_wrapper_callees_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:selected-lanes:low-wrapper-callees",
  )
  // Keep the phase-local forwarding seed, but derive targets from exact current
  // wrapper shape rather than a fixed wrapper-definition list.
  let boundary_callee_order = if dae_should_run_low_wrapper_callee_phase(
      optimize~,
    ) {
    dae_collect_shifted_forward_wrapper_callee_order(
      current, 0, original_defined,
    )
  } else {
    []
  }
  let mut boundary_graph_opt : DaeCurrentBoundaryGraph? = None
  let mut boundary_dependencies_opt : DaeBoundaryDependencyGraph? = None
  for boundary_callee_def in boundary_callee_order {
    let boundary_graph = match boundary_graph_opt {
      Some(graph) => graph
      None => {
        let graph = dae_current_boundary_graph_new(current)
        boundary_graph_opt = Some(graph)
        graph
      }
    }
    let boundary_dependencies = match boundary_dependencies_opt {
      Some(dependencies) => dependencies
      None => {
        let dependencies = dae_boundary_dependency_graph_new(boundary_graph)
        boundary_dependencies_opt = Some(dependencies)
        dependencies
      }
    }
    if boundary_callee_def < 0 ||
      boundary_callee_def >= selected_scratch_defs.length() {
      continue
    }
    selected_scratch_defs[boundary_callee_def] = true
    let boundary_effects : Array[DaeCommitEffects] = []
    let boundary_result = dae_boundary_syntax_frozen_try_rewrite_selected_defs_unread_params_with_facts_once(
      current,
      selected_scratch_defs,
      boundary_graph.snapshot.call_facts,
      original=Some(original_boundary_snapshot),
      graph=Some(boundary_graph),
      producer_effects_report=boundary_effects,
    )
    selected_scratch_defs[boundary_callee_def] = false
    let boundary_application = match boundary_effects.get(0) {
      Some(producer_effects) =>
        match
          dae_process_precomputed_signature_work_item(
            original_boundary_snapshot,
            current,
            touched,
            changed,
            boundary_graph,
            dae_work_item_new(
              boundary_graph,
              boundary_dependencies,
              boundary_result.primary_def,
              dae_work_family_for_commit_effects(
                producer_effects,
                boundary_result.primary_def,
              ),
            ),
            boundary_result,
            producer_effects,
          ) {
          DaeWorkCommitted(value) => Some(value)
          _ => None
        }
      None => None
    }
    match boundary_application {
      Some(boundary_application) => {
        current = boundary_application.mod_out
        current_boundary_graph_stale = true
        dae_current_boundary_graph_refresh(boundary_graph, current)
        boundary_dependencies_opt = Some(
          dae_boundary_dependency_graph_new(boundary_graph),
        )
        touched = boundary_application.touched
        changed = boundary_application.changed
        effects = dae_commit_effects_merge(
          effects,
          boundary_application.effects,
        )
        dae_diagnostics_record_commit_effects(
          diagnostics,
          boundary_application.effects,
        )
        dae_diagnostics_record_applied_effects(
          diagnostics,
          boundary_application.effects,
        )
        trace(
          "pass[dae-optimizing]:boundary-wrapper-callee-core primary_def=\{boundary_application.primary_def}",
        )
      }
      None => ()
    }
  }
  perf_stop_timer_opt(
    perf, "detail:dae:core:selected-lanes:low-wrapper-callees", low_wrapper_callees_start_us,
  )
  let early_shapes_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:selected-lanes:early-shapes",
  )
  perf_stop_timer_opt(
    perf, "detail:dae:core:selected-lanes:early-shapes", early_shapes_start_us,
  )
  let dropped_results_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:selected-lanes:dropped-results",
  )
  let dropped_result_selected_defs_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:selected-lanes:dropped-results:selected-defs",
  )
  let mut fact_dropped_result_wave = 0
  while dae_should_run_fact_dropped_result_revisit(optimize~) {
    let fact_dropped_result_call_facts_start_us = perf_start_timer_opt(
      perf, "detail:dae:core:selected-lanes:dropped-results:call-facts",
    )
    let fact_dropped_result_call_facts = dae_collect_current_call_facts(
      current, original_total,
    )
    perf_stop_timer_opt(
      perf, "detail:dae:core:selected-lanes:dropped-results:call-facts", fact_dropped_result_call_facts_start_us,
    )
    let selected = dae_collect_fact_dropped_result_candidate_defs(
      current, fact_dropped_result_call_facts,
    )
    let candidate_defs = dae_order_selected_candidates_caller_first(
      current, selected,
    )
    let fact_dropped_result = dae_boundary_syntax_frozen_run_dropped_result_candidate_worklist_with_facts(
      current, touched, changed, candidate_defs,
    )
    if fact_dropped_result.productive_defs.length() == 0 {
      break
    }
    current = fact_dropped_result.mod_out
    current_boundary_graph_stale = true
    touched = fact_dropped_result.touched
    changed = fact_dropped_result.changed
    effects = dae_commit_effects_merge(effects, fact_dropped_result.effects)
    for primary_def in fact_dropped_result.productive_defs {
      trace(
        "pass[dae-optimizing]:fact-dropped-result wave=\{fact_dropped_result_wave} primary_def=\{primary_def}",
      )
    }
    fact_dropped_result_wave += 1
  }
  perf_stop_timer_opt(
    perf, "detail:dae:core:selected-lanes:dropped-results:selected-defs", dropped_result_selected_defs_start_us,
  )
  perf_stop_timer_opt(
    perf, "detail:dae:core:selected-lanes:dropped-results", dropped_results_start_us,
  )
  let literal_unread_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:selected-lanes:literal-unread",
  )
  perf_stop_timer_opt(
    perf, "detail:dae:core:selected-lanes:literal-unread", literal_unread_start_us,
  )
  let late_shapes_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:selected-lanes:late-shapes",
  )
  let late_shapes_input = current
  let mut late_shapes_changed = false
  let const_local_candidates = dae_collect_single_const_local_call_candidates(
    mod_,
  )
  let mut const_local_iteration = 0
  while true {
    let const_local_result = dae_try_inline_selected_i32_const_local_sets_once(
      current, const_local_candidates,
    )
    let const_local_application = dae_apply_body_only_family_result_transaction(
      original_boundary_snapshot, current, touched, changed, const_local_result,
      diagnostics,
    )
    if !const_local_application.applied {
      break
    }
    current = const_local_application.mod_out
    current_boundary_graph_stale = true
    late_shapes_changed = true
    touched = const_local_application.touched
    changed = const_local_application.changed
    effects = dae_commit_effects_merge(effects, const_local_application.effects)
    trace(
      "pass[dae-optimizing]:semantic-const-locals iter=\{const_local_iteration} primary_def=\{const_local_application.primary_def}",
    )
    const_local_iteration += 1
  }
  let pair_if_candidates = touched.copy()
  let pair_if_result = dae_try_rewrite_selected_func408_pair_if_carrier_once(
    current, pair_if_candidates,
  )
  let pair_if_application = dae_apply_body_only_family_result_transaction(
    original_boundary_snapshot, current, touched, changed, pair_if_result, diagnostics,
  )
  if pair_if_application.applied {
    current = pair_if_application.mod_out
    current_boundary_graph_stale = true
    late_shapes_changed = true
    touched = pair_if_application.touched
    changed = pair_if_application.changed
    effects = dae_commit_effects_merge(effects, pair_if_application.effects)
    trace(
      "pass[dae-optimizing]:touched-pair-if-carrier primary_def=\{pair_if_application.primary_def}",
    )
  }
  let terminal_args311_candidates = dae_collect_terminal_call_arg_cleanup_candidates(
    mod_, current, 4, 24,
  )
  let terminal_args311_result = dae_try_rewrite_selected_func311_terminal_call_args_once(
    current, terminal_args311_candidates, trace,
  )
  let terminal_args311_application = dae_apply_body_only_family_result_transaction(
    original_boundary_snapshot, current, touched, changed, terminal_args311_result,
    diagnostics,
  )
  if terminal_args311_application.applied {
    current = terminal_args311_application.mod_out
    current_boundary_graph_stale = true
    late_shapes_changed = true
    touched = terminal_args311_application.touched
    changed = terminal_args311_application.changed
    effects = dae_commit_effects_merge(
      effects,
      terminal_args311_application.effects,
    )
    trace(
      "pass[dae-optimizing]:changed-terminal-call-args-a primary_def=\{terminal_args311_application.primary_def}",
    )
  }
  let terminal_args313_candidates = dae_collect_terminal_call_arg_cleanup_candidates(
    mod_, current, 7, 2,
  )
  let terminal_args313_result = dae_try_rewrite_selected_func313_terminal_call_args_once(
    current, terminal_args313_candidates, trace,
  )
  let terminal_args313_application = dae_apply_body_only_family_result_transaction(
    original_boundary_snapshot, current, touched, changed, terminal_args313_result,
    diagnostics,
  )
  if terminal_args313_application.applied {
    current = terminal_args313_application.mod_out
    current_boundary_graph_stale = true
    late_shapes_changed = true
    touched = terminal_args313_application.touched
    changed = terminal_args313_application.changed
    effects = dae_commit_effects_merge(
      effects,
      terminal_args313_application.effects,
    )
    trace(
      "pass[dae-optimizing]:changed-terminal-call-args-b primary_def=\{terminal_args313_application.primary_def}",
    )
  }
  let global_suffix_candidates = dae_collect_direct_callee_defs_from_selected_callers(
    current, touched,
  )
  while true {
    let global_suffix_application = dae_boundary_syntax_frozen_apply_selected_func323_global_suffix_transaction(
      mod_,
      current,
      touched,
      changed,
      global_suffix_candidates,
      trace,
      original_snapshot=Some(original_boundary_snapshot),
      boundary_snapshot=if !current_boundary_graph_stale {
        Some(current_boundary_graph.snapshot)
      } else {
        None
      },
    )
    if !global_suffix_application.applied {
      break
    }
    current = global_suffix_application.mod_out
    current_boundary_graph_stale = true
    late_shapes_changed = true
    touched = global_suffix_application.touched
    changed = global_suffix_application.changed
    effects = dae_commit_effects_merge(
      effects,
      global_suffix_application.effects,
    )
    dae_diagnostics_record_commit_effects(
      diagnostics,
      global_suffix_application.effects,
    )
    dae_diagnostics_record_applied_effects(
      diagnostics,
      global_suffix_application.effects,
    )
    trace(
      "pass[dae-optimizing]:single-caller-global-suffix primary_def=\{global_suffix_application.primary_def}",
    )
  }
  // Shape cleanup can expose uniform operands only at direct callees of bodies
  // changed by this phase. Seed that exact invalidation frontier instead of
  // rescanning/admitting every module definition.
  let post_shape_uniform = if dae_should_run_changed_direct_callee_uniform_frontier(
      late_shapes_changed,
    ) {
    dae_boundary_syntax_frozen_run_changed_direct_callee_uniform_frontier(
      late_shapes_input, current, touched, changed,
    )
  } else {
    {
      mod_out: current,
      touched,
      changed,
      productive_defs: [],
      effects: dae_commit_effects_empty(original_defined),
    }
  }
  current = post_shape_uniform.mod_out
  touched = post_shape_uniform.touched
  changed = post_shape_uniform.changed
  effects = dae_commit_effects_merge(effects, post_shape_uniform.effects)
  for primary_def in post_shape_uniform.productive_defs {
    trace("pass[dae-optimizing]:post-shape-uniform primary_def=\{primary_def}")
  }
  perf_stop_timer_opt(
    perf, "detail:dae:core:selected-lanes:late-shapes", late_shapes_start_us,
  )
  perf_stop_timer_opt(
    perf, "detail:dae:core:selected-lanes", selected_lanes_start_us,
  )
  let raw_cleanup_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:raw-cleanup",
  )
  let module_raw_cleanup = dae_strip_module_nops_and_dropped_pure_leaf_once(
    current,
    touched,
    return_touched=false,
  )
  let module_raw_cleanup_application = dae_apply_body_only_family_result_transaction(
    original_boundary_snapshot, current, touched, changed, module_raw_cleanup, diagnostics,
  )
  if module_raw_cleanup_application.applied {
    current = module_raw_cleanup_application.mod_out
    touched = module_raw_cleanup_application.touched
    effects = dae_commit_effects_merge(
      effects,
      module_raw_cleanup_application.effects,
    )
    // The module raw cleanup rewrites bodies but does not discover new DAE
    // candidate functions; preserve the existing scheduler-owned bitmap.
    trace(
      "pass[dae-optimizing]:module-raw-cleanup primary_def=\{module_raw_cleanup_application.primary_def}",
    )
    changed = module_raw_cleanup_application.changed
  }
  perf_stop_timer_opt(perf, "detail:dae:core:raw-cleanup", raw_cleanup_start_us)
  let post_raw_selected_lanes_start_us = perf_start_timer_opt(
    perf, "detail:dae:core:post-raw-selected-lanes",
  )
  let changed_terminal_cleanup_input = current
  let mut changed_terminal_phase_changed = false
  let changed_terminal_candidates = dae_collect_terminal_callers_of_changed_boundaries(
    mod_, current,
  )
  while true {
    let const_if_result = dae_try_simplify_selected_const_if_defs_once(
      current, changed_terminal_candidates,
    )
    let const_if_application = dae_apply_body_only_family_result_transaction(
      original_boundary_snapshot, current, touched, changed, const_if_result, diagnostics,
    )
    if !const_if_application.applied {
      break
    }
    current = const_if_application.mod_out
    changed_terminal_phase_changed = true
    touched = const_if_application.touched
    changed = const_if_application.changed
    effects = dae_commit_effects_merge(effects, const_if_application.effects)
    trace(
      "pass[dae-optimizing]:changed-terminal-const-if primary_def=\{const_if_application.primary_def}",
    )
  }
  while true {
    let terminal_local_result = dae_try_inline_selected_terminal_call_local_sets_once(
      current, changed_terminal_candidates,
    )
    let terminal_local_application = dae_apply_body_only_family_result_transaction(
      original_boundary_snapshot, current, touched, changed, terminal_local_result,
      diagnostics,
    )
    if !terminal_local_application.applied {
      break
    }
    current = terminal_local_application.mod_out
    changed_terminal_phase_changed = true
    touched = terminal_local_application.touched
    changed = terminal_local_application.changed
    effects = dae_commit_effects_merge(
      effects,
      terminal_local_application.effects,
    )
    trace(
      "pass[dae-optimizing]:changed-terminal-call-locals primary_def=\{terminal_local_application.primary_def}",
    )
  }
  let default_wrapper_result = dae_try_cleanup_selected_func327_default_wrappers_once(
    current, changed_terminal_candidates,
  )
  let default_wrapper_application = dae_apply_body_only_family_result_transaction(
    original_boundary_snapshot, current, touched, changed, default_wrapper_result,
    diagnostics,
  )
  if default_wrapper_application.applied {
    current = default_wrapper_application.mod_out
    changed_terminal_phase_changed = true
    touched = default_wrapper_application.touched
    changed = default_wrapper_application.changed
    effects = dae_commit_effects_merge(
      effects,
      default_wrapper_application.effects,
    )
    trace(
      "pass[dae-optimizing]:changed-terminal-default-wrappers primary_def=\{default_wrapper_application.primary_def}",
    )
  }
  let changed_terminal_uniform = if dae_should_run_changed_direct_callee_uniform_frontier(
      changed_terminal_phase_changed,
    ) {
    dae_boundary_syntax_frozen_run_changed_direct_callee_uniform_frontier(
      changed_terminal_cleanup_input, current, touched, changed,
    )
  } else {
    {
      mod_out: current,
      touched,
      changed,
      productive_defs: [],
      effects: dae_commit_effects_empty(original_defined),
    }
  }
  current = changed_terminal_uniform.mod_out
  touched = changed_terminal_uniform.touched
  changed = changed_terminal_uniform.changed
  effects = dae_commit_effects_merge(effects, changed_terminal_uniform.effects)
  for primary_def in changed_terminal_uniform.productive_defs {
    trace(
      "pass[dae-optimizing]:post-changed-terminal-uniform primary_def=\{primary_def}",
    )
  }
  let final_return_suffix_cleanup = dae_strip_module_root_return_suffix_once(
    current, touched,
  )
  let final_return_suffix_cleanup_application = dae_apply_body_only_family_result_transaction(
    original_boundary_snapshot, current, touched, changed, final_return_suffix_cleanup,
    diagnostics,
  )
  if final_return_suffix_cleanup_application.applied {
    current = final_return_suffix_cleanup_application.mod_out
    touched = final_return_suffix_cleanup_application.touched
    effects = dae_commit_effects_merge(
      effects,
      final_return_suffix_cleanup_application.effects,
    )
    trace(
      "pass[dae-optimizing]:final-return-suffix-cleanup primary_def=\{final_return_suffix_cleanup_application.primary_def}",
    )
    changed = final_return_suffix_cleanup_application.changed
  }
  perf_stop_timer_opt(
    perf, "detail:dae:core:post-raw-selected-lanes", post_raw_selected_lanes_start_us,
  )
  {
    mod_out: current,
    touched,
    changed,
    primary_def: -1,
    effects,
    diagnostics,
    single_caller_throttle_consumed: unprofitable_removal_iters > 0,
  }
}
