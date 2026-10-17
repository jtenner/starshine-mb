///|
test "heap-store-optimization aliases resolve to the transform-family aggregate" {
  @debug.assert_eq(
    gen_valid_profile_name(HeapStoreOptimizationProfile),
    "heap-store-optimization",
  )
  assert_true(gen_valid_profiles().contains(HeapStoreOptimizationProfile))
  assert_true(gen_valid_profile_names().contains("heap-store-optimization"))

  for
    name in [
      "hso", "heap-store-optimization-closeout", "heap-store-optimization-all", "heap-store-optimization-all-profiles",
    ] {
    match gen_valid_profile_by_name(name) {
      Ok(profile) => {
        @debug.assert_eq(profile, HeapStoreOptimizationProfile)
        assert_true(gen_valid_profile_is_composite(profile))
      }
      Err(msg) => fail(msg)
    }
  }
}

///|
test "heap-store-optimization aggregate samples every maintained transform family" {
  let expected = [
    HsoTeeProfile,
    HsoChainProfile,
    HsoDefaultProfile,
    HsoSideEffectsProfile,
    HsoDescriptorProfile,
    HsoControlFlowProfile,
    HsoSwapProfile,
    HsoSharedOrderingProfile,
    HsoBoundariesProfile,
  ]
  let members = gen_valid_profile_members(HeapStoreOptimizationProfile)
  @debug.assert_eq(members.length(), expected.length())
  for expected_profile in expected {
    assert_true(
      members.contains(GenValidProfileMember::new(expected_profile, 1)),
      msg="missing HSO aggregate member \{gen_valid_profile_name(expected_profile)}",
    )
  }

  let seen : Array[GenValidProfile] = []
  for index = 1; index <= 512; index = index + 1 {
    let leaf = gen_valid_profile_leaf_for_case(
      HeapStoreOptimizationProfile,
      0x5eedUL,
      index,
    )
    assert_false(gen_valid_profile_is_composite(leaf))
    if !seen.contains(leaf) {
      seen.push(leaf)
    }
  }
  for expected_profile in expected {
    assert_true(
      seen.contains(expected_profile),
      msg="missing sampled HSO leaf \{gen_valid_profile_name(expected_profile)}",
    )
  }
}

///|
test "heap-store-optimization transform-family profiles expose stable labels" {
  let expected = [
    (HsoTeeProfile, "heap-store-optimization-tee", "hso:tee"),
    (HsoChainProfile, "heap-store-optimization-chains", "hso:chains"),
    (HsoDefaultProfile, "heap-store-optimization-defaults", "hso:defaults"),
    (
      HsoSideEffectsProfile,
      "heap-store-optimization-side-effects",
      "hso:side-effects",
    ),
    (
      HsoDescriptorProfile,
      "heap-store-optimization-descriptors",
      "hso:descriptors",
    ),
    (
      HsoControlFlowProfile,
      "heap-store-optimization-control-flow",
      "hso:control-flow",
    ),
    (HsoSwapProfile, "heap-store-optimization-swaps", "hso:swaps"),
    (
      HsoSharedOrderingProfile,
      "heap-store-optimization-shared-ordering",
      "hso:shared-ordering",
    ),
    (
      HsoBoundariesProfile,
      "heap-store-optimization-boundaries",
      "hso:boundaries",
    ),
  ]
  for row in expected {
    let (profile, name, label) = row
    @debug.assert_eq(gen_valid_profile_name(profile), name)
    match gen_valid_profile_by_name(name) {
      Ok(parsed) => @debug.assert_eq(parsed, profile)
      Err(msg) => fail(msg)
    }
    @debug.assert_eq(
      gen_valid_heap_store_optimization_profile_case_label(profile),
      Some(label),
    )
  }
}

///|
test "heap-store-optimization closeout leaves generate valid dedicated fixtures" {
  let leaves = [
    HsoTeeProfile,
    HsoChainProfile,
    HsoDefaultProfile,
    HsoSideEffectsProfile,
    HsoDescriptorProfile,
    HsoControlFlowProfile,
    HsoSwapProfile,
    HsoSharedOrderingProfile,
    HsoBoundariesProfile,
  ]
  for idx, profile in leaves {
    let generated = match
      gen_valid_module_result_from_seed(
        0x48534F00UL + idx.to_uint64(),
        GenValidConfig::for_profile(profile),
      ) {
      Ok(value) => value
      Err(failure) =>
        fail(
          "expected dedicated HSO profile \{gen_valid_profile_name(profile)} to generate: \{failure.validation_error_message}",
        )
    }
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) =>
        fail(
          "expected dedicated HSO profile \{gen_valid_profile_name(profile)} to validate: \{err}",
        )
    }
  }
}

///|
fn hso_test_module_has_descriptor_metadata(mod_ : Module) -> Bool {
  match mod_.type_sec {
    Some(TypeSec(types)) =>
      for rec_type in types {
        let group = match rec_type {
          SingleRecType(subtype) => [subtype]
          GroupRecType(subtypes) => subtypes
        }
        for subtype in group {
          let metadata = match subtype {
            SubType(_, _, metadata, _) | CompTypeSubType(metadata, _) =>
              metadata
          }
          if metadata.descriptor is Some(_) || metadata.describes is Some(_) {
            return true
          }
        }
      }
    None => ()
  }
  false
}

///|
test "heap-store-optimization keeps descriptors in the descriptor leaf only" {
  let ordinary_leaves = [
    HsoTeeProfile,
    HsoChainProfile,
    HsoDefaultProfile,
    HsoSideEffectsProfile,
    HsoControlFlowProfile,
    HsoSwapProfile,
    HsoSharedOrderingProfile,
    HsoBoundariesProfile,
  ]
  for idx, profile in ordinary_leaves {
    let generated = match
      gen_valid_module_result_from_seed(
        0x48534F80UL + idx.to_uint64(),
        GenValidConfig::for_profile(profile),
      ) {
      Ok(value) => value
      Err(failure) => fail(failure.validation_error_message)
    }
    assert_false(
      hso_test_module_has_descriptor_metadata(generated.wasm_module),
      msg="ordinary HSO leaf unexpectedly requires descriptor runtime support: \{gen_valid_profile_name(profile)}",
    )
  }

  let descriptor = match
    gen_valid_module_result_from_seed(
      0x48534FFFUL,
      GenValidConfig::for_profile(HsoDescriptorProfile),
    ) {
    Ok(value) => value
    Err(failure) => fail(failure.validation_error_message)
  }
  assert_true(hso_test_module_has_descriptor_metadata(descriptor.wasm_module))
}

///|
test "heap-store-optimization leaves omit unrelated active segments" {
  let leaves = [
    HsoTeeProfile,
    HsoChainProfile,
    HsoDefaultProfile,
    HsoSideEffectsProfile,
    HsoDescriptorProfile,
    HsoControlFlowProfile,
    HsoSwapProfile,
    HsoSharedOrderingProfile,
    HsoBoundariesProfile,
  ]
  for idx, profile in leaves {
    let generated = match
      gen_valid_module_result_from_seed(
        0x48535080UL + idx.to_uint64(),
        GenValidConfig::for_profile(profile),
      ) {
      Ok(value) => value
      Err(failure) => fail(failure.validation_error_message)
    }
    assert_eq(generated.wasm_module.elem_sec, None)
    assert_eq(generated.wasm_module.data_sec, None)
  }
}
