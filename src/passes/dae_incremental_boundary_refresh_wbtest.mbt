///|
fn dae_refresh_assert_calls(
  actual : Array[DaeStableCallsite],
  expected : Array[DaeStableCallsite],
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for index in 0..<actual.length() {
    let left = actual[index]
    let right = expected[index]
    assert_eq(
      (left.caller_def, left.callee_abs, left.active, left.dropped, left.tail),
      (
        right.caller_def,
        right.callee_abs,
        right.active,
        right.dropped,
        right.tail,
      ),
    )
    assert_eq(left.path.to_array(), right.path.to_array())
  }
}

///|
fn dae_refresh_assert_graphs(
  actual : DaeCurrentBoundaryGraph,
  expected : DaeCurrentBoundaryGraph,
) -> Unit raise {
  let left = actual.snapshot
  let right = expected.snapshot
  assert_eq(
    (left.imported, left.defined, left.total),
    (right.imported, right.defined, right.total),
  )
  assert_eq(left.type_indices, right.type_indices)
  assert_eq(left.function_types, right.function_types)
  assert_true(dae_snapshot_funcs_unchanged(left.funcs, right.funcs))
  assert_true(dae_current_call_facts_equal(left.call_facts, right.call_facts))
  assert_eq(left.parameter_loop_free, right.parameter_loop_free)
  assert_eq(left.function_infos.length(), right.function_infos.length())
  for index in 0..<left.function_infos.length() {
    let a = left.function_infos[index]
    let b = right.function_infos[index]
    assert_eq(
      (
        a.stale,
        a.has_tail_calls,
        a.has_adjacent_local_set_get,
        a.has_unseen_calls,
      ),
      (
        b.stale,
        b.has_tail_calls,
        b.has_adjacent_local_set_get,
        b.has_unseen_calls,
      ),
    )
    assert_eq(a.unused_params, b.unused_params)
    assert_eq(a.tail_callees, b.tail_callees)
    assert_eq(a.loop_type_indices, b.loop_type_indices)
    dae_refresh_assert_calls(a.calls, b.calls)
    dae_refresh_assert_calls(a.dropped_calls, b.dropped_calls)
    let a = left.exposure[index]
    let b = right.exposure[index]
    assert_eq(
      (
        a.imported,
        a.exported,
        a.start,
        a.ref_func_body,
        a.ref_func_module,
        a.active_element,
        a.passive_element,
        a.declarative_element,
      ),
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
    )
  }
  let a = actual.topology
  let b = expected.topology
  assert_eq(a.direct_return_callers, b.direct_return_callers)
  assert_eq(
    a.direct_return_callees_by_caller,
    b.direct_return_callees_by_caller,
  )
  assert_eq(a.has_outgoing_call_indirect, b.has_outgoing_call_indirect)
  assert_eq(a.has_outgoing_call_ref, b.has_outgoing_call_ref)
  assert_eq(a.has_outgoing_return_call, b.has_outgoing_return_call)
  assert_eq(
    a.has_outgoing_return_call_indirect,
    b.has_outgoing_return_call_indirect,
  )
  assert_eq(a.has_outgoing_return_call_ref, b.has_outgoing_return_call_ref)
  assert_eq(
    (actual.module_epoch, actual.call_epoch, actual.type_epoch),
    (expected.module_epoch, expected.call_epoch, expected.type_epoch),
  )
  for index in 0..<actual.function_epochs.length() {
    assert_eq(
      actual.function_epochs[index].body_epoch,
      expected.function_epochs[index].body_epoch,
    )
    assert_eq(
      actual.function_epochs[index].signature_epoch,
      expected.function_epochs[index].signature_epoch,
    )
  }
  assert_true(actual.dependency_cache is None)
}

