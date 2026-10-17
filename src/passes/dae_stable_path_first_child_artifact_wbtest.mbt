// This test-only owner differs only by retaining each fresh root.

///|
fn dae_first_child_census_collect_analysis(
  mod_ : @lib.Module,
  total_funcs : Int32,
  owners_out : Array[DaeStablePathWorkspace],
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
        let census_root = DaeStablePath::empty()
        owners_out.push(census_root.workspace)
        ignore(
          dae_scan_current_call_facts_instrs(
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
            stable_path=Some(census_root),
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
fn dae_first_child_census(input : @lib.Module, label : String) -> Unit raise {
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let actual = dae_current_boundary_graph_new(input)
  let expected = dae_first_child_frozen_current_boundary_graph_new(input)
  dae_first_child_assert_graph_bounded(actual, expected)
  // Test-only owner retains EVERY actual scanner workspace, including bodies
  // with no recorded calls. It adds no normal per-instruction recorder.
  let owners : Array[DaeStablePathWorkspace] = []
  let counted = dae_first_child_census_collect_analysis(
    input,
    actual.snapshot.total,
    owners,
  )
  assert_true(
    dae_current_call_facts_equal(counted.call_facts, actual.snapshot.call_facts),
  )
  assert_eq(
    counted.function_infos.length(),
    actual.snapshot.function_infos.length(),
  )
  for idx in 0..<counted.function_infos.length() {
    dae_first_child_assert_calls_bounded(
      counted.function_infos[idx].calls,
      actual.snapshot.function_infos[idx].calls,
    )
    dae_first_child_assert_calls_bounded(
      counted.function_infos[idx].dropped_calls,
      actual.snapshot.function_infos[idx].dropped_calls,
    )
  }
  assert_true(
    counted.parameter_loop_free == actual.snapshot.parameter_loop_free,
  )
  assert_eq(owners.length(), actual.snapshot.defined)
  let mut workspaces = 0
  let mut nodes = 0
  let mut first_children = 0
  let mut largest_fanout = 0
  let mut single_child_parents = 0
  for owner in owners {
    let workspace = owner
    workspaces += 1
    nodes += workspace.nodes.length()
    let counts = Array::make(workspace.nodes.length() + 1, 0)
    let seen : @hashmap.HashMap[UInt64, Int32] = @hashmap.new()
    for idx in 0..<workspace.nodes.length() {
      let node = workspace.nodes[idx]
      assert_true(node.parent >= -1 && node.parent < idx)
      let key = dae_stable_path_key(node.parent, node.value)
      assert_true(seen.get(key) is None, msg="canonical parent/value")
      seen.set(key, idx)
      counts[node.parent + 1] += 1
    }
    for count in counts {
      if count > 0 {
        first_children += 1
      }
      if count == 1 {
        single_child_parents += 1
      }
      if count > largest_fanout {
        largest_fanout = count
      }
    }
  }
  // These are actual retained syntax nodes, not predicted instruction counts.
  // Each occupied parent has one first insertion. Repeated first-child lookup
  // hits cannot be inferred from this state; obtain them from the call profile.
  println(
    "@DAE_FIRST_CHILD_CENSUS {\"artifact\":\"\{label}\",\"all_function_workspaces\":\{workspaces},\"nodes\":\{nodes},\"first_child_insertions\":\{first_children},\"overflow_insertions\":\{nodes - first_children},\"single_child_parents\":\{single_child_parents},\"largest_fanout\":\{largest_fanout}}",
  )
  dae_first_child_assert_graph_bounded(actual, expected)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("whole-artifact exact graph and node census; dedicated resource lane")
test "DAE first child whole-small graph fields and node distribution" {
  let input = @binary.decode_module(
    @sfs.read_file_bytes(
      "/home/dev/Projects/starshine-mb/.tmp/dae-speed-20261016/inputs/small.wasm",
    ).unwrap(),
  ).unwrap()
  dae_first_child_census(input, "small")
}

///|
#skip("whole-artifact exact graph and node census; dedicated resource lane")
test "DAE first child whole-large graph fields and node distribution" {
  let input = @binary.decode_module(
    @sfs.read_file_bytes(
      "/home/dev/Projects/starshine-mb/.tmp/dae-speed-20261016/inputs/large.wasm",
    ).unwrap(),
  ).unwrap()
  dae_first_child_census(input, "large")
}
