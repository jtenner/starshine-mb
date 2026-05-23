///|
pub enum GenInvalidSeedMode {
  RandomValidSeed
  MinimalValidSeed
} derive(Eq, Debug)

///|
pub enum GenInvalidNamedSeedProfile {
  NaturalSeedProfile
  CoverageForcedSeedProfile
  SmallNaturalSeedProfile
  SmallCoverageForcedSeedProfile
  ReproSeedProfile
  MinimalSeedProfile
  RichSeedProfile
} derive(Eq, Debug)

///|
pub fn gen_invalid_seed_mode_name(mode : GenInvalidSeedMode) -> String {
  match mode {
    RandomValidSeed => "random-valid"
    MinimalValidSeed => "minimal-valid"
  }
}

///|
pub fn gen_invalid_named_seed_profile_name(
  profile : GenInvalidNamedSeedProfile,
) -> String {
  match profile {
    NaturalSeedProfile => "natural"
    CoverageForcedSeedProfile => "coverage-forced"
    SmallNaturalSeedProfile => "small-natural"
    SmallCoverageForcedSeedProfile => "small-coverage-forced"
    ReproSeedProfile => "repro"
    MinimalSeedProfile => "minimal"
    RichSeedProfile => "rich"
  }
}

///|
pub struct GenInvalidAstParams {
  strategy : ValidateInvalidAstStrategyId
  seed_mode : GenInvalidSeedMode
  seed_profile : GenInvalidNamedSeedProfile?
  generator_config : GenValidConfig
  require_strategy_prereqs : Bool
} derive(Eq, Debug)

///|
pub fn gen_invalid_coverage_seed_generator_config() -> GenValidConfig {
  GenValidConfig::for_profile(MutationSeedRichProfile)
}

