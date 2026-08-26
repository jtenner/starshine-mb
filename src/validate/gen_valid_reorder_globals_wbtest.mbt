///|
fn gen_valid_rg_test_global_count(mod_ : Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        if import_ is Import(_, _, GlobalExternType(_)) {
          count += 1
        }
      }
    None => ()
  }
  match mod_.global_sec {
    Some(GlobalSec(globals)) => count += globals.length()
    None => ()
  }
  count
}

///|
fn gen_valid_rg_test_has_legacy_try(mod_ : Module) -> Bool {
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, Expr(body)) = func
        for instr in body {
          if instr is Try(_, _, _, _) || instr is TryTable(_, _, _) {
            return true
          }
        }
      }
    None => ()
  }
  false
}

///|
test "reorder-globals GenValid aggregate resolves every source family" {
  @debug.assert_eq(
    gen_valid_profile_name(ReorderGlobalsAllProfile),
    "reorder-globals-all",
  )
  assert_true(gen_valid_profile_is_composite(ReorderGlobalsAllProfile))
  let members = gen_valid_profile_members(ReorderGlobalsAllProfile)
  @debug.assert_eq(members.length(), 7)
  for
    expected in [
      GenValidProfileMember::new(ReorderGlobalsHotTrafficProfile, 3),
      GenValidProfileMember::new(ReorderGlobalsDependencySearchProfile, 3),
      GenValidProfileMember::new(ReorderGlobalsImportedProfile, 2),
      GenValidProfileMember::new(ReorderGlobalsModuleCodeProfile, 3),
      GenValidProfileMember::new(ReorderGlobalsLegacyEhProfile, 3),
      GenValidProfileMember::new(ReorderGlobalsMetadataRemapProfile, 2),
      GenValidProfileMember::new(ReorderGlobalsThresholdProfile, 1),
    ] {
    assert_true(members.contains(expected))
  }
  for
    name in [
      "reorder-globals", "reorder-globals-closeout", "reorder-globals-all",
    ] {
    match gen_valid_profile_by_name(name) {
      Ok(profile) => @debug.assert_eq(profile, ReorderGlobalsAllProfile)
      Err(msg) => fail(msg)
    }
  }
}

///|
test "reorder-globals GenValid seeded subfamilies all validate" {
  for seed = 0; seed < 4; seed = seed + 1 {
    match
      validate_module(gen_valid_rg_dependency_search_module(seed.to_uint64())) {
      Ok(_) => ()
      Err(err) =>
        fail("dependency seed \{seed}: \{validation_error_message(err)}")
    }
    match validate_module(gen_valid_rg_module_code_module(seed.to_uint64())) {
      Ok(_) => ()
      Err(err) =>
        fail("module-code seed \{seed}: \{validation_error_message(err)}")
    }
  }
  for seed = 0; seed < 5; seed = seed + 1 {
    match validate_module(gen_valid_rg_legacy_eh_module(seed.to_uint64())) {
      Ok(_) => ()
      Err(err) => fail(validation_error_message(err))
    }
  }
  for seed = 0; seed < 3; seed = seed + 1 {
    let mod_ = gen_valid_rg_threshold_module(seed.to_uint64())
    match validate_module(mod_) {
      Ok(_) => ()
      Err(err) => fail(validation_error_message(err))
    }
    @debug.assert_eq(gen_valid_rg_test_global_count(mod_), 127 + seed)
  }
}

///|
test "reorder-globals GenValid leaves emit valid pass-owned surfaces" {
  let profiles = [
    ReorderGlobalsHotTrafficProfile,
    ReorderGlobalsDependencySearchProfile,
    ReorderGlobalsImportedProfile,
    ReorderGlobalsModuleCodeProfile,
    ReorderGlobalsLegacyEhProfile,
    ReorderGlobalsMetadataRemapProfile,
    ReorderGlobalsThresholdProfile,
  ]
  for i = 0; i < profiles.length(); i = i + 1 {
    let generated = match
      gen_valid_module_result_from_seed(
        0x52474C4FUL + i.to_uint64(),
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
    assert_true(gen_valid_rg_test_global_count(generated.wasm_module) >= 127)
    match profiles[i] {
      ReorderGlobalsImportedProfile => {
        assert_true(generated.wasm_module.import_sec is Some(_))
        assert_true(generated.wasm_module.global_sec is None)
      }
      ReorderGlobalsModuleCodeProfile =>
        assert_true(
          generated.wasm_module.table_sec is Some(_) ||
          generated.wasm_module.elem_sec is Some(_) ||
          generated.wasm_module.data_sec is Some(_) ||
          generated.wasm_module.global_sec is Some(_),
        )
      ReorderGlobalsLegacyEhProfile =>
        assert_true(gen_valid_rg_test_has_legacy_try(generated.wasm_module))
      ReorderGlobalsMetadataRemapProfile => {
        assert_true(generated.wasm_module.export_sec is Some(_))
        assert_true(generated.wasm_module.name_sec is Some(_))
      }
      _ => ()
    }
  }
}
