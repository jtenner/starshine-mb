///|
fn dae_review_assert_dependencies(
  actual : DaeBoundaryDependencyGraph,
  expected : DaeBoundaryDependencyGraph,
) -> Unit raise {
  assert_eq(actual.callers_by_def, expected.callers_by_def)
  assert_eq(actual.callees_by_def, expected.callees_by_def)
  assert_eq(actual.return_callers_by_def, expected.return_callers_by_def)
  assert_eq(
    actual.parameter_forwarding_edges,
    expected.parameter_forwarding_edges,
  )
  assert_eq(
    actual.parameter_forwarders_by_def,
    expected.parameter_forwarders_by_def,
  )
  assert_eq(actual.result_forwarders_by_def, expected.result_forwarders_by_def)
  assert_eq(
    actual.result_dependencies_by_def,
    expected.result_dependencies_by_def,
  )
  assert_eq(actual.result_observers_by_def, expected.result_observers_by_def)
  assert_eq(actual.component_by_def, expected.component_by_def)
  assert_eq(actual.component_members, expected.component_members)
  assert_eq(
    actual.forwarding_component_by_def,
    expected.forwarding_component_by_def,
  )
  assert_eq(
    actual.forwarding_component_members,
    expected.forwarding_component_members,
  )
}

///|
test "DAE forwarding syntax reuse checks current signatures for inactive tail calls" {
  let input = pass_test_module_from_wat(
    "(module (func $target (param i32 i32) (result i32) local.get 0) " +
    "(func (param i32) (result i32) unreachable local.get 0 i32.const 7 return_call $target))",
  )
  let graph = dae_current_boundary_graph_new(input)
  let first = dae_boundary_dependency_graph_new(graph)
  assert_eq(first.parameter_forwarding_edges.length(), 1)
  let cached = graph.forwarding_syntax[1].unwrap()
  let types = input.func_sec.unwrap().0.copy()
  types[0] = types[1]
  let reduced = input.with_func_sec(@lib.FuncSec::new(types))
  @validate.validate_module(reduced).unwrap()
  for next in [reduced, input] {
    assert_true(
      dae_try_refresh_current_boundary_graph_incremental(
        graph,
        next,
        forced_changed_defs=Some([true, false]),
      ),
    )
    let actual = dae_boundary_dependency_graph_new(graph)
    dae_review_assert_dependencies(
      actual,
      dae_review_dependency_reference(graph),
    )
    assert_true(physical_equal(cached, graph.forwarding_syntax[1].unwrap()))
    assert_eq(
      actual.parameter_forwarding_edges.length(),
      if physical_equal(next, input) {
        1
      } else {
        0
      },
    )
  }
}

///|
test "DAE forwarding syntax invalidates forced aliased bodies" {
  let input = pass_test_module_from_wat(
    "(module (func $target (param i32) (result i32) local.get 0) " +
    "(func (param i32) (result i32) local.get 0 call $target))",
  )
  let graph = dae_current_boundary_graph_new(input)
  assert_eq(
    dae_boundary_dependency_graph_new(graph).parameter_forwarding_edges.length(),
    1,
  )
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[1]
  body[0] = @lib.Instruction::i32_const(7)
  assert_true(
    dae_try_refresh_current_boundary_graph_incremental(
      graph,
      input,
      forced_changed_defs=Some([false, true]),
    ),
  )
  let actual = dae_boundary_dependency_graph_new(graph)
  dae_review_assert_dependencies(actual, dae_review_dependency_reference(graph))
  assert_eq(actual.parameter_forwarding_edges.length(), 0)
}

///|
fn dae_review_dependency_bench(it : @bench.T, reference : Bool) -> Unit raise {
  let padding = Array::make(128, "local.get 0 drop").join(" ")
  let callers = Array::make(
    64,
    "(func (param i32) (result i32) \{padding} local.get 0 call $target)",
  ).join(" ")
  let input = pass_test_module_from_wat(
    "(module (func $target (param i32) (result i32) local.get 0) \{callers})",
  )
  let graph = dae_current_boundary_graph_new(input)
  let expected = dae_review_dependency_reference(graph)
  let actual = dae_boundary_dependency_graph_new(graph)
  dae_review_assert_dependencies(actual, expected)
  assert_eq(actual.parameter_forwarding_edges.length(), 64)
  it.bench(fn() {
    it.keep(
      if reference {
        dae_review_dependency_reference(graph)
      } else {
        dae_boundary_dependency_graph_build(graph)
      },
    )
  })
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE forwarding dependency body-walk reference" (it : @bench.T) {
  dae_review_dependency_bench(it, true)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE forwarding dependency cached syntax" (it : @bench.T) {
  dae_review_dependency_bench(it, false)
}

///|
test "DAE shared call-count syntax retains inactive-tail and legacy-control rules" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (func $target (param i32) (result i32) local.get 0)
      #|   (func (param i32) (result i32)
      #|     local.get 0 if (result i32)
      #|       local.get 0 call $target
      #|     else local.get 0 call $target end)
      #|   (func (param i32) (result i32)
      #|     unreachable local.get 0 return_call $target)
      #|   (func (param i32)
      #|     (try (do local.get 0 call $target drop)
      #|       (catch_all local.get 0 call $target drop))))
    ),
  )
  let graph = dae_current_boundary_graph_new(input)
  let actual = dae_collect_cached_module_call_counts(graph)
  assert_eq(actual, [2, 0, 0, 0])
  assert_eq(
    actual,
    dae_collect_module_call_counts_anywhere(
      input.code_sec.unwrap().0,
      graph.snapshot.imported,
      graph.snapshot.defined,
    ),
  )
}

///|
test "DAE call-count cache uses the raw scanner for intentionally invalid block types" {
  let input = pass_test_module_from_wat(
    "(module (func $target) (func block call $target end))",
  )
  let funcs = input.code_sec.unwrap().0.copy()
  funcs[1] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(99U)),
        @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
      ),
    ]),
  )
  let invalid = input.with_code_sec(@lib.CodeSec::new(funcs))
  assert_true(@validate.validate_module(invalid) is Err(_))
  let graph = dae_current_boundary_graph_new(invalid)
  assert_eq(dae_collect_cached_module_call_counts(graph), [1, 0])
  assert_false(graph.forwarding_syntax[1].unwrap().complete)
}

///|
fn dae_review_call_count_bench(it : @bench.T, reference : Bool) -> Unit raise {
  let padding = Array::make(128, "local.get 0 drop").join(" ")
  let callers = Array::make(64, "(func (param i32) \{padding} call $target)").join(
    " ",
  )
  let input = pass_test_module_from_wat("(module (func $target) \{callers})")
  let graph = dae_current_boundary_graph_new(input)
  let expected = dae_collect_module_call_counts_anywhere(
    input.code_sec.unwrap().0,
    0,
    65,
  )
  let actual = dae_collect_cached_module_call_counts(graph)
  assert_eq(actual, expected)
  assert_eq(actual[0], 64)
  it.bench(fn() {
    it.keep(
      if reference {
        dae_collect_module_call_counts_anywhere(
          input.code_sec.unwrap().0,
          0,
          65,
        )
      } else {
        dae_collect_cached_module_call_counts(graph)
      },
    )
  })
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE call-count body-walk reference" (it : @bench.T) {
  dae_review_call_count_bench(it, true)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE call-count shared syntax" (it : @bench.T) {
  dae_review_call_count_bench(it, false)
}