///|
test "DAE incremental refresh retains unchanged call paths and old snapshot ownership" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $target (result i32) i32.const 7)
      #|  (func (export "run") (result i32) call $target)
      #|  (func (result f64) f64.const nan))
    ),
  )
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let previous = graph.snapshot
  let old_info = previous.function_infos[0]
  old_info.stale = false
  old_info.unused_params = [true]
  ignore(dae_boundary_dependency_graph_new(graph))
  let reference = dae_current_boundary_graph_new(input)
  dae_current_boundary_graph_refresh_full(reference, input)
  assert_true(
    dae_try_refresh_current_boundary_graph_incremental(
      graph,
      input,
      forced_changed_defs=Some([false, false, false]),
    ),
  )
  dae_refresh_assert_graphs(graph, reference)
  assert_true(
    physical_equal(graph.snapshot.function_infos[0].calls, old_info.calls),
  )
  assert_false(old_info.stale)
  assert_eq(old_info.unused_params, [true])
  assert_eq(previous.function_infos[0].calls[0].path.to_array(), [0])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE incremental refresh updates changed signatures and indexed loop admission" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $loop (func (param i32) (result i32)))
      #|  (func $target (param i32) (result i32) local.get 0)
      #|  (func (export "run") (result i32)
      #|    i32.const 7 loop (type $loop) end call $target))
    ),
  )
  let next = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $loop (func (result i32)))
      #|  (func $target (result i32) i32.const 7)
      #|  (func (export "run") (result i32)
      #|    loop (type $loop) i32.const 7 end drop call $target))
    ),
  )
  let graph = dae_current_boundary_graph_new(input)
  let reference = dae_current_boundary_graph_new(input)
  dae_current_boundary_graph_refresh_full(reference, next)
  assert_true(
    dae_try_refresh_current_boundary_graph_incremental(
      graph,
      next,
      forced_changed_defs=Some([true, true]),
    ),
  )
  dae_refresh_assert_graphs(graph, reference)
  assert_eq(graph.snapshot.parameter_loop_free, [true, true])
  assert_eq(graph.function_epochs[0].signature_epoch, 1)
  assert_eq(graph.function_epochs[1].body_epoch, 1)
}

///|
test "DAE incremental refresh replaces added and removed exact escape evidence" {
  let plain = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $target)
      #|  (func (export "run") call $target))
    ),
  )
  let escaped = pass_test_module_from_wat(
    (
      #|(module
      #|  (elem declare func $target)
      #|  (func $target)
      #|  (func (export "run") ref.func $target drop call $target))
    ),
  )
  let graph = dae_current_boundary_graph_new(plain)
  let reference = dae_current_boundary_graph_new(plain)
  for next in [escaped, plain] {
    dae_current_boundary_graph_refresh_full(reference, next)
    assert_true(
      dae_try_refresh_current_boundary_graph_incremental(
        graph,
        next,
        forced_changed_defs=Some([false, true]),
      ),
    )
    dae_refresh_assert_graphs(graph, reference)
  }
  assert_false(graph.snapshot.call_facts.escaped[0])
  assert_false(graph.snapshot.function_infos[0].has_unseen_calls)
}

///|
test "DAE incremental refresh rebases nested tail and unreachable calls exactly" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $a (result i32) i32.const 1)
      #|  (func $b (result i32) i32.const 2)
      #|  (func (export "run") (result i32)
      #|    block call $a drop end call $b)
      #|  (func (result i32) return_call $a))
    ),
  )
  let next = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $a (result i32) i32.const 1)
      #|  (func $b (result i32) i32.const 2)
      #|  (func (export "run") (result i32)
      #|    block i32.const 0 drop call $b drop end
      #|    unreachable call $a)
      #|  (func (result i32) return_call $b))
    ),
  )
  let graph = dae_current_boundary_graph_new(input)
  let reference = dae_current_boundary_graph_new(input)
  dae_current_boundary_graph_refresh_full(reference, next)
  assert_true(
    dae_try_refresh_current_boundary_graph_incremental(
      graph,
      next,
      forced_changed_defs=Some([false, false, true, true]),
    ),
  )
  dae_refresh_assert_graphs(graph, reference)
  assert_eq(graph.snapshot.call_facts.tail_calls, [false, true, false, false])
}

