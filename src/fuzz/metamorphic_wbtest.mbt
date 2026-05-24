///|
test "metamorphic add-custom transform preserves validation and binary roundtrip" {
  let generated = match
    gen_valid_module_result_from_seed(
      0x1036UL,
      GenValidConfig::natural_default(),
    ) {
    Ok(v) => v
    Err(e) =>
      fail("expected valid GenValid seed, got \{e.validation_error_message}")
  }
  let transformed = match
    metamorphic_apply_transform(generated.wasm_module, AddNonNameCustomSection) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(transformed.transform_id, "add-non-name-custom-section")
  @debug.assert_eq(
    transformed.wasm_module.custom_secs.length(),
    generated.wasm_module.custom_secs.length() + 1,
  )
  match validate_module(transformed.wasm_module) {
    Ok(_) => ()
    Err(err) => fail(validation_error_message(err))
  }
  let encoded = match encode_module(transformed.wasm_module) {
    Ok(bytes) => bytes
    Err(msg) => fail("encode failed: \{msg}")
  }
  let decoded = match decode_module(encoded) {
    Ok(mod) => mod
    Err(msg) => fail("decode failed: \{msg}")
  }
  match validate_module(decoded) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "decoded transformed module invalid: \{validation_error_message(err)}",
      )
  }
}

///|
test "metamorphic smoke applies deterministic transform to GenValid source" {
  let stats = match run_validate_valid_metamorphic_fuzz("smoke", 0x1036UL) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(stats.profile, "smoke")
  @debug.assert_eq(stats.generated, 1)
  @debug.assert_eq(stats.transformed, 1)
  @debug.assert_eq(stats.validated, 1)
  assert_true(stats.transform_ids.contains("add-non-name-custom-section"))
}
