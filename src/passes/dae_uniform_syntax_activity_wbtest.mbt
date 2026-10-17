///|
/// This probe is outside every timed closure. Each call creates a fresh graph
/// and a query owner that ends before candidate discovery returns.
fn dae_uniform_syntax_discovery_activity(
  input : @lib.Module,
  indexed : Bool,
) -> (Array[Int32], Array[Int32]) {
  let graph = dae_current_boundary_graph_new(input)
  let stats = [0, 0, 0, 0]
  let candidates = dae_collect_exact_literal_candidate_defs_with_facts(
    input,
    graph.snapshot.call_facts,
    -1,
    indexed_syntax=indexed,
    syntax_stats=Some(stats),
  )
  (candidates, stats)
}

///|
#skip("artifact-scale untimed syntax activity; dedicated native evidence lane")
test "probe DAE fixed small artifact syntax activity" {
  let bytes = @sfs.read_file_bytes(
    "/home/dev/Projects/starshine-mb/.tmp/dae-speed-20261016/inputs/small.wasm",
  ).unwrap()
  let input = @binary.decode_module(bytes).unwrap()
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let (actual, stats) = dae_uniform_syntax_discovery_activity(input, true)
  let (expected, reference_stats) = dae_uniform_syntax_discovery_activity(
    input, false,
  )
  assert_eq(actual, expected)
  let graph = dae_current_boundary_graph_new(input)
  assert_eq(
    actual,
    dae_s10_frozen_discovery_reference(input, graph.snapshot.call_facts, -1),
  )
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
  let output_bytes = @binary.encode_module(output.mod_out).unwrap()
  let reference_bytes = @binary.encode_module(reference.mod_out).unwrap()
  assert_eq(output_bytes, reference_bytes)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  println(
    "syntax stats [constructions, caller misses, caller hits, stored calls]",
  )
  println(stats)
  println("candidate count")
  println(actual.length())
  println("candidate ids in scalar order")
  println(actual)
  // Evidence writes are explicit, skipped, untimed, and outside production.
  @sfs.write_file_bytes(
    "/home/dev/Projects/starshine-mb/.tmp/dae-speed-20261016/uniform-syntax-repair/s10/indexed-output.wasm",
    output_bytes,
  ).unwrap()
  @sfs.write_file_bytes(
    "/home/dev/Projects/starshine-mb/.tmp/dae-speed-20261016/uniform-syntax-repair/s10/reference-output.wasm",
    reference_bytes,
  ).unwrap()
  @sfs.write_file_bytes(
    "/home/dev/Projects/starshine-mb/.tmp/dae-speed-20261016/uniform-syntax-repair/s10/normalized-input.wasm",
    saved,
  ).unwrap()
  println("retained reference stats")
  println(reference_stats)
}
