///|
test "engine campaign profiles are registered composites" {
  let profiles = [
    ("engine-compile-shapes", EngineCompileShapesProfile),
    ("engine-proposal-matrix", EngineProposalMatrixProfile),
    ("engine-state-core", EngineStateCoreProfile),
    ("engine-tiering-stress", EngineTieringStressProfile),
  ]
  for (name, profile) in profiles {
    match gen_valid_profile_by_name(name) {
      Ok(found) => assert_true(found == profile)
      Err(message) => fail(message)
    }
    inspect(gen_valid_profile_name(profile), content=name)
    inspect(gen_valid_profile_is_composite(profile), content="true")
    assert_true(!gen_valid_profile_members(profile).is_empty())
  }
}

///|
test "engine aggregates do not shadow representative leaf config labels" {
  inspect(
    gen_valid_config_label(GenValidConfig::for_profile(FlattenBlocksProfile)),
    content="flatten-blocks",
  )
  inspect(
    gen_valid_config_label(
      GenValidConfig::for_profile(CampaignSimdNumericProfile),
    ),
    content="campaign-simd-numeric",
  )
}

///|
test "engine compile shapes spans the intended structural families" {
  let members = gen_valid_profile_members(EngineCompileShapesProfile)
  let member_profiles = members.map(fn(entry) { entry.profile })
  assert_true(member_profiles.contains(FlattenBlocksProfile))
  assert_true(member_profiles.contains(Dae2CyclesProfile))
  assert_true(member_profiles.contains(SsaNestedValueProfile))
  assert_true(member_profiles.contains(MemoryPackingPassiveSplitsProfile))
  assert_true(member_profiles.contains(ReorderGlobalsDependencySearchProfile))
  assert_true(member_profiles.contains(EngineStateDecoderTopologyProfile))
}

///|
test "engine proposal matrix covers single proposals and interactions" {
  let members = gen_valid_profile_members(EngineProposalMatrixProfile)
  let member_profiles = members.map(fn(entry) { entry.profile })
  assert_true(member_profiles.contains(CampaignSimdNumericProfile))
  assert_true(member_profiles.contains(CampaignGcRefSubtypesProfile))
  assert_true(member_profiles.contains(CampaignEhControlProfile))
  assert_true(member_profiles.contains(CampaignMemory64MultiMemoryProfile))
  assert_true(member_profiles.contains(EngineStateTypeCallMatrixProfile))
  assert_true(member_profiles.contains(EngineStateExceptionUnwindProfile))
  assert_true(member_profiles.contains(EngineStateMemory64MultiMemoryProfile))
}

///|
test "engine state core excludes expected failures and support graphs" {
  let members = gen_valid_profile_members(EngineStateCoreProfile)
  let member_profiles = members.map(fn(entry) { entry.profile })
  assert_true(member_profiles.contains(EngineStateScalarControlProfile))
  assert_true(member_profiles.contains(EngineStateCallsProfile))
  assert_true(member_profiles.contains(EngineStateMemoryProfile))
  assert_true(member_profiles.contains(EngineStateTableProfile))
  assert_true(member_profiles.contains(EngineStateCompilerBoundariesProfile))
  assert_false(member_profiles.contains(EngineStateTrapProfile))
  assert_false(member_profiles.contains(EngineStateInvalidModuleProfile))
  assert_false(
    member_profiles.contains(EngineStateInstantiationBoundariesProfile),
  )
  assert_false(member_profiles.contains(EngineStateLinkGraphProfile))
  assert_false(member_profiles.contains(EngineStateMetamorphicTwinsProfile))
}

