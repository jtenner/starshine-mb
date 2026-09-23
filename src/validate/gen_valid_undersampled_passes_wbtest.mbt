///|
fn gen_valid_undersampled_test_has_repeated_func(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) => {
      for left = 0; left < funcs.length(); left = left + 1 {
        for right = left + 1; right < funcs.length(); right = right + 1 {
          if funcs[left] == funcs[right] {
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
fn gen_valid_undersampled_test_has_lcse_repeat(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(
      CodeSec(
        [
          Func(
            _,
            Expr(
              [
                LocalGet(LocalIdx(0U)),
                LocalGet(LocalIdx(1U)),
                first,
                Drop,
                LocalGet(LocalIdx(0U)),
                LocalGet(LocalIdx(1U)),
                second,
                Drop,
              ]
            )
          ),
        ]
      )
    ) =>
      first == second && (first is I32Add || first is I32Sub || first is I32Xor)
    _ => false
  }
}

///|
test "undersampled pass GenValid profiles register deterministic trigger leaves" {
  @debug.assert_eq(
    gen_valid_profile_by_name("local-cse"),
    Ok(LocalCseTriggerProfile),
  )
  @debug.assert_eq(
    gen_valid_profile_by_name("duplicate-function-elimination"),
    Ok(DuplicateFunctionEliminationTriggerProfile),
  )
  let random_members = gen_valid_profile_members(RandomAllProfilesProfile)
  assert_true(
    random_members.contains(
      GenValidProfileMember::new(LocalCseTriggerProfile, 1),
    ),
  )
  assert_true(
    random_members.contains(
      GenValidProfileMember::new(DuplicateFunctionEliminationTriggerProfile, 1),
    ),
  )
}

///|
test "undersampled pass GenValid profiles always emit valid owned triggers" {
  let profiles = [
    LocalCseTriggerProfile,
    DuplicateFunctionEliminationTriggerProfile,
  ]
  for profile in profiles {
    let labels : Array[String] = []
    for ordinal = 0; ordinal < 4; ordinal = ordinal + 1 {
      let seed = 0x5eedUL + ordinal.to_uint64()
      let generated = match
        gen_valid_module_result_from_seed(
          seed,
          GenValidConfig::for_profile(profile),
        ) {
        Ok(value) => value
        Err(failure) => fail(failure.validation_error_message)
      }
      match validate_module(generated.wasm_module) {
        Ok(_) => ()
        Err(err) => fail(validation_error_message(err))
      }
      match profile {
        LocalCseTriggerProfile =>
          assert_true(
            gen_valid_undersampled_test_has_lcse_repeat(generated.wasm_module),
            msg="local-cse profile missed its repeated expression",
          )
        DuplicateFunctionEliminationTriggerProfile =>
          assert_true(
            gen_valid_undersampled_test_has_repeated_func(generated.wasm_module),
            msg="DFE profile missed its duplicate function pair",
          )
        _ => fail("unexpected undersampled pass profile")
      }
      match gen_valid_undersampled_pass_profile_case_label(profile, seed) {
        Some(label) => if !labels.contains(label) { labels.push(label) }
        None =>
          fail("missing trigger label for {gen_valid_profile_name(profile)}")
      }
    }
    assert_true(
      labels.length() >= 2,
      msg="profile {gen_valid_profile_name(profile)} did not vary triggers",
    )
  }
}
