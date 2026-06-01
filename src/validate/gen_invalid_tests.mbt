///|
test "gen_invalid_ast_seed_config widens declared memory-data prerequisites" {
  let restrictive = GenValidConfig::{
    ..GenValidConfig::natural_default(),
    max_mems: 0,
    max_datas: 0,
    section_bias: GenValidSectionBias::{
      ..GenValidSectionBias::natural_default(),
      mems_percent: 0,
      datas_percent: 0,
    },
    features: GenValidFeatureToggles::{
      ..GenValidFeatureToggles::natural_default(),
      allow_mems: false,
      allow_datas: false,
    },
  }
  let adjusted = gen_invalid_ast_seed_config(
    GenInvalidAstParams::new(
      NonConstantDataOffset,
      generator_config=restrictive,
    ),
  )
  @debug.assert_eq(adjusted.max_mems, 1)
  @debug.assert_eq(adjusted.max_datas, 1)
  @debug.assert_eq(adjusted.section_bias.mems_percent, 100)
  @debug.assert_eq(adjusted.section_bias.datas_percent, 100)
  assert_true(adjusted.features.allow_mems)
  assert_true(adjusted.features.allow_datas)
}

///|
test "gen_invalid_ast_generate returns valid base and invalid mutation for a fixed strategy seed" {
  let params = GenInvalidAstParams::new(
    MissingDataCount,
    generator_config=GenValidConfig::natural_default(),
  )
  let generated = match
    gen_invalid_ast_generate(@splitmix.new(seed=0x5eedUL), params) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected gen-invalid base module to validate, got \{validation_error_message(err)}",
      )
  }
  assert_true(generated.mutation.applicable)
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected gen-invalid mutated module to fail validation")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
      assert_true(generated.mutation.expected_family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports minimal valid seeds" {
  let params = GenInvalidAstParams::minimal_seed(InvalidStartSignature)
  let generated = match
    gen_invalid_ast_generate(@splitmix.new(seed=0x5eedUL), params) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected minimal gen-invalid base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected minimal-seed gen-invalid mutation to fail validation")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == StartSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast natural_seed uses natural defaults" {
  let params = GenInvalidAstParams::natural_seed(DuplicateExportName)
  assert_true(params.seed_mode == RandomValidSeed)
  assert_true(params.generator_config.mode == Natural)
  @debug.assert_eq(
    params.generator_config.section_bias,
    GenValidSectionBias::natural_default(),
  )
  @debug.assert_eq(
    params.generator_config.features,
    GenValidFeatureToggles::natural_default(),
  )
}

///|
test "gen_invalid_ast coverage_forced_seed uses coverage-forced defaults" {
  let params = GenInvalidAstParams::coverage_forced_seed(DuplicateExportName)
  assert_true(params.seed_mode == RandomValidSeed)
  assert_true(params.generator_config.mode == CoverageForced)
  @debug.assert_eq(
    params.generator_config.section_bias,
    GenValidSectionBias::coverage_forced_default(),
  )
  @debug.assert_eq(
    params.generator_config.features,
    GenValidFeatureToggles::coverage_forced_default(),
  )
}

///|
test "gen_invalid_ast new can disable strategy prereqs" {
  let restrictive = GenValidConfig::{
    ..GenValidConfig::natural_default(),
    max_mems: 0,
    max_datas: 0,
    section_bias: GenValidSectionBias::{
      ..GenValidSectionBias::natural_default(),
      mems_percent: 0,
      datas_percent: 0,
    },
    features: GenValidFeatureToggles::{
      ..GenValidFeatureToggles::natural_default(),
      allow_mems: false,
      allow_datas: false,
    },
  }
  let params = GenInvalidAstParams::new(
    NonConstantDataOffset,
    generator_config=restrictive,
    require_strategy_prereqs=false,
  )
  assert_false(params.require_strategy_prereqs)
  let adjusted = gen_invalid_ast_seed_config(params)
  @debug.assert_eq(adjusted.max_mems, 0)
  @debug.assert_eq(adjusted.max_datas, 0)
  assert_false(adjusted.features.allow_mems)
  assert_false(adjusted.features.allow_datas)
}

///|
test "gen_invalid_require_memory_data_gen_valid_config widens memory and data prerequisites" {
  let restrictive = GenValidConfig::{
    ..GenValidConfig::natural_default(),
    max_mems: 0,
    max_datas: 0,
    section_bias: GenValidSectionBias::{
      ..GenValidSectionBias::natural_default(),
      mems_percent: 0,
      datas_percent: 0,
    },
    features: GenValidFeatureToggles::{
      ..GenValidFeatureToggles::natural_default(),
      allow_mems: false,
      allow_datas: false,
    },
  }
  let adjusted = gen_invalid_require_memory_data_gen_valid_config(restrictive)
  @debug.assert_eq(adjusted.max_mems, 1)
  @debug.assert_eq(adjusted.max_datas, 1)
  @debug.assert_eq(adjusted.section_bias.mems_percent, 100)
  @debug.assert_eq(adjusted.section_bias.datas_percent, 100)
  assert_true(adjusted.features.allow_mems)
  assert_true(adjusted.features.allow_datas)
}

///|
test "gen_invalid_require_defined_func_gen_valid_config widens type and func minimums" {
  let restrictive = GenValidConfig::{
    ..GenValidConfig::natural_default(),
    max_type_defs: 0,
    max_defined_funcs: 0,
  }
  let adjusted = gen_invalid_require_defined_func_gen_valid_config(restrictive)
  @debug.assert_eq(adjusted.max_type_defs, 1)
  @debug.assert_eq(adjusted.max_defined_funcs, 1)
}

///|
test "gen_invalid_ast_seed_config composes declared prerequisites" {
  let restrictive = GenValidConfig::{
    ..GenValidConfig::natural_default(),
    max_type_defs: 0,
    max_defined_funcs: 0,
    max_mems: 0,
    max_datas: 0,
    section_bias: GenValidSectionBias::{
      ..GenValidSectionBias::natural_default(),
      mems_percent: 0,
      datas_percent: 0,
    },
    features: GenValidFeatureToggles::{
      ..GenValidFeatureToggles::natural_default(),
      allow_mems: false,
      allow_datas: false,
    },
  }
  let adjusted = gen_invalid_ast_seed_config(
    GenInvalidAstParams::new(
      MissingDataCountDataDrop,
      generator_config=restrictive,
    ),
  )
  @debug.assert_eq(adjusted.max_type_defs, 1)
  @debug.assert_eq(adjusted.max_defined_funcs, 1)
  @debug.assert_eq(adjusted.max_mems, 1)
  @debug.assert_eq(adjusted.max_datas, 1)
  assert_true(adjusted.features.allow_mems)
  assert_true(adjusted.features.allow_datas)
}

///|
test "gen_invalid_small_gen_valid_config shrinks a natural config" {
  let natural = GenValidConfig::natural_default()
  let shrunk = gen_invalid_small_gen_valid_config(natural)
  assert_true(shrunk.mode == Natural)
  assert_true(shrunk.max_type_defs < natural.max_type_defs)
  assert_true(shrunk.max_defined_funcs < natural.max_defined_funcs)
  assert_true(shrunk.max_body_statements < natural.max_body_statements)
  assert_true(shrunk.max_body_depth < natural.max_body_depth)
}

///|
test "gen_invalid_ast small_natural_seed uses a smaller natural config" {
  let params = GenInvalidAstParams::small_natural_seed(DuplicateExportName)
  let natural = GenValidConfig::natural_default()
  assert_true(params.seed_mode == RandomValidSeed)
  assert_true(params.generator_config.mode == Natural)
  assert_true(params.generator_config.max_type_defs < natural.max_type_defs)
  assert_true(
    params.generator_config.max_defined_funcs < natural.max_defined_funcs,
  )
  assert_true(
    params.generator_config.max_body_statements < natural.max_body_statements,
  )
  assert_true(params.generator_config.max_body_depth < natural.max_body_depth)
}

///|
test "gen_invalid_ast small_coverage_forced_seed uses a smaller coverage config" {
  let params = GenInvalidAstParams::small_coverage_forced_seed(
    DuplicateExportName,
  )
  let forced = GenValidConfig::coverage_forced_default()
  assert_true(params.seed_mode == RandomValidSeed)
  assert_true(params.generator_config.mode == CoverageForced)
  assert_true(params.generator_config.max_type_defs < forced.max_type_defs)
  assert_true(
    params.generator_config.max_defined_funcs < forced.max_defined_funcs,
  )
  assert_true(
    params.generator_config.max_body_statements < forced.max_body_statements,
  )
  assert_true(params.generator_config.max_body_depth < forced.max_body_depth)
}

///|
test "gen_invalid_ast small_natural_seed still widens missing-datacount prereqs" {
  let adjusted = gen_invalid_ast_seed_config(
    GenInvalidAstParams::small_natural_seed(MissingDataCount),
  )
  @debug.assert_eq(adjusted.max_mems, 1)
  @debug.assert_eq(adjusted.max_datas, 1)
  @debug.assert_eq(adjusted.section_bias.mems_percent, 100)
  @debug.assert_eq(adjusted.section_bias.datas_percent, 100)
  assert_true(adjusted.features.allow_mems)
  assert_true(adjusted.features.allow_datas)
}

///|
test "gen_invalid_ast repro_seed matches small coverage-forced seed defaults" {
  let repro = GenInvalidAstParams::repro_seed(DuplicateExportName)
  let small = GenInvalidAstParams::small_coverage_forced_seed(
    DuplicateExportName,
  )
  assert_true(repro.seed_mode == small.seed_mode)
  assert_true(repro.generator_config == small.generator_config)
  assert_true(repro.require_strategy_prereqs == small.require_strategy_prereqs)
}

///|
test "gen_invalid_ast_generate supports function-section invalid type index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef2UL),
      GenInvalidAstParams::repro_seed(InvalidFuncTypeIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-func-type-index base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-func-type-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports data-section invalid offset strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef5UL),
      GenInvalidAstParams::repro_seed(NonConstantDataOffset),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected non-constant-data-offset base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected non-constant-data-offset mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == DataSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports data-section invalid offset type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef87UL),
      GenInvalidAstParams::repro_seed(InvalidDataOffsetType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-data-offset-type base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-data-offset-type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == DataSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid global initializer type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef41UL),
      GenInvalidAstParams::repro_seed(InvalidGlobalInitType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-global-init-type base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-global-init-type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == GlobalSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports import-section invalid func type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef6UL),
      GenInvalidAstParams::repro_seed(InvalidImportedFuncTypeIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-imported-func-type-index base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-imported-func-type-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == ImportSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports element-section invalid offset strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef8UL),
      GenInvalidAstParams::repro_seed(NonConstantElemOffset),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected non-constant-elem-offset base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected non-constant-elem-offset mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == ElementSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports data-section active memory index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef82UL),
      GenInvalidAstParams::repro_seed(InvalidDataActiveMemoryIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-data-active-memory-index base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-data-active-memory-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == DataSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports element-section active table index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef81UL),
      GenInvalidAstParams::repro_seed(InvalidElementActiveTableIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-element-active-table-index base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-element-active-table-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == ElementSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports element-section function index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef83UL),
      GenInvalidAstParams::repro_seed(InvalidElementFuncIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-element-func-index base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-element-func-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == ElementSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports element-section typed expression type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef84UL),
      GenInvalidAstParams::repro_seed(InvalidElementTypedExprType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-element-typed-expr-type base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-element-typed-expr-type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == ElementSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports element-section table ref-type mismatch strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef841UL),
      GenInvalidAstParams::repro_seed(InvalidElementTableRefTypeMismatch),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-element-table-ref-type-mismatch base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-element-table-ref-type-mismatch mutation to fail")
    Err(err) => {
      let diagnostic = validation_error_diagnostic(err)
      assert_true(
        validation_issue_family(diagnostic.issue) == ElementSectionFamily,
      )
      assert_true(
        validation_error_message(err).contains(
          "elem.active: elem type does not match table element type",
        ),
      )
    }
  }
}

