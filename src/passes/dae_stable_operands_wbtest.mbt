///|
fn dae_stable_operands_fixture(
  calls : Int,
  params : Int,
) -> DaeCurrentBoundaryGraph {
  let text = StringBuilder::new()
  text.write_string("(module (func $helper (param")
  for _ in 0..<params {
    text.write_string(" i32")
  }
  text.write_string(") (result i32) local.get 0) (func (export \"run\") ")
  for _ in 0..<calls {
    text.write_string("block ")
    for p in 0..<params {
      text.write_string("i32.const \{p + 7} ")
    }
    text.write_string("call $helper drop end ")
  }
  text.write_string("))")
  dae_current_boundary_graph_new(pass_test_module_from_wat(text.to_string()))
}

///|
test "dae stable operands preserve per-parameter candidates with one callsite resolution" {
  let graph = dae_stable_operands_fixture(1, 2)
  let resolutions = [0]
  let cache = DaeUniformResolutionCache::new(
    graph.snapshot.defined,
    graph.snapshot.total,
    function_infos=Some(graph.snapshot.function_infos),
  )
  for p in 0..<2 {
    let active = Array::make(2, false)
    active[p] = true
    let actual = dae_collect_uniform_const_actuals_from_function_infos(
      graph.mod_,
      0,
      2,
      graph.snapshot.type_indices,
      graph.snapshot.boundary_facts,
      graph.snapshot.function_infos,
      collect_params=Some(active),
      stable_callsite_resolutions=Some(resolutions),
      uniform_resolution_cache=Some(cache),
    ).unwrap()
    assert_eq(actual[p], Some(@lib.Instruction::i32_const(@lib.I32(p + 7))))
    assert_eq(actual[1 - p], None)
  }
  assert_eq(resolutions[0], 1)
}