///|
test "DAE incremental refresh rejects shape changes for full refresh fallback" {
  let input = pass_test_module_from_wat("(module (func $a))")
  for
    next in [
      pass_test_module_from_wat("(module)"),
      pass_test_module_from_wat("(module (func $a) (func $b))"),
      pass_test_module_from_wat(
        "(module (import \"env\" \"a\" (func)) (func $b))",
      ),
    ] {
    let graph = dae_current_boundary_graph_new(input)
    let previous = graph.snapshot
    assert_false(
      dae_try_refresh_current_boundary_graph_incremental(
        graph,
        next,
        forced_changed_defs=Some([true]),
      ),
    )
    assert_true(physical_equal(previous.funcs, graph.snapshot.funcs))
    let reference = dae_current_boundary_graph_new(input)
    dae_current_boundary_graph_refresh_full(reference, next)
    dae_current_boundary_graph_refresh(graph, next)
    dae_refresh_assert_graphs(graph, reference)
  }
}

///|
test "DAE incremental refresh rescans explicit producer owned aliased callers" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $a)
      #|  (func $b)
      #|  (func (export "run") call $a))
    ),
  )
  let graph = dae_current_boundary_graph_new(input)
  let fallback_graph = dae_current_boundary_graph_new(input)
  let reference = dae_current_boundary_graph_new(input)
  // Legacy producer-owned cleanup can change an aliased instruction-array slot.
  // Its structural touch mask must force a new scan even when identity agrees.
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[2]
  body[0] = @lib.Instruction::call(@lib.FuncIdx::new(1U))
  dae_current_boundary_graph_refresh_full(reference, input)
  assert_false(
    dae_try_refresh_current_boundary_graph_incremental(fallback_graph, input),
  )
  dae_current_boundary_graph_refresh(fallback_graph, input)
  dae_refresh_assert_graphs(fallback_graph, reference)
  assert_true(
    dae_try_refresh_current_boundary_graph_incremental(
      graph,
      input,
      forced_changed_defs=Some([false, false, true]),
    ),
  )
  dae_refresh_assert_graphs(graph, reference)
  assert_eq(graph.snapshot.call_facts.direct_calls, [0, 1, 0])
}

///|
test "DAE incremental refresh rejects invalid producer masks without mutation" {
  let input = pass_test_module_from_wat("(module (func))")
  let graph = dae_current_boundary_graph_new(input)
  let previous = graph.snapshot
  // Wrong-sized masks are intentionally unsupported and use full refresh.
  for mask in [[], [true, false]] {
    assert_false(
      dae_try_refresh_current_boundary_graph_incremental(
        graph,
        input,
        forced_changed_defs=Some(mask),
      ),
    )
    assert_true(physical_equal(previous.funcs, graph.snapshot.funcs))
    assert_eq(graph.module_epoch, 0)
  }
}

///|
test "DAE cached refresh adds and removes body function-reference exposure" {
  let plain = pass_test_module_from_wat(
    "(module (func $a) (elem declare func $a) (func nop))",
  )
  let referenced = pass_test_module_from_wat(
    "(module (func $a) (elem declare func $a) (func ref.func $a drop))",
  )
  let graph = dae_current_boundary_graph_new(plain)
  let reference = dae_current_boundary_graph_new(plain)
  for next in [referenced, plain, referenced] {
    dae_current_boundary_graph_refresh_full(reference, next)
    assert_true(
      dae_try_refresh_current_boundary_graph_incremental(
        graph,
        next,
        forced_changed_defs=Some([false, true]),
      ),
    )
    dae_refresh_assert_graphs(graph, reference)
  }
}
