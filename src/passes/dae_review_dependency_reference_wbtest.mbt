///|
/// Pre-cache forwarding body-walk control.
fn dae_review_dependency_reference(
  graph : DaeCurrentBoundaryGraph,
  builds~ : Array[Int32]? = None,
  result_edge_work~ : Array[Int32]? = None,
) -> DaeBoundaryDependencyGraph {
  match builds {
    Some(count) => count[0] += 1
    None => ()
  }
  let imported = graph.snapshot.imported
  let defined = graph.snapshot.defined
  let callers_by_def = dae_dependency_adjacency_new(defined)
  let callees_by_def = dae_dependency_adjacency_new(defined)
  let return_callers_by_def = dae_dependency_adjacency_new(defined)
  let result_forwarders_by_def = dae_dependency_adjacency_new(defined)
  let result_dependencies_by_def = dae_dependency_adjacency_new(defined)
  let result_observers_by_def = dae_dependency_adjacency_new(defined)
  let direct_callers = graph.snapshot.call_facts.direct_callers
  let mut callee_def = 0
  while callee_def < defined {
    let callee_abs = imported + callee_def
    if callee_abs >= 0 && callee_abs < direct_callers.length() {
      for caller_def in direct_callers[callee_abs] {
        if caller_def >= 0 && caller_def < defined {
          // `direct_callers` is already unique per callee, and this outer loop
          // visits each callee once, so both insertions are unique by construction.
          callers_by_def[callee_def].push(caller_def)
          callees_by_def[caller_def].push(callee_def)
        }
      }
    }
    callee_def += 1
  }
  callee_def = 0
  while callee_def < defined {
    let callee_abs = imported + callee_def
    if callee_abs >= 0 && callee_abs < graph.snapshot.function_infos.length() {
      // Each callee owns a fresh sparse map. No retained-capacity clear or
      // function-count-sized table is needed. Masks: tail=1, observer=2, both=3.
      let mut caller_kinds : @hashmap.HashMap[Int32, Int32]? = None
      let mut last_caller = -1
      let mut last_mask = 0
      for callsite in graph.snapshot.function_infos[callee_abs].calls {
        let caller_def = callsite.caller_def
        if callsite.active &&
          caller_def >= 0 &&
          caller_def < defined &&
          (callsite.tail || !callsite.dropped) {
          if caller_def != last_caller {
            last_caller = caller_def
            last_mask = match caller_kinds {
              Some(kinds) => {
                match result_edge_work {
                  Some(count) => count[1] += 1
                  None => ()
                }
                kinds.get(caller_def).unwrap_or(0)
              }
              None => 0
            }
          }
          let new_kind = if callsite.tail {
            last_mask == 0 || last_mask == 2
          } else {
            last_mask == 0 || last_mask == 1
          }
          if new_kind {
            if callsite.tail {
              return_callers_by_def[callee_def].push(caller_def)
            } else {
              result_observers_by_def[callee_def].push(caller_def)
            }
            if last_mask == 0 {
              result_forwarders_by_def[callee_def].push(caller_def)
              result_dependencies_by_def[caller_def].push(callee_def)
            }
            last_mask += if callsite.tail { 1 } else { 2 }
            match result_edge_work {
              Some(count) => count[2] += 1
              None => ()
            }
            match caller_kinds {
              Some(kinds) => kinds.set(caller_def, last_mask)
              None => {
                let kinds : @hashmap.HashMap[Int32, Int32] = @hashmap.new()
                kinds.set(caller_def, last_mask)
                caller_kinds = Some(kinds)
                match result_edge_work {
                  Some(count) => count[3] += 1
                  None => ()
                }
              }
            }
          }
        }
      }
    }
    callee_def += 1
  }
  let parameter_forwarding_edges : Array[DaeParameterForwardingEdge] = []
  let parameter_forwarders_by_def = dae_dependency_adjacency_new(defined)
  let membership = DaeForwardingMembership::new(
    parameter_forwarding_edges, parameter_forwarders_by_def,
  )
  let mut caller_def = 0
  while caller_def < defined && caller_def < graph.snapshot.funcs.length() {
    let caller_abs = imported + caller_def
    let caller_param_count = match graph.snapshot.function_types[caller_abs] {
      Some(@lib.FuncType(params, _)) => params.length()
      None => 0
    }
    let @lib.Func(_, @lib.Expr(body)) = graph.snapshot.funcs[caller_def]
    dae_collect_parameter_forwarding_dependencies_instrs(
      body,
      0,
      graph.mod_,
      caller_def,
      caller_param_count,
      graph.snapshot.type_indices,
      graph.function_epochs,
      parameter_forwarding_edges,
      parameter_forwarders_by_def,
      function_types=Some(graph.snapshot.function_types),
      membership=Some(membership),
    )
    caller_def += 1
  }
  let (component_by_def, component_members) = dae_boundary_components(
    callees_by_def,
  )
  let forwarding_adjacency = dae_dependency_adjacency_new(defined)
  let mut target_def = 0
  while target_def < parameter_forwarders_by_def.length() {
    for forwarder_def in parameter_forwarders_by_def[target_def] {
      if forwarder_def >= 0 && forwarder_def < defined {
        // Parameter forwarders are unique per target. Each undirected pair is
        // therefore emitted once in each direction; a self-edge needs one copy.
        forwarding_adjacency[target_def].push(forwarder_def)
        if forwarder_def != target_def {
          forwarding_adjacency[forwarder_def].push(target_def)
        }
      }
    }
    target_def += 1
  }
  let (forwarding_component_by_def, forwarding_component_members) = dae_boundary_components(
    forwarding_adjacency,
  )
  let caller_callee_dependencies = dae_dependency_adjacency_union(
    callers_by_def, callees_by_def,
  )
  {
    callers_by_def,
    callees_by_def,
    return_callers_by_def,
    parameter_forwarding_edges,
    parameter_forwarders_by_def,
    // Uniform-value evidence is invalidated by the bodies of every exact
    // current direct caller, but not by unrelated callees of the target.
    uniform_value_forwarders_by_def: dae_dependency_adjacency_copy(
      callers_by_def,
    ),
    result_forwarders_by_def,
    result_dependencies_by_def,
    result_observers_by_def,
    tail_result_dependencies_by_def: dae_dependency_adjacency_copy(
      return_callers_by_def,
    ),
    type_dependencies_by_def: dae_dependency_adjacency_copy(
      caller_callee_dependencies,
    ),
    body_use_dependencies_by_def: dae_dependency_adjacency_copy(
      caller_callee_dependencies,
    ),
    nested_cleanup_dependencies_by_def: dae_dependency_adjacency_copy(
      caller_callee_dependencies,
    ),
    component_by_def,
    component_members,
    forwarding_component_by_def,
    forwarding_component_members,
  }
}
