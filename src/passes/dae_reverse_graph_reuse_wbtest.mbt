///|
test "DAE reverse literal scanning reuses its exact module graph without rebuilding while preserving active and unchanged output" {
  for active in [false, true] {
    let input = dae_reverse_signature_fixture(12, 4, active)
    let saved = @binary.encode_module(input).unwrap()
    let original = dae_collect_original_boundary_snapshot(input)
    let graph = dae_current_boundary_graph_new(input)
    let signature_epoch = graph.type_epoch
    let call_epoch = graph.call_epoch
    let graph_builds = [0]
    let output = dae_literal_replay_fixture_run(
      input,
      original,
      [0],
      supplied_graph=Some(graph),
      graph_builds=Some(graph_builds),
    )
    let reference = dae_literal_replay_fixture_run(input, original, [0])
    assert_eq(output.changed, active)
    assert_eq(output.primary_def, reference.primary_def)
    assert_eq(output.touched, reference.touched)
    assert_eq(
      @binary.encode_module(output.mod_out).unwrap(),
      @binary.encode_module(reference.mod_out).unwrap(),
    )
    if active {
      assert_eq(dae_wb_param_count(output.mod_out, 7), 0)
    }
    assert_eq(graph_builds[0], 0)
    assert_eq(graph.type_epoch, signature_epoch)
    assert_eq(graph.call_epoch, call_epoch)
    @validate.validate_module(output.mod_out).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE reverse literal scanning rebuilds a different module graph before active pruning" {
  let before = dae_reverse_signature_fixture(12, 4, false)
  let input = dae_reverse_signature_fixture(12, 4, true)
  let saved = @binary.encode_module(input).unwrap()
  let before_saved = @binary.encode_module(before).unwrap()
  let original = dae_collect_original_boundary_snapshot(input)
  let graph = dae_current_boundary_graph_new(before)
  let builds = [0]
  let output = dae_literal_replay_fixture_run(
    input,
    original,
    [0],
    supplied_graph=Some(graph),
    graph_builds=Some(builds),
  )
  let reference = dae_literal_replay_fixture_run(input, original, [0])
  assert_true(output.changed)
  assert_eq(output.primary_def, reference.primary_def)
  assert_eq(dae_wb_param_count(output.mod_out, 7), 0)
  assert_eq(
    @binary.encode_module(output.mod_out).unwrap(),
    @binary.encode_module(reference.mod_out).unwrap(),
  )
  assert_eq(builds[0], 1)
  @validate.validate_module(output.mod_out).unwrap()
  assert_eq(@binary.encode_module(before).unwrap(), before_saved)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
