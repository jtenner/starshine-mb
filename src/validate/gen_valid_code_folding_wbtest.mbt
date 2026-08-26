///|
fn gen_valid_code_folding_test_contains(
  instrs : Array[Instruction],
  predicate : (Instruction) -> Bool,
) -> Bool {
  for instr in instrs {
    if predicate(instr) {
      return true
    }
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_code_folding_test_contains(body, predicate) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_code_folding_test_contains(then_body, predicate) {
          return true
        }
        match else_body {
          Some(body) =>
            if gen_valid_code_folding_test_contains(body, predicate) {
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
fn gen_valid_code_folding_test_body(mod_ : Module) -> Array[Instruction] {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      match funcs.get(funcs.length() - 1) {
        Some(Func(_, Expr(body))) => body
        None => abort("expected code-folding profile body")
      }
    None => abort("expected code-folding profile code section")
  }
}

///|
test "code-folding GenValid aggregate resolves every source family" {
  @debug.assert_eq(
    gen_valid_profile_name(CodeFoldingAllProfile),
    "code-folding-all",
  )
  assert_true(gen_valid_profile_is_composite(CodeFoldingAllProfile))
  let members = gen_valid_profile_members(CodeFoldingAllProfile)
  @debug.assert_eq(members.length(), 6)
  assert_true(
    members.contains(GenValidProfileMember::new(CodeFoldingIfArmsProfile, 1)),
  )
  assert_true(
    members.contains(
      GenValidProfileMember::new(CodeFoldingBlockExitsProfile, 1),
    ),
  )
  assert_true(
    members.contains(GenValidProfileMember::new(CodeFoldingReturnsProfile, 1)),
  )
  assert_true(
    members.contains(GenValidProfileMember::new(CodeFoldingTailCallsProfile, 1)),
  )
  assert_true(
    members.contains(GenValidProfileMember::new(CodeFoldingMovementProfile, 1)),
  )
  assert_true(
    members.contains(GenValidProfileMember::new(CodeFoldingEhProfile, 1)),
  )
  match gen_valid_profile_by_name("code-folding") {
    Ok(profile) => @debug.assert_eq(profile, CodeFoldingAllProfile)
    Err(msg) => fail(msg)
  }
}

///|
test "code-folding GenValid leaves emit valid family triggers" {
  let profiles = [
    CodeFoldingIfArmsProfile,
    CodeFoldingBlockExitsProfile,
    CodeFoldingReturnsProfile,
    CodeFoldingTailCallsProfile,
    CodeFoldingMovementProfile,
    CodeFoldingEhProfile,
  ]
  for i = 0; i < profiles.length(); i = i + 1 {
    let generated = match
      gen_valid_module_result_from_seed(
        0xCF0000UL + i.to_uint64(),
        GenValidConfig::for_profile(profiles[i]),
      ) {
      Ok(value) => value
      Err(failure) =>
        fail(
          "profile \{gen_valid_profile_name(profiles[i])}: \{failure.validation_error_message}",
        )
    }
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) => fail(validation_error_message(err))
    }
    let body = gen_valid_code_folding_test_body(generated.wasm_module)
    let triggered = match profiles[i] {
      CodeFoldingIfArmsProfile =>
        gen_valid_code_folding_test_contains(body, fn(instr) {
          match instr {
            If(_, _, Some(_)) => true
            _ => false
          }
        })
      CodeFoldingBlockExitsProfile | CodeFoldingMovementProfile =>
        gen_valid_code_folding_test_contains(body, fn(instr) {
          match instr {
            Br(_) | BrTable(_, _) => true
            _ => false
          }
        })
      CodeFoldingReturnsProfile =>
        gen_valid_code_folding_test_contains(body, fn(instr) {
          match instr {
            Return => true
            _ => false
          }
        })
      CodeFoldingTailCallsProfile =>
        gen_valid_code_folding_test_contains(body, fn(instr) {
          match instr {
            ReturnCall(_) => true
            _ => false
          }
        })
      CodeFoldingEhProfile =>
        gen_valid_code_folding_test_contains(body, fn(instr) {
          match instr {
            TryTable(_, _, _) => true
            _ => false
          }
        })
      _ => false
    }
    assert_true(
      triggered,
      msg="missing trigger for \{gen_valid_profile_name(profiles[i])}",
    )
  }
}
