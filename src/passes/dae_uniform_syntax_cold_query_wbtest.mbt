///|
fn dae_syntax_cold_input(calls : Int32, forwarded : Bool) -> @lib.Module {
  let wat = StringBuilder()
  wat.write_string(
    "(module (import \"m\" \"tick\" (func $tick)) (func $h (param i32) (result i32) local.get 0) ",
  )
  if forwarded {
    wat.write_string(
      "(func $forward (param i32) (result i32) local.get 0 call $h) ",
    )
  }
  wat.write_string("(func (export \"run\") (result i32) ")
  for _ in 0..<calls {
    wat.write_string("call $tick ")
  }
  wat.write_string("i32.const 7 call ")
  wat.write_string(if forwarded { "$forward))" } else { "$h))" })
  pass_test_module_from_wat(wat.to_string()).with_custom_secs([
    @lib.CustomSec::new(@lib.Name::new("syntax.cold.keep"), b"unchanged"),
  ])
}

///|
fn dae_syntax_cold_rewrite(
  graph : DaeCurrentBoundaryGraph,
  values : Array[@lib.Instruction?]?,
) -> DaePassResult {
  let target = graph.snapshot.imported
  dae_try_rewrite_candidate(
    graph.mod_,
    target,
    [true],
    values.unwrap(),
    dae_local_use_for_callee(graph.snapshot.funcs[0], 1, target, 1),
    graph.snapshot.boundary_facts.direct_calls[target],
    graph.snapshot.boundary_facts.direct_callers[target],
  )
}

///|
fn dae_syntax_cold_assert_rewrite(
  input : @lib.Module,
  actual : Array[@lib.Instruction?]?,
  expected : Array[@lib.Instruction?]?,
  saved : Bytes,
) -> Unit raise {
  assert_eq(actual, Some([Some(@lib.Instruction::i32_const(@lib.I32(7)))]))
  assert_eq(actual, expected)
  let graph = dae_current_boundary_graph_new(input)
  let output = dae_syntax_cold_rewrite(graph, actual)
  let reference = dae_syntax_cold_rewrite(graph, expected)
  assert_true(output.changed)
  assert_eq(output.primary_def, 0)
  assert_eq(output.touched, reference.touched)
  @validate.validate_module(output.mod_out).unwrap()
  let item = dae_work_item_new(
    graph,
    dae_boundary_dependency_graph_new(graph),
    0,
    DaeUniformActualWork,
  )
  assert_eq(
    dae_work_item_candidate_effects(input, graph, item, output),
    dae_work_item_candidate_effects(input, graph, item, reference),
  )
  let after = dae_current_boundary_graph_new(output.mod_out)
  assert_eq(
    after.snapshot.function_types[graph.snapshot.imported],
    Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
  )
  let @lib.Func(locals, @lib.Expr(body)) = after.snapshot.funcs[0]
  assert_eq(locals.length(), 0)
  assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(7))])
  assert_eq(
    @binary.encode_module(output.mod_out).unwrap(),
    @binary.encode_module(reference.mod_out).unwrap(),
  )
  assert_eq(output.mod_out.custom_secs, input.custom_secs)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE normal boundary query keeps the literal rewrite without a cold index" {
  for calls in [0, 16] {
    let input = dae_syntax_cold_input(calls, true)
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let graph = dae_current_boundary_graph_new(input)
    let stats = [0, 0, 0, 0]
    let actual = dae_collect_uniform_const_actuals_from_boundary_facts(
      input,
      graph.snapshot.imported,
      1,
      graph.snapshot.type_indices,
      graph.snapshot.boundary_facts,
      syntax_stats=Some(stats),
    )
    let expected = dae_s6_uniform_reference_collect_uniform_const_actuals_from_boundary_facts(
      input,
      graph.snapshot.imported,
      1,
      graph.snapshot.type_indices,
      graph.snapshot.boundary_facts,
    )
    dae_syntax_cold_assert_rewrite(input, actual, expected, saved)
    // These checks follow real output/effect/ownership checks. The normal
    // query must allocate neither a query owner nor caller/call rows.
    assert_eq(stats, [0, 0, 0, 0])
  }
}

///|
test "DAE direct stable-path literal rewrite creates no unused syntax owner" {
  let input = dae_syntax_cold_input(0, false)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let stats = [0, 0, 0, 0]
  let resolutions = [0, 0, 0, 0, 0]
  let actual = dae_collect_uniform_const_actuals_from_function_infos(
    input,
    graph.snapshot.imported,
    1,
    graph.snapshot.type_indices,
    graph.snapshot.boundary_facts,
    graph.snapshot.function_infos,
    stable_callsite_resolutions=Some(resolutions),
    syntax_stats=Some(stats),
  )
  let expected = dae_s6_uniform_reference_collect_uniform_const_actuals_from_function_infos(
    input,
    graph.snapshot.imported,
    1,
    graph.snapshot.type_indices,
    graph.snapshot.boundary_facts,
    graph.snapshot.function_infos,
  )
  dae_syntax_cold_assert_rewrite(input, actual, expected, saved)
  assert_true(resolutions[3] > 0)
  assert_eq(stats, [0, 0, 0, 0])
}
