///|
test "DAE sparse result edges retain complete real graph fields and independent builds" {
  for mode in [0, 1, 2, 3, 4] {
    dae_result_edge_sparse_check(dae_result_edge_sparse_fixture(8, mode))
  }
  // The instruction journal must suppress a dead tail and dead ordinary call.
  dae_result_edge_sparse_check(
    pass_test_module_from_wat(
      "(module (func $target (param i32) (result i32) local.get 0) " +
      "(func (result i32) i32.const 8 return i32.const 7 call $target drop " +
      "i32.const 7 return_call $target))",
    ),
  )
}

///|
test "DAE sparse result edges retain ordered independent kinds and invalid caller guards" {
  let input = pass_test_module_from_wat(
    "(module (import \"m\" \"mark\" (func)) (func (result i32) i32.const 1) " +
    "(func (result i32) i32.const 2) (func) (func))",
  )
  let saved = @binary.encode_module(input).unwrap()
  @validate.validate_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  // These intentionally invalid caller metadata rows test the existing range
  // guard. They do not change the valid module or its source instruction arrays.
  for abs in 0..<graph.snapshot.function_infos.length() {
    let calls = graph.snapshot.function_infos[abs].calls
    while !calls.is_empty() {
      ignore(calls.pop())
    }
  }
  for
    (caller, active, dropped, tail) in [
      (2, false, false, true),
      (2, true, true, false),
      (3, true, false, false),
      (1, true, false, true),
      (3, true, false, true),
      (1, true, false, false),
      (3, true, false, false),
      (1, true, false, true),
      (-1, true, false, true),
      (4, true, false, false),
      (2, true, true, true),
    ] {
    graph.snapshot.function_infos[1].calls.push({
      caller_def: caller,
      path: DaeStablePath::empty(),
      callee_abs: 1,
      active,
      dropped,
      tail,
    })
  }
  for (caller, tail) in [(3, false), (2, true), (3, false), (2, true)] {
    graph.snapshot.function_infos[2].calls.push({
      caller_def: caller,
      path: DaeStablePath::empty(),
      callee_abs: 2,
      active: true,
      dropped: false,
      tail,
    })
  }
  // Imported callees are deliberately outside these defined-function rows.
  graph.snapshot.function_infos[0].calls.push({
    caller_def: 0,
    path: DaeStablePath::empty(),
    callee_abs: 0,
    active: true,
    dropped: false,
    tail: true,
  })
  let facts = dae_boundary_dependency_graph_build(graph)
  dae_result_edge_sparse_assert_equal(
    facts,
    dae_result_edge_sparse_reference(graph),
  )
  assert_eq(facts.return_callers_by_def, [[1, 3, 2], [2], [], []])
  assert_eq(facts.result_observers_by_def, [[3, 1], [3], [], []])
  assert_eq(facts.result_forwarders_by_def, [[3, 1, 2], [3, 2], [], []])
  assert_eq(facts.result_dependencies_by_def, [[], [0], [0, 1], [0, 1]])
  assert_eq(facts.tail_result_dependencies_by_def, [[1, 3, 2], [2], [], []])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE sparse result edges retain active scalar output effects and callback order" {
  let input = dae_result_edge_sparse_fixture(8, 2)
  let saved = @binary.encode_module(input).unwrap()
  let actual = dae_result_edge_sparse_round(input, false)
  let expected = dae_result_edge_sparse_round(input, true)
  assert_true(actual.changed)
  assert_eq(actual.touched, expected.touched)
  assert_eq(actual.primary_def, expected.primary_def)
  assert_eq(actual.effects, expected.effects)
  assert_eq(
    @binary.encode_module(actual.mod_out).unwrap(),
    @binary.encode_module(expected.mod_out).unwrap(),
  )
  @validate.validate_module(actual.mod_out).unwrap()
  @validate.validate_module(expected.mod_out).unwrap()
  let funcs = actual.mod_out.code_sec.unwrap().0
  let run = funcs[funcs.length() - 1]
  let @lib.Func(_, @lib.Expr(body)) = run
  let mut callbacks = 0
  for instr in body {
    match instr {
      @lib.Call(idx) => if dae_func_idx_slot(idx) == 0 { callbacks += 1 }
      _ => ()
    }
  }
  assert_eq(callbacks, 8)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE sparse result edges remove actual residual edge-key work after exact behavior guards" {
  let input = dae_result_edge_sparse_fixture(32, 2)
  dae_result_edge_sparse_check(input)
  let graph = dae_current_boundary_graph_new(input)
  let work = [0, 0, 0, 0]
  let facts = dae_boundary_dependency_graph_build(
    graph,
    result_edge_work=Some(work),
  )
  dae_result_edge_sparse_assert_equal(
    facts,
    dae_result_edge_sparse_reference(graph),
  )
  assert_eq(facts.result_forwarders_by_def[0].length(), 1)
  // Runtime RED must fail here, after all behavior and ownership checks above.
  // Counter zero is actual DaeAdjacencyKey lookups, not a predicted proxy.
  assert_eq(work[0], 0)
  assert_eq(work, [0, 0, 2, 1])
}

///|
test "DAE sparse result edges create no map when all result sites are dropped" {
  let input = dae_result_edge_sparse_fixture(32, 0)
  dae_result_edge_sparse_check(input)
  let work = [0, 0, 0, 0]
  let graph = dae_current_boundary_graph_new(input)
  let facts = dae_boundary_dependency_graph_build(
    graph,
    result_edge_work=Some(work),
  )
  dae_result_edge_sparse_assert_equal(
    facts,
    dae_result_edge_sparse_reference(graph),
  )
  assert_eq(work, [0, 0, 0, 0])
  for row in facts.result_forwarders_by_def {
    assert_eq(row, [])
  }
}

///|
test "DAE sparse result edges retain noncontiguous callers without repeated kind writes" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 1) (func) (func))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  for
    (caller, tail) in [
      (2, false),
      (1, true),
      (2, false),
      (1, false),
      (2, true),
      (1, true),
      (2, false),
    ] {
    graph.snapshot.function_infos[0].calls.push({
      caller_def: caller,
      path: DaeStablePath::empty(),
      callee_abs: 0,
      active: true,
      dropped: false,
      tail,
    })
  }
  let work = [0, 0, 0, 0]
  let facts = dae_boundary_dependency_graph_build(
    graph,
    result_edge_work=Some(work),
  )
  dae_result_edge_sparse_assert_equal(
    facts,
    dae_result_edge_sparse_reference(graph),
  )
  dae_result_edge_sparse_assert_equal(
    facts,
    dae_result_edge_sparse_array_reference(graph),
  )
  assert_eq(facts.return_callers_by_def, [[1, 2], [], []])
  assert_eq(facts.result_observers_by_def, [[2, 1], [], []])
  assert_eq(facts.result_forwarders_by_def, [[2, 1], [], []])
  assert_eq(facts.result_dependencies_by_def, [[], [0], [0]])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  // RED must reach these actual key/get/set/map work assertions after behavior.
  assert_eq(work, [0, 6, 4, 1])
}
