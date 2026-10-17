///|
/// Frozen S6 uniform-query component. Only the six mutually recursive entry
/// names are renamed. There is no new syntax-query constructor or mode branch.
/// Shared helpers are pinned in uniform-syntax-prep/s6-component-reference.json.

///|
fn dae_s6_uniform_reference_resolve_forwarded_uniform_const_local_get(
  mod_ : @lib.Module,
  caller_abs : Int32,
  local_slot : Int32,
  func_type_indices : Array[@lib.TypeIdx],
  boundary_facts : DaeCallBoundaryFacts,
  visited : Array[Bool],
  allow_immutable_global_get~ : Bool = false,
  uniform_resolution_cache~ : DaeUniformResolutionCache? = None,
) -> @lib.Instruction? {
  if caller_abs < 0 ||
    caller_abs >= func_type_indices.length() ||
    caller_abs >= visited.length() ||
    visited[caller_abs] {
    return None
  }
  if !dae_call_boundary_allows_forwarding(boundary_facts, caller_abs) {
    return None
  }
  let imported = dae_imported_func_count(mod_)
  let def_idx = caller_abs - imported
  if def_idx < 0 {
    return None
  }
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return None
  }
  if def_idx >= funcs.length() {
    return None
  }
  let func_type = match
    dae_resolve_func_type(mod_, func_type_indices, caller_abs) {
    Some(ft) => ft
    None => return None
  }
  let @lib.FuncType(params, _) = func_type
  if local_slot < 0 || local_slot >= params.length() {
    return None
  }
  let func = funcs[def_idx]
  if dae_forwarded_uniform_caller_is_recursive(
      boundary_facts, caller_abs, imported,
    ) {
    return None
  }
  let @lib.Func(locals, _) = func
  let local_use = match uniform_resolution_cache {
    Some(cache) if def_idx < cache.local_uses.length() => {
      if !cache.local_use_ready[def_idx] {
        cache.local_uses[def_idx] = Some(
          dae_local_use_for_callee(
            func,
            params.length() + locals.length(),
            caller_abs,
            params.length(),
          ),
        )
        cache.local_use_ready[def_idx] = true
        match cache.local_use_scans {
          Some(scans) => scans[0] += 1
          None => ()
        }
      }
      match cache.local_uses[def_idx] {
        Some(value) => value
        None => return None
      }
    }
    _ =>
      dae_local_use_for_callee(
        func,
        params.length() + locals.length(),
        caller_abs,
        params.length(),
      )
  }
  if local_use.writes[local_slot] {
    return None
  }
  match uniform_resolution_cache {
    Some(cache) if def_idx < cache.forwarded_values.length() => {
      if cache.forwarded_values[def_idx].length() != params.length() {
        cache.forwarded_values[def_idx] = Array::make(params.length(), None)
        cache.forwarded_ready[def_idx] = Array::make(params.length(), false)
        cache.forwarded_resolving[def_idx] = Array::make(params.length(), false)
      }
      if cache.forwarded_ready[def_idx][local_slot] {
        return cache.forwarded_values[def_idx][local_slot]
      }
      if cache.forwarded_resolving[def_idx][local_slot] {
        return None
      }
      cache.forwarded_resolving[def_idx][local_slot] = true
      match cache.forwarded_resolution_scans {
        Some(scans) => scans[0] += 1
        None => ()
      }
    }
    _ => ()
  }
  visited[caller_abs] = true
  let collect_params = Array::make(params.length(), false)
  collect_params[local_slot] = true
  let resolved_values = match uniform_resolution_cache {
    Some(cache) =>
      match cache.function_infos {
        Some(function_infos) =>
          dae_s6_uniform_reference_collect_uniform_const_actuals_from_function_infos(
            mod_,
            caller_abs,
            params.length(),
            func_type_indices,
            boundary_facts,
            function_infos,
            allow_immutable_global_get~,
            collect_params=Some(collect_params),
            stable_callsite_resolutions=cache.stable_callsite_resolutions,
            uniform_resolution_cache~,
          )
        None =>
          dae_s6_uniform_reference_collect_uniform_const_actuals_visited(
            mod_,
            caller_abs,
            params.length(),
            func_type_indices,
            boundary_facts,
            visited,
            allow_immutable_global_get~,
            collect_params=Some(collect_params),
            uniform_resolution_cache~,
          )
      }
    None =>
      dae_s6_uniform_reference_collect_uniform_const_actuals_visited(
        mod_,
        caller_abs,
        params.length(),
        func_type_indices,
        boundary_facts,
        visited,
        allow_immutable_global_get~,
        collect_params=Some(collect_params),
      )
  }
  let resolved = match resolved_values {
    Some(values) => values[local_slot]
    None => None
  }
  visited[caller_abs] = false
  match uniform_resolution_cache {
    Some(cache) if def_idx < cache.forwarded_values.length() &&
      cache.forwarded_values[def_idx].length() == params.length() => {
      cache.forwarded_values[def_idx][local_slot] = resolved
      cache.forwarded_ready[def_idx][local_slot] = true
      cache.forwarded_resolving[def_idx][local_slot] = false
    }
    _ => ()
  }
  resolved
}

