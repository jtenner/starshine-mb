///|
fn gen_valid_rub_test_instrs_any(
  instrs : Array[Instruction],
  predicate : (Instruction) -> Bool,
) -> Bool {
  for instr in instrs {
    if predicate(instr) {
      return true
    }
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_rub_test_instrs_any(body, predicate) {
          return true
        }
      Try(_, Expr(body), catches, _) => {
        if gen_valid_rub_test_instrs_any(body, predicate) {
          return true
        }
        for catch_ in catches {
          let Expr(catch_body) = match catch_ {
            LegacyCatch(_, body) | LegacyCatchAll(body) => body
          }
          if gen_valid_rub_test_instrs_any(catch_body, predicate) {
            return true
          }
        }
      }
      If(_, then_body, else_body) => {
        if gen_valid_rub_test_instrs_any(then_body, predicate) {
          return true
        }
        match else_body {
          Some(body) =>
            if gen_valid_rub_test_instrs_any(body, predicate) {
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
fn gen_valid_rub_test_module_any(
  mod_ : Module,
  predicate : (Instruction) -> Bool,
) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, Expr(body)) = func
        if gen_valid_rub_test_instrs_any(body, predicate) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn gen_valid_rub_test_defined_func_count(mod_ : Module) -> Int {
  match mod_.code_sec {
    Some(CodeSec(funcs)) => funcs.length()
    None => 0
  }
}

///|
test "remove-unused-brs GenValid aggregate resolves focused parity families" {
  @debug.assert_eq(
    gen_valid_profile_name(RemoveUnusedBrsAllProfile),
    "remove-unused-brs-all",
  )
  assert_true(gen_valid_profile_is_composite(RemoveUnusedBrsAllProfile))
  let members = gen_valid_profile_members(RemoveUnusedBrsAllProfile)
  for
    profile in [
      RemoveUnusedBrsConstantBrIfProfile,
      RemoveUnusedBrsSingleTargetBrTableProfile,
      RemoveUnusedBrsMultiFunctionProfile,
      RemoveUnusedBrsResultRefinalizeProfile,
      RemoveUnusedBrsMultivalueDropProfile,
      RemoveUnusedBrsWrapperCleanupProfile,
      RemoveUnusedBrsSelectifyProfile,
      RemoveUnusedBrsTailFlowProfile,
      RemoveUnusedBrsOneArmIfProfile,
      RemoveUnusedBrsLoopProfile,
      RemoveUnusedBrsSinkBlocksProfile,
      RemoveUnusedBrsEhProfile,
      RemoveUnusedBrsJumpThreadProfile,
      RemoveUnusedBrsTablifyProfile,
      RemoveUnusedBrsOptimizeSetIfProfile,
      RemoveUnusedBrsRestructureIfProfile,
      RemoveUnusedBrsAdjacentBranchProfile,
      RemoveUnusedBrsControlProfile,
      RemoveUnusedBrsSwitchProfile,
      RemoveUnusedBrsCleanupProfile,
      RemoveUnusedBrsGcProfile,
    ] {
    assert_true(
      members.any(fn(entry) { entry.profile == profile }),
      msg="missing aggregate member \{gen_valid_profile_name(profile)}",
    )
  }
  assert_false(
    members.any(fn(entry) { entry.profile == RemoveUnusedBrsWinBoundaryProfile }),
    msg="measured Starshine-win boundary must remain outside exact-parity aggregate",
  )
  for
    name in [
      "remove-unused-brs", "remove-unused-brs-closeout", "remove-unused-brs-all",
    ] {
    match gen_valid_profile_by_name(name) {
      Ok(profile) => @debug.assert_eq(profile, RemoveUnusedBrsAllProfile)
      Err(msg) => fail(msg)
    }
  }
  assert_true(
    gen_valid_profile_members(RandomAllProfilesProfile).contains(
      GenValidProfileMember::new(RemoveUnusedBrsAllProfile, 1),
    ),
  )
}

///|
test "remove-unused-brs focused GenValid leaves emit valid owned triggers" {
  let profiles = [
    RemoveUnusedBrsConstantBrIfProfile,
    RemoveUnusedBrsSingleTargetBrTableProfile,
    RemoveUnusedBrsMultiFunctionProfile,
    RemoveUnusedBrsResultRefinalizeProfile,
    RemoveUnusedBrsMultivalueDropProfile,
    RemoveUnusedBrsWrapperCleanupProfile,
    RemoveUnusedBrsSelectifyProfile,
    RemoveUnusedBrsTailFlowProfile,
    RemoveUnusedBrsOneArmIfProfile,
    RemoveUnusedBrsLoopProfile,
    RemoveUnusedBrsSinkBlocksProfile,
    RemoveUnusedBrsEhProfile,
    RemoveUnusedBrsJumpThreadProfile,
    RemoveUnusedBrsTablifyProfile,
    RemoveUnusedBrsOptimizeSetIfProfile,
    RemoveUnusedBrsRestructureIfProfile,
    RemoveUnusedBrsAdjacentBranchProfile,
    RemoveUnusedBrsWinBoundaryProfile,
  ]
  for i = 0; i < profiles.length(); i = i + 1 {
    let profile = profiles[i]
    let generated = match
      gen_valid_module_result_from_seed(
        0x52554200UL + i.to_uint64(),
        GenValidConfig::for_profile(profile),
      ) {
      Ok(value) => value
      Err(failure) =>
        fail(
          "profile \{gen_valid_profile_name(profile)}: \{failure.validation_error_message}",
        )
    }
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) => fail(validation_error_message(err))
    }
    let has_trigger = match profile {
      RemoveUnusedBrsConstantBrIfProfile =>
        gen_valid_rub_test_module_any(generated.wasm_module, fn(instr) {
          instr is BrIf(_)
        })
      RemoveUnusedBrsSingleTargetBrTableProfile =>
        gen_valid_rub_test_module_any(generated.wasm_module, fn(instr) {
          instr is BrTable(_, _)
        })
      RemoveUnusedBrsMultiFunctionProfile =>
        gen_valid_rub_test_defined_func_count(generated.wasm_module) >= 2 &&
        gen_valid_rub_test_module_any(generated.wasm_module, fn(instr) {
          instr is BrIf(_) || instr is BrTable(_, _)
        })
      RemoveUnusedBrsResultRefinalizeProfile =>
        gen_valid_rub_test_module_any(generated.wasm_module, fn(instr) {
          instr is RefI31
        })
      RemoveUnusedBrsMultivalueDropProfile =>
        gen_valid_rub_test_module_any(generated.wasm_module, fn(instr) {
          match instr {
            Block(TypeIdxBlockType(_), _) => true
            _ => false
          }
        })
      RemoveUnusedBrsWrapperCleanupProfile =>
        gen_valid_rub_test_module_any(generated.wasm_module, fn(instr) {
          instr is Br(_)
        })
      RemoveUnusedBrsSelectifyProfile =>
        gen_valid_rub_test_module_any(generated.wasm_module, fn(instr) {
          instr is If(_, _, _)
        })
      RemoveUnusedBrsTailFlowProfile =>
        gen_valid_rub_test_module_any(generated.wasm_module, fn(instr) {
          instr is Br(_) || instr is Return
        })
      RemoveUnusedBrsOneArmIfProfile
      | RemoveUnusedBrsSinkBlocksProfile
      | RemoveUnusedBrsOptimizeSetIfProfile =>
        gen_valid_rub_test_module_any(generated.wasm_module, fn(instr) {
          instr is If(_, _, _)
        })
      RemoveUnusedBrsLoopProfile =>
        gen_valid_rub_test_module_any(generated.wasm_module, fn(instr) {
          instr is Loop(_, _)
        })
      RemoveUnusedBrsEhProfile =>
        gen_valid_rub_test_module_any(generated.wasm_module, fn(instr) {
          instr is Throw(_)
        })
      RemoveUnusedBrsJumpThreadProfile =>
        gen_valid_rub_test_module_any(generated.wasm_module, fn(instr) {
          instr is Br(_)
        })
      RemoveUnusedBrsTablifyProfile
      | RemoveUnusedBrsRestructureIfProfile
      | RemoveUnusedBrsAdjacentBranchProfile =>
        gen_valid_rub_test_module_any(generated.wasm_module, fn(instr) {
          instr is BrIf(_)
        })
      RemoveUnusedBrsWinBoundaryProfile =>
        gen_valid_rub_test_module_any(generated.wasm_module, fn(instr) {
          instr is LocalTee(_)
        })
      _ => false
    }
    assert_true(
      has_trigger,
      msg="profile \{gen_valid_profile_name(profile)} must emit its owned trigger",
    )
  }
}
