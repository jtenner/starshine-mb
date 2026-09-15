///|
test "global-refining GenValid aggregate covers reference globals" {
  let profile = match gen_valid_profile_by_name("global-refining") {
    Ok(profile) => profile
    Err(error) => fail(error)
  }
  @debug.assert_eq(gen_valid_profile_name(profile), "global-refining-all")
  assert_true(gen_valid_profile_is_composite(profile))
  @debug.assert_eq(gen_valid_profile_members(profile).length(), 4)
}

///|
test "global-refining GenValid leaves vary valid global writes and boundaries" {
  for
    name in [
      "global-refining-private-writes", "global-refining-export-boundaries", "global-refining-import-aliases",
      "global-refining-subtype-joins",
    ] {
    let profile = match gen_valid_profile_by_name(name) {
      Ok(profile) => profile
      Err(error) => fail(error)
    }
    let mut previous : Module? = None
    for seed = 0; seed < 4; seed = seed + 1 {
      let config = GenValidConfig::for_profile(profile)
      let generated = match
        gen_valid_module_result_from_seed(seed.to_uint64(), config) {
        Ok(result) => result
        Err(error) => fail(error.validation_error_message)
      }
      let mod_ = generated.wasm_module
      assert_true(validate_module(mod_).is_ok())
      assert_true(mod_.global_sec.unwrap().0.length() > 0)
      @debug.assert_eq(generated.config_label, name)
      let again = gen_valid_module_result_from_seed(seed.to_uint64(), config).unwrap()
      @debug.assert_eq(mod_, again.wasm_module)
      if previous is Some(previous) {
        assert_true(mod_ != previous)
      }
      previous = Some(mod_)
      let Func(_, Expr(body)) = mod_.code_sec.unwrap().0[0]
      assert_true(body.any(fn(i) { i is GlobalSet(_) || i is If(_, _, _) }))
      if name == "global-refining-import-aliases" {
        @debug.assert_eq(mod_.import_sec.unwrap().0.length(), 2)
        @debug.assert_eq(mod_.global_sec.unwrap().0.length(), 3)
      }
      if name == "global-refining-export-boundaries" {
        @debug.assert_eq(mod_.export_sec.unwrap().0.length(), 3)
      }
    }
  }
}
