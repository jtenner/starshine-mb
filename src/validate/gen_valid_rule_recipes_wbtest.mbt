///|
fn gen_valid_rule_recipe_test_profiles() -> Array[GenValidProfile] {
  [
    RuleRecipeOiI32AddZeroPositiveProfile,
    RuleRecipeOiI32AddZeroNearMissProfile,
    RuleRecipeDae2UnusedTypedIfArgumentPositiveProfile,
    RuleRecipeDae2UnusedTypedIfArgumentNearMissProfile,
  ]
}

///|
test "rule recipe profiles register as two balanced positive and near-miss pairs" {
  @debug.assert_eq(
    gen_valid_profile_by_name("rule-recipes"),
    Ok(RuleRecipesAllProfile),
  )
  let members = gen_valid_profile_members(RuleRecipesAllProfile)
  @debug.assert_eq(members.length(), 4)
  for profile in gen_valid_rule_recipe_test_profiles() {
    assert_true(gen_valid_profiles().contains(profile))
    assert_true(
      members.contains(GenValidProfileMember::new(profile, 1)),
      msg="missing balanced rule-recipe member {gen_valid_profile_name(profile)}",
    )
    @debug.assert_eq(
      gen_valid_profile_by_name(gen_valid_profile_name(profile)),
      Ok(profile),
    )
  }
}

///|
test "rule recipe metadata records explicit premises stable pairs and structures" {
  let profiles = gen_valid_rule_recipe_test_profiles()
  for pair = 0; pair < 2; pair = pair + 1 {
    let positive = gen_valid_rule_recipe_metadata(profiles[pair * 2], 0x600dUL).unwrap()
    let near_miss = gen_valid_rule_recipe_metadata(
      profiles[pair * 2 + 1],
      0x600dUL,
    ).unwrap()
    let other_seed = gen_valid_rule_recipe_metadata(
      profiles[pair * 2],
      0x600eUL,
    ).unwrap()
    @debug.assert_eq(positive.recipe_id, near_miss.recipe_id)
    @debug.assert_eq(positive.relation_id, near_miss.relation_id)
    @debug.assert_eq(positive.structure_id, near_miss.structure_id)
    assert_true(positive.relation_id != other_seed.relation_id)
    assert_true(positive.structure_id != other_seed.structure_id)
    @debug.assert_eq(positive.variant, "positive")
    @debug.assert_eq(near_miss.variant, "near-miss")
    assert_true(!positive.operand_relations.is_empty())
    assert_true(!positive.required_facts.is_empty())
    assert_true(!positive.legal_contexts.is_empty())
    assert_true(!positive.prohibited_effects.is_empty())
    @debug.assert_eq(positive.feature_requirements, ["core"])
  }
}

///|
test "rule recipe generation is deterministic valid and has 32 structures per variant" {
  for profile in gen_valid_rule_recipe_test_profiles() {
    let structures : Array[String] = []
    for index = 1; index <= 32; index = index + 1 {
      let seed = gen_valid_case_seed(0x600dUL, index)
      let config = GenValidConfig::for_profile(profile)
      let first = gen_valid_module_result_from_seed(seed, config).unwrap()
      let second = gen_valid_module_result_from_seed(seed, config).unwrap()
      validate_module(first.wasm_module).unwrap()
      @debug.assert_eq(
        @binary.encode_module(first.wasm_module).unwrap(),
        @binary.encode_module(second.wasm_module).unwrap(),
      )
      let structure = gen_valid_rule_recipe_metadata(profile, seed).unwrap().structure_id
      assert_true(!structures.contains(structure), msg="duplicate {structure}")
      structures.push(structure)
    }
    @debug.assert_eq(structures.length(), 32)
  }
}

///|
test "rule recipe pairs differ by exactly one protected premise" {
  let seed = 0x600dUL
  let oi_positive = gen_valid_module_result_from_seed(
      seed,
      GenValidConfig::for_profile(RuleRecipeOiI32AddZeroPositiveProfile),
    ).unwrap().wasm_module
  let oi_near_miss = gen_valid_module_result_from_seed(
      seed,
      GenValidConfig::for_profile(RuleRecipeOiI32AddZeroNearMissProfile),
    ).unwrap().wasm_module
  let Func(_, Expr(oi_positive_body)) = oi_positive.code_sec.unwrap().0[0]
  let Func(_, Expr(oi_near_miss_body)) = oi_near_miss.code_sec.unwrap().0[0]
  @debug.assert_eq(oi_positive_body.length(), oi_near_miss_body.length())
  for i = 0; i < oi_positive_body.length() - 2; i = i + 1 {
    @debug.assert_eq(oi_positive_body[i], oi_near_miss_body[i])
  }
  assert_true(
    oi_positive_body[oi_positive_body.length() - 2] is I32Const(I32(0)),
  )
  assert_true(
    oi_near_miss_body[oi_near_miss_body.length() - 2] is I32Const(I32(1)),
  )
  assert_true(oi_positive_body[oi_positive_body.length() - 1] is I32Add)
  assert_true(oi_near_miss_body[oi_near_miss_body.length() - 1] is I32Add)

  let dae_positive = gen_valid_module_result_from_seed(
      seed,
      GenValidConfig::for_profile(
        RuleRecipeDae2UnusedTypedIfArgumentPositiveProfile,
      ),
    ).unwrap().wasm_module
  let dae_near_miss = gen_valid_module_result_from_seed(
      seed,
      GenValidConfig::for_profile(
        RuleRecipeDae2UnusedTypedIfArgumentNearMissProfile,
      ),
    ).unwrap().wasm_module
  let Func(_, Expr(dae_positive_callee)) = dae_positive.code_sec.unwrap().0[0]
  let Func(_, Expr(dae_near_miss_callee)) = dae_near_miss.code_sec.unwrap().0[0]
  let Func(_, Expr(dae_positive_caller)) = dae_positive.code_sec.unwrap().0[1]
  let Func(_, Expr(dae_near_miss_caller)) = dae_near_miss.code_sec.unwrap().0[1]
  assert_true(dae_positive_callee[0] is I32Const(_))
  assert_true(dae_near_miss_callee[0] is LocalGet(LocalIdx(0U)))
  @debug.assert_eq(dae_positive_caller, dae_near_miss_caller)
}
