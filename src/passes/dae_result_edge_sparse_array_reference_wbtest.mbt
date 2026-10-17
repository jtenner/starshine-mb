///|
fn dae_result_edge_sparse_array_reference(
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
  // These stamps belong to this build. A callee is visited once, in increasing
  // order. Tail and observer edges are independent; their union owns the two
  // result-forwarding rows. Allocate no stamps until a result edge is eligible.
  let mut tail_seen : Array[Int32] = []
  let mut observer_seen : Array[Int32] = []
  callee_def = 0
  while callee_def < defined {
    let callee_abs = imported + callee_def
    if callee_abs >= 0 && callee_abs < graph.snapshot.function_infos.length() {
      for callsite in graph.snapshot.function_infos[callee_abs].calls {
        let caller_def = callsite.caller_def
        if callsite.active &&
          caller_def >= 0 &&
          caller_def < defined &&
          (callsite.tail || !callsite.dropped) {
          if tail_seen.is_empty() {
            tail_seen = Array::make(defined, -1)
            observer_seen = Array::make(defined, -1)
            match result_edge_work {
              Some(count) =>
                count[1] += tail_seen.length() + observer_seen.length()
              None => ()
            }
          }
          if callsite.tail {
            if tail_seen[caller_def] != callee_def {
              return_callers_by_def[callee_def].push(caller_def)
              if observer_seen[caller_def] != callee_def {
                result_forwarders_by_def[callee_def].push(caller_def)
                result_dependencies_by_def[caller_def].push(callee_def)
              }
              tail_seen[caller_def] = callee_def
            }
          } else if observer_seen[caller_def] != callee_def {
            result_observers_by_def[callee_def].push(caller_def)
            if tail_seen[caller_def] != callee_def {
              result_forwarders_by_def[callee_def].push(caller_def)
              result_dependencies_by_def[caller_def].push(callee_def)
            }
            observer_seen[caller_def] = callee_def
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
