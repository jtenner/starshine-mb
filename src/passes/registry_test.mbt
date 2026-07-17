///|
fn registry_test_assert_requires(
  descriptor : @ir.HotPassDescriptor,
  expected : Array[@ir.HotAnalysis],
) -> Unit raise {
  @debug.assert_eq(@ir.hot_pass_requires(descriptor), expected)
}

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
    pass_registry_category("flatten"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("ssa"),
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
    pass_registry_category("simplify-locals-notee"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("simplify-locals-no-tee"),
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
  let full_ssa = ssa_full_descriptor()
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
  let locals_notee = simplify_locals_notee_descriptor()
  let locals_nostructure = simplify_locals_nostructure_descriptor()
  let locals_notee_nostructure = simplify_locals_notee_nostructure_descriptor()
  let merge_blocks = merge_blocks_descriptor()
  let rse = rse_descriptor()
  let rub = remove_unused_brs_descriptor()

  @debug.assert_eq(ssa.name, "ssa-nomerge")
  @debug.assert_eq(
    ssa_nomerge_summary(),
    "Freshen single-source locals and materialize defaults while preserving merge traffic.",
  )
  match pass_registry_lookup("ssa-nomerge") {
    Some(entry) =>
      @debug.assert_eq(
        entry.summary,
        "Freshen single-source locals and materialize defaults while preserving merge traffic.",
      )
    None => fail("expected ssa-nomerge registry entry")
  }
  @debug.assert_eq(@ir.hot_pass_requires(ssa), [])
  @debug.assert_eq(full_ssa.name, "ssa")
  @debug.assert_eq(@ir.hot_pass_requires(full_ssa), [])
  @debug.assert_eq(dce.name, "dead-code-elimination")
  @debug.assert_eq(@ir.hot_pass_requires(dce), [])
  @debug.assert_eq(opt.name, "optimize-instructions")
  @debug.assert_eq(@ir.hot_pass_requires(opt), [
    @ir.HotAnalysis::use_def(),
    @ir.HotAnalysis::effects(),
  ])
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
  @debug.assert_eq(@ir.hot_pass_requires(hso), [])
  @debug.assert_eq(h2l.name, "heap2local")
  @debug.assert_eq(@ir.hot_pass_requires(h2l), [@ir.HotAnalysis::use_def()])
  @debug.assert_eq(oc.name, "optimize-casts")
  @debug.assert_eq(@ir.hot_pass_requires(oc), [])
  @debug.assert_eq(locals.name, "simplify-locals")
  @debug.assert_eq(@ir.hot_pass_requires(locals), [])
  @debug.assert_eq(locals_notee.name, "simplify-locals-notee")
  @debug.assert_eq(@ir.hot_pass_requires(locals_notee), [])
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
  @debug.assert_eq(@ir.hot_pass_requires(rub), [@ir.HotAnalysis::use_def()])
}

///|
test "precompute descriptor split keeps direct pass SSA-free and prefix SSA-backed" {
  let direct = precompute_descriptor()
  let prefix = precompute_propagate_prefix_descriptor()

  @debug.assert_eq(direct.name, "precompute")
  @debug.assert_eq(prefix.name, "precompute-propagate-prefix")
  registry_test_assert_requires(direct, [])
  registry_test_assert_requires(prefix, [@ir.HotAnalysis::ssa()])
  assert_true(@ir.hot_pass_invalidates(direct).contains(@ir.HotAnalysis::ssa()))
  assert_true(@ir.hot_pass_invalidates(prefix).contains(@ir.HotAnalysis::ssa()))
  @debug.assert_eq(pass_registry_category("precompute-propagate-prefix"), None)
}

///|
test "audited pass_require helper metadata contracts stay declared" {
  // Keep this table aligned with audited direct uses of pass_require_* helpers.
  // Add a row here when a pass starts requiring a new analysis, or document the
  // pass as intentionally lazy in its descriptor when eager metadata is wrong.
  registry_test_assert_requires(optimize_instructions_descriptor(), [
    @ir.HotAnalysis::use_def(),
    @ir.HotAnalysis::effects(),
  ])
  registry_test_assert_requires(remove_unused_brs_descriptor(), [
    @ir.HotAnalysis::use_def(),
  ])
  registry_test_assert_requires(precompute_propagate_prefix_descriptor(), [
    @ir.HotAnalysis::ssa(),
  ])
  registry_test_assert_requires(pick_load_signs_descriptor(), [
    @ir.HotAnalysis::use_def(),
  ])
  registry_test_assert_requires(tuple_optimization_descriptor(), [
    @ir.HotAnalysis::use_def(),
  ])
  registry_test_assert_requires(heap2local_descriptor(), [
    @ir.HotAnalysis::use_def(),
  ])
  registry_test_assert_requires(local_cse_descriptor(), [
    @ir.HotAnalysis::effects(),
  ])
}

///|
test "preset expansion stays on implemented active pass names" {
  let optimize = optimize_preset_passes(HotPipelineOptions::new())
  let shrink = shrink_preset_passes(HotPipelineOptions::new())

  assert_true(optimize.length() > 0)
  @debug.assert_eq(optimize, shrink)
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
test "aggressive presets schedule the Binaryen flatten cleanup prelude" {
  assert_true(simplify_locals_notee_nostructure_exact_neighborhood_ready())
  let expected_prefix = [
    "duplicate-function-elimination", "remove-unused-module-elements", "memory-packing",
    "once-reduction", "global-refining", "global-struct-inference", "ssa-nomerge",
    "flatten", "simplify-locals-notee-nostructure", "local-cse", "dead-code-elimination",
  ]
  let optimize = optimize_preset_passes(HotPipelineOptions::new())
  let shrink = shrink_preset_passes(HotPipelineOptions::new())
  @debug.assert_eq(optimize[:expected_prefix.length()], expected_prefix)
  @debug.assert_eq(shrink[:expected_prefix.length()], expected_prefix)
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
test "run_hot_pipeline dispatches flatten through the public registry" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 1 i32.const 2 i32.add))",
  )
  match run_hot_pipeline(input, HotPipelineOptions::new(), ["flatten"]) {
    Ok(output) =>
      match output.code_sec {
        Some(@lib.CodeSec([@lib.Func(locals, _)])) =>
          assert_true(locals.length() > 0)
        other =>
          fail(
            "expected one flattened function, got \{@debug.to_string(other)}",
          )
      }
    Err(err) => fail("expected public flatten dispatch, got \{err}")
  }
}

///|
test "run_hot_pipeline accepts full ssa for direct non-merge sibling work" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) (local i32) i32.const 1 local.set 0 local.get 0))",
  )

  match run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa"]) {
    Ok(_) => ()
    Err(err) =>
      fail("expected active full ssa non-merge pipeline success, got \{err}")
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
      @debug.assert_eq(locals.length(), 4)
    other =>
      fail(
        "expected single-function tuple-optimization module, got \{@debug.to_string(other)}",
      )
  }
}
