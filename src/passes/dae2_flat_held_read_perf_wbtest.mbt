///|
// Direct structured replay is the correct-shape reference for a held read.
// Direct flat replay is the unchanged-path reference when no read is held.
// Compare dispatch overhead, not the old equal-size but noncanonical output.
fn dae2_flat_held_read_bench(
  it : @bench.T,
  width : Int32,
  held : Bool,
  direct : Bool,
) -> Unit raise {
  let producer = []
  if held {
    producer.push("local.get 0")
  }
  for _ in 0..<width {
    producer.push("local.get 0 call $effect")
  }
  if !held {
    producer.push("local.get 0")
  }
  let input = dae2_flat_tee_demand_fixture(producer.join(" "))
  dae2_flat_tee_complete_compare(input)
  let saved = @binary.encode_module(input).unwrap()
  let context = @ir.hot_module_context_from_module(input)
  let graph = Dae2Graph::new()
  let infos : Array[Dae2Function] = []
  for index in 0..<3 {
    let @lib.FuncType(params, results) = @ir.hot_module_resolve_func_type(
      context,
      @lib.FuncIdx::new(index.to_uint()),
    ).unwrap()
    infos.push(Dae2Function::new(graph, params, results))
  }
  for index in 1..<3 {
    let plan = dae2_raw_dependency_plan(
      graph,
      infos,
      index,
      [],
      input.code_sec.unwrap().0[index - 1],
      None,
      module_context=Some(context),
    ).unwrap()
    plan.commit(graph)
    infos[index].raw_analysis = true
    infos[index].raw_write_locations = plan.write_locations
  }
  graph.observe(infos[0].param_locations[0])
  graph.observe(infos[2].param_locations[0])
  graph.observe(infos[2].result_location)
  graph.solve()
  let original = input.code_sec.unwrap().0[1]
  let replay = fn(direct : Bool) {
    if direct {
      if held {
        dae2_rewrite_raw_structured_function(
          graph,
          infos,
          2,
          original,
          context,
          infos[2].params,
          [],
        ).unwrap()
      } else {
        dae2_rewrite_raw_flat_function(
          graph,
          infos,
          2,
          original,
          context,
          infos[2].params,
          [],
        ).unwrap()
      }
    } else {
      dae2_rewrite_raw_function(
        graph,
        infos,
        2,
        original,
        context,
        infos[2].params,
        [],
      ).unwrap()
    }
  }
  assert_eq(replay(true), replay(false))
  // This is a setup bound on solved module facts; ephemeral replay work is
  // measured by the paired native calls, including a failed flat trial.
  assert_true(graph.used.length() <= 3 * width + 16)
  assert_true(graph.edges.length() <= 3 * width + 16)
  it.bench(fn() { it.keep(replay(direct)) })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("manual native flat-to-structured route cost control; excluded from default tests")
test "bench DAE2 flat read held width=32 reference" (it : @bench.T) {
  dae2_flat_held_read_bench(it, 32, true, true)
}

///|
#skip("manual native flat-to-structured route cost control; excluded from default tests")
test "bench DAE2 flat read held width=32 current" (it : @bench.T) {
  dae2_flat_held_read_bench(it, 32, true, false)
}

///|
#skip("manual native flat-to-structured route cost control; excluded from default tests")
test "bench DAE2 flat read held width=128 reference" (it : @bench.T) {
  dae2_flat_held_read_bench(it, 128, true, true)
}

///|
#skip("manual native flat-to-structured route cost control; excluded from default tests")
test "bench DAE2 flat read held width=128 current" (it : @bench.T) {
  dae2_flat_held_read_bench(it, 128, true, false)
}

///|
#skip("manual native flat-to-structured route cost control; excluded from default tests")
test "bench DAE2 flat read held width=512 reference" (it : @bench.T) {
  dae2_flat_held_read_bench(it, 512, true, true)
}

///|
#skip("manual native flat-to-structured route cost control; excluded from default tests")
test "bench DAE2 flat read held width=512 current" (it : @bench.T) {
  dae2_flat_held_read_bench(it, 512, true, false)
}

///|
#skip("manual native flat-to-structured route cost control; excluded from default tests")
test "bench DAE2 flat read no-held width=32 reference" (it : @bench.T) {
  dae2_flat_held_read_bench(it, 32, false, true)
}

///|
#skip("manual native flat-to-structured route cost control; excluded from default tests")
test "bench DAE2 flat read no-held width=32 current" (it : @bench.T) {
  dae2_flat_held_read_bench(it, 32, false, false)
}

///|
#skip("manual native flat-to-structured route cost control; excluded from default tests")
test "bench DAE2 flat read no-held width=128 reference" (it : @bench.T) {
  dae2_flat_held_read_bench(it, 128, false, true)
}

///|
#skip("manual native flat-to-structured route cost control; excluded from default tests")
test "bench DAE2 flat read no-held width=128 current" (it : @bench.T) {
  dae2_flat_held_read_bench(it, 128, false, false)
}

///|
#skip("manual native flat-to-structured route cost control; excluded from default tests")
test "bench DAE2 flat read no-held width=512 reference" (it : @bench.T) {
  dae2_flat_held_read_bench(it, 512, false, true)
}

///|
#skip("manual native flat-to-structured route cost control; excluded from default tests")
test "bench DAE2 flat read no-held width=512 current" (it : @bench.T) {
  dae2_flat_held_read_bench(it, 512, false, false)
}
