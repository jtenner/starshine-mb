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
    pass_registry_category("pick-load-signs"),
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
    pass_registry_category("de-nan"),
    Some(HotPassRegistryCategory::removed()),
  )
}

///|
test "batch 1 descriptors expose the active first hot ports" {
  let ssa = ssa_nomerge_descriptor()
  let dce = dead_code_elimination_descriptor()
  let opt = optimize_instructions_descriptor()
  let pls = pick_load_signs_descriptor()
  let hso = heap_store_optimization_descriptor()
  let locals = simplify_locals_descriptor()

  assert_eq(ssa.name, "ssa-nomerge")
  assert_eq(@ir.hot_pass_requires(ssa), [])
  assert_eq(dce.name, "dead-code-elimination")
  assert_eq(@ir.hot_pass_requires(dce), [])
  assert_eq(opt.name, "optimize-instructions")
  assert_eq(pls.name, "pick-load-signs")
  assert_eq(@ir.hot_pass_requires(pls), [@ir.HotAnalysis::use_def()])
  assert_eq(hso.name, "heap-store-optimization")
  assert_true(@ir.hot_pass_requires(hso).contains(@ir.HotAnalysis::effects()))
  assert_eq(locals.name, "simplify-locals")
  assert_true(@ir.hot_pass_requires(locals).contains(@ir.HotAnalysis::ssa()))
}

///|
test "preset expansion stays on implemented active pass names" {
  let optimize = optimize_preset_passes(HotPipelineOptions::new())
  let shrink = shrink_preset_passes(HotPipelineOptions::new())

  assert_eq(optimize, [
    "memory-packing", "once-reduction", "global-refining", "global-struct-inference",
    "ssa-nomerge", "dead-code-elimination", "remove-unused-names", "vacuum", "optimize-instructions",
    "heap-store-optimization", "pick-load-signs", "simplify-locals",
  ])
  assert_eq(shrink, [
    "memory-packing", "once-reduction", "global-refining", "global-struct-inference",
    "ssa-nomerge", "dead-code-elimination", "remove-unused-names", "vacuum", "optimize-instructions",
    "heap-store-optimization", "pick-load-signs", "simplify-locals",
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
