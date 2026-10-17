///|
test "DAE measured adverse caller sizes preserve productive bytes without a cold shared index" {
  for pairs in [16, 32, 64] {
    let input = dae_s10_discovery_input(pairs, false)
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
    assert_eq(actual, [1, 2, 3])
    dae_s10_assert_discovery_output(input, actual, expected, saved)
    // Resource assertion follows actual output/order/effect/ownership checks.
    assert_eq(stats, [0, 0, 0, 0])
  }
}

///|
test "DAE measured adverse low-call widths preserve productive output without a shared index" {
  for width in [8, 16] {
    for nested in [false, true] {
      let input = dae_s11_multi_query_input(width, nested)
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
      assert_eq(actual, [0, 1, 2])
      dae_s10_assert_discovery_output(input, actual, expected, saved)
      assert_eq(stats, [0, 0, 0, 0])
    }
  }
}

///|
test "DAE tiny typed-catch discovery keeps ordered productive output without an index" {
  let input = dae_s10_discovery_input(4, true, catch_wrapped=true)
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
  assert_eq(actual, [1, 2])
  dae_s10_assert_discovery_output(input, actual, expected, saved)
  assert_eq(stats, [0, 0, 0, 0])
}

///|
fn dae_s11_wrap_last_body(input : @lib.Module) -> @lib.Module {
  let funcs = match input.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs.copy()
    None => abort("fixture requires code")
  }
  let last = funcs.length() - 1
  let @lib.Func(locals, @lib.Expr(body)) = funcs[last]
  funcs[last] = @lib.Func::new(
    locals,
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new(body),
      ),
    ]),
  )
  input.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
test "DAE measured winning width32 retains productive shared discovery" {
  for nested in [false, true] {
    let input = dae_s11_multi_query_input(32, nested)
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
    assert_eq(actual, [0, 1, 2])
    dae_s10_assert_discovery_output(input, actual, expected, saved)
    assert_eq(stats[0], 1)
    assert_true(stats[2] > 0)
  }
}

///|
test "DAE winning large caller stays indexed through nested and ineligible ancestors" {
  for dead_forward in [false, true] {
    for nested in [false, true] {
      let plain = dae_s10_discovery_input(128, dead_forward)
      let input = if nested { dae_s11_wrap_last_body(plain) } else { plain }
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
      assert_eq(actual, if dead_forward { [1, 2] } else { [1, 2, 3] })
      dae_s10_assert_discovery_output(input, actual, expected, saved)
      assert_eq(stats[0], 1)
      assert_true(stats[2] > 0)
    }
  }
}
