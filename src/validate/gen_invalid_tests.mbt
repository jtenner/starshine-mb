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
