///|
fn dae_uniform_syntax_test_query(
  graph : DaeCurrentBoundaryGraph,
  indexed : Bool,
) -> DaeUniformSyntaxQuery {
  DaeUniformSyntaxQuery::new(
    graph.mod_,
    graph.snapshot.type_indices,
    graph.snapshot.boundary_facts,
    indexed,
    syntax_visits=Some([0]),
  )
}

///|
fn dae_uniform_syntax_fixture(debris : Int32) -> @lib.Module {
  let wat = StringBuilder()
  wat.write_string(
    "(module (func $a (param i32) (result i32) local.get 0) (func $b (param i32) (result i32) local.get 0) (func $forward (param i32) (result i32) local.get 0 call $a drop local.get 0 call $b) (func (export \"run\") (result i32) ",
  )
  for _ in 0..<debris {
    wat.write_string("nop ")
  }
  wat.write_string("i32.const 7 call $forward))")
  pass_test_module_from_wat(wat.to_string()).with_custom_secs([
    @lib.CustomSec::new(@lib.Name::new("syntax.keep"), b"unchanged"),
  ])
}

///|
fn dae_uniform_syntax_assert_values_equal(
  actual : Array[@lib.Instruction?]?,
  expected : Array[@lib.Instruction?]?,
) -> Unit raise {
  match (actual, expected) {
    (Some(actual), Some(expected)) => {
      assert_eq(actual.length(), expected.length())
      for p in 0..<actual.length() {
        match (actual[p], expected[p]) {
          (Some(a), Some(b)) => assert_true(dae_materialized_const_equal(a, b))
          (None, None) => ()
          _ => fail("different optional uniform literal")
        }
      }
    }
    (None, None) => ()
    _ => fail("different optional uniform proof")
  }
}

///|
fn dae_uniform_syntax_rewrite(
  graph : DaeCurrentBoundaryGraph,
  callee : Int32,
  values : Array[@lib.Instruction?]?,
) -> DaePassResult {
  let values = values.unwrap()
  dae_try_rewrite_candidate(
    graph.mod_,
    callee,
    [true],
    values,
    dae_local_use_for_callee(graph.snapshot.funcs[callee], 1, callee, 1),
    graph.snapshot.boundary_facts.direct_calls[callee],
    graph.snapshot.boundary_facts.direct_callers[callee],
  )
}

///|
test "DAE syntax index is private to read-only candidate discovery" {
  let input = dae_uniform_syntax_fixture(32)
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let indexed_visits = [0]
  let reference_visits = [0]
  let actual = dae_s11_forced_filtered_discovery(
    input,
    graph.snapshot.call_facts,
    -1,
    syntax_visits=Some(indexed_visits),
  )
  let expected = dae_collect_exact_literal_candidate_defs_with_facts(
    input,
    graph.snapshot.call_facts,
    -1,
    indexed_syntax=false,
    syntax_visits=Some(reference_visits),
  )
  assert_eq(actual, [0, 1, 2])
  assert_eq(actual, expected)
  assert_true(indexed_visits[0] < reference_visits[0])
  let output = dae_run_exact_literal_candidate_worklist_with_facts(
    input,
    Array::make(graph.snapshot.defined, false),
    false,
    actual,
  )
  let reference_input = dae_uniform_syntax_fixture(32)
  let scalar = dae_run_exact_literal_candidate_worklist_with_facts(
    reference_input,
    Array::make(graph.snapshot.defined, false),
    false,
    expected,
  )
  assert_true(output.changed)
  assert_eq(output.productive_defs, scalar.productive_defs)
  assert_eq(output.touched, scalar.touched)
  assert_eq(output.effects, scalar.effects)
  @validate.validate_module(output.mod_out).unwrap()
  assert_eq(
    @binary.encode_module(output.mod_out).unwrap(),
    @binary.encode_module(scalar.mod_out).unwrap(),
  )
  assert_eq(output.mod_out.custom_secs, input.custom_secs)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(@binary.encode_module(reference_input).unwrap(), saved)
}

