///|
fn gen_valid_msf_test_defined_func_count(mod_ : Module) -> Int {
  match mod_.code_sec {
    Some(CodeSec(funcs)) => funcs.length()
    None => 0
  }
}

///|
fn gen_valid_msf_test_has_large_sibling_pair(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) => {
      if funcs.length() < 2 {
        return false
      }
      for left = 0; left < funcs.length(); left = left + 1 {
        let Func(left_locals, Expr(left_body)) = funcs[left]
        for right = left + 1; right < funcs.length(); right = right + 1 {
          let Func(right_locals, Expr(right_body)) = funcs[right]
          if left_locals == right_locals &&
            left_body.length() >= 15 &&
            right_body.length() >= 15 &&
            left_body.length() == right_body.length() {
            return true
          }
        }
      }
      false
    }
    None => false
  }
}

///|
test "merge-similar-functions GenValid aggregate registers all trigger families" {
  @debug.assert_eq(
    gen_valid_profile_name(MergeSimilarFunctionsAllProfile),
    "merge-similar-functions-all",
  )
  assert_true(gen_valid_profile_is_composite(MergeSimilarFunctionsAllProfile))
  let members = gen_valid_profile_members(MergeSimilarFunctionsAllProfile)
  for
    profile in [
      MergeSimilarFunctionsLiteralsProfile,
      MergeSimilarFunctionsRepeatedDiffProfile,
      MergeSimilarFunctionsExactDuplicatesProfile,
      MergeSimilarFunctionsDuplicateTypesProfile,
      MergeSimilarFunctionsLocalsProfile,
      MergeSimilarFunctionsNestedProfile,
      MergeSimilarFunctionsCallTargetsProfile,
      MergeSimilarFunctionsTailCallsProfile,
    ] {
    assert_true(
      members.any(fn(entry) { entry.profile == profile }),
      msg="missing MSF aggregate member \{gen_valid_profile_name(profile)}",
    )
  }
  for
    profile_alias in [
      "merge-similar-functions", "merge-similar-functions-closeout", "msf",
    ] {
    match gen_valid_profile_by_name(profile_alias) {
      Ok(profile) => @debug.assert_eq(profile, MergeSimilarFunctionsAllProfile)
      Err(err) => fail(err)
    }
  }
  assert_true(
    gen_valid_profile_members(RandomAllProfilesProfile).contains(
      GenValidProfileMember::new(MergeSimilarFunctionsAllProfile, 1),
    ),
  )
}

///|
test "merge-similar-functions GenValid leaves emit valid large sibling shapes" {
  let profiles = [
    MergeSimilarFunctionsLiteralsProfile,
    MergeSimilarFunctionsRepeatedDiffProfile,
    MergeSimilarFunctionsExactDuplicatesProfile,
    MergeSimilarFunctionsDuplicateTypesProfile,
    MergeSimilarFunctionsLocalsProfile,
    MergeSimilarFunctionsNestedProfile,
    MergeSimilarFunctionsCallTargetsProfile,
    MergeSimilarFunctionsTailCallsProfile,
  ]
  for idx = 0; idx < profiles.length(); idx = idx + 1 {
    let profile = profiles[idx]
    let generated = match
      gen_valid_module_result(
        @splitmix.new(seed=0x5eedUL + idx.to_uint64()),
        GenValidConfig::for_profile(profile),
      ) {
      Ok(value) => value
      Err(failure) => fail(failure.validation_error_message)
    }
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) => fail(validation_error_message(err))
    }
    assert_true(
      gen_valid_msf_test_defined_func_count(generated.wasm_module) >= 2,
    )
    assert_true(
      gen_valid_msf_test_has_large_sibling_pair(generated.wasm_module),
      msg="profile \{gen_valid_profile_name(profile)} did not emit a large sibling pair",
    )
    assert_true(
      gen_valid_msf_profile_case_label(profile, 0x5eedUL + idx.to_uint64())
      is Some(_),
    )
  }
}