///|
pub fn GenInvalidAstParams::new(
  strategy : ValidateInvalidAstStrategyId,
  seed_mode? : GenInvalidSeedMode = RandomValidSeed,
  generator_config? : GenValidConfig = gen_invalid_coverage_seed_generator_config(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidAstParams {
  {
    strategy,
    seed_mode,
    seed_profile: None,
    generator_config,
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidAstParams::natural_seed(
  strategy : ValidateInvalidAstStrategyId,
  generator_config? : GenValidConfig = GenValidConfig::natural_default(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidAstParams {
  {
    strategy,
    seed_mode: RandomValidSeed,
    seed_profile: Some(NaturalSeedProfile),
    generator_config,
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidAstParams::coverage_forced_seed(
  strategy : ValidateInvalidAstStrategyId,
  generator_config? : GenValidConfig = gen_invalid_coverage_seed_generator_config(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidAstParams {
  {
    strategy,
    seed_mode: RandomValidSeed,
    seed_profile: Some(CoverageForcedSeedProfile),
    generator_config,
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidAstParams::small_natural_seed(
  strategy : ValidateInvalidAstStrategyId,
  generator_config? : GenValidConfig = GenValidConfig::natural_default(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidAstParams {
  {
    strategy,
    seed_mode: RandomValidSeed,
    seed_profile: Some(SmallNaturalSeedProfile),
    generator_config: gen_invalid_small_gen_valid_config(generator_config),
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidAstParams::small_coverage_forced_seed(
  strategy : ValidateInvalidAstStrategyId,
  generator_config? : GenValidConfig = gen_invalid_coverage_seed_generator_config(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidAstParams {
  {
    strategy,
    seed_mode: RandomValidSeed,
    seed_profile: Some(SmallCoverageForcedSeedProfile),
    generator_config: gen_invalid_small_gen_valid_config(generator_config),
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidAstParams::repro_seed(
  strategy : ValidateInvalidAstStrategyId,
  generator_config? : GenValidConfig = gen_invalid_coverage_seed_generator_config(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidAstParams {
  {
    strategy,
    seed_mode: RandomValidSeed,
    seed_profile: Some(ReproSeedProfile),
    generator_config: gen_invalid_small_gen_valid_config(generator_config),
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidAstParams::minimal_seed(
  strategy : ValidateInvalidAstStrategyId,
  generator_config? : GenValidConfig = gen_invalid_coverage_seed_generator_config(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidAstParams {
  {
    strategy,
    seed_mode: MinimalValidSeed,
    seed_profile: Some(MinimalSeedProfile),
    generator_config,
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidAstParams::rich_seed(
  strategy : ValidateInvalidAstStrategyId,
  generator_config? : GenValidConfig = gen_invalid_coverage_seed_generator_config(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidAstParams {
  {
    strategy,
    seed_mode: RandomValidSeed,
    seed_profile: Some(RichSeedProfile),
    generator_config,
    require_strategy_prereqs,
  }
}

///|
pub fn gen_invalid_ast_params_profile_name(
  params : GenInvalidAstParams,
) -> String {
  match params.seed_profile {
    Some(profile) => gen_invalid_named_seed_profile_name(profile)
    None => "custom"
  }
}

///|
pub struct GenInvalidAstGenerated {
  base_module : Module
  mutation : ValidateInvalidAstMutation
} derive(Debug)

///|
fn gen_invalid_ast_strategy_label(
  strategy : ValidateInvalidAstStrategyId,
) -> String {
  match strategy {
    DuplicateExportName => "duplicate-export-name"
    InvalidExportFuncIndex => "invalid-export-func-index"
    InvalidImportedStartFuncParam => "invalid-imported-start-func-param"
    InvalidImportedStartFuncResult => "invalid-imported-start-func-result"
    InvalidImportedStartFuncParamResult =>
      "invalid-imported-start-func-param-result"
    InvalidImportedStartFuncMultiParam =>
      "invalid-imported-start-func-multi-param"
    InvalidImportedStartFuncF32Param => "invalid-imported-start-func-f32-param"
    InvalidImportedStartFuncExternrefParam =>
      "invalid-imported-start-func-externref-param"
    InvalidImportedStartFuncFuncrefParam =>
      "invalid-imported-start-func-funcref-param"
    InvalidStartSignature => "invalid-start-signature"
    StartFuncOutOfRange => "start-func-out-of-range"
    MissingDataCount => "missing-datacount"
    MissingDataCountDataDrop => "missing-datacount-data-drop"
    InvalidFunctionBodyLocalIndex => "invalid-function-body-local-index"
    InvalidFunctionBodyGlobalIndex => "invalid-function-body-global-index"
    InvalidFunctionBodyTableIndex => "invalid-function-body-table-index"
    InvalidFunctionBodyMemoryIndex => "invalid-function-body-memory-index"
    InvalidFunctionBodyCallIndex => "invalid-function-body-call-index"
    InvalidFunctionBodyBrLabelIndex =>
      "invalid-function-body-branch-label-index"
    InvalidFunctionBodyBrPayloadMismatch =>
      "invalid-function-body-branch-payload-mismatch"
    UndeclaredRefFunc => "undeclared-ref-func"
    InvalidNameSectionFuncIndex => "invalid-name-section-func-index"
    InvalidLocalNameSectionIndex => "invalid-local-name-section-index"
    InvalidLabelNameSectionIndex => "invalid-label-name-section-index"
    InvalidMemoryNameSectionIndex => "invalid-memory-name-section-index"
    CodeSecWithoutFuncSec => "codesec-without-funcsec"
    InvalidTableNameSectionIndex => "invalid-table-name-section-index"
    InvalidGlobalNameSectionIndex => "invalid-global-name-section-index"
    InvalidTypeNameSectionIndex => "invalid-type-name-section-index"
    InvalidFieldNameSectionIndex => "invalid-field-name-section-index"
    InvalidElemNameSectionIndex => "invalid-elem-name-section-index"
    InvalidDataNameSectionIndex => "invalid-data-name-section-index"
    InvalidExportTableIndex => "invalid-export-table-index"
    InvalidExportGlobalIndex => "invalid-export-global-index"
    InvalidExportMemoryIndex => "invalid-export-memory-index"
    InvalidExportTagIndex => "invalid-export-tag-index"
    InvalidTagNameSectionIndex => "invalid-tag-name-section-index"
    DataCountMismatchTooSmall => "datacount-mismatch-too-small"
    DataCountMismatchTooLarge => "datacount-mismatch-too-large"
    InvalidFuncTypeIndex => "invalid-func-type-index"
    FuncSecWithoutCodeSec => "funcsec-without-codesec"
    MutableGlobalGetInConstInit => "mutable-global-get-in-const-init"
    NonConstantDataOffset => "non-constant-data-offset"
    InvalidImportedFuncTypeIndex => "invalid-imported-func-type-index"
    InvalidImportedTagTypeIndex => "invalid-imported-tag-type-index"
    MutableGlobalGetInTableInit => "mutable-global-get-in-table-init"
    NonConstantElemOffset => "non-constant-elem-offset"
    SharedMemoryWithoutMax => "shared-memory-without-max"
    SharedMemory64WithoutMax => "shared-memory64-without-max"
    InvalidTagTypeIndex => "invalid-tag-type-index"
    InvalidSubtypeSuperIndex => "invalid-subtype-super-index"
    InvalidSubtypeSuperShape => "invalid-subtype-super-shape"
    DescriptorOnFuncType => "descriptor-on-func-type"
    DataCountWithoutDataSec => "datacount-without-data-sec"
  }
}

///|
fn gen_invalid_max_int(left : Int, right : Int) -> Int {
  if left >= right {
    left
  } else {
    right
  }
}

///|
fn gen_invalid_min_int(left : Int, right : Int) -> Int {
  if left <= right {
    left
  } else {
    right
  }
}

///|
pub fn gen_invalid_require_defined_func_gen_valid_config(
  config : GenValidConfig,
) -> GenValidConfig {
  GenValidConfig::{
    ..config,
    max_type_defs: gen_invalid_max_int(config.max_type_defs, 1),
    max_defined_funcs: gen_invalid_max_int(config.max_defined_funcs, 1),
  }
}

///|
pub fn gen_invalid_require_memory_data_gen_valid_config(
  config : GenValidConfig,
) -> GenValidConfig {
  GenValidConfig::{
    ..config,
    max_mems: gen_invalid_max_int(config.max_mems, 1),
    max_datas: gen_invalid_max_int(config.max_datas, 1),
    section_bias: GenValidSectionBias::{
      ..config.section_bias,
      mems_percent: 100,
      datas_percent: 100,
    },
    features: GenValidFeatureToggles::{
      ..config.features,
      allow_mems: true,
      allow_datas: true,
    },
  }
}

///|
pub fn gen_invalid_small_gen_valid_config(
  config : GenValidConfig,
) -> GenValidConfig {
  GenValidConfig::{
    ..config,
    max_type_defs: gen_invalid_min_int(config.max_type_defs, 2),
    max_imports: gen_invalid_min_int(config.max_imports, 1),
    max_defined_funcs: gen_invalid_min_int(config.max_defined_funcs, 2),
    max_tables: gen_invalid_min_int(config.max_tables, 1),
    max_mems: gen_invalid_min_int(config.max_mems, 1),
    max_globals: gen_invalid_min_int(config.max_globals, 1),
    max_tags: gen_invalid_min_int(config.max_tags, 1),
    max_elems: gen_invalid_min_int(config.max_elems, 1),
    max_datas: gen_invalid_min_int(config.max_datas, 1),
    max_params: gen_invalid_min_int(config.max_params, 1),
    max_results: gen_invalid_min_int(config.max_results, 1),
    max_locals: gen_invalid_min_int(config.max_locals, 1),
    max_body_statements: gen_invalid_min_int(config.max_body_statements, 3),
    max_body_depth: gen_invalid_min_int(config.max_body_depth, 1),
  }
}

///|
fn gen_invalid_apply_seed_prerequisite(
  config : GenValidConfig,
  prerequisite : ValidateInvalidAstSeedPrerequisite,
) -> GenValidConfig {
  match prerequisite {
    RequiresDefinedFunc =>
      gen_invalid_require_defined_func_gen_valid_config(config)
    RequiresMemoryData =>
      gen_invalid_require_memory_data_gen_valid_config(config)
  }
}

///|
pub fn gen_invalid_ast_strategy_seed_prerequisites(
  strategy : ValidateInvalidAstStrategyId,
) -> Array[ValidateInvalidAstSeedPrerequisite] {
  match validate_invalid_ast_strategy_spec_by_id(strategy) {
    Some(spec) => spec.seed_prerequisites
    None => []
  }
}

///|
pub fn gen_invalid_ast_seed_config(
  params : GenInvalidAstParams,
) -> GenValidConfig {
  if !params.require_strategy_prereqs {
    return params.generator_config
  }
  let mut config = params.generator_config
  for
    prerequisite in gen_invalid_ast_strategy_seed_prerequisites(params.strategy) {
    config = gen_invalid_apply_seed_prerequisite(config, prerequisite)
  }
  config
}

///|
fn gen_invalid_ast_minimal_seed_module(
  strategy : ValidateInvalidAstStrategyId,
) -> Module {
  ignore(strategy)
  let (base, _) = validate_invalid_ast_ensure_any_func(Module::new())
  base
}

///|
pub fn gen_invalid_ast_seed_module(
  rnd : RandomState,
  params : GenInvalidAstParams,
) -> Result[Module, String] {
  let base = match params.seed_mode {
    RandomValidSeed => {
      let seeded_config = gen_invalid_ast_seed_config(params)
      gen_valid_module_with_config(rnd, seeded_config)
    }
    MinimalValidSeed => gen_invalid_ast_minimal_seed_module(params.strategy)
  }
  match validate_module(base) {
    Ok(_) => Ok(base)
    Err(err) =>
      Err(
        "gen-invalid base generation failed before mutation: strategy=\{gen_invalid_ast_strategy_label(params.strategy)} error=\{validation_error_message(err)}",
      )
  }
}

///|
pub fn gen_invalid_ast_generate(
  rnd : RandomState,
  params : GenInvalidAstParams,
) -> Result[GenInvalidAstGenerated, String] {
  let base = match gen_invalid_ast_seed_module(rnd, params) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let mutation = match
    apply_validate_invalid_ast_strategy(params.strategy, base) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  if !mutation.applicable {
    return Err(
      "gen-invalid mutation was not applicable after valid seed generation: strategy=\{gen_invalid_ast_strategy_label(params.strategy)}",
    )
  }
  Ok({ base_module: base, mutation })
}