///|
test "DAE syntax index falls back for intentionally mismatched module ownership" {
  let input = dae_uniform_syntax_fixture(0)
  let graph = dae_current_boundary_graph_new(input)
  let query = dae_uniform_syntax_test_query(graph, true)
  assert_eq(
    dae_uniform_syntax_query_values(query, graph, 0, 1),
    Some([Some(@lib.Instruction::i32_const(@lib.I32(7)))]),
  )
  let changed = pass_test_module_from_wat(
    "(module (func $h (param i32)) (func (export \"run\") i32.const 11 call $h))",
  )
  let changed_graph = dae_current_boundary_graph_new(changed)
  let saved = @binary.encode_module(changed).unwrap()
  // A context belongs to one exact source. A mismatched source must never
  // receive cached locations, even if its function indices happen to match.
  assert_eq(
    dae_uniform_syntax_query_values(query, changed_graph, 0, 1),
    Some([Some(@lib.Instruction::i32_const(@lib.I32(11)))]),
  )
  assert_eq(@binary.encode_module(changed).unwrap(), saved)
}

///|
test "DAE syntax index shares caller walks while preserving real literal rewrites" {
  let input = dae_uniform_syntax_fixture(32)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let indexed = dae_uniform_syntax_test_query(graph, true)
  let reference = dae_uniform_syntax_test_query(graph, false)
  let mut first_visits = 0
  let actual_values : Array[Array[@lib.Instruction?]?] = []
  let expected_values : Array[Array[@lib.Instruction?]?] = []
  for target in 0..<2 {
    let actual = dae_uniform_syntax_query_values(indexed, graph, target, 1)
    let expected = dae_uniform_syntax_query_values(reference, graph, target, 1)
    assert_eq(actual, Some([Some(@lib.Instruction::i32_const(@lib.I32(7)))]))
    dae_uniform_syntax_assert_values_equal(actual, expected)
    actual_values.push(actual)
    expected_values.push(expected)
    if target == 0 {
      first_visits = indexed.syntax_visits.unwrap()[0]
      assert_true(first_visits > 0)
    }
  }
  // All source analysis ends before the first rewrite/commit.
  for target in 0..<2 {
    let actual = actual_values[target]
    let expected = expected_values[target]
    let output = dae_uniform_syntax_rewrite(graph, target, actual)
    let scalar = dae_uniform_syntax_rewrite(graph, target, expected)
    assert_true(output.changed)
    assert_eq(output.touched, scalar.touched)
    @validate.validate_module(output.mod_out).unwrap()
    assert_eq(
      @binary.encode_module(output.mod_out).unwrap(),
      @binary.encode_module(scalar.mod_out).unwrap(),
    )
    let after = dae_current_boundary_graph_new(output.mod_out)
    assert_eq(
      after.snapshot.function_types[target],
      Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
    )
    let @lib.Func(_, @lib.Expr(body)) = after.snapshot.funcs[target]
    assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(7))])
    assert_eq(output.mod_out.custom_secs, input.custom_secs)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
  // Both callees use the same two caller bodies. Semantic resolution still
  // runs twice, but the immutable source syntax is walked only once.
  assert_eq(indexed.syntax_visits.unwrap()[0], first_visits)
  assert_true(
    indexed.syntax_visits.unwrap()[0] < reference.syntax_visits.unwrap()[0],
  )
}

