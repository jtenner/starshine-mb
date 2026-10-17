///|
fn dae_liveness_handoff_bench(
  it : @bench.T,
  hot : Bool,
  reference : Bool,
) -> Unit raise {
  let input = dae_liveness_handoff_fixture(hot, reads=256)
  let original = dae_collect_original_boundary_snapshot(input)
  let graph = dae_current_boundary_graph_new(input)
  let expected = dae_boundary_syntax_frozen_try_rewrite_selected_defs_unread_params_with_facts_once(
    input,
    [true, false],
    graph.snapshot.call_facts,
    original=Some(original),
    graph=Some(graph),
  )
  let actual = dae_try_rewrite_selected_defs_unread_params_with_facts_once(
    input,
    [true, false],
    graph.snapshot.call_facts,
    original=Some(original),
    graph=Some(graph),
  )
  dae_liveness_handoff_assert_result(input, actual, expected)
  assert_eq(dae_wb_param_count(actual.mod_out, 0), 1)
  it.bench(fn() {
    it.keep(
      if reference {
        dae_boundary_syntax_frozen_try_rewrite_selected_defs_unread_params_with_facts_once(
          input,
          [true, false],
          graph.snapshot.call_facts,
          original=Some(original),
          graph=Some(graph),
        )
      } else {
        dae_try_rewrite_selected_defs_unread_params_with_facts_once(
          input,
          [true, false],
          graph.snapshot.call_facts,
          original=Some(original),
          graph=Some(graph),
        )
      },
    )
  })
}

///|
#skip("paired native selected unread cost; dedicated performance lane")
test "bench DAE raw liveness handoff reference" (it : @bench.T) {
  dae_liveness_handoff_bench(it, false, true)
}

///|
#skip("paired native selected unread cost; dedicated performance lane")
test "bench DAE raw liveness handoff shared" (it : @bench.T) {
  dae_liveness_handoff_bench(it, false, false)
}

///|
#skip("paired native selected unread cost; dedicated performance lane")
test "bench DAE HOT liveness handoff reference" (it : @bench.T) {
  dae_liveness_handoff_bench(it, true, true)
}

///|
#skip("paired native selected unread cost; dedicated performance lane")
test "bench DAE HOT liveness handoff shared" (it : @bench.T) {
  dae_liveness_handoff_bench(it, true, false)
}
