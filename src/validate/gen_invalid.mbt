///|
pub enum GenInvalidSeedMode {
  RandomValidSeed
  MinimalValidSeed
} derive(Eq, Debug)

///|
pub struct GenInvalidAstParams {
  strategy : ValidateInvalidAstStrategyId
  seed_mode : GenInvalidSeedMode
  generator_config : GenValidConfig
  require_strategy_prereqs : Bool
} derive(Eq, Debug)

///|
pub fn GenInvalidAstParams::new(
  strategy : ValidateInvalidAstStrategyId,
  seed_mode? : GenInvalidSeedMode = RandomValidSeed,
  generator_config? : GenValidConfig = GenValidConfig::coverage_forced_default(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidAstParams {
  { strategy, seed_mode, generator_config, require_strategy_prereqs }
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
    generator_config,
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidAstParams::coverage_forced_seed(
  strategy : ValidateInvalidAstStrategyId,
  generator_config? : GenValidConfig = GenValidConfig::coverage_forced_default(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidAstParams {
  {
    strategy,
    seed_mode: RandomValidSeed,
    generator_config,
    require_strategy_prereqs,
  }
}

///|
pub fn GenInvalidAstParams::minimal_seed(
  strategy : ValidateInvalidAstStrategyId,
  generator_config? : GenValidConfig = GenValidConfig::coverage_forced_default(),
  require_strategy_prereqs? : Bool = true,
) -> GenInvalidAstParams {
  {
    strategy,
    seed_mode: MinimalValidSeed,
    generator_config,
    require_strategy_prereqs,
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
    InvalidStartSignature => "invalid-start-signature"
    MissingDataCount => "missing-datacount"
    UndeclaredRefFunc => "undeclared-ref-func"
    InvalidNameSectionFuncIndex => "invalid-name-section-func-index"
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
pub fn gen_invalid_ast_seed_config(
  params : GenInvalidAstParams,
) -> GenValidConfig {
  if !params.require_strategy_prereqs {
    return params.generator_config
  }
  let config = params.generator_config
  match params.strategy {
    MissingDataCount =>
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
    _ => config
  }
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