///|
test "DAE syntax index preserves visited-context rejection for mutual cycles" {
  let input = pass_test_module_from_wat(
    "(module (func $leaf (param i32) (result i32) local.get 0) (func $a (param i32) (result i32) local.get 0 call $leaf drop local.get 0 call $b) (func $b (param i32) (result i32) local.get 0 call $a) (func (export \"run\") (result i32) i32.const 7 call $a))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  for indexed in [false, true] {
    let query = dae_uniform_syntax_test_query(graph, indexed)
    assert_eq(dae_uniform_syntax_query_values(query, graph, 0, 1), Some([None]))
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE syntax index preserves typed nested scopes and inactive suffix calls" {
  for
    wat in [
      "(module (type $block (func (param i32) (result i32))) (func $h (param i32) (result i32) local.get 0) (func (export \"run\") (result i32) i32.const 9 block (type $block) i32.const 7 call $h i32.add end))",
      "(module (func $h (param i32)) (func (export \"run\") i32.const 7 call $h unreachable i32.const 8 call $h))",
      "(module (import \"m\" \"tick\" (func $tick)) (func $h (param i32)) (func (export \"run\") i32.const 7 call $tick call $h))",
      "(module (tag $e (param i32)) (func $h (param i32)) (func (export \"run\") (try (do (i32.const 7) (call $h)) (catch $e (call $h)))))",
    ] {
    let input = pass_test_module_from_wat(wat)
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let graph = dae_current_boundary_graph_new(input)
    let target = graph.snapshot.imported
    let actual = dae_uniform_syntax_query_values(
      dae_uniform_syntax_test_query(graph, true),
      graph,
      target,
      1,
    )
    let expected = dae_uniform_syntax_query_values(
      dae_uniform_syntax_test_query(graph, false),
      graph,
      target,
      1,
    )
    dae_uniform_syntax_assert_values_equal(actual, expected)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE syntax index preserves ref.func indices and source ownership" {
  for actuals in ["ref.func $f ref.func $f", "ref.func $f ref.func $g"] {
    let input = pass_test_module_from_wat(
      "(module (func $f) (func $g) (elem declare func $f $g) (func $h (param funcref funcref)) (func (export \"run\") \{actuals} call $h))",
    )
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let graph = dae_current_boundary_graph_new(input)
    let actual = dae_uniform_syntax_query_values(
      dae_uniform_syntax_test_query(graph, true),
      graph,
      2,
      2,
    )
    let expected = dae_uniform_syntax_query_values(
      dae_uniform_syntax_test_query(graph, false),
      graph,
      2,
      2,
    )
    dae_uniform_syntax_assert_values_equal(actual, expected)
    let values = actual.unwrap()
    assert_eq(
      values[0],
      Some(@lib.Instruction::ref_func(@lib.FuncIdx::new(0U))),
    )
    assert_eq(
      values[1],
      Some(
        @lib.Instruction::ref_func(
          @lib.FuncIdx::new(
            if actuals == "ref.func $f ref.func $f" {
              0U
            } else {
              1U
            },
          ),
        ),
      ),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE syntax index preserves literal bits and the immutable-global option" {
  for literal in ["f64.const nan:0x123", "f64.const -0", "f64.const 0"] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param f64)) (func (export \"run\") \{literal} call $h))",
    )
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let graph = dae_current_boundary_graph_new(input)
    let actual = dae_uniform_syntax_query_values(
      dae_uniform_syntax_test_query(graph, true),
      graph,
      0,
      1,
    )
    let expected = dae_uniform_syntax_query_values(
      dae_uniform_syntax_test_query(graph, false),
      graph,
      0,
      1,
    )
    dae_uniform_syntax_assert_values_equal(actual, expected)
    assert_true(actual.unwrap()[0] is Some(@lib.F64Const(_)))
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
  let input = pass_test_module_from_wat(
    "(module (global $g i32 (i32.const 7)) (func $h (param i32)) (func (export \"run\") global.get $g call $h))",
  )
  let graph = dae_current_boundary_graph_new(input)
  for allow in [false, true] {
    let actual = dae_uniform_syntax_query_values(
      dae_uniform_syntax_test_query(graph, true),
      graph,
      0,
      1,
      allow_immutable_global_get=allow,
    )
    let expected = dae_uniform_syntax_query_values(
      dae_uniform_syntax_test_query(graph, false),
      graph,
      0,
      1,
      allow_immutable_global_get=allow,
    )
    dae_uniform_syntax_assert_values_equal(actual, expected)
    assert_eq(actual.unwrap()[0].is_some(), allow)
  }
}

///|
test "DAE syntax index preserves partial candidates before an intentionally invalid control barrier" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32)) (func (export \"run\") i32.const 7 call $h))",
  )
  let graph = dae_current_boundary_graph_new(input)
  let @lib.Func(_, @lib.Expr(original)) = graph.snapshot.funcs[1]
  let body = original.copy()
  body.push(
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(999U)),
      @lib.Expr::new([]),
    ),
  )
  let saved = body.copy()
  for indexed in [false, true] {
    let seen = [false]
    let invalid = [false]
    let candidates = [None]
    let ok = dae_collect_uniform_const_actuals_instrs(
      body,
      0,
      [@lib.ValType::i32()],
      0,
      1,
      input,
      graph.snapshot.type_indices,
      graph.snapshot.boundary_facts,
      Array::make(graph.snapshot.total, false),
      seen,
      invalid,
      candidates,
      syntax_query=Some(dae_uniform_syntax_test_query(graph, indexed)),
    )
    assert_false(ok)
    assert_eq(seen, [true])
    assert_eq(invalid, [false])
    assert_eq(candidates, [Some(@lib.Instruction::i32_const(@lib.I32(7)))])
    assert_eq(body, saved)
  }
}

