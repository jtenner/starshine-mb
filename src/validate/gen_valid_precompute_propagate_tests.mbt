///|
test "precompute-propagate gen-valid profile exposes stable names and trigger limits" {
  @debug.assert_eq(
    gen_valid_profile_name(PrecomputePropagateLocalFactsProfile),
    "precompute-propagate-local-facts",
  )
  for name in ["precompute-propagate-local-facts"] {
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

///|
test "precompute aggregate profiles include returned scalar GC and effectful values" {
  @debug.assert_eq(
    gen_valid_profile_name(PrecomputeScalarValueProfile),
    "precompute-scalar-values",
  )
  @debug.assert_eq(
    gen_valid_profile_name(PrecomputeGcValueProfile),
    "precompute-gc-values",
  )
  @debug.assert_eq(
    gen_valid_profile_name(PrecomputeEffectfulValueProfile),
    "precompute-effectful-values",
  )
  let aggregate = gen_valid_profile_members(PrecomputeAllProfile)
  assert_true(
    aggregate.any(fn(entry) { entry.profile == PrecomputeScalarValueProfile }),
  )
  assert_true(
    aggregate.any(fn(entry) { entry.profile == PrecomputeGcValueProfile }),
  )
  assert_true(
    aggregate.any(fn(entry) { entry.profile == PrecomputeEffectfulValueProfile }),
  )
  assert_true(
    aggregate.any(fn(entry) {
      entry.profile == PrecomputePropagateLocalFactsProfile
    }),
  )
  assert_true(
    gen_valid_profile_members(RandomAllProfilesProfile).any(fn(entry) {
      entry.profile == PrecomputeAllProfile
    }),
  )
  for name in ["precompute-propagate", "precompute-propagate-closeout"] {
    @debug.assert_eq(
      match gen_valid_profile_by_name(name) {
        Ok(profile) => profile
        Err(msg) => fail(msg)
      },
      PrecomputeAllProfile,
    )
  }
}

///|
test "precompute returned-value profiles emit the missing optimization families" {
  let scalar = match
    gen_valid_module_result_from_seed(
      0x5eedUL,
      GenValidConfig::for_profile(PrecomputeScalarValueProfile),
    ) {
    Ok(value) => value.wasm_module
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(scalar) {
    Ok(_) => ()
    Err(err) => fail(validation_error_message(err))
  }
  let scalar_text = scalar.to_string()
  assert_true(scalar_text.contains("I32Clz"), msg=scalar_text)
  assert_true(scalar_text.contains("I32Rotl"), msg=scalar_text)
  assert_true(scalar_text.contains("F64Sqrt"), msg=scalar_text)
  assert_true(scalar_text.contains("F32Min"), msg=scalar_text)
  assert_true(scalar_text.contains("I64ExtendI32U"), msg=scalar_text)
  assert_true(scalar_text.contains("F32Ceil"), msg=scalar_text)
  assert_true(scalar_text.contains("F32Nearest"), msg=scalar_text)
  assert_true(scalar_text.contains("F64Max"), msg=scalar_text)
  assert_true(scalar_text.contains("I32TruncSatF64S"), msg=scalar_text)
  assert_true(scalar_text.contains("I64Ctz"), msg=scalar_text)
  assert_true(scalar_text.contains("I64TruncF64U"), msg=scalar_text)
  assert_true(scalar_text.contains("F32DemoteF64"), msg=scalar_text)
  assert_true(scalar_text.contains("F64PromoteF32"), msg=scalar_text)
  assert_true(scalar_text.contains("F32Add"), msg=scalar_text)
  assert_true(scalar_text.contains("F32Div"), msg=scalar_text)
  assert_true(scalar_text.contains("F64Add"), msg=scalar_text)
  assert_true(scalar_text.contains("F64Div"), msg=scalar_text)
  assert_true(scalar_text.contains("F32Max"), msg=scalar_text)

  let gc = match
    gen_valid_module_result_from_seed(
      0x5eedUL,
      GenValidConfig::for_profile(PrecomputeGcValueProfile),
    ) {
    Ok(value) => value.wasm_module
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(gc) {
    Ok(_) => ()
    Err(err) => fail(validation_error_message(err))
  }
  let gc_text = gc.to_string()
  assert_true(gc_text.contains("ArrayNewFixed"), msg=gc_text)
  assert_true(gc_text.contains("ArrayGet"), msg=gc_text)
  assert_true(gc_text.contains("ArrayNewDefault"), msg=gc_text)
  assert_true(gc_text.contains("ArrayLen"), msg=gc_text)
  assert_true(gc_text.contains("ArrayGetS"), msg=gc_text)
  assert_true(gc_text.contains("StructNewDefault"), msg=gc_text)
  assert_true(gc_text.contains("StructGetS"), msg=gc_text)
  let negative_get = gc.pretty_print_func(@lib.FuncIdx::new(6U))
  let negative_len = gc.pretty_print_func(@lib.FuncIdx::new(7U))
  let negative_default = gc.pretty_print_func(@lib.FuncIdx::new(8U))
  let fixed_oob = gc.pretty_print_func(@lib.FuncIdx::new(9U))
  assert_true(
    negative_get.contains("I32(-1)") && negative_get.contains("array.get"),
    msg=negative_get,
  )
  assert_true(
    negative_len.contains("I32(-1)") && negative_len.contains("array.len"),
    msg=negative_len,
  )
  assert_true(
    negative_default.contains("I32(-1)") &&
    negative_default.contains("array.get"),
    msg=negative_default,
  )
  assert_true(fixed_oob.contains("array.get"), msg=fixed_oob)
  let below_limit = gc.pretty_print_func(@lib.FuncIdx::new(10U))
  let at_limit_len = gc.pretty_print_func(@lib.FuncIdx::new(11U))
  let at_limit_get = gc.pretty_print_func(@lib.FuncIdx::new(12U))
  assert_true(below_limit.contains("I32(44739241)"), msg=below_limit)
  assert_true(
    at_limit_len.contains("I32(44739242)") && at_limit_len.contains("array.len"),
    msg=at_limit_len,
  )
  assert_true(
    at_limit_get.contains("I32(44739242)") && at_limit_get.contains("array.get"),
    msg=at_limit_get,
  )

  let effectful = match
    gen_valid_module_result_from_seed(
      0x5eedUL,
      GenValidConfig::for_profile(PrecomputeEffectfulValueProfile),
    ) {
    Ok(value) => value.wasm_module
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(effectful) {
    Ok(_) => ()
    Err(err) => fail(validation_error_message(err))
  }
  let effectful_text = effectful.to_string()
  assert_true(effectful_text.contains("LocalTee"), msg=effectful_text)
  assert_true(effectful_text.contains("I32Add"), msg=effectful_text)
}
