// Frozen whole-map interning reference. No production source changes.
// Candidate compatibility may add only first_child: -1 to the node literal and
// adapt the optional overflow-map representation; retain all get/set operations.

///|
fn dae_first_child_frozen_append(
  path : DaeStablePath,
  value : Int32,
) -> DaeStablePath {
  let key = dae_stable_path_key(path.tail, value)
  let children = match path.workspace.children {
    Some(children) => children
    None => {
      let children = @hashmap.new()
      path.workspace.children = Some(children)
      children
    }
  }
  let tail = match children.get(key) {
    Some(node) => node
    None => {
      let node = path.workspace.nodes.length()
      path.workspace.nodes.push({
        parent: path.tail,
        value,
        depth: path.length + 1,
        first_child: -1,
      })
      path.workspace.active_stamps.push(0)
      path.workspace.call_stamps.push(0)
      children.set(key, node)
      node
    }
  }
  { workspace: path.workspace, tail, length: path.length + 1, }
}

///|
fn dae_first_child_frozen_collect_module_boundary_snapshot(
  mod_ : @lib.Module,
  perf~ : HotPerfSession? = None,
  topology_out~ : DaeCurrentTopologyExtras? = None,
) -> DaeModuleBoundarySnapshot {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let analysis_start_us = perf_start_timer_opt(
    perf, "detail:dae:boundary-snapshot:function-analysis",
  )
  let analysis = dae_first_child_frozen_collect_current_function_analysis(
    mod_,
    total,
    perf~,
    topology_out~,
  )
  perf_stop_timer_opt(
    perf, "detail:dae:boundary-snapshot:function-analysis", analysis_start_us,
  )
  let call_facts = analysis.call_facts
  let type_indices_start_us = perf_start_timer_opt(
    perf, "detail:dae:boundary-snapshot:type-indices",
  )
  let type_indices = dae_collect_func_type_indices(mod_)
  perf_stop_timer_opt(
    perf, "detail:dae:boundary-snapshot:type-indices", type_indices_start_us,
  )
  let function_types_start_us = perf_start_timer_opt(
    perf, "detail:dae:boundary-snapshot:function-types",
  )
  let function_types = dae_snapshot_function_types(mod_, type_indices)
  perf_stop_timer_opt(
    perf, "detail:dae:boundary-snapshot:function-types", function_types_start_us,
  )
  {
    imported,
    defined,
    total,
    type_indices,
    function_types,
    funcs: match mod_.code_sec {
      Some(@lib.CodeSec(funcs)) => funcs
      None => []
    },
    call_facts,
    boundary_facts: dae_call_boundary_facts_from_current(call_facts),
    function_infos: analysis.function_infos,
    exposure: analysis.exposure,
    parameter_loop_free: analysis.parameter_loop_free,
  }
}

///|
fn dae_first_child_frozen_current_boundary_graph_new(
  mod_ : @lib.Module,
  topology~ : DaeCurrentTopologyExtras? = None,
  topology_walk_visits~ : Array[Int32]? = None,
) -> DaeCurrentBoundaryGraph {
  ignore(topology_walk_visits)
  let total = dae_imported_func_count(mod_) + dae_defined_func_count(mod_)
  let supplied = match topology {
    Some(value) if dae_current_topology_extras_shape_matches(value, total) =>
      Some(value)
    _ => None
  }
  let resolved_topology = match supplied {
    Some(value) => value
    None => dae_empty_topology_extras(total)
  }
  let snapshot = dae_first_child_frozen_collect_module_boundary_snapshot(
    mod_,
    topology_out=if supplied is None { Some(resolved_topology) } else { None },
  )
  {
    mod_,
    snapshot,
    topology: resolved_topology,
    function_epochs: dae_make_function_epochs(snapshot.defined, 0, 0),
    module_epoch: 0,
    call_epoch: 0,
    type_epoch: 0,
    dependency_cache: None,
  }
}

