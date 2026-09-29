///|
fn dae_reverse_graph_round(
  input : @lib.Module,
  original : DaeOriginalBoundarySnapshot,
  shared : Bool,
) -> DaePassResult {
  let graph = dae_current_boundary_graph_new(input)
  let result = dae_literal_replay_fixture_run(
    input,
    original,
    [0],
    supplied_graph=if shared { Some(graph) } else { None },
  )
  if !result.changed {
    return result
  }
  let item = dae_work_item_new(
    graph,
    dae_boundary_dependency_graph_new(graph),
    result.primary_def,
    DaeUniformActualWork,
  )
  let effects = dae_work_item_candidate_effects(input, graph, item, result)
  match
    dae_process_precomputed_signature_work_item(
      original,
      input,
      [],
      false,
      graph,
      item,
      result,
      effects,
    ) {
    DaeWorkCommitted(application) =>
      {
        mod_out: application.mod_out,
        touched: application.touched,
        changed: application.changed,
        primary_def: application.primary_def,
      }
    _ => abort("reverse graph round lost active transaction")
  }
}

///|
fn dae_reverse_graph_bench(
  it : @bench.T,
  types : Int,
  helpers : Int,
  active : Bool,
  shared : Bool,
) -> Unit {
  let input = dae_reverse_signature_fixture(types, helpers, active)
  let saved = @binary.encode_module(input).unwrap()
  let original = dae_collect_original_boundary_snapshot(input)
  let output = dae_reverse_graph_round(input, original, true)
  let reference = dae_reverse_graph_round(input, original, false)
  if output.changed != active ||
    output.primary_def != reference.primary_def ||
    output.touched != reference.touched ||
    @binary.encode_module(output.mod_out).unwrap() !=
    @binary.encode_module(reference.mod_out).unwrap() {
    abort("reverse graph round changed active behavior or exact output")
  }
  @validate.validate_module(output.mod_out).unwrap()
  it.bench(fn() { it.keep(dae_reverse_graph_round(input, original, shared)) })
  if @binary.encode_module(input).unwrap() != saved {
    abort("reverse graph round mutated input")
  }
}

///|
test "bench DAE reverse graph round types=1 helpers=1 nonconstant rebuild reference" (
  it : @bench.T,
) {
  dae_reverse_graph_bench(it, 1, 1, false, false)
}

///|
test "bench DAE reverse graph round types=1 helpers=1 nonconstant shared" (
  it : @bench.T,
) {
  dae_reverse_graph_bench(it, 1, 1, false, true)
}

///|
test "bench DAE reverse graph round types=1 helpers=1 active rebuild reference" (
  it : @bench.T,
) {
  dae_reverse_graph_bench(it, 1, 1, true, false)
}

///|
test "bench DAE reverse graph round types=1 helpers=1 active shared" (
  it : @bench.T,
) {
  dae_reverse_graph_bench(it, 1, 1, true, true)
}

///|
test "bench DAE reverse graph round types=256 helpers=32 nonconstant rebuild reference" (
  it : @bench.T,
) {
  dae_reverse_graph_bench(it, 256, 32, false, false)
}

///|
test "bench DAE reverse graph round types=256 helpers=32 nonconstant shared" (
  it : @bench.T,
) {
  dae_reverse_graph_bench(it, 256, 32, false, true)
}

///|
test "bench DAE reverse graph round types=256 helpers=32 active rebuild reference" (
  it : @bench.T,
) {
  dae_reverse_graph_bench(it, 256, 32, true, false)
}

///|
test "bench DAE reverse graph round types=256 helpers=32 active shared" (
  it : @bench.T,
) {
  dae_reverse_graph_bench(it, 256, 32, true, true)
}
