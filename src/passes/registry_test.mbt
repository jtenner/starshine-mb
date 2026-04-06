///|
test "pass registry classifies active, boundary-only, and removed names" {
  assert_eq(
    pass_registry_category("vacuum"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  assert_eq(
    pass_registry_category("remove-unused-names"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  assert_eq(
    pass_registry_category("ssa-nomerge"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  assert_eq(
    pass_registry_category("dead-code-elimination"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  assert_eq(
    pass_registry_category("optimize-instructions"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  assert_eq(
    pass_registry_category("heap-store-optimization"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  assert_eq(
    pass_registry_category("heap2local"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  assert_eq(
    pass_registry_category("pick-load-signs"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  assert_eq(
    pass_registry_category("tuple-optimization"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  assert_eq(
    pass_registry_category("code-pushing"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  assert_eq(
    pass_registry_category("simplify-locals"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  assert_eq(
    pass_registry_category("duplicate-function-elimination"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  assert_eq(
    pass_registry_category("remove-unused-module-elements"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  assert_eq(
    pass_registry_category("remove-unused-brs"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  assert_eq(
    pass_registry_category("simplify-locals"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  assert_eq(
    pass_registry_category("optimize"),
    Some(HotPassRegistryCategory::preset()),
  )
  assert_eq(
    pass_registry_category("memory-packing"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  assert_eq(
    pass_registry_category("once-reduction"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  assert_eq(
    pass_registry_category("global-refining"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  assert_eq(
    pass_registry_category("global-struct-inference"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  assert_eq(
    pass_registry_category("reorder-locals"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  assert_eq(
    pass_registry_category("de-nan"),
    Some(HotPassRegistryCategory::removed()),
  )
}

///|
test "batch 1 descriptors expose the active first hot ports" {
  let ssa = ssa_nomerge_descriptor()
  let dce = dead_code_elimination_descriptor()
  let opt = optimize_instructions_descriptor()
  let precompute = precompute_descriptor()
  let pls = pick_load_signs_descriptor()
  let tuple = tuple_optimization_descriptor()
  let cp = code_pushing_descriptor()
  let hso = heap_store_optimization_descriptor()
  let h2l = heap2local_descriptor()
  let locals = simplify_locals_descriptor()
  let rub = remove_unused_brs_descriptor()

  assert_eq(ssa.name, "ssa-nomerge")
  assert_eq(@ir.hot_pass_requires(ssa), [])
  assert_eq(dce.name, "dead-code-elimination")
  assert_eq(@ir.hot_pass_requires(dce), [])
  assert_eq(opt.name, "optimize-instructions")
  assert_eq(precompute.name, "precompute")
  assert_eq(@ir.hot_pass_requires(precompute), [])
  assert_eq(pls.name, "pick-load-signs")
  assert_eq(@ir.hot_pass_requires(pls), [@ir.HotAnalysis::use_def()])
  assert_eq(tuple.name, "tuple-optimization")
  assert_eq(@ir.hot_pass_requires(tuple), [@ir.HotAnalysis::use_def()])
  assert_eq(cp.name, "code-pushing")
  assert_eq(@ir.hot_pass_requires(cp), [])
  assert_eq(hso.name, "heap-store-optimization")
  assert_true(@ir.hot_pass_requires(hso).contains(@ir.HotAnalysis::effects()))
  assert_eq(h2l.name, "heap2local")
  assert_eq(@ir.hot_pass_requires(h2l), [@ir.HotAnalysis::use_def()])
  assert_eq(locals.name, "simplify-locals")
  assert_true(@ir.hot_pass_requires(locals).contains(@ir.HotAnalysis::ssa()))
  assert_eq(rub.name, "remove-unused-brs")
}

///|
test "preset expansion stays on implemented active pass names" {
  let optimize = optimize_preset_passes(HotPipelineOptions::new())
  let shrink = shrink_preset_passes(HotPipelineOptions::new())

  assert_eq(optimize, [
    "memory-packing", "once-reduction", "global-refining", "global-struct-inference",
    "ssa-nomerge", "dead-code-elimination", "remove-unused-names", "remove-unused-brs",
    "remove-unused-names", "vacuum", "remove-unused-brs", "optimize-instructions",
    "heap-store-optimization", "pick-load-signs", "precompute", "code-pushing", "remove-unused-brs",
    "heap2local", "simplify-locals", "precompute", "remove-unused-names",
  ])
  assert_eq(shrink, [
    "memory-packing", "once-reduction", "global-refining", "global-struct-inference",
    "ssa-nomerge", "dead-code-elimination", "remove-unused-names", "remove-unused-brs",
    "remove-unused-names", "vacuum", "remove-unused-brs", "optimize-instructions",
    "heap-store-optimization", "pick-load-signs", "precompute", "code-pushing", "remove-unused-brs",
    "heap2local", "simplify-locals", "precompute", "remove-unused-names",
  ])
  for name in optimize {
    match pass_registry_category(name) {
      Some(HotPass) | Some(ModulePass) => ()
      other =>
        fail("expected optimize preset pass category for \{name}, got \{other}")
    }
  }
}

///|
test "run_hot_pipeline rejects removed registry names" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 1))",
  )

  match run_hot_pipeline(input, HotPipelineOptions::new(), ["de-nan"]) {
    Ok(_) => fail("expected removed registry name to reject in hot pipeline")
    Err(err) => assert_true(err.contains("removed"))
  }
}

///|
test "run_hot_pipeline accepts tuple-optimization as an active hot pass" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) (local i32 i32) (block (result i32 i32) i32.const 5 i32.const 9) local.set 0 local.set 1 local.get 0))",
  )

  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["tuple-optimization"]) {
    Ok(mod) => mod
    Err(err) => fail("expected tuple-optimization pipeline success, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(locals, _)])) => assert_eq(locals.length(), 4)
    other =>
      fail("expected single-function tuple-optimization module, got \{other}")
  }
}
