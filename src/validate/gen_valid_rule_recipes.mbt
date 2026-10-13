///|
pub struct GenValidRuleRecipeMetadata {
  recipe_id : String
  pass_name : String
  variant : String
  relation_id : String
  structure_id : String
  result_types : Array[String]
  operand_relations : Array[String]
  required_facts : Array[String]
  legal_contexts : Array[String]
  prohibited_effects : Array[String]
  feature_requirements : Array[String]
} derive(Eq, Debug)

///|
fn gen_valid_rule_recipe_profile_config(
  profile : GenValidProfile,
) -> GenValidConfig {
  let base = GenValidConfig::natural_default()
  let profile_tag = match profile {
    RuleRecipeOiI32AddZeroPositiveProfile => 601
    RuleRecipeOiI32AddZeroNearMissProfile => 602
    RuleRecipeDae2UnusedTypedIfArgumentPositiveProfile => 605
    RuleRecipeDae2UnusedTypedIfArgumentNearMissProfile => 606
    _ => 601
  }
  GenValidConfig::{
    ..base,
    max_type_defs: if profile ==
      RuleRecipeDae2UnusedTypedIfArgumentPositiveProfile ||
      profile == RuleRecipeDae2UnusedTypedIfArgumentNearMissProfile {
      2
    } else {
      1
    },
    max_imports: 0,
    max_defined_funcs: if profile ==
      RuleRecipeDae2UnusedTypedIfArgumentPositiveProfile ||
      profile == RuleRecipeDae2UnusedTypedIfArgumentNearMissProfile {
      2
    } else {
      1
    },
    max_tables: 0,
    max_mems: 0,
    max_globals: 0,
    max_tags: 0,
    max_elems: 0,
    max_datas: 0,
    max_params: 1,
    max_results: 1,
    max_locals: 1,
    max_body_statements: profile_tag,
    max_body_depth: 1,
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_imports: false,
      allow_tables: false,
      allow_mems: false,
      allow_globals: false,
      allow_tags: false,
      allow_start: false,
      allow_elems: false,
      allow_datas: false,
      allow_ref_types: false,
      allow_v128: false,
      allow_relaxed_simd: false,
      allow_calls: profile == RuleRecipeDae2UnusedTypedIfArgumentPositiveProfile ||
      profile == RuleRecipeDae2UnusedTypedIfArgumentNearMissProfile,
      allow_call_indirect: false,
      allow_tail_calls: false,
      allow_branch_heavy_control: profile ==
      RuleRecipeDae2UnusedTypedIfArgumentPositiveProfile ||
      profile == RuleRecipeDae2UnusedTypedIfArgumentNearMissProfile,
      allow_memory_limit_variants: false,
      allow_table_limit_variants: false,
      allow_const_expr_variants: false,
      allow_shared_memories: false,
      allow_memory64: false,
      allow_atomics: false,
      allow_subtyping_topology: false,
      allow_name_custom_sections: false,
      allow_typed_body_generator: false,
      allow_ssa_nomerge_body_generator: false,
      allow_heap_store_optimization_body_generator: false,
      allow_heap2local_body_generator: false,
    },
  }
}

///|
fn gen_valid_is_rule_recipe_profile_config(config : GenValidConfig) -> Bool {
  config == GenValidConfig::for_profile(RuleRecipeOiI32AddZeroPositiveProfile) ||
  config == GenValidConfig::for_profile(RuleRecipeOiI32AddZeroNearMissProfile) ||
  config ==
  GenValidConfig::for_profile(
    RuleRecipeDae2UnusedTypedIfArgumentPositiveProfile,
  ) ||
  config ==
  GenValidConfig::for_profile(
    RuleRecipeDae2UnusedTypedIfArgumentNearMissProfile,
  )
}

///|
fn gen_valid_rule_recipe_profile_for_config(
  config : GenValidConfig,
) -> GenValidProfile {
  for
    profile in [
      RuleRecipeOiI32AddZeroPositiveProfile,
      RuleRecipeOiI32AddZeroNearMissProfile,
      RuleRecipeDae2UnusedTypedIfArgumentPositiveProfile,
      RuleRecipeDae2UnusedTypedIfArgumentNearMissProfile,
    ] {
    if config == GenValidConfig::for_profile(profile) {
      return profile
    }
  }
  RuleRecipeOiI32AddZeroPositiveProfile
}

///|
fn gen_valid_rule_recipe_is_near_miss(profile : GenValidProfile) -> Bool {
  profile == RuleRecipeOiI32AddZeroNearMissProfile ||
  profile == RuleRecipeDae2UnusedTypedIfArgumentNearMissProfile
}

///|
pub fn gen_valid_rule_recipe_metadata(
  profile : GenValidProfile,
  seed : UInt64,
) -> GenValidRuleRecipeMetadata? {
  let variant = if gen_valid_rule_recipe_is_near_miss(profile) {
    "near-miss"
  } else {
    "positive"
  }
  let feature_requirements = ["core"]
  match profile {
    RuleRecipeOiI32AddZeroPositiveProfile
    | RuleRecipeOiI32AddZeroNearMissProfile =>
      Some({
        recipe_id: "oi.i32-add-zero",
        pass_name: "optimize-instructions",
        variant,
        relation_id: "rule-recipe:oi.i32-add-zero:\{seed}",
        structure_id: "oi.i32-add-zero.shape-\{seed % 32UL}",
        result_types: ["i32"],
        operand_relations: if variant == "positive" {
          ["rhs == i32.const 0"]
        } else {
          ["rhs == i32.const 1"]
        },
        required_facts: ["lhs has type i32", "addition result is consumed"],
        legal_contexts: ["function result expression"],
        prohibited_effects: ["rhs has no side effects", "rhs cannot trap"],
        feature_requirements,
      })
    RuleRecipeDae2UnusedTypedIfArgumentPositiveProfile
    | RuleRecipeDae2UnusedTypedIfArgumentNearMissProfile =>
      Some({
        recipe_id: "dae2.unused-typed-if-argument",
        pass_name: "dae2",
        variant,
        relation_id: "rule-recipe:dae2.unused-typed-if-argument:\{seed}",
        structure_id: "dae2.unused-typed-if-argument.shape-\{seed % 32UL}",
        result_types: ["i32"],
        operand_relations: if variant == "positive" {
          ["callee parameter read count == 0"]
        } else {
          ["callee parameter read count == 1"]
        },
        required_facts: [
          "callee is private", "all calls are direct", "argument is typed if(result i32)",
        ],
        legal_contexts: ["closed-world two-function module"],
        prohibited_effects: ["argument arms have no side effects"],
        feature_requirements,
      })
    _ => None
  }
}

