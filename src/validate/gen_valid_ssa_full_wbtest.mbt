///|
priv struct SsaFullProfileCase {
  profile : GenValidProfile
  name : String
  label : String
}

///|
fn gen_valid_ssa_full_test_profiles() -> Array[SsaFullProfileCase] {
  [
    {
      profile: SsaFreshSetProfile,
      name: "ssa-fresh-set",
      label: "ssa:fresh-set-and-retarget",
    },
    {
      profile: SsaFreshTeeProfile,
      name: "ssa-fresh-tee",
      label: "ssa:fresh-tee-and-retarget",
    },
    {
      profile: SsaParamEntryProfile,
      name: "ssa-param-entry",
      label: "ssa:single-param-entry",
    },
    {
      profile: SsaDefaultNumericProfile,
      name: "ssa-default-numeric",
      label: "ssa:single-default-numeric",
    },
    {
      profile: SsaDefaultRefProfile,
      name: "ssa-default-ref",
      label: "ssa:single-default-ref-refinalize",
    },
    {
      profile: SsaUnreachableProfile,
      name: "ssa-unreachable",
      label: "ssa:unreachable-get-noop",
    },
    {
      profile: SsaMergeExplicitProfile,
      name: "ssa-merge-explicit",
      label: "ssa:merge-explicit-writes",
    },
    {
      profile: SsaMergeParamEntryProfile,
      name: "ssa-merge-param-entry",
      label: "ssa:merge-param-entry-prepend",
    },
    {
      profile: SsaMergeDefaultEntryProfile,
      name: "ssa-merge-default-entry",
      label: "ssa:merge-default-entry-no-prepend",
    },
    {
      profile: SsaMergeSharedSetsProfile,
      name: "ssa-merge-shared-sets",
      label: "ssa:merge-shared-sets-nested-tees",
    },
    {
      profile: SsaLoopProfile,
      name: "ssa-loop",
      label: "ssa:loop-backedge-merge",
    },
    {
      profile: SsaBranchProfile,
      name: "ssa-branch",
      label: "ssa:branch-target-merges",
    },
    {
      profile: SsaTypedControlProfile,
      name: "ssa-typed-control",
      label: "ssa:typed-control-local-flow",
    },
    {
      profile: SsaNestedValueProfile,
      name: "ssa-nested-value",
      label: "ssa:nested-value-block-local-flow",
    },
    {
      profile: SsaEhProfile,
      name: "ssa-eh",
      label: "ssa:exceptional-local-flow",
    },
  ]
}

///|
test "full ssa gen-valid profiles resolve every transformation family" {
  for item in gen_valid_ssa_full_test_profiles() {
    @debug.assert_eq(gen_valid_profile_name(item.profile), item.name)
    match gen_valid_profile_by_name(item.name) {
      Ok(resolved) => @debug.assert_eq(resolved, item.profile)
      Err(msg) => fail(msg)
    }
    @debug.assert_eq(
      gen_valid_ssa_full_profile_case_label(item.profile),
      Some(item.label),
    )
    let config = GenValidConfig::for_profile(item.profile)
    assert_true(config.features.allow_ssa_nomerge_body_generator, msg=item.name)
  }
  match gen_valid_profile_by_name("ssa") {
    Ok(profile) => @debug.assert_eq(profile, SsaAllProfile)
    Err(msg) => fail(msg)
  }
  match gen_valid_profile_by_name("ssa-closeout") {
    Ok(profile) => @debug.assert_eq(profile, SsaAllProfile)
    Err(msg) => fail(msg)
  }
}

///|
test "full ssa aggregate deterministically samples every singleton profile" {
  assert_true(gen_valid_profile_is_composite(SsaAllProfile))
  let members = gen_valid_profile_members(SsaAllProfile)
  @debug.assert_eq(
    members.length(),
    gen_valid_ssa_full_test_profiles().length(),
  )
  for item in gen_valid_ssa_full_test_profiles() {
    assert_true(
      members.any(fn(entry) { entry.profile == item.profile }),
      msg=gen_valid_profile_name(item.profile),
    )
  }
  let seen : Array[GenValidProfile] = []
  let mut index = 1
  while index <= 512 {
    let profile = gen_valid_profile_leaf_for_case(
      SsaAllProfile,
      0x5eedUL,
      index,
    )
    if !seen.contains(profile) {
      seen.push(profile)
    }
    index += 1
  }
  for item in gen_valid_ssa_full_test_profiles() {
    assert_true(
      seen.contains(item.profile),
      msg=gen_valid_profile_name(item.profile),
    )
  }
}

///|
test "full ssa singleton profiles generate their promised source families" {
  for item in gen_valid_ssa_full_test_profiles() {
    let generated = match
      gen_valid_module_result_from_seed(
        0x5eedUL,
        GenValidConfig::for_profile(item.profile),
      ) {
      Ok(value) => value
      Err(failure) => fail("\{item.name}: \{failure.validation_error_message}")
    }
    @debug.assert_eq(generated.config_label, item.name)
    let facts = generated.facts
    match item.profile {
      SsaFreshSetProfile => {
        assert_true(facts.has_ssa_multi_def_same_local)
        assert_true(facts.has_ssa_straight_line_local_chain)
      }
      SsaFreshTeeProfile => {
        assert_true(facts.has_ssa_local_tee_def_use)
        assert_true(facts.has_ssa_tee_freshen_candidate)
      }
      SsaParamEntryProfile => assert_true(facts.has_ssa_param_entry_read)
      SsaDefaultNumericProfile =>
        assert_true(facts.has_ssa_default_local_read_after_branchy_control)
      SsaDefaultRefProfile => {
        assert_true(facts.has_ssa_default_local_read_after_branchy_control)
        assert_true(facts.uses_ref_types)
      }
      SsaUnreachableProfile =>
        assert_true(facts.has_ssa_unreachable_local_carrier)
      SsaMergeExplicitProfile => assert_true(facts.has_ssa_both_arm_local_merge)
      SsaMergeParamEntryProfile =>
        assert_true(facts.has_ssa_one_arm_param_merge)
      SsaMergeDefaultEntryProfile =>
        assert_true(facts.has_ssa_one_arm_default_merge)
      SsaMergeSharedSetsProfile => {
        assert_true(facts.has_ssa_both_arm_local_merge)
        assert_true(facts.has_ssa_if_join_phi_candidate)
      }
      SsaLoopProfile => assert_true(facts.has_ssa_loop_carried_local_merge)
      SsaBranchProfile => {
        assert_true(facts.has_ssa_block_branch_merge_copy)
        assert_true(facts.has_ssa_br_table_phi_candidate)
      }
      SsaTypedControlProfile =>
        assert_true(facts.has_ssa_typed_loop_param_fail_closed_shape)
      SsaNestedValueProfile => {
        assert_true(facts.has_ssa_straight_line_local_chain)
        assert_true(facts.has_ssa_multi_def_same_local)
      }
      SsaEhProfile => assert_true(facts.has_ssa_exceptional_fail_closed_shape)
      _ => fail("unexpected full ssa singleton profile")
    }
  }
}