///|
fn dae_s6_uniform_reference_resolve_uniform_const_candidate(
  mod_ : @lib.Module,
  caller_abs : Int32,
  candidate : @lib.Instruction,
  func_type_indices : Array[@lib.TypeIdx],
  boundary_facts : DaeCallBoundaryFacts,
  visited : Array[Bool],
  allow_immutable_global_get~ : Bool = false,
  uniform_resolution_cache~ : DaeUniformResolutionCache? = None,
) -> @lib.Instruction? {
  match
    dae_materializable_control_const(
      mod_, candidate, allow_immutable_global_get,
    ) {
    Some(materialized) => return Some(materialized)
    None => ()
  }
  if allow_immutable_global_get {
    if dae_instr_is_materializable_const_with_immutable_global(mod_, candidate) {
      return Some(candidate)
    }
  } else if dae_instr_is_materializable_const(candidate) {
    return Some(candidate)
  }
  match candidate {
    @lib.LocalGet(local_idx) =>
      dae_s6_uniform_reference_resolve_forwarded_uniform_const_local_get(
        mod_,
        caller_abs,
        dae_local_idx_slot(local_idx),
        func_type_indices,
        boundary_facts,
        visited,
        allow_immutable_global_get~,
        uniform_resolution_cache~,
      )
    _ => None
  }
}