///|
test "gen_invalid_ast_generate supports table-section invalid init expression type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef86UL),
      GenInvalidAstParams::repro_seed(InvalidTableInitExprType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-table-init-expr-type base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-table-init-expr-type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == TableSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports memory-section invalid limit range strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef85UL),
      GenInvalidAstParams::repro_seed(InvalidMemoryLimitRange),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-memory-limit-range base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-memory-limit-range mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == MemorySectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports table-section invalid limit range strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef86UL),
      GenInvalidAstParams::repro_seed(InvalidTableLimitRange),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-table-limit-range base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-table-limit-range mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == TableSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports imported memory invalid limit range strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef87UL),
      GenInvalidAstParams::repro_seed(InvalidImportedMemoryLimitRange),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-imported-memory-limit-range base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-imported-memory-limit-range mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == ImportSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports imported table invalid limit range strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef88UL),
      GenInvalidAstParams::repro_seed(InvalidImportedTableLimitRange),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-imported-table-limit-range base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-imported-table-limit-range mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == ImportSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports imported shared memory without max strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef89UL),
      GenInvalidAstParams::repro_seed(InvalidImportedSharedMemoryWithoutMax),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-imported-shared-memory-without-max base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-imported-shared-memory-without-max mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == ImportSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports imported shared memory64 without max strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef8aUL),
      GenInvalidAstParams::repro_seed(InvalidImportedSharedMemory64WithoutMax),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-imported-shared-memory64-without-max base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-imported-shared-memory64-without-max mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == ImportSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports tag-section invalid type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5efaUL),
      GenInvalidAstParams::repro_seed(InvalidTagTypeIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-tag-type-index base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-tag-type-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == TagSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports tag-section result type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef8bUL),
      GenInvalidAstParams::repro_seed(InvalidTagResultType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-tag-result-type base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-tag-result-type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == TagSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports imported tag result type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5ef8cUL),
      GenInvalidAstParams::repro_seed(InvalidImportedTagResultType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-imported-tag-result-type base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-imported-tag-result-type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == ImportSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports datacount-section invalid strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5efcUL),
      GenInvalidAstParams::repro_seed(DataCountWithoutDataSec),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected datacount-without-data base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected datacount-without-data mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == DataCountSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid export func index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5efdUL),
      GenInvalidAstParams::repro_seed(InvalidExportFuncIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-export-func-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == ExportSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid export func wrong-kind index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5efd01UL),
      GenInvalidAstParams::repro_seed(InvalidExportFuncWrongKindIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected invalid-export-func-wrong-kind-index base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-export-func-wrong-kind-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == ExportSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid imported start func param strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5efd1UL),
      GenInvalidAstParams::repro_seed(InvalidImportedStartFuncParam),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-imported-start-func-param mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == StartSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid imported start func result strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5efd2UL),
      GenInvalidAstParams::repro_seed(InvalidImportedStartFuncResult),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-imported-start-func-result mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == StartSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid imported start func param-result strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5efd21UL),
      GenInvalidAstParams::repro_seed(InvalidImportedStartFuncParamResult),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-imported-start-func-param-result mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == StartSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid imported start func multi-param strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5efd22UL),
      GenInvalidAstParams::repro_seed(InvalidImportedStartFuncMultiParam),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-imported-start-func-multi-param mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == StartSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid imported start func f32-param strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5efd23UL),
      GenInvalidAstParams::repro_seed(InvalidImportedStartFuncF32Param),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-imported-start-func-f32-param mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == StartSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid imported start func externref-param strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5efd24UL),
      GenInvalidAstParams::repro_seed(InvalidImportedStartFuncExternrefParam),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-imported-start-func-externref-param mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == StartSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid imported start func funcref-param strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5efd25UL),
      GenInvalidAstParams::repro_seed(InvalidImportedStartFuncFuncrefParam),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-imported-start-func-funcref-param mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == StartSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports start func wrong-kind index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5efd26UL),
      GenInvalidAstParams::repro_seed(StartFuncWrongKindIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected start-func-wrong-kind-index base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected start-func-wrong-kind-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == StartSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid local name index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5efd3UL),
      GenInvalidAstParams::repro_seed(InvalidLocalNameSectionIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-local-name-section-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == NameSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid label name index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5efd4UL),
      GenInvalidAstParams::repro_seed(InvalidLabelNameSectionIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-label-name-section-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == NameSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid local-name function index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5efd41UL),
      GenInvalidAstParams::repro_seed(InvalidLocalNameSectionFuncIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-local-name-section-func-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == NameSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid label-name function index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5efd42UL),
      GenInvalidAstParams::repro_seed(InvalidLabelNameSectionFuncIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-label-name-section-func-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == NameSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports missing-datacount data.drop strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5effUL),
      GenInvalidAstParams::repro_seed(MissingDataCountDataDrop),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected missing-datacount-data-drop mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports codesec without funcsec strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f01UL),
      GenInvalidAstParams::repro_seed(CodeSecWithoutFuncSec),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected codesec-without-funcsec mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == CodeSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports codesec length too small strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f011UL),
      GenInvalidAstParams::repro_seed(CodeSecLengthMismatchTooSmall),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected codesec-length-mismatch-too-small base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected codesec-length-mismatch-too-small mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == CodeSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports codesec length too large strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f012UL),
      GenInvalidAstParams::repro_seed(CodeSecLengthMismatchTooLarge),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected codesec-length-mismatch-too-large base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected codesec-length-mismatch-too-large mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == CodeSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports codesec imported body strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f013UL),
      GenInvalidAstParams::repro_seed(CodeSecIncludesImportedBody),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.base_module) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected codesec-includes-imported-body base module to validate, got \{validation_error_message(err)}",
      )
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected codesec-includes-imported-body mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == CodeSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid table name index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f02UL),
      GenInvalidAstParams::repro_seed(InvalidTableNameSectionIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-table-name-section-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == NameSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid global name index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f03UL),
      GenInvalidAstParams::repro_seed(InvalidGlobalNameSectionIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-global-name-section-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == NameSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid type name index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f04UL),
      GenInvalidAstParams::repro_seed(InvalidTypeNameSectionIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-type-name-section-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == NameSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid field name index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f041UL),
      GenInvalidAstParams::repro_seed(InvalidFieldNameSectionIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-field-name-section-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == NameSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid elem name index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f05UL),
      GenInvalidAstParams::repro_seed(InvalidElemNameSectionIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-elem-name-section-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == NameSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid data name index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f06UL),
      GenInvalidAstParams::repro_seed(InvalidDataNameSectionIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-data-name-section-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == NameSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid export table index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f07UL),
      GenInvalidAstParams::repro_seed(InvalidExportTableIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-export-table-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == ExportSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid export global index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f08UL),
      GenInvalidAstParams::repro_seed(InvalidExportGlobalIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-export-global-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == ExportSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid export memory index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f091UL),
      GenInvalidAstParams::repro_seed(InvalidExportMemoryIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-export-memory-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == ExportSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid export tag index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f09UL),
      GenInvalidAstParams::repro_seed(InvalidExportTagIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-export-tag-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == ExportSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid tag name index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f0aUL),
      GenInvalidAstParams::repro_seed(InvalidTagNameSectionIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-tag-name-section-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == NameSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid imported tag type index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f0aaUL),
      GenInvalidAstParams::repro_seed(InvalidImportedTagTypeIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-imported-tag-type-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == ImportSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid imported table ref type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f0abUL),
      GenInvalidAstParams::repro_seed(InvalidImportedTableRefType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-imported-table-ref-type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == ImportSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid imported global ref type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f0acUL),
      GenInvalidAstParams::repro_seed(InvalidImportedGlobalRefType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-imported-global-ref-type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == ImportSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid table ref type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f0adUL),
      GenInvalidAstParams::repro_seed(InvalidTableRefType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-table-ref-type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == TableSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid descriptor field ref type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f0afUL),
      GenInvalidAstParams::repro_seed(InvalidDescriptorFieldRefType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-descriptor-field-ref-type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == TypeSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid subtype super cycle strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x1020a5UL),
      GenInvalidAstParams::repro_seed(InvalidSubtypeSuperCycle),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-subtype-super-cycle mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == TypeSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports invalid global ref type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f0aeUL),
      GenInvalidAstParams::repro_seed(InvalidGlobalRefType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-global-ref-type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == GlobalSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports datacount mismatch too-small strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f0bUL),
      GenInvalidAstParams::repro_seed(DataCountMismatchTooSmall),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected datacount-mismatch-too-small mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == DataCountSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports datacount mismatch too-large strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f0cUL),
      GenInvalidAstParams::repro_seed(DataCountMismatchTooLarge),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected datacount-mismatch-too-large mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == DataCountSectionFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body invalid local index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f0dUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyLocalIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-function-body-local-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body invalid global index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f0eUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyGlobalIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-function-body-global-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body invalid table index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f0fUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-function-body-table-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body invalid memory index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f10UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-function-body-memory-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body invalid function index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f11UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyCallIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected invalid-function-body-call-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body invalid branch label index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f12UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyBrLabelIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-function-body-branch-label-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body invalid branch payload strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f13UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyBrPayloadMismatch),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-branch-payload-mismatch mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body call payload mismatch strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f14UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyCallPayloadMismatch),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-call-payload-mismatch mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body br_if payload mismatch strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f15UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyBrIfPayloadMismatch),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-br-if-payload-mismatch mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body br_table payload mismatch strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f16UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyBrTablePayloadMismatch),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-br-table-payload-mismatch mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory64 address type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f1aUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemory64AddressType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory64-address-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory store address type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d36UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryStoreAddressType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory-store-address-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory64 store address type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d37UL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodyMemory64StoreAddressType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory64-store-address-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory store value type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f1bUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryStoreValueType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory-store-value-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory64 store value type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d38UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemory64StoreValueType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory64-store-value-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory64.copy length type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d39UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemory64CopyLengthType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory64-copy-length-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory64.copy source type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d3aUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemory64CopySourceType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory64-copy-source-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory64.copy dest type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d3bUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemory64CopyDestType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory64-copy-dest-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory64.init dest type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d6aUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemory64InitDestType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory64-init-dest-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body local.set value type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10ca1UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyLocalSetValueType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-local-set-value-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body local.tee value type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10ce2UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyLocalTeeValueType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-local-tee-value-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body table.set value type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f1cUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableSetValueType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-table-set-value-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body table.set index type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cfbUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableSetIndexType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-table-set-index-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body call_indirect index type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cfcUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyCallIndirectIndexType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-call-indirect-index-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body return_call_indirect index type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cfdUL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodyReturnCallIndirectIndexType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-return-call-indirect-index-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body return_call_ref ref type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cfeUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyReturnCallRefType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-return-call-ref-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body call_ref ref type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cffUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyCallRefType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-function-body-call-ref-type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body ref.cast input type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d00UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyRefCastInputType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-ref-cast-input-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body ref.test input type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d01UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyRefTestInputType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-ref-test-input-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body ref.test_desc input type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d02UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyRefTestDescInputType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-ref-test-desc-input-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body ref.cast_desc_eq input type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d03UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyRefCastDescEqInputType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-ref-cast-desc-eq-input-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body ref.get_desc input type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d06UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyRefGetDescInputType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-ref-get-desc-input-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body ref.eq input type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d07UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyRefEqInputType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-function-body-ref-eq-input-type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body br_on_cast input type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d04UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyBrOnCastInputType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-br-on-cast-input-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body br_on_cast target subtype strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d73UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyBrOnCastTargetSubtype),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-br-on-cast-target-subtype mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body br_on_cast_fail input type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d05UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyBrOnCastFailInputType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-br-on-cast-fail-input-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body table.get index type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10ce4UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableGetIndexType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-table-get-index-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body table.grow value type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10ce5UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableGrowValueType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-table-grow-value-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body table.fill value type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10ce6UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableFillValueType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-table-fill-value-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory load alignment strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d44UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryLoadAlignment),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory-load-alignment mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory store alignment strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d45UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryStoreAlignment),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory-store-alignment mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory load offset range strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d46UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryLoadOffsetRange),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory-load-offset-range mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory store offset range strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d47UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryStoreOffsetRange),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory-store-offset-range mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory.copy destination index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d48UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryCopyDestIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory-copy-dest-index mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory.copy source index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d49UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryCopySourceIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory-copy-source-index mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory load memarg index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d4cUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryLoadIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-function-body-memory-load-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory store memarg index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d4dUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryStoreIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-function-body-memory-store-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic load memarg index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d4eUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyAtomicLoadIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-function-body-atomic-load-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic store memarg index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d4fUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyAtomicStoreIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-function-body-atomic-store-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic notify memarg index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d50UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyAtomicNotifyIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-atomic-notify-index mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic wait memarg index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d51UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyAtomicWaitIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-function-body-atomic-wait-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic rmw memarg index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d52UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyAtomicRmwIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-function-body-atomic-rmw-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic cmpxchg memarg index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d53UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyAtomicCmpxchgIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-atomic-cmpxchg-index mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD extract lane index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d54UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdExtractLaneIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD extract lane index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD replace lane index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d55UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdReplaceLaneIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD replace lane index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD load lane index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d56UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdLoadLaneIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD load lane index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD store lane index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d57UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdStoreLaneIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD store lane index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD splat input type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d58UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdSplatInputType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD splat input type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD swizzle input type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d59UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdSwizzleInputType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD swizzle input type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD bitselect mask type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d5aUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdBitselectMaskType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD bitselect mask type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD bitselect left type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d6aUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdBitselectLeftType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD bitselect left type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD bitselect right type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d6bUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdBitselectRightType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD bitselect right type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD extract input type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d5bUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdExtractInputType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD extract input type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD replace vector type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d5cUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdReplaceVectorType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD replace vector type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD replace value type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d5dUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdReplaceValueType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD replace value type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD load address type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d5eUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdLoadAddressType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD load address type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD store address type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d5fUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdStoreAddressType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD store address type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD store value type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d60UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdStoreValueType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD store value type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD load-extend address type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d61UL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodySimdLoadExtendAddressType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD load-extend address type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD load-splat address type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d62UL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodySimdLoadSplatAddressType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD load-splat address type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD load-zero address type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d63UL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodySimdLoadZeroAddressType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD load-zero address type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD unary input type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d64UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdUnaryInputType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD unary input type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD binary left type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d65UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdBinaryLeftType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD binary left type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body relaxed SIMD swizzle left type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x1020c3UL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodyRelaxedSimdSwizzleLeftType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected relaxed SIMD swizzle left type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body relaxed SIMD laneselect mask type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x1022b9UL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodyRelaxedSimdLaneselectMaskType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected relaxed SIMD laneselect mask type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD binary right type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d66UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdBinaryRightType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD binary right type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD shift vector type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d67UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdShiftVectorType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD shift vector type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD shift count type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d68UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdShiftCountType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD shift count type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD load-lane address type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d69UL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodySimdLoadLaneAddressType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD load-lane address type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD load-lane vector type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d6aUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdLoadLaneVectorType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD load-lane vector type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD store-lane address type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d6bUL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodySimdStoreLaneAddressType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD store-lane address type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD store-lane vector type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d6cUL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodySimdStoreLaneVectorType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD store-lane vector type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD load memory index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d6dUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdLoadMemoryIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD load memory index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD store memory index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d6eUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySimdStoreMemoryIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD store memory index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD load-lane memory index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d6fUL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodySimdLoadLaneMemoryIndex,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD load-lane memory index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body SIMD store-lane memory index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d70UL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodySimdStoreLaneMemoryIndex,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) => fail("expected SIMD store-lane memory index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory.init data index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d4aUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryInitDataIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory-init-data-index mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body table.init elem index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d4bUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableInitElemIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-table-init-elem-index mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body table.init table index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d71UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableInitTableIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-table-init-table-index mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body if condition type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d42UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyIfConditionType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-function-body-if-condition-type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body if branch result type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d43UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyIfBranchResultType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-if-branch-result-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body select condition type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d40UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySelectConditionType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-select-condition-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body select operand type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d41UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodySelectOperandType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-select-operand-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory.size index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d3cUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemorySizeIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-function-body-memory-size-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory.grow index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d3dUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryGrowIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-function-body-memory-grow-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory.grow delta type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10ce7UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryGrowDeltaType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory-grow-delta-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory.fill value type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10ce8UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryFillValueType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory-fill-value-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory.fill dest type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d3eUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryFillDestType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory-fill-dest-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory.fill length type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d3fUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryFillLengthType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory-fill-length-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory.copy length type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10ce9UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryCopyLengthType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory-copy-length-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory.copy source type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10ceaUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryCopySourceType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory-copy-source-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory.copy dest type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cebUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryCopyDestType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory-copy-dest-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory.init length type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cecUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryInitLengthType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory-init-length-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory.init source type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cedUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryInitSourceType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory-init-source-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body memory.init dest type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10ceeUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyMemoryInitDestType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-memory-init-dest-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body table.copy length type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cefUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableCopyLengthType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-table-copy-length-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body table.copy source type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cf0UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableCopySourceType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-table-copy-source-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body table.copy dest type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cf1UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableCopyDestType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-table-copy-dest-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body table.copy dest index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d70UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableCopyDestIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-table-copy-dest-index mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body table.copy source index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d71UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableCopySourceIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-table-copy-source-index mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body table.init length type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cf2UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableInitLengthType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-table-init-length-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body table.init source type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cf3UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableInitSourceType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-table-init-source-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body table.init dest type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cf4UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableInitDestType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-table-init-dest-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body data.drop index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cf5UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyDataDropIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-function-body-data-drop-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body elem.drop index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cf6UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyElemDropIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-function-body-elem-drop-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body table.size index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cf7UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableSizeIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-function-body-table-size-index mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body table.fill dest type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cf9UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableFillDestType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-table-fill-dest-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body table.fill length type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cfaUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableFillLengthType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-table-fill-length-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body table.grow delta type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10cf8UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyTableGrowDeltaType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-table-grow-delta-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body return value type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10ce3UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyReturnValueType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail("expected invalid-function-body-return-value-type mutation to fail")
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.fill input type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d0bUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyArrayFillInputType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-fill-input-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.fill value type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d0cUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyArrayFillValueType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-fill-value-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.fill length type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d0dUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyArrayFillLengthType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-fill-length-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.copy input type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d0eUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyArrayCopyInputType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-copy-input-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.copy source input type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d0fUL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodyArrayCopySourceInputType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-copy-source-input-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.copy length type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d10UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyArrayCopyLengthType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-copy-length-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.init_data input type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d11UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyArrayInitDataInputType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-init-data-input-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.init_data dest type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d12UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyArrayInitDataDestType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-init-data-dest-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.init_data source type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d13UL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodyArrayInitDataSourceType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-init-data-source-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.init_data length type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d14UL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodyArrayInitDataLengthType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-init-data-length-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.init_elem input type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d15UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyArrayInitElemInputType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-init-elem-input-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.init_elem dest type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d16UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyArrayInitElemDestType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-init-elem-dest-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.init_elem source type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d17UL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodyArrayInitElemSourceType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-init-elem-source-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.init_elem length type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d18UL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodyArrayInitElemLengthType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-init-elem-length-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.new value type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d19UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyArrayNewValueType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-new-value-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.new length type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d1aUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyArrayNewLengthType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-new-length-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.new_default length type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d1bUL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodyArrayNewDefaultLengthType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-new-default-length-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.new_fixed value type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d1cUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyArrayNewFixedValueType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-new-fixed-value-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.new_data source type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d1dUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyArrayNewDataSourceType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-new-data-source-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.new_data length type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d1eUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyArrayNewDataLengthType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-new-data-length-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.new_elem source type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d1fUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyArrayNewElemSourceType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-new-elem-source-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body array.new_elem length type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d20UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyArrayNewElemLengthType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-array-new-elem-length-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body struct.new value type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d21UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyStructNewValueType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-struct-new-value-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body struct.get input type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d22UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyStructGetInputType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-struct-get-input-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body struct.set input type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d23UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyStructSetInputType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-struct-set-input-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body struct.set value type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d24UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyStructSetValueType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-struct-set-value-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body struct.get field index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d25UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyStructGetFieldIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-struct-get-field-index mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body struct.set field index strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d26UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyStructSetFieldIndex),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-struct-set-field-index mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body struct.set immutable field strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d27UL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodyStructSetImmutableField,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-struct-set-immutable-field mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body struct.get signed field type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d28UL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodyStructGetSignedFieldType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-struct-get-signed-field-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic.notify count type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d29UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyAtomicNotifyCountType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-atomic-notify-count-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic.wait timeout type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d2aUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyAtomicWaitTimeoutType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-atomic-wait-timeout-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic.rmw value type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d2bUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyAtomicRmwValueType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-atomic-rmw-value-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic.cmpxchg replacement type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d2cUL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodyAtomicCmpxchgReplacementType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-atomic-cmpxchg-replacement-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic.load address type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d2dUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyAtomicLoadAddressType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-atomic-load-address-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic.load non-shared memory strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d36UL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodyAtomicLoadNonSharedMemory,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-atomic-load-non-shared-memory mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic.store address type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d2eUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyAtomicStoreAddressType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-atomic-store-address-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic.store value type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d2fUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyAtomicStoreValueType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-atomic-store-value-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic.notify address type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d30UL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodyAtomicNotifyAddressType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-atomic-notify-address-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic.wait address type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d31UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyAtomicWaitAddressType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-atomic-wait-address-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic.wait expected type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d32UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyAtomicWaitExpectedType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-atomic-wait-expected-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic.rmw address type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d33UL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyAtomicRmwAddressType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-atomic-rmw-address-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic.cmpxchg address type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d34UL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodyAtomicCmpxchgAddressType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-atomic-cmpxchg-address-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body atomic.cmpxchg expected type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x10d35UL),
      GenInvalidAstParams::repro_seed(
        InvalidFunctionBodyAtomicCmpxchgExpectedType,
      ),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-atomic-cmpxchg-expected-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid_ast_generate supports function-body global.set value type strategy" {
  let generated = match
    gen_invalid_ast_generate(
      @splitmix.new(seed=0x5f1dUL),
      GenInvalidAstParams::repro_seed(InvalidFunctionBodyGlobalSetValueType),
    ) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  match validate_module(generated.mutation.mutated_module) {
    Ok(_) =>
      fail(
        "expected invalid-function-body-global-set-value-type mutation to fail",
      )
    Err(err) => {
      let family = validation_issue_family(
        validation_error_diagnostic(err).issue,
      )
      assert_true(family == FunctionBodyFamily)
    }
  }
}

