///|
test "pass registry classifies active, boundary-only, and removed names" {
  @debug.assert_eq(
    pass_registry_category("vacuum"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("remove-unused-names"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("ssa-nomerge"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("dead-code-elimination"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("optimize-instructions"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("heap-store-optimization"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("heap2local"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("optimize-casts"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("pick-load-signs"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("code-pushing"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("code-folding"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("tuple-optimization"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("simplify-locals"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("simplify-locals-nostructure"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("simplify-locals-no-structure"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("simplify-locals-notee-nostructure"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("merge-blocks"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("redundant-set-elimination"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("reorder-locals"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("local-subtyping"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("coalesce-locals"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("merge-locals"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("untee"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("duplicate-function-elimination"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("duplicate-import-elimination"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("inlining"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("inlining-optimizing"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("reorder-globals"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("directize"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("remove-unused-module-elements"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("remove-unused-nonfunction-module-elements"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("remove-unused-brs"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("simplify-locals"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("optimize"),
    Some(HotPassRegistryCategory::preset()),
  )
  @debug.assert_eq(
    pass_registry_category("memory-packing"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("once-reduction"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("global-refining"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("global-struct-inference"),
    Some(HotPassRegistryCategory::module_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("de-nan"),
    Some(HotPassRegistryCategory::removed()),
  )
  @debug.assert_eq(
    pass_registry_category("simplify-locals-no-tee-no-structure"),
    Some(HotPassRegistryCategory::removed()),
  )
}

///|
test "batch 1 descriptors expose the active first hot ports" {
  let ssa = ssa_nomerge_descriptor()
  let dce = dead_code_elimination_descriptor()
  let opt = optimize_instructions_descriptor()
  let precompute = precompute_descriptor()
  let code_pushing = code_pushing_descriptor()
  let code_folding = code_folding_descriptor()
  let pls = pick_load_signs_descriptor()
  let tuple = tuple_optimization_descriptor()
  let hso = heap_store_optimization_descriptor()
  let h2l = heap2local_descriptor()
  let oc = optimize_casts_descriptor()
  let locals = simplify_locals_descriptor()
  let locals_nostructure = simplify_locals_nostructure_descriptor()
  let locals_notee_nostructure = simplify_locals_notee_nostructure_descriptor()
  let merge_blocks = merge_blocks_descriptor()
  let rse = rse_descriptor()
  let rub = remove_unused_brs_descriptor()

  @debug.assert_eq(ssa.name, "ssa-nomerge")
  @debug.assert_eq(@ir.hot_pass_requires(ssa), [])
  @debug.assert_eq(dce.name, "dead-code-elimination")
  @debug.assert_eq(@ir.hot_pass_requires(dce), [])
  @debug.assert_eq(opt.name, "optimize-instructions")
  @debug.assert_eq(precompute.name, "precompute")
  @debug.assert_eq(@ir.hot_pass_requires(precompute), [])
  @debug.assert_eq(code_pushing.name, "code-pushing")
  @debug.assert_eq(@ir.hot_pass_requires(code_pushing), [])
  @debug.assert_eq(code_folding.name, "code-folding")
  @debug.assert_eq(@ir.hot_pass_requires(code_folding), [])
  @debug.assert_eq(pls.name, "pick-load-signs")
  @debug.assert_eq(@ir.hot_pass_requires(pls), [@ir.HotAnalysis::use_def()])
  @debug.assert_eq(tuple.name, "tuple-optimization")
  @debug.assert_eq(@ir.hot_pass_requires(tuple), [@ir.HotAnalysis::use_def()])
  @debug.assert_eq(hso.name, "heap-store-optimization")
  assert_true(@ir.hot_pass_requires(hso).contains(@ir.HotAnalysis::effects()))
  @debug.assert_eq(h2l.name, "heap2local")
  @debug.assert_eq(@ir.hot_pass_requires(h2l), [@ir.HotAnalysis::use_def()])
  @debug.assert_eq(oc.name, "optimize-casts")
  @debug.assert_eq(@ir.hot_pass_requires(oc), [])
  @debug.assert_eq(locals.name, "simplify-locals")
  @debug.assert_eq(@ir.hot_pass_requires(locals), [])
  @debug.assert_eq(locals_nostructure.name, "simplify-locals-nostructure")
  @debug.assert_eq(@ir.hot_pass_requires(locals_nostructure), [])
  @debug.assert_eq(
    locals_notee_nostructure.name,
    "simplify-locals-notee-nostructure",
  )
  @debug.assert_eq(@ir.hot_pass_requires(locals_notee_nostructure), [])
  @debug.assert_eq(merge_blocks.name, "merge-blocks")
  @debug.assert_eq(@ir.hot_pass_requires(merge_blocks), [])
  @debug.assert_eq(rse.name, "redundant-set-elimination")
  @debug.assert_eq(@ir.hot_pass_requires(rse), [])
  @debug.assert_eq(rub.name, "remove-unused-brs")
}

///|
test "preset expansion stays on implemented active pass names" {
  let optimize = optimize_preset_passes(HotPipelineOptions::new())
  let shrink = shrink_preset_passes(HotPipelineOptions::new())

  @debug.assert_eq(optimize, [
    "memory-packing", "once-reduction", "global-refining", "global-struct-inference",
    "ssa-nomerge", "dead-code-elimination", "remove-unused-names", "remove-unused-brs",
    "remove-unused-names", "vacuum", "remove-unused-brs", "optimize-instructions",
    "heap-store-optimization", "pick-load-signs", "precompute", "code-pushing", "tuple-optimization",
    "simplify-locals-nostructure", "vacuum", "reorder-locals", "remove-unused-brs",
    "heap2local", "optimize-casts", "local-subtyping", "coalesce-locals", "local-cse",
    "simplify-locals", "merge-blocks", "remove-unused-brs", "remove-unused-names",
    "merge-blocks", "precompute", "optimize-instructions", "heap-store-optimization",
    "simplify-globals-optimizing", "remove-unused-module-elements", "string-gathering",
    "reorder-globals", "directize",
  ])
  @debug.assert_eq(shrink, [
    "memory-packing", "once-reduction", "global-refining", "global-struct-inference",
    "ssa-nomerge", "dead-code-elimination", "remove-unused-names", "remove-unused-brs",
    "remove-unused-names", "vacuum", "remove-unused-brs", "optimize-instructions",
    "heap-store-optimization", "pick-load-signs", "precompute", "code-pushing", "tuple-optimization",
    "simplify-locals-nostructure", "vacuum", "reorder-locals", "remove-unused-brs",
    "heap2local", "optimize-casts", "local-subtyping", "coalesce-locals", "local-cse",
    "simplify-locals", "merge-blocks", "remove-unused-brs", "remove-unused-names",
    "merge-blocks", "precompute", "optimize-instructions", "heap-store-optimization",
    "simplify-globals-optimizing", "remove-unused-module-elements", "string-gathering",
    "reorder-globals", "directize",
  ])
  for name in optimize {
    match pass_registry_category(name) {
      Some(HotPass) | Some(ModulePass) => ()
      other =>
        fail(
          "expected optimize preset pass category for \{name}, got \{@debug.to_string(other)}",
        )
    }
  }
}

///|
test "run_hot_pipeline rejects removed registry names" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 1))",
  )

  @debug.assert_eq(
    pass_registry_category("untee"),
    Some(HotPassRegistryCategory::module_pass()),
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
    Some(@lib.CodeSec([@lib.Func(locals, _)])) =>
      @debug.assert_eq(locals.length(), 2)
    other =>
      fail(
        "expected single-function tuple-optimization module, got \{@debug.to_string(other)}",
      )
  }
}
