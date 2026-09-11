///|
test "sparse local flow matches converged definitions through joins loops and handlers" {
  let fixtures = [
    "(module (func (param i32 i32) (local i32) block $exit loop $again local.get 0 if (result i32) i32.const 7 local.tee 1 else local.get 1 end local.set 2 local.get 2 br_if $exit i32.const 0 local.set 0 br $again end end local.get 1 drop))",
    "(module (tag $e) (func (param i32) (local i32) (try (do (if (local.get 0) (then (local.set 1 (i32.const 7)) (throw $e)))) (catch $e (drop (local.get 1)))) (drop (local.get 1))))",
    "(module (func (param i32) (local i32 i32 i32) (if (result i32 i32) (local.get 0) (then (local.get 1) (local.set 1 (i32.const 7)) (i32.const 3)) (else (i32.const 2) (i32.const 4))) local.set 2 local.set 3 (drop (local.get 1))))",
    "(module (func (param i32 i32) local.get 0 if (result i32) i32.const 7 local.tee 1 else local.get 1 end if nop end local.get 1 drop))",
  ]
  for source in fixtures {
    let mod_ = match @wast.wast_to_binary_module(source) {
      Ok(mod_) => mod_
      Err(err) => fail("sparse fixture: \{err}; \{source}")
    }
    let func = hot_lift_func_with_context_result(
      mod_,
      @lib.FuncIdx::new(0U),
      hot_module_context_from_module(mod_),
      capture_stack_locals=true,
      materialize_multi_values=true,
    ).unwrap()
    local_graph_sparse_assert_definitions(func)
  }
}

///|
fn local_graph_sparse_assert_definitions(func : HotFunc) -> Unit raise {
  let cfg = cfg_build(func)
  for exceptional in [false, true] {
    let expected = local_graph_build_with_exceptional_policy(
      func, cfg, exceptional,
    )
    let actual = local_graph_build_sparse_flow(func, cfg, exceptional)
    for node in 0..<hot_node_count(func) {
      let expected_sources = expected.get_source_ids[node].copy()
      let actual_sources = actual.get_source_ids[node].copy()
      expected_sources.sort()
      actual_sources.sort()
      @debug.assert_eq(actual_sources, expected_sources)
      let expected_gets = expected.set_influence_gets[node].copy()
      let actual_gets = actual.set_influence_gets[node].copy()
      expected_gets.sort()
      actual_gets.sort()
      @debug.assert_eq(actual_gets, expected_gets)
    }
    @debug.assert_eq(actual.local_is_already_ssa, expected.local_is_already_ssa)
  }
}

///|
#skip
test "sparse local flow dedicated GenValid definitions comparison" {
  // Dedicated aggregate seed sweep; exclude from default behavior tests.
  for
    name in [
      "dae2-locals", "dae2-tuple-results", "constraint-joins", "constraint-loops",
      "constraint-effects",
    ] {
    let profile = @validate.gen_valid_profile_by_name(name).unwrap()
    for seed = 0UL; seed < 1000UL; seed = seed + 1UL {
      let generated = @validate.gen_valid_module_result_from_seed(
        seed,
        @validate.GenValidConfig::for_profile(profile),
      ).unwrap()
      let mod_ = generated.wasm_module
      let context = hot_module_context_from_module(mod_)
      for index = 0; index < context.func_imports.length(); index = index + 1 {
        if context.func_imports[index] is Some(_) {
          continue
        }
        let func = hot_lift_func_with_context_result(
          mod_,
          @lib.FuncIdx::new(index.reinterpret_as_uint()),
          context,
          capture_stack_locals=true,
          materialize_multi_values=true,
        ).unwrap()
        local_graph_sparse_assert_definitions(func)
      }
    }
  }
}
