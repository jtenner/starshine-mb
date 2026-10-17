///|
fn dae_candidate_effects_bench(
  it : @bench.T,
  siblings : Int32,
  reference : Bool,
) -> Unit raise {
  let (input, output) = dae_signature_plan_metadata_fixture(siblings)
  let graph = dae_current_boundary_graph_new(input)
  let touched = Array::make(siblings + 2, false)
  touched[0] = true
  touched[1] = true
  let candidate : DaePassResult = {
    mod_out: output,
    touched,
    changed: true,
    primary_def: 0,
  }
  let item = dae_work_item_new(
    graph,
    dae_boundary_dependency_graph_new(graph),
    0,
    DaeDroppedResultWork,
  )
  assert_eq(
    dae_work_item_candidate_effects(input, graph, item, candidate),
    dae_candidate_effects_reference(input, graph, item, candidate),
  )
  it.bench(fn() {
    it.keep(
      if reference {
        dae_candidate_effects_reference(input, graph, item, candidate)
      } else {
        dae_work_item_candidate_effects(input, graph, item, candidate)
      },
    )
  })
}

///|
#skip("paired native candidate effect cost; dedicated performance lane")
test "bench DAE candidate effects siblings=0 reference" (it : @bench.T) {
  dae_candidate_effects_bench(it, 0, true)
}

///|
#skip("paired native candidate effect cost; dedicated performance lane")
test "bench DAE candidate effects siblings=0 bounded" (it : @bench.T) {
  dae_candidate_effects_bench(it, 0, false)
}

///|
#skip("paired native candidate effect cost; dedicated performance lane")
test "bench DAE candidate effects siblings=32 reference" (it : @bench.T) {
  dae_candidate_effects_bench(it, 32, true)
}

///|
#skip("paired native candidate effect cost; dedicated performance lane")
test "bench DAE candidate effects siblings=32 bounded" (it : @bench.T) {
  dae_candidate_effects_bench(it, 32, false)
}
