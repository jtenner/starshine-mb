///|
fn raw_forward_resource_plan(
  input : @lib.Module,
) -> (Dae2Graph, Dae2Function, Dae2RawPlan?) {
  let context = @ir.hot_module_context_from_module(input)
  let @lib.FuncType(params, results) = @ir.hot_module_resolve_func_type(
    context,
    @lib.FuncIdx::new(0U),
  ).unwrap()
  let graph = Dae2Graph::new()
  let info = Dae2Function::new(graph, params, results)
  let plan = dae2_raw_forward_dependency_plan(
    graph,
    [info],
    0,
    [],
    input.code_sec.unwrap().0[0],
    None,
    Some(context),
  )
  (graph, info, plan)
}

///|
fn raw_forward_repeated_function_targets(
  width : Int32,
  targets : Int32,
) -> @lib.Module {
  let params = Array::make(width + 2, "i32").join(" ")
  let results = Array::make(width, "i32").join(" ")
  let values = Array::makei(width, fn(i) { "local.get \{i}" }).join(" ")
  pass_test_module_from_wat(
    "(module (func (param \{params}) (result \{results}) \{values} local.get \{width} br_table \{Array::make(targets, "0").join(" ")}))",
  )
}

///|
test "DAE2 raw repeated implicit function targets retain payload demand with linear edges" {
  let width = 8
  let input = raw_forward_repeated_function_targets(width, 32)
  raw_conditional_compare_boundaries(input, 1)
  let (graph, info, candidate) = raw_forward_resource_plan(input)
  let plan = candidate.unwrap()
  assert_true(plan.sources.length() <= width)
  assert_true(plan.observations.length() <= width + 2)
  plan.commit(graph)
  graph.solve()
  for param in 0..<(width + 1) {
    assert_true(graph.used[info.param_locations[param]])
  }
  assert_false(graph.used[info.param_locations[width + 1]])
  assert_true(graph.used[info.result_location])
}

///|
fn raw_forward_identical_exits(width : Int32, branches : Int32) -> @lib.Module {
  let locals = Array::make(width, "i32").join(" ")
  let initial = Array::makei(width, fn(i) { "local.get 1 local.set \{i + 4}" }).join(
    " ",
  )
  let updated = Array::makei(width, fn(i) { "local.get 2 local.set \{i + 4}" }).join(
    " ",
  )
  let result = Array::makei(width, fn(i) { "local.get \{i + 4} i32.add" }).join(
    " ",
  )
  let exits = Array::make(branches, "local.get 0 br_if $out").join(" ")
  pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i32 i64) (result i32) (local \{locals}) \{initial} block $out local.get 0 br_if $out \{updated} \{exits} end i32.const 0 \{result}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
  )
}

///|
test "DAE2 raw identical forward exit states retain precise writes without repeated joins" {
  let width = 8
  let input = raw_forward_identical_exits(width, 16)
  raw_conditional_compare_boundaries(input, 2)
  for result_used in [false, true] {
    let (graph, info, candidate) = raw_forward_resource_plan(input)
    let plan = candidate.unwrap()
    assert_true(plan.count <= 4 * width + 2)
    assert_true(plan.sources.length() <= 8 * width + 8)
    plan.commit(graph)
    if result_used {
      graph.observe(info.result_location)
    }
    graph.solve()
    assert_true(graph.used[info.param_locations[0]])
    assert_eq(graph.used[info.param_locations[1]], result_used)
    assert_eq(graph.used[info.param_locations[2]], result_used)
    assert_false(graph.used[info.param_locations[3]])
    for (_, location) in plan.write_locations.unwrap() {
      assert_eq(graph.used[location], result_used)
    }
  }
}

///|
test "DAE2 raw exit cache preserves distinct payloads writes restores and merged assignments" {
  for
    body in [
      "block $out (result i32) local.get 1 local.get 0 br_if $out drop local.get 2 local.get 0 br_if $out drop i32.const 7 end",
      "local.get 1 local.set 4 block $out local.get 0 br_if $out local.get 1 local.set 4 local.get 0 br_if $out local.get 1 local.set 4 local.get 0 br_if $out end local.get 4",
      "local.get 1 local.set 4 block $out local.get 0 if local.get 2 local.set 4 br $out else br $out end end local.get 4",
      "local.get 1 local.set 4 block $out local.get 0 br_if $out local.get 0 if local.get 2 local.set 4 else i32.const 7 local.set 4 end local.get 0 br_if $out end local.get 4",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i32 i64) (result i32) (local i32) \{body}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
    )
    raw_conditional_compare_boundaries(input, 2)
  }
}

///|
fn raw_forward_nested_target_locals(
  depth : Int32,
  width : Int32,
) -> @lib.Module {
  let locals = Array::make(width, "i32").join(" ")
  let blocks = Array::makei(depth, fn(i) { "block $out\{i}" }).join(" ")
  let writes = Array::makei(width, fn(i) { "local.get 1 local.set \{i + 4}" }).join(
    " ",
  )
  let targets = Array::makei(depth, fn(i) { "$out\{i}" }).join(" ")
  let ends = Array::make(depth, "end").join(" ")
  let result = Array::makei(width, fn(i) { "local.get \{i + 4} i32.add" }).join(
    " ",
  )
  pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i32 i64) (result i32) (local \{locals}) \{blocks} \{writes} local.get 0 br_table \{targets} \{ends} i32.const 0 \{result}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
  )
}

///|
test "DAE2 raw resource guard intentionally delegates nested wide exit maps to HOT" {
  let small = raw_forward_nested_target_locals(2, 2)
  raw_conditional_compare_boundaries(small, 2)
  let input = raw_forward_nested_target_locals(32, 32)
  let (graph, info, plan) = raw_forward_resource_plan(input)
  // This intentionally unsupported raw shape needs depth times width state.
  // Qualification must stop atomically; HOT still performs the optimization.
  assert_true(plan is None)
  assert_eq(graph.used.length(), info.params.length() + 1)
  assert_eq(graph.edges.length(), 0)
  assert_eq(graph.work.length(), 0)
  raw_conditional_compare_boundaries(input, 1)
  let output = dae2_run_module_pass(input, false).unwrap()
  let @lib.FuncType(params, _) = @ir.hot_module_resolve_func_type(
    @ir.hot_module_context_from_module(output),
    @lib.FuncIdx::new(0U),
  ).unwrap()
  assert_eq(params.length(), 2)
}