///|
fn dae_s6_uniform_reference_collect_uniform_const_actuals_instrs(
  instrs : Array[@lib.Instruction],
  callee_abs : Int32,
  param_types : Array[@lib.ValType],
  entry_stack_values : Int32,
  caller_abs : Int32,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
  boundary_facts : DaeCallBoundaryFacts,
  visited : Array[Bool],
  seen : Array[Bool],
  invalid : Array[Bool],
  candidates : Array[@lib.Instruction?],
  allow_immutable_global_get~ : Bool = false,
  collect_params~ : Array[Bool]? = None,
  uniform_resolution_cache~ : DaeUniformResolutionCache? = None,
  legacy_tag_entries~ : Array[Int32]? = None,
) -> Bool {
  let tag_entries = match legacy_tag_entries {
    Some(entries) => entries
    None => []
  }
  let param_count = param_types.length()
  let active_params = match collect_params {
    Some(active) if active.length() == param_count => active
    Some(_) => return false
    None => Array::make(param_count, true)
  }
  let mut idx = 0
  while idx < instrs.length() {
    match
      dae_target_callsite_evidence(
        instrs[idx],
        callee_abs,
        DaeTargetDirectOrReturnCall,
      ) {
      Some(_) =>
        match
          dae_uniform_callsite_operands_at(
            mod_, instrs, idx, param_count, entry_stack_values, func_type_indices,
          ) {
          Some(operands) => {
            let mut p = 0
            while p < param_count {
              if active_params[p] && !invalid[p] {
                let actual = match operands.direct_actual_start {
                  Some(start) => {
                    let actual_idx = start + p
                    Some({
                      param_idx: p,
                      actual_idx,
                      instr: instrs[actual_idx],
                    })
                  }
                  None =>
                    match operands.evidence {
                      Some(evidence) =>
                        dae_callsite_single_instruction_actual(
                          evidence, p, instrs,
                        )
                      None => None
                    }
                }
                match actual {
                  Some(actual) =>
                    match
                      dae_s6_uniform_reference_resolve_uniform_const_candidate(
                        mod_,
                        caller_abs,
                        actual.instr,
                        func_type_indices,
                        boundary_facts,
                        visited,
                        allow_immutable_global_get~,
                        uniform_resolution_cache~,
                      ) {
                      Some(candidate) =>
                        dae_record_uniform_const_candidate(
                          seen, invalid, candidates, p, candidate,
                        )
                      None =>
                        match actual.instr {
                          @lib.LocalGet(local_idx) =>
                            match
                              dae_resolve_local_set_const_carrier(
                                instrs,
                                actual.actual_idx,
                                dae_local_idx_slot(local_idx),
                                mod_,
                                allow_immutable_global_get,
                              ) {
                              Some(candidate) =>
                                dae_record_uniform_const_candidate(
                                  seen, invalid, candidates, p, candidate,
                                )
                              None => invalid[p] = true
                            }
                          _ => invalid[p] = true
                        }
                    }
                  None =>
                    match
                      (match operands.evidence {
                        Some(evidence) =>
                          dae_materializable_uniform_slice_candidate(
                            instrs,
                            evidence.slices[p],
                            param_types[p],
                          )
                        None => None
                      }) {
                      Some(candidate) =>
                        dae_record_uniform_const_candidate(
                          seen, invalid, candidates, p, candidate,
                        )
                      None => invalid[p] = true
                    }
                }
              }
              p += 1
            }
          }
          None => return false
        }
      None =>
        match instrs[idx] {
          @lib.Try(block_type, @lib.Expr(body), catches, _) => {
            let body_entry = match
              dae_control_entry_stack_values(block_type, mod_) {
              Some(count) => count
              None => return false
            }
            if !dae_s6_uniform_reference_collect_uniform_const_actuals_instrs(
                body,
                callee_abs,
                param_types,
                body_entry,
                caller_abs,
                mod_,
                func_type_indices,
                boundary_facts,
                visited,
                seen,
                invalid,
                candidates,
                allow_immutable_global_get~,
                collect_params=Some(active_params),
                uniform_resolution_cache~,
                legacy_tag_entries=Some(tag_entries),
              ) {
              return false
            }
            for catch_ in catches {
              let catch_entry = match
                dae_legacy_catch_entry_stack_values(catch_, mod_, tag_entries) {
                Some(count) => count
                None => return false
              }
              let @lib.Expr(catch_body) = match catch_ {
                @lib.LegacyCatch(_, expr) | @lib.LegacyCatchAll(expr) => expr
              }
              if !dae_s6_uniform_reference_collect_uniform_const_actuals_instrs(
                  catch_body,
                  callee_abs,
                  param_types,
                  catch_entry,
                  caller_abs,
                  mod_,
                  func_type_indices,
                  boundary_facts,
                  visited,
                  seen,
                  invalid,
                  candidates,
                  allow_immutable_global_get~,
                  collect_params=Some(active_params),
                  uniform_resolution_cache~,
                  legacy_tag_entries=Some(tag_entries),
                ) {
                return false
              }
            }
          }
          @lib.Block(_, @lib.Expr(_))
          | @lib.Loop(_, @lib.Expr(_))
          | @lib.TryTable(_, _, @lib.Expr(_))
          | @lib.If(_, _, _) => {
            let child_evidence = match
              dae_nested_control_children_evidence(instrs[idx], mod_) {
              Some(evidence) => evidence
              None => return false
            }
            if !dae_s6_uniform_reference_collect_uniform_const_actuals_instrs(
                child_evidence.primary_body,
                callee_abs,
                param_types,
                child_evidence.entry_stack_values,
                caller_abs,
                mod_,
                func_type_indices,
                boundary_facts,
                visited,
                seen,
                invalid,
                candidates,
                allow_immutable_global_get~,
                collect_params=Some(active_params),
                uniform_resolution_cache~,
                legacy_tag_entries=Some(tag_entries),
              ) {
              return false
            }
            match child_evidence.secondary_body {
              Some(body) =>
                if !dae_s6_uniform_reference_collect_uniform_const_actuals_instrs(
                    body,
                    callee_abs,
                    param_types,
                    child_evidence.entry_stack_values,
                    caller_abs,
                    mod_,
                    func_type_indices,
                    boundary_facts,
                    visited,
                    seen,
                    invalid,
                    candidates,
                    allow_immutable_global_get~,
                    collect_params=Some(active_params),
                    uniform_resolution_cache~,
                    legacy_tag_entries=Some(tag_entries),
                  ) {
                  return false
                }
              None => ()
            }
          }
          _ => ()
        }
    }
    idx += 1
  }
  true
}