///|
/// direct-return or indirect/reference topology extras.
fn dae_first_child_frozen_typed_batch_boundary_graph_new(
  mod_ : @lib.Module,
  perf~ : HotPerfSession? = None,
) -> DaeCurrentBoundaryGraph {
  let snapshot = dae_first_child_frozen_collect_module_boundary_snapshot(
    mod_,
    perf~,
  )
  {
    mod_,
    snapshot,
    topology: dae_empty_topology_extras(snapshot.total),
    function_epochs: dae_make_function_epochs(snapshot.defined, 0, 0),
    module_epoch: 0,
    call_epoch: 0,
    type_epoch: 0,
    dependency_cache: None,
  }
}

///|
fn dae_first_child_frozen_collect_current_function_analysis(
  mod_ : @lib.Module,
  total_funcs : Int32,
  perf~ : HotPerfSession? = None,
  call_fact_rebuilds~ : Array[Int32]? = None,
  topology_out~ : DaeCurrentTopologyExtras? = None,
) -> DaeFunctionAnalysis {
  ignore(call_fact_rebuilds)
  let direct_calls = Array::make(total_funcs, 0)
  let tail_calls = Array::make(total_funcs, false)
  let direct_callers = dae_make_direct_callers(total_funcs)
  let dropped_calls = Array::make(total_funcs, 0)
  let type_indices = dae_collect_func_type_indices(mod_)
  let exposure_start_us = perf_start_timer_opt(
    perf, "detail:dae:boundary-snapshot:exposure",
  )
  let exposure = dae_collect_original_exposure(mod_, total_funcs, type_indices)
  perf_stop_timer_opt(
    perf, "detail:dae:boundary-snapshot:exposure", exposure_start_us,
  )
  let escaped = dae_exposure_to_escaped(exposure)
  let function_infos = dae_make_function_infos(total_funcs, escaped)
  let caller_seen_stamps = Array::make(total_funcs, -1)
  let imported = dae_imported_func_count(mod_)
  let body_scan_start_us = perf_start_timer_opt(
    perf, "detail:dae:boundary-snapshot:body-scan",
  )
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let mut caller_def = 0
      while caller_def < funcs.length() {
        let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
        ignore(
          dae_first_child_frozen_scan_current_call_facts_instrs(
            body,
            caller_def,
            imported + caller_def,
            [],
            direct_calls,
            tail_calls,
            direct_callers,
            dropped_calls,
            escaped,
            function_infos,
            caller_seen_stamps,
            true,
            topology_out~,
            stable_path=Some(DaeStablePath::empty()),
          ),
        )
        caller_def += 1
      }
    }
    None => ()
  }
  perf_stop_timer_opt(
    perf, "detail:dae:boundary-snapshot:body-scan", body_scan_start_us,
  )
  let mut escaped_idx = 0
  while escaped_idx < escaped.length() && escaped_idx < function_infos.length() {
    function_infos[escaped_idx].has_unseen_calls = escaped[escaped_idx] ||
      function_infos[escaped_idx].has_unseen_calls
    escaped_idx += 1
  }
  let defined = total_funcs - imported
  let loop_admission_start_us = perf_start_timer_opt(
    perf, "detail:dae:boundary-snapshot:loop-admission",
  )
  let parameter_loop_free = dae_parameter_loop_admission(
    mod_, imported, defined, function_infos,
  )
  perf_stop_timer_opt(
    perf, "detail:dae:boundary-snapshot:loop-admission", loop_admission_start_us,
  )
  let call_facts_start_us = perf_start_timer_opt(
    perf, "detail:dae:boundary-snapshot:call-facts",
  )
  let call_facts : DaeCurrentCallFacts = {
    direct_calls,
    tail_calls,
    direct_callers,
    dropped_calls,
    escaped,
  }
  perf_stop_timer_opt(
    perf, "detail:dae:boundary-snapshot:call-facts", call_facts_start_us,
  )
  { call_facts, function_infos, exposure, parameter_loop_free, }
}