///|
test "engine tiering stress cycles through focused runtime shapes" {
  let members = gen_valid_profile_members(EngineTieringStressProfile)
  let member_profiles = members.map(fn(entry) { entry.profile })
  inspect(member_profiles.length(), content="8")
  assert_true(member_profiles.contains(EngineTieringLoopProfile))
  assert_true(member_profiles.contains(EngineTieringLargeFunctionProfile))
  assert_true(member_profiles.contains(EngineTieringCallChainProfile))
  assert_true(member_profiles.contains(EngineTieringCallFanoutProfile))
  assert_true(member_profiles.contains(EngineTieringIndirectProfile))
  assert_true(member_profiles.contains(EngineTieringLocalsStackProfile))
  assert_true(member_profiles.contains(EngineTieringMemoryProfile))
  assert_true(member_profiles.contains(EngineTieringGcProfile))
}

///|
test "engine composites use exact weighted cycles" {
  for
    profile in [
      EngineCompileShapesProfile,
      EngineProposalMatrixProfile,
      EngineStateCoreProfile,
      EngineTieringStressProfile,
    ] {
    let members = gen_valid_profile_members(profile)
    let cycle_length = members.fold(init=0, fn(total, entry) {
      total + entry.weight
    })
    for entry in members {
      let mut count = 0
      for case_index = 1
          case_index <= cycle_length
          case_index = case_index + 1 {
        let selected = gen_valid_profile_leaf_for_case(
          profile, 0x5eedUL, case_index,
        )
        if selected == entry.profile {
          count += 1
        }
      }
      inspect(count, content=entry.weight.to_string())
    }
  }
}

///|
test "engine tiering leaves generate valid deterministic modules" {
  let profiles = [
    EngineTieringLoopProfile,
    EngineTieringLargeFunctionProfile,
    EngineTieringCallChainProfile,
    EngineTieringCallFanoutProfile,
    EngineTieringIndirectProfile,
    EngineTieringLocalsStackProfile,
    EngineTieringMemoryProfile,
    EngineTieringGcProfile,
  ]
  for profile in profiles {
    let config = GenValidConfig::for_profile(profile)
    for seed in [0UL, 1UL, 2UL, 3UL, 7UL] {
      let first = gen_valid_module_result_from_seed(seed, config).unwrap()
      let second = gen_valid_module_result_from_seed(seed, config).unwrap()
      match validate_module(first.wasm_module) {
        Ok(_) => ()
        Err(message) => fail(message.to_string())
      }
      inspect(first.wasm_module == second.wasm_module, content="true")
    }
  }
}

///|
test "engine tiering call graphs scale across seed buckets" {
  let chain_config = GenValidConfig::for_profile(EngineTieringCallChainProfile)
  let fanout_config = GenValidConfig::for_profile(
    EngineTieringCallFanoutProfile,
  )
  let small_chain = gen_valid_module_result_from_seed(0UL, chain_config).unwrap()
  let large_chain = gen_valid_module_result_from_seed(3UL, chain_config).unwrap()
  let small_fanout = gen_valid_module_result_from_seed(0UL, fanout_config).unwrap()
  let large_fanout = gen_valid_module_result_from_seed(12UL, fanout_config).unwrap()
  assert_true(
    large_chain.wasm_module.code_sec.unwrap().0.length() >
    small_chain.wasm_module.code_sec.unwrap().0.length(),
  )
  assert_true(
    large_fanout.wasm_module.code_sec.unwrap().0.length() >
    small_fanout.wasm_module.code_sec.unwrap().0.length(),
  )
}

///|
test "engine tiering case labels record scale and dispatch mode" {
  inspect(
    gen_valid_engine_tiering_profile_case_label(EngineTieringLoopProfile, 2UL),
    content="Some(tiering:loop:trip-count=4096)",
  )
  inspect(
    gen_valid_engine_tiering_profile_case_label(
      EngineTieringCallChainProfile,
      3UL,
    ),
    content="Some(tiering:call-chain:depth=64)",
  )
  inspect(
    gen_valid_engine_tiering_profile_case_label(
      EngineTieringIndirectProfile,
      16UL,
    ),
    content="Some(tiering:indirect:polymorphic:trip-count=256)",
  )
}
