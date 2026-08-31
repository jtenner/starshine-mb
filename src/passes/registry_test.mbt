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
    pass_registry_category("simplify-locals-nonesting"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  @debug.assert_eq(
    pass_registry_category("simplify-locals-no-nesting"),
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
    Some(HotPassRegistryCategory::hot_pass()),
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
    pass_registry_category("merge-similar-functions"),
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
    pass_registry_category("apply-compiler-facts"),
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
  let locals_nonesting = simplify_locals_nonesting_descriptor()
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
  @debug.assert_eq(@ir.hot_pass_requires(full_ssa), [@ir.HotAnalysis::cfg()])
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
  @debug.assert_eq(locals_nonesting.name, "simplify-locals-nonesting")
  @debug.assert_eq(@ir.hot_pass_requires(locals_nonesting), [])
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
  @debug.assert_eq(@ir.hot_pass_requires(rub), [])
}

///|
test "precompute descriptors keep plain SSA-free and propagate SSA-backed" {
  let direct = precompute_descriptor()
  let propagate = precompute_propagate_descriptor()

  @debug.assert_eq(direct.name, "precompute")
  @debug.assert_eq(propagate.name, "precompute-propagate")
  registry_test_assert_requires(direct, [])
  registry_test_assert_requires(propagate, [@ir.HotAnalysis::ssa()])
  assert_true(@ir.hot_pass_invalidates(direct).contains(@ir.HotAnalysis::ssa()))
  assert_true(
    @ir.hot_pass_invalidates(propagate).contains(@ir.HotAnalysis::ssa()),
  )
  @debug.assert_eq(
    pass_registry_category("precompute-propagate"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
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
  // RUB uses a lightweight exact node-use count only for the opt-in literal
  // multivalue path, so eager full use-def metadata would be dishonest.
  registry_test_assert_requires(remove_unused_brs_descriptor(), [])
  registry_test_assert_requires(precompute_propagate_descriptor(), [
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
test "O4z preset expansion keeps Binaryen v131's 56 slots plus late local convergence" {
  let options = HotPipelineOptions::new(optimize_level=4, shrink_level=4)
  let optimize = optimize_preset_passes(options)
  let shrink = shrink_preset_passes(options)
  let binaryen_v131 = [
    "duplicate-function-elimination", "remove-unused-module-elements", "memory-packing",
    "once-reduction", "global-refining", "remove-unused-module-elements", "global-struct-inference",
    "ssa-nomerge", "flatten", "simplify-locals-notee-nostructure", "local-cse", "dead-code-elimination",
    "remove-unused-names", "remove-unused-brs", "remove-unused-names", "optimize-instructions",
    "heap-store-optimization", "pick-load-signs", "precompute-propagate", "code-pushing",
    "tuple-optimization", "simplify-locals-nostructure", "vacuum", "reorder-locals",
    "remove-unused-brs", "heap2local", "merge-locals", "optimize-casts", "local-subtyping",
    "coalesce-locals", "local-cse", "simplify-locals", "vacuum", "reorder-locals",
    "coalesce-locals", "reorder-locals", "vacuum", "code-folding", "merge-blocks",
    "remove-unused-brs", "remove-unused-names", "merge-blocks", "precompute-propagate",
    "optimize-instructions", "heap-store-optimization", "redundant-set-elimination",
    "vacuum", "dae-optimizing", "inlining-optimizing", "duplicate-function-elimination",
    "duplicate-import-elimination", "simplify-globals-optimizing", "remove-unused-module-elements",
    "string-gathering", "reorder-globals", "directize",
  ]

  @debug.assert_eq(binaryen_v131.length(), 56)
  @debug.assert_eq(optimize, shrink)
  @debug.assert_eq(optimize[:binaryen_v131.length()], binaryen_v131)
  @debug.assert_eq(optimize[binaryen_v131.length():], [
    "strip-debug", "simplify-locals-nostructure", "coalesce-locals-cfg", "reorder-locals",
    "vacuum", "simplify-locals-nostructure", "coalesce-locals-cfg", "reorder-locals",
    "vacuum", "ssa-nomerge", "simplify-locals-nostructure", "coalesce-locals-cfg",
    "reorder-locals", "vacuum", "ssa-nomerge", "simplify-locals-nostructure", "coalesce-locals-cfg",
    "reorder-locals", "vacuum",
  ])
  @debug.assert_eq(
    optimize.filter(fn(name) { name == "precompute-propagate" }).length(),
    2,
  )
  @debug.assert_eq(
    optimize
    .filter(fn(name) { name == "remove-unused-module-elements" })
    .length(),
    3,
  )
  @debug.assert_eq(
    optimize.filter(fn(name) { name == "remove-unused-brs" }).length(),
    3,
  )
  @debug.assert_eq(optimize.length(), 75)
  @debug.assert_eq(optimize[13], "remove-unused-brs")
  @debug.assert_eq(optimize[24], "remove-unused-brs")
  @debug.assert_eq(optimize[39], "remove-unused-brs")
  assert_false(optimize.contains("precompute"))
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
test "module-aware report expansion exposes every repeated preset boundary" {
  let mod_ = @lib.Module::new()
  let options = HotPipelineOptions::new(optimize_level=4, shrink_level=4)
  let expanded = match
    pass_registry_expanded_names_for_module(mod_, options, ["optimize"]) {
    Ok(names) => names
    Err(err) => fail("expected report expansion success, got \{err}")
  }
  assert_true(expanded.length() > 56)
  @debug.assert_eq(expanded[0], "duplicate-function-elimination")
  @debug.assert_eq(expanded[expanded.length() - 1], "vacuum")
  assert_false(expanded.contains("heap-store-optimization"))
  assert_false(expanded.contains("tuple-optimization"))
  assert_false(expanded.contains("string-gathering"))
  let mut vacuum_count = 0
  for name in expanded {
    if name == "vacuum" {
      vacuum_count += 1
    }
  }
  assert_true(vacuum_count >= 8)
}

///|
test "module-aware report expansion rejects unsupported boundaries" {
  let result = pass_registry_expanded_names_for_module(
    @lib.Module::new(),
    HotPipelineOptions::new(optimize_level=4, shrink_level=4),
    ["gufa"],
  )
  match result {
    Err(message) => assert_true(message.contains("boundary-only"))
    Ok(names) => fail("expected unsupported report expansion, got \{names}")
  }
}

///|
test "public non-O4z presets keep only measured fast-payoff passes" {
  let o1 = optimize_preset_passes(HotPipelineOptions::new(optimize_level=1))
  let o2 = optimize_preset_passes(HotPipelineOptions::new(optimize_level=2))
  let o3 = optimize_preset_passes(HotPipelineOptions::new(optimize_level=3))
  let o4 = optimize_preset_passes(HotPipelineOptions::new(optimize_level=4))
  let os = shrink_preset_passes(
    HotPipelineOptions::new(optimize_level=2, shrink_level=1),
  )
  let oz = shrink_preset_passes(
    HotPipelineOptions::new(optimize_level=2, shrink_level=2),
  )

  let fast_default = ["duplicate-function-elimination", "strip-debug"]
  @debug.assert_eq(o1, fast_default)
  @debug.assert_eq(o2, fast_default)
  let fast_size_or_aggressive = [
    "duplicate-function-elimination", "vacuum", "reorder-locals", "strip-debug",
  ]
  @debug.assert_eq(o3, fast_size_or_aggressive)
  @debug.assert_eq(o4, fast_size_or_aggressive)
  @debug.assert_eq(os, fast_size_or_aggressive)
  @debug.assert_eq(oz, fast_size_or_aggressive)
  for passes in [o1, o2, o3, o4, os, oz] {
    assert_false(passes.contains("dae-optimizing"))
    assert_false(passes.contains("inlining-optimizing"))
    assert_false(passes.contains("optimize-casts"))
    assert_false(passes.contains("merge-blocks"))
  }
}

///|
test "aggressive presets schedule the Binaryen flatten cleanup prelude" {
  assert_true(simplify_locals_notee_nostructure_exact_neighborhood_ready())
  let expected_prefix = [
    "duplicate-function-elimination", "remove-unused-module-elements", "memory-packing",
    "once-reduction", "global-refining", "remove-unused-module-elements", "global-struct-inference",
    "ssa-nomerge", "flatten", "simplify-locals-notee-nostructure", "local-cse", "dead-code-elimination",
  ]
  let options = HotPipelineOptions::new(optimize_level=4, shrink_level=4)
  let optimize = optimize_preset_passes(options)
  let shrink = shrink_preset_passes(options)
  @debug.assert_eq(optimize[:expected_prefix.length()], expected_prefix)
  @debug.assert_eq(shrink[:expected_prefix.length()], expected_prefix)
}

///|
fn registry_test_assert_dae_optimizing_late_slot(
  label : String,
  passes : Array[String],
) -> Unit raise {
  let mut dae_idx = -1
  let mut dae_count = 0
  for idx, name in passes {
    if name == "dae-optimizing" {
      dae_idx = idx
      dae_count += 1
    }
  }
  @debug.assert_eq(dae_count, 1)
  @debug.assert_eq(dae_idx, 47)
  assert_true(dae_idx >= 3, msg="expected \{label} DAEO cleanup prelude")
  assert_true(
    dae_idx + 1 < passes.length(),
    msg="expected \{label} DAEO successor",
  )
  @debug.assert_eq(passes[dae_idx - 3], "heap-store-optimization")
  @debug.assert_eq(passes[dae_idx - 2], "redundant-set-elimination")
  @debug.assert_eq(passes[dae_idx - 1], "vacuum")
  @debug.assert_eq(passes[dae_idx + 1], "inlining-optimizing")
}

///|
test "O4z optimize and shrink presets schedule dae-optimizing in the late postpass slot" {
  let options = HotPipelineOptions::new(optimize_level=4, shrink_level=4)
  registry_test_assert_dae_optimizing_late_slot(
    "runtime optimize",
    optimize_preset_passes(options),
  )
  registry_test_assert_dae_optimizing_late_slot(
    "runtime shrink",
    shrink_preset_passes(options),
  )
  for preset_name in ["optimize", "shrink"] {
    match pass_registry_lookup(preset_name) {
      Some(entry) =>
        registry_test_assert_dae_optimizing_late_slot(
          "registry \{preset_name}",
          entry.expanded_passes,
        )
      None => fail("expected registered \{preset_name} preset")
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
