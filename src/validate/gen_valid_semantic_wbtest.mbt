///|
test "semantic optimizer GenValid profiles resolve dedicated leaves and aggregate" {
  let expected = [
    (SemanticEffectsProfile, "semantic-effects"),
    (SemanticImportEventsProfile, "semantic-import-events"),
    (SemanticTrapFrontierProfile, "semantic-trap-frontier"),
    (SemanticResourcesProfile, "semantic-resources"),
  ]
  for item in expected {
    let (profile, name) = item
    @debug.assert_eq(gen_valid_profile_name(profile), name)
    match gen_valid_profile_by_name(name) {
      Ok(resolved) => @debug.assert_eq(resolved, profile)
      Err(msg) => fail(msg)
    }
  }
  @debug.assert_eq(
    gen_valid_profile_name(SemanticOptimizerAllProfile),
    "semantic-optimizer-all",
  )
  assert_true(gen_valid_profile_is_composite(SemanticOptimizerAllProfile))
  let members = gen_valid_profile_members(SemanticOptimizerAllProfile)
  for item in expected {
    let (profile, _) = item
    assert_true(
      members.any(fn(entry) { entry.profile == profile && entry.weight > 0 }),
    )
  }
}

///|
test "semantic optimizer profiles emit stable event trap and resource facts" {
  let cases = [
    (SemanticEffectsProfile, 0x5101UL),
    (SemanticImportEventsProfile, 0x5102UL),
    (SemanticTrapFrontierProfile, 0x5103UL),
    (SemanticResourcesProfile, 0x5104UL),
  ]
  for item in cases {
    let (profile, seed) = item
    let generated = match
      gen_valid_module_result_from_seed(
        seed,
        GenValidConfig::for_profile(profile),
      ) {
      Ok(value) => value
      Err(failure) => fail(failure.validation_error_message)
    }
    match profile {
      SemanticEffectsProfile =>
        assert_true(generated.facts.has_semantic_effects)
      SemanticImportEventsProfile =>
        assert_true(generated.facts.has_import_event_channel)
      SemanticTrapFrontierProfile =>
        assert_true(generated.facts.has_trap_frontier)
      SemanticResourcesProfile =>
        assert_true(generated.facts.has_resource_observation)
      _ => fail("unexpected semantic profile")
    }
  }
}

///|
test "semantic optimizer feature floors resolve by stable labels" {
  for
    label in [
      "semantic_effects", "import_event_channel", "trap_frontier", "resource_observation",
      "poisoned_dead_code",
    ] {
    match validate_valid_feature_floor_by_label(label, 1) {
      Ok(floor) => @debug.assert_eq(floor.min_count, 1)
      Err(msg) => fail(msg)
    }
  }
}