///|
fn gen_valid_rule_recipe_i32_func_type(
  params : Array[ValType],
  results : Array[ValType],
) -> RecType {
  RecType::new(SubType::comp_type(CompType::func(params, results)))
}

///|
fn gen_valid_rule_recipe_oi_module(seed : UInt64, near_miss : Bool) -> Module {
  let shape = (seed % 32UL).to_int()
  let context_width = shape / 4
  let lhs_variant = shape % 4
  let body : Array[Instruction] = []
  for i = 0; i < context_width; i = i + 1 {
    body.push(Instruction::local_get(LocalIdx::new(0U)))
    body.push(Instruction::drop())
  }
  body.push(Instruction::local_get(LocalIdx::new(0U)))
  match lhs_variant {
    1 => {
      body.push(Instruction::i32_const(I32(0)))
      body.push(Instruction::i32_xor())
    }
    2 => {
      body.push(Instruction::i32_const(I32(7)))
      body.push(Instruction::i32_add())
      body.push(Instruction::i32_const(I32(7)))
      body.push(Instruction::i32_sub())
    }
    3 => {
      body.push(Instruction::local_get(LocalIdx::new(0U)))
      body.push(Instruction::i32_const(I32(1)))
      body.push(Instruction::select())
    }
    _ => ()
  }
  body.push(Instruction::i32_const(I32(if near_miss { 1 } else { 0 })))
  body.push(Instruction::i32_add())
  Module::new()
  .with_type_sec(
    TypeSec::new([
      gen_valid_rule_recipe_i32_func_type([ValType::i32()], [ValType::i32()]),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(0U))),
    ]),
  )
  .with_code_sec(CodeSec::new([Func::new(Locals::empty(), Expr::new(body))]))
}

///|
fn gen_valid_rule_recipe_dae2_module(seed : UInt64, near_miss : Bool) -> Module {
  let value = 1 + ((seed >> 16) % 1000003UL).to_int()
  let callee_body = if near_miss {
    [Instruction::local_get(LocalIdx::new(0U))]
  } else {
    [Instruction::i32_const(I32(value))]
  }
  let shape = (seed % 32UL).to_int()
  let context_width = shape / 4
  let argument_variant = shape % 4
  let caller_body : Array[Instruction] = []
  for i = 0; i < context_width; i = i + 1 {
    caller_body.push(Instruction::local_get(LocalIdx::new(0U)))
    caller_body.push(Instruction::drop())
  }
  caller_body.push(Instruction::local_get(LocalIdx::new(0U)))
  let then_arm = match argument_variant {
    1 => [Instruction::local_get(LocalIdx::new(0U))]
    2 =>
      [
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::i32_const(I32(1)),
        Instruction::i32_add(),
      ]
    3 =>
      [
        Instruction::i32_const(I32(value + 1)),
        Instruction::i32_const(I32(value + 2)),
        Instruction::local_get(LocalIdx::new(0U)),
        Instruction::select(),
      ]
    _ => [Instruction::i32_const(I32(value + 1))]
  }
  caller_body.push(
    Instruction::if_(
      BlockType::val_type(ValType::i32()),
      then_arm,
      Some([Instruction::i32_const(I32(value + 2))]),
    ),
  )
  caller_body.push(Instruction::call(FuncIdx::new(0U)))
  Module::new()
  .with_type_sec(
    TypeSec::new([
      gen_valid_rule_recipe_i32_func_type([ValType::i32()], [ValType::i32()]),
      gen_valid_rule_recipe_i32_func_type([ValType::i32()], [ValType::i32()]),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0U), TypeIdx::new(1U)]))
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(1U))),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::new(Locals::empty(), Expr::new(callee_body)),
      Func::new(Locals::empty(), Expr::new(caller_body)),
    ]),
  )
}

///|
fn gen_valid_rule_recipe_profile_module(ctx : GenValidContext) -> Module {
  let profile = gen_valid_rule_recipe_profile_for_config(ctx.config)
  match profile {
    RuleRecipeOiI32AddZeroPositiveProfile =>
      gen_valid_rule_recipe_oi_module(ctx.root_seed, false)
    RuleRecipeOiI32AddZeroNearMissProfile =>
      gen_valid_rule_recipe_oi_module(ctx.root_seed, true)
    RuleRecipeDae2UnusedTypedIfArgumentPositiveProfile =>
      gen_valid_rule_recipe_dae2_module(ctx.root_seed, false)
    RuleRecipeDae2UnusedTypedIfArgumentNearMissProfile =>
      gen_valid_rule_recipe_dae2_module(ctx.root_seed, true)
    _ => gen_valid_rule_recipe_oi_module(ctx.root_seed, false)
  }
}
