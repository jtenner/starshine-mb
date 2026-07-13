///|
test "optimize-instructions closeout aliases resolve to the OI aggregate profile" {
  @debug.assert_eq(gen_valid_profile_name(PassOiAllProfile), "pass-oi-all")
  assert_true(gen_valid_profiles().contains(PassOiAllProfile))
  assert_true(gen_valid_profile_names().contains("pass-oi-all"))

  for
    alias in [
      "optimize-instructions", "optimize-instructions-closeout", "optimize-instructions-all-profiles",
      "oi-all",
    ] {
    match gen_valid_profile_by_name(alias) {
      Ok(profile) => {
        @debug.assert_eq(profile, PassOiAllProfile)
        assert_true(gen_valid_profile_is_composite(profile))
      }
      Err(msg) => fail(msg)
    }
  }
}

///|
test "optimize-instructions aggregate keeps the nine maintained OI leaves" {
  let aggregate = match gen_valid_profile_by_name("optimize-instructions") {
    Ok(profile) => profile
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(aggregate, PassOiAllProfile)

  let expected = [
    PassOiDefaultScalarProfile,
    PassOiLocalFactsProfile,
    PassOiBooleanSelectProfile,
    PassOiMemoryBulkProfile,
    PassOiCallRefProfile,
    PassOiRefGcProfile,
    PassOiGcAggregateProfile,
    PassOiDescriptorGcProfile,
    PassOiTupleProfile,
  ]
  let members = gen_valid_profile_members(aggregate)
  @debug.assert_eq(members.length(), expected.length())
  for expected_profile in expected {
    assert_true(
      members.contains(GenValidProfileMember::new(expected_profile, 1)),
      msg="missing OI aggregate member \{gen_valid_profile_name(expected_profile)}",
    )
  }

  let seen : Array[GenValidProfile] = []
  let mut index = 1
  while index <= 256 {
    let leaf = gen_valid_profile_leaf_for_case(aggregate, 0x5eedUL, index)
    assert_false(gen_valid_profile_is_composite(leaf))
    if !seen.contains(leaf) {
      seen.push(leaf)
    }
    index += 1
  }
  for expected_profile in expected {
    assert_true(
      seen.contains(expected_profile),
      msg="missing sampled OI aggregate leaf \{gen_valid_profile_name(expected_profile)}",
    )
  }
}