///|
fn dae_first_child_frozen_scan_current_call_facts_instrs(
  instrs : Array[@lib.Instruction],
  caller_def : Int32,
  caller_abs : Int32,
  path : Array[Int32],
  direct_calls : Array[Int32],
  tail_calls : Array[Bool],
  direct_callers : Array[Array[Int32]],
  dropped_calls : Array[Int32],
  escaped : Array[Bool],
  function_infos : Array[DaeFunctionInfo],
  caller_seen_stamps : Array[Int32],
  active : Bool,
  topology_out~ : DaeCurrentTopologyExtras? = None,
  stable_path~ : DaeStablePath? = None,
) -> Bool {
  let mut idx = 0
  let mut current_active = active
  let singleton = instrs.length() == 1
  let mut singleton_trap = false
  while idx < instrs.length() {
    if idx + 1 < instrs.length() &&
      caller_abs >= 0 &&
      caller_abs < function_infos.length() {
      match (instrs[idx], instrs[idx + 1]) {
        (@lib.LocalSet(target), @lib.LocalGet(read)) if target == read =>
          function_infos[caller_abs].has_adjacent_local_set_get = true
        _ => ()
      }
    }
    match instrs[idx] {
      @lib.Unreachable => {
        current_active = false
        singleton_trap = singleton
      }
      @lib.Call(func_idx) => {
        let slot = dae_func_idx_slot(func_idx)
        if slot >= 0 && slot < direct_calls.length() {
          let dropped = current_active &&
            idx + 1 < instrs.length() &&
            instrs[idx + 1] == @lib.Instruction::drop()
          if slot < function_infos.length() {
            let callsite = {
              caller_def,
              path: match stable_path {
                Some(prefix) => dae_first_child_frozen_append(prefix, idx)
                None => dae_callsite_path(path, idx)
              },
              callee_abs: slot,
              active: current_active,
              dropped,
              tail: false,
            }
            function_infos[slot].calls.push(callsite)
            if dropped {
              function_infos[slot].dropped_calls.push(callsite)
            }
          }
          if current_active {
            direct_calls[slot] = direct_calls[slot] + 1
            if dropped {
              dropped_calls[slot] = dropped_calls[slot] + 1
            }
          }
          if caller_seen_stamps[slot] != caller_def {
            direct_callers[slot].push(caller_def)
            caller_seen_stamps[slot] = caller_def
          }
        }
      }
      @lib.ReturnCall(func_idx) =>
        if current_active {
          let slot = dae_func_idx_slot(func_idx)
          match topology_out {
            Some(topology) => {
              if caller_abs >= 0 &&
                caller_abs < topology.has_outgoing_return_call.length() {
                topology.has_outgoing_return_call[caller_abs] = true
              }
              if slot >= 0 && slot < topology.direct_return_callers.length() {
                dae_adjacency_add_unique(
                  topology.direct_return_callers,
                  slot,
                  caller_abs,
                  0,
                  topology.adjacency_membership,
                )
                if caller_abs >= 0 &&
                  caller_abs < topology.direct_return_callees_by_caller.length() {
                  dae_adjacency_add_unique(
                    topology.direct_return_callees_by_caller,
                    caller_abs,
                    slot,
                    1,
                    topology.adjacency_membership,
                  )
                }
              }
            }
            None => ()
          }
          if slot >= 0 && slot < direct_calls.length() {
            direct_calls[slot] = direct_calls[slot] + 1
            tail_calls[slot] = true
            if slot < function_infos.length() {
              let callsite = {
                caller_def,
                path: match stable_path {
                  Some(prefix) => dae_first_child_frozen_append(prefix, idx)
                  None => dae_callsite_path(path, idx)
                },
                callee_abs: slot,
                active: true,
                dropped: false,
                tail: true,
              }
              function_infos[slot].calls.push(callsite)
            }
            if caller_abs >= 0 && caller_abs < function_infos.length() {
              function_infos[caller_abs].has_tail_calls = true
              dae_function_info_add_tail_callee(
                function_infos[caller_abs],
                slot,
              )
            }
            if caller_seen_stamps[slot] != caller_def {
              direct_callers[slot].push(caller_def)
              caller_seen_stamps[slot] = caller_def
            }
          }
        }
      @lib.ReturnCallIndirect(_, _) => {
        if current_active {
          match topology_out {
            Some(topology) =>
              if caller_abs >= 0 &&
                caller_abs < topology.has_outgoing_return_call_indirect.length() {
                topology.has_outgoing_return_call_indirect[caller_abs] = true
              }
            None => ()
          }
        }

        if current_active &&
          caller_abs >= 0 &&
          caller_abs < function_infos.length() {
          function_infos[caller_abs].has_tail_calls = true
        }
      }
      @lib.ReturnCallRef(_) => {
        if current_active {
          match topology_out {
            Some(topology) =>
              if caller_abs >= 0 &&
                caller_abs < topology.has_outgoing_return_call_ref.length() {
                topology.has_outgoing_return_call_ref[caller_abs] = true
              }
            None => ()
          }
        }

        if current_active &&
          caller_abs >= 0 &&
          caller_abs < function_infos.length() {
          function_infos[caller_abs].has_tail_calls = true
        }
      }
      @lib.CallIndirect(_, _) =>
        if current_active {
          match topology_out {
            Some(topology) =>
              if caller_abs >= 0 &&
                caller_abs < topology.has_outgoing_call_indirect.length() {
                topology.has_outgoing_call_indirect[caller_abs] = true
              }
            None => ()
          }
        }
      @lib.CallRef(_) =>
        if current_active {
          match topology_out {
            Some(topology) =>
              if caller_abs >= 0 &&
                caller_abs < topology.has_outgoing_call_ref.length() {
                topology.has_outgoing_call_ref[caller_abs] = true
              }
            None => ()
          }
        }
      @lib.RefFunc(func_idx) => {
        let slot = dae_func_idx_slot(func_idx)
        if slot >= 0 && slot < escaped.length() {
          escaped[slot] = true
          if slot < function_infos.length() {
            function_infos[slot].has_unseen_calls = true
          }
        }
      }
      @lib.Block(_, @lib.Expr(body)) => {
        let child_trap = dae_first_child_frozen_scan_current_call_facts_child(
          body,
          caller_def,
          caller_abs,
          path,
          idx,
          0,
          direct_calls,
          tail_calls,
          direct_callers,
          dropped_calls,
          escaped,
          function_infos,
          caller_seen_stamps,
          current_active,
          topology_out~,
          stable_path~,
        )
        // A singleton Block chain ending in Unreachable contains no calls;
        // its summary is available after this required child scan. Other
        // structured controls retain their existing conservative admission.
        if child_trap {
          current_active = false
          singleton_trap = singleton
        }
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        match block_type {
          @lib.TypeIdxBlockType(type_idx) =>
            if caller_abs >= 0 && caller_abs < function_infos.length() {
              dae_function_info_add_loop_type_index(
                function_infos[caller_abs],
                type_idx,
              )
            }
          _ => ()
        }
        ignore(
          dae_first_child_frozen_scan_current_call_facts_child(
            body,
            caller_def,
            caller_abs,
            path,
            idx,
            1,
            direct_calls,
            tail_calls,
            direct_callers,
            dropped_calls,
            escaped,
            function_infos,
            caller_seen_stamps,
            current_active,
            topology_out~,
            stable_path~,
          ),
        )
      }
      @lib.If(_, then_body, Some(else_body)) => {
        ignore(
          dae_first_child_frozen_scan_current_call_facts_child(
            then_body,
            caller_def,
            caller_abs,
            path,
            idx,
            2,
            direct_calls,
            tail_calls,
            direct_callers,
            dropped_calls,
            escaped,
            function_infos,
            caller_seen_stamps,
            current_active,
            topology_out~,
            stable_path~,
          ),
        )
        ignore(
          dae_first_child_frozen_scan_current_call_facts_child(
            else_body,
            caller_def,
            caller_abs,
            path,
            idx,
            3,
            direct_calls,
            tail_calls,
            direct_callers,
            dropped_calls,
            escaped,
            function_infos,
            caller_seen_stamps,
            current_active,
            topology_out~,
            stable_path~,
          ),
        )
      }
      @lib.If(_, then_body, None) =>
        ignore(
          dae_first_child_frozen_scan_current_call_facts_child(
            then_body,
            caller_def,
            caller_abs,
            path,
            idx,
            2,
            direct_calls,
            tail_calls,
            direct_callers,
            dropped_calls,
            escaped,
            function_infos,
            caller_seen_stamps,
            current_active,
            topology_out~,
            stable_path~,
          ),
        )
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        ignore(
          dae_first_child_frozen_scan_current_call_facts_child(
            body,
            caller_def,
            caller_abs,
            path,
            idx,
            4,
            direct_calls,
            tail_calls,
            direct_callers,
            dropped_calls,
            escaped,
            function_infos,
            caller_seen_stamps,
            current_active,
            topology_out~,
            stable_path~,
          ),
        )
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        ignore(
          dae_first_child_frozen_scan_current_call_facts_child(
            body,
            caller_def,
            caller_abs,
            path,
            idx,
            4,
            direct_calls,
            tail_calls,
            direct_callers,
            dropped_calls,
            escaped,
            function_infos,
            caller_seen_stamps,
            current_active,
            topology_out~,
            stable_path~,
          ),
        )
        let mut catch_idx = 0
        while catch_idx < catches.length() {
          match catches[catch_idx] {
            @lib.LegacyCatch(_, @lib.Expr(catch_body))
            | @lib.LegacyCatchAll(@lib.Expr(catch_body)) =>
              ignore(
                dae_first_child_frozen_scan_current_call_facts_child(
                  catch_body,
                  caller_def,
                  caller_abs,
                  path,
                  idx,
                  5 + catch_idx,
                  direct_calls,
                  tail_calls,
                  direct_callers,
                  dropped_calls,
                  escaped,
                  function_infos,
                  caller_seen_stamps,
                  current_active,
                  topology_out~,
                  stable_path~,
                ),
              )
          }
          catch_idx += 1
        }
      }
      _ => ()
    }
    idx += 1
  }
  singleton_trap
}

