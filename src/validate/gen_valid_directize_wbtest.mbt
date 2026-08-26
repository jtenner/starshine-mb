///|
fn gen_valid_directize_test_instr_has_indirect_call(
  instr : Instruction,
) -> Bool {
  match instr {
    CallIndirect(_, _) | ReturnCallIndirect(_, _) => true
    Block(_, Expr(body)) | Loop(_, Expr(body)) =>
      body.any(gen_valid_directize_test_instr_has_indirect_call)
    If(_, then_body, else_body) => {
      if then_body.any(gen_valid_directize_test_instr_has_indirect_call) {
        return true
      }
      match else_body {
        Some(body) => body.any(gen_valid_directize_test_instr_has_indirect_call)
        None => false
      }
    }
    Try(_, Expr(body), catches, _) => {
      if body.any(gen_valid_directize_test_instr_has_indirect_call) {
        return true
      }
      for catch_ in catches {
        let Expr(catch_body) = match catch_ {
          @lib.LegacyCatch(_, body) | @lib.LegacyCatchAll(body) => body
        }
        if catch_body.any(gen_valid_directize_test_instr_has_indirect_call) {
          return true
        }
      }
      false
    }
    TryTable(_, _, Expr(body)) =>
      body.any(gen_valid_directize_test_instr_has_indirect_call)
    _ => false
  }
}

///|
fn gen_valid_directize_test_has_indirect_call(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, Expr(body)) = func
        if body.any(gen_valid_directize_test_instr_has_indirect_call) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
test "directize GenValid aggregate resolves every source family" {
  @debug.assert_eq(gen_valid_profile_name(DirectizeAllProfile), "directize-all")
  assert_true(gen_valid_profile_is_composite(DirectizeAllProfile))
  let members = gen_valid_profile_members(DirectizeAllProfile)
  @debug.assert_eq(members.length(), 8)
  for
    expected in [
      GenValidProfileMember::new(DirectizeConstantProfile, 3),
      GenValidProfileMember::new(DirectizeSelectProfile, 3),
      GenValidProfileMember::new(DirectizeTableFactsProfile, 3),
      GenValidProfileMember::new(DirectizeTailCallProfile, 2),
      GenValidProfileMember::new(DirectizeGcProfile, 2),
      GenValidProfileMember::new(DirectizeTable64Profile, 2),
      GenValidProfileMember::new(DirectizeLegacyEhProfile, 3),
      GenValidProfileMember::new(DirectizeBoundaryProfile, 2),
    ] {
    assert_true(members.contains(expected))
  }
  for name in ["directize", "directize-closeout", "directize-all"] {
    match gen_valid_profile_by_name(name) {
      Ok(profile) => @debug.assert_eq(profile, DirectizeAllProfile)
      Err(msg) => fail(msg)
    }
  }
  assert_true(
    gen_valid_profile_members(RandomAllProfilesProfile).contains(
      GenValidProfileMember::new(DirectizeAllProfile, 1),
    ),
  )
}

///|
test "directize GenValid leaves emit valid indirect-call surfaces" {
  let profiles = [
    DirectizeConstantProfile,
    DirectizeSelectProfile,
    DirectizeTableFactsProfile,
    DirectizeTailCallProfile,
    DirectizeGcProfile,
    DirectizeTable64Profile,
    DirectizeLegacyEhProfile,
    DirectizeBoundaryProfile,
  ]
  for i = 0; i < profiles.length(); i = i + 1 {
    for variant = 0; variant < 5; variant = variant + 1 {
      let seed = 0x44495200UL + i.to_uint64() * 16UL + variant.to_uint64()
      let generated = match
        gen_valid_module_result_from_seed(
          seed,
          GenValidConfig::for_profile(profiles[i]),
        ) {
        Ok(value) => value
        Err(failure) =>
          fail(
            "profile \{gen_valid_profile_name(profiles[i])}: \{failure.validation_error_message}: \{@debug.to_string(failure.last_candidate)}",
          )
      }
      match validate_module(generated.wasm_module) {
        Ok(_) => ()
        Err(err) => fail(validation_error_message(err))
      }
      @debug.assert_eq(
        generated.config_label,
        gen_valid_profile_name(profiles[i]),
      )
      assert_true(
        gen_valid_directize_test_has_indirect_call(generated.wasm_module),
      )
      assert_true(
        gen_valid_directize_profile_case_label(profiles[i], seed) is Some(_),
      )
    }
  }
}
