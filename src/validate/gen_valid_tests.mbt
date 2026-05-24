///|
test "gen_valid_module_result reports success diagnostics" {
  let config = GenValidConfig::natural_default()
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0x5eedUL), config) {
    Ok(v) => v
    Err(failure) =>
      fail(
        "expected gen-valid success, got \{failure.validation_error_message}",
      )
  }
  assert_true(generated.attempts >= 1)
  @debug.assert_eq(generated.config_label, "natural")
  @debug.assert_eq(generated.config, config)
  @debug.assert_eq(generated.facts.mode, Natural)
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected generated module to validate, got \{validation_error_message(err)}",
      )
  }
}

///|
test "gen-valid PRNG stream labels have stable seed derivations" {
  @debug.assert_eq(gen_valid_random_stream_labels().length(), 15)
  @debug.assert_eq(
    gen_valid_random_stream_label_name(ModuleTopologyStream),
    "module-topology",
  )
  @debug.assert_eq(gen_valid_random_stream_label_name(GlobalStream), "globals")
  @debug.assert_eq(gen_valid_random_stream_label_name(TagStream), "tags")
  @debug.assert_eq(gen_valid_random_stream_label_name(StartStream), "start")
  @debug.assert_eq(gen_valid_random_stream_label_name(BodyStream), "bodies")
  @debug.assert_eq(
    gen_valid_derive_stream_seed(0x5eedUL, ModuleTopologyStream),
    gen_valid_derive_stream_seed(0x5eedUL, ModuleTopologyStream),
  )
  assert_true(
    gen_valid_derive_stream_seed(0x5eedUL, ModuleTopologyStream) !=
    gen_valid_derive_stream_seed(0x5eedUL, TypeStream),
    msg="different stream labels should derive independent seeds from the same root seed",
  )
  assert_true(
    gen_valid_derive_stream_seed(0x5eedUL, TypeStream) !=
    gen_valid_derive_stream_seed(0x5eeeUL, TypeStream),
    msg="same stream label should still vary when the root seed changes",
  )
}

///|
test "streamed gen-valid keeps type choices stable when body budget changes" {
  let base_config = {
    ..GenValidConfig::natural_default(),
    max_defined_funcs: 3,
    max_type_defs: 5,
    max_params: 3,
    max_results: 2,
    max_body_statements: 1,
  }
  let bigger_body_config = { ..base_config, max_body_statements: 6 }
  let left = match gen_valid_module_result_from_seed(0x51034UL, base_config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  let right = match
    gen_valid_module_result_from_seed(0x51034UL, bigger_body_config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  @debug.assert_eq(
    gen_valid_test_flat_func_types(left.wasm_module),
    gen_valid_test_flat_func_types(right.wasm_module),
  )
  match validate_module(left.wasm_module) {
    Ok(_) => ()
    Err(err) => fail(validation_error_message(err))
  }
  match validate_module(right.wasm_module) {
    Ok(_) => ()
    Err(err) => fail(validation_error_message(err))
  }
}

///|
test "streamed gen-valid keeps function-local shapes stable when metadata budgets change" {
  let base_config = {
    ..GenValidConfig::natural_default(),
    max_defined_funcs: 3,
    max_type_defs: 5,
    max_imports: 0,
    max_tables: 0,
    max_mems: 0,
    max_globals: 0,
    max_tags: 0,
    max_elems: 0,
    max_datas: 0,
    max_body_statements: 5,
    features: {
      ..GenValidFeatureToggles::natural_default(),
      allow_start: false,
      allow_ref_types: false,
      allow_v128: false,
      allow_typed_body_generator: false,
      allow_imports: false,
    },
    section_bias: {
      ..GenValidSectionBias::natural_default(),
      globals_percent: 100,
    },
  }
  let metadata_heavy_config = { ..base_config, max_globals: 4 }
  let mut checked = 0
  for offset in 0..<64 {
    let seed = 0x51134UL + offset.to_uint64()
    let left = match gen_valid_module_result_from_seed(seed, base_config) {
      Ok(v) => v
      Err(failure) => fail(failure.validation_error_message)
    }
    let right = match
      gen_valid_module_result_from_seed(seed, metadata_heavy_config) {
      Ok(v) => v
      Err(failure) => fail(failure.validation_error_message)
    }
    if left.attempts == 1 &&
      right.attempts == 1 &&
      gen_valid_test_defined_func_type_idxs(left.wasm_module) ==
      gen_valid_test_defined_func_type_idxs(right.wasm_module) {
      checked += 1
      @debug.assert_eq(
        gen_valid_test_defined_func_locals(left.wasm_module),
        gen_valid_test_defined_func_locals(right.wasm_module),
      )
      match validate_module(left.wasm_module) {
        Ok(_) => ()
        Err(err) => fail(validation_error_message(err))
      }
      match validate_module(right.wasm_module) {
        Ok(_) => ()
        Err(err) => fail(validation_error_message(err))
      }
    }
  }
  assert_true(checked > 0)
}

///|
test "streamed gen-valid keeps function type choices stable when metadata budgets change" {
  let base_config = {
    ..GenValidConfig::natural_default(),
    max_defined_funcs: 4,
    max_type_defs: 6,
    max_imports: 0,
    max_tables: 0,
    max_mems: 0,
    max_globals: 0,
    max_tags: 0,
    max_elems: 0,
    max_datas: 0,
    features: {
      ..GenValidFeatureToggles::natural_default(),
      allow_start: false,
      allow_ref_types: false,
      allow_v128: false,
      allow_typed_body_generator: false,
    },
    section_bias: {
      ..GenValidSectionBias::natural_default(),
      mems_percent: 100,
      globals_percent: 100,
    },
  }
  let metadata_heavy_config = {
    ..base_config,
    max_mems: 4,
    max_globals: 4,
    max_datas: 4,
  }
  let mut checked = 0
  for offset in 0..<64 {
    let seed = 0x51035UL + offset.to_uint64()
    let left = match gen_valid_module_result_from_seed(seed, base_config) {
      Ok(v) => v
      Err(failure) => fail(failure.validation_error_message)
    }
    let right = match
      gen_valid_module_result_from_seed(seed, metadata_heavy_config) {
      Ok(v) => v
      Err(failure) => fail(failure.validation_error_message)
    }
    if left.attempts == 1 && right.attempts == 1 {
      checked += 1
      @debug.assert_eq(
        gen_valid_test_flat_func_types(left.wasm_module),
        gen_valid_test_flat_func_types(right.wasm_module),
      )
      @debug.assert_eq(
        gen_valid_test_defined_func_type_idxs(left.wasm_module),
        gen_valid_test_defined_func_type_idxs(right.wasm_module),
      )
      match validate_module(left.wasm_module) {
        Ok(_) => ()
        Err(err) => fail(validation_error_message(err))
      }
      match validate_module(right.wasm_module) {
        Ok(_) => ()
        Err(err) => fail(validation_error_message(err))
      }
    }
  }
  assert_true(checked > 0)
}

///|
test "coverage-forced prelude records deterministic randomized template order" {
  let config = GenValidConfig::coverage_forced_default()
  let left = match
    gen_valid_module_result(@splitmix.new(seed=0xf001UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  let right = match
    gen_valid_module_result(@splitmix.new(seed=0xf002UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  let left_again = match
    gen_valid_module_result(@splitmix.new(seed=0xf001UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  let left_sig = gen_valid_coverage_template_signature(left.wasm_module)
  let right_sig = gen_valid_coverage_template_signature(right.wasm_module)
  @debug.assert_eq(
    left_sig,
    gen_valid_coverage_template_signature(left_again.wasm_module),
  )
  assert_true(left_sig.length() > 0)
  assert_true(right_sig.length() > 0)
  assert_true(
    left_sig != right_sig,
    msg="different seeds should vary coverage-forced template ordering",
  )
  assert_true(left.facts.has_numeric_full_ops)
  assert_true(right.facts.has_numeric_full_ops)
  assert_true(left.facts.has_branch_heavy_control)
  assert_true(right.facts.has_branch_heavy_control)
}

///|
test "coverage-forced prelude varies memory and table template order by seed" {
  let config = GenValidConfig::coverage_forced_default()
  let mut saw_memory_before_table = false
  let mut saw_table_before_memory = false
  for offset in 0..<16 {
    let generated = match
      gen_valid_module_result(
        @splitmix.new(seed=0xf120UL + offset.to_uint64()),
        config,
      ) {
      Ok(v) => v
      Err(failure) => fail(failure.validation_error_message)
    }
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) =>
        fail(
          "expected coverage-forced generated module to validate, got \{validation_error_message(err)}",
        )
    }
    let sig = gen_valid_coverage_template_signature(generated.wasm_module)
    if sig.contains("memory|table") {
      saw_memory_before_table = true
    }
    if sig.contains("table|memory") {
      saw_table_before_memory = true
    }
    assert_true(generated.facts.has_mems)
    assert_true(generated.facts.has_tables)
  }
  assert_true(
    saw_memory_before_table,
    msg="coverage-forced prelude should retain memory-before-table templates for some seeds",
  )
  assert_true(
    saw_table_before_memory,
    msg="coverage-forced prelude should also emit table-before-memory templates for some seeds",
  )
}

///|
test "coverage-forced prelude varies SIMD template phase order by seed" {
  let config = GenValidConfig::coverage_forced_default()
  let mut saw_simd1_before_simd2 = false
  let mut saw_simd2_before_simd1 = false
  for offset in 0..<24 {
    let generated = match
      gen_valid_module_result(
        @splitmix.new(seed=0xf1a0UL + offset.to_uint64()),
        config,
      ) {
      Ok(v) => v
      Err(failure) => fail(failure.validation_error_message)
    }
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) =>
        fail(
          "expected randomized SIMD coverage-forced generated module to validate, got \{validation_error_message(err)}",
        )
    }
    let sig = gen_valid_coverage_template_signature(generated.wasm_module)
    if sig.contains("simd1|simd2") {
      saw_simd1_before_simd2 = true
    }
    if sig.contains("simd2|simd1") {
      saw_simd2_before_simd1 = true
    }
    assert_true(generated.facts.uses_v128)
  }
  assert_true(
    saw_simd1_before_simd2,
    msg="coverage-forced SIMD prelude should retain phase1-before-phase2 ordering for some seeds",
  )
  assert_true(
    saw_simd2_before_simd1,
    msg="coverage-forced SIMD prelude should also emit phase2-before-phase1 ordering for some seeds",
  )
}

///|
test "coverage-forced prelude varies direct indirect and ref call template order by seed" {
  let config = GenValidConfig::coverage_forced_default()
  let mut saw_direct_before_indirect = false
  let mut saw_indirect_before_direct = false
  let mut saw_ref_before_direct = false
  for offset in 0..<24 {
    let generated = match
      gen_valid_module_result(
        @splitmix.new(seed=0xf1d0UL + offset.to_uint64()),
        config,
      ) {
      Ok(v) => v
      Err(failure) => fail(failure.validation_error_message)
    }
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) =>
        fail(
          "expected randomized call coverage-forced generated module to validate, got \{validation_error_message(err)}",
        )
    }
    let sig = gen_valid_coverage_template_signature(generated.wasm_module)
    if sig.contains("direct_call|call_indirect") {
      saw_direct_before_indirect = true
    }
    if sig.contains("call_indirect|direct_call") {
      saw_indirect_before_direct = true
    }
    if sig.contains("call_ref|direct_call") {
      saw_ref_before_direct = true
    }
    assert_true(generated.facts.has_call)
    assert_true(generated.facts.has_call_indirect)
  }
  assert_true(
    saw_direct_before_indirect,
    msg="coverage-forced call prelude should retain direct-call-before-indirect ordering for some seeds",
  )
  assert_true(
    saw_indirect_before_direct,
    msg="coverage-forced call prelude should also emit indirect-call-before-direct ordering for some seeds",
  )
  assert_true(
    saw_ref_before_direct,
    msg="coverage-forced call prelude should sometimes move call_ref templates before direct-call templates",
  )
}

///|
test "coverage-forced prelude varies ref gc and exception template order by seed" {
  let config = GenValidConfig::coverage_forced_default()
  let mut saw_gc_before_ref = false
  let mut saw_ref_before_gc = false
  let mut saw_exception_template = false
  for offset in 0..<32 {
    let generated = match
      gen_valid_module_result(
        @splitmix.new(seed=0xf230UL + offset.to_uint64()),
        config,
      ) {
      Ok(v) => v
      Err(failure) => fail(failure.validation_error_message)
    }
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) =>
        fail(
          "expected randomized ref/GC/exception coverage-forced generated module to validate, got \{validation_error_message(err)}",
        )
    }
    let sig = gen_valid_coverage_template_signature(generated.wasm_module)
    if sig.contains("gc|ref") {
      saw_gc_before_ref = true
    }
    if sig.contains("ref|gc") {
      saw_ref_before_gc = true
    }
    if sig.contains("try_table") {
      saw_exception_template = true
    }
    assert_true(generated.facts.uses_ref_types)
    assert_true(generated.facts.has_gc_constructors)
    assert_true(generated.facts.has_exception_try_table_matrix)
  }
  assert_true(
    saw_gc_before_ref,
    msg="coverage-forced ref/GC prelude should retain GC-before-ref ordering for some seeds",
  )
  assert_true(
    saw_ref_before_gc,
    msg="coverage-forced ref/GC prelude should also emit ref-before-GC ordering for some seeds",
  )
  assert_true(
    saw_exception_template,
    msg="coverage-forced ref/GC randomized template runs should retain exception templates",
  )
}

