///|
fn gen_valid_merge_blocks_test_contains(
  instrs : Array[Instruction],
  predicate : (Instruction) -> Bool,
) -> Bool {
  for instr in instrs {
    if predicate(instr) {
      return true
    }
    match instr {
      Block(_, Expr(body)) | Loop(_, Expr(body)) | TryTable(_, _, Expr(body)) =>
        if gen_valid_merge_blocks_test_contains(body, predicate) {
          return true
        }
      If(_, then_body, else_body) => {
        if gen_valid_merge_blocks_test_contains(then_body, predicate) {
          return true
        }
        match else_body {
          Some(body) =>
            if gen_valid_merge_blocks_test_contains(body, predicate) {
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
fn gen_valid_merge_blocks_test_body(mod_ : Module) -> Array[Instruction] {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      match funcs.get(funcs.length() - 1) {
        Some(Func(_, Expr(body))) => body
        None => abort("expected merge-blocks profile body")
      }
    None => abort("expected merge-blocks profile code section")
  }
}

///|
test "merge-blocks GenValid aggregate resolves every source family" {
  @debug.assert_eq(
    gen_valid_profile_name(MergeBlocksAllProfile),
    "merge-blocks-all",
  )
  assert_true(gen_valid_profile_is_composite(MergeBlocksAllProfile))
  let members = gen_valid_profile_members(MergeBlocksAllProfile)
  @debug.assert_eq(members.length(), 4)
  assert_true(
    members.contains(
      GenValidProfileMember::new(MergeBlocksStructuralProfile, 3),
    ),
  )
  assert_true(
    members.contains(
      GenValidProfileMember::new(MergeBlocksExpressionProfile, 3),
    ),
  )
  assert_true(
    members.contains(GenValidProfileMember::new(MergeBlocksEffectProfile, 2)),
  )
  assert_true(
    members.contains(GenValidProfileMember::new(MergeBlocksEhAtomicProfile, 2)),
  )
  for name in ["merge-blocks", "merge-blocks-closeout", "merge-blocks-all"] {
    match gen_valid_profile_by_name(name) {
      Ok(profile) => @debug.assert_eq(profile, MergeBlocksAllProfile)
      Err(msg) => fail(msg)
    }
  }
  assert_true(
    gen_valid_profile_members(RandomAllProfilesProfile).contains(
      GenValidProfileMember::new(MergeBlocksAllProfile, 1),
    ),
  )
}

///|
test "merge-blocks GenValid leaves emit valid family triggers" {
  let profiles = [
    MergeBlocksStructuralProfile,
    MergeBlocksExpressionProfile,
    MergeBlocksEffectProfile,
    MergeBlocksEhAtomicProfile,
  ]
  for i = 0; i < profiles.length(); i = i + 1 {
    let generated = match
      gen_valid_module_result_from_seed(
        0x4D4200UL + i.to_uint64(),
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
    let body = gen_valid_merge_blocks_test_body(generated.wasm_module)
    assert_true(
      gen_valid_merge_blocks_test_contains(body, fn(instr) {
        match instr {
          Block(_, Expr(nested)) =>
            gen_valid_merge_blocks_test_contains(nested, fn(child) {
              match child {
                Block(_, _) => true
                _ => false
              }
            })
          _ => false
        }
      }),
      msg="profile \{gen_valid_profile_name(profiles[i])} must include a structural merge opportunity",
    )
    match profiles[i] {
      MergeBlocksStructuralProfile =>
        assert_true(
          gen_valid_merge_blocks_test_contains(body, fn(instr) {
            match instr {
              Loop(_, _) => true
              _ => false
            }
          }),
        )
      MergeBlocksExpressionProfile => {
        assert_true(
          gen_valid_merge_blocks_test_contains(body, fn(instr) {
            match instr {
              If(_, _, _) => true
              _ => false
            }
          }),
        )
        assert_true(
          gen_valid_merge_blocks_test_contains(body, fn(instr) {
            match instr {
              I32Store(_) => true
              _ => false
            }
          }),
        )
        assert_true(
          gen_valid_merge_blocks_test_contains(body, fn(instr) {
            match instr {
              Throw(_) => true
              _ => false
            }
          }),
        )
      }
      MergeBlocksEffectProfile => {
        assert_true(
          gen_valid_merge_blocks_test_contains(body, fn(instr) {
            match instr {
              GlobalGet(_) => true
              _ => false
            }
          }),
        )
        assert_true(
          gen_valid_merge_blocks_test_contains(body, fn(instr) {
            match instr {
              GlobalSet(_) => true
              _ => false
            }
          }),
        )
      }
      MergeBlocksEhAtomicProfile => {
        assert_true(
          gen_valid_merge_blocks_test_contains(body, fn(instr) {
            match instr {
              TryTable(_, _, _) => true
              _ => false
            }
          }),
        )
        assert_true(
          gen_valid_merge_blocks_test_contains(body, fn(instr) {
            match instr {
              AtomicFence | I32AtomicLoad(_) => true
              _ => false
            }
          }),
        )
      }
      _ => ()
    }
  }
}