///|
test "gen_invalid seed helpers reuse named gen-valid profiles" {
  @debug.assert_eq(
    gen_invalid_coverage_seed_generator_config(),
    GenValidConfig::for_profile(MutationSeedRichProfile),
  )
  @debug.assert_eq(
    GenInvalidAstParams::small_natural_seed(DuplicateExportName).generator_config,
    GenValidConfig::for_profile(MutationSeedSmallProfile),
  )
  @debug.assert_eq(
    GenInvalidAstParams::repro_seed(DuplicateExportName).generator_config,
    gen_invalid_small_gen_valid_config(
      GenValidConfig::for_profile(MutationSeedRichProfile),
    ),
  )
}

///|
test "gen_invalid_ast_params_profile_name identifies named and custom profiles" {
  @debug.assert_eq(
    gen_invalid_ast_params_profile_name(
      GenInvalidAstParams::natural_seed(DuplicateExportName),
    ),
    "natural",
  )
  @debug.assert_eq(
    gen_invalid_ast_params_profile_name(
      GenInvalidAstParams::coverage_forced_seed(DuplicateExportName),
    ),
    "coverage-forced",
  )
  @debug.assert_eq(
    gen_invalid_ast_params_profile_name(
      GenInvalidAstParams::small_natural_seed(DuplicateExportName),
    ),
    "small-natural",
  )
  @debug.assert_eq(
    gen_invalid_ast_params_profile_name(
      GenInvalidAstParams::small_coverage_forced_seed(DuplicateExportName),
    ),
    "small-coverage-forced",
  )
  @debug.assert_eq(
    gen_invalid_ast_params_profile_name(
      GenInvalidAstParams::repro_seed(DuplicateExportName),
    ),
    "repro",
  )
  @debug.assert_eq(
    gen_invalid_ast_params_profile_name(
      GenInvalidAstParams::minimal_seed(DuplicateExportName),
    ),
    "minimal",
  )
  @debug.assert_eq(
    gen_invalid_ast_params_profile_name(
      GenInvalidAstParams::new(DuplicateExportName, generator_config=GenValidConfig::{
        ..GenValidConfig::natural_default(),
        max_body_depth: 99,
      }),
    ),
    "custom",
  )
}