///|
test "gen_valid named profiles expose stable labels and compatibility aliases" {
  @debug.assert_eq(
    gen_valid_profile_name(CoverageForcedAllFeaturesProfile),
    "coverage-forced-all-features",
  )
  @debug.assert_eq(
    gen_valid_profile_name(TopologyHeavyProfile),
    "topology-heavy",
  )
  @debug.assert_eq(
    gen_valid_profile_name(PathologicalValidProfile),
    "pathological-valid",
  )
  @debug.assert_eq(
    GenValidConfig::for_profile(NaturalSmallProfile).mode,
    Natural,
  )
  @debug.assert_eq(
    GenValidConfig::for_profile(CoverageForcedPortableProfile),
    GenValidConfig::portable_coverage_forced_default(),
  )
  @debug.assert_eq(
    GenValidConfig::for_profile(BinaryenOraclePortableProfile),
    GenValidConfig::binaryen_oracle_coverage_forced_default(),
  )
  @debug.assert_eq(
    gen_valid_profile_name(BinaryenOracleRelaxedSimdProfile),
    "binaryen-oracle-relaxed-simd",
  )
  let relaxed_oracle = GenValidConfig::for_profile(
    BinaryenOracleRelaxedSimdProfile,
  )
  assert_true(relaxed_oracle.features.allow_v128)
  assert_true(relaxed_oracle.features.allow_relaxed_simd)
  assert_false(relaxed_oracle.features.allow_tags)
  assert_false(relaxed_oracle.features.allow_imports)
  assert_false(relaxed_oracle.features.allow_mems)
  @debug.assert_eq(relaxed_oracle.max_tags, 0)
  @debug.assert_eq(relaxed_oracle.max_imports, 0)
  @debug.assert_eq(
    GenValidConfig::for_profile(PassFuzzStressProfile),
    GenValidConfig::binaryen_oracle_coverage_forced_default(),
  )
  @debug.assert_eq(
    gen_valid_config_label(GenValidConfig::for_profile(ValidatorStressProfile)),
    "validator-stress",
  )
  let looked_up = match gen_valid_profile_by_name("Coverage Forced Portable") {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(looked_up, CoverageForcedPortableProfile)
  match GenValidConfig::profile("not-a-profile") {
    Ok(_) => fail("expected unknown gen-valid profile to fail")
    Err(msg) => {
      assert_true(msg.contains("unknown gen-valid profile"))
      assert_true(msg.contains("natural-small"))
      assert_true(msg.contains("binaryen-oracle-portable"))
      assert_true(msg.contains("binaryen-oracle-relaxed-simd"))
      assert_true(msg.contains("topology-heavy"))
      assert_true(msg.contains("pathological-valid"))
    }
  }
}

///|
test "pass-targeted gen-valid profiles expose stable pass recipes" {
  @debug.assert_eq(gen_valid_profile_name(PassCleanupProfile), "pass-cleanup")
  @debug.assert_eq(gen_valid_profile_name(PassDaeProfile), "pass-dae")
  @debug.assert_eq(gen_valid_profile_name(PassInliningProfile), "pass-inlining")
  @debug.assert_eq(gen_valid_profile_name(PassMemoryProfile), "pass-memory")
  @debug.assert_eq(gen_valid_profile_name(PassGcRefProfile), "pass-gc-ref")
  @debug.assert_eq(gen_valid_profile_name(PassControlProfile), "pass-control")

  let cleanup = GenValidConfig::for_profile(PassCleanupProfile)
  @debug.assert_eq(gen_valid_config_label(cleanup), "pass-cleanup")
  assert_false(cleanup.features.allow_imports)
  assert_false(cleanup.features.allow_mems)
  assert_true(cleanup.features.allow_typed_body_generator)
  assert_true(cleanup.max_body_statements >= 8)

  let dae = GenValidConfig::for_profile(PassDaeProfile)
  assert_true(dae.features.allow_calls)
  assert_true(dae.features.allow_globals)
  assert_true(dae.max_defined_funcs >= 6)
  assert_true(dae.max_params >= 3)

  let inlining = GenValidConfig::for_profile(PassInliningProfile)
  assert_true(inlining.features.allow_calls)
  assert_true(inlining.features.allow_tail_calls)
  assert_false(inlining.features.allow_call_indirect)
  assert_true(inlining.max_defined_funcs >= 8)

  let memory = GenValidConfig::for_profile(PassMemoryProfile)
  assert_true(memory.features.allow_mems)
  assert_true(memory.features.allow_atomics)
  assert_true(memory.features.allow_v128)
  assert_true(memory.max_mems >= 2)

  let gc_ref = GenValidConfig::for_profile(PassGcRefProfile)
  assert_true(gc_ref.features.allow_ref_types)
  assert_true(gc_ref.features.allow_subtyping_topology)
  assert_true(gc_ref.max_type_defs >= 12)

  let control = GenValidConfig::for_profile(PassControlProfile)
  assert_true(control.features.allow_branch_heavy_control)
  assert_true(control.features.allow_tail_calls)
  assert_true(control.max_body_depth >= 4)

  match gen_valid_profile_by_name("pass dae") {
    Ok(profile) => @debug.assert_eq(profile, PassDaeProfile)
    Err(msg) => fail(msg)
  }
}

///|
test "pathological-valid profile sets bounded generator budgets" {
  let config = GenValidConfig::for_profile(PathologicalValidProfile)
  @debug.assert_eq(gen_valid_config_label(config), "pathological-valid")
  assert_true(
    config.max_defined_funcs >
    GenValidConfig::natural_default().max_defined_funcs,
  )
  assert_true(
    config.max_body_statements >
    GenValidConfig::natural_default().max_body_statements,
  )
  assert_true(
    config.max_body_depth > GenValidConfig::natural_default().max_body_depth,
  )
  match config.max_instruction_count_budget {
    Some(limit) => assert_true(limit >= 512)
    None => fail("pathological-valid should keep a bounded instruction budget")
  }
  match config.max_expression_depth_budget {
    Some(limit) => assert_true(limit >= 8)
    None =>
      fail("pathological-valid should keep a bounded expression-depth budget")
  }
  match config.max_module_byte_size_budget {
    Some(limit) => assert_true(limit >= 4096)
    None => fail("pathological-valid should keep a bounded byte-size budget")
  }
  match config.max_rec_group_size_budget {
    Some(limit) => assert_true(limit >= 1)
    None => fail("pathological-valid should keep a bounded rec-group budget")
  }
  match config.max_section_count_budget {
    Some(limit) => assert_true(limit >= 8)
    None =>
      fail("pathological-valid should keep a bounded section-count budget")
  }
  assert_true(config.max_name_length >= 32)
  assert_true(config.max_segment_payload_size >= 64)
}

///|
test "gen_valid_module_result reports instruction budget stop diagnostics" {
  let base = GenValidConfig::for_profile(NaturalSmallProfile)
  let config = GenValidConfig::{
    ..base,
    max_instruction_count_budget: Some(-1),
  }
  match gen_valid_module_result(@splitmix.new(seed=0xf351UL), config) {
    Ok(_) =>
      fail("expected negative instruction budget to reject every candidate")
    Err(failure) => {
      @debug.assert_eq(failure.config, config)
      @debug.assert_eq(
        failure.budget_stop,
        Some(InstructionCountBudgetExceeded),
      )
      assert_true(
        failure.validation_error_message.contains("instruction budget"),
      )
      assert_true(failure.validation_error_message.contains("limit -1"))
    }
  }
}

///|
test "gen_valid_module_result reports expression depth budget stop diagnostics" {
  let base = GenValidConfig::for_profile(NaturalSmallProfile)
  let config = GenValidConfig::{ ..base, max_expression_depth_budget: Some(-1) }
  match gen_valid_module_result(@splitmix.new(seed=0xf352UL), config) {
    Ok(_) =>
      fail(
        "expected negative expression-depth budget to reject every candidate",
      )
    Err(failure) => {
      @debug.assert_eq(failure.config, config)
      @debug.assert_eq(failure.budget_stop, Some(ExpressionDepthBudgetExceeded))
      assert_true(
        failure.validation_error_message.contains("expression depth budget"),
      )
      assert_true(failure.validation_error_message.contains("limit -1"))
    }
  }
}

///|
test "gen_valid_module_result reports byte-size budget stop diagnostics" {
  let base = GenValidConfig::for_profile(NaturalSmallProfile)
  let config = GenValidConfig::{ ..base, max_module_byte_size_budget: Some(-1) }
  match gen_valid_module_result(@splitmix.new(seed=0xf353UL), config) {
    Ok(_) =>
      fail("expected negative byte-size budget to reject every candidate")
    Err(failure) => {
      @debug.assert_eq(failure.config, config)
      @debug.assert_eq(failure.budget_stop, Some(ModuleByteSizeBudgetExceeded))
      assert_true(failure.validation_error_message.contains("byte-size budget"))
      assert_true(failure.validation_error_message.contains("limit -1"))
    }
  }
}

///|
test "gen_valid_module_result reports rec-group budget stop diagnostics" {
  let base = GenValidConfig::for_profile(NaturalSmallProfile)
  let config = GenValidConfig::{ ..base, max_rec_group_size_budget: Some(-1) }
  match gen_valid_module_result(@splitmix.new(seed=0xf355UL), config) {
    Ok(_) =>
      fail("expected negative rec-group budget to reject every candidate")
    Err(failure) => {
      @debug.assert_eq(failure.config, config)
      @debug.assert_eq(failure.budget_stop, Some(RecGroupSizeBudgetExceeded))
      assert_true(failure.validation_error_message.contains("rec-group budget"))
      assert_true(failure.validation_error_message.contains("limit -1"))
    }
  }
}

///|
test "gen_valid_module_result reports section-count budget stop diagnostics" {
  let base = GenValidConfig::for_profile(NaturalSmallProfile)
  let config = GenValidConfig::{ ..base, max_section_count_budget: Some(-1) }
  match gen_valid_module_result(@splitmix.new(seed=0xf356UL), config) {
    Ok(_) =>
      fail("expected negative section-count budget to reject every candidate")
    Err(failure) => {
      @debug.assert_eq(failure.config, config)
      @debug.assert_eq(failure.budget_stop, Some(SectionCountBudgetExceeded))
      assert_true(
        failure.validation_error_message.contains("section-count budget"),
      )
      assert_true(failure.validation_error_message.contains("limit -1"))
    }
  }
}

///|
test "gen_valid segment payload cap bounds generated data payloads" {
  let base = GenValidConfig::for_profile(MemoryHeavyProfile)
  let config = GenValidConfig::{ ..base, max_segment_payload_size: 3 }
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0xf354UL), config) {
    Ok(generated) => generated
    Err(failure) => fail(failure.validation_error_message)
  }
  match generated.wasm_module.data_sec {
    Some(DataSec(datas)) =>
      for data in datas {
        let Data(_, bytes) = data
        assert_true(bytes.length() <= 3)
      }
    None => fail("memory-heavy coverage should generate data segments")
  }
}

///|
fn gen_valid_test_total_func_count(mod_ : Module) -> Int {
  let import_funcs = match mod_.import_sec {
    Some(ImportSec(imports)) => {
      let mut count = 0
      for import_ in imports {
        let Import(_, _, extern_type) = import_
        match extern_type {
          FuncExternType(_) => count += 1
          _ => ()
        }
      }
      count
    }
    None => 0
  }
  let defined_funcs = match mod_.func_sec {
    Some(FuncSec(funcs)) => funcs.length()
    None => 0
  }
  import_funcs + defined_funcs
}

///|
fn gen_valid_test_import_module_count(mod_ : Module) -> Int {
  let modules : Array[Name] = []
  match mod_.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(module_name, _, _) = import_
        let mut seen = false
        for existing in modules {
          if existing == module_name {
            seen = true
          }
        }
        if !seen {
          modules.push(module_name)
        }
      }
    None => ()
  }
  modules.length()
}

