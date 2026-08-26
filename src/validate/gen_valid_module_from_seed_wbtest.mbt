///|
test "seeded module generation can omit exhaustive feature facts" {
  let config = GenValidConfig::for_profile(NaturalSmallProfile)
  let lightweight = match gen_valid_module_from_seed(0x5eedUL, config) {
    Ok(generated) => generated
    Err(failure) => fail(failure.validation_error_message)
  }
  let full = match gen_valid_module_result_from_seed(0x5eedUL, config) {
    Ok(generated) => generated
    Err(failure) => fail(failure.validation_error_message)
  }
  @debug.assert_eq(lightweight.wasm_module, full.wasm_module)
  @debug.assert_eq(lightweight.config, full.config)
  @debug.assert_eq(lightweight.config_label, full.config_label)
  @debug.assert_eq(lightweight.attempts, full.attempts)
}
