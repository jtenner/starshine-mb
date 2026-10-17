///|
test "DAE discovery skips ineligible siblings and keeps the one real rewrite without an index" {
  let input = dae_s10_single_target_input()
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let stats = [0, 0, 0, 0]
  let actual = dae_collect_exact_literal_candidate_defs_with_facts(
    input,
    graph.snapshot.call_facts,
    -1,
    syntax_stats=Some(stats),
  )
  let expected = dae_s10_frozen_discovery_reference(
    input,
    graph.snapshot.call_facts,
    -1,
  )
  assert_eq(actual, [0])
  dae_s10_assert_discovery_output(input, actual, expected, saved)
  // Nullary, dead-parameter and written-only siblings cannot enter this list.
  assert_eq(stats, [0, 0, 0, 0])
}

///|
test "DAE discovery filters unrelated imported and defined calls while keeping all literal rewrites" {
  let input = dae_s10_discovery_input(16, false)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let stats = [0, 0, 0, 0]
  let actual = dae_s11_forced_filtered_discovery(
    input,
    graph.snapshot.call_facts,
    -1,
    syntax_stats=Some(stats),
  )
  let expected = dae_s10_frozen_discovery_reference(
    input,
    graph.snapshot.call_facts,
    -1,
  )
  assert_eq(actual, [1, 2, 3])
  dae_s10_assert_discovery_output(input, actual, expected, saved)
  assert_eq(stats[0], 1)
  assert_true(stats[2] > 0)
  assert_eq(stats[3], 3)
}

///|
test "DAE discovery retains ineligible forwarding ancestors through typed catches" {
  for catch_wrapped in [false, true] {
    let input = dae_s10_discovery_input(4, true, catch_wrapped~)
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let graph = dae_current_boundary_graph_new(input)
    let stats = [0, 0, 0, 0]
    let actual = dae_s11_forced_filtered_discovery(
      input,
      graph.snapshot.call_facts,
      -1,
      syntax_stats=Some(stats),
    )
    let expected = dae_s10_frozen_discovery_reference(
      input,
      graph.snapshot.call_facts,
      -1,
    )
    // The forwarder has a dead second parameter, yet its actuals prove both
    // leaf constants. Filtering only final candidates would lose this proof.
    assert_eq(actual, [1, 2])
    dae_s10_assert_discovery_output(input, actual, expected, saved)
    assert_eq(stats[0], 1)
    assert_true(stats[2] > 0)
    assert_eq(stats[3], if catch_wrapped { 4 } else { 3 })
  }
}

///|
fn dae_s10_filtered_scan(
  input : @lib.Module,
  graph : DaeCurrentBoundaryGraph,
  body : Array[@lib.Instruction],
  indexed : Bool,
  include_target : Bool,
) -> (
  (Bool, Array[Bool], Array[Bool], Array[@lib.Instruction?], Array[Int32]),
  Array[Int32],
) {
  let targets : @hashmap.HashMap[Int32, Bool] = @hashmap.new()
  targets.set(if include_target { 0 } else { 1 }, true)
  let stats = [0, 0, 0, 0]
  let query = DaeUniformSyntaxQuery::new(
    input,
    graph.snapshot.type_indices,
    graph.snapshot.boundary_facts,
    indexed,
    targets=Some(targets),
    syntax_stats=Some(stats),
  )
  let seen = [false]
  let invalid = [false]
  let candidates : Array[@lib.Instruction?] = [None]
  let tags : Array[Int32] = []
  let ok = dae_collect_uniform_const_actuals_instrs(
    body,
    0,
    [@lib.ValType::i32()],
    0,
    2,
    input,
    graph.snapshot.type_indices,
    graph.snapshot.boundary_facts,
    Array::make(graph.snapshot.total, false),
    seen,
    invalid,
    candidates,
    syntax_query=Some(query),
    legacy_tag_entries=Some(tags),
  )
  ((ok, seen, invalid, candidates, tags), stats)
}

///|
test "DAE filtered calls keep real literal output and intentional failure barriers in catch order" {
  let input = pass_test_module_from_wat(
    "(module (tag $e (param i32)) (func $h (param i32) (result i32) local.get 0) (func $noise) (func (export \"run\") (try (do i32.const 7 call $h drop call $noise) (catch $e drop i32.const 7 call $h drop call $noise))))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let expected_defs = dae_s10_frozen_discovery_reference(
    input,
    graph.snapshot.call_facts,
    -1,
  )
  assert_eq(expected_defs, [0])
  dae_s10_assert_discovery_output(input, [0], expected_defs, saved)
  let @lib.Func(_, @lib.Expr(original)) = graph.snapshot.funcs[2]
  let early_invalid = [@lib.Instruction::call(@lib.FuncIdx::new(0U))]
  early_invalid.append(original)
  let late_invalid = original.copy()
  late_invalid.push(
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(999U)),
      @lib.Expr::new([]),
    ),
  )
  // The second and third bodies are intentionally invalid analysis inputs.
  // Earlier candidate writes and typed-catch cache writes still match exactly.
  let bodies = [original, early_invalid, late_invalid]
  for i in 0..<bodies.length() {
    let body = bodies[i]
    let (expected, _) = dae_s10_filtered_scan(input, graph, body, false, true)
    let (actual, stats) = dae_s10_filtered_scan(input, graph, body, true, true)
    assert_eq(actual, expected)
    let (ok, seen, invalid, candidates, tags) = actual
    assert_eq(ok, i == 0)
    assert_eq(seen, [i != 1])
    assert_eq(invalid, [false])
    assert_eq(
      candidates,
      if i == 1 {
        [None]
      } else {
        [Some(@lib.Instruction::i32_const(@lib.I32(7)))]
      },
    )
    assert_eq(tags, if i == 1 { [] } else { [1] })
    assert_eq(stats[3], if i == 1 { 3 } else { 2 })
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
  // An explicit query outside its private interest set must use the retained
  // visitor, including all catch effects, rather than return an empty proof.
  let (actual, stats) = dae_s10_filtered_scan(
    input, graph, original, true, false,
  )
  let (expected, _) = dae_s10_filtered_scan(
    input, graph, original, false, false,
  )
  assert_eq(actual, expected)
  assert_eq(stats[3], 0)
}
