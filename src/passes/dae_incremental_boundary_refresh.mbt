///| A committed structural mask proves which aliased producer bodies need a

///|
/// scan. Unknown callers retain the full reference refresh.
fn dae_current_boundary_graph_refresh(
  graph : DaeCurrentBoundaryGraph,
  mod_ : @lib.Module,
  topology_walk_visits~ : Array[Int32]? = None,
  forced_changed_defs~ : Array[Bool]? = None,
) -> Unit {
  if dae_try_refresh_current_boundary_graph_incremental(
      graph,
      mod_,
      forced_changed_defs~,
    ) {
    return
  }
  dae_current_boundary_graph_refresh_full(graph, mod_, topology_walk_visits~)
}

///|
/// Replay immutable call records and topology for unchanged callers. Only
/// changed or forced callers need the fused instruction scanner. A snapshot
/// with body function references retains the complete exposure scan so removed
/// references cannot leave stale visibility facts.
fn dae_try_refresh_current_boundary_graph_incremental(
  graph : DaeCurrentBoundaryGraph,
  mod_ : @lib.Module,
  forced_changed_defs~ : Array[Bool]? = None,
) -> Bool {
  let previous = graph.snapshot
  let defined = dae_defined_func_count(mod_)
  let imported = dae_imported_func_count(mod_)
  let total = imported + defined
  let forced = match forced_changed_defs {
    Some(mask) if mask.length() == defined => mask
    _ => return false
  }
  if imported != previous.imported ||
    defined != previous.defined ||
    total != previous.total ||
    graph.mod_.import_sec != mod_.import_sec ||
    previous.funcs.length() != defined ||
    previous.function_types.length() != total ||
    previous.function_infos.length() != total ||
    graph.function_epochs.length() != defined {
    return false
  }
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) if funcs.length() == defined => funcs
    None if defined == 0 => []
    _ => return false
  }
  let type_indices = dae_collect_func_type_indices(mod_)
  if type_indices.length() != total {
    return false
  }
  let function_types = dae_snapshot_function_types(mod_, type_indices)
  let body_changed = Array::make(defined, false)
  let signature_changed = Array::make(defined, false)
  let rescanned = Array::make(defined, false)
  for def_idx in 0..<defined {
    signature_changed[def_idx] = previous.function_types[imported + def_idx] !=
      function_types[imported + def_idx]
    body_changed[def_idx] = !dae_snapshot_func_unchanged(
      previous.funcs[def_idx],
      funcs[def_idx],
    )
    rescanned[def_idx] = forced[def_idx] ||
      body_changed[def_idx] ||
      signature_changed[def_idx]
  }
  // With no body ref.func exposure in the checked snapshot, unchanged bodies
  // cannot add one. The changed-body scanner records any new references.
  let rescan_body_exposure = previous.exposure.any(fn(row) { row.ref_func_body })
  let exposure = dae_collect_original_exposure(
    mod_,
    total,
    type_indices,
    include_body=rescan_body_exposure,
  )
  let escaped = dae_exposure_to_escaped(exposure)
  let refreshed_infos = dae_make_function_infos(total, escaped)
  let direct_calls = Array::make(total, 0)
  let tail_calls = Array::make(total, false)
  let direct_callers = dae_make_direct_callers(total)
  let dropped_calls = Array::make(total, 0)
  let caller_seen_stamps = Array::make(total, -1)
  let topology = dae_empty_topology_extras(total)
  // Stable call records retain active, dropped, tail, and caller facts. Replay
  // unchanged edges instead of traversing every unchanged instruction tree.
  for callee_abs in 0..<total {
    for callsite in previous.function_infos[callee_abs].calls {
      let caller = callsite.caller_def
      if caller < 0 || caller >= defined || rescanned[caller] {
        continue
      }
      if callsite.active {
        direct_calls[callee_abs] += 1
        if callsite.dropped {
          dropped_calls[callee_abs] += 1
        }
        if callsite.tail {
          tail_calls[callee_abs] = true
        }
      }
      if caller_seen_stamps[callee_abs] != caller {
        direct_callers[callee_abs].push(caller)
        caller_seen_stamps[callee_abs] = caller
      }
    }
  }
  for def_idx in 0..<defined {
    let caller_abs = imported + def_idx
    if !rescanned[def_idx] {
      let before = graph.topology
      topology.has_outgoing_call_indirect[caller_abs] = before.has_outgoing_call_indirect[caller_abs]
      topology.has_outgoing_call_ref[caller_abs] = before.has_outgoing_call_ref[caller_abs]
      topology.has_outgoing_return_call[caller_abs] = before.has_outgoing_return_call[caller_abs]
      topology.has_outgoing_return_call_indirect[caller_abs] = before.has_outgoing_return_call_indirect[caller_abs]
      topology.has_outgoing_return_call_ref[caller_abs] = before.has_outgoing_return_call_ref[caller_abs]
      for callee in before.direct_return_callees_by_caller[caller_abs] {
        dae_adjacency_add_unique(
          topology.direct_return_callers,
          callee,
          caller_abs,
          0,
          topology.adjacency_membership,
        )
        dae_adjacency_add_unique(
          topology.direct_return_callees_by_caller,
          caller_abs,
          callee,
          1,
          topology.adjacency_membership,
        )
      }
      continue
    }
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    ignore(
      dae_scan_current_call_facts_instrs(
        body,
        def_idx,
        imported + def_idx,
        [],
        direct_calls,
        tail_calls,
        direct_callers,
        dropped_calls,
        escaped,
        if rescanned[def_idx] {
          refreshed_infos
        } else {
          []
        },
        caller_seen_stamps,
        true,
        topology_out=Some(topology),
        body_exposure_out=if rescan_body_exposure {
          None
        } else {
          Some(exposure)
        },
        stable_path=if rescanned[def_idx] {
          Some(DaeStablePath::empty())
        } else {
          None
        },
      ),
    )
  }
  // The scanner visits changed callers after cached edges. Restore the full
  // scanner's ascending caller order before equality checks and scheduling.
  for row in direct_callers {
    row.sort()
  }
  for row in topology.direct_return_callers {
    row.sort()
  }
  let function_infos : Array[DaeFunctionInfo] = []
  for func_abs in 0..<total {
    let before = previous.function_infos[func_abs]
    let refreshed = refreshed_infos[func_abs]
    let incoming_changed = !refreshed.calls.is_empty() ||
      before.calls.any(fn(callsite) {
        callsite.caller_def >= 0 &&
        callsite.caller_def < rescanned.length() &&
        rescanned[callsite.caller_def]
      })
    let calls = if incoming_changed {
      dae_merge_rebased_stable_calls(before.calls, refreshed.calls, rescanned)
    } else {
      before.calls
    }
    let dropped = if incoming_changed {
      calls.filter(fn(callsite) { callsite.dropped })
    } else {
      before.dropped_calls
    }
    let def_idx = func_abs - imported
    let own_body_rescanned = def_idx >= 0 &&
      def_idx < rescanned.length() &&
      rescanned[def_idx]
    // Fresh wrappers retain old snapshot ownership. Full refresh also resets
    // each per-function analysis cache, including bodies that did not change.
    function_infos.push({
      stale: true,
      unused_params: [],
      calls,
      dropped_calls: dropped,
      has_tail_calls: if own_body_rescanned {
        refreshed.has_tail_calls
      } else {
        before.has_tail_calls
      },
      tail_callees: if own_body_rescanned {
        refreshed.tail_callees
      } else {
        before.tail_callees
      },
      loop_type_indices: if own_body_rescanned {
        refreshed.loop_type_indices
      } else {
        before.loop_type_indices
      },
      has_adjacent_local_set_get: if own_body_rescanned {
        refreshed.has_adjacent_local_set_get
      } else {
        before.has_adjacent_local_set_get
      },
      has_unseen_calls: escaped[func_abs],
    })
  }
  let call_facts : DaeCurrentCallFacts = {
    direct_calls,
    tail_calls,
    direct_callers,
    dropped_calls,
    escaped,
  }
  let parameter_loop_free = dae_parameter_loop_admission(
    mod_, imported, defined, function_infos,
  )
  let mut changed = false
  for def_idx in 0..<defined {
    if signature_changed[def_idx] {
      graph.function_epochs[def_idx].signature_epoch += 1
      changed = true
    }
    if body_changed[def_idx] {
      graph.function_epochs[def_idx].body_epoch += 1
      changed = true
    }
  }
  if !dae_current_call_facts_equal(previous.call_facts, call_facts) {
    graph.call_epoch += 1
    changed = true
  }
  if graph.mod_.type_sec != mod_.type_sec ||
    graph.mod_.func_sec != mod_.func_sec {
    graph.type_epoch += 1
    changed = true
  }
  if changed {
    graph.module_epoch += 1
  }
  graph.dependency_cache = None
  if graph.forwarding_syntax.length() != defined ||
    graph.mod_.type_sec != mod_.type_sec {
    graph.forwarding_syntax = []
  } else {
    for def_idx in 0..<defined {
      if rescanned[def_idx] {
        graph.forwarding_syntax[def_idx] = None
      }
    }
  }
  graph.mod_ = mod_
  graph.snapshot = {
    imported,
    defined,
    total,
    type_indices,
    function_types,
    funcs,
    call_facts,
    boundary_facts: dae_call_boundary_facts_from_current(call_facts),
    function_infos,
    exposure,
    parameter_loop_free,
  }
  graph.topology = topology
  true
}
