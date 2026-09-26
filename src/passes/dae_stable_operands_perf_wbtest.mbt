///|
fn dae_stable_operands_bench(it : @bench.T, calls : Int) -> Unit {
  let graph = dae_stable_operands_fixture(calls, 16)
  it.bench(fn() {
    let cache = DaeUniformResolutionCache::new(
      graph.snapshot.defined,
      graph.snapshot.total,
      function_infos=Some(graph.snapshot.function_infos),
    )
    for p in 0..<16 {
      let active = Array::make(16, false)
      active[p] = true
      it.keep(
        dae_collect_uniform_const_actuals_from_function_infos(
          graph.mod_,
          0,
          16,
          graph.snapshot.type_indices,
          graph.snapshot.boundary_facts,
          graph.snapshot.function_infos,
          collect_params=Some(active),
          uniform_resolution_cache=Some(cache),
        ),
      )
    }
  })
}

///|
test "bench DAE stable parameter queries calls=32" (it : @bench.T) {
  dae_stable_operands_bench(it, 32)
}

///|
test "bench DAE stable parameter queries calls=128" (it : @bench.T) {
  dae_stable_operands_bench(it, 128)
}

///|
fn dae_current_call_facts_bench(
  it : @bench.T,
  calls : Int,
  stable : Bool,
) -> Unit {
  let graph = dae_stable_operands_fixture(calls, 2)
  it.bench(fn() {
    it.keep(
      dae_collect_uniform_const_actuals_from_current_call_facts(
        graph.mod_,
        0,
        2,
        graph.snapshot.type_indices,
        graph.snapshot.boundary_facts,
        graph.snapshot.function_infos,
        prefer_stable_paths=stable,
      ),
    )
  })
}

///|
test "bench DAE current uniform facts calls=128" (it : @bench.T) {
  dae_current_call_facts_bench(it, 128, true)
}

///|
test "bench DAE current uniform facts calls=512" (it : @bench.T) {
  dae_current_call_facts_bench(it, 512, true)
}

///|
test "bench DAE legacy uniform scan calls=128" (it : @bench.T) {
  dae_current_call_facts_bench(it, 128, false)
}

///|
test "bench DAE legacy uniform scan calls=512" (it : @bench.T) {
  dae_current_call_facts_bench(it, 512, false)
}
