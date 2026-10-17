///|
fn dae_s10_discovery_filter_bench(
  it : @bench.T,
  calls : Int32,
  mode : Int32,
) -> Unit raise {
  let input = dae_s10_discovery_input(calls, false)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let expected = dae_s10_frozen_discovery_reference(
    input,
    graph.snapshot.call_facts,
    -1,
  )
  assert_eq(expected, [1, 2, 3])
  for control in 0..<3 {
    let actual = dae_s10_discovery_query(
      input,
      graph.snapshot.call_facts,
      control,
    )
    dae_s10_assert_discovery_output(input, actual, expected, saved)
  }
  // Recorder/counters are absent. Input setup, validation, exact productive
  // output/effect checks and ownership checks are outside the timed closure.
  it.bench(fn() {
    it.keep(dae_s10_discovery_query(input, graph.snapshot.call_facts, mode))
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("paired native discovery filtering cost; dedicated performance lane")
test "bench DAE discovery unrelated pairs=16 frozen S6" (it : @bench.T) {
  dae_s10_discovery_filter_bench(it, 16, 0)
}

///|
#skip("paired native discovery filtering cost; dedicated performance lane")
test "bench DAE discovery unrelated pairs=16 visitor" (it : @bench.T) {
  dae_s10_discovery_filter_bench(it, 16, 1)
}

///|
#skip("paired native discovery filtering cost; dedicated performance lane")
test "bench DAE discovery unrelated pairs=16 filtered" (it : @bench.T) {
  dae_s10_discovery_filter_bench(it, 16, 2)
}

///|
#skip("paired native discovery filtering cost; dedicated performance lane")
test "bench DAE discovery unrelated pairs=128 frozen S6" (it : @bench.T) {
  dae_s10_discovery_filter_bench(it, 128, 0)
}

///|
#skip("paired native discovery filtering cost; dedicated performance lane")
test "bench DAE discovery unrelated pairs=128 visitor" (it : @bench.T) {
  dae_s10_discovery_filter_bench(it, 128, 1)
}

///|
#skip("paired native discovery filtering cost; dedicated performance lane")
test "bench DAE discovery unrelated pairs=128 filtered" (it : @bench.T) {
  dae_s10_discovery_filter_bench(it, 128, 2)
}

///|
#skip("paired native discovery filtering cost; dedicated performance lane")
test "bench DAE discovery unrelated pairs=1024 frozen S6" (it : @bench.T) {
  dae_s10_discovery_filter_bench(it, 1024, 0)
}

///|
#skip("paired native discovery filtering cost; dedicated performance lane")
test "bench DAE discovery unrelated pairs=1024 visitor" (it : @bench.T) {
  dae_s10_discovery_filter_bench(it, 1024, 1)
}

///|
#skip("paired native discovery filtering cost; dedicated performance lane")
test "bench DAE discovery unrelated pairs=1024 filtered" (it : @bench.T) {
  dae_s10_discovery_filter_bench(it, 1024, 2)
}

///|
fn dae_s10_single_wide_bench(it : @bench.T, mode : Int32) -> Unit raise {
  let input = dae_s10_single_wide_target_input()
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let expected = dae_s10_frozen_discovery_reference(
    input,
    graph.snapshot.call_facts,
    -1,
  )
  assert_eq(expected, [0])
  for control in 0..<3 {
    let actual = dae_s10_discovery_query(
      input,
      graph.snapshot.call_facts,
      control,
    )
    assert_eq(actual, expected)
    let output = dae_run_exact_literal_candidate_worklist_with_facts(
      input,
      Array::make(graph.snapshot.defined, false),
      false,
      actual,
    )
    let reference = dae_run_exact_literal_candidate_worklist_with_facts(
      input,
      Array::make(graph.snapshot.defined, false),
      false,
      expected,
    )
    assert_true(output.changed)
    assert_eq(output.productive_defs, reference.productive_defs)
    assert_eq(output.touched, reference.touched)
    assert_eq(output.effects, reference.effects)
    @validate.validate_module(output.mod_out).unwrap()
    assert_eq(
      @binary.encode_module(output.mod_out).unwrap(),
      @binary.encode_module(reference.mod_out).unwrap(),
    )
    let after = dae_current_boundary_graph_new(output.mod_out)
    assert_eq(
      after.snapshot.function_types[0],
      Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
  it.bench(fn() {
    it.keep(dae_s10_discovery_query(input, graph.snapshot.call_facts, mode))
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("paired single-candidate multi-parameter admission cost; dedicated native lane")
test "bench DAE discovery one candidate eight forwarded params frozen S6" (
  it : @bench.T,
) {
  dae_s10_single_wide_bench(it, 0)
}

///|
#skip("paired single-candidate multi-parameter admission cost; dedicated native lane")
test "bench DAE discovery one candidate eight forwarded params visitor" (
  it : @bench.T,
) {
  dae_s10_single_wide_bench(it, 1)
}

///|
#skip("paired single-candidate multi-parameter admission cost; dedicated native lane")
test "bench DAE discovery one candidate eight forwarded params filtered" (
  it : @bench.T,
) {
  dae_s10_single_wide_bench(it, 2)
}