///|
fn dae_s6_uniform_reference_collect_uniform_const_actuals_visited(
  mod_ : @lib.Module,
  callee_abs : Int32,
  param_count : Int32,
  func_type_indices : Array[@lib.TypeIdx],
  boundary_facts : DaeCallBoundaryFacts,
  visited : Array[Bool],
  allow_immutable_global_get~ : Bool = false,
  collect_params~ : Array[Bool]? = None,
  uniform_resolution_cache~ : DaeUniformResolutionCache? = None,
) -> Array[@lib.Instruction?]? {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Some(Array::make(param_count, None))
  }
  let param_types = match
    dae_resolve_func_type(mod_, func_type_indices, callee_abs) {
    Some(@lib.FuncType(params, _)) if params.length() == param_count => params
    _ => return None
  }
  let imported = dae_imported_func_count(mod_)
  let seen = Array::make(param_count, false)
  let invalid = Array::make(param_count, false)
  let candidates : Array[@lib.Instruction?] = Array::make(param_count, None)
  let caller_defs = dae_call_boundary_direct_callers(boundary_facts, callee_abs)
  let mut caller_idx = 0
  while caller_idx < caller_defs.length() {
    let def_idx = caller_defs[caller_idx]
    if def_idx >= 0 && def_idx < funcs.length() {
      let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
      if !dae_s6_uniform_reference_collect_uniform_const_actuals_instrs(
          body,
          callee_abs,
          param_types,
          0,
          imported + def_idx,
          mod_,
          func_type_indices,
          boundary_facts,
          visited,
          seen,
          invalid,
          candidates,
          allow_immutable_global_get~,
          collect_params~,
          uniform_resolution_cache~,
        ) {
        return None
      }
    }
    caller_idx += 1
  }
  let out : Array[@lib.Instruction?] = []
  let mut p = 0
  while p < param_count {
    if invalid[p] || !seen[p] {
      out.push(None)
    } else {
      out.push(candidates[p])
    }
    p += 1
  }
  Some(out)
}

///|
fn dae_s6_uniform_reference_collect_uniform_const_actuals_from_boundary_facts(
  mod_ : @lib.Module,
  callee_abs : Int32,
  param_count : Int32,
  func_type_indices : Array[@lib.TypeIdx],
  boundary_facts : DaeCallBoundaryFacts,
  allow_immutable_global_get~ : Bool = false,
  collect_params~ : Array[Bool]? = None,
  uniform_resolution_cache~ : DaeUniformResolutionCache? = None,
) -> Array[@lib.Instruction?]? {
  let total = func_type_indices.length()
  dae_s6_uniform_reference_collect_uniform_const_actuals_visited(
    mod_,
    callee_abs,
    param_count,
    func_type_indices,
    boundary_facts,
    Array::make(total, false),
    allow_immutable_global_get~,
    collect_params~,
    uniform_resolution_cache~,
  )
}

