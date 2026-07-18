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
    MergeLocalsReverseProfile,
    MergeLocalsControlProfile,
    MergeLocalsTeeProfile,
    MergeLocalsMergeBoundaryProfile,
    MergeLocalsTypeBoundaryProfile,
    MergeLocalsRollbackProfile,
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
