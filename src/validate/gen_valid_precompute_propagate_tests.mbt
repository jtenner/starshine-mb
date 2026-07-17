///|
test "precompute-propagate gen-valid profile exposes stable names and trigger limits" {
  @debug.assert_eq(
    gen_valid_profile_name(PrecomputePropagateLocalFactsProfile),
    "precompute-propagate-local-facts",
  )
  for
    name in [
      "precompute-propagate-local-facts", "precompute-propagate", "precompute-propagate-closeout",
    ] {
    @debug.assert_eq(
      match gen_valid_profile_by_name(name) {
        Ok(profile) => profile
        Err(msg) => fail(msg)
      },
      PrecomputePropagateLocalFactsProfile,
    )
  }
  let config = GenValidConfig::for_profile(PrecomputePropagateLocalFactsProfile)
  @debug.assert_eq(
    gen_valid_config_label(config),
    "precompute-propagate-local-facts",
  )
  assert_true(config.features.allow_calls)
  assert_false(config.features.allow_imports)
  assert_false(config.features.allow_call_indirect)
  assert_true(config.max_defined_funcs >= 2)
  assert_true(config.max_params >= 1)
  assert_true(config.max_locals >= 6)
}

///|
test "precompute-propagate gen-valid profile emits local consensus and boundary shapes" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x5eedUL,
      GenValidConfig::for_profile(PrecomputePropagateLocalFactsProfile),
    ) {
    Ok(value) => value
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated.wasm_module) {
    Ok(_) => ()
    Err(err) => fail(validation_error_message(err))
  }
  let pretty = generated.wasm_module.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(
    pretty.contains("if") && pretty.contains("local.set (Local 1)"),
    msg="profile did not emit an agreeing branch-local definition:\n\{pretty}",
  )
  assert_true(
    pretty.contains("local.set (Local 2)") &&
    pretty.contains("i32.const I32(20)"),
    msg="profile did not emit a differing reaching-set boundary:\n\{pretty}",
  )
  assert_true(
    pretty.contains("local.get (Local 3)"),
    msg="profile did not emit a defaultable-local entry read:\n\{pretty}",
  )
  assert_true(
    pretty.contains("local.tee (Local 4)") &&
    pretty.contains("local.tee (Local 5)"),
    msg="profile did not emit direct and block-fallthrough tee facts:\n\{pretty}",
  )
  assert_true(
    pretty.contains("i32.add") && pretty.contains("i32.const I32(10)"),
    msg="profile did not emit the bounded propagation/evaluation chain:\n\{pretty}",
  )
}
