///|
fn gen_valid_merge_locals_test_first_body(mod_ : Module) -> Array[Instruction] {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      match funcs.get(0) {
        Some(Func(_, Expr(body))) => body
        None => abort("expected merge-locals profile function")
      }
    None => abort("expected merge-locals profile code section")
  }
}

///|
fn gen_valid_merge_locals_test_has_copy(instrs : Array[Instruction]) -> Bool {
  for idx = 0; idx + 1 < instrs.length(); idx = idx + 1 {
    match (instrs[idx], instrs[idx + 1]) {
      (LocalGet(LocalIdx(source)), LocalSet(LocalIdx(target)))
      | (LocalGet(LocalIdx(source)), LocalTee(LocalIdx(target))) =>
        if source != target {
          return true
        }
      _ => ()
    }
  }
  for instr in instrs {
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_merge_locals_test_has_copy(body) {
          return true
        }
      Try(_, Expr(body), catches, _) => {
        if gen_valid_merge_locals_test_has_copy(body) {
          return true
        }
        for catch_ in catches {
          let Expr(catch_body) = match catch_ {
            LegacyCatch(_, catch_expr) | LegacyCatchAll(catch_expr) =>
              catch_expr
          }
          if gen_valid_merge_locals_test_has_copy(catch_body) {
            return true
          }
        }
      }
      If(_, then_body, else_body) => {
        if gen_valid_merge_locals_test_has_copy(then_body) {
          return true
        }
        match else_body {
          Some(body) =>
            if gen_valid_merge_locals_test_has_copy(body) {
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
test "merge-locals GenValid family profiles emit valid copy-shaped modules" {
  let profiles = [
    MergeLocalsForwardProfile,
    MergeLocalsForwardMultipleProfile,
    MergeLocalsPartialInfluenceProfile,
    MergeLocalsReverseProfile,
    MergeLocalsReverseBoundaryProfile,
    MergeLocalsControlProfile,
    MergeLocalsTeeProfile,
    MergeLocalsMergeBoundaryProfile,
    MergeLocalsTypeBoundaryProfile,
    MergeLocalsRollbackProfile,
    MergeLocalsReverseRollbackProfile,
    MergeLocalsNestedCopiesProfile,
    MergeLocalsTrivialConfusionProfile,
    MergeLocalsUnreachableProfile,
    MergeLocalsLegacyEhProfile,
  ]
  for idx = 0; idx < profiles.length(); idx = idx + 1 {
    let profile = profiles[idx]
    let generated = match
      gen_valid_module_result_from_seed(
        0x5eedUL + idx.to_uint64(),
        GenValidConfig::for_profile(profile),
      ) {
      Ok(v) => v
      Err(failure) => fail(failure.validation_error_message)
    }
    @debug.assert_eq(generated.config_label, gen_valid_profile_name(profile))
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) => fail(validation_error_message(err))
    }
    assert_true(
      gen_valid_merge_locals_test_has_copy(
        gen_valid_merge_locals_test_first_body(generated.wasm_module),
      ),
      msg="profile \{gen_valid_profile_name(profile)} must emit a local copy",
    )
  }
}

///|
test "merge-locals GenValid control profile rotates block if and loop families" {
  let labels : Array[String] = []
  for seed in [0UL, 1UL, 2UL, 3UL, 4UL, 5UL] {
    match
      gen_valid_merge_locals_profile_case_label(MergeLocalsControlProfile, seed) {
      Some(label) => if !labels.contains(label) { labels.push(label) }
      None => fail("expected merge-locals control case label")
    }
  }
  @debug.assert_eq(labels.length(), 3)
}

///|
test "merge-locals GenValid source-family labels cover Binaryen v131" {
  let expected = [
    "merge-locals:forward", "merge-locals:forward-multiple", "merge-locals:partial-influence-0",
    "merge-locals:partial-influence-1", "merge-locals:reverse", "merge-locals:reverse-boundary-0",
    "merge-locals:reverse-boundary-1", "merge-locals:control-0", "merge-locals:control-1",
    "merge-locals:control-2", "merge-locals:tee", "merge-locals:merge-boundary",
    "merge-locals:type-boundary", "merge-locals:rollback", "merge-locals:reverse-rollback-0",
    "merge-locals:reverse-rollback-1", "merge-locals:reverse-rollback-2", "merge-locals:nested-copies-0",
    "merge-locals:nested-copies-1", "merge-locals:trivial-confusion", "merge-locals:unreachable",
    "merge-locals:legacy-eh-protected", "merge-locals:legacy-eh-catch", "merge-locals:legacy-eh-catch-all",
    "merge-locals:legacy-eh-delegate",
  ]
  let found : Array[String] = []
  let profiles = [
    MergeLocalsForwardProfile,
    MergeLocalsForwardMultipleProfile,
    MergeLocalsPartialInfluenceProfile,
    MergeLocalsReverseProfile,
    MergeLocalsReverseBoundaryProfile,
    MergeLocalsControlProfile,
    MergeLocalsTeeProfile,
    MergeLocalsMergeBoundaryProfile,
    MergeLocalsTypeBoundaryProfile,
    MergeLocalsRollbackProfile,
    MergeLocalsReverseRollbackProfile,
    MergeLocalsNestedCopiesProfile,
    MergeLocalsTrivialConfusionProfile,
    MergeLocalsUnreachableProfile,
    MergeLocalsLegacyEhProfile,
  ]
  for profile in profiles {
    for seed = 0UL; seed < 8UL; seed = seed + 1UL {
      match gen_valid_merge_locals_profile_case_label(profile, seed) {
        Some(label) => if !found.contains(label) { found.push(label) }
        None => fail("expected merge-locals source-family label")
      }
    }
  }
  for label in expected {
    assert_true(found.contains(label), msg="missing source family \{label}")
  }
}

///|
test "merge-locals GenValid legacy EH profile enables tags and every region form validates" {
  let config = GenValidConfig::for_profile(MergeLocalsLegacyEhProfile)
  assert_true(config.features.allow_tags)
  assert_true(config.max_tags > 0)
  for seed in [0UL, 1UL, 2UL, 3UL] {
    let generated = match gen_valid_module_result_from_seed(seed, config) {
      Ok(v) => v
      Err(failure) => fail(failure.validation_error_message)
    }
    match validate_module(generated.wasm_module) {
      Ok(_) => ()
      Err(err) => fail(validation_error_message(err))
    }
    assert_true(
      gen_valid_merge_locals_test_has_copy(
        gen_valid_merge_locals_test_first_body(generated.wasm_module),
      ),
    )
  }
}

///|
test "merge-locals GenValid type boundary enables GC subtype topology" {
  let config = GenValidConfig::for_profile(MergeLocalsTypeBoundaryProfile)
  assert_true(config.features.allow_ref_types)
  assert_true(config.features.allow_subtyping_topology)
  let generated = match gen_valid_module_result_from_seed(0x5eedUL, config) {
    Ok(v) => v
    Err(failure) => fail(failure.validation_error_message)
  }
  match generated.wasm_module.type_sec {
    Some(TypeSec(types)) => @debug.assert_eq(types.length(), 3)
    None => fail("expected base child and function types")
  }
}