///|
#inline
fn dae_first_child_frozen_scan_current_call_facts_child(
  instrs : Array[@lib.Instruction],
  caller_def : Int32,
  caller_abs : Int32,
  path : Array[Int32],
  instr_idx : Int32,
  child_kind : Int32,
  direct_calls : Array[Int32],
  tail_calls : Array[Bool],
  direct_callers : Array[Array[Int32]],
  dropped_calls : Array[Int32],
  escaped : Array[Bool],
  function_infos : Array[DaeFunctionInfo],
  caller_seen_stamps : Array[Int32],
  active : Bool,
  topology_out~ : DaeCurrentTopologyExtras? = None,
  stable_path~ : DaeStablePath? = None,
) -> Bool {
  let parent_length = path.length()
  let collect_paths = !function_infos.is_empty()
  if collect_paths {
    path.push(instr_idx)
    path.push(child_kind)
  }
  let child_stable_path = stable_path.map(fn(prefix) {
    dae_first_child_frozen_append(
      dae_first_child_frozen_append(prefix, instr_idx),
      child_kind,
    )
  })
  // Only recorded callsites copy a path. Recursive traversal borrows scratch;
  // shrinking restores the caller's prefix while retaining reusable capacity.
  let singleton_trap = dae_first_child_frozen_scan_current_call_facts_instrs(
    instrs,
    caller_def,
    caller_abs,
    path,
    direct_calls,
    tail_calls,
    direct_callers,
    dropped_calls,
    escaped,
    function_infos,
    caller_seen_stamps,
    active,
    topology_out~,
    stable_path=child_stable_path,
  )
  if collect_paths {
    path.resize(parent_length, 0)
  }
  singleton_trap
}

