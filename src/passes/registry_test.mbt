///|
test "pass registry classifies active, boundary-only, and removed names" {
  assert_eq(
    pass_registry_category("vacuum"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  assert_eq(
    pass_registry_category("optimize"),
    Some(HotPassRegistryCategory::preset()),
  )
  assert_eq(
    pass_registry_category("memory-packing"),
    Some(HotPassRegistryCategory::boundary_only()),
  )
  assert_eq(
    pass_registry_category("de-nan"),
    Some(HotPassRegistryCategory::removed()),
  )
}

///|
test "batch 1 placeholder descriptors expose the planned first hot ports" {
  let dce = dead_code_elimination_descriptor()
  let opt = optimize_instructions_descriptor()
  let locals = simplify_locals_descriptor()

  assert_eq(dce.name, "dead-code-elimination")
  assert_true(@ir.hot_pass_requires(dce).contains(@ir.HotAnalysis::use_def()))
  assert_eq(opt.name, "optimize-instructions")
  assert_eq(locals.name, "simplify-locals")
  assert_true(@ir.hot_pass_requires(locals).contains(@ir.HotAnalysis::ssa()))
}

///|
test "preset expansion stays on implemented hot pass names" {
  let optimize = optimize_preset_passes(HotPipelineOptions::new())
  let shrink = shrink_preset_passes(HotPipelineOptions::new())

  assert_eq(optimize, ["vacuum"])
  assert_eq(shrink, ["vacuum"])
  for name in optimize {
    assert_eq(
      pass_registry_category(name),
      Some(HotPassRegistryCategory::hot_pass()),
    )
  }
}

///|
test "run_hot_pipeline rejects removed and boundary-only registry names" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 1))",
  )

  match run_hot_pipeline(input, HotPipelineOptions::new(), ["memory-packing"]) {
    Ok(_) =>
      fail("expected boundary-only registry name to reject in hot pipeline")
    Err(err) => assert_true(err.contains("boundary-only"))
  }

  match run_hot_pipeline(input, HotPipelineOptions::new(), ["de-nan"]) {
    Ok(_) => fail("expected removed registry name to reject in hot pipeline")
    Err(err) => assert_true(err.contains("removed"))
  }
}