///|
test "DAE syntax index preserves catch cache ordering before an intentionally invalid earlier call" {
  let input = pass_test_module_from_wat(
    "(module (tag $e (param i32)) (func $h (param i32)) (func (export \"run\") (try (do (i32.const 7) (call $h)) (catch $e (call $h)))))",
  )
  @validate.validate_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let @lib.Func(_, @lib.Expr(original)) = graph.snapshot.funcs[1]
  // Intentionally invalid call before the first catch. The retained visitor
  // fails before catch admission can initialize its supplied tag cache.
  let body = [@lib.Instruction::call(@lib.FuncIdx::new(0U))]
  body.append(original)
  for indexed in [false, true] {
    let tags : Array[Int32] = []
    let seen = [false]
    let candidates = [None]
    assert_false(
      dae_collect_uniform_const_actuals_instrs(
        body,
        0,
        [@lib.ValType::i32()],
        0,
        1,
        input,
        graph.snapshot.type_indices,
        graph.snapshot.boundary_facts,
        Array::make(graph.snapshot.total, false),
        seen,
        [false],
        candidates,
        syntax_query=Some(dae_uniform_syntax_test_query(graph, indexed)),
        legacy_tag_entries=Some(tags),
      ),
    )
    assert_eq(seen, [false])
    assert_eq(candidates, [None])
    assert_eq(tags, [])
  }
}

///|
test "DAE syntax index guards intentionally different supplied catch cache values" {
  let input = pass_test_module_from_wat(
    "(module (tag $e (param i32)) (func $h (param i32)) (func (export \"run\") (try (do) (catch $e (call $h)))))",
  )
  @validate.validate_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let @lib.Func(_, @lib.Expr(body)) = graph.snapshot.funcs[1]
  let indexed = dae_uniform_syntax_test_query(graph, true)
  let reference = dae_uniform_syntax_test_query(graph, false)
  for supplied in [0, 1] {
    let mut expected_ok = false
    for query in [reference, indexed] {
      let tags = [supplied]
      let seen = [false]
      let invalid = [false]
      let candidates = [None]
      let ok = dae_collect_uniform_const_actuals_instrs(
        body,
        0,
        [@lib.ValType::i32()],
        0,
        1,
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
      if physical_equal(query, reference) {
        expected_ok = ok
      }
      assert_eq(ok, expected_ok)
      assert_eq(ok, supplied == 1)
      assert_eq(tags, [supplied])
      assert_eq(seen, [false])
      assert_eq(candidates, [None])
      assert_eq(invalid, [supplied == 1])
    }
  }
}

///|
test "DAE syntax index replays nested catch initialization before a later invalid barrier" {
  let input = pass_test_module_from_wat(
    "(module (tag $e (param i32)) (func $h (param i32)) (func (export \"run\") (try (do (i32.const 7) (call $h)) (catch $e drop (try (do (i32.const 7) (call $h)) (catch $e drop (i32.const 7) (call $h)))))))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let @lib.Func(_, @lib.Expr(original)) = graph.snapshot.funcs[1]
  let body = original.copy()
  body.push(
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(999U)),
      @lib.Expr::new([]),
    ),
  )
  for indexed in [false, true] {
    let tags : Array[Int32] = []
    let seen = [false]
    let invalid = [false]
    let candidates = [None]
    assert_false(
      dae_collect_uniform_const_actuals_instrs(
        body,
        0,
        [@lib.ValType::i32()],
        0,
        1,
        input,
        graph.snapshot.type_indices,
        graph.snapshot.boundary_facts,
        Array::make(graph.snapshot.total, false),
        seen,
        invalid,
        candidates,
        syntax_query=Some(dae_uniform_syntax_test_query(graph, indexed)),
        legacy_tag_entries=Some(tags),
      ),
    )
    assert_eq(tags, [1])
    assert_eq(seen, [true])
    assert_eq(invalid, [false])
    assert_eq(candidates, [Some(@lib.Instruction::i32_const(@lib.I32(7)))])
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