///|
fn dae_first_child_assert_calls_bounded(
  actual : Array[DaeStableCallsite],
  expected : Array[DaeStableCallsite],
) -> Unit raise {
  assert_true(
    actual.length() == expected.length(),
    msg="graph field actual.length()",
  )
  for index in 0..<actual.length() {
    let left = actual[index]
    let right = expected[index]
    assert_true(
      (left.caller_def, left.callee_abs, left.active, left.dropped, left.tail) ==
      (
        right.caller_def,
        right.callee_abs,
        right.active,
        right.dropped,
        right.tail,
      ),
      msg="graph field (left.caller_def, left.callee_abs, left.active, left.dropped, left.tail)",
    )
    assert_true(
      left.path.to_array() == right.path.to_array(),
      msg="graph field left.path.to_array()",
    )
  }
}

///|
fn dae_first_child_assert_graph_bounded(
  actual : DaeCurrentBoundaryGraph,
  expected : DaeCurrentBoundaryGraph,
) -> Unit raise {
  let left = actual.snapshot
  let right = expected.snapshot
  assert_true(
    (left.imported, left.defined, left.total) ==
    (right.imported, right.defined, right.total),
    msg="graph field (left.imported, left.defined, left.total)",
  )
  assert_true(
    left.type_indices == right.type_indices,
    msg="graph field left.type_indices",
  )
  assert_true(
    left.function_types == right.function_types,
    msg="graph field left.function_types",
  )
  assert_true(dae_snapshot_funcs_unchanged(left.funcs, right.funcs))
  assert_true(dae_current_call_facts_equal(left.call_facts, right.call_facts))
  assert_true(
    left.parameter_loop_free == right.parameter_loop_free,
    msg="graph field left.parameter_loop_free",
  )
  assert_true(
    left.function_infos.length() == right.function_infos.length(),
    msg="graph field left.function_infos.length()",
  )
  for index in 0..<left.function_infos.length() {
    let a = left.function_infos[index]
    let b = right.function_infos[index]
    assert_true(
      (
        a.stale,
        a.has_tail_calls,
        a.has_adjacent_local_set_get,
        a.has_unseen_calls,
      ) ==
      (
        b.stale,
        b.has_tail_calls,
        b.has_adjacent_local_set_get,
        b.has_unseen_calls,
      ),
      msg="graph field ( a.stale, a.has_tail_calls, a.has_adjacent_local_set_get, a.has_unseen_calls, )",
    )
    assert_true(
      a.unused_params == b.unused_params,
      msg="graph field a.unused_params",
    )
    assert_true(
      a.tail_callees == b.tail_callees,
      msg="graph field a.tail_callees",
    )
    assert_true(
      a.loop_type_indices == b.loop_type_indices,
      msg="graph field a.loop_type_indices",
    )
    dae_first_child_assert_calls_bounded(a.calls, b.calls)
    dae_first_child_assert_calls_bounded(a.dropped_calls, b.dropped_calls)
    let a = left.exposure[index]
    let b = right.exposure[index]
    assert_true(
      (
        a.imported,
        a.exported,
        a.start,
        a.ref_func_body,
        a.ref_func_module,
        a.active_element,
        a.passive_element,
        a.declarative_element,
      ) ==
      (
        b.imported,
        b.exported,
        b.start,
        b.ref_func_body,
        b.ref_func_module,
        b.active_element,
        b.passive_element,
        b.declarative_element,
      ),
      msg="graph field ( a.imported, a.exported, a.start, a.ref_func_body, a.ref_func_module, a.active_element, a.passive_e",
    )
  }
  let a = actual.topology
  let b = expected.topology
  assert_true(
    a.direct_return_callers == b.direct_return_callers,
    msg="graph field a.direct_return_callers",
  )
  assert_true(
    a.direct_return_callees_by_caller == b.direct_return_callees_by_caller,
    msg="graph field a.direct_return_callees_by_caller",
  )
  assert_true(
    a.has_outgoing_call_indirect == b.has_outgoing_call_indirect,
    msg="graph field a.has_outgoing_call_indirect",
  )
  assert_true(
    a.has_outgoing_call_ref == b.has_outgoing_call_ref,
    msg="graph field a.has_outgoing_call_ref",
  )
  assert_true(
    a.has_outgoing_return_call == b.has_outgoing_return_call,
    msg="graph field a.has_outgoing_return_call",
  )
  assert_true(
    a.has_outgoing_return_call_indirect == b.has_outgoing_return_call_indirect,
    msg="graph field a.has_outgoing_return_call_indirect",
  )
  assert_true(
    a.has_outgoing_return_call_ref == b.has_outgoing_return_call_ref,
    msg="graph field a.has_outgoing_return_call_ref",
  )
  assert_true(
    (actual.module_epoch, actual.call_epoch, actual.type_epoch) ==
    (expected.module_epoch, expected.call_epoch, expected.type_epoch),
    msg="graph field (actual.module_epoch, actual.call_epoch, actual.type_epoch)",
  )
  for index in 0..<actual.function_epochs.length() {
    assert_true(
      actual.function_epochs[index].body_epoch ==
      expected.function_epochs[index].body_epoch,
      msg="graph field actual.function_epochs[index].body_epoch",
    )
    assert_true(
      actual.function_epochs[index].signature_epoch ==
      expected.function_epochs[index].signature_epoch,
      msg="graph field actual.function_epochs[index].signature_epoch",
    )
  }
  assert_true(actual.dependency_cache is None)
}