///|
fn dae_s6_uniform_reference_collect_uniform_const_actuals_from_function_infos(
  mod_ : @lib.Module,
  callee_abs : Int32,
  param_count : Int32,
  func_type_indices : Array[@lib.TypeIdx],
  boundary_facts : DaeCallBoundaryFacts,
  function_infos : Array[DaeFunctionInfo],
  allow_immutable_global_get~ : Bool = false,
  collect_params~ : Array[Bool]? = None,
  stable_callsite_resolutions~ : Array[Int32]? = None,
  uniform_resolution_cache~ : DaeUniformResolutionCache? = None,
) -> Array[@lib.Instruction?]? {
  if callee_abs < 0 || callee_abs >= function_infos.length() {
    return None
  }
  let active_params = match collect_params {
    Some(active) if active.length() == param_count => active
    Some(_) => return None
    None => Array::make(param_count, true)
  }
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Some(Array::make(param_count, None))
  }
  let imported = dae_imported_func_count(mod_)
  let seen = Array::make(param_count, false)
  let invalid = Array::make(param_count, false)
  let candidates : Array[@lib.Instruction?] = Array::make(param_count, None)
  let mut unresolved_count = 0
  for active in active_params {
    if active {
      unresolved_count += 1
    }
  }
  let visited = match uniform_resolution_cache {
    Some(cache) if cache.visited.length() == func_type_indices.length() =>
      cache.visited
    _ => Array::make(func_type_indices.length(), false)
  }
  // Only narrowed, multi-parameter queries repeat operand recovery. Keep the
  // common full-parameter scan allocation-free with respect to this cache.
  let operand_cache = match (uniform_resolution_cache, collect_params) {
    (Some(cache), Some(_)) if param_count > 1 => {
      let entries = match cache.callsite_operands {
        Some(entries) => entries
        None => {
          let entries = @hashmap.new()
          cache.callsite_operands = Some(entries)
          entries
        }
      }
      Some(entries)
    }
    _ => None
  }
  // A tail call supplies the same parameter boundary as an ordinary call.
  // Its arguments must join the constant proof, including recursive updates.
  let tag_entries : Array[Int32] = []
  let callsites = function_infos[callee_abs].calls
  for callsite_index = 0
      callsite_index < callsites.length()
      callsite_index = callsite_index + 1 {
    let callsite = callsites[callsite_index]
    if !callsite.active || callsite.callee_abs != callee_abs {
      continue
    }
    let caller_def = callsite.caller_def
    if caller_def < 0 || caller_def >= funcs.length() {
      return None
    }
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    let operands = match
      dae_resolve_uniform_callsite_operands(
        mod_,
        body,
        callsite,
        callee_abs,
        param_count,
        func_type_indices,
        operand_cache,
        callsite_index,
        stable_callsite_resolutions,
        legacy_tag_entries=Some(tag_entries),
      ) {
      Some(operands) => operands
      None => return None
    }
    let scope = operands.scope
    let direct_actual_start = operands.direct_actual_start
    let evidence = operands.evidence
    let mut p = 0
    while p < param_count {
      if active_params[p] && !invalid[p] {
        let actual = match direct_actual_start {
          Some(start) => {
            let actual_idx = start + p
            Some({ param_idx: p, actual_idx, instr: scope[actual_idx], })
          }
          None =>
            match evidence {
              Some(value) =>
                dae_callsite_single_instruction_actual(value, p, scope)
              None => None
            }
        }
        match actual {
          Some(value) => {
            match stable_callsite_resolutions {
              Some(resolutions) if resolutions.length() >= 5 =>
                match value.instr {
                  @lib.LocalGet(_) => resolutions[4] += 1
                  _ => resolutions[3] += 1
                }
              _ => ()
            }
            match
              dae_s6_uniform_reference_resolve_uniform_const_candidate(
                mod_,
                imported + caller_def,
                value.instr,
                func_type_indices,
                boundary_facts,
                visited,
                allow_immutable_global_get~,
                uniform_resolution_cache~,
              ) {
              Some(candidate) =>
                dae_record_uniform_const_candidate(
                  seen, invalid, candidates, p, candidate,
                )
              None =>
                match value.instr {
                  @lib.LocalGet(local_idx) =>
                    match
                      dae_resolve_local_set_const_carrier(
                        scope,
                        value.actual_idx,
                        dae_local_idx_slot(local_idx),
                        mod_,
                        allow_immutable_global_get,
                      ) {
                      Some(candidate) =>
                        dae_record_uniform_const_candidate(
                          seen, invalid, candidates, p, candidate,
                        )
                      None => invalid[p] = true
                    }
                  _ => invalid[p] = true
                }
            }
          }
          None => {
            let candidate = match evidence {
              Some(value) =>
                match
                  dae_resolve_func_type(mod_, func_type_indices, callee_abs) {
                  Some(@lib.FuncType(params, _)) if p < params.length() =>
                    dae_materializable_uniform_slice_candidate(
                      scope,
                      value.slices[p],
                      params[p],
                    )
                  _ => None
                }
              None => None
            }
            match candidate {
              Some(candidate) =>
                dae_record_uniform_const_candidate(
                  seen, invalid, candidates, p, candidate,
                )
              None => invalid[p] = true
            }
          }
        }
        if invalid[p] {
          unresolved_count -= 1
        }
      }
      p += 1
    }
    if unresolved_count == 0 {
      break
    }
  }
  let out : Array[@lib.Instruction?] = []
  let mut p = 0
  while p < param_count {
    if invalid[p] || !seen[p] {
      out.push(None)
    } else {
      out.push(candidates[p])
    }
    p += 1
  }
  Some(out)
}
