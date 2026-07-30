///|
fn gen_valid_coalesce_locals_test_first_body(
  mod_ : Module,
) -> Array[Instruction] {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      match funcs.get(0) {
        Some(Func(_, Expr(body))) => body
        None => abort("expected coalesce-locals profile function")
      }
    None => abort("expected coalesce-locals profile code section")
  }
}

///|
fn gen_valid_coalesce_locals_test_has_local_traffic(
  instrs : Array[Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      LocalGet(_) | LocalSet(_) | LocalTee(_) => return true
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_coalesce_locals_test_has_local_traffic(body) {
          return true
        }
      Try(_, Expr(body), catches, _) => {
        if gen_valid_coalesce_locals_test_has_local_traffic(body) {
          return true
        }
        for catch_ in catches {
          let Expr(catch_body) = match catch_ {
            LegacyCatch(_, catch_expr) | LegacyCatchAll(catch_expr) =>
              catch_expr
          }
          if gen_valid_coalesce_locals_test_has_local_traffic(catch_body) {
            return true
          }
        }
      }
      If(_, then_body, else_body) => {
        if gen_valid_coalesce_locals_test_has_local_traffic(then_body) {
          return true
        }
        match else_body {
          Some(body) =>
            if gen_valid_coalesce_locals_test_has_local_traffic(body) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
test "coalesce-locals GenValid aggregate owns every transform family" {
  let expected = [
    CoalesceLocalsStraightLineProfile,
    CoalesceLocalsStructuredProfile,
    CoalesceLocalsLoopCopyThroughProfile,
    CoalesceLocalsEntryValuesProfile,
    CoalesceLocalsCopyPreferenceProfile,
    CoalesceLocalsTeeCopiesProfile,
    CoalesceLocalsInterBlockProfile,
    CoalesceLocalsUnreachableProfile,
    CoalesceLocalsLegacyEhProfile,
    CoalesceLocalsLargeUnusedProfile,
    CoalesceLocalsExactTypesProfile,
  ]
  let members = gen_valid_profile_members(CoalesceLocalsAllProfile)
  @debug.assert_eq(members.length(), expected.length())
  for profile in expected {
    assert_true(
      members.any(fn(entry) { entry.profile == profile }),
      msg="missing coalesce-locals family \{gen_valid_profile_name(profile)}",
    )
  }
}

///|
test "coalesce-locals GenValid leaves emit valid local-traffic fixtures" {
  let profiles = [
    CoalesceLocalsStraightLineProfile,
    CoalesceLocalsStructuredProfile,
    CoalesceLocalsLoopCopyThroughProfile,
    CoalesceLocalsEntryValuesProfile,
    CoalesceLocalsCopyPreferenceProfile,
    CoalesceLocalsTeeCopiesProfile,
    CoalesceLocalsInterBlockProfile,
    CoalesceLocalsUnreachableProfile,
    CoalesceLocalsLegacyEhProfile,
    CoalesceLocalsLargeUnusedProfile,
    CoalesceLocalsExactTypesProfile,
  ]
  for idx = 0; idx < profiles.length(); idx = idx + 1 {
    let profile = profiles[idx]
    let generated = match
      gen_valid_module_result_from_seed(
        0xc0a1UL + idx.to_uint64(),
        GenValidConfig::for_profile(profile),
      ) {
      Ok(value) => value
      Err(failure) => fail(failure.validation_error_message)
    }
    @debug.assert_eq(generated.config_label, gen_valid_profile_name(profile))
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) => fail(validation_error_message(err))
    }
    assert_true(
      gen_valid_coalesce_locals_test_has_local_traffic(
        gen_valid_coalesce_locals_test_first_body(generated.wasm_module),
      ),
      msg="profile \{gen_valid_profile_name(profile)} must emit local traffic",
    )
  }
}
