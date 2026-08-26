///|
fn gen_valid_rume_test_defined_func_count(mod_ : Module) -> Int {
  match mod_.func_sec {
    Some(FuncSec(type_idxs)) => type_idxs.length()
    None => 0
  }
}

///|
fn gen_valid_rume_test_has_call_indirect(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, Expr(body)) = func
        for instr in body {
          if instr is CallIndirect(_, _) {
            return true
          }
        }
      }
    None => ()
  }
  false
}

///|
fn gen_valid_rume_test_has_instruction(
  mod_ : Module,
  predicate : (Instruction) -> Bool,
) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, Expr(body)) = func
        for instr in body {
          if predicate(instr) {
            return true
          }
        }
      }
    None => ()
  }
  false
}

///|
fn gen_valid_rume_test_has_legacy_try(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, Expr(body)) = func
        for instr in body {
          if instr is Try(_, _, _, _) {
            return true
          }
        }
      }
    None => ()
  }
  false
}

///|
test "RUME GenValid aggregate resolves every owned family" {
  @debug.assert_eq(gen_valid_profile_name(RumeAllProfile), "rume-all")
  assert_true(gen_valid_profile_is_composite(RumeAllProfile))
  let members = gen_valid_profile_members(RumeAllProfile)
  @debug.assert_eq(members.length(), 7)
  assert_true(
    members.contains(GenValidProfileMember::new(RumeDeadGraphProfile, 3)),
  )
  assert_true(
    members.contains(GenValidProfileMember::new(RumeTableTrapProfile, 2)),
  )
  assert_true(
    members.contains(GenValidProfileMember::new(RumeLegacyEhProfile, 2)),
  )
  assert_true(
    members.contains(GenValidProfileMember::new(RumeSpecialImportsProfile, 3)),
  )
  assert_true(
    members.contains(
      GenValidProfileMember::new(RumeCallableReferencesProfile, 2),
    ),
  )
  assert_true(
    members.contains(
      GenValidProfileMember::new(RumeContinuationsDescriptorsProfile, 2),
    ),
  )
  assert_true(
    members.contains(GenValidProfileMember::new(RumeIndexRemapStressProfile, 3)),
  )
  for
    name in [
      "remove-unused-module-elements", "rume", "rume-closeout", "rume-all",
    ] {
    match gen_valid_profile_by_name(name) {
      Ok(profile) => @debug.assert_eq(profile, RumeAllProfile)
      Err(msg) => fail(msg)
    }
  }
}

///|
test "RUME special-import profile emits ordinary and tail direct-call variants" {
  let ordinary_without_effects = gen_valid_rume_special_imports_module(0UL)
  let tail_without_effects = gen_valid_rume_special_imports_module(1UL)
  let ordinary_configure = gen_valid_rume_special_imports_module(2UL)
  let tail_configure = gen_valid_rume_special_imports_module(3UL)
  for
    mod_ in [
      ordinary_without_effects, tail_without_effects, ordinary_configure, tail_configure,
    ] {
    match validate_module(mod_) {
      Ok(_) => ()
      Err(err) => fail(validation_error_message(err))
    }
  }
  assert_true(
    gen_valid_rume_test_has_instruction(ordinary_without_effects, fn(instr) {
      instr is Call(_)
    }),
  )
  assert_true(
    gen_valid_rume_test_has_instruction(tail_without_effects, fn(instr) {
      instr is ReturnCall(_)
    }),
  )
  assert_true(
    gen_valid_rume_test_has_instruction(ordinary_configure, fn(instr) {
      instr is Call(_)
    }),
  )
  assert_true(
    gen_valid_rume_test_has_instruction(tail_configure, fn(instr) {
      instr is ReturnCall(_)
    }),
  )
}

///|
test "RUME GenValid leaves emit valid pass-owned opportunities" {
  let profiles = [
    RumeDeadGraphProfile,
    RumeTableTrapProfile,
    RumeLegacyEhProfile,
    RumeSpecialImportsProfile,
    RumeCallableReferencesProfile,
    RumeContinuationsDescriptorsProfile,
    RumeIndexRemapStressProfile,
  ]
  for i = 0; i < profiles.length(); i = i + 1 {
    let generated = match
      gen_valid_module_result_from_seed(
        0x52554D45UL + i.to_uint64(),
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
    @debug.assert_eq(
      generated.config_label,
      gen_valid_profile_name(profiles[i]),
    )
    match profiles[i] {
      RumeDeadGraphProfile => {
        assert_true(
          gen_valid_rume_test_defined_func_count(generated.wasm_module) >= 3,
        )
        assert_true(generated.wasm_module.global_sec is Some(_))
        assert_true(generated.wasm_module.table_sec is Some(_))
        assert_true(generated.wasm_module.mem_sec is Some(_))
        assert_true(generated.wasm_module.tag_sec is Some(_))
        assert_true(generated.wasm_module.elem_sec is Some(_))
        assert_true(generated.wasm_module.data_sec is Some(_))
      }
      RumeTableTrapProfile => {
        assert_true(
          gen_valid_rume_test_has_call_indirect(generated.wasm_module),
        )
        assert_true(generated.wasm_module.table_sec is Some(_))
        assert_true(generated.wasm_module.elem_sec is Some(_))
      }
      RumeLegacyEhProfile => {
        assert_true(gen_valid_rume_test_has_legacy_try(generated.wasm_module))
        match generated.wasm_module.tag_sec {
          Some(TagSec(tags)) => @debug.assert_eq(tags.length(), 2)
          None => fail("expected dead and live legacy-EH tags")
        }
      }
      RumeSpecialImportsProfile => {
        assert_true(generated.wasm_module.import_sec is Some(_))
        assert_true(
          gen_valid_rume_test_has_instruction(generated.wasm_module, fn(instr) {
            instr is Call(_) || instr is ReturnCall(_)
          }),
        )
      }
      RumeCallableReferencesProfile => {
        assert_true(
          gen_valid_rume_test_has_instruction(generated.wasm_module, fn(instr) {
            instr is CallRef(_) || instr is ReturnCallRef(_)
          }),
        )
        assert_true(generated.wasm_module.table_sec is Some(_))
        assert_true(generated.wasm_module.func_annotation_sec is Some(_))
      }
      RumeContinuationsDescriptorsProfile => {
        assert_true(
          gen_valid_rume_test_has_instruction(generated.wasm_module, fn(instr) {
            instr is ContNew(_)
          }),
        )
        assert_true(generated.wasm_module.global_sec is Some(_))
      }
      RumeIndexRemapStressProfile => {
        assert_true(
          gen_valid_rume_test_defined_func_count(generated.wasm_module) >= 6,
        )
        match generated.wasm_module.global_sec {
          Some(GlobalSec(globals)) => assert_true(globals.length() >= 2)
          None => fail("expected index-remap globals")
        }
      }
      _ => fail("unexpected RUME profile")
    }
  }
}