///|
fn gen_valid_test_has_repeated_export_idx(mod_ : Module) -> Bool {
  match mod_.export_sec {
    Some(ExportSec(exports)) => {
      let seen : Array[ExternIdx] = []
      for export_ in exports {
        let Export(_, idx) = export_
        for prior in seen {
          if prior == idx {
            return true
          }
        }
        seen.push(idx)
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_test_has_export_named(mod_ : Module, name : String) -> Bool {
  match mod_.export_sec {
    Some(ExportSec(exports)) => {
      for export_ in exports {
        let Export(export_name, _) = export_
        if export_name == Name::new(name) {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_test_has_any_export(mod_ : Module) -> Bool {
  match mod_.export_sec {
    Some(ExportSec(exports)) => !exports.is_empty()
    None => false
  }
}

///|
fn gen_valid_test_has_nonzero_resource_export(mod_ : Module) -> Bool {
  match mod_.export_sec {
    Some(ExportSec(exports)) => {
      for export_ in exports {
        let Export(_, idx) = export_
        match idx {
          TableExternIdx(TableIdx(table_idx)) if table_idx.reinterpret_as_int() >
            0 => return true
          MemExternIdx(MemIdx(mem_idx)) if mem_idx.reinterpret_as_int() > 0 =>
            return true
          GlobalExternIdx(GlobalIdx(global_idx)) if global_idx.reinterpret_as_int() >
            0 => return true
          TagExternIdx(TagIdx(tag_idx)) if tag_idx.reinterpret_as_int() > 0 =>
            return true
          _ => ()
        }
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_test_has_nonzero_active_elem(mod_ : Module) -> Bool {
  match mod_.elem_sec {
    Some(ElemSec(elems)) => {
      for elem in elems {
        let Elem(mode, _) = elem
        match mode {
          Active(TableIdx(table_idx), _) if table_idx.reinterpret_as_int() > 0 =>
            return true
          _ => ()
        }
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_test_has_nonzero_active_data(mod_ : Module) -> Bool {
  match mod_.data_sec {
    Some(DataSec(datas)) => {
      for data in datas {
        let Data(mode, _) = data
        match mode {
          Active(MemIdx(mem_idx), _) if mem_idx.reinterpret_as_int() > 0 =>
            return true
          _ => ()
        }
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_test_non_name_custom_count(mod_ : Module) -> Int {
  let mut count = 0
  for custom in mod_.custom_secs {
    let CustomSec(name, _) = custom
    if name != Name::new("name") {
      count += 1
    }
  }
  count
}

///|
fn gen_valid_test_idx_is_nonzero_mem(mem_idx : MemIdx) -> Bool {
  let MemIdx(mem_idx_u) = mem_idx
  mem_idx_u.reinterpret_as_int() > 0
}

///|
fn gen_valid_test_idx_is_nonzero_table(table_idx : TableIdx) -> Bool {
  let TableIdx(table_idx_u) = table_idx
  table_idx_u.reinterpret_as_int() > 0
}

///|
fn gen_valid_test_memarg_has_nonzero_mem(ma : MemArg) -> Bool {
  let MemArg(_, mem_idx, _) = ma
  match mem_idx {
    Some(idx) => gen_valid_test_idx_is_nonzero_mem(idx)
    None => false
  }
}

///|
fn gen_valid_test_instr_is_scalar_memory_over_nonzero_mem(
  instr : Instruction,
) -> Bool {
  match instr {
    I32Load(ma)
    | I64Load(ma)
    | F32Load(ma)
    | F64Load(ma)
    | I32Load8S(ma)
    | I32Load8U(ma)
    | I32Load16S(ma)
    | I32Load16U(ma)
    | I64Load8S(ma)
    | I64Load8U(ma)
    | I64Load16S(ma)
    | I64Load16U(ma)
    | I64Load32S(ma)
    | I64Load32U(ma)
    | I32Store(ma)
    | I64Store(ma)
    | F32Store(ma)
    | F64Store(ma)
    | I32Store8(ma)
    | I32Store16(ma)
    | I64Store8(ma)
    | I64Store16(ma)
    | I64Store32(ma) => gen_valid_test_memarg_has_nonzero_mem(ma)
    _ => false
  }
}

///|
fn gen_valid_test_instrs_have_scalar_memory_over_nonzero_mem(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    if gen_valid_test_instr_is_scalar_memory_over_nonzero_mem(instr) {
      return true
    }
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_instrs_have_scalar_memory_over_nonzero_mem(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_instrs_have_scalar_memory_over_nonzero_mem(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_instrs_have_scalar_memory_over_nonzero_mem(
              body,
            ) => return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_instr_is_simd_memory_over_nonzero_mem(
  instr : Instruction,
) -> Bool {
  match instr {
    V128Load(ma)
    | V128Store(ma)
    | V128Load8x8S(ma)
    | V128Load8x8U(ma)
    | V128Load16x4S(ma)
    | V128Load16x4U(ma)
    | V128Load32x2S(ma)
    | V128Load32x2U(ma)
    | V128Load8Splat(ma)
    | V128Load16Splat(ma)
    | V128Load32Splat(ma)
    | V128Load64Splat(ma)
    | V128Load32Zero(ma)
    | V128Load64Zero(ma) => gen_valid_test_memarg_has_nonzero_mem(ma)
    V128Load8Lane(ma, _)
    | V128Load16Lane(ma, _)
    | V128Load32Lane(ma, _)
    | V128Load64Lane(ma, _)
    | V128Store8Lane(ma, _)
    | V128Store16Lane(ma, _)
    | V128Store32Lane(ma, _)
    | V128Store64Lane(ma, _) => gen_valid_test_memarg_has_nonzero_mem(ma)
    _ => false
  }
}

///|
fn gen_valid_test_instrs_have_simd_memory_over_nonzero_mem(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    if gen_valid_test_instr_is_simd_memory_over_nonzero_mem(instr) {
      return true
    }
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_instrs_have_simd_memory_over_nonzero_mem(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_instrs_have_simd_memory_over_nonzero_mem(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_instrs_have_simd_memory_over_nonzero_mem(
              body,
            ) => return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_scalar_memory_over_nonzero_mem(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) => {
      for func in funcs {
        let Func(_, Expr(body)) = func
        if gen_valid_test_instrs_have_scalar_memory_over_nonzero_mem(body) {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_test_has_simd_memory_over_nonzero_mem(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) => {
      for func in funcs {
        let Func(_, Expr(body)) = func
        if gen_valid_test_instrs_have_simd_memory_over_nonzero_mem(body) {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_test_instr_has_simd_lane(
  instr : Instruction,
  lane_count : Int,
  expected : LaneIdx,
) -> Bool {
  match instr {
    I8x16ExtractLaneS(li)
    | I8x16ExtractLaneU(li)
    | I8x16ReplaceLane(li)
    | V128Load8Lane(_, li)
    | V128Store8Lane(_, li) => lane_count == 16 && li == expected
    I16x8ExtractLaneS(li)
    | I16x8ExtractLaneU(li)
    | I16x8ReplaceLane(li)
    | V128Load16Lane(_, li)
    | V128Store16Lane(_, li) => lane_count == 8 && li == expected
    I32x4ExtractLane(li)
    | I32x4ReplaceLane(li)
    | F32x4ExtractLane(li)
    | F32x4ReplaceLane(li)
    | V128Load32Lane(_, li)
    | V128Store32Lane(_, li) => lane_count == 4 && li == expected
    I64x2ExtractLane(li)
    | I64x2ReplaceLane(li)
    | F64x2ExtractLane(li)
    | F64x2ReplaceLane(li)
    | V128Load64Lane(_, li)
    | V128Store64Lane(_, li) => lane_count == 2 && li == expected
    _ => false
  }
}

///|
fn gen_valid_test_instrs_have_simd_lane(
  instrs : Array[Instruction],
  lane_count : Int,
  expected : LaneIdx,
) -> Bool {
  for instr in instrs {
    if gen_valid_test_instr_has_simd_lane(instr, lane_count, expected) {
      return true
    }
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_instrs_have_simd_lane(body, lane_count, expected) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_instrs_have_simd_lane(then_body, lane_count, expected) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_instrs_have_simd_lane(
              body, lane_count, expected,
            ) => return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_simd_lane(
  mod_ : Module,
  lane_count : Int,
  expected : LaneIdx,
) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) => {
      for func in funcs {
        let Func(_, Expr(body)) = func
        if gen_valid_test_instrs_have_simd_lane(body, lane_count, expected) {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_test_flat_func_types(mod_ : Module) -> Array[FuncType] {
  let out : Array[FuncType] = []
  match mod_.type_sec {
    Some(TypeSec(types)) =>
      for rec in types {
        match rec {
          SingleRecType(st) =>
            match st.get_comptype() {
              FuncCompType(params, results) =>
                out.push(FuncType::new(params, results))
              _ => ()
            }
          GroupRecType(sts) =>
            for st in sts {
              match st.get_comptype() {
                FuncCompType(params, results) =>
                  out.push(FuncType::new(params, results))
                _ => ()
              }
            }
        }
      }
    None => ()
  }
  out
}

///|
fn gen_valid_test_typeidx_to_int(idx : TypeIdx) -> Int {
  match idx {
    TypeIdx(i) | RecIdx(i) => i.reinterpret_as_int()
  }
}

///|
fn gen_valid_test_defined_func_type_idxs(mod_ : Module) -> Array[Int] {
  match mod_.func_sec {
    Some(FuncSec(type_idxs)) => {
      let out : Array[Int] = []
      for type_idx in type_idxs {
        out.push(gen_valid_test_typeidx_to_int(type_idx))
      }
      out
    }
    None => []
  }
}

///|
fn gen_valid_test_defined_func_locals(mod_ : Module) -> Array[Locals] {
  match mod_.code_sec {
    Some(CodeSec(funcs)) => {
      let out : Array[Locals] = []
      for func in funcs {
        let Func(locals, _) = func
        out.push(locals)
      }
      out
    }
    None => []
  }
}

///|
fn gen_valid_test_defined_func_type(
  func_types : Array[FuncType],
  func_type_idxs : Array[TypeIdx],
  defined_idx : Int,
) -> FuncType? {
  match func_type_idxs.get(defined_idx) {
    Some(type_idx) => func_types.get(gen_valid_test_typeidx_to_int(type_idx))
    None => None
  }
}

///|
fn gen_valid_test_func_has_v128_local(
  func_type : FuncType,
  locals : Locals,
) -> Bool {
  let FuncType(params, _) = func_type
  for vt in params {
    if vt == ValType::v128() {
      return true
    }
  }
  for vt in locals.iter() {
    if vt == ValType::v128() {
      return true
    }
  }
  false
}

///|
fn gen_valid_test_func_local_type(
  func_type : FuncType,
  locals : Locals,
  idx : LocalIdx,
) -> ValType? {
  let FuncType(params, _) = func_type
  let LocalIdx(i) = idx
  let local_i = i.reinterpret_as_int()
  if local_i < params.length() {
    Some(params[local_i])
  } else {
    locals.at(local_i - params.length())
  }
}

///|
fn gen_valid_test_instrs_have_v128_local_set(
  instrs : Array[Instruction],
  func_type : FuncType,
  locals : Locals,
) -> Bool {
  for instr in instrs {
    match instr {
      LocalSet(idx) | LocalTee(idx) =>
        if gen_valid_test_func_local_type(func_type, locals, idx) ==
          Some(ValType::v128()) {
          return true
        }
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_instrs_have_v128_local_set(body, func_type, locals) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_instrs_have_v128_local_set(
            then_body, func_type, locals,
          ) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_instrs_have_v128_local_set(
              body, func_type, locals,
            ) => return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_instrs_have_v128_result_control(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      Block(ValTypeBlockType(vt), _)
      | Loop(ValTypeBlockType(vt), _)
      | If(ValTypeBlockType(vt), _, _) if vt == ValType::v128() => return true
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_instrs_have_v128_result_control(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_instrs_have_v128_result_control(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_instrs_have_v128_result_control(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_v128_threaded_body(mod_ : Module) -> Bool {
  let func_types = gen_valid_test_flat_func_types(mod_)
  match (mod_.func_sec, mod_.code_sec) {
    (Some(FuncSec(type_idxs)), Some(CodeSec(funcs))) => {
      let mut saw_v128_signature = false
      let mut saw_v128_local = false
      let mut saw_v128_local_set = false
      let mut saw_v128_result_control = false
      for i = 0; i < funcs.length(); i = i + 1 {
        match gen_valid_test_defined_func_type(func_types, type_idxs, i) {
          Some(func_type) => {
            let FuncType(params, results) = func_type
            if params.contains(ValType::v128()) ||
              results.contains(ValType::v128()) {
              saw_v128_signature = true
            }
            let Func(locals, Expr(body)) = funcs[i]
            if gen_valid_test_func_has_v128_local(func_type, locals) {
              saw_v128_local = true
            }
            if gen_valid_test_instrs_have_v128_local_set(
                body, func_type, locals,
              ) {
              saw_v128_local_set = true
            }
            if gen_valid_test_instrs_have_v128_result_control(body) {
              saw_v128_result_control = true
            }
          }
          None => ()
        }
      }
      saw_v128_signature &&
      saw_v128_local &&
      saw_v128_local_set &&
      saw_v128_result_control
    }
    _ => false
  }
}

///|
fn gen_valid_test_instrs_have_nonzero_memory_copy(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      MemoryCopy(dst, src) if gen_valid_test_idx_is_nonzero_mem(dst) ||
        gen_valid_test_idx_is_nonzero_mem(src) => return true
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_instrs_have_nonzero_memory_copy(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_instrs_have_nonzero_memory_copy(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_instrs_have_nonzero_memory_copy(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_nonzero_memory_copy(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) => {
      for func in funcs {
        let Func(_, Expr(body)) = func
        if gen_valid_test_instrs_have_nonzero_memory_copy(body) {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_test_has_nonzero_memory_init(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) => {
      for func in funcs {
        let Func(_, Expr(body)) = func
        if gen_valid_test_instrs_have_nonzero_memory_init(body) {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_test_instrs_have_nonzero_table_copy_or_fill(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      TableFill(table_idx) if gen_valid_test_idx_is_nonzero_table(table_idx) =>
        return true
      TableCopy(dst, src) if gen_valid_test_idx_is_nonzero_table(dst) ||
        gen_valid_test_idx_is_nonzero_table(src) => return true
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_instrs_have_nonzero_table_copy_or_fill(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_instrs_have_nonzero_table_copy_or_fill(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_instrs_have_nonzero_table_copy_or_fill(
              body,
            ) => return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_instrs_have_nonzero_memory_init(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      MemoryInit(_, mem_idx) if gen_valid_test_idx_is_nonzero_mem(mem_idx) =>
        return true
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_instrs_have_nonzero_memory_init(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_instrs_have_nonzero_memory_init(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_instrs_have_nonzero_memory_init(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_instrs_have_nonzero_table_init(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      TableInit(_, table_idx) if gen_valid_test_idx_is_nonzero_table(table_idx) =>
        return true
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_instrs_have_nonzero_table_init(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_instrs_have_nonzero_table_init(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_instrs_have_nonzero_table_init(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_collect_nonzero_table_access(
  instrs : Array[Instruction],
  saw_get : Ref[Bool],
  saw_set : Ref[Bool],
  saw_grow : Ref[Bool],
  saw_size : Ref[Bool],
) -> Unit {
  for instr in instrs {
    match instr {
      TableGet(table_idx) if gen_valid_test_idx_is_nonzero_table(table_idx) =>
        saw_get.val = true
      TableSet(table_idx) if gen_valid_test_idx_is_nonzero_table(table_idx) =>
        saw_set.val = true
      TableGrow(table_idx) if gen_valid_test_idx_is_nonzero_table(table_idx) =>
        saw_grow.val = true
      TableSize(table_idx) if gen_valid_test_idx_is_nonzero_table(table_idx) =>
        saw_size.val = true
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        gen_valid_test_collect_nonzero_table_access(
          body, saw_get, saw_set, saw_grow, saw_size,
        )
      If(_, then_body, else_body) => {
        gen_valid_test_collect_nonzero_table_access(
          then_body, saw_get, saw_set, saw_grow, saw_size,
        )
        match else_body {
          Some(body) =>
            gen_valid_test_collect_nonzero_table_access(
              body, saw_get, saw_set, saw_grow, saw_size,
            )
          None => ()
        }
      }
      _ => ()
    }
  }
}

///|
fn gen_valid_test_has_nonzero_table_copy_or_fill(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) => {
      for func in funcs {
        let Func(_, Expr(body)) = func
        if gen_valid_test_instrs_have_nonzero_table_copy_or_fill(body) {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_test_has_nonzero_table_init(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) => {
      for func in funcs {
        let Func(_, Expr(body)) = func
        if gen_valid_test_instrs_have_nonzero_table_init(body) {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_test_has_all_nonzero_table_accesses(mod_ : Module) -> Bool {
  let saw_get = Ref::new(false)
  let saw_set = Ref::new(false)
  let saw_grow = Ref::new(false)
  let saw_size = Ref::new(false)
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, Expr(body)) = func
        gen_valid_test_collect_nonzero_table_access(
          body, saw_get, saw_set, saw_grow, saw_size,
        )
      }
    None => ()
  }
  saw_get.val && saw_set.val && saw_grow.val && saw_size.val
}

///|
test "memory-heavy profile emits nonzero memory bulk and segment operators" {
  let config = GenValidConfig::for_profile(MemoryHeavyProfile)
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0xf71007UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected memory-heavy generated module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(generated.facts.has_data_segment_range)
  assert_true(
    gen_valid_test_has_nonzero_memory_copy(generated.wasm_module),
    msg="memory-heavy profile should emit memory.copy coverage over a nonzero memory index",
  )
  assert_true(
    gen_valid_test_has_nonzero_memory_init(generated.wasm_module),
    msg="memory-heavy profile should emit memory.init coverage over a nonzero memory index",
  )
  assert_true(
    gen_valid_test_has_scalar_memory_over_nonzero_mem(generated.wasm_module),
    msg="memory-heavy profile should emit scalar memory coverage over a nonzero memory index",
  )
}

///|
test "topology-heavy profile emits nonzero table bulk and element operators" {
  let config = GenValidConfig::for_profile(TopologyHeavyProfile)
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0xf71008UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected topology-heavy generated module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(generated.facts.has_element_segment_range)
  assert_true(
    gen_valid_test_has_nonzero_table_copy_or_fill(generated.wasm_module),
    msg="topology-heavy profile should emit table.fill or table.copy coverage over a nonzero table index",
  )
  assert_true(
    gen_valid_test_has_nonzero_table_init(generated.wasm_module),
    msg="topology-heavy profile should emit table.init coverage over a nonzero table index",
  )
  assert_true(
    gen_valid_test_has_all_nonzero_table_accesses(generated.wasm_module),
    msg="topology-heavy profile should emit table get, set, grow, and size coverage over a nonzero table index",
  )
}

///|
test "topology-heavy profile emits high-index import export topology" {
  let config = GenValidConfig::for_profile(TopologyHeavyProfile)
  assert_true(config.max_defined_funcs >= 16)
  assert_true(config.max_imports >= 12)
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0xf71003UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected topology-heavy generated module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(
    gen_valid_test_total_func_count(generated.wasm_module) >= 10,
    msg="topology-heavy profile should exercise high function indices",
  )
  assert_true(
    gen_valid_test_import_module_count(generated.wasm_module) >= 2,
    msg="topology-heavy profile should use multiple import module names",
  )
  assert_true(
    gen_valid_test_has_repeated_export_idx(generated.wasm_module),
    msg="topology-heavy profile should export the same item under distinct names",
  )
  assert_true(
    gen_valid_test_has_nonzero_resource_export(generated.wasm_module),
    msg="topology-heavy profile should export nonzero table/memory/global/tag indices",
  )
  assert_true(
    gen_valid_test_has_nonzero_active_elem(generated.wasm_module),
    msg="topology-heavy profile should place an active element segment on a nonzero table index",
  )
  assert_true(
    gen_valid_test_has_nonzero_active_data(generated.wasm_module),
    msg="topology-heavy profile should place an active data segment on a nonzero memory index",
  )
  assert_true(
    gen_valid_test_non_name_custom_count(generated.wasm_module) >= 2,
    msg="topology-heavy profile should emit multiple non-name custom sections in the binary-supported leading custom section area",
  )
  assert_true(generated.facts.has_import_export_topology)
  assert_true(generated.facts.has_imports_start_exports)
}

///|
test "topology-heavy profile emits explicit no-main and no-export variants" {
  let config = GenValidConfig::for_profile(TopologyHeavyProfile)
  let mut saw_no_main_export = false
  let mut saw_no_export = false
  for offset in 0..<32 {
    let generated = match
      gen_valid_module_result(
        @splitmix.new(seed=0xf71030UL + offset.to_uint64()),
        config,
      ) {
      Ok(v) => v
      Err(failure) => fail(failure.validation_error_message)
    }
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) =>
        fail(
          "expected topology-heavy generated module to validate, got \{validation_error_message(err)}",
        )
    }
    if gen_valid_test_has_any_export(generated.wasm_module) &&
      !gen_valid_test_has_export_named(generated.wasm_module, "main") {
      saw_no_main_export = true
    }
    if !gen_valid_test_has_any_export(generated.wasm_module) {
      saw_no_export = true
      assert_false(generated.facts.has_imports_start_exports)
    }
  }
  assert_true(
    saw_no_main_export,
    msg="topology-heavy profile should sometimes avoid the conventional main export name",
  )
  assert_true(
    saw_no_export,
    msg="topology-heavy profile should sometimes generate modules without exports",
  )
}

///|
test "gen_valid_module_with_config remains deterministic compatibility wrapper" {
  let config = GenValidConfig::binaryen_oracle_coverage_forced_default()
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0x51eedUL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  let wrapped = gen_valid_module_with_config(
    @splitmix.new(seed=0x51eedUL),
    config,
  )
  @debug.assert_eq(wrapped, generated.wasm_module)
  @debug.assert_eq(generated.config_label, "binaryen-oracle-coverage-forced")
}

///|
fn gen_valid_test_count_local_set_instrs(instrs : Array[Instruction]) -> Int {
  let mut count = 0
  for instr in instrs {
    count += match instr {
      LocalSet(_) => 1
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        gen_valid_test_count_local_set_instrs(body)
      If(_, then_body, else_body) => {
        let else_count = match else_body {
          Some(body) => gen_valid_test_count_local_set_instrs(body)
          None => 0
        }
        gen_valid_test_count_local_set_instrs(then_body) + else_count
      }
      _ => 0
    }
  }
  count
}

///|
fn gen_valid_test_local_idx_is_high(idx : LocalIdx) -> Bool {
  let LocalIdx(raw) = idx
  raw >= 16U
}

///|
fn gen_valid_test_instrs_have_high_local_access(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      LocalGet(idx) | LocalSet(idx) | LocalTee(idx) =>
        if gen_valid_test_local_idx_is_high(idx) {
          return true
        }
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_instrs_have_high_local_access(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_instrs_have_high_local_access(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_instrs_have_high_local_access(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_module_has_high_local_access(mod : Module) -> Bool {
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, Expr(instrs)) = func
        if gen_valid_test_instrs_have_high_local_access(instrs) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn gen_valid_test_module_has_empty_zero_local_body(mod : Module) -> Bool {
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(locals, Expr(instrs)) = func
        if locals.length() == 0 && instrs.is_empty() {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn gen_valid_test_module_has_unreachable_result_body(mod : Module) -> Bool {
  match (mod.func_sec, mod.code_sec) {
    (Some(FuncSec(type_idxs)), Some(CodeSec(funcs))) =>
      for i = 0; i < funcs.length() && i < type_idxs.length(); i = i + 1 {
        if gen_valid_module_typeidx_has_multiple_results(mod, type_idxs[i]) {
          let Func(_, Expr(instrs)) = funcs[i]
          if instrs == [Instruction::unreachable_()] {
            return true
          }
        }
      }
    _ => ()
  }
  false
}

///|
fn gen_valid_test_module_has_local_name_entries(mod : Module) -> Bool {
  match mod.name_sec {
    Some(name_sec) =>
      match name_sec.local_names {
        Some(IndirectNameMap(entries)) => !entries.is_empty()
        None => false
      }
    None => false
  }
}

///|
fn gen_valid_test_has_i64_const_local_set(instrs : Array[Instruction]) -> Bool {
  for i = 0; i + 1 < instrs.length(); i = i + 1 {
    match (instrs[i], instrs[i + 1]) {
      (I64Const(_), LocalSet(_)) => return true
      _ => ()
    }
  }
  for instr in instrs {
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_i64_const_local_set(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_i64_const_local_set(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_i64_const_local_set(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_typed_payload_br_value_block(
  instrs : Array[Instruction],
  wanted : ValType,
) -> Bool {
  for instr in instrs {
    match instr {
      Block(ValTypeBlockType(vt), Expr(body)) if vt == wanted => {
        for i = 0; i + 1 < body.length(); i = i + 1 {
          match body[i + 1] {
            Br(label) if label == LabelIdx::new(0U) => return true
            _ => ()
          }
        }
        if gen_valid_test_has_typed_payload_br_value_block(body, wanted) {
          return true
        }
      }
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_typed_payload_br_value_block(body, wanted) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_typed_payload_br_value_block(then_body, wanted) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_typed_payload_br_value_block(
              body, wanted,
            ) => return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_i32_payload_br_value_block(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      Block(ValTypeBlockType(vt), Expr(body)) if vt == ValType::i32() => {
        for i = 0; i + 1 < body.length(); i = i + 1 {
          match (body[i], body[i + 1]) {
            (I32Const(_), Br(label)) if label == LabelIdx::new(0U) =>
              return true
            _ => ()
          }
        }
        if gen_valid_test_has_i32_payload_br_value_block(body) {
          return true
        }
      }
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_i32_payload_br_value_block(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_i32_payload_br_value_block(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_i32_payload_br_value_block(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_i32_payload_br_if_value_block(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      Block(ValTypeBlockType(vt), Expr(body)) if vt == ValType::i32() => {
        for i = 0; i + 2 < body.length(); i = i + 1 {
          match (body[i], body[i + 1], body[i + 2]) {
            (I32Const(_), I32Const(_), BrIf(label)) if label ==
              LabelIdx::new(0U) => return true
            _ => ()
          }
        }
        if gen_valid_test_has_i32_payload_br_if_value_block(body) {
          return true
        }
      }
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_i32_payload_br_if_value_block(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_i32_payload_br_if_value_block(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_i32_payload_br_if_value_block(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_i32_payload_br_table_value_block(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      Block(ValTypeBlockType(vt), Expr(body)) if vt == ValType::i32() => {
        for i = 0; i + 2 < body.length(); i = i + 1 {
          match (body[i], body[i + 1], body[i + 2]) {
            (I32Const(_), I32Const(_), BrTable(targets, default_label)) if default_label ==
              LabelIdx::new(0U) &&
              targets.length() > 0 &&
              targets[0] == LabelIdx::new(0U) => return true
            _ => ()
          }
        }
        if gen_valid_test_has_i32_payload_br_table_value_block(body) {
          return true
        }
      }
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_i32_payload_br_table_value_block(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_i32_payload_br_table_value_block(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_i32_payload_br_table_value_block(
              body,
            ) => return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_typed_select_for(
  instrs : Array[Instruction],
  wanted : ValType,
) -> Bool {
  for instr in instrs {
    match instr {
      Select(Some(types)) if types.length() == 1 && types[0] == wanted =>
        return true
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_typed_select_for(body, wanted) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_typed_select_for(then_body, wanted) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_typed_select_for(body, wanted) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_outer_payload_branch(
  instrs : Array[Instruction],
  wanted : ValType,
) -> Bool {
  for instr in instrs {
    match instr {
      Block(ValTypeBlockType(vt), Expr(body)) if vt == wanted => {
        for inner in body {
          match inner {
            Block(_, Expr(nested)) | Loop(_, Expr(nested)) =>
              for nested_instr in nested {
                match nested_instr {
                  Br(label) | BrIf(label) if label == LabelIdx::new(1U) =>
                    return true
                  BrTable(targets, default_label) if default_label ==
                    LabelIdx::new(1U) =>
                    if targets.length() > 0 && targets[0] == LabelIdx::new(1U) {
                      return true
                    }
                  _ => ()
                }
              }
            _ => ()
          }
        }
        if gen_valid_test_has_outer_payload_branch(body, wanted) {
          return true
        }
      }
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_outer_payload_branch(body, wanted) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_outer_payload_branch(then_body, wanted) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_outer_payload_branch(body, wanted) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_i32_result_loop(instrs : Array[Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      Loop(ValTypeBlockType(vt), Expr(body)) if vt == ValType::i32() => {
        for inner in body {
          match inner {
            I32Const(_) => return true
            _ => ()
          }
        }
        if gen_valid_test_has_i32_result_loop(body) {
          return true
        }
      }
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_i32_result_loop(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_i32_result_loop(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_i32_result_loop(body) => return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_nested_return(instrs : Array[Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) => {
        for inner in body {
          match inner {
            Return => return true
            _ => ()
          }
        }
        if gen_valid_test_has_nested_return(body) {
          return true
        }
      }
      If(_, then_body, else_body) => {
        for inner in then_body {
          match inner {
            Return => return true
            _ => ()
          }
        }
        if gen_valid_test_has_nested_return(then_body) {
          return true
        }
        match else_body {
          Some(body) => {
            for inner in body {
              match inner {
                Return => return true
                _ => ()
              }
            }
            if gen_valid_test_has_nested_return(body) {
              return true
            }
          }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_module_local_set_count(mod_ : Module) -> Int {
  match mod_.code_sec {
    Some(CodeSec(funcs)) => {
      let mut count = 0
      for func in funcs {
        let Func(_, Expr(instrs)) = func
        count += gen_valid_test_count_local_set_instrs(instrs)
      }
      count
    }
    None => 0
  }
}

///|
fn gen_valid_test_module_has_i64_const_local_set(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, Expr(instrs)) = func
        if gen_valid_test_has_i64_const_local_set(instrs) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn gen_valid_test_func_type_results(
  mod_ : Module,
  type_idx : TypeIdx,
) -> Array[ValType]? {
  let wanted = match type_idx {
    TypeIdx(type_idx_u) | RecIdx(type_idx_u) => type_idx_u.reinterpret_as_int()
  }
  match mod_.type_sec {
    Some(TypeSec(types)) => {
      let mut cursor = 0
      for rec_type in types {
        match rec_type {
          SingleRecType(SubType(_, _, _, FuncCompType(_, results)))
          | SingleRecType(CompTypeSubType(_, FuncCompType(_, results))) =>
            if cursor == wanted {
              return Some(results)
            }
          GroupRecType(group) =>
            for subtype in group {
              match subtype {
                SubType(_, _, _, FuncCompType(_, results))
                | CompTypeSubType(_, FuncCompType(_, results)) =>
                  if cursor == wanted {
                    return Some(results)
                  }
                _ => ()
              }
              cursor += 1
            }
          _ => ()
        }
        match rec_type {
          SingleRecType(_) => cursor += 1
          GroupRecType(_) => ()
        }
      }
      None
    }
    None => None
  }
}

///|
fn gen_valid_test_has_multivalue_typeidx_block(
  mod_ : Module,
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      Block(TypeIdxBlockType(type_idx), Expr(body)) => {
        match gen_valid_test_func_type_results(mod_, type_idx) {
          Some(results) if results.length() > 1 => return true
          _ => ()
        }
        if gen_valid_test_has_multivalue_typeidx_block(mod_, body) {
          return true
        }
      }
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_multivalue_typeidx_block(mod_, body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_multivalue_typeidx_block(mod_, then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_multivalue_typeidx_block(mod_, body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_val_type_is_exact_ref(vt : ValType) -> Bool {
  match vt {
    RefTypeValType(rt) => rt.is_exact()
    _ => false
  }
}

///|
fn gen_valid_test_module_has_exact_ref_local(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(locals, _) = func
        for vt in locals.iter() {
          if gen_valid_test_val_type_is_exact_ref(vt) {
            return true
          }
        }
      }
    None => ()
  }
  false
}

///|
fn gen_valid_test_has_exact_ref_local_flow_block(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      Block(ValTypeBlockType(vt), Expr(body)) if gen_valid_test_val_type_is_exact_ref(
          vt,
        ) => {
        let mut saw_set = false
        let mut saw_get = false
        for nested in body {
          match nested {
            LocalSet(_) => saw_set = true
            LocalGet(_) => saw_get = true
            _ => ()
          }
        }
        if saw_set && saw_get {
          return true
        }
        if gen_valid_test_has_exact_ref_local_flow_block(body) {
          return true
        }
      }
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_exact_ref_local_flow_block(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_exact_ref_local_flow_block(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_exact_ref_local_flow_block(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_module_has_exact_ref_local_flow_block(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, Expr(instrs)) = func
        if gen_valid_test_has_exact_ref_local_flow_block(instrs) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn gen_valid_test_has_local_call_ref_source(
  instrs : Array[Instruction],
) -> Bool {
  for i = 0; i + 3 < instrs.length(); i = i + 1 {
    match (instrs[i], instrs[i + 1], instrs[i + 2], instrs[i + 3]) {
      (RefFunc(_), LocalSet(set_idx), LocalGet(get_idx), CallRef(_)) if set_idx ==
        get_idx => return true
      _ => ()
    }
  }
  for instr in instrs {
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_local_call_ref_source(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_local_call_ref_source(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_local_call_ref_source(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_block_returns_callable_ref(instr : Instruction) -> Bool {
  match instr {
    Block(ValTypeBlockType(RefTypeValType(_)), Expr(body)) =>
      for child in body {
        match child {
          RefFunc(_) => return true
          _ => ()
        }
      }
    _ => ()
  }
  false
}

///|
fn gen_valid_test_has_block_return_call_ref_source(
  instrs : Array[Instruction],
) -> Bool {
  for i = 0; i + 1 < instrs.length(); i = i + 1 {
    if gen_valid_test_block_returns_callable_ref(instrs[i]) {
      match instrs[i + 1] {
        CallRef(_) | ReturnCallRef(_) => return true
        _ => ()
      }
    }
  }
  for instr in instrs {
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_block_return_call_ref_source(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_block_return_call_ref_source(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_block_return_call_ref_source(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_global_call_ref_source(
  instrs : Array[Instruction],
) -> Bool {
  for i = 0; i + 1 < instrs.length(); i = i + 1 {
    match (instrs[i], instrs[i + 1]) {
      (GlobalGet(_), CallRef(_)) => return true
      _ => ()
    }
  }
  for instr in instrs {
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_global_call_ref_source(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_global_call_ref_source(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_global_call_ref_source(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_table_call_ref_source(
  instrs : Array[Instruction],
) -> Bool {
  for i = 0; i + 2 < instrs.length(); i = i + 1 {
    match (instrs[i], instrs[i + 1], instrs[i + 2]) {
      (I32Const(_), TableGet(_), CallRef(_)) => return true
      _ => ()
    }
  }
  for i = 0; i + 3 < instrs.length(); i = i + 1 {
    match (instrs[i], instrs[i + 1], instrs[i + 2], instrs[i + 3]) {
      (I32Const(_), TableGet(_), RefCast(_, _), CallRef(_)) => return true
      _ => ()
    }
  }
  for instr in instrs {
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_table_call_ref_source(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_table_call_ref_source(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_table_call_ref_source(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_module_has_call_ref_source_variants(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) => {
      let mut has_local_source = false
      let mut has_block_source = false
      let mut has_global_source = false
      let mut has_table_source = false
      for func in funcs {
        let Func(_, Expr(instrs)) = func
        if gen_valid_test_has_local_call_ref_source(instrs) {
          has_local_source = true
        }
        if gen_valid_test_has_block_return_call_ref_source(instrs) {
          has_block_source = true
        }
        if gen_valid_test_has_global_call_ref_source(instrs) {
          has_global_source = true
        }
        if gen_valid_test_has_table_call_ref_source(instrs) {
          has_table_source = true
        }
      }
      has_local_source &&
      has_block_source &&
      has_global_source &&
      has_table_source
    }
    None => false
  }
}

///|
fn gen_valid_test_instrs_call_func(
  instrs : Array[Instruction],
  target : FuncIdx,
) -> Bool {
  for instr in instrs {
    match instr {
      Call(idx) if idx == target => return true
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_instrs_call_func(body, target) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_instrs_call_func(then_body, target) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_instrs_call_func(body, target) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_imported_func_count(mod_ : Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(_, _, extern_type) = import_
        match extern_type {
          FuncExternType(_) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn gen_valid_test_has_const_index_call_indirect(
  instrs : Array[Instruction],
  table_idx : TableIdx,
  index : Int,
) -> Bool {
  for i = 0; i + 1 < instrs.length(); i = i + 1 {
    match (instrs[i], instrs[i + 1]) {
      (I32Const(I32(value)), CallIndirect(_, target_table)) if value == index &&
        target_table == table_idx => return true
      _ => ()
    }
  }
  for instr in instrs {
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_const_index_call_indirect(body, table_idx, index) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_const_index_call_indirect(
            then_body, table_idx, index,
          ) {
          return true
        }
        match else_body {
          Some(body) =>
            if gen_valid_test_has_const_index_call_indirect(
                body, table_idx, index,
              ) {
              return true
            }
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_module_has_populated_nonzero_table_call_indirect(
  mod_ : Module,
) -> Bool {
  let populated_tables : Array[TableIdx] = []
  match mod_.elem_sec {
    Some(ElemSec(elems)) =>
      for elem in elems {
        let Elem(mode, _) = elem
        match mode {
          Active(table_idx, _) => populated_tables.push(table_idx)
          _ => ()
        }
      }
    None => ()
  }
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for table_idx in populated_tables {
        let TableIdx(table_idx_u) = table_idx
        if table_idx_u.reinterpret_as_int() > 0 {
          for func in funcs {
            let Func(_, Expr(instrs)) = func
            if gen_valid_test_has_const_index_call_indirect(
                instrs, table_idx, 1,
              ) {
              return true
            }
          }
        }
      }
    None => ()
  }
  false
}

///|
fn gen_valid_test_has_if_nested_tail_call(instrs : Array[Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      If(_, then_body, else_body) => {
        for child in then_body {
          match child {
            ReturnCall(_) | ReturnCallIndirect(_, _) | ReturnCallRef(_) =>
              return true
            _ => ()
          }
        }
        match else_body {
          Some(body) =>
            for child in body {
              match child {
                ReturnCall(_) | ReturnCallIndirect(_, _) | ReturnCallRef(_) =>
                  return true
                _ => ()
              }
            }
          None => ()
        }
        if gen_valid_test_has_if_nested_tail_call(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_if_nested_tail_call(body) =>
            return true
          _ => ()
        }
      }
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_has_if_nested_tail_call(body) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_nested_tail_call(instrs : Array[Instruction]) -> Bool {
  for instr in instrs {
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) => {
        for child in body {
          match child {
            ReturnCall(_) | ReturnCallIndirect(_, _) | ReturnCallRef(_) =>
              return true
            _ => ()
          }
        }
        if gen_valid_test_has_nested_tail_call(body) {
          return true
        }
      }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_nested_tail_call(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_nested_tail_call(body) => return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_nested_return_call_indirect(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) => {
        for i = 0; i + 1 < body.length(); i = i + 1 {
          match (body[i], body[i + 1]) {
            (I32Const(I32(1)), ReturnCallIndirect(_, TableIdx(0U))) =>
              return true
            _ => ()
          }
        }
        if gen_valid_test_has_nested_return_call_indirect(body) {
          return true
        }
      }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_nested_return_call_indirect(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_nested_return_call_indirect(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_has_nested_return_call_ref(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) => {
        if gen_valid_test_has_block_return_call_ref_source(body) {
          return true
        }
        if gen_valid_test_has_nested_return_call_ref(body) {
          return true
        }
      }
      If(_, then_body, else_body) => {
        if gen_valid_test_has_nested_return_call_ref(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_has_nested_return_call_ref(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn gen_valid_test_module_has_nonzero_indirect_and_nested_tail(
  mod_ : Module,
) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) => {
      let mut has_nonzero_indirect = false
      let mut has_nested_tail = false
      let mut has_nested_indirect_tail = false
      let mut has_nested_ref_tail = false
      let mut has_populated_nonzero_table_indirect = false
      let mut has_if_nested_tail = false
      has_populated_nonzero_table_indirect = gen_valid_test_module_has_populated_nonzero_table_call_indirect(
        mod_,
      )
      for func in funcs {
        let Func(_, Expr(instrs)) = func
        has_nonzero_indirect = has_nonzero_indirect ||
          gen_valid_test_has_const_index_call_indirect(
            instrs,
            TableIdx::new(0U),
            1,
          )
        has_nested_tail = has_nested_tail ||
          gen_valid_test_has_nested_tail_call(instrs)
        has_nested_indirect_tail = has_nested_indirect_tail ||
          gen_valid_test_has_nested_return_call_indirect(instrs)
        has_nested_ref_tail = has_nested_ref_tail ||
          gen_valid_test_has_nested_return_call_ref(instrs)
        has_if_nested_tail = has_if_nested_tail ||
          gen_valid_test_has_if_nested_tail_call(instrs)
      }
      has_nonzero_indirect &&
      has_nested_tail &&
      has_nested_indirect_tail &&
      has_nested_ref_tail &&
      has_populated_nonzero_table_indirect &&
      has_if_nested_tail
    }
    None => false
  }
}

///|
fn gen_valid_test_module_has_import_self_and_mutual_direct_calls(
  mod_ : Module,
) -> Bool {
  let imported_func_count = gen_valid_test_imported_func_count(mod_)
  match mod_.code_sec {
    Some(CodeSec(funcs)) if imported_func_count > 0 && funcs.length() >= 2 => {
      let imported_idx = FuncIdx::new(0U)
      let first_defined = FuncIdx::new(
        imported_func_count.reinterpret_as_uint(),
      )
      let second_defined = FuncIdx::new(
        (imported_func_count + 1).reinterpret_as_uint(),
      )
      let mut has_imported_call = false
      let mut has_self_call = false
      let mut first_calls_second = false
      let mut second_calls_first = false
      for i = 0; i < funcs.length(); i = i + 1 {
        let Func(_, Expr(instrs)) = funcs[i]
        if gen_valid_test_instrs_call_func(instrs, imported_idx) {
          has_imported_call = true
        }
        let self_idx = FuncIdx::new(
          (imported_func_count + i).reinterpret_as_uint(),
        )
        if gen_valid_test_instrs_call_func(instrs, self_idx) {
          has_self_call = true
        }
        if self_idx == first_defined &&
          gen_valid_test_instrs_call_func(instrs, second_defined) {
          first_calls_second = true
        }
        if self_idx == second_defined &&
          gen_valid_test_instrs_call_func(instrs, first_defined) {
          second_calls_first = true
        }
      }
      has_imported_call &&
      has_self_call &&
      first_calls_second &&
      second_calls_first
    }
    _ => false
  }
}

///|
fn gen_valid_test_has_mutual_struct_array_group(mod_ : Module) -> Bool {
  match mod_.type_sec {
    Some(TypeSec(types)) => {
      let mut cursor = 0
      for rec_type in types {
        match rec_type {
          GroupRecType(group) if group.length() >= 2 =>
            for i = 0; i < group.length(); i = i + 1 {
              for j = 0; j < group.length(); j = j + 1 {
                if i != j {
                  let struct_idx = TypeIdx::new(
                    (cursor + i).reinterpret_as_uint(),
                  )
                  let array_idx = TypeIdx::new(
                    (cursor + j).reinterpret_as_uint(),
                  )
                  let mut struct_refs_array = false
                  let mut array_refs_struct = false
                  match group[i] {
                    SubType(_, _, _, StructCompType(fields))
                    | CompTypeSubType(_, StructCompType(fields)) =>
                      for field in fields {
                        match field {
                          FieldType(
                            ValTypeStorageType(
                              RefTypeValType(
                                HeapTypeRefType(_, _, HeapType(target))
                              )
                            ),
                            _
                          ) if target == array_idx => struct_refs_array = true
                          _ => ()
                        }
                      }
                    _ => ()
                  }
                  match group[j] {
                    SubType(_, _, _, ArrayCompType(field))
                    | CompTypeSubType(_, ArrayCompType(field)) =>
                      match field {
                        FieldType(
                          ValTypeStorageType(
                            RefTypeValType(
                              HeapTypeRefType(_, _, HeapType(target))
                            )
                          ),
                          _
                        ) if target == struct_idx => array_refs_struct = true
                        _ => ()
                      }
                    _ => ()
                  }
                  if struct_refs_array && array_refs_struct {
                    return true
                  }
                }
              }
            }
          _ => ()
        }
        match rec_type {
          SingleRecType(_) => cursor += 1
          GroupRecType(group) => cursor += group.length()
        }
      }
      false
    }
    None => false
  }
}

///|
fn gen_valid_test_has_descriptor_final_open_matrix(mod_ : Module) -> Bool {
  match mod_.type_sec {
    Some(TypeSec(types)) => {
      let mut cursor = 0
      for rec_type in types {
        match rec_type {
          GroupRecType(group) if group.length() >= 4 => {
            let base_described = TypeIdx::new(cursor.reinterpret_as_uint())
            let base_descriptor = TypeIdx::new(
              (cursor + 1).reinterpret_as_uint(),
            )
            let leaf_described = TypeIdx::new(
              (cursor + 2).reinterpret_as_uint(),
            )
            let leaf_descriptor = TypeIdx::new(
              (cursor + 3).reinterpret_as_uint(),
            )
            match (group[0], group[1], group[2], group[3]) {
              (
                SubType(false, [], base_meta, StructCompType(_)),
                SubType(false, [], desc_meta, StructCompType(_)),
                SubType(true, leaf_supers, leaf_meta, StructCompType(_)),
                SubType(true, desc_supers, leaf_desc_meta, StructCompType(_)),
              ) =>
                if base_meta.descriptor == Some(base_descriptor) &&
                  desc_meta.describes == Some(base_described) &&
                  leaf_meta.descriptor == Some(leaf_descriptor) &&
                  leaf_desc_meta.describes == Some(leaf_described) &&
                  leaf_supers.length() == 1 &&
                  leaf_supers[0] == base_described &&
                  desc_supers.length() == 1 &&
                  desc_supers[0] == base_descriptor {
                  return true
                }
              _ => ()
            }
          }
          _ => ()
        }
        match rec_type {
          SingleRecType(_) => cursor += 1
          GroupRecType(group) => cursor += group.length()
        }
      }
      false
    }
    None => false
  }
}

///|
test "GC-heavy GenValid emits descriptor final-open subtype matrix" {
  let config = GenValidConfig::for_profile(GcHeavyProfile)
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0xf71006UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected descriptor final-open matrix generated module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(generated.facts.has_subtyping_topology)
  assert_true(
    gen_valid_test_has_descriptor_final_open_matrix(generated.wasm_module),
    msg="GC-heavy generation should include open descriptor/describes supertypes with final descriptor/describes subtypes",
  )
}

///|
test "coverage-forced GenValid emits mutually recursive struct and array topology" {
  let config = GenValidConfig::for_profile(GcHeavyProfile)
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0xf71005UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected mutual struct/array topology generated module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(generated.facts.has_subtyping_topology)
  assert_true(generated.facts.has_rich_gc_field_plans)
  assert_true(
    gen_valid_test_has_mutual_struct_array_group(generated.wasm_module),
    msg="GC-heavy generation should include a rec group where a struct field references an array sibling and the array element references the struct sibling",
  )
}

///|
test "natural GenValid organically emits recursive GC topology families" {
  let config = GenValidConfig::natural_default()
  let mut saw_subtyping_topology = false
  let mut saw_mutual_struct_array = false
  let mut saw_descriptor_matrix = false
  for offset in 0..<128 {
    let generated = match
      gen_valid_module_result(
        @splitmix.new(seed=0xf71040UL + offset.to_uint64()),
        config,
      ) {
      Ok(v) => v
      Err(failure) => fail(failure.validation_error_message)
    }
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) =>
        fail(
          "expected natural recursive-topology generated module to validate, got \{validation_error_message(err)}",
        )
    }
    saw_subtyping_topology = saw_subtyping_topology ||
      generated.facts.has_subtyping_topology
    saw_mutual_struct_array = saw_mutual_struct_array ||
      gen_valid_test_has_mutual_struct_array_group(generated.wasm_module)
    saw_descriptor_matrix = saw_descriptor_matrix ||
      gen_valid_test_has_descriptor_final_open_matrix(generated.wasm_module)
  }
  assert_true(
    saw_subtyping_topology,
    msg="natural generation should organically produce subtype topology over a bounded seed lane",
  )
  assert_true(
    saw_mutual_struct_array,
    msg="natural generation should organically produce mutually recursive struct/array rec groups, not only coverage-forced preludes",
  )
  assert_true(
    saw_descriptor_matrix,
    msg="natural generation should organically produce descriptor/describes subtype matrices, not only coverage-forced preludes",
  )
}

///|
priv struct GenValidTestNumericBoundaryLiterals {
  mut has_i32_zero : Bool
  mut has_i32_one : Bool
  mut has_i32_neg_one : Bool
  mut has_i32_min : Bool
  mut has_i32_max : Bool
  mut has_i32_power_two : Bool
  mut has_i64_zero : Bool
  mut has_i64_one : Bool
  mut has_i64_neg_one : Bool
  mut has_i64_min : Bool
  mut has_i64_max : Bool
  mut has_i64_power_two : Bool
  mut has_f32_neg_zero : Bool
  mut has_f32_pos_inf : Bool
  mut has_f32_neg_inf : Bool
  mut has_f32_nan_payload : Bool
  mut has_f64_neg_zero : Bool
  mut has_f64_pos_inf : Bool
  mut has_f64_neg_inf : Bool
  mut has_f64_nan_payload : Bool
}

///|
fn gen_valid_test_numeric_boundary_literals_empty() -> GenValidTestNumericBoundaryLiterals {
  {
    has_i32_zero: false,
    has_i32_one: false,
    has_i32_neg_one: false,
    has_i32_min: false,
    has_i32_max: false,
    has_i32_power_two: false,
    has_i64_zero: false,
    has_i64_one: false,
    has_i64_neg_one: false,
    has_i64_min: false,
    has_i64_max: false,
    has_i64_power_two: false,
    has_f32_neg_zero: false,
    has_f32_pos_inf: false,
    has_f32_neg_inf: false,
    has_f32_nan_payload: false,
    has_f64_neg_zero: false,
    has_f64_pos_inf: false,
    has_f64_neg_inf: false,
    has_f64_nan_payload: false,
  }
}

///|
fn gen_valid_test_note_numeric_boundary_literal(
  facts : GenValidTestNumericBoundaryLiterals,
  instr : Instruction,
) -> Unit {
  match instr {
    I32Const(I32(value)) =>
      if value == 0 {
        facts.has_i32_zero = true
      } else if value == 1 {
        facts.has_i32_one = true
      } else if value == -1 {
        facts.has_i32_neg_one = true
      } else if value == -2147483647 - 1 {
        facts.has_i32_min = true
      } else if value == 2147483647 {
        facts.has_i32_max = true
      } else if value == 1024 {
        facts.has_i32_power_two = true
      }
    I64Const(I64(value)) =>
      if value == 0L {
        facts.has_i64_zero = true
      } else if value == 1L {
        facts.has_i64_one = true
      } else if value == -1L {
        facts.has_i64_neg_one = true
      } else if value == -9223372036854775807L - 1L {
        facts.has_i64_min = true
      } else if value == 9223372036854775807L {
        facts.has_i64_max = true
      } else if value == 1099511627776L {
        facts.has_i64_power_two = true
      }
    F32Const(F32(value)) => {
      let bits = value.reinterpret_as_uint()
      if bits == 0x80000000U {
        facts.has_f32_neg_zero = true
      } else if bits == 0x7f800000U {
        facts.has_f32_pos_inf = true
      } else if bits == 0xff800000U {
        facts.has_f32_neg_inf = true
      } else if bits == 0x7fc00001U {
        facts.has_f32_nan_payload = true
      }
    }
    F64Const(F64(value)) => {
      let bits = value.reinterpret_as_uint64()
      if bits == 0x8000000000000000UL {
        facts.has_f64_neg_zero = true
      } else if bits == 0x7ff0000000000000UL {
        facts.has_f64_pos_inf = true
      } else if bits == 0xfff0000000000000UL {
        facts.has_f64_neg_inf = true
      } else if bits == 0x7ff8000000000001UL {
        facts.has_f64_nan_payload = true
      }
    }
    _ => ()
  }
}

///|
fn gen_valid_test_collect_numeric_boundary_literals(
  facts : GenValidTestNumericBoundaryLiterals,
  instrs : Array[Instruction],
) -> Unit {
  for instr in instrs {
    gen_valid_test_note_numeric_boundary_literal(facts, instr)
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        gen_valid_test_collect_numeric_boundary_literals(facts, body)
      If(_, then_body, else_body) => {
        gen_valid_test_collect_numeric_boundary_literals(facts, then_body)
        match else_body {
          Some(body) =>
            gen_valid_test_collect_numeric_boundary_literals(facts, body)
          None => ()
        }
      }
      _ => ()
    }
  }
}

///|
fn gen_valid_test_module_numeric_boundary_literals(
  mod_ : Module,
) -> GenValidTestNumericBoundaryLiterals {
  let facts = gen_valid_test_numeric_boundary_literals_empty()
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, Expr(instrs)) = func
        gen_valid_test_collect_numeric_boundary_literals(facts, instrs)
      }
    None => ()
  }
  facts
}

///|
fn gen_valid_test_instrs_have_numeric_expression_tree(
  instrs : Array[Instruction],
) -> Bool {
  let mut i = 0
  while i + 5 < instrs.length() {
    match
      (
        instrs[i],
        instrs[i + 1],
        instrs[i + 2],
        instrs[i + 3],
        instrs[i + 4],
        instrs[i + 5],
      ) {
      (I32Const(_), I32Const(_), I32Add, I32Const(_), I32Mul, Drop) =>
        return true
      (F64Const(_), F64Const(_), F64Div, F64Const(_), F64Sub, Drop) =>
        return true
      _ => ()
    }
    match instrs[i] {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_test_instrs_have_numeric_expression_tree(body) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_test_instrs_have_numeric_expression_tree(then_body) {
          return true
        }
        match else_body {
          Some(body) if gen_valid_test_instrs_have_numeric_expression_tree(body) =>
            return true
          _ => ()
        }
      }
      _ => ()
    }
    i += 1
  }
  false
}

///|
fn gen_valid_test_module_has_numeric_expression_tree(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, Expr(instrs)) = func
        if gen_valid_test_instrs_have_numeric_expression_tree(instrs) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
test "coverage-forced GenValid emits standard SIMD representative exact opcode counters" {
  let base = GenValidConfig::coverage_forced_default()
  let config = GenValidConfig::{
    ..base,
    max_imports: 0,
    section_bias: GenValidSectionBias::{
      ..base.section_bias,
      imports_percent: 0,
    },
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_typed_body_generator: true,
    },
  }
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0xf71009UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected SIMD coverage-forced generated module to validate, got \{validation_error_message(err)}",
      )
  }
  let counts = generated.facts.exact_opcode_counts
  assert_true(generated.facts.uses_v128)
  assert_true(generated.facts.has_simd_phase1)
  assert_true(generated.facts.has_simd_phase2)
  assert_true(generated.facts.has_simd_phase3)
  assert_true(
    counts.v128_const > 0,
    msg="SIMD exact coverage should include v128.const",
  )
  assert_true(
    counts.i8x16_splat > 0,
    msg="SIMD exact coverage should include i8x16.splat",
  )
  assert_true(
    counts.i16x8_splat > 0,
    msg="SIMD exact coverage should include i16x8.splat",
  )
  assert_true(
    counts.i32x4_splat > 0,
    msg="SIMD exact coverage should include i32x4.splat",
  )
  assert_true(
    counts.i64x2_splat > 0,
    msg="SIMD exact coverage should include i64x2.splat",
  )
  assert_true(
    counts.f32x4_splat > 0,
    msg="SIMD exact coverage should include f32x4.splat",
  )
  assert_true(
    counts.f64x2_splat > 0,
    msg="SIMD exact coverage should include f64x2.splat",
  )
  assert_true(
    counts.i8x16_extract_lane_s > 0,
    msg="SIMD exact coverage should include i8x16.extract_lane_s",
  )
  assert_true(
    counts.i8x16_extract_lane_u > 0,
    msg="SIMD exact coverage should include i8x16.extract_lane_u",
  )
  assert_true(
    counts.i16x8_extract_lane_s > 0,
    msg="SIMD exact coverage should include i16x8.extract_lane_s",
  )
  assert_true(
    counts.i16x8_extract_lane_u > 0,
    msg="SIMD exact coverage should include i16x8.extract_lane_u",
  )
  assert_true(
    counts.i16x8_replace_lane > 0,
    msg="SIMD exact coverage should include i16x8.replace_lane",
  )
  assert_true(
    counts.i32x4_extract_lane > 0,
    msg="SIMD exact coverage should include i32x4.extract_lane",
  )
  assert_true(
    counts.i32x4_replace_lane > 0,
    msg="SIMD exact coverage should include i32x4.replace_lane",
  )
  assert_true(
    counts.i64x2_extract_lane > 0,
    msg="SIMD exact coverage should include i64x2.extract_lane",
  )
  assert_true(
    counts.i64x2_replace_lane > 0,
    msg="SIMD exact coverage should include i64x2.replace_lane",
  )
  assert_true(
    counts.f32x4_extract_lane > 0,
    msg="SIMD exact coverage should include f32x4.extract_lane",
  )
  assert_true(
    counts.f32x4_replace_lane > 0,
    msg="SIMD exact coverage should include f32x4.replace_lane",
  )
  assert_true(
    counts.f64x2_extract_lane > 0,
    msg="SIMD exact coverage should include f64x2.extract_lane",
  )
  assert_true(
    counts.f64x2_replace_lane > 0,
    msg="SIMD exact coverage should include f64x2.replace_lane",
  )
  assert_true(
    counts.i8x16_replace_lane > 0,
    msg="SIMD exact coverage should include i8x16.replace_lane",
  )
  assert_true(
    counts.v128_not > 0,
    msg="SIMD exact coverage should include v128.not",
  )
  assert_true(
    counts.v128_and > 0,
    msg="SIMD exact coverage should include v128.and",
  )
  assert_true(
    counts.v128_andnot > 0,
    msg="SIMD exact coverage should include v128.andnot",
  )
  assert_true(
    counts.v128_or > 0,
    msg="SIMD exact coverage should include v128.or",
  )
  assert_true(
    counts.v128_xor > 0,
    msg="SIMD exact coverage should include v128.xor",
  )
  assert_true(
    counts.v128_bitselect > 0,
    msg="SIMD exact coverage should include v128.bitselect",
  )
  assert_true(
    counts.v128_any_true > 0,
    msg="SIMD exact coverage should include v128.any_true",
  )
  assert_true(
    counts.i8x16_eq > 0,
    msg="SIMD exact coverage should include i8x16.eq",
  )
  assert_true(
    counts.i8x16_ne > 0,
    msg="SIMD exact coverage should include i8x16.ne",
  )
  assert_true(
    counts.i8x16_ge_u > 0,
    msg="SIMD exact coverage should include i8x16.ge_u",
  )
  assert_true(
    counts.i8x16_lt_s > 0,
    msg="SIMD exact coverage should include i8x16.lt_s",
  )
  assert_true(
    counts.i8x16_lt_u > 0,
    msg="SIMD exact coverage should include i8x16.lt_u",
  )
  assert_true(
    counts.i8x16_gt_s > 0,
    msg="SIMD exact coverage should include i8x16.gt_s",
  )
  assert_true(
    counts.i8x16_gt_u > 0,
    msg="SIMD exact coverage should include i8x16.gt_u",
  )
  assert_true(
    counts.i8x16_le_s > 0,
    msg="SIMD exact coverage should include i8x16.le_s",
  )
  assert_true(
    counts.i8x16_le_u > 0,
    msg="SIMD exact coverage should include i8x16.le_u",
  )
  assert_true(
    counts.i8x16_ge_s > 0,
    msg="SIMD exact coverage should include i8x16.ge_s",
  )
  assert_true(
    counts.i16x8_eq > 0,
    msg="SIMD exact coverage should include i16x8.eq",
  )
  assert_true(
    counts.i16x8_ne > 0,
    msg="SIMD exact coverage should include i16x8.ne",
  )
  assert_true(
    counts.i16x8_lt_s > 0,
    msg="SIMD exact coverage should include i16x8.lt_s",
  )
  assert_true(
    counts.i16x8_lt_u > 0,
    msg="SIMD exact coverage should include i16x8.lt_u",
  )
  assert_true(
    counts.i16x8_gt_s > 0,
    msg="SIMD exact coverage should include i16x8.gt_s",
  )
  assert_true(
    counts.i16x8_gt_u > 0,
    msg="SIMD exact coverage should include i16x8.gt_u",
  )
  assert_true(
    counts.i16x8_le_s > 0,
    msg="SIMD exact coverage should include i16x8.le_s",
  )
  assert_true(
    counts.i16x8_le_u > 0,
    msg="SIMD exact coverage should include i16x8.le_u",
  )
  assert_true(
    counts.i16x8_ge_s > 0,
    msg="SIMD exact coverage should include i16x8.ge_s",
  )
  assert_true(
    counts.i16x8_ge_u > 0,
    msg="SIMD exact coverage should include i16x8.ge_u",
  )
  assert_true(
    counts.i32x4_eq > 0,
    msg="SIMD exact coverage should include i32x4.eq",
  )
  assert_true(
    counts.i32x4_ne > 0,
    msg="SIMD exact coverage should include i32x4.ne",
  )
  assert_true(
    counts.i32x4_lt_s > 0,
    msg="SIMD exact coverage should include i32x4.lt_s",
  )
  assert_true(
    counts.i32x4_lt_u > 0,
    msg="SIMD exact coverage should include i32x4.lt_u",
  )
  assert_true(
    counts.i32x4_gt_s > 0,
    msg="SIMD exact coverage should include i32x4.gt_s",
  )
  assert_true(
    counts.i32x4_gt_u > 0,
    msg="SIMD exact coverage should include i32x4.gt_u",
  )
  assert_true(
    counts.i32x4_le_s > 0,
    msg="SIMD exact coverage should include i32x4.le_s",
  )
  assert_true(
    counts.i32x4_le_u > 0,
    msg="SIMD exact coverage should include i32x4.le_u",
  )
  assert_true(
    counts.i32x4_ge_s > 0,
    msg="SIMD exact coverage should include i32x4.ge_s",
  )
  assert_true(
    counts.i32x4_ge_u > 0,
    msg="SIMD exact coverage should include i32x4.ge_u",
  )
  assert_true(
    counts.i64x2_eq > 0,
    msg="SIMD exact coverage should include i64x2.eq",
  )
  assert_true(
    counts.i64x2_ne > 0,
    msg="SIMD exact coverage should include i64x2.ne",
  )
  assert_true(
    counts.i64x2_lt_s > 0,
    msg="SIMD exact coverage should include i64x2.lt_s",
  )
  assert_true(
    counts.i64x2_gt_s > 0,
    msg="SIMD exact coverage should include i64x2.gt_s",
  )
  assert_true(
    counts.i64x2_le_s > 0,
    msg="SIMD exact coverage should include i64x2.le_s",
  )
  assert_true(
    counts.i64x2_ge_s > 0,
    msg="SIMD exact coverage should include i64x2.ge_s",
  )
  assert_true(
    counts.f32x4_eq > 0,
    msg="SIMD exact coverage should include f32x4.eq",
  )
  assert_true(
    counts.f32x4_ne > 0,
    msg="SIMD exact coverage should include f32x4.ne",
  )
  assert_true(
    counts.f32x4_lt > 0,
    msg="SIMD exact coverage should include f32x4.lt",
  )
  assert_true(
    counts.f32x4_gt > 0,
    msg="SIMD exact coverage should include f32x4.gt",
  )
  assert_true(
    counts.f32x4_le > 0,
    msg="SIMD exact coverage should include f32x4.le",
  )
  assert_true(
    counts.f32x4_ge > 0,
    msg="SIMD exact coverage should include f32x4.ge",
  )
  assert_true(
    counts.f64x2_eq > 0,
    msg="SIMD exact coverage should include f64x2.eq",
  )
  assert_true(
    counts.f64x2_ne > 0,
    msg="SIMD exact coverage should include f64x2.ne",
  )
  assert_true(
    counts.f64x2_lt > 0,
    msg="SIMD exact coverage should include f64x2.lt",
  )
  assert_true(
    counts.f64x2_gt > 0,
    msg="SIMD exact coverage should include f64x2.gt",
  )
  assert_true(
    counts.f64x2_le > 0,
    msg="SIMD exact coverage should include f64x2.le",
  )
  assert_true(
    counts.f64x2_ge > 0,
    msg="SIMD exact coverage should include f64x2.ge",
  )
  assert_true(
    counts.i8x16_abs > 0,
    msg="SIMD exact coverage should include i8x16.abs",
  )
  assert_true(
    counts.i8x16_neg > 0,
    msg="SIMD exact coverage should include i8x16.neg",
  )
  assert_true(
    counts.i8x16_popcnt > 0,
    msg="SIMD exact coverage should include i8x16.popcnt",
  )
  assert_true(
    counts.i8x16_all_true > 0,
    msg="SIMD exact coverage should include i8x16.all_true",
  )
  assert_true(
    counts.i8x16_bitmask > 0,
    msg="SIMD exact coverage should include i8x16.bitmask",
  )
  assert_true(
    counts.i16x8_abs > 0,
    msg="SIMD exact coverage should include i16x8.abs",
  )
  assert_true(
    counts.i16x8_neg > 0,
    msg="SIMD exact coverage should include i16x8.neg",
  )
  assert_true(
    counts.i16x8_q15mulr_sat_s > 0,
    msg="SIMD exact coverage should include i16x8.q15mulr_sat_s",
  )
  assert_true(
    counts.i16x8_all_true > 0,
    msg="SIMD exact coverage should include i16x8.all_true",
  )
  assert_true(
    counts.i16x8_bitmask > 0,
    msg="SIMD exact coverage should include i16x8.bitmask",
  )
  assert_true(
    counts.i32x4_abs > 0,
    msg="SIMD exact coverage should include i32x4.abs",
  )
  assert_true(
    counts.i32x4_neg > 0,
    msg="SIMD exact coverage should include i32x4.neg",
  )
  assert_true(
    counts.i32x4_bitmask > 0,
    msg="SIMD exact coverage should include i32x4.bitmask",
  )
  assert_true(
    counts.i64x2_abs > 0,
    msg="SIMD exact coverage should include i64x2.abs",
  )
  assert_true(
    counts.i64x2_neg > 0,
    msg="SIMD exact coverage should include i64x2.neg",
  )
  assert_true(
    counts.i64x2_all_true > 0,
    msg="SIMD exact coverage should include i64x2.all_true",
  )
  assert_true(
    counts.i8x16_add > 0,
    msg="SIMD exact coverage should include i8x16.add",
  )
  assert_true(
    counts.i8x16_add_sat_s > 0,
    msg="SIMD exact coverage should include i8x16.add_sat_s",
  )
  assert_true(
    counts.i8x16_add_sat_u > 0,
    msg="SIMD exact coverage should include i8x16.add_sat_u",
  )
  assert_true(
    counts.i8x16_sub > 0,
    msg="SIMD exact coverage should include i8x16.sub",
  )
  assert_true(
    counts.i8x16_sub_sat_s > 0,
    msg="SIMD exact coverage should include i8x16.sub_sat_s",
  )
  assert_true(
    counts.i8x16_sub_sat_u > 0,
    msg="SIMD exact coverage should include i8x16.sub_sat_u",
  )
  assert_true(
    counts.i8x16_min_s > 0,
    msg="SIMD exact coverage should include i8x16.min_s",
  )
  assert_true(
    counts.i8x16_min_u > 0,
    msg="SIMD exact coverage should include i8x16.min_u",
  )
  assert_true(
    counts.i8x16_max_s > 0,
    msg="SIMD exact coverage should include i8x16.max_s",
  )
  assert_true(
    counts.i8x16_max_u > 0,
    msg="SIMD exact coverage should include i8x16.max_u",
  )
  assert_true(
    counts.i8x16_avgr_u > 0,
    msg="SIMD exact coverage should include i8x16.avgr_u",
  )
  assert_true(
    counts.i16x8_add > 0,
    msg="SIMD exact coverage should include i16x8.add",
  )
  assert_true(
    counts.i16x8_add_sat_s > 0,
    msg="SIMD exact coverage should include i16x8.add_sat_s",
  )
  assert_true(
    counts.i16x8_add_sat_u > 0,
    msg="SIMD exact coverage should include i16x8.add_sat_u",
  )
  assert_true(
    counts.i16x8_sub > 0,
    msg="SIMD exact coverage should include i16x8.sub",
  )
  assert_true(
    counts.i16x8_sub_sat_s > 0,
    msg="SIMD exact coverage should include i16x8.sub_sat_s",
  )
  assert_true(
    counts.i16x8_sub_sat_u > 0,
    msg="SIMD exact coverage should include i16x8.sub_sat_u",
  )
  assert_true(
    counts.i16x8_min_s > 0,
    msg="SIMD exact coverage should include i16x8.min_s",
  )
  assert_true(
    counts.i16x8_min_u > 0,
    msg="SIMD exact coverage should include i16x8.min_u",
  )
  assert_true(
    counts.i16x8_max_s > 0,
    msg="SIMD exact coverage should include i16x8.max_s",
  )
  assert_true(
    counts.i16x8_max_u > 0,
    msg="SIMD exact coverage should include i16x8.max_u",
  )
  assert_true(
    counts.i16x8_avgr_u > 0,
    msg="SIMD exact coverage should include i16x8.avgr_u",
  )
  assert_true(
    counts.i16x8_mul > 0,
    msg="SIMD exact coverage should include i16x8.mul",
  )
  assert_true(
    counts.i8x16_shl > 0,
    msg="SIMD exact coverage should include i8x16.shl",
  )
  assert_true(
    counts.i8x16_shr_s > 0,
    msg="SIMD exact coverage should include i8x16.shr_s",
  )
  assert_true(
    counts.i8x16_shr_u > 0,
    msg="SIMD exact coverage should include i8x16.shr_u",
  )
  assert_true(
    counts.i16x8_shl > 0,
    msg="SIMD exact coverage should include i16x8.shl",
  )
  assert_true(
    counts.i16x8_shr_s > 0,
    msg="SIMD exact coverage should include i16x8.shr_s",
  )
  assert_true(
    counts.i16x8_shr_u > 0,
    msg="SIMD exact coverage should include i16x8.shr_u",
  )
  assert_true(
    counts.i32x4_shl > 0,
    msg="SIMD exact coverage should include i32x4.shl",
  )
  assert_true(
    counts.i32x4_shr_s > 0,
    msg="SIMD exact coverage should include i32x4.shr_s",
  )
  assert_true(
    counts.i32x4_shr_u > 0,
    msg="SIMD exact coverage should include i32x4.shr_u",
  )
  assert_true(
    counts.i64x2_shl > 0,
    msg="SIMD exact coverage should include i64x2.shl",
  )
  assert_true(
    counts.i64x2_shr_s > 0,
    msg="SIMD exact coverage should include i64x2.shr_s",
  )
  assert_true(
    counts.i64x2_shr_u > 0,
    msg="SIMD exact coverage should include i64x2.shr_u",
  )
  assert_true(
    counts.i32x4_all_true > 0,
    msg="SIMD exact coverage should include i32x4.all_true",
  )
  assert_true(
    counts.i64x2_bitmask > 0,
    msg="SIMD exact coverage should include i64x2.bitmask",
  )
  assert_true(
    counts.i32x4_add > 0,
    msg="SIMD exact coverage should include i32x4.add",
  )
  assert_true(
    counts.i32x4_sub > 0,
    msg="SIMD exact coverage should include i32x4.sub",
  )
  assert_true(
    counts.i32x4_mul > 0,
    msg="SIMD exact coverage should include i32x4.mul",
  )
  assert_true(
    counts.i32x4_min_s > 0,
    msg="SIMD exact coverage should include i32x4.min_s",
  )
  assert_true(
    counts.i32x4_min_u > 0,
    msg="SIMD exact coverage should include i32x4.min_u",
  )
  assert_true(
    counts.i32x4_max_s > 0,
    msg="SIMD exact coverage should include i32x4.max_s",
  )
  assert_true(
    counts.i32x4_max_u > 0,
    msg="SIMD exact coverage should include i32x4.max_u",
  )
  assert_true(
    counts.i64x2_add > 0,
    msg="SIMD exact coverage should include i64x2.add",
  )
  assert_true(
    counts.i64x2_sub > 0,
    msg="SIMD exact coverage should include i64x2.sub",
  )
  assert_true(
    counts.i64x2_mul > 0,
    msg="SIMD exact coverage should include i64x2.mul",
  )
  assert_true(
    counts.f32x4_add > 0,
    msg="SIMD exact coverage should include f32x4.add",
  )
  assert_true(
    counts.f32x4_div > 0,
    msg="SIMD exact coverage should include f32x4.div",
  )
  assert_true(
    counts.f32x4_min > 0,
    msg="SIMD exact coverage should include f32x4.min",
  )
  assert_true(
    counts.f32x4_max > 0,
    msg="SIMD exact coverage should include f32x4.max",
  )
  assert_true(
    counts.f64x2_add > 0,
    msg="SIMD exact coverage should include f64x2.add",
  )
  assert_true(
    counts.f64x2_div > 0,
    msg="SIMD exact coverage should include f64x2.div",
  )
  assert_true(
    counts.f64x2_min > 0,
    msg="SIMD exact coverage should include f64x2.min",
  )
  assert_true(
    counts.f64x2_max > 0,
    msg="SIMD exact coverage should include f64x2.max",
  )
  assert_true(
    counts.f32x4_ceil > 0,
    msg="SIMD exact coverage should include f32x4.ceil",
  )
  assert_true(
    counts.f32x4_floor > 0,
    msg="SIMD exact coverage should include f32x4.floor",
  )
  assert_true(
    counts.f32x4_trunc > 0,
    msg="SIMD exact coverage should include f32x4.trunc",
  )
  assert_true(
    counts.f32x4_nearest > 0,
    msg="SIMD exact coverage should include f32x4.nearest",
  )
  assert_true(
    counts.f64x2_ceil > 0,
    msg="SIMD exact coverage should include f64x2.ceil",
  )
  assert_true(
    counts.f64x2_floor > 0,
    msg="SIMD exact coverage should include f64x2.floor",
  )
  assert_true(
    counts.f64x2_trunc > 0,
    msg="SIMD exact coverage should include f64x2.trunc",
  )
  assert_true(
    counts.f64x2_nearest > 0,
    msg="SIMD exact coverage should include f64x2.nearest",
  )
  assert_true(
    counts.v128_load > 0,
    msg="SIMD exact coverage should include v128.load",
  )
  assert_true(
    counts.v128_store > 0,
    msg="SIMD exact coverage should include v128.store",
  )
  assert_true(
    counts.v128_load8x8_s > 0,
    msg="SIMD exact coverage should include v128.load8x8_s",
  )
  assert_true(
    counts.v128_load8x8_u > 0,
    msg="SIMD exact coverage should include v128.load8x8_u",
  )
  assert_true(
    counts.v128_load16x4_s > 0,
    msg="SIMD exact coverage should include v128.load16x4_s",
  )
  assert_true(
    counts.v128_load16x4_u > 0,
    msg="SIMD exact coverage should include v128.load16x4_u",
  )
  assert_true(
    counts.v128_load32x2_s > 0,
    msg="SIMD exact coverage should include v128.load32x2_s",
  )
  assert_true(
    counts.v128_load32x2_u > 0,
    msg="SIMD exact coverage should include v128.load32x2_u",
  )
  assert_true(
    counts.v128_load8_splat > 0,
    msg="SIMD exact coverage should include v128.load8_splat",
  )
  assert_true(
    counts.v128_load16_splat > 0,
    msg="SIMD exact coverage should include v128.load16_splat",
  )
  assert_true(
    counts.v128_load32_splat > 0,
    msg="SIMD exact coverage should include v128.load32_splat",
  )
  assert_true(
    counts.v128_load64_splat > 0,
    msg="SIMD exact coverage should include v128.load64_splat",
  )
  assert_true(
    counts.v128_load8_lane > 0,
    msg="SIMD exact coverage should include v128.load8_lane",
  )
  assert_true(
    counts.v128_load16_lane > 0,
    msg="SIMD exact coverage should include v128.load16_lane",
  )
  assert_true(
    counts.v128_load32_lane > 0,
    msg="SIMD exact coverage should include v128.load32_lane",
  )
  assert_true(
    counts.v128_load64_lane > 0,
    msg="SIMD exact coverage should include v128.load64_lane",
  )
  assert_true(
    counts.v128_store8_lane > 0,
    msg="SIMD exact coverage should include v128.store8_lane",
  )
  assert_true(
    counts.v128_store16_lane > 0,
    msg="SIMD exact coverage should include v128.store16_lane",
  )
  assert_true(
    counts.v128_store32_lane > 0,
    msg="SIMD exact coverage should include v128.store32_lane",
  )
  assert_true(
    counts.v128_store64_lane > 0,
    msg="SIMD exact coverage should include v128.store64_lane",
  )
  assert_true(
    counts.v128_load32_zero > 0,
    msg="SIMD exact coverage should include v128.load32_zero",
  )
  assert_true(
    counts.v128_load64_zero > 0,
    msg="SIMD exact coverage should include v128.load64_zero",
  )
  assert_true(
    counts.i8x16_shuffle > 0,
    msg="SIMD exact coverage should include i8x16.shuffle",
  )
  assert_true(
    counts.i8x16_swizzle > 0,
    msg="SIMD exact coverage should include i8x16.swizzle",
  )
  assert_true(
    counts.i8x16_narrow_i16x8_s > 0,
    msg="SIMD exact coverage should include i8x16.narrow_i16x8_s",
  )
  assert_true(
    counts.i8x16_narrow_i16x8_u > 0,
    msg="SIMD exact coverage should include i8x16.narrow_i16x8_u",
  )
  assert_true(
    counts.i16x8_narrow_i32x4_s > 0,
    msg="SIMD exact coverage should include i16x8.narrow_i32x4_s",
  )
  assert_true(
    counts.i16x8_narrow_i32x4_u > 0,
    msg="SIMD exact coverage should include i16x8.narrow_i32x4_u",
  )
  assert_true(
    counts.i16x8_extadd_pairwise_i8x16_s > 0,
    msg="SIMD exact coverage should include i16x8.extadd_pairwise_i8x16_s",
  )
  assert_true(
    counts.i16x8_extadd_pairwise_i8x16_u > 0,
    msg="SIMD exact coverage should include i16x8.extadd_pairwise_i8x16_u",
  )
  assert_true(
    counts.i32x4_extadd_pairwise_i16x8_s > 0,
    msg="SIMD exact coverage should include i32x4.extadd_pairwise_i16x8_s",
  )
  assert_true(
    counts.i32x4_extadd_pairwise_i16x8_u > 0,
    msg="SIMD exact coverage should include i32x4.extadd_pairwise_i16x8_u",
  )
  assert_true(
    counts.i32x4_dot_i16x8_s > 0,
    msg="SIMD exact coverage should include i32x4.dot_i16x8_s",
  )
  assert_true(
    counts.f32x4_demote_f64x2_zero > 0,
    msg="SIMD exact coverage should include f32x4.demote_f64x2_zero",
  )
  assert_true(
    counts.f64x2_promote_low_f32x4 > 0,
    msg="SIMD exact coverage should include f64x2.promote_low_f32x4",
  )
  assert_true(
    counts.i32x4_trunc_sat_f32x4_s > 0,
    msg="SIMD exact coverage should include i32x4.trunc_sat_f32x4_s",
  )
  assert_true(
    counts.i32x4_trunc_sat_f32x4_u > 0,
    msg="SIMD exact coverage should include i32x4.trunc_sat_f32x4_u",
  )
  assert_true(
    counts.f32x4_convert_i32x4_s > 0,
    msg="SIMD exact coverage should include f32x4.convert_i32x4_s",
  )
  assert_true(
    counts.f32x4_convert_i32x4_u > 0,
    msg="SIMD exact coverage should include f32x4.convert_i32x4_u",
  )
  assert_true(
    counts.i32x4_trunc_sat_f64x2_s_zero > 0,
    msg="SIMD exact coverage should include i32x4.trunc_sat_f64x2_s_zero",
  )
  assert_true(
    counts.i32x4_trunc_sat_f64x2_u_zero > 0,
    msg="SIMD exact coverage should include i32x4.trunc_sat_f64x2_u_zero",
  )
  assert_true(
    counts.f64x2_convert_low_i32x4_s > 0,
    msg="SIMD exact coverage should include f64x2.convert_low_i32x4_s",
  )
  assert_true(
    counts.f64x2_convert_low_i32x4_u > 0,
    msg="SIMD exact coverage should include f64x2.convert_low_i32x4_u",
  )
  assert_true(
    counts.f32x4_abs > 0,
    msg="SIMD exact coverage should include f32x4.abs",
  )
  assert_true(
    counts.f32x4_neg > 0,
    msg="SIMD exact coverage should include f32x4.neg",
  )
  assert_true(
    counts.f32x4_sqrt > 0,
    msg="SIMD exact coverage should include f32x4.sqrt",
  )
  assert_true(
    counts.f32x4_sub > 0,
    msg="SIMD exact coverage should include f32x4.sub",
  )
  assert_true(
    counts.f32x4_mul > 0,
    msg="SIMD exact coverage should include f32x4.mul",
  )
  assert_true(
    counts.f32x4_pmin > 0,
    msg="SIMD exact coverage should include f32x4.pmin",
  )
  assert_true(
    counts.f32x4_pmax > 0,
    msg="SIMD exact coverage should include f32x4.pmax",
  )
  assert_true(
    counts.f64x2_abs > 0,
    msg="SIMD exact coverage should include f64x2.abs",
  )
  assert_true(
    counts.f64x2_neg > 0,
    msg="SIMD exact coverage should include f64x2.neg",
  )
  assert_true(
    counts.f64x2_sqrt > 0,
    msg="SIMD exact coverage should include f64x2.sqrt",
  )
  assert_true(
    counts.f64x2_sub > 0,
    msg="SIMD exact coverage should include f64x2.sub",
  )
  assert_true(
    counts.f64x2_mul > 0,
    msg="SIMD exact coverage should include f64x2.mul",
  )
  assert_true(
    counts.f64x2_pmin > 0,
    msg="SIMD exact coverage should include f64x2.pmin",
  )
  assert_true(
    counts.f64x2_pmax > 0,
    msg="SIMD exact coverage should include f64x2.pmax",
  )
  assert_true(
    counts.i16x8_extend_low_i8x16_s > 0,
    msg="SIMD exact coverage should include i16x8.extend_low_i8x16_s",
  )
  assert_true(
    counts.i16x8_extend_high_i8x16_s > 0,
    msg="SIMD exact coverage should include i16x8.extend_high_i8x16_s",
  )
  assert_true(
    counts.i16x8_extend_low_i8x16_u > 0,
    msg="SIMD exact coverage should include i16x8.extend_low_i8x16_u",
  )
  assert_true(
    counts.i16x8_extend_high_i8x16_u > 0,
    msg="SIMD exact coverage should include i16x8.extend_high_i8x16_u",
  )
  assert_true(
    counts.i32x4_extend_low_i16x8_s > 0,
    msg="SIMD exact coverage should include i32x4.extend_low_i16x8_s",
  )
  assert_true(
    counts.i32x4_extend_high_i16x8_s > 0,
    msg="SIMD exact coverage should include i32x4.extend_high_i16x8_s",
  )
  assert_true(
    counts.i32x4_extend_low_i16x8_u > 0,
    msg="SIMD exact coverage should include i32x4.extend_low_i16x8_u",
  )
  assert_true(
    counts.i32x4_extend_high_i16x8_u > 0,
    msg="SIMD exact coverage should include i32x4.extend_high_i16x8_u",
  )
  assert_true(
    counts.i64x2_extend_low_i32x4_s > 0,
    msg="SIMD exact coverage should include i64x2.extend_low_i32x4_s",
  )
  assert_true(
    counts.i64x2_extend_high_i32x4_s > 0,
    msg="SIMD exact coverage should include i64x2.extend_high_i32x4_s",
  )
  assert_true(
    counts.i64x2_extend_low_i32x4_u > 0,
    msg="SIMD exact coverage should include i64x2.extend_low_i32x4_u",
  )
  assert_true(
    counts.i64x2_extend_high_i32x4_u > 0,
    msg="SIMD exact coverage should include i64x2.extend_high_i32x4_u",
  )
  assert_true(
    counts.i16x8_extmul_low_i8x16_s > 0,
    msg="SIMD exact coverage should include i16x8.extmul_low_i8x16_s",
  )
  assert_true(
    counts.i16x8_extmul_high_i8x16_s > 0,
    msg="SIMD exact coverage should include i16x8.extmul_high_i8x16_s",
  )
  assert_true(
    counts.i16x8_extmul_low_i8x16_u > 0,
    msg="SIMD exact coverage should include i16x8.extmul_low_i8x16_u",
  )
  assert_true(
    counts.i16x8_extmul_high_i8x16_u > 0,
    msg="SIMD exact coverage should include i16x8.extmul_high_i8x16_u",
  )
  assert_true(
    counts.i32x4_extmul_low_i16x8_s > 0,
    msg="SIMD exact coverage should include i32x4.extmul_low_i16x8_s",
  )
  assert_true(
    counts.i32x4_extmul_high_i16x8_s > 0,
    msg="SIMD exact coverage should include i32x4.extmul_high_i16x8_s",
  )
  assert_true(
    counts.i32x4_extmul_low_i16x8_u > 0,
    msg="SIMD exact coverage should include i32x4.extmul_low_i16x8_u",
  )
  assert_true(
    counts.i32x4_extmul_high_i16x8_u > 0,
    msg="SIMD exact coverage should include i32x4.extmul_high_i16x8_u",
  )
  assert_true(
    counts.i64x2_extmul_low_i32x4_s > 0,
    msg="SIMD exact coverage should include i64x2.extmul_low_i32x4_s",
  )
  assert_true(
    counts.i64x2_extmul_high_i32x4_s > 0,
    msg="SIMD exact coverage should include i64x2.extmul_high_i32x4_s",
  )
  assert_true(
    counts.i64x2_extmul_low_i32x4_u > 0,
    msg="SIMD exact coverage should include i64x2.extmul_low_i32x4_u",
  )
  assert_true(
    counts.i64x2_extmul_high_i32x4_u > 0,
    msg="SIMD exact coverage should include i64x2.extmul_high_i32x4_u",
  )
}

///|
test "SIMD-heavy profile emits SIMD memory coverage over nonzero memory indices" {
  let base = GenValidConfig::for_profile(SimdHeavyProfile)
  let config = GenValidConfig::{ ..base, max_mems: 4 }
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0xf71011UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected SIMD-heavy generated module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(generated.facts.has_simd_phase3)
  assert_true(
    gen_valid_test_has_simd_memory_over_nonzero_mem(generated.wasm_module),
    msg="SIMD-heavy profile should emit SIMD memory coverage over a nonzero memory index",
  )
}

///|
test "SIMD-heavy profile threads v128 through signatures locals and control results" {
  let generated = match
    gen_valid_module_result(
      @splitmix.new(seed=0xf71013UL),
      GenValidConfig::for_profile(SimdHeavyProfile),
    ) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected SIMD-heavy generated module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(
    gen_valid_test_has_v128_threaded_body(generated.wasm_module),
    msg="SIMD-heavy profile should deterministically thread v128 through signatures, locals/local.set, and typed result control",
  )
}

///|
test "SIMD-heavy profile emits SIMD lane min middle and max coverage" {
  let generated = match
    gen_valid_module_result(
      @splitmix.new(seed=0xf71012UL),
      GenValidConfig::for_profile(SimdHeavyProfile),
    ) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected SIMD-heavy generated module to validate, got \{validation_error_message(err)}",
      )
  }
  let mod_ = generated.wasm_module
  assert_true(
    gen_valid_test_has_simd_lane(mod_, 16, LaneIdx::new(0)),
    msg="SIMD lane coverage should include i8x16/v128 lane min 0",
  )
  assert_true(
    gen_valid_test_has_simd_lane(mod_, 16, LaneIdx::new(8)),
    msg="SIMD lane coverage should include i8x16/v128 lane middle 8",
  )
  assert_true(
    gen_valid_test_has_simd_lane(mod_, 16, LaneIdx::new(15)),
    msg="SIMD lane coverage should include i8x16/v128 lane max 15",
  )
  assert_true(
    gen_valid_test_has_simd_lane(mod_, 8, LaneIdx::new(0)),
    msg="SIMD lane coverage should include i16x8/v128 lane min 0",
  )
  assert_true(
    gen_valid_test_has_simd_lane(mod_, 8, LaneIdx::new(4)),
    msg="SIMD lane coverage should include i16x8/v128 lane middle 4",
  )
  assert_true(
    gen_valid_test_has_simd_lane(mod_, 8, LaneIdx::new(7)),
    msg="SIMD lane coverage should include i16x8/v128 lane max 7",
  )
  assert_true(
    gen_valid_test_has_simd_lane(mod_, 4, LaneIdx::new(0)),
    msg="SIMD lane coverage should include i32x4/f32x4/v128 lane min 0",
  )
  assert_true(
    gen_valid_test_has_simd_lane(mod_, 4, LaneIdx::new(2)),
    msg="SIMD lane coverage should include i32x4/f32x4/v128 lane middle 2",
  )
  assert_true(
    gen_valid_test_has_simd_lane(mod_, 4, LaneIdx::new(3)),
    msg="SIMD lane coverage should include i32x4/f32x4/v128 lane max 3",
  )
  assert_true(
    gen_valid_test_has_simd_lane(mod_, 2, LaneIdx::new(0)),
    msg="SIMD lane coverage should include i64x2/f64x2/v128 lane min 0",
  )
  assert_true(
    gen_valid_test_has_simd_lane(mod_, 2, LaneIdx::new(1)),
    msg="SIMD lane coverage should include i64x2/f64x2/v128 lane max 1",
  )
}

///|
test "relaxed SIMD profile emits explicit relaxed SIMD exact opcode counters" {
  let config = GenValidConfig::for_profile(RelaxedSimdProfile)
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0xf71010UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected relaxed-SIMD generated module to validate, got \{validation_error_message(err)}",
      )
  }
  let counts = generated.facts.exact_opcode_counts
  assert_true(generated.facts.uses_v128)
  assert_true(
    counts.i8x16_relaxed_swizzle > 0,
    msg="relaxed SIMD exact coverage should include i8x16.relaxed_swizzle",
  )
  assert_true(
    counts.i8x16_relaxed_laneselect > 0,
    msg="relaxed SIMD exact coverage should include i8x16.relaxed_laneselect",
  )
  assert_true(
    counts.i16x8_relaxed_laneselect > 0,
    msg="relaxed SIMD exact coverage should include i16x8.relaxed_laneselect",
  )
  assert_true(
    counts.i32x4_relaxed_laneselect > 0,
    msg="relaxed SIMD exact coverage should include i32x4.relaxed_laneselect",
  )
  assert_true(
    counts.i64x2_relaxed_laneselect > 0,
    msg="relaxed SIMD exact coverage should include i64x2.relaxed_laneselect",
  )
  assert_true(
    counts.i32x4_relaxed_trunc_f32x4_s > 0,
    msg="relaxed SIMD exact coverage should include i32x4.relaxed_trunc_f32x4_s",
  )
  assert_true(
    counts.i32x4_relaxed_trunc_f32x4_u > 0,
    msg="relaxed SIMD exact coverage should include i32x4.relaxed_trunc_f32x4_u",
  )
  assert_true(
    counts.i32x4_relaxed_trunc_zero_f64x2_s > 0,
    msg="relaxed SIMD exact coverage should include i32x4.relaxed_trunc_zero_f64x2_s",
  )
  assert_true(
    counts.i32x4_relaxed_trunc_zero_f64x2_u > 0,
    msg="relaxed SIMD exact coverage should include i32x4.relaxed_trunc_zero_f64x2_u",
  )
  assert_true(
    counts.f32x4_relaxed_madd > 0,
    msg="relaxed SIMD exact coverage should include f32x4.relaxed_madd",
  )
  assert_true(
    counts.f32x4_relaxed_nmadd > 0,
    msg="relaxed SIMD exact coverage should include f32x4.relaxed_nmadd",
  )
  assert_true(
    counts.f64x2_relaxed_madd > 0,
    msg="relaxed SIMD exact coverage should include f64x2.relaxed_madd",
  )
  assert_true(
    counts.f64x2_relaxed_nmadd > 0,
    msg="relaxed SIMD exact coverage should include f64x2.relaxed_nmadd",
  )
  assert_true(
    counts.f32x4_relaxed_min > 0,
    msg="relaxed SIMD exact coverage should include f32x4.relaxed_min",
  )
  assert_true(
    counts.f32x4_relaxed_max > 0,
    msg="relaxed SIMD exact coverage should include f32x4.relaxed_max",
  )
  assert_true(
    counts.f64x2_relaxed_min > 0,
    msg="relaxed SIMD exact coverage should include f64x2.relaxed_min",
  )
  assert_true(
    counts.f64x2_relaxed_max > 0,
    msg="relaxed SIMD exact coverage should include f64x2.relaxed_max",
  )
  assert_true(
    counts.i16x8_relaxed_q15mulr_s > 0,
    msg="relaxed SIMD exact coverage should include i16x8.relaxed_q15mulr_s",
  )
  assert_true(
    counts.i16x8_relaxed_dot_i8x16_i7x16_s > 0,
    msg="relaxed SIMD exact coverage should include i16x8.relaxed_dot_i8x16_i7x16_s",
  )
  assert_true(
    counts.i32x4_relaxed_dot_i8x16_i7x16_add_s > 0,
    msg="relaxed SIMD exact coverage should include i32x4.relaxed_dot_i8x16_i7x16_add_s",
  )
}

///|
test "coverage-forced GenValid emits scalar numeric arithmetic and reinterpret counters" {
  let config = GenValidConfig::coverage_forced_default()
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0xf71009UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected scalar-numeric coverage-forced generated module to validate, got \{validation_error_message(err)}",
      )
  }
  let counts = generated.facts.exact_opcode_counts
  assert_true(generated.facts.has_numeric_full_ops)
  assert_true(counts.i32_add > 0, msg="numeric coverage should include i32.add")
  assert_true(counts.i64_add > 0, msg="numeric coverage should include i64.add")
  assert_true(counts.f32_add > 0, msg="numeric coverage should include f32.add")
  assert_true(counts.f64_add > 0, msg="numeric coverage should include f64.add")
  assert_true(counts.i32_ne > 0, msg="numeric coverage should include i32.ne")
  assert_true(
    counts.i32_lt_s > 0,
    msg="numeric coverage should include i32.lt_s",
  )
  assert_true(
    counts.i32_lt_u > 0,
    msg="numeric coverage should include i32.lt_u",
  )
  assert_true(
    counts.i32_gt_s > 0,
    msg="numeric coverage should include i32.gt_s",
  )
  assert_true(
    counts.i32_gt_u > 0,
    msg="numeric coverage should include i32.gt_u",
  )
  assert_true(
    counts.i32_le_s > 0,
    msg="numeric coverage should include i32.le_s",
  )
  assert_true(
    counts.i32_le_u > 0,
    msg="numeric coverage should include i32.le_u",
  )
  assert_true(
    counts.i32_ge_s > 0,
    msg="numeric coverage should include i32.ge_s",
  )
  assert_true(
    counts.i32_ge_u > 0,
    msg="numeric coverage should include i32.ge_u",
  )
  assert_true(counts.i64_ne > 0, msg="numeric coverage should include i64.ne")
  assert_true(
    counts.i64_lt_s > 0,
    msg="numeric coverage should include i64.lt_s",
  )
  assert_true(
    counts.i64_lt_u > 0,
    msg="numeric coverage should include i64.lt_u",
  )
  assert_true(
    counts.i64_gt_s > 0,
    msg="numeric coverage should include i64.gt_s",
  )
  assert_true(
    counts.i64_gt_u > 0,
    msg="numeric coverage should include i64.gt_u",
  )
  assert_true(
    counts.i64_le_s > 0,
    msg="numeric coverage should include i64.le_s",
  )
  assert_true(
    counts.i64_le_u > 0,
    msg="numeric coverage should include i64.le_u",
  )
  assert_true(
    counts.i64_ge_s > 0,
    msg="numeric coverage should include i64.ge_s",
  )
  assert_true(
    counts.i64_ge_u > 0,
    msg="numeric coverage should include i64.ge_u",
  )
  assert_true(counts.f32_ne > 0, msg="numeric coverage should include f32.ne")
  assert_true(counts.f32_lt > 0, msg="numeric coverage should include f32.lt")
  assert_true(counts.f32_gt > 0, msg="numeric coverage should include f32.gt")
  assert_true(counts.f32_le > 0, msg="numeric coverage should include f32.le")
  assert_true(counts.f32_ge > 0, msg="numeric coverage should include f32.ge")
  assert_true(counts.f64_ne > 0, msg="numeric coverage should include f64.ne")
  assert_true(counts.f64_lt > 0, msg="numeric coverage should include f64.lt")
  assert_true(counts.f64_gt > 0, msg="numeric coverage should include f64.gt")
  assert_true(counts.f64_le > 0, msg="numeric coverage should include f64.le")
  assert_true(counts.f64_ge > 0, msg="numeric coverage should include f64.ge")
  assert_true(counts.i32_clz > 0, msg="numeric coverage should include i32.clz")
  assert_true(counts.i32_ctz > 0, msg="numeric coverage should include i32.ctz")
  assert_true(
    counts.i32_popcnt > 0,
    msg="numeric coverage should include i32.popcnt",
  )
  assert_true(counts.i32_sub > 0, msg="numeric coverage should include i32.sub")
  assert_true(counts.i32_mul > 0, msg="numeric coverage should include i32.mul")
  assert_true(
    counts.i32_div_s > 0,
    msg="numeric coverage should include i32.div_s",
  )
  assert_true(
    counts.i32_div_u > 0,
    msg="numeric coverage should include i32.div_u",
  )
  assert_true(
    counts.i32_rem_s > 0,
    msg="numeric coverage should include i32.rem_s",
  )
  assert_true(
    counts.i32_rem_u > 0,
    msg="numeric coverage should include i32.rem_u",
  )
  assert_true(counts.i32_and > 0, msg="numeric coverage should include i32.and")
  assert_true(counts.i32_or > 0, msg="numeric coverage should include i32.or")
  assert_true(counts.i32_xor > 0, msg="numeric coverage should include i32.xor")
  assert_true(counts.i32_shl > 0, msg="numeric coverage should include i32.shl")
  assert_true(
    counts.i32_shr_s > 0,
    msg="numeric coverage should include i32.shr_s",
  )
  assert_true(
    counts.i32_shr_u > 0,
    msg="numeric coverage should include i32.shr_u",
  )
  assert_true(
    counts.i32_rotl > 0,
    msg="numeric coverage should include i32.rotl",
  )
  assert_true(
    counts.i32_rotr > 0,
    msg="numeric coverage should include i32.rotr",
  )
  assert_true(counts.i64_clz > 0, msg="numeric coverage should include i64.clz")
  assert_true(counts.i64_ctz > 0, msg="numeric coverage should include i64.ctz")
  assert_true(
    counts.i64_popcnt > 0,
    msg="numeric coverage should include i64.popcnt",
  )
  assert_true(counts.i64_sub > 0, msg="numeric coverage should include i64.sub")
  assert_true(counts.i64_mul > 0, msg="numeric coverage should include i64.mul")
  assert_true(
    counts.i64_div_s > 0,
    msg="numeric coverage should include i64.div_s",
  )
  assert_true(
    counts.i64_div_u > 0,
    msg="numeric coverage should include i64.div_u",
  )
  assert_true(
    counts.i64_rem_s > 0,
    msg="numeric coverage should include i64.rem_s",
  )
  assert_true(
    counts.i64_rem_u > 0,
    msg="numeric coverage should include i64.rem_u",
  )
  assert_true(counts.i64_and > 0, msg="numeric coverage should include i64.and")
  assert_true(counts.i64_or > 0, msg="numeric coverage should include i64.or")
  assert_true(counts.i64_xor > 0, msg="numeric coverage should include i64.xor")
  assert_true(counts.i64_shl > 0, msg="numeric coverage should include i64.shl")
  assert_true(
    counts.i64_shr_s > 0,
    msg="numeric coverage should include i64.shr_s",
  )
  assert_true(
    counts.i64_shr_u > 0,
    msg="numeric coverage should include i64.shr_u",
  )
  assert_true(
    counts.i64_rotl > 0,
    msg="numeric coverage should include i64.rotl",
  )
  assert_true(
    counts.i64_rotr > 0,
    msg="numeric coverage should include i64.rotr",
  )
  assert_true(counts.f32_abs > 0, msg="numeric coverage should include f32.abs")
  assert_true(counts.f32_neg > 0, msg="numeric coverage should include f32.neg")
  assert_true(
    counts.f32_ceil > 0,
    msg="numeric coverage should include f32.ceil",
  )
  assert_true(
    counts.f32_floor > 0,
    msg="numeric coverage should include f32.floor",
  )
  assert_true(
    counts.f32_trunc > 0,
    msg="numeric coverage should include f32.trunc",
  )
  assert_true(
    counts.f32_nearest > 0,
    msg="numeric coverage should include f32.nearest",
  )
  assert_true(
    counts.f32_sqrt > 0,
    msg="numeric coverage should include f32.sqrt",
  )
  assert_true(counts.f32_sub > 0, msg="numeric coverage should include f32.sub")
  assert_true(counts.f32_mul > 0, msg="numeric coverage should include f32.mul")
  assert_true(counts.f32_div > 0, msg="numeric coverage should include f32.div")
  assert_true(counts.f32_min > 0, msg="numeric coverage should include f32.min")
  assert_true(counts.f32_max > 0, msg="numeric coverage should include f32.max")
  assert_true(
    counts.f32_copysign > 0,
    msg="numeric coverage should include f32.copysign",
  )
  assert_true(counts.f64_abs > 0, msg="numeric coverage should include f64.abs")
  assert_true(counts.f64_neg > 0, msg="numeric coverage should include f64.neg")
  assert_true(
    counts.f64_ceil > 0,
    msg="numeric coverage should include f64.ceil",
  )
  assert_true(
    counts.f64_floor > 0,
    msg="numeric coverage should include f64.floor",
  )
  assert_true(
    counts.f64_trunc > 0,
    msg="numeric coverage should include f64.trunc",
  )
  assert_true(
    counts.f64_nearest > 0,
    msg="numeric coverage should include f64.nearest",
  )
  assert_true(
    counts.f64_sqrt > 0,
    msg="numeric coverage should include f64.sqrt",
  )
  assert_true(counts.f64_sub > 0, msg="numeric coverage should include f64.sub")
  assert_true(counts.f64_mul > 0, msg="numeric coverage should include f64.mul")
  assert_true(counts.f64_div > 0, msg="numeric coverage should include f64.div")
  assert_true(counts.f64_min > 0, msg="numeric coverage should include f64.min")
  assert_true(counts.f64_max > 0, msg="numeric coverage should include f64.max")
  assert_true(
    counts.f64_copysign > 0,
    msg="numeric coverage should include f64.copysign",
  )
  assert_true(
    counts.i32_wrap_i64 > 0,
    msg="numeric coverage should include i32.wrap_i64",
  )
  assert_true(
    counts.i32_trunc_f32s > 0,
    msg="numeric coverage should include i32.trunc_f32_s",
  )
  assert_true(
    counts.i32_trunc_f32u > 0,
    msg="numeric coverage should include i32.trunc_f32_u",
  )
  assert_true(
    counts.i32_trunc_f64s > 0,
    msg="numeric coverage should include i32.trunc_f64_s",
  )
  assert_true(
    counts.i32_trunc_f64u > 0,
    msg="numeric coverage should include i32.trunc_f64_u",
  )
  assert_true(
    counts.i64_extend_i32s > 0,
    msg="numeric coverage should include i64.extend_i32_s",
  )
  assert_true(
    counts.i64_extend_i32u > 0,
    msg="numeric coverage should include i64.extend_i32_u",
  )
  assert_true(
    counts.i64_trunc_f32s > 0,
    msg="numeric coverage should include i64.trunc_f32_s",
  )
  assert_true(
    counts.i64_trunc_f32u > 0,
    msg="numeric coverage should include i64.trunc_f32_u",
  )
  assert_true(
    counts.i64_trunc_f64s > 0,
    msg="numeric coverage should include i64.trunc_f64_s",
  )
  assert_true(
    counts.i64_trunc_f64u > 0,
    msg="numeric coverage should include i64.trunc_f64_u",
  )
  assert_true(
    counts.f32_convert_i32s > 0,
    msg="numeric coverage should include f32.convert_i32_s",
  )
  assert_true(
    counts.f32_convert_i32u > 0,
    msg="numeric coverage should include f32.convert_i32_u",
  )
  assert_true(
    counts.f32_convert_i64s > 0,
    msg="numeric coverage should include f32.convert_i64_s",
  )
  assert_true(
    counts.f32_convert_i64u > 0,
    msg="numeric coverage should include f32.convert_i64_u",
  )
  assert_true(
    counts.f32_demote_f64 > 0,
    msg="numeric coverage should include f32.demote_f64",
  )
  assert_true(
    counts.f64_convert_i32s > 0,
    msg="numeric coverage should include f64.convert_i32_s",
  )
  assert_true(
    counts.f64_convert_i32u > 0,
    msg="numeric coverage should include f64.convert_i32_u",
  )
  assert_true(
    counts.f64_convert_i64s > 0,
    msg="numeric coverage should include f64.convert_i64_s",
  )
  assert_true(
    counts.f64_convert_i64u > 0,
    msg="numeric coverage should include f64.convert_i64_u",
  )
  assert_true(
    counts.f64_promote_f32 > 0,
    msg="numeric coverage should include f64.promote_f32",
  )
  assert_true(
    counts.i32_extend8s > 0,
    msg="numeric coverage should include i32.extend8_s",
  )
  assert_true(
    counts.i32_extend16s > 0,
    msg="numeric coverage should include i32.extend16_s",
  )
  assert_true(
    counts.i64_extend8s > 0,
    msg="numeric coverage should include i64.extend8_s",
  )
  assert_true(
    counts.i64_extend16s > 0,
    msg="numeric coverage should include i64.extend16_s",
  )
  assert_true(
    counts.i64_extend32s > 0,
    msg="numeric coverage should include i64.extend32_s",
  )
  assert_true(
    counts.i32_reinterpret_f32 > 0,
    msg="numeric coverage should include i32.reinterpret_f32",
  )
  assert_true(
    counts.i64_reinterpret_f64 > 0,
    msg="numeric coverage should include i64.reinterpret_f64",
  )
  assert_true(
    counts.f32_reinterpret_i32 > 0,
    msg="numeric coverage should include f32.reinterpret_i32",
  )
  assert_true(
    counts.f64_reinterpret_i64 > 0,
    msg="numeric coverage should include f64.reinterpret_i64",
  )
  let literals = gen_valid_test_module_numeric_boundary_literals(
    generated.wasm_module,
  )
  assert_true(
    literals.has_i32_zero,
    msg="numeric coverage should include i32.const 0",
  )
  assert_true(
    literals.has_i32_one,
    msg="numeric coverage should include i32.const 1",
  )
  assert_true(
    literals.has_i32_neg_one,
    msg="numeric coverage should include i32.const -1",
  )
  assert_true(
    literals.has_i32_min,
    msg="numeric coverage should include i32.const min",
  )
  assert_true(
    literals.has_i32_max,
    msg="numeric coverage should include i32.const max",
  )
  assert_true(
    literals.has_i32_power_two,
    msg="numeric coverage should include i32.const power-of-two literal",
  )
  assert_true(
    literals.has_i64_zero,
    msg="numeric coverage should include i64.const 0",
  )
  assert_true(
    literals.has_i64_one,
    msg="numeric coverage should include i64.const 1",
  )
  assert_true(
    literals.has_i64_neg_one,
    msg="numeric coverage should include i64.const -1",
  )
  assert_true(
    literals.has_i64_min,
    msg="numeric coverage should include i64.const min",
  )
  assert_true(
    literals.has_i64_max,
    msg="numeric coverage should include i64.const max",
  )
  assert_true(
    literals.has_i64_power_two,
    msg="numeric coverage should include i64.const power-of-two literal",
  )
  assert_true(
    literals.has_f32_neg_zero,
    msg="numeric coverage should include f32.const -0",
  )
  assert_true(
    literals.has_f32_pos_inf,
    msg="numeric coverage should include f32.const +inf",
  )
  assert_true(
    literals.has_f32_neg_inf,
    msg="numeric coverage should include f32.const -inf",
  )
  assert_true(
    literals.has_f32_nan_payload,
    msg="numeric coverage should include f32.const NaN payload",
  )
  assert_true(
    literals.has_f64_neg_zero,
    msg="numeric coverage should include f64.const -0",
  )
  assert_true(
    literals.has_f64_pos_inf,
    msg="numeric coverage should include f64.const +inf",
  )
  assert_true(
    literals.has_f64_neg_inf,
    msg="numeric coverage should include f64.const -inf",
  )
  assert_true(
    literals.has_f64_nan_payload,
    msg="numeric coverage should include f64.const NaN payload",
  )
  assert_true(
    gen_valid_test_module_has_numeric_expression_tree(generated.wasm_module),
    msg="numeric coverage should include nontrivial scalar expression trees, not only isolated drops",
  )
}

///|
test "coverage-forced GenValid routes exact refs through locals and block results" {
  let config = GenValidConfig::coverage_forced_default()
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0xf71004UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected exact-ref coverage-forced generated module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(generated.facts.uses_ref_types)
  assert_true(generated.facts.has_gc_constructors)
  assert_true(
    gen_valid_test_module_has_exact_ref_local(generated.wasm_module),
    msg="coverage-forced GC topology should declare at least one exact-reference local",
  )
  assert_true(
    gen_valid_test_module_has_exact_ref_local_flow_block(generated.wasm_module),
    msg="coverage-forced GC topology should route an exact reference through local.set/local.get inside an exact block result",
  )
}

///|
test "coverage-forced GenValid routes call_ref through locals and block results" {
  let config = GenValidConfig::coverage_forced_default()
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0x71008UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected call-ref coverage-forced generated module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(generated.facts.has_call)
  assert_true(
    gen_valid_test_module_has_call_ref_source_variants(generated.wasm_module),
    msg="coverage-forced call-ref generation should include callable references sourced through a typed function-reference local and block result",
  )
}

///|
test "coverage-forced GenValid emits imported self and mutual direct calls" {
  let config = GenValidConfig::coverage_forced_default()
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0x71007UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected direct-call graph coverage-forced generated module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(generated.facts.has_call)
  assert_true(
    gen_valid_test_module_has_import_self_and_mutual_direct_calls(
      generated.wasm_module,
    ),
    msg="coverage-forced direct-call generation should include imported calls, recursive self-calls, and a mutually recursive pair",
  )
}

///|
test "coverage-forced GenValid emits nonzero call_indirect and nested tail calls" {
  let config = GenValidConfig::coverage_forced_default()
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0x71008UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected indirect/tail coverage-forced generated module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(generated.facts.has_call_indirect)
  assert_true(generated.facts.has_tail_calls)
  assert_true(generated.facts.exact_opcode_counts.return_call > 0)
  assert_true(
    gen_valid_test_module_has_nonzero_indirect_and_nested_tail(
      generated.wasm_module,
    ),
    msg="coverage-forced call generation should include table-0 and populated nonzero-table call_indirect index-1 variants plus tail calls nested inside terminal block and if-control forms",
  )
}

///|
test "control-heavy profile records widened local declaration layout" {
  let config = GenValidConfig::for_profile(ControlHeavyProfile)
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0x71002UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected local-layout generated module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(
    generated.facts.has_grouped_local_decls,
    msg="typed body profiles should deliberately include a grouped local declaration run",
  )
  assert_true(
    generated.facts.has_mixed_local_decl_types,
    msg="typed body profiles should deliberately include mixed local declaration run types",
  )
  assert_true(
    generated.facts.has_high_local_indices,
    msg="body-layout profiles should exercise local indices beyond the tiny default range",
  )
  assert_true(
    generated.facts.has_unused_locals,
    msg="body-layout profiles should deliberately leave at least one declared local unused",
  )
  assert_true(
    generated.facts.has_write_only_locals,
    msg="body-layout profiles should deliberately write at least one declared local without reading it back",
  )
  assert_true(
    generated.facts.has_zero_local_funcs,
    msg="body-layout profiles should include a valid function body with no body-local declarations",
  )
  assert_true(
    generated.facts.has_multi_param_result_arities,
    msg="body-layout profiles should include mixed parameter/result arities",
  )
  assert_true(
    generated.facts.has_empty_body_funcs,
    msg="body-layout profiles should include an empty body where the signature permits it",
  )
  assert_true(
    generated.facts.has_unreachable_result_bodies,
    msg="body-layout profiles should include an unreachable body for a declared-result function",
  )
  assert_true(
    generated.facts.has_local_name_entries,
    msg="body-layout profiles should include local-name name-section entries",
  )
  assert_true(
    gen_valid_test_module_has_high_local_access(generated.wasm_module),
    msg="body-layout profiles should reference a high local index from generated code, not only declare it",
  )
  assert_true(
    gen_valid_test_module_has_empty_zero_local_body(generated.wasm_module),
    msg="body-layout profiles should materialize an empty zero-local function body",
  )
  assert_true(
    gen_valid_test_module_has_unreachable_result_body(generated.wasm_module),
    msg="body-layout profiles should materialize a declared-result body as a bare unreachable",
  )
  assert_true(
    gen_valid_test_module_has_local_name_entries(generated.wasm_module),
    msg="body-layout profiles should attach local names in the structured name section",
  )
}

///|
test "control-heavy profile uses typed GenValid body generator slice" {
  let config = GenValidConfig::for_profile(ControlHeavyProfile)
  assert_true(config.features.allow_typed_body_generator)
  let generated = match
    gen_valid_module_result(@splitmix.new(seed=0x71002UL), config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected typed-body generated module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(generated.facts.has_branch_heavy_control)
  assert_true(
    generated.facts.has_payload_control_flow,
    msg="control-heavy facts should distinguish payload-bearing control from simple branch-heavy control",
  )
  assert_true(
    generated.facts.has_multivalue_control_flow,
    msg="control-heavy facts should distinguish multi-value control from simple branch-heavy control",
  )
  assert_true(generated.facts.has_local_tee)
  assert_true(generated.facts.exact_opcode_counts.local_tee > 0)
  assert_true(
    gen_valid_test_module_local_set_count(generated.wasm_module) > 0,
    msg="typed body generator should emit stack-planned local.set coverage",
  )
  assert_true(
    gen_valid_test_module_has_i64_const_local_set(generated.wasm_module),
    msg="typed body generator should widen beyond the original i32-only local slice",
  )
  match generated.wasm_module.code_sec {
    Some(CodeSec(funcs)) => {
      let mut has_payload_br = false
      let mut has_payload_br_if = false
      let mut has_payload_br_table = false
      let mut has_multivalue_block = false
      let mut has_i64_payload_br = false
      let mut has_f32_payload_br = false
      let mut has_f64_payload_br = false
      let mut has_v128_payload_br = false
      let mut has_funcref_payload_br = false
      let mut has_outer_i32_payload_branch = false
      let mut has_v128_typed_select = false
      let mut has_funcref_typed_select = false
      let mut has_i32_result_loop = false
      let mut has_nested_return = false
      for func in funcs {
        let Func(_, Expr(instrs)) = func
        if gen_valid_test_has_i32_payload_br_value_block(instrs) {
          has_payload_br = true
        }
        if gen_valid_test_has_typed_payload_br_value_block(
            instrs,
            ValType::i64(),
          ) {
          has_i64_payload_br = true
        }
        if gen_valid_test_has_typed_payload_br_value_block(
            instrs,
            ValType::f32(),
          ) {
          has_f32_payload_br = true
        }
        if gen_valid_test_has_typed_payload_br_value_block(
            instrs,
            ValType::f64(),
          ) {
          has_f64_payload_br = true
        }
        if gen_valid_test_has_typed_payload_br_value_block(
            instrs,
            ValType::v128(),
          ) {
          has_v128_payload_br = true
        }
        if gen_valid_test_has_typed_payload_br_value_block(
            instrs,
            ValType::funcref(),
          ) {
          has_funcref_payload_br = true
        }
        if gen_valid_test_has_outer_payload_branch(instrs, ValType::i32()) {
          has_outer_i32_payload_branch = true
        }
        if gen_valid_test_has_typed_select_for(instrs, ValType::v128()) {
          has_v128_typed_select = true
        }
        if gen_valid_test_has_typed_select_for(instrs, ValType::funcref()) {
          has_funcref_typed_select = true
        }
        if gen_valid_test_has_i32_payload_br_if_value_block(instrs) {
          has_payload_br_if = true
        }
        if gen_valid_test_has_i32_payload_br_table_value_block(instrs) {
          has_payload_br_table = true
        }
        if gen_valid_test_has_multivalue_typeidx_block(
            generated.wasm_module,
            instrs,
          ) {
          has_multivalue_block = true
        }
        if gen_valid_test_has_i32_result_loop(instrs) {
          has_i32_result_loop = true
        }
        if gen_valid_test_has_nested_return(instrs) {
          has_nested_return = true
        }
      }
      assert_true(
        has_payload_br,
        msg="typed body generator should emit a value block with a typed br payload",
      )
      assert_true(
        has_payload_br_if,
        msg="typed body generator should emit a value block with br_if payload and fallthrough values",
      )
      assert_true(
        has_payload_br_table,
        msg="typed body generator should emit a value block with br_table payload and matching target arities",
      )
      assert_true(
        has_i64_payload_br,
        msg="typed body generator should emit an i64 value block with a typed br payload",
      )
      assert_true(
        has_f32_payload_br,
        msg="typed body generator should emit an f32 value block with a typed br payload",
      )
      assert_true(
        has_f64_payload_br,
        msg="typed body generator should emit an f64 value block with a typed br payload",
      )
      assert_true(
        has_v128_payload_br,
        msg="typed body generator should emit a v128 value block with a typed br payload",
      )
      assert_true(
        has_funcref_payload_br,
        msg="typed body generator should emit a funcref value block with a typed br payload",
      )
      assert_true(
        has_outer_i32_payload_branch,
        msg="typed body generator should emit nested label-depth branch payload coverage",
      )
      assert_true(
        has_v128_typed_select,
        msg="control-heavy generation should emit typed select over v128 values",
      )
      assert_true(
        has_funcref_typed_select,
        msg="control-heavy generation should emit typed select over ref values",
      )
      assert_true(
        has_multivalue_block,
        msg="typed body generator should emit a multi-value TypeIdx block",
      )
      assert_true(
        has_i32_result_loop,
        msg="typed body generator should emit a value-producing loop where block result typing is valid",
      )
      assert_true(
        has_nested_return,
        msg="typed body generator should emit a return from nested control in a return-typed function",
      )
    }
    None => fail("expected generated module to contain code bodies")
  }
}
