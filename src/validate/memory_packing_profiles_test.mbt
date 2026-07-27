///|
test "memory-packing GenValid aggregate selects every behavior family" {
  let aggregate = match gen_valid_profile_by_name("memory-packing-all") {
    Ok(profile) => profile
    Err(message) => fail(message)
  }
  let expected_names = [
    "memory-packing-active-ranges", "memory-packing-active-traps", "memory-packing-defined-overlap",
    "memory-packing-passive-splits", "memory-packing-segment-ops", "memory-packing-memory64",
    "memory-packing-boundaries",
  ]
  let members = gen_valid_profile_members(aggregate)
  for expected_name in expected_names {
    let expected = match gen_valid_profile_by_name(expected_name) {
      Ok(profile) => profile
      Err(message) => fail(message)
    }
    let mut found = false
    for profile_member in members {
      if profile_member.profile == expected {
        found = true
      }
    }
    assert_true(found, msg="missing memory-packing family " + expected_name)
  }
}

///|
test "memory-packing GenValid family modules validate and carry trigger data" {
  let profile_names = [
    "memory-packing-active-ranges", "memory-packing-active-traps", "memory-packing-defined-overlap",
    "memory-packing-passive-splits", "memory-packing-segment-ops", "memory-packing-memory64",
    "memory-packing-boundaries", "memory-packing-imported-overlap",
  ]
  for profile_name in profile_names {
    let profile = match gen_valid_profile_by_name(profile_name) {
      Ok(profile) => profile
      Err(message) => fail(message)
    }
    let generated = match
      gen_valid_module_result_from_seed(
        0x5eedUL,
        GenValidConfig::for_profile(profile),
      ) {
      Ok(generated) => generated
      Err(_) => fail("generation failed for " + profile_name)
    }
    let mod_ = generated.wasm_module
    match validate_module(mod_) {
      Ok(_) => ()
      Err(_) => fail("invalid memory-packing profile " + profile_name)
    }
    match mod_.data_sec {
      Some(@lib.DataSec(datas)) => assert_true(!datas.is_empty())
      None => fail("memory-packing profile emitted no data section")
    }
    assert_true(gen_valid_memory_packing_profile_case_label(profile) is Some(_))
  }
}

///|
test "memory-packing imported overlap profile has a separate zero-filled alias" {
  let canonical = match
    gen_valid_profile_by_name("memory-packing-imported-overlap") {
    Ok(profile) => profile
    Err(message) => fail(message)
  }
  @debug.assert_eq(
    gen_valid_profile_by_name("memory-packing-zero-filled"),
    Ok(canonical),
  )
}
